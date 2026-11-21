import 'package:flutter/services.dart';

/// Limita o texto em unidades UTF-16 (`String.length`), a mesma medida com
/// que o `AssessmentRepository.setObservation` corta a observação. O
/// `maxLength` do `TextField` conta grafemas: um texto com emojis passaria de
/// 500 unidades e seria cortado em silêncio na hora de gravar.
///
/// Se o corte cairia no meio de um emoji (par de substitutos), o emoji inteiro
/// fica de fora.
class ObservationLengthFormatter extends TextInputFormatter {
  const ObservationLengthFormatter(this.maxLength);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.length <= maxLength) return newValue;

    // Já no limite e a edição passaria dele: ignora a edição (mesma guarda do
    // LengthLimitingTextInputFormatter), em vez de apagar o fim em silêncio.
    if (oldValue.text.length >= maxLength) return oldValue;

    var end = maxLength;
    final last = text.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--;
    return TextEditingValue(
      text: text.substring(0, end),
      selection: newValue.selection.isValid
          ? TextSelection(
              baseOffset: newValue.selection.baseOffset.clamp(0, end),
              extentOffset: newValue.selection.extentOffset.clamp(0, end),
            )
          : TextSelection.collapsed(offset: end),
    );
  }
}
