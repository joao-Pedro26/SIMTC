export declare const NOTE_DEDUCTIONS: Record<'B' | 'PM' | 'M', number>;
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
export declare function calculateCategoryScore(noteWeights: number[], totalInfractionsInCategory: number): number;
/** Média simples entre todas as categorias (inclusive as não avaliadas, que contam 100%) */
export declare function calculateOverallScore(categoryScores: number[]): number;
export declare function getApprovalStatus(score: number): 'APROVADO' | 'NECESSITA_REAVALIACAO';
export declare function getApprovalLabel(score: number): string;
//# sourceMappingURL=scoring.d.ts.map