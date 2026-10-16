import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/name_sort.dart';

void main() {
  test('ignora caixa e acento, para "Ângela" ficar junto de "Ana"', () {
    expect(nameSortKey('Ângela Reis'), 'angela reis');
    expect(nameSortKey('JOSÉ'), 'jose');
    expect(nameSortKey('Conceição'), 'conceicao');

    final names = ['Zeca', 'Ângela', 'ana', 'Érica', 'Bruno']
      ..sort((a, b) => nameSortKey(a).compareTo(nameSortKey(b)));
    expect(names, ['ana', 'Ângela', 'Bruno', 'Érica', 'Zeca']);
  });
}
