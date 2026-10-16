import { ConflictException } from '@nestjs/common';

/**
 * Código da recusa "o participante não está mais com quem enviou". O app
 * mobile o reconhece para mostrar um motivo próprio na aba Sincronizar, no
 * lugar do genérico "recusada pelo servidor".
 */
export const SYNC_REFUSAL_NOT_ASSIGNED = 'NOT_ASSIGNED';

/**
 * Recusa de uma avaliação no `POST /practical-assessments/sync` que leva um
 * código além da mensagem. O código sai no item da resposta (`code`), ao lado
 * de `error`.
 */
export class SyncRefusedException extends ConflictException {
  constructor(
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}
