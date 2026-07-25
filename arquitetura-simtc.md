# Arquitetura SIMTC — Documento de Referência

**Projeto:** App de Treinamento SIM Treinamentos  
**Versão:** 2.1 — 22/07/2026  
**Baseado em:** Reunião 21/07/2026 + análise das 38 telas do PowerApp  

---

## 1. Visão Geral

O sistema SIMTC substitui o PowerApp atual da Microsoft por uma plataforma própria composta de cinco frentes:

- **Web Admin** (Next.js): painel exclusivo do Sebastião para operações restritas — gerenciar empresas, consultores, cursos, categorias de avaliação, funil de demandas, geração de documentação e relatórios globais
- **Painel do Consultor** (Next.js): acesso web restrito para consultores — visualizar próprias sessões, ver participantes, acompanhar resultados e exibir QR Code em campo
- **Formulário Público** (Next.js, sem login): auto-cadastro de participantes via QR Code gerado para cada turma
- **Portal do Cliente** (Next.js, login restrito): responsáveis das empresas clientes visualizam seus próprios treinamentos e baixam certificados
- **App Mobile** (Flutter): consultores/instrutores realizam avaliações práticas em campo, com suporte offline completo

Todas as frentes se comunicam com um único **backend NestJS** que expõe uma API REST, conectado a um banco **PostgreSQL gerenciado pelo Supabase**.

---

## 2. Stack Técnica

| Camada | Tecnologia | Justificativa |
|--------|------------|---------------|
| Backend | NestJS + TypeScript | Estrutura modular robusta, DI nativo, facilidade para testes |
| ORM | Prisma | Schema declarativo, migrations automáticas, type-safety completo |
| Banco de dados | PostgreSQL via Supabase | Gerenciado, gratuito no MVP, backups automáticos |
| Storage de arquivos | Supabase Storage | PDFs de certificados, assinaturas de consultores, logos |
| Auth | JWT (NestJS) + bcrypt | Roles: admin / consultor / cliente; senhas nunca em plaintext |
| Web frontend | Next.js 14 (App Router) | SSR para o formulário público, RSC para performance do admin |
| Estilização web | Tailwind CSS + shadcn/ui | Rápido, consistente, fácil de manter |
| App mobile | Flutter | Offline-first com Drift (SQLite), iOS e Android |
| Banco offline mobile | Drift (SQLite) | ORM para Flutter, reactive streams, migrations tipadas |
| Geração de PDF | Puppeteer (backend) | Renderiza HTML template → PDF, flexível para white-label |
| Envio de e-mail | Resend | API simples, gratuito até 3.000 e-mails/mês |
| Hospedagem backend | Railway | Deploy simples via Git, $5/mês plano Hobby |
| Hospedagem web | Vercel | Deploy automático do Next.js, gratuito |
| Organização de código | Turborepo (monorepo) | Tipos compartilhados entre NestJS e Next.js |
| CI/CD | GitHub Actions | Lint, testes e deploy automáticos no push para main |

---

## 3. Estrutura do Monorepo

```
simtc/
├── apps/
│   ├── backend/          ← NestJS API
│   ├── web/              ← Next.js (admin + formulário público + portal cliente)
│   └── mobile/           ← Flutter
├── packages/
│   └── shared-types/     ← DTOs e enums TypeScript compartilhados (backend + web)
├── turbo.json
├── package.json          ← workspaces npm
└── .github/
    └── workflows/
        ├── backend.yml   ← testa + deploys Railway
        └── web.yml       ← deploys Vercel
```

**Por que monorepo?** NestJS e Next.js são ambos TypeScript. Com `packages/shared-types`, tipos como `CreateTrainingDto` ou enums como `TrainingStatus` são definidos uma vez e importados nos dois projetos — sem risco de drift de tipos entre frontend e backend. O Flutter fica de fora dessa vantagem (é Dart), mas ainda é prático ter tudo num repositório só.

---

## 4. Schema do Banco de Dados

### 4.1 Visão de entidades

```
Company (1) ──< CompanyContact (1..3)       ← responsáveis que podem ter login
Company (1) ──< TrainingSession (N)
Company (1) ──< DemandPipeline (N)

Consultant (N) >──< TrainingSession (N)     ← via SessionConsultant
Course (1) ──< TrainingSession (N)
Course (1) ──< DemandPipeline (N)

AssessmentCategory (1) ──< Infraction (N)
Infraction (1) ──< InfractionNote (3)       ← B, PM, M com deduções distintas

TrainingSession (1) ──< TrainingParticipant (N)
Participant (1) ──< TrainingParticipant (N)

TrainingParticipant (1) ──< PracticalAssessment (0..1)
PracticalAssessment (1) ──< AssessmentItem (N)
AssessmentItem >── InfractionNote           ← qual nota foi atribuída

TrainingParticipant (1) ──< Certificate (0..1)

User >── Consultant | CompanyContact        ← auth unificado
```

### 4.2 Schema Prisma completo

