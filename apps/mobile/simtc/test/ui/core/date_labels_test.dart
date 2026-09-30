import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/date_labels.dart';

void main() {
  final agora = DateTime(2026, 9, 23, 14);

  test('dayMonthYearLabel escreve a data da sessão por extenso curto', () {
    expect(dayMonthYearLabel(DateTime(2026, 9, 12)), '12 set 2026');
  });

  test('momentLabel diz "hoje" no mesmo dia', () {
    expect(momentLabel(DateTime(2026, 9, 23, 8, 5), agora), 'hoje 08:05');
  });

  test('momentLabel mostra dia e mês em outro dia do mesmo ano', () {
    expect(momentLabel(DateTime(2026, 9, 12, 17, 40), agora), '12 set 17:40');
  });

  test('momentLabel mostra o ano quando ele é outro', () {
    expect(momentLabel(DateTime(2025, 12, 30, 9, 0), agora), '30 dez 2025 09:00');
  });

  test('momentLabel converte um instante UTC para a hora local', () {
    final utc = DateTime.utc(2026, 9, 23, 11, 12);
    final local = utc.toLocal();
    String dois(int v) => v.toString().padLeft(2, '0');

    expect(momentLabel(utc, local), 'hoje ${dois(local.hour)}:${dois(local.minute)}');
  });

  test('offlineDataMessage diz a idade dos dados, e nada sem sync', () {
    expect(offlineDataMessage(DateTime(2026, 9, 20, 8, 3)),
        'Sem conexão — dados de 20/09 às 08:03.');
    expect(offlineDataMessage(null), isNull);
  });

  test('clockLabel é só a hora no mesmo dia, e dia e hora nos outros', () {
    expect(clockLabel(DateTime(2026, 9, 23, 8, 41), agora), '08:41');
    expect(clockLabel(DateTime(2026, 9, 22, 17, 2), agora), '22 set 17:02');
  });

  test('atLabel diz "às" no mesmo dia e "em" nos outros', () {
    expect(atLabel(DateTime(2026, 9, 23, 7, 58), agora), 'às 07:58');
    expect(atLabel(DateTime(2026, 9, 22, 7, 58), agora), 'em 22 set 07:58');
  });

  test('stopwatchLabel é o cronômetro, e um intervalo negativo vale zero', () {
    expect(stopwatchLabel(const Duration(minutes: 12, seconds: 41)), '00:12:41');
    expect(stopwatchLabel(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
    expect(stopwatchLabel(const Duration(seconds: -5)), '00:00:00');
  });
}
