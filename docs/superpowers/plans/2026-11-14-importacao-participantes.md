# Importar participantes por planilha (Excel/CSV) — Plano de Implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIA: usar superpowers:subagent-driven-development, uma task por vez, commit por task, ledger em `.superpowers/sdd/2026-11-14-importacao-participantes/`. Tasks 4 e 5 em paralelo via superpowers:dispatching-parallel-agents. Os passos usam checkbox (`- [ ]`). **Nenhum subagente em Opus**; não criar `.claude/agents/`; o modelo é escolhido no despacho:
>
> | Task | Fase | Quem faz | Modelo |
> |---|---|---|---|
> | 1 — Dependências e linha de base | setup | Subagente | Haiku |
> | 2 — Contrato em `shared-types` | 0 | Sessão principal | Fable 5.2 |
> | 3 — Parser + testes | A | Subagente implementador | Sonnet |
> | 4 — Preview + commit | B | Subagente implementador | Fable 5.2 |
> | 5 — Modal web | D | Subagente implementador (`uploadPost` pode ir num Haiku) | Sonnet |
> | 6 — Modelo `.xlsx` | C | Subagente implementador | Sonnet |
> | 7 — Revisão final e verificação | fecho | Subagente revisor + Haiku para rodar as suítes | Fable 5.2 / Haiku |
>
> Ordem: 1 → 2 → 3 → (4 ∥ 5) → 6 → 7. Correções de revisão de 1–5 linhas e mensagens de commit: sessão principal.

**Goal:** O ADMIN importa participantes de um `.xlsx`/`.csv` na aba Participantes do treinamento, vendo uma prévia classificada antes de gravar só as linhas válidas.

**Architecture:** Parse no backend em duas chamadas: `preview` (multipart, lê o buffer em memória, não grava) e `import` (JSON com as linhas escolhidas, que o servidor revalida e reclassifica, gravando cada linha em transação própria). Um parser puro (sem Prisma) concentra leitura e normalização; a regra "nome sempre, e-mail/CNH só se preenchidos" sai para uma função única usada pelo cadastro manual, pela inscrição pública e pela importação. Síncrono, sem job, sem migration.

**Tech Stack:** NestJS + Prisma + multer + `exceljs` + `papaparse` (backend, jest); Next.js App Router + CSS Modules (web); `@simtc/shared-types` para o contrato.

**Spec:** `brainstorm-importacao-participantes.md` (raiz do repo). Executores leem a seção indicada em cada task.

## Global Constraints

- **Código escrito uma vez:** sem spike, protótipo, script em `/tmp` ou exemplo avulso para "ver se a lib funciona". Cada trecho nasce no arquivo definitivo. Dúvida de API de lib (ExcelJS `dataValidations`, `cell.text`, papaparse) se resolve lendo os `.d.ts` em `node_modules`. Os testes escritos ficam no repo. Verificar (`type-check`, `jest`, `npm run start:dev`) roda o código real. Erro apontado em revisão é corrigido no próprio código, sem reescrever a feature.
- **Árvore suja:** há mudanças não commitadas de outras features (tipos de veículo em `schema.prisma`/`courses/*`/`shared-types/src/enums.ts`/`course.dto.ts`, `info-tab.*`, mobile). Nunca `git add -A`/`git add .`, nunca `git restore/checkout/stash`. Commitar só os arquivos desta feature: `git add <caminhos>` e `git commit -m "..." -- <caminhos>` (o `-- <caminhos>` protege o commit quando duas tasks rodam em paralelo), conferindo `git diff --cached --stat` antes.
- **Banco de produção:** nunca `prisma migrate reset` nem `db push`. Esta feature não tem migration nem muda `schema.prisma`.
- **Backend sem `esModuleInterop`:** `import * as ExcelJS from 'exceljs'`, `import * as Papa from 'papaparse'`. Import default de lib CJS passa no `tsc` e quebra em runtime — a Task 4 sobe `npm run start:dev` para conferir.
- **Libs:** `exceljs` (.xlsx) e `papaparse` + `@types/papaparse` (.csv) no backend. Não usar o pacote npm `xlsx` (SheetJS 0.18.5 com CVEs). `.xls` recusado.
- **Validação da importação:** Nome e CPF obrigatórios; **Categoria CNH obrigatória e dentro de `CNH_CATEGORIES`** (sem a coluna = erro do arquivo); **e-mail opcional, mas se preenchido tem que ser válido** (mesma regra do `@IsEmail`). Validade CNH ilegível e tipo não reconhecido = só aviso.
- **Não alterar o cadastro manual** ("Adicionar manualmente"): CNH lá continua opcional; `AddParticipantDto` não muda.
- **Só ADMIN** (`@Roles(UserRole.ADMIN)`); recusar sessão `CANCELADO`/`CONCLUIDO`; teto 500 linhas / 2 MB.
- Testes pré-existentes que já falham (bcrypt em `users`/`auth.service.spec.ts`, providers em `participants.service.spec.ts`) não são regressão — a Task 1 registra a linha de base e a Task 7 compara.
- Commits em português, sem acento, `tipo(escopo): descricao`, uma linha, sem rodapé.
- Mensagens de erro/aviso ao usuário em português, com acento.

