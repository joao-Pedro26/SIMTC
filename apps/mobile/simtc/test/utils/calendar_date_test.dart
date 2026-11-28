import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/utils/calendar_date.dart';

void main() {
  group('calendarDateFromApi', () {
    test('lê o ISO da API em UTC, sem deslocar o dia', () {
      expect(calendarDateFromApi('2027-03-12T00:00:00.000Z'), '2027-03-12');
    });

    test('aceita a data já no formato AAAA-MM-DD', () {
      expect(calendarDateFromApi('2027-03-12'), '2027-03-12');
    });

    test('nulo e texto ilegível viram nulo', () {
      expect(calendarDateFromApi(null), isNull);
      expect(calendarDateFromApi('xx'), isNull);
    });
  });

  group('calendarDateFromBr', () {
    test('converte dd/mm/aaaa para AAAA-MM-DD', () {
      expect(calendarDateFromBr('12/03/2027'), '2027-03-12');
    });

    test('datas que não existem viram nulo', () {
      expect(calendarDateFromBr('31/02/2027'), isNull);
      expect(calendarDateFromBr('00/13/2027'), isNull);
    });

    test('ano fora de 2000 a 2099 ou incompleto vira nulo', () {
      expect(calendarDateFromBr('12/03/0227'), isNull);
      expect(calendarDateFromBr('12/03/20'), isNull);
    });
  });

  test('brDateFromCalendar converte AAAA-MM-DD para dd/mm/aaaa', () {
    expect(brDateFromCalendar('2027-03-12'), '12/03/2027');
  });

  group('isCalendarDateBefore', () {
    test('o dia anterior ao de hoje está vencido', () {
      expect(
        isCalendarDateBefore('2027-03-11', DateTime(2027, 3, 12, 0, 1)),
        isTrue,
      );
    });

    test('o próprio dia de hoje não está vencido, mesmo no fim do dia', () {
      expect(
        isCalendarDateBefore('2027-03-12', DateTime(2027, 3, 12, 23, 59)),
        isFalse,
      );
    });
  });
}
