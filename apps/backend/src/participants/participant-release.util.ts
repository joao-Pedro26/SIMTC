import { Prisma } from '@prisma/client';
import { getApprovalStatus } from '@simtc/shared-types';

/**
 * Status de um participante que deixa de estar em avaliação sem ter sido
 * avaliado agora — foi desatribuído, ou o consultor que estava com ele saiu
 * do treinamento: `PENDENTE` se nunca foi avaliado, ou o status da nota da
 * avaliação anterior, numa reavaliação. Nota zero é nota: volta a
 * "Não recomendado", não a "Pendente".
 */
export function statusAfterRelease(previousScore: number | null | undefined) {
  return previousScore != null ? getApprovalStatus(previousScore) : 'PENDENTE';
}

/**
 * Libera os participantes do treinamento que estavam em avaliação com algum
 * dos consultores de `consultantIds`: ficam sem consultor e voltam ao status
 * de antes da atribuição (ver `statusAfterRelease`).
 *
 * É o que acontece quando um consultor sai do treinamento (decisão de
 * 06/10/2026, Fase 6B do app mobile): sem isso, o participante ficaria "em
 * avaliação" com alguém que não está mais lá, e ninguém mais conseguiria
 * pegá-lo. Chamar na MESMA transação que tira o vínculo do consultor.
 */
export async function releaseParticipantsOfConsultants(
  tx: Prisma.TransactionClient,
  trainingSessionId: string,
  consultantIds: string[],
): Promise<void> {
  if (consultantIds.length === 0) return;

  const held = await tx.trainingParticipant.findMany({
    where: {
      trainingSessionId,
      status: 'EM_AVALIACAO',
      assignedConsultantId: { in: consultantIds },
    },
    include: { assessment: { select: { score: true } } },
  });

  for (const participant of held) {
    await tx.trainingParticipant.update({
      where: { id: participant.id },
      data: {
        assignedConsultantId: null,
        status: statusAfterRelease(participant.assessment?.score),
      },
    });
  }
}
