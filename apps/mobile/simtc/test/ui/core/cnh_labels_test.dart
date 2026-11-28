import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/cnh_labels.dart';

void main() {
  // Fim do dia 12/03/2027: vencer "hoje" ainda é válida.
  final now = DateTime(2027, 3, 12, 23, 59);

  test('vencimento depois de hoje: "Vence"', () {
    final label = cnhLabel('AB', '2027-03-13', now);
    expect(label.text, 'Cat. AB · Vence 13/03/2027');
    expect(label.expired, isFalse);
  });

  test('vence hoje: continua válida', () {
    final label = cnhLabel('AB', '2027-03-12', now);
    expect(label.text, 'Cat. AB · Vence 12/03/2027');
    expect(label.expired, isFalse);
  });

  test('vencimento antes de hoje: "Vencida em", marcada como vencida', () {
    final label = cnhLabel('AB', '2025-03-12', now);
    expect(label.text, 'Cat. AB · Vencida em 12/03/2025');
    expect(label.expired, isTrue);
  });

  test('sem categoria nem vencimento', () {
    final label = cnhLabel(null, null, now);
    expect(label.text, 'CNH não informada');
    expect(label.expired, isFalse);
  });

  test('categoria sem vencimento', () {
    final label = cnhLabel('AB', null, now);
    expect(label.text, 'Cat. AB · Vencimento não informado');
    expect(label.expired, isFalse);
  });

  test('vencimento sem categoria mostra só a data', () {
    final label = cnhLabel(null, '2027-03-13', now);
    expect(label.text, 'Vence 13/03/2027');
    expect(label.expired, isFalse);
  });

  test('vencimento sem categoria e vencido', () {
    final label = cnhLabel(null, '2025-03-12', now);
    expect(label.text, 'Vencida em 12/03/2025');
    expect(label.expired, isTrue);
  });

  test('categoria e vencimento vazios contam como não informados', () {
    final label = cnhLabel('', '', now);
    expect(label.text, 'CNH não informada');
    expect(label.expired, isFalse);
  });

  test('vencimento vazio conta como não informado', () {
    final label = cnhLabel('AB', '', now);
    expect(label.text, 'Cat. AB · Vencimento não informado');
    expect(label.expired, isFalse);
  });

  test('categoria vazia conta como ausente', () {
    final label = cnhLabel('', '2027-03-13', now);
    expect(label.text, 'Vence 13/03/2027');
    expect(label.expired, isFalse);
  });
}
