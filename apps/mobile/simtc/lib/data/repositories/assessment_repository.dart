import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../services/local/app_database.dart';

/// A avaliação prática rascunhada no aparelho (Fase 4 — Checklist).
///
/// Só fala com o `AppDatabase`: não há chamada de rede aqui. O envio ao
/// backend (a fila de `pendingSync`) é de uma fase futura — esta classe só
/// precisa deixar a avaliação pronta e completa no aparelho, mesmo sem sinal.
class AssessmentRepository {
  AssessmentRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  /// Abre o rascunho da avaliação do participante, retomando o que já existe
  /// (`trainingParticipantId` é chave única) em vez de recriar — o consultor
  /// pode ter saído do checklist e voltado antes do próximo sync. Devolve a
  /// linha (a tela lê `startTime` dela para o cronômetro).
  ///
  /// `date` é a data de calendário da sessão (como `TrainingSession.date`,
  /// meia-noite local); sessão sem data, ou fora do cache, usa a de hoje.
  Future<LocalAssessment> openDraft({
    required String trainingParticipantId,
    required String sessionId,
  }) async {
    final existing = await (_db.select(_db.localAssessments)
          ..where(
              (t) => t.trainingParticipantId.equals(trainingParticipantId)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final session = await (_db.select(_db.sessions)
          ..where((t) => t.id.equals(sessionId)))
        .getSingleOrNull();
    final id = _uuid.v4();
    final now = DateTime.now();
    final companion = LocalAssessmentsCompanion.insert(
      id: id,
      trainingParticipantId: trainingParticipantId,
      sessionId: sessionId,
      date: session?.date ?? DateTime(now.year, now.month, now.day),
      startTime: now,
      syncStatus: LocalSyncStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.localAssessments).insert(companion);
    return await (_db.select(_db.localAssessments)
          ..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Marcações da avaliação — uma linha por infração marcada. A tela junta
  /// isto com o catálogo (`AssessmentCatalogRepository.loadCatalog`) para
  /// montar as seções do acordeão.
  Stream<List<LocalAssessmentItem>> watchItems(String localAssessmentId) {
    final query = _db.select(_db.localAssessmentItems)
      ..where((t) => t.localAssessmentId.equals(localAssessmentId));
    return query.watch();
  }

  /// Marca (ou troca) a nota de uma infração — uma infração tem no máximo
  /// uma nota selecionada por vez, garantido pela chave única
  /// (`localAssessmentId`, `infractionId`): a troca é um upsert numa
  /// instrução só, sem janela entre ler e gravar.
  ///
  /// Devolve as marcações atualizadas: quem escreve não espera o `watchItems`
  /// para saber o resultado da própria escrita (o stream de uma assinatura já
  /// aberta pode notificar um turno de evento depois).
  Future<List<LocalAssessmentItem>> mark({
    required String localAssessmentId,
    required String infractionId,
    required String infractionNoteId,
  }) async {
    final now = DateTime.now();
    final items = _db.localAssessmentItems;
    await _db.into(items).insert(
          LocalAssessmentItemsCompanion.insert(
            id: _uuid.v4(),
            localAssessmentId: localAssessmentId,
            infractionId: infractionId,
            infractionNoteId: infractionNoteId,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => LocalAssessmentItemsCompanion(
              infractionNoteId: Value(infractionNoteId),
              updatedAt: Value(now),
            ),
            target: [items.localAssessmentId, items.infractionId],
          ),
        );
    return _itemsOf(localAssessmentId);
  }

  /// Desmarca a infração — o mesmo botão apertado de novo tira a nota.
  /// Mesma razão do `mark` para devolver a lista, em vez de `void`.
  Future<List<LocalAssessmentItem>> unmark({
    required String localAssessmentId,
    required String infractionId,
  }) async {
    await (_db.delete(_db.localAssessmentItems)
          ..where((t) =>
              t.localAssessmentId.equals(localAssessmentId) &
              t.infractionId.equals(infractionId)))
        .go();
    return _itemsOf(localAssessmentId);
  }

  Future<List<LocalAssessmentItem>> _itemsOf(String localAssessmentId) {
    return (_db.select(_db.localAssessmentItems)
          ..where((t) => t.localAssessmentId.equals(localAssessmentId)))
        .get();
  }

  /// Finaliza a avaliação: grava `endTime` e põe na fila de envio. Não sobe
  /// nada agora — só marca o rascunho como pronto para a próxima fase enviar.
  Future<void> finish(String localAssessmentId) {
    final now = DateTime.now();
    return (_db.update(_db.localAssessments)
          ..where((t) => t.id.equals(localAssessmentId)))
        .write(
      LocalAssessmentsCompanion(
        endTime: Value(now),
        syncStatus: const Value(LocalSyncStatus.pendingSync),
        updatedAt: Value(now),
      ),
    );
  }
}
