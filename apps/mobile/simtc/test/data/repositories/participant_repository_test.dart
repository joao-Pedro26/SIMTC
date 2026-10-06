import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/remote_assessment.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
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

  /// O detalhe como `findTrainingSessionById` devolve (`company: true`, por
  /// isso o logo vem junto).
  Map<String, dynamic> detailJson(List<Map<String, dynamic>> participants) {
    return {
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
}
