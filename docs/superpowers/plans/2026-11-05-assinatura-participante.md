# Assinatura do participante no formulário de inscrição — Plano de Implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIA: usar superpowers:subagent-driven-development (implementadores em haiku, uma fase por vez, validação do usuário entre fases) ou superpowers:executing-plans. Os passos usam checkbox (`- [ ]`).

**Goal:** O participante assina com o dedo no formulário público `/register/[qrToken]`; a assinatura fica ligada ao CPF e sai no certificado.

**Architecture:** Dois campos novos em `Participant` (`signaturePath`, `signatureUpdatedAt`) apontam para um PNG no bucket privado `signatures` (prefixo `participants/`). A inscrição pública passa a aceitar multipart (JSON continua aceito). Prévia, troca e remoção exigem CPF + e-mail conferindo. O PDF resolve uma signed URL de 300s, como já faz com o consultor.

**Tech Stack:** NestJS + Prisma + Supabase Storage + multer (backend, jest); Next.js (App Router) + CSS Modules + `signature_pad` (web).

**Spec:** `brainstorm-assinatura-participante.md` (raiz do repo). Decisões de 05/11/2026 sobre os pontos em aberto: **inclui** remover pelo aluno (§11.2) e pelo admin (§11.3); **sem** marca d'água (§11.4).

## Global Constraints

- Bucket privado **existente** `signatures` (o mesmo dos consultores), com os alunos sob o prefixo `participants/`; path `participants/{participantId}/{Date.now()}.png`; no banco só o path, nunca a URL. Desvio consciente do brainstorm §3 (bucket separado), por escolha do usuário em 05/11/2026; as leituras do consultor e do aluno nunca se cruzam porque o aluno só usa o prefixo `participants/`.
- Prévia: signed URL de **120 s**. PDF: **300 s**. Throttle da prévia: **20/hora/IP**. Throttle da inscrição continua **10/hora**.
- Upload: máx. **300 KB**, magic bytes PNG `89 50 4E 47`, largura/altura lidas do IHDR (bytes 16–23), recusa acima de **2000×2000**. Sem `sharp`.
- Cliente exporta PNG transparente recortado (margem 8 px), máx. **600×200**. `signature_pad`: traço `#111`, `minWidth 0.8`, `maxWidth 2.6`. Confirmar exige ≥ 2 traços ou ≥ 15 pontos.
- E-mail comparado em minúsculas e sem espaços nas pontas. A prévia e o `locked` não devolvem nenhum outro dado do participante.
- Falha no upload **não derruba a inscrição** (`signatureSaved: false`). Troca/remoção sem e-mail conferindo: mantém a antiga e descarta a nova (`signatureIgnored: true`).
- Storage nunca dentro de transação: apagar arquivos **depois do commit**, com `.catch(() => null)`.
- Migration só com `prisma migrate dev --create-only` + `migrate deploy`. **Nunca `migrate reset`.**
- Textos de UI em português, exatamente como no brainstorm §5. Commits em português, `tipo(escopo): descrição`, uma linha. Rodar `npm run build` em `apps/web` ao fim de cada fase web.
- **Árvore suja:** já existem alterações não commitadas do usuário em `participants.controller.ts`, `participants.service.ts`, `public-register-flow.tsx`, `public-register.module.css`, `participants-tab.tsx`, `session-management-drawer.*`. Nunca usar `git restore/checkout/stash`; ler o arquivo antes de editar e commitar só com `git add -p` os hunks próprios (ou perguntar se os hunks se misturarem).

## Review Focus

1. **`include: { participant: true }` vaza `signaturePath`** nas listagens (`findBySession`, `findOne` de sessão, mobile). Esperado: nenhuma resposta traz o path; só `hasSignature`. (Tasks 2 e 8)
2. **Multipart não passa pelo `ValidationPipe`** (o DTO é `interface`, sem validação hoje). Esperado: `participationType` inválido ou `signatureAction` desconhecido → 400. (Task 2)
3. **Concorrência/duplo envio:** dois uploads para o mesmo CPF. Esperado: o último vence e o arquivo perdedor não fica órfão. (Task 2)
4. **Arquivo PNG corrompido/truncado** (menos de 24 bytes). Esperado: 400, sem exceção de índice. (Task 1)
5. **Sessão encerrada/CPF inexistente na prévia.** Esperado: 400 / `none`, sem 500. (Task 4)