```prisma
// ─── EMPRESAS ────────────────────────────────────────────────

model Company {
  id        String   @id @default(cuid())
  name      String
  cnpj      String   @unique
  address   String?
  city      String?
  state     String?                      // UF (ex: SP, MG)
  logoUrl   String?                      // Supabase Storage — para white-label nos certificados
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  contacts  CompanyContact[]
  trainings TrainingSession[]
  demands   DemandPipeline[]
}

// Até 3 responsáveis por empresa — podem ter login no portal do cliente
model CompanyContact {
  id        String  @id @default(cuid())
  companyId String
  name      String
  email     String
  phone     String?
  isPrimary Boolean @default(false)

  company   Company @relation(fields: [companyId], references: [id])
  user      User?
}

// ─── CONSULTORES ─────────────────────────────────────────────

model Consultant {
  id            String   @id @default(cuid())
  name          String
  email         String   @unique
  phone         String?
  signatureUrl  String?  // Supabase Storage — assinatura aparece nos certificados
  createdAt     DateTime @default(now())

  user                User?
  sessionConsultants  SessionConsultant[]
  assessments         PracticalAssessment[]
  demands             DemandPipeline[]
}

// ─── CURSOS ──────────────────────────────────────────────────

model Course {
  id            String      @id @default(cuid())
  name          String
  vehicleType   VehicleType // LEVE, PESADO, MOTO
  theoryHours   Float
  practiceHours Float       @default(0)
  description   String      // texto que vai no certificado
  createdAt     DateTime    @default(now())

  trainings     TrainingSession[]
  demands       DemandPipeline[]
}

enum VehicleType {
  LEVE
  PESADO
  MOTO
}

// ─── CATEGORIAS E INFRAÇÕES ──────────────────────────────────
// Categorias: CV (Controle do Veículo), RR (Respeito às Regras),
//             CS (Comportamento Seguro), TP (Técnica de Pista)...

model AssessmentCategory {
  id          String       @id @default(cuid())
  code        String       @unique  // CV, RR, CS, TP — exibido na UI
  name        String                // nome completo
  description String?               // texto disciplinar base para o laudo
  order       Int          @default(0)

  infractions Infraction[]
}

model Infraction {
  id          String             @id @default(cuid())
  categoryId  String
  description String             // ex: "Não ajustou banco/retrovisor antes de partir"
  order       Int                @default(0)

  category    AssessmentCategory @relation(fields: [categoryId], references: [id])
  notes       InfractionNote[]
}

// Cada infração tem 3 notas com deduções e comentários distintos
model InfractionNote {
  id           String     @id @default(cuid())
  infractionId String
  noteType     NoteType   // B, PM, M
  comment      String?    // comentário específico para este nível
  deduction    Int        // B=1, PM=3, M=5 — "em branco" (não ocorreu) = ausência de registro, não uma nota

  infraction      Infraction       @relation(fields: [infractionId], references: [id])
  assessmentItems AssessmentItem[]

  @@unique([infractionId, noteType])
}

enum NoteType {
  B   // Bom — ocorreu mas com bom desempenho (-1 pt)
  PM  // Pode Melhorar — deduz 3 pontos
  M   // Melhorar — deduz 5 pontos
}

// ─── FUNIL DE DEMANDAS (Kanban) ──────────────────────────────

model DemandPipeline {
  id               String       @id @default(cuid())
  companyId        String
  consultantId     String
  courseId         String
  status           DemandStatus @default(QUALIFICACAO)
  participantCount Int?
  notes            String?
  createdAt        DateTime     @default(now())
  updatedAt        DateTime     @updatedAt

  company    Company    @relation(fields: [companyId], references: [id])
  consultant Consultant @relation(fields: [consultantId], references: [id])
  course     Course     @relation(fields: [courseId], references: [id])
}

enum DemandStatus {
  QUALIFICACAO
  ANALISE
  PROPOSTA
  AGENDAMENTO
  CONCLUIDO
  PERDIDO
}

// ─── TREINAMENTOS ────────────────────────────────────────────

model TrainingSession {
  id                      String         @id @default(cuid())
  companyId               String
  courseId                String
  responsibleConsultantId String
  city                    String
  state                   String         // UF
  date                    DateTime?
  participantCount        Int?           // estimativa inicial
  notes                   String?
  status                  TrainingStatus @default(PLANEJADO)
  qrCodeToken             String         @unique @default(cuid()) // token para URL do formulário público
  createdAt               DateTime       @default(now())
  updatedAt               DateTime       @updatedAt

  company               Company              @relation(fields: [companyId], references: [id])
  course                Course               @relation(fields: [courseId], references: [id])
  responsibleConsultant Consultant           @relation(fields: [responsibleConsultantId], references: [id])
  consultants           SessionConsultant[]
  participants          TrainingParticipant[]
}

enum TrainingStatus {
  PLANEJADO
  EM_ANDAMENTO
  CONCLUIDO
  CANCELADO
}

// Múltiplos consultores podem atuar na mesma sessão (divisão da parte prática)
model SessionConsultant {
  trainingSessionId String
  consultantId      String

  training   TrainingSession @relation(fields: [trainingSessionId], references: [id])
  consultant Consultant      @relation(fields: [consultantId], references: [id])

  @@id([trainingSessionId, consultantId])
}

// ─── PARTICIPANTES ───────────────────────────────────────────

model Participant {
  id             String   @id @default(cuid())
  name           String
  cpf            String   @unique            // validado com dígito verificador
  email          String?
  cnhCategory    String?                     // A, B, C, D, E
  cnhExpiration  DateTime?
  createdAt      DateTime @default(now())

  trainings TrainingParticipant[]
}

// Relaciona participante com uma sessão específica
model TrainingParticipant {
  id                String            @id @default(cuid())
  trainingSessionId String
  participantId     String
  participationType ParticipationType @default(TEORICA_E_PRATICA)
  status            ParticipantStatus @default(PENDENTE)
  registeredAt      DateTime          @default(now())

  training    TrainingSession     @relation(fields: [trainingSessionId], references: [id])
  participant Participant         @relation(fields: [participantId], references: [id])
  assessment  PracticalAssessment?
  certificate Certificate?

  @@unique([trainingSessionId, participantId])
}

enum ParticipationType {
  SOMENTE_TEORICA     // sem avaliação prática, certificado direto
  TEORICA_E_PRATICA   // precisa passar pela avaliação prática
}

enum ParticipantStatus {
  PENDENTE
  EM_AVALIACAO
  APROVADO            // >= 70 pontos
  NECESSITA_REAVALIACAO
}

// ─── AVALIAÇÃO PRÁTICA ───────────────────────────────────────

model PracticalAssessment {
  id                    String    @id @default(cuid())
  trainingParticipantId String    @unique
  consultantId          String
  date                  DateTime
  startTime             DateTime
  endTime               DateTime?
  synced                Boolean   @default(false) // false enquanto gerado offline no mobile
  createdAt             DateTime  @default(now())

  trainingParticipant TrainingParticipant @relation(fields: [trainingParticipantId], references: [id])
  consultant          Consultant          @relation(fields: [consultantId], references: [id])
  items               AssessmentItem[]
}

// Cada item representa uma infração marcada com a nota atribuída
model AssessmentItem {
  id               String              @id @default(cuid())
  assessmentId     String
  infractionNoteId String              // qual nota (B/PM/M) foi atribuída àquela infração

  assessment     PracticalAssessment @relation(fields: [assessmentId], references: [id])
  infractionNote InfractionNote      @relation(fields: [infractionNoteId], references: [id])
}

// ─── CERTIFICADOS ────────────────────────────────────────────

model Certificate {
  id                    String   @id @default(cuid())
  trainingParticipantId String   @unique
  generatedAt           DateTime @default(now())
  pdfUrl                String?  // Supabase Storage — URL assinada (privada)
  sentToParticipant     Boolean  @default(false)
  sentToCompany         Boolean  @default(false)

  trainingParticipant TrainingParticipant @relation(fields: [trainingParticipantId], references: [id])
}

// ─── USUÁRIOS / AUTH ─────────────────────────────────────────

model User {
  id           String    @id @default(cuid())
  email        String    @unique
  passwordHash String                         // bcrypt — NUNCA plaintext
  role         UserRole
  createdAt    DateTime  @default(now())
  lastLogin    DateTime?

  consultantId String?         @unique
  contactId    String?         @unique
  consultant   Consultant?     @relation(fields: [consultantId], references: [id])
  contact      CompanyContact? @relation(fields: [contactId], references: [id])
}

enum UserRole {
  ADMIN       // Sebastião — acesso total: empresas, consultores, cursos, certificados, relatórios globais
  CONSULTANT  // Consultores/instrutores — painel web restrito (sessões próprias) + app mobile
  CLIENT      // Responsáveis das empresas — portal somente leitura (histórico + certificados)
}
```

---

## 5. Backend — NestJS

### 5.1 Estrutura de módulos

```
apps/backend/src/
├── main.ts
├── app.module.ts
├── prisma/
│   └── prisma.service.ts
├── auth/
│   ├── auth.module.ts
│   ├── auth.controller.ts    ← POST /auth/login, POST /auth/refresh
│   ├── auth.service.ts
│   ├── jwt.strategy.ts
│   └── guards/
│       ├── jwt-auth.guard.ts
│       └── roles.guard.ts
├── companies/
├── consultants/
│   └── signature.service.ts  ← upload para Supabase Storage
├── courses/
├── assessment-categories/    ← categorias + infrações + notas
├── demand-pipeline/
├── training-sessions/
│   └── qr-code.service.ts    ← geração de imagem QR Code
├── participants/
│   └── public-register.controller.ts  ← rota pública sem auth
├── practical-assessments/    ← recebe sync do mobile
├── certificates/
│   ├── certificates.service.ts
│   ├── pdf-generator.service.ts  ← Puppeteer
│   └── templates/
│       ├── certificate.html  ← template white-label
│       └── report.html       ← laudo de avaliação técnica
├── reports/
├── storage/                  ← abstração do Supabase Storage
├── email/                    ← integração Resend
└── common/
    ├── decorators/
    │   ├── roles.decorator.ts
    │   └── current-user.decorator.ts
    └── pipes/
        └── validate-cpf.pipe.ts
```

### 5.2 Autenticação e roles

Login único em `/auth/login` — o JWT retornado carrega o `role`, o `userId` e, quando aplicável, o `companyId` ou `consultantId`. O frontend redireciona para o painel correto ao fazer login.

