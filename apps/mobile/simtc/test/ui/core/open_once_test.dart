import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/open_once.dart';

void main() {
  late BuildContext ctx;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }),
    ));
  }

  testWidgets('o segundo pedido no mesmo quadro é recusado', (tester) async {
    await pumpApp(tester);
    expect(ctx.claimOpen(), isTrue);
    expect(ctx.claimOpen(), isFalse);
    await tester.pump();
  });

  testWidgets('depois do quadro, a trava solta', (tester) async {
    await pumpApp(tester);
    expect(ctx.claimOpen(), isTrue);
    await tester.pump();
    expect(ctx.claimOpen(), isTrue);
    await tester.pump();
  });

  testWidgets('com outra tela por cima, é recusado', (tester) async {
    await pumpApp(tester);
    final debaixo = ctx;
    Navigator.of(debaixo).push(MaterialPageRoute<void>(
      builder: (_) => const Text('por cima'),
    ));
    await tester.pumpAndSettle();
    expect(debaixo.claimOpen(), isFalse);
    await tester.pump();
  });
}
