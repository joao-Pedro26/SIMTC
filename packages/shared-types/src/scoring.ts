// ─── LÓGICA DE SCORES ─────────────────────────────────────────────────────────
// Compartilhada entre backend (cálculo no servidor) e web (preview em tempo real)

export const NOTE_DEDUCTIONS: Record<'B' | 'PM' | 'M', number> = {
  B:  1,  // Bom — desconta 1 ponto
  PM: 3,  // Pode Melhorar — desconta 3 pontos
  M:  5,  // Melhorar — desconta 5 pontos
};

/** Peso máximo possível de uma nota — usado para normalizar a proporção da falta */
const MAX_NOTE_WEIGHT = NOTE_DEDUCTIONS.M;

/**
 * Score por categoria em porcentagem (0-100).
 *
 * Cada tópico começa em 100%. Cada infração cadastrada na categoria (marcada
 * ou não) representa uma fração igual de 100% — se há N infrações no tópico,
 * cada uma vale 100/N. A nota escolhida (B/PM/M) modula quanto dessa fatia é
 * de fato descontado, preservando a proporção de severidade 1:3:5 já usada em
 * NOTE_DEDUCTIONS (normalizada pelo peso máximo, M = 5).
 *
 * @param noteWeights            pesos (`deduction`) das notas marcadas nesta categoria
 * @param totalInfractionsInCategory total de infrações cadastradas na categoria (marcadas ou não)
 */
export function calculateCategoryScore(
  noteWeights: number[],
  totalInfractionsInCategory: number,
): number {
  if (totalInfractionsInCategory <= 0) return 100;

  const perInfractionShare = 100 / totalInfractionsInCategory;
  const totalDeduction = noteWeights.reduce(
    (acc, weight) => acc + (weight / MAX_NOTE_WEIGHT) * perInfractionShare,
    0,
  );
  return Math.max(0, 100 - totalDeduction);
}

/** Média simples entre todas as categorias (inclusive as não avaliadas, que contam 100%) */
export function calculateOverallScore(categoryScores: number[]): number {
  if (categoryScores.length === 0) return 100;
  return categoryScores.reduce((a, b) => a + b, 0) / categoryScores.length;
}

export function getApprovalStatus(score: number): 'APROVADO' | 'NECESSITA_REAVALIACAO' {
  return score >= 70 ? 'APROVADO' : 'NECESSITA_REAVALIACAO';
}

export function getApprovalLabel(score: number): string {
  if (score >= 70) return 'Aprovado';
  return 'Necessita Reavaliação';
}
