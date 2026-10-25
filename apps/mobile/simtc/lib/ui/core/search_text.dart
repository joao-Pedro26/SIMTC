import 'name_sort.dart';

/// As regras da busca local das listas (Fase 8B): sem diferença de
/// maiúscula nem de acento, e o trecho em qualquer parte do texto — "jose"
/// acha "José", "ana" acha "Mariana". Busca vazia acha tudo.
bool containsSearch(String text, String query) {
  final wanted = nameSortKey(query.trim());
  if (wanted.isEmpty) return true;
  return nameSortKey(text).contains(wanted);
}

/// Só dígitos, pontos, traço e espaços: o jeito de digitar um CPF.
final RegExp _cpfLike = RegExp(r'^[\d.\-\s]+$');

/// Os dígitos de uma busca que é um CPF (com ou sem máscara); nulo quando
/// ela tem letras — aí é busca por nome.
String? cpfSearchDigits(String query) {
  final trimmed = query.trim();
  if (!_cpfLike.hasMatch(trimmed)) return null;
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty ? null : digits;
}

/// Quantos dígitos do CPF o aparelho guarda (`maskCpf`: `123.456.***-**`).
const int knownCpfDigits = 6;

/// O começo do CPF: o aparelho só guarda os 6 primeiros dígitos (decisão de
/// 24/10/2026 — nada novo é guardado). Com 6 ou mais digitados, inclusive o
/// CPF inteiro que o participante dita, compara os 6 primeiros; com menos,
/// compara o começo. Um CPF que o aparelho não conhece (`***.***.***-**`)
/// nunca é achado.
bool matchesCpfStart(String maskedCpf, String digits) {
  final known = maskedCpf.replaceAll(RegExp(r'\D'), '');
  if (known.length < knownCpfDigits) return false;
  final wanted = digits.length > knownCpfDigits
      ? digits.substring(0, knownCpfDigits)
      : digits;
  return known.startsWith(wanted);
}
