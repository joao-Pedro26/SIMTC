# Task 1: Types e Mock Data

## Context
You are implementing the training sessions screen for SIMTC, a Next.js 14 web admin app.
This is the foundation task — all other tasks depend on the types and mock data you create here.
Working directory: `C:\Users\joaop\Claude\Projects\App de Treinamento SIMTC\apps\web`

## Files to Create
- `src/features/training-sessions/types.ts`
- `src/features/training-sessions/mock-data.ts`

## Step 1: Create `src/features/training-sessions/types.ts`

```ts
// src/features/training-sessions/types.ts

export type TrainingStatus =
  | 'PLANEJADO'
  | 'EM_ANDAMENTO'
  | 'CONCLUIDO'
  | 'ARQUIVADO'
  | 'CANCELADO'

export type ParticipationType = 'SOMENTE_TEORICA' | 'TEORICA_E_PRATICA'

export type ParticipantStatus =
  | 'PENDENTE'
  | 'EM_AVALIACAO'
  | 'APROVADO'
  | 'NECESSITA_REAVALIACAO'

export interface TrainingCompany {
  id: number
  name: string
  logoUrl: string | null
}

export interface TrainingCourse {
  id: number
  name: string
  theoryHours: number
  practiceHours: number
}

export interface TrainingConsultant {
  id: number
  name: string
}

export interface TrainingParticipant {
  id: number
  name: string
  cpf: string
  email: string
  cnhCategory: string
  cnhExpiration: string
  type: ParticipationType
  status: ParticipantStatus
  score: number | null
  certificateGenerated: boolean
}

export interface TrainingSession {
  id: number
  company: TrainingCompany
  course: TrainingCourse
  responsibleConsultant: TrainingConsultant
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
```

## Step 2: Create `src/features/training-sessions/mock-data.ts`

```ts
// src/features/training-sessions/mock-data.ts

import type { TrainingSession, TrainingCompany, TrainingCourse, TrainingConsultant } from './types'

export const mockTrainingSessions: TrainingSession[] = [
  {
    id: 1,
    company: { id: 1, name: 'Louis Dreyfus Company Brasil S.A', logoUrl: null },
    course: { id: 1, name: 'Direção Preventiva 4h', theoryHours: 4, practiceHours: 2 },
    responsibleConsultant: { id: 1, name: 'Sebastião Souza' },
    additionalConsultants: [
      { id: 2, name: 'Francisco Camargo Filho' },
      { id: 3, name: 'Rene Dias' },
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
        id: 1, name: 'João da Silva', cpf: '123.456.789-00', email: 'joao@email.com',
        cnhCategory: 'B', cnhExpiration: '2028-03-10',
        type: 'TEORICA_E_PRATICA', status: 'APROVADO', score: 88, certificateGenerated: true,
      },
      {
        id: 2, name: 'Maria Souza', cpf: '987.654.321-00', email: 'maria@email.com',
        cnhCategory: 'AB', cnhExpiration: '2027-06-15',
        type: 'SOMENTE_TEORICA', status: 'PENDENTE', score: null, certificateGenerated: false,
      },
      {
        id: 3, name: 'Carlos Pereira', cpf: '111.222.333-44', email: 'carlos@email.com',
        cnhCategory: 'B', cnhExpiration: '2026-11-20',
        type: 'TEORICA_E_PRATICA', status: 'NECESSITA_REAVALIACAO', score: 62, certificateGenerated: false,
      },
    ],
  },
  {
    id: 2,
    company: { id: 2, name: 'BRACELL SP CELULOSE LTDA', logoUrl: null },
    course: { id: 2, name: 'Direção Preventiva Veículos Pesados 8h', theoryHours: 8, practiceHours: 4 },
    responsibleConsultant: { id: 2, name: 'Francisco Camargo Filho' },
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
        id: 4, name: 'Ana Lima', cpf: '555.666.777-88', email: 'ana@email.com',
        cnhCategory: 'C', cnhExpiration: '2029-01-05',
        type: 'TEORICA_E_PRATICA', status: 'APROVADO', score: 91, certificateGenerated: true,
      },
    ],
  },
  {
    id: 3,
    company: { id: 3, name: 'Jalles Machado', logoUrl: null },
    course: { id: 1, name: 'Direção Preventiva 4h', theoryHours: 4, practiceHours: 2 },
    responsibleConsultant: { id: 3, name: 'Rene Dias' },
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
    id: 4,
    company: { id: 4, name: 'Agrex do Brasil', logoUrl: null },
    course: { id: 3, name: 'Palestra Segurança no Trânsito 1h', theoryHours: 1, practiceHours: 0 },
    responsibleConsultant: { id: 1, name: 'Sebastião Souza' },
    additionalConsultants: [],
    city: 'Goiânia',
    state: 'GO',
    date: '2025-11-20',
    participantCount: 80,
    notes: null,
    status: 'ARQUIVADO',
    qrCodeToken: 'token-jkl-012',
    participants: [],
  },
]

export const mockConsultants: TrainingConsultant[] = [
  { id: 1, name: 'Sebastião Souza' },
  { id: 2, name: 'Francisco Camargo Filho' },
  { id: 3, name: 'Rene Dias' },
  { id: 4, name: 'Mauricio Gomes de Oliveira' },
]

export const mockCompanies: TrainingCompany[] = [
  { id: 1, name: 'Louis Dreyfus Company Brasil S.A', logoUrl: null },
  { id: 2, name: 'BRACELL SP CELULOSE LTDA', logoUrl: null },
  { id: 3, name: 'Jalles Machado', logoUrl: null },
  { id: 4, name: 'Agrex do Brasil', logoUrl: null },
]

export const mockCourses: TrainingCourse[] = [
  { id: 1, name: 'Direção Preventiva 4h', theoryHours: 4, practiceHours: 2 },
  { id: 2, name: 'Direção Preventiva Veículos Pesados 8h', theoryHours: 8, practiceHours: 4 },
  { id: 3, name: 'Palestra Segurança no Trânsito 1h', theoryHours: 1, practiceHours: 0 },
]
```

## Step 3: Verify type-check

```bash
cd "C:\Users\joaop\Claude\Projects\App de Treinamento SIMTC\apps\web"
npm run type-check
```

Expected: no errors related to training-sessions/

## Step 4: Commit

```bash
git add src/features/training-sessions/types.ts src/features/training-sessions/mock-data.ts
git commit -m "feat(training-sessions): add types and mock data"
```

## Report Contract

Write your full report to: `C:\Users\joaop\Claude\Projects\App de Treinamento SIMTC\apps\web\.superpowers\sdd\task-1-report.md`

Include:
- Files created
- type-check output
- Commit hash
- Any concerns

Return only: status (DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED), commit hash, one-line test summary, and any concerns.
