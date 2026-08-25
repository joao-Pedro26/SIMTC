// src/features/training-sessions/types.ts

export type TrainingStatus =
  | 'PLANEJADO'
  | 'EM_ANDAMENTO'
  | 'CONCLUIDO'
  | 'CANCELADO'

export type ParticipationType = 'SOMENTE_TEORICA' | 'TEORICA_E_PRATICA'

export type ParticipantStatus =
  | 'PENDENTE'
  | 'EM_AVALIACAO'
  | 'APROVADO'
  | 'NECESSITA_REAVALIACAO'

export interface TrainingCompany {
  id: string
  name: string
  logoUrl?: string | null
}

export interface TrainingCourse {
  id: string
  name: string
  theoryHours: number
  practiceHours: number
}

export interface TrainingConsultant {
  id: string
  name: string
}

export interface TrainingParticipant {
  id: string
  name: string
  cpf: string
  email: string
  cnhCategory: string
  cnhExpiration: string
  type: ParticipationType
  status: ParticipantStatus
  score: number | null
  certificateGenerated: boolean
  certificateId: string | null
  certificatePdfUrl: string | null
  assignedConsultantId?: string | null
  assignedConsultant?: { id: string; name: string } | null
}

export interface TrainingSession {
  id: string
  company: TrainingCompany
  course: TrainingCourse
  responsibleConsultant: TrainingConsultant | null
  additionalConsultants: TrainingConsultant[]
  city: string
  state: string
  date: string
  participantCount: number
  notes: string | null
  status: TrainingStatus
  qrCodeToken: string
  participants: TrainingParticipant[]
}
