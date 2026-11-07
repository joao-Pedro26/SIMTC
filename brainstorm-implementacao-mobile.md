# Brainstorm de Implementação — App Mobile SIMTC (Flutter)

**Data:** 17/09/2026
**Objetivo deste documento:** quebrar a implementação completa do app mobile (já mapeado em `brainstorm-app-mobile.md` e desenhado em alta fidelidade a partir de `prompt-claude-design-mobile.md`) em **fases sequenciais e testáveis**, cada uma terminando em um app que roda de verdade num aparelho físico e que agrega valor sobre a fase anterior. Este documento serve de insumo para o prompt entregue ao Claude Code (`prompt-implementacao-mobile-claude-code.md`), que usará o plugin **superpowers** (SDD) para transformar cada fase abaixo num plano de tasks detalhado e executá-lo.

**Como testar ao longo da implementação:** dispositivo Android físico conectado por USB ou depuração Wi-Fi (`flutter run` apontando para o device físico, não emulador) — decisão do usuário, mais fiel ao uso real em campo (permite testar o fluxo offline de verdade, tirando o cabo/desligando o Wi-Fi do aparelho).

---

## 0. Decisões de escopo tomadas nesta rodada (17/09/2026)

1. ~~Gap da assinatura do participante (não existe campo/endpoint hoje) → entra como Fase 0, resolvido no backend antes de qualquer tela do app ser construída.~~ **Superado em 20/09/2026:** a assinatura do participante deixou de ser capturada no app mobile. Agora é opcional e coletada no formulário público de inscrição (web, via QR code), só para aparecer no certificado — não confirma mais o resultado da avaliação prática. A Fase 5 não tem mais etapa de assinatura (ver Fase 5 abaixo). O trabalho de backend já feito na Fase 0 (`PracticalAssessment.participantSignatureUrl` + endpoints `PATCH`/`GET .../participant-signature`) fica sem uso pelo mobile.
2. **Telas administrativas inline** (Editar Sessão, Adicionar Participante, Gerenciar Consultores) → entram no **ciclo principal** (Fase 6), não numa etapa separada ao final — os endpoints já existem prontos, então o custo extra é baixo e evita retrabalho de navegação depois.
3. **Tablet/adaptativo** → **celular primeiro, tablet por último** (Fase 7). Todas as telas nascem "compact-first"; a adaptação por breakpoint (`flutter_adaptive_scaffold`, master-detail, navbar lateral, popovers admin) é uma camada de layout que se soma por cima dos ViewModels já prontos, sem duplicar lógica.
4. **Nuance de re-avaliação resolvida:** como `applyScore()` (`practical-assessments.service.ts`) sempre reseta `assignedConsultantId: null` depois de um sync (linha `data: { status, assignedConsultantId: null }`), um participante `NECESSITA_REAVALIACAO` **não está mais atribuído a ninguém**. Portanto, o botão "Reavaliar" da tela de Resultado deve **chamar `POST /practical-assessments/assign` novamente (silenciosamente, sem exigir um novo toque em "Atribuir a mim")** antes de abrir o Formulário de Avaliação — caso contrário o `sync` subsequente pode ser roubado por outro consultor que também tentar reavaliar. Isso deve ser encoded explicitamente na Fase 5.

---

## 1. Visão geral das fases

| Fase | Nome | Entrega testável no aparelho |
|---|---|---|
| 0 | Preparação (backend + ambiente) | ~~Migration de assinatura + endpoint aplicados em staging~~ (feito, depois superado — ver seção 0); `flutter run` funcionando no device físico com o scaffold atual |
| 1 | Design System + Fundação MVVM | Tela de login redesenhada (novo DS) autenticando de verdade contra a API real; scaffold placeholder removido |
| 2 | Minhas Sessões (Home) | Lista real de treinamentos do consultor logado, com cache offline |
| 3 | Detalhe da Sessão + Autoatribuição + Catálogo | Ver participantes reais de uma sessão, atribuir a si mesmo, catálogo de categorias/infrações cacheado |
| 4 | Checklist de Avaliação (offline) | Preencher o checklist inteiro em modo avião, fechar/reabrir o app retomando o rascunho |
| 5 | Resumo + Sincronização automática | Fluxo ponta a ponta: avaliar offline → reconectar → ver resultado real no backend/web |
| 6 | Ações administrativas inline | Admin edita sessão/participante/consultores direto do celular, refletido no painel web |
| 7 | Adaptação para tablet | Mesmo app rodando em tablet físico com master-detail, navbar lateral, popovers |
| 8 | Polish e QA final | Skeletons, empty/error states, acessibilidade, revisão end-to-end |

