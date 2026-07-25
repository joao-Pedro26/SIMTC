// ─── LÓGICA DE SCORES ─────────────────────────────────────────────────────────
// Compartilhada entre backend (cálculo no servidor) e web (preview em tempo real)

export const NOTE_DEDUCTIONS: Record<'B' | 'PM' | 'M', number> = {
  B:  0,  // Bom — sem dedução
  PM: 3,  // Pode Melhorar — desconta 3 pontos
  M:  5,  // Melhorar — desconta 5 pontos
};

/** Score por categoria = 100 menos a soma das deduções dos itens marcados */
export function calculateCategoryScore(deductions: number[]): number {
  const total = deductions.reduce((acc, d) => acc + d, 0);
  return Math.max(0, 100 - total);
}

/** Média simples entre todas as categorias avaliadas */
export function calculateOverallScore(categoryScores: number[]): number {
  if (categoryScores.length === 0) return 100;
  return categoryScores.reduce((a, b) => a + b, 0) / categoryScores.length;
}

export function getApprovalStatus(score: number): 'APROVADO' | 'NECESSITA_REAVALIACAO' {
  return score >= 70 ? 'APROVADO' : 'NECESSITA_REAVALIACAO';
}

export function getApprovalLabel(score: number): string {
  if (score >= 85) return 'Aprovado com Excelência';
  if (score >= 70) return 'Aprovado';
  return 'Necessita Reavaliação';
}
