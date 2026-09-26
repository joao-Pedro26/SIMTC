# App Mobile SIMTC — Fase 3: Detalhe da Sessão + Autoatribuição + Catálogo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ligar o toque no card da Home à tela 1.4 "Detalhe da sessão": participantes reais cacheados no Drift, com filtros Todos/Pendentes/Meus/Concluídos, "Atribuir a mim" contra `POST /practical-assessments/assign`, "Iniciar sessão" para o responsável, e o catálogo de categorias/infrações/notas baixado e guardado no aparelho para a Fase 4.

**Architecture:** Mesma regra da Fase 2 — a tela lê só do banco local. `ParticipantRepository.syncSession()` baixa `GET /training-sessions/:id` e regrava a sessão e os participantes dela numa transação; a `SessionDetailViewModel` assina `watchSession()`/`watchBySession()` e aplica as regras puras de `participant_filter.dart` (situação de cada linha, filtros, ordem, progresso). As regras de ação espelham o `getAction` do painel web: atribuir e abrir o checklist só com a sessão `EM_ANDAMENTO`. O catálogo desce junto com cada refresh da Home, em paralelo e em silêncio. O checklist (Fase 4) e o resultado (Fase 5) ganham agora as rotas definitivas, apontando para uma tela provisória.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · dio 5.11.1 · drift 2.31.0 + drift_flutter 0.2.8 · cached_network_image 3.4.1 · connectivity_plus 6.1.5 · mocktail (testes). **Nenhuma mudança de backend.**

**Spec:** `brainstorm-implementacao-mobile.md` → "Fase 3 — Detalhe da Sessão + Autoatribuição + Catálogo"; tela 1.4 do canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html` (quadros `1e`, linhas 854–941, e `1f`, 943–1040; dados de exemplo nas linhas 3628–3658); pendências de backend em `apps/mobile/docs/fase-0-auditoria.md` (linhas 79–82). O desenho aprovado em 23/09/2026 está na seção "Decisões tomadas com o usuário" abaixo — a trilha mobile não usa doc de spec separado, o plano é o documento.

**Validação prévia:** todo o código deste plano foi escrito e rodado numa cópia descartável do app antes de o plano ser fechado — `flutter analyze` sem issues e **202 testes passando** no fim da Task 7. Os números "Esperado" de cada task vêm dessa execução.

## Decisões tomadas com o usuário (23/09/2026)

1. **Offline dos participantes — baixar ao abrir.** O detalhe é buscado ao abrir a tela, no puxar para atualizar e na volta da conexão, e fica no Drift. Offline, uma sessão já aberta mostra o cache; uma nunca aberta mostra um aviso. Recusado: pré-carregar o detalhe de todas as sessões de Hoje + Esta semana (N chamadas no 4G). O fluxo de campo continua coberto porque "Atribuir a mim" exige conexão de qualquer forma: o consultor atribui com sinal e avalia sem.
2. **Filtro "Meus" = em avaliação comigo + avaliados por mim** (`assessment.consultantId`), como sugerem os números do canvas. **Pendentes** = `PENDENTE` com prática; **Concluídos** = `APROVADO` + `NECESSITA_REAVALIACAO`; "Somente teórica" só aparece em **Todos**.
3. **Busca fica para a Fase 8**, junto com a busca da Home. A lupa do canvas não entra nesta fase.
4. **Ajustes visuais não commitados** (`session_card.dart`, `session_filter.dart`, `sessions_screen.dart`, feitos durante a validação em campo) viram a Task 0: commitados, com os números soltos trocados por tokens do DS sem mudar o visual. **Achado ao preparar a Task 0:** os 2 testes que falhavam com esses ajustes não precisavam ser adaptados — pegaram 2 bugs reais: o bloco "Concluídas" passou a usar o builder da semana com o id fixo `semana` (o "Ver mais" de Concluídas revelaria sessões de "Esta semana"), e a regra "fim do scroll destaca a última seção **montada**" falha quando Concluídas fica longa demais para o `cacheExtent`. A Task 0 corrige os dois.
5. **Regra do web para avaliar + botão "Iniciar sessão".** Como no painel (`session-management-drawer.tsx`, `getAction`), "Atribuir a mim" e o acesso ao checklist só existem com a sessão `EM_ANDAMENTO`. Em `PLANEJADO`, o consultor responsável (ou um ADMIN) vê **"Iniciar sessão"** no cabeçalho — online, com confirmação, chamando `POST /training-sessions/:id/start`; os demais veem "Aguardando o responsável iniciar a sessão". O botão **não está no canvas**: entrou por causa desta regra, para o consultor não ficar travado em campo. Um ADMIN sem perfil de consultor acompanha a sessão, mas não atribui (mesma regra do web).
6. **Catálogo — caminho A.** Desce junto com o sync da Home (abertura, puxar, reconexão), em paralelo e em silêncio: o puxar para atualizar não espera por ele e a falha dele não vira mensagem. Troca total numa transação; resposta vazia ou fora do formato não apaga o catálogo do aparelho. Como não há tela do catálogo nesta fase, um log só de debug ("Catálogo sincronizado. No aparelho: N categorias…") é como se confere no aparelho que ele persiste offline. Recusados: baixar só ao abrir o detalhe (B) e validade de 24h (C).
7. **Esquema Drift v3:** `Sessions.responsibleConsultantId`, `Sessions.participantsSyncedAt` (distingue "nunca baixada" de "baixada e vazia"), `Participants.assessedByConsultantId` e `Participants.assessedAt`. A migração 2→3 usa `addColumn` na mesma transação da 1→2. O CPF vai para o cache **já mascarado** (`042.118.***-**`) e o e-mail não é guardado — a tela nunca mostra os dois inteiros, então o aparelho não precisa deles.
8. **`syncAll` da Home para de apagar o logo.** Hoje ele grava `companyLogoUrl` nulo (a listagem não traz o logo), o que apagaria a cada refresh o logo que o detalhe salvou.
9. **Os chips da 1.4 filtram de verdade** (o canvas tem "Todos" e uma lista única) — ao contrário dos da Home, que são âncoras de rolagem.
10. **Ordem da lista = ordem do canvas:** os meus, pendentes, com outro consultor, concluídos, somente teórica; por nome dentro de cada grupo, ignorando acentos.
11. **Score arredondado como no web** (`Math.round`), para os números baterem com o painel — inclusive o caso 69,6 → "Reavaliar · 70%", que o web também mostra.
12. **"Atribuir a mim" com 48dp**, não os 36dp do canvas: alvo mínimo do DS. Entra no DS como `AppCtaButton`, com o token `AppColors.ctaInk`.
13. **Divergências forçadas do canvas:** "em avaliação por outro consultor **desde 08:29**" sai (o backend não guarda quando a atribuição aconteceu); o cronômetro do "Avaliando · você" depende do rascunho local (Fase 4); a variante ADMIN do quadro `1f` (editar, consultores, adicionar participante, "3 consultores") é da Fase 6; o badge de sync é da Fase 4.
14. **Reavaliação em andamento** (em avaliação com avaliação anterior, como o `getDisplayStatus` do web): o chip vira "Reavaliando · você", e a nota de quem está com outro consultor vira "Em reavaliação com outro consultor.".
15. **Rotas definitivas agora, tela provisória atrás delas** (como previa o brainstorm): `/sessions/:id/participants/:pid/checklist` e `.../result`. As Fases 4 e 5 só trocam o builder.
16. **Cabeçalho e chips fixos, lista rolando embaixo**, como no canvas.
17. **Fatiamento:** a "tela 1.4" do desenho aprovado foi dividida em duas tasks (componentes do DS e tela), para o revisor poder aprovar uma sem a outra.

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app` (a mesma das Fases 0–2). Sem git worktree. Não criar branch, não fazer merge, não fazer push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem arquivos soltos que não são desta fase (backend de remoção da assinatura, `devtools_options.yaml`, arquivos na raiz) — **não tocar neles**.
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-09-23-mobile-fase-3-detalhe-da-sessao/`.

**Mobile (valem para todas as fases)**
- Flutter 3.41.6 / Dart 3.11.4. App **só Android**, APK sideload. Validação manual em **aparelho físico** (USB ou Wi-Fi, nunca emulador) — procedimento em `apps/mobile/simtc/README.md`.
- MVVM + Repository: um `ChangeNotifier` por tela via `provider`; tela nunca chama `Dio`/Drift direto; Repository por domínio devolvendo o `Result<T>` de `lib/utils/result.dart`.
- `ConnectivityService` único, criado no `MultiProvider` do app, nunca dentro de uma tela.
- Composição "quebra-cabeça": cada tela decompõe a UI em métodos privados `Widget _buildX()` combinados num `build()` enxuto.
- Design System: nenhum `Color(0xFF…)`, nenhum número mágico de espaçamento e nenhum `TextStyle` literal fora de `lib/ui/core/theme/`. Aritmética sobre tokens (`AppSpacing.sm + 2`) é o padrão já aceito no código. Cores por `AppColors`, espaçamento por `AppSpacing`/`AppRadius`, texto por `AppTypography`, ícones por `AppIcons`.
- Status nunca só por cor — sempre ícone + texto (`StatusChip`).
- Alvos de toque mínimos de 48dp (`AppSpacing.touchTarget`); skeleton no lugar de spinner em listas; estados de erro e vazio explícitos.
- Contratos reais apenas — nenhum campo ou endpoint não confirmado no código do backend.
- Arquivos gerados (`*.g.dart`) são versionados junto com a fonte.
- TDD: teste falhando pelo motivo certo → implementação → teste passando.

## Estado herdado (ponto de partida)

HEAD `058fb1e`, com os ajustes visuais da validação em campo **não commitados** em três arquivos (Task 0). `flutter analyze` limpo; **112 testes passam e 2 falham** (`sessions_screen_test.dart`: "bloco com mais de 10 sessões mostra 'Ver mais'…" e "quando o fallback não acha a seção…") — exatamente os 2 bugs que a Task 0 corrige.

Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| `Result<T>` | `lib/utils/result.dart` | `Success(data)` / `Failure(exception, [message])`, `isSuccess`, `dataOrNull` |
| `ApiClient` | `lib/data/services/api/api_client.dart` | `get<T>(path, {queryParameters})`, `post<T>(path, {Object? data})`; lança `ApiException` |
| `ApiException` | `lib/data/services/api/api_exception.dart` | `message`, `statusCode`, `isNetworkError`; `message` já traz o texto do backend (`{ message }` do NestJS) |
| `AppDatabase` | `lib/data/services/local/app_database.dart` | `schemaVersion => 2`, `onUpgrade` com `addColumn` dentro de `transaction`, `PRAGMA foreign_keys = ON` |
| Tabelas | `lib/data/services/local/tables.dart` | `Sessions`, `Participants` (FK `sessionId`), `AssessmentCategories`, `Infractions` (FK), `InfractionNotes` (FK) — as três do catálogo **já existem**, vazias |
| `TrainingSession` | `lib/data/models/training_session.dart` | `fromJson`, `fromRow`, `SessionStatus` (`label`, `wireValue`, `parse`) |
| `SessionRepository` | `lib/data/repositories/session_repository.dart` | `watchSessions()`, `watchLastSyncedAt()`, `syncAll()`; `_write` poda participantes antes das sessões |
| `AuthRepository` / `AuthUser` | `lib/data/repositories/auth_repository.dart`, `lib/data/models/auth_user.dart` | `currentUser` → `AuthUser?` com `name`, `isAdmin`, `consultantId?` (lido do JWT) |
| `ConnectivityService` | `lib/data/services/connectivity_service.dart` | `isOnline`, `isOffline`, `Stream<void> onReconnected` |
| `SessionsListViewModel` / `SessionsScreen` | `lib/ui/sessions/` | `refresh()` na abertura, no puxar e na reconexão; card com `onTap: null` |
| Widgets do DS | `lib/ui/core/widgets/` | `StatusChip(label, icon, tone, dashedBorder)`, `FilterChipBar(items, selectedIndex, onSelect)`, `InlineNotice(icon, message, tone)`, `ConnectivityBanner(isOffline, message)`, `SkeletonListItem`, `AppPrimaryButton(label, onPressed, isLoading, icon)` |
| `AppDependencies` | `lib/app_providers.dart` | fábrica única das dependências + `providers` |
| Rotas | `lib/router.dart` | `AppRoutes.splash/login/home/designSystem`, `createRouter(auth)` com redirect por `isAuthenticated` |

## Contrato real do backend, conferido em 23/09/2026

`GET /training-sessions/:id` (`training-sessions.service.ts`, `findTrainingSessionById`) — CONSULTANT só acessa se estiver vinculado (`403 "Você não tem acesso a este treinamento"`); inexistente → `404 "Sessão de treinamento não encontrada"`:

```jsonc
{
  "id": "clx...", "responsibleConsultantId": "c-resp",
  "city": "Itabira", "state": "MG",
  "date": "2026-09-12T00:00:00.000Z",          // data de calendário, nullable
  "status": "EM_ANDAMENTO", "notes": "Pátio 3 — ...",
  "company": { "id": "...", "name": "Bracell", "logoUrl": "https://..." },  // `company: true` → vem o logo
  "course": { "id": "...", "name": "Direção Defensiva — Veículo Pesado" },
  "responsibleConsultant": { ... }, "consultants": [ ... ],
  "participants": [
    {
      "id": "tp-1",                              // TrainingParticipant.id — é o que o assign recebe
      "participationType": "TEORICA_E_PRATICA",  // | SOMENTE_TEORICA
      "status": "EM_AVALIACAO",                  // PENDENTE | EM_AVALIACAO | APROVADO | NECESSITA_REAVALIACAO
      "assignedConsultantId": "c-2",
      "participant": { "name": "Ana Paula Ribeiro", "cpf": "04211899001", "email": "..." },
      "assessment": {                            // null até o primeiro sync de avaliação
        "consultantId": "c-1", "date": "...", "startTime": "2026-09-23T10:58:00.000Z",
        "endTime": "2026-09-23T11:12:00.000Z", "score": 86.4
      },
      "certificate": null,
      "assignedConsultant": { "id": "c-2", "name": "Rafael Lima" }
    }
  ]
}
```

`POST /practical-assessments/assign` com `{ "participantIds": ["tp-1"] }` → `201 { "assigned": 1 }`. Conflitos em `409` com a mensagem no corpo: "Participantes aprovados não podem ser reavaliados", "Um ou mais participantes já estão em avaliação com outro consultor", "Um ou mais participantes não foram encontrados", "Este usuário não possui um perfil de consultor associado…". **Não confere** vínculo do consultor com a sessão, status da sessão nem tipo de participação (ver Pendências).

`POST /training-sessions/:id/start` (sem corpo) → sessão com `status: "EM_ANDAMENTO"`. Só ADMIN ou o responsável; os demais recebem `403 "Somente o consultor responsável por este treinamento pode iniciá-lo ou concluí-lo"`.

`GET /assessment-categories` (ADMIN e CONSULTANT) → lista ordenada por `order`, com `infractions[]` (ordenadas por `order`) e `notes[]` (`{ id, noteType: "B"|"PM"|"M", comment, deduction }`) aninhadas.

## Mapa de Arquivos

### Novos

| Arquivo | Responsabilidade |
|---|---|
| `lib/data/models/session_participant.dart` | `SessionParticipant`, `ParticipationType`, `ParticipantStatus`, `maskCpf` |
| `lib/data/models/assessment_catalog.dart` | `CatalogCategory` > `CatalogInfraction` > `CatalogNote` |
| `lib/data/repositories/participant_repository.dart` | `syncSession`, `watchBySession`, `assign` |
| `lib/data/repositories/assessment_catalog_repository.dart` | `sync` (troca total), `loadCatalog`, log de conferência |
| `lib/ui/core/date_labels.dart` | `dayMonthYearLabel`, `momentLabel`, `offlineDataMessage` |
| `lib/ui/core/widgets/app_top_bar.dart` | barra das telas empilhadas (voltar + título + atalho) |
| `lib/ui/core/widgets/sync_status_indicator.dart` | indicador de sync (Home e detalhe) |
| `lib/ui/sessions/session_status_style.dart` | tom/ícone/traço de cada `SessionStatus` (Home e detalhe) |
| `lib/ui/session_detail/participant_filter.dart` | regras puras: situação, filtros, ordem, progresso, rótulos |
| `lib/ui/session_detail/session_detail_viewmodel.dart` | estado da tela 1.4 |
| `lib/ui/session_detail/participant_row.dart` | linha de participante |
| `lib/ui/session_detail/session_detail_screen.dart` | tela 1.4 |
| `lib/ui/evaluation/evaluation_placeholder_screen.dart` | tela provisória do checklist/resultado |
| `test/data/models/session_participant_test.dart` | parsing, máscara, `fromRow` |
| `test/data/repositories/participant_repository_test.dart` | sync, poda, assign |
| `test/data/repositories/assessment_catalog_repository_test.dart` | troca total, falhas, log |
| `test/ui/core/date_labels_test.dart` | rótulos de data |
| `test/ui/session_detail/participant_filter_test.dart` | regras puras |
| `test/ui/session_detail/session_detail_viewmodel_test.dart` | VM |
| `test/ui/session_detail/session_detail_screen_test.dart` | tela + navegação pelas rotas reais |

### Modificados

| Arquivo | O que muda |
|---|---|
| `lib/ui/sessions/session_filter.dart` | Task 0: `_buildWeekBlock` vira `_buildDayBlock(id: ...)` |
| `lib/ui/sessions/sessions_screen.dart` | Task 0: tokens + fim de scroll; Task 4: catálogo na VM; Task 7: toque no card, `SyncStatusIndicator`, `offlineDataMessage`, `SessionStatusStyle` |
| `lib/ui/core/widgets/session_card.dart` | Task 0: comentário (traço só em cima) |
| `lib/ui/core/theme/app_typography.dart` | Task 0: `sectionTitle`; Task 6: `detailTitle`, `buttonCompact`, `code` |
| `lib/data/services/local/tables.dart` | Task 1: 4 colunas novas |
| `lib/data/services/local/app_database.dart` (+ `.g.dart`) | Task 1: `schemaVersion` 3 + passo 2→3 |
| `lib/data/models/training_session.dart` | Task 1: `responsibleConsultantId`, `participantsSyncedAt` |
| `lib/data/repositories/session_repository.dart` | Task 1: logo fora do upsert + responsável; Task 3: `watchSession`, `start` |
| `lib/ui/sessions/sessions_list_viewmodel.dart` | Task 4: catálogo no `refresh()` |
| `lib/app_providers.dart` | Task 4: catálogo; Task 7: participantes |
| `lib/ui/core/theme/app_colors.dart`, `app_icons.dart` | Task 6: `ctaInk`; ícones novos |
| `lib/ui/core/widgets/app_buttons.dart` | Task 6: `AppCtaButton` |
| `lib/router.dart` | Task 7: rotas novas + `initialLocation` opcional |
| `test/...` existentes | `app_database_test`, `training_session_test`, `session_repository_test`, `session_filter_test`, `sessions_list_viewmodel_test`, `sessions_screen_test`, `form_widgets_test`, `display_widgets_test` |

Todos os caminhos de código são relativos a `apps/mobile/simtc/`; os comandos rodam a partir dessa pasta.

---

## Task 0: Commitar os ajustes visuais da Home e corrigir os 2 bugs que eles expuseram

Os ajustes no working tree são decisão do usuário depois da validação em campo — **não reverta nenhum**: traço só em cima do card (0,8), Concluídas com traço neutro, cabeçalho de seção com linha inferior e padding maior, sem espaço entre os cards, e Concluídas agrupada por dia. Esta task só corrige o que eles quebraram e troca os números soltos por tokens, sem mudar o visual.

**Files:**
- Modify: `lib/ui/sessions/session_filter.dart` (`SessionDayGroup`, `SessionBlock.dayGroups`, `_buildWeekBlock`, `buildSections`)
- Modify: `lib/ui/sessions/sessions_screen.dart` (`_updateActiveChipFromScroll`, `_buildSection`, `_buildDayGroup`)
- Modify: `lib/ui/core/widgets/session_card.dart` (comentário da classe)
- Modify: `lib/ui/core/theme/app_typography.dart` (token `sectionTitle`)
- Test: `test/ui/sessions/session_filter_test.dart`
- Test (já existentes, hoje falhando): `test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces: `AppTypography.sectionTitle` (Inter 13, w700, altura 1.3, `AppColors.text3`) — a Task 7 usa no cabeçalho "Participantes". `_buildDayBlock` é privado.

- [ ] **Step 1: Conferir o ponto de partida**

Run: `git status --short -- lib test`
Esperado: ` M lib/ui/core/widgets/session_card.dart`, ` M lib/ui/sessions/session_filter.dart`, ` M lib/ui/sessions/sessions_screen.dart` (e nada mais em `lib`/`test`).

Run: `flutter test test/ui/sessions/sessions_screen_test.dart`
Esperado: 2 falhas — "bloco com mais de 10 sessões mostra "Ver mais", que revela o resto" e "quando o fallback não acha a seção nem depois do salto, o chip volta a marcar o filtro que estava ativo antes do toque". As duas procuram a key `ver-mais-concluidas`, que sumiu: o bloco Concluídas hoje é montado por `_buildWeekBlock`, que fixa `id: SessionBlockId.semana`.

- [ ] **Step 2: Escrever o teste que falha**

No fim do `main()` de `test/ui/sessions/session_filter_test.dart`:

```dart
  test(
      'Concluídas divide por dia, como "Esta semana", mas pagina com o id do '
      'próprio bloco', () {
    final sections = buildSections([
      session('c1', status: SessionStatus.concluido, date: DateTime(2026, 9, 10, 8)),
      session('c2', status: SessionStatus.concluido, date: DateTime(2026, 9, 10, 14)),
      session('c3', status: SessionStatus.concluido, date: DateTime(2026, 9, 12, 8)),
    ], agora, const {});
    final block = sections.last.blocks.single;

    // O "Ver mais" da tela chama `revealMore(block.id)`: com o id de "Esta
    // semana" aqui, o toque em Concluídas revelaria as sessões da semana.
    expect(block.id, SessionBlockId.concluidas);
    expect(
      block.dayGroups.map((g) => g.title).toList(),
      ['Qui, 10 set', 'Sáb, 12 set'],
    );
    expect(idsOf(block), ['c1', 'c2', 'c3']);
    expect(block.dayGroups.first.sessions, hasLength(2));
  });
```

- [ ] **Step 3: Rodar e confirmar que falha pelo motivo certo**

Run: `flutter test test/ui/sessions/session_filter_test.dart`
Esperado: FAIL no teste novo — `Expected: SessionBlockId:<SessionBlockId.concluidas>`, `Actual: SessionBlockId:<SessionBlockId.semana>`.

- [ ] **Step 4: Dar ao builder por dia o id de quem chama**

Em `lib/ui/sessions/session_filter.dart`, trocar o comentário de `SessionDayGroup`:

```dart
/// Um agrupamento visual dentro de um bloco. Só tem título em "Esta semana"
/// (um por dia); nos demais blocos é um grupo único sem título.
```

por:

```dart
/// Um agrupamento visual dentro de um bloco. Tem título nos blocos divididos
/// por dia ("Esta semana" e "Concluídas"); em "Hoje" é um grupo único sem
/// título.
```

Trocar o comentário de `SessionBlock.dayGroups`:

```dart
  /// As sessões do bloco, já cortadas em `visibleCount` e organizadas em
  /// grupos por dia (um único grupo sem título, exceto em "Esta semana").
```

por:

```dart
  /// As sessões do bloco, já cortadas em `visibleCount` e organizadas em
  /// grupos por dia (um único grupo sem título em "Hoje"; um por dia em "Esta
  /// semana" e "Concluídas").
```

Trocar o cabeçalho de `_buildWeekBlock`:

```dart
/// O bloco de "Esta semana": as sessões truncadas se dividem em um
/// `SessionDayGroup` por dia.
SessionBlock _buildWeekBlock({
  required List<TrainingSession> all,
  required int visibleCount,
}) {
```

por:

```dart
/// Um bloco dividido por dia ("Esta semana" e "Concluídas"): as sessões
/// truncadas viram um `SessionDayGroup` por dia. O `id` vem de quem chama —
/// é ele que o "Ver mais" usa para saber qual bloco revelar.
SessionBlock _buildDayBlock({
  required SessionBlockId id,
  required List<TrainingSession> all,
  required int visibleCount,
}) {
```

No `return` da mesma função, trocar `    id: SessionBlockId.semana,` por `    id: id,`.

Em `buildSections`, trocar as duas chamadas:

```dart
  final semanaBlock = _buildWeekBlock(
    all: daSemana,
    visibleCount: _visibleCountFor(visibleCounts, SessionBlockId.semana),
  );

  final concluidasBlock = _buildWeekBlock(
    all: concluidas,
    visibleCount: _visibleCountFor(visibleCounts, SessionBlockId.concluidas),
  );
```

por:

```dart
  final semanaBlock = _buildDayBlock(
    id: SessionBlockId.semana,
    all: daSemana,
    visibleCount: _visibleCountFor(visibleCounts, SessionBlockId.semana),
  );

  final concluidasBlock = _buildDayBlock(
    id: SessionBlockId.concluidas,
    all: concluidas,
    visibleCount: _visibleCountFor(visibleCounts, SessionBlockId.concluidas),
  );
```

- [ ] **Step 5: Rodar os testes de sessões**

Run: `flutter test test/ui/sessions/`
Esperado: `session_filter_test.dart` inteiro passa; em `sessions_screen_test.dart` o teste do "Ver mais" passa e **só o do fallback continua falhando**, agora na linha que espera o chip "Concluídas" destacado depois de `position.jumpTo(position.maxScrollExtent)` (`Expected: true`, `Actual: <false>`).