---

## Fase 1 — Backend: dados e upload

### Task 1: Validador de PNG

**Files:**
- Create: `apps/backend/src/participants/png-signature.util.ts`
- Test: `apps/backend/test/png-signature.util.spec.ts`

**Interfaces:**
- Produces: `assertValidSignaturePng(buffer: Buffer): void` — lança `BadRequestException` se não for PNG, tiver < 24 bytes ou largura/altura > 2000.

- [ ] **Step 1: Testes** (`png-signature.util.spec.ts`): `aceita PNG 600x200`, `recusa buffer que não é PNG`, `recusa buffer com menos de 24 bytes`, `recusa 2001x100`, `recusa 100x2001`. Montar o buffer com a assinatura `89504E470D0A1A0A` + chunk IHDR (largura/altura big-endian nos bytes 16–23).
- [ ] **Step 2:** `npx jest test/png-signature.util.spec.ts` → FAIL (módulo inexistente).
- [ ] **Step 3:** Implementar `assertValidSignaturePng` lendo `readUInt32BE(16)` e `readUInt32BE(20)`.
- [ ] **Step 4:** mesmo comando → PASS.
- [ ] **Step 5:** `git commit -m "feat(backend): validador de png para assinatura do participante"`

### Task 2: Schema, bucket, tipos e `registerPublic` com assinatura

**Files:**
- Modify: `apps/backend/prisma/schema.prisma` (model `Participant`), `packages/shared-types/src/dtos/training.dto.ts`, `apps/backend/src/participants/public-register.controller.ts`, `apps/backend/src/participants/participants.service.ts`, `apps/backend/src/participants/participants.module.ts` (só se o multer exigir)
- Create: `apps/backend/prisma/migrations/<timestamp>_add_participant_signature/migration.sql`
- Test: `apps/backend/test/participants.service.spec.ts` (novo `describe('registerPublic — assinatura')`)

**Interfaces:**
- Consumes: `assertValidSignaturePng` (Task 1); `StorageService.upload/delete` (existentes).
- Produces:
  - `type SignatureAction = 'keep' | 'replace' | 'none'` e `RegisterParticipantPublicDto.signatureAction?: SignatureAction` em shared-types; `RegisterParticipantPublicResponse = TrainingParticipant & { signatureSaved: boolean; signatureIgnored?: boolean }` (nome/forma conforme os tipos já existentes no arquivo).
  - `registerPublic(qrCodeToken: string, dto: RegisterParticipantPublicDto, signature?: Express.Multer.File)`.
  - Constante `SIGNATURE_BUCKET = 'signatures'` exportada de `participants/signature.constants.ts`.
  - Helper privado `emailMatches(stored: string | null, given?: string): boolean` (trim + lowercase; falso se algum lado vazio) — reutilizado nas Tasks 4 e 5.

- [ ] **Step 1: Migration.** Adicionar `signaturePath String?` e `signatureUpdatedAt DateTime?` ao `Participant`; gerar com `npx prisma migrate dev --create-only --name add_participant_signature`, conferir o SQL (só dois `ADD COLUMN`) e `npx prisma migrate deploy`, depois `npx prisma generate`. O bucket `signatures` já existe e é privado; não criar bucket nem pasta (o prefixo `participants/` nasce com o primeiro upload).
- [ ] **Step 2: Testes** (mockar `StorageService` com `upload/delete` jest.fn; `emailMatches` coberto via `registerPublic`):
  - `salva assinatura nova`: arquivo PNG válido + `replace` → `storage.upload('signatures', 'participants/<id>/<ts>.png', …)` chamado **antes** da transação; `participant.update` com `signaturePath`/`signatureUpdatedAt`; resposta `signatureSaved: true`.
  - `keep` e `none` → nenhum upload, `signatureSaved: false`, `signatureIgnored` ausente.
  - `replace` com assinatura já salva e e-mail diferente → sem upload, antiga mantida, `signatureIgnored: true`.
  - `replace` com assinatura já salva e e-mail igual (caixa/espaços diferentes) → sobe a nova e, **após** o commit, `storage.delete` do path antigo.
  - falha no upload → inscrição criada, `signatureSaved: false`.
  - falha na transação → `storage.delete` do arquivo recém-enviado; erro propagado.
  - `replace` sem arquivo → `BadRequestException`; arquivo não-PNG → `BadRequestException`; `signatureAction` desconhecido → `BadRequestException`; `participationType` fora do enum → `BadRequestException`.
