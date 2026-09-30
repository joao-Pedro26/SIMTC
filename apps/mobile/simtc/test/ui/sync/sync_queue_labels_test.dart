import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/sync/sync_queue_labels.dart';

import '../../support/fake_assessment_sync_service.dart';

void main() {
  final agora = DateTime(2026, 9, 29, 9);

  test('o estado do item: o envio no ar vence; senão, erro ou na fila', () {
    final queued = queuedAssessment('1');
    final failed = queuedAssessment('2', status: LocalSyncStatus.error);

    expect(queueItemStateOf(queued, sending: false), QueueItemState.queued);
    expect(queueItemStateOf(failed, sending: false), QueueItemState.failed);
    expect(queueItemStateOf(failed, sending: true), QueueItemState.sending);
  });

  test('o título é o nome guardado, ou "Participante" sem ele', () {
    expect(queueItemTitle(queuedAssessment('1', participantName: 'Ana Paula Ribeiro')),
        'Ana Paula Ribeiro');
    expect(queueItemTitle(queuedAssessment('2')), 'Participante');
    expect(queueItemTitle(queuedAssessment('3', participantName: '  ')), 'Participante');
  });

  test('na fila: o tipo, o % e a hora do Confirmar', () {
    expect(
      queueItemMeta(
        queuedAssessment('1', score: 86.6667, endTime: DateTime(2026, 9, 29, 8, 41)),
        QueueItemState.queued,
        agora,
      ),
      'Avaliação prática · 86,7% · 08:41',
    );
    expect(
      queueItemMeta(
        queuedAssessment('2', endTime: DateTime(2026, 9, 28, 17, 2)),
        QueueItemState.queued,
        agora,
      ),
      'Avaliação prática · 28 set 17:02',
      reason: 'sem % (Fase 4) e confirmada ontem',
    );
  });

  test('com erro: quando falhou e por quê', () {
    expect(
      queueItemMeta(
        queuedAssessment(
          '1',
          status: LocalSyncStatus.error,
          lastAttemptAt: DateTime(2026, 9, 29, 7, 58),
          lastError: 'tempo esgotado',
        ),
        QueueItemState.failed,
        agora,
      ),
      'Falhou às 07:58 · tempo esgotado',
    );
  });

  test('a contagem do cartão e a última sincronização', () {
    expect(queueCountLabel(1), '1 avaliação na fila');
    expect(queueCountLabel(3), '3 avaliações na fila');
    expect(lastSyncLabel(DateTime(2026, 9, 29, 7, 12), agora),
        'Última sincronização hoje 07:12');
    expect(lastSyncLabel(null, agora), 'Nenhuma avaliação enviada ainda');
  });
}