| Role | O que pode fazer na web | Mobile |
|------|------------------------|--------|
| `ADMIN` | Tudo — CRUD de empresas, consultores, cursos, categorias, treinamentos, documentação, relatórios globais | ✅ Avaliação prática offline (igual ao consultor) |
| `CONSULTANT` | Ver e gerenciar apenas as próprias sessões, participantes e resultados | ✅ Avaliação prática offline |
| `CLIENT` | Somente leitura — histórico e certificados da própria empresa | — |

**Regras de acesso no backend:**

- `@Roles(UserRole.ADMIN)` protege todas as rotas de criação/edição de recursos de configuração (empresas, cursos, consultores, categorias)
- `ADMIN` e `CONSULTANT` têm acesso ao app mobile — o JWT de ambos é aceito pelo backend nas rotas de avaliação prática
- `CONSULTANT` acessa apenas `TrainingSession` em que está em `SessionConsultant` — filtro automático por `consultantId` do JWT
- `ADMIN` no mobile enxerga todas as sessões (sem filtro), útil quando o Sebastião atua como instrutor em campo
- `CONSULTANT` pode ver participantes e resultados de avaliações das próprias sessões, mas **não pode gerar certificados nem ver dados de outras sessões**
- `CLIENT` filtra automaticamente por `companyId` do JWT — nunca vê dados de outra empresa
- Formulário público (`/public/register/:qrToken`): rota sem auth, validada pelo token UUID da sessão
- **Senhas**: bcrypt com salt rounds 12. O PowerApp atual expõe senhas em plaintext — risco crítico eliminado desde o dia 1.

### 5.3 Endpoints da API

```
POST /auth/login
POST /auth/refresh

GET  /companies                    ADMIN | CLIENT (filtra pela empresa do token)
POST /companies                    ADMIN
GET  /companies/:id                ADMIN | CLIENT (própria)
PUT  /companies/:id                ADMIN
GET  /companies/:id/contacts       ADMIN | CLIENT (própria)
POST /companies/:id/contacts       ADMIN

GET  /consultants                  ADMIN
GET  /consultants/me               CONSULTANT (próprio perfil)
POST /consultants                  ADMIN
PUT  /consultants/:id              ADMIN
PATCH /consultants/me              CONSULTANT (atualizar próprios dados e senha)
POST /consultants/:id/signature    ADMIN (multipart upload → Supabase Storage)

GET  /courses                      ADMIN | CONSULTANT (leitura)
POST /courses                      ADMIN
PUT  /courses/:id                  ADMIN

GET  /assessment-categories                        ADMIN | CONSULTANT (leitura — usada no app)
POST /assessment-categories                        ADMIN
GET  /assessment-categories/:id/infractions        ADMIN | CONSULTANT (leitura)
POST /assessment-categories/:id/infractions        ADMIN
PUT  /infractions/:id                              ADMIN

GET  /demand-pipeline              ADMIN
POST /demand-pipeline              ADMIN
PATCH /demand-pipeline/:id/status  ADMIN

GET  /training-sessions                            ADMIN (todas) | CONSULTANT (só as suas)
POST /training-sessions                            ADMIN
GET  /training-sessions/:id                        ADMIN | CONSULTANT (se for participante)
PUT  /training-sessions/:id                        ADMIN
POST /training-sessions/:id/start                  ADMIN
POST /training-sessions/:id/complete               ADMIN
GET  /training-sessions/:id/qr-code                ADMIN | CONSULTANT (exibir em campo)
GET  /training-sessions/:id/participants            ADMIN | CONSULTANT (se for participante)
POST /training-sessions/:id/participants            ADMIN (cadastro manual)
POST /training-sessions/:id/participants/bulk       ADMIN (import XLSX)

POST /public/register/:qrToken     PÚBLICO — formulário inscrição via QR

PATCH /training-participants/:id/type  ADMIN (somente teoria vs teoria+prática)

POST /practical-assessments        ADMIN | CONSULTANT (sync do mobile)
GET  /practical-assessments/:id    ADMIN | CONSULTANT (se for o avaliador)
GET  /training-sessions/:id/results  ADMIN | CONSULTANT (resultados da sessão, se for participante)

POST /training-sessions/:id/generate-certificates  ADMIN (gera PDFs em lote)
POST /certificates/:id/send                        ADMIN (envia por e-mail)

GET  /reports/training-sessions            ADMIN
GET  /reports/training-sessions/:id        ADMIN | CONSULTANT (só das suas sessões)
GET  /reports/companies/:id/history        ADMIN | CLIENT (própria empresa)
```

### 5.4 Lógica de scores

```typescript
// packages/shared-types/src/scoring.ts

export const NOTE_DEDUCTIONS: Record<'B' | 'PM' | 'M', number> = {
  B: 1,   // Bom — ocorreu mas com bom desempenho; desconta 1 ponto
  PM: 3,  // Pode Melhorar — desconta 3 pontos do total de 100
  M: 5,   // Melhorar — desconta 5 pontos
};
// Nota: "em branco" (infração não ocorreu) = 0 dedução — é a ausência de marcação, não uma nota.

// Score por categoria = 100 menos a soma das deduções dos itens marcados
export function calculateCategoryScore(deductions: number[]): number {
  const total = deductions.reduce((acc, d) => acc + d, 0);
  return Math.max(0, 100 - total);
}

// Média simples entre todas as categorias avaliadas
export function calculateOverallScore(categoryScores: number[]): number {
  if (categoryScores.length === 0) return 100;
  return categoryScores.reduce((a, b) => a + b, 0) / categoryScores.length;
}

export function getApprovalStatus(score: number): 'APROVADO' | 'NECESSITA_REAVALIACAO' {
  return score >= 70 ? 'APROVADO' : 'NECESSITA_REAVALIACAO';
}

export function getApprovalLabel(score: number): string {
  if (score >= 85) return 'Aprovado com Excelência';
  if (score >= 70) return 'Aprovado';
  return 'Necessita Reavaliação';
}
```

### 5.5 Geração de certificado PDF

```
Fluxo:
1. Admin clica em "Gerar Documentação" na sessão concluída
2. Backend busca todos os dados: participant, training, course, consultant,
   assessment scores, logo da empresa cliente
3. Renderiza template HTML (Handlebars) com os dados
4. Puppeteer headless converte o HTML → PDF
5. PDF é enviado ao Supabase Storage (bucket: certificates/, acesso privado)
6. URL assinada de 7 dias é salva no modelo Certificate
7. Admin pode optar por enviar por e-mail:
   - Para o participante (e-mail cadastrado no formulário)
   - Para o responsável da empresa (CompanyContact.isPrimary)
   - Para ambos
8. Resend envia com PDF em anexo
```

---

## 6. Web — Next.js

### 6.1 Rotas (App Router)

