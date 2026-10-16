const Map<String, String> _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c',
};

/// Chave de ordenação por nome que põe "Ângela" junto de "Ana", e não depois
/// de "Zeca" — o SQLite só ignora caixa em letras sem acento. Serve às listas
/// de participantes e de consultores.
String nameSortKey(String name) {
  final lower = name.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_semAcento[char] ?? char);
  }
  return buffer.toString();
}
