import '../../data/services/local/app_database.dart';
import '../core/date_labels.dart';
import '../core/score_labels.dart';

/// Como um item da fila aparece na aba Sincronizar (canvas "2h").
enum QueueItemState {
  /// Confirmada, esperando o próximo envio: pílula "Na fila".
  queued,

  /// Faz parte do envio no ar: pílula "Enviando" (não está no canvas —
  /// aprovada em 29/09/2026).
  sending,

  /// O último envio falhou: pílula "Erro" e o botão "Tentar novamente".
  failed,
}

QueueItemState queueItemStateOf(LocalAssessment item, {required bool sending}) {
  if (sending) return QueueItemState.sending;
  return item.syncStatus == LocalSyncStatus.error
      ? QueueItemState.failed
      : QueueItemState.queued;
}

/// O nome do participante guardado no "Confirmar" — "Participante" nas
/// avaliações de antes da Fase 5A cujo nome não estava mais no cache.
String queueItemTitle(LocalAssessment item) {
  final name = item.participantName?.trim() ?? '';
  return name.isEmpty ? 'Participante' : name;
}

/// "Avaliação prática · 86,7% · 08:41" ou "Falhou às 07:58 · tempo
/// esgotado". Sem o "+ assinatura" do canvas: a assinatura saiu do app em
/// 20/09/2026.
String queueItemMeta(LocalAssessment item, QueueItemState state, DateTime now) {
  if (state == QueueItemState.failed) {
    final at = item.lastAttemptAt;
    final reason = item.lastError ?? '';
    return [
      at == null ? 'Falhou' : 'Falhou ${atLabel(at, now)}',
      if (reason.isNotEmpty) reason,
    ].join(' · ');
  }

  final score = item.score;
  final end = item.endTime;
  return [
    'Avaliação prática',
    if (score != null) percentLabel(score),
    if (end != null) clockLabel(end, now),
  ].join(' · ');
}

/// "3 avaliações na fila", do cartão âmbar sem rede.
String queueCountLabel(int count) =>
    count == 1 ? '1 avaliação na fila' : '$count avaliações na fila';

/// "Última sincronização hoje 07:12" — o último envio aceito.
String lastSyncLabel(DateTime? at, DateTime now) => at == null
    ? 'Nenhuma avaliação enviada ainda'
    : 'Última sincronização ${momentLabel(at, now)}';
