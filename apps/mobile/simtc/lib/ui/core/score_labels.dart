/// "86,7%" — uma casa, vírgula decimal, como no canvas. É o % do checklist,
/// da tela 1.6 e da fila de envio; os chips "Aprovado · 87%" do detalhe
/// arredondam como o painel web (`chipLabelFor`).
String percentLabel(double score) =>
    '${score.toStringAsFixed(1).replaceAll('.', ',')}%';
