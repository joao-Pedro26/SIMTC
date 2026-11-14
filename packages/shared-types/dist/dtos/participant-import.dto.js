"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PARTICIPANT_IMPORT_MAX_BYTES = exports.PARTICIPANT_IMPORT_MAX_ROWS = void 0;
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
exports.PARTICIPANT_IMPORT_MAX_ROWS = 500;
exports.PARTICIPANT_IMPORT_MAX_BYTES = 2 * 1024 * 1024;
//# sourceMappingURL=participant-import.dto.js.map