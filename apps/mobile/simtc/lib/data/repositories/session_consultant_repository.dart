import 'package:drift/drift.dart';

import '../../utils/result.dart';
import '../models/session_consultant.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/local/app_database.dart';

/// Consultores de uma sessão (tela "Consultores", Fase 6B).
///
/// Como nos outros repositórios, a tela lê do banco: [watchBySession] serve os
/// consultores que o detalhe da sessão baixou. [add] e [remove] mandam um
/// consultor por vez ao backend e gravam no cache a lista que ele devolve. A
/// equipe ([fetchTeam]) é a exceção: vem do servidor a cada abertura da tela
/// e não fica guardada.
class SessionConsultantRepository {
  SessionConsultantRepository({
    required ApiClient apiClient,
    required AppDatabase database,
  })  : _api = apiClient,
        _db = database;

  final ApiClient _api;
  final AppDatabase _db;

  static const String _teamPath = '/consultants';

  static const String _teamFailed = 'Não foi possível carregar a equipe.';
  static const String _addFailed =
      'Não foi possível adicionar o consultor. Tente de novo.';
  static const String _removeFailed =
      'Não foi possível remover o consultor. Tente de novo.';

  /// Os consultores da sessão que estão no cache. A ordem de exibição (o
  /// responsável primeiro) é regra de tela e fica na ViewModel.
  Stream<List<SessionConsultant>> watchBySession(String sessionId) {
    final query = _db.select(_db.sessionConsultants)
      ..where((t) => t.sessionId.equals(sessionId))
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);

    return query.watch().map(
          (rows) => rows.map(SessionConsultant.fromRow).toList(growable: false),
        );
  }

  /// Os consultores ativos da equipe (`GET /consultants?active=true`, aberto a
  /// ADMIN e a consultor), na ordem em que o backend manda. Quem já está na
  /// sessão também vem: tirar esses da lista é da ViewModel.
  Future<Result<List<SessionConsultant>>> fetchTeam() async {
    try {
      final response = await _api.get<List<dynamic>>(
        _teamPath,
        queryParameters: {'active': 'true'},
      );
      final body = response.data;
      if (body == null) {
        return Failure(
          Exception('resposta de $_teamPath fora do formato'),
          _teamFailed,
        );
      }
      return Success(
        body
            .map(SessionConsultant.tryParse)
            .whereType<SessionConsultant>()
            .toList(growable: false),
      );
    } on ApiException catch (error) {
      return Failure(error, error.isNetworkError ? error.message : _teamFailed);
    } catch (error) {
      return Failure(Exception('$error'), _teamFailed);
    }
  }

  /// Põe um consultor na sessão
  /// (`POST /training-sessions/:id/consultants`, só ADMIN).
  Future<Result<void>> add(String sessionId, String consultantId) {
    return _change(
      sessionId,
      () async {
        final response = await _api.post<Map<String, dynamic>>(
          '/training-sessions/$sessionId/consultants',
          data: {'consultantId': consultantId},
        );
        return response.data;
      },
      _addFailed,
    );
  }

  /// Tira um consultor da sessão
  /// (`DELETE /training-sessions/:id/consultants/:consultantId`, só ADMIN). O
  /// backend libera, na mesma operação, quem estava em avaliação com ele: quem
  /// chama baixa a sessão de novo para a lista de participantes acompanhar.
  Future<Result<void>> remove(String sessionId, String consultantId) {
    return _change(
      sessionId,
      () async {
        final response = await _api.delete<Map<String, dynamic>>(
          '/training-sessions/$sessionId/consultants/$consultantId',
        );
        return response.data;
      },
      _removeFailed,
    );
  }

  /// Manda a mudança e grava no cache os consultores que o backend devolve
  /// (`{ responsibleConsultantId, consultants: [...] }`).
  Future<Result<void>> _change(
    String sessionId,
    Future<Map<String, dynamic>?> Function() send,
    String fallback,
  ) async {
    final Map<String, dynamic>? body;
    try {
      body = await send();
    } on ApiException catch (error) {
      // 400 (consultor inativo, ou tentar tirar o responsável), 403 (sessão
      // concluída ou cancelada) e 404 (a sessão ou o consultor não existem
      // mais) têm mensagem própria do backend; sem rede, a do `ApiException`
      // já diz o que fazer.
      final status = error.statusCode;
      final ownMessage =
          status == 400 || status == 403 || status == 404 || error.isNetworkError;
      return Failure(error, ownMessage ? error.message : fallback);
    } catch (error) {
      return Failure(Exception('$error'), fallback);
    }

    try {
      final consultants =
          body == null ? null : SessionConsultant.listFromJson(body);
      if (consultants != null) {
        await _db.replaceSessionConsultants(
          sessionId,
          consultants.map((c) => c.toCompanion(sessionId)),
        );
      }
    } catch (_) {
      // O backend já mudou — isso é o que importa. Com a resposta fora do
      // formato, ou a sessão fora do cache, o próximo download do detalhe
      // acerta a lista.
    }
    return const Success<void>(null);
  }
}
