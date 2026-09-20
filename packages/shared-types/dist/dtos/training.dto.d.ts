import { ParticipationType, TrainingStatus } from '../enums';
export interface CreateTrainingSessionDto {
    companyId: string;
    courseId: string;
    responsibleConsultantId: string;
    city: string;
    state: string;
    date?: string;
    participantCount?: number;
    notes?: string;
    consultantIds?: string[];
}
export interface UpdateTrainingSessionDto extends Partial<CreateTrainingSessionDto> {
    status?: TrainingStatus;
}
export interface RegisterParticipantPublicDto {
    name: string;
    cpf: string;
    email?: string;
    cnhCategory?: string;
    cnhExpiration?: string;
    participationType?: ParticipationType;
}
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
    /** Avaliáveis já concluídos (`APROVADO` ou `NECESSITA_REAVALIACAO`). */
    assessed: number;
}
//# sourceMappingURL=training.dto.d.ts.map