Cada fase abaixo já indica: o que constrói, os ViewModels/Repositories/tabelas Drift envolvidos, os endpoints reais consumidos, e o critério de "pronto para testar".

---

## Fase 0 — Preparação (backend + ambiente de teste)

**Por quê primeiro:** sem o ambiente de teste configurado, nenhuma fase seguinte pode ser validada de verdade no aparelho.

> **Nota (20/09/2026):** o bloco "Backend" abaixo descreve trabalho de assinatura que **foi feito, mas depois ficou sem uso pelo mobile** — a assinatura do participante passou a ser capturada no formulário web de inscrição, não mais no app ao final da avaliação (ver seção 0, item 1). Mantido aqui como registro histórico do que essa fase entregou.

**Backend:**
- ~~Migration Prisma em `PracticalAssessment`: novo campo `participantSignatureUrl String?`~~ (mesmo padrão de `Consultant.signatureUrl` — guarda o *path* no bucket, não a URL pública, seguindo [[simtc-storage-pattern]]).
- ~~Novo endpoint `PATCH /practical-assessments/:id/participant-signature`~~ (multipart, campo `file`), reaproveitando `StorageService.upload()`/`getSignedUrl()` já existentes — bucket novo `participant-signatures` (separado do bucket `signatures` do consultor, para não misturar as duas assinaturas). Segue o padrão de cache-busting: deleta o arquivo antigo antes de subir o novo, path com timestamp (`{assessmentId}/{Date.now()}.png`).
- ~~Novo endpoint `GET /practical-assessments/:id/participant-signature-url`~~ retornando signed URL (mesmo padrão de `getSignatureSignedUrl`).
- Proteção: `@UseGuards(JwtAuthGuard)`, sem `@Roles` extra (qualquer consultor autenticado que tenha acesso à avaliação pode enviar a assinatura — a checagem de "é o consultor certo" já acontece implicitamente porque só quem tem o `assessmentId` local consegue chamar).

**App mobile:**
- Confirmar `flutter run -d <device-id>` funcionando no aparelho físico via USB ou `flutter run --wireless` (depuração Wi-Fi), com o scaffold placeholder atual (ainda sem nenhuma tela nova).
- Auditoria do scaffold: confirmar quais arquivos serão descartados por completo (`login_viewmodel.dart` com mock, `evaluation_screen.dart` com slider genérico, `app_colors.dart` com paleta antiga `#00569E`, `api_constants.dart` apontando pra `/evaluations` em vez de `/practical-assessments`) vs. o que é só estrutura reaproveitável (pastas, `pubspec.yaml`, `app_database.dart` como esqueleto do Drift).

**Pronto para testar quando:** a migration roda contra o banco de staging sem quebrar nada existente; os dois endpoints novos respondem via Swagger/Insomnia com um arquivo de teste; o app atual (ainda placeholder) compila e roda no celular/tablet físico via cabo ou Wi-Fi.

---

## Fase 1 — Design System + Fundação MVVM

Esta é a fase mais "invisível" em termos de telas, mas a mais importante para o pedido do usuário de reaproveitamento e organização — tudo daqui pra frente é construído em cima dela.

