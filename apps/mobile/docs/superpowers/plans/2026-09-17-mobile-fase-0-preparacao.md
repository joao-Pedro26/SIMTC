# App Mobile SIMTC — Fase 0: Preparação (backend + ambiente) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deixar tudo pronto para as telas do app: no backend, a assinatura do participante (migration + 2 endpoints) e o `assessmentId` na resposta do sync; no mobile, o scaffold Flutter versionado como base só Android e auditado, e o ambiente de teste validado em aparelho físico (USB e Wi-Fi) com acesso ao backend local.

**Architecture:** A assinatura do participante segue o padrão de `Consultant.signatureUrl`: bucket privado do Supabase (`participant-signatures`), só o *path* do arquivo salvo em `PracticalAssessment.participantSignatureUrl` e leitura por signed URL de 1 h. As rotas ficam no `PracticalAssessmentsController` (JWT na classe + `RolesGuard` ADMIN/CONSULTANT nas rotas novas) e a lógica no `PracticalAssessmentsService`, que passa a receber o `StorageService`. A migration é gerada offline (`prisma migrate diff`) e só é aplicada com `prisma migrate deploy` depois da confirmação do usuário. No mobile esta fase não escreve Dart: versiona o scaffold atual (sem as plataformas que não são Android), documenta o que a Fase 1 descarta e valida `flutter run` + `adb reverse` no aparelho.

**Tech Stack:** NestJS 10.4 · Prisma 7.9 (PostgreSQL no Supabase) · Supabase Storage · Jest 29 / ts-jest · Flutter 3.41.6 / Dart 3.11.4 · Android (adb 37)

**Spec:** `brainstorm-implementacao-mobile.md` → "Fase 0" (raiz do repo). Contexto: `brainstorm-app-mobile.md`, `prompt-claude-design-mobile.md` e `prompt-implementacao-mobile-claude-code.md`. As decisões tomadas com o usuário em 17/09/2026 (seção abaixo) prevalecem sobre o brainstorm quando os dois divergem.

## Decisões tomadas com o usuário (17/09/2026)

1. **Proteção dos endpoints de assinatura:** `RolesGuard` + `@Roles(ADMIN, CONSULTANT)`, com CLIENT bloqueado. Motivo: a premissa do brainstorm ("só quem tem o `assessmentId` local consegue chamar") não se sustenta, porque `GET /reports/training-sessions/:id` entrega o `id` da avaliação aos usuários CLIENT da empresa.
2. **`POST /practical-assessments/sync` passa a devolver `assessmentId`** em cada item com `status: 'fulfilled'`. Hoje a resposta traz só `{ trainingParticipantId, status, error }`, e o app precisa do id para chamar `PATCH /practical-assessments/:id/participant-signature`.
3. **Base do mobile no git em dois commits:** (a) remover o app Flutter antigo (`apps/mobile/lib/**`, `apps/mobile/pubspec.yaml`, `apps/mobile/assets/images/logo-simtc.png`: 58 arquivos do commit `e618daa`), que já está apagado no working tree; (b) versionar `apps/mobile/simtc/` como base **só Android**, apagando `ios/ linux/ macos/ web/ windows/` (dá para recriar com `flutter create --platforms=<p> .`).
4. **Branch:** `feat/mobile-app`, criada a partir de `feat/frontend-backend-integration`.

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app`. Não executar em git worktree: os documentos-fonte (`brainstorm-implementacao-mobile.md`, `prompt-*.md`) não estão versionados e precisam estar visíveis.
- Commits em português, numa linha, no formato `tipo(escopo): mensagem` (tipos: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `perf`), sem ponto final e **sem `Co-Authored-By`** nem rodapé. É o padrão dos commits recentes; a proibição do rodapé vem de `apps/backend/CLAUDE.md` e nunca foi usado no histórico. Um commit por task concluída e verificada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`: o working tree tem arquivos não relacionados (`.vscode/`, brainstorms, `test-*.js`, `apps/web/src/app/(client)/.../certificates/`).
- Não avançar com teste novo falhando, `tsc`/`flutter analyze` com erro ou build quebrado (ver "Baseline" sobre as falhas pré-existentes do backend).
- Diante de ambiguidade de regra de negócio, parar e perguntar ao usuário.
- Artefatos SDD (briefs, reports e ledger) ficam em `.superpowers/sdd/2026-09-17-mobile-fase-0-preparacao/` (pasta ignorada pelo git).

**Backend (NestJS/Prisma)**
- Nunca rodar `prisma migrate dev` (recusa ambiente não interativo e pode propor reset do banco) nem `prisma db push`. O SQL da migration é gerado com `prisma migrate diff` e aplicado com `prisma migrate deploy` **somente após confirmação explícita do usuário** sobre o banco de destino (`DIRECT_URL` de `apps/backend/.env.development`).
- Erros usam exceções do NestJS com mensagens em português. Testes Jest ficam em `apps/backend/test/*.spec.ts`, com Prisma e Storage mockados; `npx tsc --noEmit` precisa passar limpo.
- Buckets privados guardam só o *path* no banco (nunca a URL), e a leitura é por signed URL de 3600 s. Bucket novo: `participant-signatures` (privado).
- `apps/backend/CLAUDE.md` não é versionado, mas é regra obrigatória do próprio arquivo atualizar a seção "Estado Atual" ao concluir itens.
- Nenhum campo ou endpoint além dos confirmados no código. Lacunas viram pendência (ver `apps/mobile/docs/fase-0-auditoria.md`).

**Mobile (Flutter) — vale para todas as fases**
- Flutter 3.41.6 / Dart 3.11.4. App **só Android** (celular e tablet), distribuído por APK sideload. Cada fase é validada manualmente em **aparelho físico** (USB ou depuração Wi-Fi), nunca em emulador.
- MVVM + Repository: um `ChangeNotifier` por tela/fluxo, injetado via `provider`. Tela nunca chama `Dio`/Drift direto. Um Repository por domínio (Auth, Session, Participant, AssessmentCatalog, Assessment, Signature, SessionConsultants), retornando o `Result<T>` de `lib/utils/result.dart` (reaproveitado, não recriado).
- Um único `ConnectivityService`, criado no `MultiProvider` do app (nunca dentro de uma tela), que dispara a sincronização na transição offline→online, esteja o usuário em qualquer tela.
- Composição "quebra-cabeça" obrigatória: cada tela decompõe a UI em métodos privados `Widget _buildX()`, combinados num `build()` enxuto.
- Design System (da Fase 1 em diante, nunca contornado). Cores de marca: primária `#1D9AA4` (hover `#167F8A`, escuro `#0A6E80`, suave `#EEF9FA`); CTA `#F5A520` (hover `#E09510`, suave `#FEF8EE`); mauve `#9B80A8` (suave `#F5F0F8`); charcoal `#1E2A34`/`#2A3A46`; neutros `#F8FAFC`, `#FFFFFF`, `#E2E8F0`, `#0F172A`, `#475569`, `#94A3B8`. Severidade, em paleta separada e igual à do web: B `#DCFCE7`/`#16A34A`, PM `#FEF9C3`/`#CA8A04`, M `#FEE2E2`/`#DC2626`, com os rótulos literais "B", "PM" e "M". Status de participante: PENDENTE cinza, EM_AVALIACAO amarelo, APROVADO verde, NECESSITA_REAVALIACAO vermelho/laranja escuro, nunca o laranja de marca. Status e severidade nunca só por cor (sempre com ícone e/ou texto). Espaçamento em constantes nomeadas, tipografia Inter (`google_fonts`) com `MediaQuery.textScaler`, um único `ThemeData` Material 3, e nenhum `Color(0xFF…)` fora do DS.
- Componentes-base "burros": chip de status, badge de severidade, card de sessão, navbar pill, botões primário e secundário, campo de texto, banner de conectividade e skeleton.
- Fluxo de avaliação (checklist → resumo → assinatura) offline-first, com autosave no Drift. A sincronização é automática, sem botão manual. As ações admin (editar sessão, adicionar participante, gerenciar consultores) exigem conexão: offline, ficam visíveis e desabilitadas, com explicação.
- Scoring portado 1:1 de `packages/shared-types/src/scoring.ts`, com testes Dart contra casos da implementação TS.
- Contratos reais (confirmados no código):
  - Auth: `POST /auth/login` `{ email, password }` → `{ accessToken, refreshToken }`; `GET /auth/me` → `{ id, name, email, role }`, aceitando só `CONSULTANT`/`ADMIN`; `POST /auth/refresh` `{ refreshToken }`; `POST /auth/logout`.
  - Sessões: `GET /training-sessions?page=&limit=` (sem `consultantId`); `GET /training-sessions/:id`; `PATCH /training-sessions/:id`, que também faz o replace total de `additionalConsultantsIds`.
  - Participantes: `GET|POST /training-sessions/:id/participants`; `DELETE /participants/:participantId`.
  - Avaliações: `POST /practical-assessments/assign` `{ participantIds }`; `POST /practical-assessments/sync` (array, sem `consultantId`). O sync zera `assignedConsultantId`, por isso "Reavaliar" chama `assign` antes. Também `GET /practical-assessments/by-participant/:id`, `GET /practical-assessments/:id` e os endpoints de assinatura desta fase.
  - Catálogo: `GET /assessment-categories`, com cache local.
- Arquivos gerados (`*.g.dart`) são versionados junto com a fonte.

## Baseline verificada em 17/09/2026

- **Backend:** `npx tsc --noEmit` passa limpo, e `npx jest test/practical-assessments.service.spec.ts` dá 14 passed. A suíte completa (`npx jest`) já tem **12 falhas pré-existentes**: 1 em `test/auth.service.spec.ts` (espera `sendOtpCode` com 2 argumentos; hoje são 3) e 11 em `test/participants.service.spec.ts` (falta o mock de `EmailService`). Elas estão fora do escopo desta fase. Critério: nenhuma falha nova (a suíte continua com `12 failed`), e as suítes tocadas aqui ficam 100% verdes.
- **Banco do `DIRECT_URL`** (Supabase sa-east-1): `npx prisma migrate status` encontra 13 migrations e responde "Database schema is up to date!".
- **Mobile:** `flutter analyze` → "No issues found!" e `flutter test` → 1 teste passando. `flutter devices` lista só o emulador `emulator-5554`; nenhum aparelho físico estava conectado no momento da verificação.