O motivo: com 40 concluídas reveladas e um subtítulo por dia, o cabeçalho de Concluídas fica bem acima do `cacheExtent` (5000px) quando a lista está no fim — ele nem está montado, e a regra de fim de scroll só olha seções montadas. Nenhuma está, e o chip cai em "Hoje".

- [ ] **Step 6: No fim do scroll, a seção ativa é sempre a última**

Em `lib/ui/sessions/sessions_screen.dart`, dentro de `_updateActiveChipFromScroll`, trocar:

```dart
    // No fim absoluto do scroll, a última seção ("Concluídas") pode ser curta
    // demais para o cabeçalho dela cruzar a linha de ativação — não há
    // conteúdo abaixo dela pra "empurrá-la" pra cima do topo da área rolável.
    // Sem este caso especial, o chip ficaria preso na seção anterior mesmo
    // com "Concluídas" inteira na tela. Aqui o critério vira só "está
    // montada", não "cruzou a linha".
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 1) {
      for (final filter in SessionFilter.values.reversed) {
        final box = sectionBox(filter);
        if (box != null && box.attached) {
          active = filter;
          break;
        }
      }
    }
```

por:

```dart
    // No fim absoluto do scroll, a seção na tela é sempre a última
    // ("Concluídas" — as três existem sempre, nesta ordem). A geometria não
    // serve aqui: se ela for curta, o cabeçalho nunca cruza a linha de
    // ativação (não há conteúdo abaixo para empurrá-lo); se for longa (dezenas
    // de concluídas, agora com um subtítulo por dia), o cabeçalho sai do
    // cacheExtent e nem está montado. Nos dois casos o chip ficaria preso numa
    // seção anterior.
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 1) {
      active = SessionFilter.values.last;
    }
```

- [ ] **Step 7: Trocar os números soltos por tokens, sem mudar o visual**

Em `lib/ui/core/theme/app_typography.dart`, logo depois de `meta`:

```dart
  /// Cabeçalho de seção de lista ("Hoje · 23 set", "Concluídas")
  static TextStyle get sectionTitle =>
      _inter(size: 13, weight: FontWeight.w700, height: 1.3, color: AppColors.text3);
```

É exatamente o que o ajuste em campo produzia (`meta` com tamanho 13 e negrito). Em `lib/ui/sessions/sessions_screen.dart`, em `_buildSection`, trocar:

```dart
          child: Text(
            section.title,
            style: AppTypography.meta.copyWith(
              fontSize: 13, fontWeight: FontWeight.bold
              ),
          ),
```

por:

```dart
          child: Text(section.title, style: AppTypography.sectionTitle),
```

Em `_buildDayGroup`, trocar o `10` do padding pelo equivalente em tokens:

```dart
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm + 2,
            AppSpacing.xl,
            AppSpacing.xs,
          ),
```

(`AppSpacing.lg - 1` no mesmo arquivo já é aritmética de token — fica como está.)

Em `lib/ui/core/widgets/session_card.dart`, o comentário da classe ficou desatualizado com a borda só em cima. Trocar:

```dart
/// Linha de sessão da Home: empresa, curso, metadados, chip de status e, quando
/// houver, o progresso de avaliação. O traço superior e inferior usa a cor do
/// status, como no canvas.
```

por:

```dart
/// Linha de sessão da Home: empresa, curso, metadados, chip de status e, quando
/// houver, o progresso de avaliação. O traço superior usa a cor do status.
```

- [ ] **Step 8: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **115 testes passando** (os 114 de antes, agora todos verdes, mais o novo).

- [ ] **Step 9: Commit**

```bash
git add lib/ui/core/widgets/session_card.dart lib/ui/sessions/session_filter.dart lib/ui/sessions/sessions_screen.dart lib/ui/core/theme/app_typography.dart test/ui/sessions/session_filter_test.dart
git commit -m "fix(mobile): conclui os ajustes visuais da lista de sessoes validados em campo"
```

---

## Task 1: Esquema 3 do cache — responsável, sync dos participantes e dados de avaliação

**Files:**
- Modify: `lib/data/services/local/tables.dart` (`Sessions`, `Participants`)
- Modify: `lib/data/services/local/app_database.dart` (`schemaVersion`, `migration`)
- Modify (gerado): `lib/data/services/local/app_database.g.dart`
- Modify: `lib/data/models/training_session.dart`
- Modify: `lib/data/repositories/session_repository.dart` (`_write`)
- Test: `test/data/services/local/app_database_test.dart`
- Test: `test/data/models/training_session_test.dart`
- Test: `test/data/repositories/session_repository_test.dart`

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces:
  - `Sessions.responsibleConsultantId` (`TextColumn`, anulável) e `Sessions.participantsSyncedAt` (`DateTimeColumn`, anulável); `Participants.assessedByConsultantId` (`TextColumn`, anulável) e `Participants.assessedAt` (`DateTimeColumn`, anulável). Os companions ganham os parâmetros `Value<...>` de mesmo nome; o row `Session`/`Participant` ganha os campos.
  - `TrainingSession.responsibleConsultantId` (`String?`, lido de `json['responsibleConsultantId']` e do row) e `TrainingSession.participantsSyncedAt` (`DateTime?`, só do row). Ambos opcionais no construtor.
  - `SessionRepository.syncAll()` não grava mais `companyLogoUrl` (coluna ausente = intocada no upsert) e grava `responsibleConsultantId`.

- [ ] **Step 1: Escrever os testes que falham — migração**

Em `test/data/services/local/app_database_test.dart`, trocar o comentário de `_FailOnNthAlterTableDelegate`:

```dart
/// Derruba a enésima instrução `ALTER TABLE` antes que ela chegue ao SQLite —
/// simula o processo sendo morto no meio da migração 1→2 (a `addColumn` da
/// `AppDatabase` real gera três `ALTER TABLE`, um por coluna nova).
```

por:

```dart
/// Derruba a enésima instrução `ALTER TABLE` antes que ela chegue ao SQLite —
/// simula o processo sendo morto no meio de uma migração (cada `addColumn` da
/// `AppDatabase` real gera um `ALTER TABLE`).
```

Logo antes de `void main() {`, acrescentar as tabelas como cada fase as deixou. Os testes de migração precisam de `participants` no banco antigo porque o passo 2→3 mexe nela — e nos aparelhos ela existe, porque a Fase 1 criou o esquema inteiro:

```dart
/// A tabela `sessions` exatamente como a Fase 1 a criou (esquema 1).
const String _sessionsV1 = '''
  CREATE TABLE IF NOT EXISTS sessions (
    id TEXT NOT NULL,
    company_name TEXT NOT NULL,
    company_logo_url TEXT NULL,
    course_name TEXT NOT NULL,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    date INTEGER NULL,
    status TEXT NOT NULL,
    notes TEXT NULL,
    cached_at INTEGER NOT NULL,
    PRIMARY KEY (id)
  )
''';

/// A tabela `sessions` como a Fase 2 a deixou (esquema 2): a do esquema 1 mais
/// as três contagens.
const String _sessionsV2 = '''
  CREATE TABLE IF NOT EXISTS sessions (
    id TEXT NOT NULL,
    company_name TEXT NOT NULL,
    company_logo_url TEXT NULL,
    course_name TEXT NOT NULL,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    date INTEGER NULL,
    status TEXT NOT NULL,
    notes TEXT NULL,
    total_participants INTEGER NOT NULL DEFAULT 0,
    assessable_participants INTEGER NOT NULL DEFAULT 0,
    assessed_participants INTEGER NOT NULL DEFAULT 0,
    cached_at INTEGER NOT NULL,
    PRIMARY KEY (id)
  )
''';

/// A tabela `participants` como as Fases 1 e 2 a deixaram — igual nos
/// esquemas 1 e 2, porque só a Fase 3 mexe nela.
const String _participantsV1 = '''
  CREATE TABLE IF NOT EXISTS participants (
    id TEXT NOT NULL,
    session_id TEXT NOT NULL REFERENCES sessions (id),
    name TEXT NOT NULL,
    cpf TEXT NOT NULL,
    email TEXT NULL,
    participation_type TEXT NOT NULL,
    status TEXT NOT NULL,
    assigned_consultant_id TEXT NULL,
    assigned_consultant_name TEXT NULL,
    score REAL NULL,
    cached_at INTEGER NOT NULL,
    PRIMARY KEY (id)
  )
''';
```

Substituir o teste inteiro `'migra do esquema 1 para o 2 mantendo as sessões já cacheadas'` por estes dois:

```dart
  test('migra do esquema 1 para o atual mantendo as sessões já cacheadas',
      () async {
    final directory = Directory.systemTemp.createTempSync('simtc_migracao');
    final file = File('${directory.path}/simtc.sqlite');

    final migrated = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          // O banco como a Fase 1 o criou: todas as tabelas existem (a Fase 1
          // criou o esquema inteiro), mas `sessions` ainda sem as contagens e
          // `participants` sem as colunas da Fase 3.
          raw.execute(_sessionsV1);
          raw.execute(_participantsV1);
          raw.execute('''
            INSERT INTO sessions (id, company_name, course_name, city, state, status, cached_at)
            VALUES ('sess-antiga', 'Bracell Celulose', 'Direção Preventiva',
                    'Lençóis Paulista', 'SP', 'PLANEJADO', 0)
          ''');
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );

    addTearDown(() async {
      await migrated.close();
      directory.deleteSync(recursive: true);
    });

    final row = await migrated.select(migrated.sessions).getSingle();

    expect(row.id, 'sess-antiga');
    expect(row.companyName, 'Bracell Celulose');
    expect(row.totalParticipants, 0);
    expect(row.assessableParticipants, 0);
    expect(row.assessedParticipants, 0);
    expect(row.responsibleConsultantId, isNull);
    expect(row.participantsSyncedAt, isNull);
  });

  test(
      'migra do esquema 2 para o 3 mantendo sessões e participantes já '
      'cacheados', () async {
    final directory = Directory.systemTemp.createTempSync('simtc_migracao_v3');
    final file = File('${directory.path}/simtc.sqlite');

    final migrated = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(_sessionsV2);
          raw.execute(_participantsV1);
          raw.execute('''
            INSERT INTO sessions (id, company_name, course_name, city, state, status,
                                  total_participants, assessable_participants,
                                  assessed_participants, cached_at)
            VALUES ('sess-1', 'Bracell Celulose', 'Direção Preventiva',
                    'Lençóis Paulista', 'SP', 'EM_ANDAMENTO', 5, 4, 2, 0)
          ''');
          raw.execute('''
            INSERT INTO participants (id, session_id, name, cpf, participation_type,
                                      status, cached_at)
            VALUES ('tp-1', 'sess-1', 'Ana Paula Ribeiro', '042.118.***-**',
                    'TEORICA_E_PRATICA', 'PENDENTE', 0)
          ''');
          raw.execute('PRAGMA user_version = 2');
        },
      ),
    );

    addTearDown(() async {
      await migrated.close();
      directory.deleteSync(recursive: true);
    });

    final session = await migrated.select(migrated.sessions).getSingle();
    expect(session.totalParticipants, 5,
        reason: 'as contagens da Fase 2 sobrevivem à migração');
    expect(session.responsibleConsultantId, isNull);
    expect(session.participantsSyncedAt, isNull);

    final participant =
        await migrated.select(migrated.participants).getSingle();
    expect(participant.name, 'Ana Paula Ribeiro');
    expect(participant.assessedByConsultantId, isNull);
    expect(participant.assessedAt, isNull);
  });
```

No teste `'onUpgrade é atômico: …'`, trocar o `rawSetup()`:

```dart
    DatabaseSetup rawSetup() => (raw) {
          raw.execute('''
            CREATE TABLE IF NOT EXISTS sessions (
              id TEXT NOT NULL,
              company_name TEXT NOT NULL,
              company_logo_url TEXT NULL,
              course_name TEXT NOT NULL,
              city TEXT NOT NULL,
              state TEXT NOT NULL,
              date INTEGER NULL,
              status TEXT NOT NULL,
              notes TEXT NULL,
              cached_at INTEGER NOT NULL,
              PRIMARY KEY (id)
            )
          ''');
          raw.execute('PRAGMA user_version = 1');
        };
```

por:

```dart
    DatabaseSetup rawSetup() => (raw) {
          raw.execute(_sessionsV1);
          raw.execute(_participantsV1);
          raw.execute('PRAGMA user_version = 1');
        };
```

e o comentário de `openAndCaptureError` dentro dele:

```dart
    /// Abre o `AppDatabase` real — o getter `migration` de produção, sem
    /// nenhuma sobrescrita — sobre um `DatabaseDelegate` que derruba a 2ª
    /// instrução `ALTER TABLE` (a migração real faz 3, uma por coluna nova).
    /// A 1ª tem sucesso, a 2ª nunca chega ao SQLite. A abertura (`select`)
    /// dispara a migração de forma preguiçosa.
```

por:

```dart
    /// Abre o `AppDatabase` real — o getter `migration` de produção, sem
    /// nenhuma sobrescrita — sobre um `DatabaseDelegate` que derruba a 2ª
    /// instrução `ALTER TABLE` (a partir do esquema 1 a migração faz sete:
    /// três da Fase 2 e quatro da Fase 3). A 1ª tem sucesso, a 2ª nunca chega
    /// ao SQLite. A abertura (`select`) dispara a migração de forma preguiçosa.
```

No fim do `main()`, o teste de atomicidade do passo novo:

```dart
  test(
      'a migração 2→3 também é atômica: uma falha nas colunas de participante '
      'desfaz as de sessão', () async {
    final directory =
        Directory.systemTemp.createTempSync('simtc_migracao_v3_atomica');
    final file = File('${directory.path}/simtc.sqlite');
    addTearDown(() => directory.deleteSync(recursive: true));

    DatabaseSetup rawSetup() => (raw) {
          raw.execute(_sessionsV2);
          raw.execute(_participantsV1);
          raw.execute('PRAGMA user_version = 2');
        };

    /// A migração 2→3 faz quatro `ALTER TABLE`: dois em `sessions` e dois em
    /// `participants`. Derrubar o 3º deixa as duas colunas de sessão já
    /// criadas — só a transação de `onUpgrade` impede que elas fiquem.
    Future<Object> openAndCaptureError() async {
      final realDelegate = NativeDatabase(file, setup: rawSetup()).delegate;
      final executor =
          DelegatedDatabase(_FailOnNthAlterTableDelegate(realDelegate, 3));
      final db = AppDatabase(executor);
      try {
        await db.select(db.sessions).get();
        fail('esperava que a migração falhasse de propósito');
      } catch (error) {
        return error;
      } finally {
        await db.close();
      }
    }

    final firstError = await openAndCaptureError();
    expect('$firstError', contains('interrompida de propósito'));

    final secondError = await openAndCaptureError();
    expect('$secondError', contains('interrompida de propósito'),
        reason: 'sem a transação, a 2ª tentativa quebraria com "duplicate '
            'column name: responsible_consultant_id"');
  });
```

- [ ] **Step 2: Escrever os testes que falham — modelo e repositório**

No fim do `main()` de `test/data/models/training_session_test.dart`:

```dart
  test('lê o consultor responsável da sessão', () {
    final session = TrainingSession.fromJson({
      ...json(),
      'responsibleConsultantId': 'c-resp',
    });

    expect(session.responsibleConsultantId, 'c-resp');
    expect(session.participantsSyncedAt, isNull,
        reason: 'a data de sync dos participantes só existe no cache');
  });
```

Em `test/data/repositories/session_repository_test.dart`, acrescentar o import (o `hide` evita o conflito do `isNull` deprecated do drift com o matcher, como em `app_database_test.dart`):

```dart
import 'package:drift/drift.dart' hide isNull;
```

logo antes de `import 'package:drift/native.dart';`, e no fim do `main()`:

```dart
  test(
      'sync da lista grava o responsável e não apaga o logo que o detalhe '
      'gravou', () async {
    // O detalhe da sessão (Fase 3) já gravou o logo e a data de sync dos
    // participantes; a listagem não traz nenhum dos dois.
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 's1',
            companyName: 'Bracell Celulose',
            companyLogoUrl: const Value('https://cdn.simtc/logos/bracell.png'),
            courseName: 'Direção Preventiva',
            city: 'Lençóis Paulista',
            state: 'SP',
            status: 'PLANEJADO',
            participantsSyncedAt: Value(DateTime(2026, 9, 22, 8)),
            cachedAt: DateTime(2026, 9, 22, 8),
          ),
        );

    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([
              {...sessionJson('s1'), 'responsibleConsultantId': 'c-resp'},
            ], pageNumber: 1, totalPages: 1));

    final result = await repository.syncAll();

    expect(result.isSuccess, isTrue);
    final row = await db.select(db.sessions).getSingle();
    expect(row.responsibleConsultantId, 'c-resp');
    expect(row.companyLogoUrl, 'https://cdn.simtc/logos/bracell.png');
    expect(row.participantsSyncedAt, DateTime(2026, 9, 22, 8));
  });
```

- [ ] **Step 3: Rodar e confirmar que falham**

Run: `flutter test test/data/services/local/app_database_test.dart test/data/models/training_session_test.dart test/data/repositories/session_repository_test.dart`
Esperado: FAIL na compilação — `responsibleConsultantId`, `participantsSyncedAt`, `assessedByConsultantId` e `assessedAt` não existem.

- [ ] **Step 4: Acrescentar as colunas**

Em `lib/data/services/local/tables.dart`, em `class Sessions`, logo antes de `cachedAt`:

```dart
  /// `Consultant.id` do responsável — decide quem vê "Iniciar sessão".
  TextColumn get responsibleConsultantId => text().nullable()();

  /// Quando os participantes desta sessão foram baixados pela última vez.
  /// Nulo = nunca baixados, o que a tela distingue de "baixados e vazia".
  DateTimeColumn get participantsSyncedAt => dateTime().nullable()();
```

Em `class Participants`, logo depois de `score`:

```dart
  /// `PracticalAssessment.consultantId`: quem fez a avaliação — filtro "Meus".
  TextColumn get assessedByConsultantId => text().nullable()();

  /// Fim (ou início) da avaliação sincronizada — a linha "hoje 08:12".
  DateTimeColumn get assessedAt => dateTime().nullable()();
```

- [ ] **Step 5: Subir a versão do esquema e escrever o passo 2→3**

Em `lib/data/services/local/app_database.dart`, substituir `schemaVersion` e o `onUpgrade` (o `beforeOpen` fica como está). O `transaction()` passa a envolver **todos** os passos: um aparelho que ainda esteja no esquema 1 migra 1→2→3 de uma vez, e uma falha no meio precisa desfazer tudo.

```dart
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // `onUpgrade` do drift não roda em transação por conta própria — o
          // `user_version` só é gravado depois que ele termina (ver
          // `_runMigrations` em drift/src/runtime/executor/helpers/
          // engines.dart). Sem este `transaction()`, o Android matando o app
          // entre dois `addColumn` deixaria o arquivo com a versão antiga e
          // uma coluna já criada; na abertura seguinte o `addColumn`
          // estouraria "duplicate column name" e o app não abriria o banco
          // nunca mais. Uma transação só para todos os passos torna a
          // migração tudo-ou-nada — inclusive para quem pula do esquema 1
          // direto para o 3.
          await transaction(() async {
            if (from < 2) {
              // Fase 2: contagens de participantes no card da Home. São cache
              // — entram com 0 e o primeiro sync preenche. Migrar por
              // `addColumn` (e não recriando a tabela) preserva a lista que o
              // consultor já tem no aparelho, que é o que ele vê offline.
              await m.addColumn(sessions, sessions.totalParticipants);
              await m.addColumn(sessions, sessions.assessableParticipants);
              await m.addColumn(sessions, sessions.assessedParticipants);
            }
            if (from < 3) {
              // Fase 3: quem pode iniciar a sessão, quando os participantes
              // dela foram baixados, e quem avaliou cada participante e
              // quando. Tudo anulável — o próximo sync preenche.
              await m.addColumn(sessions, sessions.responsibleConsultantId);
              await m.addColumn(sessions, sessions.participantsSyncedAt);
              await m.addColumn(
                participants,
                participants.assessedByConsultantId,
              );
              await m.addColumn(participants, participants.assessedAt);
            }
          });
        },
```

- [ ] **Step 6: Regerar o código do Drift**

Run: `dart run build_runner build --delete-conflicting-outputs`
Esperado: `app_database.g.dart` regravado, sem erro.

- [ ] **Step 7: Levar os campos novos ao modelo**

Em `lib/data/models/training_session.dart`, no construtor, depois de `this.notes,`:

```dart
    this.responsibleConsultantId,
    this.participantsSyncedAt,
```

Depois do campo `assessedParticipants`:

```dart
  /// `Consultant.id` do responsável pela sessão. Só ele (ou um ADMIN) pode
  /// iniciá-la — é o que o backend confere em `POST /:id/start`.
  final String? responsibleConsultantId;

  /// Quando os participantes desta sessão foram baixados pela última vez.
  /// Só existe no cache (quem grava é o detalhe da sessão); nulo quer dizer
  /// "nunca baixados", que a tela 1.4 distingue de "baixados e sem ninguém".
  final DateTime? participantsSyncedAt;
```

No `return` de `fromJson`, depois de `assessedParticipants: _asInt(stats['assessed']),`:

```dart
      responsibleConsultantId: json['responsibleConsultantId'] as String?,
```

No `return` de `fromRow`, depois de `assessedParticipants: row.assessedParticipants,`:

```dart
      responsibleConsultantId: row.responsibleConsultantId,
      participantsSyncedAt: row.participantsSyncedAt,
```

- [ ] **Step 8: O sync da lista para de apagar o logo**

Em `lib/data/repositories/session_repository.dart`, dentro de `_write`, trocar o início do laço:

```dart
      for (final session in sessions) {
        await _db.into(_db.sessions).insertOnConflictUpdate(
              SessionsCompanion.insert(
                id: session.id,
                companyName: session.companyName,
                companyLogoUrl: Value(session.companyLogoUrl),
                courseName: session.courseName,
```

por:

```dart
      for (final session in sessions) {
        // `companyLogoUrl` fica de fora de propósito: a listagem não traz o
        // logo (só o detalhe da sessão traz), e um `Value(null)` aqui apagaria
        // a cada sync da Home o logo que o detalhe gravou. No upsert, coluna
        // ausente do companion não é tocada. Pelo mesmo motivo,
        // `participantsSyncedAt` também fica de fora.
        await _db.into(_db.sessions).insertOnConflictUpdate(
              SessionsCompanion.insert(
                id: session.id,
                companyName: session.companyName,
                courseName: session.courseName,
```

e, no mesmo companion, trocar:

```dart
                assessedParticipants: Value(session.assessedParticipants),
                cachedAt: now,
```

por:

```dart
                assessedParticipants: Value(session.assessedParticipants),
                responsibleConsultantId: Value(session.responsibleConsultantId),
                cachedAt: now,
```

A semântica de "coluna ausente fica intocada" foi conferida no código do drift 2.31 (`insertOnConflictUpdate`: "columns from the old row that are not present on entity are unchanged").

- [ ] **Step 9: Rodar os testes e confirmar que passam**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **119 testes passando**. Se o `app_database_test.dart` imprimir stack traces do drift sobre várias instâncias de banco, é o aviso de debug que os testes de migração já produziam — não é falha.

- [ ] **Step 10: Commit**

```bash
git add lib/data/services/local/tables.dart lib/data/services/local/app_database.dart lib/data/services/local/app_database.g.dart lib/data/models/training_session.dart lib/data/repositories/session_repository.dart test/data/services/local/app_database_test.dart test/data/models/training_session_test.dart test/data/repositories/session_repository_test.dart
git commit -m "feat(mobile): esquema 3 do cache com responsavel e dados de avaliacao"
```

---

## Task 2: Modelo `SessionParticipant`

**Files:**
- Create: `lib/data/models/session_participant.dart`
- Test: `test/data/models/session_participant_test.dart`

**Interfaces:**
- Consumes: `Participant` (row gerado na Task 1, com `assessedByConsultantId` e `assessedAt`).
- Produces:
  - `enum ParticipationType { somenteTeorica, teoricaEPratica }` com `wireValue` e `static parse(String?)` (desconhecido → `teoricaEPratica`).
  - `enum ParticipantStatus { pendente, emAvaliacao, aprovado, necessitaReavaliacao }` com `wireValue` e `static parse(String?)` (desconhecido → `pendente`).
  - `String maskCpf(String? raw)` → `'042.118.***-**'`, ou `'***.***.***-**'` se não houver 11 dígitos.
  - `class SessionParticipant` com `id`, `sessionId`, `name`, `maskedCpf`, `participationType`, `status`, `assignedConsultantId?`, `assignedConsultantName?`, `score?` (0–100), `assessedByConsultantId?`, `assessedAt?`; getters `isAssessed` e `hasPreviousAssessment` (`score != null`); `factory fromJson(Map<String, dynamic> json, {required String sessionId})` e `factory fromRow(Participant row)`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/data/models/session_participant_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/services/local/app_database.dart';

