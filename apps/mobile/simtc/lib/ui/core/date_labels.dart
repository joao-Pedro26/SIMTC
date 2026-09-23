/// Rótulos de data e hora do app, sem depender dos dados de locale do `intl`
/// (que exigiriam inicialização assíncrona) — os meses abreviados são os
/// mesmos que a Home já usa nos cabeçalhos de dia.
const List<String> _meses = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _dois(int value) => value.toString().padLeft(2, '0');

/// "12 set 2026" — a data de uma sessão, no cabeçalho do detalhe.
String dayMonthYearLabel(DateTime date) =>
    '${date.day} ${_meses[date.month - 1]} ${date.year}';

/// Quando algo aconteceu, do jeito que se fala em campo: "hoje 08:12",
/// "12 set 08:12" ou, em outro ano, "12 set 2025 08:12". Converte para a hora
/// local — o instante pode ter vindo em UTC da API.
String momentLabel(DateTime moment, DateTime now) {
  final local = moment.toLocal();
  final hora = '${_dois(local.hour)}:${_dois(local.minute)}';
  final mesmoDia = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (mesmoDia) return 'hoje $hora';

  final dia = '${local.day} ${_meses[local.month - 1]}';
  return local.year == now.year ? '$dia $hora' : '$dia ${local.year} $hora';
}

/// Texto da faixa de offline: sem conexão, o consultor precisa saber a idade
/// do que está vendo — uma lista de ontem parece igualzinha a uma de agora.
/// Nulo quando nunca houve sync (aí a faixa usa a mensagem padrão dela).
String? offlineDataMessage(DateTime? syncedAt) {
  if (syncedAt == null) return null;
  final d = syncedAt.toLocal();
  return 'Sem conexão — dados de ${_dois(d.day)}/${_dois(d.month)} '
      'às ${_dois(d.hour)}:${_dois(d.minute)}.';
}
