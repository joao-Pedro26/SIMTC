/**
 * Data e horários de uma avaliação prática, como o admin edita na tela
 * (`<input type="date">` e `<input type="time">`), e a conversão para o que o
 * backend grava. É o que sai no relatório: "Data", "Hora início", "Hora término".
 *
 * - `date` vai como `AAAA-MM-DD` (o backend grava à meia-noite UTC, como a data
 *   da sessão).
 * - Os horários são lidos no fuso do navegador e vão como instantes ISO em UTC.
 */
export interface AssessmentTimes {
  /** AAAA-MM-DD */
  date: string
  /** HH:mm */
  start: string
  /** HH:mm */
  end: string
}

const pad = (n: number) => String(n).padStart(2, '0')

/** Data local do navegador em AAAA-MM-DD (o `toISOString` daria o dia UTC). */
export function toDateInput(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

/** Hora local em HH:mm */
export function toTimeInput(d: Date): string {
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`
}

/** Valores iniciais a partir de instantes (os da avaliação, ou "agora"). */
export function assessmentTimesFrom(start: Date, end: Date | null, date?: string | null): AssessmentTimes {
  return {
    date: date || toDateInput(start),
    start: toTimeInput(start),
    end: end ? toTimeInput(end) : '',
  }
}

/** A partir de uma avaliação salva (`date` à meia-noite UTC, horários ISO). */
export function assessmentTimesFromSaved(saved: {
  date: string
  startTime: string
  endTime?: string | null
}): AssessmentTimes {
  return assessmentTimesFrom(
    new Date(saved.startTime),
    saved.endTime ? new Date(saved.endTime) : null,
    saved.date.split('T')[0],
  )
}

/** Combina data e hora no fuso do navegador. */
function localInstant(date: string, time: string): Date {
  // "AAAA-MM-DDTHH:mm" sem fuso é lido como horário local.
  return new Date(`${date}T${time}`)
}

/** Mensagem do primeiro problema, ou null se está tudo certo. */
export function assessmentTimesError(t: AssessmentTimes, now: Date = new Date()): string | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(t.date)) return 'Informe a data da avaliação.'
  if (!/^\d{2}:\d{2}$/.test(t.start)) return 'Informe a hora de início.'
  if (!/^\d{2}:\d{2}$/.test(t.end)) return 'Informe a hora de término.'
  if (t.date > toDateInput(now)) return 'A data da avaliação não pode ser no futuro.'
  if (t.end <= t.start) return 'A hora de término precisa ser depois da hora de início.'
  return null
}

/** Corpo para o backend (`sync` e `PATCH /practical-assessments/:id/times`). */
export function assessmentTimesPayload(t: AssessmentTimes) {
  return {
    date: t.date,
    startTime: localInstant(t.date, t.start).toISOString(),
    endTime: localInstant(t.date, t.end).toISOString(),
  }
}
