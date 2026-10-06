/// Cálculo de score da avaliação prática — cópia 1:1 de
/// `packages/shared-types/src/scoring.ts` (a fonte de verdade, compartilhada
/// com o backend e o painel web). Qualquer mudança aqui tem que mudar lá
/// também, e vice-versa. Sem nenhuma dependência de Flutter ou do resto do
/// app — só números entram, só números (ou o texto fixo do status) saem.
const int maxNoteWeight = 5; // NOTE_DEDUCTIONS.M no TS

/// Score de uma categoria, de 0 a 100.
///
/// Cada infração cadastrada na categoria (marcada ou não) vale uma fração
/// igual de 100. A nota escolhida (peso de `InfractionNote.deduction`)
/// modula quanto dessa fatia é descontada, normalizada pelo peso máximo
/// (M = 5) — a mesma proporção 1:3:5 de `NOTE_DEDUCTIONS`. Uma infração não
/// marcada não aparece em [noteWeights], e por isso não desconta nada da sua
/// fatia: fica com o valor cheio.
double calculateCategoryScore(
  List<int> noteWeights,
  int totalInfractionsInCategory,
) {
  if (totalInfractionsInCategory <= 0) return 100;

  final perInfractionShare = 100 / totalInfractionsInCategory;
  final totalDeduction = noteWeights.fold<double>(
    0,
    (acc, weight) => acc + (weight / maxNoteWeight) * perInfractionShare,
  );
  final score = 100 - totalDeduction;
  return score < 0 ? 0 : score;
}

/// Média simples entre todas as categorias do catálogo — inclusive as que o
/// consultor nunca abriu, que contam 100.
double calculateOverallScore(List<double> categoryScores) {
  if (categoryScores.isEmpty) return 100;
  final total = categoryScores.fold<double>(0, (acc, score) => acc + score);
  return total / categoryScores.length;
}

/// `'APROVADO'` com 70 ou mais; `'NAO_RECOMENDADO'` abaixo disso —
/// mesmo corte e mesmas strings do backend (`getApprovalStatus`,
/// `ParticipantStatus`). Devolve o texto puro, não o enum do app: quem
/// consumir aqui decide se quer `ParticipantStatus.parse()` sobre o
/// resultado, ou só o texto mesmo.
String getApprovalStatus(double score) {
  return score >= 70 ? 'APROVADO' : 'NAO_RECOMENDADO';
}
