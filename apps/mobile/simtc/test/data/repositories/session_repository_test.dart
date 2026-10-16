import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/utils/result.dart';

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
    final from = DateTime.now().subtract(const Duration(days: 90));
    String dois(int value) => value.toString().padLeft(2, '0');
    final fromParam = '${from.year}-${dois(from.month)}-${dois(from.day)}';

    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: {'page': 1, 'limit': 50, 'from': fromParam}))
        .thenAnswer((_) async => page([sessionJson('s1')], pageNumber: 1, totalPages: 2));
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: {'page': 2, 'limit': 50, 'from': fromParam}))
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

  test('a sessão que sumiu do servidor leva os consultores dela do cache',
      () async {
    // Os consultores têm chave estrangeira para a sessão (Fase 6B): se não
    // saíssem junto, apagar a sessão derrubaria a transação inteira do sync.
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page(
              [sessionJson('s1'), sessionJson('s2')],
              pageNumber: 1,
              totalPages: 1,
            ));
    await repository.syncAll();
    for (final sessionId in ['s1', 's2']) {
      await db.into(db.sessionConsultants).insert(
            SessionConsultantsCompanion.insert(
              sessionId: sessionId,
              consultantId: 'c-1',
              name: 'Carla Mendes',
            ),
          );
    }

    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('s2')], pageNumber: 1, totalPages: 1));
    final result = await repository.syncAll();

    expect(result.isSuccess, isTrue);
    final rows = await db.select(db.sessionConsultants).get();
    expect(rows.map((r) => r.sessionId), ['s2']);
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

  test('pede só a janela de 90 dias, contando a partir de hoje', () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([], pageNumber: 1, totalPages: 1));

    await repository.syncAll();

    final captured = verify(() => api.get<Map<String, dynamic>>(
          '/training-sessions',
          queryParameters: captureAny(named: 'queryParameters'),
        )).captured.single as Map<String, dynamic>;

    final esperado = DateTime.now().subtract(const Duration(days: 90));
    String dois(int v) => v.toString().padLeft(2, '0');
    expect(
      captured['from'],
      '${esperado.year}-${dois(esperado.month)}-${dois(esperado.day)}',
    );
  });

  test(
      'sync da lista grava o responsável e não apaga o logo que o detalhe '
      'gravou', () async {
    // O detalhe da sessão (Fase 3) já gravou o logo e a data de sync dos
    // participantes; a listagem não traz nenhum dos dois.
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 's1',
            companyName: 'Bracell Celulose',
            companyLogoUrl: const Value('https://cdn.simtc/logos/bracell.png'),
            courseName: 'Direção Preventiva',
            city: 'Lençóis Paulista',
            state: 'SP',
            status: 'PLANEJADO',
            participantsSyncedAt: Value(DateTime(2026, 9, 22, 8)),
            cachedAt: DateTime(2026, 9, 22, 8),
          ),
        );

    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([
              {...sessionJson('s1'), 'responsibleConsultantId': 'c-resp'},
            ], pageNumber: 1, totalPages: 1));

    final result = await repository.syncAll();

    expect(result.isSuccess, isTrue);
    final row = await db.select(db.sessions).getSingle();
    expect(row.responsibleConsultantId, 'c-resp');
    expect(row.companyLogoUrl, 'https://cdn.simtc/logos/bracell.png');
    expect(row.participantsSyncedAt, DateTime(2026, 9, 22, 8));
  });

  test('sync da lista grava o logo da empresa que a listagem traz', () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([
              {
                ...sessionJson('s1'),
                'company': {
                  'id': 'emp-1',
                  'name': 'Bracell Celulose',
                  'logoUrl': 'https://cdn.simtc/logos/bracell.png',
                },
              },
            ], pageNumber: 1, totalPages: 1));

    await repository.syncAll();

    final row = await db.select(db.sessions).getSingle();
    expect(row.companyLogoUrl, 'https://cdn.simtc/logos/bracell.png');
  });

  test('watchSession emite a sessão pedida, e nulo se ela não está no cache',
      () async {
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 's1',
            companyName: 'Bracell Celulose',
            courseName: 'Direção Preventiva',
            city: 'Lençóis Paulista',
            state: 'SP',
            status: 'EM_ANDAMENTO',
            responsibleConsultantId: const Value('c-resp'),
            cachedAt: DateTime(2026, 9, 22, 8),
          ),
        );

    final session = await repository.watchSession('s1').first;
    final missing = await repository.watchSession('nao-existe').first;

    expect(session?.companyName, 'Bracell Celulose');
    expect(session?.responsibleConsultantId, 'c-resp');
    expect(missing, isNull);
  });

  group('start', () {
    Future<void> seedPlanned() {
      return db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: 's1',
              companyName: 'Bracell Celulose',
              courseName: 'Direção Preventiva',
              city: 'Lençóis Paulista',
              state: 'SP',
              status: 'PLANEJADO',
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );
    }

    test('chama o /start e já marca a sessão local como em andamento',
        () async {
      await seedPlanned();
      when(() => api.post<Map<String, dynamic>>('/training-sessions/s1/start'))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions:
                    RequestOptions(path: '/training-sessions/s1/start'),
                statusCode: 201,
                data: {'id': 's1', 'status': 'EM_ANDAMENTO'},
              ));

      final result = await repository.start('s1');

      expect(result.isSuccess, isTrue);
      final row = await db.select(db.sessions).getSingle();
      expect(row.status, 'EM_ANDAMENTO');
    });

    test('403 devolve a mensagem do backend e não mexe no status local',
        () async {
      await seedPlanned();
      when(() => api.post<Map<String, dynamic>>('/training-sessions/s1/start'))
          .thenThrow(const ApiException(
        message:
            'Somente o consultor responsável por este treinamento pode iniciá-lo ou concluí-lo',
        statusCode: 403,
      ));

      final result = await repository.start('s1');

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.message,
          'message',
          'Somente o consultor responsável por este treinamento pode iniciá-lo ou concluí-lo',
        ),
      );
      final row = await db.select(db.sessions).getSingle();
      expect(row.status, 'PLANEJADO');
    });
  });

  group('edição pelo ADMIN', () {
    const path = '/training-sessions/s1';

    Future<void> seedSession() {
      return db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: 's1',
              companyName: 'Bracell Celulose',
              courseName: 'Direção Preventiva',
              city: 'Itabira',
              state: 'MG',
              date: Value(DateTime(2026, 9, 12)),
              status: 'EM_ANDAMENTO',
              notes: const Value('Pátio 3 — portaria B.'),
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );
    }

    Response<Map<String, dynamic>> ok(String requestPath) {
      return Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: requestPath),
        statusCode: 200,
        data: {'id': 's1'},
      );
    }

    void patchAnswers() {
      when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
          .thenAnswer((_) async => ok(path));
    }

    Object? sentBody() {
      return verify(
        () => api.patch<Map<String, dynamic>>(path, data: captureAny(named: 'data')),
      ).captured.single;
    }

    group('update', () {
      test(
          'manda só o que mudou, com a data como AAAA-MM-DD, e já grava no '
          'cache', () async {
        await seedSession();
        patchAnswers();

        final result = await repository.update(
          's1',
          date: DateTime(2026, 10, 3),
          notes: '',
        );

        expect(result.isSuccess, isTrue);
        expect(sentBody(), {'date': '2026-10-03', 'notes': ''});
        final row = await db.select(db.sessions).getSingle();
        expect(row.date, DateTime(2026, 10, 3));
        expect(row.notes, '');
        expect(row.city, 'Itabira', reason: 'o que não mudou fica como estava');
        expect(row.state, 'MG');
      });

      test('cidade e UF vão separadas, como o backend guarda', () async {
        await seedSession();
        patchAnswers();

        final result = await repository.update('s1', city: 'Betim', state: 'SP');

        expect(result.isSuccess, isTrue);
        expect(sentBody(), {'city': 'Betim', 'state': 'SP'});
        final row = await db.select(db.sessions).getSingle();
        expect(row.city, 'Betim');
        expect(row.state, 'SP');
        expect(row.date, DateTime(2026, 9, 12));
        expect(row.notes, 'Pátio 3 — portaria B.');
      });

      test('dia e mês de um dígito ganham o zero à esquerda', () async {
        await seedSession();
        patchAnswers();

        await repository.update('s1', date: DateTime(2027, 1, 5));

        expect(sentBody(), {'date': '2027-01-05'});
      });

      test('sem mudança nenhuma, não chama o servidor', () async {
        await seedSession();

        final result = await repository.update('s1');

        expect(result.isSuccess, isTrue);
        verifyNever(
          () => api.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
        );
      });

      test('403 devolve a mensagem do backend e não mexe no cache', () async {
        await seedSession();
        when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
            .thenThrow(const ApiException(
          message: 'Não é possível editar um treinamento concluído ou cancelado',
          statusCode: 403,
        ));

        final result = await repository.update('s1', city: 'Betim');

        expect(
          result,
          isA<Failure<void>>().having(
            (f) => f.message,
            'message',
            'Não é possível editar um treinamento concluído ou cancelado',
          ),
        );
        final row = await db.select(db.sessions).getSingle();
        expect(row.city, 'Itabira');
      });

      test('sem rede, a mensagem de falta de conexão', () async {
        await seedSession();
        when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
            .thenThrow(const ApiException(
          message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
          isNetworkError: true,
        ));

        final result = await repository.update('s1', city: 'Betim');

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
        await seedSession();
        when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
            .thenThrow(const ApiException(
          message: 'city must be a string',
          statusCode: 400,
        ));

        final result = await repository.update('s1', city: 'Betim');

        expect(
          result,
          isA<Failure<void>>().having(
            (f) => f.message,
            'message',
            'Não foi possível salvar as alterações. Tente de novo.',
          ),
        );
      });
    });

    group('cancel', () {
      const cancelPath = '/training-sessions/s1/cancel';

      test('chama o /cancel e já marca a sessão local como cancelada',
          () async {
        await seedSession();
        when(() => api.patch<Map<String, dynamic>>(cancelPath))
            .thenAnswer((_) async => ok(cancelPath));

        final result = await repository.cancel('s1');

        expect(result.isSuccess, isTrue);
        final row = await db.select(db.sessions).getSingle();
        expect(row.status, 'CANCELADO');
      });

      test('403 devolve a mensagem do backend e não mexe no status local',
          () async {
        await seedSession();
        when(() => api.patch<Map<String, dynamic>>(cancelPath))
            .thenThrow(const ApiException(
          message: 'Não é possível cancelar um treinamento já concluído',
          statusCode: 403,
        ));

        final result = await repository.cancel('s1');

        expect(
          result,
          isA<Failure<void>>().having(
            (f) => f.message,
            'message',
            'Não é possível cancelar um treinamento já concluído',
          ),
        );
        final row = await db.select(db.sessions).getSingle();
        expect(row.status, 'EM_ANDAMENTO');
      });

      test('erro inesperado do servidor vira uma mensagem genérica', () async {
        await seedSession();
        when(() => api.patch<Map<String, dynamic>>(cancelPath)).thenThrow(
          const ApiException(message: 'Internal server error', statusCode: 500),
        );

        final result = await repository.cancel('s1');

        expect(
          result,
          isA<Failure<void>>().having(
            (f) => f.message,
            'message',
            'Não foi possível cancelar a sessão. Tente de novo.',
          ),
        );
        final row = await db.select(db.sessions).getSingle();
        expect(row.status, 'EM_ANDAMENTO');
      });
    });
  });
}