void main() {
  /// Um item de `participants[]` como `GET /training-sessions/:id` devolve
  /// (include de `participant`, `assessment`, `certificate` e
  /// `assignedConsultant`, conferido em `training-sessions.service.ts`).
  Map<String, dynamic> json({
    String status = 'PENDENTE',
    String participationType = 'TEORICA_E_PRATICA',
    String cpf = '04211899001',
    Map<String, dynamic>? assessment,
    Map<String, dynamic>? assignedConsultant,
  }) {
    return {
      'id': 'tp-1',
      'trainingSessionId': 'sess-1',
      'participantId': 'p-1',
      'participationType': participationType,
      'status': status,
      'assignedConsultantId': assignedConsultant?['id'],
      'registeredAt': '2026-09-20T10:00:00.000Z',
      'participant': {
        'id': 'p-1',
        'name': 'Ana Paula Ribeiro',
        'cpf': cpf,
        'email': 'ana@exemplo.com',
      },
      'assessment': assessment,
      'certificate': null,
      'assignedConsultant': assignedConsultant,
    };
  }

  test('lê o cadastro e guarda o CPF já mascarado', () {
    final p = SessionParticipant.fromJson(json(), sessionId: 'sess-1');

    expect(p.id, 'tp-1');
    expect(p.sessionId, 'sess-1');
    expect(p.name, 'Ana Paula Ribeiro');
    expect(p.maskedCpf, '042.118.***-**');
    expect(p.participationType, ParticipationType.teoricaEPratica);
    expect(p.status, ParticipantStatus.pendente);
    expect(p.score, isNull);
    expect(p.isAssessed, isFalse);
  });

  test('lê quem está com o participante em avaliação', () {
    final p = SessionParticipant.fromJson(
      json(
        status: 'EM_AVALIACAO',
        assignedConsultant: {'id': 'c-2', 'name': 'Rafael Lima'},
      ),
      sessionId: 'sess-1',
    );

    expect(p.status, ParticipantStatus.emAvaliacao);
    expect(p.assignedConsultantId, 'c-2');
    expect(p.assignedConsultantName, 'Rafael Lima');
  });

  test('lê score, avaliador e momento da avaliação sincronizada', () {
    final p = SessionParticipant.fromJson(
      json(
        status: 'APROVADO',
        assessment: {
          'id': 'pa-1',
          'consultantId': 'c-1',
          'date': '2026-09-23T00:00:00.000Z',
          'startTime': '2026-09-23T10:58:00.000Z',
          'endTime': '2026-09-23T11:12:00.000Z',
          'score': 86.4,
        },
      ),
      sessionId: 'sess-1',
    );

    expect(p.score, 86.4);
    expect(p.assessedByConsultantId, 'c-1');
    expect(p.assessedAt, DateTime.parse('2026-09-23T11:12:00.000Z'));
    expect(p.isAssessed, isTrue);
    expect(p.hasPreviousAssessment, isTrue);
  });

  test('sem endTime, o momento da avaliação é o startTime', () {
    final p = SessionParticipant.fromJson(
      json(
        status: 'NECESSITA_REAVALIACAO',
        assessment: {
          'consultantId': 'c-1',
          'startTime': '2026-09-23T10:58:00.000Z',
          'endTime': null,
          'score': 62,
        },
      ),
      sessionId: 'sess-1',
    );

    expect(p.assessedAt, DateTime.parse('2026-09-23T10:58:00.000Z'));
    expect(p.score, 62.0);
  });

  test('status e tipo desconhecidos caem nos valores iniciais do backend', () {
    final p = SessionParticipant.fromJson(
      json(status: 'ALGO_NOVO', participationType: 'OUTRO_TIPO'),
      sessionId: 'sess-1',
    );

    expect(p.status, ParticipantStatus.pendente);
    expect(p.participationType, ParticipationType.teoricaEPratica);
  });

  test('lê o tipo somente teórica', () {
    final p = SessionParticipant.fromJson(
      json(participationType: 'SOMENTE_TEORICA'),
      sessionId: 'sess-1',
    );

    expect(p.participationType, ParticipationType.somenteTeorica);
  });

  group('maskCpf', () {
    test('mantém só os 6 primeiros dígitos, com pontuação ou sem', () {
      expect(maskCpf('04211899001'), '042.118.***-**');
      expect(maskCpf('042.118.990-01'), '042.118.***-**');
    });

    test('CPF malformado ou ausente vira a máscara inteira', () {
      expect(maskCpf('123'), '***.***.***-**');
      expect(maskCpf(''), '***.***.***-**');
      expect(maskCpf(null), '***.***.***-**');
    });
  });

  test('fromRow devolve o mesmo participante que foi para o cache', () {
    final row = Participant(
      id: 'tp-1',
      sessionId: 'sess-1',
      name: 'Ana Paula Ribeiro',
      cpf: '042.118.***-**',
      participationType: 'SOMENTE_TEORICA',
      status: 'EM_AVALIACAO',
      assignedConsultantId: 'c-1',
      assignedConsultantName: 'Carla Souza',
      score: 70,
      assessedByConsultantId: 'c-3',
      assessedAt: DateTime(2026, 9, 23, 8, 12),
      cachedAt: DateTime(2026, 9, 23, 9),
    );

    final p = SessionParticipant.fromRow(row);

    expect(p.maskedCpf, '042.118.***-**');
    expect(p.participationType, ParticipationType.somenteTeorica);
    expect(p.status, ParticipantStatus.emAvaliacao);
    expect(p.assignedConsultantName, 'Carla Souza');
    expect(p.score, 70);
    expect(p.assessedByConsultantId, 'c-3');
    expect(p.assessedAt, DateTime(2026, 9, 23, 8, 12));
    expect(p.hasPreviousAssessment, isTrue);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/data/models/session_participant_test.dart`
Esperado: FAIL na compilação — `session_participant.dart` não existe.

- [ ] **Step 3: Implementar o modelo**

Criar `lib/data/models/session_participant.dart`:

```dart
import '../services/local/app_database.dart';

/// Tipo de participação no treinamento. Espelha `ParticipationType` do
/// backend.
enum ParticipationType {
  somenteTeorica,
  teoricaEPratica;

  /// Nome que o backend usa — também é o que vai para o cache.
  String get wireValue => switch (this) {
        ParticipationType.somenteTeorica => 'SOMENTE_TEORICA',
        ParticipationType.teoricaEPratica => 'TEORICA_E_PRATICA',
      };

  /// Um valor desconhecido cai no padrão do backend (`TEORICA_E_PRATICA` é o
  /// `@default` do Prisma) — o mesmo critério de `SessionStatus.parse`.
  static ParticipationType parse(String? value) => value == 'SOMENTE_TEORICA'
      ? ParticipationType.somenteTeorica
      : ParticipationType.teoricaEPratica;
}

/// Situação do participante na avaliação prática. Espelha `ParticipantStatus`
/// do backend.
enum ParticipantStatus {
  pendente,
  emAvaliacao,
  aprovado,
  necessitaReavaliacao;

  String get wireValue => switch (this) {
        ParticipantStatus.pendente => 'PENDENTE',
        ParticipantStatus.emAvaliacao => 'EM_AVALIACAO',
        ParticipantStatus.aprovado => 'APROVADO',
        ParticipantStatus.necessitaReavaliacao => 'NECESSITA_REAVALIACAO',
      };

  /// Um status novo no backend não pode derrubar a lista, então o
  /// desconhecido cai no valor inicial.
  static ParticipantStatus parse(String? value) => switch (value) {
        'EM_AVALIACAO' => ParticipantStatus.emAvaliacao,
        'APROVADO' => ParticipantStatus.aprovado,
        'NECESSITA_REAVALIACAO' => ParticipantStatus.necessitaReavaliacao,
        _ => ParticipantStatus.pendente,
      };
}

/// CPF no formato que o app mostra e guarda: `042.118.***-**`.
///
/// A tela nunca mostra o CPF inteiro (decisão do canvas de design), então o
/// aparelho também não guarda — se o celular for perdido, o cache não entrega
/// o documento de ninguém. Qualquer coisa que não sejam 11 dígitos vira a
/// máscara inteira, em vez de expor um pedaço de um valor malformado.
String maskCpf(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length != 11) return '***.***.***-**';
  return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.***-**';
}

/// Um participante inscrito numa sessão (`TrainingParticipant`), achatado com
/// o cadastro (`Participant`) e a avaliação já sincronizada, quando houver.
class SessionParticipant {
  const SessionParticipant({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.maskedCpf,
    required this.participationType,
    required this.status,
    this.assignedConsultantId,
    this.assignedConsultantName,
    this.score,
    this.assessedByConsultantId,
    this.assessedAt,
  });

  /// Id do `TrainingParticipant` — é o que `assign` e `sync` recebem.
  final String id;
  final String sessionId;
  final String name;

  /// Já mascarado — ver [maskCpf].
  final String maskedCpf;
  final ParticipationType participationType;
  final ParticipantStatus status;

  /// Quem está com o participante agora (só faz sentido em `EM_AVALIACAO`).
  final String? assignedConsultantId;
  final String? assignedConsultantName;

  /// Score da última avaliação sincronizada, de 0 a 100.
  final double? score;

  /// Quem fez a última avaliação sincronizada — entra no filtro "Meus".
  final String? assessedByConsultantId;

  /// Fim (ou início, se não houver fim) da última avaliação sincronizada.
  final DateTime? assessedAt;

  /// Já tem resultado: aprovado ou aguardando reavaliação.
  bool get isAssessed =>
      status == ParticipantStatus.aprovado ||
      status == ParticipantStatus.necessitaReavaliacao;

  /// Existe uma avaliação anterior. Com o participante de novo em
  /// `EM_AVALIACAO`, é uma reavaliação em andamento — mesmo critério do web
  /// (`getDisplayStatus`, `participants-tab.tsx`).
  bool get hasPreviousAssessment => score != null;

  /// Monta a partir de um item de `participants[]` de
  /// `GET /training-sessions/:id`.
  factory SessionParticipant.fromJson(
    Map<String, dynamic> json, {
    required String sessionId,
  }) {
    final participant = json['participant'] as Map<String, dynamic>? ?? const {};
    final assessment = json['assessment'] as Map<String, dynamic>?;
    final assigned = json['assignedConsultant'] as Map<String, dynamic>?;
    final end = assessment?['endTime'] as String?;
    final start = assessment?['startTime'] as String?;

    return SessionParticipant(
      id: json['id'] as String? ?? '',
      sessionId: sessionId,
      name: participant['name'] as String? ?? '',
      maskedCpf: maskCpf(participant['cpf'] as String?),
      participationType:
          ParticipationType.parse(json['participationType'] as String?),
      status: ParticipantStatus.parse(json['status'] as String?),
      assignedConsultantId:
          json['assignedConsultantId'] as String? ?? assigned?['id'] as String?,
      assignedConsultantName: assigned?['name'] as String?,
      score: (assessment?['score'] as num?)?.toDouble(),
      assessedByConsultantId: assessment?['consultantId'] as String?,
      // `endTime`/`startTime` são instantes de verdade (não datas de
      // calendário como `TrainingSession.date`): a hora local é a certa.
      assessedAt: DateTime.tryParse(end ?? start ?? ''),
    );
  }

  /// Reconstrói a partir da linha do cache local.
  factory SessionParticipant.fromRow(Participant row) {
    return SessionParticipant(
      id: row.id,
      sessionId: row.sessionId,
      name: row.name,
      maskedCpf: row.cpf,
      participationType: ParticipationType.parse(row.participationType),
      status: ParticipantStatus.parse(row.status),
      assignedConsultantId: row.assignedConsultantId,
      assignedConsultantName: row.assignedConsultantName,
      score: row.score,
      assessedByConsultantId: row.assessedByConsultantId,
      assessedAt: row.assessedAt,
    );
  }
}
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/data/models/session_participant_test.dart && flutter analyze`
Esperado: 9 testes passando e `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/session_participant.dart test/data/models/session_participant_test.dart
git commit -m "feat(mobile): modelo de participante da sessao com cpf mascarado"
```

---

## Task 3: `ParticipantRepository` e `SessionRepository.watchSession`/`start`

**Files:**
- Create: `lib/data/repositories/participant_repository.dart`
- Modify: `lib/data/repositories/session_repository.dart`
- Test: `test/data/repositories/participant_repository_test.dart`
- Test: `test/data/repositories/session_repository_test.dart`

**Interfaces:**
- Consumes: `SessionParticipant`, `ParticipationType`, `ParticipantStatus` (Task 2); colunas novas e `TrainingSession.responsibleConsultantId` (Task 1).
- Produces:
  - `ParticipantRepository({required ApiClient apiClient, required AppDatabase database})`
  - `Stream<List<SessionParticipant>> watchBySession(String sessionId)` — em ordem de nome.
  - `Future<Result<int>> syncSession(String sessionId)` — `GET /training-sessions/:id`; grava sessão (sem tocar `cachedAt` de linha existente; `participantsSyncedAt = agora`; contagens recalculadas) e troca os participantes dela numa transação; devolve quantos ficaram. `Failure.message`: a do backend em 403/404, senão `'Não foi possível atualizar. Mostrando os dados já baixados.'`.
  - `Future<Result<void>> assign(String participantId, {required String consultantId, required String consultantName})` — `POST /practical-assessments/assign`; no sucesso, a linha local vira `EM_AVALIACAO` com o consultor. `Failure.message`: a do backend em 409 e a do `ApiException` sem rede, senão `'Não foi possível atribuir o participante. Tente de novo.'`.
  - `SessionRepository.watchSession(String sessionId)` → `Stream<TrainingSession?>`.
  - `SessionRepository.start(String sessionId)` → `Future<Result<void>>` — `POST /training-sessions/:id/start`; no sucesso, o status local vira `EM_ANDAMENTO`. `Failure.message`: a do backend em 403 e a do `ApiException` sem rede, senão `'Não foi possível iniciar a sessão. Tente de novo.'`.

- [ ] **Step 1: Escrever os testes que falham — participantes**

Criar `test/data/repositories/participant_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/utils/result.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late ParticipantRepository repository;

  const detailPath = '/training-sessions/sess-1';

  Map<String, dynamic> participantJson(
    String id, {
    String name = 'Ana Paula Ribeiro',
    String status = 'PENDENTE',
    String participationType = 'TEORICA_E_PRATICA',
    Map<String, dynamic>? assessment,
  }) {
    return {
      'id': id,
      'participationType': participationType,
      'status': status,
      'assignedConsultantId': null,
      'participant': {'id': 'p-$id', 'name': name, 'cpf': '04211899001'},
      'assessment': assessment,
      'certificate': null,
      'assignedConsultant': null,
    };
  }

  /// O detalhe como `findTrainingSessionById` devolve (`company: true`, por
  /// isso o logo vem junto).
  Map<String, dynamic> detailJson(List<Map<String, dynamic>> participants) {
    return {
      'id': 'sess-1',
      'responsibleConsultantId': 'c-resp',
      'city': 'Itabira',
      'state': 'MG',
      'date': '2026-09-23T00:00:00.000Z',
      'status': 'EM_ANDAMENTO',
      'notes': 'Pátio 3 — portaria B às 07h30.',
      'company': {
        'id': 'emp-1',
        'name': 'Bracell',
        'logoUrl': 'https://cdn.simtc/logos/bracell.png',
      },
      'course': {'id': 'cur-1', 'name': 'Direção Defensiva'},
      'participants': participants,
    };
  }

  Response<Map<String, dynamic>> ok(Map<String, dynamic> body) {
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: detailPath),
      statusCode: 200,
      data: body,
    );
  }

  Future<void> seedSession({DateTime? cachedAt}) {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva',
            city: 'Itabira',
            state: 'MG',
            status: 'PLANEJADO',
            cachedAt: cachedAt ?? DateTime(2026, 9, 22, 8),
          ),
        );
  }

  setUp(() {
    api = _MockApiClient();
    db = AppDatabase(NativeDatabase.memory());
    repository = ParticipantRepository(apiClient: api, database: db);
  });

  tearDown(() => db.close());

  group('syncSession', () {
    test('grava os participantes com o CPF mascarado e a avaliação', () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([
          participantJson('tp-1'),
          participantJson(
            'tp-2',
            name: 'Juliana Freitas Costa',
            status: 'APROVADO',
            assessment: {
              'consultantId': 'c-1',
              'startTime': '2026-09-23T10:58:00.000Z',
              'endTime': '2026-09-23T11:12:00.000Z',
              'score': 86.4,
            },
          ),
        ])),
      );

      final result = await repository.syncSession('sess-1');

      expect(result.dataOrNull, 2);
      final rows = await db.select(db.participants).get();
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.cpf == '042.118.***-**'), isTrue,
          reason: 'o aparelho nunca guarda o CPF inteiro');
      expect(rows.every((r) => r.email == null), isTrue);
      final juliana = rows.singleWhere((r) => r.id == 'tp-2');
      expect(juliana.score, 86.4);
      expect(juliana.assessedByConsultantId, 'c-1');
      // O drift devolve hora local; o que importa é ser o mesmo instante.
      expect(juliana.assessedAt!.toUtc(), DateTime.parse('2026-09-23T11:12:00.000Z'));
    });

    test(
        'atualiza a sessão com o detalhe, recalcula as contagens e marca o '
        'sync dos participantes, sem mexer no cachedAt da agenda', () async {
      await seedSession(cachedAt: DateTime(2026, 9, 22, 8));
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([
          participantJson('tp-1'),
          participantJson('tp-2', status: 'APROVADO'),
          participantJson('tp-3', status: 'NECESSITA_REAVALIACAO'),
          participantJson('tp-4', participationType: 'SOMENTE_TEORICA'),
        ])),
      );

      await repository.syncSession('sess-1');

      final session = await db.select(db.sessions).getSingle();
      expect(session.status, 'EM_ANDAMENTO');
      expect(session.companyLogoUrl, 'https://cdn.simtc/logos/bracell.png');
      expect(session.notes, 'Pátio 3 — portaria B às 07h30.');
      expect(session.responsibleConsultantId, 'c-resp');
      expect(session.totalParticipants, 4);
      expect(session.assessableParticipants, 3);
      expect(session.assessedParticipants, 2);
      expect(session.participantsSyncedAt, isNotNull);
      expect(session.cachedAt, DateTime(2026, 9, 22, 8),
          reason: 'a idade da agenda da Home não muda por abrir uma sessão');
    });

    test('quem saiu da sessão no servidor sai do cache', () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([participantJson('tp-1'), participantJson('tp-2')])),
      );
      await repository.syncSession('sess-1');

      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([participantJson('tp-2')])),
      );
      await repository.syncSession('sess-1');

      final ids = (await db.select(db.participants).get()).map((r) => r.id);
      expect(ids, ['tp-2']);
    });

    test('resposta fora do formato vira Failure sem apagar o cache', () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([participantJson('tp-1')])),
      );
      await repository.syncSession('sess-1');

      when(() => api.get<Map<String, dynamic>>(detailPath))
          .thenAnswer((_) async => ok(const <String, dynamic>{}));

      final result = await repository.syncSession('sess-1');

      expect(result.isFailure, isTrue);
      expect(await db.select(db.participants).get(), hasLength(1));
    });

    test('403 devolve a mensagem do backend e preserva o cache', () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([participantJson('tp-1')])),
      );
      await repository.syncSession('sess-1');

      when(() => api.get<Map<String, dynamic>>(detailPath)).thenThrow(
        const ApiException(
          message: 'Você não tem acesso a este treinamento',
          statusCode: 403,
        ),
      );

      final result = await repository.syncSession('sess-1');

      expect(
        result,
        isA<Failure<int>>().having(
            (f) => f.message, 'message', 'Você não tem acesso a este treinamento'),
      );
      expect(await db.select(db.participants).get(), hasLength(1));
    });

    test('sem rede, a mensagem diz que o cache continua na tela', () async {
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenThrow(
        const ApiException(message: 'sem rede', isNetworkError: true),
      );

      final result = await repository.syncSession('sess-1');

      expect(
        result,
        isA<Failure<int>>().having((f) => f.message, 'message',
            'Não foi possível atualizar. Mostrando os dados já baixados.'),
      );
    });
  });

  test('watchBySession traz só os participantes da sessão pedida', () async {
    await seedSession();
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-2',
            companyName: 'Suzano',
            courseName: 'Empilhadeira',
            city: 'Bauru',
            state: 'SP',
            status: 'PLANEJADO',
            cachedAt: DateTime(2026, 9, 22, 8),
          ),
        );
    Future<void> insert(String id, String sessionId, String name) {
      return db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: id,
              sessionId: sessionId,
              name: name,
              cpf: '042.118.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'PENDENTE',
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );
    }

    await insert('tp-b', 'sess-1', 'Bruno');
    await insert('tp-a', 'sess-1', 'Ana');
    await insert('tp-x', 'sess-2', 'Xavier');

    final list = await repository.watchBySession('sess-1').first;

    expect(list.map((p) => p.name), ['Ana', 'Bruno']);
  });

  group('assign', () {
    const assignPath = '/practical-assessments/assign';

    Future<void> seedPending() async {
      await seedSession();
      await db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-1',
              sessionId: 'sess-1',
              name: 'Carlos Eduardo Nunes',
              cpf: '187.443.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'PENDENTE',
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );
    }

    test('reserva no backend e já marca a linha local como minha', () async {
      await seedPending();
      when(() => api.post<Map<String, dynamic>>(assignPath,
          data: any(named: 'data'))).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: assignPath),
          statusCode: 201,
          data: {'assigned': 1},
        ),
      );

      final result = await repository.assign(
        'tp-1',
        consultantId: 'c-1',
        consultantName: 'Carla Souza',
      );

      expect(result.isSuccess, isTrue);
      final sent = verify(() => api.post<Map<String, dynamic>>(assignPath,
          data: captureAny(named: 'data'))).captured.single;
      expect(sent, {
        'participantIds': ['tp-1'],
      });
      final row = await db.select(db.participants).getSingle();
      expect(row.status, ParticipantStatus.emAvaliacao.wireValue);
      expect(row.assignedConsultantId, 'c-1');
      expect(row.assignedConsultantName, 'Carla Souza');
    });

    test('409 devolve o motivo do conflito e não mexe na linha local', () async {
      await seedPending();
      when(() => api.post<Map<String, dynamic>>(assignPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(
          message:
              'Um ou mais participantes já estão em avaliação com outro consultor',
          statusCode: 409,
        ),
      );

      final result = await repository.assign(
        'tp-1',
        consultantId: 'c-1',
        consultantName: 'Carla Souza',
      );

      expect(
        result,
        isA<Failure<void>>().having((f) => f.message, 'message',
            'Um ou mais participantes já estão em avaliação com outro consultor'),
      );
      final row = await db.select(db.participants).getSingle();
      expect(row.status, 'PENDENTE');
    });

    test('erro inesperado do servidor vira uma mensagem genérica', () async {
      await seedPending();
      when(() => api.post<Map<String, dynamic>>(assignPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(message: 'Internal server error', statusCode: 500),
      );

      final result = await repository.assign(
        'tp-1',
        consultantId: 'c-1',
        consultantName: 'Carla Souza',
      );

      expect(
        result,
        isA<Failure<void>>().having((f) => f.message, 'message',
            'Não foi possível atribuir o participante. Tente de novo.'),
      );
    });
  });
}
```

- [ ] **Step 2: Escrever os testes que falham — sessão**

Em `test/data/repositories/session_repository_test.dart`, acrescentar `import 'package:simtc/utils/result.dart';` depois do import de `app_database.dart`, e no fim do `main()`:

```dart
  test('watchSession emite a sessão pedida, e nulo se ela não está no cache',
      () async {
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 's1',
            companyName: 'Bracell Celulose',
            courseName: 'Direção Preventiva',
            city: 'Lençóis Paulista',
            state: 'SP',
            status: 'EM_ANDAMENTO',
            responsibleConsultantId: const Value('c-resp'),
            cachedAt: DateTime(2026, 9, 22, 8),
          ),
        );

    final session = await repository.watchSession('s1').first;
    final missing = await repository.watchSession('nao-existe').first;

    expect(session?.companyName, 'Bracell Celulose');
    expect(session?.responsibleConsultantId, 'c-resp');
    expect(missing, isNull);
  });

  group('start', () {
    Future<void> seedPlanned() {
      return db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: 's1',
              companyName: 'Bracell Celulose',
              courseName: 'Direção Preventiva',
              city: 'Lençóis Paulista',
              state: 'SP',
              status: 'PLANEJADO',
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );
    }

    test('chama o /start e já marca a sessão local como em andamento',
        () async {
      await seedPlanned();
      when(() => api.post<Map<String, dynamic>>('/training-sessions/s1/start'))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions:
                    RequestOptions(path: '/training-sessions/s1/start'),
                statusCode: 201,
                data: {'id': 's1', 'status': 'EM_ANDAMENTO'},
              ));

      final result = await repository.start('s1');

      expect(result.isSuccess, isTrue);
      final row = await db.select(db.sessions).getSingle();
      expect(row.status, 'EM_ANDAMENTO');
    });

    test('403 devolve a mensagem do backend e não mexe no status local',
        () async {
      await seedPlanned();
      when(() => api.post<Map<String, dynamic>>('/training-sessions/s1/start'))
          .thenThrow(const ApiException(
        message:
            'Somente o consultor responsável por este treinamento pode iniciá-lo ou concluí-lo',
        statusCode: 403,
      ));

      final result = await repository.start('s1');

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.message,
          'message',
          'Somente o consultor responsável por este treinamento pode iniciá-lo ou concluí-lo',
        ),
      );
      final row = await db.select(db.sessions).getSingle();
      expect(row.status, 'PLANEJADO');
    });
  });
```

- [ ] **Step 3: Rodar e confirmar que falham**

Run: `flutter test test/data/repositories/`
Esperado: FAIL na compilação — `participant_repository.dart` não existe; `watchSession` e `start` não existem em `SessionRepository`.

- [ ] **Step 4: Implementar o `ParticipantRepository`**

Criar `lib/data/repositories/participant_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../../utils/result.dart';
import '../models/session_participant.dart';
import '../models/training_session.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/local/app_database.dart';

