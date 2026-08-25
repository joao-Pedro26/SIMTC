# Frontend–Backend Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Conectar o frontend Next.js ao backend NestJS por fluxo de uso real: infraestrutura de fetch, formulário público de inscrição via QR Code, gerenciamento de sessão pelo admin, uploads de logo/assinatura, certificados e portal do consultor.

**Architecture:** Client Components usam `clientApi` (lê token via `document.cookie`); Server Components usam `api` (lê token via `cookies()` do `next/headers`). `TrainingSessionDetailTabs` passa a ser dono do fetch de detalhe da sessão, recebendo `sessionId: string` em vez do objeto completo. O formulário público (`/register/[qrToken]`) é inteiramente sem autenticação. `PublicRegisterController` não usa `JwtAuthGuard` — não precisa de `@Public()`.

**Tech Stack:** Next.js 14 App Router, NestJS, CSS Modules, `@simtc/shared-types` (scoring, DTOs), Prisma (via backend).

## Global Constraints

- CSS Modules em todos os novos arquivos `.tsx` — nunca Tailwind
- Tokens CSS: `--teal`, `--teal-dark`, `--teal-soft`, `--orange`, `--orange-dark`, `--orange-soft`, `--charcoal`, `--bg`, `--surface`, `--border`, `--text`, `--text-2`, `--text-muted`; `border-radius` 4px (botões/inputs) ou 8px (cards/modais)
- `clientApi` para Client Components, `api` para Server Components
- Campos de body: `cnhCategory` e `cnhExpiration` (nunca `licenseCategory`/`licenseExpiry`)
- Tipo de participante: `participationType` (não `type`) — conforme DTO do backend
- Commits em inglês, formato `type(scope): message`, sem Co-Authored-By
- Backend base URL: `http://localhost:3001/api` (via `NEXT_PUBLIC_API_URL`)

---

## Mapa de Arquivos

### Novos arquivos

| Arquivo | Responsabilidade |
|---|---|
| `apps/web/.env.local` | `NEXT_PUBLIC_APP_URL=http://localhost:3000` |
| `apps/web/src/app/register/[qrToken]/public-register-flow.tsx` | Client Component: 3 telas (confirmação, form, sucesso) |
| `apps/web/src/app/register/[qrToken]/public-register.module.css` | Estilos do formulário público |
| `apps/web/src/app/(consultant)/consultant-layout.module.css` | Estilos do layout do consultor |
| `apps/web/src/app/(consultant)/my-sessions/my-sessions-table.tsx` | Tabela de sessões do consultor |
| `apps/web/src/app/(consultant)/my-sessions/my-sessions.module.css` | Estilos da listagem |
| `apps/web/src/app/(consultant)/my-sessions/[id]/session-nav-tabs.tsx` | Tabs de navegação entre sub-rotas |
| `apps/web/src/app/(consultant)/my-sessions/[id]/session-nav-tabs.module.css` | Estilos das tabs |
| `apps/web/src/app/(consultant)/my-sessions/[id]/session-detail.module.css` | Estilos da página de detalhe |
| `apps/web/src/app/(consultant)/my-sessions/[id]/participants/participants.module.css` | Estilos de participantes |
| `apps/web/src/app/(consultant)/my-sessions/[id]/qr-code/qr-code.module.css` | Estilos do QR Code |
| `apps/web/src/app/(consultant)/my-sessions/[id]/results/results.module.css` | Estilos dos resultados |

### Arquivos modificados / substituídos

| Arquivo | O que muda |
|---|---|
| `apps/backend/src/participants/participants.service.ts` | Adicionar `findByToken(qrToken)` |
| `apps/backend/src/participants/public-register.controller.ts` | Adicionar `GET training-sessions/by-token/:qrToken` |
| `apps/backend/src/participants/participants.controller.ts` | Remover `@Post('public/register/:qrToken')` duplicado |
| `apps/web/src/lib/client-api.ts` | Refresh de token + FormData support + método `upload` |
| `apps/web/src/lib/api.ts` | Adicionar `cache: 'no-store'` |
| `apps/web/src/features/training-sessions/qr-code-tab.tsx` | Corrigir URL hardcoded |
| `apps/web/src/app/register/[qrToken]/page.tsx` | Implementar Server Component com fetch público |
| `apps/web/src/features/training-sessions/training-session-detail-tabs.tsx` | Mudar interface para `sessionId: string`, ownership do fetch |
| `apps/web/src/features/training-sessions/participants-tab.tsx` | Conectar todas as ações à API |
| `apps/web/src/features/training-sessions/documents-tab.tsx` | Implementar gerar e enviar certificados |
| `apps/web/src/app/(admin)/training-sessions/page.tsx` | `limit=200`, adaptar `openDetail`, `handleSessionChanged` com `useCallback` |
| `apps/web/src/features/companies/company-edit-form.tsx` | Adicionar `companyId` + upload de logo |
| `apps/web/src/app/(admin)/companies/page.tsx` | Passar `companyId` para `CompanyEditForm` |
| `apps/web/src/features/consultants/consultant-edit-form.tsx` | Adicionar `consultantId` + upload de assinatura |
| `apps/web/src/app/(admin)/consultants/page.tsx` | Passar `consultantId` para `ConsultantEditForm` |
| `apps/web/src/app/(consultant)/layout.tsx` | Remover Tailwind, usar CSS Modules |
| `apps/web/src/app/(consultant)/my-sessions/page.tsx` | Implementar listagem |
| `apps/web/src/app/(consultant)/my-sessions/[id]/page.tsx` | Implementar detalhe |
| `apps/web/src/app/(consultant)/my-sessions/[id]/participants/page.tsx` | Implementar lista read-only |
| `apps/web/src/app/(consultant)/my-sessions/[id]/qr-code/page.tsx` | Implementar QR Code |
| `apps/web/src/app/(consultant)/my-sessions/[id]/results/page.tsx` | Implementar resultados com scoring |

### Arquivos deletados

| Arquivo | Motivo |
|---|---|
| `apps/web/src/app/(consultant)/my-sessions/overview.tsx` | Arquivo órfão — só um comentário, nunca referenciado |

---

## Task 1: Infraestrutura — `client-api.ts` com refresh e FormData

**Files:**
- Modify: `apps/web/src/lib/client-api.ts`

**Interfaces:**
- Produces: `clientApi.upload<T>(path: string, fd: FormData): Promise<T>` — usado nas Tasks 8 e 9

- [ ] **Step 1: Substituir o conteúdo de `client-api.ts`**

```typescript
'use client'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'

function getToken(cookieName: string): string | null {
  if (typeof document === 'undefined') return null
  const match = document.cookie
    .split('; ')
    .find((c) => c.startsWith(`${cookieName}=`))
  return match ? decodeURIComponent(match.split('=')[1]) : null
}

function setTokenCookie(value: string) {
  document.cookie = `simtc-token=${encodeURIComponent(value)}; path=/; max-age=${15 * 60}; samesite=lax`
}

async function clientFetch<T>(
  path: string,
  options?: RequestInit,
  isRetry = false,
): Promise<T> {
  const token = getToken('simtc-token')
  const isFormData = options?.body instanceof FormData

  const res = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      ...(!isFormData ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options?.headers,
    },
  })

  if (res.status === 401 && !isRetry) {
    const refreshToken = getToken('simtc-refresh')
    if (refreshToken) {
      const refreshRes = await fetch(`${API_URL}/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken }),
      })
      if (refreshRes.ok) {
        const { accessToken } = await refreshRes.json()
        setTokenCookie(accessToken)
        return clientFetch<T>(path, options, true)
      }
    }
    if (typeof window !== 'undefined') window.location.href = '/login'
    throw new Error('Sessão expirada. Faça login novamente.')
  }

  if (!res.ok) {
    const error = await res.json().catch(() => ({ message: res.statusText }))
    throw new Error(error.message ?? `Erro ${res.status}`)
  }

  if (res.status === 204) return undefined as T
  return res.json() as Promise<T>
}

export const clientApi = {
  get:    <T>(path: string)                => clientFetch<T>(path),
  post:   <T>(path: string, body: unknown) => clientFetch<T>(path, { method: 'POST',   body: JSON.stringify(body) }),
  put:    <T>(path: string, body: unknown) => clientFetch<T>(path, { method: 'PUT',    body: JSON.stringify(body) }),
  patch:  <T>(path: string, body: unknown) => clientFetch<T>(path, { method: 'PATCH',  body: JSON.stringify(body) }),
  delete: <T>(path: string)                => clientFetch<T>(path, { method: 'DELETE' }),
  upload: <T>(path: string, fd: FormData)  => clientFetch<T>(path, { method: 'PATCH',  body: fd }),
}
```

- [ ] **Step 2: Testar manualmente**

Abrir o painel admin e fazer qualquer ação que chame a API. O comportamento atual deve continuar funcionando. Para testar o refresh: alterar temporariamente `JWT_EXPIRES_IN=20s` no `.env.development` do backend, reiniciar o backend, aguardar 20s após o login e fazer uma ação — deve renovar automaticamente sem redirect.

- [ ] **Step 3: Commit**

```bash
git add apps/web/src/lib/client-api.ts
git commit -m "feat(client-api): add token refresh interceptor and FormData upload support"
```

---

## Task 2: Infraestrutura — `api.ts` com `cache: 'no-store'` e `.env.local`

**Files:**
- Modify: `apps/web/src/lib/api.ts`
- Modify: `apps/web/src/features/training-sessions/qr-code-tab.tsx`
- Create: `apps/web/.env.local`

- [ ] **Step 1: Criar `apps/web/.env.local`**

```
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

