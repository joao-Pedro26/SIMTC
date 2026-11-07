/**
 * Categorias de CNH aceitas no cadastro de participante. Mesma lista do
 * seletor do web (`apps/web/src/lib/validate-cpf.ts` → CNH_CATEGORIES).
 */
export const CNH_CATEGORIES = ['A', 'B', 'C', 'D', 'E', 'AB', 'AC', 'AD', 'AE'] as const;
export type CnhCategory = (typeof CNH_CATEGORIES)[number];

export function isValidCnhCategory(value: unknown): value is CnhCategory {
  return typeof value === 'string' && (CNH_CATEGORIES as readonly string[]).includes(value);
}
