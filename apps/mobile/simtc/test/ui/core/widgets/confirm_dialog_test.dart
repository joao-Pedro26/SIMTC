import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/widgets/confirm_dialog.dart';

/// Um botão abre o diálogo e guarda o resultado em [result].
Future<void> _pumpOpener(
  WidgetTester tester, {
  required void Function(bool) onResult,
  String title = 'Descartar a avaliação?',
  String message = 'A avaliação será apagada deste aparelho.',
  String confirmLabel = 'Descartar',
  String cancelLabel = 'Cancelar',
  bool destructive = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await showConfirmDialog(
                  context,
                  title: title,
                  message: message,
                  confirmLabel: confirmLabel,
                  cancelLabel: cancelLabel,
                  destructive: destructive,
                );
                onResult(result);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('mostra o título, a mensagem e os dois botões com os rótulos dados',
      (tester) async {
    await _pumpOpener(
      tester,
      onResult: (_) {},
      cancelLabel: 'Voltar',
      confirmLabel: 'Desatribuir',
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Descartar a avaliação?'), findsOneWidget);
    expect(find.text('A avaliação será apagada deste aparelho.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Voltar'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Desatribuir'), findsOneWidget);
  });

  testWidgets('confirmar devolve verdadeiro', (tester) async {
    bool? result;
    await _pumpOpener(tester, onResult: (value) => result = value);
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('cancelar, tocar fora e o voltar devolvem falso', (tester) async {
    final results = <bool>[];
    await _pumpOpener(tester, onResult: results.add);

    // Cancelar.
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    // Tocar fora do diálogo (na barreira).
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // Voltar do sistema.
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    expect(results, [false, false, false]);
  });

  testWidgets('destructive pinta o confirmar de dangerInk; sem ele, fica o estilo padrão',
      (tester) async {
    await _pumpOpener(tester, onResult: (_) {});
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final destructiveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Descartar'),
    );
    expect(
      destructiveButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.dangerInk,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    await _pumpOpener(
      tester,
      onResult: (_) {},
      destructive: false,
      confirmLabel: 'Iniciar',
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final plainButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Iniciar'),
    );
    expect(plainButton.style, isNull);
  });

  testWidgets('cancelLabel troca o texto do cancelar', (tester) async {
    await _pumpOpener(tester, onResult: (_) {}, cancelLabel: 'Voltar');
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Voltar'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancelar'), findsNothing);
  });
}
