export type ParticipantStatus =
  | 'PENDENTE'
  | 'EM_AVALIACAO'
  | 'APROVADO'
  | 'NECESSITA_REAVALIACAO'

export interface SessionParticipant {
  /** PK da linha TrainingParticipant (join table) — usar este para ações em lote (bulk-download etc). */
  id: string
  /** FK para Participant.id — apenas para referência/exibição, NÃO usar em ações que operam sobre a matrícula. */
  participantId: string
  participant: {
    id: string
    name: string
    cpf: string
    email: string | null
    cnhCategory: string | null
    cnhExpiration: string | null
  }
  status: ParticipantStatus
  assessment: { score: number | null } | null
}

export interface AssessmentReportRow {
  participantId: string
  participantName: string
  status: ParticipantStatus
  assessmentReport: {
    id: string
    pdfUrl: string
    generatedAt: string
  } | null
}

export interface CertificateRow {
  participantId: string
  participantName: string
  status: ParticipantStatus
  certificate: {
    id: string
    pdfUrl: string
    generatedAt: string
    sentToParticipant: boolean
    sentToCompany: boolean
  } | null
}

export interface SessionDetail {
  id: string
  city: string
  state: string
  date: string | null
  course: { name: string }
  participants: SessionParticipant[]
}
