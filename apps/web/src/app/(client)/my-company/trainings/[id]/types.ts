export type ParticipantStatus =
  | 'PENDENTE'
  | 'EM_AVALIACAO'
  | 'APROVADO'
  | 'NECESSITA_REAVALIACAO'

export interface SessionParticipant {
  participantId: string
  participant: { id: string; name: string }
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