## Mapa de Arquivos

### Novos

| Arquivo | Responsabilidade |
|---|---|
| `apps/mobile/docs/superpowers/plans/2026-09-17-mobile-fase-0-preparacao.md` | Este plano |
| `apps/mobile/docs/fase-0-auditoria.md` | Auditoria do scaffold + achados de contrato do backend, por fase |
| `apps/mobile/simtc/**` (primeira vez no git) | Scaffold Flutter placeholder, só Android (50 arquivos) |
| `apps/backend/prisma/migrations/20260917120000_add_participant_signature_to_assessment/migration.sql` | `ALTER TABLE` que cria a coluna nova |
| `apps/backend/test/practical-assessments.controller.spec.ts` | Testes das rotas de assinatura (roles, tipo de arquivo, 404) |

### Arquivos modificados

| Arquivo | O que muda |
|---|---|
| `.gitignore` (raiz) | Exceções de `*.png` para `apps/mobile/simtc/`; remove o bloco Flutter do caminho antigo |
| `apps/mobile/simtc/android/.gitignore` | Passa a ignorar `.kotlin/` (cache do Kotlin 2.x) |
| `apps/mobile/simtc/README.md` | Guia para rodar no aparelho físico + `adb reverse` |
| `apps/backend/prisma/schema.prisma` | `PracticalAssessment.participantSignatureUrl String?` |
| `apps/backend/src/practical-assessments/practical-assessments.module.ts` | Importa `StorageModule` |
| `apps/backend/src/practical-assessments/practical-assessments.service.ts` | Injeta `StorageService`; ganha `uploadParticipantSignature` e `getParticipantSignatureSignedUrl`; `assessmentId` no sync |
| `apps/backend/src/practical-assessments/practical-assessments.controller.ts` | `PATCH :id/participant-signature` e `GET :id/participant-signature-url` |
| `apps/backend/test/practical-assessments.service.spec.ts` | Mock de `StorageService` + testes novos |
| `apps/backend/CLAUDE.md` (não versionado) | Seção "Estado Atual" atualizada |

### Arquivos deletados

| Arquivo | Motivo |
|---|---|
| `apps/mobile/lib/**` (56), `apps/mobile/pubspec.yaml`, `apps/mobile/assets/images/logo-simtc.png` | App Flutter antigo, substituído por `apps/mobile/simtc/` (decisão 3) |
| `apps/mobile/simtc/{ios,linux,macos,web,windows}/` (não versionados) | App só Android (decisão 3) |

## Ordem de execução

| Passo | Quem executa | Depende de |
|---|---|---|
| Preparação: branch + commit do plano | controlador | aprovação do plano |
| Task 1 — remover o app antigo | controlador | Preparação |
| Task 2 — scaffold base + auditoria | subagente | Task 1 |
| Task 3 — migration | subagente | Task 1 |
| Task 4 — endpoints de assinatura | subagente | Task 3 |
| Task 5 — `assessmentId` no sync | subagente | Task 4 |
| Task 6 — aplicar migration, bucket e teste ponta a ponta | controlador + usuário | Tasks 3–5 |
| Task 7 — aparelho físico + README | controlador + usuário | Task 2 |
| Revisão final da fase | controlador + revisor | Tasks 1–7 |

Cada task delegada gera `task-N-brief.md` e `task-N-report.md` em `.superpowers/sdd/2026-09-17-mobile-fase-0-preparacao/`, e o ledger fica em `progress.md` na mesma pasta. Ao fim da fase, **parar** e aguardar a validação manual do usuário no aparelho antes de escrever o plano da Fase 1.

### Preparação (controlador, antes da Task 1)

- [ ] **Criar a branch e commitar este plano**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git rev-parse --short HEAD
git switch -c feat/mobile-app
git add apps/mobile/docs/superpowers/plans/2026-09-17-mobile-fase-0-preparacao.md
git commit -m "docs(mobile): plano SDD da Fase 0 (preparação de backend e ambiente)"
```

Expected: o hash-base (anotar no ledger), `Switched to a new branch 'feat/mobile-app'` e um commit com 1 arquivo.

- [ ] **Criar o ledger** `.superpowers/sdd/2026-09-17-mobile-fase-0-preparacao/progress.md`:

```markdown
# SDD ledger — plan: apps/mobile/docs/superpowers/plans/2026-09-17-mobile-fase-0-preparacao.md

Branch: feat/mobile-app (base: <hash anotado acima> em feat/frontend-backend-integration)

## Task Progress

Task 1: pending
Task 2: pending
Task 3: pending
Task 4: pending
Task 5: pending
Task 6: pending (manual, com o usuário)
Task 7: pending (manual, com o usuário)

## Final Review

