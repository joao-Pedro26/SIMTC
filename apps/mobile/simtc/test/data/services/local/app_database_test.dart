// `isNull` é escondido de propósito: `package:drift/drift.dart` exporta uma
// função top-level deprecated com esse nome, que conflita com o matcher
// `isNull` de `package:flutter_test` (erro `ambiguous_import`). O teste de
// atomicidade da migração abaixo precisa de `DatabaseDelegate` e companhia
// (`package:drift/backends.dart`, a API para escrever backends/testes de
// baixo nível) — `package:drift/native.dart` não os reexporta.
import 'dart:async';
import 'dart:io';

import 'package:drift/backends.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/services/local/app_database.dart';

/// Derruba a enésima instrução `ALTER TABLE` antes que ela chegue ao SQLite —
/// simula o processo sendo morto no meio da migração 1→2 (a `addColumn` da
/// `AppDatabase` real gera três `ALTER TABLE`, um por coluna nova).
///
/// Onde a falha é injetada, e por quê: um `QueryInterceptor` em volta do
/// `QueryExecutor` (a rota sugerida à primeira vista) **não funciona aqui** —
/// drift roda `beforeOpen`/`onUpgrade` direto contra o `DatabaseDelegate` do
/// engine (`DelegatedDatabase._runMigrations` monta um `_BeforeOpeningExecutor`
/// que lê `delegate` por baixo do `QueryExecutor` de fora), então um
/// interceptor de `QueryExecutor` nunca vê as instruções da migração —
/// confirmado empiricamente: um interceptor desse tipo não disparou nem uma
/// vez durante a migração. `DatabaseDelegate.runCustom` é o único ponto por
/// onde toda e qualquer instrução passa, dentro ou fora de `beforeOpen`,
/// dentro ou fora de transação — por isso a falha é injetada aqui, envolvendo
/// o `DatabaseDelegate` real do `NativeDatabase` (campo público
/// `delegate`), sem tocar no getter `migration` de `AppDatabase`.
class _FailOnNthAlterTableDelegate extends DatabaseDelegate {
  _FailOnNthAlterTableDelegate(this._inner, this._failOnNth);

  final DatabaseDelegate _inner;
  final int _failOnNth;
  int _alterTableCount = 0;

  @override
  DbVersionDelegate get versionDelegate => _inner.versionDelegate;

  @override
  TransactionDelegate get transactionDelegate => _inner.transactionDelegate;

  @override
  FutureOr<bool> get isOpen => _inner.isOpen;

  @override
  Future<void> open(QueryExecutorUser db) => _inner.open(db);

  @override
  Future<void> close() => _inner.close();

  @override
  void notifyDatabaseOpened(OpeningDetails details) =>
      _inner.notifyDatabaseOpened(details);

  @override
  Future<QueryResult> runSelect(String statement, List<Object?> args) =>
      _inner.runSelect(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      _inner.runUpdate(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      _inner.runInsert(statement, args);

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _inner.runBatched(statements);

  @override
  Future<void> runCustom(String statement, List<Object?> args) {
    if (statement.startsWith('ALTER TABLE')) {
      _alterTableCount++;
      if (_alterTableCount == _failOnNth) {
        throw StateError(
          'migração interrompida de propósito (teste, injetada no DatabaseDelegate)',
        );
      }
    }
    return _inner.runCustom(statement, args);
  }
}

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

  test('migra do esquema 1 para o 2 mantendo as sessões já cacheadas', () async {
    final directory = Directory.systemTemp.createTempSync('simtc_migracao');
    final file = File('${directory.path}/simtc.sqlite');

    final migrated = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          // A tabela `sessions` exatamente como a Fase 1 a criou.
          raw.execute('''
            CREATE TABLE IF NOT EXISTS sessions (
              id TEXT NOT NULL,
              company_name TEXT NOT NULL,
              company_logo_url TEXT NULL,
              course_name TEXT NOT NULL,
              city TEXT NOT NULL,
              state TEXT NOT NULL,
              date INTEGER NULL,
              status TEXT NOT NULL,
              notes TEXT NULL,
              cached_at INTEGER NOT NULL,
              PRIMARY KEY (id)
            )
          ''');
          raw.execute('''
            INSERT INTO sessions (id, company_name, course_name, city, state, status, cached_at)
            VALUES ('sess-antiga', 'Bracell Celulose', 'Direção Preventiva',
                    'Lençóis Paulista', 'SP', 'PLANEJADO', 0)
          ''');
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );

    addTearDown(() async {
      await migrated.close();
      directory.deleteSync(recursive: true);
    });

    final row = await migrated.select(migrated.sessions).getSingle();

    expect(row.id, 'sess-antiga');
    expect(row.companyName, 'Bracell Celulose');
    expect(row.totalParticipants, 0);
    expect(row.assessableParticipants, 0);
    expect(row.assessedParticipants, 0);
  });

