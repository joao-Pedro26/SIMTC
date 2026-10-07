import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/cpf_lookup.dart';

void main() {
  test('CPF sem cadastro', () {
    final lookup = CpfLookup.tryParse({
      'registered': false,
      'name': null,
      'email': null,
      'enrolled': false,
    });

    expect(lookup, isNotNull);
    expect(lookup!.registered, isFalse);
    expect(lookup.enrolled, isFalse);
    expect(lookup.name, isNull);
    expect(lookup.email, isNull);
  });

  test('CPF com cadastro traz nome e e-mail', () {
    final lookup = CpfLookup.tryParse({
      'registered': true,
      'name': 'Fernanda Lopes Meireles',
      'email': 'fernanda@empresa.com.br',
      'enrolled': true,
    });

    expect(lookup!.registered, isTrue);
    expect(lookup.enrolled, isTrue);
    expect(lookup.name, 'Fernanda Lopes Meireles');
    expect(lookup.email, 'fernanda@empresa.com.br');
  });

  test('nome ou e-mail em branco contam como ausentes', () {
    final lookup = CpfLookup.tryParse({
      'registered': true,
      'name': '   ',
      'email': '',
      'enrolled': false,
    });

    expect(lookup!.name, isNull);
    expect(lookup.email, isNull);
  });

  test('resposta fora do formato é nula, em vez de um palpite', () {
    expect(CpfLookup.tryParse(null), isNull);
    expect(CpfLookup.tryParse(''), isNull);
    expect(CpfLookup.tryParse(const <String, dynamic>{}), isNull);
    expect(
      CpfLookup.tryParse({'registered': 'sim', 'enrolled': false}),
      isNull,
      reason: 'registered precisa ser booleano',
    );
    expect(
      CpfLookup.tryParse({'registered': true, 'name': 'Fernanda'}),
      isNull,
      reason: 'sem enrolled não dá para dizer se já está na sessão',
    );
  });
}