pending
```

---

## Task 1: Remover o app Flutter antigo de `apps/mobile/`

**Files:**
- Delete: `apps/mobile/lib/**` (56 arquivos), `apps/mobile/pubspec.yaml`, `apps/mobile/assets/images/logo-simtc.png`

**Interfaces:**
- Consumes: branch `feat/mobile-app` (Preparação).
- Produces: `apps/mobile/` sem o app antigo no HEAD; `apps/mobile/simtc/` continua fora do git até a Task 2.

- [ ] **Step 1: Conferir a branch e o índice vazio**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git branch --show-current
git diff --cached --name-only
```

Expected: `feat/mobile-app`, e nenhuma linha no segundo comando.

- [ ] **Step 2: Conferir que só o app antigo está apagado em `apps/mobile/`**

```bash
git status --porcelain -- apps/mobile | cut -c1-2 | sort | uniq -c
```

Expected (o `??` é `apps/mobile/simtc/`):

```
     58  D
      1 ??
```

- [ ] **Step 3: Registrar a remoção no índice**

```bash
git rm -r --quiet apps/mobile/lib apps/mobile/pubspec.yaml apps/mobile/assets/images/logo-simtc.png
git diff --cached --shortstat
git diff --cached --name-only | grep -v -E '^apps/mobile/(lib/|pubspec\.yaml$|assets/images/logo-simtc\.png$)' || echo "ok: só o app antigo"
```

Expected: ` 58 files changed, 1732 deletions(-)` e `ok: só o app antigo`.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(mobile): remove app Flutter antigo de apps/mobile (substituído por apps/mobile/simtc)"
git status --porcelain -- apps/mobile
```

Expected: um commit com 58 arquivos, e o status seguinte mostra só `?? apps/mobile/simtc/`.

---

## Task 2: Scaffold `apps/mobile/simtc` como base só Android + auditoria

**Files:**
- Delete (não versionados): `apps/mobile/simtc/ios/`, `apps/mobile/simtc/linux/`, `apps/mobile/simtc/macos/`, `apps/mobile/simtc/web/`, `apps/mobile/simtc/windows/`
- Modify: `.gitignore` (raiz)
- Modify: `apps/mobile/simtc/android/.gitignore`
- Create: `apps/mobile/docs/fase-0-auditoria.md`
- Add ao git: `apps/mobile/simtc/**` (50 arquivos)

**Interfaces:**
- Consumes: Task 1 (app antigo removido do HEAD).
- Produces: base versionada do scaffold, sobre a qual a Fase 1 reescreve. Produz também `apps/mobile/docs/fase-0-auditoria.md`, com o que a Fase 1 descarta ou reaproveita e as pendências de backend por fase; os planos seguintes leem esse arquivo.

- [ ] **Step 1: Apagar as pastas das plataformas que não são Android**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
rm -rf ios linux macos web windows
ls
```

Expected: `README.md  analysis_options.yaml  android  assets  build  lib  pubspec.lock  pubspec.yaml  simtc.iml  test`. A pasta `build` pode não existir, e se existir é ignorada.

- [ ] **Step 2: `.gitignore` da raiz — remover o bloco Flutter do caminho antigo**

Em `.gitignore` (raiz do repo), substituir:

```
# Flutter
apps/mobile/.dart_tool/
apps/mobile/.flutter-plugins
apps/mobile/.flutter-plugins-dependencies
apps/mobile/build/
apps/mobile/.packages
apps/mobile/pubspec.lock
```

por:

```
# Flutter — as regras do app ficam em apps/mobile/simtc/.gitignore
# (apps/mobile/simtc/pubspec.lock é versionado: builds reproduzíveis do APK)
```

- [ ] **Step 3: `.gitignore` da raiz — apontar a exceção de PNG para o caminho novo**

No mesmo arquivo, substituir:

```
# Exceção: assets reais do app mobile (bundlados pelo Flutter via pubspec.yaml)
!apps/mobile/assets/**
```

por:

```
# Exceção: assets reais do app mobile (bundlados pelo Flutter via pubspec.yaml)
# e ícones do launcher Android (referenciados pelo AndroidManifest.xml)
!apps/mobile/simtc/assets/**
!apps/mobile/simtc/android/app/src/main/res/**
```

- [ ] **Step 4: `apps/mobile/simtc/android/.gitignore` — ignorar o cache do Kotlin**

Substituir:

```
GeneratedPluginRegistrant.java
.cxx/
```

por:

```
GeneratedPluginRegistrant.java
.cxx/
.kotlin/
```

- [ ] **Step 5: Conferir as regras de ignore**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git check-ignore apps/mobile/simtc/assets/images/logo-simtc.png apps/mobile/simtc/android/app/src/main/res/mipmap-hdpi/ic_launcher.png | wc -l
git check-ignore apps/mobile/simtc/android/local.properties apps/mobile/simtc/.idea apps/mobile/simtc/build apps/mobile/simtc/.dart_tool apps/mobile/simtc/android/.kotlin | wc -l
```

Expected: `0` (os PNGs **não** são mais ignorados) e `5` (os arquivos locais continuam ignorados). Se `apps/mobile/simtc/build` ainda não existir, o segundo número será `4`.

- [ ] **Step 6: Criar `apps/mobile/docs/fase-0-auditoria.md`**

Conteúdo completo do arquivo:

````markdown
# Fase 0 — Auditoria do scaffold e dos contratos do backend

**Data:** 17/09/2026 · **Plano:** `apps/mobile/docs/superpowers/plans/2026-09-17-mobile-fase-0-preparacao.md`

Leitura obrigatória antes de planejar as Fases 1 a 8. Tudo aqui foi conferido no código, não em documentação.

## 1. Scaffold `apps/mobile/simtc`

Estado registrado na Fase 0: Flutter 3.41.6 / Dart 3.11.4, `flutter analyze` sem issues e `flutter test` com 1 smoke test. O app abre um login **mock** e telas genéricas de "dashboard" e "avaliação"; nada disso reflete o domínio real.

### 1.1 O que a Fase 1 descarta ou reescreve

| Arquivo | Problema encontrado | Destino |
|---|---|---|
| `lib/utils/app_colors.dart` | Paleta errada (`#00569E`, `#00A859`…) | Substituído pelos tokens do Design System |
| `lib/utils/api_constants.dart` | `baseUrl` é `https://api.simtc.com.br/v1`, mas a API real usa o prefixo `/api`; os endpoints `/evaluations` e `/evaluations/sync` não existem | Reescrito com os endpoints reais e `baseUrl` por ambiente |
| `lib/data/services/api/api_service.dart` | Só tem GET e POST; guarda o token num header mutável; não faz refresh em `401` | Reescrito como cliente `dio` com interceptors (auth + refresh) |
| `lib/data/repositories/auth_repository.dart` | Tem fallback mock: qualquer e-mail com senha de 4+ caracteres "loga". `isLoggedIn()` inventa um usuário se houver qualquer token salvo, e o login espera um campo `token` que a API não devolve | Reescrito sem mock |
| `lib/data/models/user_model.dart` | Espera `{ id, name, email, token }`, mas o login real devolve `{ accessToken, refreshToken }` e `/auth/me` devolve `{ id, name, email, role }` | Reescrito |
| `lib/data/repositories/evaluation_repository.dart` | Lista mock em memória; `saveEvaluation` devolve sucesso mesmo quando a API falha | Removido |
| `lib/data/models/evaluation_model.dart` | Domínio genérico (título e nota de 0 a 10) que não existe no backend | Removido |
| `lib/data/services/local/app_database.dart` (+ `.g.dart`) | Só a tabela placeholder `EvaluationTable`, com `schemaVersion` 1 e banco `simtc_app_db` | Esquema reescrito (ver 1.3) |
| `lib/ui/auth/login_screen.dart`, `login_viewmodel.dart` | Login mock, mensagem de erro genérica, e o ViewModel aplica `trim()` na **senha** | Reescritos com o DS, sem `trim()` na senha |
| `lib/ui/dashboard/*` | Lista de avaliações mock | Removidos (substituídos por "Minhas Sessões" na Fase 2) |
| `lib/ui/evaluation/*` | Formulário genérico com slider de 0 a 10 | Removidos (o checklist real entra na Fase 4) |
| `lib/ui/core/widgets/custom_button.dart`, `custom_text_field.dart` | Estilos próprios sobre a paleta errada | Substituídos pelos componentes do DS |
| `lib/router.dart` | Rotas `/login`, `/dashboard` e `/evaluation`, sem redirecionamento por autenticação | Reescrito |
| `lib/app.dart` | Providers dos placeholders e `ColorScheme.fromSeed` com a paleta errada | Reescrito (`MultiProvider` com serviços globais + tema do DS) |
| `test/widget_test.dart` | Smoke test do app placeholder | Reescrito |

### 1.2 O que se reaproveita

| Item | Observação |
|---|---|
| `pubspec.yaml` | As dependências estão certas: `provider` 6.1.5, `go_router` 14.8.1, `dio` 5.11.1, `drift`/`drift_dev` 2.31.0, `drift_flutter` 0.2.8, `flutter_secure_storage` 9.2.4, `google_fonts` 6.3.3, `flutter_svg` 2.3.0, `cached_network_image` 3.4.1, `connectivity_plus` 6.1.5, `uuid` 4.6.0, `intl` 0.19.0, `json_annotation`/`json_serializable` e `build_runner` (versões resolvidas no `pubspec.lock`) |
| `lib/utils/result.dart` | `Result<T>` selado (`Success`/`Failure`), usado por todos os repositories novos |
| `lib/main.dart` | Hoje só chama `runApp`; será estendido para inicializar o banco e os serviços |
| Estrutura `lib/data/{models,repositories,services}` + `lib/ui/<feature>/` + `lib/ui/core/` | Mantida (é o padrão da arquitetura recomendada pelo Flutter); o DS entra em `lib/ui/core/` |
| `assets/images/logo-simtc.png` | Logo real (37 KB) |
| `android/` | Template do Flutter 3.41 (AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14) |

Pacotes a decidir em cada fase:
- mocks para os testes (Fase 1);
- captura de assinatura, por pacote ou `CustomPainter` (Fase 5);
- `flutter_adaptive_scaffold`: conferir se continua mantido antes de adotar (Fase 7);
- versão do app na tela de Perfil (Fase 8).

O `pdfx` está no `pubspec.yaml`, mas nenhuma tela prevista o usa; avaliar a remoção na Fase 1.

### 1.3 Ajustes de plataforma e ambiente

- **Plataformas:** `ios/`, `linux/`, `macos/`, `web/` e `windows/` foram removidas na Fase 0 (o app é só Android). Para recriar alguma: `flutter create --platforms=<plataforma> .`
- **Permissão `INTERNET` no manifest principal:** `android/app/src/main/AndroidManifest.xml` não declara `android.permission.INTERNET`; só o manifest de debug declara. Um APK release não acessaria a API. Corrigir na Fase 1.
- **Identidade do app:** `applicationId`/`namespace` são `com.example.simtc` e `android:label` é `"simtc"`. Definir o id definitivo antes de distribuir o primeiro APK, porque trocar depois instala um segundo app no aparelho.
- **Assinatura do release:** `build.gradle.kts` assina o release com a chave de debug. Criar uma keystore própria antes da distribuição (Fase 8).
- **Fonte offline:** o `google_fonts` baixa a Inter em tempo de execução. Para o app abrir com a fonte certa sem internet, embutir os arquivos da Inter como asset e desligar o download (`GoogleFonts.config.allowRuntimeFetching = false`). Fase 1.
- **Banco local antigo nos aparelhos de teste:** o placeholder cria o banco `simtc_app_db` com `schemaVersion` 1. Se a Fase 1 mantiver o mesmo nome e a mesma versão, o Drift abre o arquivo antigo e não cria as tabelas novas. Desinstalar o app placeholder dos aparelhos antes de testar a Fase 1, ou usar outro nome de banco.
- **HTTP em desenvolvimento:** o app de dev fala com o backend local em `http://localhost:3001/api` via `adb reverse` (ver `apps/mobile/simtc/README.md`). Se o Android recusar a chamada HTTP por política de cleartext, liberar cleartext **só** em `android/app/src/debug/AndroidManifest.xml` (Fase 1).
- **URL de produção da API:** não está no repositório (o CI da `main` faz deploy no Railway, e os commits recentes citam uma VPS com Docker). Confirmar com o usuário a URL HTTPS de produção na Fase 1.

## 2. Contratos do backend — achados

### 2.1 Resolvidos na Fase 0

- `PracticalAssessment.participantSignatureUrl`, com o path do arquivo no bucket privado `participant-signatures`.
- `PATCH /api/practical-assessments/:id/participant-signature` (multipart, campo `file`, PNG/JPEG com menos de 2 MB) e `GET /api/practical-assessments/:id/participant-signature-url` → `{ signedUrl }`, válida por 1 h. Só ADMIN e CONSULTANT têm acesso.
- `POST /api/practical-assessments/sync` passa a devolver `assessmentId` em cada item com `status: 'fulfilled'`.

### 2.2 Pendências por fase (não resolvidas na Fase 0)

| Fase | Achado no código | Impacto no app |
|---|---|---|
| 1 | Login de consultor inativo devolve o mesmo `401 "Credenciais inválidas"` da senha errada (`auth.service.ts`) | A mensagem específica de "consultor inativo" prevista na tela 1.2 depende de mudança no backend. Decidir na Fase 1 |
| 1 | `GET /auth/me` devolve só `{ id, name, email, role }`, sem `consultantId` | O app lê o `consultantId` do payload do access token (o campo está no JWT) para saber quem é "eu" nas atribuições |
| 1 | `POST /auth/refresh` (body `{ refreshToken }`) devolve um par novo `{ accessToken, refreshToken }` | O interceptor precisa salvar os dois tokens |
| 2 | `GET /training-sessions` inclui só `company { id, name }`, `course { id, name }` e `responsibleConsultant { id, name }`, sem `company.logoUrl` nem contagem de participantes por status, e ordena por `createdAt desc` | Só com a listagem não dá para montar o card da Home (logo + "X de Y avaliados"). Opções: ampliar o `include`/`_count` no backend ou buscar o detalhe de cada sessão. Decidir na Fase 2 |
| 2 | Para `role = ADMIN`, `GET /training-sessions` devolve **todas** as sessões | "Minhas Sessões" de um admin listaria tudo. Decidir o comportamento na Fase 2 |
| 2 | `Company.logoUrl` guarda uma URL pública (o bucket `logos` é público) | O `cached_network_image` carrega direto, sem token |
| 3 | `GET /training-sessions/:id` traz `participants[]` com `participant`, `assessment`, `certificate` e `assignedConsultant { id, name }`, e bloqueia consultor não vinculado. Já `GET /training-sessions/:id/participants` traz só `participant` + `assessment` e não confere o vínculo | Usar o detalhe da sessão na tela 1.4 |
| 3 | O web trata `EM_AVALIACAO` com avaliação anterior como "reavaliação em andamento" (`getDisplayStatus`, commit `bd4d1a5`) | Espelhar no app para não esconder o fluxo |
| 3 | `POST /practical-assessments/assign` responde `409` com "Participantes aprovados não podem ser reavaliados" ou "Um ou mais participantes já estão em avaliação com outro consultor" | Mostrar a mensagem sem quebrar a lista |
| 3 | O seed (`prisma/seed.ts`) já cria infrações e notas por categoria (`INFRACTIONS_BY_CATEGORY`); a observação contrária no `apps/backend/CLAUDE.md` estava desatualizada | O catálogo está disponível para testar as Fases 3 e 4 |
| 4 | O score usa o `deduction` de cada `InfractionNote` vindo do banco, normalizado por `MAX_NOTE_WEIGHT = 5`, e a média geral considera **todas** as categorias do catálogo (categoria sem infração marcada = 100%); ver `applyScore()` | O port Dart recebe o `deduction` e o total de infrações por categoria a partir do cache local |
| 5 | O `sync` **não valida** o `assignedConsultantId` (bug já listado no `apps/backend/CLAUDE.md`) e sempre zera esse campo depois do sucesso | "Reavaliar" continua chamando `assign` antes, para reservar o participante, mas o `sync` não falha por conflito de atribuição. Reenviar o mesmo item atualiza o mesmo registro |
| 5 | O `sync` responde `201` mesmo com itens rejeitados; cada item traz `status` (`fulfilled`/`rejected`) e `error` | A fila do app trata o resultado item a item, não pelo status HTTP |
| 5 | `GET /practical-assessments/:id` usa `findUniqueOrThrow`, então um id inexistente vira `500` | Tratar como erro genérico |
| 5 | O upload valida `file.mimetype`, e o `dio` manda `application/octet-stream` por padrão | Enviar o `MultipartFile` com `contentType` `image/png` |
| 6 | Não existe busca de participante por CPF. `POST /training-sessions/:id/participants` deduplica por CPF e **sobrescreve** o `name` do cadastro existente (e também `email`/`cnh*`, quando enviados) | A tela 1.4.2 ("buscar por CPF → confirmar dados") não sai só com os endpoints atuais. Decidir na Fase 6 |
| 6 | `PATCH /training-sessions/:id` e `POST /training-sessions/:id/participants` recusam sessões `CONCLUIDO`/`CANCELADO` | Desabilitar as ações admin nesses status |
| 6 | Quando recebe `additionalConsultantsIds`, o `updateSession` recria os vínculos e sempre inclui de novo o consultor responsável | A tela 1.4.3 não precisa enviar o responsável na lista |
| 6 | `GET /consultants?active=true` (ADMIN e CONSULTANT) lista os consultores ativos | É a fonte da busca "Adicionar consultor" |

### 2.3 Testes do backend

Em 17/09/2026, `npx jest` em `apps/backend` já tinha 12 falhas pré-existentes: `test/auth.service.spec.ts` espera `sendOtpCode` com 2 argumentos, e `test/participants.service.spec.ts` não tem o mock de `EmailService`. Qualquer fase que mexa no backend deve manter esse número, sem criar falhas novas.
````

- [ ] **Step 7: Verificar o scaffold (análise, teste e build Android)**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Expected: `No issues found!`, `All tests passed!` e `✓ Built build\app\outputs\flutter-apk\app-debug.apk` (o primeiro build pode levar alguns minutos).

- [ ] **Step 8: Adicionar ao índice e conferir o conjunto**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add .gitignore apps/mobile/simtc apps/mobile/docs/fase-0-auditoria.md
git diff --cached --name-only | wc -l
git diff --cached --name-only | grep -E '(\.iml$|/\.idea/|local\.properties|/build/|\.dart_tool|/\.kotlin/|/\.gradle/|gradlew|gradle-wrapper\.jar|GeneratedPluginRegistrant|simtc/(ios|linux|macos|web|windows)/)' || echo "ok: nada indevido"
git diff --cached --name-only | grep -c '\.png$'
```

Expected: `52` (50 do scaffold + auditoria + `.gitignore`), `ok: nada indevido` e `6` (logo + 5 ícones do launcher). Avisos do git sobre LF/CRLF são esperados. Se a contagem não bater, listar com `git diff --cached --name-only`, tirar do índice o que não for do scaffold (`git restore --staged <arquivo>`) e ajustar o `.gitignore` antes de seguir.

- [ ] **Step 9: Commit**

```bash
git commit -m "chore(mobile): versiona scaffold Flutter apps/mobile/simtc (só Android) e auditoria da Fase 0"
```

---

## Task 3: Backend — coluna `participantSignatureUrl` + migration

**Files:**
- Modify: `apps/backend/prisma/schema.prisma` (model `PracticalAssessment`)
- Create: `apps/backend/prisma/migrations/20260917120000_add_participant_signature_to_assessment/migration.sql`

**Interfaces:**
- Produces: `participantSignatureUrl: string | null` em `PracticalAssessment` no Prisma Client (usado na Task 4). Guarda o *path* `{assessmentId}/{timestamp}.{png|jpg}` do bucket `participant-signatures`, nunca a URL.
- Produces: migration `20260917120000_add_participant_signature_to_assessment`, aplicada só na Task 6.

- [ ] **Step 1: Guardar o schema atual para gerar o diff**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/backend"
git show HEAD:apps/backend/prisma/schema.prisma > schema.before.tmp.prisma
```

- [ ] **Step 2: Adicionar o campo no schema**

Em `apps/backend/prisma/schema.prisma`, substituir:

```prisma
  reportGeneratedAt     DateTime?
  createdAt             DateTime  @default(now())
```

por:

```prisma
  reportGeneratedAt     DateTime?
  // Path (não a URL) da assinatura do participante no bucket privado
  // `participant-signatures` — mesmo padrão de Consultant.signatureUrl.
  participantSignatureUrl String?
  createdAt             DateTime  @default(now())
```

Não rodar `prisma format`: ele realinharia outros models e poluiria o diff.

- [ ] **Step 3: Validar o schema**

```bash
npx prisma validate
```

Expected: `The schema at prisma\schema.prisma is valid 🚀`

- [ ] **Step 4: Gerar a migration offline (sem tocar no banco)**

```bash
npx prisma migrate diff \
  --from-schema schema.before.tmp.prisma \
  --to-schema prisma/schema.prisma \
  --script \
  --output prisma/migrations/20260917120000_add_participant_signature_to_assessment/migration.sql
rm schema.before.tmp.prisma
cat prisma/migrations/20260917120000_add_participant_signature_to_assessment/migration.sql
git diff --stat -- prisma/schema.prisma
```

Expected: o arquivo tem exatamente

```sql
-- AlterTable
ALTER TABLE "PracticalAssessment" ADD COLUMN     "participantSignatureUrl" TEXT;
```

e o `git diff --stat` mostra `1 file changed, 3 insertions(+)`. Não usar `prisma migrate dev` (ver Global Constraints).

- [ ] **Step 5: Regenerar o Prisma Client e conferir tipos e testes**

Se `npm run start:dev` estiver rodando, pare antes: no Windows, o `generate` pode falhar com `EPERM`.

```bash
npx prisma generate
npx tsc --noEmit
npx jest test/practical-assessments.service.spec.ts
```

Expected: mensagem `Generated Prisma Client`, `tsc` sem saída e `Tests: 14 passed, 14 total`.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/backend/prisma/schema.prisma apps/backend/prisma/migrations/20260917120000_add_participant_signature_to_assessment/migration.sql
git commit -m "feat(prisma): adiciona participantSignatureUrl em PracticalAssessment"
```

A migration **não** é aplicada nesta task; isso fica para a Task 6.

---

## Task 4: Backend — endpoints de assinatura do participante (TDD)

**Files:**
- Modify: `apps/backend/src/practical-assessments/practical-assessments.module.ts`
- Modify: `apps/backend/src/practical-assessments/practical-assessments.service.ts`
- Modify: `apps/backend/src/practical-assessments/practical-assessments.controller.ts`
- Modify: `apps/backend/test/practical-assessments.service.spec.ts`
- Create: `apps/backend/test/practical-assessments.controller.spec.ts`

**Interfaces:**
- Consumes: `PracticalAssessment.participantSignatureUrl` (Task 3).
- Consumes: métodos existentes de `src/storage/storage.service.ts`: `StorageService.upload(bucket, path, buffer, contentType): Promise<string>`, `StorageService.delete(bucket, path): Promise<void>` e `StorageService.getSignedUrl(bucket, path, expiresIn): Promise<string>`.
- Produces (service):
  - `uploadParticipantSignature(id: string, buffer: Buffer, contentType: string): Promise<{ signedUrl: string }>`
  - `getParticipantSignatureSignedUrl(id: string): Promise<{ signedUrl: string } | null>`
  - Os dois lançam `NotFoundException('Avaliação não encontrada')` quando o id não existe.
- Produces (HTTP; o app consome na Fase 5):
  - `PATCH /api/practical-assessments/:id/participant-signature` — `multipart/form-data`, campo `file` (PNG ou JPEG, < 2 MB), para ADMIN ou CONSULTANT → `200 { "signedUrl": string }`.
    - `400`: `File is required`, `Validation failed (expected size is less than 2097152)` ou `Tipo de arquivo inválido. Aceito: PNG, JPEG.`
    - `401`: sem token.
    - `403`: `Forbidden resource` (ex.: CLIENT).
    - `404`: `Avaliação não encontrada`.
  - `GET /api/practical-assessments/:id/participant-signature-url` — para ADMIN ou CONSULTANT → `200 { "signedUrl": string }`, válida por 1 h.
    - `401`: sem token.
    - `403`: CLIENT.
    - `404`: `Avaliação não encontrada` ou `Sem assinatura do participante cadastrada`.
  - O app deve mandar a parte `file` com `Content-Type: image/png`; sem isso, o `dio` usa `application/octet-stream`.

- [ ] **Step 1: Spec do service — importar e mockar o `StorageService`**

Em `apps/backend/test/practical-assessments.service.spec.ts`:

1a. Substituir:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException } from '@nestjs/common';
import { PracticalAssessmentsService } from 'src/practical-assessments/practical-assessments.service';
import { PrismaService } from 'src/prisma/prisma.service';
```

por:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { PracticalAssessmentsService } from 'src/practical-assessments/practical-assessments.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { StorageService } from 'src/storage/storage.service';
```

1b. Substituir:

```typescript
  $transaction: jest.fn(),
};
```

por:

```typescript
  $transaction: jest.fn(),
};

const mockStorage = {
  upload: jest.fn(),
  delete: jest.fn(),
  getSignedUrl: jest.fn(),
};
```

1c. Substituir:

```typescript
        { provide: PrismaService, useValue: mockPrisma },
      ],
```

por:

```typescript
        { provide: PrismaService, useValue: mockPrisma },
        { provide: StorageService, useValue: mockStorage },
      ],
```

- [ ] **Step 2: Spec do service — testes novos**

No mesmo arquivo, inserir o bloco abaixo **antes do `});` final** (última linha do arquivo, que fecha `describe('PracticalAssessmentsService')`):

```typescript

  // ─── Assinatura do participante ──────────────────────────────────────────

  describe('uploadParticipantSignature', () => {
    const png = Buffer.from('fake-png');
    let nowSpy: jest.SpyInstance;

    beforeEach(() => {
      nowSpy = jest.spyOn(Date, 'now').mockReturnValue(1_700_000_000_000);
      mockStorage.upload.mockResolvedValue('https://ignorada.example/publica.png');
      mockStorage.delete.mockResolvedValue(undefined);
      mockStorage.getSignedUrl.mockResolvedValue('https://signed.example/assinatura.png');
      mockPrisma.practicalAssessment.update.mockResolvedValue({});
    });

    afterEach(() => nowSpy.mockRestore());

    it('lança NotFoundException se a avaliação não existe', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);

      await expect(
        service.uploadParticipantSignature('assess-x', png, 'image/png'),
      ).rejects.toThrow(NotFoundException);
      expect(mockStorage.upload).not.toHaveBeenCalled();
    });

    it('sobe no bucket participant-signatures, salva só o path e devolve signed URL', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ participantSignatureUrl: null });

      const result = await service.uploadParticipantSignature('assess-1', png, 'image/png');

      expect(mockStorage.delete).not.toHaveBeenCalled();
      expect(mockStorage.upload).toHaveBeenCalledWith(
        'participant-signatures',
        'assess-1/1700000000000.png',
        png,
        'image/png',
      );
      expect(mockPrisma.practicalAssessment.update).toHaveBeenCalledWith({
        where: { id: 'assess-1' },
        data: { participantSignatureUrl: 'assess-1/1700000000000.png' },
      });
      expect(mockStorage.getSignedUrl).toHaveBeenCalledWith(
        'participant-signatures',
        'assess-1/1700000000000.png',
        3600,
      );
      expect(result).toEqual({ signedUrl: 'https://signed.example/assinatura.png' });
    });

    it('apaga o arquivo anterior antes de subir o novo', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({
        participantSignatureUrl: 'assess-1/1600000000000.png',
      });

      await service.uploadParticipantSignature('assess-1', png, 'image/png');

      expect(mockStorage.delete).toHaveBeenCalledWith(
        'participant-signatures',
        'assess-1/1600000000000.png',
      );
      expect(mockStorage.delete.mock.invocationCallOrder[0]).toBeLessThan(
        mockStorage.upload.mock.invocationCallOrder[0],
      );
    });

    it('segue com o upload mesmo se apagar o arquivo anterior falhar', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({
        participantSignatureUrl: 'assess-1/1600000000000.png',
      });
      mockStorage.delete.mockRejectedValueOnce(new Error('Object not found'));

      await expect(
        service.uploadParticipantSignature('assess-1', png, 'image/png'),
      ).resolves.toEqual({ signedUrl: 'https://signed.example/assinatura.png' });
      expect(mockStorage.upload).toHaveBeenCalled();
    });

    it('usa extensão .jpg para image/jpeg', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ participantSignatureUrl: null });

      await service.uploadParticipantSignature('assess-1', png, 'image/jpeg');

      expect(mockStorage.upload).toHaveBeenCalledWith(
        'participant-signatures',
        'assess-1/1700000000000.jpg',
        png,
        'image/jpeg',
      );
    });
  });

  describe('getParticipantSignatureSignedUrl', () => {
    it('lança NotFoundException se a avaliação não existe', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);

      await expect(service.getParticipantSignatureSignedUrl('assess-x')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('retorna null se a avaliação não tem assinatura', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ participantSignatureUrl: null });

      await expect(service.getParticipantSignatureSignedUrl('assess-1')).resolves.toBeNull();
      expect(mockStorage.getSignedUrl).not.toHaveBeenCalled();
    });

    it('gera signed URL de 1h a partir do path salvo', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({
        participantSignatureUrl: 'assess-1/1700000000000.png',
      });
      mockStorage.getSignedUrl.mockResolvedValue('https://signed.example/assinatura.png');

      await expect(service.getParticipantSignatureSignedUrl('assess-1')).resolves.toEqual({
        signedUrl: 'https://signed.example/assinatura.png',
      });
      expect(mockStorage.getSignedUrl).toHaveBeenCalledWith(
        'participant-signatures',
        'assess-1/1700000000000.png',
        3600,
      );
    });
  });
```

- [ ] **Step 3: Criar `apps/backend/test/practical-assessments.controller.spec.ts`**

```typescript
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { Reflector } from '@nestjs/core';
import { PracticalAssessmentsController } from 'src/practical-assessments/practical-assessments.controller';
import { PracticalAssessmentsService } from 'src/practical-assessments/practical-assessments.service';
import { RolesGuard } from 'src/auth/guards/roles.guard';
import { ROLES_KEY } from 'src/auth/decorators/roles.decorator';

const mockService = {
  uploadParticipantSignature: jest.fn(),
  getParticipantSignatureSignedUrl: jest.fn(),
};

function fakeFile(mimetype: string): Express.Multer.File {
  return { mimetype, buffer: Buffer.from('x'), size: 1 } as Express.Multer.File;
}

describe('PracticalAssessmentsController — assinatura do participante', () => {
  const controller = new PracticalAssessmentsController(
    mockService as unknown as PracticalAssessmentsService,
  );
  const reflector = new Reflector();

  beforeEach(() => jest.clearAllMocks());

  it('upload exige RolesGuard com ADMIN ou CONSULTANT (CLIENT bloqueado)', () => {
    const handler = PracticalAssessmentsController.prototype.uploadParticipantSignature;
    expect(reflector.get(GUARDS_METADATA, handler)).toContain(RolesGuard);
    expect(reflector.get(ROLES_KEY, handler)).toEqual(['ADMIN', 'CONSULTANT']);
  });

  it('leitura da signed URL exige RolesGuard com ADMIN ou CONSULTANT (CLIENT bloqueado)', () => {
    const handler = PracticalAssessmentsController.prototype.getParticipantSignatureUrl;
    expect(reflector.get(GUARDS_METADATA, handler)).toContain(RolesGuard);
    expect(reflector.get(ROLES_KEY, handler)).toEqual(['ADMIN', 'CONSULTANT']);
  });

  it('recusa arquivo que não é PNG/JPEG', () => {
    expect(() =>
      controller.uploadParticipantSignature('assess-1', fakeFile('application/pdf')),
    ).toThrow(BadRequestException);
    expect(mockService.uploadParticipantSignature).not.toHaveBeenCalled();
  });

  it('repassa o PNG para o service', async () => {
    mockService.uploadParticipantSignature.mockResolvedValue({ signedUrl: 'https://s' });
    const file = fakeFile('image/png');

    await expect(controller.uploadParticipantSignature('assess-1', file)).resolves.toEqual({
      signedUrl: 'https://s',
    });
    expect(mockService.uploadParticipantSignature).toHaveBeenCalledWith(
      'assess-1',
      file.buffer,
      'image/png',
    );
  });

  it('responde 404 quando não há assinatura', async () => {
    mockService.getParticipantSignatureSignedUrl.mockResolvedValue(null);

    await expect(controller.getParticipantSignatureUrl('assess-1')).rejects.toThrow(
      NotFoundException,
    );
  });

  it('devolve a signed URL quando há assinatura', async () => {
    mockService.getParticipantSignatureSignedUrl.mockResolvedValue({ signedUrl: 'https://s' });

    await expect(controller.getParticipantSignatureUrl('assess-1')).resolves.toEqual({
      signedUrl: 'https://s',
    });
  });
});
```

- [ ] **Step 4: Rodar os testes e ver falhar**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/backend"
npx jest test/practical-assessments.service.spec.ts test/practical-assessments.controller.spec.ts
```

Expected: FAIL nas 2 suítes, com erros de TypeScript do ts-jest como `Property 'uploadParticipantSignature' does not exist on type 'PracticalAssessmentsService'` e `Property 'getParticipantSignatureUrl' does not exist on type 'PracticalAssessmentsController'`.

- [ ] **Step 5: Module — importar o `StorageModule`**

Substituir todo o conteúdo de `apps/backend/src/practical-assessments/practical-assessments.module.ts`:

```typescript
import { Module } from '@nestjs/common';
import { PracticalAssessmentsController } from './practical-assessments.controller';
import { PracticalAssessmentsService } from './practical-assessments.service';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [StorageModule],
  controllers: [PracticalAssessmentsController],
  providers: [PracticalAssessmentsService],
  exports: [PracticalAssessmentsService],
})
export class PracticalAssessmentsModule {}
```

- [ ] **Step 6: Service — imports, bucket e construtor**

Em `apps/backend/src/practical-assessments/practical-assessments.service.ts`, substituir:

```typescript
import { Injectable, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SyncPracticalAssessmentDto } from '@simtc/shared-types';
import { AssignParticipantsDto } from './dto/assign-participants.dto';
import { calculateCategoryScore, calculateOverallScore, getApprovalStatus } from '@simtc/shared-types';

@Injectable()
export class PracticalAssessmentsService {
  constructor(private readonly prisma: PrismaService) {}
```

por:

```typescript
import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { SyncPracticalAssessmentDto } from '@simtc/shared-types';
import { AssignParticipantsDto } from './dto/assign-participants.dto';
import { calculateCategoryScore, calculateOverallScore, getApprovalStatus } from '@simtc/shared-types';

/** Bucket privado das assinaturas de participantes (separado de `signatures`, dos consultores) */
const PARTICIPANT_SIGNATURES_BUCKET = 'participant-signatures';

