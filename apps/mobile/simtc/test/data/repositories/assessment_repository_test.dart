import 'package:drift/drift.dart' show Value;
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

  group('openDraft', () {
    test('cria um rascunho novo em draft, com startTime agora', () async {
      final assessment = await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      );

      final row = await db.select(db.localAssessments).getSingle();
      expect(row.id, assessment.id);
      expect(assessment.trainingParticipantId, 'tp-1');
      expect(assessment.sessionId, 'sess-1');
      expect(assessment.syncStatus, LocalSyncStatus.draft);
      expect(assessment.endTime, isNull);
      expect(assessment.startTime, isNotNull);
    });

    test('a data da avaliação é a data de calendário da sessão', () async {
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: 'sess-1',
              companyName: 'Bracell',
              courseName: 'Direção Defensiva',
              city: 'Itabira',
              state: 'MG',
              status: 'EM_ANDAMENTO',
              date: Value(DateTime(2026, 9, 12)),
              cachedAt: DateTime(2026, 9, 12, 8),
            ),
          );

      final assessment = await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      );

      expect(assessment.date, DateTime(2026, 9, 12));
    });

    test('sessão sem data (ou fora do cache) usa a data de hoje', () async {
      final assessment = await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-sem-cache',
      );

      final now = DateTime.now();
      expect(assessment.date, DateTime(now.year, now.month, now.day));
    });

    test('retoma o rascunho existente do participante, sem duplicar', () async {
      final first = await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      );

      final second = await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      );

      expect(second.id, first.id);
      expect(second.startTime, first.startTime);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });
  });

  group('mark / unmark / watchItems', () {
    test('marca uma infração e ela aparece em watchItems', () async {
      final assessmentId = (await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      )).id;

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
      final assessmentId = (await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      )).id;

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
      final assessmentId = (await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      )).id;
      await repository.mark(
        localAssessmentId: assessmentId,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );

      await repository.unmark(localAssessmentId: assessmentId, infractionId: 'inf-1');

      expect(await repository.watchItems(assessmentId).first, isEmpty);
    });

    test('marcações de avaliações diferentes não se misturam', () async {
      final a1 = (await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      )).id;
      final a2 = (await repository.openDraft(
        trainingParticipantId: 'tp-2',
        sessionId: 'sess-1',
      )).id;

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

      expect((await repository.watchItems(a1).first).single.infractionNoteId, 'note-b');
      expect((await repository.watchItems(a2).first).single.infractionNoteId, 'note-m');
    });
  });

  group('finish', () {
    test('grava endTime e põe em pendingSync', () async {
      final assessmentId = (await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      )).id;

      await repository.finish(assessmentId);

      final row = await db.select(db.localAssessments).getSingle();
      expect(row.syncStatus, LocalSyncStatus.pendingSync);
      expect(row.endTime, isNotNull);
    });

    test(
        'reabrir o checklist de um participante já finalizado retoma a mesma '
        'avaliação, sem estourar a chave única', () async {
      final assessmentId = (await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      )).id;
      await repository.finish(assessmentId);

      final reopened = await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      );

      expect(reopened.id, assessmentId);
      expect(reopened.syncStatus, LocalSyncStatus.pendingSync);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });
  });
}