- [ ] **Step 3:** `npx jest test/participants.service.spec.ts` → FAIL.
- [ ] **Step 4: Implementar.**
  - Controller: `@UseInterceptors(FileInterceptor('signature', { limits: { fileSize: 300 * 1024 } }))` no `POST register/:qrToken`, passando `@UploadedFile() signature`. Aceita JSON e multipart. Como o corpo não é validado (interface), validar `participationType` e `signatureAction` à mão no service. Estourar o limite do multer vira 413 → o front trata como "assinatura não salva"? **Não:** converter em 400 claro (`BadRequestException('Assinatura maior que 300 KB')`).
  - Service: seguir a ordem do brainstorm §6 (sessão → dedupe → conferência de e-mail se já há assinatura → upload → transação criando o `TrainingParticipant` + `participant.update` → rollback do arquivo → apagar antigo pós-commit). Para quem não tinha assinatura, `replace` não exige e-mail. Falha no upload só vira `signatureSaved: false`.
  - Concorrência (Review Focus 3): fazer o `participant.update` condicional ao `signaturePath` lido no passo da conferência (`updateMany` com `where: { id, signaturePath: <lido> }`); se `count === 0`, apagar o arquivo recém-enviado e responder `signatureIgnored: true`.
- [ ] **Step 5:** testes PASS; `npx tsc --noEmit -p apps/backend`.
- [ ] **Step 6:** `git commit -m "feat(backend): assinatura do participante na inscrição pública"` (inclui migration e shared-types).

---

## Fase 2 — Backend: prévia, remoção pelo aluno e limpeza

### Task 3: Cleanup devolve os paths

**Files:**
- Modify: `apps/backend/src/participants/participant-cleanup.util.ts`, e os 3 chamadores: `participants.service.ts` (`removeParticipant`), `training-sessions/training-sessions.service.ts` (`deleteSession`), `companies/companies.service.ts` (~l.153)
- Test: `apps/backend/test/participants.service.spec.ts`, `apps/backend/test/training-sessions.service.spec.ts`

**Interfaces:**
- Produces: `deleteOrphanedParticipants(tx, ids): Promise<string[]>` — devolve os `signaturePath` dos participantes apagados (vazio se nenhum). Quem chama apaga do bucket `signatures` depois do commit com `.catch(() => null)`.

- [ ] **Step 1: Testes:** `removeParticipant apaga a assinatura do último vínculo` (mock `participant.findMany` com `signaturePath`; espera `storage.delete('signatures', path)` após a transação); `não apaga a assinatura se o participante continua em outro treinamento`; idem para `deleteSession`.
- [ ] **Step 2:** rodar → FAIL. **Step 3:** implementar (ler `signaturePath` dos órfãos antes do `deleteMany`) e ajustar os 3 chamadores. **Step 4:** rodar `npx jest` completo → PASS.
- [ ] **Step 5:** `git commit -m "fix(backend): apagar assinatura do storage ao remover participante órfão"`

### Task 4: Prévia da assinatura

**Files:**
- Modify: `apps/backend/src/participants/public-register.controller.ts`, `participants.service.ts`
- Create: `apps/backend/src/participants/dto/signature-lookup.dto.ts` (classe com `class-validator`: `cpf` válido via mesmo padrão do `lookup-participant.dto.ts`, `email` `@IsEmail`)
- Test: `apps/backend/test/participants.service.spec.ts`, `apps/backend/test/signature-preview.controller.spec.ts` (DTO)

**Interfaces:**
- Consumes: `emailMatches`, `SIGNATURE_BUCKET` (Task 2).
- Produces: `POST /public/register/:qrToken/signature-preview` → `SignaturePreviewResponse = { status: 'none' } | { status: 'found'; previewUrl: string; updatedAt: string } | { status: 'locked' }` (adicionar em shared-types). Método `signaturePreview(qrToken: string, dto: SignatureLookupDto)`. `@Throttle({ default: { limit: 20, ttl: 3600_000 } })`.