/// Participantes de uma sessão e a autoatribuição.
///
/// Mesma regra do `SessionRepository`: a tela lê do banco, nunca da resposta
/// HTTP. `syncSession()` baixa o detalhe e grava; `watchBySession()` serve a
/// lista. Offline, a tela continua com o que foi baixado na última vez que a
/// sessão foi aberta com sinal (decisão de 23/09/2026: baixar ao abrir, sem
/// pré-carregar sessões que o consultor não abriu).
class ParticipantRepository {
  ParticipantRepository({
    required ApiClient apiClient,
    required AppDatabase database,
  })  : _api = apiClient,
        _db = database;

  final ApiClient _api;
  final AppDatabase _db;

  static const String _assignPath = '/practical-assessments/assign';

  static const String _refreshFailed =
      'Não foi possível atualizar. Mostrando os dados já baixados.';
  static const String _assignFailed =
      'Não foi possível atribuir o participante. Tente de novo.';

  /// Participantes da sessão em ordem de nome. A ordem de exibição (meus
  /// primeiro, somente teórica por último) é regra de tela e fica na
  /// `SessionDetailViewModel`.
  Stream<List<SessionParticipant>> watchBySession(String sessionId) {
    final query = _db.select(_db.participants)
      ..where((t) => t.sessionId.equals(sessionId))
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);

    return query.watch().map(
          (rows) =>
              rows.map(SessionParticipant.fromRow).toList(growable: false),
        );
  }

  /// Baixa `GET /training-sessions/:id` e regrava a sessão e os participantes
  /// dela numa transação só. Devolve quantos participantes ficaram.
  Future<Result<int>> syncSession(String sessionId) async {
    try {
      final response =
          await _api.get<Map<String, dynamic>>('/training-sessions/$sessionId');
      final body = response.data;
      final list = body?['participants'];

      // Mesma lição do `syncAll`: um corpo 200 fora do formato não pode virar
      // "sessão sem ninguém" — isso apagaria os participantes do cache.
      if (body == null || body['id'] != sessionId || list is! List) {
        return Failure(
          Exception('resposta de /training-sessions/$sessionId fora do formato'),
          _refreshFailed,
        );
      }

      final session = TrainingSession.fromJson(body);
      final participants = list
          .whereType<Map<String, dynamic>>()
          .map((json) => SessionParticipant.fromJson(json, sessionId: sessionId))
          .where((p) => p.id.isNotEmpty)
          .toList(growable: false);

      await _write(session, participants);
      return Success(participants.length);
    } on ApiException catch (error) {
      // 403 (consultor saiu da sessão) e 404 (sessão apagada) têm mensagem
      // própria do backend que explica o que aconteceu; o resto é "sem rede ou
      // servidor fora", e a mensagem genérica diz o que importa: o cache ficou.
      final ownMessage = error.statusCode == 403 || error.statusCode == 404;
      return Failure(error, ownMessage ? error.message : _refreshFailed);
    } catch (error) {
      return Failure(Exception('$error'), _refreshFailed);
    }
  }

  Future<void> _write(
    TrainingSession session,
    List<SessionParticipant> participants,
  ) {
    final now = DateTime.now();
    final assessable = participants
        .where((p) => p.participationType == ParticipationType.teoricaEPratica)
        .toList(growable: false);

    // As contagens do card da Home são recalculadas daqui, com a mesma regra
    // do `participantStats` do backend — voltar para a Home depois de abrir a
    // sessão mostra os números que o consultor acabou de ver.
    final fields = SessionsCompanion(
      companyName: Value(session.companyName),
      companyLogoUrl: Value(session.companyLogoUrl),
      courseName: Value(session.courseName),
      city: Value(session.city),
      state: Value(session.state),
      date: Value(session.date),
      status: Value(session.status.wireValue),
      notes: Value(session.notes),
      responsibleConsultantId: Value(session.responsibleConsultantId),
      totalParticipants: Value(participants.length),
      assessableParticipants: Value(assessable.length),
      assessedParticipants: Value(assessable.where((p) => p.isAssessed).length),
      participantsSyncedAt: Value(now),
    );

    return _db.transaction(() async {
      // `cachedAt` só entra se a linha for nova: é a idade da agenda inteira
      // que a Home mostra offline, e o detalhe de uma sessão não atualiza as
      // outras. No conflito, o `DoUpdate` grava só `fields`.
      await _db.into(_db.sessions).insert(
            fields.copyWith(id: Value(session.id), cachedAt: Value(now)),
            onConflict: DoUpdate((_) => fields),
          );

      await (_db.delete(_db.participants)
            ..where((t) => t.sessionId.equals(session.id)))
          .go();

      for (final p in participants) {
        await _db.into(_db.participants).insert(
              ParticipantsCompanion.insert(
                id: p.id,
                sessionId: session.id,
                name: p.name,
                cpf: p.maskedCpf,
                participationType: p.participationType.wireValue,
                status: p.status.wireValue,
                assignedConsultantId: Value(p.assignedConsultantId),
                assignedConsultantName: Value(p.assignedConsultantName),
                score: Value(p.score),
                assessedByConsultantId: Value(p.assessedByConsultantId),
                assessedAt: Value(p.assessedAt),
                cachedAt: now,
              ),
            );
      }
    });
  }

  /// Reserva o participante para o consultor logado
  /// (`POST /practical-assessments/assign`).
  ///
  /// Precisa de conexão por natureza: a reserva é o que impede dois
  /// consultores de avaliarem a mesma pessoa. Com sucesso, a linha local muda
  /// na hora — a tela não espera o re-sync para mostrar "Avaliando · você".
  Future<Result<void>> assign(
    String participantId, {
    required String consultantId,
    required String consultantName,
  }) async {
    try {
      await _api.post<Map<String, dynamic>>(
        _assignPath,
        data: {
          'participantIds': [participantId],
        },
      );
    } on ApiException catch (error) {
      // 409 traz o motivo do conflito ("já estão em avaliação com outro
      // consultor", "aprovados não podem ser reavaliados"...), e sem rede a
      // mensagem do `ApiException` já diz o que fazer.
      final ownMessage = error.statusCode == 409 || error.isNetworkError;
      return Failure(error, ownMessage ? error.message : _assignFailed);
    } catch (error) {
      return Failure(Exception('$error'), _assignFailed);
    }

    try {
      await (_db.update(_db.participants)
            ..where((t) => t.id.equals(participantId)))
          .write(
        ParticipantsCompanion(
          status: Value(ParticipantStatus.emAvaliacao.wireValue),
          assignedConsultantId: Value(consultantId),
          assignedConsultantName: Value(consultantName),
        ),
      );
    } catch (_) {
      // O backend já reservou — isso é o que importa. Se a escrita local
      // falhar, o re-sync que a tela dispara em seguida corrige a linha.
    }
    return const Success<void>(null);
  }
}
```

Três detalhes que os testes cobrem e que não podem se perder:
- o upsert da sessão usa `insert(..., onConflict: DoUpdate((_) => fields))` com `cachedAt` **só** no companion de inserção — `cachedAt` é a idade da agenda inteira que a Home mostra offline, e abrir uma sessão não atualiza as outras;
- os participantes da sessão são apagados e regravados dentro da mesma transação (o stream do drift emite uma vez só, depois do commit);
- o CPF gravado é o `maskedCpf`, e o `email` fica de fora.

- [ ] **Step 5: `watchSession` e `start` no `SessionRepository`**

Em `lib/data/repositories/session_repository.dart`, depois de `_offlineMessage`:

```dart
  static const String _startFailed =
      'Não foi possível iniciar a sessão. Tente de novo.';
```

E logo antes do comentário de `watchLastSyncedAt`:

```dart
  /// Uma sessão do cache — o cabeçalho da tela 1.4. Emite nulo se ela não
  /// estiver no aparelho (a Home podou, por exemplo).
  Stream<TrainingSession?> watchSession(String sessionId) {
    final query = _db.select(_db.sessions)
      ..where((t) => t.id.equals(sessionId));
    return query.watchSingleOrNull().map(
          (row) => row == null ? null : TrainingSession.fromRow(row),
        );
  }

  /// Inicia a sessão (`POST /training-sessions/:id/start`). Só o ADMIN e o
  /// consultor responsável podem — o backend responde 403 para os demais.
  ///
  /// Com sucesso, o status local muda na hora para os botões de atribuir
  /// aparecerem sem esperar o re-sync do detalhe.
  Future<Result<void>> start(String sessionId) async {
    try {
      await _api.post<Map<String, dynamic>>('$_path/$sessionId/start');
    } on ApiException catch (error) {
      final ownMessage = error.statusCode == 403 || error.isNetworkError;
      return Failure(error, ownMessage ? error.message : _startFailed);
    } catch (error) {
      return Failure(Exception('$error'), _startFailed);
    }

    try {
      await (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId)))
          .write(
        SessionsCompanion(status: Value(SessionStatus.emAndamento.wireValue)),
      );
    } catch (_) {
      // O backend já iniciou; o re-sync do detalhe corrige a linha local.
    }
    return const Success<void>(null);
  }

```

- [ ] **Step 6: Rodar os testes e confirmar que passam**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **141 testes passando**.

- [ ] **Step 7: Commit**

```bash
git add lib/data/repositories/participant_repository.dart lib/data/repositories/session_repository.dart test/data/repositories/participant_repository_test.dart test/data/repositories/session_repository_test.dart
git commit -m "feat(mobile): sincroniza participantes da sessao e atribui ao consultor"
```

---

## Task 4: Catálogo de avaliação no aparelho, junto com a agenda

**Files:**
- Create: `lib/data/models/assessment_catalog.dart`
- Create: `lib/data/repositories/assessment_catalog_repository.dart`
- Modify: `lib/ui/sessions/sessions_list_viewmodel.dart`
- Modify: `lib/ui/sessions/sessions_screen.dart` (criação da VM)
- Modify: `lib/app_providers.dart`
- Test: `test/data/repositories/assessment_catalog_repository_test.dart`
- Test: `test/ui/sessions/sessions_list_viewmodel_test.dart`
- Test: `test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: tabelas `AssessmentCategories`, `Infractions`, `InfractionNotes` (existem desde a Fase 1, vazias).
- Produces:
  - `CatalogCategory { id, code, name, description?, order, List<CatalogInfraction> infractions }`, `CatalogInfraction { id, categoryId, description, order, List<CatalogNote> notes }`, `CatalogNote { id, infractionId, noteType ('B'|'PM'|'M'), comment?, deduction }`, cada um com `fromJson`.
  - `AssessmentCatalogRepository({required ApiClient apiClient, required AppDatabase database, void Function(String)? log})`, `Future<Result<int>> sync()` (troca total; devolve quantas categorias) e `Future<List<CatalogCategory>> loadCatalog()` (ordem da ficha) — a Fase 4 consome o `loadCatalog`.
  - `SessionsListViewModel` passa a exigir `required AssessmentCatalogRepository catalog`; `refresh()` dispara `catalog.sync()` sem esperar.
  - `AppDependencies.catalogRepository` + `Provider<AssessmentCatalogRepository>`.

- [ ] **Step 1: Escrever os testes que falham — repositório**

Criar `test/data/repositories/assessment_catalog_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late List<String> logs;
  late AssessmentCatalogRepository repository;

  const path = '/assessment-categories';

  /// Uma categoria como `GET /assessment-categories` devolve: infrações e
  /// notas aninhadas (`include: { infractions: { include: { notes: true } } }`).
  Map<String, dynamic> category(
    String id, {
    required int order,
    List<Map<String, dynamic>> infractions = const [],
  }) {
    return {
      'id': id,
      'code': id.toUpperCase(),
      'name': 'Categoria $id',
      'description': null,
      'order': order,
      'infractions': infractions,
    };
  }

  Map<String, dynamic> infraction(String id, {required int order}) {
    return {
      'id': id,
      'description': 'Infração $id',
      'order': order,
      'notes': [
        {'id': '$id-b', 'noteType': 'B', 'comment': 'Leve', 'deduction': 1},
        {'id': '$id-pm', 'noteType': 'PM', 'comment': 'Média', 'deduction': 3},
        {'id': '$id-m', 'noteType': 'M', 'comment': null, 'deduction': 5},
      ],
    };
  }

  Response<List<dynamic>> ok(List<dynamic> body) {
    return Response<List<dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: body,
    );
  }

  setUp(() {
    api = _MockApiClient();
    db = AppDatabase(NativeDatabase.memory());
    logs = [];
    repository = AssessmentCatalogRepository(
      apiClient: api,
      database: db,
      log: logs.add,
    );
  });

  tearDown(() => db.close());

  test('grava categorias, infrações e notas e devolve na ordem da ficha',
      () async {
    when(() => api.get<List<dynamic>>(path)).thenAnswer(
      (_) async => ok([
        category('tp', order: 2),
        category('cv', order: 1, infractions: [
          infraction('cv2', order: 2),
          infraction('cv1', order: 1),
        ]),
      ]),
    );

    final result = await repository.sync();
    final catalog = await repository.loadCatalog();

    expect(result.dataOrNull, 2);
    expect(catalog.map((c) => c.id), ['cv', 'tp']);
    expect(catalog.first.infractions.map((i) => i.id), ['cv1', 'cv2']);
    expect(
      catalog.first.infractions.first.notes.map((n) => n.deduction),
      containsAll([1, 3, 5]),
    );
    expect(catalog.last.infractions, isEmpty);
  });

  test('um novo sync troca o catálogo inteiro, sem sobrar nada do antigo',
      () async {
    when(() => api.get<List<dynamic>>(path)).thenAnswer(
      (_) async => ok([
        category('cv', order: 1, infractions: [infraction('cv1', order: 1)]),
        category('tp', order: 2, infractions: [infraction('tp1', order: 1)]),
      ]),
    );
    await repository.sync();

    when(() => api.get<List<dynamic>>(path)).thenAnswer(
      (_) async => ok([
        category('cv', order: 1, infractions: [infraction('cv9', order: 1)]),
      ]),
    );
    await repository.sync();

    final catalog = await repository.loadCatalog();
    expect(catalog.map((c) => c.id), ['cv']);
    expect(catalog.single.infractions.map((i) => i.id), ['cv9']);
    expect(await db.select(db.infractionNotes).get(), hasLength(3));
  });

  test('sem rede, o catálogo do aparelho continua inteiro', () async {
    when(() => api.get<List<dynamic>>(path)).thenAnswer(
      (_) async => ok([
        category('cv', order: 1, infractions: [infraction('cv1', order: 1)]),
      ]),
    );
    await repository.sync();

    when(() => api.get<List<dynamic>>(path)).thenThrow(
      const ApiException(message: 'sem rede', isNetworkError: true),
    );

    final result = await repository.sync();

    expect(result.isFailure, isTrue);
    expect(await repository.loadCatalog(), hasLength(1));
  });

  test('resposta vazia não apaga o catálogo do aparelho', () async {
    when(() => api.get<List<dynamic>>(path)).thenAnswer(
      (_) async => ok([
        category('cv', order: 1, infractions: [infraction('cv1', order: 1)]),
      ]),
    );
    await repository.sync();

    when(() => api.get<List<dynamic>>(path)).thenAnswer((_) async => ok([]));

    final result = await repository.sync();

    expect(result.isFailure, isTrue);
    expect(await repository.loadCatalog(), hasLength(1));
  });

  test('registra no log o que ficou no aparelho, com sync ou sem', () async {
    when(() => api.get<List<dynamic>>(path)).thenAnswer(
      (_) async => ok([
        category('cv', order: 1, infractions: [infraction('cv1', order: 1)]),
      ]),
    );
    await repository.sync();

    when(() => api.get<List<dynamic>>(path)).thenThrow(
      const ApiException(message: 'sem rede', isNetworkError: true),
    );
    await repository.sync();

    expect(logs, [
      'Catálogo sincronizado. No aparelho: 1 categorias, 1 infrações, 3 notas.',
      'Catálogo não atualizado (sem rede). No aparelho: 1 categorias, '
          '1 infrações, 3 notas.',
    ]);
  });
}
```

- [ ] **Step 2: Escrever os testes que falham — Home**

Em `test/ui/sessions/sessions_list_viewmodel_test.dart`:
- import `package:simtc/data/repositories/assessment_catalog_repository.dart` (logo antes do import de `session_repository.dart`);
- depois de `_MockSessionRepository`, a classe `class _MockCatalogRepository extends Mock implements AssessmentCatalogRepository {}`;
- `late _MockCatalogRepository catalog;` depois de `late _MockSessionRepository repository;`;
- `catalog: catalog,` no `build()`, entre `repository:` e `connectivity:`;
- no `setUp`, `catalog = _MockCatalogRepository();` depois de `repository = ...` e, depois do `when(repository.syncAll)...`, `when(catalog.sync).thenAnswer((_) async => const Success(7));`.

No fim do `main()`:

```dart
  test('baixa o catálogo junto com a agenda, ao abrir e na volta da conexão',
      () async {
    build().init();
    await Future<void>.delayed(Duration.zero);

    connectivity.reconnect();
    await Future<void>.delayed(Duration.zero);

    verify(catalog.sync).called(2);
  });

  test('falha do catálogo não vira mensagem na Home', () async {
    when(catalog.sync).thenAnswer(
      (_) async => Failure(Exception('sem rede'), 'Não foi possível atualizar o catálogo.'),
    );

    final viewModel = build()..init();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isRefreshing, isFalse);
  });

  test('um catálogo lento não segura o puxar para atualizar', () async {
    final catalogo = Completer<Result<int>>();
    when(catalog.sync).thenAnswer((_) => catalogo.future);

    final viewModel = build();
    await viewModel.refresh();

    expect(viewModel.isRefreshing, isFalse,
        reason: 'o refresh terminou mesmo com o catálogo ainda baixando');
    catalogo.complete(const Success(7));
  });
```

Em `test/ui/sessions/sessions_screen_test.dart` (a tela cria a VM com `context.read`, então o provider é obrigatório):
- import `package:simtc/data/repositories/assessment_catalog_repository.dart` antes do import de `auth_repository.dart`;
- depois de `_MockAuthRepository`, `class _MockCatalogRepository extends Mock implements AssessmentCatalogRepository {}`;
- `late _MockCatalogRepository catalog;` depois de `late _MockAuthRepository auth;`;
- no `setUp`, `catalog = _MockCatalogRepository();` depois de `auth = ...` e, no fim, `when(catalog.sync).thenAnswer((_) async => const Success(7));`;
- no `pump`, `Provider<AssessmentCatalogRepository>.value(value: catalog),` logo depois do provider de `SessionRepository`.

- [ ] **Step 3: Rodar e confirmar que falham**

Run: `flutter test test/data/repositories/assessment_catalog_repository_test.dart test/ui/sessions/`
Esperado: FAIL na compilação — `assessment_catalog_repository.dart` não existe e `SessionsListViewModel` não tem `catalog`.

- [ ] **Step 4: Implementar os modelos do catálogo**

Criar `lib/data/models/assessment_catalog.dart`:

```dart
/// Catálogo da avaliação prática: categorias, infrações de cada categoria e as
/// notas (B, PM, M) de cada infração. Vem de `GET /assessment-categories`, que
/// devolve tudo aninhado numa chamada só.
class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.order,
    required this.infractions,
    this.description,
  });

  final String id;

  /// Sigla da categoria na ficha oficial ("CV", "TP"...).
  final String code;
  final String name;
  final String? description;
  final int order;
  final List<CatalogInfraction> infractions;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final infractions = json['infractions'];
    return CatalogCategory(
      id: id,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      infractions: infractions is List
          ? infractions
              .whereType<Map<String, dynamic>>()
              .map((item) => CatalogInfraction.fromJson(item, categoryId: id))
              .toList(growable: false)
          : const [],
    );
  }
}

class CatalogInfraction {
  const CatalogInfraction({
    required this.id,
    required this.categoryId,
    required this.description,
    required this.order,
    required this.notes,
  });

  final String id;
  final String categoryId;
  final String description;

  /// Número do item na ficha oficial — é por ele que a infração é localizada
  /// numa contestação.
  final int order;
  final List<CatalogNote> notes;

  factory CatalogInfraction.fromJson(
    Map<String, dynamic> json, {
    required String categoryId,
  }) {
    final id = json['id'] as String? ?? '';
    final notes = json['notes'];
    return CatalogInfraction(
      id: id,
      categoryId: categoryId,
      description: json['description'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      notes: notes is List
          ? notes
              .whereType<Map<String, dynamic>>()
              .map((item) => CatalogNote.fromJson(item, infractionId: id))
              .toList(growable: false)
          : const [],
    );
  }
}

class CatalogNote {
  const CatalogNote({
    required this.id,
    required this.infractionId,
    required this.noteType,
    required this.deduction,
    this.comment,
  });

  final String id;
  final String infractionId;

  /// `B`, `PM` ou `M`, como vem do backend.
  final String noteType;
  final String? comment;

  /// Peso usado no score — o cálculo lê este valor, nunca uma constante.
  final int deduction;

  factory CatalogNote.fromJson(
    Map<String, dynamic> json, {
    required String infractionId,
  }) {
    return CatalogNote(
      id: json['id'] as String? ?? '',
      infractionId: infractionId,
      noteType: json['noteType'] as String? ?? '',
      comment: json['comment'] as String?,
      deduction: (json['deduction'] as num?)?.toInt() ?? 0,
    );
  }
}
```

- [ ] **Step 5: Implementar o repositório**

Criar `lib/data/repositories/assessment_catalog_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../utils/result.dart';
import '../models/assessment_catalog.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/local/app_database.dart';

/// Catálogo de categorias, infrações e notas, guardado no aparelho.
///
/// O checklist da Fase 4 precisa funcionar sem sinal, então o catálogo tem de
/// estar no aparelho antes de o consultor chegar ao pátio. Ele desce junto com
/// cada atualização da Home (decisão de 23/09/2026) — uma chamada pequena, que
/// também traz para o app qualquer edição feita pelo admin no painel web.
class AssessmentCatalogRepository {
  AssessmentCatalogRepository({
    required ApiClient apiClient,
    required AppDatabase database,
    void Function(String message)? log,
  })  : _api = apiClient,
        _db = database,
        _log = log ?? _debugLog;

  final ApiClient _api;
  final AppDatabase _db;

  /// Não há tela do catálogo nesta fase — o log de debug é como se confere, no
  /// console do `flutter run`, que ele ficou no aparelho (inclusive offline).
  final void Function(String message) _log;

  static const String _path = '/assessment-categories';
  static const String _failed = 'Não foi possível atualizar o catálogo.';

  static void _debugLog(String message) {
    if (kDebugMode) debugPrint(message);
  }

  /// Baixa o catálogo inteiro e troca o do aparelho numa transação só.
  /// Devolve quantas categorias ficaram.
  Future<Result<int>> sync() async {
    try {
      final response = await _api.get<List<dynamic>>(_path);
      final data = response.data;
      final categories = data is List
          ? data
              .whereType<Map<String, dynamic>>()
              .map(CatalogCategory.fromJson)
              .toList(growable: false)
          : const <CatalogCategory>[];

      // Catálogo vazio não substitui o que está no aparelho: sem categorias
      // não há checklist, e uma resposta vazia é muito mais provável de ser
      // defeito (proxy, mudança de contrato) do que o admin ter apagado tudo.
      if (categories.isEmpty) {
        await _logSummary('Catálogo não atualizado (resposta vazia)');
        return Failure(Exception('catálogo vazio ou fora do formato'), _failed);
      }

      await _replace(categories);
      await _logSummary('Catálogo sincronizado');
      return Success(categories.length);
    } on ApiException catch (error) {
      await _logSummary('Catálogo não atualizado (${error.message})');
      return Failure(error, _failed);
    } catch (error) {
      await _logSummary('Catálogo não atualizado ($error)');
      return Failure(Exception('$error'), _failed);
    }
  }

  Future<void> _replace(List<CatalogCategory> categories) {
    return _db.transaction(() async {
      // Notas → infrações → categorias: as chaves estrangeiras apontam nessa
      // direção, e apagar na ordem inversa derrubaria a transação.
      await _db.delete(_db.infractionNotes).go();
      await _db.delete(_db.infractions).go();
      await _db.delete(_db.assessmentCategories).go();

      await _db.batch((batch) {
        for (final category in categories) {
          batch.insert(
            _db.assessmentCategories,
            AssessmentCategoriesCompanion.insert(
              id: category.id,
              code: category.code,
              name: category.name,
              description: Value(category.description),
              order: category.order,
            ),
          );
          for (final infraction in category.infractions) {
            batch.insert(
              _db.infractions,
              InfractionsCompanion.insert(
                id: infraction.id,
                categoryId: category.id,
                description: infraction.description,
                order: infraction.order,
              ),
            );
            for (final note in infraction.notes) {
              batch.insert(
                _db.infractionNotes,
                InfractionNotesCompanion.insert(
                  id: note.id,
                  infractionId: infraction.id,
                  noteType: note.noteType,
                  comment: Value(note.comment),
                  deduction: note.deduction,
                ),
              );
            }
          }
        }
      });
    });
  }

  /// O catálogo do aparelho, na ordem da ficha oficial — o que o checklist da
  /// Fase 4 percorre.
  Future<List<CatalogCategory>> loadCatalog() async {
    final categories = await (_db.select(_db.assessmentCategories)
          ..orderBy([(t) => OrderingTerm(expression: t.order)]))
        .get();
    final infractions = await (_db.select(_db.infractions)
          ..orderBy([(t) => OrderingTerm(expression: t.order)]))
        .get();
    final notes = await _db.select(_db.infractionNotes).get();

    return [
      for (final category in categories)
        CatalogCategory(
          id: category.id,
          code: category.code,
          name: category.name,
          description: category.description,
          order: category.order,
          infractions: [
            for (final infraction
                in infractions.where((i) => i.categoryId == category.id))
              CatalogInfraction(
                id: infraction.id,
                categoryId: category.id,
                description: infraction.description,
                order: infraction.order,
                notes: [
                  for (final note
                      in notes.where((n) => n.infractionId == infraction.id))
                    CatalogNote(
                      id: note.id,
                      infractionId: infraction.id,
                      noteType: note.noteType,
                      comment: note.comment,
                      deduction: note.deduction,
                    ),
                ],
              ),
          ],
        ),
    ];
  }

  Future<void> _logSummary(String prefix) async {
    try {
      final categories = await _db.assessmentCategories.count().getSingle();
      final infractions = await _db.infractions.count().getSingle();
      final notes = await _db.infractionNotes.count().getSingle();
      _log('$prefix. No aparelho: $categories categorias, '
          '$infractions infrações, $notes notas.');
    } catch (_) {
      // Log de conferência — nunca pode derrubar o sync.
    }
  }
}
```

