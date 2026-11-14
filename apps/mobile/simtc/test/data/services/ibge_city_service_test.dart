import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/services/ibge_city_service.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late IbgeCityService service;

  Response<List<dynamic>> answer(List<dynamic> data) => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: IbgeCityService.url),
        statusCode: 200,
        data: data,
      );

  Map<String, dynamic> municipio(String nome, {String? micro, String? imediata}) {
    return {
      'nome': nome,
      'microrregiao': micro == null
          ? null
          : {
              'mesorregiao': {
                'UF': {'sigla': micro},
              },
            },
      'regiao-imediata': imediata == null
          ? null
          : {
              'regiao-intermediaria': {
                'UF': {'sigla': imediata},
              },
            },
    };
  }

  setUp(() {
    dio = _MockDio();
    service = IbgeCityService(dio: dio);
  });

  group('load', () {
    test('lê o nome e a UF, da microrregião ou, na falta dela, da região imediata',
        () async {
      when(() => dio.get<List<dynamic>>(IbgeCityService.url)).thenAnswer(
        (_) async => answer([
          municipio('Betim', micro: 'MG'),
          municipio('Boa Vista', imediata: 'RR'),
          municipio('Sem UF'),
          {'sem': 'nome'},
        ]),
      );

      final cities = await service.load();

      expect(cities.map((c) => '${c.name}/${c.uf}'), ['Betim/MG', 'Boa Vista/RR']);
      expect(cities.first.search, 'betim');
    });

    test('a lista é pedida uma vez só', () async {
      when(() => dio.get<List<dynamic>>(IbgeCityService.url))
          .thenAnswer((_) async => answer([municipio('Betim', micro: 'MG')]));

      await Future.wait([service.load(), service.load()]);
      await service.load();

      verify(() => dio.get<List<dynamic>>(IbgeCityService.url)).called(1);
    });

    test('uma falha não fica guardada: a próxima chamada tenta de novo',
        () async {
      var calls = 0;
      when(() => dio.get<List<dynamic>>(IbgeCityService.url)).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('sem rede');
        return answer([municipio('Betim', micro: 'MG')]);
      });

      await expectLater(service.load(), throwsException);
      final cities = await service.load();

      expect(cities, hasLength(1));
      expect(calls, 2);
    });
  });

  group('searchCities', () {
    final cities = [
      for (final (name, uf) in const [
        ('Belo Horizonte', 'MG'),
        ('Rio Bonito', 'RJ'),
        ('Bonito', 'MS'),
        ('São José', 'SC'),
        ('Ibirité', 'MG'),
      ])
        IbgeCity(name: name, uf: uf, search: IbgeCityService.normalizeText(name)),
    ];

    List<String> names(String q, {String? uf, int limit = 8}) =>
        IbgeCityService.searchCities(cities, q, uf: uf, limit: limit)
            .map((c) => c.name)
            .toList();

    test('texto vazio não sugere nada', () {
      expect(names(''), isEmpty);
      expect(names('   '), isEmpty);
    });

    test('quem começa com o texto vem antes de quem só o contém', () {
      expect(names('bonito'), ['Bonito', 'Rio Bonito']);
    });

    test('ignora acentos e maiúsculas', () {
      expect(names('SAO JOSE'), ['São José']);
      expect(names('ibirite'), ['Ibirité']);
    });

    test('a UF restringe as sugestões', () {
      expect(names('bonito', uf: 'RJ'), ['Rio Bonito']);
    });

    test('respeita o limite', () {
      expect(names('o', limit: 2), hasLength(2));
    });
  });

  test('normalizeText tira acentos, passa para minúsculas e apara', () {
    expect(IbgeCityService.normalizeText('  São João '), 'sao joao');
    expect(IbgeCityService.normalizeText('ÀÉÎÕÜÇ'), 'aeiouc');
  });
}
