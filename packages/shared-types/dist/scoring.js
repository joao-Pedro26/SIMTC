"use strict";
// ─── LÓGICA DE SCORES ─────────────────────────────────────────────────────────
// Compartilhada entre backend (cálculo no servidor) e web (preview em tempo real)
Object.defineProperty(exports, "__esModule", { value: true });
exports.NOTE_DEDUCTIONS = void 0;
exports.calculateCategoryScore = calculateCategoryScore;
exports.calculateOverallScore = calculateOverallScore;
exports.getApprovalStatus = getApprovalStatus;
exports.getApprovalLabel = getApprovalLabel;
exports.NOTE_DEDUCTIONS = {
    B: 1, // Bom — desconta 1 ponto
    PM: 3, // Pode Melhorar — desconta 3 pontos
    M: 5, // Melhorar — desconta 5 pontos
};
/** Score por categoria = 100 menos a soma das deduções dos itens marcados */
function calculateCategoryScore(deductions) {
    const total = deductions.reduce((acc, d) => acc + d, 0);
    return Math.max(0, 100 - total);
}
/** Média simples entre todas as categorias avaliadas */
function calculateOverallScore(categoryScores) {
    if (categoryScores.length === 0)
        return 100;
    return categoryScores.reduce((a, b) => a + b, 0) / categoryScores.length;
}
function getApprovalStatus(score) {
    return score >= 70 ? 'APROVADO' : 'NECESSITA_REAVALIACAO';
}
function getApprovalLabel(score) {
    if (score >= 85)
        return 'Aprovado com Excelência';
    if (score >= 70)
        return 'Aprovado';
    return 'Necessita Reavaliação';
}
//# sourceMappingURL=scoring.js.map