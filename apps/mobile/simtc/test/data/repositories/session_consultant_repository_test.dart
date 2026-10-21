import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/session_consultant.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/utils/result.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late SessionConsultantRepository repository;

  const addPath = '/training-sessions/sess-1/consultants';
  const removePath = '/training-sessions/sess-1/consultants/c-2';

  Future<void> seedSession(String id) {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: id,
            companyName: 'Bracell',
            courseName: 'Direção Defensiva',
            city: 'Itabira',
            state: 'MG',
            status: 'EM_ANDAMENTO',
            cachedAt: DateTime(2026, 10, 9, 8),
          ),
        );
  }

  Future<void> seedConsultant(String sessionId, String id, String name) {
    return db.into(db.sessionConsultants).insert(
          SessionConsultantsCompanion.insert(
            sessionId: sessionId,
            consultantId: id,
            name: name,
          ),
        );
  }

  Future<Set<String>> cachedIds(String sessionId) async {
    final rows = await (db.select(db.sessionConsultants)
          ..where((t) => t.sessionId.equals(sessionId)))
        .get();
    return rows.map((r) => r.consultantId).toSet();
  }

  Map<String, dynamic> link(String id, String name, {String? email}) {
    return {
      'trainingSessionId': 'sess-1',
      'consultantId': id,
      'consultant': {'id': id, 'name': name, 'email': email},
    };
  }

  /// A resposta das duas rotas de consultor: quem é o responsável e os
  /// consultores da sessão depois da mudança.
  Response<Map<String, dynamic>> changed(List<Map<String, dynamic>> links) {
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: addPath),
      statusCode: 200,
      data: {'responsibleConsultantId': 'c-1', 'consultants': links},
    );
  }

  setUp(() {
    api = _MockApiClient();
    db = AppDatabase(NativeDatabase.memory());
    repository = SessionConsultantRepository(apiClient: api, database: db);
  });

  tearDown(() => db.close());

  group('aviso de mudança aceita', () {
    test('add e remove aceitos avisam a sessão; a recusa não', () async {
      final changedSessions = <String>[];
      repository = SessionConsultantRepository(
        apiClient: api,
        database: db,
        onSessionChanged: changedSessions.add,
      );
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenAnswer((_) async => changed([link('c-2', 'Rafael Lima')]));
      when(() => api.delete<Map<String, dynamic>>(removePath))
          .thenAnswer((_) async => changed([]));

      await repository.add('sess-1', 'c-2');
      await repository.remove('sess-1', 'c-2');
      expect(changedSessions, ['sess-1', 'sess-1']);

      when(() => api.delete<Map<String, dynamic>>(removePath)).thenThrow(
        const ApiException(message: 'Sessão concluída', statusCode: 403),
      );
      await repository.remove('sess-1', 'c-2');
      expect(changedSessions, hasLength(2));
    });
  });

  test('watchBySession traz só os consultores da sessão pedida, por nome',
      () async {
    await seedSession('sess-1');
    await seedSession('sess-2');
    await seedConsultant('sess-1', 'c-2', 'Rafael Lima');
    await seedConsultant('sess-1', 'c-1', 'Carla Mendes');
    await seedConsultant('sess-2', 'c-9', 'Diego Barbosa');

    final list = await repository.watchBySession('sess-1').first;

    expect(list, const [
      SessionConsultant(id: 'c-1', name: 'Carla Mendes'),
      SessionConsultant(id: 'c-2', name: 'Rafael Lima'),
    ]);
  });

  group('fetchTeam', () {
    Response<List<dynamic>> team(List<dynamic>? body) {
      return Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/consultants'),
        statusCode: 200,
        data: body,
      );
    }

    test('pede só os ativos e devolve quem veio com id e nome', () async {
      when(() => api.get<List<dynamic>>(
            '/consultants',
            queryParameters: {'active': 'true'},
          )).thenAnswer((_) async => team([
            {'id': 'c-2', 'name': 'Rafael Lima', 'email': 'rafael@sim.com', 'active': true},
            {'id': 'c-1', 'name': 'Carla Mendes', 'email': null, 'active': true},
            {'id': '', 'name': 'Sem Id'},
            'lixo',
          ]));

      final result = await repository.fetchTeam();

      expect(result.dataOrNull, const [
        SessionConsultant(id: 'c-2', name: 'Rafael Lima', email: 'rafael@sim.com'),
        SessionConsultant(id: 'c-1', name: 'Carla Mendes'),
      ]);
    });

    test('resposta sem corpo vira falha, não "equipe vazia"', () async {
      when(() => api.get<List<dynamic>>(
            '/consultants',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => team(null));

      final result = await repository.fetchTeam();

      expect(
        result,
        isA<Failure<List<SessionConsultant>>>().having(
          (f) => f.message,
          'message',
          'Não foi possível carregar a equipe.',
        ),
      );
    });

    test('sem rede, a mensagem de falta de conexão', () async {
      when(() => api.get<List<dynamic>>(
            '/consultants',
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(const ApiException(
        message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        isNetworkError: true,
      ));

      final result = await repository.fetchTeam();

      expect(
        result,
        isA<Failure<List<SessionConsultant>>>().having(
          (f) => f.message,
          'message',
          'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        ),
      );
    });

    test('erro do servidor vira a mensagem genérica', () async {
      when(() => api.get<List<dynamic>>(
            '/consultants',
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(const ApiException(message: 'Internal server error', statusCode: 500));

      final result = await repository.fetchTeam();

      expect(
        result,
        isA<Failure<List<SessionConsultant>>>().having(
          (f) => f.message,
          'message',
          'Não foi possível carregar a equipe.',
        ),
      );
    });
  });

  group('add', () {
    test('manda um consultor só e grava no cache a lista que o backend devolve',
        () async {
      await seedSession('sess-1');
      await seedConsultant('sess-1', 'c-1', 'Carla Mendes');
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenAnswer((_) async => changed([
                link('c-1', 'Carla Mendes', email: 'carla@sim.com'),
                link('c-2', 'Rafael Lima'),
              ]));

      final result = await repository.add('sess-1', 'c-2');

      expect(result.isSuccess, isTrue);
      final sent = verify(
        () => api.post<Map<String, dynamic>>(addPath, data: captureAny(named: 'data')),
      ).captured.single;
      expect(sent, {'consultantId': 'c-2'});
      expect(await repository.watchBySession('sess-1').first, const [
        SessionConsultant(id: 'c-1', name: 'Carla Mendes', email: 'carla@sim.com'),
        SessionConsultant(id: 'c-2', name: 'Rafael Lima'),
      ]);
    });

    test('resposta fora do formato: o backend aceitou, e o cache fica como está',
        () async {
      await seedSession('sess-1');
      await seedConsultant('sess-1', 'c-1', 'Carla Mendes');
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: addPath),
                statusCode: 201,
                data: {'ok': true},
              ));

      final result = await repository.add('sess-1', 'c-2');

      expect(result.isSuccess, isTrue);
      expect(await cachedIds('sess-1'), {'c-1'});
    });

    test('sessão fora do cache: o backend aceitou, e isso basta', () async {
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenAnswer((_) async => changed([link('c-2', 'Rafael Lima')]));

      final result = await repository.add('sess-1', 'c-2');

      expect(result.isSuccess, isTrue);
      expect(await cachedIds('sess-1'), isEmpty);
    });

    for (final refusal in const [
      (400, 'Consultor inativo não pode entrar em um treinamento'),
      (403, 'Não é possível editar um treinamento concluído ou cancelado'),
      (404, 'Consultor não encontrado'),
    ]) {
      test('${refusal.$1} devolve o motivo do backend e não mexe no cache',
          () async {
        await seedSession('sess-1');
        await seedConsultant('sess-1', 'c-1', 'Carla Mendes');
        when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
            .thenThrow(ApiException(message: refusal.$2, statusCode: refusal.$1));

        final result = await repository.add('sess-1', 'c-2');

        expect(
          result,
          isA<Failure<void>>()
              .having((f) => f.message, 'message', refusal.$2)
              .having(
                (f) => f.exception,
                'exception',
                isA<ApiException>().having((e) => e.statusCode, 'statusCode', refusal.$1),
              ),
        );
        expect(await cachedIds('sess-1'), {'c-1'});
      });
    }

    test('sem rede, a mensagem de falta de conexão', () async {
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        isNetworkError: true,
      ));

      final result = await repository.add('sess-1', 'c-2');

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.message,
          'message',
          'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        ),
      );
    });

    test('erro inesperado do servidor vira uma mensagem genérica', () async {
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenThrow(const ApiException(message: 'Internal server error', statusCode: 500));

      final result = await repository.add('sess-1', 'c-2');

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.message,
          'message',
          'Não foi possível adicionar o consultor. Tente de novo.',
        ),
      );
    });

    test('exceção que não é da API também vira a mensagem genérica', () async {
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenThrow(StateError('quebrou'));

      final result = await repository.add('sess-1', 'c-2');

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.message,
          'message',
          'Não foi possível adicionar o consultor. Tente de novo.',
        ),
      );
    });
  });

  group('remove', () {
    test('chama a rota do consultor e grava no cache a lista que sobrou',
        () async {
      await seedSession('sess-1');
      await seedConsultant('sess-1', 'c-1', 'Carla Mendes');
      await seedConsultant('sess-1', 'c-2', 'Rafael Lima');
      when(() => api.delete<Map<String, dynamic>>(removePath))
          .thenAnswer((_) async => changed([link('c-1', 'Carla Mendes')]));

      final result = await repository.remove('sess-1', 'c-2');

      expect(result.isSuccess, isTrue);
      verify(() => api.delete<Map<String, dynamic>>(removePath)).called(1);
      expect(await cachedIds('sess-1'), {'c-1'});
    });

    test('400 (o responsável não sai) devolve o motivo e não mexe no cache',
        () async {
      const reason =
          'O consultor responsável não pode ser removido do treinamento. Troque o responsável antes.';
      await seedSession('sess-1');
      await seedConsultant('sess-1', 'c-2', 'Rafael Lima');
      when(() => api.delete<Map<String, dynamic>>(removePath))
          .thenThrow(const ApiException(message: reason, statusCode: 400));

      final result = await repository.remove('sess-1', 'c-2');

      expect(
        result,
        isA<Failure<void>>().having((f) => f.message, 'message', reason),
      );
      expect(await cachedIds('sess-1'), {'c-2'});
    });

    test('erro inesperado do servidor vira uma mensagem genérica', () async {
      when(() => api.delete<Map<String, dynamic>>(removePath))
          .thenThrow(const ApiException(message: 'Internal server error', statusCode: 502));

      final result = await repository.remove('sess-1', 'c-2');

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.message,
          'message',
          'Não foi possível remover o consultor. Tente de novo.',
        ),
      );
    });
  });
}
