import { Prisma } from '@prisma/client';

/**
 * `Participant` é um cadastro compartilhado por CPF: a mesma pessoa pode
 * estar inscrita (via `TrainingParticipant`) em vários treinamentos ao mesmo
 * tempo. Por decisão do cliente (30/08/2026), quando um treinamento ou uma
 * inscrição é excluído, o cadastro do participante só deve ser apagado
 * junto se essa era a ÚLTIMA inscrição dele — ou seja, se ele não continuar
 * vinculado a nenhum outro treinamento. Ver [[simtc-participant-training-delete]].
 *
 * IMPORTANTE: chamar isso DEPOIS de apagar as linhas de `TrainingParticipant`
 * relevantes, na MESMA transação — a checagem de "ainda referenciado" precisa
 * refletir o estado pós-exclusão, senão todo participante pareceria não-órfão
 * (ainda contaria a própria linha que está sendo removida).
 *
 * `Participant` só é referenciado por `TrainingParticipant.participantId`
 * (nenhum outro model tem FK para `Participant`), então essa checagem é
 * suficiente.
 */
export async function deleteOrphanedParticipants(
  tx: Prisma.TransactionClient,
  participantIds: (string | null | undefined)[],
): Promise<void> {
  const uniqueIds = Array.from(new Set(participantIds.filter((id): id is string => !!id)));
  if (uniqueIds.length === 0) return;

  const stillLinked = await tx.trainingParticipant.findMany({
    where: { participantId: { in: uniqueIds } },
    select: { participantId: true },
    distinct: ['participantId'],
  });
  const stillLinkedIds = new Set(stillLinked.map((r) => r.participantId));

  const orphanIds = uniqueIds.filter((id) => !stillLinkedIds.has(id));
  if (orphanIds.length === 0) return;

  await tx.participant.deleteMany({ where: { id: { in: orphanIds } } });
}
