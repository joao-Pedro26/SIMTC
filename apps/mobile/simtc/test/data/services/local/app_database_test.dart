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
/// simula o processo sendo morto no meio de uma migração (cada `addColumn` da
/// `AppDatabase` real gera um `ALTER TABLE`).
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

/// A tabela `sessions` exatamente como a Fase 1 a criou (esquema 1).
const String _sessionsV1 = '''
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
''';

/// A tabela `sessions` como a Fase 2 a deixou (esquema 2): a do esquema 1 mais
/// as três contagens.
const String _sessionsV2 = '''
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
    total_participants INTEGER NOT NULL DEFAULT 0,
    assessable_participants INTEGER NOT NULL DEFAULT 0,
    assessed_participants INTEGER NOT NULL DEFAULT 0,
    cached_at INTEGER NOT NULL,
    PRIMARY KEY (id)
  )
''';

/// A tabela `participants` como as Fases 1 e 2 a deixaram — igual nos
/// esquemas 1 e 2, porque só a Fase 3 mexe nela.
const String _participantsV1 = '''
  CREATE TABLE IF NOT EXISTS participants (
    id TEXT NOT NULL,
    session_id TEXT NOT NULL REFERENCES sessions (id),
    name TEXT NOT NULL,
    cpf TEXT NOT NULL,
    email TEXT NULL,
    participation_type TEXT NOT NULL,
    status TEXT NOT NULL,
    assigned_consultant_id TEXT NULL,
    assigned_consultant_name TEXT NULL,
    score REAL NULL,
    cached_at INTEGER NOT NULL,
    PRIMARY KEY (id)
  )
''';

/// A tabela `sessions` como as Fases 3 a 6A a deixaram (esquemas 3 e 4): a do
/// esquema 2 mais o responsável e a hora do download dos participantes.
const String _sessionsV4 = '''
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
    total_participants INTEGER NOT NULL DEFAULT 0,
    assessable_participants INTEGER NOT NULL DEFAULT 0,
    assessed_participants INTEGER NOT NULL DEFAULT 0,
    responsible_consultant_id TEXT NULL,
    participants_synced_at INTEGER NULL,
    cached_at INTEGER NOT NULL,
    PRIMARY KEY (id)
  )
''';

/// A tabela `local_assessments` como a Fase 1 a criou — nenhuma migração
/// mexeu nela até a Fase 5A (esquema 4).
const String _localAssessmentsV3 = '''
  CREATE TABLE IF NOT EXISTS local_assessments (
    id TEXT NOT NULL,
    training_participant_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    date INTEGER NOT NULL,
    start_time INTEGER NOT NULL,
    end_time INTEGER NULL,
    sync_status TEXT NOT NULL,
    last_error TEXT NULL,
    last_attempt_at INTEGER NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (training_participant_id)
  )
''';