```
apps/web/src/app/
│
├── (auth)/
│   └── login/                          ← login unificado; redireciona conforme role
│
├── (admin)/                            ← layout com sidebar completa; requer ADMIN
│   │                                      (Sebastião — acesso irrestrito)
│   ├── dashboard/                      ← métricas gerais, sessões recentes
│   ├── companies/
│   │   ├── page.tsx                    ← lista paginada com busca
│   │   ├── new/page.tsx
│   │   └── [id]/
│   │       ├── page.tsx                ← detalhe + edição
│   │       └── contacts/page.tsx       ← responsáveis + criar login de cliente
│   ├── consultants/
│   │   ├── page.tsx
│   │   ├── new/page.tsx
│   │   └── [id]/page.tsx              ← inclui upload de assinatura + criar login
│   ├── courses/
│   ├── assessment-categories/          ← categorias (CV/RR/CS...) + infrações + notas
│   ├── demand-pipeline/                ← kanban drag-and-drop
│   ├── training-sessions/
│   │   ├── page.tsx                    ← TODAS as sessões, com filtros globais
│   │   ├── new/page.tsx
│   │   └── [id]/
│   │       ├── page.tsx                ← info geral + consultores participantes
│   │       ├── participants/page.tsx   ← lista, import XLSX, marcar tipo
│   │       ├── qr-code/page.tsx        ← QR Code para projetar na sala
│   │       └── documents/page.tsx      ← gerar certificados + laudo + enviar
│   └── reports/
│       ├── page.tsx                    ← relatório geral (todas as sessões)
│       └── [id]/page.tsx              ← relatório de uma sessão específica
│
├── (consultant)/                       ← layout próprio com sidebar reduzida; requer CONSULTANT
│   │                                      (consultores veem apenas o que é deles)
│   ├── dashboard/                      ← próximas sessões + avaliações pendentes de sync
│   ├── my-sessions/
│   │   ├── page.tsx                    ← sessões em que o consultor está registrado
│   │   └── [id]/
│   │       ├── page.tsx                ← detalhe da sessão (info geral, colegas consultores)
│   │       ├── participants/page.tsx   ← lista de participantes + status de avaliação
│   │       ├── qr-code/page.tsx        ← QR Code (para exibir no celular em campo)
│   │       └── results/page.tsx        ← resultados das avaliações da sessão
│   └── profile/page.tsx               ← dados pessoais + atualizar senha
│
├── (client)/                           ← portal somente leitura; requer CLIENT
│   └── my-company/
│       ├── page.tsx                    ← dados da empresa + histórico de treinamentos
│       └── trainings/[id]/
│           └── certificates/page.tsx   ← lista e download de certificados
│
└── register/
    └── [qrToken]/
        └── page.tsx                    ← ROTA PÚBLICA — formulário de inscrição
```

### 6.2 Painel do Consultor — o que ele pode e não pode fazer

O consultor tem acesso web com sidebar reduzida. A separação de responsabilidades em relação ao admin é clara:

| Funcionalidade | Admin (Sebastião) | Consultor |
|----------------|:-----------------:|:---------:|
| Criar/editar empresas | ✅ | ❌ |
| Criar/editar consultores | ✅ | ❌ |
| Criar/editar cursos | ✅ | ❌ |
| Criar/editar categorias e infrações | ✅ | ❌ |
| Ver e criar treinamentos (todos) | ✅ | ❌ |
| Ver treinamentos próprios | ✅ | ✅ |
| Ver participantes das próprias sessões | ✅ | ✅ |
| Exibir QR Code da sessão | ✅ | ✅ |
| Ver resultados de avaliações das próprias sessões | ✅ | ✅ |
| Gerar certificados | ✅ | ❌ |
| Funil de demandas (Kanban) | ✅ | ❌ |
| Relatórios globais | ✅ | ❌ |
| Atualizar próprio perfil e senha | ✅ | ✅ |
| Usar app mobile (avaliação offline) | ✅ | ✅ |

O consultor **não vê nada que não seja diretamente relacionado às sessões dele**. Isso evita que um consultor acesse dados de clientes, valores negociados no funil ou informações de outros consultores.

### 6.3 Formulário público (inscrição via QR Code)

A URL gerada para cada turma é: `https://simtc.com.br/register/[qrCodeToken]`

- Rota completamente pública — sem login necessário
- O `qrCodeToken` é o identificador único da `TrainingSession`
- A página busca os dados da sessão pelo token para exibir nome do treinamento, empresa e instrutor
- Campos do formulário: nome completo, CPF, e-mail, categoria CNH, vencimento CNH
- Ao submeter: `POST /public/register/:qrToken`
- Se o CPF já existe no banco, o sistema apenas vincula ao treinamento sem criar duplicata (de-duplicação automática)
- Proteção: rate limiting por IP (máximo 10 submissões por hora por IP)
- QR Code gerado com `qrcode` npm package no backend, exibido como PNG na tela `/training-sessions/:id/qr-code` para o Sebastião projetar ou imprimir

### 6.4 Portal do cliente

- Login com e-mail/senha do `CompanyContact`
- JWT com role `CLIENT` e `companyId` embutidos
- Backend filtra automaticamente todos os dados pelo `companyId` do token
- Funcionalidades: ver histórico de treinamentos, ver lista de participantes, baixar certificados disponíveis
- Sem permissão para criar, editar ou excluir qualquer coisa

---

## 7. App Mobile — Flutter

### 7.1 Arquitetura MVVM

O app adota **MVVM (Model — View — ViewModel)** com Riverpod como cola entre as camadas.

```
Model      → entidades de domínio + repositórios (acesso a dados: Drift e API)
ViewModel  → Notifier do Riverpod: estado da tela + lógica de negócio
View       → Widgets Flutter: apenas renderização e eventos do usuário
```

A View **nunca acessa repositórios diretamente** — ela só lê estado do ViewModel e chama métodos dele. O ViewModel **não importa nada de Flutter** (sem `BuildContext`, sem widgets) — é Dart puro, facilitando testes unitários.

```
┌─────────────────────────────────────────────┐
│  View (Widget)                              │
│  • ref.watch(assessmentVmProvider)          │
│  • vm.markInfraction(...)  ← chama ViewModel│
└───────────────┬─────────────────────────────┘
                │ observa / chama
┌───────────────▼─────────────────────────────┐
│  ViewModel (Notifier)                       │
│  • AssessmentState (estado imutável)        │
│  • markInfraction(), save(), calcScore()    │
└───────────────┬─────────────────────────────┘
                │ usa
┌───────────────▼─────────────────────────────┐
│  Model                                      │
│  • AssessmentRepository (Drift + API)       │
│  • Entidades: Assessment, InfractionNote... │
└─────────────────────────────────────────────┘
```

### 7.2 Estrutura de pastas

Cada feature tem suas próprias camadas `model/`, `viewmodel/` e `view/`. Código compartilhado entre features fica em `core/` e `shared/`.

