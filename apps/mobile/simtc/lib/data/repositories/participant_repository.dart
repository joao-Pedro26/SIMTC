import 'package:drift/drift.dart';

import '../../utils/result.dart';
import '../models/session_participant.dart';
import '../models/training_session.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/local/app_database.dart';

/// Participantes de uma sessão e a autoatribuição.
///
/// Mesma regra do `SessionRepository`: a tela lê do banco, nunca da resposta
/// HTTP. `syncSession()` baixa o detalhe e grava; `watchBySession()` serve a
/// lista. Offline, a tela continua com o que foi baixado na última vez que a
/// sessão foi aberta com sinal (decisão de 23/09/2026: baixar ao abrir, sem
/// pré-carregar sessões que o consultor não abriu).
class ParticipantRepository {
  ParticipantRepository({
    required ApiClient apiClient,
    required AppDatabase database,
  })  : _api = apiClient,
        _db = database;

  final ApiClient _api;
  final AppDatabase _db;

  static const String _assignPath = '/practical-assessments/assign';

  static const String _refreshFailed =
      'Não foi possível atualizar. Mostrando os dados já baixados.';
  static const String _assignFailed =
      'Não foi possível atribuir o participante. Tente de novo.';

  /// Participantes da sessão em ordem de nome. A ordem de exibição (meus
  /// primeiro, somente teórica por último) é regra de tela e fica na
  /// `SessionDetailViewModel`.
  Stream<List<SessionParticipant>> watchBySession(String sessionId) {
    final query = _db.select(_db.participants)
      ..where((t) => t.sessionId.equals(sessionId))
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);

    return query.watch().map(
          (rows) =>
              rows.map(SessionParticipant.fromRow).toList(growable: false),
        );
  }

  /// Baixa `GET /training-sessions/:id` e regrava a sessão e os participantes
  /// dela numa transação só. Devolve quantos participantes ficaram.
  Future<Result<int>> syncSession(String sessionId) async {
    try {
      final response =
          await _api.get<Map<String, dynamic>>('/training-sessions/$sessionId');
      final body = response.data;
      final list = body?['participants'];

      // Mesma lição do `syncAll`: um corpo 200 fora do formato não pode virar
      // "sessão sem ninguém" — isso apagaria os participantes do cache.
      if (body == null || body['id'] != sessionId || list is! List) {
        return Failure(
          Exception('resposta de /training-sessions/$sessionId fora do formato'),
          _refreshFailed,
        );
      }

      final session = TrainingSession.fromJson(body);
      final participants = list
          .whereType<Map<String, dynamic>>()
          .map((json) => SessionParticipant.fromJson(json, sessionId: sessionId))
          .where((p) => p.id.isNotEmpty)
          .toList(growable: false);

      await _write(session, participants);
      return Success(participants.length);
    } on ApiException catch (error) {
      // 403 (consultor saiu da sessão) e 404 (sessão apagada) têm mensagem
      // própria do backend que explica o que aconteceu; o resto é "sem rede ou
      // servidor fora", e a mensagem genérica diz o que importa: o cache ficou.
      final ownMessage = error.statusCode == 403 || error.statusCode == 404;
      return Failure(error, ownMessage ? error.message : _refreshFailed);
    } catch (error) {
      return Failure(Exception('$error'), _refreshFailed);
    }
  }

  Future<void> _write(
    TrainingSession session,
    List<SessionParticipant> participants,
  ) {
    final now = DateTime.now();
    final assessable = participants
        .where((p) => p.participationType == ParticipationType.teoricaEPratica)
        .toList(growable: false);

    // As contagens do card da Home são recalculadas daqui, com a mesma regra
    // do `participantStats` do backend — voltar para a Home depois de abrir a
    // sessão mostra os números que o consultor acabou de ver.
    final fields = SessionsCompanion(
      companyName: Value(session.companyName),
      companyLogoUrl: Value(session.companyLogoUrl),
      courseName: Value(session.courseName),
      city: Value(session.city),
      state: Value(session.state),
      date: Value(session.date),
      status: Value(session.status.wireValue),
      notes: Value(session.notes),
      responsibleConsultantId: Value(session.responsibleConsultantId),
      totalParticipants: Value(participants.length),
      assessableParticipants: Value(assessable.length),
      assessedParticipants: Value(assessable.where((p) => p.isAssessed).length),
      participantsSyncedAt: Value(now),
    );

    return _db.transaction(() async {
      // `cachedAt` só entra se a linha for nova: é a idade da agenda inteira
      // que a Home mostra offline, e o detalhe de uma sessão não atualiza as
      // outras. No conflito, o `DoUpdate` grava só `fields`.
      await _db.into(_db.sessions).insert(
            fields.copyWith(id: Value(session.id), cachedAt: Value(now)),
            onConflict: DoUpdate((_) => fields),
          );

      await (_db.delete(_db.participants)
            ..where((t) => t.sessionId.equals(session.id)))
          .go();

      for (final p in participants) {
        await _db.into(_db.participants).insert(
              ParticipantsCompanion.insert(
                id: p.id,
                sessionId: session.id,
                name: p.name,
                cpf: p.maskedCpf,
                participationType: p.participationType.wireValue,
                status: p.status.wireValue,
                assignedConsultantId: Value(p.assignedConsultantId),
                assignedConsultantName: Value(p.assignedConsultantName),
                score: Value(p.score),
                assessedByConsultantId: Value(p.assessedByConsultantId),
                assessedAt: Value(p.assessedAt),
                cachedAt: now,
              ),
            );
      }
    });
  }

  /// Reserva o participante para o consultor logado
  /// (`POST /practical-assessments/assign`).
  ///
  /// Precisa de conexão por natureza: a reserva é o que impede dois
  /// consultores de avaliarem a mesma pessoa. Com sucesso, a linha local muda
  /// na hora — a tela não espera o re-sync para mostrar "Avaliando · você".
  Future<Result<void>> assign(
    String participantId, {
    required String consultantId,
    required String consultantName,
  }) async {
    try {
      await _api.post<Map<String, dynamic>>(
        _assignPath,
        data: {
          'participantIds': [participantId],
        },
      );
    } on ApiException catch (error) {
      // 409 traz o motivo do conflito ("já estão em avaliação com outro
      // consultor", "aprovados não podem ser reavaliados"...), e sem rede a
      // mensagem do `ApiException` já diz o que fazer.
      final ownMessage = error.statusCode == 409 || error.isNetworkError;
      return Failure(error, ownMessage ? error.message : _assignFailed);
    } catch (error) {
      return Failure(Exception('$error'), _assignFailed);
    }

    try {
      await (_db.update(_db.participants)
            ..where((t) => t.id.equals(participantId)))
          .write(
        ParticipantsCompanion(
          status: Value(ParticipantStatus.emAvaliacao.wireValue),
          assignedConsultantId: Value(consultantId),
          assignedConsultantName: Value(consultantName),
        ),
      );
    } catch (_) {
      // O backend já reservou — isso é o que importa. Se a escrita local
      // falhar, o re-sync que a tela dispara em seguida corrige a linha.
    }
    return const Success<void>(null);
  }
}