- [ ] **Step 2: Substituir o conteúdo de `apps/web/src/lib/api.ts`**

```typescript
import { cookies } from 'next/headers';

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api';

export async function apiFetch<T>(
  path: string,
  options?: RequestInit,
): Promise<T> {
  const cookieStore = await cookies();
  const token = cookieStore.get('simtc-token')?.value;

  const res = await fetch(`${API_URL}${path}`, {
    cache: 'no-store',
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options?.headers,
    },
  });

  if (!res.ok) {
    const error = await res.json().catch(() => ({ message: res.statusText }));
    throw new Error(error.message ?? `API error ${res.status}`);
  }

  return res.json() as Promise<T>;
}

export const api = {
  get:    <T>(path: string) => apiFetch<T>(path),
  post:   <T>(path: string, body: unknown) => apiFetch<T>(path, { method: 'POST',  body: JSON.stringify(body) }),
  put:    <T>(path: string, body: unknown) => apiFetch<T>(path, { method: 'PUT',   body: JSON.stringify(body) }),
  patch:  <T>(path: string, body: unknown) => apiFetch<T>(path, { method: 'PATCH', body: JSON.stringify(body) }),
  delete: <T>(path: string)                => apiFetch<T>(path, { method: 'DELETE' }),
};
```

- [ ] **Step 3: Corrigir URL hardcoded em `qr-code-tab.tsx`**

Em `apps/web/src/features/training-sessions/qr-code-tab.tsx`, substituir as linhas que constroem `publicUrl` e `copyLink`:

```typescript
// Adicionar no topo do arquivo (após a linha de API_URL):
const APP_URL = process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000'

// Substituir linha 15:
// ANTES:
const publicUrl = `simtc.com.br/register/${session.qrCodeToken}`
// DEPOIS:
const publicUrl = `${APP_URL}/register/${session.qrCodeToken}`

// Substituir copyLink (linha 19):
// ANTES:
navigator.clipboard.writeText(`https://${publicUrl}`)
// DEPOIS:
navigator.clipboard.writeText(publicUrl)
```

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/lib/api.ts apps/web/.env.local apps/web/src/features/training-sessions/qr-code-tab.tsx
git commit -m "feat(infra): add cache no-store, NEXT_PUBLIC_APP_URL, fix hardcoded qr-code URL"
```

---

## Task 3: Backend — Endpoint público `GET /public/training-sessions/by-token/:qrToken`

**Files:**
- Modify: `apps/backend/src/participants/participants.service.ts`
- Modify: `apps/backend/src/participants/public-register.controller.ts`
- Modify: `apps/backend/src/participants/participants.controller.ts`

**Interfaces:**
- Produces: `GET /api/public/training-sessions/by-token/:qrToken` → `{ companyName: string, courseName: string, status: string }`
- Produces: `ParticipantsService.findByToken(qrToken: string)` — usado pelo controller

- [ ] **Step 1: Adicionar `findByToken` em `participants.service.ts`**

Adicionar o método após `findBySession` (linha ~17):

```typescript
async findByToken(qrToken: string): Promise<{ companyName: string; courseName: string; status: string }> {
  const session = await this.prisma.trainingSession.findUnique({
    where: { qrCodeToken: qrToken },
    include: {
      company: { select: { name: true } },
      course: { select: { name: true } },
    },
  });

  if (!session) {
    throw new NotFoundException('Sessão de treinamento não encontrada');
  }

  return {
    companyName: session.company.name,
    courseName: session.course.name,
    status: session.status,
  };
}
```

Adicionar `NotFoundException` ao import existente de `@nestjs/common`.

- [ ] **Step 2: Substituir o conteúdo de `public-register.controller.ts`**

```typescript
import { Controller, Get, Post, Param, Body, UseGuards } from '@nestjs/common';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { ParticipantsService } from './participants.service';
import { RegisterParticipantPublicDto } from '@simtc/shared-types';

@ApiTags('public')
@Controller('public')
export class PublicRegisterController {
  constructor(private readonly service: ParticipantsService) {}

  @Get('training-sessions/by-token/:qrToken')
  @ApiOperation({ summary: 'Busca dados da sessão pelo QR token — sem autenticação' })
  getSessionByToken(@Param('qrToken') qrToken: string) {
    return this.service.findByToken(qrToken);
  }

  @Post('register/:qrToken')
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: 10, ttl: 3600_000 } })
  @ApiOperation({ summary: 'Formulário público de inscrição via QR Code — sem autenticação' })
  register(
    @Param('qrToken') qrToken: string,
    @Body() dto: RegisterParticipantPublicDto,
  ) {
    return this.service.registerPublic(qrToken, dto);
  }
}
```

- [ ] **Step 3: Remover rota duplicada de `participants.controller.ts`**

Remover o método `registerPublic` (o `@Post('public/register/:qrToken')`) do `ParticipantsController`. O arquivo final deve começar em `@Get('training-sessions/:id/participants')`. Remover também o import de `RegisterParticipantPublicDto` se não for mais usado.

- [ ] **Step 4: Testar o endpoint**

Com o backend rodando (`npm run start:dev` em `apps/backend`):

```bash
# Token válido (pegar um qrCodeToken real do banco)
curl http://localhost:3001/api/public/training-sessions/by-token/TOKEN_VALIDO
# Esperado: { "companyName": "...", "courseName": "...", "status": "PLANEJADO" }

# Token inválido
curl http://localhost:3001/api/public/training-sessions/by-token/INVALIDO
# Esperado: 404 { "message": "Sessão de treinamento não encontrada" }
```

- [ ] **Step 5: Commit**

```bash
git add apps/backend/src/participants/
git commit -m "feat(participants): add public GET by-token endpoint, remove duplicate route"
```

---

## Task 4: Formulário Público de Inscrição (`/register/[qrToken]`)

**Files:**
- Create: `apps/web/src/app/register/[qrToken]/public-register-flow.tsx`
- Create: `apps/web/src/app/register/[qrToken]/public-register.module.css`
- Modify: `apps/web/src/app/register/[qrToken]/page.tsx`

**Interfaces:**
- Consumes: `GET /api/public/training-sessions/by-token/:qrToken` → `{ companyName, courseName, status }` (Task 3)
- Consumes: `POST /api/public/register/:qrToken` com body `{ name, cpf, email, cnhCategory, cnhExpiration }`

- [ ] **Step 1: Criar `public-register.module.css`**

```css
.container {
  min-height: 100vh;
  background-color: var(--bg);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1.5rem;
}

.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 2rem;
  width: 100%;
  max-width: 480px;
}

.logoText {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--teal);
  margin-bottom: 1.5rem;
  display: block;
}

.companyBadge {
  font-size: 0.75rem;
  color: var(--text-muted);
  margin-bottom: 0.25rem;
}

.sessionTitle {
  font-size: 1.25rem;
  font-weight: 600;
  color: var(--text);
  margin-bottom: 0.25rem;
}

.sessionDesc {
  font-size: 0.9rem;
  color: var(--text-2);
  margin-bottom: 1.5rem;
}

.divider {
  border: none;
  border-top: 1px solid var(--border);
  margin: 1.5rem 0;
}

.fieldGroup {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.label {
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--text-2);
}

.input {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--border);
  border-radius: 4px;
  font-size: 0.9375rem;
  color: var(--text);
  background: var(--surface);
  outline: none;
  transition: border-color 0.15s;
}

.input:focus {
  border-color: var(--teal);
}

.select {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--border);
  border-radius: 4px;
  font-size: 0.9375rem;
  color: var(--text);
  background: var(--surface);
  outline: none;
  cursor: pointer;
}

.errorMsg {
  font-size: 0.8125rem;
  color: #e53e3e;
  margin-bottom: 1rem;
}

.btnPrimary {
  width: 100%;
  padding: 0.75rem;
  background: var(--teal);
  color: #fff;
  border: none;
  border-radius: 4px;
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
}

.btnPrimary:hover:not(:disabled) {
  background: var(--teal-dark);
}

.btnPrimary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.successIcon {
  text-align: center;
  font-size: 3rem;
  margin-bottom: 1rem;
}

.successTitle {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--text);
  text-align: center;
  margin-bottom: 0.5rem;
}

.successDesc {
  font-size: 0.9rem;
  color: var(--text-2);
  text-align: center;
  line-height: 1.6;
}

.errorPage {
  text-align: center;
}

.errorPageTitle {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--text);
  margin-bottom: 0.5rem;
}

.errorPageDesc {
  font-size: 0.9rem;
  color: var(--text-2);
}
```

- [ ] **Step 2: Criar `public-register-flow.tsx`**

