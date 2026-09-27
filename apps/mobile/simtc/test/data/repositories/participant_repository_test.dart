import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
          participantJson('tp-3', status: 'NECESSITA_REAVALIACAO'),
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
}