## Review Focus

1. A refatoração `buildParticipantUpdateData` **não pode mudar** o comportamento do cadastro manual nem do `registerPublic` (nome sempre sobrescreve; e-mail/CNH só se preenchidos) — teste na Task 4, Step 1.
2. O commit **revalida e reclassifica** no servidor; não confia no JSON vindo do preview. Linha com erro não grava nada; uma linha que falha não derruba as outras; `P2002` vira `JA_INSCRITO` — testes na Task 4, Step 3.
3. Preview sem N+1 (uma query de `participant` + uma de `trainingParticipant` para o arquivo todo) — teste na Task 4, Step 3 (`toHaveBeenCalledTimes(1)`).
4. Parser: CPF numérico sem zero à esquerda, e-mail como hiperlink, CSV `;` em latin1, cabeçalho fora da linha 1, CNH `A/B` → `AB` — testes na Task 3.
5. Web: `onRefresh` ao fechar o resultado não pode desmontar a aba (regressão do bug de 07/11). O web não tem runner de testes: conferência manual na Task 5, Step 5, e item obrigatório do revisor na Task 7.

---

## Estrutura de arquivos

| Arquivo | Responsabilidade | Task |
|---|---|---|
| `packages/shared-types/src/dtos/participant-import.dto.ts` (novo) + `index.ts` | Contrato preview/commit | 2 |
| `apps/backend/src/participants/import/participant-import.parser.ts` (novo) | Ler arquivo, achar cabeçalho, normalizar e validar linha (puro) | 3 |
| `apps/backend/src/participants/participant-data.util.ts` (novo) | `buildParticipantUpdateData` | 4 |
| `apps/backend/src/participants/import/participant-import.service.ts` (novo) | `preview` e `commit` | 4 |
| `apps/backend/src/participants/dto/import-participants.dto.ts` (novo) | DTO do commit (class-validator) | 4 |
| `apps/backend/src/participants/participants.controller.ts`, `participants.module.ts`, `participants.service.ts` | 2 rotas POST (Task 4), 1 GET (Task 6), registro do service, uso da função extraída | 4, 6 |
| `apps/backend/src/participants/import/participant-import.template.ts` (novo) | Gerar o modelo `.xlsx` | 6 |
| `apps/web/src/features/training-sessions/import-participants-modal.tsx` + `.module.css` (novos) | Modal de 3 passos | 5 |
| `apps/web/src/lib/client-api.ts`, `participants-tab.tsx` | `uploadPost`; habilitar o botão | 5 |
| `apps/backend/test/participant-import.parser.spec.ts`, `participant-data.util.spec.ts`, `participant-import.service.spec.ts`, `participant-import.template.spec.ts` (novos) | Testes | 3, 4, 6 |

---

### Task 1: Dependências e linha de base (Haiku)

**Files:**
- Modify: `apps/backend/package.json`, `package-lock.json` (raiz; o repo usa npm workspaces)
- Create: `.superpowers/sdd/2026-11-14-importacao-participantes/baseline.md`

- [ ] **Step 1:** Na raiz: `npm install exceljs papaparse -w apps/backend` e `npm install -D @types/papaparse -w apps/backend`. Conferir que `git status --short apps/backend/package.json package-lock.json` mostra só esses dois arquivos como novidade desta task.
- [ ] **Step 2:** Em `apps/backend`: `npx jest 2>&1` e `npm run type-check`; em `apps/web`: `npm run type-check`. Gravar em `baseline.md`, por comando: total de suítes/testes, e a lista **nominal** das suítes e testes que falham (com a primeira linha do erro). Não tentar consertar nada.
- [ ] **Step 3:** `git add apps/backend/package.json package-lock.json` → `git commit -m "chore(backend): exceljs e papaparse para importacao de participantes" -- apps/backend/package.json package-lock.json`. Devolver só o resumo da linha de base.

