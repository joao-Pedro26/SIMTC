import 'package:flutter_test/flutter_test.dart';

/// As diretrizes de acessibilidade do Flutter para o que se toca (Fase 8C):
/// alvo de pelo menos 48x48 e um rótulo para o leitor de tela. O contraste é
/// conferido nos tokens (`app_contrast_test.dart`): a fonte de teste desenha
/// cada letra como um bloco, e a medida na tela engana.
Future<void> expectAccessibleTargets(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}
