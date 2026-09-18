import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart' show LocalSyncStatus;

part 'app_database.g.dart';

/// Banco local do app.
///
/// O arquivo se chama `simtc.sqlite` — nome diferente do usado pelo scaffold
/// placeholder (`simtc_app_db`), para que aparelhos com a versão antiga
/// instalada não abram um banco sem as tabelas novas.
@DriftDatabase(
  tables: [
    Sessions,
    Participants,
    AssessmentCategories,
    Infractions,
    InfractionNotes,
    LocalAssessments,
    LocalAssessmentItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // O esquema usa chaves estrangeiras (participante → sessão, infração →
          // categoria); no SQLite elas só são aplicadas com este pragma ligado.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() => driftDatabase(name: 'simtc');
}