### Task 2: Contrato compartilhado — Fase 0 (sessão principal)

**Files:**
- Create: `packages/shared-types/src/dtos/participant-import.dto.ts`
- Modify: `packages/shared-types/src/index.ts` (uma linha de export)

**Interfaces — Produces** (este é o código final do arquivo; `ParticipationType` vem de `../enums`):

```ts
export const PARTICIPANT_IMPORT_MAX_ROWS = 500;
export const PARTICIPANT_IMPORT_MAX_BYTES = 2 * 1024 * 1024;

export type ParticipantImportRowStatus =
  | 'NOVO' | 'ATUALIZA_E_INSCREVE' | 'JA_INSCRITO' | 'DUPLICADO_NA_PLANILHA' | 'ERRO';

/** Campos de uma linha já normalizados. `cpf` só com dígitos; `cnhExpiration` em aaaa-mm-dd. */
export interface ParticipantImportRowDto {
  rowNumber: number;            // número da linha no arquivo (1 = primeira linha)
  name: string;
  cpf: string;
  email?: string;
  cnhCategory?: string;
  cnhExpiration?: string;
  participationType?: ParticipationType; // ausente = usa o padrão do modal
}

export interface ParticipantImportChange {
  field: 'name' | 'email' | 'cnhCategory' | 'cnhExpiration';
  from: string | null;
  to: string;
}

export interface ParticipantImportPreviewRow extends ParticipantImportRowDto {
  status: ParticipantImportRowStatus;
  errors: string[];
  warnings: string[];
  changes?: ParticipantImportChange[]; // só em ATUALIZA_E_INSCREVE
}

export interface ParticipantImportTotals {
  total: number; novo: number; atualizaEInscreve: number;
  jaInscrito: number; duplicado: number; erro: number;
}

export interface ParticipantImportPreviewResponse {
  sheetName: string | null;     // null em CSV
  headerRow: number;
  ignoredColumns: string[];
  rows: ParticipantImportPreviewRow[];
  totals: ParticipantImportTotals;
}

export interface ImportParticipantsDto {
  defaultParticipationType: ParticipationType;
  rows: ParticipantImportRowDto[];
}

export interface ParticipantImportSkipped { rowNumber: number; cpf: string; reason: string; }

/** `skipped`: linha recusada pela regra (erro, duplicada, já inscrita). `failed`: erro inesperado ao gravar. */
export interface ParticipantImportResult {
  created: number;
  updatedAndEnrolled: number;
  skipped: ParticipantImportSkipped[];
  failed: ParticipantImportSkipped[];
}
```

Rotas (fixas para as Tasks 4, 5 e 6): `POST /training-sessions/:id/participants/import/preview` (multipart, campo `file`) → `ParticipantImportPreviewResponse`; `POST /training-sessions/:id/participants/import` (JSON `ImportParticipantsDto`) → `ParticipantImportResult`; `GET /participants/import/template` → arquivo `modelo-importacao-participantes.xlsx`.

- [ ] **Step 1:** Criar o arquivo e adicionar `export * from './dtos/participant-import.dto';` ao `index.ts`.
- [ ] **Step 2:** `npm run build -w packages/shared-types` (backend e web consomem o `dist/`) → sem erros.
- [ ] **Step 3:** `git commit -m "feat(shared-types): contrato da importacao de participantes" -- packages/shared-types/src/dtos/participant-import.dto.ts packages/shared-types/src/index.ts` (após `git add` dos dois; **não** incluir `enums.ts`/`course.dto.ts`, que têm mudanças de outra feature).

### Task 3: Parser puro + testes — Fase A (Sonnet)

Ler: brainstorm §3.3 e §4.1–4.3.

**Files:**
- Create: `apps/backend/src/participants/import/participant-import.parser.ts`
- Test: `apps/backend/test/participant-import.parser.spec.ts`

