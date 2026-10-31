import 'package:flutter/services.dart';

import '../../utils/cpf.dart';

/// Mascara o CPF enquanto ele é digitado ("529.982.247-25") e descarta o que
/// passa do 11º dígito.
///
/// O cursor fica onde a pessoa está digitando (Fase 8D): depois do mesmo
/// número de dígitos que ele tinha à esquerda, e não no fim do campo — quem
/// corrige um dígito no meio continua corrigindo dali.
class CpfInputFormatter extends TextInputFormatter {
  const CpfInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = formatCpf(newValue.text);
    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, newValue.text.length)
        : newValue.text.length;
    final digitsBefore = cpfDigits(newValue.text.substring(0, cursor)).length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: _offsetAfter(text, digitsBefore)),
    );
  }

  /// A posição logo depois do [digits]-ésimo dígito de [text].
  static int _offsetAfter(String text, int digits) {
    if (digits <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < text.length; i++) {
      if (cpfDigits(text[i]).isNotEmpty) seen++;
      if (seen == digits) return i + 1;
    }
    return text.length;
  }
}
