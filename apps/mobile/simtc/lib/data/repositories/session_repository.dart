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
  ///
  /// Pública porque "Dados do treinamento" usa a mesma janela para avisar
  /// quando uma data nova tira a sessão desta lista (Fase 6B).
  static const int historyWindowDays = 90;

  static const String _offlineMessage =
      'Não foi possível atualizar. Mostrando os dados já baixados.';

  static const String _startFailed =
      'Não foi possível iniciar a sessão. Tente de novo.';

  static const String _updateFailed =
      'Não foi possível salvar as alterações. Tente de novo.';

  static const String _cancelFailed =
      'Não foi possível cancelar a sessão. Tente de novo.';

  /// `AAAA-MM-DD`: a data de calendário como o backend a recebe — o mesmo
  /// formato que o painel web manda de um `<input type="date">`.
  static String _isoDate(DateTime date) {
    String dois(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${dois(date.month)}-${dois(date.day)}';
  }

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

  /// Uma sessão do cache — o cabeçalho da tela 1.4. Emite nulo se ela não
  /// estiver no aparelho (a Home podou, por exemplo).
  Stream<TrainingSession?> watchSession(String sessionId) {
    final query = _db.select(_db.sessions)
      ..where((t) => t.id.equals(sessionId));
    return query.watchSingleOrNull().map(
          (row) => row == null ? null : TrainingSession.fromRow(row),
        );
  }

  /// Inicia a sessão (`POST /training-sessions/:id/start`). Só o ADMIN e o
  /// consultor responsável podem — o backend responde 403 para os demais.
  ///
  /// Com sucesso, o status local muda na hora para os botões de atribuir
  /// aparecerem sem esperar o re-sync do detalhe.
  Future<Result<void>> start(String sessionId) async {
    try {
      await _api.post<Map<String, dynamic>>('$_path/$sessionId/start');
    } on ApiException catch (error) {
      final ownMessage = error.statusCode == 403 || error.isNetworkError;
      return Failure(error, ownMessage ? error.message : _startFailed);
    } catch (error) {
      return Failure(Exception('$error'), _startFailed);
    }

    try {
      await (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId)))
          .write(
        SessionsCompanion(status: Value(SessionStatus.emAndamento.wireValue)),
      );
    } catch (_) {
      // O backend já iniciou; o re-sync do detalhe corrige a linha local.
    }
    return const Success<void>(null);
  }

  /// "Dados do treinamento" (Fase 6A): edita data, cidade, UF e observações
  /// (`PATCH /training-sessions/:id`, só ADMIN). Nulo quer dizer "não mudou"
  /// e não é enviado — assim uma edição feita no painel web em outro campo
  /// não é desfeita por um valor velho do cache. Observações vazias limpam o
  /// campo no servidor; a data não tem como ser apagada (o backend ignora
  /// data vazia).
  ///
  /// O backend recusa (403) sessão concluída ou cancelada. Com sucesso, o
  /// cache muda na hora, sem esperar o re-sync do detalhe.
  Future<Result<void>> update(
    String sessionId, {
    DateTime? date,
    String? city,
    String? state,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      if (date != null) 'date': _isoDate(date),
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (notes != null) 'notes': notes,
    };
    if (body.isEmpty) return const Success<void>(null);

    try {
      await _api.patch<Map<String, dynamic>>('$_path/$sessionId', data: body);
    } on ApiException catch (error) {
      return Failure(error, _ownMessage(error) ? error.message : _updateFailed);
    } catch (error) {
      return Failure(Exception('$error'), _updateFailed);
    }

    try {
      await (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId)))
          .write(
        SessionsCompanion(
          date: date == null ? const Value.absent() : Value(date),
          city: city == null ? const Value.absent() : Value(city),
          state: state == null ? const Value.absent() : Value(state),
          notes: notes == null ? const Value.absent() : Value(notes),
        ),
      );
    } catch (_) {
      // O backend já gravou; o re-sync do detalhe corrige a linha local.
    }
    return const Success<void>(null);
  }

  /// "Cancelar sessão" (`PATCH /training-sessions/:id/cancel`, só ADMIN). O
  /// backend recusa (403) sessão já concluída ou já cancelada, e não há como
  /// desfazer. Com sucesso, o status local muda na hora — e a Home deixa de
  /// mostrar a sessão (decisão de 20/09/2026).
  Future<Result<void>> cancel(String sessionId) async {
    try {
      await _api.patch<Map<String, dynamic>>('$_path/$sessionId/cancel');
    } on ApiException catch (error) {
      return Failure(error, _ownMessage(error) ? error.message : _cancelFailed);
    } catch (error) {
      return Failure(Exception('$error'), _cancelFailed);
    }

    try {
      await (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId)))
          .write(
        SessionsCompanion(status: Value(SessionStatus.cancelado.wireValue)),
      );
    } catch (_) {
      // O backend já cancelou; o próximo sync corrige a linha local.
    }
    return const Success<void>(null);
  }

  /// Recusas do backend que explicam o que houve — 403 (sessão concluída ou
  /// cancelada) e 404 (sessão apagada) — e a falta de rede, cuja mensagem já
  /// diz o que fazer. O resto (400 de validação, 5xx) vira o texto genérico.
  static bool _ownMessage(ApiException error) =>
      error.statusCode == 403 || error.statusCode == 404 || error.isNetworkError;

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
      const Duration(days: historyWindowDays),
    );

    try {
      for (var page = 1; page <= _maxPages; page++) {
        final response = await _api.get<Map<String, dynamic>>(
          _path,
          queryParameters: {
            'page': page,
            'limit': _pageSize,
            'from': _isoDate(from),
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
        // O logo só entra quando a listagem o traz (o card da Home o mostra
        // desde 24/09/2026). Nulo fica de fora em vez de virar `Value(null)`:
        // um backend ainda sem o campo na listagem apagaria, a cada sync da
        // Home, o logo que o detalhe gravou — no upsert, coluna ausente do
        // companion não é tocada. `participantsSyncedAt` fica sempre de fora:
        // só o detalhe sabe quando baixou os participantes.
        await _db.into(_db.sessions).insertOnConflictUpdate(
              SessionsCompanion.insert(
                id: session.id,
                companyName: session.companyName,
                companyLogoUrl: session.companyLogoUrl == null
                    ? const Value.absent()
                    : Value(session.companyLogoUrl),
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