**Interfaces:**
- Consumes: `CNH_CATEGORIES`/`isValidCnhCategory` (`../cnh.constants`), `ValidateCpfPipe` (`../../common/pipes/validate-cpf.pipe`; `transform` devolve só dígitos ou lança), `isEmail` do `class-validator`, `ParticipationType` e `PARTICIPANT_IMPORT_MAX_ROWS` de `@simtc/shared-types`.
- Produces:
  - `interface RawImportRow { rowNumber: number; name?: unknown; cpf?: unknown; email?: unknown; cnhCategory?: unknown; cnhExpiration?: unknown; participationType?: unknown }`
  - `interface ParsedRow extends ParticipantImportRowDto { errors: string[]; warnings: string[] }`
  - `interface ParsedSheet { sheetName: string | null; headerRow: number; ignoredColumns: string[]; rows: ParsedRow[] }`
  - `validateImportRow(raw: RawImportRow): ParsedRow` — normaliza e valida **uma** linha, sem banco. É a mesma função que o commit (Task 4) usa para revalidar o JSON, por isso aceita valores já normalizados (ex.: `participationType: 'SOMENTE_TEORICA'`, data `aaaa-mm-dd`) além dos crus (`Date`, número serial, texto BR).
  - `parseParticipantSheet(buffer: Buffer, filename: string): Promise<ParsedSheet>` — assíncrona porque `workbook.xlsx.load` é assíncrono (o brainstorm escreve o retorno síncrono; é a única diferença). Erros do arquivo inteiro lançam `BadRequestException` com a mensagem ao usuário.

**Regras que a spec fixa (o resto é decisão do implementador):**
- Erros de arquivo (mensagens exatas): `.xls` → `Arquivos .xls não são suportados. Abra no Excel e use "Salvar como" .xlsx`; extensão fora de `.xlsx`/`.csv` → `Envie um arquivo .xlsx ou .csv`; `.xlsx` sem assinatura `PK\x03\x04` ou ilegível → `Não foi possível ler o arquivo .xlsx`; sem Nome e CPF nas 10 primeiras linhas de nenhuma aba → `Não encontramos as colunas Nome e CPF. Baixe o modelo para ver o formato esperado`; com Nome e CPF mas sem CNH → `Coluna Categoria CNH não encontrada`; mais de 500 linhas de dados → `A planilha tem N linhas; o limite é 500 por arquivo`.
- Erros de linha (acumulam todos): `Nome obrigatório`, `CPF obrigatório`, `CPF inválido`, `Categoria CNH obrigatória`, `Categoria CNH inválida (use: A, B, C, D, E, AB, AC, AD, AE)`, `E-mail inválido`. Avisos: `Validade da CNH ilegível`, `Tipo de participação não reconhecido`.
- Aliases de cabeçalho, normalização (minúsculas, sem acento, sem pontuação, espaços colapsados; `Nome*` do modelo tem que casar com `nome`), aliases de tipo de participação e formatos de data: exatamente os do brainstorm §4.1 e §4.3. Se um alias casar com mais de uma coluna, vale a primeira.
- Linha com erro mantém em `name`/`cpf` o que deu para ler (string, possivelmente vazia) para a prévia mostrar. `rowNumber` é a linha real do arquivo.
- Célula: sempre `cell.text` no ExcelJS (hiperlink/rich text), resultado de fórmula, `mailto:` removido, e-mail em minúsculas. CPF número com 9–10 dígitos recebe zeros à esquerda até 11.
- CSV: UTF-8 estrito com BOM removido, senão `latin1`; delimitador detectado pelo papaparse.