```
apps/mobile/
└── lib/
    ├── main.dart
    ├── app/
    │   ├── app.dart
    │   └── router.dart                      ← GoRouter (rotas e guards de auth)
    │
    ├── core/                                ← infraestrutura transversal
    │   ├── database/
    │   │   ├── app_database.dart            ← Drift: setup + conexão SQLite
    │   │   ├── tables/                      ← definição das tabelas Drift
    │   │   └── daos/                        ← Data Access Objects por domínio
    │   ├── network/
    │   │   ├── api_client.dart              ← Dio + interceptor de Bearer token
    │   │   └── connectivity.dart            ← stream de status de rede
    │   ├── sync/
    │   │   └── sync_service.dart            ← orquestra sync offline → servidor
    │   └── providers/
    │       └── core_providers.dart          ← providers de infraestrutura (DB, API, Sync)
    │
    ├── features/
    │   │
    │   ├── auth/
    │   │   ├── model/
    │   │   │   ├── user.dart                ← entidade User (role, token)
    │   │   │   └── auth_repository.dart     ← login, refresh, logout via API
    │   │   ├── viewmodel/
    │   │   │   ├── auth_state.dart          ← estado imutável (loading, logado, erro)
    │   │   │   └── auth_viewmodel.dart      ← Notifier: login(), logout()
    │   │   └── view/
    │   │       └── login_page.dart
    │   │
    │   ├── training_sessions/
    │   │   ├── model/
    │   │   │   ├── training_session.dart
    │   │   │   └── session_repository.dart  ← lista do servidor + cache Drift
    │   │   ├── viewmodel/
    │   │   │   ├── session_list_state.dart
    │   │   │   └── session_list_viewmodel.dart  ← Notifier: loadSessions(), sync()
    │   │   └── view/
    │   │       ├── session_list_page.dart
    │   │       └── session_detail_page.dart
    │   │
    │   ├── participants/
    │   │   ├── model/
    │   │   │   ├── participant.dart
    │   │   │   └── participant_repository.dart
    │   │   ├── viewmodel/
    │   │   │   ├── participant_list_state.dart
    │   │   │   └── participant_list_viewmodel.dart  ← Notifier: selectForRound()
    │   │   └── view/
    │   │       └── participant_list_page.dart
    │   │
    │   ├── assessment/
    │   │   ├── model/
    │   │   │   ├── assessment.dart               ← entidade da avaliação
    │   │   │   ├── assessment_item.dart          ← infração + nota (B/PM/M)
    │   │   │   ├── score_calculator.dart         ← lógica pura de cálculo de score
    │   │   │   └── assessment_repository.dart    ← salva no Drift, envia para API
    │   │   ├── viewmodel/
    │   │   │   ├── assessment_state.dart         ← estado imutável da tela
    │   │   │   └── assessment_viewmodel.dart     ← Notifier: markInfraction(),
    │   │   │                                        setStartTime(), save()
    │   │   └── view/
    │   │       ├── assessment_page.dart          ← monta a tela, observa ViewModel
    │   │       └── widgets/
    │   │           ├── category_section.dart     ← seção expansível por categoria
    │   │           ├── infraction_row.dart       ← linha com seletor B / PM / M
    │   │           └── score_summary.dart        ← score em tempo real no rodapé
    │   │
    │   └── sync_status/
    │       ├── model/
    │       │   └── sync_status.dart              ← enum: online, offline, syncing
    │       ├── viewmodel/
    │       │   └── sync_viewmodel.dart           ← Notifier: dispara sync automático
    │       └── view/
    │           └── sync_banner.dart              ← widget global de status de rede
    │
    └── shared/
        ├── widgets/                              ← widgets reutilizáveis entre features
        │   ├── loading_overlay.dart
        │   └── error_snackbar.dart
        └── extensions/
            └── date_format.dart
```

### 7.3 Tabelas locais (Drift/SQLite)

```dart
// Espelha as tabelas do servidor para a sessão ativa

class LocalTrainingSessions extends Table { /* ... */ }
class LocalParticipants extends Table { /* ... */ }
class LocalAssessmentCategories extends Table { /* ... */ }
class LocalInfractions extends Table { /* ... */ }
class LocalInfractionNotes extends Table {
  // deduction: 0, 3 ou 5 conforme noteType B/PM/M
}
class LocalPracticalAssessments extends Table {
  // synced: bool — false enquanto não sincronizado com o servidor
}
class LocalAssessmentItems extends Table {
  // infractionNoteId → qual nota (B/PM/M) foi marcada
}
```

### 7.4 Fluxo offline completo

```
1. ANTES DE IR A CAMPO (com internet):
   → Consultor abre o app, vê lista de sessões do dia
   → Toca na sessão para sincronizar
   → App faz GET /training-sessions/:id
   → Salva localmente: participantes, categorias, infrações, notas (B/PM/M)
   → Exibe: "✅ Sessão carregada. Você pode trabalhar sem internet."

2. EM CAMPO (sem ou com internet):
   → Consultor seleciona 2-3 participantes que vão com ele nesta rodada
   → Para cada participante, abre a tela de avaliação:
     - Data e horário de início (obrigatório — desbloqueia o Salvar)
     - Categorias (CV, RR, CS...) com infrações expandíveis
     - Para cada infração: toca em [B], [PM] ou [M]
     - Score por categoria calculado em tempo real
   → Ao finalizar: informa horário de término
   → Salva localmente (Drift) com synced=false

3. AO RECONECTAR:
   → SyncService detecta conexão de rede
   → Busca todas as avaliações com synced=false
   → Faz POST /practical-assessments em lote
   → Servidor retorna confirmação
   → Marca como synced=true
   → Exibe: "✅ 3 avaliações sincronizadas."

4. CONFLITO (caso improvável):
   → Se um participante já tiver avaliação no servidor (unique constraint),
     servidor retorna erro específico
   → App exibe aviso ao consultor com a data/hora da avaliação já existente
```

### 7.5 UX da tela de avaliação

```
┌─────────────────────────────────────────┐
│ Avaliando: João da Silva                │
│ 📅 22/07/2026  🕐 10:15  →  10:45      │
├─────────────────────────────────────────┤
│ ▾ Controle do Veículo (CV)              │
│                                         │
│  Não ajustou banco/retrovisor           │
│  ○ B   ● PM   ○ M    (-3)              │
│                                         │
│  Posicionamento das mãos                │
│  ○ B   ○ PM   ● M    (-5)              │
│                                         │
│  Suavidade ao dirigir                   │
│  ● B   ○ PM   ○ M    (0)               │
│                                         │
│  Score CV: 92/100                       │
├─────────────────────────────────────────┤
│ ▸ Respeito às Regras (RR)               │
│ ▸ Comportamento Seguro (CS)             │
├─────────────────────────────────────────┤
│ Média Geral: 88.3  ✅ Excelência        │
│                                         │
│        [ Salvar Avaliação ]             │
└─────────────────────────────────────────┘
```

### 7.7 Design System (DS)

O app Flutter tem seu próprio Design System — uma camada de tokens visuais e componentes reutilizáveis que garante consistência em toda a interface e evita duplicação de código.

#### Estrutura do DS

O DS vive em `lib/design_system/` com um único arquivo de entrada (barrel export). Toda a codebase importa apenas esse arquivo — nunca arquivos internos individualmente.

```
lib/design_system/
├── ds.dart                          ← import único para tudo do DS
│                                       import 'package:simtc/design_system/ds.dart'
├── tokens/
│   ├── colors.dart                  ← SimtcColors
│   ├── typography.dart              ← SimtcTypography
│   ├── spacing.dart                 ← SimtcSpacing (escala de 4px)
│   ├── radius.dart                  ← SimtcRadius
│   └── shadows.dart                 ← SimtcShadows
├── theme/
│   └── simtc_theme.dart             ← ThemeData completo usando os tokens
└── components/
    ├── buttons/
    │   └── simtc_button.dart        ← variantes: primary, secondary, danger, ghost
    ├── inputs/
    │   ├── simtc_text_field.dart
    │   └── simtc_dropdown.dart
    ├── cards/
    │   └── simtc_card.dart
    ├── badges/
    │   ├── status_badge.dart        ← Aprovado / Necessita Reavaliação / Pendente
    │   └── note_chip.dart           ← B / PM / M como chip colorido
    ├── assessment/                  ← componentes exclusivos da avaliação prática
    │   ├── note_selector.dart       ← seletor B/PM/M — componente mais usado no app
    │   ├── score_bar.dart           ← barra de progresso do score por categoria
    │   └── category_header.dart     ← cabeçalho expansível por categoria (CV, RR, CS...)
    ├── feedback/
    │   ├── simtc_loading.dart       ← indicador de carregamento padrão
    │   ├── simtc_empty_state.dart   ← tela vazia com ilustração e mensagem
    │   └── simtc_error_state.dart   ← tela de erro com botão de retry
    └── layout/
        ├── simtc_scaffold.dart      ← scaffold padrão com AppBar e padding consistentes
        └── simtc_section.dart       ← seção com título, subtítulo e separador
```

#### Tokens

**Cores (`SimtcColors`)**