**Design System (`lib/ui/core/` ou `lib/design_system/`):**
- `app_colors.dart` reescrito com os tokens **reais** confirmados em `prompt-claude-design-mobile.md`: primária `#1D9AA4` (hover `#167F8A`, escuro `#0A6E80`, fundo suave `#EEF9FA`), CTA laranja `#F5A520` (hover `#E09510`, suave `#FEF8EE`), `#9B80A8` (suave `#F5F0F8`), charcoal `#1E2A34`/`#2A3A46`, neutros (`#F8FAFC`, `#FFFFFF`, `#E2E8F0`, `#0F172A`, `#475569`, `#94A3B8`). Paleta semântica **separada**: severidade B/PM/M (verde `#16A34A`/`#DCFCE7`, âmbar `#CA8A04`/`#FEF9C3`, vermelho `#DC2626`/`#FEE2E2` — idênticas ao web, não inventar escala nova) e status de participante (cinza/amarelo/verde/vermelho, nunca reusando o laranja de marca).
- `app_spacing.dart` — escala de espaçamento (ex: 4/8/12/16/24/32/48dp) como constantes nomeadas, não números soltos espalhados pelas telas.
- `app_typography.dart` — escala tipográfica sobre `google_fonts` Inter (títulos, corpo, legendas, com suporte a `MediaQuery.textScaler` para acessibilidade/tipografia dinâmica).
- `app_theme.dart` — `ThemeData` Material 3 único, mapeando os tokens acima para `ColorScheme` (primary/secondary/tertiary/surface/error), consumido por `MaterialApp.theme` — nenhuma tela deve usar `Color(0xFF...)` hardcoded depois desta fase.
- **Granularidade de arquivo dos componentes — seguir o padrão já usado em `login_screen.dart` (scaffold atual):** não é "um arquivo por widget" por padrão. Um widget só vira arquivo próprio em `lib/ui/core/widgets/` quando for **genuinamente reutilizável em várias telas** (ex: `CustomButton`, `CustomTextField` já existem assim) **ou** grande/complexo o bastante para atrapalhar a leitura se ficasse embutido. Widgets pequenos e específicos de uma tela continuam como métodos privados `_buildX()` dentro do próprio arquivo da tela (exatamente como `login_screen.dart` já faz com `_buildHeader()`, `_buildFormFields()`, `_buildErrorMessage()`, `_buildSubmitButton()` — nenhum desses virou arquivo separado). Componentes-base do DS que se qualificam para arquivo próprio por serem reutilizados em múltiplas telas:
  - `StatusChip` (status do participante: PENDENTE/EM_AVALIACAO/APROVADO/NECESSITA_REAVALIACAO, sempre ícone + texto + cor, nunca só cor)
  - `SeverityBadge` (B/PM/M)
  - `SessionCard` (card de treinamento com logo/placeholder de iniciais, nome, curso, local, data, contador)
  - `PillNavBar` (navbar flutuante arredondada, variante bottom/celular por enquanto — variante lateral vira na Fase 7)
  - `AppPrimaryButton`, `AppSecondaryButton`, `AppTextField` (substituem `custom_button.dart`/`custom_text_field.dart` do scaffold atual, mesmo espírito)
  - `ConnectivityBanner` (indicador on/off discreto)
  - `SkeletonListItem` (placeholder de carregamento, reaproveitado nas listas das Fases 2 e 3)

**Fundação de arquitetura:**
- `ApiService`/`ApiClient` reescrito sobre `dio`: interceptor de `Authorization: Bearer`, interceptor de refresh automático em `401` (mesmo padrão do `clientFetch` do web: tenta `/auth/refresh`, senão desloga), `baseUrl` configurável por ambiente (dev/staging/prod), removendo o `evaluations`/`syncEvaluations` do `api_constants.dart` (substituídos pelos endpoints reais abaixo).
- `AuthRepository` reescrito sem fallback mock: `login()` (`POST /auth/login`), `refresh()`, `getMe()` (`GET /auth/me` — valida `role` e bloqueia se não for `CONSULTANT`/`ADMIN`), `logout()`, token via `flutter_secure_storage`.
- `ConnectivityService` (serviço global, inicializado no nível do app via `provider`/`MultiProvider` no `main.dart`, não dentro de uma tela) — expõe stream online/offline via `connectivity_plus`.
- Esquema Drift completo (arquivo `app_database.dart` reescrito, tabelas conforme seção 4 do `brainstorm-app-mobile.md`): `SessionsTable`, `ParticipantsTable`, `AssessmentCategoriesTable`, `InfractionsTable`, `InfractionNotesTable`, `LocalAssessmentTable` (com `syncStatus`), `LocalAssessmentItemTable`. Rodar `build_runner` e confirmar geração sem erro.
- **Convenção de composição "quebra-cabeça" (obrigatória em toda tela a partir daqui):** cada `Screen`/`View` implementa métodos privados `_buildHeader()`, `_buildBody()`, `_buildXList()`, `_buildFooterActions()` etc., todos retornando `Widget`, combinados em um único `build()` enxuto. Nenhuma tela deve ter um `build()` com árvore de widgets profunda e não decomposta.
- **MVVM estrito:** `ChangeNotifier` ViewModel por tela/fluxo (nunca lógica de API/Drift dentro do widget), Repository por domínio (nunca o ViewModel chamando `Dio`/Drift diretamente — sempre via Repository), `Result<T>`/sealed class de erro já existente no scaffold (`utils/result.dart`) reaproveitado em todos os Repositories novos.

