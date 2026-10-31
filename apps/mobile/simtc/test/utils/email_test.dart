import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/utils/email.dart';

void main() {
  // A resposta do `isEmail` do class-validator para cada caso, conferida no
  // backend em 30/10/2026.
  test('aceita o que o servidor aceita', () {
    for (final email in [
      'fernanda@empresa.com.br',
      'f.l+cert@sub.empresa.com',
      'a@b.co',
      'joão@empresa.com.br',
      'maria@empresá.com.br',
      'MARIA@EMPRESA.COM',
      'maria_silva-2@x-y.com',
      'maria@1.2.3.com',
      'm@x.xn--p1ai',
    ]) {
      expect(isValidEmail(email), isTrue, reason: email);
    }
  });

  test('recusa o que o servidor recusa', () {
    for (final email in [
      'a@b.c',
      'maria@empresa..com',
      'm@x.com.',
      '.maria@x.com',
      'maria.@x.com',
      'ma..ria@x.com',
      'maria@-empresa.com',
      'maria@empresa-.com',
      'maria@empresa.c0m',
      'maria@empresa.123',
      'a b@c.com',
      'maria@empresa',
      'maria@@x.com',
      'maria@empresa.com.b',
      'maria@x.com.br.',
      'maria@localhost',
      'maria@x.co.u_k',
    ]) {
      expect(isValidEmail(email), isFalse, reason: email);
    }
  });
}