```dart
class SimtcColors {
  SimtcColors._();

  // Brand
  static const primary    = Color(0xFF1A56DB); // azul — transmite confiança/segurança
  static const onPrimary  = Color(0xFFFFFFFF);
  static const primaryLight = Color(0xFFEBF5FF);

  // Notas de avaliação — usadas em todo o app
  static const noteB      = Color(0xFF16A34A); // verde  — Bom
  static const notePM     = Color(0xFFD97706); // âmbar  — Pode Melhorar
  static const noteM      = Color(0xFFDC2626); // vermelho — Melhorar

  // Status do participante
  static const approved       = Color(0xFF16A34A); // verde
  static const needsReview    = Color(0xFFDC2626); // vermelho
  static const pending        = Color(0xFF6B7280); // cinza
  static const inProgress     = Color(0xFF2563EB); // azul

  // Superfícies e neutros
  static const surface        = Color(0xFFFFFFFF);
  static const background     = Color(0xFFF9FAFB);
  static const border         = Color(0xFFE5E7EB);
  static const textPrimary    = Color(0xFF111827);
  static const textSecondary  = Color(0xFF6B7280);
  static const textDisabled   = Color(0xFFD1D5DB);
}
```

**Espaçamento (`SimtcSpacing`) — escala de 4px**

```dart
class SimtcSpacing {
  SimtcSpacing._();
  static const xs  =  4.0;
  static const sm  =  8.0;
  static const md  = 16.0;
  static const lg  = 24.0;
  static const xl  = 32.0;
  static const xxl = 48.0;
}
```

**Tipografia (`SimtcTypography`)**

```dart
class SimtcTypography {
  SimtcTypography._();
  static const fontFamily = 'Inter';

  static const headingLg = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
  static const headingMd = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4);
  static const headingSm = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4);
  static const body      = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static const bodyBold  = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.5);
  static const caption   = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);
  static const label     = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);
}
```

**Border Radius (`SimtcRadius`)**

```dart
class SimtcRadius {
  SimtcRadius._();
  static const sm  =  6.0;
  static const md  = 10.0;
  static const lg  = 16.0;
  static const full = 999.0; // pill / chip
}
```

#### Componente principal — `NoteSelector`

O `NoteSelector` é o widget mais crítico do app: aparece em cada linha de infração e precisa ser fácil de tocar em campo, mesmo com a tela suja ou usando luva.

```dart
// components/assessment/note_selector.dart

class NoteSelector extends StatelessWidget {
  final NoteType? selected;
  final void Function(NoteType) onSelect;
  final bool enabled;

  const NoteSelector({
    required this.onSelect,
    this.selected,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: NoteType.values.map((note) {
        final isSelected = selected == note;
        return Padding(
          padding: const EdgeInsets.only(left: SimtcSpacing.xs),
          child: GestureDetector(
            onTap: enabled ? () => onSelect(note) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48), // toque acessível
              padding: const EdgeInsets.symmetric(
                horizontal: SimtcSpacing.sm,
                vertical: SimtcSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isSelected ? _colorFor(note) : SimtcColors.surface,
                borderRadius: BorderRadius.circular(SimtcRadius.sm),
                border: Border.all(
                  color: isSelected ? _colorFor(note) : SimtcColors.border,
                ),
              ),
              child: Text(
                note.label,       // 'B', 'PM', 'M'
                textAlign: TextAlign.center,
                style: SimtcTypography.label.copyWith(
                  color: isSelected ? Colors.white : _colorFor(note),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _colorFor(NoteType note) => switch (note) {
    NoteType.B  => SimtcColors.noteB,
    NoteType.PM => SimtcColors.notePM,
    NoteType.M  => SimtcColors.noteM,
  };
}
```

#### Como usar o DS nas Views

```dart
// ✅ correto — import único do DS
import 'package:simtc/design_system/ds.dart';

// ❌ errado — nunca importar arquivos internos diretamente
import 'package:simtc/design_system/tokens/colors.dart';
import 'package:simtc/design_system/components/buttons/simtc_button.dart';
```

```dart
// Exemplo de uso na InfractionRow (View)
class InfractionRow extends StatelessWidget {
  final Infraction infraction;
  final NoteType? selectedNote;
  final void Function(NoteType) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SimtcSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(infraction.description, style: SimtcTypography.body),
          ),
          NoteSelector(
            selected: selectedNote,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }
}
```

#### Convenções do DS

- **Prefixo `Simtc`** em todos os componentes para evitar conflito com widgets do Flutter (`SimtcButton`, não `Button`)
- **Import único** via `ds.dart` — nunca importar arquivos internos do DS individualmente
- **Sem lógica de negócio**: componentes do DS são puramente visuais — estados e callbacks sempre vêm do ViewModel via parâmetros
- **Toque mínimo de 48×48px** em todos os elementos interativos — usabilidade em campo com tela suja ou luva
- **Animações curtas** (150ms) para feedback visual imediato sem parecer lento

---

### 7.6 Mapeamento MVVM → Riverpod

| Camada MVVM | Implementação Riverpod |
|-------------|----------------------|
| **ViewModel** | `class AssessmentViewModel extends Notifier<AssessmentState>` |
| **State** | `@freezed class AssessmentState` — imutável, copiado a cada mudança |
| **Provider** | `final assessmentVmProvider = NotifierProvider<..., ...>()` |
| **View observa** | `ref.watch(assessmentVmProvider)` — reconstrói só o que mudou |
| **View chama** | `ref.read(assessmentVmProvider.notifier).markInfraction(...)` |

Exemplo de como a View e o ViewModel se comunicam sem acoplamento:

```dart
// viewmodel/assessment_viewmodel.dart
class AssessmentViewModel extends Notifier<AssessmentState> {
  @override
  AssessmentState build() => AssessmentState.initial();

  void markInfraction(String infractionId, NoteType note) {
    // lógica pura — sem BuildContext, sem widgets
    final updated = state.items.map((item) {
      return item.infractionId == infractionId
          ? item.copyWith(noteType: note)
          : item;
    }).toList();
    state = state.copyWith(items: updated);
  }

  Future<void> save() async {
    state = state.copyWith(isSaving: true);
    await ref.read(assessmentRepositoryProvider).saveLocally(state.toEntity());
    state = state.copyWith(isSaving: false, saved: true);
  }
}

// view/assessment_page.dart
class AssessmentPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assessmentVmProvider);       // observa
    final vm = ref.read(assessmentVmProvider.notifier);  // aciona

    return Column(
      children: [
        ScoreSummary(score: state.overallScore),
        ...state.categories.map((cat) =>
          CategorySection(
            category: cat,
            onMark: (infractionId, note) =>
              vm.markInfraction(infractionId, note),   // chama ViewModel
          ),
        ),
        ElevatedButton(
          onPressed: state.canSave ? vm.save : null,
          child: Text('Salvar Avaliação'),
        ),
      ],
    );
  }
}
```

**Pacotes utilizados:**
- `riverpod` + `flutter_riverpod` — gerenciamento de estado (ViewModel)
- `freezed` — classes de estado imutáveis com `copyWith` gerado automaticamente
- `go_router` — navegação com guards de autenticação
- `dio` — chamadas HTTP com interceptor que injeta Bearer token
- `connectivity_plus` — stream de status de rede para trigger de sync automático

---

## 8. Infraestrutura

### 8.1 Supabase

```
Projeto: simtc-prod

PostgreSQL gerenciado:
  - Prisma aponta via DATABASE_URL (connection pooling via pgBouncer)
  - Backups automáticos diários (Free: 7 dias de histórico)

Storage Buckets (privados — URLs assinadas):
  - signatures/     ← assinaturas PNG dos consultores (para PDFs)
  - certificates/   ← PDFs gerados de certificados e laudos
  - logos/          ← logos PNG das empresas clientes (white-label)

Plano Free:
  - 500 MB banco      → suficiente para anos de dados do MVP
  - 1 GB storage      → ~2.000 PDFs de certificado antes de precisar upgrade
  - Upgrade para Pro ($25/mês) quando necessário
```

