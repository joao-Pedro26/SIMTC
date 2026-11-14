/**
 * Dados do `update` de um `Participant` já cadastrado (dedup por CPF), usados
 * por todo fluxo que inscreve alguém: cadastro manual, inscrição pública e
 * importação por planilha.
 *
 * `name` sempre sobrescreve. `email`, `cnhCategory` e `cnhExpiration` só
 * quando vêm preenchidos: `undefined` no `data` do Prisma faz o campo ser
 * ignorado, mantendo o que já está no banco em vez de apagar.
 */
export function buildParticipantUpdateData(dto: {
  name: string;
  email?: string;
  cnhCategory?: string;
  cnhExpiration?: string;
}): {
  name: string;
  email: string | undefined;
  cnhCategory: string | undefined;
  cnhExpiration: Date | undefined;
} {
  return {
    name: dto.name,
    email: dto.email ? dto.email : undefined,
    cnhCategory: dto.cnhCategory ? dto.cnhCategory : undefined,
    cnhExpiration: dto.cnhExpiration ? new Date(dto.cnhExpiration) : undefined,
  };
}
