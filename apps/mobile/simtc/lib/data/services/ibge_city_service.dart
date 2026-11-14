import 'package:dio/dio.dart';

/// Um município da API de Localidades do IBGE.
class IbgeCity {
  const IbgeCity({required this.name, required this.uf, required this.search});

  final String name;
  final String uf;

  /// Nome sem acentos e em minúsculas, pré-calculado para a busca.
  final String search;
}

/// Lista de municípios do Brasil pela API de Localidades do IBGE (gratuita,
/// sem chave) — a mesma que o painel web usa no campo de cidade. Uma única
/// chamada traz todos (~5.570); o resultado fica na memória para não repetir a
/// requisição entre telas. Uma falha não fica guardada: a próxima busca tenta
/// de novo.
///
/// Usa o seu próprio `Dio`, sem o `ApiClient`: a URL é de fora e não leva o
/// token do app.
class IbgeCityService {
  IbgeCityService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
              ),
            );

  final Dio _dio;

  static const String url =
      'https://servicodados.ibge.gov.br/api/v1/localidades/municipios'
      '?orderBy=nome';

  Future<List<IbgeCity>>? _cache;

  /// Todos os municípios. Lança se o IBGE estiver fora do ar ou sem rede — o
  /// campo de cidade segue valendo como texto livre.
  Future<List<IbgeCity>> load() {
    return _cache ??= _fetch().catchError((Object error) {
      _cache = null;
      throw error;
    });
  }

  Future<List<IbgeCity>> _fetch() async {
    final response = await _dio.get<List<dynamic>>(url);
    final raw = response.data ?? const [];
    final cities = <IbgeCity>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final name = item['nome'];
      final uf = _ufOf(item);
      if (name is! String || uf == null || uf.isEmpty) continue;
      cities.add(IbgeCity(name: name, uf: uf, search: normalizeText(name)));
    }
    return cities;
  }

  /// A UF vem da microrregião; quando ela falta, da região imediata.
  static String? _ufOf(Map<String, dynamic> municipio) {
    String? sigla(Object? node, List<String> path) {
      Object? current = node;
      for (final key in path) {
        if (current is! Map<String, dynamic>) return null;
        current = current[key];
      }
      return current is String ? current : null;
    }

    return sigla(municipio['microrregiao'], ['mesorregiao', 'UF', 'sigla']) ??
        sigla(
          municipio['regiao-imediata'],
          ['regiao-intermediaria', 'UF', 'sigla'],
        );
  }

  /// Cidades que começam com o texto digitado vêm antes das que apenas o
  /// contêm (a mesma ordem do painel web).
  static List<IbgeCity> searchCities(
    List<IbgeCity> cities,
    String query, {
    String? uf,
    int limit = 8,
  }) {
    final q = normalizeText(query);
    if (q.isEmpty) return const [];

    final starts = <IbgeCity>[];
    final contains = <IbgeCity>[];
    for (final city in cities) {
      if (uf != null && city.uf != uf) continue;
      if (city.search.startsWith(q)) {
        starts.add(city);
      } else if (city.search.contains(q)) {
        contains.add(city);
      }
      if (starts.length >= limit) break;
    }
    return [...starts, ...contains].take(limit).toList();
  }

  static const String _accented =
      'áàâãäåéèêëíìîïóòôõöúùûüçñýÿÁÀÂÃÄÅÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑÝ';
  static const String _plain =
      'aaaaaaeeeeiiiiooooouuuucnyyAAAAAAEEEEIIIIOOOOOUUUUCNY';

  /// Sem acentos, em minúsculas e aparado — a chave da busca.
  static String normalizeText(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final at = _accented.indexOf(char);
      buffer.write(at == -1 ? char : _plain[at]);
    }
    return buffer.toString().toLowerCase().trim();
  }
}
