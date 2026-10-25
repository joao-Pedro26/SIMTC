import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/list_search.dart';
import 'package:simtc/ui/core/search_text.dart';

class _List extends ChangeNotifier with ListSearch {}

void main() {
  group('containsSearch', () {
    test('não diferencia maiúscula nem acento', () {
      expect(containsSearch('José Antônio', 'jose'), isTrue);
      expect(containsSearch('JOSE ANTONIO', 'antônio'), isTrue);
      expect(containsSearch('Ângela', 'ANGELA'), isTrue);
    });

    test('acha o trecho em qualquer parte do texto', () {
      expect(containsSearch('Mariana Costa', 'ana'), isTrue);
      expect(containsSearch('Bracell Celulose', 'celul'), isTrue);
      expect(containsSearch('Bracell Celulose', 'suzano'), isFalse);
    });

    test('busca vazia ou só com espaços acha tudo', () {
      expect(containsSearch('Bracell', ''), isTrue);
      expect(containsSearch('Bracell', '   '), isTrue);
    });

    test('os espaços das pontas da busca não contam', () {
      expect(containsSearch('Ana Paula', ' ana '), isTrue);
    });
  });

  group('cpfSearchDigits', () {
    test('só dígitos, com ou sem máscara, é busca por CPF', () {
      expect(cpfSearchDigits('042'), '042');
      expect(cpfSearchDigits('042.118.990-01'), '04211899001');
      expect(cpfSearchDigits(' 042 118 '), '042118');
    });

    test('com letras é busca por nome', () {
      expect(cpfSearchDigits('ana 042'), isNull);
      expect(cpfSearchDigits('Ana'), isNull);
    });

    test('sem nenhum dígito não é CPF', () {
      expect(cpfSearchDigits(''), isNull);
      expect(cpfSearchDigits('.-'), isNull);
    });
  });

  group('matchesCpfStart', () {
    const stored = '042.118.***-**';

    test('com menos de 6 dígitos compara o começo', () {
      expect(matchesCpfStart(stored, '0'), isTrue);
      expect(matchesCpfStart(stored, '04211'), isTrue);
      expect(matchesCpfStart(stored, '04212'), isFalse);
      expect(matchesCpfStart(stored, '118'), isFalse);
    });

    test('com 6 ou mais (inclusive o CPF inteiro) compara os 6 primeiros', () {
      expect(matchesCpfStart(stored, '042118'), isTrue);
      expect(matchesCpfStart(stored, '04211899001'), isTrue);
      expect(matchesCpfStart(stored, '04211812345'), isTrue);
      expect(matchesCpfStart(stored, '04211999001'), isFalse);
    });

    test('um CPF que o aparelho não conhece nunca é achado', () {
      expect(matchesCpfStart('***.***.***-**', '042'), isFalse);
    });

    test('o aparelho guarda 6 dígitos', () {
      expect(knownCpfDigits, 6);
    });
  });

  group('ListSearch', () {
    test('a lupa abre, o texto filtra, o X fecha e esquece o texto', () {
      final list = _List();
      var notified = 0;
      list.addListener(() => notified++);

      expect(list.isSearching, isFalse);
      expect(list.isFiltering, isFalse);

      list.openSearch();
      expect(list.isSearching, isTrue);
      expect(list.isFiltering, isFalse, reason: 'aberta e vazia, sem filtro');

      list.setSearchQuery('ana');
      expect(list.searchQuery, 'ana');
      expect(list.isFiltering, isTrue);

      list.setSearchQuery('   ');
      expect(list.isFiltering, isFalse, reason: 'só espaços não filtra');

      list.setSearchQuery('ana');
      list.closeSearch();
      expect(list.isSearching, isFalse);
      expect(list.searchQuery, '');
      expect(list.isFiltering, isFalse);
      expect(notified, 5);
    });

    test('repetir o mesmo passo não avisa de novo', () {
      final list = _List()..openSearch()..setSearchQuery('a');
      var notified = 0;
      list.addListener(() => notified++);

      list.openSearch();
      list.setSearchQuery('a');
      expect(notified, 0);

      list.closeSearch();
      list.closeSearch();
      expect(notified, 1);
    });
  });
}