@Injectable()
export class PracticalAssessmentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}
```

- [ ] **Step 7: Service — métodos novos**

No mesmo arquivo, substituir:

```typescript
  async assignParticipants(dto: AssignParticipantsDto, consultantIdFromJwt?: string, userId?: string) {
```

por:

```typescript
  /**
   * Salva a assinatura do participante (capturada no app mobile) no bucket privado
   * `participant-signatures`, com o mesmo padrão de ConsultantsService.uploadSignature:
   * apaga o arquivo anterior, sobe o novo com path único por envio (evita signed URL
   * antiga em cache) e grava no banco só o path, nunca a URL.
   */
  async uploadParticipantSignature(id: string, buffer: Buffer, contentType: string) {
    const previousPath = await this.findParticipantSignaturePath(id);
    if (previousPath) {
      // Limpeza best-effort: se falhar, sobra só um arquivo órfão no bucket,
      // o que não deve impedir o novo envio (mesmo padrão dos outros uploads)
      await this.storage.delete(PARTICIPANT_SIGNATURES_BUCKET, previousPath).catch(() => null);
    }

    const ext = contentType === 'image/png' ? 'png' : 'jpg';
    const storagePath = `${id}/${Date.now()}.${ext}`;

    // Bucket é privado: a URL pública devolvida pelo upload é ignorada
    await this.storage.upload(PARTICIPANT_SIGNATURES_BUCKET, storagePath, buffer, contentType);

    await this.prisma.practicalAssessment.update({
      where: { id },
      data: { participantSignatureUrl: storagePath },
    });

    const signedUrl = await this.storage.getSignedUrl(PARTICIPANT_SIGNATURES_BUCKET, storagePath, 3600);
    return { signedUrl };
  }

  /** Signed URL (1h) da assinatura do participante, ou null se a avaliação ainda não tem assinatura */
  async getParticipantSignatureSignedUrl(id: string) {
    const storagePath = await this.findParticipantSignaturePath(id);
    if (!storagePath) return null;

    const signedUrl = await this.storage.getSignedUrl(PARTICIPANT_SIGNATURES_BUCKET, storagePath, 3600);
    return { signedUrl };
  }

  /** Path da assinatura salva (ou null); lança 404 se a avaliação não existe */
  private async findParticipantSignaturePath(id: string): Promise<string | null> {
    const assessment = await this.prisma.practicalAssessment.findUnique({
      where: { id },
      select: { participantSignatureUrl: true },
    });
    if (!assessment) throw new NotFoundException('Avaliação não encontrada');
    return assessment.participantSignatureUrl;
  }

  async assignParticipants(dto: AssignParticipantsDto, consultantIdFromJwt?: string, userId?: string) {
```

- [ ] **Step 8: Controller — rotas novas**

Substituir todo o conteúdo de `apps/backend/src/practical-assessments/practical-assessments.controller.ts`:

```typescript
import {
  BadRequestException,
  Body,
  Controller,
  Get,
  MaxFileSizeValidator,
  NotFoundException,
  Param,
  ParseFilePipe,
  Patch,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody, ApiConsumes } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtPayload, SyncPracticalAssessmentDto, UserRole } from '@simtc/shared-types';
import { PracticalAssessmentsService } from './practical-assessments.service';
import { AssignParticipantsDto } from './dto/assign-participants.dto';

@ApiTags('practical-assessments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('practical-assessments')
export class PracticalAssessmentsController {
  constructor(private readonly service: PracticalAssessmentsService) {}

  @Post('assign')
  @ApiOperation({ summary: 'Atribui participantes ao consultor/admin logado para avaliação' })
  assign(@Body() dto: AssignParticipantsDto, @CurrentUser() user: JwtPayload) {
    // Passa consultantId do JWT (se existir) + userId como fallback para admins
    return this.service.assignParticipants(dto, user.consultantId, user.sub);
  }

  @Post('sync')
  @ApiOperation({ summary: 'Salva avaliações (web ou sync offline do mobile)' })
  sync(@Body() dtos: SyncPracticalAssessmentDto[], @CurrentUser() user: JwtPayload) {
    // No web, o consultantId sempre vem do JWT para evitar impersonação
    return this.service.syncFromMobile(dtos, user.consultantId, user.sub);
  }

  @Get('by-participant/:trainingParticipantId')
  @ApiOperation({ summary: 'Retorna avaliação existente do participante, ou null' })
  findByParticipant(@Param('trainingParticipantId') trainingParticipantId: string) {
    return this.service.findByParticipant(trainingParticipantId);
  }

  // CLIENT recebe o id da avaliação em GET /reports/training-sessions/:id, por isso
  // as rotas de assinatura exigem ADMIN ou CONSULTANT (decisão de 17/09/2026).
  @Patch(':id/participant-signature')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @ApiOperation({ summary: 'Envia a assinatura do participante (PNG/JPEG, até 2 MB) capturada no app mobile' })
  uploadParticipantSignature(
    @Param('id') id: string,
    @UploadedFile(new ParseFilePipe({
      validators: [new MaxFileSizeValidator({ maxSize: 2 * 1024 * 1024 })],
    }))
    file: Express.Multer.File,
  ) {
    if (!/^image\/(png|jpeg)$/.test(file.mimetype)) {
      throw new BadRequestException('Tipo de arquivo inválido. Aceito: PNG, JPEG.');
    }
    return this.service.uploadParticipantSignature(id, file.buffer, file.mimetype);
  }

  @Get(':id/participant-signature-url')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  @ApiOperation({ summary: 'Signed URL (1h) da assinatura do participante' })
  async getParticipantSignatureUrl(@Param('id') id: string) {
    const result = await this.service.getParticipantSignatureSignedUrl(id);
    if (!result) throw new NotFoundException('Sem assinatura do participante cadastrada');
    return result;
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }
}
```

Observações para quem implementa:
- `uploadParticipantSignature` **não** é `async`: o `BadRequestException` precisa ser lançado de forma síncrona (o teste do controller depende disso).
- O `JwtAuthGuard` da classe roda antes do `RolesGuard` do método, então `req.user` já está preenchido quando os papéis são checados.
- `@ApiConsumes` e `@ApiBody` só existem para o Swagger mostrar o seletor de arquivo no teste manual (Task 6).

- [ ] **Step 9: Rodar os testes e ver passar**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/backend"
npx jest test/practical-assessments.service.spec.ts test/practical-assessments.controller.spec.ts
npx tsc --noEmit
```

Expected: `Test Suites: 2 passed, 2 total`, `Tests: 28 passed, 28 total` (14 já existentes + 8 novos no service + 6 no controller) e `tsc` sem saída.

- [ ] **Step 10: Suíte completa (regressão)**

```bash
npx jest 2>&1 | grep -E "^(Tests|Test Suites):"
```

Expected: `Test Suites: 2 failed, 4 passed, 6 total` e `Tests: 12 failed, 60 passed, 72 total`. As 12 falhas são as pré-existentes de `auth`/`participants` (ver Baseline); qualquer número diferente de 12 falhas bloqueia a task.

- [ ] **Step 11: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/backend/src/practical-assessments/practical-assessments.module.ts apps/backend/src/practical-assessments/practical-assessments.service.ts apps/backend/src/practical-assessments/practical-assessments.controller.ts apps/backend/test/practical-assessments.service.spec.ts apps/backend/test/practical-assessments.controller.spec.ts
git commit -m "feat(practical-assessments): upload e signed URL da assinatura do participante"
```

---

## Task 5: Backend — `assessmentId` na resposta do sync (TDD)

**Files:**
- Modify: `apps/backend/src/practical-assessments/practical-assessments.service.ts` (`syncFromMobile`)
- Modify: `apps/backend/test/practical-assessments.service.spec.ts`

**Interfaces:**
- Consumes: `PracticalAssessmentsService.syncFromMobile(dtos: SyncPracticalAssessmentDto[], consultantIdFromJwt?: string, userId?: string)`, que já existe (o spec já provê o mock de `StorageService` desde a Task 4).
- Produces: `POST /api/practical-assessments/sync` responde `201` com um array na mesma ordem do corpo, cada item no formato `{ trainingParticipantId: string; status: 'fulfilled' | 'rejected'; assessmentId?: string; error?: string }`.
  - `assessmentId` só vem quando `status === 'fulfilled'`. O campo é novo e aditivo; o web (`assessment-drawer.tsx`) ignora a resposta.
  - O app usa o `assessmentId` na Fase 5 para chamar `PATCH /api/practical-assessments/:id/participant-signature`.

- [ ] **Step 1: Spec — mocks do Prisma usados pelo sync**

Em `apps/backend/test/practical-assessments.service.spec.ts`, substituir:

```typescript
  trainingParticipant: { findMany: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
  $transaction: jest.fn(),
```

por:

```typescript
  trainingParticipant: { findMany: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
  assessmentItem: { deleteMany: jest.fn() },
  assessmentCategory: { findMany: jest.fn() },
  $transaction: jest.fn(),
```

- [ ] **Step 2: Spec — testes novos**

No mesmo arquivo, inserir o bloco abaixo **antes do `});` final** (última linha do arquivo):

```typescript

  // ─── syncFromMobile ──────────────────────────────────────────────────────

  describe('syncFromMobile', () => {
    const dto = {
      trainingParticipantId: 'tp-1',
      date: '2026-09-17',
      startTime: '2026-09-17T10:00:00.000Z',
      endTime: '2026-09-17T10:30:00.000Z',
      items: [],
    };

    beforeEach(() => {
      mockPrisma.assessmentCategory.findMany.mockResolvedValue([]);
      mockPrisma.$transaction.mockResolvedValue([]);
    });

    it('devolve o assessmentId de cada avaliação sincronizada', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);
      mockPrisma.practicalAssessment.create.mockResolvedValue({ id: 'assess-1', items: [] });

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result).toEqual([
        { trainingParticipantId: 'tp-1', status: 'fulfilled', assessmentId: 'assess-1' },
      ]);
    });

    it('devolve o assessmentId também na reavaliação (registro existente)', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ id: 'assess-1' });
      mockPrisma.assessmentItem.deleteMany.mockResolvedValue({ count: 2 });
      mockPrisma.practicalAssessment.update.mockResolvedValue({ id: 'assess-1', items: [] });

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result[0]).toMatchObject({ status: 'fulfilled', assessmentId: 'assess-1' });
    });

    it('não devolve assessmentId para item rejeitado', async () => {
      mockPrisma.practicalAssessment.findUnique.mockRejectedValueOnce(new Error('falha no banco'));

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result).toEqual([
        { trainingParticipantId: 'tp-1', status: 'rejected', error: 'falha no banco' },
      ]);
      expect(result[0].assessmentId).toBeUndefined();
    });
  });
