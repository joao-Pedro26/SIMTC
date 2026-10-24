import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/cpf_lookup.dart';
import 'package:simtc/data/models/remote_assessment.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/utils/result.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late ParticipantRepository repository;

  const detailPath = '/training-sessions/sess-1';

  Map<String, dynamic> participantJson(
    String id, {
    String name = 'Ana Paula Ribeiro',
    String status = 'PENDENTE',
    String participationType = 'TEORICA_E_PRATICA',
    Map<String, dynamic>? assessment,
  }) {
    return {
      'id': id,
      'participationType': participationType,
      'status': status,
      'assignedConsultantId': null,
      'participant': {'id': 'p-$id', 'name': name, 'cpf': '04211899001'},
      'assessment': assessment,
      'certificate': null,
      'assignedConsultant': null,
    };
  }

  /// Um vínculo de `consultants[]` do detalhe (`include: { consultant: true }`).
  Map<String, dynamic> consultantLink(String id, String name, {String? email}) {
    return {
      'trainingSessionId': 'sess-1',
      'consultantId': id,
      'consultant': {'id': id, 'name': name, 'email': email, 'active': true},
    };
  }

  /// O detalhe como `findTrainingSessionById` devolve (`company: true`, por
  /// isso o logo vem junto). Sem [consultants], o corpo nem traz a chave.
  Map<String, dynamic> detailJson(
    List<Map<String, dynamic>> participants, {
    List<Map<String, dynamic>>? consultants,
  }) {
    return {
      if (consultants != null) 'consultants': consultants,
      'id': 'sess-1',
      'responsibleConsultantId': 'c-resp',
      'city': 'Itabira',
      'state': 'MG',
      'date': '2026-09-23T00:00:00.000Z',
      'status': 'EM_ANDAMENTO',
      'notes': 'Pátio 3 — portaria B às 07h30.',
      'company': {
        'id': 'emp-1',
        'name': 'Bracell',
        'logoUrl': 'https://cdn.simtc/logos/bracell.png',
      },
      'course': {'id': 'cur-1', 'name': 'Direção Defensiva'},
      'participants': participants,
    };
  }

  Response<Map<String, dynamic>> ok(Map<String, dynamic> body) {
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: detailPath),
      statusCode: 200,
      data: body,
    );
  }

  Future<void> seedSession({DateTime? cachedAt}) {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva',
            city: 'Itabira',
            state: 'MG',
            status: 'PLANEJADO',
            cachedAt: cachedAt ?? DateTime(2026, 9, 22, 8),
          ),
        );
  }

  setUp(() {
    api = _MockApiClient();
    db = AppDatabase(NativeDatabase.memory());
    repository = ParticipantRepository(apiClient: api, database: db);
  });

  tearDown(() => db.close());

  group('syncSession', () {
    test(
        'o participantsSyncedAt é a hora em que o GET foi pedido, não a da '
        'escrita', () async {
      await seedSession();
      final reads = [
        DateTime(2026, 9, 30, 8, 12, 10),
        DateTime(2026, 9, 30, 8, 12, 50),
      ];
      var next = 0;
      repository = ParticipantRepository(
        apiClient: api,
        database: db,
        now: () => reads[next < reads.length - 1 ? next++ : next],
      );
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([participantJson('tp-1')])),
      );

      await repository.syncSession('sess-1');

      final session = await db.select(db.sessions).getSingle();
      expect(session.participantsSyncedAt, DateTime(2026, 9, 30, 8, 12, 10));
    });

    test('grava os participantes com o CPF mascarado e a avaliação', () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([
          participantJson('tp-1'),
          participantJson(
            'tp-2',
            name: 'Juliana Freitas Costa',
            status: 'APROVADO',
            assessment: {
              'consultantId': 'c-1',
              'startTime': '2026-09-23T10:58:00.000Z',
              'endTime': '2026-09-23T11:12:00.000Z',
              'score': 86.4,
            },
          ),
        ])),
      );

      final result = await repository.syncSession('sess-1');

      expect(result.dataOrNull, 2);
      final rows = await db.select(db.participants).get();
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.cpf == '042.118.***-**'), isTrue,
          reason: 'o aparelho nunca guarda o CPF inteiro');
      expect(rows.every((r) => r.email == null), isTrue);
      final juliana = rows.singleWhere((r) => r.id == 'tp-2');
      expect(juliana.score, 86.4);
      expect(juliana.assessedByConsultantId, 'c-1');
      // O drift devolve hora local; o que importa é ser o mesmo instante.
      expect(juliana.assessedAt!.toUtc(), DateTime.parse('2026-09-23T11:12:00.000Z'));
    });

    test(
        'atualiza a sessão com o detalhe, recalcula as contagens e marca o '
        'sync dos participantes, sem mexer no cachedAt da agenda', () async {
      await seedSession(cachedAt: DateTime(2026, 9, 22, 8));
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([
          participantJson('tp-1'),
          participantJson('tp-2', status: 'APROVADO'),
          participantJson('tp-3', status: 'NAO_RECOMENDADO'),
          participantJson('tp-4', participationType: 'SOMENTE_TEORICA'),
        ])),
      );

      await repository.syncSession('sess-1');

      final session = await db.select(db.sessions).getSingle();
      expect(session.status, 'EM_ANDAMENTO');
      expect(session.companyLogoUrl, 'https://cdn.simtc/logos/bracell.png');
      expect(session.notes, 'Pátio 3 — portaria B às 07h30.');
      expect(session.responsibleConsultantId, 'c-resp');
      expect(session.totalParticipants, 4);
      expect(session.assessableParticipants, 3);
      expect(session.assessedParticipants, 2);
      expect(session.participantsSyncedAt, isNotNull);
      expect(session.cachedAt, DateTime(2026, 9, 22, 8),
          reason: 'a idade da agenda da Home não muda por abrir uma sessão');
    });

    test('grava os consultores da sessão que vêm no detalhe', () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson(
          [participantJson('tp-1')],
          consultants: [
            consultantLink('c-resp', 'Carla Mendes', email: 'carla@sim.com'),
            consultantLink('c-2', 'Rafael Lima'),
          ],
        )),
      );

      await repository.syncSession('sess-1');

      final rows = await (db.select(db.sessionConsultants)
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();
      expect(rows.map((r) => r.sessionId), everyElement('sess-1'));
      expect(rows.map((r) => (r.consultantId, r.name, r.email)), [
        ('c-resp', 'Carla Mendes', 'carla@sim.com'),
        ('c-2', 'Rafael Lima', null),
      ]);
    });

    test('o consultor que saiu da sessão no servidor sai do cache', () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson(
          const [],
          consultants: [
            consultantLink('c-resp', 'Carla Mendes'),
            consultantLink('c-2', 'Rafael Lima'),
          ],
        )),
      );
      await repository.syncSession('sess-1');

      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson(
          const [],
          consultants: [
            consultantLink('c-resp', 'Carla Mendes'),
            consultantLink('c-3', 'Tatiane Souza'),
          ],
        )),
      );
      await repository.syncSession('sess-1');

      final rows = await db.select(db.sessionConsultants).get();
      expect(rows.map((r) => r.consultantId).toSet(), {'c-resp', 'c-3'});
    });

    test('detalhe sem a lista de consultores não apaga os que estão no cache',
        () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson(
          const [],
          consultants: [consultantLink('c-resp', 'Carla Mendes')],
        )),
      );
      await repository.syncSession('sess-1');

      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([participantJson('tp-1')])),
      );
      final result = await repository.syncSession('sess-1');

      expect(result.dataOrNull, 1);
      final rows = await db.select(db.sessionConsultants).get();
      expect(rows.map((r) => r.consultantId), ['c-resp']);
    });

    test('quem saiu da sessão no servidor sai do cache', () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([participantJson('tp-1'), participantJson('tp-2')])),
      );
      await repository.syncSession('sess-1');

      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([participantJson('tp-2')])),
      );
      await repository.syncSession('sess-1');

      final ids = (await db.select(db.participants).get()).map((r) => r.id);
      expect(ids, ['tp-2']);
    });

    test('resposta fora do formato vira Failure sem apagar o cache', () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([participantJson('tp-1')])),
      );
      await repository.syncSession('sess-1');

      when(() => api.get<Map<String, dynamic>>(detailPath))
          .thenAnswer((_) async => ok(const <String, dynamic>{}));

      final result = await repository.syncSession('sess-1');

      expect(result.isFailure, isTrue);
      expect(await db.select(db.participants).get(), hasLength(1));
    });

    test('403 devolve a mensagem do backend e preserva o cache', () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([participantJson('tp-1')])),
      );
      await repository.syncSession('sess-1');

      when(() => api.get<Map<String, dynamic>>(detailPath)).thenThrow(
        const ApiException(
          message: 'Você não tem acesso a este treinamento',
          statusCode: 403,
        ),
      );

      final result = await repository.syncSession('sess-1');

      expect(
        result,
        isA<Failure<int>>().having(
            (f) => f.message, 'message', 'Você não tem acesso a este treinamento'),
      );
      expect(await db.select(db.participants).get(), hasLength(1));
    });

    test('sem rede, a mensagem diz que o cache continua na tela', () async {
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenThrow(
        const ApiException(message: 'sem rede', isNetworkError: true),
      );

      final result = await repository.syncSession('sess-1');

      expect(
        result,
        isA<Failure<int>>().having((f) => f.message, 'message',
            'Não foi possível atualizar. Mostrando os dados já baixados.'),
      );
    });

    test(
        'o detalhe que chega depois de o cache ser apagado (sair da conta) não '
        'grava', () async {
      await seedSession();
      final response = Completer<Response<Map<String, dynamic>>>();
      when(() => api.get<Map<String, dynamic>>(detailPath))
          .thenAnswer((_) => response.future);

      final sync = repository.syncSession('sess-1');
      await db.clearSessionsCache();
      response.complete(ok(detailJson([participantJson('tp-1')])));

      expect(await sync, isA<Failure<int>>());
      expect(await db.select(db.sessions).get(), isEmpty);
      expect(await db.select(db.participants).get(), isEmpty);
    });
  });

  group('download velho depois de mudança aceita', () {
    late DateTime clock;
    late Completer<Response<Map<String, dynamic>>> oldGet;
    const assignPath = '/practical-assessments/assign';
    const consultantsPath = '/training-sessions/sess-1/consultants/c-2';

    Future<List<String>> cachedConsultantIds() async {
      final rows = await db.select(db.sessionConsultants).get();
      return rows.map((r) => r.consultantId).toList();
    }

    setUp(() async {
      clock = DateTime(2026, 10, 21, 9);
      repository = ParticipantRepository(
        apiClient: api,
        database: db,
        now: () => clock,
      );
      await seedSession();
      oldGet = Completer<Response<Map<String, dynamic>>>();
      // O primeiro GET fica no ar; o segundo traz o estado depois da mudança.
      var calls = 0;
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer((_) {
        calls++;
        if (calls == 1) return oldGet.future;
        return Future.value(ok(detailJson(
          [participantJson('tp-1', status: 'EM_AVALIACAO')],
          consultants: [consultantLink('c-1', 'Carla Souza')],
        )));
      });
    });

    test('um GET pedido antes de um assign aceito não grava por cima dele',
        () async {
      when(() => api.post<Map<String, dynamic>>(assignPath,
          data: any(named: 'data'))).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: assignPath),
          statusCode: 201,
          data: {'assigned': 1},
        ),
      );

      await db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-1',
              sessionId: 'sess-1',
              name: 'Ana Paula Ribeiro',
              cpf: '042.118.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'PENDENTE',
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );

      final older = repository.syncSession('sess-1');
      clock = clock.add(const Duration(seconds: 5));
      await repository.assign('tp-1',
          consultantId: 'c-1', consultantName: 'Carla Souza');
      clock = clock.add(const Duration(seconds: 5));
      await repository.syncSession('sess-1');

      oldGet.complete(ok(detailJson(
        [participantJson('tp-1')],
        consultants: [consultantLink('c-1', 'Carla Souza'), consultantLink('c-2', 'Rafael Lima')],
      )));
      final olderResult = await older;

      expect(olderResult.isSuccess, isTrue);
      final row = await db.select(db.participants).getSingle();
      expect(row.status, 'EM_AVALIACAO');
      expect(await cachedConsultantIds(), ['c-1']);
    });

    test('o mesmo vale para a remoção de consultor aceita', () async {
      final consultants = SessionConsultantRepository(
        apiClient: api,
        database: db,
        onSessionChanged: repository.markSessionChanged,
      );
      when(() => api.delete<Map<String, dynamic>>(consultantsPath)).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: consultantsPath),
          statusCode: 200,
          data: {
            'responsibleConsultantId': 'c-resp',
            'consultants': [consultantLink('c-1', 'Carla Souza')],
          },
        ),
      );

      final older = repository.syncSession('sess-1');
      clock = clock.add(const Duration(seconds: 5));
      await consultants.remove('sess-1', 'c-2');
      clock = clock.add(const Duration(seconds: 5));
      await repository.syncSession('sess-1');

      oldGet.complete(ok(detailJson(
        [participantJson('tp-1')],
        consultants: [consultantLink('c-1', 'Carla Souza'), consultantLink('c-2', 'Rafael Lima')],
      )));
      await older;

      expect(await cachedConsultantIds(), ['c-1']);
    });

    test('um GET pedido depois da mudança grava normalmente', () async {
      repository.markSessionChanged('sess-1');
      clock = clock.add(const Duration(seconds: 5));
      oldGet.complete(ok(detailJson(
        [participantJson('tp-1', status: 'EM_AVALIACAO')],
      )));

      final result = await repository.syncSession('sess-1');

      expect(result.isSuccess, isTrue);
      final row = await db.select(db.participants).getSingle();
      expect(row.status, 'EM_AVALIACAO');
    });
  });

  test('watchBySession traz só os participantes da sessão pedida', () async {
    await seedSession();
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-2',
            companyName: 'Suzano',
            courseName: 'Empilhadeira',
            city: 'Bauru',
            state: 'SP',
            status: 'PLANEJADO',
            cachedAt: DateTime(2026, 9, 22, 8),
          ),
        );
    Future<void> insert(String id, String sessionId, String name) {
      return db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: id,
              sessionId: sessionId,
              name: name,
              cpf: '042.118.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'PENDENTE',
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );
    }

    await insert('tp-b', 'sess-1', 'Bruno');
    await insert('tp-a', 'sess-1', 'Ana');
    await insert('tp-x', 'sess-2', 'Xavier');

    final list = await repository.watchBySession('sess-1').first;

    expect(list.map((p) => p.name), ['Ana', 'Bruno']);
  });

  group('watchParticipant', () {
    test('traz o participante do cache pelo id', () async {
      await seedSession();
      await db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-1',
              sessionId: 'sess-1',
              name: 'Carlos Eduardo Nunes',
              cpf: '187.443.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'PENDENTE',
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );

      final participant = await repository.watchParticipant('tp-1').first;

      expect(participant?.name, 'Carlos Eduardo Nunes');
    });

    test('emite nulo se o participante não estiver no aparelho', () async {
      final participant = await repository.watchParticipant('tp-inexistente').first;

      expect(participant, isNull);
    });
  });

  group('findParticipant', () {
    test('lê uma vez o participante do cache — nulo se não está no aparelho',
        () async {
      await seedSession();
      await db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-1',
              sessionId: 'sess-1',
              name: 'Carlos Eduardo Nunes',
              cpf: '187.443.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'PENDENTE',
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );

      expect((await repository.findParticipant('tp-1'))?.name, 'Carlos Eduardo Nunes');
      expect(await repository.findParticipant('tp-inexistente'), isNull);
    });
  });

  group('assign', () {
    const assignPath = '/practical-assessments/assign';

    Future<void> seedPending() async {
      await seedSession();
      await db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-1',
              sessionId: 'sess-1',
              name: 'Carlos Eduardo Nunes',
              cpf: '187.443.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'PENDENTE',
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );
    }

    test('reserva no backend e já marca a linha local como minha', () async {
      await seedPending();
      when(() => api.post<Map<String, dynamic>>(assignPath,
          data: any(named: 'data'))).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: assignPath),
          statusCode: 201,
          data: {'assigned': 1},
        ),
      );

      final result = await repository.assign(
        'tp-1',
        consultantId: 'c-1',
        consultantName: 'Carla Souza',
      );

      expect(result.isSuccess, isTrue);
      final sent = verify(() => api.post<Map<String, dynamic>>(assignPath,
          data: captureAny(named: 'data'))).captured.single;
      expect(sent, {
        'participantIds': ['tp-1'],
      });
      final row = await db.select(db.participants).getSingle();
      expect(row.status, ParticipantStatus.emAvaliacao.wireValue);
      expect(row.assignedConsultantId, 'c-1');
      expect(row.assignedConsultantName, 'Carla Souza');
    });

    test('409 devolve o motivo do conflito e não mexe na linha local', () async {
      await seedPending();
      when(() => api.post<Map<String, dynamic>>(assignPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(
          message:
              'Um ou mais participantes já estão em avaliação com outro consultor',
          statusCode: 409,
        ),
      );

      final result = await repository.assign(
        'tp-1',
        consultantId: 'c-1',
        consultantName: 'Carla Souza',
      );

      expect(
        result,
        isA<Failure<void>>().having((f) => f.message, 'message',
            'Um ou mais participantes já estão em avaliação com outro consultor'),
      );
      final row = await db.select(db.participants).getSingle();
      expect(row.status, 'PENDENTE');
    });

    test('erro inesperado do servidor vira uma mensagem genérica', () async {
      await seedPending();
      when(() => api.post<Map<String, dynamic>>(assignPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(message: 'Internal server error', statusCode: 500),
      );

      final result = await repository.assign(
        'tp-1',
        consultantId: 'c-1',
        consultantName: 'Carla Souza',
      );

      expect(
        result,
        isA<Failure<void>>().having((f) => f.message, 'message',
            'Não foi possível atribuir o participante. Tente de novo.'),
      );
    });
  });

  group('fetchAssessment', () {
    const path = '/practical-assessments/by-participant/tp-1';

    void answer(Object? body) {
      when(() => api.get<Object?>(path)).thenAnswer(
        (_) async => Response<Object?>(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: body,
        ),
      );
    }

    /// Como o `findByParticipant` do backend devolve: cada item com a nota, a
    /// infração e a categoria aninhadas.
    Map<String, dynamic> assessmentJson() => {
          'id': 'assess-1',
          'trainingParticipantId': 'tp-1',
          'consultantId': 'c-1',
          'date': '2026-09-30T00:00:00.000Z',
          'startTime': '2026-09-30T11:12:00.000Z',
          'endTime': '2026-09-30T11:31:00.000Z',
          'synced': true,
          'score': 86.7,
          'items': [
            {
              'id': 'item-1',
              'assessmentId': 'assess-1',
              'infractionNoteId': 'note-pm-1',
              'infractionNote': {
                'id': 'note-pm-1',
                'infractionId': 'inf-1',
                'noteType': 'PM',
                'comment': 'Ajuste feito somente após solicitação',
                'deduction': 3,
                'infraction': {
                  'id': 'inf-1',
                  'categoryId': 'cat-cv',
                  'description': 'Não ajustou o banco, cinto ou espelhos',
                  'order': 1,
                  'category': {
                    'id': 'cat-cv',
                    'code': 'CV',
                    'name': 'Controle do Veículo',
                    'description': null,
                    'order': 1,
                  },
                },
              },
            },
            // Um item sem a nota aninhada não tem o que mostrar: fica de fora.
            {'id': 'item-2', 'assessmentId': 'assess-1', 'infractionNoteId': 'x'},
          ],
        };

    test('traz a avaliação do backend, com cada item achatado', () async {
      answer(assessmentJson());

      final result = await repository.fetchAssessment('tp-1');

      final assessment = result.dataOrNull!;
      expect(assessment.score, 86.7);
      expect(assessment.startTime, DateTime.utc(2026, 9, 30, 11, 12));
      expect(assessment.endTime, DateTime.utc(2026, 9, 30, 11, 31));
      final item = assessment.items.single;
      expect(item.infractionNoteId, 'note-pm-1');
      expect(item.noteType, 'PM');
      expect(item.comment, 'Ajuste feito somente após solicitação');
      expect(item.deduction, 3);
      expect(item.infractionId, 'inf-1');
      expect(item.infractionDescription, 'Não ajustou o banco, cinto ou espelhos');
      expect(item.infractionOrder, 1);
      expect(item.categoryId, 'cat-cv');
      expect(item.categoryCode, 'CV');
      expect(item.categoryName, 'Controle do Veículo');
      expect(item.categoryOrder, 1);
    });

    test('sem avaliação no backend (200 sem corpo), sucesso vazio', () async {
      answer(null);

      final result = await repository.fetchAssessment('tp-1');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
    });

    test('resposta fora do formato vira falha, com a mensagem genérica', () async {
      answer({'id': 'assess-1'});

      final result = await repository.fetchAssessment('tp-1');

      expect(
        result,
        isA<Failure<RemoteAssessment?>>().having(
            (f) => f.message, 'message', 'Não foi possível carregar o resultado.'),
      );
    });

    test('sem rede, a mensagem de falta de conexão', () async {
      when(() => api.get<Object?>(path)).thenThrow(
        const ApiException(message: 'Sem conexão', isNetworkError: true),
      );

      final result = await repository.fetchAssessment('tp-1');

      expect(
        result,
        isA<Failure<RemoteAssessment?>>()
            .having((f) => f.message, 'message', 'Sem conexão')
            .having((f) => f.exception, 'exception', isA<ApiException>()),
      );
    });
  });

  group('unassign', () {
    const unassignPath = '/practical-assessments/unassign';

    Future<void> seedMine({double? score}) async {
      await seedSession();
      await db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-1',
              sessionId: 'sess-1',
              name: 'Carlos Eduardo Nunes',
              cpf: '187.443.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'EM_AVALIACAO',
              assignedConsultantId: const Value('c-1'),
              assignedConsultantName: const Value('Carla Souza'),
              score: Value(score),
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );
    }

    void answerOk() {
      when(() => api.post<Map<String, dynamic>>(unassignPath,
          data: any(named: 'data'))).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: unassignPath),
          statusCode: 201,
          data: {'unassigned': 1},
        ),
      );
    }

    test('libera no backend e já devolve a linha local a "Pendente"', () async {
      await seedMine();
      answerOk();

      final result = await repository.unassign('tp-1');

      expect(result.isSuccess, isTrue);
      final sent = verify(() => api.post<Map<String, dynamic>>(unassignPath,
          data: captureAny(named: 'data'))).captured.single;
      expect(sent, {
        'participantIds': ['tp-1'],
      });
      final row = await db.select(db.participants).getSingle();
      expect(row.status, ParticipantStatus.pendente.wireValue);
      expect(row.assignedConsultantId, isNull);
      expect(row.assignedConsultantName, isNull);
    });

    test('numa reavaliação, a linha volta ao status da nota anterior', () async {
      await seedMine(score: 62.5);
      answerOk();

      await repository.unassign('tp-1');

      final row = await db.select(db.participants).getSingle();
      expect(row.status, ParticipantStatus.necessitaReavaliacao.wireValue);
      expect(row.score, 62.5);
    });

    test('409 devolve o motivo e não mexe na linha local', () async {
      await seedMine();
      when(() => api.post<Map<String, dynamic>>(unassignPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(
          message: 'Um ou mais participantes não estão atribuídos a você',
          statusCode: 409,
        ),
      );

      final result = await repository.unassign('tp-1');

      expect(
        result,
        isA<Failure<void>>().having((f) => f.message, 'message',
            'Um ou mais participantes não estão atribuídos a você'),
      );
      final row = await db.select(db.participants).getSingle();
      expect(row.status, 'EM_AVALIACAO');
      expect(row.assignedConsultantId, 'c-1');
    });

    test('sem rede, a mensagem de falta de conexão', () async {
      await seedMine();
      when(() => api.post<Map<String, dynamic>>(unassignPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(message: 'Sem conexão', isNetworkError: true),
      );

      final result = await repository.unassign('tp-1');

      expect(
        result,
        isA<Failure<void>>().having((f) => f.message, 'message', 'Sem conexão'),
      );
    });

    test('erro inesperado do servidor vira uma mensagem genérica', () async {
      await seedMine();
      when(() => api.post<Map<String, dynamic>>(unassignPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(message: 'Internal server error', statusCode: 500),
      );

      final result = await repository.unassign('tp-1');

      expect(
        result,
        isA<Failure<void>>().having((f) => f.message, 'message',
            'Não foi possível desatribuir o participante. Tente de novo.'),
      );
    });
  });

  group('lookupCpf', () {
    const lookupPath = '/training-sessions/sess-1/participants/lookup';

    void lookupAnswers(Map<String, dynamic>? body) {
      when(() => api.post<Map<String, dynamic>>(lookupPath,
          data: any(named: 'data'))).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: lookupPath),
          statusCode: 200,
          data: body,
        ),
      );
    }

    test('manda o CPF no corpo e devolve o cadastro que o backend achou',
        () async {
      lookupAnswers({
        'registered': true,
        'name': 'Fernanda Lopes Meireles',
        'email': 'fernanda@empresa.com.br',
        'enrolled': false,
      });

      final result = await repository.lookupCpf('sess-1', '52998224725');

      final sent = verify(() => api.post<Map<String, dynamic>>(lookupPath,
          data: captureAny(named: 'data'))).captured.single;
      expect(sent, {'cpf': '52998224725'});
      final lookup = (result as Success<CpfLookup>).data;
      expect(lookup.registered, isTrue);
      expect(lookup.enrolled, isFalse);
      expect(lookup.name, 'Fernanda Lopes Meireles');
      expect(lookup.email, 'fernanda@empresa.com.br');
    });

    test('CPF já inscrito nesta sessão', () async {
      lookupAnswers({
        'registered': true,
        'name': 'Fernanda Lopes Meireles',
        'email': null,
        'enrolled': true,
      });

      final result = await repository.lookupCpf('sess-1', '52998224725');

      expect((result as Success<CpfLookup>).data.enrolled, isTrue);
    });

    test('resposta fora do formato vira falha, não "sem cadastro"', () async {
      lookupAnswers(null);

      final result = await repository.lookupCpf('sess-1', '52998224725');

      expect(
        result,
        isA<Failure<CpfLookup>>().having(
            (f) => f.message, 'message', 'Não foi possível consultar o CPF.'),
      );
    });

    test('sem rede ou com erro do servidor, a mesma falha de consulta',
        () async {
      when(() => api.post<Map<String, dynamic>>(lookupPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(message: 'Sem conexão', isNetworkError: true),
      );

      final result = await repository.lookupCpf('sess-1', '52998224725');

      expect(
        result,
        isA<Failure<CpfLookup>>().having(
            (f) => f.message, 'message', 'Não foi possível consultar o CPF.'),
      );
    });
  });

  group('add', () {
    const addPath = '/training-sessions/sess-1/participants';

    Map<String, dynamic> addedJson({
      String participationType = 'TEORICA_E_PRATICA',
    }) {
      return {
        'id': 'tp-9',
        'trainingSessionId': 'sess-1',
        'participantId': 'p-9',
        'participationType': participationType,
        'status': 'PENDENTE',
        'assignedConsultantId': null,
        'registeredAt': '2026-10-07T12:00:00.000Z',
        'participant': {
          'id': 'p-9',
          'name': 'Fernanda Lopes Meireles',
          'cpf': '52998224725',
          'email': 'fernanda@empresa.com.br',
        },
      };
    }

    void addAnswers(Map<String, dynamic>? body) {
      when(() => api.post<Map<String, dynamic>>(addPath,
          data: any(named: 'data'))).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: addPath),
          statusCode: 201,
          data: body,
        ),
      );
    }

    Object? sentBody() {
      return verify(() => api.post<Map<String, dynamic>>(addPath,
          data: captureAny(named: 'data'))).captured.single;
    }

    test(
        'inscreve no backend e a linha já entra no cache, com o CPF '
        'mascarado', () async {
      await seedSession();
      addAnswers(addedJson());

      final result = await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        email: 'fernanda@empresa.com.br',
        participationType: ParticipationType.teoricaEPratica,
      );

      expect(sentBody(), {
        'cpf': '52998224725',
        'name': 'Fernanda Lopes Meireles',
        'email': 'fernanda@empresa.com.br',
        'participationType': 'TEORICA_E_PRATICA',
      });
      final added = (result as Success<SessionParticipant>).data;
      expect(added.id, 'tp-9');
      expect(added.name, 'Fernanda Lopes Meireles');

      final row = await db.select(db.participants).getSingle();
      expect(row.id, 'tp-9');
      expect(row.sessionId, 'sess-1');
      expect(row.name, 'Fernanda Lopes Meireles');
      expect(row.cpf, '529.982.***-**', reason: 'o CPF inteiro não é guardado');
      expect(row.status, 'PENDENTE');
      expect(row.participationType, 'TEORICA_E_PRATICA');
      expect(row.assignedConsultantId, isNull);
    });

    test('sem e-mail, o campo nem é enviado; somente teórica vai com o tipo',
        () async {
      await seedSession();
      addAnswers(addedJson(participationType: 'SOMENTE_TEORICA'));

      await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        email: '',
        participationType: ParticipationType.somenteTeorica,
      );

      expect(sentBody(), {
        'cpf': '52998224725',
        'name': 'Fernanda Lopes Meireles',
        'participationType': 'SOMENTE_TEORICA',
      });
      final row = await db.select(db.participants).getSingle();
      expect(row.participationType, 'SOMENTE_TEORICA');
    });

    test('409 devolve o motivo e não cria linha', () async {
      await seedSession();
      when(() => api.post<Map<String, dynamic>>(addPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(
          message: 'CPF já inscrito neste treinamento',
          statusCode: 409,
        ),
      );

      final result = await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        participationType: ParticipationType.teoricaEPratica,
      );

      expect(
        result,
        isA<Failure<SessionParticipant>>().having(
            (f) => f.message, 'message', 'CPF já inscrito neste treinamento'),
      );
      expect(await db.select(db.participants).get(), isEmpty);
    });

    test('400 (inscrições encerradas) devolve o motivo do backend', () async {
      await seedSession();
      when(() => api.post<Map<String, dynamic>>(addPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(
          message: 'Inscrições encerradas para este treinamento',
          statusCode: 400,
        ),
      );

      final result = await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        participationType: ParticipationType.teoricaEPratica,
      );

      expect(
        result,
        isA<Failure<SessionParticipant>>().having((f) => f.message, 'message',
            'Inscrições encerradas para este treinamento'),
      );
    });

    test('erro inesperado do servidor vira uma mensagem genérica', () async {
      await seedSession();
      when(() => api.post<Map<String, dynamic>>(addPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(message: 'Internal server error', statusCode: 500),
      );

      final result = await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        participationType: ParticipationType.teoricaEPratica,
      );

      expect(
        result,
        isA<Failure<SessionParticipant>>().having((f) => f.message, 'message',
            'Não foi possível adicionar o participante. Tente de novo.'),
      );
    });

    test(
        'aceito pelo backend com o corpo fora do formato: sucesso, sem linha '
        'no cache', () async {
      await seedSession();
      addAnswers(null);

      final result = await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        participationType: ParticipationType.teoricaEPratica,
      );

      // Falhar aqui faria o admin tentar de novo e receber "CPF já inscrito".
      final added = (result as Success<SessionParticipant>).data;
      expect(added.name, 'Fernanda Lopes Meireles');
      expect(added.maskedCpf, '529.982.***-**');
      expect(await db.select(db.participants).get(), isEmpty);
    });

    test('sessão fora do cache: o backend inscreveu, e isso basta', () async {
      // Sem `seedSession()`: a linha local violaria a chave estrangeira.
      addAnswers(addedJson());

      final result = await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        participationType: ParticipationType.teoricaEPratica,
      );

      expect(result.isSuccess, isTrue);
      expect(await db.select(db.participants).get(), isEmpty);
    });
  });
}
