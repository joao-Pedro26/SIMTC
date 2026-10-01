import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../services/local/app_database.dart';

/// A avaliação prática feita no aparelho: o rascunho do checklist (Fase 4) e
/// a fila de envio (Fase 5A).
///
/// Só fala com o `AppDatabase`: quem sobe a fila para o backend é o
/// `AssessmentSyncService`, que usa os métodos da fila daqui para ler o que
/// enviar e gravar o resultado de cada envio.
class AssessmentRepository {
  AssessmentRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  /// Situações de quem já confirmou e espera o backend aceitar.
  static const List<LocalSyncStatus> _queued = [
    LocalSyncStatus.pendingSync,
    LocalSyncStatus.error,
  ];

  /// A avaliação em andamento de [ownerUserId] para o participante, ou nula
  /// se ela ainda não foi iniciada — o checklist abre sem gravar nada e mostra
  /// o "Iniciar avaliação" (decisão de 29/09/2026).
  ///
  /// Dois casos contam como não iniciada, mesmo com uma linha no banco, porque
  /// o "Iniciar" começa um rascunho novo no lugar dela (ver [openDraft]):
  /// - a avaliação já foi enviada (`synced`): é uma reavaliação — inclusive
  ///   uma atribuição refeita pelo painel web;
  /// - o rascunho é de outro consultor: num aparelho compartilhado, quem
  ///   pegou o participante agora não herda as marcações de quem saiu.
  ///
  /// Uma avaliação na fila (`pendingSync`/`error`) é sempre devolvida: ela é
  /// de alguém que confirmou e só espera o envio. Um rascunho sem dono (de
  /// antes da Fase 5A) passa a ser de [ownerUserId], com as marcações.
  Future<LocalAssessment?> findCurrent({
    required String trainingParticipantId,
    required String ownerUserId,
  }) async {
    final existing = await findByParticipant(trainingParticipantId);
    if (existing == null || _startsOver(existing, ownerUserId)) return null;
    if (existing.ownerUserId != null) return existing;
    await (_db.update(_db.localAssessments)
          ..where((t) => t.id.equals(existing.id)))
        .write(LocalAssessmentsCompanion(ownerUserId: Value(ownerUserId)));
    return existing.copyWith(ownerUserId: Value(ownerUserId));
  }

