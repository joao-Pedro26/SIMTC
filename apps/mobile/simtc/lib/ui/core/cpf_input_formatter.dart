import 'package:flutter/services.dart';

import '../../utils/cpf.dart';

/// Mascara o CPF enquanto ele é digitado ("529.982.247-25") e descarta o que
/// passa do 11º dígito.
///
/// O cursor vai sempre para o fim: o campo é curto e digitado de uma vez, e
/// reposicionar o cursor no meio da máscara custaria mais do que vale.
class CpfInputFormatter extends TextInputFormatter {
  const CpfInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = formatCpf(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
