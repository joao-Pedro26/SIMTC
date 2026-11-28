import '../../utils/calendar_date.dart';

/// O texto da CNH na linha do participante e se ela está vencida.
///
/// O consultor confere a CNH antes de iniciar a avaliação; vencida só ganha
/// destaque, nunca bloqueia nada. O vencimento é uma data de calendário
/// (`AAAA-MM-DD`), comparada com o dia local de [now]: vencer hoje é válida.
({String text, bool expired}) cnhLabel(
  String? category,
  String? expiration,
  DateTime now,
) {
  // Vazio (ou só espaços) vem do formulário ou do cache como "não informado":
  // tratar como nulo evita montar "Cat.  · " ou parsear uma data em branco.
  final cat = _nullIfBlank(category);
  final exp = _nullIfBlank(expiration);

  if (cat == null && exp == null) {
    return (text: 'CNH não informada', expired: false);
  }
  if (exp == null) {
    return (text: 'Cat. $cat · Vencimento não informado', expired: false);
  }

  final expired = isCalendarDateBefore(exp, now);
  final date = brDateFromCalendar(exp);
  final dateText = expired ? 'Vencida em $date' : 'Vence $date';
  return (
    text: cat == null ? dateText : 'Cat. $cat · $dateText',
    expired: expired,
  );
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
