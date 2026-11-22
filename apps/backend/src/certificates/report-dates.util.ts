/**
 * Datas e horas que saem nos PDFs, sem depender do fuso do servidor.
 *
 * - Datas de calendário (data da sessão, da avaliação, validade da CNH) chegam
 *   como `AAAA-MM-DD` e são gravadas à meia-noite UTC: leem-se em UTC. Lidas no
 *   fuso de Brasília, cairiam no dia anterior.
 * - Horários (início e término da avaliação) são instantes de verdade: leem-se
 *   no fuso de Brasília. O container de produção roda em UTC, e sem isso o
 *   relatório saía 3 horas adiantado.
 */
export const REPORT_TIME_ZONE = 'America/Sao_Paulo';

const MONTHS = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

/** "22/11/2026" */
export function formatCalendarDate(date: Date): string {
  return date.toLocaleDateString('pt-BR', { timeZone: 'UTC' });
}

/** "22 de Novembro de 2026" */
export function formatLongDate(date: Date): string {
  return `${String(date.getUTCDate()).padStart(2, '0')} de ${MONTHS[date.getUTCMonth()]} de ${date.getUTCFullYear()}`;
}

/** "Novembro/2026" (rodapé do relatório de avaliação) */
export function formatMonthYear(date: Date): string {
  return `${MONTHS[date.getUTCMonth()]}/${date.getUTCFullYear()}`;
}

/** "08:30h", no horário de Brasília */
export function formatClock(instant: Date): string {
  return (
    instant.toLocaleTimeString('pt-BR', {
      hour: '2-digit',
      minute: '2-digit',
      timeZone: REPORT_TIME_ZONE,
    }) + 'h'
  );
}
