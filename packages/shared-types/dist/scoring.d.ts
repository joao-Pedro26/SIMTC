export declare const NOTE_DEDUCTIONS: Record<'B' | 'PM' | 'M', number>;
/** Score por categoria = 100 menos a soma das deduções dos itens marcados */
export declare function calculateCategoryScore(deductions: number[]): number;
/** Média simples entre todas as categorias avaliadas */
export declare function calculateOverallScore(categoryScores: number[]): number;
export declare function getApprovalStatus(score: number): 'APROVADO' | 'NECESSITA_REAVALIACAO';
export declare function getApprovalLabel(score: number): string;
//# sourceMappingURL=scoring.d.ts.map