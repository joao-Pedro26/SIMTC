import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/cpf_input_formatter.dart';

void main() {
  const formatter = CpfInputFormatter();

  TextEditingValue typed(String text) {
    return formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
  }

  test('põe os pontos e o traço conforme os dígitos chegam', () {
    expect(typed('5299').text, '529.9');
    expect(typed('5299822').text, '529.982.2');
    expect(typed('52998224725').text, '529.982.247-25');
  });

  test('o cursor fica no fim do texto mascarado', () {
    final value = typed('5299822');

    expect(value.selection, const TextSelection.collapsed(offset: 9));
  });

  test('descarta letras e o que passa do 11º dígito', () {
    expect(typed('529a982b247c25999').text, '529.982.247-25');
  });

  test('apagar o dígito depois do traço leva o traço junto', () {
    // "529.982.247-2" com o backspace vira "529.982.247-".
    expect(typed('529.982.247-').text, '529.982.247');
    expect(typed('529.').text, '529');
  });

  testWidgets('num campo de verdade, mascara enquanto se digita', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            inputFormatters: const [CpfInputFormatter()],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '52998224725');

    expect(controller.text, '529.982.247-25');
  });
}