- [ ] **Step 6: A Home baixa o catálogo junto com a agenda**

Em `lib/ui/sessions/sessions_list_viewmodel.dart`, acrescentar o import `import '../../data/repositories/assessment_catalog_repository.dart';` antes do de `session_repository.dart`, e trocar o construtor e os campos:

```dart
  SessionsListViewModel({
    required SessionRepository repository,
    required ConnectivityService connectivity,
    DateTime Function()? now,
  })  : _repository = repository,
        _connectivity = connectivity,
        _now = now ?? DateTime.now;

  final SessionRepository _repository;
  final ConnectivityService _connectivity;
```

por:

```dart
  SessionsListViewModel({
    required SessionRepository repository,
    required AssessmentCatalogRepository catalog,
    required ConnectivityService connectivity,
    DateTime Function()? now,
  })  : _repository = repository,
        _catalog = catalog,
        _connectivity = connectivity,
        _now = now ?? DateTime.now;

  final SessionRepository _repository;
  final AssessmentCatalogRepository _catalog;
  final ConnectivityService _connectivity;
```

Em `refresh()`, entre o `notifyListeners();` inicial e o `try`:

```dart
    // O catálogo de avaliação desce junto com a agenda (decisão de
    // 23/09/2026): é o que garante que ele já está no aparelho quando o
    // consultor perde o sinal no pátio. Corre em paralelo e em silêncio — o
    // puxar para atualizar não espera por ele, e a falha dele não vira
    // mensagem na Home; o próximo refresh tenta de novo.
    unawaited(_syncCatalog());
```

E logo antes de `clearError()`:

```dart
  Future<void> _syncCatalog() async {
    try {
      await _catalog.sync();
    } catch (_) {
      // `sync` já devolve `Result`; isto só impede que um erro inesperado
      // escape como exceção não tratada.
    }
  }

```

Em `lib/ui/sessions/sessions_screen.dart`, acrescentar o import `import '../../data/repositories/assessment_catalog_repository.dart';` antes do de `auth_repository.dart`, e na criação da VM, `catalog: context.read<AssessmentCatalogRepository>(),` entre `repository:` e `connectivity:`.

- [ ] **Step 7: Registrar o repositório nas dependências do app**

Em `lib/app_providers.dart`:
- import `data/repositories/assessment_catalog_repository.dart` antes de `auth_repository.dart`;
- `required this.catalogRepository,` no construtor privado, depois de `required this.sessionRepository,`;
- em `create`, depois do `sessionRepository`:

```dart
    final catalogRepository = AssessmentCatalogRepository(
      apiClient: apiClient,
      database: database,
    );
```

- `catalogRepository: catalogRepository,` no `return AppDependencies._(...)`, depois de `sessionRepository:`;
- o campo `final AssessmentCatalogRepository catalogRepository;` depois de `sessionRepository`;
- em `providers`, `Provider<AssessmentCatalogRepository>.value(value: catalogRepository),` logo depois do de `SessionRepository`.

O catálogo não é apagado no logout (`clearSessionsCache`): ele é o mesmo para todos os consultores.

- [ ] **Step 8: Rodar os testes e confirmar que passam**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **149 testes passando**.

- [ ] **Step 9: Commit**

```bash
git add lib/data/models/assessment_catalog.dart lib/data/repositories/assessment_catalog_repository.dart lib/ui/sessions/sessions_list_viewmodel.dart lib/ui/sessions/sessions_screen.dart lib/app_providers.dart test/data/repositories/assessment_catalog_repository_test.dart test/ui/sessions/sessions_list_viewmodel_test.dart test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): baixa o catalogo de avaliacao junto com a agenda"
```

---

## Task 5: Regras da tela 1.4 e `SessionDetailViewModel`

**Files:**
- Create: `lib/ui/core/date_labels.dart`
- Create: `lib/ui/session_detail/participant_filter.dart`
- Create: `lib/ui/session_detail/session_detail_viewmodel.dart`
- Test: `test/ui/core/date_labels_test.dart`
- Test: `test/ui/session_detail/participant_filter_test.dart`
- Test: `test/ui/session_detail/session_detail_viewmodel_test.dart`

**Interfaces:**
- Consumes: `SessionParticipant`, `ParticipationType`, `ParticipantStatus` (Task 2); `ParticipantRepository.watchBySession/syncSession/assign` e `SessionRepository.watchSession/start` (Task 3); `TrainingSession.responsibleConsultantId/participantsSyncedAt` (Task 1); `AuthUser`, `ConnectivityService`, `ApiException`.
- Produces:
  - `date_labels.dart`: `dayMonthYearLabel(DateTime)` → `'12 set 2026'`; `momentLabel(DateTime moment, DateTime now)` → `'hoje 08:12'` / `'12 set 08:12'` / `'30 dez 2025 09:00'` (converte para hora local); `offlineDataMessage(DateTime?)` → `'Sem conexão — dados de 20/09 às 08:03.'` ou nulo.
  - `participant_filter.dart`: `enum ParticipantFilter { todos, pendentes, meus, concluidos }` (com `label`); `enum ParticipantSituation { mine, pending, other, approved, needsReview, theoryOnly }`; `situationOf(p, myConsultantId)`; `matchesFilter(p, filter, myConsultantId)`; `sortForDisplay(list, myConsultantId)`; `class ParticipantProgress { assessed, assessable, fraction?, label, percentLabel }` e `progressOf(list)`; `chipLabelFor(p, situation)`; `blockedNoteFor(p, situation)`; `assessedAtLabelFor(p, situation, now)`.
  - `SessionDetailViewModel({required String sessionId, required SessionRepository sessionRepository, required ParticipantRepository participantRepository, required ConnectivityService connectivity, required AuthUser? currentUser, DateTime Function()? now})` com: `session`, `filter`, `isRefreshing`, `isStarting`, `assigningParticipantId`, `message`, `now`, `myConsultantId`, `hasConsultantProfile`, `neverDownloaded`, `isLoading`, `hasParticipants`, `evaluationOpen`, `canStartSession`, `hasPendingToAssign`, `progress`, `counts`, `visibleParticipants`; `situationFor(p)`, `canAssign(p)`, `opensChecklist(p)`, `opensResult(p)`; `init()`, `setFilter(f)`, `refresh()`, `assign(participantId)`, `startSession()`, `clearMessage()`.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/core/date_labels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/date_labels.dart';

void main() {
  final agora = DateTime(2026, 9, 23, 14);

  test('dayMonthYearLabel escreve a data da sessão por extenso curto', () {
    expect(dayMonthYearLabel(DateTime(2026, 9, 12)), '12 set 2026');
  });

  test('momentLabel diz "hoje" no mesmo dia', () {
    expect(momentLabel(DateTime(2026, 9, 23, 8, 5), agora), 'hoje 08:05');
  });

  test('momentLabel mostra dia e mês em outro dia do mesmo ano', () {
    expect(momentLabel(DateTime(2026, 9, 12, 17, 40), agora), '12 set 17:40');
  });

  test('momentLabel mostra o ano quando ele é outro', () {
    expect(momentLabel(DateTime(2025, 12, 30, 9, 0), agora), '30 dez 2025 09:00');
  });

  test('momentLabel converte um instante UTC para a hora local', () {
    final utc = DateTime.utc(2026, 9, 23, 11, 12);
    final local = utc.toLocal();
    String dois(int v) => v.toString().padLeft(2, '0');

    expect(momentLabel(utc, local), 'hoje ${dois(local.hour)}:${dois(local.minute)}');
  });

  test('offlineDataMessage diz a idade dos dados, e nada sem sync', () {
    expect(offlineDataMessage(DateTime(2026, 9, 20, 8, 3)),
        'Sem conexão — dados de 20/09 às 08:03.');
    expect(offlineDataMessage(null), isNull);
  });
}
```

Criar `test/ui/session_detail/participant_filter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/ui/session_detail/participant_filter.dart';

