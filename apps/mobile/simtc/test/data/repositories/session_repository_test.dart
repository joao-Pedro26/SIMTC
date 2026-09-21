import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late SessionRepository repository;

  Map<String, dynamic> sessionJson(String id) {
    return {
      'id': id,
      'city': 'Lençóis Paulista',
      'state': 'SP',
      'date': '2026-09-20T12:00:00.000Z',
      'status': 'PLANEJADO',
      'notes': null,
      'company': {'id': 'emp-1', 'name': 'Bracell Celulose'},
      'course': {'id': 'cur-1', 'name': 'Direção Preventiva'},
      'participantStats': {'total': 4, 'assessable': 4, 'assessed': 1},
    };
  }

  Response<Map<String, dynamic>> page(
    List<Map<String, dynamic>> data, {
    required int pageNumber,
    required int totalPages,
  }) {
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/training-sessions'),
      statusCode: 200,
      data: {
        'data': data,
        'total': data.length,
        'page': pageNumber,
        'limit': 50,
        'totalPages': totalPages,
      },
    );
  }

  setUp(() {
    api = _MockApiClient();
    db = AppDatabase(NativeDatabase.memory());
    repository = SessionRepository(apiClient: api, database: db);
  });

  tearDown(() => db.close());

  test('percorre todas as páginas e grava tudo no cache', () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: {'page': 1, 'limit': 50}))
        .thenAnswer((_) async => page([sessionJson('s1')], pageNumber: 1, totalPages: 2));
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: {'page': 2, 'limit': 50}))
        .thenAnswer((_) async => page([sessionJson('s2')], pageNumber: 2, totalPages: 2));

    final result = await repository.syncAll();

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull, 2);
    final ids = (await db.select(db.sessions).get()).map((r) => r.id).toList();
    expect(ids, containsAll(['s1', 's2']));
  });

  test('apaga do cache a sessão que sumiu do servidor', () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('s1')], pageNumber: 1, totalPages: 1));
    await repository.syncAll();

    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('s2')], pageNumber: 1, totalPages: 1));
    await repository.syncAll();

    final ids = (await db.select(db.sessions).get()).map((r) => r.id).toList();
    expect(ids, ['s2']);
  });

  test('falha de rede preserva o que já estava no cache', () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('s1')], pageNumber: 1, totalPages: 1));
    await repository.syncAll();

    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenThrow(const ApiException(message: 'sem rede', isNetworkError: true));

    final result = await repository.syncAll();

    expect(result.isFailure, isTrue);
    expect(await db.select(db.sessions).get(), hasLength(1));
  });

  test(
      'uma exceção fora do ApiException também vira Failure, sem subir crua '
      'e travar o pull-to-refresh', () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('s1')], pageNumber: 1, totalPages: 1));
    await repository.syncAll();

    // Simula um `TypeError` do `fromJson` (campo com tipo inesperado) ou uma
    // falha de escrita do drift — nenhum dos dois é um `ApiException`.
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenThrow(StateError('bug inesperado no parsing'));

    final result = await repository.syncAll();

    expect(result.isFailure, isTrue);
    expect(await db.select(db.sessions).get(), hasLength(1),
        reason: 'o cache velho continua válido quando o sync quebra');
  });

  test('watchSessions ordena pela data mais próxima e deixa sem data por último',
      () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
        queryParameters: any(named: 'queryParameters'))).thenAnswer(
      (_) async => page([
        {...sessionJson('tarde'), 'date': '2026-09-25T12:00:00.000Z'},
        {...sessionJson('sem-data'), 'date': null},
        {...sessionJson('cedo'), 'date': '2026-09-21T12:00:00.000Z'},
      ], pageNumber: 1, totalPages: 1),
    );
    await repository.syncAll();

    final sessions = await repository.watchSessions().first;

    expect(sessions.map((s) => s.id).toList(), ['cedo', 'tarde', 'sem-data']);
  });

  test(
      'poda apaga os participantes antes da sessão que sumiu do servidor '
      '(FK ativa)', () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('s1')], pageNumber: 1, totalPages: 1));
    await repository.syncAll();

    // A sessão 's1' precisa ter um participante cacheado: é isso que dá à FK
    // algo para violar se a ordem de deleção em `_write` for invertida.
    await db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-1',
            sessionId: 's1',
            name: 'João Pedro',
            cpf: '12345678909',
            participationType: 'TEORICA_E_PRATICA',
            status: 'PENDENTE',
            cachedAt: DateTime(2026, 9, 17, 8),
          ),
        );

    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('s2')], pageNumber: 1, totalPages: 1));

    final result = await repository.syncAll();

    expect(result.isSuccess, isTrue);
    final sessionIds = (await db.select(db.sessions).get()).map((r) => r.id).toList();
    expect(sessionIds, ['s2']);
    expect(await db.select(db.participants).get(), isEmpty);
  });

  test(
      'resposta 200 fora do formato esperado vira Failure, sem apagar o '
      'cache', () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('s1')], pageNumber: 1, totalPages: 1));
    await repository.syncAll();

    // Corpo 200 sem a chave 'data' como lista: envelope renomeado numa
    // mudança futura do backend, resposta de proxy, etc. Antes da correção
    // isto virava `data: []` -> `reachedEnd = true` -> poda com lista de ids
    // vazia, e `id NOT IN ()` no SQLite apaga a tabela inteira.
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: '/training-sessions'),
              statusCode: 200,
              data: const <String, dynamic>{},
            ));

    final result = await repository.syncAll();

    expect(result.isFailure, isTrue);
    expect(await db.select(db.sessions).get(), hasLength(1),
        reason: 'uma resposta que não foi entendida não pode apagar o cache');
  });

  test(
      'teto de páginas suspende a poda: sessão que não veio nas páginas '
      'baixadas sobrevive', () async {
    // Semeia o cache diretamente (sem sync), para não depender da contagem
    // de chamadas de uma primeira sincronização.
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'antiga',
            companyName: 'Bracell Celulose',
            courseName: 'Direção Preventiva',
            city: 'Lençóis Paulista',
            state: 'SP',
            status: 'PLANEJADO',
            cachedAt: DateTime(2026, 9, 17, 8),
          ),
        );

    // totalPages bem maior que o teto (_maxPages = 10): o laço nunca vê
    // `page >= totalPages`, então `reachedEnd` fica falso e a poda é pulada.
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('nova')], pageNumber: 1, totalPages: 999));

    final result = await repository.syncAll();

    expect(result.isSuccess, isTrue);
    // Prova que o laço realmente parou no teto, e não por outro motivo.
    verify(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .called(10);
    final ids = (await db.select(db.sessions).get()).map((r) => r.id).toList();
    expect(ids, containsAll(['antiga', 'nova']));
  });
}