  test(
      'onUpgrade é atômico: uma falha no meio da migração não deixa coluna '
      'já criada nem a versão marcada como migrada', () async {
    final directory = Directory.systemTemp.createTempSync('simtc_migracao_atomica');
    final file = File('${directory.path}/simtc.sqlite');
    addTearDown(() => directory.deleteSync(recursive: true));

    DatabaseSetup rawSetup() => (raw) {
          raw.execute('''
            CREATE TABLE IF NOT EXISTS sessions (
              id TEXT NOT NULL,
              company_name TEXT NOT NULL,
              company_logo_url TEXT NULL,
              course_name TEXT NOT NULL,
              city TEXT NOT NULL,
              state TEXT NOT NULL,
              date INTEGER NULL,
              status TEXT NOT NULL,
              notes TEXT NULL,
              cached_at INTEGER NOT NULL,
              PRIMARY KEY (id)
            )
          ''');
          raw.execute('PRAGMA user_version = 1');
        };

    /// Abre o `AppDatabase` real — o getter `migration` de produção, sem
    /// nenhuma sobrescrita — sobre um `DatabaseDelegate` que derruba a 2ª
    /// instrução `ALTER TABLE` (a migração real faz 3, uma por coluna nova).
    /// A 1ª tem sucesso, a 2ª nunca chega ao SQLite. A abertura (`select`)
    /// dispara a migração de forma preguiçosa.
    Future<Object> openAndCaptureError() async {
      final realDelegate = NativeDatabase(file, setup: rawSetup()).delegate;
      final executor =
          DelegatedDatabase(_FailOnNthAlterTableDelegate(realDelegate, 2));
      final db = AppDatabase(executor);
      try {
        await db.select(db.sessions).get();
        fail('esperava que a migração falhasse de propósito');
      } catch (error) {
        return error;
      } finally {
        await db.close();
      }
    }

    final firstError = await openAndCaptureError();
    expect('$firstError', contains('interrompida de propósito'));

    // Reabrir sobre o MESMO arquivo com um novo `_FailOnNthAlterTableDelegate`
    // (contagem do zero): se a primeira tentativa tivesse deixado a primeira
    // coluna já criada fora de uma transação (o bug original — `addColumn`
    // sem `transaction()`), esta segunda tentativa quebraria com "duplicate
    // column name" ao tentar recriar a mesma coluna, em vez do erro
    // proposital de novo. O mesmo erro nas duas vezes prova que nada da
    // tentativa anterior sobrou: nem a coluna, nem a versão do esquema.
    //
    // A falha é injetada de fora do getter `migration` — quem está sob teste
    // é o `migration` real de `AppDatabase`, sem cópia nem sobrescrita.
    // Verificado manualmente: reverter o `transaction()` em
    // `app_database.dart` faz este `secondError` virar "duplicate column
    // name: total_participants" e a asserção abaixo falhar; devolvê-lo faz
    // o teste passar de novo.
    final secondError = await openAndCaptureError();
    expect('$secondError', contains('interrompida de propósito'),
        reason: 'se a 1ª tentativa tivesse deixado a coluna já criada fora '
            'de uma transação, esta falharia com "duplicate column name"');
  });
}
