import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/result/result_viewmodel.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;
  late SessionRepository sessionRepository;

  const resultPath = '/practical-assessments/by-participant/tp-1';
  const assignPath = '/practical-assessments/assign';
  final now = DateTime(2026, 9, 30, 9);

  setUp(() async {
    api = _MockApiClient();
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    assessmentRepository = AssessmentRepository(database: db);
    participantRepository = ParticipantRepository(apiClient: api, database: db);
    catalogRepository = AssessmentCatalogRepository(apiClient: api, database: db);
    sessionRepository = SessionRepository(apiClient: api, database: db);

    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva',
            city: 'Itabira',
            state: 'MG',
            status: 'EM_ANDAMENTO',
            cachedAt: DateTime(2026, 9, 30, 7),
          ),
        );
    // CV com os itens 1 e 4, RR com o item 3: uma PM em CV dá 70% em CV e
    // 85% no geral.
    for (final (id, code, name, order) in [
      ('cat-cv', 'CV', 'Controle do Veículo', 1),
      ('cat-rr', 'RR', 'Respeito às Regras', 2),
    ]) {
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(id: id, code: code, name: name, order: order),
          );
    }
    for (final (id, category, order) in [
      ('inf-1', 'cat-cv', 1),
      ('inf-4', 'cat-cv', 4),
      ('inf-3', 'cat-rr', 3),
    ]) {
      await db.into(db.infractions).insert(
            InfractionsCompanion.insert(
              id: id,
              categoryId: category,
              description: 'Infração do item $order',
              order: order,
            ),
          );
      for (final (type, deduction) in [('B', 1), ('PM', 3), ('M', 5)]) {
        await db.into(db.infractionNotes).insert(
              InfractionNotesCompanion.insert(
                id: '$id-$type',
                infractionId: id,
                noteType: type,
                deduction: deduction,
                comment: Value(type == 'PM' ? 'Ajuste feito somente após solicitação' : null),
              ),
            );
      }
    }
  });

  tearDown(() => db.close());

  Future<void> seedParticipant({
    String status = 'APROVADO',
    double? score,
    String? assignedTo,
  }) {
    return db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-1',
            sessionId: 'sess-1',
            name: 'Ana Paula Ribeiro',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: status,
            assignedConsultantId: Value(assignedTo),
            score: Value(score),
            cachedAt: DateTime(2026, 9, 30, 7),
          ),
        );
  }

  /// Uma avaliação feita neste aparelho e confirmada na 1.6: PM no item 1
  /// (85%), das 08:12 às 08:31.
  Future<LocalAssessment> confirmedHere() async {
    final draft = await assessmentRepository.openDraft(
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    await assessmentRepository.mark(
      localAssessmentId: draft.id,
      infractionId: 'inf-1',
      infractionNoteId: 'inf-1-PM',
    );
    await (db.update(db.localAssessments)..where((t) => t.id.equals(draft.id)))
        .write(LocalAssessmentsCompanion(startTime: Value(DateTime(2026, 9, 30, 8, 12))));
    await assessmentRepository.confirm(
      draft.id,
      participantName: 'Ana Paula Ribeiro',
      score: 85,
      endTime: DateTime(2026, 9, 30, 8, 31),
    );
    return draft;
  }

  /// O que o backend devolve de uma avaliação aceita: B no item 4.
  Map<String, dynamic> serverJson() => {
        'id': 'assess-1',
        'trainingParticipantId': 'tp-1',
        'startTime': '2026-09-30T11:12:00.000Z',
        'endTime': '2026-09-30T11:31:00.000Z',
        'score': 90,
        'items': [
          {
            'id': 'item-1',
            'infractionNoteId': 'inf-4-B',
            'infractionNote': {
              'id': 'inf-4-B',
              'noteType': 'B',
              'comment': 'Frenagem um pouco brusca',
              'deduction': 1,
              'infraction': {
                'id': 'inf-4',
                'description': 'Uso excessivo ou tardio do freio',
                'order': 4,
                'category': {'id': 'cat-cv', 'code': 'CV', 'name': 'Controle do Veículo', 'order': 1},
              },
            },
          },
        ],
      };

  void serverAnswers(Object? body) {
    when(() => api.get<Object?>(resultPath)).thenAnswer(
      (_) async => Response<Object?>(
        requestOptions: RequestOptions(path: resultPath),
        statusCode: 200,
        data: body,
      ),
    );
  }

  void serverFails(ApiException error) {
    when(() => api.get<Object?>(resultPath)).thenThrow(error);
  }

  ResultViewModel buildViewModel({bool justConfirmed = false, String? consultantId = 'c-eu'}) {
    return ResultViewModel(
      sessionId: 'sess-1',
      participantId: 'tp-1',
      ownerUserId: 'user-1',
      consultantId: consultantId,
      consultantName: 'Carla Souza',
      justConfirmed: justConfirmed,
      assessmentRepository: assessmentRepository,
      participantRepository: participantRepository,
      catalogRepository: catalogRepository,
      sessionRepository: sessionRepository,
      now: () => now,
    );
  }

  /// Deixa os streams do banco entregarem o que acabou de ser gravado.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  test(
      'logo depois do "Confirmar": os dados do aparelho, o aviso de fila e '
      'nenhuma busca no servidor', () async {
    await seedParticipant(status: 'EM_AVALIACAO', assignedTo: 'c-eu');
    await confirmedHere();
    final vm = buildViewModel(justConfirmed: true);
    addTearDown(vm.dispose);

    await vm.init();
    await settle();

    expect(vm.isLoading, isFalse);
    expect(vm.source, ResultSource.device);
    expect(vm.score, 85);
    expect(vm.isApproved, isTrue);
    expect(vm.timesLabel, 'Início 08:12 · Fim 08:31');
    expect(vm.sendNotice, 'Na fila de envio — sai sozinha quando houver conexão.');
    expect(vm.categories!.first.score, 70);
    expect(vm.categories!.first.infractions.single.comment,
        'Ajuste feito somente após solicitação');
    expect(vm.infractionCount, 1);
    expect(vm.justConfirmed, isTrue);
    expect(vm.canReevaluate, isFalse);
    verifyNever(() => api.get<Object?>(any()));
  });

  test('o aviso de envio acompanha a fila: erro e, depois, enviada', () async {
    await seedParticipant(status: 'EM_AVALIACAO', assignedTo: 'c-eu');
    final local = await confirmedHere();
    final vm = buildViewModel(justConfirmed: true);
    addTearDown(vm.dispose);
    await vm.init();

    await assessmentRepository.saveSendResults(
      {local.id: 'sem conexão'},
      at: DateTime(2026, 9, 30, 8, 40),
    );
    await settle();
    expect(vm.sendStatus, LocalSyncStatus.error);
    expect(vm.sendNotice, 'Erro no envio · falhou às 08:40 · sem conexão.');

    await assessmentRepository.saveSendResults({local.id: null}, at: DateTime(2026, 9, 30, 8, 45));
    await settle();
    expect(vm.sendStatus, LocalSyncStatus.synced);
    expect(vm.sendNotice, 'Enviada às 08:45.');
  });

  test(
      'avaliação aceita: a nota e as infrações do servidor, e o % de cada '
      'categoria pelo catálogo do aparelho', () async {
    await seedParticipant(status: 'APROVADO', score: 90);
    serverAnswers(serverJson());
    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await vm.init();

    expect(vm.source, ResultSource.server);
    expect(vm.score, 90);
    expect(vm.isApproved, isTrue);
    expect(vm.startTime, DateTime.utc(2026, 9, 30, 11, 12));
    expect(vm.endTime, DateTime.utc(2026, 9, 30, 11, 31));
    expect(vm.categories!.first.score, 90, reason: 'B num dos 2 itens de CV');
    final infraction = vm.categories!.first.infractions.single;
    expect(infraction.number, 4);
    expect(infraction.description, 'Uso excessivo ou tardio do freio');
    expect(infraction.comment, 'Frenagem um pouco brusca');
    expect(vm.sendStatus, isNull);
    expect(vm.sendNotice, isNull);
    expect(vm.dataNotice, isNull);
  });

  test(
      'sem rede e sem avaliação no aparelho: a nota e o status guardados, com '
      'o aviso', () async {
    await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
    serverFails(const ApiException(message: 'Sem conexão', isNetworkError: true));
    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await vm.init();
    await settle();

    expect(vm.source, ResultSource.cacheOnly);
    expect(vm.score, 62.5);
    expect(vm.isApproved, isFalse);
    expect(vm.categories, isNull);
    expect(vm.dataNotice, ResultDataNotice.offline);
    expect(vm.canRetry, isFalse);
  });

  test(
      'o servidor falhou e o aparelho tem a avaliação aceita: mostra a do '
      'aparelho, com aviso', () async {
    await seedParticipant(status: 'APROVADO', score: 85);
    final local = await confirmedHere();
    await assessmentRepository.saveSendResults({local.id: null}, at: DateTime(2026, 9, 30, 8, 45));
    serverFails(const ApiException(message: 'Internal server error', statusCode: 500));
    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await vm.init();
    await settle();

    expect(vm.source, ResultSource.device);
    expect(vm.dataNotice, ResultDataNotice.deviceFallback);
    expect(vm.score, 85);
    expect(vm.sendNotice, 'Enviada às 08:45.');
  });

  test('o servidor não tem avaliação: a nota e o status guardados, com aviso',
      () async {
    await seedParticipant(status: 'APROVADO', score: 88);
    serverAnswers(null);
    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await vm.init();
    await settle();

    expect(vm.source, ResultSource.cacheOnly);
    expect(vm.dataNotice, ResultDataNotice.notOnServer);
    expect(vm.score, 88);
  });

  test(
      'o servidor falhou sem avaliação no aparelho: "Tentar novamente" busca '
      'de novo', () async {
    await seedParticipant(status: 'APROVADO', score: 90);
    serverFails(const ApiException(message: 'Internal server error', statusCode: 500));
    final vm = buildViewModel();
    addTearDown(vm.dispose);
    await vm.init();
    expect(vm.dataNotice, ResultDataNotice.serverFailed);
    expect(vm.canRetry, isTrue);

    serverAnswers(serverJson());
    await vm.retry();

    expect(vm.source, ResultSource.server);
    expect(vm.dataNotice, isNull);
    expect(vm.categories, isNotNull);
  });

  group('Reavaliar', () {
    test(
        'só para "Necessita reavaliação", fora do "Confirmar", com perfil de '
        'consultor e sem avaliação do aparelho esperando envio', () async {
      await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
      serverAnswers(serverJson());

      final fromDetail = buildViewModel();
      addTearDown(fromDetail.dispose);
      await fromDetail.init();
      await settle();
      expect(fromDetail.canReevaluate, isTrue);

      final afterConfirm = buildViewModel(justConfirmed: true);
      addTearDown(afterConfirm.dispose);
      await afterConfirm.init();
      await settle();
      expect(afterConfirm.canReevaluate, isFalse);

      final noProfile = buildViewModel(consultantId: null);
      addTearDown(noProfile.dispose);
      await noProfile.init();
      await settle();
      expect(noProfile.canReevaluate, isFalse);

      await confirmedHere();
      final waitingToSend = buildViewModel();
      addTearDown(waitingToSend.dispose);
      await waitingToSend.init();
      await settle();
      expect(waitingToSend.canReevaluate, isFalse);
    });

    test(
        'só com a sessão em andamento: numa sessão concluída não há "Reavaliar" '
        'nem reserva', () async {
      Future<void> sessionStatus(String status) {
        return (db.update(db.sessions)..where((t) => t.id.equals('sess-1')))
            .write(SessionsCompanion(status: Value(status)));
      }

      await sessionStatus('CONCLUIDO');
      await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
      serverAnswers(serverJson());
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await settle();

      expect(vm.canReevaluate, isFalse);
      expect(await vm.reevaluate(), isFalse);
      verifyNever(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')));

      await sessionStatus('EM_ANDAMENTO');
      await settle();

      expect(vm.canReevaluate, isTrue, reason: 'a sessão em andamento libera');
    });

    test('dois toques rápidos em "Reavaliar" reservam uma vez só', () async {
      await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
      serverAnswers(serverJson());
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: assignPath),
                statusCode: 201,
                data: {'assigned': 1},
              ));
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await settle();

      final first = vm.reevaluate();
      final second = vm.reevaluate();

      expect(await first, isTrue);
      expect(await second, isFalse);
      verify(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .called(1);
    });

    test('aprovado não tem "Reavaliar"', () async {
      await seedParticipant(status: 'APROVADO', score: 90);
      serverAnswers(serverJson());
      final vm = buildViewModel();
      addTearDown(vm.dispose);

      await vm.init();
      await settle();

      expect(vm.canReevaluate, isFalse);
    });

    test('reserva o participante para quem tocou; um 409 mostra o motivo',
        () async {
      await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
      serverAnswers(serverJson());
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Um ou mais participantes já estão em avaliação com outro consultor',
        statusCode: 409,
      ));
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await settle();

      expect(await vm.reevaluate(), isFalse);
      expect(vm.reevaluateError,
          'Um ou mais participantes já estão em avaliação com outro consultor');

      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: assignPath),
                statusCode: 201,
                data: {'assigned': 1},
              ));

      expect(await vm.reevaluate(), isTrue);
      expect(vm.reevaluateError, isNull);
      final row = await db.select(db.participants).getSingle();
      expect(row.status, 'EM_AVALIACAO');
      expect(row.assignedConsultantId, 'c-eu');
    });
  });
}