```

- [ ] **Step 3: Rodar e ver falhar**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/backend"
npx jest test/practical-assessments.service.spec.ts
```

Expected: FAIL com erro de TypeScript do ts-jest que começa com `Property 'assessmentId' does not exist on type` (vem do `result[0].assessmentId` do terceiro teste). É o sinal de que a resposta ainda não tem o campo.

- [ ] **Step 4: Implementar**

Em `apps/backend/src/practical-assessments/practical-assessments.service.ts`, substituir:

```typescript
    return results.map((r, i) => ({
      trainingParticipantId: dtos[i].trainingParticipantId,
      status: r.status,
      error: r.status === 'rejected' ? (r.reason as Error).message : undefined,
    }));
```

por:

```typescript
    return results.map((r, i) => ({
      trainingParticipantId: dtos[i].trainingParticipantId,
      status: r.status,
      // id da avaliação criada/atualizada — o app mobile usa para enviar a assinatura do participante
      assessmentId: r.status === 'fulfilled' ? r.value.id : undefined,
      error: r.status === 'rejected' ? (r.reason as Error).message : undefined,
    }));
```

- [ ] **Step 5: Rodar e ver passar**

```bash
npx jest test/practical-assessments.service.spec.ts test/practical-assessments.controller.spec.ts
npx tsc --noEmit
```