- [ ] **Step 1: Testes** (fixtures montadas em memória com ExcelJS → `writeBuffer`, e strings/`Buffer` para CSV). Um `it` por caso:
  - cabeçalho na linha 3 (título e linha vazia antes) → `headerRow: 3`, `rowNumber` da 1ª pessoa `4`
  - aliases com acento (`Nome Completo`, `E-mail`, `Colaborador`, `Vencimento CNH`, `Participação`) reconhecidos; coluna `Setor` aparece em `ignoredColumns`
  - segunda aba tem o cabeçalho, a primeira não → usa a segunda (`sheetName`)
  - CPF como número `1234567890`-like sem o zero (usar um CPF válido que começa com 0) → 11 dígitos, sem erro; CPF com máscara → só dígitos
  - e-mail hiperlink (`{ text, hyperlink: 'mailto:...' }`) e em maiúsculas → texto limpo em minúsculas
  - Validade como `Date`, como serial numérico, `31/12/2027`, `31-12-2027`, `2027-12-31` → `'2027-12-31'`; `05/04/2027` → `'2027-04-05'` (dia/mês); `amanha` → sem data + aviso
  - CSV `;` em latin1 com `João`/`Conceição` → nomes íntegros; CSV `,` em UTF-8 com BOM → primeira coluna reconhecida
  - linhas totalmente vazias no meio e no fim → ignoradas, `rowNumber` das seguintes preservado
  - `.xls` recusado; `.txt` recusado; `.xlsx` cujo conteúdo não é ZIP recusado; sem coluna CPF → erro de arquivo; sem coluna Categoria CNH → erro de arquivo; 501 linhas → erro de arquivo, 500 → ok
  - CNH vazia, `F`, `ABC` → erro; `A/B`, `a b`, ` ab ` → `AB`
  - e-mail vazio → sem erro, `email` undefined; `fulano@` → `E-mail inválido`
  - linha com nome vazio + CPF inválido + CNH vazia → os três erros juntos
  - tipo `teorica`/`Somente Teórica` → `SOMENTE_TEORICA`; `completa`/`Teórica e Prática` → `TEORICA_E_PRATICA`; vazio → undefined sem aviso; `xyz` → undefined + aviso
  - nome `  Maria   da  SILVA ` → `Maria da SILVA`
  - `validateImportRow` com entrada já normalizada (`cnhExpiration: '2027-12-31'`, `participationType: 'SOMENTE_TEORICA'`) devolve os mesmos valores sem aviso
- [ ] **Step 2:** `npx jest test/participant-import.parser.spec.ts` (em `apps/backend`) → FAIL (módulo inexistente).
- [ ] **Step 3:** Implementar o parser.
- [ ] **Step 4:** mesmo comando → PASS; `npm run type-check` → sem erros novos.
- [ ] **Step 5:** `git commit -m "feat(backend): parser de planilha para importacao de participantes" -- apps/backend/src/participants/import/participant-import.parser.ts apps/backend/test/participant-import.parser.spec.ts`

### Task 4: Preview + commit — Fase B (Fable 5.2) — paralela à Task 5

Ler: brainstorm §4.4 e §5.1–5.2.

**Files:**
- Create: `apps/backend/src/participants/participant-data.util.ts`, `apps/backend/src/participants/import/participant-import.service.ts`, `apps/backend/src/participants/dto/import-participants.dto.ts`
- Modify: `apps/backend/src/participants/participants.service.ts` (`findOrUpdateParticipantForSession` ~l.120 e o `tx.participant.update` do `registerPublic` ~l.217), `participants.controller.ts`, `participants.module.ts`
- Test: `apps/backend/test/participant-data.util.spec.ts`, `apps/backend/test/participant-import.service.spec.ts`

**Interfaces:**
- Consumes: `parseParticipantSheet`, `validateImportRow`, `ParsedRow` (Task 3); tipos da Task 2.
- Produces:
  - `buildParticipantUpdateData(dto: { name: string; email?: string; cnhCategory?: string; cnhExpiration?: string }): { name: string; email: string | undefined; cnhCategory: string | undefined; cnhExpiration: Date | undefined }` em `participant-data.util.ts`.
  - `ParticipantImportService.preview(sessionId: string, buffer: Buffer, filename: string): Promise<ParticipantImportPreviewResponse>` e `.commit(sessionId: string, dto: ImportParticipantsDto): Promise<ParticipantImportResult>`; injeta só `PrismaService`.
  - Classes `ImportParticipantsBodyDto` / `ImportParticipantRowBodyDto` (class-validator) implementando o contrato.

