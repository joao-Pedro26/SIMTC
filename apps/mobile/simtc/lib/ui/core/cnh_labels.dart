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
  if (category == null && expiration == null) {
    return (text: 'CNH não informada', expired: false);
  }
  if (expiration == null) {
    return (text: 'Cat. $category · Vencimento não informado', expired: false);
  }

  final expired = isCalendarDateBefore(expiration, now);
  final date = brDateFromCalendar(expiration);
  final dateText = expired ? 'Vencida em $date' : 'Vence $date';
  return (
    text: category == null ? dateText : 'Cat. $category · $dateText',
    expired: expired,
  );
}