Expected: `Tests: 31 passed, 31 total` (25 no service + 6 no controller) e `tsc` sem saída.

- [ ] **Step 6: Suíte completa (regressão)**

```bash
npx jest 2>&1 | grep -E "^(Tests|Test Suites):"
```

Expected: `Test Suites: 2 failed, 4 passed, 6 total` e `Tests: 12 failed, 63 passed, 75 total` (continuam só as 12 falhas pré-existentes).

- [ ] **Step 7: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/backend/src/practical-assessments/practical-assessments.service.ts apps/backend/test/practical-assessments.service.spec.ts
git commit -m "feat(practical-assessments): sync devolve assessmentId de cada avaliação sincronizada"
```

---

## Task 6: Aplicar a migration, criar o bucket e testar os endpoints ponta a ponta

> Esta task é executada pelo controlador **junto com o usuário**, porque depende de confirmar o banco, mexer no painel do Supabase e usar credenciais reais. Não delegar a subagente. Não há commit de código.

**Files:**
- Modify (não versionado): `apps/backend/CLAUDE.md`

**Interfaces:**
- Consumes: migration (Task 3), endpoints (Task 4) e sync com `assessmentId` (Task 5).
- Produces: coluna `participantSignatureUrl` no banco do `DIRECT_URL`, bucket privado `participant-signatures` e os endpoints validados manualmente.

- [ ] **Step 1: Confirmar o banco de destino com o usuário**

Perguntar explicitamente: "O `DIRECT_URL` de `apps/backend/.env.development` (Supabase sa-east-1, banco `postgres`) é o banco onde a migration deve ser aplicada? É o banco de produção?". Só seguir com um "sim" explícito. Para contexto: a coluna nova é nullable e aditiva, então o backend em produção, ainda com o Prisma Client antigo, continua funcionando.

- [ ] **Step 2: Conferir as migrations pendentes**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/backend"
npx prisma migrate status
```

