import 'package:flutter/foundation.dart';

/// O estado da busca de uma lista (Fase 8B), para a ViewModel da tela: a
/// lupa abre o campo, o texto filtra, o X fecha e limpa. Vive na ViewModel
/// para atravessar o giro do tablet e a ida a um resultado e a volta.
mixin ListSearch on ChangeNotifier {
  bool _searching = false;
  String _query = '';

  /// O campo de busca está aberto (no lugar da faixa onde mora a lupa).
  bool get isSearching => _searching;

  String get searchQuery => _query;

  /// A lista está filtrada: o campo está aberto e tem algum texto. Aberto e
  /// vazio, a lista é a de sempre.
  bool get isFiltering => _searching && _query.trim().isNotEmpty;

  void openSearch() {
    if (_searching) return;
    _searching = true;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  /// O X do campo: fecha a busca e esquece o texto.
  void closeSearch() {
    if (!_searching && _query.isEmpty) return;
    _searching = false;
    _query = '';
    notifyListeners();
  }
}
