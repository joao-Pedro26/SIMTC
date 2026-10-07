/// Só os dígitos de [value] — é assim que o backend guarda e recebe o CPF.
String cpfDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Confere os dois dígitos verificadores, com a mesma conta do
/// `ValidateCpfPipe` do backend — que também recusa as sequências de um
/// dígito só ("111.111.111-11" passa na conta, mas não é um CPF).
bool isValidCpf(String value) {
  final digits = cpfDigits(value);
  if (digits.length != 11 || RegExp(r'^(\d)\1+$').hasMatch(digits)) {
    return false;
  }

  for (var position = 9; position < 11; position++) {
    var sum = 0;
    for (var i = 0; i < position; i++) {
      sum += int.parse(digits[i]) * (position + 1 - i);
    }
    final check = (sum * 10) % 11 % 10;
    if (check != int.parse(digits[position])) return false;
  }
  return true;
}

/// "529.982.247-25". Aceita o CPF incompleto ("529.98"), para mascarar
/// enquanto ele é digitado; o que passa do 11º dígito é descartado.
String formatCpf(String value) {
  final digits = cpfDigits(value);
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length && i < 11; i++) {
    if (i == 3 || i == 6) buffer.write('.');
    if (i == 9) buffer.write('-');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