Expected: `14 migrations found in prisma/migrations`, e a **única** migration listada como não aplicada é `20260917120000_add_participant_signature_to_assessment`. Se aparecer qualquer outra, **parar** e reportar ao usuário.

- [ ] **Step 3: Aplicar a migration**

```bash
npx prisma migrate deploy
npx prisma migrate status
```

Expected: `All migrations have been successfully applied.` e, em seguida, `Database schema is up to date!`.

- [ ] **Step 4: Criar o bucket (usuário, no painel do Supabase)**

No painel do Supabase, abrir o projeto do SIMTC → Storage → New bucket:
- Name: `participant-signatures`
- Public bucket: **desligado** (bucket privado)
- Opcional: limitar o tamanho a 2 MB e os tipos a `image/png, image/jpeg` (o backend já valida os dois)

- [ ] **Step 5: Subir o backend local**

```bash
npm run start:dev
```

Expected: `🚀 SIMTC API rodando em: http://localhost:3001/api`

- [ ] **Step 6: Obter um token e escolher a avaliação de teste**

Os comandos abaixo são para o Git Bash, em outro terminal. No PowerShell 5.1, `curl` é um alias e as aspas do JSON quebram; nesse caso, use o Swagger em `http://localhost:3001/docs` → Authorize.

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/backend"
API=http://localhost:3001/api
TOKEN=$(curl.exe -s -X POST "$API/auth/login" -H "Content-Type: application/json" \
  -d '{"email":"EMAIL_DO_ADMIN_OU_CONSULTOR","password":"SENHA"}' \
  | sed -E 's/.*"accessToken":"([^"]+)".*/\1/')
echo "${TOKEN:0:16}..."
ASSESSMENT_ID=ID_DE_UMA_AVALIACAO_DE_SESSAO_DE_TESTE
```

- `EMAIL_DO_ADMIN_OU_CONSULTOR` e `SENHA`: credenciais de um usuário ADMIN ou CONSULTANT de teste (não commitar).
- `ASSESSMENT_ID`: rodar `npx prisma studio`, abrir a tabela `PracticalAssessment` e copiar o `id` de uma avaliação **de uma sessão de teste**. O upload grava `participantSignatureUrl` nessa linha.

Expected: o `echo` mostra o começo do JWT (`eyJhbGciOiJIUzI1...`), e não um JSON de erro.

- [ ] **Step 7: Upload (caminho feliz)**

```bash
PNG="../mobile/simtc/assets/images/logo-simtc.png"
curl.exe -s -w "\nHTTP %{http_code}\n" -X PATCH "$API/practical-assessments/$ASSESSMENT_ID/participant-signature" \
  -H "Authorization: Bearer $TOKEN" -F "file=@$PNG;type=image/png"
```

Expected:
- A resposta é `{"signedUrl":"https://<projeto>.supabase.co/storage/v1/object/sign/participant-signatures/<ASSESSMENT_ID>/<timestamp>.png?token=..."}`, seguida de `HTTP 200`.
- Ao abrir essa URL no navegador, a imagem aparece.
- No Prisma Studio, o `participantSignatureUrl` dessa avaliação passa a ser `<ASSESSMENT_ID>/<timestamp>.png`.

- [ ] **Step 8: Leitura da signed URL**

```bash
curl.exe -s -w "\nHTTP %{http_code}\n" "$API/practical-assessments/$ASSESSMENT_ID/participant-signature-url" \
  -H "Authorization: Bearer $TOKEN"
```

Expected: `{"signedUrl":"https://..."}` e `HTTP 200`; a URL abre a imagem.

- [ ] **Step 9: O reenvio troca o arquivo**

Repetir o comando do Step 7.

Expected: `HTTP 200`, com outro `<timestamp>`. No Supabase, em Storage → `participant-signatures` → pasta `<ASSESSMENT_ID>`, existe **um** arquivo só (o anterior foi apagado).

- [ ] **Step 10: Casos de erro**

```bash
# 1. tipo inválido
curl.exe -s -w "\nHTTP %{http_code}\n" -X PATCH "$API/practical-assessments/$ASSESSMENT_ID/participant-signature" \
  -H "Authorization: Bearer $TOKEN" -F "file=@package.json;type=application/json"
# 2. arquivo maior que 2 MB
head -c 2200000 /dev/urandom > grande.tmp.png
curl.exe -s -w "\nHTTP %{http_code}\n" -X PATCH "$API/practical-assessments/$ASSESSMENT_ID/participant-signature" \
  -H "Authorization: Bearer $TOKEN" -F "file=@grande.tmp.png;type=image/png"
rm grande.tmp.png
# 3. sem token
curl.exe -s -w "\nHTTP %{http_code}\n" "$API/practical-assessments/$ASSESSMENT_ID/participant-signature-url"
# 4. avaliação inexistente
curl.exe -s -w "\nHTTP %{http_code}\n" "$API/practical-assessments/nao-existe/participant-signature-url" \
  -H "Authorization: Bearer $TOKEN"
```

Expected, na ordem:
1. `{"message":"Tipo de arquivo inválido. Aceito: PNG, JPEG.","error":"Bad Request","statusCode":400}` / `HTTP 400`
2. `{"message":"Validation failed (expected size is less than 2097152)","error":"Bad Request","statusCode":400}` / `HTTP 400`
3. `{"message":"Unauthorized","statusCode":401}` / `HTTP 401`
4. `{"message":"Avaliação não encontrada","error":"Not Found","statusCode":404}` / `HTTP 404`

Casos opcionais, conforme os dados disponíveis:
- Avaliação de teste **sem** assinatura, no endpoint `participant-signature-url` → `{"message":"Sem assinatura do participante cadastrada",...}` / `HTTP 404`.
- Token de um usuário CLIENT de teste (fluxo OTP: `POST /auth/client/request-code` → código chega no e-mail → `POST /auth/client/verify`), no `PATCH` → `{"message":"Forbidden resource","error":"Forbidden","statusCode":403}` / `HTTP 403`.

- [ ] **Step 11 (opcional, só com participante de teste): o sync devolve `assessmentId`**

> Atenção: este passo cria ou sobrescreve a avaliação do participante e muda o status dele (sem itens = 100% = `APROVADO`). Use apenas um `TrainingParticipant` de sessão de teste.

No Swagger (`http://localhost:3001/docs` → Authorize → `POST /api/practical-assessments/sync`), enviar:

