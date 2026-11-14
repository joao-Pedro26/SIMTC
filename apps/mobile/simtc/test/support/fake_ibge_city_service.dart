import 'package:simtc/data/services/ibge_city_service.dart';

/// O serviço do IBGE dos testes de tela: devolve a lista dada, sem rede.
class FakeIbgeCityService implements IbgeCityService {
  FakeIbgeCityService([List<IbgeCity>? cities, this.fails = false])
      : cities = cities ?? defaultCities;

  final List<IbgeCity> cities;

  /// Simula o IBGE fora do ar.
  final bool fails;

  int loads = 0;

  static final List<IbgeCity> defaultCities = [
    for (final (name, uf) in const [
      ('Betim', 'MG'),
      ('Belo Horizonte', 'MG'),
      ('Bela Vista', 'SP'),
      ('São Paulo', 'SP'),
    ])
      IbgeCity(
        name: name,
        uf: uf,
        search: IbgeCityService.normalizeText(name),
      ),
  ];

  @override
  Future<List<IbgeCity>> load() async {
    loads++;
    if (fails) throw Exception('IBGE fora do ar');
    return cities;
  }
}
