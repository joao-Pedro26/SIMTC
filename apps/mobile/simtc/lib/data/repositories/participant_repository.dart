import 'package:drift/drift.dart';

import '../../utils/result.dart';
import '../../utils/scoring.dart';
import '../models/cpf_lookup.dart';
import '../models/remote_assessment.dart';
import '../models/session_consultant.dart';
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
    DateTime Function()? now,
  })  : _api = apiClient,
        _db = database,
        _now = now ?? DateTime.now;

  final ApiClient _api;
  final AppDatabase _db;
  final DateTime Function() _now;

  static const String _assignPath = '/practical-assessments/assign';
  static const String _unassignPath = '/practical-assessments/unassign';

  static const String _refreshFailed =
      'Não foi possível atualizar. Mostrando os dados já baixados.';
  static const String _assignFailed =
      'Não foi possível atribuir o participante. Tente de novo.';
  static const String _unassignFailed =
      'Não foi possível desatribuir o participante. Tente de novo.';
  static const String _resultFailed = 'Não foi possível carregar o resultado.';
  static const String _lookupFailed = 'Não foi possível consultar o CPF.';
  static const String _addFailed =
      'Não foi possível adicionar o participante. Tente de novo.';

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

  /// Um participante do cache — o cabeçalho do checklist (Fase 4). Emite
  /// nulo se ele não estiver no aparelho.
  Stream<SessionParticipant?> watchParticipant(String participantId) {
    final query = _db.select(_db.participants)
      ..where((t) => t.id.equals(participantId));
    return query.watchSingleOrNull().map(
          (row) => row == null ? null : SessionParticipant.fromRow(row),
        );
  }

  /// Uma leitura só do participante do cache; nulo se ele não estiver no
  /// aparelho. Para quem precisa do valor agora, sem assinar o stream.
  Future<SessionParticipant?> findParticipant(String participantId) async {
    final row = await (_db.select(_db.participants)
          ..where((t) => t.id.equals(participantId)))
        .getSingleOrNull();
    return row == null ? null : SessionParticipant.fromRow(row);
  }

  /// Baixa `GET /training-sessions/:id` e regrava a sessão, os participantes e
  /// os consultores dela numa transação só. Devolve quantos participantes
  /// ficaram.
  ///
  /// O `participantsSyncedAt` é a hora em que o GET foi **pedido**, não a da
  /// escrita: os dados valem a partir de quando foram pedidos. Um GET
  /// respondido antes de um envio aceito, mas gravado depois, não pode parecer
  /// posterior a ele (a linha "Enviada" do detalhe compara os dois horários).
  Future<Result<int>> syncSession(String sessionId) async {
    final requestedAt = _now();
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

      await _write(
        session,
        participants,
        SessionConsultant.listFromJson(body),
        requestedAt,
      );
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
    List<SessionConsultant>? consultants,
    DateTime now,
  ) {
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

      // Os consultores vêm no mesmo corpo (Fase 6B). Nulo: a resposta não
      // trouxe a lista, e o que já está no cache fica.
      if (consultants != null) {
        await _db.replaceSessionConsultants(
          session.id,
          consultants.map((c) => c.toCompanion(session.id)),
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

  /// A avaliação do participante no backend
  /// (`GET /practical-assessments/by-participant/:id`), para a tela de
  /// Resultado (Fase 5B). `Success(null)` quando o backend não tem avaliação
  /// dele. Nada é guardado no aparelho (decisão de 01/10/2026): sem rede, a
  /// tela mostra o que o cache da sessão já tem.
  Future<Result<RemoteAssessment?>> fetchAssessment(String participantId) async {
    try {
      final response = await _api
          .get<Object?>('/practical-assessments/by-participant/$participantId');
      final body = response.data;
      // O NestJS responde 200 sem corpo quando a avaliação não existe.
      if (body == null || body == '') return const Success(null);

      final assessment = RemoteAssessment.tryParse(body);
      if (assessment == null) {
        return Failure(
          Exception('resposta de by-participant/$participantId fora do formato'),
          _resultFailed,
        );
      }
      return Success(assessment);
    } on ApiException catch (error) {
      return Failure(error, error.isNetworkError ? error.message : _resultFailed);
    } catch (error) {
      return Failure(Exception('$error'), _resultFailed);
    }
  }

  /// "Desatribuir participante" (decisão de 01/10/2026): libera no backend
  /// (`POST /practical-assessments/unassign`) o participante reservado para o
  /// consultor logado.
  ///
  /// Precisa de conexão, como o [assign]. Com sucesso, a linha local muda na
  /// hora pela mesma regra do backend: sem atribuição, e de volta ao status de
  /// antes — "Pendente" se nunca foi avaliado, ou o da nota anterior numa
  /// reavaliação.
  Future<Result<void>> unassign(String participantId) async {
    try {
      await _api.post<Map<String, dynamic>>(
        _unassignPath,
        data: {
          'participantIds': [participantId],
        },
      );
    } on ApiException catch (error) {
      // 409: "não estão atribuídos a você" (o painel passou o participante
      // para outro consultor, por exemplo). Sem rede, a mensagem do
      // `ApiException` já diz o que fazer.
      final ownMessage = error.statusCode == 409 || error.isNetworkError;
      return Failure(error, ownMessage ? error.message : _unassignFailed);
    } catch (error) {
      return Failure(Exception('$error'), _unassignFailed);
    }

    try {
      final row = await (_db.select(_db.participants)
            ..where((t) => t.id.equals(participantId)))
          .getSingleOrNull();
      final score = row?.score;
      await (_db.update(_db.participants)
            ..where((t) => t.id.equals(participantId)))
          .write(
        ParticipantsCompanion(
          status: Value(score != null
              ? getApprovalStatus(score)
              : ParticipantStatus.pendente.wireValue),
          assignedConsultantId: const Value(null),
          assignedConsultantName: const Value(null),
        ),
      );
    } catch (_) {
      // O backend já liberou — isso é o que importa. O próximo sync da
      // sessão corrige a linha.
    }
    return const Success<void>(null);
  }

  /// Consulta de CPF de "Adicionar participante" (Fase 6A,
  /// `POST /training-sessions/:id/participants/lookup`, só ADMIN): diz se o
  /// CPF já tem cadastro — com nome e e-mail, para a tela preencher — e se já
  /// está nesta sessão. [cpf] vai só com dígitos, no corpo (não na URL).
  ///
  /// Toda falha tem a mesma mensagem: a tela não bloqueia por causa dela —
  /// segue como formulário simples, e o backend resolve o CPF repetido.
  Future<Result<CpfLookup>> lookupCpf(String sessionId, String cpf) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/training-sessions/$sessionId/participants/lookup',
        data: {'cpf': cpf},
      );
      final lookup = CpfLookup.tryParse(response.data);
      if (lookup == null) {
        return Failure(
          Exception('resposta de participants/lookup fora do formato'),
          _lookupFailed,
        );
      }
      return Success(lookup);
    } on ApiException catch (error) {
      return Failure(error, _lookupFailed);
    } catch (error) {
      return Failure(Exception('$error'), _lookupFailed);
    }
  }

  /// "Adicionar participante" (Fase 6A): inscreve na sessão
  /// (`POST /training-sessions/:id/participants`, só ADMIN). [cpf] vai só com
  /// dígitos, como o painel web manda. Para um CPF que já tem cadastro, o
  /// backend reaproveita o cadastro e grava nele o [name] — e o [email], se
  /// vier preenchido (vazio não apaga o que já está lá).
  ///
  /// Recusas com motivo próprio: 409 (CPF já inscrito nesta sessão), 400
  /// (inscrições encerradas: sessão concluída ou cancelada) e 404.
  ///
  /// Com sucesso, a linha entra no cache na hora, já com o CPF mascarado — o
  /// CPF inteiro nunca é guardado no aparelho.
  Future<Result<SessionParticipant>> add(
    String sessionId, {
    required String cpf,
    required String name,
    String? email,
    required ParticipationType participationType,
  }) async {
    final SessionParticipant added;
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/training-sessions/$sessionId/participants',
        data: {
          'cpf': cpf,
          'name': name,
          if (email != null && email.isNotEmpty) 'email': email,
          'participationType': participationType.wireValue,
        },
      );
      added = SessionParticipant.fromJson(
        response.data ?? const <String, dynamic>{},
        sessionId: sessionId,
      );
    } on ApiException catch (error) {
      final ownMessage = error.statusCode == 409 ||
          error.statusCode == 400 ||
          error.statusCode == 404 ||
          error.isNetworkError;
      return Failure(error, ownMessage ? error.message : _addFailed);
    } catch (error) {
      return Failure(Exception('$error'), _addFailed);
    }

    // O backend já inscreveu. Um corpo fora do formato não vira falha — o
    // admin tentaria de novo e receberia "CPF já inscrito": só não há linha
    // para o cache, e o re-sync do detalhe a traz.
    if (added.id.isEmpty) {
      return Success(
        SessionParticipant(
          id: '',
          sessionId: sessionId,
          name: name,
          maskedCpf: maskCpf(cpf),
          participationType: participationType,
          status: ParticipantStatus.pendente,
        ),
      );
    }

    try {
      await _db.into(_db.participants).insertOnConflictUpdate(
            ParticipantsCompanion.insert(
              id: added.id,
              sessionId: sessionId,
              name: added.name,
              cpf: added.maskedCpf,
              participationType: added.participationType.wireValue,
              status: added.status.wireValue,
              cachedAt: _now(),
            ),
          );
    } catch (_) {
      // Sessão fora do cache, por exemplo (a linha violaria a chave
      // estrangeira): o re-sync do detalhe corrige.
    }
    return Success(added);
  }
}
