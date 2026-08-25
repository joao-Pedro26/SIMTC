// src/features/training-sessions/mock-data.ts
// Arquivo de dados de exemplo — usado apenas em componentes que ainda não consomem a API real.

import type { TrainingSession, TrainingCompany, TrainingCourse, TrainingConsultant } from './types'

export const mockTrainingSessions: TrainingSession[] = [
  {
    id: 'mock-1',
    company: { id: 'mock-c1', name: 'Louis Dreyfus Company Brasil S.A', logoUrl: null },
    course: { id: 'mock-crs1', name: 'Direção Preventiva 4h', theoryHours: 4, practiceHours: 2 },
    responsibleConsultant: { id: 'mock-con1', name: 'Sebastião Souza' },
    additionalConsultants: [
      { id: 'mock-con2', name: 'Francisco Camargo Filho' },
      { id: 'mock-con3', name: 'Rene Dias' },
    ],
    city: 'Guarulhos',
    state: 'SP',
    date: '2026-07-22',
    participantCount: 20,
    notes: 'Treinamento começa às 8h',
    status: 'EM_ANDAMENTO',
    qrCodeToken: 'token-abc-123',
    participants: [
      {
        id: 'mock-p1', name: 'João da Silva', cpf: '123.456.789-00', email: 'joao@email.com',
        cnhCategory: 'B', cnhExpiration: '2028-03-10',
        type: 'TEORICA_E_PRATICA', status: 'APROVADO', score: 88, certificateGenerated: true, certificateId: 'cert-1', certificatePdfUrl: null,
      },
      {
        id: 'mock-p2', name: 'Maria Souza', cpf: '987.654.321-00', email: 'maria@email.com',
        cnhCategory: 'AB', cnhExpiration: '2027-06-15',
        type: 'SOMENTE_TEORICA', status: 'PENDENTE', score: null, certificateGenerated: false, certificateId: null, certificatePdfUrl: null,
      },
      {
        id: 'mock-p3', name: 'Carlos Pereira', cpf: '111.222.333-44', email: 'carlos@email.com',
        cnhCategory: 'B', cnhExpiration: '2026-11-20',
        type: 'TEORICA_E_PRATICA', status: 'NECESSITA_REAVALIACAO', score: 62, certificateGenerated: false, certificateId: null, certificatePdfUrl: null,
      },
    ],
  },
  {
    id: 'mock-2',
    company: { id: 'mock-c2', name: 'BRACELL SP CELULOSE LTDA', logoUrl: null },
    course: { id: 'mock-crs2', name: 'Direção Preventiva Veículos Pesados 8h', theoryHours: 8, practiceHours: 4 },
    responsibleConsultant: { id: 'mock-con2', name: 'Francisco Camargo Filho' },
    additionalConsultants: [],
    city: 'Lençóis Paulista',
    state: 'SP',
    date: '2026-07-10',
    participantCount: 15,
    notes: null,
    status: 'CONCLUIDO',
    qrCodeToken: 'token-def-456',
    participants: [
      {
        id: 'mock-p4', name: 'Ana Lima', cpf: '555.666.777-88', email: 'ana@email.com',
        cnhCategory: 'C', cnhExpiration: '2029-01-05',
        type: 'TEORICA_E_PRATICA', status: 'APROVADO', score: 91, certificateGenerated: true, certificateId: 'cert-2', certificatePdfUrl: null,
      },
    ],
  },
  {
    id: 'mock-3',
    company: { id: 'mock-c3', name: 'Jalles Machado', logoUrl: null },
    course: { id: 'mock-crs1', name: 'Direção Preventiva 4h', theoryHours: 4, practiceHours: 2 },
    responsibleConsultant: { id: 'mock-con3', name: 'Rene Dias' },
    additionalConsultants: [],
    city: 'Goianésia',
    state: 'GO',
    date: '2026-08-15',
    participantCount: 30,
    notes: 'Treinamento solicitado pelo RH',
    status: 'PLANEJADO',
    qrCodeToken: 'token-ghi-789',
    participants: [],
  },
  {
    id: 'mock-4',
    company: { id: 'mock-c4', name: 'Agrex do Brasil', logoUrl: null },
    course: { id: 'mock-crs3', name: 'Palestra Segurança no Trânsito 1h', theoryHours: 1, practiceHours: 0 },
    responsibleConsultant: { id: 'mock-con1', name: 'Sebastião Souza' },
    additionalConsultants: [],
    city: 'Goiânia',
    state: 'GO',
    date: '2025-11-20',
    participantCount: 80,
    notes: null,
    status: 'CANCELADO',
    qrCodeToken: 'token-jkl-012',
    participants: [],
  },
]

export const mockConsultants: TrainingConsultant[] = [
  { id: 'mock-con1', name: 'Sebastião Souza' },
  { id: 'mock-con2', name: 'Francisco Camargo Filho' },
  { id: 'mock-con3', name: 'Rene Dias' },
  { id: 'mock-con4', name: 'Mauricio Gomes de Oliveira' },
]

export const mockCompanies: TrainingCompany[] = [
  { id: 'mock-c1', name: 'Louis Dreyfus Company Brasil S.A', logoUrl: null },
  { id: 'mock-c2', name: 'BRACELL SP CELULOSE LTDA', logoUrl: null },
  { id: 'mock-c3', name: 'Jalles Machado', logoUrl: null },
  { id: 'mock-c4', name: 'Agrex do Brasil', logoUrl: null },
]

export const mockCourses: TrainingCourse[] = [
  { id: 'mock-crs1', name: 'Direção Preventiva 4h', theoryHours: 4, practiceHours: 2 },
  { id: 'mock-crs2', name: 'Direção Preventiva Veículos Pesados 8h', theoryHours: 8, practiceHours: 4 },
  { id: 'mock-crs3', name: 'Palestra Segurança no Trânsito 1h', theoryHours: 1, practiceHours: 0 },
]
