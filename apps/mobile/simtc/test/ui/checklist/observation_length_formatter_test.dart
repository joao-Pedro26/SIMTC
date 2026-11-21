import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/checklist/observation_length_formatter.dart';

void main() {
  const formatter = ObservationLengthFormatter(5);

  TextEditingValue value(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );

  test('aceita texto até o limite, em unidades UTF-16', () {
    expect(formatter.formatEditUpdate(value(''), value('abcde')).text, 'abcde');
    // O emoji vale 2 unidades: 3 + 2 = 5.
    expect(formatter.formatEditUpdate(value(''), value('abc😀')).text, 'abc😀');
  });

  test('corta no limite', () {
    expect(formatter.formatEditUpdate(value('abcde'), value('abcdef')).text, 'abcde');
  });

  test('nunca parte um emoji ao meio: o par de substitutos inteiro fica de fora',
      () {
    final result = formatter.formatEditUpdate(value('abcd'), value('abcd😀'));
    expect(result.text, 'abcd');
    expect(result.selection, const TextSelection.collapsed(offset: 4));
  });

  test('no limite, digitar no meio devolve o valor antigo (nada some, cursor fica)',
      () {
    const old = TextEditingValue(
      text: 'abcde',
      selection: TextSelection.collapsed(offset: 2),
    );
    const typed = TextEditingValue(
      text: 'abXcde',
      selection: TextSelection.collapsed(offset: 3),
    );
    final result = formatter.formatEditUpdate(old, typed);
    expect(result, old);
  });

  test('colagem acima do limite com texto antigo abaixo corta sem partir emoji',
      () {
    const old = TextEditingValue(
      text: 'abc',
      selection: TextSelection.collapsed(offset: 3),
    );
    final pasted = value('abcde😀');
    final result = formatter.formatEditUpdate(old, pasted);
    expect(result.text, 'abcde');
    expect(result.selection, const TextSelection.collapsed(offset: 5));
  });

  test('o corte mantem o cursor dentro do texto cortado', () {
    const old = TextEditingValue(
      text: 'abc',
      selection: TextSelection.collapsed(offset: 1),
    );
    const pasted = TextEditingValue(
      text: 'aXYZWb',
      selection: TextSelection.collapsed(offset: 4),
    );
    final result = formatter.formatEditUpdate(old, pasted);
    expect(result.text, 'aXYZW');
    expect(result.selection, const TextSelection.collapsed(offset: 4));
  });
}