- [ ] **Step 1: Testes:** `none` (CPF inexistente); `none` (CPF existe sem assinatura); `found` (e-mail confere, signed URL com expiração **120**); `locked` (e-mail diferente; **sem** `previewUrl`); sessão `CANCELADO`/`CONCLUIDO` → `BadRequestException`; token inexistente → 404; signed URL falhando → `none`; DTO recusa CPF/e-mail inválido.
- [ ] **Step 2–4:** FAIL → implementar (CPF normalizado só com dígitos, como `lookupByCpf`) → PASS. Resposta nunca inclui nome/CNH.
- [ ] **Step 5:** `git commit -m "feat(backend): prévia da assinatura com confere de cpf e e-mail"`

### Task 5: Remoção da assinatura pelo aluno

**Files:** mesmos da Task 4. Test em `participants.service.spec.ts`.

**Interfaces:**
- Consumes: `signaturePreview` helpers da Task 4.
- Produces: `DELETE /public/register/:qrToken/signature` com body `SignatureLookupDto` → `{ removed: true }`; se `none` → `{ removed: false }`; se `locked` → `403`. Método `removeOwnSignature(qrToken, dto)`. Mesmo throttle de 20/h (compartilhar a constante).

- [ ] **Step 1: Testes:** remove quando CPF + e-mail conferem (zera `signaturePath`/`signatureUpdatedAt` no banco e, **depois**, `storage.delete`); `403` quando o e-mail não confere, sem tocar em banco/storage; `{ removed: false }` sem assinatura; falha do storage não desfaz a remoção no banco.
- [ ] **Step 2–4:** FAIL → implementar (banco primeiro, storage depois com `.catch`) → PASS.
- [ ] **Step 5:** `git commit -m "feat(backend): aluno remove a própria assinatura salva"`

---

## Fase 3 — Web: componente de assinatura

### Task 6: `useSignaturePad`, recorte e `SignatureModal`

**Files:**
- Create: `apps/web/src/lib/signature/crop-signature.ts`, `apps/web/src/lib/signature/use-signature-pad.ts`, `apps/web/src/components/signature-modal/signature-modal.tsx` + `.module.css`, rota de teste `apps/web/src/app/dev/signature/page.tsx` (**remover na Task 11**)
- Modify: `apps/web/package.json` (`signature_pad`, versão exata, fixada)
- Test: `apps/web/src/lib/signature/crop-signature.test.ts` **se** já existir runner de testes no web (verificar `package.json`); caso contrário, validar pela rota de dev.

**Interfaces:**
- Produces:
  - `cropAndScaleSignature(canvas: HTMLCanvasElement): Promise<Blob | null>` — recorta o espaço transparente (margem 8 px), reduz para ≤ 600×200 mantendo proporção, PNG transparente; `null` se vazio.
  - `useSignaturePad(): { canvasRef; isEmpty: boolean; strokeCount: number; clear(): void; toBlob(): Promise<Blob | null>; hasEnoughInk: boolean }` — guarda `toData()` e redesenha com `fromData()` em resize/rotação considerando `devicePixelRatio`.
  - `<SignatureModal open onCancel onConfirm={(blob: Blob, previewUrl: string) => void} />`.

- [ ] **Step 1:** instalar `signature_pad`. **Step 2:** implementar o recorte e o hook. **Step 3:** modal conforme brainstorm §5 (tela cheia no celular / dialog centralizado no desktop; linha de base + "Assine acima da linha"; dica "Gire o celular para ter mais espaço"; botões Limpar · Cancelar · Confirmar; Confirmar desabilitado até `hasEnoughInk`; consentimento acima do Confirmar com o texto exato do brainstorm; `touch-action: none`; travar scroll do body; `overscroll-behavior: contain`). **Step 4:** `npm run build` em `apps/web`. **Step 5: checkpoint manual (usuário):** abrir `/dev/signature` num Android (Chrome) e num iPhone (Safari) — assinar, girar, limpar, confirmar. **Parar aqui e aguardar o aval.**
- [ ] **Step 6:** `git commit -m "feat(web): modal de assinatura com signature_pad"`

---

## Fase 4 — Web: integração no formulário

### Task 7: Card de assinatura, prévia, envio multipart e remoção