void main() {
  const eu = 'c-eu';

  SessionParticipant p(
    String id, {
    String? name,
    ParticipantStatus status = ParticipantStatus.pendente,
    ParticipationType type = ParticipationType.teoricaEPratica,
    String? assignedTo,
    String? assignedName,
    double? score,
    String? assessedBy,
    DateTime? assessedAt,
  }) {
    return SessionParticipant(
      id: id,
      sessionId: 'sess-1',
      name: name ?? 'Participante $id',
      maskedCpf: '042.118.***-**',
      participationType: type,
      status: status,
      assignedConsultantId: assignedTo,
      assignedConsultantName: assignedName,
      score: score,
      assessedByConsultantId: assessedBy,
      assessedAt: assessedAt,
    );
  }

  group('situationOf', () {
    test('somente teórica vence qualquer status', () {
      expect(
        situationOf(
          p('1', type: ParticipationType.somenteTeorica, status: ParticipantStatus.aprovado),
          eu,
        ),
        ParticipantSituation.theoryOnly,
      );
    });

    test('em avaliação é "meu" só quando a atribuição é minha', () {
      final comigo = p('1', status: ParticipantStatus.emAvaliacao, assignedTo: eu);
      final comOutro = p('2', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-2');

      expect(situationOf(comigo, eu), ParticipantSituation.mine);
      expect(situationOf(comOutro, eu), ParticipantSituation.other);
    });

    test('sem perfil de consultor, nada em avaliação é meu', () {
      final semDono = p('1', status: ParticipantStatus.emAvaliacao, assignedTo: null);

      expect(situationOf(semDono, null), ParticipantSituation.other);
    });

    test('aprovado e reavaliar são situações próprias', () {
      expect(situationOf(p('1', status: ParticipantStatus.aprovado), eu),
          ParticipantSituation.approved);
      expect(situationOf(p('2', status: ParticipantStatus.necessitaReavaliacao), eu),
          ParticipantSituation.needsReview);
    });
  });

  group('matchesFilter', () {
    final pendente = p('pend');
    final teorica = p('teo', type: ParticipationType.somenteTeorica);
    final meu = p('meu', status: ParticipantStatus.emAvaliacao, assignedTo: eu);
    final deOutro = p('outro', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-2');
    final avaliadoPorMim = p('ok-meu', status: ParticipantStatus.aprovado, assessedBy: eu);
    final avaliadoPorOutro =
        p('ok-outro', status: ParticipantStatus.necessitaReavaliacao, assessedBy: 'c-2');
    final todos = [pendente, teorica, meu, deOutro, avaliadoPorMim, avaliadoPorOutro];

    List<String> ids(ParticipantFilter filter) => todos
        .where((x) => matchesFilter(x, filter, eu))
        .map((x) => x.id)
        .toList();

    test('Todos traz todo mundo, inclusive quem é só da teórica', () {
      expect(ids(ParticipantFilter.todos), hasLength(6));
    });

    test('Pendentes deixa de fora quem é só da teórica', () {
      expect(ids(ParticipantFilter.pendentes), ['pend']);
    });

    test('Meus junta o que está comigo e o que eu avaliei', () {
      expect(ids(ParticipantFilter.meus), ['meu', 'ok-meu']);
    });

    test('Concluídos junta aprovados e aguardando reavaliação', () {
      expect(ids(ParticipantFilter.concluidos), ['ok-meu', 'ok-outro']);
    });
  });

  test('sortForDisplay segue a ordem do canvas e ignora acentos no nome', () {
    final lista = [
      p('teo', name: 'Simone Barbosa', type: ParticipationType.somenteTeorica),
      p('redo', name: 'Rodrigo Tavares', status: ParticipantStatus.necessitaReavaliacao),
      p('ok', name: 'Juliana Costa', status: ParticipantStatus.aprovado),
      p('outro', name: 'Marcos Alves', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-2'),
      p('pend-z', name: 'Zeca Nunes'),
      p('pend-a', name: 'Ângela Nunes'),
      p('meu', name: 'Ana Ribeiro', status: ParticipantStatus.emAvaliacao, assignedTo: eu),
    ];

    final ordem = sortForDisplay(lista, eu).map((x) => x.id).toList();

    expect(ordem, ['meu', 'pend-a', 'pend-z', 'outro', 'ok', 'redo', 'teo']);
  });

  test('progressOf conta só quem faz a prática', () {
    final progresso = progressOf([
      p('1', status: ParticipantStatus.aprovado),
      p('2', status: ParticipantStatus.necessitaReavaliacao),
      p('3'),
      p('4', status: ParticipantStatus.emAvaliacao, assignedTo: eu),
      p('5', type: ParticipationType.somenteTeorica),
    ]);

    expect(progresso.assessed, 2);
    expect(progresso.assessable, 4);
    expect(progresso.label, '2 de 4 participantes avaliados');
    expect(progresso.percentLabel, '50%');
    expect(progressOf([p('t', type: ParticipationType.somenteTeorica)]).fraction,
        isNull);
  });

  group('rótulos', () {
    test('o chip de quem está com outro usa primeiro e último nome', () {
      final x = p('1',
          status: ParticipantStatus.emAvaliacao,
          assignedTo: 'c-2',
          assignedName: 'Rafael Lima de Souza');

      expect(chipLabelFor(x, ParticipantSituation.other), 'Rafael Souza');
      expect(chipLabelFor(p('2', status: ParticipantStatus.emAvaliacao), ParticipantSituation.other),
          'Outro consultor');
    });

    test('reavaliação em andamento muda o rótulo e a nota', () {
      final minha = p('1', status: ParticipantStatus.emAvaliacao, assignedTo: eu, score: 62);
      final deOutro = p('2', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-2', score: 62);

      expect(chipLabelFor(minha, ParticipantSituation.mine), 'Reavaliando · você');
      expect(blockedNoteFor(deOutro, ParticipantSituation.other),
          'Em reavaliação com outro consultor.');
      expect(chipLabelFor(p('3', status: ParticipantStatus.emAvaliacao, assignedTo: eu),
          ParticipantSituation.mine), 'Avaliando · você');
    });

    test('o score é arredondado como no painel web', () {
      expect(chipLabelFor(p('1', status: ParticipantStatus.aprovado, score: 86.4),
          ParticipantSituation.approved), 'Aprovado · 86%');
      expect(chipLabelFor(p('2', status: ParticipantStatus.necessitaReavaliacao, score: 69.6),
          ParticipantSituation.needsReview), 'Reavaliar · 70%');
    });

    test('só quem está com outro tem nota de bloqueio', () {
      expect(blockedNoteFor(p('1'), ParticipantSituation.pending), isNull);
      expect(blockedNoteFor(p('2', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-2'),
          ParticipantSituation.other), 'Em avaliação com outro consultor.');
    });

    test('o horário da avaliação só aparece nos concluídos', () {
      final agora = DateTime(2026, 9, 23, 14);
      final avaliado = p('1',
          status: ParticipantStatus.aprovado,
          score: 90,
          assessedAt: DateTime(2026, 9, 23, 8, 12));

      expect(assessedAtLabelFor(avaliado, ParticipantSituation.approved, agora),
          'hoje 08:12');
      expect(assessedAtLabelFor(p('2'), ParticipantSituation.pending, agora), isNull);
    });
  });
}
```

Criar `test/ui/session_detail/session_detail_viewmodel_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/session_detail/participant_filter.dart';
import 'package:simtc/ui/session_detail/session_detail_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

/// Conectividade de mentira: o serviço real conversa com o plugin de
/// plataforma, que não existe num teste de unidade.
class _FakeConnectivity extends ConnectivityService {
  final _reconnected = StreamController<void>.broadcast();

  @override
  Stream<void> get onReconnected => _reconnected.stream;

  void reconnect() => _reconnected.add(null);

  @override
  void dispose() {
    _reconnected.close();
    super.dispose();
  }
}

void main() {
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late _FakeConnectivity connectivity;
  late StreamController<TrainingSession?> sessionStream;
  late StreamController<List<SessionParticipant>> participantsStream;

  const consultora = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-eu',
  );

  TrainingSession session({
    SessionStatus status = SessionStatus.emAndamento,
    String? responsible = 'c-resp',
    DateTime? participantsSyncedAt,
  }) {
    return TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell',
      courseName: 'Direção Defensiva',
      city: 'Itabira',
      state: 'MG',
      status: status,
      totalParticipants: 0,
      assessableParticipants: 0,
      assessedParticipants: 0,
      responsibleConsultantId: responsible,
      participantsSyncedAt: participantsSyncedAt ?? DateTime(2026, 9, 23, 8),
    );
  }

  SessionParticipant participant(
    String id, {
    ParticipantStatus status = ParticipantStatus.pendente,
    String? assignedTo,
    String? assessedBy,
  }) {
    return SessionParticipant(
      id: id,
      sessionId: 'sess-1',
      name: 'Participante $id',
      maskedCpf: '042.118.***-**',
      participationType: ParticipationType.teoricaEPratica,
      status: status,
      assignedConsultantId: assignedTo,
      assessedByConsultantId: assessedBy,
    );
  }

  SessionDetailViewModel build({AuthUser? user = consultora}) {
    return SessionDetailViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      connectivity: connectivity,
      currentUser: user,
      now: () => DateTime(2026, 9, 23, 14),
    );
  }

  /// Monta a VM já com a sessão e os participantes entregues pelo cache.
  Future<SessionDetailViewModel> ready({
    TrainingSession? withSession,
    List<SessionParticipant> withParticipants = const [],
    AuthUser? user = consultora,
  }) async {
    final vm = build(user: user)..init();
    sessionStream.add(withSession ?? session());
    participantsStream.add(withParticipants);
    await Future<void>.delayed(Duration.zero);
    return vm;
  }

  setUp(() {
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    connectivity = _FakeConnectivity();
    sessionStream = StreamController<TrainingSession?>.broadcast();
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
  });

  tearDown(() {
    sessionStream.close();
    participantsStream.close();
    connectivity.dispose();
  });

  test('baixa o detalhe ao abrir e de novo quando a conexão volta', () async {
    await ready();

    connectivity.reconnect();
    await Future<void>.delayed(Duration.zero);

    verify(() => participants.syncSession('sess-1')).called(2);
  });

  test('nunca baixada: fica carregando até a primeira descida terminar',
      () async {
    final download = Completer<Result<int>>();
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) => download.future);

    final vm = build()..init();
    sessionStream.add(const TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell',
      courseName: 'Direção Defensiva',
      city: 'Itabira',
      state: 'MG',
      status: SessionStatus.emAndamento,
      totalParticipants: 0,
      assessableParticipants: 0,
      assessedParticipants: 0,
    ));
    participantsStream.add(const []);
    await Future<void>.delayed(Duration.zero);

    expect(vm.isLoading, isTrue);

    download.complete(const Success(0));
    await Future<void>.delayed(Duration.zero);

    expect(vm.isLoading, isFalse);
    expect(vm.neverDownloaded, isTrue,
        reason: 'o stream da sessão ainda não trouxe participantsSyncedAt');
  });

  test('os chips filtram e os contadores não dependem do chip escolhido',
      () async {
    final vm = await ready(withParticipants: [
      participant('pend'),
      participant('meu', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu'),
      participant('ok', status: ParticipantStatus.aprovado, assessedBy: 'c-2'),
    ]);

    vm.setFilter(ParticipantFilter.meus);

    expect(vm.visibleParticipants.map((p) => p.id), ['meu']);
    expect(vm.counts[ParticipantFilter.todos], 3);
    expect(vm.counts[ParticipantFilter.pendentes], 1);
    expect(vm.counts[ParticipantFilter.concluidos], 1);
  });

  group('regras de ação', () {
    test('atribuir só com a sessão em andamento', () async {
      final emAndamento = await ready(withParticipants: [participant('p')]);
      expect(emAndamento.canAssign(participant('p')), isTrue);

      final planejada = await ready(
        withSession: session(status: SessionStatus.planejado),
        withParticipants: [participant('p')],
      );
      expect(planejada.canAssign(participant('p')), isFalse);
    });

    test('ADMIN sem perfil de consultor não atribui', () async {
      final vm = await ready(
        withParticipants: [participant('p')],
        user: const AuthUser(
          id: 'u2',
          name: 'Rita Alves',
          email: 'rita@simtc.com.br',
          role: AppUserRole.admin,
        ),
      );

      expect(vm.canAssign(participant('p')), isFalse);
      expect(vm.hasConsultantProfile, isFalse);
    });

    test('o checklist abre só para o meu participante, com a sessão aberta',
        () async {
      final meu =
          participant('meu', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final aberta = await ready(withParticipants: [meu]);
      expect(aberta.opensChecklist(meu), isTrue);

      final concluida = await ready(
        withSession: session(status: SessionStatus.concluido),
        withParticipants: [meu],
      );
      expect(concluida.opensChecklist(meu), isFalse);
    });

    test('o resultado abre em qualquer status de sessão', () async {
      final ok = participant('ok', status: ParticipantStatus.aprovado);
      final vm = await ready(
        withSession: session(status: SessionStatus.concluido),
        withParticipants: [ok],
      );

      expect(vm.opensResult(ok), isTrue);
    });

    test('iniciar é do responsável e do ADMIN, e só com a sessão planejada',
        () async {
      final responsavel = await ready(
        withSession: session(status: SessionStatus.planejado, responsible: 'c-eu'),
      );
      expect(responsavel.canStartSession, isTrue);

      final outro = await ready(
        withSession: session(status: SessionStatus.planejado, responsible: 'c-2'),
      );
      expect(outro.canStartSession, isFalse);

      final admin = await ready(
        withSession: session(status: SessionStatus.planejado, responsible: 'c-2'),
        user: const AuthUser(
          id: 'u2',
          name: 'Rita Alves',
          email: 'rita@simtc.com.br',
          role: AppUserRole.admin,
        ),
      );
      expect(admin.canStartSession, isTrue);

      final jaIniciada = await ready(
        withSession: session(status: SessionStatus.emAndamento, responsible: 'c-eu'),
      );
      expect(jaIniciada.canStartSession, isFalse);
    });
  });

  group('assign', () {
    test('atribui com meu id e meu nome, avisa e baixa o detalhe de novo',
        () async {
      when(() => participants.assign('p1',
              consultantId: 'c-eu', consultantName: 'Carla Souza'))
          .thenAnswer((_) async => const Success<void>(null));
      final vm = await ready(withParticipants: [participant('p1')]);

      await vm.assign('p1');
      await Future<void>.delayed(Duration.zero);

      expect(vm.message, 'Participante atribuído a você.');
      expect(vm.assigningParticipantId, isNull);
      verify(() => participants.syncSession('sess-1')).called(2);
    });

    test('conflito mostra o motivo e baixa o detalhe para mostrar com quem está',
        () async {
      when(() => participants.assign('p1',
              consultantId: any(named: 'consultantId'),
              consultantName: any(named: 'consultantName')))
          .thenAnswer((_) async => const Failure<void>(
                ApiException(
                  message: 'Um ou mais participantes já estão em avaliação com outro consultor',
                  statusCode: 409,
                ),
                'Um ou mais participantes já estão em avaliação com outro consultor',
              ));
      final vm = await ready(withParticipants: [participant('p1')]);

      await vm.assign('p1');
      await Future<void>.delayed(Duration.zero);

      expect(vm.message,
          'Um ou mais participantes já estão em avaliação com outro consultor');
      verify(() => participants.syncSession('sess-1')).called(2);
    });

    test('sem rede, avisa e não tenta baixar de novo', () async {
      when(() => participants.assign('p1',
              consultantId: any(named: 'consultantId'),
              consultantName: any(named: 'consultantName')))
          .thenAnswer((_) async => const Failure<void>(
                ApiException(message: 'Sem conexão com o servidor.', isNetworkError: true),
                'Sem conexão com o servidor.',
              ));
      final vm = await ready(withParticipants: [participant('p1')]);

      await vm.assign('p1');
      await Future<void>.delayed(Duration.zero);

      expect(vm.message, 'Sem conexão com o servidor.');
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('um segundo toque enquanto o primeiro não voltou é ignorado', () async {
      final resposta = Completer<Result<void>>();
      when(() => participants.assign(any(),
              consultantId: any(named: 'consultantId'),
              consultantName: any(named: 'consultantName')))
          .thenAnswer((_) => resposta.future);
      final vm = await ready(
        withParticipants: [participant('p1'), participant('p2')],
      );

      final primeiro = vm.assign('p1');
      await vm.assign('p2');
      expect(vm.assigningParticipantId, 'p1');

      resposta.complete(const Success<void>(null));
      await primeiro;

      verify(() => participants.assign(any(),
          consultantId: any(named: 'consultantId'),
          consultantName: any(named: 'consultantName'))).called(1);
    });
  });

  group('startSession', () {
    test('inicia, avisa e baixa o detalhe de novo', () async {
      when(() => sessions.start('sess-1'))
          .thenAnswer((_) async => const Success<void>(null));
      final vm = await ready(
        withSession: session(status: SessionStatus.planejado, responsible: 'c-eu'),
      );

      await vm.startSession();
      await Future<void>.delayed(Duration.zero);

      expect(vm.message, 'Sessão iniciada. Já dá para atribuir participantes.');
      verify(() => participants.syncSession('sess-1')).called(2);
    });

    test('falha vira mensagem, sem novo download', () async {
      when(() => sessions.start('sess-1')).thenAnswer(
        (_) async => const Failure<void>(
          ApiException(message: 'Sem conexão com o servidor.', isNetworkError: true),
          'Sem conexão com o servidor.',
        ),
      );
      final vm = await ready(
        withSession: session(status: SessionStatus.planejado, responsible: 'c-eu'),
      );

      await vm.startSession();

      expect(vm.message, 'Sem conexão com o servidor.');
      expect(vm.isStarting, isFalse);
      verify(() => participants.syncSession('sess-1')).called(1);
    });
  });

  test('falha ao atualizar vira mensagem, sem apagar a lista', () async {
    when(() => participants.syncSession('sess-1')).thenAnswer(
      (_) async => Failure(Exception('sem rede'),
          'Não foi possível atualizar. Mostrando os dados já baixados.'),
    );

    final vm = await ready(withParticipants: [participant('p1')]);

    expect(vm.message, 'Não foi possível atualizar. Mostrando os dados já baixados.');
    expect(vm.visibleParticipants, hasLength(1));
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/ui/core/date_labels_test.dart test/ui/session_detail/`
Esperado: FAIL na compilação — os três arquivos de produção não existem.

- [ ] **Step 3: Implementar os rótulos de data**

Criar `lib/ui/core/date_labels.dart`:

```dart
/// Rótulos de data e hora do app, sem depender dos dados de locale do `intl`
/// (que exigiriam inicialização assíncrona) — os meses abreviados são os
/// mesmos que a Home já usa nos cabeçalhos de dia.
const List<String> _meses = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _dois(int value) => value.toString().padLeft(2, '0');

/// "12 set 2026" — a data de uma sessão, no cabeçalho do detalhe.
String dayMonthYearLabel(DateTime date) =>
    '${date.day} ${_meses[date.month - 1]} ${date.year}';

/// Quando algo aconteceu, do jeito que se fala em campo: "hoje 08:12",
/// "12 set 08:12" ou, em outro ano, "12 set 2025 08:12". Converte para a hora
/// local — o instante pode ter vindo em UTC da API.
String momentLabel(DateTime moment, DateTime now) {
  final local = moment.toLocal();
  final hora = '${_dois(local.hour)}:${_dois(local.minute)}';
  final mesmoDia = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (mesmoDia) return 'hoje $hora';

  final dia = '${local.day} ${_meses[local.month - 1]}';
  return local.year == now.year ? '$dia $hora' : '$dia ${local.year} $hora';
}

/// Texto da faixa de offline: sem conexão, o consultor precisa saber a idade
/// do que está vendo — uma lista de ontem parece igualzinha a uma de agora.
/// Nulo quando nunca houve sync (aí a faixa usa a mensagem padrão dela).
String? offlineDataMessage(DateTime? syncedAt) {
  if (syncedAt == null) return null;
  final d = syncedAt.toLocal();
  return 'Sem conexão — dados de ${_dois(d.day)}/${_dois(d.month)} '
      'às ${_dois(d.hour)}:${_dois(d.minute)}.';
}
```

- [ ] **Step 4: Implementar as regras puras**

Criar `lib/ui/session_detail/participant_filter.dart`:

```dart
import '../../data/models/session_participant.dart';
import '../core/date_labels.dart';

/// Os quatro chips da tela 1.4. Aqui eles filtram de verdade (o canvas tem
/// "Todos"), ao contrário dos chips da Home, que são âncoras de rolagem.
enum ParticipantFilter {
  todos('Todos'),
  pendentes('Pendentes'),
  meus('Meus'),
  concluidos('Concluídos');

  const ParticipantFilter(this.label);

  final String label;
}

/// O que uma linha da lista é, do ponto de vista do consultor logado. A ordem
/// do enum é a ordem da lista no canvas: o trabalho dele primeiro, o que dá
/// para pegar em seguida, o que está com outro, os concluídos e, por último,
/// quem nem passa pela prática.
enum ParticipantSituation { mine, pending, other, approved, needsReview, theoryOnly }

ParticipantSituation situationOf(
  SessionParticipant participant,
  String? myConsultantId,
) {
  if (participant.participationType == ParticipationType.somenteTeorica) {
    return ParticipantSituation.theoryOnly;
  }
  return switch (participant.status) {
    ParticipantStatus.pendente => ParticipantSituation.pending,
    ParticipantStatus.emAvaliacao => myConsultantId != null &&
            participant.assignedConsultantId == myConsultantId
        ? ParticipantSituation.mine
        : ParticipantSituation.other,
    ParticipantStatus.aprovado => ParticipantSituation.approved,
    ParticipantStatus.necessitaReavaliacao => ParticipantSituation.needsReview,
  };
}

bool _isConcluded(ParticipantSituation situation) =>
    situation == ParticipantSituation.approved ||
    situation == ParticipantSituation.needsReview;

/// Regra dos chips (decidida com o usuário em 23/09/2026):
/// - **Pendentes**: ninguém pegou ainda (quem é só da teórica não entra);
/// - **Meus**: em avaliação comigo **e** os que eu mesmo avaliei;
/// - **Concluídos**: aprovados e aguardando reavaliação.
bool matchesFilter(
  SessionParticipant participant,
  ParticipantFilter filter,
  String? myConsultantId,
) {
  final situation = situationOf(participant, myConsultantId);
  return switch (filter) {
    ParticipantFilter.todos => true,
    ParticipantFilter.pendentes => situation == ParticipantSituation.pending,
    ParticipantFilter.meus => situation == ParticipantSituation.mine ||
        (_isConcluded(situation) &&
            myConsultantId != null &&
            participant.assessedByConsultantId == myConsultantId),
    ParticipantFilter.concluidos => _isConcluded(situation),
  };
}

/// Posição do grupo na lista — aprovados e reavaliar dividem o mesmo grupo
/// ("concluídos"), em ordem de nome entre si, como no canvas.
int _groupOf(ParticipantSituation situation) => switch (situation) {
      ParticipantSituation.mine => 0,
      ParticipantSituation.pending => 1,
      ParticipantSituation.other => 2,
      ParticipantSituation.approved || ParticipantSituation.needsReview => 3,
      ParticipantSituation.theoryOnly => 4,
    };

const Map<String, String> _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c',
};

/// Chave de ordenação por nome que põe "Ângela" junto de "Ana", e não depois
/// de "Zeca" — o SQLite só ignora caixa em letras sem acento.
String _nameKey(String name) {
  final lower = name.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_semAcento[char] ?? char);
  }
  return buffer.toString();
}

/// A lista na ordem do canvas: por grupo e, dentro do grupo, por nome.
/// Comparador completo (e não um `sort` estável sobre a ordem do banco),
/// porque o `List.sort` do Dart não garante estabilidade.
List<SessionParticipant> sortForDisplay(
  List<SessionParticipant> participants,
  String? myConsultantId,
) {
  final sorted = [...participants];
  sorted.sort((a, b) {
    final byGroup = _groupOf(situationOf(a, myConsultantId))
        .compareTo(_groupOf(situationOf(b, myConsultantId)));
    if (byGroup != 0) return byGroup;
    return _nameKey(a.name).compareTo(_nameKey(b.name));
  });
  return sorted;
}

/// "X de Y participantes avaliados" do cabeçalho — a mesma regra do
/// `participantStats` do backend: só quem faz a prática entra na conta.
class ParticipantProgress {
  const ParticipantProgress({required this.assessed, required this.assessable});

  final int assessed;
  final int assessable;

  /// De 0 a 1; nulo quando ninguém faz a prática (aí não há barra).
  double? get fraction => assessable <= 0 ? null : assessed / assessable;

  String get label => '$assessed de $assessable participantes avaliados';

  String get percentLabel => '${((fraction ?? 0) * 100).round()}%';
}

ParticipantProgress progressOf(List<SessionParticipant> participants) {
  final assessable = participants
      .where((p) => p.participationType == ParticipationType.teoricaEPratica)
      .toList(growable: false);
  return ParticipantProgress(
    assessed: assessable.where((p) => p.isAssessed).length,
    assessable: assessable.length,
  );
}

/// "Rafael Lima" de "Rafael Lima de Souza": o chip é estreito, e o primeiro e
/// o último nome bastam para o consultor saber com quem falar.
String _shortName(String fullName) {
  final words =
      fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length <= 2) return words.join(' ');
  return '${words.first} ${words.last}';
}

/// Score arredondado como no painel web (`Math.round`), para os números
/// baterem — inclusive o 69,6 que aparece "70%" ao lado de "Reavaliar".
String _percent(double? score) => score == null ? '' : ' · ${score.round()}%';

String chipLabelFor(
  SessionParticipant participant,
  ParticipantSituation situation,
) {
  return switch (situation) {
    ParticipantSituation.theoryOnly => 'Somente teórica',
    ParticipantSituation.pending => 'Pendente',
    ParticipantSituation.mine => participant.hasPreviousAssessment
        ? 'Reavaliando · você'
        : 'Avaliando · você',
    ParticipantSituation.other =>
      _shortName(participant.assignedConsultantName ?? '').isEmpty
          ? 'Outro consultor'
          : _shortName(participant.assignedConsultantName!),
    ParticipantSituation.approved => 'Aprovado${_percent(participant.score)}',
    ParticipantSituation.needsReview =>
      'Reavaliar${_percent(participant.score)}',
  };
}

/// Explica por que a linha não tem ação. Só existe para quem está com outro
/// consultor — o canvas tinha "desde 08:29", mas o backend não guarda quando
/// a atribuição aconteceu.
String? blockedNoteFor(
  SessionParticipant participant,
  ParticipantSituation situation,
) {
  if (situation != ParticipantSituation.other) return null;
  return participant.hasPreviousAssessment
      ? 'Em reavaliação com outro consultor.'
      : 'Em avaliação com outro consultor.';
}

/// "hoje 08:12" dos concluídos. Nulo para quem ainda não tem avaliação.
String? assessedAtLabelFor(
  SessionParticipant participant,
  ParticipantSituation situation,
  DateTime now,
) {
  if (!_isConcluded(situation) || participant.assessedAt == null) return null;
  return momentLabel(participant.assessedAt!, now);
}
```

- [ ] **Step 5: Implementar a ViewModel**

Criar `lib/ui/session_detail/session_detail_viewmodel.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../data/services/connectivity_service.dart';
import '../../utils/result.dart';
import 'participant_filter.dart';

/// Estado da tela 1.4 "Detalhe da sessão".
///
/// Como na Home, nada vem da resposta HTTP: a sessão e os participantes
/// chegam pelos streams do cache, e o sync é um efeito colateral que o
/// atualiza. As regras de quem pode fazer o quê espelham o `getAction` do
/// painel web (`session-management-drawer.tsx`): atribuir e abrir o checklist
/// só com a sessão em andamento; o resultado abre sempre.
class SessionDetailViewModel extends ChangeNotifier {
  SessionDetailViewModel({
    required this.sessionId,
    required SessionRepository sessionRepository,
    required ParticipantRepository participantRepository,
    required ConnectivityService connectivity,
    required AuthUser? currentUser,
    DateTime Function()? now,
  })  : _sessionRepository = sessionRepository,
        _participantRepository = participantRepository,
        _connectivity = connectivity,
        _currentUser = currentUser,
        _now = now ?? DateTime.now;

  final String sessionId;
  final SessionRepository _sessionRepository;
  final ParticipantRepository _participantRepository;
  final ConnectivityService _connectivity;
  final AuthUser? _currentUser;
  final DateTime Function() _now;

  static const String _refreshFailed =
      'Não foi possível atualizar os participantes.';
  static const String _assignFailed =
      'Não foi possível atribuir o participante. Tente de novo.';
  static const String _startFailed =
      'Não foi possível iniciar a sessão. Tente de novo.';

  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<List<SessionParticipant>>? _participantsSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  TrainingSession? _session;
  List<SessionParticipant> _participants = const [];
  bool _sessionLoaded = false;
  bool _participantsLoaded = false;
  bool _isRefreshing = false;
  bool _isStarting = false;
  String? _assigningParticipantId;
  ParticipantFilter _filter = ParticipantFilter.todos;
  String? _message;

  /// Nula depois de carregada quer dizer que a sessão não está mais no
  /// aparelho (a Home podou, por exemplo).
  TrainingSession? get session => _session;
  ParticipantFilter get filter => _filter;
  bool get isRefreshing => _isRefreshing;
  bool get isStarting => _isStarting;

  /// Participante com atribuição em andamento — só um de cada vez.
  String? get assigningParticipantId => _assigningParticipantId;

  /// Aviso passageiro (SnackBar) — sucesso ou falha de uma ação.
  String? get message => _message;

  /// Relógio da tela — injetável para os testes de "hoje 08:12".
  DateTime get now => _now();

  String? get myConsultantId => _currentUser?.consultantId;

  /// Um ADMIN sem perfil de consultor acompanha a sessão, mas não avalia — o
  /// backend recusa a atribuição, e o web também esconde a ação.
  bool get hasConsultantProfile => myConsultantId != null;

  /// Os participantes desta sessão nunca foram baixados neste aparelho — que
  /// é diferente de "baixados, e a sessão não tem ninguém".
  bool get neverDownloaded => _session?.participantsSyncedAt == null;

  /// Antes da primeira leitura do cache é sempre carregamento. Depois, só
  /// enquanto a primeira descida dos participantes ainda está em andamento —
  /// sem isso, a tela diria "nenhum participante" enquanto baixa em 4G ruim.
  bool get isLoading =>
      !_sessionLoaded ||
      !_participantsLoaded ||
      (neverDownloaded && _participants.isEmpty && _isRefreshing);

  bool get hasParticipants => _participants.isNotEmpty;

  /// Atribuir e abrir o checklist só valem com a sessão em andamento.
  bool get evaluationOpen => _session?.status == SessionStatus.emAndamento;

  /// Iniciar é do ADMIN e do consultor responsável — a mesma checagem do
  /// backend em `POST /training-sessions/:id/start`.
  bool get canStartSession {
    final session = _session;
    if (session == null || session.status != SessionStatus.planejado) {
      return false;
    }
    if (_currentUser?.isAdmin == true) return true;
    return myConsultantId != null &&
        session.responsibleConsultantId == myConsultantId;
  }

  /// Há alguém que eu poderia atribuir agora — é quando o aviso de "atribuir
  /// precisa de internet" faz sentido.
  bool get hasPendingToAssign => _participants.any(canAssign);

  ParticipantProgress get progress => progressOf(_participants);

  Map<ParticipantFilter, int> get counts => {
        for (final filter in ParticipantFilter.values)
          filter: _participants
              .where((p) => matchesFilter(p, filter, myConsultantId))
              .length,
      };

  /// A lista do chip escolhido, na ordem do canvas.
  List<SessionParticipant> get visibleParticipants => sortForDisplay(
        _participants
            .where((p) => matchesFilter(p, _filter, myConsultantId))
            .toList(growable: false),
        myConsultantId,
      );

  ParticipantSituation situationFor(SessionParticipant participant) =>
      situationOf(participant, myConsultantId);

  bool canAssign(SessionParticipant participant) =>
      evaluationOpen &&
      hasConsultantProfile &&
      situationFor(participant) == ParticipantSituation.pending;

  bool opensChecklist(SessionParticipant participant) =>
      evaluationOpen && situationFor(participant) == ParticipantSituation.mine;

  bool opensResult(SessionParticipant participant) {
    final situation = situationFor(participant);
    return situation == ParticipantSituation.approved ||
        situation == ParticipantSituation.needsReview;
  }

  /// Assina o cache e dispara o primeiro sync. Chamado uma vez pela tela.
  void init() {
    _sessionSubscription ??=
        _sessionRepository.watchSession(sessionId).listen((session) {
      _session = session;
      _sessionLoaded = true;
      notifyListeners();
    });

    _participantsSubscription ??= _participantRepository
        .watchBySession(sessionId)
        .listen((participants) {
      _participants = participants;
      _participantsLoaded = true;
      notifyListeners();
    });

    _reconnectSubscription ??=
        _connectivity.onReconnected.listen((_) => refresh());

    unawaited(refresh());
  }

  void setFilter(ParticipantFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  /// Abertura da tela, puxar para atualizar e volta da conexão caem aqui.
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    notifyListeners();

    try {
      final result = await _participantRepository.syncSession(sessionId);
      if (result case Failure(:final message)) {
        _message = message ?? _refreshFailed;
      }
    } catch (_) {
      // Rede de segurança: `syncSession` já devolve `Result` para todo erro
      // esperado. Sem ela, `_isRefreshing` travaria em `true`.
      _message = _refreshFailed;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// "Atribuir a mim". Depois da resposta, baixa o detalhe de novo: no
  /// sucesso, para ficar com o estado oficial; no conflito, para a linha
  /// mostrar com quem o participante está.
  Future<void> assign(String participantId) async {
    final user = _currentUser;
    final consultantId = user?.consultantId;
    if (_assigningParticipantId != null || user == null || consultantId == null) {
      return;
    }

    _assigningParticipantId = participantId;
    notifyListeners();

    var resync = false;
    try {
      final result = await _participantRepository.assign(
        participantId,
        consultantId: consultantId,
        consultantName: user.name,
      );
      switch (result) {
        case Success():
          _message = 'Participante atribuído a você.';
          resync = true;
        case Failure(:final exception, :final message):
          _message = message ?? _assignFailed;
          // Sem rede, o re-sync falharia do mesmo jeito e só empilharia um
          // segundo aviso em cima deste.
          resync = exception is! ApiException || !exception.isNetworkError;
      }
    } catch (_) {
      _message = _assignFailed;
    } finally {
      _assigningParticipantId = null;
      notifyListeners();
    }

    if (resync) unawaited(refresh());
  }

  /// "Iniciar sessão" — só o responsável ou um ADMIN chegam a ver o botão.
  Future<void> startSession() async {
    if (_isStarting || !canStartSession) return;

    _isStarting = true;
    notifyListeners();

    var resync = false;
    try {
      final result = await _sessionRepository.start(sessionId);
      switch (result) {
        case Success():
          _message = 'Sessão iniciada. Já dá para atribuir participantes.';
          resync = true;
        case Failure(:final message):
          _message = message ?? _startFailed;
      }
    } catch (_) {
      _message = _startFailed;
    } finally {
      _isStarting = false;
      notifyListeners();
    }

    if (resync) unawaited(refresh());
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _participantsSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
```

Por que o re-sync depois do `assign` é condicional: no sucesso ele traz o estado oficial; no conflito (409) ele mostra com quem o participante ficou; **sem rede ele não roda**, porque falharia do mesmo jeito e empilharia um segundo SnackBar em cima do primeiro.

- [ ] **Step 6: Rodar os testes e confirmar que passam**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **185 testes passando**.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/core/date_labels.dart lib/ui/session_detail/participant_filter.dart lib/ui/session_detail/session_detail_viewmodel.dart test/ui/core/date_labels_test.dart test/ui/session_detail/participant_filter_test.dart test/ui/session_detail/session_detail_viewmodel_test.dart
git commit -m "feat(mobile): regras e estado da tela de detalhe da sessao"
```

---

## Task 6: Componentes do DS — barra das telas empilhadas, indicador de sync e botão de CTA

**Files:**
- Modify: `lib/ui/core/theme/app_colors.dart`, `lib/ui/core/theme/app_typography.dart`, `lib/ui/core/theme/app_icons.dart`
- Modify: `lib/ui/core/widgets/app_buttons.dart` (`AppCtaButton`)
- Create: `lib/ui/core/widgets/app_top_bar.dart`
- Create: `lib/ui/core/widgets/sync_status_indicator.dart`
- Test: `test/ui/core/widgets/form_widgets_test.dart`
- Test: `test/ui/core/widgets/display_widgets_test.dart`

**Interfaces:**
- Consumes: nada de tasks anteriores (só o DS existente).
- Produces:
  - `AppColors.ctaInk` (`#3D2500`).
  - `AppTypography.detailTitle` (Inter 18/w600), `AppTypography.buttonCompact` (Inter 14/w700, `ctaInk`), `AppTypography.code` (JetBrains Mono 12/w600, `text3`).
  - `AppIcons.back`, `place`, `event`, `notes`, `startSession`, `assign`, `notStarted`, `evaluating`, `lockedByOther`.
  - `AppCtaButton({required String label, VoidCallback? onPressed, bool isLoading = false, IconData? icon})` — 48dp de altura, largura total.
  - `AppTopBar({required String title, Widget? trailing})` — voltar com `Navigator.maybePop`, tooltip `'Voltar'`.
  - `SyncStatusIndicator()` — o mesmo ícone que a Home desenha hoje em `_buildSyncIndicator`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/core/widgets/form_widgets_test.dart`, logo antes de `group('AppCheckbox', () {`:

```dart
  group('AppCtaButton', () {
    testWidgets('dispara a ação e tem pelo menos o alvo mínimo de toque',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AppCtaButton(
          label: 'Atribuir a mim',
          icon: AppIcons.assign,
          onPressed: () => taps++,
        ),
      );

      await tester.tap(find.text('Atribuir a mim'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(AppCtaButton)).height,
          greaterThanOrEqualTo(48));
    });

    testWidgets('em carregamento mostra o indicador e não responde ao toque',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AppCtaButton(
          label: 'Atribuir a mim',
          isLoading: true,
          onPressed: () => taps++,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppCtaButton));
      expect(taps, 0);
    });

    testWidgets('sem ação, fica desabilitado', (tester) async {
      await _pump(tester, const AppCtaButton(label: 'Atribuir a mim'));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });
```

Em `test/ui/core/widgets/display_widgets_test.dart`, acrescentar os imports `package:simtc/ui/core/widgets/app_top_bar.dart` (depois do de `app_theme.dart`) e `package:simtc/ui/core/widgets/sync_status_indicator.dart` (depois do de `status_chip.dart`), e no fim do `main()`:

```dart
  testWidgets('AppTopBar mostra o título e o voltar desempilha a tela',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: AppTopBar(
                        title: 'Detalhe da sessão',
                        trailing: SyncStatusIndicator(),
                      ),
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhe da sessão'), findsOneWidget);
    expect(find.byIcon(AppIcons.syncDone), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhe da sessão'), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/ui/core/widgets/`
Esperado: FAIL na compilação — `AppCtaButton`, `AppIcons.assign`, `AppTopBar` e `SyncStatusIndicator` não existem.

- [ ] **Step 3: Tokens novos**

Em `lib/ui/core/theme/app_colors.dart`, depois de `ctaSoft`:

```dart

  /// Tinta sobre o laranja de CTA ("Atribuir a mim") — branco sobre #F5A520
  /// não passa no contraste; o canvas usa este marrom escuro.
  static const Color ctaInk = Color(0xFF3D2500);
```

Em `lib/ui/core/theme/app_typography.dart`, depois de `cardTitle`:

```dart

  /// Nome da empresa no cabeçalho do detalhe da sessão
  static TextStyle get detailTitle =>
      _inter(size: 18, weight: FontWeight.w600, height: 1.25);
```

depois de `button`:

```dart

  /// Texto de botão compacto, dentro de uma linha de lista ("Atribuir a mim")
  static TextStyle get buttonCompact =>
      _inter(size: 14, weight: FontWeight.w700, height: 1.2, color: AppColors.ctaInk);
```

e depois de `counter`:

```dart

  /// CPF mascarado, cronômetro e códigos — o token "code / mono" do canvas
  static TextStyle get code =>
      _mono(size: 12, weight: FontWeight.w600, height: 1.2, color: AppColors.text3);
```

Em `lib/ui/core/theme/app_icons.dart`, depois de `logout`:

```dart
  static const IconData back = Icons.chevron_left;
  static const IconData place = Icons.place_outlined;
  static const IconData event = Icons.event_outlined;
  static const IconData notes = Icons.sticky_note_2_outlined;
  static const IconData startSession = Icons.play_arrow_rounded;
  static const IconData assign = Icons.person_add_alt_1_outlined;

  /// Participante: pendente, em avaliação comigo e com outro consultor
  static const IconData notStarted = Icons.radio_button_unchecked;
  static const IconData evaluating = Icons.play_circle_outline;
  static const IconData lockedByOther = Icons.lock_outline;
```

- [ ] **Step 4: `AppCtaButton`**

No fim de `lib/ui/core/widgets/app_buttons.dart`:

```dart
/// Botão de chamada para ação em laranja, na altura mínima de toque — para
/// ações dentro de uma linha de lista, como "Atribuir a mim". O canvas o
/// desenha com 36dp; aqui ele tem 48dp, o alvo mínimo do DS (o consultor usa
/// o app dentro do veículo).
class AppCtaButton extends StatelessWidget {
  const AppCtaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cta,
          foregroundColor: AppColors.ctaInk,
          disabledBackgroundColor: isLoading ? AppColors.cta : AppColors.border,
          disabledForegroundColor:
              isLoading ? AppColors.ctaInk : AppColors.textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.buttonCompact,
        ),
        child: isLoading ? _buildSpinner() : _buildContent(),
      ),
    );
  }

  Widget _buildSpinner() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.ctaInk),
      ),
    );
  }

  Widget _buildContent() {
    // Sem `style` no `Text`: a cor vem do botão, e assim o rótulo fica cinza
    // junto com o fundo quando o botão está desabilitado (offline).
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 19),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
```

- [ ] **Step 5: `AppTopBar` e `SyncStatusIndicator`**

Criar `lib/ui/core/widgets/app_top_bar.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Barra superior das telas empilhadas (detalhe da sessão e, nas próximas
/// fases, checklist, resumo e resultado): voltar à esquerda, título
/// centralizado e, opcionalmente, um atalho à direita.
///
/// O lado direito sempre reserva o espaço de um alvo de toque, com ou sem
/// atalho — é o que mantém o título no centro da tela.
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          SizedBox.square(
            dimension: AppSpacing.touchTarget,
            child: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(AppIcons.back, size: 30, color: AppColors.text),
              // `maybePop` funciona igual sob o go_router e num
              // `MaterialApp` simples de teste.
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: AppTypography.appBarTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox.square(dimension: AppSpacing.touchTarget, child: trailing),
        ],
      ),
    );
  }
}
```

Criar `lib/ui/core/widgets/sync_status_indicator.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';

/// Indicador de avaliações esperando envio, no canto do cabeçalho da Home e
/// do detalhe da sessão. Fica sem badge até a Fase 4 criar a fila local; já
/// existe para o consultor aprender onde olhar — e para a Fase 4 mudar um
/// lugar só.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: AppSpacing.touchTarget,
      height: AppSpacing.touchTarget,
      child: Icon(AppIcons.syncDone, color: AppColors.text3),
    );
  }
}
```

- [ ] **Step 6: Rodar os testes e confirmar que passam**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **189 testes passando**.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/core/theme/app_colors.dart lib/ui/core/theme/app_typography.dart lib/ui/core/theme/app_icons.dart lib/ui/core/widgets/app_buttons.dart lib/ui/core/widgets/app_top_bar.dart lib/ui/core/widgets/sync_status_indicator.dart test/ui/core/widgets/form_widgets_test.dart test/ui/core/widgets/display_widgets_test.dart
git commit -m "feat(mobile): componentes do DS para telas empilhadas e acoes de lista"
```

---

## Task 7: Tela 1.4, rotas e toque no card da Home

**Files:**
- Create: `lib/ui/sessions/session_status_style.dart`
- Create: `lib/ui/session_detail/participant_row.dart`
- Create: `lib/ui/session_detail/session_detail_screen.dart`
- Create: `lib/ui/evaluation/evaluation_placeholder_screen.dart`
- Modify: `lib/router.dart`
- Modify: `lib/app_providers.dart`
- Modify: `lib/ui/sessions/sessions_screen.dart`
- Test: `test/ui/session_detail/session_detail_screen_test.dart`
- Test: `test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: tudo das Tasks 1–6 — em especial `SessionDetailViewModel` e as funções de `participant_filter.dart` (Task 5), `ParticipantRepository` (Task 3), `AppTopBar`, `SyncStatusIndicator`, `AppCtaButton`, tokens e ícones (Task 6), `AppTypography.sectionTitle` (Task 0), `offlineDataMessage`/`dayMonthYearLabel` (Task 5).
- Produces:
  - `SessionDetailScreen({required String sessionId})`.
  - `EvaluationPlaceholderScreen({required EvaluationPlaceholderKind kind, String? participantName})` e `enum EvaluationPlaceholderKind { checklist, result }` — as Fases 4 e 5 trocam o builder das rotas e apagam este arquivo.
  - `AppRoutes.sessionDetail(sessionId)` → `/sessions/:id`; `AppRoutes.participantChecklist(sessionId, participantId)` → `/sessions/:id/participants/:pid/checklist`; `AppRoutes.participantResult(...)` → `.../result`. O nome do participante vai no `extra`.
  - `createRouter(AuthRepository auth, {String initialLocation = AppRoutes.splash})` — o parâmetro só muda nos testes.
  - `extension SessionStatusStyle on SessionStatus { tone, icon, accentColor }`.
  - `AppDependencies.participantRepository` + `Provider<ParticipantRepository>`.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/session_detail/session_detail_screen_test.dart` — os testes de navegação usam o `createRouter` de produção, então provam também que os caminhos de `AppRoutes` casam com as rotas registradas:

```dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/evaluation/evaluation_placeholder_screen.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late _MockAuthRepository auth;
  late ConnectivityService connectivity;
  late StreamController<TrainingSession?> sessionStream;
  late StreamController<List<SessionParticipant>> participantsStream;

  const consultora = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-eu',
  );

  TrainingSession session({
    SessionStatus status = SessionStatus.emAndamento,
    String? responsible = 'c-resp',
    bool downloaded = true,
  }) {
    return TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell Celulose',
      courseName: 'Direção Defensiva — Veículo Pesado',
      city: 'Itabira',
      state: 'MG',
      date: DateTime(2026, 9, 12),
      status: status,
      notes: 'Pátio 3 — apresentar-se na portaria B às 07h30.',
      totalParticipants: 0,
      assessableParticipants: 0,
      assessedParticipants: 0,
      responsibleConsultantId: responsible,
      participantsSyncedAt: downloaded ? DateTime(2026, 9, 23, 8) : null,
    );
  }

  SessionParticipant participant(
    String id,
    String name, {
    ParticipantStatus status = ParticipantStatus.pendente,
    ParticipationType type = ParticipationType.teoricaEPratica,
    String? assignedTo,
    String? assignedName,
    double? score,
  }) {
    return SessionParticipant(
      id: id,
      sessionId: 'sess-1',
      name: name,
      maskedCpf: '042.118.***-**',
      participationType: type,
      status: status,
      assignedConsultantId: assignedTo,
      assignedConsultantName: assignedName,
      score: score,
    );
  }

  setUp(() {
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    auth = _MockAuthRepository();
    connectivity = ConnectivityService();
    sessionStream = StreamController<TrainingSession?>.broadcast();
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
    when(() => auth.currentUser).thenReturn(consultora);
    when(() => auth.isAuthenticated).thenReturn(true);
  });

  tearDown(() {
    sessionStream.close();
    participantsStream.close();
    connectivity.dispose();
  });

  Widget withProviders(Widget child) {
    return MultiProvider(
      providers: [
        Provider<SessionRepository>.value(value: sessions),
        Provider<ParticipantRepository>.value(value: participants),
        ChangeNotifierProvider<AuthRepository>.value(value: auth),
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
      ],
      child: child,
    );
  }

  /// Tela alta: a lista inteira fica montada, sem depender de rolagem.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> show(
    WidgetTester tester, {
    TrainingSession? withSession,
    List<SessionParticipant> withParticipants = const [],
  }) async {
    tallScreen(tester);
    await tester.pumpWidget(
      withProviders(
        const MaterialApp(home: SessionDetailScreen(sessionId: 'sess-1')),
      ),
    );
    sessionStream.add(withSession ?? session());
    participantsStream.add(withParticipants);
    await tester.pump();
  }

  Future<void> goOffline() async {
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity)
        .thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged)
        .thenAnswer((_) => const Stream.empty());
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  testWidgets('mostra skeleton antes da primeira leitura do cache',
      (tester) async {
    await tester.pumpWidget(
      withProviders(
        const MaterialApp(home: SessionDetailScreen(sessionId: 'sess-1')),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('session-detail-skeleton')), findsOneWidget);
  });

  testWidgets(
      'o cabeçalho mostra empresa, curso, local, data, status, observações e '
      'progresso', (tester) async {
    await show(tester, withParticipants: [
      participant('a', 'Ana Paula Ribeiro', status: ParticipantStatus.aprovado, score: 90),
      participant('b', 'Bruno Lima'),
    ]);

    expect(find.text('Bracell Celulose'), findsOneWidget);
    expect(find.text('Direção Defensiva — Veículo Pesado'), findsOneWidget);
    expect(find.text('Itabira/MG'), findsOneWidget);
    expect(find.text('12 set 2026'), findsOneWidget);
    expect(find.text('Em andamento'), findsOneWidget);
    expect(find.text('Pátio 3 — apresentar-se na portaria B às 07h30.'),
        findsOneWidget);
    expect(find.text('1 de 2 participantes avaliados'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('BC'), findsOneWidget, reason: 'iniciais no lugar do logo');
  });

  testWidgets('cada situação de participante tem o seu chip', (tester) async {
    await show(tester, withParticipants: [
      participant('1', 'Ana Paula Ribeiro',
          status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu'),
      participant('2', 'Carlos Eduardo Nunes'),
      participant('3', 'Marcos Vinícius Alves',
          status: ParticipantStatus.emAvaliacao,
          assignedTo: 'c-2',
          assignedName: 'Rafael Lima'),
      participant('4', 'Juliana Freitas Costa',
          status: ParticipantStatus.aprovado, score: 86.4),
      participant('5', 'Rodrigo Tavares',
          status: ParticipantStatus.necessitaReavaliacao, score: 62),
      participant('6', 'Simone Barbosa', type: ParticipationType.somenteTeorica),
    ]);

    expect(find.text('Avaliando · você'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
    expect(find.text('Rafael Lima'), findsOneWidget);
    expect(find.text('Em avaliação com outro consultor.'), findsOneWidget);
    expect(find.text('Aprovado · 86%'), findsOneWidget);
    expect(find.text('Reavaliar · 62%'), findsOneWidget);
    expect(find.text('Somente teórica'), findsOneWidget);
    expect(find.text('042.118.***-**'), findsNWidgets(6));
  });

  testWidgets('"Atribuir a mim" chama o repositório com o consultor logado',
      (tester) async {
    when(() => participants.assign('2',
            consultantId: 'c-eu', consultantName: 'Carla Souza'))
        .thenAnswer((_) async => const Success<void>(null));

    await show(tester, withParticipants: [
      participant('2', 'Carlos Eduardo Nunes'),
    ]);

    await tester.tap(find.text('Atribuir a mim'));
    await tester.pump(); // resposta do assign
    await tester.pump(); // post-frame do SnackBar
    await tester.pump(const Duration(milliseconds: 750));

    verify(() => participants.assign('2',
        consultantId: 'c-eu', consultantName: 'Carla Souza')).called(1);
    expect(find.text('Participante atribuído a você.'), findsOneWidget);
  });

  testWidgets('offline, "Atribuir a mim" fica desabilitado e o aviso explica',
      (tester) async {
    await goOffline();

    await show(tester, withParticipants: [
      participant('2', 'Carlos Eduardo Nunes'),
    ]);

    final button = tester.widget<AppCtaButton>(find.byType(AppCtaButton));
    expect(button.onPressed, isNull);
    expect(
      find.text('Sem conexão: dá para ver a lista e abrir quem já é seu, '
          'mas atribuir precisa de internet.'),
      findsOneWidget,
    );
  });

  testWidgets('sessão planejada não oferece "Atribuir a mim"', (tester) async {
    await show(
      tester,
      withSession: session(status: SessionStatus.planejado, responsible: 'c-2'),
      withParticipants: [participant('2', 'Carlos Eduardo Nunes')],
    );

    expect(find.text('Atribuir a mim'), findsNothing);
    expect(find.text('Iniciar sessão'), findsNothing);
    expect(
      find.text('Aguardando o responsável iniciar a sessão para atribuir e '
          'avaliar participantes.'),
      findsOneWidget,
    );
  });

  testWidgets('o responsável inicia a sessão depois de confirmar',
      (tester) async {
    when(() => sessions.start('sess-1'))
        .thenAnswer((_) async => const Success<void>(null));

    await show(
      tester,
      withSession: session(status: SessionStatus.planejado, responsible: 'c-eu'),
    );

    await tester.tap(find.text('Iniciar sessão'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar a sessão?'), findsOneWidget);

    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();

    verify(() => sessions.start('sess-1')).called(1);
  });

  testWidgets('sessão nunca baixada avisa, em vez de dizer que está vazia',
      (tester) async {
    await show(tester, withSession: session(downloaded: false));

    expect(
      find.text('Os participantes desta sessão ainda não foram baixados. '
          'Puxe para atualizar quando houver conexão.'),
      findsOneWidget,
    );
    expect(find.text('Nenhum participante inscrito nesta sessão.'), findsNothing);
  });

  testWidgets('os chips filtram a lista', (tester) async {
    await show(tester, withParticipants: [
      participant('2', 'Carlos Eduardo Nunes'),
      participant('4', 'Juliana Freitas Costa',
          status: ParticipantStatus.aprovado, score: 86),
    ]);

    // Com os contadores, os quatro chips não cabem em 420px: traz
    // "Concluídos" para a faixa visível antes do toque.
    await tester.ensureVisible(find.widgetWithText(InkWell, 'Concluídos'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Concluídos'));
    await tester.pump();

    expect(find.text('Juliana Freitas Costa'), findsOneWidget);
    expect(find.text('Carlos Eduardo Nunes'), findsNothing);
  });

  group('navegação pelas rotas reais', () {
    Future<void> showWithRouter(
      WidgetTester tester,
      List<SessionParticipant> list,
    ) async {
      tallScreen(tester);
      final router = createRouter(
        auth,
        initialLocation: AppRoutes.sessionDetail('sess-1'),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        withProviders(MaterialApp.router(routerConfig: router)),
      );
      sessionStream.add(session());
      participantsStream.add(list);
      await tester.pump();
    }

    testWidgets('o meu participante abre o checklist (provisório)',
        (tester) async {
      await showWithRouter(tester, [
        participant('1', 'Ana Paula Ribeiro',
            status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu'),
      ]);

      await tester.tap(find.text('Ana Paula Ribeiro'));
      await tester.pumpAndSettle();

      final screen = tester.widget<EvaluationPlaceholderScreen>(
        find.byType(EvaluationPlaceholderScreen),
      );
      expect(screen.kind, EvaluationPlaceholderKind.checklist);
      expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
    });

    testWidgets('um concluído abre o resultado (provisório)', (tester) async {
      await showWithRouter(tester, [
        participant('4', 'Juliana Freitas Costa',
            status: ParticipantStatus.aprovado, score: 86),
      ]);

      await tester.tap(find.text('Juliana Freitas Costa'));
      await tester.pumpAndSettle();

      final screen = tester.widget<EvaluationPlaceholderScreen>(
        find.byType(EvaluationPlaceholderScreen),
      );
      expect(screen.kind, EvaluationPlaceholderKind.result);
    });

    testWidgets('pendente e de outro consultor não abrem nada', (tester) async {
      await showWithRouter(tester, [
        participant('2', 'Carlos Eduardo Nunes'),
        participant('3', 'Marcos Vinícius Alves',
            status: ParticipantStatus.emAvaliacao, assignedTo: 'c-2'),
      ]);

      await tester.tap(find.text('Carlos Eduardo Nunes'));
      await tester.tap(find.text('Marcos Vinícius Alves'));
      await tester.pumpAndSettle();

      expect(find.byType(EvaluationPlaceholderScreen), findsNothing);
    });
  });
}
```

Em `test/ui/sessions/sessions_screen_test.dart`, acrescentar os imports `package:simtc/data/models/session_participant.dart` (junto dos outros de `data/models`), `package:simtc/data/repositories/participant_repository.dart` (depois do de `auth_repository.dart`), `package:simtc/router.dart` (depois do de `connectivity_service.dart`) e `package:simtc/ui/session_detail/session_detail_screen.dart` (antes do de `sessions_screen.dart`); a classe `class _MockParticipantRepository extends Mock implements ParticipantRepository {}` depois de `_MockCatalogRepository`; e no fim do `main()`:

```dart
  testWidgets('tocar no card abre o detalhe daquela sessão', (tester) async {
    final participants = _MockParticipantRepository();
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => repository.watchSession('sess-1'))
        .thenAnswer((_) => Stream.value(hoje()));
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => Stream.value(const <SessionParticipant>[]));
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));

    final router = createRouter(auth, initialLocation: AppRoutes.home);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: repository),
          Provider<AssessmentCatalogRepository>.value(value: catalog),
          Provider<ParticipantRepository>.value(value: participants),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    sessions.add([hoje()]);
    await tester.pump();

    await tester.tap(find.byType(SessionCard));
    await tester.pumpAndSettle();

    final detail =
        tester.widget<SessionDetailScreen>(find.byType(SessionDetailScreen));
    expect(detail.sessionId, 'sess-1');
  });
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/ui/session_detail/session_detail_screen_test.dart test/ui/sessions/sessions_screen_test.dart`
Esperado: FAIL na compilação — `session_detail_screen.dart`, `evaluation_placeholder_screen.dart`, `AppRoutes.sessionDetail` e o parâmetro `initialLocation` não existem.

- [ ] **Step 3: Estilo de status de sessão compartilhado**

Criar `lib/ui/sessions/session_status_style.dart` (é o mapeamento que hoje está privado na Home, em `_accentFor`/`_toneFor`/`_iconFor`, já com o traço neutro de Concluídas da Task 0):

```dart
import 'package:flutter/widgets.dart';

import '../../data/models/training_session.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/widgets/status_chip.dart';

/// Como cada status de sessão aparece — o mesmo no card da Home e no
/// cabeçalho do detalhe, para o consultor reconhecer a sessão nas duas telas.
extension SessionStatusStyle on SessionStatus {
  StatusTone get tone => switch (this) {
        SessionStatus.planejado => StatusTone.neutral,
        SessionStatus.emAndamento => StatusTone.info,
        SessionStatus.concluido => StatusTone.success,
        SessionStatus.cancelado => StatusTone.danger,
      };

  IconData get icon => switch (this) {
        SessionStatus.planejado => AppIcons.pending,
        SessionStatus.emAndamento => AppIcons.inProgress,
        SessionStatus.concluido => AppIcons.approved,
        SessionStatus.cancelado => AppIcons.needsReview,
      };

  /// Traço superior do card da Home.
  Color get accentColor => switch (this) {
        SessionStatus.planejado => AppColors.border,
        SessionStatus.emAndamento => AppColors.primary,
        SessionStatus.concluido => AppColors.border,
        SessionStatus.cancelado => AppColors.dangerBorder,
      };
}
```

- [ ] **Step 4: Linha de participante**

Criar `lib/ui/session_detail/participant_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// Uma linha da lista de participantes da tela 1.4: nome, CPF mascarado,
/// chip de situação e, conforme o caso, o horário da avaliação, a nota de
/// bloqueio ou o botão "Atribuir a mim".
///
/// Arquivo próprio por tamanho, não por reuso: embutida na tela, ela
/// atrapalharia a leitura do `build()` (convenção do `login_screen.dart`).
class ParticipantRow extends StatelessWidget {
  const ParticipantRow({
    super.key,
    required this.name,
    required this.maskedCpf,
    required this.chip,
    this.meta,
    this.blockedNote,
    this.action,
    this.onTap,
    this.accentColor = AppColors.border,
    this.muted = false,
  });

  final String name;
  final String maskedCpf;
  final Widget chip;

  /// "hoje 08:12" dos concluídos.
  final String? meta;

  /// Por que a linha não tem ação ("Em avaliação com outro consultor.").
  final String? blockedNote;

  /// Botão sob a linha — hoje, só o "Atribuir a mim".
  final Widget? action;

  /// Nulo = a linha não abre nada, e o chevron some.
  final VoidCallback? onTap;

  /// Traço superior, na cor da situação.
  final Color accentColor;

  /// Fundo apagado para quem está com outro consultor.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg - 1,
        ),
        decoration: BoxDecoration(
          color: muted ? AppColors.background : AppColors.surface,
          border: Border(top: BorderSide(color: accentColor, width: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            if (blockedNote != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(blockedNote!, style: AppTypography.meta),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(child: _buildIdentity()),
        const SizedBox(width: AppSpacing.md),
        chip,
        if (onTap != null) ...[
          const SizedBox(width: AppSpacing.xs),
          const Icon(AppIcons.chevronRight, size: 24, color: AppColors.text3),
        ],
      ],
    );
  }

  Widget _buildIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: AppTypography.cardTitle.copyWith(
            color: muted ? AppColors.text2 : AppColors.text,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(maskedCpf, style: AppTypography.code),
        if (meta != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(meta!, style: AppTypography.meta),
        ],
      ],
    );
  }
}
```

- [ ] **Step 5: Tela provisória do checklist e do resultado**

Criar `lib/ui/evaluation/evaluation_placeholder_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/inline_notice.dart';

/// Qual tela a provisória está ocupando.
enum EvaluationPlaceholderKind { checklist, result }

/// Tela provisória atrás das rotas definitivas do participante. A Fase 4
/// troca a do checklist e a Fase 5 a do resultado — e aí este arquivo sai.
class EvaluationPlaceholderScreen extends StatelessWidget {
  const EvaluationPlaceholderScreen({
    super.key,
    required this.kind,
    this.participantName,
  });

  final EvaluationPlaceholderKind kind;

  /// Chega pelo `extra` da navegação — só para o consultor confirmar que
  /// tocou na pessoa certa.
  final String? participantName;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (kind) {
      EvaluationPlaceholderKind.checklist => (
          'Avaliação',
          'O checklist de avaliação chega na próxima versão do app.',
        ),
      EvaluationPlaceholderKind.result => (
          'Resultado',
          'O resultado da avaliação chega numa próxima versão do app.',
        ),
    };

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTopBar(title: title),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (participantName != null) ...[
                    Text(participantName!, style: AppTypography.detailTitle),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  InlineNotice(icon: AppIcons.pending, message: message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Tela 1.4**

Criar `lib/ui/session_detail/session_detail_screen.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../router.dart';
import '../core/date_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/filter_chip_bar.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/skeleton.dart';
import '../core/widgets/status_chip.dart';
import '../core/widgets/sync_status_indicator.dart';
import '../sessions/session_status_style.dart';
import 'participant_filter.dart';
import 'participant_row.dart';
import 'session_detail_viewmodel.dart';

/// Tela 1.4 — detalhe da sessão, com a lista de participantes.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final SessionDetailViewModel _viewModel = SessionDetailViewModel(
    sessionId: widget.sessionId,
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    connectivity: context.read<ConnectivityService>(),
    currentUser: context.read<AuthRepository>().currentUser,
  )..init();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_showMessageWhenItArrives);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_showMessageWhenItArrives);
    _viewModel.dispose();
    super.dispose();
  }

  /// Mesmo padrão da Home: o aviso é passageiro, a lista continua válida. A
  /// mensagem é limpa assim que é agendada — limpar antes de agendar também
  /// evita reentrância, já que `clearMessage()` notifica de novo.
  void _showMessageWhenItArrives() {
    final message = _viewModel.message;
    if (message == null) return;
    _viewModel.clearMessage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(
              title: 'Detalhe da sessão',
              trailing: SyncStatusIndicator(),
            ),
            ConnectivityBanner(
              isOffline: isOffline,
              message: offlineDataMessage(
                _viewModel.session?.participantsSyncedAt,
              ),
            ),
            Expanded(child: _buildBody(isOffline)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isOffline) {
    if (_viewModel.isLoading) return _buildSkeleton();

    final session = _viewModel.session;
    if (session == null) return _buildMissingSession();

    // Cabeçalho e chips fixos, lista rolando embaixo — como no canvas.
    return Column(
      children: [
        _buildSessionHeader(session, isOffline),
        _buildFilters(),
        Expanded(child: _buildParticipantList(session, isOffline)),
      ],
    );
  }

  Widget _buildSessionHeader(TrainingSession session, bool isOffline) {
    final notes = session.notes?.trim() ?? '';
    final progress = _viewModel.progress;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md + 2,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCompanyRow(session),
          const SizedBox(height: AppSpacing.md),
          _buildMetaRow(session),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            InlineNotice(icon: AppIcons.notes, message: notes),
          ],
          if (progress.fraction != null) ...[
            const SizedBox(height: AppSpacing.md),
            _buildProgress(progress),
          ],
          if (_viewModel.canStartSession) ...[
            const SizedBox(height: AppSpacing.md),
            _buildStartButton(isOffline),
          ],
        ],
      ),
    );
  }

  Widget _buildCompanyRow(TrainingSession session) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLogo(session),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.companyName, style: AppTypography.detailTitle),
              const SizedBox(height: AppSpacing.xxs + 1),
              Text(session.courseName, style: AppTypography.body),
            ],
          ),
        ),
      ],
    );
  }

  /// Logo da empresa (bucket público, sem token). O `cached_network_image`
  /// guarda o arquivo no aparelho, então ele continua aparecendo offline
  /// depois da primeira vez; sem logo, ou sem rede na primeira vez, ficam as
  /// iniciais da empresa.
  Widget _buildLogo(TrainingSession session) {
    final url = session.companyLogoUrl;
    final initials = _buildInitials(session.companyName);

    return Container(
      width: AppSpacing.huge + AppSpacing.xs,
      height: AppSpacing.huge + AppSpacing.xs,
      padding: const EdgeInsets.all(AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.primarySurface),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: url == null
          ? initials
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (context, _) => initials,
              errorWidget: (context, _, __) => initials,
            ),
    );
  }

  Widget _buildInitials(String companyName) {
    final words = companyName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2);
    final initials = words.map((word) => word[0].toUpperCase()).join();

    return Center(
      child: Text(
        initials,
        style: AppTypography.cardTitle.copyWith(color: AppColors.primaryDark),
      ),
    );
  }

  Widget _buildMetaRow(TrainingSession session) {
    final date = session.date;

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildMetaItem(AppIcons.place, '${session.city}/${session.state}'),
        _buildMetaItem(
          AppIcons.event,
          date == null ? 'Sem data' : dayMonthYearLabel(date),
        ),
        StatusChip(
          label: session.status.label,
          icon: session.status.icon,
          tone: session.status.tone,
        ),
      ],
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.text3),
        const SizedBox(width: AppSpacing.xs + 1),
        Text(text, style: AppTypography.optionLabel),
      ],
    );
  }

  Widget _buildProgress(ParticipantProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                progress.label,
                style: AppTypography.meta.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              progress.percentLabel,
              style: AppTypography.meta.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  /// Não está no canvas: entrou com a regra do web de só avaliar com a sessão
  /// em andamento (decisão de 23/09/2026) — sem ele, o consultor em campo
  /// ficaria travado numa sessão que ninguém iniciou no painel.
  Widget _buildStartButton(bool isOffline) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPrimaryButton(
          label: 'Iniciar sessão',
          icon: AppIcons.startSession,
          isLoading: _viewModel.isStarting,
          onPressed: isOffline ? null : _confirmStart,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          isOffline
              ? 'Iniciar a sessão precisa de conexão.'
              : 'Inicie a sessão para atribuir e avaliar participantes.',
          style: AppTypography.meta,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _confirmStart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Iniciar a sessão?'),
        content: const Text(
          'Com a sessão em andamento, os consultores podem atribuir e avaliar '
          'participantes. O painel web passa a mostrá-la como "Em andamento".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _viewModel.startSession();
  }

  Widget _buildFilters() {
    final counts = _viewModel.counts;

    return Container(
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: FilterChipBar(
        items: [
          for (final filter in ParticipantFilter.values)
            FilterChipData(label: filter.label, count: counts[filter]),
        ],
        selectedIndex: ParticipantFilter.values.indexOf(_viewModel.filter),
        onSelect: (index) =>
            _viewModel.setFilter(ParticipantFilter.values[index]),
      ),
    );
  }

  Widget _buildParticipantList(TrainingSession session, bool isOffline) {
    final notice = _buildNotice(session, isOffline);
    final visible = _viewModel.visibleParticipants;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _viewModel.refresh,
      child: ListView(
        // Explícito pelo mesmo motivo da Home: puxar para atualizar precisa
        // funcionar mesmo quando a lista é mais curta que a tela.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.huge),
        children: [
          if (notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                0,
              ),
              child: notice,
            ),
          _buildListHeader(),
          if (visible.isEmpty)
            _buildEmpty()
          else
            for (final participant in visible)
              _buildParticipant(participant, isOffline),
        ],
      ),
    );
  }

  /// Um aviso por vez, o mais importante primeiro: sem dados baixados, nada
  /// mais importa; depois, por que ninguém pode ser atribuído agora.
  Widget? _buildNotice(TrainingSession session, bool isOffline) {
    if (_viewModel.neverDownloaded) {
      return const InlineNotice(
        icon: AppIcons.noSignal,
        tone: NoticeTone.warning,
        message: 'Os participantes desta sessão ainda não foram baixados. '
            'Puxe para atualizar quando houver conexão.',
      );
    }

    switch (session.status) {
      case SessionStatus.planejado:
        // Quem pode iniciar já tem o botão e a explicação no cabeçalho.
        if (_viewModel.canStartSession) return null;
        return const InlineNotice(
          icon: AppIcons.pending,
          message: 'Aguardando o responsável iniciar a sessão para atribuir '
              'e avaliar participantes.',
        );
      case SessionStatus.concluido:
        return const InlineNotice(
          icon: AppIcons.approved,
          message: 'Sessão concluída: os participantes ficam só para consulta.',
        );
      case SessionStatus.cancelado:
        return const InlineNotice(
          icon: AppIcons.needsReview,
          message: 'Sessão cancelada: os participantes ficam só para consulta.',
        );
      case SessionStatus.emAndamento:
        if (!_viewModel.hasConsultantProfile) {
          return const InlineNotice(
            icon: AppIcons.profile,
            tone: NoticeTone.warning,
            message: 'Seu usuário não tem perfil de consultor: dá para '
                'acompanhar a sessão, mas não avaliar.',
          );
        }
        if (isOffline && _viewModel.hasPendingToAssign) {
          return const InlineNotice(
            icon: AppIcons.offline,
            tone: NoticeTone.warning,
            message: 'Sem conexão: dá para ver a lista e abrir quem já é seu, '
                'mas atribuir precisa de internet.',
          );
        }
        return null;
    }
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg - 1,
      ),
      child: Text('Participantes', style: AppTypography.sectionTitle),
    );
  }

  Widget _buildEmpty() {
    // Nunca baixada: o aviso de cima já explica, e "nenhum participante"
    // seria uma afirmação que o app não tem como fazer.
    if (_viewModel.neverDownloaded) return const SizedBox.shrink();

    final message = !_viewModel.hasParticipants
        ? 'Nenhum participante inscrito nesta sessão.'
        : switch (_viewModel.filter) {
            ParticipantFilter.todos => 'Nenhum participante inscrito nesta sessão.',
            ParticipantFilter.pendentes => 'Nenhum participante pendente.',
            ParticipantFilter.meus => 'Nenhum participante com você.',
            ParticipantFilter.concluidos => 'Nenhum participante avaliado ainda.',
          };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: InlineNotice(icon: AppIcons.profile, message: message),
    );
  }

  Widget _buildParticipant(SessionParticipant participant, bool isOffline) {
    final situation = _viewModel.situationFor(participant);

    return ParticipantRow(
      key: ValueKey('participante-${participant.id}'),
      name: participant.name,
      maskedCpf: participant.maskedCpf,
      chip: _buildSituationChip(participant, situation),
      meta: assessedAtLabelFor(participant, situation, _viewModel.now),
      blockedNote: blockedNoteFor(participant, situation),
      muted: situation == ParticipantSituation.other,
      accentColor: situation == ParticipantSituation.mine
          ? AppColors.primary
          : AppColors.border,
      onTap: _tapActionFor(participant),
      action: _viewModel.canAssign(participant)
          ? _buildAssignButton(participant, isOffline)
          : null,
    );
  }

  /// Para onde a linha leva. O checklist (Fase 4) e o resultado (Fase 5)
  /// ainda são uma tela provisória — as rotas já são as definitivas.
  VoidCallback? _tapActionFor(SessionParticipant participant) {
    if (_viewModel.opensChecklist(participant)) {
      return () => context.push(
            AppRoutes.participantChecklist(widget.sessionId, participant.id),
            extra: participant.name,
          );
    }
    if (_viewModel.opensResult(participant)) {
      return () => context.push(
            AppRoutes.participantResult(widget.sessionId, participant.id),
            extra: participant.name,
          );
    }
    return null;
  }

  Widget _buildAssignButton(SessionParticipant participant, bool isOffline) {
    final assigning = _viewModel.assigningParticipantId;

    return AppCtaButton(
      key: ValueKey('atribuir-${participant.id}'),
      label: 'Atribuir a mim',
      icon: AppIcons.assign,
      isLoading: assigning == participant.id,
      // Um de cada vez, e nunca offline: a reserva é feita no servidor.
      onPressed: isOffline || assigning != null
          ? null
          : () => _viewModel.assign(participant.id),
    );
  }

  Widget _buildSituationChip(
    SessionParticipant participant,
    ParticipantSituation situation,
  ) {
    final (icon, tone) = switch (situation) {
      ParticipantSituation.mine => (AppIcons.evaluating, StatusTone.info),
      ParticipantSituation.pending => (AppIcons.notStarted, StatusTone.neutral),
      ParticipantSituation.other => (AppIcons.lockedByOther, StatusTone.neutral),
      ParticipantSituation.approved => (AppIcons.approved, StatusTone.success),
      ParticipantSituation.needsReview => (AppIcons.needsReview, StatusTone.danger),
      ParticipantSituation.theoryOnly => (AppIcons.theoryOnly, StatusTone.mauve),
    };

    return StatusChip(
      label: chipLabelFor(participant, situation),
      icon: icon,
      tone: tone,
      dashedBorder: situation == ParticipantSituation.other,
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      key: const Key('session-detail-skeleton'),
      children: const [
        SkeletonListItem(),
        SkeletonListItem(),
        SkeletonListItem(),
        SkeletonListItem(),
      ],
    );
  }

  Widget _buildMissingSession() {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: InlineNotice(
        icon: AppIcons.sessions,
        message: 'Esta sessão não está mais disponível neste aparelho. '
            'Volte para a lista de sessões.',
      ),
    );
  }
}
```

Pontos que o revisor deve conferir contra as decisões:
- avisos em ordem de importância, um por vez (`_buildNotice`): nunca baixada → sessão planejada sem permissão de iniciar → concluída/cancelada → ADMIN sem perfil de consultor → offline com alguém para atribuir;
- "Atribuir a mim" some fora de `EM_ANDAMENTO` e fica desabilitado offline e durante outra atribuição;
- o toque na linha só existe para "meu, em andamento" (checklist) e para concluídos (resultado).

- [ ] **Step 7: Rotas**

Em `lib/router.dart`, acrescentar os imports `ui/evaluation/evaluation_placeholder_screen.dart` e `ui/session_detail/session_detail_screen.dart` (antes do de `sessions_screen.dart`), e trocar `AppRoutes` e o começo de `createRouter`:

```dart
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String designSystem = '/ds';
}

/// Rotas do app. O redirecionamento observa o `AuthRepository`: entrar ou sair
/// da sessão troca a tela sem nenhuma navegação manual espalhada pelo código.
GoRouter createRouter(AuthRepository auth) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
```

por:

```dart
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String designSystem = '/ds';

  /// Detalhe da sessão (tela 1.4).
  static String sessionDetail(String sessionId) => '/sessions/$sessionId';

  /// Checklist do participante (Fase 4) — por ora, uma tela provisória.
  static String participantChecklist(String sessionId, String participantId) =>
      '/sessions/$sessionId/participants/$participantId/checklist';

  /// Resultado do participante (Fase 5) — por ora, uma tela provisória.
  static String participantResult(String sessionId, String participantId) =>
      '/sessions/$sessionId/participants/$participantId/result';
}

/// Rotas do app. O redirecionamento observa o `AuthRepository`: entrar ou sair
/// da sessão troca a tela sem nenhuma navegação manual espalhada pelo código.
///
/// `initialLocation` só muda nos testes, para abrir direto numa tela sem
/// passar pela abertura.
GoRouter createRouter(
  AuthRepository auth, {
  String initialLocation = AppRoutes.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: auth,
```

Depois da rota de `AppRoutes.home`:

```dart
      GoRoute(
        path: '/sessions/:sessionId',
        builder: (context, state) => SessionDetailScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
        routes: [
          GoRoute(
            path: 'participants/:participantId/checklist',
            builder: (context, state) => EvaluationPlaceholderScreen(
              kind: EvaluationPlaceholderKind.checklist,
              participantName: state.extra as String?,
            ),
          ),
          GoRoute(
            path: 'participants/:participantId/result',
            builder: (context, state) => EvaluationPlaceholderScreen(
              kind: EvaluationPlaceholderKind.result,
              participantName: state.extra as String?,
            ),
          ),
        ],
      ),
```

- [ ] **Step 8: Registrar o `ParticipantRepository`**

Em `lib/app_providers.dart`:
- import `data/repositories/participant_repository.dart` depois de `auth_repository.dart`;
- `required this.participantRepository,` no construtor privado, depois de `required this.sessionRepository,`;
- em `create`, antes do `catalogRepository`:

```dart
    final participantRepository = ParticipantRepository(
      apiClient: apiClient,
      database: database,
    );
```

- `participantRepository: participantRepository,` no `return AppDependencies._(...)`, depois de `sessionRepository:`;
- o campo `final ParticipantRepository participantRepository;` depois de `sessionRepository`;
- em `providers`, `Provider<ParticipantRepository>.value(value: participantRepository),` logo depois do de `SessionRepository`.

O cache de participantes já é apagado no logout: `AppDatabase.clearSessionsCache()` limpa `participants` antes de `sessions`.

- [ ] **Step 9: Home — o card abre o detalhe**

Em `lib/ui/sessions/sessions_screen.dart`:
- imports: `package:go_router/go_router.dart` (depois de `flutter/material.dart`), `../../router.dart` e `../core/date_labels.dart` (depois de `connectivity_service.dart`), `../core/widgets/sync_status_indicator.dart` (depois de `status_chip.dart`) e `session_status_style.dart` (depois de `session_filter.dart`);
- no `ConnectivityBanner`, trocar `message: _offlineMessage(viewModel.lastSyncedAt),` por `message: offlineDataMessage(viewModel.lastSyncedAt),`;
- no cabeçalho, trocar `_buildSyncIndicator(),` por `const SyncStatusIndicator(),`;
- apagar os métodos `_offlineMessage` e `_buildSyncIndicator` (os dois viraram código compartilhado com o detalhe);
- trocar `_buildCard` e os três mapeamentos privados que vêm logo depois dele:

```dart
  Widget _buildCard(TrainingSession session) {
    return SessionCard(
      companyName: session.companyName,
      courseName: session.courseName,
      meta: session.meta,
      accentColor: _accentFor(session.status),
      statusChip: StatusChip(
        label: session.status.label,
        icon: _iconFor(session.status),
        tone: _toneFor(session.status),
      ),
      progressValue: session.progress,
      progressLabel: session.progressLabel,
      // O detalhe da sessão é a Fase 3; até lá o card não navega.
      onTap: null,
    );
  }

  Color _accentFor(SessionStatus status) => switch (status) {
        SessionStatus.planejado => AppColors.border,
        SessionStatus.emAndamento => AppColors.primary,
        SessionStatus.concluido => AppColors.border,
        SessionStatus.cancelado => AppColors.dangerBorder,
      };

  StatusTone _toneFor(SessionStatus status) => switch (status) {
        SessionStatus.planejado => StatusTone.neutral,
        SessionStatus.emAndamento => StatusTone.info,
        SessionStatus.concluido => StatusTone.success,
        SessionStatus.cancelado => StatusTone.danger,
      };

  IconData _iconFor(SessionStatus status) => switch (status) {
        SessionStatus.planejado => AppIcons.pending,
        SessionStatus.emAndamento => AppIcons.inProgress,
        SessionStatus.concluido => AppIcons.approved,
        SessionStatus.cancelado => AppIcons.needsReview,
      };
```

por:

```dart
  Widget _buildCard(TrainingSession session) {
    return SessionCard(
      companyName: session.companyName,
      courseName: session.courseName,
      meta: session.meta,
      accentColor: session.status.accentColor,
      statusChip: StatusChip(
        label: session.status.label,
        icon: session.status.icon,
        tone: session.status.tone,
      ),
      progressValue: session.progress,
      progressLabel: session.progressLabel,
      onTap: () => context.push(AppRoutes.sessionDetail(session.id)),
    );
  }
```

- [ ] **Step 10: Rodar os testes e confirmar que passam**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **202 testes passando**.

- [ ] **Step 11: Commit**

```bash
git add lib/ui/sessions/session_status_style.dart lib/ui/session_detail/participant_row.dart lib/ui/session_detail/session_detail_screen.dart lib/ui/evaluation/evaluation_placeholder_screen.dart lib/router.dart lib/app_providers.dart lib/ui/sessions/sessions_screen.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): tela de detalhe da sessao com autoatribuicao"
```

---

## Task 8: Validação no aparelho físico

Esta task é o portão da fase: sem ela, a Fase 4 não é planejada (decisão do usuário, registrada em 17/09/2026). É o roteiro que só o usuário pode rodar.

**Files:** nenhum arquivo de código.

**Interfaces:**
- Consumes: o app inteiro, montado pelas Tasks 0–7.
- Produces: o aval do usuário para planejar a Fase 4.

- [ ] **Step 1: Subir o backend e liberar a porta para o aparelho**

Run: `cd apps/backend && npm run start:dev`

Em outro terminal, com o aparelho conectado: `adb reverse tcp:3001 tcp:3001`

- [ ] **Step 2: Instalar no aparelho**

Descubra o id com `flutter devices` e rode, em `apps/mobile/simtc`:

Run: `flutter run -d <ID_DO_APARELHO>`

Sem `--dart-define` — o padrão já aponta para o backend local. **Não desinstale o app antes:** a migração 2→3 roda sozinha na primeira abertura, e é isso que este passo exercita com dados reais. Deixe o `flutter run` conectado — o console é onde se confere o catálogo.

- [ ] **Step 3: Percorrer o roteiro de aceite**

Detalhe da sessão:
- [ ] tocar num card da Home abre o detalhe **daquela** sessão; o voltar (seta ou gesto) retorna à Home;
- [ ] o cabeçalho mostra logo da empresa (ou as iniciais, se não houver logo), empresa, curso, `Cidade/UF`, data, status, observações e "X de Y participantes avaliados" com os números do painel web;
- [ ] a lista mostra os participantes reais com o CPF mascarado (`042.118.***-**`), na ordem: os meus, pendentes, com outro consultor, concluídos, somente teórica;
- [ ] os chips Todos/Pendentes/Meus/Concluídos mostram contadores coerentes, e tocar em cada um filtra a lista;
- [ ] um concluído mostra "Aprovado · N%" ou "Reavaliar · N%" com o mesmo número do painel web, e "hoje HH:MM" (ou a data) da avaliação.

Iniciar e atribuir:
- [ ] numa sessão `PLANEJADO` em que você é o responsável, aparece "Iniciar sessão"; confirmar inicia, o status vira "Em andamento" e aparecem os botões "Atribuir a mim" — e o painel web mostra a sessão "Em andamento";
- [ ] numa sessão `PLANEJADO` de outro responsável (logado como consultor), aparece "Aguardando o responsável iniciar a sessão…", sem botão;
- [ ] "Atribuir a mim" num pendente: a linha vira "Avaliando · você" na hora, aparece "Participante atribuído a você.", e o painel web mostra o participante em avaliação com você;
- [ ] tocar em "Avaliando · você" abre a tela provisória "Avaliação" com o nome do participante; tocar num concluído abre a provisória "Resultado"; pendentes e "com outro consultor" não abrem nada;
- [ ] **conflito:** com a lista aberta no app, atribua o mesmo participante pendente a outro usuário pelo painel web; sem atualizar o app, toque em "Atribuir a mim" — aparece a mensagem do backend ("…já estão em avaliação com outro consultor") e a linha passa a mostrar o outro consultor, sem quebrar a lista.

Offline:
- [ ] modo avião, abrir de novo uma sessão já aberta: a lista aparece do cache, com a faixa "Sem conexão — dados de …", e "Atribuir a mim" desabilitado com o aviso de que atribuir precisa de internet;
- [ ] modo avião, abrir uma sessão **nunca aberta** no aparelho: aparece "Os participantes desta sessão ainda não foram baixados…" em vez de "nenhum participante";
- [ ] desligar o modo avião com o detalhe aberto atualiza a lista sozinho.

Catálogo (no console do `flutter run`):
- [ ] abrindo a Home com rede, aparece `Catálogo sincronizado. No aparelho: N categorias, M infrações, K notas.` com N > 0;
- [ ] fechar o app, ativar o modo avião e abrir de novo: aparece `Catálogo não atualizado (…). No aparelho: N categorias…` com **os mesmos números** — o catálogo sobreviveu offline.

Regressões da Task 0 (os defeitos que os testes pegaram):
- [ ] a seção Concluídas mostra um subtítulo por dia, e o "Ver mais" dela revela mais **concluídas** (não sessões de "Esta semana");
- [ ] com muitas concluídas reveladas, rolar até o fim absoluto da lista destaca o chip "Concluídas".

Acrescentados depois da revisão final (commit `402838c`), cada um cobre um defeito corrigido:
- [ ] tocar em "Atribuir a mim" e voltar para a Home **antes** da resposta chegar: nenhuma linha vermelha "used after being disposed" aparece no console do `flutter run`;
- [ ] abrir uma sessão e tocar em "Atribuir a mim" logo em seguida, com a rede lenta: a linha termina como "Avaliando · você" e não volta para "Pendente" quando a primeira atualização chega atrasada.

Acrescentados com o novo export do canvas (24/09/2026, commits `14f0556` e `1ba0b39` — **reinicie o backend**, a listagem passou a enviar o logo):
- [ ] os cards da Home mostram, à esquerda do nome, o logo da empresa (44×44) ou, sem logo cadastrado, as iniciais em teal ("BR" para uma palavra só, "BC" para "Bracell Celulose") — sem precisar abrir a sessão antes;
- [ ] o logo do cabeçalho do detalhe aparece sem borda;
- [ ] em modo avião, os logos que já apareceram uma vez continuam aparecendo (cache de imagem).

Conhecido, ainda não tratado (ver Pendências): o toque nos cards e nas linhas não mostra a animação de toque (ripple), e offline numa sessão nunca baixada aparecem ao mesmo tempo o aviso "ainda não foram baixados" e o SnackBar "Mostrando os dados já baixados".

ADMIN:
- [ ] logado como ADMIN, a tela é a mesma do consultor, e "Iniciar sessão" aparece em sessões `PLANEJADO` mesmo sem ser o responsável.

**Não verificável neste aparelho, e por quê:** "ADMIN sem perfil de consultor não vê 'Atribuir a mim'" depende de um usuário ADMIN sem `consultantId`, que o seed não cria — a premissa do brainstorm é que todo ADMIN é consultor. A regra fica coberta pelos testes da ViewModel.

- [x] **Step 4: Registrar o resultado**

Se tudo passar, avisar o usuário e pedir o aval para planejar a Fase 4. Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio ou de contrato do backend, parar e perguntar.

**Validado em 26/09/2026, no aparelho físico, pelo usuário — roteiro completo, incluindo o logo em SVG da Bracell (commit `17b79ff`). Aval dado para planejar a Fase 4.**

---

## Pendências levadas para as fases seguintes

| Fase | Pendência |
|---|---|
| 4 | O checklist substitui a tela provisória da rota `…/checklist` (só trocar o builder em `router.dart`). O catálogo já está no aparelho: `AssessmentCatalogRepository.loadCatalog()`. |
| 4 | O "Avaliando · você" ganha o cronômetro do canvas (vem do `startTime` do rascunho local). |
| 4 | `SyncStatusIndicator` ganha o badge com a contagem da fila local — um lugar só para a Home e o detalhe. |
| 4 | O catálogo é trocado inteiro a cada refresh da Home. Se o admin remover uma infração enquanto houver um rascunho que a marcou, o `infractionNoteId` do rascunho deixa de existir no aparelho (e no backend). Decidir o tratamento ao desenhar o rascunho. |
| 4 | `CatalogCategory/Infraction/Note.fromJson` aceitam item sem `id` como `''`. Ao consumir `loadCatalog()` no checklist, descartar ids vazios (como o `syncSession` faz com participantes). |
| — (decidir com o usuário) | Offline numa sessão nunca baixada, o aviso "Os participantes desta sessão ainda não foram baixados…" aparece junto com o SnackBar "Não foi possível atualizar. Mostrando os dados já baixados." — mensagens contraditórias, e cada sessão aberta offline enfileira um SnackBar. Sugestão da revisão final: não mostrar o SnackBar de falha de rede quando a sessão nunca foi baixada. |
| 7 | `SessionsListViewModel` chama `notifyListeners` depois de `await` sem guarda de dispose (a correção de `402838c` foi só na `SessionDetailViewModel`). Hoje a Home só é descartada no logout, que ainda não existe na interface; aplicar a mesma guarda quando a tela de Perfil trouxer o logout. |
| 8 | O toque em `SessionCard` e `ParticipantRow` não mostra ripple: o `InkWell` envolve um `Container` com cor opaca, que pinta por cima da animação. Trocar por `Ink(decoration: …)` ou `Material(color: …)` em volta do `InkWell`. |
| 8 | Dois toques rápidos num card da Home (ou numa linha de participante) empilham duas telas iguais. |
| 5 | O resultado substitui a tela provisória da rota `…/result`. "Reavaliar" chama `assign` antes de reabrir o checklist (seção 0.4 do brainstorm) — `ParticipantRepository.assign` já existe. |
| 6 | Variante ADMIN do quadro `1f`: editar sessão, gerenciar consultores ("3 consultores" no cabeçalho) e adicionar participante. |
| 8 | Busca local na lista de participantes (a lupa do canvas), junto com a busca da Home. |
| 8 | Tipografia dinâmica: o cabeçalho da 1.4 é fixo (como no canvas); com fonte do sistema muito grande e observações longas, ele pode ocupar a maior parte da tela. Conferir no QA de acessibilidade. |
| 8 | Home: rolando **pelo meio** de uma seção mais alta que o `cacheExtent` (dezenas de concluídas reveladas), nenhum cabeçalho fica montado e o chip pode cair em "Hoje" até o fim da lista. Limitação que já existia, e que ficou mais provável com os subtítulos por dia de Concluídas; a Task 0 só resolveu o fim do scroll. |
| 8 | `session_filter.dart` e `date_labels.dart` têm cada um a sua lista de meses abreviados; consolidar quando a Home for revisitada. |
| — | "Desde 08:29" na nota de quem está com outro consultor: só com um campo de horário de atribuição no backend (não existe). |
| Backend | `POST /practical-assessments/assign` não confere se o consultor está vinculado à sessão, o status da sessão nem o tipo de participação — o app se protege pela interface, mas a API aceita. `POST /training-sessions/:id/start` não confere o status atual (iniciar uma sessão concluída a reabriria); o app só mostra o botão em `PLANEJADO`. |
