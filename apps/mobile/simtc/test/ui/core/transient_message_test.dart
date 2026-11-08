import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/transient_message.dart';

/// Uma tela de teste que agenda o aviso ao receber [message] e pode sair da
/// árvore antes do quadro seguinte.
class _Screen extends StatefulWidget {
  const _Screen({required this.message});

  final String message;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('tela'));
  }

  void schedule() => showTransientMessage(this, widget.message);
}

void main() {
  testWidgets('mostra o aviso no quadro seguinte', (tester) async {
    const message = 'Não foi possível atualizar.';
    await tester.pumpWidget(
      const MaterialApp(home: _Screen(message: message)),
    );

    tester.state<_ScreenState>(find.byType(_Screen)).schedule();
    // Ainda não: o aviso sai no quadro seguinte.
    expect(find.text(message), findsNothing);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(message), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('não mostra nada se a tela saiu antes do quadro', (tester) async {
    const message = 'Não foi possível atualizar.';
    await tester.pumpWidget(
      const MaterialApp(home: _Screen(message: message)),
    );

    tester.state<_ScreenState>(find.byType(_Screen)).schedule();
    // A tela sai da árvore antes do quadro que mostraria o aviso.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text(message), findsNothing);
  });
}
