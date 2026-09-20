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
}