```json
[
  {
    "trainingParticipantId": "ID_DE_TRAINING_PARTICIPANT_DE_TESTE",
    "date": "2026-09-17",
    "startTime": "2026-09-17T13:00:00.000Z",
    "endTime": "2026-09-17T13:20:00.000Z",
    "items": []
  }
]
```

Expected: `201` com `[{"trainingParticipantId":"...","status":"fulfilled","assessmentId":"<id>"}]`.

- [ ] **Step 12 (opcional): Limpeza dos dados de teste**

No Prisma Studio, voltar para `null` o `participantSignatureUrl` da avaliação usada. No Supabase, apagar a pasta `<ASSESSMENT_ID>` do bucket `participant-signatures`.

- [ ] **Step 13: Atualizar `apps/backend/CLAUDE.md` (arquivo não versionado)**

13a. Na seção `### PracticalAssessments — src/practical-assessments/`, depois da linha que começa com `❌ **Sem endpoint para listar avaliações de uma sessão**`, acrescentar:

```markdown

✅ `PATCH /practical-assessments/:id/participant-signature` — upload da assinatura do participante (PNG/JPEG < 2 MB, bucket privado `participant-signatures`, salva só o path em `participantSignatureUrl`; ADMIN/CONSULTANT, CLIENT bloqueado). Implementado em 2026-09-17.
✅ `GET /practical-assessments/:id/participant-signature-url` — signed URL de 1 h (ADMIN/CONSULTANT). Implementado em 2026-09-17.
✅ `POST /practical-assessments/sync` devolve `assessmentId` em cada item com sucesso (usado pelo app mobile). Implementado em 2026-09-17.
```

13b. Na seção `### Storage — src/storage/`, substituir a linha que começa com `⚠️ **Buckets não documentados**` por:

```markdown
⚠️ **Buckets criados manualmente no Supabase** — `logos` (público), `signatures`, `certificates`, `reports` e `participant-signatures` (privado, criado em 2026-09-17) precisam existir antes do primeiro uso.
```

13c. Na seção `### Infraestrutura Base`, substituir a linha que começa com `- Cria 4 categorias de avaliação sem infrações` por:

```markdown
- Cria as categorias de avaliação com infrações e notas (`INFRACTIONS_BY_CATEGORY`), sem duplicar infrações de categorias já populadas ✅ (conferido em 2026-09-17)
```

- [ ] **Step 14: Registrar no ledger**

Em `progress.md`, anotar: confirmação do banco (quem e quando), saída do `migrate deploy`, criação do bucket e o resultado de cada passo de 7 a 11. Não há commit nesta task.

---

## Task 7: Ambiente de teste no aparelho físico + README do app

> Executada pelo controlador **junto com o usuário**, que precisa estar com o aparelho em mãos. O controlador escreve o README; o usuário faz a validação.

**Files:**
- Modify: `apps/mobile/simtc/README.md` (substitui o README padrão do `flutter create`)

**Interfaces:**
- Consumes: scaffold versionado (Task 2) e o backend local, em qualquer versão, para o teste de acesso.
- Produces: procedimento documentado e validado (USB, Wi-Fi e `adb reverse`), usado nos testes de todas as fases seguintes.

- [ ] **Step 1: Substituir todo o conteúdo de `apps/mobile/simtc/README.md`**

````markdown
# SIMTC Mobile (Flutter)

App Android (celular e tablet) do fluxo de avaliação prática da SIM Treinamentos.
Planos de implementação: `apps/mobile/docs/superpowers/plans/`. Auditoria da base: `apps/mobile/docs/fase-0-auditoria.md`.

## Requisitos

- Flutter 3.41.x (Dart 3.11). Conferir com `flutter --version`.
- Android SDK com `adb` no PATH. Conferir com `adb version`.
- Aparelho Android físico com as **Opções do desenvolvedor** ativadas: em Configurações → Sobre o telefone, tocar 7 vezes em **Número da versão** (em alguns aparelhos, **Número de compilação**).

Os testes de cada fase são feitos em aparelho físico, não em emulador.

## Comandos do dia a dia

```bash
cd apps/mobile/simtc
flutter pub get
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs   # depois de mudar tabelas Drift ou modelos JSON
```

## Rodar no aparelho via USB

1. No aparelho, em Opções do desenvolvedor, ativar **Depuração USB**.
2. Conectar o cabo e aceitar, no aparelho, o pedido "Permitir depuração USB?".
3. Rodar `adb devices -l`: o aparelho deve aparecer com o estado `device`. Se aparecer `unauthorized`, desbloqueie a tela e aceite o pedido.
4. Rodar `flutter devices` e copiar o id do aparelho (a linha **sem** "emulator").
5. Rodar `flutter run -d <ID_DO_APARELHO>`.

## Rodar no aparelho via Wi-Fi (Android 11+)

O PC e o aparelho precisam estar na mesma rede Wi-Fi.

1. No aparelho, em Opções do desenvolvedor, ativar **Depuração por Wi-Fi**.
2. Nessa tela, tocar em **Parear dispositivo com código de pareamento** e, no PC, rodar:
   `adb pair <IP>:<PORTA_DE_PAREAMENTO> <CÓDIGO>`
3. Ainda na tela "Depuração por Wi-Fi", anotar o **endereço IP e porta** (é uma porta diferente da do pareamento) e, no PC, rodar:
   `adb connect <IP>:<PORTA>`
4. Rodar `flutter devices --device-connection wireless`: o aparelho aparece como `<IP>:<PORTA>`.
5. Desconectar o cabo, se houver, e rodar `flutter run -d <IP>:<PORTA>`.

O pareamento (passo 2) é feito uma vez por PC; nas próximas vezes basta o passo 3. A porta do passo 3 muda sempre que a depuração por Wi-Fi é desligada e ligada de novo.

## Acessar o backend local a partir do aparelho

Em desenvolvimento, o app fala com o backend que roda no PC (`npm run start:dev` em `apps/backend`, porta 3001). Em vez de usar o IP do PC, que exige liberar o firewall do Windows, redirecione a porta pelo `adb`:

```bash
adb -s <ID_DO_APARELHO> reverse tcp:3001 tcp:3001
adb -s <ID_DO_APARELHO> reverse --list    # deve listar tcp:3001 tcp:3001
```

Com isso, `http://localhost:3001/api` **no aparelho** chega ao backend do PC. Para um teste rápido, abra `http://localhost:3001/docs` no Chrome do aparelho: deve aparecer o Swagger da API.

- O redirecionamento some quando o aparelho desconecta do `adb`. Rode o `reverse` de novo depois de reconectar.
- **Testes offline (Fases 4 e 5):** via USB, o modo avião não derruba o `adb`, então com o `reverse` ativo o app continua alcançando `localhost:3001`. Para simular falta de rede de verdade, ative o modo avião, confira que o Wi-Fi também desligou e remova o redirecionamento com `adb -s <ID_DO_APARELHO> reverse --remove tcp:3001`. Para "voltar a ficar online", recrie o redirecionamento e desligue o modo avião.
````

- [ ] **Step 2: Conferir a toolchain**

```bash
flutter doctor
```

Expected: `[✓] Flutter` e `[✓] Android toolchain`. Se aparecer aviso de licenças, rodar `flutter doctor --android-licenses`.

- [ ] **Step 3 (usuário): Rodar via USB**

Seguir a seção "Rodar no aparelho via USB" do README.

Expected:
- `flutter devices` lista o aparelho físico (sem "emulator").
- O app placeholder abre no aparelho.
- O login mock (qualquer e-mail + senha com 4+ caracteres) leva ao dashboard placeholder.
- Apertar `r` no terminal faz hot reload.

- [ ] **Step 4 (usuário): Rodar via Wi-Fi, com o cabo desconectado**

Seguir a seção "Rodar no aparelho via Wi-Fi" do README.

Expected: `flutter devices --device-connection wireless` lista `<IP>:<PORTA>`, e o app abre como no Step 3.

- [ ] **Step 5 (usuário): Acesso ao backend local**

Com `npm run start:dev` rodando em `apps/backend`, rodar `adb -s <ID_DO_APARELHO> reverse tcp:3001 tcp:3001` e abrir `http://localhost:3001/docs` no Chrome do aparelho.

Expected: o Swagger "SIMTC API" carrega no aparelho.

- [ ] **Step 6 (opcional): Tablet**

Repetir o Step 3 num tablet Android, se houver um disponível.

- [ ] **Step 7: Registrar no ledger**

Anotar modelo do aparelho, versão do Android, id mostrado pelo `flutter devices` e o resultado dos Steps 3 a 6.

- [ ] **Step 8: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/mobile/simtc/README.md
git commit -m "docs(mobile): guia para rodar o app em aparelho Android físico (USB, Wi-Fi e adb reverse)"
```

---

## Critério de "pronto para testar" da Fase 0 (spec)

- [ ] A migration foi aplicada, sem quebrar nada, no banco confirmado pelo usuário (Task 6, Steps 2–3).
- [ ] Os dois endpoints novos respondem ao teste com arquivo (Task 6, Steps 7–10).
- [ ] O app atual compila e roda no aparelho físico, via cabo e via Wi-Fi (Task 7).

Depois disso, o controlador:
1. revisa o diff completo da fase (`git diff <hash-base>..feat/mobile-app`);
2. registra o resultado no ledger;
3. **para** e aguarda a validação do usuário antes de escrever o plano da Fase 1.
