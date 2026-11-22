import { IsISO8601, IsOptional, Matches } from 'class-validator';

/**
 * Correção, pelo ADMIN, da data e dos horários de uma avaliação já salva —
 * o que sai no relatório ("Data", "Hora início", "Hora término"). A nota e as
 * faltas não mudam.
 */
export class UpdateAssessmentTimesDto {
  /** Data de calendário, `AAAA-MM-DD` (mesmo formato do `sync`). */
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'date deve estar no formato AAAA-MM-DD' })
  date!: string;

  /** Instante ISO 8601 (a web manda em UTC). */
  @IsISO8601({ strict: true })
  startTime!: string;

  /** Opcional: sem ele, a avaliação fica sem hora de término. */
  @IsOptional()
  @IsISO8601({ strict: true })
  endTime?: string;
}
