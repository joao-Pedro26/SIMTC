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
    SessionConsultants,
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
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // `onUpgrade` do drift não roda em transação por conta própria — o
          // `user_version` só é gravado depois que ele termina (ver
          // `_runMigrations` em drift/src/runtime/executor/helpers/
          // engines.dart). Sem este `transaction()`, o Android matando o app
          // entre dois `addColumn` deixaria o arquivo com a versão antiga e
          // uma coluna já criada; na abertura seguinte o `addColumn`
          // estouraria "duplicate column name" e o app não abriria o banco
          // nunca mais. Uma transação só para todos os passos torna a
          // migração tudo-ou-nada — inclusive para quem pula do esquema 1
          // direto para o atual.
          await transaction(() async {
            if (from < 2) {
              // Fase 2: contagens de participantes no card da Home. São cache
              // — entram com 0 e o primeiro sync preenche. Migrar por
              // `addColumn` (e não recriando a tabela) preserva a lista que o
              // consultor já tem no aparelho, que é o que ele vê offline.
              await m.addColumn(sessions, sessions.totalParticipants);
              await m.addColumn(sessions, sessions.assessableParticipants);
              await m.addColumn(sessions, sessions.assessedParticipants);
            }
            if (from < 3) {
              // Fase 3: quem pode iniciar a sessão, quando os participantes
              // dela foram baixados, e quem avaliou cada participante e
              // quando. Tudo anulável — o próximo sync preenche.
              await m.addColumn(sessions, sessions.responsibleConsultantId);
              await m.addColumn(sessions, sessions.participantsSyncedAt);
              await m.addColumn(
                participants,
                participants.assessedByConsultantId,
              );
              await m.addColumn(participants, participants.assessedAt);
            }
            if (from < 4) {
              // Fase 5A: dono, nome do participante e % de cada avaliação
              // local. Anuláveis: as avaliações da Fase 4 que já estão no
              // aparelho ficam com o primeiro usuário que entrar.
              await m.addColumn(localAssessments, localAssessments.ownerUserId);
              await m.addColumn(
                localAssessments,
                localAssessments.participantName,
              );
              await m.addColumn(localAssessments, localAssessments.score);
            }
            if (from < 5) {
              // Fase 6B: os consultores de cada sessão, para a tela
              // "Consultores" e o "N consultores" do detalhe abrirem offline.
              // Tabela nova e vazia: o próximo download do detalhe a preenche.
              await m.createTable(sessionConsultants);
            }
          });
        },
        beforeOpen: (details) async {
          // O esquema usa chaves estrangeiras (participante → sessão, infração →
          // categoria); no SQLite elas só são aplicadas com este pragma ligado.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() => driftDatabase(name: 'simtc');

  /// Apaga o cache de sessões e participantes (os consultores de cada sessão
  /// vão junto, pela chave estrangeira em cascata).
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

  /// "Limpar cache local" do Perfil (Fase 8A): apaga o que foi baixado do
  /// servidor — sessões, participantes, consultores e catálogo —, sem tocar
  /// na fila nem nos rascunhos.
  Future<void> clearDownloadedData() {
    return transaction(() async {
      await delete(sessionConsultants).go();
      await delete(participants).go();
      await delete(sessions).go();
      // Notas antes das infrações, e infrações antes das categorias: a mesma
      // ordem das chaves estrangeiras.
      await delete(infractionNotes).go();
      await delete(infractions).go();
      await delete(assessmentCategories).go();
    });
  }

  /// Apaga tudo, inclusive a fila e os rascunhos: a troca de servidor
  /// (decisão de 24/10/2026, ver `DeviceDataService.resetIfServerChanged`).
  Future<void> clearAll() {
    return transaction(() async {
      await delete(localAssessmentItems).go();
      await delete(localAssessments).go();
      await clearDownloadedData();
    });
  }

  /// O espaço que o banco ocupa, em bytes, sem as páginas livres: depois de
  /// um [clearDownloadedData], o número cai sem precisar de `VACUUM`.
  Future<int> usedBytes() async {
    Future<int> pragma(String name) async {
      final row = await customSelect('PRAGMA $name').getSingle();
      return row.read<int>(name);
    }

    final pages = await pragma('page_count') - await pragma('freelist_count');
    return pages * await pragma('page_size');
  }

  /// Troca os consultores de uma sessão no cache pelos de [rows] (Fase 6B).
  ///
  /// Tem transação própria, e entra na de quem chama quando há uma aberta: o
  /// detalhe da sessão grava participantes e consultores de uma vez só.
  Future<void> replaceSessionConsultants(
    String sessionId,
    Iterable<SessionConsultantsCompanion> rows,
  ) {
    return transaction(() async {
      await (delete(sessionConsultants)
            ..where((t) => t.sessionId.equals(sessionId)))
          .go();
      for (final row in rows) {
        await into(sessionConsultants).insert(row);
      }
    });
  }
}