**Pronto para testar quando:** a tela de Login (única tela nova nesta fase, para validar o DS + fundação de ponta a ponta) usa os componentes/tokens do DS, autentica de verdade contra `POST /auth/login` no ambiente de staging, salva o token, e navega para uma tela provisória em branco — tudo isso rodando no aparelho físico.

---

## Fase 2 — Minhas Sessões (Home)

**ViewModels/Repositories:** `SessionsListViewModel`, `SessionRepository.findAll()` (`GET /training-sessions?page=1&limit=20`, filtragem por consultor já é automática no backend via JWT — nenhum parâmetro extra necessário).

**Tela 1.3:** lista de `SessionCard`, indicador de conectividade no topo, badge de sincronização pendente (contagem vem da tabela `LocalAssessmentTable` local, ainda sempre zero nesta fase — a fila só passa a existir na Fase 4), pull-to-refresh, estado vazio, skeleton de carregamento (usa `SkeletonListItem` da Fase 1). Cache: ao buscar da API com sucesso, grava em `SessionsTable` (Drift); ao abrir o app offline, lê do cache.

**Pronto para testar quando:** logar no device físico mostra a lista real de treinamentos vinculados ao consultor de teste; ativar modo avião e reabrir o app ainda mostra a última lista cacheada; puxar para atualizar com internet de volta busca dados novos.

---

## Fase 3 — Detalhe da Sessão + Autoatribuição + Catálogo

**ViewModels/Repositories:** `SessionDetailViewModel`, `ParticipantRepository` (`findBySession` via `GET training-sessions/:id/participants`, autoatribuição via `POST /practical-assessments/assign`), `AssessmentCatalogRepository` (`GET /assessment-categories`, cacheado em `AssessmentCategoriesTable`/`InfractionsTable`/`InfractionNotesTable` — busca uma vez e reutiliza, refresh manual/periódico).

**Tela 1.4:** cabeçalho da sessão + lista de participantes com `StatusChip` (PENDENTE cinza + botão "Atribuir a mim"; EM_AVALIACAO meu → abre Fase 4 quando ela existir, por ora navega para uma tela provisória; EM_AVALIACAO de outro → bloqueado; APROVADO/NECESSITA_REAVALIACAO → abre Resultado, que só ganha conteúdo real na Fase 5; badge "Somente teórica"). Filtro rápido (Todos/Pendentes/Meus/Concluídos). Tratamento de conflito: se `assign` retornar erro (participante já atribuído a outro), mostrar mensagem clara sem quebrar a lista.

**Pronto para testar quando:** abrir uma sessão real mostra os participantes reais; tocar "Atribuir a mim" num `PENDENTE` chama a API de verdade e o item muda de status na tela e (validando no painel web) no banco; o catálogo de categorias/infrações é buscado uma vez e persiste no Drift (visível reiniciando o app offline).

---

## Fase 4 — Checklist de Avaliação (offline-first)

A tela mais densa e mais importante do app — critério explícito do usuário: precisa ser 100% funcional sem internet.

**ViewModels/Repositories:** `EvaluationFormViewModel`, `AssessmentRepository` (CRUD local do rascunho: cria `LocalAssessmentTable` ao abrir o checklist pela primeira vez para aquele participante, grava `startTime`, autosave em `LocalAssessmentItemTable` a cada seleção B/PM/M).

