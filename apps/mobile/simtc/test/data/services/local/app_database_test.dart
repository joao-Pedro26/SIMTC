// `package:drift/drift.dart` não é importado aqui de propósito: ele exporta
// uma função top-level deprecated chamada `isNull` que conflita com o
// matcher `isNull` de `package:flutter_test` (erro `ambiguous_import`), e
// nada deste arquivo precisa de um símbolo exclusivo dele — `NativeDatabase`
// e `SqliteException` já vêm de `package:drift/native.dart`.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/services/local/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insertSession(String id) {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: id,
            companyName: 'Bracell Celulose',
            courseName: 'Direção Preventiva',
            city: 'Lençóis Paulista',
            state: 'SP',
            status: 'EM_ANDAMENTO',
            cachedAt: DateTime(2026, 9, 17, 8),
          ),
        );
  }

  test('grava e lê uma sessão do cache', () async {
    await insertSession('sess-1');

    final rows = await db.select(db.sessions).get();
    expect(rows, hasLength(1));
    expect(rows.single.companyName, 'Bracell Celulose');
    expect(rows.single.date, isNull);
  });

  test('participante exige uma sessão existente (chave estrangeira ativa)', () async {
    expect(
      () => db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-1',
              sessionId: 'sessao-inexistente',
              name: 'João Pedro',
              cpf: '12345678909',
              participationType: 'TEORICA_E_PRATICA',
              status: 'PENDENTE',
              cachedAt: DateTime(2026, 9, 17, 8),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('avaliação local guarda o status de sincronização como enum', () async {
    await db.into(db.localAssessments).insert(
          LocalAssessmentsCompanion.insert(
            id: 'local-1',
            trainingParticipantId: 'tp-1',
            sessionId: 'sess-1',
            date: DateTime(2026, 9, 17),
            startTime: DateTime(2026, 9, 17, 9, 30),
            syncStatus: LocalSyncStatus.draft,
            createdAt: DateTime(2026, 9, 17, 9, 30),
            updatedAt: DateTime(2026, 9, 17, 9, 30),
          ),
        );

    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.draft);
    expect(row.attemptCount, 0);
  });

  test('um participante não pode ter duas avaliações locais', () async {
    Future<void> insert(String id) {
      return db.into(db.localAssessments).insert(
            LocalAssessmentsCompanion.insert(
              id: id,
              trainingParticipantId: 'tp-1',
              sessionId: 'sess-1',
              date: DateTime(2026, 9, 17),
              startTime: DateTime(2026, 9, 17, 9, 30),
              syncStatus: LocalSyncStatus.draft,
              createdAt: DateTime(2026, 9, 17, 9, 30),
              updatedAt: DateTime(2026, 9, 17, 9, 30),
            ),
          );
    }

    await insert('local-1');
    expect(() => insert('local-2'), throwsA(isA<SqliteException>()));
  });

  test('uma infração só pode ter uma nota marcada por avaliação', () async {
    await db.into(db.localAssessments).insert(
          LocalAssessmentsCompanion.insert(
            id: 'local-1',
            trainingParticipantId: 'tp-1',
            sessionId: 'sess-1',
            date: DateTime(2026, 9, 17),
            startTime: DateTime(2026, 9, 17, 9, 30),
            syncStatus: LocalSyncStatus.draft,
            createdAt: DateTime(2026, 9, 17, 9, 30),
            updatedAt: DateTime(2026, 9, 17, 9, 30),
          ),
        );

    Future<void> mark(String id, String noteId) {
      return db.into(db.localAssessmentItems).insert(
            LocalAssessmentItemsCompanion.insert(
              id: id,
              localAssessmentId: 'local-1',
              infractionId: 'inf-1',
              infractionNoteId: noteId,
              updatedAt: DateTime(2026, 9, 17, 9, 35),
            ),
          );
    }

    await mark('item-1', 'note-b');
    expect(() => mark('item-2', 'note-m'), throwsA(isA<SqliteException>()));
  });
}