**Files:**
- Create: `apps/web/src/app/register/[qrToken]/signature-card.tsx` + `signature-card.module.css`, `apps/web/src/app/register/[qrToken]/use-signature-preview.ts`
- Modify: `apps/web/src/app/register/[qrToken]/public-register-flow.tsx` e `public-register.module.css` (**têm alterações do usuário não commitadas** — ler antes, editar sem sobrescrever)

**Interfaces:**
- Consumes: `SignatureModal` (Task 6); endpoints das Tasks 2, 4, 5; `SignaturePreviewResponse`.
- Produces:
  - `useSignaturePreview(qrToken: string, cpf: string, email: string): { state: 'idle' | 'loading' | 'none' | 'found' | 'locked' | 'error'; previewUrl?: string; updatedAt?: string; refetch(): void }` — debounce 600 ms, só dispara com `validateCpf(cpf)` e e-mail válido, descarta respostas atrasadas (compara com os valores atuais).
  - `<SignatureCard>` com estados A/B/C/D do brainstorm §5; resultado entregue ao fluxo como `{ action: SignatureAction; blob?: Blob }`.

- [ ] **Step 1:** hook de prévia (skeleton enquanto `loading`; `error` cai no estado A sem bloquear a inscrição).
- [ ] **Step 2:** card: A (vazio, "✍️ Toque para assinar"), B (prévia + "Assinatura salva em dd/mm/aaaa" + "Usar esta" marcado por padrão / "Assinar novamente" + link discreto **"Remover assinatura salva"** com `useConfirm`, que chama `DELETE .../signature` e volta ao A), C (prévia local por `dataURL`/`URL.createObjectURL`, selo "Nova", Refazer/Remover; Remover volta a B se havia salva, senão A), D (`locked`, texto neutro do brainstorm, nenhuma ação). Etiqueta "Recomendado" com `--orange-soft`. Revogar `objectURL`s ao trocar/desmontar.
- [ ] **Step 3:** trocar o `fetch` JSON por `FormData` **somente quando houver assinatura ou ação** (senão manter JSON); enviar `signatureAction` (`replace` no C; `keep` no B com "Usar esta"; `none` no A/D). Se o e-mail/CPF mudarem depois de assinar (estado C), manter a nova assinatura.
- [ ] **Step 4:** diálogo de lembrete **uma vez** ao enviar em estado A: "Seu certificado sairá sem a sua assinatura. Deseja assinar agora?" com [Assinar agora] / [Enviar sem assinatura]; não aparece em B, C, D.
- [ ] **Step 5:** tela de sucesso com as 3 linhas do brainstorm §5 (usa `signatureSaved`/`signatureIgnored` da resposta; ignorada = "Inscrição feita, mas a assinatura não pôde ser salva.").
- [ ] **Step 6:** `npm run build`. **Step 7: checkpoint manual (usuário):** fluxo A→C→envio; mesmo CPF em outro treinamento → B; e-mail diferente → D; remover no B.
- [ ] **Step 8:** `git add -p` só dos hunks próprios; `git commit -m "feat(web): assinatura do participante no formulário de inscrição"`

---

## Fase 5 — Certificado

### Task 8: Assinatura do aluno no PDF

**Files:**
- Modify: `apps/backend/src/certificates/certificates.service.ts` (`generateOne`), `templates/certificate.html`, `templates/certificate-preview.html`
- Test: `apps/backend/test/certificates.service.spec.ts` (criar se não houver)

**Interfaces:**
- Consumes: `SIGNATURE_BUCKET`, `participant.signaturePath`.
- Produces: `participant.signatureUrl: string | null` no contexto do template; `.sig-img` e `.sig-line` alinhados nas duas colunas.

- [ ] **Step 1: Teste:** `generateOne resolve a signed URL (300s) da assinatura do participante e passa ao renderer`; `segue com null se o getSignedUrl falhar`; `sem signaturePath não chama o storage`.
- [ ] **Step 2–3:** FAIL → implementar (passar `participant: { ...participant, signatureUrl }`, **sem** repassar `signaturePath` ao template); template na coluna do aluno conforme brainstorm §7; alinhar as colunas (`.sig` com `min-height` fixa = altura do `.sig-img` + linha, ou `align-items: flex-end` em `.signatures`); atualizar o `certificate-preview.html`.
- [ ] **Step 4:** testes PASS. **Step 5:** gerar PDFs de teste nas 4 combinações (consultor com/sem × aluno com/sem) usando `test-render.js` como base e **conferir visualmente** (usuário valida os PDFs).
- [ ] **Step 6:** `git commit -m "feat(backend): assinatura do participante no certificado"`