### 8.2 Railway (NestJS backend)

```
Serviço: simtc-backend
  - Deploy via GitHub Actions no push para main
  - Plano Hobby: $5/mês
  - Variáveis de ambiente:
      DATABASE_URL=...          (Supabase PostgreSQL connection string)
      JWT_SECRET=...            (string aleatória de 256 bits)
      JWT_REFRESH_SECRET=...
      SUPABASE_URL=...
      SUPABASE_SERVICE_KEY=...  (service role — acesso total ao storage)
      RESEND_API_KEY=...
      FRONTEND_URL=https://simtc.com.br

Domínio: api.simtc.com.br  (DNS CNAME apontando para Railway)
```

### 8.3 Vercel (Next.js web)

```
Projeto: simtc-web
  - Deploy automático no push para main
  - Preview deployments automáticos em PRs (ótimo para testar antes de subir)
  - Plano Free
  - Variáveis de ambiente:
      NEXT_PUBLIC_API_URL=https://api.simtc.com.br
      NEXTAUTH_SECRET=...
      NEXTAUTH_URL=https://simtc.com.br

Domínio: simtc.com.br  (DNS configurado para Vercel)
```

### 8.4 Resend (e-mail)

```
Plano Free: 3.000 e-mails/mês → mais que suficiente para o volume do Sebastião

Tipos de e-mail enviados:
  - Certificado do participante (PDF em anexo)
  - Certificado para responsável da empresa (PDF em anexo)
  - Link de acesso para responsável da empresa (portal cliente)

Remetente: noreply@simtc.com.br
  → DNS: configurar SPF, DKIM e DMARC para boa entregabilidade
```

### 8.5 Custos mensais estimados (produção)

| Serviço | Custo mensal |
|---------|-------------|
| Supabase Free | R$ 0 |
| Railway Hobby | ~R$ 27 |
| Vercel Free | R$ 0 |
| Resend Free | R$ 0 |
| Domínio .com.br | ~R$ 5 |
| **Total MVP** | **~R$ 32/mês** |

Para escalar depois: Supabase Pro ($25/mês) + Railway Developer ($20/mês) → ~R$ 250/mês.

---

## 9. Ambientes (Dev vs Produção)

### 9.1 Estratégia de ambientes

O projeto mantém dois ambientes completamente isolados — desenvolvimento e produção — cada um com suas próprias variáveis de ambiente e banco de dados separado. O código é idêntico nos dois; só as variáveis mudam.

| Serviço | Desenvolvimento | Produção |
|---------|:--------------:|:--------:|
| NestJS backend | Render (free) | Railway (~R$27/mês) |
| PostgreSQL | Supabase **simtc-dev** (free) | Supabase **simtc-prod** (free) |
| Next.js web | Vercel (free, preview deploy) | Vercel (free, domínio próprio) |
| **Custo total** | **R$0** | **~R$27/mês** |

### 9.2 Render (backend em desenvolvimento)

O Render Free tem uma limitação importante: o serviço **dorme após 15 minutos sem requisições** e leva ~30-50 segundos para acordar na primeira chamada. Em desenvolvimento isso é aceitável — você abre o projeto, aguarda a primeira resposta, e daí em diante roda normalmente enquanto estiver trabalhando.

Para evitar surpresas durante testes, mantenha o Insomnia/Postman aberto com uma requisição de health check (`GET /health`) para acordar o serviço antes de começar.

### 9.3 Dois projetos Supabase separados

Crie dois projetos distintos no Supabase — **nunca use o banco de produção para desenvolvimento**.

```
Supabase: simtc-dev   ← desenvolvimento e testes
Supabase: simtc-prod  ← produção (dados reais do Sebastião)
```

Isso permite rodar migrations experimentais, inserir dados de teste e fazer rollbacks sem nenhum risco para os dados reais. Cada projeto tem seu próprio `DATABASE_URL`.

### 9.4 Variáveis de ambiente

```bash
# apps/backend/.env.development
DATABASE_URL="postgresql://...supabase-dev..."
JWT_SECRET="qualquer-string-para-dev"
SUPABASE_URL="https://xxx.supabase.co"          # projeto simtc-dev
SUPABASE_SERVICE_KEY="..."
RESEND_API_KEY="..."
FRONTEND_URL="http://localhost:3000"

# apps/backend/.env.production
DATABASE_URL="postgresql://...supabase-prod..."
JWT_SECRET="string-aleatoria-forte-256-bits"    # openssl rand -base64 32
SUPABASE_URL="https://yyy.supabase.co"          # projeto simtc-prod
SUPABASE_SERVICE_KEY="..."
RESEND_API_KEY="..."
FRONTEND_URL="https://simtc.com.br"
```

```bash
# apps/web/.env.local (desenvolvimento)
NEXT_PUBLIC_API_URL="https://seu-app.onrender.com"
NEXTAUTH_SECRET="qualquer-string-para-dev"
NEXTAUTH_URL="http://localhost:3000"

# apps/web (variáveis no painel da Vercel — produção)
NEXT_PUBLIC_API_URL="https://api.simtc.com.br"
NEXTAUTH_SECRET="string-forte"
NEXTAUTH_URL="https://simtc.com.br"
```

> **Importante:** os arquivos `.env.*` nunca entram no repositório. O `.gitignore` deve incluir `.env`, `.env.development` e `.env.production`. As variáveis de produção são configuradas diretamente nos painéis do Railway e da Vercel.

### 9.5 Fluxo de deploy

```
Desenvolvimento local
  │  git push → branch feature/*
  ▼
Vercel cria preview deploy automático (URL temporária para testar o web)
Render continua rodando o backend de dev
  │  Pull Request aprovado → merge em main
  ▼
GitHub Actions executa: lint + testes
  │  testes passam
  ▼
Railway faz deploy automático do backend (produção)
Vercel faz deploy automático do web (produção)
```

---

## 10. Fases de Desenvolvimento (ordem de prioridade)

### Fase 1 — Fundação (~20h)
**Entregável:** API rodando em produção, banco configurado, auth funcionando.

- Setup monorepo (Turborepo + npm workspaces)
- Prisma schema + migrations iniciais
- Deploy NestJS no Railway + Supabase configurado
- Módulo Auth (login JWT, refresh token, guards, roles)
- CRUD completo: Empresas + Contatos
- CRUD completo: Consultores + upload de assinatura
- CRUD completo: Cursos
- CRUD completo: Categorias de Avaliação + Infrações + Notas (B/PM/M)
- GitHub Actions: lint + testes + deploy automático

**Critério de aceite:** Consegue criar um treinamento completo via API (Postman/Insomnia) e o dado persiste no banco.

---

### Fase 2 — Web Admin: Cadastros (~15h)
**Entregável:** Sebastião consegue usar o sistema para cadastrar o operacional.

- Setup Next.js com autenticação (NextAuth)
- Layout admin (sidebar, header, navegação)
- Tela Empresas: lista paginada + filtros + formulário
- Tela Consultores: lista + formulário + upload de assinatura
- Tela Cursos: lista + formulário
- Tela Categorias de Avaliação: lista de categorias + infrações por categoria + notas
- Tela Funil de Demandas: kanban com drag-and-drop (colunas por status)

---

### Fase 3 — Treinamentos + Formulário Público (~20h)
**Entregável:** Fluxo completo de cadastro de treinamento e auto-inscrição de participantes.

- Tela de criação de treinamento (empresa, curso, data, cidade/UF, consultores)
- Tela de gestão de participantes (lista com status, tipo teoria/prática)
- Import de participantes via XLSX (planilha do cliente)
- Cadastro manual de participantes
- **QR Code da turma**: exibe PNG para projetar na sala
- **Formulário público** `/register/:qrToken`:
  - Exibe nome do treinamento ao carregar
  - Campos: nome, CPF, e-mail, categoria CNH, vencimento CNH
  - Validação de CPF com dígito verificador
  - De-duplicação automática por CPF
  - Feedback visual de sucesso
