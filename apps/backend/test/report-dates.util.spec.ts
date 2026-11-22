import {
  formatCalendarDate,
  formatClock,
  formatLongDate,
  formatMonthYear,
} from 'src/certificates/report-dates.util';

// O resultado não pode depender do fuso da máquina: produção roda em UTC, o
// notebook do João em Brasília.
describe('report-dates.util', () => {
  // Data de calendário como o backend grava: `new Date('AAAA-MM-DD')`.
  const day = new Date('2026-11-01');

  it('data de calendário sai no mesmo dia, e não no anterior', () => {
    expect(formatCalendarDate(day)).toBe('01/11/2026');
  });

  it('data por extenso e mês do rodapé', () => {
    expect(formatLongDate(day)).toBe('01 de Novembro de 2026');
    expect(formatMonthYear(day)).toBe('Novembro/2026');
  });

  it('horário sai no fuso de Brasília', () => {
    // 11:30 UTC = 08:30 em Brasília (UTC-3, sem horário de verão)
    expect(formatClock(new Date('2026-11-20T11:30:00.000Z'))).toBe('08:30h');
  });

  it('avaliação perto da meia-noite UTC continua no horário local', () => {
    // 01:15 UTC do dia 21 = 22:15 do dia 20 em Brasília
    expect(formatClock(new Date('2026-11-21T01:15:00.000Z'))).toBe('22:15h');
  });
});
