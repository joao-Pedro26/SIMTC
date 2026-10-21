// `isNull`/`isNotNull` são escondidos de propósito: `package:drift/drift.dart`
// exporta funções top-level com esses nomes, que conflitam com os matchers de
// `package:flutter_test` (ver `app_database_test.dart`).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/services/local/app_database.dart';

void main() {
  late AppDatabase db;
  late AssessmentRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = AssessmentRepository(database: db);
  });

  tearDown(() => db.close());

  /// Abre o rascunho de [participantId] para [owner] — o caminho do checklist.
  /// [consultant] é o `Consultant.id` de [owner].
  Future<LocalAssessment> open(
    String participantId, {
    String owner = 'user-1',
    String? consultant = 'c-1',
  }) {
    return repository.openDraft(
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      ownerUserId: owner,
      consultantId: consultant,
    );
  }

  Future<LocalAssessment> row(String id) {
    return (db.select(db.localAssessments)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Um rascunho direto no banco, sem a regra de um por vez: para os testes
  /// que precisam de vários rascunhos do mesmo consultor ao mesmo tempo.
  Future<LocalAssessment> insertDraft(
    String participantId, {
    String owner = 'user-1',
    String sessionId = 'sess-1',
    DateTime? startTime,
  }) async {
    final id = 'draft-$participantId-$owner';
    await db.into(db.localAssessments).insert(
          LocalAssessmentsCompanion.insert(
            id: id,
            trainingParticipantId: participantId,
            sessionId: sessionId,
            date: DateTime(2026, 9, 29),
            startTime: startTime ?? DateTime(2026, 9, 29, 8),
            syncStatus: LocalSyncStatus.draft,
            createdAt: DateTime(2026, 9, 29, 8),
            updatedAt: DateTime(2026, 9, 29, 8),
            ownerUserId: Value(owner),
          ),
        );
    return row(id);
  }

  Future<void> write(String id, LocalAssessmentsCompanion changes) {
    return (db.update(db.localAssessments)..where((t) => t.id.equals(id)))
        .write(changes);
  }

  Future<void> seedSession({DateTime? date}) {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva',
            city: 'Itabira',
            state: 'MG',
            status: 'EM_ANDAMENTO',
            date: Value(date),
            cachedAt: DateTime(2026, 9, 12, 8),
          ),
        );
  }

  /// O participante no cache, como o detalhe da sessão o grava: em avaliação
  /// com [consultant]. É o que faz a avaliação dele "ainda dar para abrir".
  Future<void> seedParticipant(
    String id, {
    String? consultant = 'c-1',
    String status = 'EM_AVALIACAO',
  }) {
    return db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: id,
            sessionId: 'sess-1',
            name: 'Participante $id',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: status,
            assignedConsultantId: Value(consultant),
            cachedAt: DateTime(2026, 9, 12, 8),
          ),
        );
  }

  group('openDraft', () {
    test('cria um rascunho novo em draft, com startTime agora e o dono', () async {
      final assessment = await open('tp-1');

      final saved = await db.select(db.localAssessments).getSingle();
      expect(saved.id, assessment.id);
      expect(assessment.trainingParticipantId, 'tp-1');
      expect(assessment.sessionId, 'sess-1');
      expect(assessment.syncStatus, LocalSyncStatus.draft);
      expect(assessment.endTime, isNull);
      expect(assessment.startTime, isNotNull);
      expect(assessment.ownerUserId, 'user-1');
    });

    test('a data da avaliação é a data de calendário da sessão', () async {
      await seedSession(date: DateTime(2026, 9, 12));

      final assessment = await open('tp-1');

      expect(assessment.date, DateTime(2026, 9, 12));
    });

    test('sessão sem data (ou fora do cache) usa a data de hoje', () async {
      final assessment = await open('tp-1');

      final now = DateTime.now();
      expect(assessment.date, DateTime(now.year, now.month, now.day));
    });

    test('retoma o rascunho do próprio dono, sem duplicar', () async {
      final first = await open('tp-1');

      final second = await open('tp-1');

      expect(second.id, first.id);
      expect(second.startTime, first.startTime);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });

    test('avaliação já enviada começa um rascunho novo — é uma reavaliação',
        () async {
      final first = await open('tp-1');
      await repository.mark(
        localAssessmentId: first.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      await repository.confirm(first.id, participantName: 'Ana', score: 96);
      await repository.saveSendResults({first.id: null}, at: DateTime(2026, 9, 29, 9));

      final again = await open('tp-1');

      expect(again.id, isNot(first.id));
      expect(again.syncStatus, LocalSyncStatus.draft);
      expect(again.endTime, isNull);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
      expect(await db.select(db.localAssessmentItems).get(), isEmpty,
          reason: 'as marcações da avaliação enviada saem junto com ela');
    });

    test(
        'rascunho de outro consultor não é reaproveitado: começa um novo, sem '
        'as marcações dele', () async {
      final theirs = await open('tp-1', owner: 'user-2');
      await repository.mark(
        localAssessmentId: theirs.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-m',
      );

      final mine = await open('tp-1');

      expect(mine.id, isNot(theirs.id));
      expect(mine.ownerUserId, 'user-1');
      expect(await repository.loadItems(mine.id), isEmpty);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });

    test(
        'rascunho sem dono (de antes da Fase 5A) passa a ser de quem abriu, '
        'com as marcações', () async {
      final legacy = await open('tp-1');
      await repository.mark(
        localAssessmentId: legacy.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      await write(legacy.id, const LocalAssessmentsCompanion(ownerUserId: Value(null)));

      final reopened = await open('tp-1');

      expect(reopened.id, legacy.id);
      expect(reopened.ownerUserId, 'user-1');
      expect((await row(legacy.id)).ownerUserId, 'user-1');
      expect(await repository.loadItems(legacy.id), hasLength(1));
    });

    test('avaliação na fila nunca é zerada — nem pelo dono, nem por outro',
        () async {
      final queued = await open('tp-1');
      await repository.confirm(queued.id, participantName: 'Ana', score: 80);

      final byOwner = await open('tp-1');
      final byOther = await open('tp-1', owner: 'user-2');

      expect(byOwner.id, queued.id);
      expect(byOther.id, queued.id);
      expect(byOther.syncStatus, LocalSyncStatus.pendingSync);
    });
  });

  test('confirmar grava o fim pedido — e a hora do toque se nenhum for dado',
      () async {
    final a = await open('tp-1');
    final b = await insertDraft('tp-2');

    await repository.confirm(a.id,
        participantName: 'A', score: 90, endTime: DateTime(2026, 9, 30, 8, 31));
    await repository.confirm(b.id, participantName: 'B', score: 90);

    final rows = {
      for (final row in await db.select(db.localAssessments).get())
        row.id: row.endTime,
    };
    expect(rows[a.id], DateTime(2026, 9, 30, 8, 31));
    expect(rows[b.id], isNotNull);
  });

  group('um por vez', () {
    // A sessão em andamento e o tp-1 com o consultor: é o que faz o rascunho
    // dele contar — só bloqueia a avaliação que ainda dá para abrir (decisão
    // de 06/10/2026).
    setUp(() async {
      await seedSession();
      await seedParticipant('tp-1');
    });

    Future<LocalAssessment?> other(
      String except, {
      String owner = 'user-1',
      String? consultant = 'c-1',
    }) {
      return repository.findInProgressOther(
        ownerUserId: owner,
        consultantId: consultant,
        exceptTrainingParticipantId: except,
      );
    }

    test('acha o rascunho de outro participante do mesmo consultor', () async {
      final a = await open('tp-1');

      expect((await other('tp-2'))?.id, a.id);
      expect(await other('tp-1'), isNull, reason: 'o próprio não conta');
      expect(await other('tp-2', owner: 'user-2', consultant: 'c-2'), isNull,
          reason: 'o rascunho é de outro consultor');
    });

    test('só o rascunho conta: confirmada, na fila ou enviada liberam', () async {
      final a = await open('tp-1');
      await repository.confirm(a.id, participantName: 'A', score: 90);
      expect(await other('tp-2'), isNull, reason: 'na fila');

      await repository.saveSendResults({a.id: null}, at: DateTime(2026, 9, 30, 9));
      expect(await other('tp-2'), isNull, reason: 'enviada');
    });

    test('iniciar outro participante é recusado enquanto há um em andamento',
        () async {
      final a = await open('tp-1');

      await expectLater(
        open('tp-2'),
        throwsA(isA<EvaluationInProgressException>()
            .having((e) => e.trainingParticipantId, 'trainingParticipantId', 'tp-1')),
      );

      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.id), [a.id], reason: 'nada foi gravado');
    });

    test('reabrir o que está em andamento continua valendo, e confirmar libera '
        'o próximo', () async {
      final a = await open('tp-1');
      expect((await open('tp-1')).id, a.id);

      await repository.confirm(a.id, participantName: 'A', score: 90);
      final next = await open('tp-2');

      expect(next.trainingParticipantId, 'tp-2');
      expect(next.syncStatus, LocalSyncStatus.draft);
    });

    test('o rascunho de outro consultor não bloqueia', () async {
      await open('tp-1', owner: 'user-2', consultant: 'c-2');

      final mine = await open('tp-2');

      expect(mine.ownerUserId, 'user-1');
    });

    group('avaliação presa', () {
      Future<void> setSessionStatus(String status) {
        return (db.update(db.sessions)..where((t) => t.id.equals('sess-1')))
            .write(SessionsCompanion(status: Value(status)));
      }

      Future<void> setParticipant({
        required String status,
        required String? consultant,
      }) {
        return (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
            .write(
          ParticipantsCompanion(
            status: Value(status),
            assignedConsultantId: Value(consultant),
          ),
        );
      }

      test('sessão que não está mais em andamento: o rascunho deixa de bloquear',
          () async {
        final a = await open('tp-1');

        for (final status in ['CONCLUIDO', 'CANCELADO', 'PLANEJADO']) {
          await setSessionStatus(status);
          expect(await other('tp-2'), isNull, reason: status);
        }

        await setSessionStatus('EM_ANDAMENTO');
        expect((await other('tp-2'))?.id, a.id, reason: 'voltou a andamento');
      });

      test('sessão que saiu do aparelho (o consultor foi removido dela)',
          () async {
        await open('tp-1');
        await db.delete(db.participants).go();
        await db.delete(db.sessions).go();

        expect(await other('tp-2'), isNull);
      });

      test('participante liberado, com outro consultor ou sem dono', () async {
        await open('tp-1');

        await setParticipant(status: 'PENDENTE', consultant: null);
        expect(await other('tp-2'), isNull, reason: 'liberado: voltou a pendente');

        await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-outro');
        expect(await other('tp-2'), isNull, reason: 'com outro consultor');

        await setParticipant(status: 'EM_AVALIACAO', consultant: null);
        expect(await other('tp-2'), isNull, reason: 'em avaliação, sem dono');
      });

      test('nada é apagado: se o participante volta, o rascunho volta a bloquear',
          () async {
        final a = await open('tp-1');
        await setParticipant(status: 'PENDENTE', consultant: null);

        expect(await other('tp-2'), isNull);
        final rows = await db.select(db.localAssessments).get();
        expect(rows.map((r) => r.id), [a.id], reason: 'continua guardado');

        await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-1');
        expect((await other('tp-2'))?.id, a.id);
      });

      test('sem perfil de consultor, nenhum participante está com o usuário',
          () async {
        await open('tp-1');

        expect(await other('tp-2', consultant: null), isNull);
      });

      test('com um rascunho preso e outro que ainda abre, bloqueia o que abre',
          () async {
        // O tp-0 começou antes e ficou preso: não está mais com o consultor.
        await seedParticipant('tp-0', status: 'PENDENTE', consultant: null);
        await insertDraft('tp-0');
        final a = await open('tp-1');

        expect((await other('tp-2'))?.id, a.id);
      });

      test('iniciar outro participante passa quando o rascunho antigo ficou preso',
          () async {
        final a = await open('tp-1');
        await setParticipant(status: 'PENDENTE', consultant: null);

        final next = await open('tp-2');

        expect(next.trainingParticipantId, 'tp-2');
        final rows = await db.select(db.localAssessments).get();
        expect(rows.map((r) => r.id), unorderedEquals([a.id, next.id]),
            reason: 'o preso continua guardado');
      });
    });

    // O participante foi liberado com a avaliação pela metade, o consultor
    // começou outra, e o primeiro voltou para ele: são duas em andamento, e
    // vale a que começou por último (decisão de 09/10/2026).
    group('avaliação antiga que volta', () {
      late LocalAssessment old;
      late LocalAssessment recent;

      setUp(() async {
        await seedParticipant('tp-2');
        old = await insertDraft('tp-1', startTime: DateTime(2026, 9, 29, 8, 12));
        recent = await insertDraft('tp-2', startTime: DateTime(2026, 9, 29, 8, 30));
      });

      Future<LocalAssessment?> otherAfter(String except, DateTime startedAfter) {
        return repository.findInProgressOther(
          ownerUserId: 'user-1',
          consultantId: 'c-1',
          exceptTrainingParticipantId: except,
          startedAfter: startedAfter,
        );
      }

      test('só a avaliação que começou depois faz a outra esperar', () async {
        expect((await otherAfter('tp-1', old.startTime))?.id, recent.id);
        expect(await otherAfter('tp-2', recent.startTime), isNull);
      });

      test('sem o corte de horário, qualquer outra em andamento conta — é a '
          'regra de quem vai iniciar uma avaliação nova', () async {
        expect((await other('tp-1'))?.id, recent.id);
        expect((await other('tp-2'))?.id, old.id);
        // A que começou primeiro vem primeiro.
        expect((await other('tp-3'))?.id, old.id);
      });

      test('continuar a antiga é recusado enquanto a mais nova está em '
          'andamento, e nada muda', () async {
        await expectLater(
          open('tp-1'),
          throwsA(isA<EvaluationInProgressException>()
              .having((e) => e.trainingParticipantId, 'trainingParticipantId', 'tp-2')),
        );

        expect((await row(old.id)).startTime, old.startTime);
      });

      test('a mais nova continua abrindo, sem esperar pela antiga', () async {
        final again = await open('tp-2');

        expect(again.id, recent.id);
        expect(again.startTime, recent.startTime);
      });

      test('com a mais nova confirmada ou descartada, a antiga volta a abrir, '
          'com a mesma hora de início', () async {
        await repository.confirm(recent.id, participantName: 'B', score: 90);

        final again = await open('tp-1');

        expect(again.id, old.id);
        expect(again.startTime, old.startTime);
      });

      test('a mais nova que ficou presa não segura a antiga', () async {
        await (db.update(db.participants)..where((t) => t.id.equals('tp-2')))
            .write(const ParticipantsCompanion(
          status: Value('PENDENTE'),
          assignedConsultantId: Value(null),
        ));

        final again = await open('tp-1');

        expect(again.id, old.id);
      });

      test('avaliação na fila não espera ninguém: abre mesmo com outra mais '
          'nova em andamento', () async {
        await repository.confirm(old.id, participantName: 'A', score: 90);

        final again = await open('tp-1');

        expect(again.id, old.id);
        expect(again.syncStatus, LocalSyncStatus.pendingSync);
      });
    });
  });

  group('findCurrent', () {
    Future<LocalAssessment?> current(String participantId, {String owner = 'user-1'}) {
      return repository.findCurrent(trainingParticipantId: participantId, ownerUserId: owner);
    }

    test('sem nada iniciado, é nula e não grava nada — abrir o checklist só lê',
        () async {
      expect(await current('tp-1'), isNull);
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    test('devolve a avaliação em andamento do próprio dono', () async {
      final started = await open('tp-1');

      final found = await current('tp-1');

      expect(found?.id, started.id);
      expect(found?.startTime, started.startTime);
    });

    test(
        'avaliação já enviada e rascunho de outro consultor contam como não '
        'iniciada — e nada é apagado só por abrir', () async {
      final sent = await open('tp-1');
      await repository.confirm(sent.id, participantName: 'A', score: 90);
      await repository.saveSendResults({sent.id: null}, at: DateTime(2026, 9, 29, 9));
      final theirs = await open('tp-2', owner: 'user-2');

      expect(await current('tp-1'), isNull);
      expect(await current('tp-2'), isNull);
      expect((await row(sent.id)).syncStatus, LocalSyncStatus.synced);
      expect((await row(theirs.id)).ownerUserId, 'user-2');
    });

    test('avaliação na fila é devolvida, mesmo de outro consultor', () async {
      final queued = await open('tp-1', owner: 'user-2');
      await repository.confirm(queued.id, participantName: 'A', score: 90);

      expect((await current('tp-1'))?.id, queued.id);
    });

    test('rascunho sem dono passa a ser de quem abriu', () async {
      final legacy = await open('tp-1');
      await write(legacy.id, const LocalAssessmentsCompanion(ownerUserId: Value(null)));

      final found = await current('tp-1');

      expect(found?.id, legacy.id);
      expect(found?.ownerUserId, 'user-1');
      expect((await row(legacy.id)).ownerUserId, 'user-1');
    });
  });

  group('mark / unmark / watchItems', () {
    test('marca uma infração e ela aparece em watchItems', () async {
      final assessmentId = (await open('tp-1')).id;

      await repository.mark(
        localAssessmentId: assessmentId,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );

      final items = await repository.watchItems(assessmentId).first;
      expect(items, hasLength(1));
      expect(items.single.infractionId, 'inf-1');
      expect(items.single.infractionNoteId, 'note-b');
    });

    test('marcar de novo a mesma infração troca a nota, sem duplicar linha', () async {
      final assessmentId = (await open('tp-1')).id;

      final first = await repository.mark(
        localAssessmentId: assessmentId,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      final second = await repository.mark(
        localAssessmentId: assessmentId,
        infractionId: 'inf-1',
        infractionNoteId: 'note-m',
      );

      expect(second, hasLength(1));
      expect(second.single.infractionNoteId, 'note-m');
      expect(second.single.id, first.single.id,
          reason: 'o upsert atualiza a linha, não troca por outra');
      final items = await repository.watchItems(assessmentId).first;
      expect(items.single.infractionNoteId, 'note-m');
    });

    test('unmark remove a marcação da infração', () async {
      final assessmentId = (await open('tp-1')).id;
      await repository.mark(
        localAssessmentId: assessmentId,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );

      await repository.unmark(localAssessmentId: assessmentId, infractionId: 'inf-1');

      expect(await repository.watchItems(assessmentId).first, isEmpty);
    });

    test('marcações de avaliações diferentes não se misturam', () async {
      final a1 = (await open('tp-1')).id;
      final a2 = (await insertDraft('tp-2')).id;

      await repository.mark(
        localAssessmentId: a1,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      await repository.mark(
        localAssessmentId: a2,
        infractionId: 'inf-1',
        infractionNoteId: 'note-m',
      );

      expect((await repository.loadItems(a1)).single.infractionNoteId, 'note-b');
      expect((await repository.loadItems(a2)).single.infractionNoteId, 'note-m');
    });
  });

  group('descartar', () {
    test(
        'descartar o rascunho apaga a avaliação e as marcações — o participante '
        'volta a "não iniciada"', () async {
      final draft = await open('tp-1');
      await repository.mark(
        localAssessmentId: draft.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );

      final discarded = await repository.discardDraft(draft.id);

      expect(discarded, isTrue);
      expect(await db.select(db.localAssessments).get(), isEmpty);
      expect(await db.select(db.localAssessmentItems).get(), isEmpty);
      expect(
        await repository.findCurrent(trainingParticipantId: 'tp-1', ownerUserId: 'user-1'),
        isNull,
      );
    });

    test('avaliação confirmada não é rascunho: descartar não apaga nada', () async {
      final queued = await open('tp-1');
      await repository.confirm(queued.id, participantName: 'Ana', score: 90);

      expect(await repository.discardDraft(queued.id), isFalse);
      expect((await row(queued.id)).syncStatus, LocalSyncStatus.pendingSync);
    });

    test(
        'descartar uma falha só apaga a avaliação em erro com o motivo pedido',
        () async {
      final refused = await open('tp-1');
      await repository.confirm(refused.id, participantName: 'Ana', score: 90);
      await repository.saveSendResults(
        {refused.id: 'recusada pelo servidor'},
        at: DateTime(2026, 9, 30, 9),
      );
      final queued = await insertDraft('tp-2');
      await repository.confirm(queued.id, participantName: 'Bia', score: 90);

      expect(
        await repository.discardFailed(refused.id, reason: 'sem conexão'),
        isFalse,
        reason: 'outro motivo',
      );
      expect(
        await repository.discardFailed(queued.id, reason: 'recusada pelo servidor'),
        isFalse,
        reason: 'na fila, sem erro',
      );
      expect(
        await repository.discardFailed(refused.id, reason: 'recusada pelo servidor'),
        isTrue,
      );
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.id), [queued.id]);
    });

    test(
        'a recusada que foi reenviada e aceita deixou de ser recusa: descartar '
        'não a apaga', () async {
      final resent = await open('tp-1');
      await repository.confirm(resent.id, participantName: 'Ana', score: 90);
      await repository.saveSendResults(
        {resent.id: 'recusada pelo servidor'},
        at: DateTime(2026, 9, 30, 9),
      );
      // O reenvio foi aceito com o diálogo de "Descartar" ainda aberto.
      await repository.saveSendResults({resent.id: null}, at: DateTime(2026, 9, 30, 9, 5));

      expect(
        await repository.discardFailed(resent.id, reason: 'recusada pelo servidor'),
        isFalse,
      );
      expect((await row(resent.id)).syncStatus, LocalSyncStatus.synced);
    });
  });

  group('confirm', () {
    test('grava endTime, o nome e o % da tela 1.6 e põe na fila', () async {
      final assessment = await open('tp-1');

      await repository.confirm(
        assessment.id,
        participantName: 'Ana Paula Ribeiro',
        score: 86.7,
      );

      final saved = await row(assessment.id);
      expect(saved.syncStatus, LocalSyncStatus.pendingSync);
      expect(saved.endTime, isNotNull);
      expect(saved.participantName, 'Ana Paula Ribeiro');
      expect(saved.score, 86.7);
    });
  });

  group('fila', () {
    test(
        'só as confirmadas e ainda não aceitas do dono, na ordem do Confirmar',
        () async {
      final draft = await insertDraft('tp-rascunho');
      final first = await insertDraft('tp-1');
      final failed = await insertDraft('tp-2');
      final second = await insertDraft('tp-3');
      final synced = await insertDraft('tp-4');
      final others = await insertDraft('tp-5', owner: 'user-2');
      for (final a in [first, failed, second, synced, others]) {
        await repository.confirm(a.id, participantName: 'P', score: 90);
      }
      // O banco guarda segundos: horários explícitos deixam a ordem certa.
      await write(first.id, LocalAssessmentsCompanion(endTime: Value(DateTime(2026, 9, 29, 8))));
      await write(failed.id, LocalAssessmentsCompanion(endTime: Value(DateTime(2026, 9, 29, 8, 5))));
      await write(second.id, LocalAssessmentsCompanion(endTime: Value(DateTime(2026, 9, 29, 8, 10))));
      await repository.saveSendResults(
        {synced.id: null, failed.id: 'sem conexão'},
        at: DateTime(2026, 9, 29, 9),
      );

      final queue = await repository.loadQueue('user-1');
      final watched = await repository.watchQueue('user-1').first;

      expect(queue.map((a) => a.id), [first.id, failed.id, second.id]);
      expect(watched.map((a) => a.id), [first.id, failed.id, second.id]);
      expect(queue.map((a) => a.id), isNot(contains(draft.id)));
    });

    test('as avaliações de uma sessão são só as do dono, em qualquer situação',
        () async {
      final draft = await open('tp-1');
      final queued = await insertDraft('tp-2');
      await repository.confirm(queued.id, participantName: 'P', score: 90);
      await open('tp-3', owner: 'user-2');
      await insertDraft('tp-4', sessionId: 'outra-sessao');

      final rows = await repository.watchSessionAssessments('sess-1', 'user-1').first;

      expect(rows.map((a) => a.id), unorderedEquals([draft.id, queued.id]));
    });

    test(
        'claimUnowned dá as avaliações sem dono a quem entrou, com o nome do '
        'participante do cache', () async {
      await seedSession();
      await db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-1',
              sessionId: 'sess-1',
              name: 'Ana Paula Ribeiro',
              cpf: '042.118.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'EM_AVALIACAO',
              cachedAt: DateTime(2026, 9, 25, 8),
            ),
          );
      // Como a Fase 4 deixou: finalizada, sem dono e sem nome.
      final legacy = await open('tp-1');
      await write(
        legacy.id,
        LocalAssessmentsCompanion(
          ownerUserId: const Value(null),
          endTime: Value(DateTime(2026, 9, 28, 10)),
          syncStatus: const Value(LocalSyncStatus.pendingSync),
        ),
      );
      final others = await open('tp-2', owner: 'user-2');

      await repository.claimUnowned('user-1');

      expect((await row(legacy.id)).ownerUserId, 'user-1');
      expect((await row(legacy.id)).participantName, 'Ana Paula Ribeiro');
      expect((await row(others.id)).ownerUserId, 'user-2');
      expect((await repository.loadQueue('user-1')).single.id, legacy.id);
    });
  });

  group('syncPayload', () {
    Future<void> seedCatalog() async {
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(
              id: 'cat-1',
              code: 'CV',
              name: 'Controle do Veículo',
              order: 1,
            ),
          );
      for (final id in ['inf-1', 'inf-2']) {
        await db.into(db.infractions).insert(
              InfractionsCompanion.insert(
                id: id,
                categoryId: 'cat-1',
                description: 'Infração $id',
                order: 1,
              ),
            );
      }
      for (final (id, infraction) in [
        ('note-b', 'inf-1'),
        ('note-m', 'inf-1'),
        ('note-x', 'inf-2'),
      ]) {
        await db.into(db.infractionNotes).insert(
              InfractionNotesCompanion.insert(
                id: id,
                infractionId: infraction,
                noteType: 'B',
                deduction: 1,
              ),
            );
      }
    }

    test(
        'manda o formato do painel web: data de calendário, horários em UTC e '
        'só as notas que existem no catálogo, na infração marcada', () async {
      await seedSession(date: DateTime(2026, 9, 12));
      await seedCatalog();
      final assessment = await open('tp-1');
      await repository.mark(
        localAssessmentId: assessment.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      // Órfã: a nota foi removida do catálogo depois da marcação.
      await repository.mark(
        localAssessmentId: assessment.id,
        infractionId: 'inf-9',
        infractionNoteId: 'note-sumiu',
      );
      // Órfã: a nota existe, mas agora é de outra infração.
      await repository.mark(
        localAssessmentId: assessment.id,
        infractionId: 'inf-2',
        infractionNoteId: 'note-m',
      );
      final start = DateTime(2026, 9, 12, 8, 30);
      final end = DateTime(2026, 9, 12, 8, 44, 7);
      await write(
        assessment.id,
        LocalAssessmentsCompanion(startTime: Value(start), endTime: Value(end)),
      );

      final payload = await repository.syncPayload([await row(assessment.id)]);

      expect(payload, [
        {
          'trainingParticipantId': 'tp-1',
          'date': '2026-09-12',
          'startTime': start.toUtc().toIso8601String(),
          'endTime': end.toUtc().toIso8601String(),
          'items': [
            {'infractionNoteId': 'note-b'},
          ],
        },
      ]);
    });

    test('cada avaliação leva só as próprias marcações', () async {
      await seedCatalog();
      final a1 = await open('tp-1');
      final a2 = await insertDraft('tp-2');
      await repository.mark(
        localAssessmentId: a1.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      await repository.mark(
        localAssessmentId: a2.id,
        infractionId: 'inf-2',
        infractionNoteId: 'note-x',
      );

      final payload = await repository.syncPayload([await row(a1.id), await row(a2.id)]);

      expect(payload.map((p) => p['items']), [
        [
          {'infractionNoteId': 'note-b'},
        ],
        [
          {'infractionNoteId': 'note-x'},
        ],
      ]);
    });
  });

  group('resultado do envio', () {
    test(
        'aceita sai da fila; recusada fica com o motivo — e cada envio conta '
        'uma tentativa', () async {
      final accepted = await open('tp-1');
      final refused = await insertDraft('tp-2');
      await repository.confirm(accepted.id, participantName: 'A', score: 90);
      await repository.confirm(refused.id, participantName: 'B', score: 60);
      final at = DateTime(2026, 9, 29, 9, 15);

      await repository.saveSendResults(
        {accepted.id: null, refused.id: 'recusada pelo servidor'},
        at: at,
      );

      final ok = await row(accepted.id);
      expect(ok.syncStatus, LocalSyncStatus.synced);
      expect(ok.lastError, isNull);
      expect(ok.lastAttemptAt, at);
      expect(ok.attemptCount, 1);
      final ko = await row(refused.id);
      expect(ko.syncStatus, LocalSyncStatus.error);
      expect(ko.lastError, 'recusada pelo servidor');
      expect(ko.attemptCount, 1);
      expect((await repository.loadQueue('user-1')).map((a) => a.id), [refused.id]);
    });

    test('a última sincronização é o último envio aceito do dono', () async {
      expect(await repository.watchLastSyncedAt('user-1').first, isNull);

      final a = await open('tp-1');
      final b = await insertDraft('tp-2');
      final c = await open('tp-3', owner: 'user-2');
      final d = await insertDraft('tp-4');
      for (final x in [a, b, c, d]) {
        await repository.confirm(x.id, participantName: 'P', score: 90);
      }
      await repository.saveSendResults({a.id: null}, at: DateTime(2026, 9, 29, 9));
      await repository.saveSendResults({b.id: null}, at: DateTime(2026, 9, 29, 9, 30));
      await repository.saveSendResults({c.id: null}, at: DateTime(2026, 9, 29, 10));
      await repository.saveSendResults({d.id: 'sem conexão'}, at: DateTime(2026, 9, 29, 11));

      expect(
        await repository.watchLastSyncedAt('user-1').first,
        DateTime(2026, 9, 29, 9, 30),
      );
    });
  });
}