- [ ] **Step 1: Teste da regra extraída** (`participant-data.util.spec.ts`): só nome → `{ name, email: undefined, cnhCategory: undefined, cnhExpiration: undefined }`; `email: ''` e `cnhCategory: ''` → `undefined` (não apaga o que está no banco); tudo preenchido → valores e `cnhExpiration` como `Date` de `'2027-12-31'`. Rodar → FAIL.
- [ ] **Step 2:** Implementar `buildParticipantUpdateData` e trocar por ela os dois objetos `data` de update (`findOrUpdateParticipantForSession` e `registerPublic`), **sem tocar** em mais nada desses métodos (ordem das checagens, `create`, assinatura). Rodar o spec → PASS; rodar `npx jest test/participants.service.spec.ts test/participants-lookup.spec.ts` e comparar com `baseline.md`: nenhuma falha nova.
- [ ] **Step 3: Testes do service** (`participant-import.service.spec.ts`, Prisma mockado com `jest.fn`; `$transaction` mockado executando o callback com um `tx`; o parser pode ser exercitado de verdade com um CSV em `Buffer`):
  - preview: sessão inexistente → `NotFoundException`; `CANCELADO` e `CONCLUIDO` → `BadRequestException('Inscrições encerradas para este treinamento')`
  - preview classifica um arquivo com os 5 status de §4.4; `totals` bate; **nenhuma** escrita chamada; `participant.findMany` e `trainingParticipant.findMany` chamados **1 vez cada** para 6 linhas (Review Focus 3)
  - `DUPLICADO_NA_PLANILHA`: vale a primeira ocorrência; a segunda é duplicada mesmo com máscara diferente; linha com `ERRO` não "reserva" o CPF
  - `changes` em `ATUALIZA_E_INSCREVE`: nome diferente → `{ field: 'name', from, to }`; e-mail vazio na planilha → sem change de e-mail; CNH diferente → change; valores iguais → `changes` vazio
  - commit: mesmas recusas de sessão
  - commit revalida (Review Focus 2): linha do JSON com CPF inválido, CNH `F`, CNH ausente ou e-mail `x@` vai para `skipped` com o motivo e **nenhum** `create/update` é chamado para ela
  - commit reclassifica: CPF que o JSON trata como novo mas já está inscrito no banco → `skipped` com `CPF já inscrito neste treinamento`; CPF repetido no JSON → segunda em `skipped` (`CPF repetido na planilha`)
  - `NOVO` → `tx.participant.create` + `tx.trainingParticipant.create` na mesma transação, `created: 1`; `ATUALIZA_E_INSCREVE` → `tx.participant.update` com exatamente o retorno de `buildParticipantUpdateData` (e-mail ausente → `email: undefined`), `updatedAndEnrolled: 1`
  - `participationType` ausente na linha → usa `defaultParticipationType`
  - transação da 2ª linha lança erro genérico → vai para `failed`; 1ª e 3ª gravadas (`created: 2`)
  - `P2002` no `trainingParticipant.create` → `skipped` como já inscrito, não `failed`
- [ ] **Step 4:** Rodar → FAIL. Implementar:
  - `preview`: checa a sessão; parser; classifica com **duas** queries (`participant.findMany({ where: { cpf: { in } } })`, `trainingParticipant.findMany({ where: { trainingSessionId, participantId: { in } } })`). Ordem de precedência por linha: `ERRO` → `DUPLICADO_NA_PLANILHA` → `JA_INSCRITO` → `ATUALIZA_E_INSCREVE` → `NOVO`.
  - `commit`: checa a sessão; `validateImportRow` em cada linha do JSON; a mesma classificação em lote (extrair um método privado usado pelos dois); para cada linha importável, **uma** `$transaction` própria; contadores e listas conforme o contrato. Em `P2002`: reler participante + inscrição pelo CPF; se inscrito → `skipped`; se o conflito foi no `cpf` do `Participant` (cadastro criado por outra inscrição no meio do caminho) → repetir a linha **uma** vez pelo caminho de update; nova falha → `failed`. `reason` de `failed`: `Erro ao gravar a linha`, com o erro real em `console.error`.
  - DTO: `defaultParticipationType` `@IsEnum(ParticipationType)` (o enum local de `add-participant.dto.ts`); `rows` `@IsArray @ArrayMinSize(1) @ArrayMaxSize(500) @ValidateNested({ each: true }) @Type(() => ImportParticipantRowBodyDto)`; na linha, `rowNumber` `@IsInt`, `name`/`cpf` `@IsString`, opcionais `@IsOptional @IsString`. A validação de conteúdo fica **no service** de propósito: linha ruim vira `skipped`, não um 400 que derruba o lote. O `ValidationPipe` global tem `forbidNonWhitelisted`: campos extras (`status`, `errors`…) dão 400.
  - Controller: as duas rotas da Task 2, `@UseGuards(JwtAuthGuard, RolesGuard) @Roles(UserRole.ADMIN)`; preview com `FileInterceptor('file')` + `ParseFilePipe`/`MaxFileSizeValidator({ maxSize: PARTICIPANT_IMPORT_MAX_BYTES })` como em `companies.controller.ts` l.78, `@HttpCode(200)`. Registrar `ParticipantImportService` em `providers` do módulo.
