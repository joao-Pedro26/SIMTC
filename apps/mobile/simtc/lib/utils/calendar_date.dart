/// Datas de calendário (sem hora nem fuso), como o vencimento da CNH.
///
/// São guardadas e trafegadas como texto `AAAA-MM-DD`. Um `DateTime` de
/// calendário convertido com `toLocal()` muda de dia em aparelhos fora de UTC
/// (a meia-noite UTC vira 21h do dia anterior em UTC-3), por isso a data é
/// lida e escrita pelas partes, sem passar pelo fuso.
final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _brDate = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

/// Data da API (`"2027-03-12T00:00:00.000Z"` ou `"2027-03-12"`) em
/// `AAAA-MM-DD`. A leitura é em UTC: o ISO do backend marca o dia no próprio
/// texto. Nulo para nulo ou texto que não é data.
String? calendarDateFromApi(Object? value) {
  if (value is! String) return null;
  final dateOnly = _isoDate.firstMatch(value);
  if (dateOnly != null) return value;
  final instant = DateTime.tryParse(value);
  if (instant == null) return null;
  final utc = instant.toUtc();
  return _format(utc.year, utc.month, utc.day);
}

/// `dd/mm/aaaa` digitado pelo usuário em `AAAA-MM-DD`. Nulo se não tiver o
/// formato, se a data não existir (`31/02`, `00/13`) ou se o ano estiver fora
/// de 2000–2099 (um ano digitado com 2 ou 3 dígitos não é uma CNH de verdade).
String? calendarDateFromBr(String text) {
  final match = _brDate.firstMatch(text);
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  if (year < 2000 || year > 2099) return null;
  // Ida e volta pelo DateTime: 31/02 vira 03/03 e não bate com a entrada.
  final parsed = DateTime.utc(year, month, day);
  if (parsed.day != day || parsed.month != month) return null;
  return _format(year, month, day);
}

/// `AAAA-MM-DD` em `dd/mm/aaaa`, para mostrar ao usuário. Não valida: quem
/// chama passa uma data que já veio de [calendarDateFromApi] ou
/// [calendarDateFromBr].
String brDateFromCalendar(String date) {
  final parts = date.split('-');
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

/// `true` se [date] é um dia anterior ao dia local de [now]. O dia de hoje
/// não conta como passado: vencer hoje ainda é válida.
bool isCalendarDateBefore(String date, DateTime now) {
  final today = _format(now.year, now.month, now.day);
  return date.compareTo(today) < 0;
}

String _format(int year, int month, int day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${year.toString().padLeft(4, '0')}-${two(month)}-${two(day)}';
}
