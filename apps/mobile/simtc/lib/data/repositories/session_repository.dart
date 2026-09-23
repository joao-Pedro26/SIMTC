import 'package:drift/drift.dart';

import '../../utils/result.dart';
import '../models/training_session.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/local/app_database.dart';

/// Sessões de treinamento do consultor.
///
/// A regra desta camada é simples: **a tela lê do banco, nunca da resposta
/// HTTP**. `syncAll()` baixa e grava; `watchSessions()` serve a lista. Sem rede,
/// `syncAll()` falha e a lista continua vindo do cache — é assim que a Home
/// funciona offline sem nenhum código de offline na tela.
class SessionRepository {
  SessionRepository({required ApiClient apiClient, required AppDatabase database})
      : _api = apiClient,
        _db = database;

  final ApiClient _api;
  final AppDatabase _db;

  static const String _path = '/training-sessions';

  /// Páginas maiores que o padrão do backend: a Home quer a lista inteira e
  /// cada viagem extra custa caro no 4G do cliente.
  static const int _pageSize = 50;

  /// Teto de segurança para não girar para sempre se o backend devolver um
  /// `totalPages` incoerente.
  static const int _maxPages = 10;

  /// Quanto passado o app carrega. Fora disso, o consultor consulta pelo painel
  /// web — baixar o histórico inteiro faria o admin, que recebe todas as sessões
  /// do sistema, estourar o teto de páginas e ficar com uma lista parcial em
  /// silêncio. Decidido com o usuário em 20/09/2026.
  static const int _historyWindowDays = 90;

  static const String _offlineMessage =
      'Não foi possível atualizar. Mostrando os dados já baixados.';

  /// Lista do cache, da data mais próxima para a mais distante; sem data por
  /// último, porque não dá para saber onde ela entra na agenda.
  Stream<List<TrainingSession>> watchSessions() {
    final query = _db.select(_db.sessions)
      ..orderBy([
        (t) => OrderingTerm(expression: t.date.isNull()),
        (t) => OrderingTerm(expression: t.date),
        (t) => OrderingTerm(expression: t.companyName),
      ]);

    return query.watch().map(
          (rows) => rows.map(TrainingSession.fromRow).toList(growable: false),
        );
  }

  /// Quando o cache foi atualizado pela última vez — a tela mostra isso quando
  /// está offline, para o consultor saber a idade do que está vendo.
  Stream<DateTime?> watchLastSyncedAt() {
    final cachedAt = _db.sessions.cachedAt.max();
    final query = _db.selectOnly(_db.sessions)..addColumns([cachedAt]);
    return query.watchSingleOrNull().map((row) => row?.read(cachedAt));
  }

  /// Baixa todas as páginas e regrava o cache. Devolve quantas sessões ficaram.
  ///
  /// Nada é escrito antes de todas as páginas chegarem: uma queda no meio do
  /// caminho deixaria o cache com metade da agenda, que é pior do que a agenda
  /// velha inteira.
  Future<Result<int>> syncAll() async {
    final sessions = <TrainingSession>[];
    var reachedEnd = false;

    // Calculado uma vez antes do laço: uma virada de meia-noite no meio do
    // sync não pode mudar o filtro entre páginas.
    final from = DateTime.now().subtract(
      const Duration(days: _historyWindowDays),
    );
    String dois(int value) => value.toString().padLeft(2, '0');

    try {
      for (var page = 1; page <= _maxPages; page++) {
        final response = await _api.get<Map<String, dynamic>>(
          _path,
          queryParameters: {
            'page': page,
            'limit': _pageSize,
            'from': '${from.year}-${dois(from.month)}-${dois(from.day)}',
          },
        );

        final body = response.data ?? const <String, dynamic>{};
        final data = body['data'];
        // Um corpo 200 fora do formato esperado (vazio, `{}`, envelope
        // renomeado numa futura mudança de backend, resposta de proxy) não
        // pode virar "página vazia": isso levaria a `reachedEnd = true` e a
        // poda apagaria o cache inteiro (`id NOT IN ()` é sempre verdadeiro
        // no SQLite). Só poda quando a resposta foi de fato entendida.
        if (data is! List) {
          return Failure(
            Exception('resposta de $_path fora do formato esperado'),
            _offlineMessage,
          );
        }
        sessions.addAll(
          data.whereType<Map<String, dynamic>>().map(TrainingSession.fromJson),
        );

        final totalPages = (body['totalPages'] as num?)?.toInt() ?? page;
        if (page >= totalPages) {
          reachedEnd = true;
          break;
        }
      }

      // Só poda quando a lista veio inteira: se o teto de páginas interrompeu
      // o download, apagar "o que não veio" jogaria fora sessões válidas.
      //
      // `_write` fica dentro deste `try`: uma falha de escrita do drift não
      // pode subir crua — quem chama (`SessionsListViewModel.refresh`) espera
      // sempre um `Result`, e uma exceção sem tratamento trava o
      // pull-to-refresh (o `_isRefreshing` de lá nunca volta a `false`).
      await _write(sessions, prune: reachedEnd);
      return Success(sessions.length);
    } on ApiException catch (error) {
      return Failure(error, _offlineMessage);
    } catch (error) {
      // Rede de segurança para o que não é `ApiException`: um `TypeError` do
      // `fromJson` (campo com tipo inesperado do backend) ou uma falha de
      // escrita do drift, por exemplo. O cache antigo continua intacto — a
      // escrita só acontece dentro da transação de `_write`, que não chegou
      // a ser chamada ou foi desfeita por inteiro.
      return Failure(Exception('$error'), _offlineMessage);
    }
  }

  Future<void> _write(List<TrainingSession> sessions, {required bool prune}) {
    final now = DateTime.now();

    return _db.transaction(() async {
      if (prune) {
        final ids = sessions.map((s) => s.id).toList(growable: false);
        // Participantes têm chave estrangeira para a sessão: apagar a sessão
        // antes deles violaria a FK e derrubaria a transação inteira.
        await (_db.delete(_db.participants)
              ..where((t) => t.sessionId.isNotIn(ids)))
            .go();
        await (_db.delete(_db.sessions)..where((t) => t.id.isNotIn(ids))).go();
      }

      for (final session in sessions) {
        // `companyLogoUrl` fica de fora de propósito: a listagem não traz o
        // logo (só o detalhe da sessão traz), e um `Value(null)` aqui apagaria
        // a cada sync da Home o logo que o detalhe gravou. No upsert, coluna
        // ausente do companion não é tocada. Pelo mesmo motivo,
        // `participantsSyncedAt` também fica de fora.
        await _db.into(_db.sessions).insertOnConflictUpdate(
              SessionsCompanion.insert(
                id: session.id,
                companyName: session.companyName,
                courseName: session.courseName,
                city: session.city,
                state: session.state,
                date: Value(session.date),
                status: session.status.wireValue,
                notes: Value(session.notes),
                totalParticipants: Value(session.totalParticipants),
                assessableParticipants: Value(session.assessableParticipants),
                assessedParticipants: Value(session.assessedParticipants),
                responsibleConsultantId: Value(session.responsibleConsultantId),
                cachedAt: now,
              ),
            );
      }
    });
  }
}