---

## Fase 6 — Admin

### Task 9: `hasSignature` sem vazar o path

**Files:**
- Modify: `apps/backend/src/participants/participants.service.ts` (`findBySession`), `apps/backend/src/training-sessions/training-sessions.service.ts` (include de `participants` ~l.123 e demais listagens que usem `participant: true`), `apps/web/src/features/training-sessions/types.ts`, `participants-tab.tsx`
- Test: `apps/backend/test/participants.service.spec.ts`, `apps/backend/test/training-sessions.service.spec.ts`

**Interfaces:**
- Produces: nas respostas, `participant` **sem** `signaturePath`/`signatureUpdatedAt` e com `hasSignature: boolean`. Helper `toPublicParticipant(p): Omit<Participant,'signaturePath'|'signatureUpdatedAt'> & { hasSignature: boolean }` em `participants/participant-view.util.ts`.

- [ ] **Step 1: Testes:** `findBySession não expõe signaturePath e devolve hasSignature`; idem na busca de sessão; grep por outros `participant: true` / `include: { participant` em `apps/backend/src` (inclusive mobile endpoints e `certificates`/`practical-assessments`) e cobrir os que saem para o cliente.
- [ ] **Step 2–4:** FAIL → implementar o helper e aplicá-lo → PASS. O uso interno do path (certificado, cleanup) continua lendo do banco, não da resposta.
- [ ] **Step 5:** `participants-tab.tsx`: ícone de caneta (lucide `PenLine`), cheio/vazio, com `title`/`aria-label` "Assinatura salva"/"Sem assinatura". Árvore suja: editar sem sobrescrever.
- [ ] **Step 6:** `npm run build`; commit `feat(admin): indicador de assinatura na aba participantes`.

### Task 10: Admin remove a assinatura

**Files:**
- Modify: `apps/backend/src/participants/participants.controller.ts`, `participants.service.ts`, `apps/web/.../participants-tab.tsx`
- Test: `apps/backend/test/participants.service.spec.ts`

**Interfaces:**
- Produces: `DELETE /participants/:participantId/signature` (`@Roles(UserRole.ADMIN)`; `:participantId` é o id do `TrainingParticipant`, como a rota `participants/:participantId` existente) → `{ removed: boolean }`; método `removeSignature(trainingParticipantId: string)`.

- [ ] **Step 1: Testes:** zera o banco e apaga do storage depois; `404` se a inscrição não existe; `{ removed: false }` sem assinatura; falha do storage não desfaz; o controller exige ADMIN (mesmo padrão de teste dos outros endpoints, se houver).
- [ ] **Step 2–4:** FAIL → implementar → PASS.
- [ ] **Step 5:** botão na linha (só quando `hasSignature`), com `useConfirm` ("Remover a assinatura de {nome}? Os próximos certificados sairão sem ela."), `useToast`, refetch.
- [ ] **Step 6:** `npm run build`; commit `feat(admin): remover assinatura do participante`.

---

## Fase 7 — QA ponta a ponta

### Task 11: Roteiro de QA e limpeza

**Files:** remover `apps/web/src/app/dev/signature/page.tsx`; atualizar `IMPLEMENTATION-STATUS.md`.

- [ ] **Step 1:** `npx jest` (backend) e `npm run build` (web) limpos.
- [ ] **Step 2: Roteiro (usuário, em celular real):** (1) QR → inscrição com assinatura → gerar certificado → baixar PDF; (2) mesmo CPF em outro treinamento → prévia → "Usar esta" → certificado; (3) mesmo CPF, e-mail diferente → `locked`, sem prévia; (4) inscrição sem assinatura passando pelo lembrete → certificado só com a linha; (5) "Remover assinatura salva" no formulário → nova inscrição volta a A; (6) admin remove → ícone vazio; (7) excluir o único treinamento do participante → arquivo some do bucket.
- [ ] **Step 3:** remover a rota de dev; commit `chore(web): remover rota de teste da assinatura`.
- [ ] **Step 4:** lembrar o usuário de aplicar a migration em **produção** (o bucket `signatures` já existe) (VPS Hostinger/EasyPanel, branch `feat/frontend-backend-integration`) antes do deploy.