- [ ] **Step 5:** `npx jest test/participant-import.service.spec.ts test/participant-data.util.spec.ts test/participant-import.parser.spec.ts` → PASS; `npm run type-check` → sem erros novos.
- [ ] **Step 6: Runtime.** `npm run start:dev` em `apps/backend`; esperar `Nest application successfully started` **sem** `TypeError ... is not a function/constructor` vindo de `exceljs`/`papaparse`; conferir no log as rotas `.../participants/import/preview` e `.../participants/import` mapeadas; encerrar o processo. (Só leitura do boot: não chamar o endpoint de commit contra o banco.)
- [ ] **Step 7:** `git add` + `git commit -m "feat(backend): previa e gravacao da importacao de participantes" -- <os 8 arquivos desta task>`

### Task 5: Modal no web — Fase D (Sonnet) — paralela à Task 4

Ler: brainstorm §6. Não tocar em nada de `apps/backend`.

**Files:**
- Create: `apps/web/src/features/training-sessions/import-participants-modal.tsx`, `import-participants-modal.module.css`
- Modify: `apps/web/src/lib/client-api.ts` (l.122, ao lado de `upload`), `apps/web/src/features/training-sessions/participants-tab.tsx` (botão l.233; render do modal junto do `BulkJobProgressModal` l.451)

**Interfaces:**
- Consumes: tipos e rotas da Task 2; `clientApi.downloadFile(path, fallbackName)`; `useBulkSelection(selectableIds: string[])` (`@/lib/use-bulk-selection`); padrão visual de `apps/web/src/components/ui/bulk-job-modal/bulk-job-progress-modal.tsx`; máscara de CPF e rótulos de tipo de participação já existentes no web (procurar em `@/lib` antes de criar).
- Produces: `clientApi.uploadPost<T>(path: string, fd: FormData)` (POST multipart via `clientFetch`); `<ImportParticipantsModal sessionId={string} onClose={() => void} onImported={() => void} />`.

- [ ] **Step 1:** `uploadPost` em `client-api.ts`.
- [ ] **Step 2: Modal, passo 1 (arquivo).** Arrastar-e-soltar + "Escolher arquivo" (`accept=".xlsx,.csv"`), link "Baixar modelo" (`downloadFile('/participants/import/template', 'modelo-importacao-participantes.xlsx')`), select "Tipo de participação padrão" (inicial `TEORICA_E_PRATICA`). Escolher o arquivo dispara o preview (`FormData` com campo `file`) com loading; erro do backend aparece no próprio passo, mantendo o usuário nele.
- [ ] **Step 3: Passo 2 (prévia).** Chips de `totals`; filtro por status; "colunas ignoradas" quando houver; tabela com nº da linha, nome, CPF mascarado, e-mail, CNH, tipo (o da linha ou o padrão), badge de status, erros em vermelho, avisos em amarelo, `changes` como "antes → depois". Seleção com `useBulkSelection` usando `String(rowNumber)` como id; selecionáveis = `NOVO` e `ATUALIZA_E_INSCREVE`, todas marcadas ao chegar a prévia; demais linhas com checkbox desabilitado. Botões "Importar N participantes" (desabilitado com N = 0 ou enviando) e "Trocar arquivo". O corpo enviado leva **somente** os campos de `ParticipantImportRowDto` (o backend recusa campos extras com 400) + `defaultParticipationType`.
- [ ] **Step 4: Passo 3 (resultado).** Resumo (`created`, `updatedAndEnrolled`) e lista de `skipped`/`failed` com linha, CPF mascarado e motivo. Fechar chama `onImported()` **uma vez** e depois `onClose()`; fechar nos passos 1–2 só chama `onClose()`.
- [ ] **Step 5: `participants-tab.tsx`.** Botão "Importar planilha" passa a `disabled={!canEdit || busy}` com `onClick` abrindo o modal; render condicional do modal com `onImported={() => onRefresh()}`. **Review Focus 5:** o estado "modal aberto" vive na aba e o `onRefresh` só roda ao fechar o resultado; não adicionar `key`, spinner de tela inteira nem nada que remonte a aba — conferir que o caminho é o mesmo do `onFinished` do `BulkJobProgressModal` (l.455).
- [ ] **Step 6:** em `apps/web`: `npm run type-check` e `npm run build` → sem erros novos frente a `baseline.md`.
- [ ] **Step 7:** `git add` + `git commit -m "feat(web): modal de importacao de participantes por planilha" -- <os 4 arquivos desta task>`

