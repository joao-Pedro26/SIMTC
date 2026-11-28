import 'package:flutter/services.dart';

/// Mascara a data enquanto ela é digitada ("12/03/2027") e descarta o que
/// passa do 8º dígito. Só máscara: se a data existe quem diz é a ViewModel.
///
/// O cursor segue o mesmo esquema do `CpfInputFormatter`: depois do mesmo
/// número de dígitos que ele tinha à esquerda, e não no fim do campo.
class DateInputFormatter extends TextInputFormatter {
  const DateInputFormatter();

  static const int _maxDigits = 8;

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  static String _format(String digits) {
    final capped = digits.length > _maxDigits
        ? digits.substring(0, _maxDigits)
        : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(capped[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = _format(_digits(newValue.text));
    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, newValue.text.length)
        : newValue.text.length;
    final digitsBefore = _digits(newValue.text.substring(0, cursor)).length;
    return TextEditingValue(
      text: text,
      selection:
          TextSelection.collapsed(offset: _offsetAfter(text, digitsBefore)),
    );
  }

  /// A posição logo depois do [digits]-ésimo dígito de [text].
  static int _offsetAfter(String text, int digits) {
    if (digits <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < text.length; i++) {
      if (_digits(text[i]).isNotEmpty) seen++;
      if (seen == digits) return i + 1;
    }
    return text.length;
  }
}
