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
}
