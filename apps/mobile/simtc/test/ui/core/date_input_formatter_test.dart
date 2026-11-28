import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/date_input_formatter.dart';

void main() {
  const formatter = DateInputFormatter();

  TextEditingValue typed(String text) {
    return formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
  }

  test('põe as barras conforme os dígitos chegam', () {
    expect(typed('12032027').text, '12/03/2027');
    expect(typed('1203').text, '12/03');
    expect(typed('12').text, '12');
    expect(typed('123').text, '12/3');
  });

  test('descarta o que passa do 8º dígito', () {
    expect(typed('120320271').text, '12/03/2027');
  });

  test('descarta o que não é dígito', () {
    expect(typed('1a2/b0').text, '12/0');
    expect(typed('abc').text, '');
  });

  test('o cursor fica no fim do texto mascarado', () {
    expect(typed('1203').selection, const TextSelection.collapsed(offset: 5));
  });

  test('o cursor fica onde a pessoa digita, no meio do texto', () {
    // "12/03/2027" com um 9 digitado depois do "1": cursor após o 2º dígito.
    final value = formatter.formatEditUpdate(
      const TextEditingValue(text: '12/03/2027'),
      const TextEditingValue(
        text: '192/03/2027',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );

    expect(value.text, '19/20/3202');
    expect(value.selection, const TextSelection.collapsed(offset: 2));
  });
}