### Task 6: Modelo `.xlsx` para baixar — Fase C (Sonnet) — só depois da Task 4

Ler: brainstorm §5.3.

**Files:**
- Create: `apps/backend/src/participants/import/participant-import.template.ts`
- Modify: `apps/backend/src/participants/participants.controller.ts`
- Test: `apps/backend/test/participant-import.template.spec.ts`

**Interfaces:**
- Consumes: `CNH_CATEGORIES`; `parseParticipantSheet` (Task 3).
- Produces: `buildParticipantImportTemplate(): Promise<Buffer>`; rota `GET participants/import/template` (ADMIN) devolvendo `StreamableFile` com `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` e `Content-Disposition: attachment; filename="modelo-importacao-participantes.xlsx"`.

**Conteúdo fixado:**
- Aba `Participantes`: cabeçalhos `Nome*`, `CPF*`, `E-mail`, `Categoria CNH*`, `Validade CNH`, `Tipo de participação`, em negrito, linha congelada; coluna CPF com `numFmt: '@'`; Validade com `dd/mm/yyyy`; validação de dados tipo lista nas linhas 2–501 para Categoria CNH (de `CNH_CATEGORIES`) e Tipo (`Somente teórica`, `Teórica e prática`). **Sem linha de exemplo nesta aba** — o exemplo vai na aba Instruções, para o parser nunca precisar reconhecer e pular uma linha falsa.
- Aba `Instruções`: campos obrigatórios (Nome, CPF, Categoria CNH), categorias aceitas, e-mail opcional mas válido, data em dd/mm/aaaa, tipos aceitos, limite de 500 linhas e 2 MB, uma linha de exemplo preenchida, e o aviso de que só a aba Participantes é lida.

- [ ] **Step 1: Testes:** o buffer começa com `PK\x03\x04`; reabrindo com ExcelJS há as abas `Participantes` e `Instruções`, a coluna CPF tem `numFmt '@'` e a validação de CNH lista exatamente `CNH_CATEGORIES`; `parseParticipantSheet(modelo, 'modelo.xlsx')` resolve com `sheetName: 'Participantes'`, `headerRow: 1`, `ignoredColumns: []`, `rows: []`; modelo com 3 linhas preenchidas (tipos escritos como na lista suspensa, um CPF começando com 0 como texto) → 3 linhas sem erro nem aviso.
- [ ] **Step 2:** rodar → FAIL. **Step 3:** implementar gerador e rota. **Step 4:** `npx jest test/participant-import.template.spec.ts` → PASS; `npm run type-check`; subir `npm run start:dev` e conferir a rota mapeada e o boot limpo.
- [ ] **Step 5:** `git add` + `git commit -m "feat(backend): modelo xlsx para importacao de participantes" -- <os 3 arquivos desta task>`

### Task 7: Revisão final e verificação

- [ ] **Step 1 (Haiku):** `npx jest` e `npm run type-check` em `apps/backend`; `npm run type-check` e `npm run build` em `apps/web`; devolver só a diferença frente a `baseline.md`.
- [ ] **Step 2 (Fable 5.2, superpowers:requesting-code-review):** revisor recebe o diff `<commit da Task 1>^..HEAD` restrito aos arquivos da feature, o brainstorm e este plano (Global Constraints + Review Focus) — **sem** os relatórios dos implementadores. Itens obrigatórios: os 5 do Review Focus, `git diff --stat` sem arquivo de outra feature, nenhum arquivo descartável criado.
- [ ] **Step 3:** correções no próprio código (1–5 linhas na sessão principal; maiores voltam ao implementador da task), commit `fix(...)` por correção.
- [ ] **Step 4 (superpowers:verification-before-completion):** repetir o Step 1 depois das correções. Atualizar `apps/backend/CLAUDE.md` (linha "❌ Sem importação por planilha Excel" → ✅ com a data e as três rotas) e commitar com `docs(backend): ...`.
- [ ] **Step 5: Entrega ao usuário:** lista de commits, verificação vs linha de base, achados em aberto e o roteiro manual da Fase E — planilha mista (novos + CPF de outro treinamento + já inscrito + duplicado + inválido), CSV exportado pelo Excel no Windows, sessão `CONCLUIDO` recusada, CPF de outro treinamento atualizando nome/CNH sem apagar o e-mail, e o modelo aberto no Excel (listas suspensas e zero à esquerda do CPF).
