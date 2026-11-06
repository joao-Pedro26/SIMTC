type WithSignature = { signaturePath?: string | null; signatureUpdatedAt?: Date | null };

export type PublicParticipant<T> = Omit<T, 'signaturePath' | 'signatureUpdatedAt'> & {
  hasSignature: boolean;
};

/**
 * Versão do participante que pode sair numa resposta HTTP: troca o caminho da
 * assinatura (dado sensível, aponta para o bucket privado) e a data da
 * atualização por um simples `hasSignature`. Quem precisa do caminho (geração
 * do certificado, limpeza) lê direto do banco, nunca da resposta.
 */
export function toPublicParticipant<T extends WithSignature>(p: T): PublicParticipant<T> {
  const { signaturePath, signatureUpdatedAt: _signatureUpdatedAt, ...rest } = p;
  return { ...rest, hasSignature: !!signaturePath } as PublicParticipant<T>;
}

/** Aplica `toPublicParticipant` ao `participant` aninhado de um registro (ex.: TrainingParticipant). */
export function withPublicParticipant<P extends WithSignature, T extends { participant: P }>(
  record: T,
): Omit<T, 'participant'> & { participant: PublicParticipant<P> } {
  return { ...record, participant: toPublicParticipant(record.participant) };
}