```typescript
'use client'

import { useState } from 'react'
import styles from './public-register.module.css'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'

type Screen = 'confirm' | 'form' | 'success'

interface Props {
  companyName: string
  courseName: string
  qrToken: string
}

interface FormState {
  name: string
  cpf: string
  email: string
  cnhCategory: string
  cnhExpiration: string
}

function validateCpf(cpf: string): boolean {
  const digits = cpf.replace(/\D/g, '')
  if (digits.length !== 11 || /^(\d)\1{10}$/.test(digits)) return false
  let sum = 0
  for (let i = 0; i < 9; i++) sum += Number(digits[i]) * (10 - i)
  let check = (sum * 10) % 11
  if (check === 10 || check === 11) check = 0
  if (check !== Number(digits[9])) return false
  sum = 0
  for (let i = 0; i < 10; i++) sum += Number(digits[i]) * (11 - i)
  check = (sum * 10) % 11
  if (check === 10 || check === 11) check = 0
  return check === Number(digits[10])
}

function applyCpfMask(value: string): string {
  const d = value.replace(/\D/g, '').slice(0, 11)
  if (d.length <= 3) return d
  if (d.length <= 6) return `${d.slice(0, 3)}.${d.slice(3)}`
  if (d.length <= 9) return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6)}`
  return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6, 9)}-${d.slice(9)}`
}

const empty: FormState = { name: '', cpf: '', email: '', cnhCategory: '', cnhExpiration: '' }

export function PublicRegisterFlow({ companyName, courseName, qrToken }: Props) {
  const [screen, setScreen] = useState<Screen>('confirm')
  const [form, setForm] = useState<FormState>(empty)
  const [submitting, setSubmitting] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')

  function setField(field: keyof FormState, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  async function handleSubmit() {
    const rawCpf = form.cpf.replace(/\D/g, '')
    if (!validateCpf(rawCpf)) {
      setErrorMsg('CPF inválido. Verifique os dígitos e tente novamente.')
      return
    }
    if (!form.name.trim() || !form.email.trim() || !form.cnhCategory || !form.cnhExpiration) {
      setErrorMsg('Preencha todos os campos obrigatórios.')
      return
    }

    setSubmitting(true)
    setErrorMsg('')
    try {
      const res = await fetch(`${API_URL}/public/register/${qrToken}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: form.name.trim(),
          cpf: rawCpf,
          email: form.email.trim(),
          cnhCategory: form.cnhCategory,
          cnhExpiration: form.cnhExpiration,
        }),
      })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        throw new Error(body.message ?? 'Erro ao realizar inscrição.')
      }
      setScreen('success')
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : 'Erro ao realizar inscrição.')
    } finally {
      setSubmitting(false)
    }
  }

  if (screen === 'confirm') {
    return (
      <>
        <p className={styles.companyBadge}>{companyName}</p>
        <p className={styles.sessionTitle}>{courseName}</p>
        <p className={styles.sessionDesc}>Confirme que este é o treinamento correto antes de preencher seus dados.</p>
        <hr className={styles.divider} />
        <button className={styles.btnPrimary} onClick={() => setScreen('form')}>
          Quero me inscrever
        </button>
      </>
    )
  }

  if (screen === 'success') {
    return (
      <>
        <div className={styles.successIcon}>✓</div>
        <p className={styles.successTitle}>Inscrição confirmada!</p>
        <p className={styles.successDesc}>
          Você está inscrito no treinamento <strong>{courseName}</strong> da empresa{' '}
          <strong>{companyName}</strong>.
        </p>
      </>
    )
  }

  return (
    <>
      <p className={styles.companyBadge}>{companyName} — {courseName}</p>
      <div className={styles.fieldGroup}>
        <div className={styles.field}>
          <label className={styles.label}>Nome completo *</label>
          <input
            className={styles.input}
            value={form.name}
            onChange={(e) => setField('name', e.target.value)}
            placeholder="Seu nome completo"
          />
        </div>
        <div className={styles.field}>
          <label className={styles.label}>CPF *</label>
          <input
            className={styles.input}
            value={form.cpf}
            onChange={(e) => setField('cpf', applyCpfMask(e.target.value))}
            placeholder="000.000.000-00"
            inputMode="numeric"
          />
        </div>
        <div className={styles.field}>
          <label className={styles.label}>E-mail *</label>
          <input
            className={styles.input}
            type="email"
            value={form.email}
            onChange={(e) => setField('email', e.target.value)}
            placeholder="seu@email.com"
          />
        </div>
        <div className={styles.field}>
          <label className={styles.label}>Categoria CNH *</label>
          <select
            className={styles.select}
            value={form.cnhCategory}
            onChange={(e) => setField('cnhCategory', e.target.value)}
          >
            <option value="">Selecione</option>
            {['A', 'B', 'AB', 'C', 'D', 'E'].map((cat) => (
              <option key={cat} value={cat}>{cat}</option>
            ))}
          </select>
        </div>
        <div className={styles.field}>
          <label className={styles.label}>Vencimento da CNH *</label>
          <input
            className={styles.input}
            type="date"
            value={form.cnhExpiration}
            onChange={(e) => setField('cnhExpiration', e.target.value)}
          />
        </div>
      </div>
      {errorMsg && <p className={styles.errorMsg}>{errorMsg}</p>}
      <button
        className={styles.btnPrimary}
        onClick={handleSubmit}
        disabled={submitting}
      >
        {submitting ? 'Enviando...' : 'Confirmar inscrição'}
      </button>
    </>
  )
}
```

- [ ] **Step 3: Substituir `apps/web/src/app/register/[qrToken]/page.tsx`**

```typescript
import { PublicRegisterFlow } from './public-register-flow'
import styles from './public-register.module.css'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'

interface RegisterPageProps {
  params: Promise<{ qrToken: string }>
}

interface SessionInfo {
  companyName: string
  courseName: string
  status: string
}

