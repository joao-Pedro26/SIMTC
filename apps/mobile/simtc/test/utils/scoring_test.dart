import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/utils/scoring.dart';

/// Os casos marcados "(backend)" são os mesmos, com os mesmos números, de
/// `apps/backend/test/practical-assessments.service.spec.ts` — o app e o
/// backend têm de dar o mesmo score para a mesma avaliação.
void main() {
  group('calculateCategoryScore', () {
    test('(backend) retorna 100 se não há infrações cadastradas na categoria', () {
      expect(calculateCategoryScore(const [], 0), 100);
    });

    test('(backend) retorna 100 se há infrações cadastradas mas nenhuma foi marcada',
        () {
      expect(calculateCategoryScore(const [], 5), 100);
    });

    test('(backend) desconta proporcionalmente ao número de infrações da categoria',
        () {
      // 5 infrações → cada uma vale 20%; uma M (peso máximo) desconta os 20%.
      expect(calculateCategoryScore(const [5], 5), 80);
    });

    test('(backend) nota B desconta só 1/5 do peso máximo dentro da fatia da infração',
        () {
      // Fatia de 20%; B (peso 1 de 5) desconta 1/5 de 20% = 4%.
      expect(calculateCategoryScore(const [1], 5), 96);
    });

    test('(backend) não vai abaixo de 0', () {
      expect(calculateCategoryScore(const [5, 5, 5], 3), 0);
    });

    test(
        'categoria "CV" do canvas: 6 infrações, uma PM (peso 3) e uma B '
        '(peso 1) marcadas — bate com o "86,7%" do quadro 1b', () {
      expect(calculateCategoryScore(const [3, 1], 6), closeTo(86.6666, 0.001));
    });
  });

  group('calculateOverallScore', () {
    test('(backend) retorna 100 se não há categorias', () {
      expect(calculateOverallScore(const []), 100);
    });

    test('(backend) retorna a média das categorias', () {
      expect(calculateOverallScore(const [80, 60]), 70);
    });

    test('(backend) retorna o valor único se só há uma categoria', () {
      expect(calculateOverallScore(const [85]), 85);
    });

    test('categorias sem marcação (100) entram na média, como no backend', () {
      final overall = calculateOverallScore(const [86.6666666666, 100, 100, 100]);
      expect(overall, closeTo(96.6666, 0.001));
    });
  });

  group('getApprovalStatus', () {
    test('(backend) APROVADO se score >= 70', () {
      expect(getApprovalStatus(70), 'APROVADO');
      expect(getApprovalStatus(85), 'APROVADO');
      expect(getApprovalStatus(100), 'APROVADO');
    });

    test('(backend) NECESSITA_REAVALIACAO se score < 70', () {
      expect(getApprovalStatus(69), 'NECESSITA_REAVALIACAO');
      expect(getApprovalStatus(0), 'NECESSITA_REAVALIACAO');
    });

    test('o corte não arredonda: 69,9 ainda precisa de reavaliação', () {
      expect(getApprovalStatus(69.9), 'NECESSITA_REAVALIACAO');
    });
  });
}
