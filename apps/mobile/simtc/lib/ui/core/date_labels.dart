/// Rótulos de data e hora do app, sem depender dos dados de locale do `intl`
/// (que exigiriam inicialização assíncrona) — os meses abreviados são os
/// mesmos que a Home já usa nos cabeçalhos de dia.
const List<String> _meses = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _dois(int value) => value.toString().padLeft(2, '0');

/// "12 set" — a data de uma sessão onde o ano não precisa aparecer (a faixa
/// de contexto de "Adicionar participante").
String dayMonthLabel(DateTime date) => '${date.day} ${_meses[date.month - 1]}';

/// "12 set 2026" — a data de uma sessão, no cabeçalho do detalhe.
String dayMonthYearLabel(DateTime date) =>
    '${dayMonthLabel(date)} ${date.year}';

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

bool _isToday(DateTime moment, DateTime now) {
  final local = moment.toLocal();
  return local.year == now.year && local.month == now.month && local.day == now.day;
}

/// "08:41" se foi hoje; nos outros dias, como [momentLabel] ("28 set 08:41")
/// — a hora do "Confirmar" na fila de envio.
String clockLabel(DateTime moment, DateTime now) {
  final local = moment.toLocal();
  if (_isToday(moment, now)) return '${_dois(local.hour)}:${_dois(local.minute)}';
  return momentLabel(moment, now);
}

/// "às 07:58" se foi hoje; "em 28 set 07:58" nos outros dias — o "falhou
/// às 07:58" de um envio que não passou.
String atLabel(DateTime moment, DateTime now) {
  final clock = clockLabel(moment, now);
  return _isToday(moment, now) ? 'às $clock' : 'em $clock';
}

/// "Iniciada às 08:12" se foi hoje; "Iniciada em 28 set 08:12" nos outros
/// dias — a hora do "Iniciar avaliação", que o app só registra (sem
/// cronômetro, decisão de 30/09/2026).
String startedLabel(DateTime start, DateTime now) =>
    'Iniciada ${atLabel(start, now)}';

/// Texto da faixa de offline: sem conexão, o consultor precisa saber a idade
/// do que está vendo — uma lista de ontem parece igualzinha a uma de agora.
/// Nulo quando nunca houve sync (aí a faixa usa a mensagem padrão dela).
String? offlineDataMessage(DateTime? syncedAt) {
  if (syncedAt == null) return null;
  final d = syncedAt.toLocal();
  return 'Sem conexão — dados de ${_dois(d.day)}/${_dois(d.month)} '
      'às ${_dois(d.hour)}:${_dois(d.minute)}.';
}