**Tela 1.5:** cabeçalho com nome do participante + cronômetro; accordion por `AssessmentCategory`, cada `Infraction` com seletor segmentado de 4 estados (Sem infração/B/PM/M) — **um único toque, sem modal**, mostrando `InfractionNote.comment` ao selecionar B/PM/M; barra de progresso de categorias revisadas; indicador discreto de autosave; botão flutuante "Finalizar avaliação" (com confirmação se houver categoria não revisada). Construída seguindo a convenção `_buildHeader()`/`_buildCategoryAccordion()`/`_buildInfractionRow()`/`_buildProgressBar()`/`_buildFinishButton()`.

**Scoring local:** portar `calculateCategoryScore`/`calculateOverallScore`/`getApprovalStatus` de `packages/shared-types/src/scoring.ts` para Dart **1:1** (mesmos números: B=1/PM=3/M=5, normalizado por peso máximo 5, categoria sem infração marcada = 100%, aprovação ≥70%), com testes unitários comparando alguns casos conhecidos contra a implementação TypeScript.

**Pronto para testar quando:** no aparelho físico, ativar modo avião, abrir um participante `PENDENTE` (após atribuir), preencher o checklist inteiro marcando B/PM/M em várias categorias, fechar o app à força e reabrir — o rascunho deve reaparecer exatamente como estava, ainda offline.

---

## Fase 5 — Resumo + Sincronização automática

Fecha o ciclo completo de valor do app: da avaliação em campo até o dado aparecer no backend/painel web.

**ViewModels/Repositories:** `EvaluationSummaryViewModel` (usa o scoring local da Fase 4), `EvaluationResultViewModel` (leitura de avaliação concluída + ação "Reavaliar"), extensão do `AssessmentRepository` com fila de sync e do `ConnectivityService` para disparo automático.

**Telas:**
- 1.6 Resumo: score local, resultado (Aprovado/Necessita Reavaliação, corte 70%), detalhamento por categoria, botão "Confirmar" — marca a avaliação local como `pendingSync`, grava `endTime` (sem etapa de assinatura, mudou em 20/09/2026 — ver seção 0, item 1).
- 1.7 Resultado (somente leitura): mesmo resumo + data/hora; botão "Reavaliar" só se `NECESSITA_REAVALIACAO` — **chama `POST /practical-assessments/assign` novamente antes de reabrir o checklist** (decisão da seção 0.4 acima, necessária porque o backend zera `assignedConsultantId` após o sync).
- 1.8 Sincronização: painel somente leitura (pendente/enviando/erro/enviado) — **sem botão manual**. `ConnectivityService` dispara `AssessmentRepository.syncPending()` automaticamente na transição offline→online, de qualquer tela do app, enviando via `POST /practical-assessments/sync` (payload exato: `trainingParticipantId`, `date`, `startTime`, `endTime`, `items: [{ infractionNoteId }]` — sem `consultantId` explícito, pois o backend prioriza o valor do JWT). Erros de conflito (ex: participante já avaliado por outro consultor) ficam visíveis no painel com retry automático por backoff, sem intervenção manual.

**Pronto para testar quando:** ciclo completo em campo simulado — modo avião, atribuir, avaliar, confirmar — depois reconectar a internet e ver, sem tocar em nada, a avaliação aparecer sincronizada no backend (conferível pelo painel web ou por uma chamada direta à API).

---

## Fase 6 — Ações administrativas inline

Só entra depois do ciclo core validado ponta a ponta, mas ainda faz parte do "ciclo principal" (decisão do usuário) — todos os endpoints já existem, é praticamente só tela + repository.

**ViewModels/Repositories:** `AdminSessionEditViewModel`/`SessionRepository.updateSession()` (`PATCH /training-sessions/:id`), `AdminAddParticipantViewModel`/`ParticipantRepository` (busca por CPF + `POST training-sessions/:id/participants`, DTO `{ cpf, name, email?, cnhCategory?, cnhExpiration?, participationType? }`), `AdminSessionConsultantsViewModel`/`SessionConsultantsRepository` (replace total via `PATCH /training-sessions/:id` com `additionalConsultantsIds` completo — carrega lista atual, aplica adições/remoções localmente, envia tudo de uma vez).

