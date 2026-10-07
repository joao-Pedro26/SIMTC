import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/utils/cpf.dart';

void main() {
  group('cpfDigits', () {
    test('tira a máscara e qualquer outro caractere', () {
      expect(cpfDigits('529.982.247-25'), '52998224725');
      expect(cpfDigits(' 529 982 247/25 '), '52998224725');
      expect(cpfDigits(''), '');
    });
  });

  group('isValidCpf', () {
    test('aceita CPF com os dois dígitos verificadores certos', () {
      expect(isValidCpf('52998224725'), isTrue);
      expect(isValidCpf('111.444.777-35'), isTrue, reason: 'com máscara');
    });

    test('recusa dígito verificador errado', () {
      expect(isValidCpf('52998224726'), isFalse, reason: 'segundo dígito');
      expect(isValidCpf('52998224735'), isFalse, reason: 'primeiro dígito');
      // O CPF de exemplo do canvas ("3a") não passa na conta.
      expect(isValidCpf('318.664.920-07'), isFalse);
    });

    test('recusa tamanho errado', () {
      expect(isValidCpf(''), isFalse);
      expect(isValidCpf('5299822472'), isFalse, reason: '10 dígitos');
      expect(isValidCpf('529982247250'), isFalse, reason: '12 dígitos');
    });

    test('recusa sequência de um dígito só, que passaria na conta', () {
      expect(isValidCpf('11111111111'), isFalse);
      expect(isValidCpf('000.000.000-00'), isFalse);
    });
  });

  group('formatCpf', () {
    test('mascara conforme os dígitos chegam', () {
      expect(formatCpf(''), '');
      expect(formatCpf('529'), '529');
      expect(formatCpf('5299'), '529.9');
      expect(formatCpf('529982'), '529.982');
      expect(formatCpf('5299822'), '529.982.2');
      expect(formatCpf('529982247'), '529.982.247');
      expect(formatCpf('5299822472'), '529.982.247-2');
      expect(formatCpf('52998224725'), '529.982.247-25');
    });

    test('ignora o que não é dígito e descarta o que passa do 11º', () {
      expect(formatCpf('529.982.247-25'), '529.982.247-25');
      expect(formatCpf('529982247259999'), '529.982.247-25');
      expect(formatCpf('abc'), '');
    });
  });
}
