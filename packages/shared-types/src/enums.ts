// ─── ENUMS COMPARTILHADOS ─────────────────────────────────────────────────────
// Definidos aqui uma vez — importados pelo backend (NestJS) e pelo web (Next.js)

export enum VehicleType {
  LEVE   = 'LEVE',
  PESADO = 'PESADO',
  MOTO   = 'MOTO',
}

export enum NoteType {
  B  = 'B',   // Bom — sem dedução
  PM = 'PM',  // Pode Melhorar — deduz 3 pontos
  M  = 'M',   // Melhorar — deduz 5 pontos
}

export enum DemandStatus {
  QUALIFICACAO = 'QUALIFICACAO',
  ANALISE      = 'ANALISE',
  PROPOSTA     = 'PROPOSTA',
  AGENDAMENTO  = 'AGENDAMENTO',
  CONCLUIDO    = 'CONCLUIDO',
  PERDIDO      = 'PERDIDO',
}

export enum TrainingStatus {
  PLANEJADO     = 'PLANEJADO',
  EM_ANDAMENTO  = 'EM_ANDAMENTO',
  CONCLUIDO     = 'CONCLUIDO',
  CANCELADO     = 'CANCELADO',
}

export enum ParticipationType {
  SOMENTE_TEORICA   = 'SOMENTE_TEORICA',
  TEORICA_E_PRATICA = 'TEORICA_E_PRATICA',
}

export enum ParticipantStatus {
  PENDENTE              = 'PENDENTE',
  EM_AVALIACAO          = 'EM_AVALIACAO',
  APROVADO              = 'APROVADO',
  NECESSITA_REAVALIACAO = 'NECESSITA_REAVALIACAO',
}

export enum UserRole {
  ADMIN      = 'ADMIN',
  CONSULTANT = 'CONSULTANT',
  CLIENT     = 'CLIENT',
}
