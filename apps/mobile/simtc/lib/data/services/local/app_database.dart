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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Fase 2: contagens de participantes no card da Home. São cache —
            // entram com 0 e o primeiro sync preenche. Migrar por `addColumn`
            // (e não recriando a tabela) preserva a lista que o consultor já
            // tem no aparelho, que é o que ele vê ao abrir o app offline.
            //
            // `onUpgrade` do drift não roda em transação por conta própria —
            // o `user_version` só é gravado depois que ele termina (ver
            // `_runMigrations` em drift/src/runtime/executor/helpers/
            // engines.dart). Sem este `transaction()`, o Android matando o
            // app entre o 1º e o 2º `addColumn` deixaria o arquivo com
            // `user_version = 1` e uma coluna já criada; na abertura
            // seguinte o `addColumn` estouraria "duplicate column name" e o
            // app não abriria o banco nunca mais. Envolver em `transaction`
            // torna a migração tudo-ou-nada: uma falha no meio desfaz as
            // colunas já adicionadas e o app tenta migrar de novo na
            // próxima abertura.
            await transaction(() async {
              await m.addColumn(sessions, sessions.totalParticipants);
              await m.addColumn(sessions, sessions.assessableParticipants);
              await m.addColumn(sessions, sessions.assessedParticipants);
            });
          }
        },
        beforeOpen: (details) async {
          // O esquema usa chaves estrangeiras (participante → sessão, infração →
          // categoria); no SQLite elas só são aplicadas com este pragma ligado.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() => driftDatabase(name: 'simtc');

  /// Apaga o cache de sessões e participantes.
  ///
  /// Chamado ao trocar de consultor (logout ou expiração do refresh token):
  /// `watchSessions()` não tem escopo de usuário, então sem isto a Home do
  /// próximo consultor a entrar mostraria a agenda do anterior — offline, por
  /// tempo indefinido — até o primeiro sync.
  Future<void> clearSessionsCache() {
    return transaction(() async {
      // Participantes têm FK para a sessão: apagar antes deles evita violar
      // a restrição, mesma ordem usada em `SessionRepository._write`.
      await delete(participants).go();
      await delete(sessions).go();
    });
  }
}
