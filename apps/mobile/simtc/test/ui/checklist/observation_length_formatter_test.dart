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
}
