import { ParticipationType, TrainingStatus } from '../enums';

export interface CreateTrainingSessionDto {
  companyId: string;
  courseId: string;
  responsibleConsultantId: string;
  city: string;
  state: string;
  date?: string;         // ISO date
  participantCount?: number;
  notes?: string;
  consultantIds?: string[];
}

export interface UpdateTrainingSessionDto extends Partial<CreateTrainingSessionDto> {
  status?: TrainingStatus;
}

/**
 * O que fazer com a assinatura do participante na inscrição pública:
 * 'replace' envia a nova (arquivo PNG), 'keep' mantém a atual, 'none' não toca nela.
 */
export type SignatureAction = 'keep' | 'replace' | 'none';

export interface RegisterParticipantPublicDto {
  name: string;
  cpf: string;
  email?: string;
  cnhCategory?: string;
  cnhExpiration?: string; // ISO date
  participationType?: ParticipationType;
  signatureAction?: SignatureAction; // ausente = 'none'
}

/**
 * Resposta da inscrição pública: a linha `TrainingParticipant` criada, mais
 * o resultado da assinatura. `signatureIgnored` só aparece quando a nova
 * assinatura foi recusada (e-mail não confere ou conflito de gravação).
 */
export interface RegisterParticipantPublicResponse {
  id: string;
  trainingSessionId: string;
  participantId: string;
  participationType: ParticipationType;
  status: string;
  registeredAt: string; // ISO date
  signatureSaved: boolean;
  signatureIgnored?: boolean;
}

/**
 * Prévia da assinatura na inscrição pública. 'none': sem assinatura (ou CPF não
 * cadastrado). 'locked': há assinatura, mas o e-mail não confere (sem prévia).
 * 'found': CPF e e-mail conferem; `previewUrl` é uma signed URL de 120 s.
 */
export type SignaturePreviewResponse =
  | { status: 'none' }
  | { status: 'found'; previewUrl: string; updatedAt: string }
  | { status: 'locked' };

export interface UpdateParticipantTypeDto {
  participationType: ParticipationType;
}

/** Contagem de participantes de uma sessão, devolvida na listagem. */
export interface TrainingSessionParticipantStats {
  /** Todos os participantes inscritos na sessão. */
  total: number;
  /**
   * Participantes que recebem avaliação prática (`TEORICA_E_PRATICA`).
   * É o denominador do progresso: quem é `SOMENTE_TEORICA` nunca é avaliado,
   * então incluí-lo faria a barra nunca chegar a 100%.
   */
  assessable: number;
  /** Avaliáveis já concluídos (`APROVADO` ou `NAO_RECOMENDADO`). */
  assessed: number;
}
