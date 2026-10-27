import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A ondulação do toque aparece (Fase 8C): o fundo é de um `Material` acima
/// do [inkWell] na árvore — pintado embaixo da ondulação —, e não de um
/// `Container` filho dele, que pintaria por cima.
void expectVisibleRipple(
  WidgetTester tester,
  Finder inkWell, {
  required Color background,
}) {
  final child = tester.widget<InkWell>(inkWell).child;
  final decoration = child is Container ? child.decoration : null;
  expect(
    decoration is BoxDecoration ? decoration.color : null,
    isNull,
    reason: 'um fundo no filho do InkWell cobre a ondulação',
  );
  final material = tester.widget<Material>(
    find.ancestor(of: inkWell, matching: find.byType(Material)).first,
  );
  expect(material.color, background);
}