- Iniciar treinamento (muda status para EM_ANDAMENTO)
- Concluir treinamento (habilita geração de documentação)

---

### Fase 4 — App Flutter (~30h)
**Entregável:** Consultores conseguem avaliar participantes em campo, offline.

- Setup Flutter + Drift + Riverpod + GoRouter
- Tela de login do consultor
- Lista de sessões do consultor (do dia + próximas)
- Sync de dados da sessão (download de participantes, infrações)
- Lista de participantes da sessão com seleção para rodada
- **Tela de avaliação prática:**
  - Registro de data, hora início e hora fim (obrigatórios para habilitar Salvar)
  - Categorias expandíveis (CV, RR, CS...)
  - Infrações com seletor B / PM / M por item
  - Score por categoria calculado em tempo real
  - Score geral e classificação (Excelência / Aprovado / Necessita Reavaliação)
  - Salvar localmente (Drift, synced=false)
- Sync automático ao reconectar
- Indicador de status: online/offline, N avaliações pendentes de sync
- Build Android (APK / Play Store interno) e iOS (TestFlight)

---

### Fase 5 — Documentação (~15h)
**Entregável:** Certificados PDF gerados com white-label e enviados por e-mail.

- Template HTML do certificado (Handlebars) com suporte a:
  - Logo da empresa cliente (white-label)
  - Assinatura do consultor responsável
  - Scores por categoria + classificação final
  - Dados do curso e data
- Puppeteer convertendo HTML → PDF no backend
- Upload do PDF para Supabase Storage (bucket privado)
- Laudo de Avaliação Técnica: documento com resumo detalhado por participante
- Tela no web admin para gerar documentação da sessão:
  - Gerar individual ou em lote
  - Escolher enviar para participante, empresa ou ambos
- Integração Resend: envio de e-mail com PDF em anexo

---

### Fase 6 — Portal do Cliente (~8h)
**Entregável:** Responsáveis das empresas acessam histórico e baixam certificados.

- Login para `CompanyContact` com role `CLIENT`
- Página da empresa (dados + histórico de treinamentos)
- Lista de participantes por treinamento
- Download de certificados disponíveis (URL assinada do Supabase)
- Opção de gerar certificado avulso pelo próprio cliente (opcional)

---

### Fase 7 — Polimento e Produção (~12h)
**Entregável:** Sistema testado, documentado e estável em produção.

- Testes E2E do fluxo crítico (Playwright: login → treinamento → QR → inscrição → doc)
- Testes de integração do backend nas rotas principais
- Relatórios: lista de sessões concluídas com filtros por empresa, consultor, período
- Dashboard admin com métricas básicas (sessões no mês, participantes avaliados)
- Domínio `simtc.com.br` configurado (DNS, SSL automático)
- SPF + DKIM configurados no DNS para e-mails
- Sentry (ou similar) para monitoramento de erros em produção
- Manual simplificado de uso para o Sebastião

---

## 11. Estimativa de Horas

| Fase | Descrição | Horas |
|------|-----------|-------|
| 1 | Fundação do Backend | 20h |
| 2 | Web Admin: Cadastros | 15h |
| 3 | Web Admin: Treinamentos + QR Code | 20h |
| 4 | Flutter App | 30h |
| 5 | Certificados e Documentação | 15h |
| 6 | Portal do Cliente | 8h |
| 7 | Polimento e Produção | 12h |
| **Total** | | **~120h** |

À R$80/hora → **R$9.600** (ligeiramente acima do estimado na reunião de R$8.000/100h).  
Sugestão: negociar 120h como escopo fechado por R$9.000, com suporte de ajustes por 30 dias após entrega.

---

## 12. Checklist de Produção

Antes de ir ao ar com usuários reais:

- [ ] HTTPS em todos os domínios (Railway e Vercel já provisionam automaticamente)
- [ ] Variáveis de ambiente em produção — nunca hardcoded no código
- [ ] JWT secret com mínimo de 256 bits (usar `openssl rand -base64 32`)
- [ ] Senhas com bcrypt (salt rounds 12) — NUNCA em plaintext
- [ ] Rate limiting nas rotas de login e no formulário público (evitar força bruta e spam)
- [ ] Validação de CPF com dígito verificador no backend e no Flutter
- [ ] Supabase Storage buckets em modo privado (URLs assinadas com expiração)
- [ ] Row-Level Security no Supabase como camada extra de isolamento por empresa
- [ ] Backups verificados (Supabase faz automaticamente no Free)
- [ ] Sentry ou Railway logs configurados para erros em produção
- [ ] Teste do fluxo offline-to-sync com dados reais antes do primeiro campo
- [ ] Build do Flutter testado em dispositivo Android real (não só emulador)
- [ ] E-mails de certificado testados em Gmail, Outlook e Yahoo

---

## 13. Decisões de Design Importantes

| Decisão | O que foi decidido | Motivo |
|---------|-------------------|--------|
| Triplicação de infrações (B/PM/M) | **Eliminada** — um modelo `InfractionNote` por tipo | O PowerApp triplicava registros; o novo design tem uma infração com 3 notas associadas |
| Número da turma no formulário | **Eliminado** — substituído por URL parametrizada | Evita erros humanos ao digitar número errado (o PowerApp sofria deste problema) |
| Senhas de consultores | **bcrypt obrigatório** | PowerApp expõe senhas em plaintext — risco crítico a ser eliminado |
| Upload de planilha de participantes | **Suportado** via import XLSX | Clientes frequentemente enviam listas antes do treinamento |
| Concluir treinamento para quem só fez teoria | **Checkbox por participante** (`ParticipationType.SOMENTE_TEORICA`) | Pode ter mistura de alunos só-teoria e alunos com prática na mesma sessão |
| Múltiplos consultores por sessão | **Suportado** via `SessionConsultant` | Divisão do grupo na parte prática é comum |
| Envio de certificado | **Dois destinos** (participante e/ou empresa) | Preferência varia por cliente: alguns querem distribuir eles mesmos |
| Painel web para consultores | **Sim** — painel próprio com sidebar reduzida | Consultores precisam ver agenda e QR Code mesmo sem estar em campo, mas não devem acessar gestão de negócio (funil, empresas, finanças) |
| Consultor pode criar treinamento? | **Não** — só o admin cria e associa consultores | Evita que consultor acesse dados de clientes, valores negociados ou informações de colegas |

---

## 14. Dúvidas em Aberto (para alinhar com o Sebastião)

1. **Logo do cliente nos certificados**: como o Sebastião vai enviar a logo de cada empresa? Upload pela tela de empresas no admin (preferido) ou via WhatsApp/e-mail manualmente?

2. **Laudo de Avaliação Técnica**: o template atual é .docx Word. Vamos manter Word ou migrar para PDF gerado pelo backend? PDF é mais fácil de controlar visualmente e não precisa de Word instalado.

3. **Acesso dos consultores ao web admin**: os consultores precisam acessar o painel web (para ver agenda, histórico) ou apenas o app mobile é suficiente para eles?

4. **Treinamentos 100% online**: quando o treinamento teórico acontece online e a prática é marcada depois como sessão separada, são dois cadastros de `TrainingSession` separados ou uma sessão com duas datas?

5. **QR Code no app mobile**: o consultor pode precisar exibir o QR Code da turma no celular (caso não tenha projetor)? Se sim, a rota de QR Code precisa ficar disponível também no app.

---

*Este documento é vivo — atualize conforme decisões forem tomadas. Versão: 2.0 — 22/07/2026*
