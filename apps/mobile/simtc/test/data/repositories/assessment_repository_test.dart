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
  Future<LocalAssessment> open(String participantId, {String owner = 'user-1'}) {
    return repository.openDraft(
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      ownerUserId: owner,
    );
  }

  Future<LocalAssessment> row(String id) {
    return (db.select(db.localAssessments)..where((t) => t.id.equals(id)))
        .getSingle();
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
      final a2 = (await open('tp-2')).id;

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
      final draft = await open('tp-rascunho');
      final first = await open('tp-1');
      final failed = await open('tp-2');
      final second = await open('tp-3');
      final synced = await open('tp-4');
      final others = await open('tp-5', owner: 'user-2');
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
      final queued = await open('tp-2');
      await repository.confirm(queued.id, participantName: 'P', score: 90);
      await open('tp-3', owner: 'user-2');
      await repository.openDraft(
        trainingParticipantId: 'tp-4',
        sessionId: 'outra-sessao',
        ownerUserId: 'user-1',
      );

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
      final a2 = await open('tp-2');
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
      final refused = await open('tp-2');
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
      final b = await open('tp-2');
      final c = await open('tp-3', owner: 'user-2');
      final d = await open('tp-4');
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