**Telas 1.4.1/1.4.2/1.4.3:** formulários simples (modais/telas cheias no celular), **visíveis apenas para `role = ADMIN`** e **habilitados apenas quando online** (offline: visíveis porém desabilitados, com mensagem explicativa — nunca escondidos de repente, para não confundir o admin).

**Pronto para testar quando:** logar com um usuário `ADMIN` de teste, editar data/cidade/observações de uma sessão pelo celular e confirmar a mudança no painel web; adicionar um participante novo por CPF e vê-lo aparecer na lista; adicionar/remover um consultor da sessão e confirmar no web.

---

## Fase 7 — Adaptação para tablet

Só começa depois do fluxo completo (Fases 1–6) validado e estável no celular.

- Adicionar `flutter_adaptive_scaffold` ao `pubspec.yaml`.
- Master-detail (split view) na dupla Minhas Sessões + Detalhe da Sessão (breakpoints medium/expanded), com fallback para navegação em pilha se a largura não comportar as duas colunas em retrato estreito.
- `PillNavBar` ganha variante lateral vertical (reaproveitando o mesmo componente da Fase 1, não duplicando).
- Telas 1.4.1/1.4.2/1.4.3 passam a abrir como popover/diálogo ancorado no tablet (mesmos ViewModels da Fase 6, só a camada de apresentação muda).
- Suporte a retrato e paisagem no tablet (celular continua fixo em retrato).
- Fluxo de avaliação (1.5–1.7) permanece em tela cheia mesmo no tablet — não vira split view, para preservar foco.

**Pronto para testar quando:** o mesmo app instalado num tablet Android físico mostra o master-detail funcionando em retrato e paisagem, a navbar lateral, e os modais administrativos como popover — sem regressão no comportamento do celular.

---

## Fase 8 — Polish e QA final

- Skeleton screens em todas as listas que ainda não têm (revisão final, não só as citadas nas fases anteriores).
- Estados de erro/vazio explícitos em todas as telas (não só o caminho feliz).
- Verificação de tipografia dinâmica (aumentar fonte do sistema e confirmar que nenhum layout quebra).
- Tela 1.10 Perfil completa: dados do consultor, badge "Admin" se aplicável, logout com confirmação (limpa token + avisa se houver avaliação pendente de sync não enviada), versão do app.
- Checklist de acessibilidade básica (contraste, alvos de toque ≥48dp, nunca status só por cor).
- QA manual do fluxo completo em ambos os perfis (CONSULTANT e ADMIN) e ambos os formatos (celular e tablet), incluindo cenários de conflito (dois consultores tentando avaliar o mesmo participante) e de erro de rede no meio do sync.

---

## 2. Tabelas/Repositories por fase (referência rápida)

| Fase | Tabelas Drift novas/afetadas | Repositories novos/afetados |
|---|---|---|
| 1 | todas (criação do schema completo) | `AuthRepository` (reescrito) |
| 2 | `SessionsTable` | `SessionRepository` |
| 3 | `ParticipantsTable`, `AssessmentCategoriesTable`, `InfractionsTable`, `InfractionNotesTable` | `ParticipantRepository`, `AssessmentCatalogRepository` |
| 4 | `LocalAssessmentTable`, `LocalAssessmentItemTable` | `AssessmentRepository` |
| 5 | (extensão de `LocalAssessmentTable.syncStatus`) | extensão de `AssessmentRepository` |
| 6 | — | `SessionConsultantsRepository`, extensões de `SessionRepository`/`ParticipantRepository` |
| 7 | — | — (só camada de apresentação) |
| 8 | — | — |

---

*Este documento é a base do prompt entregue ao Claude Code em `prompt-implementacao-mobile-claude-code.md`. Cada fase acima deve virar, dentro do fluxo do plugin superpowers, um plano de tasks detalhado próprio (arquivos, interfaces, steps com código, comando de teste, commit) — no mesmo formato de `apps/web/docs/superpowers/plans/2026-08-02-frontend-backend-integration.md` — implementado e testado no aparelho físico antes de avançar para a fase seguinte.*