  /// "Iniciar avaliação": cria o rascunho de [ownerUserId] com `startTime`
  /// agora — o cronômetro e a duração enviada contam a partir daqui. Se a
  /// avaliação já está em andamento ([findCurrent]), devolve a mesma, sem
  /// recomeçar: um segundo toque não zera o cronômetro.
  ///
  /// `date` é a data de calendário da sessão (como `TrainingSession.date`,
  /// meia-noite local); sessão sem data, ou fora do cache, usa a de hoje.
  Future<LocalAssessment> openDraft({
    required String trainingParticipantId,
    required String sessionId,
    required String ownerUserId,
  }) async {
    final current = await findCurrent(
      trainingParticipantId: trainingParticipantId,
      ownerUserId: ownerUserId,
    );
    if (current != null) return current;

    final existing = await findByParticipant(trainingParticipantId);
    final session = await (_db.select(_db.sessions)
          ..where((t) => t.id.equals(sessionId)))
        .getSingleOrNull();
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.transaction(() async {
      if (existing != null) await _delete(existing.id);
      await _db.into(_db.localAssessments).insert(
            LocalAssessmentsCompanion.insert(
              id: id,
              trainingParticipantId: trainingParticipantId,
              sessionId: sessionId,
              date: session?.date ?? DateTime(now.year, now.month, now.day),
              startTime: now,
              syncStatus: LocalSyncStatus.draft,
              createdAt: now,
              updatedAt: now,
              ownerUserId: Value(ownerUserId),
            ),
          );
    });
    return await (_db.select(_db.localAssessments)
          ..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Ver [findCurrent]: avaliação já enviada, ou rascunho de outro consultor.
  static bool _startsOver(LocalAssessment existing, String ownerUserId) {
    return switch (existing.syncStatus) {
      LocalSyncStatus.synced => true,
      LocalSyncStatus.draft =>
        existing.ownerUserId != null && existing.ownerUserId != ownerUserId,
      LocalSyncStatus.pendingSync || LocalSyncStatus.error => false,
    };
  }

  Future<void> _delete(String localAssessmentId) async {
    await (_db.delete(_db.localAssessmentItems)
          ..where((t) => t.localAssessmentId.equals(localAssessmentId)))
        .go();
    await (_db.delete(_db.localAssessments)
          ..where((t) => t.id.equals(localAssessmentId)))
        .go();
  }

  /// A avaliação local do participante, em qualquer situação, ou nula.
  Future<LocalAssessment?> findByParticipant(String trainingParticipantId) {
    return (_db.select(_db.localAssessments)
          ..where(
              (t) => t.trainingParticipantId.equals(trainingParticipantId)))
        .getSingleOrNull();
  }

  /// Marcações da avaliação — uma linha por infração marcada. A tela junta
  /// isto com o catálogo (`AssessmentCatalogRepository.loadCatalog`) para
  /// montar as seções do acordeão.
  Stream<List<LocalAssessmentItem>> watchItems(String localAssessmentId) {
    final query = _db.select(_db.localAssessmentItems)
      ..where((t) => t.localAssessmentId.equals(localAssessmentId));
    return query.watch();
  }

  /// As mesmas marcações de [watchItems], lidas uma vez.
  Future<List<LocalAssessmentItem>> loadItems(String localAssessmentId) {
    return (_db.select(_db.localAssessmentItems)
          ..where((t) => t.localAssessmentId.equals(localAssessmentId)))
        .get();
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
    return loadItems(localAssessmentId);
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
    return loadItems(localAssessmentId);
  }

  /// "Confirmar" da tela 1.6: grava `endTime` (o fim que a tela mostrou, ou a
  /// hora do toque se nenhum for dado), o nome do participante e o % que a
  /// tela mostrou, e põe a avaliação na fila de envio. Quem sobe é o
  /// `AssessmentSyncService`, que observa a fila.
  Future<void> confirm(
    String localAssessmentId, {
    required String? participantName,
    required double score,
    DateTime? endTime,
  }) {
    final now = DateTime.now();
    return (_db.update(_db.localAssessments)
          ..where((t) => t.id.equals(localAssessmentId)))
        .write(
      LocalAssessmentsCompanion(
        endTime: Value(endTime ?? now),
        participantName: Value(participantName),
        score: Value(score),
        syncStatus: const Value(LocalSyncStatus.pendingSync),
        lastError: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  /// A fila de envio de [ownerUserId]: as avaliações confirmadas que o
  /// backend ainda não aceitou (`pendingSync` e `error`), na ordem em que
  /// foram confirmadas.
  Stream<List<LocalAssessment>> watchQueue(String ownerUserId) =>
      _queueOf(ownerUserId).watch();

  /// A mesma fila de [watchQueue], lida uma vez — é o que o envio manda.
  Future<List<LocalAssessment>> loadQueue(String ownerUserId) =>
      _queueOf(ownerUserId).get();

  SimpleSelectStatement<$LocalAssessmentsTable, LocalAssessment> _queueOf(
    String ownerUserId,
  ) {
    return _db.select(_db.localAssessments)
      ..where((t) =>
          t.ownerUserId.equals(ownerUserId) & t.syncStatus.isInValues(_queued))
      ..orderBy([(t) => OrderingTerm.asc(t.endTime)]);
  }

  /// As avaliações de [ownerUserId] numa sessão, em qualquer situação — o
  /// detalhe da sessão mostra com elas o cronômetro do rascunho e o chip
  /// "Na fila"/"Erro no envio".
  Stream<List<LocalAssessment>> watchSessionAssessments(
    String sessionId,
    String ownerUserId,
  ) {
    return (_db.select(_db.localAssessments)
          ..where((t) =>
              t.sessionId.equals(sessionId) &
              t.ownerUserId.equals(ownerUserId)))
        .watch();
  }

  /// Dá a [ownerUserId] as avaliações sem dono — as que a Fase 4 deixou no
  /// aparelho antes de existir a coluna (decisão de 29/09/2026: ficam com o
  /// primeiro usuário que entrar). O nome do participante vem do cache, se
  /// ele ainda estiver lá.
  Future<void> claimUnowned(String ownerUserId) {
    return _db.transaction(() async {
      final unowned = await (_db.select(_db.localAssessments)
            ..where((t) => t.ownerUserId.isNull()))
          .get();
      for (final row in unowned) {
        final participant = await (_db.select(_db.participants)
              ..where((t) => t.id.equals(row.trainingParticipantId)))
            .getSingleOrNull();
        await (_db.update(_db.localAssessments)
              ..where((t) => t.id.equals(row.id)))
            .write(
          LocalAssessmentsCompanion(
            ownerUserId: Value(ownerUserId),
            participantName: Value(row.participantName ?? participant?.name),
          ),
        );
      }
    });
  }

  /// Corpo do `POST /practical-assessments/sync` para [assessments], no
  /// mesmo formato que o painel web manda (`assessment-drawer.tsx`):
  /// - `date` como `AAAA-MM-DD`, a data de calendário da avaliação;
  /// - `startTime` e `endTime` em ISO UTC;
  /// - `items` só com as notas que existem no catálogo do aparelho, na
  ///   infração em que foram marcadas.
  ///
  /// Uma marcação que ficou órfã por mudança no catálogo não vai: é o que o
  /// checklist e a tela 1.6 mostraram, e o que o consultor confirmou
  /// (`buildChecklistSections` ignora as mesmas marcações).
  Future<List<Map<String, dynamic>>> syncPayload(
    List<LocalAssessment> assessments,
  ) async {
    final notes = await _db.select(_db.infractionNotes).get();
    final infractionOfNote = {for (final note in notes) note.id: note.infractionId};

    final payload = <Map<String, dynamic>>[];
    for (final assessment in assessments) {
      final items = await loadItems(assessment.id);
      final endTime = assessment.endTime;
      payload.add({
        'trainingParticipantId': assessment.trainingParticipantId,
        'date': _calendarDate(assessment.date),
        'startTime': assessment.startTime.toUtc().toIso8601String(),
        if (endTime != null) 'endTime': endTime.toUtc().toIso8601String(),
        'items': [
          for (final item in items)
            if (infractionOfNote[item.infractionNoteId] == item.infractionId)
              {'infractionNoteId': item.infractionNoteId},
        ],
      });
    }
    return payload;
  }

  /// Grava o resultado de um envio numa transação só, para a fila mudar de
  /// uma vez: `null` em [results] é "aceita pelo backend" (sai da fila); um
  /// texto é o motivo da falha, que a aba Sincronizar mostra.
  Future<void> saveSendResults(
    Map<String, String?> results, {
    required DateTime at,
  }) {
    return _db.transaction(() async {
      for (final MapEntry(key: id, value: failure) in results.entries) {
        final row = await (_db.select(_db.localAssessments)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (row == null) continue;
        await (_db.update(_db.localAssessments)
              ..where((t) => t.id.equals(id)))
            .write(
          LocalAssessmentsCompanion(
            syncStatus: Value(
              failure == null ? LocalSyncStatus.synced : LocalSyncStatus.error,
            ),
            lastError: Value(failure),
            lastAttemptAt: Value(at),
            attemptCount: Value(row.attemptCount + 1),
            updatedAt: Value(at),
          ),
        );
      }
    });
  }

  /// Quando o último envio de [ownerUserId] foi aceito — o "Última
  /// sincronização" da aba Sincronizar. Nulo se nada foi aceito ainda.
  Stream<DateTime?> watchLastSyncedAt(String ownerUserId) {
    final table = _db.localAssessments;
    final last = table.lastAttemptAt.max();
    final query = _db.selectOnly(table)
      ..addColumns([last])
      ..where(table.ownerUserId.equals(ownerUserId) &
          table.syncStatus.equalsValue(LocalSyncStatus.synced));
    return query.map((row) => row.read(last)).watchSingle();
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// "2026-09-29" — a data de calendário, sem hora nem fuso.
String _calendarDate(DateTime date) =>
    '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