void main() {
  late AppDatabase db;

  // Os testes de migração abrem um `AppDatabase` próprio com o do `setUp`
  // ainda aberto. Cada um tem o seu arquivo (ou a sua memória), então o aviso
  // do drift sobre o mesmo banco aberto duas vezes não se aplica — e sujava a
  // saída da suíte.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

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

  group('consultores da sessão', () {
    SessionConsultantsCompanion consultant(String sessionId, String id) {
      return SessionConsultantsCompanion.insert(
        sessionId: sessionId,
        consultantId: id,
        name: 'Carla Mendes',
      );
    }

    test('exigem uma sessão existente e não se repetem na mesma sessão',
        () async {
      await expectLater(
        db.into(db.sessionConsultants).insert(consultant('nao-existe', 'c-1')),
        throwsA(isA<SqliteException>()),
      );

      await insertSession('sess-1');
      await insertSession('sess-2');
      await db.into(db.sessionConsultants).insert(consultant('sess-1', 'c-1'));
      // O mesmo consultor em outra sessão é outra linha.
      await db.into(db.sessionConsultants).insert(consultant('sess-2', 'c-1'));

      await expectLater(
        db.into(db.sessionConsultants).insert(consultant('sess-1', 'c-1')),
        throwsA(isA<SqliteException>()),
      );
    });

    test('somem junto com a sessão, sem ninguém precisar apagá-los antes',
        () async {
      await insertSession('sess-1');
      await insertSession('sess-2');
      await db.into(db.sessionConsultants).insert(consultant('sess-1', 'c-1'));
      await db.into(db.sessionConsultants).insert(consultant('sess-2', 'c-1'));

      await (db.delete(db.sessions)..where((t) => t.id.equals('sess-1'))).go();

      final left = await db.select(db.sessionConsultants).get();
      expect(left.map((r) => r.sessionId), ['sess-2']);
    });

    test('clearSessionsCache não deixa consultor de sessão para trás', () async {
      await insertSession('sess-1');
      await db.into(db.sessionConsultants).insert(consultant('sess-1', 'c-1'));

      await db.clearSessionsCache();

      expect(await db.select(db.sessionConsultants).get(), isEmpty);
      expect(await db.select(db.sessions).get(), isEmpty);
    });

    test('replaceSessionConsultants troca só os da sessão pedida', () async {
      await insertSession('sess-1');
      await insertSession('sess-2');
      await db.into(db.sessionConsultants).insert(consultant('sess-1', 'c-1'));
      await db.into(db.sessionConsultants).insert(consultant('sess-1', 'c-2'));
      await db.into(db.sessionConsultants).insert(consultant('sess-2', 'c-9'));

      await db.replaceSessionConsultants('sess-1', [
        consultant('sess-1', 'c-2'),
        consultant('sess-1', 'c-3'),
      ]);

      final rows = await db.select(db.sessionConsultants).get();
      expect(
        rows.map((r) => (r.sessionId, r.consultantId)).toSet(),
        {('sess-1', 'c-2'), ('sess-1', 'c-3'), ('sess-2', 'c-9')},
      );
    });
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

  test('migra do esquema 1 para o atual mantendo as sessões já cacheadas',
      () async {
    final directory = Directory.systemTemp.createTempSync('simtc_migracao');
    final file = File('${directory.path}/simtc.sqlite');

    final migrated = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          // O banco como a Fase 1 o criou: todas as tabelas existem (a Fase 1
          // criou o esquema inteiro), mas `sessions` ainda sem as contagens,
          // `participants` sem as colunas da Fase 3 e `local_assessments` sem
          // as da Fase 5A.
          raw.execute(_sessionsV1);
          raw.execute(_participantsV1);
          raw.execute(_localAssessmentsV3);
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
    expect(row.responsibleConsultantId, isNull);
    expect(row.participantsSyncedAt, isNull);
  });

  test(
      'migra do esquema 2 para o atual mantendo sessões e participantes já '
      'cacheados', () async {
    final directory = Directory.systemTemp.createTempSync('simtc_migracao_v3');
    final file = File('${directory.path}/simtc.sqlite');

    final migrated = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(_sessionsV2);
          raw.execute(_participantsV1);
          raw.execute(_localAssessmentsV3);
          raw.execute('''
            INSERT INTO sessions (id, company_name, course_name, city, state, status,
                                  total_participants, assessable_participants,
                                  assessed_participants, cached_at)
            VALUES ('sess-1', 'Bracell Celulose', 'Direção Preventiva',
                    'Lençóis Paulista', 'SP', 'EM_ANDAMENTO', 5, 4, 2, 0)
          ''');
          raw.execute('''
            INSERT INTO participants (id, session_id, name, cpf, participation_type,
                                      status, cached_at)
            VALUES ('tp-1', 'sess-1', 'Ana Paula Ribeiro', '042.118.***-**',
                    'TEORICA_E_PRATICA', 'PENDENTE', 0)
          ''');
          raw.execute('PRAGMA user_version = 2');
        },
      ),
    );

    addTearDown(() async {
      await migrated.close();
      directory.deleteSync(recursive: true);
    });

    final session = await migrated.select(migrated.sessions).getSingle();
    expect(session.totalParticipants, 5,
        reason: 'as contagens da Fase 2 sobrevivem à migração');
    expect(session.responsibleConsultantId, isNull);
    expect(session.participantsSyncedAt, isNull);

    final participant =
        await migrated.select(migrated.participants).getSingle();
    expect(participant.name, 'Ana Paula Ribeiro');
    expect(participant.assessedByConsultantId, isNull);
    expect(participant.assessedAt, isNull);
  });

  test(
      'onUpgrade é atômico: uma falha no meio da migração não deixa coluna '
      'já criada nem a versão marcada como migrada', () async {
    final directory = Directory.systemTemp.createTempSync('simtc_migracao_atomica');
    final file = File('${directory.path}/simtc.sqlite');
    addTearDown(() => directory.deleteSync(recursive: true));

    DatabaseSetup rawSetup() => (raw) {
          raw.execute(_sessionsV1);
          raw.execute(_participantsV1);
          raw.execute('PRAGMA user_version = 1');
        };

    /// Abre o `AppDatabase` real — o getter `migration` de produção, sem
    /// nenhuma sobrescrita — sobre um `DatabaseDelegate` que derruba a 2ª
    /// instrução `ALTER TABLE` (a partir do esquema 1 a migração faz dez:
    /// três da Fase 2, quatro da Fase 3 e três da Fase 5A). A 1ª tem sucesso,
    /// a 2ª nunca chega ao SQLite. A abertura (`select`) dispara a migração de
    /// forma preguiçosa.
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

  test(
      'a migração 2→3 também é atômica: uma falha nas colunas de participante '
      'desfaz as de sessão', () async {
    final directory =
        Directory.systemTemp.createTempSync('simtc_migracao_v3_atomica');
    final file = File('${directory.path}/simtc.sqlite');
    addTearDown(() => directory.deleteSync(recursive: true));

    DatabaseSetup rawSetup() => (raw) {
          raw.execute(_sessionsV2);
          raw.execute(_participantsV1);
          raw.execute('PRAGMA user_version = 2');
        };

    /// A migração 2→3 faz quatro `ALTER TABLE`: dois em `sessions` e dois em
    /// `participants`. Derrubar o 3º deixa as duas colunas de sessão já
    /// criadas — só a transação de `onUpgrade` impede que elas fiquem.
    Future<Object> openAndCaptureError() async {
      final realDelegate = NativeDatabase(file, setup: rawSetup()).delegate;
      final executor =
          DelegatedDatabase(_FailOnNthAlterTableDelegate(realDelegate, 3));
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

    final secondError = await openAndCaptureError();
    expect('$secondError', contains('interrompida de propósito'),
        reason: 'sem a transação, a 2ª tentativa quebraria com "duplicate '
            'column name: responsible_consultant_id"');
  });

  test(
      'migra do esquema 3 para o 4 mantendo as avaliações locais — as da Fase '
      '4 ficam sem dono até alguém entrar', () async {
    final directory = Directory.systemTemp.createTempSync('simtc_migracao_v4');
    final file = File('${directory.path}/simtc.sqlite');

    final migrated = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(_localAssessmentsV3);
          raw.execute('''
            INSERT INTO local_assessments (id, training_participant_id, session_id,
                                           date, start_time, end_time, sync_status,
                                           attempt_count, created_at, updated_at)
            VALUES ('la-1', 'tp-1', 'sess-1', 1758600000, 1758610000, 1758611000,
                    'pendingSync', 0, 1758610000, 1758611000)
          ''');
          raw.execute('PRAGMA user_version = 3');
        },
      ),
    );

    addTearDown(() async {
      await migrated.close();
      directory.deleteSync(recursive: true);
    });

    final row = await migrated.select(migrated.localAssessments).getSingle();

    expect(row.trainingParticipantId, 'tp-1');
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
    expect(row.endTime, DateTime.fromMillisecondsSinceEpoch(1758611000 * 1000));
    expect(row.ownerUserId, isNull);
    expect(row.participantName, isNull);
    expect(row.score, isNull);
  });

  test(
      'a migração 3→4 também é atômica: uma falha na última coluna desfaz as '
      'anteriores', () async {
    final directory =
        Directory.systemTemp.createTempSync('simtc_migracao_v4_atomica');
    final file = File('${directory.path}/simtc.sqlite');
    addTearDown(() => directory.deleteSync(recursive: true));

    DatabaseSetup rawSetup() => (raw) {
          raw.execute(_localAssessmentsV3);
          raw.execute('PRAGMA user_version = 3');
        };

    /// A migração 3→4 faz três `ALTER TABLE` em `local_assessments`. Derrubar
    /// o 3º deixa as duas primeiras colunas já criadas — só a transação de
    /// `onUpgrade` impede que elas fiquem.
    Future<Object> openAndCaptureError() async {
      final realDelegate = NativeDatabase(file, setup: rawSetup()).delegate;
      final executor =
          DelegatedDatabase(_FailOnNthAlterTableDelegate(realDelegate, 3));
      final db = AppDatabase(executor);
      try {
        await db.select(db.localAssessments).get();
        fail('esperava que a migração falhasse de propósito');
      } catch (error) {
        return error;
      } finally {
        await db.close();
      }
    }

    final firstError = await openAndCaptureError();
    expect('$firstError', contains('interrompida de propósito'));

    final secondError = await openAndCaptureError();
    expect('$secondError', contains('interrompida de propósito'),
        reason: 'sem a transação, a 2ª tentativa quebraria com "duplicate '
            'column name: owner_user_id"');
  });

  test(
      'migra do esquema 4 para o 5 criando a tabela de consultores da sessão, '
      'sem mexer nas sessões já cacheadas', () async {
    final directory = Directory.systemTemp.createTempSync('simtc_migracao_v5');
    final file = File('${directory.path}/simtc.sqlite');

    final migrated = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(_sessionsV4);
          raw.execute('''
            INSERT INTO sessions (id, company_name, course_name, city, state,
                                  status, responsible_consultant_id, cached_at)
            VALUES ('sess-1', 'Bracell', 'Direção Defensiva', 'Itabira', 'MG',
                    'EM_ANDAMENTO', 'c-1', 1758600000)
          ''');
          raw.execute('PRAGMA user_version = 4');
        },
      ),
    );

    addTearDown(() async {
      await migrated.close();
      directory.deleteSync(recursive: true);
    });

    // A tabela nova nasce vazia: o próximo download do detalhe a preenche.
    expect(await migrated.select(migrated.sessionConsultants).get(), isEmpty);

    final session = await migrated.select(migrated.sessions).getSingle();
    expect(session.companyName, 'Bracell');
    expect(session.responsibleConsultantId, 'c-1');

    await migrated.into(migrated.sessionConsultants).insert(
          SessionConsultantsCompanion.insert(
            sessionId: 'sess-1',
            consultantId: 'c-1',
            name: 'Carla Mendes',
          ),
        );
    final row = await migrated.select(migrated.sessionConsultants).getSingle();
    expect(row.name, 'Carla Mendes');
    expect(row.email, isNull);
  });
}
