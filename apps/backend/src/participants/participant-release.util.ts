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
 * Libera quem está em avaliação entre os participantes de `where`: ficam sem
 * consultor e voltam ao status de antes da atribuição (ver
 * `statusAfterRelease`). Chamar na MESMA transação que faz o que os libera —
 * tirar o consultor do treinamento, excluí-lo ou cancelar o treinamento.
 *
 * A gravação é condicional ao participante continuar `EM_AVALIACAO`: se o
 * envio do consultor gravou a avaliação entre a leitura e a gravação, o
 * participante já mudou de situação por outro caminho e não é mexido.
 */
export async function releaseHeldParticipants(
  tx: Prisma.TransactionClient,
  where: Prisma.TrainingParticipantWhereInput,
): Promise<void> {
  const held = await tx.trainingParticipant.findMany({
    where: { ...where, status: 'EM_AVALIACAO' },
    include: { assessment: { select: { score: true } } },
  });

  for (const participant of held) {
    await tx.trainingParticipant.updateMany({
      where: { id: participant.id, status: 'EM_AVALIACAO' },
      data: {
        assignedConsultantId: null,
        status: statusAfterRelease(participant.assessment?.score),
      },
    });
  }
}

/**
 * Libera os participantes do treinamento que estavam em avaliação com algum
 * dos consultores de `consultantIds`.
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
  await releaseHeldParticipants(tx, {
    trainingSessionId,
    assignedConsultantId: { in: consultantIds },
  });
}