export default async function RegisterPage({ params }: RegisterPageProps) {
  const { qrToken } = await params

  let session: SessionInfo | null = null
  let notFound = false

  try {
    const res = await fetch(
      `${API_URL}/public/training-sessions/by-token/${qrToken}`,
      { cache: 'no-store' },
    )
    if (res.status === 404) {
      notFound = true
    } else if (res.ok) {
      session = await res.json()
    }
  } catch {
    notFound = true
  }

  const isEncerrado = session?.status === 'CANCELADO' || session?.status === 'CONCLUIDO'

  return (
    <div className={styles.container}>
      <div className={styles.card}>
        <span className={styles.logoText}>SIM Treinamentos</span>

        {notFound && (
          <div className={styles.errorPage}>
            <p className={styles.errorPageTitle}>Link inválido</p>
            <p className={styles.errorPageDesc}>Este QR Code não corresponde a nenhum treinamento ativo.</p>
          </div>
        )}

        {!notFound && isEncerrado && (
          <div className={styles.errorPage}>
            <p className={styles.errorPageTitle}>Inscrições encerradas</p>
            <p className={styles.errorPageDesc}>Este treinamento não está mais aceitando inscrições.</p>
          </div>
        )}

        {!notFound && session && !isEncerrado && (
          <PublicRegisterFlow
            companyName={session.companyName}
            courseName={session.courseName}
            qrToken={qrToken}
          />
        )}
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Testar o fluxo completo**

  1. Abrir uma sessão no painel admin → aba QR Code → copiar o link
  2. Abrir o link sem estar logado
  3. Verificar: tela de confirmação exibe empresa e curso corretos
  4. Clicar "Quero me inscrever" → preencher o formulário
  5. Testar CPF inválido (`111.111.111-11`) → deve exibir erro sem enviar
  6. Preencher CPF válido e submeter → tela de sucesso
  7. Tentar com o mesmo CPF novamente → backend retorna `409 CPF já inscrito neste treinamento`; frontend exibe a mensagem

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/app/register/
git commit -m "feat(register): implement public QR Code registration form"
```

---

## Task 5: Admin — `TrainingSessionDetailTabs` como dono do fetch

**Files:**
- Modify: `apps/web/src/features/training-sessions/training-session-detail-tabs.tsx`
- Modify: `apps/web/src/app/(admin)/training-sessions/page.tsx`

**Interfaces:**
- Produces: `TrainingSessionDetailTabs` com props `{ sessionId: string; onSessionChanged: (updated: TrainingSession) => void }`
- Produces: `onRefresh: () => Promise<void>` passado para `ParticipantsTab` e `DocumentsTab`

> **Atenção:** `handleSessionChanged` no `page.tsx` DEVE ser envolvido em `useCallback` (sem dependências) para evitar loop infinito. O `useEffect` de `fetchDetail` depende de `onSessionChanged` via `useCallback`. Se `onSessionChanged` for uma função inline, cada render do pai cria uma nova referência → `fetchDetail` é recriado → `useEffect` dispara → loop.

- [ ] **Step 1: Substituir `training-session-detail-tabs.tsx`**

```typescript
'use client'

import { useState, useEffect, useCallback } from 'react'
import { Loader2 } from 'lucide-react'
import { InfoTab } from './info-tab'
import { ParticipantsTab } from './participants-tab'
import { QrCodeTab } from './qr-code-tab'
import { DocumentsTab } from './documents-tab'
import { clientApi } from '@/lib/client-api'
import type { TrainingSession } from './types'
import styles from './training-session-detail-tabs.module.css'

type Tab = 'info' | 'participants' | 'qrcode' | 'documents'

interface TrainingSessionDetailTabsProps {
  sessionId: string
  onSessionChanged: (updated: TrainingSession) => void
}

interface BackendDetailSession {
  id: string
  company: { id: string; name: string; logoUrl?: string | null }
  course: { id: string; name: string; theoreticalHours: number; practicalHours: number }
  responsibleConsultant: { id: string; name: string }
  consultants?: Array<{ consultant: { id: string; name: string } }>
  city: string
  state: string
  date?: string | null
  participantCount?: number | null
  notes?: string | null
  status: TrainingSession['status']
  qrCodeToken: string
  participants?: Array<{
    id: string
    participationType: string
    status: string
    participant: {
      id: string
      name: string
      cpf: string
      email: string
      cnhCategory?: string | null
      cnhExpiration?: string | null
    }
    assessment?: { score?: number | null } | null
    certificate?: { id: string } | null
  }>
}

function mapDetailSession(s: BackendDetailSession): TrainingSession {
  return {
    id: s.id,
    company: { id: s.company.id, name: s.company.name, logoUrl: s.company.logoUrl },
    course: {
      id: s.course.id,
      name: s.course.name,
      theoryHours: s.course.theoreticalHours,
      practiceHours: s.course.practicalHours,
    },
    responsibleConsultant: s.responsibleConsultant,
    additionalConsultants: (s.consultants ?? [])
      .filter((sc) => sc.consultant.id !== s.responsibleConsultant.id)
      .map((sc) => sc.consultant),
    city: s.city,
    state: s.state,
    date: s.date ? s.date.split('T')[0] : '',
    participantCount: s.participantCount ?? 0,
    notes: s.notes ?? null,
    status: s.status,
    qrCodeToken: s.qrCodeToken,
    participants: (s.participants ?? []).map((tp) => ({
      id: tp.id,
      name: tp.participant.name,
      cpf: tp.participant.cpf,
      email: tp.participant.email,
      cnhCategory: tp.participant.cnhCategory ?? '',
      cnhExpiration: tp.participant.cnhExpiration
        ? new Date(tp.participant.cnhExpiration).toISOString().split('T')[0]
        : '',
      type: tp.participationType as TrainingSession['participants'][0]['type'],
      status: tp.status as TrainingSession['participants'][0]['status'],
      score: tp.assessment?.score ?? null,
      certificateGenerated: !!tp.certificate,
      certificateId: tp.certificate?.id ?? null,
    })),
  }
}

const tabs: { id: Tab; label: string }[] = [
  { id: 'info', label: 'Informações' },
  { id: 'participants', label: 'Participantes' },
  { id: 'qrcode', label: 'QR Code' },
  { id: 'documents', label: 'Documentos' },
]

export function TrainingSessionDetailTabs({ sessionId, onSessionChanged }: TrainingSessionDetailTabsProps) {
  const [session, setSession] = useState<TrainingSession | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [activeTab, setActiveTab] = useState<Tab>('info')

  const fetchDetail = useCallback(async () => {
    try {
      setLoading(true)
      const data = await clientApi.get<BackendDetailSession>(`/training-sessions/${sessionId}`)
      const mapped = mapDetailSession(data)
      setSession(mapped)
      onSessionChanged(mapped)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro ao carregar sessão')
    } finally {
      setLoading(false)
    }
  }, [sessionId, onSessionChanged])

  useEffect(() => { fetchDetail() }, [fetchDetail])

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', padding: '3rem' }}>
        <Loader2 size={28} style={{ opacity: 0.4 }} />
      </div>
    )
  }

  if (error || !session) {
    return <p style={{ color: '#e53e3e', padding: '1rem' }}>{error || 'Sessão não encontrada'}</p>
  }

  async function handleCancel() {
    await clientApi.patch(`/training-sessions/${sessionId}/cancel`, {})
    await fetchDetail()
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.tabList} role="tablist">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            role="tab"
            aria-selected={activeTab === tab.id}
            className={`${styles.tab} ${activeTab === tab.id ? styles.tabActive : ''}`}
            onClick={() => setActiveTab(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </div>
      <div className={styles.panel}>
        {activeTab === 'info' && (
          <InfoTab session={session} onArchive={() => {}} onCancel={handleCancel} />
        )}
        {activeTab === 'participants' && (
          <ParticipantsTab session={session} sessionId={sessionId} onRefresh={fetchDetail} />
        )}
        {activeTab === 'qrcode' && (
          <QrCodeTab session={session} />
        )}
        {activeTab === 'documents' && (
          <DocumentsTab session={session} sessionId={sessionId} onRefresh={fetchDetail} />
        )}
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Atualizar `apps/web/src/app/(admin)/training-sessions/page.tsx`**

2a. Adicionar `useCallback` ao import de React:
```typescript
import { useState, useEffect, useCallback } from 'react'
```

2b. Mudar `limit=100` para `limit=200`:
```typescript
clientApi.get<PaginatedResponse<BackendSession>>('/training-sessions?limit=200'),
```

2c. Renomear `handleUpdateSession` para `handleSessionChanged` e envolver em `useCallback`:
```typescript
const handleSessionChanged = useCallback((updated: TrainingSession) => {
  setSessions((prev) => prev.map((s) => (s.id === updated.id ? updated : s)))
  setSelected(updated)
}, [])
```

2d. No JSX do drawer, substituir `<TrainingSessionDetailTabs>`:
```typescript
{drawerMode === 'detail' && selected && (
  <TrainingSessionDetailTabs
    sessionId={selected.id}
    onSessionChanged={handleSessionChanged}
  />
)}
```

- [ ] **Step 3: Testar**

  1. Clicar em uma sessão na tabela → drawer exibe loading e depois dados reais (horas do curso, participantes)
  2. Clicar "Cancelar Treinamento" na aba Info → fechar o drawer → reabrir → status deve ser `CANCELADO`
  3. Verificar que não há loop infinito no console (nenhuma mensagem repetida de fetch)

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/features/training-sessions/training-session-detail-tabs.tsx apps/web/src/app/(admin)/training-sessions/page.tsx
git commit -m "feat(training-sessions): detail tabs own fetch, useCallback prevents infinite loop"
```

---

## Task 6: Admin — `participants-tab.tsx` conectado à API

**Files:**
- Modify: `apps/web/src/features/training-sessions/participants-tab.tsx`
- Modify: `apps/web/src/features/training-sessions/participants-tab.module.css`

**Interfaces:**
- Consumes: `session: TrainingSession`, `sessionId: string`, `onRefresh: () => Promise<void>` (Task 5)
- Consumes: `POST /training-sessions/:id/participants`, `PATCH /participants/:id/type` (body: `{ participationType }`), `POST /training-sessions/:id/start`, `POST /training-sessions/:id/complete`, `DELETE /participants/:id`

- [ ] **Step 1: Substituir `participants-tab.tsx`**

```typescript
'use client'

import { useState } from 'react'
import { UserPlus, Upload, Check, Trash2 } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { clientApi } from '@/lib/client-api'
import type { TrainingSession, TrainingParticipant, ParticipationType, ParticipantStatus } from './types'
import styles from './participants-tab.module.css'

interface ParticipantsTabProps {
  session: TrainingSession
  sessionId: string
  onRefresh: () => Promise<void>
}

const statusLabels: Record<ParticipantStatus, string> = {
  PENDENTE: 'Pendente',
  EM_AVALIACAO: 'Em Avaliação',
  APROVADO: 'Aprovado',
  NECESSITA_REAVALIACAO: 'Necessita Reavaliação',
}

const statusColors: Record<ParticipantStatus, string> = {
  PENDENTE: styles.statusPendente,
  EM_AVALIACAO: styles.statusEmAvaliacao,
  APROVADO: styles.statusAprovado,
  NECESSITA_REAVALIACAO: styles.statusNecessita,
}

interface AddParticipantForm {
  name: string
  cpf: string
  email: string
  cnhCategory: string
  cnhExpiration: string
}

const emptyForm: AddParticipantForm = { name: '', cpf: '', email: '', cnhCategory: '', cnhExpiration: '' }

export function ParticipantsTab({ session, sessionId, onRefresh }: ParticipantsTabProps) {
  const [showAddForm, setShowAddForm] = useState(false)
  const [form, setForm] = useState<AddParticipantForm>(emptyForm)
  const [busy, setBusy] = useState(false)
  const [actionError, setActionError] = useState('')
  const canEdit = session.status === 'PLANEJADO' || session.status === 'EM_ANDAMENTO'

  function setField(field: keyof AddParticipantForm, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  async function run(action: () => Promise<unknown>) {
    setBusy(true)
    setActionError('')
    try {
      await action()
      await onRefresh()
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Erro na operação')
    } finally {
      setBusy(false)
    }
  }

  async function addParticipant() {
    if (!form.name.trim() || !form.cpf.trim()) return
    await run(() =>
      clientApi.post(`/training-sessions/${sessionId}/participants`, {
        name: form.name.trim(),
        cpf: form.cpf.replace(/\D/g, ''),
        email: form.email.trim() || undefined,
        cnhCategory: form.cnhCategory || undefined,
        cnhExpiration: form.cnhExpiration || undefined,
      })
    )
    setForm(emptyForm)
    setShowAddForm(false)
  }

  async function toggleType(p: TrainingParticipant) {
    const newType: ParticipationType =
      p.type === 'SOMENTE_TEORICA' ? 'TEORICA_E_PRATICA' : 'SOMENTE_TEORICA'
    await run(() =>
      clientApi.patch(`/participants/${p.id}/type`, { participationType: newType })
    )
  }

  async function removeParticipant(id: string) {
    if (!confirm('Remover este participante?')) return
    await run(() => clientApi.delete(`/participants/${id}`))
  }

  const canStart = session.status === 'PLANEJADO'
  const canComplete =
    session.status === 'EM_ANDAMENTO' &&
    session.participants.length > 0 &&
    session.participants.every(
      (p) => p.type === 'SOMENTE_TEORICA' || p.status === 'APROVADO' || p.status === 'NECESSITA_REAVALIACAO'
    )

  return (
    <div className={styles.wrapper}>
      <div className={styles.toolbar}>
        <p className={styles.count}>{session.participants.length} participante(s)</p>
        <div className={styles.toolbarActions}>
          <Button variant="ghost" size="sm" disabled>
            <Upload size={14} /> Importar planilha
          </Button>
          <Button
            variant="secondary"
            size="sm"
            onClick={() => setShowAddForm((v) => !v)}
            disabled={!canEdit || busy}
          >
            <UserPlus size={14} /> Adicionar manualmente
          </Button>
        </div>
      </div>

      {actionError && (
        <p style={{ color: '#e53e3e', fontSize: '0.8125rem', marginBottom: '0.5rem' }}>
          {actionError}
        </p>
      )}

      {showAddForm && (
        <div className={styles.addForm}>
          <p className={styles.addFormTitle}>Novo Participante</p>
          <div className={styles.addFormGrid}>
            <div className={styles.field}>
              <label className={styles.label}>Nome *</label>
              <input className={styles.input} value={form.name} onChange={(e) => setField('name', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label className={styles.label}>CPF *</label>
              <input className={styles.input} value={form.cpf} onChange={(e) => setField('cpf', e.target.value)} placeholder="00000000000" />
            </div>
            <div className={styles.field}>
              <label className={styles.label}>E-mail</label>
              <input className={styles.input} type="email" value={form.email} onChange={(e) => setField('email', e.target.value)} />
            </div>
            <div className={styles.field}>
              <label className={styles.label}>Cat. CNH</label>
              <input className={styles.input} value={form.cnhCategory} onChange={(e) => setField('cnhCategory', e.target.value)} placeholder="B" />
            </div>
            <div className={styles.field}>
              <label className={styles.label}>Vencimento CNH</label>
              <input className={styles.input} type="date" value={form.cnhExpiration} onChange={(e) => setField('cnhExpiration', e.target.value)} />
            </div>
          </div>
          <div className={styles.addFormActions}>
            <Button variant="ghost" size="sm" onClick={() => { setShowAddForm(false); setForm(emptyForm) }}>Cancelar</Button>
            <Button
              variant="primary"
              size="sm"
              disabled={!form.name.trim() || !form.cpf.trim() || busy}
              onClick={addParticipant}
            >
              <Check size={14} /> Confirmar
            </Button>
          </div>
        </div>
      )}

      {session.participants.length === 0 ? (
        <p className={styles.empty}>Nenhum participante inscrito ainda.</p>
      ) : (
        <div className={styles.tableWrapper}>
          <table className={styles.table}>
            <thead>
              <tr className={styles.headRow}>
                <th className={styles.th}>Nome</th>
                <th className={styles.th}>CPF</th>
                <th className={`${styles.th} ${styles.center}`}>Tipo</th>
                <th className={`${styles.th} ${styles.center}`}>Avaliação</th>
                {canEdit && <th className={styles.th} />}
              </tr>
            </thead>
            <tbody>
              {session.participants.map((p) => (
                <tr key={p.id} className={styles.row}>
                  <td className={styles.td}>{p.name}</td>
                  <td className={styles.td}>{p.cpf}</td>
                  <td className={`${styles.td} ${styles.center}`}>
                    <button
                      className={`${styles.typeBtn} ${p.type === 'SOMENTE_TEORICA' ? styles.typeSoloTeoria : styles.typePratica}`}
                      onClick={() => toggleType(p)}
                      disabled={!canEdit || busy}
                      title="Clique para alternar"
                    >
                      {p.type === 'SOMENTE_TEORICA' ? 'Só Teoria' : 'Teoria + Prática'}
                    </button>
                  </td>
                  <td className={`${styles.td} ${styles.center}`}>
                    <span className={`${styles.statusBadge} ${statusColors[p.status]}`}>
                      {statusLabels[p.status]}
                    </span>
                  </td>
                  {canEdit && (
                    <td className={styles.td}>
                      <button
                        className={styles.deleteBtn}
                        onClick={() => removeParticipant(p.id)}
                        disabled={busy || p.status === 'EM_AVALIACAO'}
                        title="Remover participante"
                      >
                        <Trash2 size={14} />
                      </button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className={styles.footer}>
        {canStart && (
          <Button variant="primary" size="sm" disabled={busy}
            onClick={() => run(() => clientApi.post(`/training-sessions/${sessionId}/start`, {}))}>
            Iniciar Treinamento
          </Button>
        )}
        {canComplete && (
          <Button variant="primary" size="sm" disabled={busy}
            onClick={() => run(() => clientApi.post(`/training-sessions/${sessionId}/complete`, {}))}>
            Concluir Treinamento
          </Button>
        )}
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Adicionar `.deleteBtn` ao `participants-tab.module.css`**

Adicionar ao final do arquivo CSS existente:

```css
.deleteBtn {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--text-muted);
  padding: 0.25rem;
  border-radius: 4px;
  display: inline-flex;
  align-items: center;
  transition: color 0.15s;
}

.deleteBtn:hover:not(:disabled) { color: #e53e3e; }
.deleteBtn:disabled { opacity: 0.3; cursor: not-allowed; }
```

- [ ] **Step 3: Testar**

  1. Adicionar participante manualmente → aparece na lista após submit
  2. Clicar badge de tipo → alterna e persiste ao fechar/reabrir drawer
  3. Clicar "Iniciar Treinamento" → status muda para EM_ANDAMENTO
  4. Clicar ícone de lixeira → participante é removido

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/features/training-sessions/participants-tab.tsx apps/web/src/features/training-sessions/participants-tab.module.css
git commit -m "feat(participants-tab): connect all actions to API"
```

---

## Task 7: Admin — `documents-tab.tsx` com geração e envio de certificados

**Files:**
- Modify: `apps/web/src/features/training-sessions/documents-tab.tsx`
- Modify: `apps/web/src/features/training-sessions/documents-tab.module.css`

**Interfaces:**
- Consumes: `session: TrainingSession` (com `certificateId: string | null` por participante), `sessionId: string`, `onRefresh: () => Promise<void>` (Task 5)
- Consumes: `POST /training-sessions/:id/generate-certificates`, `POST /certificates/:certId/send` com body `{ to: 'participant' }`

- [ ] **Step 1: Substituir `documents-tab.tsx`**

```typescript
'use client'

import { useState } from 'react'
import { FileText, Send, Loader2 } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { clientApi } from '@/lib/client-api'
import type { TrainingSession } from './types'
import styles from './documents-tab.module.css'

interface DocumentsTabProps {
  session: TrainingSession
  sessionId: string
  onRefresh: () => Promise<void>
}

export function DocumentsTab({ session, sessionId, onRefresh }: DocumentsTabProps) {
  const [generating, setGenerating] = useState(false)
  const [generateError, setGenerateError] = useState('')
  const [sendingId, setSendingId] = useState<string | null>(null)
  const [sentIds, setSentIds] = useState<Set<string>>(new Set())

  if (session.status !== 'CONCLUIDO') {
    return (
      <div className={styles.locked}>
        <FileText size={48} strokeWidth={1} className={styles.lockedIcon} />
        <p className={styles.lockedTitle}>Documentação indisponível</p>
        <p className={styles.lockedDesc}>
          Conclua o treinamento na aba &quot;Participantes&quot; para habilitar a geração de certificados.
        </p>
      </div>
    )
  }

  const allGenerated = session.participants.every((p) => p.certificateGenerated)

  async function handleGenerateAll() {
    setGenerating(true)
    setGenerateError('')
    try {
      await clientApi.post(`/training-sessions/${sessionId}/generate-certificates`, {})
      await onRefresh()
    } catch (e) {
      setGenerateError(e instanceof Error ? e.message : 'Erro ao gerar certificados')
    } finally {
      setGenerating(false)
    }
  }

  async function handleSend(certificateId: string) {
    setSendingId(certificateId)
    try {
      await clientApi.post(`/certificates/${certificateId}/send`, { to: 'participant' })
      setSentIds((prev) => new Set(prev).add(certificateId))
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Erro ao enviar certificado')
    } finally {
      setSendingId(null)
    }
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.toolbar}>
        <p className={styles.summary}>
          {session.participants.filter((p) => p.certificateGenerated).length} / {session.participants.length} certificados gerados
        </p>
        {!allGenerated && (
          <Button variant="primary" size="sm" onClick={handleGenerateAll} disabled={generating}>
            {generating
              ? <><Loader2 size={14} style={{ animation: 'spin 1s linear infinite' }} /> Gerando PDFs...</>
              : <><FileText size={14} /> Gerar todos</>
            }
          </Button>
        )}
      </div>

      {generateError && (
        <p style={{ color: '#e53e3e', fontSize: '0.8125rem', marginBottom: '0.75rem' }}>
          {generateError}
        </p>
      )}

      <div className={styles.tableWrapper}>
        <table className={styles.table}>
          <thead>
            <tr className={styles.headRow}>
              <th className={styles.th}>Nome</th>
              <th className={`${styles.th} ${styles.center}`}>Tipo</th>
              <th className={`${styles.th} ${styles.center}`}>Score</th>
              <th className={`${styles.th} ${styles.center}`}>Certificado</th>
              <th className={styles.th} />
            </tr>
          </thead>
          <tbody>
            {session.participants.map((p) => (
              <tr key={p.id} className={styles.row}>
                <td className={styles.td}>{p.name}</td>
                <td className={`${styles.td} ${styles.center}`}>
                  {p.type === 'SOMENTE_TEORICA' ? 'Só Teoria' : 'Teoria + Prática'}
                </td>
                <td className={`${styles.td} ${styles.center}`}>
                  {p.score !== null
                    ? <span className={p.score >= 70 ? styles.scoreOk : styles.scoreFail}>{p.score}%</span>
                    : <span className={styles.scoreDash}>—</span>
                  }
                </td>
                <td className={`${styles.td} ${styles.center}`}>
                  {p.certificateGenerated
                    ? <span className={styles.certGenerated}>Gerado</span>
                    : <span className={styles.certPending}>Pendente</span>
                  }
                </td>
                <td className={styles.td}>
                  <div className={styles.rowActions}>
                    {p.certificateGenerated && p.certificateId && (
                      sentIds.has(p.certificateId) ? (
                        <span className={styles.sentLabel}>Enviado ✓</span>
                      ) : (
                        <button
                          className={styles.actionBtn}
                          onClick={() => handleSend(p.certificateId!)}
                          disabled={sendingId === p.certificateId}
                          title="Enviar por e-mail"
                        >
                          {sendingId === p.certificateId
                            ? <Loader2 size={14} style={{ animation: 'spin 1s linear infinite' }} />
                            : <Send size={14} />
                          }
                        </button>
                      )
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Adicionar `.sentLabel` ao `documents-tab.module.css`**

Adicionar ao final:

```css
.sentLabel {
  font-size: 0.75rem;
  color: #38a169;
  white-space: nowrap;
}
```

- [ ] **Step 3: Testar**

  1. Concluir um treinamento e navegar para aba Documentos
  2. "Gerar todos" → spinner durante geração, coluna muda para "Gerado"
  3. Ícone de envio → muda para "Enviado ✓"

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/features/training-sessions/documents-tab.tsx apps/web/src/features/training-sessions/documents-tab.module.css
git commit -m "feat(documents-tab): connect generate-certificates and send email"
```

---

## Task 8: Upload de logo de empresa

**Files:**
- Modify: `apps/web/src/features/companies/company-edit-form.tsx`
- Modify: `apps/web/src/app/(admin)/companies/page.tsx`

**Interfaces:**
- Consumes: `clientApi.upload<{ logoUrl: string }>(path, fd)` (Task 1)
- Consumes: `PATCH /companies/:id/logo` — multipart/form-data, campo `file`

- [ ] **Step 1: Modificar `company-edit-form.tsx`**

1a. Adicionar `companyId: string` à interface `CompanyEditFormProps`.

1b. Adicionar imports:
```typescript
import { useRef, useState } from 'react'  // useState já existe; adicionar useRef
import { Loader2 } from 'lucide-react'
import { clientApi } from '@/lib/client-api'
```

1c. No corpo do componente, adicionar estado e ref:
```typescript
const [currentLogoUrl, setCurrentLogoUrl] = useState(logoUrl)
const [uploading, setUploading] = useState(false)
const [uploadError, setUploadError] = useState('')
const fileInputRef = useRef<HTMLInputElement>(null)
```

1d. Adicionar função de upload:
```typescript
async function handleLogoChange(e: React.ChangeEvent<HTMLInputElement>) {
  const file = e.target.files?.[0]
  if (!file) return
  const fd = new FormData()
  fd.append('file', file)
  setUploading(true)
  setUploadError('')
  try {
    const res = await clientApi.upload<{ logoUrl: string }>(`/companies/${companyId}/logo`, fd)
    setCurrentLogoUrl(res.logoUrl)
  } catch (err) {
    setUploadError(err instanceof Error ? err.message : 'Erro ao fazer upload do logo')
  } finally {
    setUploading(false)
  }
}
```

1e. Substituir o bloco `<div className={styles.logoWrapper}>` pelo seguinte:
```typescript
<div
  className={styles.logoWrapper}
  style={{ position: 'relative', cursor: 'pointer' }}
  onClick={() => fileInputRef.current?.click()}
>
  {uploading ? (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', width: '100%', height: '100%' }}>
      <Loader2 size={24} style={{ opacity: 0.4, animation: 'spin 1s linear infinite' }} />
    </div>
  ) : (
    <Image
      src={currentLogoUrl ?? '/logo-simtc.png'}
      alt={`Logo ${name}`}
      fill
      style={{ objectFit: 'contain' }}
    />
  )}
  <span className={styles.logoHint}>Trocar imagem</span>
  <input
    ref={fileInputRef}
    type="file"
    accept="image/*"
    style={{ display: 'none' }}
    onChange={handleLogoChange}
  />
</div>
{uploadError && (
  <p style={{ color: '#e53e3e', fontSize: '0.8125rem' }}>{uploadError}</p>
)}
```

- [ ] **Step 2: Passar `companyId` em `companies/page.tsx`**

Localizar a renderização de `<CompanyEditForm>` e adicionar:
```typescript
<CompanyEditForm
  companyId={selected.id}
  // ... demais props inalteradas
/>
```

- [ ] **Step 3: Testar**

  1. Abrir drawer de empresa → clicar na área do logo
  2. Selecionar imagem → spinner durante upload → logo atualizado

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/features/companies/company-edit-form.tsx apps/web/src/app/(admin)/companies/page.tsx
git commit -m "feat(companies): implement immediate logo upload on file select"
```

---

## Task 9: Upload de assinatura de consultor

**Files:**
- Modify: `apps/web/src/features/consultants/consultant-edit-form.tsx`
- Modify: `apps/web/src/app/(admin)/consultants/page.tsx`

**Interfaces:**
- Consumes: `clientApi.upload<{ signatureUrl: string }>(path, fd)` (Task 1)
- Consumes: `PATCH /consultants/:id/signature` — multipart/form-data, campo `file`

- [ ] **Step 1: Modificar `consultant-edit-form.tsx`**

1a. Adicionar `consultantId: string` à interface `ConsultantEditFormProps`.

1b. Adicionar import:
```typescript
import { clientApi } from '@/lib/client-api'
```

1c. No corpo do componente, após `const [signatureFile, setSignatureFile] = useState<File | null>(null)`, adicionar:
```typescript
const [uploading, setUploading] = useState(false)
const [uploadError, setUploadError] = useState('')
```

1d. Adicionar função de upload:
```typescript
async function handleSignatureChange(e: React.ChangeEvent<HTMLInputElement>) {
  const file = e.target.files?.[0]
  if (!file) return
  setSignatureFile(file)
  const fd = new FormData()
  fd.append('file', file)
  setUploading(true)
  setUploadError('')
  try {
    await clientApi.upload(`/consultants/${consultantId}/signature`, fd)
  } catch (err) {
    setUploadError(err instanceof Error ? err.message : 'Erro ao fazer upload da assinatura')
  } finally {
    setUploading(false)
  }
}
```

1e. No `<input type="file">` do campo de assinatura, substituir `onChange`:
```typescript
onChange={(e) => handleSignatureChange(e)}
```

1f. Adicionar feedback abaixo do campo de assinatura:
```typescript
{uploading && <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Enviando...</p>}
{uploadError && <p style={{ fontSize: '0.75rem', color: '#e53e3e' }}>{uploadError}</p>}
```

- [ ] **Step 2: Passar `consultantId` em `consultants/page.tsx`**

Localizar a renderização de `<ConsultantEditForm>` e adicionar:
```typescript
<ConsultantEditForm
  consultantId={selected.id}
  // ... demais props inalteradas
/>
```

- [ ] **Step 3: Testar**

  1. Abrir drawer de consultor → selecionar arquivo de assinatura
  2. Verificar "Enviando..." durante upload
  3. No Supabase Storage → bucket `signatures` → verificar arquivo criado

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/features/consultants/consultant-edit-form.tsx apps/web/src/app/(admin)/consultants/page.tsx
git commit -m "feat(consultants): implement immediate signature upload on file select"
```

---

## Task 10: Portal do Consultor — Listagem de Sessões

**Files:**
- Modify: `apps/web/src/app/(consultant)/layout.tsx`
- Modify: `apps/web/src/app/(consultant)/my-sessions/page.tsx`
- Create: `apps/web/src/app/(consultant)/consultant-layout.module.css`
- Create: `apps/web/src/app/(consultant)/my-sessions/my-sessions-table.tsx`
- Create: `apps/web/src/app/(consultant)/my-sessions/my-sessions.module.css`
- Delete: `apps/web/src/app/(consultant)/my-sessions/overview.tsx`

**Interfaces:**
- Consumes: `GET /api/training-sessions?limit=200` — backend filtra por consultor automaticamente via JWT

- [ ] **Step 1: Substituir `layout.tsx` do consultor**

```typescript
import styles from './consultant-layout.module.css'

export default function ConsultantLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className={styles.shell}>
      <main className={styles.main}>{children}</main>
    </div>
  )
}
```

- [ ] **Step 2: Criar `consultant-layout.module.css`**

```css
.shell {
  min-height: 100vh;
  background-color: var(--bg);
}

.main {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}
```

- [ ] **Step 3: Criar `my-sessions.module.css`**

```css
.page {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.title {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--text);
}

.tableWrapper {
  overflow-x: auto;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface);
}

.table {
  width: 100%;
  border-collapse: collapse;
}

.headRow {
  background: var(--bg);
  border-bottom: 1px solid var(--border);
}

.th {
  padding: 0.75rem 1rem;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--text-2);
  text-align: left;
}

.center { text-align: center; }

.row { border-bottom: 1px solid var(--border); }
.row:last-child { border-bottom: none; }

.td {
  padding: 0.875rem 1rem;
  font-size: 0.9rem;
  color: var(--text);
}

.link {
  color: var(--teal);
  text-decoration: none;
  font-weight: 500;
}

.link:hover { text-decoration: underline; }

.empty {
  color: var(--text-muted);
  font-size: 0.9rem;
  text-align: center;
  padding: 2rem;
}

.badge {
  display: inline-block;
  padding: 0.25rem 0.625rem;
  border-radius: 4px;
  font-size: 0.75rem;
  font-weight: 600;
}

.statusPlanejado { background: var(--teal-soft); color: var(--teal-dark); }
.statusAndamento { background: var(--orange-soft); color: var(--orange-dark); }
.statusConcluido { background: #f0fff4; color: #276749; }
.statusCancelado { background: #fff5f5; color: #c53030; }
```

- [ ] **Step 4: Criar `my-sessions-table.tsx`**

```typescript
import Link from 'next/link'
import styles from './my-sessions.module.css'

export interface SessionRow {
  id: string
  companyName: string
  courseName: string
  date: string
  city: string
  state: string
  status: string
}

const statusLabels: Record<string, string> = {
  PLANEJADO: 'Planejado',
  EM_ANDAMENTO: 'Em Andamento',
  CONCLUIDO: 'Concluído',
  CANCELADO: 'Cancelado',
}

const statusClass: Record<string, string> = {
  PLANEJADO: styles.statusPlanejado,
  EM_ANDAMENTO: styles.statusAndamento,
  CONCLUIDO: styles.statusConcluido,
  CANCELADO: styles.statusCancelado,
}

export function MySessionsTable({ sessions }: { sessions: SessionRow[] }) {
  if (sessions.length === 0) {
    return <p className={styles.empty}>Nenhuma sessão encontrada.</p>
  }

  return (
    <div className={styles.tableWrapper}>
      <table className={styles.table}>
        <thead>
          <tr className={styles.headRow}>
            <th className={styles.th}>Empresa</th>
            <th className={styles.th}>Curso</th>
            <th className={styles.th}>Data</th>
            <th className={styles.th}>Local</th>
            <th className={`${styles.th} ${styles.center}`}>Status</th>
          </tr>
        </thead>
        <tbody>
          {sessions.map((s) => (
            <tr key={s.id} className={styles.row}>
              <td className={styles.td}>
                <Link href={`/my-sessions/${s.id}`} className={styles.link}>{s.companyName}</Link>
              </td>
              <td className={styles.td}>{s.courseName}</td>
              <td className={styles.td}>
                {s.date ? s.date.split('T')[0].split('-').reverse().join('/') : '—'}
              </td>
              <td className={styles.td}>{s.city} / {s.state}</td>
              <td className={`${styles.td} ${styles.center}`}>
                <span className={`${styles.badge} ${statusClass[s.status] ?? ''}`}>
                  {statusLabels[s.status] ?? s.status}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
```

- [ ] **Step 5: Implementar `my-sessions/page.tsx`**

```typescript
import { api } from '@/lib/api'
import { MySessionsTable, type SessionRow } from './my-sessions-table'
import styles from './my-sessions.module.css'

interface BackendSession {
  id: string
  company: { name: string }
  course: { name: string }
  date?: string | null
  city: string
  state: string
  status: string
}

export default async function MySessionsPage() {
  let sessions: SessionRow[] = []

  try {
    const res = await api.get<{ data: BackendSession[] }>('/training-sessions?limit=200')
    sessions = res.data.map((s) => ({
      id: s.id,
      companyName: s.company.name,
      courseName: s.course.name,
      date: s.date ?? '',
      city: s.city,
      state: s.state,
      status: s.status,
    }))
  } catch {
    // exibe vazio em caso de erro
  }

  return (
    <div className={styles.page}>
      <h1 className={styles.title}>Minhas Sessões</h1>
      <MySessionsTable sessions={sessions} />
    </div>
  )
}
```

- [ ] **Step 6: Deletar arquivo órfão**

```bash
rm apps/web/src/app/(consultant)/my-sessions/overview.tsx
```

- [ ] **Step 7: Testar**

Logar como consultor → navegar para `/my-sessions` → verificar que aparece apenas as sessões associadas ao consultor, com link clicável.

- [ ] **Step 8: Commit**

```bash
git add apps/web/src/app/(consultant)/
git rm apps/web/src/app/(consultant)/my-sessions/overview.tsx
git commit -m "feat(consultant): implement my-sessions listing, remove orphan overview.tsx"
```

---

## Task 11: Portal do Consultor — Detalhe e Tabs de Navegação

**Files:**
- Modify: `apps/web/src/app/(consultant)/my-sessions/[id]/page.tsx`
- Create: `apps/web/src/app/(consultant)/my-sessions/[id]/session-nav-tabs.tsx`
- Create: `apps/web/src/app/(consultant)/my-sessions/[id]/session-nav-tabs.module.css`
- Create: `apps/web/src/app/(consultant)/my-sessions/[id]/session-detail.module.css`

**Interfaces:**
- Consumes: `GET /api/training-sessions/:id`
- Produces: `<SessionNavTabs sessionId={id} />` — usado pelas 4 sub-páginas

- [ ] **Step 1: Criar `session-nav-tabs.module.css`**

```css
.nav {
  display: flex;
  gap: 0.25rem;
  border-bottom: 1px solid var(--border);
  margin-bottom: 1.5rem;
}

.tab {
  padding: 0.625rem 1rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--text-2);
  text-decoration: none;
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
  transition: color 0.15s, border-color 0.15s;
}

.tab:hover { color: var(--text); }

.tabActive {
  color: var(--teal);
  border-bottom-color: var(--teal);
}
```

- [ ] **Step 2: Criar `session-nav-tabs.tsx`**

```typescript
'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import styles from './session-nav-tabs.module.css'

const tabs = [
  { label: 'Visão Geral', path: (id: string) => `/my-sessions/${id}` },
  { label: 'Participantes', path: (id: string) => `/my-sessions/${id}/participants` },
  { label: 'QR Code', path: (id: string) => `/my-sessions/${id}/qr-code` },
  { label: 'Resultados', path: (id: string) => `/my-sessions/${id}/results` },
]

export function SessionNavTabs({ sessionId }: { sessionId: string }) {
  const pathname = usePathname()

  return (
    <nav className={styles.nav}>
      {tabs.map((tab) => {
        const href = tab.path(sessionId)
        return (
          <Link
            key={href}
            href={href}
            className={`${styles.tab} ${pathname === href ? styles.tabActive : ''}`}
          >
            {tab.label}
          </Link>
        )
      })}
    </nav>
  )
}
```

- [ ] **Step 3: Criar `session-detail.module.css`**

```css
.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 1.5rem;
}

.title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--text);
  margin-bottom: 1.25rem;
}

.grid {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.row {
  display: flex;
  gap: 1rem;
}

.label {
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--text-muted);
  min-width: 180px;
}

.value {
  font-size: 0.875rem;
  color: var(--text);
}
```

- [ ] **Step 4: Implementar `my-sessions/[id]/page.tsx`**

```typescript
import { api } from '@/lib/api'
import { SessionNavTabs } from './session-nav-tabs'
import styles from './session-detail.module.css'

interface BackendSession {
  id: string
  company: { name: string }
  course: { name: string; theoreticalHours: number; practicalHours: number }
  responsibleConsultant: { name: string }
  consultants?: Array<{ consultant: { name: string } }>
  city: string
  state: string
  date?: string | null
  notes?: string | null
  status: string
}

interface Props {
  params: Promise<{ id: string }>
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.row}>
      <span className={styles.label}>{label}</span>
      <span className={styles.value}>{value}</span>
    </div>
  )
}

export default async function SessionDetailPage({ params }: Props) {
  const { id } = await params
  const s = await api.get<BackendSession>(`/training-sessions/${id}`)

  const additionals = (s.consultants ?? [])
    .filter((sc) => sc.consultant.name !== s.responsibleConsultant.name)
    .map((sc) => sc.consultant.name)
    .join(', ')

  const dateFormatted = s.date
    ? s.date.split('T')[0].split('-').reverse().join('/')
    : '—'

  const hours = `${s.course.theoreticalHours}h teórica${s.course.practicalHours > 0 ? ` + ${s.course.practicalHours}h prática` : ''}`

  return (
    <div>
      <SessionNavTabs sessionId={id} />
      <div className={styles.card}>
        <h2 className={styles.title}>{s.company.name} — {s.course.name}</h2>
        <div className={styles.grid}>
          <Row label="Status" value={s.status} />
          <Row label="Data" value={dateFormatted} />
          <Row label="Local" value={`${s.city} / ${s.state}`} />
          <Row label="Carga horária" value={hours} />
          <Row label="Consultor responsável" value={s.responsibleConsultant.name} />
          {additionals && <Row label="Consultores adicionais" value={additionals} />}
          {s.notes && <Row label="Observações" value={s.notes} />}
        </div>
      </div>
    </div>
  )
}
```

- [ ] **Step 5: Testar**

  1. Clicar em uma sessão na listagem → página de detalhe com dados corretos
  2. Clicar nas tabs → navegação entre sub-rotas funciona; tab ativa destacada

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/app/(consultant)/my-sessions/[id]/
git commit -m "feat(consultant): session detail page with nav tabs"
```

---

## Task 12: Portal do Consultor — Participantes, QR Code e Resultados

**Files:**
- Modify: `apps/web/src/app/(consultant)/my-sessions/[id]/participants/page.tsx`
- Modify: `apps/web/src/app/(consultant)/my-sessions/[id]/qr-code/page.tsx`
- Modify: `apps/web/src/app/(consultant)/my-sessions/[id]/results/page.tsx`
- Create: `apps/web/src/app/(consultant)/my-sessions/[id]/participants/participants.module.css`
- Create: `apps/web/src/app/(consultant)/my-sessions/[id]/qr-code/qr-code.module.css`
- Create: `apps/web/src/app/(consultant)/my-sessions/[id]/results/results.module.css`

**Interfaces:**
- Consumes: `GET /api/training-sessions/:id` (participants, qr-code)
- Consumes: `GET /api/reports/training-sessions/:id` (results) — shape real: `participants[].assessment.items[].infractionNote.{ noteType, deduction, infraction.category.id }`
- Consumes: `calculateCategoryScore`, `calculateOverallScore`, `getApprovalLabel` de `@simtc/shared-types`

- [ ] **Step 1: Criar `participants.module.css`**

```css
.tableWrapper {
  overflow-x: auto;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface);
}

.table { width: 100%; border-collapse: collapse; }
.headRow { background: var(--bg); border-bottom: 1px solid var(--border); }
.th { padding: 0.75rem 1rem; font-size: 0.8125rem; font-weight: 600; color: var(--text-2); text-align: left; }
.center { text-align: center; }
.row { border-bottom: 1px solid var(--border); }
.row:last-child { border-bottom: none; }
.td { padding: 0.875rem 1rem; font-size: 0.9rem; color: var(--text); }
.empty { color: var(--text-muted); font-size: 0.9rem; text-align: center; padding: 2rem; }
```

- [ ] **Step 2: Implementar `participants/page.tsx`**

```typescript
import { api } from '@/lib/api'
import { SessionNavTabs } from '../session-nav-tabs'
import styles from './participants.module.css'

interface BackendParticipant {
  id: string
  participationType: string
  status: string
  participant: { name: string; cpf: string }
}

interface Props {
  params: Promise<{ id: string }>
}

const statusLabels: Record<string, string> = {
  PENDENTE: 'Pendente',
  EM_AVALIACAO: 'Em Avaliação',
  APROVADO: 'Aprovado',
  NECESSITA_REAVALIACAO: 'Necessita Reavaliação',
}

function maskCpf(cpf: string): string {
  const d = cpf.replace(/\D/g, '')
  if (d.length !== 11) return cpf
  return `${d.slice(0, 3)}.${d.slice(3, 6)}.***-**`
}

export default async function ParticipantsPage({ params }: Props) {
  const { id } = await params
  const session = await api.get<{ participants?: BackendParticipant[] }>(`/training-sessions/${id}`)
  const participants = session.participants ?? []

  return (
    <div>
      <SessionNavTabs sessionId={id} />
      <p style={{ fontSize: '0.875rem', color: 'var(--text-2)', marginBottom: '1rem' }}>
        {participants.length} participante(s)
      </p>
      {participants.length === 0 ? (
        <p className={styles.empty}>Nenhum participante inscrito.</p>
      ) : (
        <div className={styles.tableWrapper}>
          <table className={styles.table}>
            <thead>
              <tr className={styles.headRow}>
                <th className={styles.th}>Nome</th>
                <th className={styles.th}>CPF</th>
                <th className={`${styles.th} ${styles.center}`}>Tipo</th>
                <th className={`${styles.th} ${styles.center}`}>Status</th>
              </tr>
            </thead>
            <tbody>
              {participants.map((tp) => (
                <tr key={tp.id} className={styles.row}>
                  <td className={styles.td}>{tp.participant.name}</td>
                  <td className={styles.td}>{maskCpf(tp.participant.cpf)}</td>
                  <td className={`${styles.td} ${styles.center}`}>
                    {tp.participationType === 'SOMENTE_TEORICA' ? 'Só Teoria' : 'Teoria + Prática'}
                  </td>
                  <td className={`${styles.td} ${styles.center}`}>
                    {statusLabels[tp.status] ?? tp.status}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 3: Criar `qr-code.module.css`**

```css
.wrapper {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 2rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  max-width: 400px;
}

.label { font-size: 0.875rem; font-weight: 600; color: var(--text); text-align: center; }
.url { font-size: 0.8125rem; color: var(--text-muted); word-break: break-all; text-align: center; }
.hint { font-size: 0.8125rem; color: var(--text-2); text-align: center; line-height: 1.6; }
```

- [ ] **Step 4: Implementar `qr-code/page.tsx`**

```typescript
import { api } from '@/lib/api'
import { SessionNavTabs } from '../session-nav-tabs'
import styles from './qr-code.module.css'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'
const APP_URL = process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000'

interface Props {
  params: Promise<{ id: string }>
}

export default async function QrCodePage({ params }: Props) {
  const { id } = await params
  const session = await api.get<{
    id: string
    qrCodeToken: string
    company: { name: string }
    course: { name: string }
  }>(`/training-sessions/${id}`)

  return (
    <div>
      <SessionNavTabs sessionId={id} />
      <div className={styles.wrapper}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={`${API_URL}/training-sessions/${id}/qr-code`}
          alt="QR Code"
          width={220}
          height={220}
        />
        <p className={styles.label}>{session.company.name} — {session.course.name}</p>
        <p className={styles.url}>{APP_URL}/register/{session.qrCodeToken}</p>
        <p className={styles.hint}>
          Projete este QR Code para os participantes escanearem com o celular.
        </p>
      </div>
    </div>
  )
}
```

- [ ] **Step 5: Criar `results.module.css`**

```css
.tableWrapper {
  overflow-x: auto;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface);
}

.table { width: 100%; border-collapse: collapse; }
.headRow { background: var(--bg); border-bottom: 1px solid var(--border); }
.th { padding: 0.75rem 1rem; font-size: 0.8125rem; font-weight: 600; color: var(--text-2); text-align: left; }
.center { text-align: center; }
.row { border-bottom: 1px solid var(--border); }
.row:last-child { border-bottom: none; }
.td { padding: 0.875rem 1rem; font-size: 0.9rem; color: var(--text); }

.badge {
  display: inline-block;
  padding: 0.25rem 0.625rem;
  border-radius: 4px;
  font-size: 0.75rem;
  font-weight: 600;
}

.approved { background: #f0fff4; color: #276749; }
.failed   { background: #fff5f5; color: #c53030; }
.neutral  { background: var(--bg); color: var(--text-muted); }
```

- [ ] **Step 6: Implementar `results/page.tsx`**

> **Shape real do response de `GET /reports/training-sessions/:id`:** `participants[].assessment.items[].infractionNote.{ noteType: 'B'|'PM'|'M', deduction: number, infraction.category.id: string }`. Não há `item.noteType` nem `item.infraction.notes[]` diretamente.

```typescript
import { api } from '@/lib/api'
import { SessionNavTabs } from '../session-nav-tabs'
import { calculateCategoryScore, calculateOverallScore, getApprovalLabel } from '@simtc/shared-types'
import styles from './results.module.css'

interface InfractionNote {
  noteType: 'B' | 'PM' | 'M'
  deduction: number
  infraction: {
    category: { id: string; name: string }
  }
}

interface AssessmentItem {
  infractionNote: InfractionNote
}

interface Assessment {
  items: AssessmentItem[]
}

interface ReportParticipant {
  id: string
  participationType: string
  participant: { name: string }
  assessment: Assessment | null
}

interface Props {
  params: Promise<{ id: string }>
}

export default async function ResultsPage({ params }: Props) {
  const { id } = await params
  const report = await api.get<{ participants?: ReportParticipant[] }>(
    `/reports/training-sessions/${id}`
  )
  const participants = report.participants ?? []

  const results = participants.map((tp) => {
    if (tp.participationType === 'SOMENTE_TEORICA' || !tp.assessment) {
      return { name: tp.participant.name, type: tp.participationType, score: null, label: 'Só Teoria' }
    }

    // Agrupar deduções por categoria
    const byCategory = new Map<string, number[]>()
    for (const item of tp.assessment.items) {
      const catId = item.infractionNote.infraction.category.id
      const deduction = item.infractionNote.deduction
      byCategory.set(catId, [...(byCategory.get(catId) ?? []), deduction])
    }

    const categoryScores = Array.from(byCategory.values()).map(calculateCategoryScore)
    const overall = calculateOverallScore(categoryScores)

    return {
      name: tp.participant.name,
      type: tp.participationType,
      score: Math.round(overall),
      label: getApprovalLabel(overall),
    }
  })

  return (
    <div>
      <SessionNavTabs sessionId={id} />
      <div className={styles.tableWrapper}>
        <table className={styles.table}>
          <thead>
            <tr className={styles.headRow}>
              <th className={styles.th}>Nome</th>
              <th className={`${styles.th} ${styles.center}`}>Tipo</th>
              <th className={`${styles.th} ${styles.center}`}>Score</th>
              <th className={`${styles.th} ${styles.center}`}>Resultado</th>
            </tr>
          </thead>
          <tbody>
            {results.map((r) => (
              <tr key={r.name} className={styles.row}>
                <td className={styles.td}>{r.name}</td>
                <td className={`${styles.td} ${styles.center}`}>
                  {r.type === 'SOMENTE_TEORICA' ? 'Só Teoria' : 'Teoria + Prática'}
                </td>
                <td className={`${styles.td} ${styles.center}`}>
                  {r.score !== null ? `${r.score}%` : '—'}
                </td>
                <td className={`${styles.td} ${styles.center}`}>
                  <span className={`${styles.badge} ${
                    r.score === null ? styles.neutral
                    : r.score >= 70 ? styles.approved
                    : styles.failed
                  }`}>
                    {r.label}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
```

- [ ] **Step 7: Testar**

  1. `/my-sessions/[id]/participants` → tabela com CPFs mascarados, read-only
  2. `/my-sessions/[id]/qr-code` → QR Code com URL `http://localhost:3000/register/...`
  3. `/my-sessions/[id]/results` → scores calculados; "—" e "Só Teoria" para `SOMENTE_TEORICA`

- [ ] **Step 8: Commit**

```bash
git add apps/web/src/app/(consultant)/my-sessions/[id]/participants/ \
        apps/web/src/app/(consultant)/my-sessions/[id]/qr-code/ \
        apps/web/src/app/(consultant)/my-sessions/[id]/results/
git commit -m "feat(consultant): implement participants, qr-code and results pages"
```
