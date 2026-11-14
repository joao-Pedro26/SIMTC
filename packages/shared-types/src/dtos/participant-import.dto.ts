import { ParticipationType } from '../enums';

/**
 * Contrato da importação de participantes por planilha (só ADMIN):
 *
 * - `POST /training-sessions/:id/participants/import/preview` (multipart, campo
 *   `file`) → `ParticipantImportPreviewResponse`. Não grava nada.
 * - `POST /training-sessions/:id/participants/import` (JSON
 *   `ImportParticipantsDto`) → `ParticipantImportResult`. O servidor revalida e
 *   reclassifica cada linha; o que veio da prévia não é confiável. O tipo de
 *   participação não vem do cliente: o servidor o deriva do curso (com horas
 *   práticas = `TEORICA_E_PRATICA`, sem = `SOMENTE_TEORICA`).
 * - `GET /participants/import/template` → `modelo-importacao-participantes.xlsx`.
 */

export const PARTICIPANT_IMPORT_MAX_ROWS = 500;
export const PARTICIPANT_IMPORT_MAX_BYTES = 2 * 1024 * 1024;

export type ParticipantImportRowStatus =
  | 'NOVO'
  | 'ATUALIZA_E_INSCREVE'
  | 'JA_INSCRITO'
  | 'DUPLICADO_NA_PLANILHA'
  | 'ERRO';

/** Campos de uma linha já normalizados. `cpf` só com dígitos; `cnhExpiration` em aaaa-mm-dd. */
export interface ParticipantImportRowDto {
  /** Número da linha no arquivo (1 = primeira linha). */
  rowNumber: number;
  name: string;
  cpf: string;
  email?: string;
  cnhCategory?: string;
  cnhExpiration?: string;
}

export interface ParticipantImportChange {
  field: 'name' | 'email' | 'cnhCategory' | 'cnhExpiration';
  from: string | null;
  to: string;
}

export interface ParticipantImportPreviewRow extends ParticipantImportRowDto {
  status: ParticipantImportRowStatus;
  errors: string[];
  warnings: string[];
  /** Só em `ATUALIZA_E_INSCREVE`: o que muda no cadastro já existente. */
  changes?: ParticipantImportChange[];
}

export interface ParticipantImportTotals {
  total: number;
  novo: number;
  atualizaEInscreve: number;
  jaInscrito: number;
  duplicado: number;
  erro: number;
}

export interface ParticipantImportPreviewResponse {
  /** Tipo com que todas as linhas serão inscritas, derivado do curso do treinamento. */
  participationType: ParticipationType;
  /** Aba lida; `null` em CSV. */
  sheetName: string | null;
  headerRow: number;
  ignoredColumns: string[];
  rows: ParticipantImportPreviewRow[];
  totals: ParticipantImportTotals;
}

export interface ImportParticipantsDto {
  rows: ParticipantImportRowDto[];
}

export interface ParticipantImportSkipped {
  rowNumber: number;
  cpf: string;
  reason: string;
}

/** `skipped`: linha recusada pela regra (erro, duplicada, já inscrita). `failed`: erro inesperado ao gravar. */
export interface ParticipantImportResult {
  created: number;
  updatedAndEnrolled: number;
  skipped: ParticipantImportSkipped[];
  failed: ParticipantImportSkipped[];
}
