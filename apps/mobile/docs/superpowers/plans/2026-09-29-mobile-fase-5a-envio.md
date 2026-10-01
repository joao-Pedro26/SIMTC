# App Mobile SIMTC — Fase 5A: Envio das avaliações — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fechar o ciclo avaliar → confirmar → enviar: o "Finalizar avaliação" abre a tela 1.6 "Conferir e finalizar", o "Confirmar" põe a avaliação numa fila no aparelho, e um serviço único a envia sozinho ao `POST /practical-assessments/sync` — com rede na hora ou quando a rede voltar —, com a fila visível na linha do participante, no badge do cabeçalho e da navbar, e na aba "Sincronizar" (1.9). E a avaliação só começa num toque explícito em "Iniciar avaliação": abrir um participante sem querer não grava nada.

**Architecture:** A tela continua lendo só do banco local. O `AssessmentRepository` ganha a fila (confirmar, ler a fila do dono, montar o corpo do envio, gravar o resultado de cada envio numa transação), e a tabela `LocalAssessments` ganha dono, nome e % (esquema v4). O novo `AssessmentSyncService` — um só para o app, como o `ConnectivityService` — observa a fila do usuário logado no banco: entrou avaliação nova, envia; a rede voltou, o app voltou do segundo plano ou um botão pediu, envia; falhou, tenta de novo com espera crescente. A 1.6 só grava, sem conhecer o serviço. Junto, a renovação do token deixa de deslogar quando falta rede — o envio passa por ela o tempo todo.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · drift 2.31.0 (+ drift_dev/build_runner para regenerar o `app_database.g.dart`) · connectivity_plus 6.1.5 · dio · mocktail (testes). **Nenhuma mudança de backend nem de dependências.** Esquema do Drift: **v3 → v4**.

**Spec:** `brainstorm-implementacao-mobile.md` → "Fase 5 — Resumo + Sincronização automática" (a fase foi dividida: esta é a 5A, "Envio"; a 5B é o Resultado); canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html`, quadros `2e` "1.6 Conferir e finalizar" (linhas 1126–1169), `2h` "1.9 Sincronizar" (1259–1323), o indicador do cabeçalho em `2c` (linha 775) e a linha do participante em `1e` (905–925); contrato do envio em `apps/backend/src/practical-assessments/practical-assessments.service.ts` (`syncFromMobile`) e o formato que o painel web manda em `apps/web/src/features/training-sessions/assessment-drawer.tsx`; pendências da Fase 4 na última seção de `2026-09-27-mobile-fase-4-checklist-de-avaliacao.md`. O desenho aprovado em 29/09/2026 está em "Decisões tomadas com o usuário" — a trilha mobile não usa doc de spec separado, o plano é o documento.

**Validação prévia:** todo o código deste plano foi escrito e rodado numa cópia descartável do app antes de o plano ser fechado, e depois as tasks foram **reencenadas em ordem** numa segunda cópia limpa (HEAD `b34c63d`): em cada task, os testes falharam antes da implementação pelo motivo descrito no passo "Esperado", e cada checkpoint bateu o número de testes — **287 → 296 → 310 → 323 → 337 → 348 → 353 → 368 → 379**, com `flutter analyze` sem issues em todos. Os blocos de código foram gerados dessa cópia por um script que confere cada "Substituir / por" contra o estado deixado pela task anterior, e um segundo script aplicou o plano inteiro, como um executor faria, e conferiu o resultado arquivo a arquivo, task a task — o que está aqui é, byte a byte, o código que passou.

## Decisões tomadas com o usuário

Em 29/09/2026, no brainstorm da fase:

1. **A Fase 5 foi dividida em 5A (Envio) e 5B (Resultado).** Esta é a 5A. A 5B traz a tela 1.8 Resultado, o "Reavaliar" (chama `assign` de novo antes de abrir o checklist) e o "Próximo participante".
2. **Aba Sincronizar como no canvas: envio automático + botões.** O envio é sempre automático; "Sincronizar agora" (desabilitado sem rede) e "Tentar novamente" (no item com erro) só adiantam a próxima tentativa. O brainstorm da fase dizia "sem botão manual" — vale o canvas.
3. **Linha do participante depois do "Confirmar": chip "Na fila".** Chip cinza "Na fila" (a mesma pílula da aba) com "86,7% · aguardando envio"; se o envio falhou, chip vermelho "Erro no envio" com "62,0% · falhou às 07:58". A linha não abre mais o checklist: avaliação confirmada não é editada. Quando o servidor aceita, a sessão é baixada de novo e a linha vira Aprovado/Reavaliar com o % do servidor. O canvas não tem esse estado.
4. **1.6 adaptada ao cálculo real.** Sem "6 pontos descontados de 45" (o score é a média dos % das categorias, não uma conta de pontos): a linha é "Nome · N infrações · mínimo para aprovação 70%."; cada categoria mostra o selo de % do checklist e "sem infração"/"1 infração"/"N infrações"; tocar numa categoria volta ao checklist com ela aberta; o ícone do "Confirmar" é um check (o `draw` do canvas era da etapa de assinatura, que saiu em 20/09).
5. **Duração = relógio corrido,** do início da avaliação até o "Confirmar", inclusive com o app fechado — é o que o cronômetro mostra e o mesmo critério do painel web. O início era a primeira abertura do checklist; com a decisão 10, passou a ser o toque em "Iniciar avaliação".
6. **Cada avaliação guarda o dono.** O backend atribui a avaliação ao dono do token que a envia; sem dono, num aparelho compartilhado, a fila de um consultor sairia no nome de outro. A fila só envia — e a aba só mostra — as do usuário logado. As que a Fase 4 deixou no aparelho ficam com o primeiro usuário que entrar.
7. **Desenho aprovado, parte 1 (dados, envio e sessão):**
   - **Renovação do token:** só uma resposta 4xx do `/auth/refresh` encerra a sessão. Sem rede, tempo esgotado ou 5xx mantêm a sessão, e a chamada original falha como erro de rede, não como 401. `AuthSession.start()` apaga o perfil salvo antes de gravar os tokens novos; falhar ao gravar o perfil não manda mais para o login. (Resolve a pendência prioritária e duas outras da Fase 4.)
   - **Banco v4:** `LocalAssessments` ganha `ownerUserId` e `participantName` (e `score`, ver os ajustes abaixo).
   - **`AssessmentRepository`:** `confirm`, a fila do dono, o resultado de cada envio e as regras novas do `openDraft`. Uma avaliação já enviada começa um rascunho novo (reavaliação, inclusive por atribuição feita no painel web). O rascunho de outro consultor não é reaproveitado.
   - **Formato do envio:** o mesmo do web. `date` como `AAAA-MM-DD`, horários em ISO UTC, e só as notas que existem no catálogo do aparelho (a marcação órfã não vai).
   - **`AssessmentSyncService`:** um envio por vez, com a fila inteira num `POST`, e o resultado lido item a item. Espera de 30 s, 1, 2 e 5 min, no máximo 10 min, entre falhas. Depois de um envio aceito, baixa de novo a sessão.
   - **Fora da 5A:** enviar com o app fechado e descartar item que o servidor sempre recusa.
8. **Desenho aprovado, parte 2 (telas):**
   - "Finalizar avaliação" abre a 1.6 **sem o diálogo** das categorias sem marcação. Isso muda a decisão 4 da Fase 4: a 1.6 mostra cada categoria com o % antes do "Confirmar".
   - Cronômetro na linha "Avaliando · você" (canvas `1e`).
   - Badge laranja com o tamanho da fila no indicador do cabeçalho (Home e detalhe) e na aba da navbar, e a aba habilitada. Tocar no indicador abre a aba, e o voltar do Android na aba vai para Sessões.
   - Na 1.9: pílula "Enviando" (não está no canvas); fila vazia "Nenhuma avaliação na fila / Tudo o que você confirmou já chegou ao servidor." (o canvas não desenha); sem o "+ assinatura" nos itens.
9. **Desenho aprovado, parte 3 (erros):**
   - **Motivo mostrado:** "sem conexão", "tempo esgotado", "servidor indisponível" (5xx) ou "recusada pelo servidor" (item `rejected` ou 4xx no lote). A mensagem crua vai só para o log.
   - **Reenvio:** é seguro, porque o backend atualiza o registro pelo `trainingParticipantId`.
   - **Sessão recusada:** a fila espera o dono entrar de novo.
   - **Falha ao gravar o "Confirmar":** mensagem na própria 1.6, que continua aberta.

Em 29/09/2026, depois do plano pronto, a pedido do usuário:

10. **A avaliação só começa no "Iniciar avaliação".** Um consultor pode atribuir vários participantes de uma vez e abrir um checklist sem querer — e abrir já gravava o rascunho e ligava o cronômetro. Agora:
    - **O botão fica dentro do checklist.** Sem avaliação iniciada, a tela mostra o nome, "⏱ não iniciada", "A avaliação ainda não começou. O cronômetro começa quando você tocar em 'Iniciar avaliação'." e o botão "Iniciar avaliação" (56dp, laranja, ▶) no lugar da lista. O toque grava o início e mostra o checklist com a primeira categoria aberta e o cronômetro do zero. Abrir sem querer e voltar não deixa rastro. Sem catálogo, não há botão. O canvas não tem este estado.
    - **Iniciar é definitivo:** não há "cancelar início".
    - **Rascunhos que já estão no aparelho** (a Fase 4 criava ao abrir) contam como iniciados, com o horário que já têm.
    - **No plano,** entrou como Task 8, a última de código, para não reescrever as Tasks 1–7 já validadas. O `openDraft` continua criando o rascunho, com as regras de dono e reavaliação da Task 2, mas só o "Iniciar" o chama; o novo `findCurrent` só lê. A validação no aparelho passou a ser a Task 9.

Em 30/09/2026, na revisão final da execução:

11. **A linha "Enviada" até a sessão ser baixada de novo.** Depois de um envio aceito, o cache do servidor continua mostrando o participante como "Avaliando · você" até a sessão ser baixada de novo. Se esse download falhar (sinal fraco logo depois do envio, 5xx, aparelho offline), a janela não tem prazo. Nela, um toque abria o checklist "não iniciada", e um "Iniciar" sobrescreveria no servidor a avaliação já aceita, inclusive de um participante aprovado. O plano tinha isso como pendência da 5B, achando que durava "um instante". Agora:
    - A linha mostra o chip **"Enviada"** (azul, nuvem com check) e "86,7% · enviada às 08:12".
    - O toque não abre nada até a sessão ser baixada depois do envio (o `participantsSyncedAt` da sessão passa a ser posterior ao `lastAttemptAt` da avaliação). Aí volta a valer o status do servidor, e uma reatribuição pelo painel para reavaliar volta a funcionar.
    - O serviço tenta de novo o download que falhou no próximo gatilho, mesmo com a fila vazia.
    - Uma sessão aceita de novo enquanto é baixada é baixada outra vez.
    - O `participantsSyncedAt` passou a ser a hora do pedido, não a da gravação.
    - O canvas não tem este estado.

Em 30/09/2026, depois da execução, a pedido do usuário:

12. **Sem cronômetro: só a hora de início e a de fim.** Isto substitui a parte "relógio corrido" da decisão 5 e o cronômetro da decisão 8.
    - **Checklist:** o cabeçalho mostra "Iniciada às 08:12" (ou "Iniciada em 28 set 08:12"), sem nada correndo. O estado "não iniciada" diz que "a hora de início é registrada quando você tocar em 'Iniciar avaliação'".
    - **Linha do participante:** o rascunho mostra "Iniciada às 08:12". O `ElapsedClock` e o `stopwatchLabel` saíram.
    - **Tela 1.6:** ganha a linha "Início 08:12 · Fim 08:31". O fim é a hora em que a 1.6 abriu, e o "Confirmar" grava esse mesmo horário, mesmo que o toque venha depois. Abrir a 1.6 de novo recalcula o fim.
    - **Envio:** o `endTime` enviado é esse fim, e o backend continua recebendo `startTime` e `endTime` no mesmo formato. A duração é fim − início, então fica alguns segundos menor que a do toque em "Confirmar".
    - **Banco:** nenhuma mudança de esquema, porque a coluna `endTime` já existia.
    - O canvas desenha o cronômetro e não tem a linha de início e fim da 1.6.

13. **A barra do checklist é a nota do participante.** O "X de Y categorias revisadas" saiu do checklist: no topo ficam só o percentual ("100,0%") e a barra, que começa cheia e esvazia a cada infração marcada. Abaixo de 70% (o corte de aprovação) a barra fica vermelha. A tela 1.6 continua mostrando as categorias, cada uma com o seu selo de %. O canvas desenha a barra como progresso de categorias.

### Desvios na execução (30/09/2026)

A execução foi por subagentes, uma task por vez, cada uma conferida arquivo a arquivo contra o código validado e revisada antes da próxima. As Tasks 1–8 saíram iguais ao plano. Os desvios foram:

**Task 3, correção `54101cb`.** A revisão da task achou que uma avaliação em "Erro" de uma execução anterior nunca voltava a sair sozinha: o timer da nova tentativa não sobrevive ao app morrer, e na abertura já online não há "rede voltou". O primeiro ajuste abaixo ("As que falharam só voltam a sair na próxima tentativa") estava errado para esse caso. Agora, a primeira leitura da fila depois do login ou da abertura com sessão salva envia tudo o que estiver nela, pendente ou em erro. Isso trouxe 1 teste a mais: os "Esperado" das Tasks 4–8 ficaram 1 acima do escrito (338, 349, 354, 369, 380).

**Revisão final, decisão 11.** Commits `ec00c13` e `dee920d`, com 14 testes a mais. Na mesma correção:
- o comentário e o nome de teste do cronômetro passaram a dizer "desde o 'Iniciar avaliação'";
- o "Confirmar" grava o nome nulo, e não vazio, quando o participante não está no cache, para a entrada do dono completar depois.

**Fim da execução:** **394 testes passando** e `flutter analyze` sem issues.

### Ajustes feitos ao preparar o plano (revisar junto com o plano)

A validação na cópia descartável levou a estes ajustes — **nenhum muda regra de negócio aprovada**, mas cada um é uma escolha que o usuário deve conferir:

- **A 1.6 só grava; quem envia é o serviço, que observa a fila no banco.** Entrou avaliação `pendingSync` nova na fila do usuário logado (o "Confirmar", ou as que já estavam no aparelho quando ele entra), o serviço envia. Assim o "Confirmar" funciona igual com e sem rede, e a 1.6 não depende do serviço. As que falharam só voltam a sair na próxima tentativa (espera, rede voltando, app voltando, botões) — reenviar a cada mudança da fila seria tentar de novo sem espera nenhuma.
- **Uma terceira coluna na v4: `score`**, o % que a 1.6 mostrou no "Confirmar". A linha "Na fila" e a aba mostram o % sem recalcular (o que exigiria o catálogo em cada linha). As avaliações da Fase 4 não têm % e aparecem sem ele ("aguardando envio").
- **O envio só começa depois da primeira leitura da conexão.** Antes dela o app acha que está online (o padrão do `ConnectivityService`), e abrir o app sem sinal marcaria a fila com "Erro · sem conexão" em vez de deixá-la "Na fila".
- **"Enviando" vive só na memória.** Se o app morrer no meio do envio, a avaliação volta a ser "Na fila" e sai de novo — sem risco, porque o reenvio atualiza o mesmo registro.
- **401 no envio não marca erro.** Se a sessão acabou de verdade (a renovação levou 4xx), o app já vai para o login; a avaliação fica "Na fila" e sai quando o dono entrar de novo.
- **O app voltando do segundo plano também envia** (`AppLifecycleListener` no `app.dart`): o aviso de rede de volta pode não chegar com o app parado.
- **`openDraft` e a fila de outro consultor:** uma avaliação **na fila** nunca é zerada pelo `openDraft`, nem por outro consultor — é de alguém que confirmou e espera o envio. Um rascunho sem dono passa a ser de quem o abre, com as marcações.
- **`percentLabel` foi para `ui/core/score_labels.dart`**, e o chip do código e o selo de % do checklist viraram widgets compartilhados (`checklist_badges.dart`) — a 1.6 e a linha do detalhe usam os mesmos. O "Aprovado · 87%" dos chips do detalhe continua arredondando como o painel web.
- **Cronômetro da linha num widget próprio (`ElapsedClock`)**: só o texto redesenha a cada segundo, não a tela inteira. O formato "00:12:41" virou `stopwatchLabel` em `date_labels.dart`, e o checklist passou a usar o mesmo.
- **Indicador do cabeçalho:** com fila, a nuvem muda — riscada sem rede (como no canvas `2c`), de sincronização com rede — e ganha o badge de 16dp do canvas. Ele lê o serviço com `context.watch<AssessmentSyncService?>()`: sem o serviço (galeria do DS, testes de outros widgets), mostra a fila vazia.
- **A aba é uma rota de topo (`/sync`)**, trocada com `context.go`, como uma aba. O toque no indicador do detalhe da sessão também leva a ela (a pilha do detalhe fica para trás; o voltar da aba vai para Sessões).
- **"Tentar novamente" com 48dp** (o canvas tem 44), o alvo mínimo do DS, como o "Atribuir a mim"; e desabilitado sem rede ou com um envio no ar, como o "Sincronizar agora".
- **Pílula "Necessita reavaliação" da 1.6** com as cores do chip "Reavaliar" do detalhe — o canvas só desenha a "Aprovado".
- **Dois testes da Home tocavam atrás da navbar** (o aviso de hit-test que ficou nas pendências da Fase 4): o toque caía em "Sincronizar", que até agora só mostrava "Disponível em breve". Com a aba navegando de verdade, isso quebraria os testes; eles passam a rolar o botão para a área visível antes de tocar. O aviso some da suíte.
- **As avaliações de teste que você finalizou na validação da Fase 4 estão como `pendingSync` no seu celular** e vão para o backend local na primeira abertura com rede desta versão (ficam com o primeiro usuário que entrar).

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app` (a mesma das Fases 0–4). Sem git worktree. Não criar branch, não fazer merge, não fazer push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento (como nas fases anteriores) e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada, com a mensagem exata dada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem arquivos soltos que não são desta fase (backend, `apps/web/…`, `devtools_options.yaml`, arquivos na raiz) — **não tocar neles**.
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-09-29-mobile-fase-5a-envio/`.

**Mobile (valem para todas as fases)**
- Flutter 3.41.6 / Dart 3.11.4. App **só Android**, APK sideload. Validação manual em **aparelho físico** (USB ou Wi-Fi, nunca emulador) — procedimento em `apps/mobile/simtc/README.md`.
- MVVM + Repository: um `ChangeNotifier` por tela; tela nunca chama `Dio`/Drift direto. Repository que fala com a rede devolve o `Result<T>` de `lib/utils/result.dart`; os métodos só locais (como todo o `AssessmentRepository`) devolvem o valor direto.
- `ConnectivityService` e `AssessmentSyncService` únicos, criados no `AppDependencies`, nunca dentro de uma tela.
- Composição "quebra-cabeça": cada tela decompõe a UI em métodos privados `Widget _buildX()` combinados num `build()` enxuto.
- Design System: nenhum `Color(0xFF…)`, nenhum número mágico de espaçamento e nenhum `TextStyle` literal fora de `lib/ui/core/theme/`; **nunca trocar `fontSize` num `.copyWith()`** fora do tema (cor, peso e espaçamento de letra, sim). Aritmética sobre tokens (`AppSpacing.sm + 2`) é o padrão aceito.
- Alvos de toque mínimos de 48dp (`AppSpacing.touchTarget`); skeleton no lugar de spinner; estados de erro e vazio explícitos.
- Contratos reais apenas — nenhum campo ou endpoint não confirmado no código do backend.
- TDD: teste falhando pelo motivo certo → implementação → teste passando.
- **Widget test com Drift de verdade** usa `AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true))`.
- **Migração do Drift** sempre dentro do `transaction()` do `onUpgrade`, por `addColumn`, com teste da migração a partir do esquema anterior e teste de atomicidade.
- Nos testes que importam `package:drift/drift.dart` inteiro, esconder `isNull` e `isNotNull` (conflitam com os matchers do `flutter_test`).

Todos os caminhos de código são relativos a `apps/mobile/simtc/`; os comandos rodam a partir dessa pasta.

## Review Focus

Os cinco casos que o desenho implica, que um consultor real vai encontrar, e onde cada um ficou preso num teste:

1. **Confirmar sem sinal** → a avaliação fica "Na fila" (não tenta, não marca erro) e sai sozinha quando a rede volta. Preso em: `sem rede, não tenta: a fila fica "Na fila" e sai sozinha quando a rede volta` (Task 3).
2. **Voltar para o sinal fraco com o token vencido** → a renovação falha por rede e o consultor **não** é deslogado; a próxima chamada com rede renova. Preso em: o grupo `renovação sem resposta do servidor mantém a sessão` (Task 1).
3. **Aparelho compartilhado** → a avaliação de outro consultor não sai no nome de quem está logado, e o rascunho de outro não é reaproveitado. Preso em: `avaliação de outro consultor não sai no nome de quem está logado` (Task 3) e `rascunho de outro consultor não é reaproveitado…` (Task 2).
4. **O backend recusa um item do lote** (participante removido da sessão, nota apagada) → só ele fica com "Erro · recusada pelo servidor"; os outros saem da fila. Preso em: `o backend recusando um item deixa só ele na fila, com o motivo` (Task 3).
5. **Abrir um participante sem querer** (vários atribuídos de uma vez) → nada é gravado e a duração não começa; voltar não deixa rastro. Preso em: `abrir só lê: … um participante aberto sem querer não começa` e `abrir sem querer e voltar não deixa rastro` (Task 8).

O catálogo mudado depois da marcação (a marcação órfã não vai no envio) também tem teste: `manda o formato do painel web: … só as notas que existem no catálogo, na infração marcada` (Task 2).

## Estado herdado (ponto de partida)

HEAD `b34c63d` (registro da validação da Fase 4 no aparelho). `flutter analyze` limpo; **287 testes passando**.

Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| Tabela da avaliação local | `lib/data/services/local/tables.dart` | `LocalAssessments`: `syncStatus` (`draft`/`pendingSync`/`synced`/`error`), `lastError`, `lastAttemptAt`, `attemptCount` já existem desde a Fase 1; esquema v3 |
| Rascunho | `lib/data/repositories/assessment_repository.dart` | `openDraft`, `watchItems`, `mark`, `unmark`, `finish` (Fase 4) |
| Conectividade | `lib/data/services/connectivity_service.dart` | `isOffline`, `onReconnected` (só na transição offline→online), `initialize()` |
| Cliente HTTP | `lib/data/services/api/api_client.dart`, `api_exception.dart` | `post<T>`; renovação com `_pendingRefresh` compartilhado; `ApiException(message, statusCode, isNetworkError)` |
| Sessão | `lib/data/services/auth_session.dart`, `local/token_storage.dart` | `start`, `saveUser`, `readSavedUser`; chave `auth.user` |
| Participantes | `lib/data/repositories/participant_repository.dart` | `syncSession(sessionId)` → `Result<int>`; `watchParticipant(id)` |
| Checklist | `lib/ui/checklist/` | `buildChecklistSections`, `overallScoreOf`, `scoreBadgeColorsFor`; `ChecklistViewModel.toggleCategory` |
| Scoring | `lib/utils/scoring.dart` | `getApprovalStatus(score)` → `'APROVADO'` \| `'NECESSITA_REAVALIACAO'` |
| Linha do participante | `lib/ui/session_detail/` | `situationOf`, `chipLabelFor`, `assessedAtLabelFor`; `ParticipantRow(meta: …)` |
| Datas | `lib/ui/core/date_labels.dart` | `momentLabel(moment, now)` → "hoje 08:12" |
| Widgets do DS | `lib/ui/core/widgets/` | `StatusChip(label, icon, tone)`, `AppCtaButton(size: AppCtaSize.large, isLoading)`, `AppTopBar(title, trailing)`, `PillNavItem(badgeCount)`, `InlineNotice` |
| Navbar da Home | `lib/ui/sessions/sessions_screen.dart` | `_buildNavBar`: "Sincronizar" e "Perfil" mostram "Disponível em breve." |
| Contrato do envio | backend `syncFromMobile` | `POST /practical-assessments/sync` com `[{ trainingParticipantId, date, startTime, endTime, items: [{ infractionNoteId }] }]`; responde **201** com `[{ trainingParticipantId, status: 'fulfilled'\|'rejected', error? }]`; o consultor vem do JWT; recalcula o score e zera `assignedConsultantId` |

## Mapa de Arquivos

### Novos

| Arquivo | Task | Responsabilidade |
|---|---|---|
| `lib/data/services/assessment_sync_service.dart` | 3 | envio da fila: gatilhos, um por vez, resultado item a item, espera crescente; `SendFailure` |
| `lib/ui/core/score_labels.dart` | 4 | `percentLabel` ("86,7%") |
| `lib/ui/checklist/checklist_badges.dart` | 4 | `CategoryCodeChip`, `ScoreBadge` (checklist e 1.6) |
| `lib/ui/summary/summary_viewmodel.dart` | 4 | estado da 1.6 |
| `lib/ui/summary/summary_screen.dart` | 4 | tela 1.6; `SummaryExit` (`SummaryConfirmed`, `SummaryReviewCategory`) |
| `lib/ui/core/widgets/elapsed_clock.dart` | 5 | "00:12:41" que avança sozinho |
| `lib/ui/sync/sync_queue_labels.dart` | 7 | regras puras dos itens da aba |
| `lib/ui/sync/sync_screen.dart` | 7 | tela 1.9 |
| `test/data/services/assessment_sync_service_test.dart` | 3 | serviço com banco em memória e API falsa |
| `test/ui/core/score_labels_test.dart` | 4 | |
| `test/ui/summary/summary_viewmodel_test.dart` | 4 | |
| `test/ui/summary/summary_screen_test.dart` | 4 | |
| `test/support/fake_assessment_sync_service.dart` | 6 | serviço falso para testes de tela (não é teste) |
| `test/ui/core/widgets/sync_status_indicator_test.dart` | 6 | |
| `test/ui/sync/sync_queue_labels_test.dart` | 7 | |
| `test/ui/sync/sync_screen_test.dart` | 7 | |

### Modificados

| Arquivo | Tasks | O que muda |
|---|---|---|
| `lib/data/services/api/api_client.dart` | 1 | renovação: 4xx encerra; sem resposta ou 5xx mantém e devolve o erro dela |
| `lib/data/services/local/token_storage.dart` | 1 | `deleteUser()` |
| `lib/data/services/auth_session.dart` | 1 | `start()` apaga o perfil; `saveUser` nunca lança |
| `lib/data/services/local/tables.dart`, `app_database.dart` (+ `.g.dart`) | 2 | v4: `ownerUserId`, `participantName`, `score` |
| `lib/data/repositories/assessment_repository.dart` | 2, 4, 8 | fila; `openDraft` com dono; (4) sai `finish`; (8) `findCurrent` |
| `lib/data/services/api/api_exception.dart` | 3 | `isTimeout` |
| `lib/app_providers.dart`, `lib/app.dart` | 3 | o serviço de envio; envio na volta do segundo plano |
| `lib/ui/checklist/checklist_viewmodel.dart` | 2, 4, 5, 8 | dono; (4) sai `finish`, entra `expandCategory`; (5) `stopwatchLabel`; (8) `init` só lê, `start()` |
| `lib/ui/checklist/checklist_screen.dart` | 2, 4, 8 | dono; (4) "Finalizar" abre a 1.6, sem diálogo; (8) estado "não iniciada" e o "Iniciar avaliação" |
| `lib/ui/checklist/checklist_sections.dart` | 4 | `markedCount`, `infractionCountLabel` |
| `lib/router.dart` | 4, 7 | rota da 1.6; (7) aba `/sync` |
| `lib/ui/core/theme/app_typography.dart` | 4, 6, 7 | estilos da 1.6, do badge e da aba |
| `lib/ui/core/theme/app_icons.dart` | 5, 7, 8 | `sendFailed`, `retry`, `startEvaluation` |
| `lib/ui/core/date_labels.dart` | 5 | `clockLabel`, `atLabel`, `stopwatchLabel` |
| `lib/ui/session_detail/participant_filter.dart`, `participant_row.dart`, `session_detail_viewmodel.dart` | 5 | `LocalProgress`, `queueMetaFor`, `liveMeta`, avaliações do aparelho |
| `lib/ui/session_detail/session_detail_screen.dart` | 5, 7 | chip "Na fila"/"Erro no envio", cronômetro; (7) toque no indicador |
| `lib/ui/core/widgets/sync_status_indicator.dart` | 6, 7 | badge da fila; (7) toque |
| `lib/ui/sessions/sessions_screen.dart` | 6, 7 | badge na navbar; (7) aba e toque no indicador |
| testes existentes | 1–8 | ver cada task |

---

## Task 1: Renovação do token sem deslogar e o perfil salvo à prova de falha

A pendência prioritária da Fase 4. Hoje qualquer falha do `/auth/refresh` — sem rede, tempo esgotado — chama `onSessionExpired` e manda para o login, que exige rede. Com a entrada offline da Fase 4 e o envio desta fase passando por aqui o tempo todo, "voltar com sinal fraco e token vencido" deslogaria o consultor. A regra nova: **só uma resposta 4xx** encerra a sessão; sem resposta ou 5xx, a sessão fica e a chamada original falha com o erro da renovação.

**Files:**
- Modify: `lib/data/services/api/api_client.dart`
- Modify: `lib/data/services/local/token_storage.dart`
- Modify: `lib/data/services/auth_session.dart`
- Test: `test/data/services/api/api_client_test.dart`
- Test: `test/data/services/local/token_storage_test.dart`
- Test: `test/data/repositories/auth_repository_test.dart`

**Interfaces:**
- Consumes: nada novo.
- Produces:
  - `ApiClient`: renovação com resposta 4xx → `onSessionExpired()` e o 401 original segue; sem resposta (rede, tempo esgotado) ou 5xx → a sessão fica e a chamada falha com o erro da renovação (`ApiException` com `isNetworkError`, ou com o `statusCode` 5xx). Uma renovação que falhou libera a próxima.
  - `TokenStorage.deleteUser()` — apaga só `auth.user`.
  - `AuthSession.start()` apaga o perfil antes de gravar os tokens; `AuthSession.saveUser()` nunca lança.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/data/services/api/api_client_test.dart`:

Substituir (1 de 4):

```dart
class _Reply {
  const _Reply(this.statusCode, [this.body = const <String, dynamic>{}]);
```

por:

```dart
class _Reply {
  const _Reply(this.statusCode, [this.body = const <String, dynamic>{}])
      : networkError = null;

  /// A requisição falha sem chegar a ter resposta (sem rede, tempo esgotado).
  const _Reply.network(DioExceptionType this.networkError)
      : statusCode = 0,
        body = const <String, dynamic>{};
```

Substituir (2 de 4):

```dart
  final Map<String, dynamic> body;
}
```

por:

```dart
  final Map<String, dynamic> body;
  final DioExceptionType? networkError;
}
```

Substituir (3 de 4):

```dart
    final reply = replies.removeAt(0);
    return _json(reply.statusCode, reply.body);
```

por:

```dart
    final reply = replies.removeAt(0);
    if (reply.networkError != null) {
      throw DioException(requestOptions: options, type: reply.networkError!);
    }
    return _json(reply.statusCode, reply.body);
```

Substituir (4 de 4):

```dart

  test('a rota de refresh não leva Authorization', () async {
```

por:

```dart

  group('renovação sem resposta do servidor mantém a sessão', () {
    test(
        'sem rede na renovação, a chamada falha como falta de conexão e a '
        'sessão continua', () async {
      final client = buildClient([
        const _Reply(401, {'message': 'Unauthorized'}),
        const _Reply.network(DioExceptionType.connectionError),
      ]);

      await expectLater(
        client.get<Map<String, dynamic>>('/training-sessions'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isNetworkError, 'isNetworkError', isTrue)
              .having((e) => e.statusCode, 'statusCode', isNull),
        ),
      );
      expect(sessionExpiredCalls, 0);
      expect(renewedTokens, isEmpty);
      expect(adapter.requests.map((r) => r.path).toList(),
          ['/training-sessions', '/auth/refresh'],
          reason: 'sem token novo, a chamada original não é repetida');
    });

    test('tempo esgotado na renovação também mantém a sessão', () async {
      final client = buildClient([
        const _Reply(401, {'message': 'Unauthorized'}),
        const _Reply.network(DioExceptionType.receiveTimeout),
      ]);

      await expectLater(
        client.get<Map<String, dynamic>>('/training-sessions'),
        throwsA(isA<ApiException>()
            .having((e) => e.isNetworkError, 'isNetworkError', isTrue)),
      );
      expect(sessionExpiredCalls, 0);
    });

    test(
        'servidor fora do ar (5xx) na renovação mantém a sessão e mostra o '
        'erro do servidor', () async {
      final client = buildClient([
        const _Reply(401, {'message': 'Unauthorized'}),
        const _Reply(503, {'message': 'Service Unavailable'}),
      ]);

      await expectLater(
        client.get<Map<String, dynamic>>('/training-sessions'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)),
      );
      expect(sessionExpiredCalls, 0);
    });

    test('qualquer 4xx na renovação encerra a sessão, não só o 401', () async {
      final client = buildClient([
        const _Reply(401, {'message': 'Unauthorized'}),
        const _Reply(403, {'message': 'Forbidden'}),
      ]);

      await expectLater(
        client.get<Map<String, dynamic>>('/training-sessions'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
      expect(sessionExpiredCalls, 1);
    });

    test(
        'depois de uma renovação que falhou sem rede, a próxima chamada tenta '
        'renovar de novo', () async {
      final client = buildClient([
        const _Reply(401, {'message': 'Unauthorized'}),
        const _Reply.network(DioExceptionType.connectionError),
        const _Reply(401, {'message': 'Unauthorized'}),
        const _Reply(200, {'accessToken': 'token-novo', 'refreshToken': 'refresh-2'}),
        const _Reply(200, {'ok': true}),
      ]);

      await expectLater(
        client.get<Map<String, dynamic>>('/training-sessions'),
        throwsA(isA<ApiException>()),
      );
      final response = await client.get<Map<String, dynamic>>('/training-sessions');

      expect(response.statusCode, 200);
      expect(renewedTokens, ['token-novo']);
      expect(sessionExpiredCalls, 0);
    });
  });

  test('a rota de refresh não leva Authorization', () async {
```

Em `test/data/services/local/token_storage_test.dart`:

Substituir:

```dart
  });
}
```

por:

```dart
  });

  test('deleteUser apaga só o perfil salvo, sem mexer nos tokens', () async {
    final secure = _MockSecureStorage();
    when(() => secure.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    final storage = TokenStorage(storage: secure);

    await storage.deleteUser();

    verify(() => secure.delete(key: 'auth.user')).called(1);
    verifyNever(() => secure.delete(key: 'auth.accessToken'));
    verifyNever(() => secure.delete(key: 'auth.refreshToken'));
  });
}
```

Em `test/data/repositories/auth_repository_test.dart`:

Substituir (1 de 2):

```dart
    when(() => storage.readUser()).thenAnswer((_) async => null);
  });
```

por:

```dart
    when(() => storage.readUser()).thenAnswer((_) async => null);
    when(() => storage.deleteUser()).thenAnswer((_) async {});
  });
```

Substituir (2 de 2):

```dart
    });
  });
```

por:

```dart
    });

    test(
        'login apaga o perfil do login anterior antes de gravar os tokens '
        'novos', () async {
      stubLogin(token: fakeJwt({'sub': 'user-2'}));
      stubMe({'id': 'user-2', 'name': 'Bruno', 'email': 'b@s.com', 'role': 'CONSULTANT'});

      await repository.login(email: 'b@s.com', password: '123456', keepSignedIn: true);

      verifyInOrder([
        () => storage.deleteUser(),
        () => storage.persist(
              accessToken: any(named: 'accessToken'),
              refreshToken: any(named: 'refreshToken'),
            ),
        () => storage.persistUser(any()),
      ]);
    });

    test('falha ao gravar o perfil não impede o login', () async {
      stubLogin(token: fakeJwt({'sub': 'user-1'}));
      stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});
      when(() => storage.persistUser(any()))
          .thenThrow(PlatformException(code: 'keystore'));

      final result = await repository.login(
        email: 'c@s.com',
        password: '123456',
        keepSignedIn: true,
      );

      expect(result, isA<Success<AuthUser>>());
      expect(repository.isAuthenticated, isTrue);
    });

    test('falha ao gravar o perfil na abertura com rede não manda para o login',
        () async {
      stubSavedTokens();
      stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});
      when(() => storage.persistUser(any()))
          .thenThrow(PlatformException(code: 'keystore'));

      final result = await repository.restoreSession();

      expect(result, isA<Success<AuthUser>>());
      expect(repository.isAuthenticated, isTrue);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/data/services/api/api_client_test.dart test/data/services/local/token_storage_test.dart test/data/repositories/auth_repository_test.dart`
Esperado: `token_storage_test.dart` e `auth_repository_test.dart` não compilam — `The method 'deleteUser' isn't defined for the type 'TokenStorage'` (e `'_MockTokenStorage'`). No `api_client_test.dart`, falham os 4 testes do grupo "renovação sem resposta do servidor mantém a sessão" que não são de 4xx (sem rede, tempo esgotado, 5xx e "a próxima chamada tenta renovar de novo"): hoje a sessão expira. O "qualquer 4xx na renovação encerra a sessão, não só o 401" **já passa** — fixa o comportamento que continua.

- [ ] **Step 3: Implementar**

Em `lib/data/services/api/api_client.dart`:

Substituir (1 de 8):

```dart
  /// Refresh em andamento — chamadas paralelas esperam o mesmo resultado.
  Future<String?>? _pendingRefresh;
```

por:

```dart
  /// Refresh em andamento — chamadas paralelas esperam o mesmo resultado.
  Future<_Refresh>? _pendingRefresh;
```

Substituir (2 de 8):

```dart

    final newToken = await _refreshToken();
    if (newToken == null) {
      handler.next(error);
      return;
```

por:

```dart

    final refresh = await _refreshToken();
    final newToken = refresh.accessToken;
    if (newToken == null) {
      // Sessão encerrada pelo servidor: segue o 401 original. Renovação que
      // não chegou a ser respondida (sem rede, tempo esgotado, 5xx): segue o
      // erro dela — quem chamou vê "sem conexão", não "não autorizado", e a
      // sessão continua valendo.
      handler.next(refresh.failure ?? error);
      return;
```

Substituir (3 de 8):

```dart

  /// Renova o par de tokens. Devolve o access token novo, ou null se a sessão
  /// acabou (aí o app precisa mandar o usuário para o login).
  Future<String?> _refreshToken() {
    return _pendingRefresh ??= _performRefresh().whenComplete(() {
```

por:

```dart

  /// Renova o par de tokens. Devolve o access token novo, a sessão encerrada
  /// (aí o app precisa mandar o usuário para o login) ou a falha que impediu
  /// a renovação sem encerrar a sessão.
  Future<_Refresh> _refreshToken() {
    return _pendingRefresh ??= _performRefresh().whenComplete(() {
```

Substituir (4 de 8):

```dart

  Future<String?> _performRefresh() async {
    final refreshToken = await readRefreshToken();
```

por:

```dart

  Future<_Refresh> _performRefresh() async {
    final refreshToken = await readRefreshToken();
```

Substituir (5 de 8):

```dart
    if (refreshToken == null || refreshToken.isEmpty) {
      await onSessionExpired();
      return null;
    }
```

por:

```dart
    if (refreshToken == null || refreshToken.isEmpty) {
      await onSessionExpired();
      return const _Refresh.expired();
    }
```

Substituir (6 de 8):

```dart
        await onSessionExpired();
        return null;
      }
```

por:

```dart
        await onSessionExpired();
        return const _Refresh.expired();
      }
```

Substituir (7 de 8):

```dart
      await onTokensRenewed(accessToken, newRefreshToken);
      return accessToken;
    } on DioException {
      await onSessionExpired();
      return null;
    }
```

por:

```dart
      await onTokensRenewed(accessToken, newRefreshToken);
      return _Refresh.renewed(accessToken);
    } on DioException catch (refreshError) {
      // Só o servidor recusando o refresh token (4xx) encerra a sessão
      // (decisão de 29/09/2026). Sem rede, tempo esgotado ou servidor fora do
      // ar (5xx), o token pode continuar valendo: a chamada falha agora e a
      // próxima com rede tenta renovar de novo. Antes, qualquer falha aqui
      // deslogava — e o login exige rede.
      final status = refreshError.response?.statusCode;
      if (status != null && status >= 400 && status < 500) {
        await onSessionExpired();
        return const _Refresh.expired();
      }
      return _Refresh.failed(refreshError);
    }
```

Substituir (8 de 8):

```dart
  }
}
```

por:

```dart
  }
}

/// Desfecho de uma renovação de token.
class _Refresh {
  const _Refresh.renewed(String this.accessToken) : failure = null;
  const _Refresh.expired()
      : accessToken = null,
        failure = null;
  const _Refresh.failed(DioException this.failure) : accessToken = null;

  /// O access token novo — nulo quando não renovou.
  final String? accessToken;

  /// Por que não renovou sem a sessão ter acabado (sem rede, 5xx). Nulo
  /// quando renovou ou quando o servidor encerrou a sessão.
  final DioException? failure;
}
```

Em `lib/data/services/local/token_storage.dart`:

Substituir:

```dart

  Future<void> clear() async {
```

por:

```dart

  /// Apaga só o perfil salvo, sem mexer nos tokens — um login novo não herda
  /// o perfil de quem entrou antes (ver `AuthSession.start`).
  Future<void> deleteUser() => _storage.delete(key: _userKey);

  Future<void> clear() async {
```

Em `lib/data/services/auth_session.dart`:

Substituir (1 de 2):

```dart
    await _storage.setKeepSignedIn(keepSignedIn);
    await updateTokens(accessToken, refreshToken);
```

por:

```dart
    await _storage.setKeepSignedIn(keepSignedIn);
    // O perfil salvo é do login anterior. Apagá-lo antes de gravar os tokens
    // novos garante que um par de tokens nunca fique com o perfil de outra
    // pessoa — nem se o app morrer antes do `saveUser` deste login.
    await _storage.deleteUser();
    await updateTokens(accessToken, refreshToken);
```

Substituir (2 de 2):

```dart
  /// conectado", a mesma regra dos tokens.
  Future<void> saveUser(AuthUser user) async {
    if (!_keepSignedIn) return;
    await _storage.persistUser(jsonEncode(user.toJson()));
  }
```

por:

```dart
  /// conectado", a mesma regra dos tokens.
  ///
  /// Nunca lança: sem o perfil, a única perda é a próxima abertura sem rede
  /// ir para o login. Derrubar o login (ou a abertura com rede) por causa
  /// dele seria pior — e a keystore do Android pode falhar sem aviso, como no
  /// `restoreFromStorage`.
  Future<void> saveUser(AuthUser user) async {
    if (!_keepSignedIn) return;
    try {
      await _storage.persistUser(jsonEncode(user.toJson()));
    } catch (_) {
      // Ver acima: segue sem o perfil salvo.
    }
  }
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **296 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/data/services/api/api_client.dart lib/data/services/local/token_storage.dart lib/data/services/auth_session.dart test/data/services/api/api_client_test.dart test/data/services/local/token_storage_test.dart test/data/repositories/auth_repository_test.dart
git commit -m "fix(mobile): renova o token sem deslogar quando falta rede"
```

---

## Task 2: Banco v4 e a fila de envio no `AssessmentRepository`

A tabela ganha três colunas anuláveis (dono, nome do participante, %), migradas por `addColumn` dentro da transação do `onUpgrade`. O repositório ganha a fila — confirmar, ler, montar o corpo do envio, gravar o resultado — e o `openDraft` passa a conhecer o dono. O `finish` da Fase 4 continua aqui até a Task 4 trocar o "Finalizar" pela 1.6.

Os testes de migração antigos criavam só `sessions` e `participants`; como a migração 3→4 altera `local_assessments`, os bancos "de antes" dos testes passam a criar essa tabela também, como a Fase 1 criava de verdade.

**Files:**
- Modify: `lib/data/services/local/tables.dart`
- Modify: `lib/data/services/local/app_database.dart` (e regenerar `app_database.g.dart`)
- Modify (reescrita): `lib/data/repositories/assessment_repository.dart`
- Modify: `lib/ui/checklist/checklist_viewmodel.dart` — passa o dono ao `openDraft`
- Modify: `lib/ui/checklist/checklist_screen.dart` — o dono vem do `AuthRepository`
- Test (reescrita): `test/data/repositories/assessment_repository_test.dart`
- Test: `test/data/services/local/app_database_test.dart`
- Test: `test/ui/checklist/checklist_viewmodel_test.dart`, `test/ui/checklist/checklist_screen_test.dart`, `test/ui/session_detail/session_detail_screen_test.dart` — o `openDraft` ganhou um parâmetro

**Interfaces:**
- Consumes: nada novo.
- Produces (`AssessmentRepository`):
  - `Future<LocalAssessment> openDraft({required String trainingParticipantId, required String sessionId, required String ownerUserId})`
  - `Future<LocalAssessment?> findByParticipant(String trainingParticipantId)`
  - `Future<List<LocalAssessmentItem>> loadItems(String localAssessmentId)`
  - `Future<void> confirm(String localAssessmentId, {required String participantName, required double score})` → `endTime` agora, `pendingSync`
  - `Stream<List<LocalAssessment>> watchQueue(String ownerUserId)` e `Future<List<LocalAssessment>> loadQueue(String ownerUserId)` — `pendingSync` + `error` do dono, por `endTime`
  - `Stream<List<LocalAssessment>> watchSessionAssessments(String sessionId, String ownerUserId)`
  - `Future<void> claimUnowned(String ownerUserId)`
  - `Future<List<Map<String, dynamic>>> syncPayload(List<LocalAssessment> assessments)`
  - `Future<void> saveSendResults(Map<String, String?> results, {required DateTime at})` — `null` = aceita (`synced`), texto = motivo (`error`); numa transação
  - `Stream<DateTime?> watchLastSyncedAt(String ownerUserId)`
  - `LocalAssessment` ganha `ownerUserId`, `participantName`, `score` (anuláveis). `ChecklistViewModel` ganha `required String ownerUserId`.

- [ ] **Step 1: Escrever os testes que falham**

Reescrever `test/data/repositories/assessment_repository_test.dart` inteiro:

```dart
// `isNull`/`isNotNull` são escondidos de propósito: `package:drift/drift.dart`
// exporta funções top-level com esses nomes, que conflitam com os matchers de
// `package:flutter_test` (ver `app_database_test.dart`).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/services/local/app_database.dart';

void main() {
  late AppDatabase db;
  late AssessmentRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = AssessmentRepository(database: db);
  });

  tearDown(() => db.close());

  /// Abre o rascunho de [participantId] para [owner] — o caminho do checklist.
  Future<LocalAssessment> open(String participantId, {String owner = 'user-1'}) {
    return repository.openDraft(
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      ownerUserId: owner,
    );
  }

  Future<LocalAssessment> row(String id) {
    return (db.select(db.localAssessments)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> write(String id, LocalAssessmentsCompanion changes) {
    return (db.update(db.localAssessments)..where((t) => t.id.equals(id)))
        .write(changes);
  }

  Future<void> seedSession({DateTime? date}) {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva',
            city: 'Itabira',
            state: 'MG',
            status: 'EM_ANDAMENTO',
            date: Value(date),
            cachedAt: DateTime(2026, 9, 12, 8),
          ),
        );
  }

  group('openDraft', () {
    test('cria um rascunho novo em draft, com startTime agora e o dono', () async {
      final assessment = await open('tp-1');

      final saved = await db.select(db.localAssessments).getSingle();
      expect(saved.id, assessment.id);
      expect(assessment.trainingParticipantId, 'tp-1');
      expect(assessment.sessionId, 'sess-1');
      expect(assessment.syncStatus, LocalSyncStatus.draft);
      expect(assessment.endTime, isNull);
      expect(assessment.startTime, isNotNull);
      expect(assessment.ownerUserId, 'user-1');
    });

    test('a data da avaliação é a data de calendário da sessão', () async {
      await seedSession(date: DateTime(2026, 9, 12));

      final assessment = await open('tp-1');

      expect(assessment.date, DateTime(2026, 9, 12));
    });

    test('sessão sem data (ou fora do cache) usa a data de hoje', () async {
      final assessment = await open('tp-1');

      final now = DateTime.now();
      expect(assessment.date, DateTime(now.year, now.month, now.day));
    });

    test('retoma o rascunho do próprio dono, sem duplicar', () async {
      final first = await open('tp-1');

      final second = await open('tp-1');

      expect(second.id, first.id);
      expect(second.startTime, first.startTime);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });

    test('avaliação já enviada começa um rascunho novo — é uma reavaliação',
        () async {
      final first = await open('tp-1');
      await repository.mark(
        localAssessmentId: first.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      await repository.confirm(first.id, participantName: 'Ana', score: 96);
      await repository.saveSendResults({first.id: null}, at: DateTime(2026, 9, 29, 9));

      final again = await open('tp-1');

      expect(again.id, isNot(first.id));
      expect(again.syncStatus, LocalSyncStatus.draft);
      expect(again.endTime, isNull);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
      expect(await db.select(db.localAssessmentItems).get(), isEmpty,
          reason: 'as marcações da avaliação enviada saem junto com ela');
    });

    test(
        'rascunho de outro consultor não é reaproveitado: começa um novo, sem '
        'as marcações dele', () async {
      final theirs = await open('tp-1', owner: 'user-2');
      await repository.mark(
        localAssessmentId: theirs.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-m',
      );

      final mine = await open('tp-1');

      expect(mine.id, isNot(theirs.id));
      expect(mine.ownerUserId, 'user-1');
      expect(await repository.loadItems(mine.id), isEmpty);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });

    test(
        'rascunho sem dono (de antes da Fase 5A) passa a ser de quem abriu, '
        'com as marcações', () async {
      final legacy = await open('tp-1');
      await repository.mark(
        localAssessmentId: legacy.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      await write(legacy.id, const LocalAssessmentsCompanion(ownerUserId: Value(null)));

      final reopened = await open('tp-1');

      expect(reopened.id, legacy.id);
      expect(reopened.ownerUserId, 'user-1');
      expect((await row(legacy.id)).ownerUserId, 'user-1');
      expect(await repository.loadItems(legacy.id), hasLength(1));
    });

    test('avaliação na fila nunca é zerada — nem pelo dono, nem por outro',
        () async {
      final queued = await open('tp-1');
      await repository.confirm(queued.id, participantName: 'Ana', score: 80);

      final byOwner = await open('tp-1');
      final byOther = await open('tp-1', owner: 'user-2');

      expect(byOwner.id, queued.id);
      expect(byOther.id, queued.id);
      expect(byOther.syncStatus, LocalSyncStatus.pendingSync);
    });
  });

  group('mark / unmark / watchItems', () {
    test('marca uma infração e ela aparece em watchItems', () async {
      final assessmentId = (await open('tp-1')).id;

      await repository.mark(
        localAssessmentId: assessmentId,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );

      final items = await repository.watchItems(assessmentId).first;
      expect(items, hasLength(1));
      expect(items.single.infractionId, 'inf-1');
      expect(items.single.infractionNoteId, 'note-b');
    });

    test('marcar de novo a mesma infração troca a nota, sem duplicar linha', () async {
      final assessmentId = (await open('tp-1')).id;

      final first = await repository.mark(
        localAssessmentId: assessmentId,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      final second = await repository.mark(
        localAssessmentId: assessmentId,
        infractionId: 'inf-1',
        infractionNoteId: 'note-m',
      );

      expect(second, hasLength(1));
      expect(second.single.infractionNoteId, 'note-m');
      expect(second.single.id, first.single.id,
          reason: 'o upsert atualiza a linha, não troca por outra');
      final items = await repository.watchItems(assessmentId).first;
      expect(items.single.infractionNoteId, 'note-m');
    });

    test('unmark remove a marcação da infração', () async {
      final assessmentId = (await open('tp-1')).id;
      await repository.mark(
        localAssessmentId: assessmentId,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );

      await repository.unmark(localAssessmentId: assessmentId, infractionId: 'inf-1');

      expect(await repository.watchItems(assessmentId).first, isEmpty);
    });

    test('marcações de avaliações diferentes não se misturam', () async {
      final a1 = (await open('tp-1')).id;
      final a2 = (await open('tp-2')).id;

      await repository.mark(
        localAssessmentId: a1,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      await repository.mark(
        localAssessmentId: a2,
        infractionId: 'inf-1',
        infractionNoteId: 'note-m',
      );

      expect((await repository.loadItems(a1)).single.infractionNoteId, 'note-b');
      expect((await repository.loadItems(a2)).single.infractionNoteId, 'note-m');
    });
  });

  group('finish', () {
    test('grava endTime e põe em pendingSync', () async {
      final assessmentId = (await open('tp-1')).id;

      await repository.finish(assessmentId);

      final saved = await db.select(db.localAssessments).getSingle();
      expect(saved.syncStatus, LocalSyncStatus.pendingSync);
      expect(saved.endTime, isNotNull);
    });

    test(
        'reabrir o checklist de um participante já finalizado retoma a mesma '
        'avaliação, sem estourar a chave única', () async {
      final assessmentId = (await open('tp-1')).id;
      await repository.finish(assessmentId);

      final reopened = await open('tp-1');

      expect(reopened.id, assessmentId);
      expect(reopened.syncStatus, LocalSyncStatus.pendingSync);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });
  });

  group('confirm', () {
    test('grava endTime, o nome e o % da tela 1.6 e põe na fila', () async {
      final assessment = await open('tp-1');

      await repository.confirm(
        assessment.id,
        participantName: 'Ana Paula Ribeiro',
        score: 86.7,
      );

      final saved = await row(assessment.id);
      expect(saved.syncStatus, LocalSyncStatus.pendingSync);
      expect(saved.endTime, isNotNull);
      expect(saved.participantName, 'Ana Paula Ribeiro');
      expect(saved.score, 86.7);
    });
  });

  group('fila', () {
    test(
        'só as confirmadas e ainda não aceitas do dono, na ordem do Confirmar',
        () async {
      final draft = await open('tp-rascunho');
      final first = await open('tp-1');
      final failed = await open('tp-2');
      final second = await open('tp-3');
      final synced = await open('tp-4');
      final others = await open('tp-5', owner: 'user-2');
      for (final a in [first, failed, second, synced, others]) {
        await repository.confirm(a.id, participantName: 'P', score: 90);
      }
      // O banco guarda segundos: horários explícitos deixam a ordem certa.
      await write(first.id, LocalAssessmentsCompanion(endTime: Value(DateTime(2026, 9, 29, 8))));
      await write(failed.id, LocalAssessmentsCompanion(endTime: Value(DateTime(2026, 9, 29, 8, 5))));
      await write(second.id, LocalAssessmentsCompanion(endTime: Value(DateTime(2026, 9, 29, 8, 10))));
      await repository.saveSendResults(
        {synced.id: null, failed.id: 'sem conexão'},
        at: DateTime(2026, 9, 29, 9),
      );

      final queue = await repository.loadQueue('user-1');
      final watched = await repository.watchQueue('user-1').first;

      expect(queue.map((a) => a.id), [first.id, failed.id, second.id]);
      expect(watched.map((a) => a.id), [first.id, failed.id, second.id]);
      expect(queue.map((a) => a.id), isNot(contains(draft.id)));
    });

    test('as avaliações de uma sessão são só as do dono, em qualquer situação',
        () async {
      final draft = await open('tp-1');
      final queued = await open('tp-2');
      await repository.confirm(queued.id, participantName: 'P', score: 90);
      await open('tp-3', owner: 'user-2');
      await repository.openDraft(
        trainingParticipantId: 'tp-4',
        sessionId: 'outra-sessao',
        ownerUserId: 'user-1',
      );

      final rows = await repository.watchSessionAssessments('sess-1', 'user-1').first;

      expect(rows.map((a) => a.id), unorderedEquals([draft.id, queued.id]));
    });

    test(
        'claimUnowned dá as avaliações sem dono a quem entrou, com o nome do '
        'participante do cache', () async {
      await seedSession();
      await db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-1',
              sessionId: 'sess-1',
              name: 'Ana Paula Ribeiro',
              cpf: '042.118.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'EM_AVALIACAO',
              cachedAt: DateTime(2026, 9, 25, 8),
            ),
          );
      // Como a Fase 4 deixou: finalizada, sem dono e sem nome.
      final legacy = await open('tp-1');
      await write(
        legacy.id,
        LocalAssessmentsCompanion(
          ownerUserId: const Value(null),
          endTime: Value(DateTime(2026, 9, 28, 10)),
          syncStatus: const Value(LocalSyncStatus.pendingSync),
        ),
      );
      final others = await open('tp-2', owner: 'user-2');

      await repository.claimUnowned('user-1');

      expect((await row(legacy.id)).ownerUserId, 'user-1');
      expect((await row(legacy.id)).participantName, 'Ana Paula Ribeiro');
      expect((await row(others.id)).ownerUserId, 'user-2');
      expect((await repository.loadQueue('user-1')).single.id, legacy.id);
    });
  });

  group('syncPayload', () {
    Future<void> seedCatalog() async {
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(
              id: 'cat-1',
              code: 'CV',
              name: 'Controle do Veículo',
              order: 1,
            ),
          );
      for (final id in ['inf-1', 'inf-2']) {
        await db.into(db.infractions).insert(
              InfractionsCompanion.insert(
                id: id,
                categoryId: 'cat-1',
                description: 'Infração $id',
                order: 1,
              ),
            );
      }
      for (final (id, infraction) in [
        ('note-b', 'inf-1'),
        ('note-m', 'inf-1'),
        ('note-x', 'inf-2'),
      ]) {
        await db.into(db.infractionNotes).insert(
              InfractionNotesCompanion.insert(
                id: id,
                infractionId: infraction,
                noteType: 'B',
                deduction: 1,
              ),
            );
      }
    }

    test(
        'manda o formato do painel web: data de calendário, horários em UTC e '
        'só as notas que existem no catálogo, na infração marcada', () async {
      await seedSession(date: DateTime(2026, 9, 12));
      await seedCatalog();
      final assessment = await open('tp-1');
      await repository.mark(
        localAssessmentId: assessment.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      // Órfã: a nota foi removida do catálogo depois da marcação.
      await repository.mark(
        localAssessmentId: assessment.id,
        infractionId: 'inf-9',
        infractionNoteId: 'note-sumiu',
      );
      // Órfã: a nota existe, mas agora é de outra infração.
      await repository.mark(
        localAssessmentId: assessment.id,
        infractionId: 'inf-2',
        infractionNoteId: 'note-m',
      );
      final start = DateTime(2026, 9, 12, 8, 30);
      final end = DateTime(2026, 9, 12, 8, 44, 7);
      await write(
        assessment.id,
        LocalAssessmentsCompanion(startTime: Value(start), endTime: Value(end)),
      );

      final payload = await repository.syncPayload([await row(assessment.id)]);

      expect(payload, [
        {
          'trainingParticipantId': 'tp-1',
          'date': '2026-09-12',
          'startTime': start.toUtc().toIso8601String(),
          'endTime': end.toUtc().toIso8601String(),
          'items': [
            {'infractionNoteId': 'note-b'},
          ],
        },
      ]);
    });

    test('cada avaliação leva só as próprias marcações', () async {
      await seedCatalog();
      final a1 = await open('tp-1');
      final a2 = await open('tp-2');
      await repository.mark(
        localAssessmentId: a1.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      await repository.mark(
        localAssessmentId: a2.id,
        infractionId: 'inf-2',
        infractionNoteId: 'note-x',
      );

      final payload = await repository.syncPayload([await row(a1.id), await row(a2.id)]);

      expect(payload.map((p) => p['items']), [
        [
          {'infractionNoteId': 'note-b'},
        ],
        [
          {'infractionNoteId': 'note-x'},
        ],
      ]);
    });
  });

  group('resultado do envio', () {
    test(
        'aceita sai da fila; recusada fica com o motivo — e cada envio conta '
        'uma tentativa', () async {
      final accepted = await open('tp-1');
      final refused = await open('tp-2');
      await repository.confirm(accepted.id, participantName: 'A', score: 90);
      await repository.confirm(refused.id, participantName: 'B', score: 60);
      final at = DateTime(2026, 9, 29, 9, 15);

      await repository.saveSendResults(
        {accepted.id: null, refused.id: 'recusada pelo servidor'},
        at: at,
      );

      final ok = await row(accepted.id);
      expect(ok.syncStatus, LocalSyncStatus.synced);
      expect(ok.lastError, isNull);
      expect(ok.lastAttemptAt, at);
      expect(ok.attemptCount, 1);
      final ko = await row(refused.id);
      expect(ko.syncStatus, LocalSyncStatus.error);
      expect(ko.lastError, 'recusada pelo servidor');
      expect(ko.attemptCount, 1);
      expect((await repository.loadQueue('user-1')).map((a) => a.id), [refused.id]);
    });

    test('a última sincronização é o último envio aceito do dono', () async {
      expect(await repository.watchLastSyncedAt('user-1').first, isNull);

      final a = await open('tp-1');
      final b = await open('tp-2');
      final c = await open('tp-3', owner: 'user-2');
      final d = await open('tp-4');
      for (final x in [a, b, c, d]) {
        await repository.confirm(x.id, participantName: 'P', score: 90);
      }
      await repository.saveSendResults({a.id: null}, at: DateTime(2026, 9, 29, 9));
      await repository.saveSendResults({b.id: null}, at: DateTime(2026, 9, 29, 9, 30));
      await repository.saveSendResults({c.id: null}, at: DateTime(2026, 9, 29, 10));
      await repository.saveSendResults({d.id: 'sem conexão'}, at: DateTime(2026, 9, 29, 11));

      expect(
        await repository.watchLastSyncedAt('user-1').first,
        DateTime(2026, 9, 29, 9, 30),
      );
    });
  });
}
```

Em `test/data/services/local/app_database_test.dart`:

Substituir (1 de 6):

```dart

void main() {
```

por:

```dart

/// A tabela `local_assessments` como a Fase 1 a criou — nenhuma migração
/// mexeu nela até a Fase 5A (esquema 4).
const String _localAssessmentsV3 = '''
  CREATE TABLE IF NOT EXISTS local_assessments (
    id TEXT NOT NULL,
    training_participant_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    date INTEGER NOT NULL,
    start_time INTEGER NOT NULL,
    end_time INTEGER NULL,
    sync_status TEXT NOT NULL,
    last_error TEXT NULL,
    last_attempt_at INTEGER NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (training_participant_id)
  )
''';

void main() {
```

Substituir (2 de 6):

```dart
          // O banco como a Fase 1 o criou: todas as tabelas existem (a Fase 1
          // criou o esquema inteiro), mas `sessions` ainda sem as contagens e
          // `participants` sem as colunas da Fase 3.
          raw.execute(_sessionsV1);
          raw.execute(_participantsV1);
          raw.execute('''
```

por:

```dart
          // O banco como a Fase 1 o criou: todas as tabelas existem (a Fase 1
          // criou o esquema inteiro), mas `sessions` ainda sem as contagens,
          // `participants` sem as colunas da Fase 3 e `local_assessments` sem
          // as da Fase 5A.
          raw.execute(_sessionsV1);
          raw.execute(_participantsV1);
          raw.execute(_localAssessmentsV3);
          raw.execute('''
```

Substituir (3 de 6):

```dart
  test(
      'migra do esquema 2 para o 3 mantendo sessões e participantes já '
      'cacheados', () async {
```

por:

```dart
  test(
      'migra do esquema 2 para o atual mantendo sessões e participantes já '
      'cacheados', () async {
```

Substituir (4 de 6):

```dart
          raw.execute(_participantsV1);
          raw.execute('''
```

por:

```dart
          raw.execute(_participantsV1);
          raw.execute(_localAssessmentsV3);
          raw.execute('''
```

Substituir (5 de 6):

```dart
    /// nenhuma sobrescrita — sobre um `DatabaseDelegate` que derruba a 2ª
    /// instrução `ALTER TABLE` (a partir do esquema 1 a migração faz sete:
    /// três da Fase 2 e quatro da Fase 3). A 1ª tem sucesso, a 2ª nunca chega
    /// ao SQLite. A abertura (`select`) dispara a migração de forma preguiçosa.
    Future<Object> openAndCaptureError() async {
```

por:

```dart
    /// nenhuma sobrescrita — sobre um `DatabaseDelegate` que derruba a 2ª
    /// instrução `ALTER TABLE` (a partir do esquema 1 a migração faz dez:
    /// três da Fase 2, quatro da Fase 3 e três da Fase 5A). A 1ª tem sucesso,
    /// a 2ª nunca chega ao SQLite. A abertura (`select`) dispara a migração de
    /// forma preguiçosa.
    Future<Object> openAndCaptureError() async {
```

Substituir (6 de 6):

```dart
  });
}
```

por:

```dart
  });

  test(
      'migra do esquema 3 para o 4 mantendo as avaliações locais — as da Fase '
      '4 ficam sem dono até alguém entrar', () async {
    final directory = Directory.systemTemp.createTempSync('simtc_migracao_v4');
    final file = File('${directory.path}/simtc.sqlite');

    final migrated = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(_localAssessmentsV3);
          raw.execute('''
            INSERT INTO local_assessments (id, training_participant_id, session_id,
                                           date, start_time, end_time, sync_status,
                                           attempt_count, created_at, updated_at)
            VALUES ('la-1', 'tp-1', 'sess-1', 1758600000, 1758610000, 1758611000,
                    'pendingSync', 0, 1758610000, 1758611000)
          ''');
          raw.execute('PRAGMA user_version = 3');
        },
      ),
    );

    addTearDown(() async {
      await migrated.close();
      directory.deleteSync(recursive: true);
    });

    final row = await migrated.select(migrated.localAssessments).getSingle();

    expect(row.trainingParticipantId, 'tp-1');
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
    expect(row.endTime, DateTime.fromMillisecondsSinceEpoch(1758611000 * 1000));
    expect(row.ownerUserId, isNull);
    expect(row.participantName, isNull);
    expect(row.score, isNull);
  });

  test(
      'a migração 3→4 também é atômica: uma falha na última coluna desfaz as '
      'anteriores', () async {
    final directory =
        Directory.systemTemp.createTempSync('simtc_migracao_v4_atomica');
    final file = File('${directory.path}/simtc.sqlite');
    addTearDown(() => directory.deleteSync(recursive: true));

    DatabaseSetup rawSetup() => (raw) {
          raw.execute(_localAssessmentsV3);
          raw.execute('PRAGMA user_version = 3');
        };

    /// A migração 3→4 faz três `ALTER TABLE` em `local_assessments`. Derrubar
    /// o 3º deixa as duas primeiras colunas já criadas — só a transação de
    /// `onUpgrade` impede que elas fiquem.
    Future<Object> openAndCaptureError() async {
      final realDelegate = NativeDatabase(file, setup: rawSetup()).delegate;
      final executor =
          DelegatedDatabase(_FailOnNthAlterTableDelegate(realDelegate, 3));
      final db = AppDatabase(executor);
      try {
        await db.select(db.localAssessments).get();
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
            'column name: owner_user_id"');
  });
}
```

Em `test/ui/checklist/checklist_viewmodel_test.dart`:

Substituir:

```dart
      participantId: 'tp-1',
      assessmentRepository: assessmentRepository,
```

por:

```dart
      participantId: 'tp-1',
      ownerUserId: 'user-1',
      assessmentRepository: assessmentRepository,
```

Em `test/ui/checklist/checklist_screen_test.dart`:

Substituir (1 de 5):

```dart
import 'package:provider/provider.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
```

por:

```dart
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
```

Substituir (2 de 5):

```dart

class _MockConnectivity extends Mock implements Connectivity {}
```

por:

```dart

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}
```

Substituir (3 de 5):

```dart
  late _MockApiClient api;
  late AppDatabase db;
```

por:

```dart
  late _MockApiClient api;
  late _MockAuthRepository auth;
  late AppDatabase db;
```

Substituir (4 de 5):

```dart
    api = _MockApiClient();
    // Ao cancelar um stream, o drift adia o fechamento com um `Timer` de
```

por:

```dart
    api = _MockApiClient();
    auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(const AuthUser(
      id: 'user-1',
      name: 'Carla Souza',
      email: 'carla@simtc.com.br',
      role: AppUserRole.consultant,
      consultantId: 'c-eu',
    ));
    // Ao cancelar um stream, o drift adia o fechamento com um `Timer` de
```

Substituir (5 de 5):

```dart
        Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
```

por:

```dart
        Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        ChangeNotifierProvider<AuthRepository>.value(value: auth),
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
```

Em `test/ui/session_detail/session_detail_screen_test.dart`:

Substituir:

```dart
          sessionId: any(named: 'sessionId'),
        )).thenAnswer((invocation) async {
```

por:

```dart
          sessionId: any(named: 'sessionId'),
          ownerUserId: any(named: 'ownerUserId'),
        )).thenAnswer((invocation) async {
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/data/repositories/assessment_repository_test.dart test/data/services/local/app_database_test.dart test/ui/checklist/ test/ui/session_detail/session_detail_screen_test.dart`
Esperado: falha de compilação — `No named parameter with the name 'ownerUserId'`, `The getter 'ownerUserId' isn't defined for the type 'LocalAssessment'` e `The method 'confirm' isn't defined for the type 'AssessmentRepository'`; os testes de migração, do checklist e do detalhe da sessão, pelo mesmo motivo.

- [ ] **Step 3: Colunas e migração**

Em `lib/data/services/local/tables.dart`:

Substituir:

```dart
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
```

por:

```dart
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// `AuthUser.id` de quem fez a avaliação (decisão de 29/09/2026). O backend
  /// atribui a avaliação ao dono do token que a envia, então a fila só pode
  /// sair no nome de quem a preencheu. Nulo nas avaliações de antes da Fase
  /// 5A — ficam com o primeiro usuário que entrar
  /// (`AssessmentRepository.claimUnowned`).
  TextColumn get ownerUserId => text().nullable()();

  /// Nome do participante no "Confirmar": a aba Sincronizar mostra a fila
  /// mesmo depois que um logout apaga o cache de participantes.
  TextColumn get participantName => text().nullable()();

  /// % geral no "Confirmar" — o que a tela 1.6 mostrou. A linha "Na fila" e
  /// a aba Sincronizar mostram sem recalcular.
  RealColumn get score => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
```

Em `lib/data/services/local/app_database.dart`:

Substituir (1 de 3):

```dart
  @override
  int get schemaVersion => 3;
```

por:

```dart
  @override
  int get schemaVersion => 4;
```

Substituir (2 de 3):

```dart
          // migração tudo-ou-nada — inclusive para quem pula do esquema 1
          // direto para o 3.
          await transaction(() async {
```

por:

```dart
          // migração tudo-ou-nada — inclusive para quem pula do esquema 1
          // direto para o atual.
          await transaction(() async {
```

Substituir (3 de 3):

```dart
              await m.addColumn(participants, participants.assessedAt);
            }
```

por:

```dart
              await m.addColumn(participants, participants.assessedAt);
            }
            if (from < 4) {
              // Fase 5A: dono, nome do participante e % de cada avaliação
              // local. Anuláveis: as avaliações da Fase 4 que já estão no
              // aparelho ficam com o primeiro usuário que entrar.
              await m.addColumn(localAssessments, localAssessments.ownerUserId);
              await m.addColumn(
                localAssessments,
                localAssessments.participantName,
              );
              await m.addColumn(localAssessments, localAssessments.score);
            }
```

Run: `dart run build_runner build --delete-conflicting-outputs`
Esperado: termina sem erro e reescreve `lib/data/services/local/app_database.g.dart` (a classe `LocalAssessment` ganha `ownerUserId`, `participantName` e `score`).

- [ ] **Step 4: O repositório e quem abre o rascunho**

Reescrever `lib/data/repositories/assessment_repository.dart` inteiro:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../services/local/app_database.dart';

/// A avaliação prática feita no aparelho: o rascunho do checklist (Fase 4) e
/// a fila de envio (Fase 5A).
///
/// Só fala com o `AppDatabase`: quem sobe a fila para o backend é o
/// `AssessmentSyncService`, que usa os métodos da fila daqui para ler o que
/// enviar e gravar o resultado de cada envio.
class AssessmentRepository {
  AssessmentRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  /// Situações de quem já confirmou e espera o backend aceitar.
  static const List<LocalSyncStatus> _queued = [
    LocalSyncStatus.pendingSync,
    LocalSyncStatus.error,
  ];

  /// Abre o rascunho da avaliação do participante para [ownerUserId].
  ///
  /// Retoma o que já existe (`trainingParticipantId` é chave única) em vez de
  /// recriar — o consultor pode ter saído do checklist e voltado. Dois casos
  /// começam um rascunho novo no lugar da linha antiga (decisão de
  /// 29/09/2026):
  /// - a avaliação já foi enviada (`synced`): é uma reavaliação — inclusive
  ///   uma atribuição refeita pelo painel web;
  /// - o rascunho é de outro consultor: num aparelho compartilhado, quem
  ///   pegou o participante agora não herda as marcações de quem saiu.
  ///
  /// Uma avaliação na fila (`pendingSync`/`error`) nunca é zerada aqui: ela é
  /// de alguém que confirmou e só espera o envio. Um rascunho sem dono (de
  /// antes da Fase 5A) passa a ser de [ownerUserId], com as marcações.
  ///
  /// `date` é a data de calendário da sessão (como `TrainingSession.date`,
  /// meia-noite local); sessão sem data, ou fora do cache, usa a de hoje.
  Future<LocalAssessment> openDraft({
    required String trainingParticipantId,
    required String sessionId,
    required String ownerUserId,
  }) async {
    final existing = await findByParticipant(trainingParticipantId);
    if (existing != null && !_startsOver(existing, ownerUserId)) {
      if (existing.ownerUserId != null) return existing;
      await (_db.update(_db.localAssessments)
            ..where((t) => t.id.equals(existing.id)))
          .write(LocalAssessmentsCompanion(ownerUserId: Value(ownerUserId)));
      return existing.copyWith(ownerUserId: Value(ownerUserId));
    }

    final session = await (_db.select(_db.sessions)
          ..where((t) => t.id.equals(sessionId)))
        .getSingleOrNull();
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.transaction(() async {
      if (existing != null) await _delete(existing.id);
      await _db.into(_db.localAssessments).insert(
            LocalAssessmentsCompanion.insert(
              id: id,
              trainingParticipantId: trainingParticipantId,
              sessionId: sessionId,
              date: session?.date ?? DateTime(now.year, now.month, now.day),
              startTime: now,
              syncStatus: LocalSyncStatus.draft,
              createdAt: now,
              updatedAt: now,
              ownerUserId: Value(ownerUserId),
            ),
          );
    });
    return await (_db.select(_db.localAssessments)
          ..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Ver [openDraft]: avaliação já enviada, ou rascunho de outro consultor.
  static bool _startsOver(LocalAssessment existing, String ownerUserId) {
    return switch (existing.syncStatus) {
      LocalSyncStatus.synced => true,
      LocalSyncStatus.draft =>
        existing.ownerUserId != null && existing.ownerUserId != ownerUserId,
      LocalSyncStatus.pendingSync || LocalSyncStatus.error => false,
    };
  }

  Future<void> _delete(String localAssessmentId) async {
    await (_db.delete(_db.localAssessmentItems)
          ..where((t) => t.localAssessmentId.equals(localAssessmentId)))
        .go();
    await (_db.delete(_db.localAssessments)
          ..where((t) => t.id.equals(localAssessmentId)))
        .go();
  }

  /// A avaliação local do participante, em qualquer situação, ou nula.
  Future<LocalAssessment?> findByParticipant(String trainingParticipantId) {
    return (_db.select(_db.localAssessments)
          ..where(
              (t) => t.trainingParticipantId.equals(trainingParticipantId)))
        .getSingleOrNull();
  }

  /// Marcações da avaliação — uma linha por infração marcada. A tela junta
  /// isto com o catálogo (`AssessmentCatalogRepository.loadCatalog`) para
  /// montar as seções do acordeão.
  Stream<List<LocalAssessmentItem>> watchItems(String localAssessmentId) {
    final query = _db.select(_db.localAssessmentItems)
      ..where((t) => t.localAssessmentId.equals(localAssessmentId));
    return query.watch();
  }

  /// As mesmas marcações de [watchItems], lidas uma vez.
  Future<List<LocalAssessmentItem>> loadItems(String localAssessmentId) {
    return (_db.select(_db.localAssessmentItems)
          ..where((t) => t.localAssessmentId.equals(localAssessmentId)))
        .get();
  }

  /// Marca (ou troca) a nota de uma infração — uma infração tem no máximo
  /// uma nota selecionada por vez, garantido pela chave única
  /// (`localAssessmentId`, `infractionId`): a troca é um upsert numa
  /// instrução só, sem janela entre ler e gravar.
  ///
  /// Devolve as marcações atualizadas: quem escreve não espera o `watchItems`
  /// para saber o resultado da própria escrita (o stream de uma assinatura já
  /// aberta pode notificar um turno de evento depois).
  Future<List<LocalAssessmentItem>> mark({
    required String localAssessmentId,
    required String infractionId,
    required String infractionNoteId,
  }) async {
    final now = DateTime.now();
    final items = _db.localAssessmentItems;
    await _db.into(items).insert(
          LocalAssessmentItemsCompanion.insert(
            id: _uuid.v4(),
            localAssessmentId: localAssessmentId,
            infractionId: infractionId,
            infractionNoteId: infractionNoteId,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => LocalAssessmentItemsCompanion(
              infractionNoteId: Value(infractionNoteId),
              updatedAt: Value(now),
            ),
            target: [items.localAssessmentId, items.infractionId],
          ),
        );
    return loadItems(localAssessmentId);
  }

  /// Desmarca a infração — o mesmo botão apertado de novo tira a nota.
  /// Mesma razão do `mark` para devolver a lista, em vez de `void`.
  Future<List<LocalAssessmentItem>> unmark({
    required String localAssessmentId,
    required String infractionId,
  }) async {
    await (_db.delete(_db.localAssessmentItems)
          ..where((t) =>
              t.localAssessmentId.equals(localAssessmentId) &
              t.infractionId.equals(infractionId)))
        .go();
    return loadItems(localAssessmentId);
  }

  /// Finaliza a avaliação: grava `endTime` e põe na fila de envio. Não sobe
  /// nada agora — só marca o rascunho como pronto para a próxima fase enviar.
  Future<void> finish(String localAssessmentId) {
    final now = DateTime.now();
    return (_db.update(_db.localAssessments)
          ..where((t) => t.id.equals(localAssessmentId)))
        .write(
      LocalAssessmentsCompanion(
        endTime: Value(now),
        syncStatus: const Value(LocalSyncStatus.pendingSync),
        updatedAt: Value(now),
      ),
    );
  }

  /// "Confirmar" da tela 1.6: grava `endTime`, o nome do participante e o %
  /// que a tela mostrou, e põe a avaliação na fila de envio. Quem sobe é o
  /// `AssessmentSyncService`, que observa a fila.
  Future<void> confirm(
    String localAssessmentId, {
    required String participantName,
    required double score,
  }) {
    final now = DateTime.now();
    return (_db.update(_db.localAssessments)
          ..where((t) => t.id.equals(localAssessmentId)))
        .write(
      LocalAssessmentsCompanion(
        endTime: Value(now),
        participantName: Value(participantName),
        score: Value(score),
        syncStatus: const Value(LocalSyncStatus.pendingSync),
        lastError: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  /// A fila de envio de [ownerUserId]: as avaliações confirmadas que o
  /// backend ainda não aceitou (`pendingSync` e `error`), na ordem em que
  /// foram confirmadas.
  Stream<List<LocalAssessment>> watchQueue(String ownerUserId) =>
      _queueOf(ownerUserId).watch();

  /// A mesma fila de [watchQueue], lida uma vez — é o que o envio manda.
  Future<List<LocalAssessment>> loadQueue(String ownerUserId) =>
      _queueOf(ownerUserId).get();

  SimpleSelectStatement<$LocalAssessmentsTable, LocalAssessment> _queueOf(
    String ownerUserId,
  ) {
    return _db.select(_db.localAssessments)
      ..where((t) =>
          t.ownerUserId.equals(ownerUserId) & t.syncStatus.isInValues(_queued))
      ..orderBy([(t) => OrderingTerm.asc(t.endTime)]);
  }

  /// As avaliações de [ownerUserId] numa sessão, em qualquer situação — o
  /// detalhe da sessão mostra com elas o cronômetro do rascunho e o chip
  /// "Na fila"/"Erro no envio".
  Stream<List<LocalAssessment>> watchSessionAssessments(
    String sessionId,
    String ownerUserId,
  ) {
    return (_db.select(_db.localAssessments)
          ..where((t) =>
              t.sessionId.equals(sessionId) &
              t.ownerUserId.equals(ownerUserId)))
        .watch();
  }

  /// Dá a [ownerUserId] as avaliações sem dono — as que a Fase 4 deixou no
  /// aparelho antes de existir a coluna (decisão de 29/09/2026: ficam com o
  /// primeiro usuário que entrar). O nome do participante vem do cache, se
  /// ele ainda estiver lá.
  Future<void> claimUnowned(String ownerUserId) {
    return _db.transaction(() async {
      final unowned = await (_db.select(_db.localAssessments)
            ..where((t) => t.ownerUserId.isNull()))
          .get();
      for (final row in unowned) {
        final participant = await (_db.select(_db.participants)
              ..where((t) => t.id.equals(row.trainingParticipantId)))
            .getSingleOrNull();
        await (_db.update(_db.localAssessments)
              ..where((t) => t.id.equals(row.id)))
            .write(
          LocalAssessmentsCompanion(
            ownerUserId: Value(ownerUserId),
            participantName: Value(row.participantName ?? participant?.name),
          ),
        );
      }
    });
  }

  /// Corpo do `POST /practical-assessments/sync` para [assessments], no
  /// mesmo formato que o painel web manda (`assessment-drawer.tsx`):
  /// - `date` como `AAAA-MM-DD`, a data de calendário da avaliação;
  /// - `startTime` e `endTime` em ISO UTC;
  /// - `items` só com as notas que existem no catálogo do aparelho, na
  ///   infração em que foram marcadas.
  ///
  /// Uma marcação que ficou órfã por mudança no catálogo não vai: é o que o
  /// checklist e a tela 1.6 mostraram, e o que o consultor confirmou
  /// (`buildChecklistSections` ignora as mesmas marcações).
  Future<List<Map<String, dynamic>>> syncPayload(
    List<LocalAssessment> assessments,
  ) async {
    final notes = await _db.select(_db.infractionNotes).get();
    final infractionOfNote = {for (final note in notes) note.id: note.infractionId};

    final payload = <Map<String, dynamic>>[];
    for (final assessment in assessments) {
      final items = await loadItems(assessment.id);
      final endTime = assessment.endTime;
      payload.add({
        'trainingParticipantId': assessment.trainingParticipantId,
        'date': _calendarDate(assessment.date),
        'startTime': assessment.startTime.toUtc().toIso8601String(),
        if (endTime != null) 'endTime': endTime.toUtc().toIso8601String(),
        'items': [
          for (final item in items)
            if (infractionOfNote[item.infractionNoteId] == item.infractionId)
              {'infractionNoteId': item.infractionNoteId},
        ],
      });
    }
    return payload;
  }

  /// Grava o resultado de um envio numa transação só, para a fila mudar de
  /// uma vez: `null` em [results] é "aceita pelo backend" (sai da fila); um
  /// texto é o motivo da falha, que a aba Sincronizar mostra.
  Future<void> saveSendResults(
    Map<String, String?> results, {
    required DateTime at,
  }) {
    return _db.transaction(() async {
      for (final MapEntry(key: id, value: failure) in results.entries) {
        final row = await (_db.select(_db.localAssessments)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (row == null) continue;
        await (_db.update(_db.localAssessments)
              ..where((t) => t.id.equals(id)))
            .write(
          LocalAssessmentsCompanion(
            syncStatus: Value(
              failure == null ? LocalSyncStatus.synced : LocalSyncStatus.error,
            ),
            lastError: Value(failure),
            lastAttemptAt: Value(at),
            attemptCount: Value(row.attemptCount + 1),
            updatedAt: Value(at),
          ),
        );
      }
    });
  }

  /// Quando o último envio de [ownerUserId] foi aceito — o "Última
  /// sincronização" da aba Sincronizar. Nulo se nada foi aceito ainda.
  Stream<DateTime?> watchLastSyncedAt(String ownerUserId) {
    final table = _db.localAssessments;
    final last = table.lastAttemptAt.max();
    final query = _db.selectOnly(table)
      ..addColumns([last])
      ..where(table.ownerUserId.equals(ownerUserId) &
          table.syncStatus.equalsValue(LocalSyncStatus.synced));
    return query.map((row) => row.read(last)).watchSingle();
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// "2026-09-29" — a data de calendário, sem hora nem fuso.
String _calendarDate(DateTime date) =>
    '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
```

Em `lib/ui/checklist/checklist_viewmodel.dart`:

Substituir (1 de 3):

```dart
    required this.participantId,
    required AssessmentRepository assessmentRepository,
```

por:

```dart
    required this.participantId,
    required this.ownerUserId,
    required AssessmentRepository assessmentRepository,
```

Substituir (2 de 3):

```dart
  final String participantId;
  final AssessmentRepository _assessmentRepository;
```

por:

```dart
  final String participantId;

  /// `AuthUser.id` do consultor logado — o dono do rascunho.
  final String ownerUserId;
  final AssessmentRepository _assessmentRepository;
```

Substituir (3 de 3):

```dart
      sessionId: sessionId,
    );
```

por:

```dart
      sessionId: sessionId,
      ownerUserId: ownerUserId,
    );
```

Em `lib/ui/checklist/checklist_screen.dart`:

Substituir (1 de 2):

```dart
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
```

por:

```dart
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
```

Substituir (2 de 2):

```dart
    participantId: widget.participantId,
    assessmentRepository: context.read<AssessmentRepository>(),
```

por:

```dart
    participantId: widget.participantId,
    // A rota só abre com sessão (redirecionamento do `router.dart`).
    ownerUserId: context.read<AuthRepository>().currentUser!.id,
    assessmentRepository: context.read<AssessmentRepository>(),
```

- [ ] **Step 5: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **310 testes passando**.

- [ ] **Step 6: Commit**

```bash
git add lib/data/services/local/tables.dart lib/data/services/local/app_database.dart lib/data/services/local/app_database.g.dart lib/data/repositories/assessment_repository.dart lib/ui/checklist/checklist_viewmodel.dart lib/ui/checklist/checklist_screen.dart test/data/repositories/assessment_repository_test.dart test/data/services/local/app_database_test.dart test/ui/checklist/checklist_viewmodel_test.dart test/ui/checklist/checklist_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart
git commit -m "feat(mobile): fila de envio no banco local com o dono da avaliacao"
```

---

## Task 3: `AssessmentSyncService` — o envio automático

O serviço segue o usuário logado (`authChanges`/`currentUserId`), assina a fila dele e envia. Os testes usam o banco em memória com o `AssessmentRepository` de verdade, a API e o `ParticipantRepository` falsos, e o `ConnectivityService` com o plugin falso — o mesmo que o app usa, só que controlado pelo teste. A espera entre falhas é injetável (`retryDelays`), como o relógio do cronômetro na Fase 4.

**Files:**
- Modify: `lib/data/services/api/api_exception.dart` — `isTimeout`
- Create: `lib/data/services/assessment_sync_service.dart`
- Modify: `lib/app_providers.dart` — cria, fornece e descarta o serviço; começa depois da primeira leitura da conexão
- Modify: `lib/app.dart` — envia quando o app volta do segundo plano
- Test: `test/data/services/api/api_client_test.dart`
- Create: `test/data/services/assessment_sync_service_test.dart`

**Interfaces:**
- Consumes: `AssessmentRepository` da Task 2 (`claimUnowned`, `watchQueue`, `loadQueue`, `syncPayload`, `saveSendResults`, `watchLastSyncedAt`); `ParticipantRepository.syncSession`; `ConnectivityService.isOffline`/`onReconnected`.
- Produces:
  - `ApiException.isTimeout` (também é `isNetworkError`).
  - `abstract final class SendFailure { noConnection = 'sem conexão'; timeout = 'tempo esgotado'; serverDown = 'servidor indisponível'; refused = 'recusada pelo servidor' }`
  - `class AssessmentSyncService extends ChangeNotifier` com `AssessmentSyncService({required ApiClient apiClient, required AssessmentRepository assessments, required ParticipantRepository participants, required ConnectivityService connectivity, required Listenable authChanges, required String? Function() currentUserId, DateTime Function()? now, List<Duration> retryDelays = defaultRetryDelays})`; `void start()`; `Future<void> syncNow()`; `List<LocalAssessment> get queue`; `bool get isSending`; `bool isSendingItem(String localAssessmentId)`; `DateTime? get lastSyncedAt`; `static const String syncPath = '/practical-assessments/sync'`.
  - `AppDependencies.assessmentSyncService`, fornecido como `ChangeNotifierProvider<AssessmentSyncService>`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/data/services/api/api_client_test.dart`:

Substituir:

```dart
            .having((e) => e.isNetworkError, 'isNetworkError', isTrue)
            .having((e) => e.statusCode, 'statusCode', isNull),
      ),
    );
  });

  test('dois 401 simultâneos compartilham uma única renovação', () async {
```

por:

```dart
            .having((e) => e.isNetworkError, 'isNetworkError', isTrue)
            .having((e) => e.isTimeout, 'isTimeout', isFalse)
            .having((e) => e.statusCode, 'statusCode', isNull),
      ),
    );
  });

  test('tempo esgotado é falta de conexão com motivo próprio', () async {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      final client = buildClient([]);
      adapter.throwNetworkError = type;

      await expectLater(
        client.get<Map<String, dynamic>>('/training-sessions'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isNetworkError, 'isNetworkError', isTrue)
              .having((e) => e.isTimeout, 'isTimeout', isTrue),
        ),
        reason: '$type',
      );
    }
  });

  test('dois 401 simultâneos compartilham uma única renovação', () async {
```

Criar `test/data/services/assessment_sync_service_test.dart`:

```dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/utils/result.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late AppDatabase db;
  late AssessmentRepository assessments;
  late _MockApiClient api;
  late _MockParticipantRepository participants;
  late _MockConnectivity plugin;
  late StreamController<List<ConnectivityResult>> network;
  late ConnectivityService connectivity;
  late ValueNotifier<String?> user;

  /// Cada envio que chegou ao "backend", com os itens do corpo.
  late List<List<Map<String, dynamic>>> sent;
  AssessmentSyncService? service;

  const semRede = ApiException(message: 'Sem conexão', isNetworkError: true);

  /// A resposta do `POST /practical-assessments/sync` real: 201, item a item.
  Response<List<dynamic>> reply(
    List<Map<String, dynamic>> payload,
    String? Function(String trainingParticipantId) errorFor,
  ) {
    return Response<List<dynamic>>(
      requestOptions: RequestOptions(path: AssessmentSyncService.syncPath),
      statusCode: 201,
      data: [
        for (final item in payload)
          {
            'trainingParticipantId': item['trainingParticipantId'],
            'status': errorFor(item['trainingParticipantId'] as String) == null
                ? 'fulfilled'
                : 'rejected',
            'error': errorFor(item['trainingParticipantId'] as String),
          },
      ],
    );
  }

  List<Map<String, dynamic>> payloadOf(Invocation invocation) =>
      (invocation.namedArguments[#data] as List).cast<Map<String, dynamic>>();

  void answer(String? Function(String trainingParticipantId) errorFor) {
    when(() => api.post<List<dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      final payload = payloadOf(invocation);
      sent.add(payload);
      return reply(payload, errorFor);
    });
  }

  void acceptAll() => answer((_) => null);

  void failWith(ApiException error) {
    when(() => api.post<List<dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      sent.add(payloadOf(invocation));
      throw error;
    });
  }

  Future<void> useConnectivity(ConnectivityResult result) async {
    when(plugin.checkConnectivity).thenAnswer((_) async => [result]);
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    assessments = AssessmentRepository(database: db);
    api = _MockApiClient();
    participants = _MockParticipantRepository();
    plugin = _MockConnectivity();
    network = StreamController<List<ConnectivityResult>>.broadcast();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => network.stream);
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
    user = ValueNotifier<String?>('user-1');
    sent = [];
    when(() => participants.syncSession(any()))
        .thenAnswer((_) async => const Success(0));
    acceptAll();
  });

  tearDown(() async {
    service?.dispose();
    service = null;
    user.dispose();
    connectivity.dispose();
    await network.close();
    await db.close();
  });

  AssessmentSyncService startService({
    List<Duration> retryDelays = const [Duration(hours: 1)],
  }) {
    final started = AssessmentSyncService(
      apiClient: api,
      assessments: assessments,
      participants: participants,
      connectivity: connectivity,
      authChanges: user,
      currentUserId: () => user.value,
      now: () => DateTime(2026, 9, 29, 9, 15),
      retryDelays: retryDelays,
    );
    service = started..start();
    return started;
  }

  /// O que o "Confirmar" da tela 1.6 deixa no banco.
  Future<LocalAssessment> confirmed(
    String participantId, {
    String owner = 'user-1',
  }) async {
    final draft = await assessments.openDraft(
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      ownerUserId: owner,
    );
    await assessments.confirm(draft.id, participantName: 'P $participantId', score: 90);
    return draft;
  }

  Future<LocalAssessment> row(String id) {
    return (db.select(db.localAssessments)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<LocalSyncStatus> statusOf(String id) async => (await row(id)).syncStatus;

  /// Espera o trabalho assíncrono do serviço (streams do drift, envio)
  /// cumprir [condition].
  Future<void> until(FutureOr<bool> Function() condition) async {
    for (var i = 0; i < 400; i++) {
      if (await condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('a condição não se cumpriu a tempo');
  }

  test('confirmar com rede envia sozinho, e a aceita sai da fila', () async {
    final sync = startService();

    final a = await confirmed('tp-1');

    await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
    expect(sent, hasLength(1));
    expect(sent.single.single['trainingParticipantId'], 'tp-1');
    await until(() => sync.queue.isEmpty);
    verify(() => participants.syncSession('sess-1')).called(1);
  });

  test(
      'ao entrar, sai o que já estava no aparelho — inclusive as avaliações '
      'sem dono, da Fase 4', () async {
    user.value = null;
    final mine = await confirmed('tp-1');
    final legacy = await confirmed('tp-2', owner: 'quem-for');
    await (db.update(db.localAssessments)..where((t) => t.id.equals(legacy.id)))
        .write(const LocalAssessmentsCompanion(ownerUserId: Value(null)));
    startService();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(sent, isEmpty, reason: 'ninguém logado, nada sai');

    user.value = 'user-1';

    await until(() async =>
        await statusOf(mine.id) == LocalSyncStatus.synced &&
        await statusOf(legacy.id) == LocalSyncStatus.synced);
    expect(sent.single.map((p) => p['trainingParticipantId']),
        unorderedEquals(['tp-1', 'tp-2']));
    expect((await row(legacy.id)).ownerUserId, 'user-1');
  });

  test('avaliação de outro consultor não sai no nome de quem está logado',
      () async {
    final theirs = await confirmed('tp-1', owner: 'user-2');
    final mine = await confirmed('tp-2');

    startService();

    await until(() async => await statusOf(mine.id) == LocalSyncStatus.synced);
    expect(sent.expand((batch) => batch).map((p) => p['trainingParticipantId']),
        ['tp-2']);
    expect(await statusOf(theirs.id), LocalSyncStatus.pendingSync);
  });

  test('o backend recusando um item deixa só ele na fila, com o motivo',
      () async {
    answer((id) => id == 'tp-2' ? 'Foreign key constraint violated' : null);
    final ok = await confirmed('tp-1');
    final refused = await confirmed('tp-2');

    final sync = startService();

    await until(() async => await statusOf(refused.id) == LocalSyncStatus.error);
    expect(await statusOf(ok.id), LocalSyncStatus.synced);
    expect((await row(refused.id)).lastError, SendFailure.refused);
    await until(() => sync.queue.length == 1);
    expect(sync.queue.single.id, refused.id);
  });

  test(
      'sem rede, não tenta: a fila fica "Na fila" e sai sozinha quando a rede '
      'volta', () async {
    await useConnectivity(ConnectivityResult.none);
    final sync = startService();

    final a = await confirmed('tp-1');
    await until(() => sync.queue.length == 1);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(sent, isEmpty);
    expect(await statusOf(a.id), LocalSyncStatus.pendingSync);

    network.add([ConnectivityResult.wifi]);

    await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
  });

  test(
      'falha de rede marca a fila com o motivo e tenta de novo sozinha, '
      'depois da espera', () async {
    failWith(semRede);
    startService(retryDelays: const [Duration(milliseconds: 50)]);

    final a = await confirmed('tp-1');
    await until(() async => await statusOf(a.id) == LocalSyncStatus.error);
    expect((await row(a.id)).lastError, SendFailure.noConnection);

    acceptAll();

    await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
    expect(sent, hasLength(2));
  });

  test('cada tipo de falha tem o seu motivo', () async {
    startService();
    final cases = [
      (
        const ApiException(message: 'x', isNetworkError: true, isTimeout: true),
        SendFailure.timeout,
      ),
      (const ApiException(message: 'x', statusCode: 503), SendFailure.serverDown),
      (
        const ApiException(message: 'Consultor não identificado', statusCode: 409),
        SendFailure.refused,
      ),
    ];

    for (var i = 0; i < cases.length; i++) {
      final (error, reason) = cases[i];
      failWith(error);
      final a = await confirmed('tp-$i');
      await until(() async => await statusOf(a.id) == LocalSyncStatus.error);
      expect((await row(a.id)).lastError, reason, reason: '$error');
    }
  });

  test(
      '401 no envio (sessão encerrada) não marca erro: a fila espera o dono '
      'entrar de novo', () async {
    failWith(const ApiException(message: 'Unauthorized', statusCode: 401));
    startService();

    final a = await confirmed('tp-1');
    await until(() => sent.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(await statusOf(a.id), LocalSyncStatus.pendingSync);
    expect((await row(a.id)).lastError, isNull);
  });

  test('"Sincronizar agora" não espera a próxima tentativa', () async {
    failWith(semRede);
    final sync = startService(retryDelays: const [Duration(hours: 1)]);
    final a = await confirmed('tp-1');
    await until(() async => await statusOf(a.id) == LocalSyncStatus.error);
    acceptAll();

    await sync.syncNow();

    expect(await statusOf(a.id), LocalSyncStatus.synced);
  });

  test(
      'um envio por vez: o que entra no meio do envio sai num segundo envio, '
      'logo depois', () async {
    final gate = Completer<void>();
    when(() => api.post<List<dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      final payload = payloadOf(invocation);
      sent.add(payload);
      if (sent.length == 1) await gate.future;
      return reply(payload, (_) => null);
    });
    final sync = startService();

    final first = await confirmed('tp-1');
    await until(() => sent.length == 1);
    expect(sync.isSending, isTrue);
    expect(sync.isSendingItem(first.id), isTrue);

    final second = await confirmed('tp-2');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(sent, hasLength(1), reason: 'o segundo espera o primeiro terminar');
    expect(sync.isSendingItem(second.id), isFalse);

    gate.complete();

    await until(() async => await statusOf(second.id) == LocalSyncStatus.synced);
    expect(sent, hasLength(2));
    expect(sent[1].map((p) => p['trainingParticipantId']), ['tp-2']);
    await until(() => !sync.isSending);
  });

  test('mostra à tela a última sincronização aceita', () async {
    final sync = startService();
    expect(sync.lastSyncedAt, isNull);

    await confirmed('tp-1');

    await until(() => sync.lastSyncedAt != null);
    expect(sync.lastSyncedAt, DateTime(2026, 9, 29, 9, 15));
    expect(sync.queue, isEmpty);
  });

  test('sair da conta para de seguir a fila de quem saiu', () async {
    failWith(semRede);
    final sync = startService();
    await confirmed('tp-1');
    await until(() => sync.queue.length == 1);

    user.value = null;

    expect(sync.queue, isEmpty);
    expect(sync.lastSyncedAt, isNull);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/data/services/api/api_client_test.dart test/data/services/assessment_sync_service_test.dart`
Esperado: `api_client_test.dart` não compila (`The getter 'isTimeout' isn't defined for the type 'ApiException'`) e `assessment_sync_service_test.dart` não acha `lib/data/services/assessment_sync_service.dart`.

- [ ] **Step 3: Implementar**

Em `lib/data/services/api/api_exception.dart`:

Substituir (1 de 3):

```dart
    this.isNetworkError = false,
  });
```

por:

```dart
    this.isNetworkError = false,
    this.isTimeout = false,
  });
```

Substituir (2 de 3):

```dart
  final bool isNetworkError;
```

por:

```dart
  final bool isNetworkError;

  /// A resposta não chegou a tempo. Também é [isNetworkError]; a aba
  /// Sincronizar mostra o motivo à parte ("tempo esgotado").
  final bool isTimeout;
```

Substituir (3 de 3):

```dart
    if (isNetwork) {
      return const ApiException(message: _networkMessage, isNetworkError: true);
    }
```

por:

```dart
    if (isNetwork) {
      final isTimeout = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          true,
        _ => false,
      };
      return ApiException(
        message: _networkMessage,
        isNetworkError: true,
        isTimeout: isTimeout,
      );
    }
```

Criar `lib/data/services/assessment_sync_service.dart`:

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../repositories/assessment_repository.dart';
import '../repositories/participant_repository.dart';
import 'api/api_client.dart';
import 'api/api_exception.dart';
import 'connectivity_service.dart';
import 'local/app_database.dart';

/// Motivo de uma falha de envio, do jeito que a aba Sincronizar e a linha do
/// participante mostram ("Falhou às 07:58 · sem conexão").
abstract final class SendFailure {
  static const String noConnection = 'sem conexão';
  static const String timeout = 'tempo esgotado';
  static const String serverDown = 'servidor indisponível';
  static const String refused = 'recusada pelo servidor';
}

/// Envia ao backend a fila de avaliações confirmadas (Fase 5A).
///
/// Um só para o app inteiro, criado no `AppDependencies`: o envio acontece de
/// qualquer tela. Quando envia (decisão de 29/09/2026):
/// - entra avaliação nova na fila — o "Confirmar" da tela 1.6, ou as que já
///   estavam no aparelho quando o consultor entra;
/// - a rede volta (`ConnectivityService.onReconnected`);
/// - o app volta do segundo plano, e nos botões da aba Sincronizar
///   ([syncNow]);
/// - depois de uma falha, sozinho, com espera crescente ([retryDelays]).
///
/// Um envio por vez, com a fila inteira num `POST /practical-assessments/sync`.
/// O backend responde 201 mesmo recusando itens, então o resultado é lido
/// item a item. Reenviar é seguro: o backend atualiza o registro do
/// participante em vez de criar outro.
class AssessmentSyncService extends ChangeNotifier {
  AssessmentSyncService({
    required ApiClient apiClient,
    required AssessmentRepository assessments,
    required ParticipantRepository participants,
    required ConnectivityService connectivity,
    required Listenable authChanges,
    required String? Function() currentUserId,
    DateTime Function()? now,
    this.retryDelays = defaultRetryDelays,
  })  : _api = apiClient,
        _assessments = assessments,
        _participants = participants,
        _connectivity = connectivity,
        _authChanges = authChanges,
        _currentUserId = currentUserId,
        _now = now ?? DateTime.now;

  final ApiClient _api;
  final AssessmentRepository _assessments;
  final ParticipantRepository _participants;
  final ConnectivityService _connectivity;

  /// Avisa quando o usuário logado muda (o `AuthRepository`) — a fila é de
  /// quem está logado.
  final Listenable _authChanges;

  /// `AuthUser.id` de quem está logado agora, ou nulo.
  final String? Function() _currentUserId;
  final DateTime Function() _now;

  /// Espera entre uma falha e a próxima tentativa; a última se repete.
  final List<Duration> retryDelays;

  static const List<Duration> defaultRetryDelays = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];

  static const String syncPath = '/practical-assessments/sync';

  StreamSubscription<List<LocalAssessment>>? _queueSubscription;
  StreamSubscription<DateTime?>? _lastSyncedSubscription;
  StreamSubscription<void>? _reconnectSubscription;
  Timer? _retryTimer;

  bool _started = false;
  bool _disposed = false;
  String? _userId;
  int _failures = 0;
  Future<void>? _running;
  bool _again = false;

  List<LocalAssessment> _queue = const [];
  Set<String> _sendingIds = const {};
  DateTime? _lastSyncedAt;

  /// A fila de quem está logado: confirmadas e ainda não aceitas, na ordem
  /// do "Confirmar".
  List<LocalAssessment> get queue => _queue;

  /// Um envio está no ar.
  bool get isSending => _running != null;

  /// A avaliação faz parte do envio no ar ("Enviando" na aba Sincronizar).
  bool isSendingItem(String localAssessmentId) =>
      _sendingIds.contains(localAssessmentId);

  /// Quando o último envio foi aceito — nulo se nada foi aceito ainda.
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Começa a seguir o usuário logado, a fila dele e a conexão. Chamado uma
  /// vez, pelo `AppDependencies`.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _authChanges.addListener(_onAuthChanged);
    _reconnectSubscription =
        _connectivity.onReconnected.listen((_) => unawaited(syncNow()));
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final userId = _currentUserId();
    if (userId == _userId) return;

    _userId = userId;
    _failures = 0;
    _retryTimer?.cancel();
    _queueSubscription?.cancel();
    _lastSyncedSubscription?.cancel();
    _queue = const [];
    _lastSyncedAt = null;
    notifyListeners();

    if (userId != null) unawaited(_follow(userId));
  }

  Future<void> _follow(String userId) async {
    await _assessments.claimUnowned(userId);
    if (_disposed || _userId != userId) return;

    _queueSubscription = _assessments.watchQueue(userId).listen(_onQueue);
    _lastSyncedSubscription =
        _assessments.watchLastSyncedAt(userId).listen((at) {
      _lastSyncedAt = at;
      notifyListeners();
    });
  }

  void _onQueue(List<LocalAssessment> queue) {
    _queue = queue;
    notifyListeners();

    // Entrou avaliação nova (o "Confirmar", ou já estava no aparelho quando o
    // consultor entrou): envia. As que falharam esperam a próxima tentativa —
    // reenviar a cada mudança da fila seria tentar de novo sem espera nenhuma.
    final hasNew = queue.any((a) =>
        a.syncStatus == LocalSyncStatus.pendingSync && !_sendingIds.contains(a.id));
    if (hasNew) unawaited(syncNow());
  }

  /// Envia a fila agora, sem esperar a próxima tentativa. Sem rede, não tenta:
  /// a volta da rede chama de novo. Com um envio já no ar, repete no fim
  /// dele, para levar o que entrou na fila no meio do caminho.
  Future<void> syncNow() async {
    if (_disposed) return;

    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }

    final sending = _sendQueue();
    _running = sending;
    notifyListeners();
    try {
      await sending;
    } catch (error) {
      // Rede de segurança: os erros esperados já viram motivo na fila. Um
      // erro inesperado (do banco, por exemplo) não pode travar o envio.
      debugPrint('Envio da fila falhou: $error');
      _scheduleRetry();
    } finally {
      _running = null;
      _sendingIds = const {};
      notifyListeners();
    }

    if (_again && !_disposed) {
      _again = false;
      await syncNow();
    }
  }

  Future<void> _sendQueue() async {
    final userId = _userId;
    if (userId == null || _connectivity.isOffline) return;

    _retryTimer?.cancel();
    final batch = await _assessments.loadQueue(userId);
    if (batch.isEmpty) {
      _failures = 0;
      return;
    }

    _sendingIds = {for (final a in batch) a.id};
    notifyListeners();

    final results = <String, String?>{};
    try {
      final payload = await _assessments.syncPayload(batch);
      final response = await _api.post<List<dynamic>>(syncPath, data: payload);
      final outcome = _outcomeByParticipant(response.data);
      for (final assessment in batch) {
        final id = assessment.trainingParticipantId;
        results[assessment.id] =
            outcome.containsKey(id) ? outcome[id] : SendFailure.refused;
      }
    } on ApiException catch (error) {
      // Sessão encerrada no meio do envio: nada falhou por culpa da
      // avaliação. A fila espera o dono entrar de novo.
      if (error.statusCode == 401) return;
      final reason = _reasonFor(error);
      for (final assessment in batch) {
        results[assessment.id] = reason;
      }
    }

    await _assessments.saveSendResults(results, at: _now());

    if (results.values.any((failure) => failure != null)) {
      _scheduleRetry();
    } else {
      _failures = 0;
    }

    // O backend recalcula o score e muda o status do participante: baixa de
    // novo as sessões afetadas, para a linha virar Aprovado/Reavaliar.
    final sessions = {
      for (final a in batch)
        if (results[a.id] == null) a.sessionId,
    };
    for (final sessionId in sessions) {
      unawaited(_participants.syncSession(sessionId));
    }
  }

  /// `{trainingParticipantId: nulo se aceita, ou o motivo}`, da resposta do
  /// backend: `[{ trainingParticipantId, status: 'fulfilled' | 'rejected',
  /// error }]`. A mensagem crua da recusa vai só para o log.
  static Map<String, String?> _outcomeByParticipant(Object? body) {
    if (body is! List) return const {};
    final outcome = <String, String?>{};
    for (final item in body.whereType<Map<dynamic, dynamic>>()) {
      final id = item['trainingParticipantId'];
      if (id is! String) continue;
      if (item['status'] == 'fulfilled') {
        outcome[id] = null;
      } else {
        debugPrint('Avaliação de $id recusada: ${item['error']}');
        outcome[id] = SendFailure.refused;
      }
    }
    return outcome;
  }

  static String _reasonFor(ApiException error) {
    if (error.isTimeout) return SendFailure.timeout;
    if (error.isNetworkError) return SendFailure.noConnection;
    final status = error.statusCode;
    if (status != null && status >= 500) return SendFailure.serverDown;
    return SendFailure.refused;
  }

  void _scheduleRetry() {
    if (_disposed) return;
    final delay = retryDelays[math.min(_failures, retryDelays.length - 1)];
    _failures++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(syncNow()));
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_started) _authChanges.removeListener(_onAuthChanged);
    _retryTimer?.cancel();
    _queueSubscription?.cancel();
    _lastSyncedSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
```

Em `lib/app_providers.dart`:

Substituir (1 de 8):

```dart
import 'package:provider/provider.dart';
```

por:

```dart
import 'dart:async';

import 'package:provider/provider.dart';
```

Substituir (2 de 8):

```dart
import 'data/services/api/api_client.dart';
import 'data/services/auth_session.dart';
```

por:

```dart
import 'data/services/api/api_client.dart';
import 'data/services/assessment_sync_service.dart';
import 'data/services/auth_session.dart';
```

Substituir (3 de 8):

```dart
    required this.connectivityService,
  });
```

por:

```dart
    required this.connectivityService,
    required this.assessmentSyncService,
  });
```

Substituir (4 de 8):

```dart
    final assessmentRepository = AssessmentRepository(database: database);
```

por:

```dart
    final assessmentRepository = AssessmentRepository(database: database);
    final connectivityService = ConnectivityService();
    final assessmentSyncService = AssessmentSyncService(
      apiClient: apiClient,
      assessments: assessmentRepository,
      participants: participantRepository,
      connectivity: connectivityService,
      authChanges: authRepository,
      currentUserId: () => authRepository.currentUser?.id,
    );
    // O envio só começa depois da primeira leitura da conexão: antes dela o
    // app acha que está online (o padrão), e abrir sem sinal marcaria a fila
    // com erro em vez de deixá-la "Na fila".
    unawaited(
      connectivityService.initialize().whenComplete(assessmentSyncService.start),
    );
```

Substituir (5 de 8):

```dart
      assessmentRepository: assessmentRepository,
      connectivityService: ConnectivityService()..initialize(),
    );
```

por:

```dart
      assessmentRepository: assessmentRepository,
      connectivityService: connectivityService,
      assessmentSyncService: assessmentSyncService,
    );
```

Substituir (6 de 8):

```dart
  final ConnectivityService connectivityService;
```

por:

```dart
  final ConnectivityService connectivityService;
  final AssessmentSyncService assessmentSyncService;
```

Substituir (7 de 8):

```dart
        ),
      ];
```

por:

```dart
        ),
        ChangeNotifierProvider<AssessmentSyncService>.value(
          value: assessmentSyncService,
        ),
      ];
```

Substituir (8 de 8):

```dart
  void dispose() {
    connectivityService.dispose();
```

por:

```dart
  void dispose() {
    assessmentSyncService.dispose();
    connectivityService.dispose();
```

Em `lib/app.dart`:

Substituir (1 de 2):

```dart
import 'package:flutter/material.dart';
```

por:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
```

Substituir (2 de 2):

```dart

  @override
  void dispose() {
    _dependencies.dispose();
```

por:

```dart

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // O app voltou do segundo plano: a rede pode ter voltado enquanto ele
    // estava parado, sem o aviso chegar — envia a fila (decisão de 29/09/2026).
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(_dependencies.assessmentSyncService.syncNow()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _dependencies.dispose();
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **323 testes passando** (inclusive `test/widget_test.dart`, que abre o app inteiro com o serviço).

- [ ] **Step 5: Commit**

```bash
git add lib/data/services/api/api_exception.dart lib/data/services/assessment_sync_service.dart lib/app_providers.dart lib/app.dart test/data/services/api/api_client_test.dart test/data/services/assessment_sync_service_test.dart
git commit -m "feat(mobile): envio automatico das avaliacoes confirmadas"
```

---

## Task 4: Tela 1.6 "Conferir e finalizar"

O "Finalizar avaliação" deixa de gravar e passa a abrir a 1.6 com `context.push<SummaryExit>`. A 1.6 fecha de três jeitos: "Confirmar" (`SummaryConfirmed` — o checklist fecha junto e volta ao detalhe), toque numa categoria (`SummaryReviewCategory` — o checklist abre nela) ou o voltar (nada muda). O `finish` sai do repositório e da ViewModel, junto com o diálogo das categorias sem marcação.

**Files:**
- Create: `lib/ui/core/score_labels.dart`
- Create: `lib/ui/checklist/checklist_badges.dart`
- Create: `lib/ui/summary/summary_viewmodel.dart`
- Create: `lib/ui/summary/summary_screen.dart`
- Modify: `lib/ui/checklist/checklist_sections.dart`
- Modify: `lib/ui/checklist/checklist_viewmodel.dart`
- Modify: `lib/ui/checklist/checklist_screen.dart`
- Modify: `lib/router.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/data/repositories/assessment_repository.dart` — sai `finish`
- Create: `test/ui/core/score_labels_test.dart`, `test/ui/summary/summary_viewmodel_test.dart`, `test/ui/summary/summary_screen_test.dart`
- Test: `test/ui/checklist/checklist_sections_test.dart`, `test/ui/checklist/checklist_viewmodel_test.dart`, `test/ui/checklist/checklist_screen_test.dart`, `test/data/repositories/assessment_repository_test.dart`

**Interfaces:**
- Consumes: `AssessmentRepository.findByParticipant`/`loadItems`/`confirm` (Task 2); `buildChecklistSections`, `overallScoreOf`, `scoreBadgeColorsFor`; `getApprovalStatus`; `ParticipantRepository.watchParticipant`.
- Produces:
  - `String percentLabel(double score)` em `lib/ui/core/score_labels.dart` (sai do `checklist_screen.dart`).
  - `CategoryCodeChip({required String code, Color background, Color ink})`, `ScoreBadge({required double score})`.
  - `ChecklistCategory.markedCount`; `String infractionCountLabel(int count)`.
  - `ChecklistViewModel.expandCategory(String categoryId)`; saem `finish`, `isFinished`, `unreviewedCount`, `hasUnreviewedCategories`.
  - `SummaryViewModel({required String participantId, required AssessmentRepository assessmentRepository, required ParticipantRepository participantRepository, required AssessmentCatalogRepository catalogRepository})`: `isLoading`, `participant`, `sections`, `overallScore`, `isApproved`, `infractionCount`, `canConfirm`, `isConfirming`, `isConfirmed`, `errorMessage`, `init()`, `confirm()`.
  - `sealed class SummaryExit`, `SummaryConfirmed`, `SummaryReviewCategory(String categoryId)`; `SummaryScreen({required String participantId})`.
  - `AppRoutes.participantSummary(sessionId, participantId)` → `/sessions/:sessionId/participants/:participantId/summary`.
  - `AppTypography`: `summaryScoreLabel`, `summaryScore`, `resultPill`, `summaryDetail`, `summarySectionTitle`.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/core/score_labels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/score_labels.dart';

void main() {
  test('percentLabel usa uma casa e vírgula decimal', () {
    expect(percentLabel(86.6666), '86,7%');
    expect(percentLabel(100), '100,0%');
    expect(percentLabel(0), '0,0%');
  });
}
```

Em `test/ui/checklist/checklist_sections_test.dart`:

Substituir:

```dart
      expect(sections[1].isReviewed, isFalse);
    });
  });
```

por:

```dart
      expect(sections[1].isReviewed, isFalse);
    });

    test('markedCount conta só as infrações com nota marcada', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [note('note-b-1', 'B', 1)]),
            infraction('inf-2', order: 2, notes: [note('note-b-2', 'B', 1)]),
            infraction('inf-3', order: 3, notes: [note('note-b-3', 'B', 1)]),
          ],
        ),
      ];
      final items = [item('inf-1', 'note-b-1'), item('inf-3', 'note-b-3')];

      final sections = buildChecklistSections(catalog, items);

      expect(sections.single.markedCount, 2);
    });
  });

  test('infractionCountLabel conta as marcações da categoria na tela 1.6', () {
    expect(infractionCountLabel(0), 'sem infração');
    expect(infractionCountLabel(1), '1 infração');
    expect(infractionCountLabel(3), '3 infrações');
  });
```

Em `test/ui/checklist/checklist_viewmodel_test.dart`:

Substituir (1 de 7):

```dart
      expect(vm.reviewedCount, 1);
      expect(vm.unreviewedCount, 0);
      expect(vm.hasUnreviewedCategories, isFalse);
    });
```

por:

```dart
      expect(vm.reviewedCount, 1);
    });
```

Substituir (2 de 7):

```dart
      expect(vm.sections.single.score, 100);
      expect(vm.unreviewedCount, 1);
      expect(vm.hasUnreviewedCategories, isTrue);
    });
```

por:

```dart
      expect(vm.sections.single.score, 100);
      expect(vm.reviewedCount, 0);
    });
```

Substituir (3 de 7):

```dart

  group('finish', () {
    test('marca local, sinaliza isFinished e para o cronômetro', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel(tickInterval: const Duration(milliseconds: 5));
      addTearDown(vm.dispose);
```

por:

```dart

  group('expandCategory', () {
    test('abre a categoria pedida sem alternar — abrir a já aberta não fecha',
        () async {
      await seedParticipant();
      await seedCatalog();
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(
              id: 'cat-2',
              code: 'RR',
              name: 'Respeito às Regras',
              order: 2,
            ),
          );
      final vm = buildViewModel();
      addTearDown(vm.dispose);
```

Substituir (4 de 7):

```dart

      await vm.finish();

      expect(vm.isFinished, isTrue);
      final row = await db.select(db.localAssessments).getSingle();
      expect(row.syncStatus, LocalSyncStatus.pendingSync);
      expect(row.endTime, isNotNull);

      var notifications = 0;
      vm.addListener(() => notifications++);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(notifications, 0, reason: 'sem cronômetro, ninguém notifica mais');
    });

    test('sem catálogo no aparelho, não finaliza — uma avaliação vazia daria 100%',
        () async {
      await seedParticipant();
```

por:

```dart

      vm.expandCategory('cat-2');
      expect(vm.expandedCategoryId, 'cat-2');

      vm.expandCategory('cat-2');
      expect(vm.expandedCategoryId, 'cat-2');
    });
  });

  group('hasCatalog', () {
    test('sem catálogo no aparelho, não há o que avaliar', () async {
      await seedParticipant();
```

Substituir (5 de 7):

```dart
      expect(vm.hasCatalog, isFalse);
      await vm.finish();

      expect(vm.isFinished, isFalse);
      final row = await db.select(db.localAssessments).getSingle();
      expect(row.syncStatus, LocalSyncStatus.draft);
    });
```

por:

```dart
      expect(vm.hasCatalog, isFalse);
    });
```

Substituir (6 de 7):

```dart
        'catálogo só com categoria sem id vale como sem catálogo — nada a '
        'avaliar, então também não finaliza', () async {
      await seedParticipant();
```

por:

```dart
        'catálogo só com categoria sem id vale como sem catálogo — nada a '
        'avaliar', () async {
      await seedParticipant();
```

Substituir (7 de 7):

```dart
      expect(vm.hasCatalog, isFalse);
      await vm.finish();

      expect(vm.isFinished, isFalse);
    });
```

por:

```dart
      expect(vm.hasCatalog, isFalse);
    });
```

Em `test/ui/checklist/checklist_screen_test.dart`:

Substituir (1 de 7):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
```

por:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
```

Substituir (2 de 7):

```dart
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
```

por:

```dart
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/summary/summary_screen.dart';
```

Substituir (3 de 7):

```dart

  /// O checklist empilhado sobre uma tela de origem — para ver a volta.
  Future<void> pumpOverOrigin(WidgetTester tester) async {
    await tester.pumpWidget(withProviders(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const ChecklistScreen(sessionId: 'sess-1', participantId: 'tp-1'),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
```

por:

```dart

  /// O checklist empilhado sobre uma tela de origem, com as rotas reais do
  /// checklist e da conferência — o "Finalizar avaliação" navega pelo
  /// go_router.
  Future<void> pumpOverOrigin(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/origem',
      routes: [
        GoRoute(
          path: '/origem',
          builder: (context, state) => const Scaffold(body: Text('origem')),
        ),
        GoRoute(
          path: AppRoutes.participantChecklist('sess-1', 'tp-1'),
          builder: (context, state) =>
              const ChecklistScreen(sessionId: 'sess-1', participantId: 'tp-1'),
        ),
        GoRoute(
          path: AppRoutes.participantSummary('sess-1', 'tp-1'),
          builder: (context, state) => const SummaryScreen(participantId: 'tp-1'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(withProviders(MaterialApp.router(routerConfig: router)));
    router.push(AppRoutes.participantChecklist('sess-1', 'tp-1'));
    await tester.pumpAndSettle();
```

Substituir (4 de 7):

```dart
  testWidgets(
      'finalizar com categoria sem marcação pergunta e, ao confirmar, grava e '
      'volta para a tela anterior', (tester) async {
    await pumpOverOrigin(tester);
```

por:

```dart
  testWidgets(
      '"Finalizar avaliação" abre a conferência sem diálogo, mesmo com '
      'categoria sem marcação, e ainda não põe nada na fila', (tester) async {
    await pumpOverOrigin(tester);
```

Substituir (5 de 7):

```dart

    expect(find.text('Finalizar avaliação?'), findsOneWidget);
    expect(
      find.text('1 categoria está sem nenhuma infração marcada e conta como '
          '100% no cálculo. Finalizar assim mesmo?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
    expect(row.endTime, isNotNull);
  });

  testWidgets('cancelar o diálogo não finaliza nem sai da tela', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen), findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
```

por:

```dart

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SummaryScreen), findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
```

Substituir (6 de 7):

```dart

  testWidgets('com todas as categorias revisadas, finaliza sem perguntar',
      (tester) async {
    await pumpOverOrigin(tester);
```

por:

```dart

  testWidgets(
      '"Confirmar" na conferência põe na fila e fecha o checklist junto, '
      'de volta à tela de origem', (tester) async {
    await pumpOverOrigin(tester);
```

Substituir (7 de 7):

```dart
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ChecklistScreen), findsNothing);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
  });
```

por:

```dart
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen), findsNothing);
    expect(find.byType(ChecklistScreen), findsNothing);
    expect(find.text('origem'), findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
    expect(row.endTime, isNotNull);
    expect(row.participantName, 'Ana Paula Ribeiro');
  });

  testWidgets('voltar da conferência sem confirmar deixa o rascunho como estava',
      (tester) async {
    await pumpOverOrigin(tester);
    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen), findsNothing);
    expect(find.byType(ChecklistScreen), findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.draft);
  });

  testWidgets(
      'tocar numa categoria da conferência volta ao checklist com ela aberta',
      (tester) async {
    await addSecondCategory();
    await pumpOverOrigin(tester);
    expect(find.text('Excesso de velocidade'), findsOneWidget);

    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Respeito às Regras'));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen), findsNothing);
    expect(find.text('Infração da ficha, item 3'), findsOneWidget);
    expect(find.text('Excesso de velocidade'), findsNothing);
  });
```

Os testes do `finish` saem do repositório.

Em `test/data/repositories/assessment_repository_test.dart`:

Substituir:

```dart
      expect((await repository.loadItems(a2)).single.infractionNoteId, 'note-m');
    });
  });

  group('finish', () {
    test('grava endTime e põe em pendingSync', () async {
      final assessmentId = (await open('tp-1')).id;

      await repository.finish(assessmentId);

      final saved = await db.select(db.localAssessments).getSingle();
      expect(saved.syncStatus, LocalSyncStatus.pendingSync);
      expect(saved.endTime, isNotNull);
    });

    test(
        'reabrir o checklist de um participante já finalizado retoma a mesma '
        'avaliação, sem estourar a chave única', () async {
      final assessmentId = (await open('tp-1')).id;
      await repository.finish(assessmentId);

      final reopened = await open('tp-1');

      expect(reopened.id, assessmentId);
      expect(reopened.syncStatus, LocalSyncStatus.pendingSync);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });
```

por:

```dart
      expect((await repository.loadItems(a2)).single.infractionNoteId, 'note-m');
    });
```

Criar `test/ui/summary/summary_viewmodel_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/summary/summary_viewmodel.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// Repositório real com o "Confirmar" falhando — como um disco cheio.
class _FailingConfirmRepository extends AssessmentRepository {
  _FailingConfirmRepository({required super.database});

  @override
  Future<void> confirm(
    String localAssessmentId, {
    required String participantName,
    required double score,
  }) =>
      Future.error(Exception('disco cheio'));
}

void main() {
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;

  setUp(() async {
    final api = _MockApiClient();
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    assessmentRepository = AssessmentRepository(database: db);
    participantRepository = ParticipantRepository(apiClient: api, database: db);
    catalogRepository = AssessmentCatalogRepository(apiClient: api, database: db);

    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva',
            city: 'Itabira',
            state: 'MG',
            status: 'EM_ANDAMENTO',
            cachedAt: DateTime(2026, 9, 25, 8),
          ),
        );
    await db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-1',
            sessionId: 'sess-1',
            name: 'Ana Paula Ribeiro',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'EM_AVALIACAO',
            cachedAt: DateTime(2026, 9, 25, 8),
          ),
        );
    // CV com duas infrações e RR com uma: uma PM em CV dá 70% em CV, 100% em
    // RR e 85% no geral.
    for (final (id, code, name, order) in [
      ('cat-1', 'CV', 'Controle do Veículo', 1),
      ('cat-2', 'RR', 'Respeito às Regras', 2),
    ]) {
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(
              id: id,
              code: code,
              name: name,
              order: order,
            ),
          );
    }
    for (final (id, category) in [
      ('inf-1', 'cat-1'),
      ('inf-2', 'cat-1'),
      ('inf-3', 'cat-2'),
    ]) {
      await db.into(db.infractions).insert(
            InfractionsCompanion.insert(
              id: id,
              categoryId: category,
              description: 'Infração $id',
              order: 1,
            ),
          );
      for (final (type, deduction) in [('B', 1), ('PM', 3), ('M', 5)]) {
        await db.into(db.infractionNotes).insert(
              InfractionNotesCompanion.insert(
                id: '$id-$type',
                infractionId: id,
                noteType: type,
                deduction: deduction,
              ),
            );
      }
    }
  });

  tearDown(() => db.close());

  Future<LocalAssessment> draftWith(Map<String, String> marks) async {
    final draft = await assessmentRepository.openDraft(
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    for (final MapEntry(key: infraction, value: note) in marks.entries) {
      await assessmentRepository.mark(
        localAssessmentId: draft.id,
        infractionId: infraction,
        infractionNoteId: note,
      );
    }
    return draft;
  }

  SummaryViewModel buildViewModel({AssessmentRepository? assessments}) {
    return SummaryViewModel(
      participantId: 'tp-1',
      assessmentRepository: assessments ?? assessmentRepository,
      participantRepository: participantRepository,
      catalogRepository: catalogRepository,
    );
  }

  test(
      'mostra o que o checklist mostrava: as categorias, o % geral, o '
      'resultado e as infrações marcadas', () async {
    await draftWith({'inf-1': 'inf-1-PM'});
    final vm = buildViewModel();
    addTearDown(vm.dispose);

    expect(vm.isLoading, isTrue);
    await vm.init();

    expect(vm.isLoading, isFalse);
    expect(vm.participant?.name, 'Ana Paula Ribeiro');
    expect(vm.sections.map((s) => s.code), ['CV', 'RR']);
    expect(vm.sections.map((s) => s.score), [70, 100]);
    expect(vm.overallScore, 85);
    expect(vm.isApproved, isTrue);
    expect(vm.infractionCount, 1);
    expect(vm.canConfirm, isTrue);
  });

  test('abaixo de 70% no geral, não é aprovado', () async {
    await draftWith({'inf-1': 'inf-1-M', 'inf-2': 'inf-2-M'});
    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await vm.init();

    expect(vm.overallScore, 50);
    expect(vm.isApproved, isFalse);
    expect(vm.infractionCount, 2);
  });

  test('confirmar grava o fim, o nome e o % mostrado, e põe na fila', () async {
    final draft = await draftWith({'inf-1': 'inf-1-PM'});
    final vm = buildViewModel();
    addTearDown(vm.dispose);
    await vm.init();

    await vm.confirm();

    expect(vm.isConfirmed, isTrue);
    expect(vm.canConfirm, isFalse);
    final row = await (db.select(db.localAssessments)
          ..where((t) => t.id.equals(draft.id)))
        .getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
    expect(row.endTime, isNotNull);
    expect(row.participantName, 'Ana Paula Ribeiro');
    expect(row.score, 85);
  });

  test('sem rascunho, não há o que confirmar', () async {
    final vm = buildViewModel();
    addTearDown(vm.dispose);
    await vm.init();

    expect(vm.canConfirm, isFalse);
    await vm.confirm();

    expect(vm.isConfirmed, isFalse);
    expect(await db.select(db.localAssessments).get(), isEmpty);
  });

  test(
      'sem catálogo, não confirma — uma avaliação sem categoria nenhuma daria '
      '100%', () async {
    final draft = await draftWith({});
    await db.delete(db.infractionNotes).go();
    await db.delete(db.infractions).go();
    await db.delete(db.assessmentCategories).go();
    final vm = buildViewModel();
    addTearDown(vm.dispose);
    await vm.init();

    expect(vm.canConfirm, isFalse);
    await vm.confirm();

    final row = await (db.select(db.localAssessments)
          ..where((t) => t.id.equals(draft.id)))
        .getSingle();
    expect(row.syncStatus, LocalSyncStatus.draft);
  });

  test(
      'falha ao gravar mostra a mensagem, não fecha e deixa tentar de novo',
      () async {
    await draftWith({'inf-1': 'inf-1-PM'});
    final vm = buildViewModel(
      assessments: _FailingConfirmRepository(database: db),
    );
    addTearDown(vm.dispose);
    await vm.init();

    await vm.confirm();

    expect(vm.isConfirmed, isFalse);
    expect(vm.errorMessage,
        'Não foi possível confirmar a avaliação. Tente de novo.');
    expect(vm.canConfirm, isTrue);
  });
}
```

Criar `test/ui/summary/summary_screen_test.dart`:

```dart
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// Repositório real com o "Confirmar" falhando — como um disco cheio.
class _FailingConfirmRepository extends AssessmentRepository {
  _FailingConfirmRepository({required super.database});

  @override
  Future<void> confirm(
    String localAssessmentId, {
    required String participantName,
    required double score,
  }) =>
      Future.error(Exception('disco cheio'));
}

void main() {
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;

  /// Como a tela fechou: o valor do `pop`, e se ela fechou.
  SummaryExit? exit;
  var closed = false;

  setUp(() async {
    final api = _MockApiClient();
    // Mesmo motivo do checklist: sem fechar os streams na hora, o `Timer` que
    // o drift agenda ao cancelar um stream ficaria pendente no teste.
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    assessmentRepository = AssessmentRepository(database: db);
    participantRepository = ParticipantRepository(apiClient: api, database: db);
    catalogRepository = AssessmentCatalogRepository(apiClient: api, database: db);
    exit = null;
    closed = false;

    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva',
            city: 'Itabira',
            state: 'MG',
            status: 'EM_ANDAMENTO',
            cachedAt: DateTime(2026, 9, 25, 8),
          ),
        );
    await db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-1',
            sessionId: 'sess-1',
            name: 'Ana Paula Ribeiro',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'EM_AVALIACAO',
            cachedAt: DateTime(2026, 9, 25, 8),
          ),
        );
    for (final (id, code, name, order) in [
      ('cat-1', 'CV', 'Controle do Veículo', 1),
      ('cat-2', 'RR', 'Respeito às Regras', 2),
    ]) {
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(
              id: id,
              code: code,
              name: name,
              order: order,
            ),
          );
    }
    for (final (id, category) in [
      ('inf-1', 'cat-1'),
      ('inf-2', 'cat-1'),
      ('inf-3', 'cat-2'),
    ]) {
      await db.into(db.infractions).insert(
            InfractionsCompanion.insert(
              id: id,
              categoryId: category,
              description: 'Infração $id',
              order: 1,
            ),
          );
      for (final (type, deduction) in [('B', 1), ('PM', 3), ('M', 5)]) {
        await db.into(db.infractionNotes).insert(
              InfractionNotesCompanion.insert(
                id: '$id-$type',
                infractionId: id,
                noteType: type,
                deduction: deduction,
              ),
            );
      }
    }
  });

  tearDown(() => db.close());

  Future<void> draftWith(Map<String, String> marks) async {
    final draft = await assessmentRepository.openDraft(
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    for (final MapEntry(key: infraction, value: note) in marks.entries) {
      await assessmentRepository.mark(
        localAssessmentId: draft.id,
        infractionId: infraction,
        infractionNoteId: note,
      );
    }
  }

  /// A tela 1.6 empilhada sobre uma origem, guardando como ela fechou.
  Future<void> pumpSummary(
    WidgetTester tester, {
    AssessmentRepository? assessments,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AssessmentRepository>.value(
            value: assessments ?? assessmentRepository,
          ),
          Provider<ParticipantRepository>.value(value: participantRepository),
          Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  exit = await Navigator.of(context).push<SummaryExit>(
                    MaterialPageRoute(
                      builder: (_) => const SummaryScreen(participantId: 'tp-1'),
                    ),
                  );
                  closed = true;
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'mostra a pontuação, o resultado e cada categoria com o que foi marcado '
      'e o %', (tester) async {
    await draftWith({'inf-1': 'inf-1-PM'});

    await pumpSummary(tester);

    expect(find.text('Conferir e finalizar'), findsOneWidget);
    expect(find.text('Pontuação final'), findsOneWidget);
    expect(find.text('85,0%'), findsOneWidget);
    expect(find.text('Aprovado'), findsOneWidget);
    expect(
      find.text('Ana Paula Ribeiro · 1 infração · mínimo para aprovação 70%.'),
      findsOneWidget,
    );
    expect(find.text('Por categoria'), findsOneWidget);
    expect(find.text('CV'), findsOneWidget);
    expect(find.text('Controle do Veículo'), findsOneWidget);
    expect(find.text('1 infração'), findsOneWidget);
    expect(find.text('70,0%'), findsOneWidget);
    expect(find.text('RR'), findsOneWidget);
    expect(find.text('sem infração'), findsOneWidget);
    expect(find.text('100,0%'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
  });

  testWidgets('abaixo de 70% mostra "Necessita reavaliação"', (tester) async {
    await draftWith({'inf-1': 'inf-1-M', 'inf-2': 'inf-2-M'});

    await pumpSummary(tester);

    expect(find.text('50,0%'), findsOneWidget);
    expect(find.text('Necessita reavaliação'), findsOneWidget);
    expect(
      find.text('Ana Paula Ribeiro · 2 infrações · mínimo para aprovação 70%.'),
      findsOneWidget,
    );
  });

  testWidgets('sem nenhuma marcação, a linha diz "nenhuma infração"',
      (tester) async {
    await draftWith({});

    await pumpSummary(tester);

    expect(
      find.text('Ana Paula Ribeiro · nenhuma infração · mínimo para aprovação 70%.'),
      findsOneWidget,
    );
  });

  testWidgets('"Confirmar" põe na fila e fecha avisando que confirmou',
      (tester) async {
    await draftWith({'inf-1': 'inf-1-PM'});
    await pumpSummary(tester);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(exit, isA<SummaryConfirmed>());
    expect(find.byType(SummaryScreen), findsNothing);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
  });

  testWidgets('tocar numa categoria fecha levando a categoria para o checklist',
      (tester) async {
    await draftWith({'inf-1': 'inf-1-PM'});
    await pumpSummary(tester);

    await tester.tap(find.text('Respeito às Regras'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(
      exit,
      isA<SummaryReviewCategory>().having((e) => e.categoryId, 'categoryId', 'cat-2'),
    );
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.draft);
  });

  testWidgets('falha ao confirmar mostra a mensagem e a tela continua aberta',
      (tester) async {
    await draftWith({'inf-1': 'inf-1-PM'});
    await pumpSummary(
      tester,
      assessments: _FailingConfirmRepository(database: db),
    );

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível confirmar a avaliação. Tente de novo.'),
        findsOneWidget);
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(closed, isFalse);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/ui/core/score_labels_test.dart test/ui/checklist/ test/ui/summary/ test/data/repositories/assessment_repository_test.dart`
Esperado: falha de compilação — `score_labels_test.dart` e os testes da 1.6 não acham `lib/ui/core/score_labels.dart` e `lib/ui/summary/…`; `checklist_sections_test.dart` não acha `markedCount`/`infractionCountLabel`; `checklist_viewmodel_test.dart`, `expandCategory`; `checklist_screen_test.dart`, `AppRoutes.participantSummary` e o `SummaryScreen`. O `assessment_repository_test.dart` passa: só perdeu os testes do `finish`.

- [ ] **Step 3: Rótulos, selos e estilos compartilhados**

Criar `lib/ui/core/score_labels.dart`:

```dart
/// "86,7%" — uma casa, vírgula decimal, como no canvas. É o % do checklist,
/// da tela 1.6 e da fila de envio; os chips "Aprovado · 87%" do detalhe
/// arredondam como o painel web (`chipLabelFor`).
String percentLabel(double score) =>
    '${score.toStringAsFixed(1).replaceAll('.', ',')}%';
```

Criar `lib/ui/checklist/checklist_badges.dart`:

```dart
import 'package:flutter/material.dart';

import '../core/score_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'checklist_sections.dart';

/// Chip do código da categoria ("CV") — no checklist e na tela 1.6.
class CategoryCodeChip extends StatelessWidget {
  const CategoryCodeChip({
    super.key,
    required this.code,
    this.background = AppColors.categoryChipBg,
    this.ink = AppColors.primaryDark,
  });

  final String code;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm - 1,
        vertical: AppSpacing.xs - 1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(code, style: AppTypography.categoryCode.copyWith(color: ink)),
    );
  }
}

/// Selo de score da categoria ("86,7%", spec "5a") — no checklist e na tela
/// 1.6, com as cores por faixa de [scoreBadgeColorsFor].
class ScoreBadge extends StatelessWidget {
  const ScoreBadge({super.key, required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final colors = scoreBadgeColorsFor(score);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm - 1,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(
        percentLabel(score),
        style: AppTypography.scoreBadge.copyWith(color: colors.ink),
      ),
    );
  }
}
```

Em `lib/ui/checklist/checklist_sections.dart`:

Substituir (1 de 2):

```dart
  /// Regra decidida com o usuário em 26/09/2026: uma categoria conta como
  /// "revisada" (não pendente, para o aviso do "Finalizar avaliação") quando
  /// tem pelo menos uma infração marcada — não precisa marcar as demais como
  /// "sem infração" para contar.
  bool get isReviewed => infractions.any((i) => i.isMarked);
}
```

por:

```dart
  /// Regra decidida com o usuário em 26/09/2026: uma categoria conta como
  /// "revisada" (para o "X de Y categorias revisadas") quando tem pelo menos
  /// uma infração marcada — não precisa marcar as demais como "sem infração"
  /// para contar.
  bool get isReviewed => infractions.any((i) => i.isMarked);

  /// Quantas infrações da categoria têm nota marcada.
  int get markedCount => infractions.where((i) => i.isMarked).length;
}
```

Substituir (2 de 2):

```dart
  return (bg: AppColors.noteMBg, ink: AppColors.noteMInk);
}
```

por:

```dart
  return (bg: AppColors.noteMBg, ink: AppColors.noteMInk);
}

/// "sem infração", "1 infração", "3 infrações" — o que foi marcado numa
/// categoria, na tela 1.6.
String infractionCountLabel(int count) => switch (count) {
      0 => 'sem infração',
      1 => '1 infração',
      _ => '$count infrações',
    };
```

Em `lib/ui/core/theme/app_typography.dart`:

Substituir:

```dart

  /// Campo de senha mascarado
```

por:

```dart

  // ─── Conferir e finalizar (quadro "2e" do canvas) ─────────────────────────

  /// "Pontuação final", acima do número
  static TextStyle get summaryScoreLabel =>
      _inter(size: 13, weight: FontWeight.w500, height: 1.2, color: AppColors.text3);

  /// O % geral em destaque ("86,7%")
  static TextStyle get summaryScore =>
      _inter(size: 40, weight: FontWeight.w800, height: 1, letterSpacing: -0.8);

  /// Pílula do resultado, ao lado do % ("Aprovado")
  static TextStyle get resultPill =>
      _inter(size: 12.5, weight: FontWeight.w600, height: 1.2);

  /// "Ana Paula Ribeiro · 3 infrações · mínimo para aprovação 70%."
  static TextStyle get summaryDetail =>
      _inter(size: 13, weight: FontWeight.w400, height: 1.45, color: AppColors.text3);

  /// "Por categoria"
  static TextStyle get summarySectionTitle =>
      _inter(size: 13, weight: FontWeight.w600, height: 1.2, color: AppColors.text3);

  /// Campo de senha mascarado
```

- [ ] **Step 4: A 1.6 e a rota**

Criar `lib/ui/summary/summary_viewmodel.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/session_participant.dart';
import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/scoring.dart';
import '../checklist/checklist_sections.dart';

/// Estado da tela 1.6 "Conferir e finalizar" (Fase 5A).
///
/// Lê só do banco, então funciona sem rede. O rascunho, as marcações e o
/// catálogo são os mesmos do checklist, e as seções saem de
/// `buildChecklistSections`: a tela mostra exatamente os números que o
/// checklist mostrava. O "Confirmar" só grava — quem envia é o
/// `AssessmentSyncService`, que observa a fila.
class SummaryViewModel extends ChangeNotifier {
  SummaryViewModel({
    required this.participantId,
    required AssessmentRepository assessmentRepository,
    required ParticipantRepository participantRepository,
    required AssessmentCatalogRepository catalogRepository,
  })  : _assessmentRepository = assessmentRepository,
        _participantRepository = participantRepository,
        _catalogRepository = catalogRepository;

  final String participantId;
  final AssessmentRepository _assessmentRepository;
  final ParticipantRepository _participantRepository;
  final AssessmentCatalogRepository _catalogRepository;

  static const String _confirmFailed =
      'Não foi possível confirmar a avaliação. Tente de novo.';

  StreamSubscription<SessionParticipant?>? _participantSubscription;

  bool _disposed = false;
  bool _loading = true;
  bool _confirming = false;
  bool _confirmed = false;
  String? _errorMessage;
  LocalAssessment? _assessment;
  SessionParticipant? _participant;
  List<ChecklistCategory> _sections = const [];

  bool get isLoading => _loading;
  SessionParticipant? get participant => _participant;
  List<ChecklistCategory> get sections => _sections;
  double get overallScore => overallScoreOf(_sections);

  /// Mesmo corte do backend (`getApprovalStatus`): 70% ou mais.
  bool get isApproved => getApprovalStatus(overallScore) == 'APROVADO';

  /// Infrações marcadas na avaliação inteira.
  int get infractionCount =>
      _sections.fold(0, (total, category) => total + category.markedCount);

  bool get isConfirming => _confirming;

  /// Uma vez `true`, a tela fecha — a avaliação está na fila de envio.
  bool get isConfirmed => _confirmed;

  /// Falha ao gravar o "Confirmar" — a tela continua aberta e o rascunho,
  /// intacto.
  String? get errorMessage => _errorMessage;

  /// Sem rascunho ou sem catálogo não há o que confirmar: uma avaliação sem
  /// categoria nenhuma daria 100%, "Aprovado".
  bool get canConfirm =>
      !_loading &&
      _assessment != null &&
      _sections.isNotEmpty &&
      !_confirming &&
      !_confirmed;

  Future<void> init() async {
    _participantSubscription ??=
        _participantRepository.watchParticipant(participantId).listen((p) {
      _participant = p;
      notifyListeners();
    });

    final assessment =
        await _assessmentRepository.findByParticipant(participantId);
    if (_disposed) return;
    _assessment = assessment;

    if (assessment != null) {
      final items = await _assessmentRepository.loadItems(assessment.id);
      final catalog = await _catalogRepository.loadCatalog();
      if (_disposed) return;
      _sections = buildChecklistSections(catalog, items);
    }

    _loading = false;
    notifyListeners();
  }

  /// "Confirmar": grava o fim, o nome e o % mostrado, e põe na fila.
  Future<void> confirm() async {
    final assessment = _assessment;
    if (assessment == null || !canConfirm) return;

    _confirming = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _assessmentRepository.confirm(
        assessment.id,
        participantName: _participant?.name ?? '',
        score: overallScore,
      );
      _confirmed = true;
    } catch (_) {
      _errorMessage = _confirmFailed;
    } finally {
      _confirming = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _participantSubscription?.cancel();
    super.dispose();
  }
}
```

Criar `lib/ui/summary/summary_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../checklist/checklist_badges.dart';
import '../checklist/checklist_sections.dart';
import '../core/score_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/skeleton.dart';
import 'summary_viewmodel.dart';

/// Como a tela 1.6 fechou — o checklist, que a abriu, decide o que fazer.
sealed class SummaryExit {
  const SummaryExit();
}

/// "Confirmar": a avaliação entrou na fila. O checklist fecha também.
final class SummaryConfirmed extends SummaryExit {
  const SummaryConfirmed();
}

/// Tocou numa categoria: o checklist abre nela, para o consultor corrigir.
final class SummaryReviewCategory extends SummaryExit {
  const SummaryReviewCategory(this.categoryId);

  final String categoryId;
}

/// Tela 1.6 — "Conferir e finalizar" (quadro "2e" do canvas, adaptado ao
/// cálculo real em 29/09/2026: sem a conta de pontos, com o selo de % de cada
/// categoria e sem a etapa de assinatura).
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.participantId});

  final String participantId;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late final SummaryViewModel _viewModel = SummaryViewModel(
    participantId: widget.participantId,
    assessmentRepository: context.read<AssessmentRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    catalogRepository: context.read<AssessmentCatalogRepository>(),
  )..init();

  bool _closing = false;

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (_viewModel.isConfirmed && !_closing) {
          _closing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop(const SummaryConfirmed());
          });
        }
        return _buildScaffold();
      },
    );
  }

  Widget _buildScaffold() {
    final ready = !_viewModel.isLoading && _viewModel.sections.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(title: 'Conferir e finalizar'),
            Expanded(child: _buildBody()),
            if (ready) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return ListView(
        key: const Key('summary-skeleton'),
        children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
      );
    }

    return ListView(
      children: [
        _buildScore(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md + 3,
            AppSpacing.xl,
            AppSpacing.md + 3,
          ),
          child: Text('Por categoria', style: AppTypography.summarySectionTitle),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final category in _viewModel.sections) _buildCategory(category),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScore() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pontuação final', style: AppTypography.summaryScoreLabel),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      percentLabel(_viewModel.overallScore),
                      style: AppTypography.summaryScore,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _ResultPill(approved: _viewModel.isApproved),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 2),
          Text(_detailLine(), style: AppTypography.summaryDetail),
        ],
      ),
    );
  }

  /// "Ana Paula Ribeiro · 3 infrações · mínimo para aprovação 70%."
  String _detailLine() {
    final name = _viewModel.participant?.name ?? '';
    final count = _viewModel.infractionCount;
    return [
      if (name.isNotEmpty) name,
      count == 0 ? 'nenhuma infração' : infractionCountLabel(count),
      'mínimo para aprovação 70%.',
    ].join(' · ');
  }

  Widget _buildCategory(ChecklistCategory category) {
    return InkWell(
      key: ValueKey('summary-category-${category.id}'),
      onTap: () => Navigator.of(context).pop(SummaryReviewCategory(category.id)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
        ),
        child: Row(
          children: [
            CategoryCodeChip(code: category.code),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: AppTypography.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs + 1),
                  Text(
                    infractionCountLabel(category.markedCount),
                    style: AppTypography.meta,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ScoreBadge(score: category.score),
            const SizedBox(width: AppSpacing.sm),
            const Icon(AppIcons.chevronRight, size: 22, color: AppColors.text3),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final error = _viewModel.errorMessage;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) ...[
            InlineNotice(
              icon: AppIcons.needsReview,
              tone: NoticeTone.danger,
              message: error,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppCtaButton(
            label: 'Confirmar',
            icon: AppIcons.check,
            size: AppCtaSize.large,
            isLoading: _viewModel.isConfirming,
            onPressed: _viewModel.canConfirm ? _viewModel.confirm : null,
          ),
        ],
      ),
    );
  }
}

/// "Aprovado" ou "Necessita reavaliação", ao lado do % — o corte de 70% do
/// backend. As cores são as dos chips de status do detalhe da sessão.
class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.approved});

  final bool approved;

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, border, ink) = approved
        ? (
            'Aprovado',
            AppIcons.approved,
            AppColors.successBg,
            AppColors.successBorder,
            AppColors.successInk,
          )
        : (
            'Necessita reavaliação',
            AppIcons.needsReview,
            AppColors.dangerBg,
            AppColors.dangerBorder,
            AppColors.dangerInk,
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm + 2,
        AppSpacing.xs + 2,
        AppSpacing.md,
        AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ink),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(label, style: AppTypography.resultPill.copyWith(color: ink)),
        ],
      ),
    );
  }
}
```

Em `lib/router.dart`:

Substituir (1 de 3):

```dart
import 'ui/splash/splash_screen.dart';
```

por:

```dart
import 'ui/splash/splash_screen.dart';
import 'ui/summary/summary_screen.dart';
```

Substituir (2 de 3):

```dart
      '/sessions/$sessionId/participants/$participantId/checklist';
```

por:

```dart
      '/sessions/$sessionId/participants/$participantId/checklist';

  /// "Conferir e finalizar" (tela 1.6, Fase 5A), aberta pelo checklist.
  static String participantSummary(String sessionId, String participantId) =>
      '/sessions/$sessionId/participants/$participantId/summary';
```

Substituir (3 de 3):

```dart
          GoRoute(
            path: 'participants/:participantId/result',
```

por:

```dart
          GoRoute(
            path: 'participants/:participantId/summary',
            builder: (context, state) => SummaryScreen(
              participantId: state.pathParameters['participantId']!,
            ),
          ),
          GoRoute(
            path: 'participants/:participantId/result',
```

- [ ] **Step 5: O checklist abre a 1.6, e o `finish` sai**

Em `lib/ui/checklist/checklist_viewmodel.dart`:

Substituir (1 de 7):

```dart
/// escreve no banco e a tela precisa reagir à própria escrita. Nada aqui fala
/// com o backend: a avaliação só é gravada no aparelho, e a fila de envio é de
/// uma fase futura.
class ChecklistViewModel extends ChangeNotifier {
```

por:

```dart
/// escreve no banco e a tela precisa reagir à própria escrita. Nada aqui fala
/// com o backend: a avaliação só é gravada no aparelho. Quem a põe na fila de
/// envio é o "Confirmar" da tela 1.6 (Fase 5A).
class ChecklistViewModel extends ChangeNotifier {
```

Substituir (2 de 7):

```dart
  String? _expandedCategoryId;
  bool _finished = false;
```

por:

```dart
  String? _expandedCategoryId;
```

Substituir (3 de 7):

```dart
  String? get expandedCategoryId => _expandedCategoryId;

  /// Uma vez `true`, a tela navega de volta ao detalhe da sessão — regra
  /// decidida com o usuário em 26/09/2026: finalizar marca local e volta.
  bool get isFinished => _finished;
```

por:

```dart
  String? get expandedCategoryId => _expandedCategoryId;
```

Substituir (4 de 7):

```dart
  int get totalCategories => sections.length;
  int get unreviewedCount => totalCategories - reviewedCount;

  /// Há categoria sem nenhuma infração marcada — só então o "Finalizar
  /// avaliação" pede confirmação (roteiro da Fase 4).
  bool get hasUnreviewedCategories => unreviewedCount > 0;
```

por:

```dart
  int get totalCategories => sections.length;
```

Substituir (5 de 7):

```dart
  /// falhou) — ou só tem itens sem id, que as seções descartam. Sem seção
  /// não há o que avaliar, e finalizar uma avaliação sem categoria nenhuma
  /// daria 100%, "Aprovado".
  bool get hasCatalog => sections.isNotEmpty;
```

por:

```dart
  /// falhou) — ou só tem itens sem id, que as seções descartam. Sem seção
  /// não há o que avaliar, e confirmar uma avaliação sem categoria nenhuma
  /// daria 100%, "Aprovado": a tela nem oferece o "Finalizar avaliação".
  bool get hasCatalog => sections.isNotEmpty;
```

Substituir (6 de 7):

```dart

  /// Aperta um dos 3 botões de nota. O mesmo botão já selecionado desmarca a
```

por:

```dart

  /// Abre a categoria (fechando a que estava aberta) sem alternar: é a volta
  /// da tela 1.6, que abre o checklist na categoria que o consultor tocou.
  void expandCategory(String categoryId) {
    if (_expandedCategoryId == categoryId) return;
    _expandedCategoryId = categoryId;
    notifyListeners();
  }

  /// Aperta um dos 3 botões de nota. O mesmo botão já selecionado desmarca a
```

Substituir (7 de 7):

```dart

  /// Finaliza a avaliação: grava local e sinaliza a volta para o detalhe.
  /// Sem catálogo, não finaliza — a tela nem mostra o botão, e esta guarda
  /// garante que uma avaliação vazia nunca entre na fila de envio.
  Future<void> finish() async {
    final assessmentId = _assessmentId;
    if (assessmentId == null || _finished || !hasCatalog) return;

    await _assessmentRepository.finish(assessmentId);
    _ticker?.cancel();
    _finished = true;
    notifyListeners();
  }

  @override
```

por:

```dart

  @override
```

Em `lib/ui/checklist/checklist_screen.dart`:

Substituir (1 de 12):

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
```

por:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
```

Substituir (2 de 12):

```dart
import '../../data/services/connectivity_service.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../../data/services/connectivity_service.dart';
import '../../router.dart';
import '../core/score_labels.dart';
import '../core/theme/app_colors.dart';
```

Substituir (3 de 12):

```dart
import '../core/widgets/skeleton.dart';
import 'checklist_sections.dart';
```

por:

```dart
import '../core/widgets/skeleton.dart';
import '../summary/summary_screen.dart';
import 'checklist_badges.dart';
import 'checklist_sections.dart';
```

Substituir (4 de 12):

```dart

  bool _poppedForFinish = false;

  /// Cabeçalho da categoria aberta — há no máximo uma, então uma chave basta.
```

por:

```dart

  /// Cabeçalho da categoria aberta — há no máximo uma, então uma chave basta.
```

Substituir (5 de 12):

```dart
      listenable: _viewModel,
      builder: (context, _) {
        // "Marca local e volta pro detalhe" (decisão de 26/09/2026): uma vez
        // finalizada, a tela sai sozinha.
        if (_viewModel.isFinished && !_poppedForFinish) {
          _poppedForFinish = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
        }
        return _buildScaffold(context);
      },
    );
```

por:

```dart
      listenable: _viewModel,
      builder: (context, _) => _buildScaffold(context),
    );
```

Substituir (6 de 12):

```dart
            Text(
              _percentLabel(_viewModel.overallScore),
              style: AppTypography.checklistProgressValue,
```

por:

```dart
            Text(
              percentLabel(_viewModel.overallScore),
              style: AppTypography.checklistProgressValue,
```

Substituir (7 de 12):

```dart
          children: [
            _CodeChip(
              code: category.code,
              background: AppColors.categoryChipBg,
              ink: AppColors.primaryDark,
            ),
            const SizedBox(width: AppSpacing.sm + 2),
```

por:

```dart
          children: [
            CategoryCodeChip(code: category.code),
            const SizedBox(width: AppSpacing.sm + 2),
```

Substituir (8 de 12):

```dart
  /// até ele (decisão de 27/09/2026) — o consultor começa sempre pela
  /// primeira infração.
  void _openCategory(String categoryId) {
    _viewModel.toggleCategory(categoryId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
```

por:

```dart
  /// até ele (decisão de 27/09/2026) — o consultor começa sempre pela
  /// primeira infração. Serve também para a volta da tela 1.6.
  void _openCategory(String categoryId) {
    _viewModel.expandCategory(categoryId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
```

Substituir (9 de 12):

```dart
          children: [
            _CodeChip(
              code: category.code,
```

por:

```dart
          children: [
            CategoryCodeChip(
              code: category.code,
```

Substituir (10 de 12):

```dart
            const SizedBox(width: AppSpacing.sm + 2),
            _ScoreBadge(score: category.score),
            const SizedBox(width: AppSpacing.sm + 2),
```

por:

```dart
            const SizedBox(width: AppSpacing.sm + 2),
            ScoreBadge(score: category.score),
            const SizedBox(width: AppSpacing.sm + 2),
```

Substituir (11 de 12):

```dart
        size: AppCtaSize.large,
        onPressed: _finish,
      ),
```

por:

```dart
        size: AppCtaSize.large,
        onPressed: _openSummary,
      ),
```

Substituir (12 de 12):

```dart

  /// Roteiro da Fase 4: só pergunta quando há categoria sem nenhuma infração
  /// marcada — com todas revisadas, finaliza direto.
  Future<void> _finish() async {
    if (_viewModel.hasUnreviewedCategories) {
      final confirmed = await _confirmUnreviewed();
      if (confirmed != true || !mounted) return;
    }
    await _viewModel.finish();
  }

  Future<bool?> _confirmUnreviewed() {
    final pending = _viewModel.unreviewedCount;
    final message = pending == 1
        ? '1 categoria está sem nenhuma infração marcada e conta como 100% '
            'no cálculo. Finalizar assim mesmo?'
        : '$pending categorias estão sem nenhuma infração marcada e contam '
            'como 100% no cálculo. Finalizar assim mesmo?';

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar avaliação?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }
}

/// "86,7%" — uma casa, vírgula decimal, como no canvas.
String _percentLabel(double score) =>
    '${score.toStringAsFixed(1).replaceAll('.', ',')}%';

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code, required this.background, required this.ink});

  final String code;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm - 1,
        vertical: AppSpacing.xs - 1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(code, style: AppTypography.categoryCode.copyWith(color: ink)),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final colors = scoreBadgeColorsFor(score);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm - 1,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(
        _percentLabel(score),
        style: AppTypography.scoreBadge.copyWith(color: colors.ink),
      ),
    );
  }
```

por:

```dart

  /// "Finalizar avaliação" abre a conferência (tela 1.6), sem o diálogo das
  /// categorias sem marcação da Fase 4: a 1.6 mostra cada categoria com o %
  /// antes do "Confirmar" (decisão de 29/09/2026). Quem põe na fila é o
  /// "Confirmar" de lá; daqui, só se decide para onde voltar.
  Future<void> _openSummary() async {
    final exit = await context.push<SummaryExit>(
      AppRoutes.participantSummary(widget.sessionId, widget.participantId),
    );
    if (!mounted) return;

    switch (exit) {
      case SummaryConfirmed():
        // Confirmada: o checklist sai também, de volta ao detalhe da sessão.
        await Navigator.of(context).maybePop();
      case SummaryReviewCategory(:final categoryId):
        _openCategory(categoryId);
      case null:
        break;
    }
  }
```

Em `lib/data/repositories/assessment_repository.dart`:

Substituir:

```dart

  /// Finaliza a avaliação: grava `endTime` e põe na fila de envio. Não sobe
  /// nada agora — só marca o rascunho como pronto para a próxima fase enviar.
  Future<void> finish(String localAssessmentId) {
    final now = DateTime.now();
    return (_db.update(_db.localAssessments)
          ..where((t) => t.id.equals(localAssessmentId)))
        .write(
      LocalAssessmentsCompanion(
        endTime: Value(now),
        syncStatus: const Value(LocalSyncStatus.pendingSync),
        updatedAt: Value(now),
      ),
    );
  }

  /// "Confirmar" da tela 1.6: grava `endTime`, o nome do participante e o %
```

por:

```dart

  /// "Confirmar" da tela 1.6: grava `endTime`, o nome do participante e o %
```

- [ ] **Step 6: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **337 testes passando**.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/core/score_labels.dart lib/ui/checklist/checklist_badges.dart lib/ui/checklist/checklist_sections.dart lib/ui/checklist/checklist_viewmodel.dart lib/ui/checklist/checklist_screen.dart lib/ui/summary/summary_viewmodel.dart lib/ui/summary/summary_screen.dart lib/router.dart lib/ui/core/theme/app_typography.dart lib/data/repositories/assessment_repository.dart test/ui/core/score_labels_test.dart test/ui/checklist/checklist_sections_test.dart test/ui/checklist/checklist_viewmodel_test.dart test/ui/checklist/checklist_screen_test.dart test/ui/summary/summary_viewmodel_test.dart test/ui/summary/summary_screen_test.dart test/data/repositories/assessment_repository_test.dart
git commit -m "feat(mobile): tela conferir e finalizar antes da fila de envio"
```

---

## Task 5: A linha do participante — "Na fila", "Erro no envio" e o cronômetro

A `SessionDetailViewModel` assina as avaliações deste aparelho da sessão (`watchSessionAssessments`, só as do consultor logado). As regras ficam puras em `participant_filter.dart`: só a linha "comigo" muda, e uma avaliação já enviada não muda nada — depois do envio, vale o status do servidor. O `ParticipantRow` ganha `liveMeta` para o cronômetro, que redesenha só o próprio texto.

**Files:**
- Modify: `lib/ui/core/date_labels.dart`
- Create: `lib/ui/core/widgets/elapsed_clock.dart`
- Modify: `lib/ui/core/theme/app_icons.dart`
- Modify: `lib/ui/checklist/checklist_viewmodel.dart` — usa o `stopwatchLabel`
- Modify: `lib/ui/session_detail/participant_filter.dart`
- Modify: `lib/ui/session_detail/participant_row.dart`
- Modify: `lib/ui/session_detail/session_detail_viewmodel.dart`
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Test: `test/ui/core/date_labels_test.dart`, `test/ui/core/widgets/display_widgets_test.dart`, `test/ui/session_detail/participant_filter_test.dart`, `test/ui/session_detail/session_detail_viewmodel_test.dart`, `test/ui/session_detail/session_detail_screen_test.dart`
- Test: `test/ui/sessions/sessions_screen_test.dart` — o toque no card abre o detalhe, que agora precisa do `AssessmentRepository`

**Interfaces:**
- Consumes: `AssessmentRepository.watchSessionAssessments` (Task 2); `percentLabel` (Task 4).
- Produces:
  - `String clockLabel(DateTime moment, DateTime now)` ("08:41" hoje), `String atLabel(DateTime moment, DateTime now)` ("às 07:58" hoje, "em 28 set 07:58"), `String stopwatchLabel(Duration elapsed)` ("00:12:41").
  - `ElapsedClock({required DateTime start, DateTime Function()? clock, Duration tickInterval, TextStyle? style})`.
  - `enum LocalProgress { draft, queued, failed }`; `LocalProgress? localProgressOf(ParticipantSituation, LocalAssessment?)`; `String queueMetaFor(LocalAssessment local, DateTime now)`.
  - `SessionDetailViewModel({…, required AssessmentRepository assessmentRepository, …})`: `localAssessmentFor(participantId)`, `localProgressFor(participant)`; `opensChecklist` é falso na fila.
  - `ParticipantRow({…, Widget? liveMeta})`; `AppIcons.sendFailed`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/core/date_labels_test.dart`:

Substituir:

```dart
  });
}
```

por:

```dart
  });

  test('clockLabel é só a hora no mesmo dia, e dia e hora nos outros', () {
    expect(clockLabel(DateTime(2026, 9, 23, 8, 41), agora), '08:41');
    expect(clockLabel(DateTime(2026, 9, 22, 17, 2), agora), '22 set 17:02');
  });

  test('atLabel diz "às" no mesmo dia e "em" nos outros', () {
    expect(atLabel(DateTime(2026, 9, 23, 7, 58), agora), 'às 07:58');
    expect(atLabel(DateTime(2026, 9, 22, 7, 58), agora), 'em 22 set 07:58');
  });

  test('stopwatchLabel é o cronômetro, e um intervalo negativo vale zero', () {
    expect(stopwatchLabel(const Duration(minutes: 12, seconds: 41)), '00:12:41');
    expect(stopwatchLabel(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
    expect(stopwatchLabel(const Duration(seconds: -5)), '00:00:00');
  });
}
```

Em `test/ui/core/widgets/display_widgets_test.dart`:

Substituir (1 de 2):

```dart
import 'package:simtc/ui/core/widgets/company_logo.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
```

por:

```dart
import 'package:simtc/ui/core/widgets/company_logo.dart';
import 'package:simtc/ui/core/widgets/elapsed_clock.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
```

Substituir (2 de 2):

```dart

  testWidgets('SkeletonListItem anima sem quebrar o layout', (tester) async {
```

por:

```dart

  testWidgets('ElapsedClock avança sozinho a cada tick', (tester) async {
    var now = DateTime(2026, 9, 29, 10, 12, 41);
    await _pump(
      tester,
      ElapsedClock(start: DateTime(2026, 9, 29, 10), clock: () => now),
    );
    expect(find.text('00:12:41'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('00:12:42'), findsOneWidget);
  });

  testWidgets('SkeletonListItem anima sem quebrar o layout', (tester) async {
```

Em `test/ui/session_detail/participant_filter_test.dart`:

Substituir (1 de 2):

```dart
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/ui/session_detail/participant_filter.dart';
```

por:

```dart
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/session_detail/participant_filter.dart';
```

Substituir (2 de 2):

```dart
  });
}
```

por:

```dart
  });

  group('avaliação deste aparelho', () {
    final agora = DateTime(2026, 9, 29, 9);

    LocalAssessment local(
      LocalSyncStatus status, {
      double? score,
      DateTime? lastAttemptAt,
    }) {
      return LocalAssessment(
        id: 'la-1',
        trainingParticipantId: '1',
        sessionId: 'sess-1',
        date: DateTime(2026, 9, 29),
        startTime: DateTime(2026, 9, 29, 8),
        syncStatus: status,
        attemptCount: 0,
        createdAt: DateTime(2026, 9, 29, 8),
        updatedAt: DateTime(2026, 9, 29, 8),
        score: score,
        lastAttemptAt: lastAttemptAt,
      );
    }

    test('só vale na linha "comigo", e a enviada não muda nada', () {
      const mine = ParticipantSituation.mine;
      expect(localProgressOf(mine, local(LocalSyncStatus.draft)), LocalProgress.draft);
      expect(localProgressOf(mine, local(LocalSyncStatus.pendingSync)),
          LocalProgress.queued);
      expect(localProgressOf(mine, local(LocalSyncStatus.error)), LocalProgress.failed);
      expect(localProgressOf(mine, local(LocalSyncStatus.synced)), isNull);
      expect(localProgressOf(mine, null), isNull);
      expect(
        localProgressOf(ParticipantSituation.approved, local(LocalSyncStatus.pendingSync)),
        isNull,
        reason: 'o servidor já respondeu: vale o status dele',
      );
    });

    test('o meta da fila leva o % e o que está acontecendo', () {
      expect(queueMetaFor(local(LocalSyncStatus.pendingSync, score: 86.6667), agora),
          '86,7% · aguardando envio');
      expect(
        queueMetaFor(
          local(LocalSyncStatus.error, score: 62, lastAttemptAt: DateTime(2026, 9, 29, 7, 58)),
          agora,
        ),
        '62,0% · falhou às 07:58',
      );
      expect(
        queueMetaFor(local(LocalSyncStatus.pendingSync), agora),
        'aguardando envio',
        reason: 'as avaliações da Fase 4 não guardaram o %',
      );
    });
  });
}
```

Em `test/ui/session_detail/session_detail_viewmodel_test.dart`:

Substituir (1 de 12):

```dart
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
```

por:

```dart
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
```

Substituir (2 de 12):

```dart
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/session_detail/participant_filter.dart';
```

por:

```dart
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/session_detail/participant_filter.dart';
```

Substituir (3 de 12):

```dart
class _MockParticipantRepository extends Mock implements ParticipantRepository {}
```

por:

```dart
class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockAssessmentRepository extends Mock implements AssessmentRepository {}
```

Substituir (4 de 12):

```dart
  late _MockParticipantRepository participants;
  late _FakeConnectivity connectivity;
```

por:

```dart
  late _MockParticipantRepository participants;
  late _MockAssessmentRepository assessments;
  late _FakeConnectivity connectivity;
```

Substituir (5 de 12):

```dart
  late StreamController<List<SessionParticipant>> participantsStream;
```

por:

```dart
  late StreamController<List<SessionParticipant>> participantsStream;
  late StreamController<List<LocalAssessment>> localStream;
```

Substituir (6 de 12):

```dart

  SessionDetailViewModel build({AuthUser? user = consultora}) {
```

por:

```dart

  /// Avaliação deste aparelho, do jeito que o `AssessmentRepository` guarda.
  LocalAssessment local(String participantId, LocalSyncStatus status) {
    final at = DateTime(2026, 9, 23, 13);
    return LocalAssessment(
      id: 'local-$participantId',
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      date: DateTime(2026, 9, 23),
      startTime: at,
      syncStatus: status,
      attemptCount: 0,
      createdAt: at,
      updatedAt: at,
      ownerUserId: 'u1',
    );
  }

  SessionDetailViewModel build({AuthUser? user = consultora}) {
```

Substituir (7 de 12):

```dart
      participantRepository: participants,
      connectivity: connectivity,
```

por:

```dart
      participantRepository: participants,
      assessmentRepository: assessments,
      connectivity: connectivity,
```

Substituir (8 de 12):

```dart
    participants = _MockParticipantRepository();
    connectivity = _FakeConnectivity();
```

por:

```dart
    participants = _MockParticipantRepository();
    assessments = _MockAssessmentRepository();
    connectivity = _FakeConnectivity();
```

Substituir (9 de 12):

```dart
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();
```

por:

```dart
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();
    localStream = StreamController<List<LocalAssessment>>.broadcast();
```

Substituir (10 de 12):

```dart
        .thenAnswer((_) async => const Success(0));
  });
```

por:

```dart
        .thenAnswer((_) async => const Success(0));
    when(() => assessments.watchSessionAssessments('sess-1', any()))
        .thenAnswer((_) => localStream.stream);
  });
```

Substituir (11 de 12):

```dart
    participantsStream.close();
    connectivity.dispose();
```

por:

```dart
    participantsStream.close();
    localStream.close();
    connectivity.dispose();
```

Substituir (12 de 12):

```dart
      expect(concluida.opensChecklist(meu), isFalse);
    });
```

por:

```dart
      expect(concluida.opensChecklist(meu), isFalse);
    });

    test(
        'a linha "comigo" sabe se a avaliação deste aparelho é rascunho, está '
        'na fila ou falhou — e, confirmada, não abre mais o checklist',
        () async {
      final rascunho =
          participant('r', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final fila =
          participant('f', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final erro =
          participant('e', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final vm = await ready(withParticipants: [rascunho, fila, erro]);

      localStream.add([
        local('r', LocalSyncStatus.draft),
        local('f', LocalSyncStatus.pendingSync),
        local('e', LocalSyncStatus.error),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(vm.localProgressFor(rascunho), LocalProgress.draft);
      expect(vm.localProgressFor(fila), LocalProgress.queued);
      expect(vm.localProgressFor(erro), LocalProgress.failed);
      expect(vm.localAssessmentFor('f')?.id, 'local-f');
      expect(vm.opensChecklist(rascunho), isTrue);
      expect(vm.opensChecklist(fila), isFalse);
      expect(vm.opensChecklist(erro), isFalse);
    });

    test(
        'avaliação já enviada, ou numa linha que o servidor já não mostra '
        'comigo, não muda a linha', () async {
      final meu =
          participant('m', status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final aprovado = participant('a', status: ParticipantStatus.aprovado);
      final vm = await ready(withParticipants: [meu, aprovado]);

      localStream.add([
        local('m', LocalSyncStatus.synced),
        local('a', LocalSyncStatus.pendingSync),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(vm.localProgressFor(meu), isNull);
      expect(vm.localProgressFor(aprovado), isNull);
      expect(vm.opensChecklist(meu), isTrue);
    });
```

Em `test/ui/session_detail/session_detail_screen_test.dart`:

Substituir (1 de 8):

```dart
import 'package:simtc/ui/evaluation/evaluation_placeholder_screen.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
```

por:

```dart
import 'package:simtc/ui/evaluation/evaluation_placeholder_screen.dart';
import 'package:simtc/ui/session_detail/participant_row.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
```

Substituir (2 de 8):

```dart
  late StreamController<List<SessionParticipant>> participantsStream;
```

por:

```dart
  late StreamController<List<SessionParticipant>> participantsStream;
  late StreamController<List<LocalAssessment>> localStream;
```

Substituir (3 de 8):

```dart
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();
```

por:

```dart
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();
    localStream = StreamController<List<LocalAssessment>>.broadcast();
```

Substituir (4 de 8):

```dart
        .thenAnswer((_) => participantsStream.stream);
    when(() => participants.syncSession('sess-1'))
```

por:

```dart
        .thenAnswer((_) => participantsStream.stream);
    when(() => assessments.watchSessionAssessments('sess-1', 'u1'))
        .thenAnswer((_) => localStream.stream);
    when(() => participants.syncSession('sess-1'))
```

Substituir (5 de 8):

```dart
    participantsStream.close();
    connectivity.dispose();
```

por:

```dart
    participantsStream.close();
    localStream.close();
    connectivity.dispose();
```

Substituir (6 de 8):

```dart
    List<SessionParticipant> withParticipants = const [],
  }) async {
```

por:

```dart
    List<SessionParticipant> withParticipants = const [],
    List<LocalAssessment> withLocal = const [],
  }) async {
```

Substituir (7 de 8):

```dart
    participantsStream.add(withParticipants);
    await tester.pump();
  }
```

por:

```dart
    participantsStream.add(withParticipants);
    localStream.add(withLocal);
    await tester.pump();
  }

  /// Avaliação deste aparelho, do jeito que o `AssessmentRepository` guarda.
  LocalAssessment local(
    String participantId,
    LocalSyncStatus status, {
    DateTime? startTime,
    double? score,
    DateTime? lastAttemptAt,
  }) {
    final at = startTime ?? DateTime.now();
    return LocalAssessment(
      id: 'local-$participantId',
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      date: at,
      startTime: at,
      syncStatus: status,
      attemptCount: 0,
      createdAt: at,
      updatedAt: at,
      ownerUserId: 'u1',
      score: score,
      lastAttemptAt: lastAttemptAt,
    );
  }
```

Substituir (8 de 8):

```dart

  group('navegação pelas rotas reais', () {
```

por:

```dart

  group('avaliação deste aparelho na linha "comigo"', () {
    SessionParticipant minha() => participant('1', 'Ana Paula Ribeiro',
        status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');

    ParticipantRow row(WidgetTester tester) =>
        tester.widget<ParticipantRow>(find.byKey(const ValueKey('participante-1')));

    testWidgets('o rascunho mostra o cronômetro, contando desde a primeira abertura',
        (tester) async {
      final start = DateTime.now().subtract(const Duration(minutes: 12, seconds: 41));

      await show(
        tester,
        withParticipants: [minha()],
        withLocal: [local('1', LocalSyncStatus.draft, startTime: start)],
      );

      expect(find.text('Avaliando · você'), findsOneWidget);
      expect(find.textContaining('00:12:4'), findsOneWidget);
      expect(row(tester).onTap, isNotNull, reason: 'o rascunho abre o checklist');
    });

    testWidgets(
        'na fila: chip "Na fila", o % e "aguardando envio" — e a linha não '
        'abre mais o checklist', (tester) async {
      await show(
        tester,
        withParticipants: [minha()],
        withLocal: [local('1', LocalSyncStatus.pendingSync, score: 86.6667)],
      );

      expect(find.text('Na fila'), findsOneWidget);
      expect(find.text('86,7% · aguardando envio'), findsOneWidget);
      expect(find.text('Avaliando · você'), findsNothing);
      expect(row(tester).onTap, isNull);
    });

    testWidgets('com erro no envio: chip "Erro no envio" e quando falhou',
        (tester) async {
      final now = DateTime.now();

      await show(
        tester,
        withParticipants: [minha()],
        withLocal: [
          local(
            '1',
            LocalSyncStatus.error,
            score: 62,
            lastAttemptAt: DateTime(now.year, now.month, now.day, 7, 58),
          ),
        ],
      );

      expect(find.text('Erro no envio'), findsOneWidget);
      expect(find.text('62,0% · falhou às 07:58'), findsOneWidget);
      expect(row(tester).onTap, isNull);
    });
  });

  group('navegação pelas rotas reais', () {
```

Em `test/ui/sessions/sessions_screen_test.dart`:

Substituir (1 de 7):

```dart
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
```

por:

```dart
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
```

Substituir (2 de 7):

```dart
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/router.dart';
```

por:

```dart
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
```

Substituir (3 de 7):

```dart
class _MockParticipantRepository extends Mock implements ParticipantRepository {}
```

por:

```dart
class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockAssessmentRepository extends Mock implements AssessmentRepository {}
```

Substituir (4 de 7):

```dart
    final participants = _MockParticipantRepository();
    when(() => auth.isAuthenticated).thenReturn(true);
```

por:

```dart
    final participants = _MockParticipantRepository();
    final assessments = _MockAssessmentRepository();
    when(() => auth.isAuthenticated).thenReturn(true);
```

Substituir (5 de 7):

```dart
        .thenAnswer((_) async => const Success(0));
```

por:

```dart
        .thenAnswer((_) async => const Success(0));
    when(() => assessments.watchSessionAssessments('sess-1', 'u1'))
        .thenAnswer((_) => Stream.value(const <LocalAssessment>[]));
```

Substituir (6 de 7):

```dart
          Provider<ParticipantRepository>.value(value: participants),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
```

por:

```dart
          Provider<ParticipantRepository>.value(value: participants),
          Provider<AssessmentRepository>.value(value: assessments),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
```

Substituir (7 de 7):

```dart
  });
}
```

por:

```dart
  });

}
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/ui/core/ test/ui/session_detail/ test/ui/sessions/sessions_screen_test.dart`
Esperado: `date_labels_test`, `display_widgets_test`, `participant_filter_test` e `session_detail_viewmodel_test` não compilam (`Method not found: 'clockLabel'`, `'ElapsedClock'`, `'localProgressOf'`, `No named parameter with the name 'assessmentRepository'`); no `session_detail_screen_test.dart`, falham os 3 testes do grupo "avaliação deste aparelho na linha 'comigo'" (nem cronômetro, nem chip "Na fila"/"Erro no envio"). O `sessions_screen_test.dart` passa: o ajuste nele só prepara o toque no card para o detalhe que, nesta task, passa a pedir o `AssessmentRepository`.

- [ ] **Step 3: Rótulos de tempo e o cronômetro**

Em `lib/ui/core/date_labels.dart`:

Substituir:

```dart

/// Texto da faixa de offline: sem conexão, o consultor precisa saber a idade
```

por:

```dart

bool _isToday(DateTime moment, DateTime now) {
  final local = moment.toLocal();
  return local.year == now.year && local.month == now.month && local.day == now.day;
}

/// "08:41" se foi hoje; nos outros dias, como [momentLabel] ("28 set 08:41")
/// — a hora do "Confirmar" na fila de envio.
String clockLabel(DateTime moment, DateTime now) {
  final local = moment.toLocal();
  if (_isToday(moment, now)) return '${_dois(local.hour)}:${_dois(local.minute)}';
  return momentLabel(moment, now);
}

/// "às 07:58" se foi hoje; "em 28 set 07:58" nos outros dias — o "falhou
/// às 07:58" de um envio que não passou.
String atLabel(DateTime moment, DateTime now) {
  final clock = clockLabel(moment, now);
  return _isToday(moment, now) ? 'às $clock' : 'em $clock';
}

/// "00:12:41" — o cronômetro da avaliação. Um intervalo negativo (o relógio
/// do aparelho voltou) vale zero.
String stopwatchLabel(Duration elapsed) {
  final total = elapsed.isNegative ? Duration.zero : elapsed;
  final hours = _dois(total.inHours);
  final minutes = _dois(total.inMinutes % 60);
  final seconds = _dois(total.inSeconds % 60);
  return '$hours:$minutes:$seconds';
}

/// Texto da faixa de offline: sem conexão, o consultor precisa saber a idade
```

Criar `lib/ui/core/widgets/elapsed_clock.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../date_labels.dart';

/// "00:12:41" que avança sozinho desde [start] — o cronômetro do rascunho na
/// linha "Avaliando · você" do detalhe da sessão (canvas "1e").
///
/// O tick redesenha só este texto, não a tela inteira.
class ElapsedClock extends StatefulWidget {
  const ElapsedClock({
    super.key,
    required this.start,
    this.clock,
    this.tickInterval = const Duration(seconds: 1),
    this.style,
  });

  final DateTime start;

  /// Relógio injetável para os testes; o padrão é `DateTime.now`.
  final DateTime Function()? clock;
  final Duration tickInterval;
  final TextStyle? style;

  @override
  State<ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<ElapsedClock> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(widget.tickInterval, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = (widget.clock ?? DateTime.now)();
    return Text(stopwatchLabel(now.difference(widget.start)), style: widget.style);
  }
}
```

Em `lib/ui/core/theme/app_icons.dart`:

Substituir:

```dart
  static const IconData finish = Icons.task_alt;
}
```

por:

```dart
  static const IconData finish = Icons.task_alt;

  /// Fila de envio (Fase 5A): o último envio falhou ("error" no canvas "2h").
  static const IconData sendFailed = Icons.error_outline;
}
```

Em `lib/ui/checklist/checklist_viewmodel.dart`:

Substituir (1 de 3):

```dart
import '../../data/services/local/app_database.dart';
import 'checklist_sections.dart';
```

por:

```dart
import '../../data/services/local/app_database.dart';
import '../core/date_labels.dart';
import 'checklist_sections.dart';
```

Substituir (2 de 3):

```dart
    if (start == null) return '00:00:00';
    return _formatElapsed(_now().difference(start));
  }
```

por:

```dart
    if (start == null) return '00:00:00';
    return stopwatchLabel(_now().difference(start));
  }
```

Substituir (3 de 3):

```dart
}

String _formatElapsed(Duration elapsed) {
  final total = elapsed.isNegative ? Duration.zero : elapsed;
  final hours = total.inHours.toString().padLeft(2, '0');
  final minutes = (total.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (total.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
```

por:

```dart
}
```

- [ ] **Step 4: As regras da linha, a ViewModel e a tela**

Em `lib/ui/session_detail/participant_filter.dart`:

Substituir (1 de 2):

```dart
import '../../data/models/session_participant.dart';
import '../core/date_labels.dart';
```

por:

```dart
import '../../data/models/session_participant.dart';
import '../../data/services/local/app_database.dart';
import '../core/date_labels.dart';
import '../core/score_labels.dart';
```

Substituir (2 de 2):

```dart
  return momentLabel(participant.assessedAt!, now);
}
```

por:

```dart
  return momentLabel(participant.assessedAt!, now);
}

/// Onde está a avaliação deste aparelho numa linha "comigo" (Fase 5A).
enum LocalProgress {
  /// Rascunho aberto: a linha mostra o cronômetro.
  draft,

  /// Confirmada, esperando o envio: chip "Na fila".
  queued,

  /// O último envio falhou: chip "Erro no envio".
  failed,
}

/// Só vale para a linha "comigo" — depois do envio, quem manda é o status
/// que o servidor devolve (Aprovado/Reavaliar), e uma avaliação já enviada
/// não muda nada na linha.
LocalProgress? localProgressOf(
  ParticipantSituation situation,
  LocalAssessment? local,
) {
  if (situation != ParticipantSituation.mine || local == null) return null;
  return switch (local.syncStatus) {
    LocalSyncStatus.draft => LocalProgress.draft,
    LocalSyncStatus.pendingSync => LocalProgress.queued,
    LocalSyncStatus.error => LocalProgress.failed,
    LocalSyncStatus.synced => null,
  };
}

/// "86,7% · aguardando envio" ou "62,0% · falhou às 07:58", da linha na fila.
/// As avaliações de antes da Fase 5A não guardaram o %: vai só o texto.
String queueMetaFor(LocalAssessment local, DateTime now) {
  final lastAttempt = local.lastAttemptAt;
  final status = local.syncStatus == LocalSyncStatus.error && lastAttempt != null
      ? 'falhou ${atLabel(lastAttempt, now)}'
      : 'aguardando envio';
  final score = local.score;
  return score == null ? status : '${percentLabel(score)} · $status';
}
```

Em `lib/ui/session_detail/participant_row.dart`:

Substituir (1 de 3):

```dart
    this.meta,
    this.blockedNote,
```

por:

```dart
    this.meta,
    this.liveMeta,
    this.blockedNote,
```

Substituir (2 de 3):

```dart

  /// "hoje 08:12" dos concluídos.
  final String? meta;
```

por:

```dart

  /// "hoje 08:12" dos concluídos, "86,7% · aguardando envio" de quem está na
  /// fila.
  final String? meta;

  /// Meta que se atualiza sozinho, no lugar de [meta] — o cronômetro do
  /// rascunho ("00:12:41").
  final Widget? liveMeta;
```

Substituir (3 de 3):

```dart
          Text(meta!, style: AppTypography.meta),
        ],
```

por:

```dart
          Text(meta!, style: AppTypography.meta),
        ] else if (liveMeta != null) ...[
          const SizedBox(height: AppSpacing.xs),
          liveMeta!,
        ],
```

Em `lib/ui/session_detail/session_detail_viewmodel.dart`:

Substituir (1 de 11):

```dart
import '../../data/models/training_session.dart';
import '../../data/repositories/participant_repository.dart';
```

por:

```dart
import '../../data/models/training_session.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
```

Substituir (2 de 11):

```dart
import '../../data/services/connectivity_service.dart';
import '../../utils/result.dart';
```

por:

```dart
import '../../data/services/connectivity_service.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/result.dart';
```

Substituir (3 de 11):

```dart
/// só com a sessão em andamento; o resultado abre sempre.
class SessionDetailViewModel extends ChangeNotifier {
```

por:

```dart
/// só com a sessão em andamento; o resultado abre sempre.
///
/// As avaliações deste aparelho (Fase 5A) vêm de outro stream: o rascunho
/// põe o cronômetro na linha, e a avaliação confirmada troca o chip por
/// "Na fila"/"Erro no envio" até o servidor responder.
class SessionDetailViewModel extends ChangeNotifier {
```

Substituir (4 de 11):

```dart
    required ParticipantRepository participantRepository,
    required ConnectivityService connectivity,
```

por:

```dart
    required ParticipantRepository participantRepository,
    required AssessmentRepository assessmentRepository,
    required ConnectivityService connectivity,
```

Substituir (5 de 11):

```dart
        _participantRepository = participantRepository,
        _connectivity = connectivity,
```

por:

```dart
        _participantRepository = participantRepository,
        _assessmentRepository = assessmentRepository,
        _connectivity = connectivity,
```

Substituir (6 de 11):

```dart
  final ParticipantRepository _participantRepository;
  final ConnectivityService _connectivity;
```

por:

```dart
  final ParticipantRepository _participantRepository;
  final AssessmentRepository _assessmentRepository;
  final ConnectivityService _connectivity;
```

Substituir (7 de 11):

```dart
  StreamSubscription<List<SessionParticipant>>? _participantsSubscription;
  StreamSubscription<void>? _reconnectSubscription;
```

por:

```dart
  StreamSubscription<List<SessionParticipant>>? _participantsSubscription;
  StreamSubscription<List<LocalAssessment>>? _localSubscription;
  StreamSubscription<void>? _reconnectSubscription;
```

Substituir (8 de 11):

```dart
  List<SessionParticipant> _participants = const [];
  bool _sessionLoaded = false;
```

por:

```dart
  List<SessionParticipant> _participants = const [];
  Map<String, LocalAssessment> _local = const {};
  bool _sessionLoaded = false;
```

Substituir (9 de 11):

```dart

  bool opensChecklist(SessionParticipant participant) =>
      evaluationOpen && situationFor(participant) == ParticipantSituation.mine;
```

por:

```dart

  /// A avaliação deste aparelho para o participante — só as do consultor
  /// logado.
  LocalAssessment? localAssessmentFor(String participantId) =>
      _local[participantId];

  /// Rascunho, na fila ou com erro de envio — só nas linhas "comigo".
  LocalProgress? localProgressFor(SessionParticipant participant) =>
      localProgressOf(situationFor(participant), _local[participant.id]);

  /// Uma avaliação confirmada espera o envio e não é mais editada (decisão
  /// de 29/09/2026): na fila ou com erro, a linha não abre o checklist.
  bool opensChecklist(SessionParticipant participant) {
    if (!evaluationOpen) return false;
    if (situationFor(participant) != ParticipantSituation.mine) return false;
    final progress = localProgressFor(participant);
    return progress != LocalProgress.queued && progress != LocalProgress.failed;
  }
```

Substituir (10 de 11):

```dart
      notifyListeners();
    });

    _reconnectSubscription ??=
```

por:

```dart
      notifyListeners();
    });

    final ownerUserId = _currentUser?.id;
    if (ownerUserId != null) {
      _localSubscription ??= _assessmentRepository
          .watchSessionAssessments(sessionId, ownerUserId)
          .listen((rows) {
        _local = {for (final row in rows) row.trainingParticipantId: row};
        notifyListeners();
      });
    }

    _reconnectSubscription ??=
```

Substituir (11 de 11):

```dart
    _participantsSubscription?.cancel();
    _reconnectSubscription?.cancel();
```

por:

```dart
    _participantsSubscription?.cancel();
    _localSubscription?.cancel();
    _reconnectSubscription?.cancel();
```

Em `lib/ui/session_detail/session_detail_screen.dart`:

Substituir (1 de 7):

```dart
import '../../data/models/training_session.dart';
import '../../data/repositories/auth_repository.dart';
```

por:

```dart
import '../../data/models/training_session.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
```

Substituir (2 de 7):

```dart
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/filter_chip_bar.dart';
```

por:

```dart
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/elapsed_clock.dart';
import '../core/widgets/filter_chip_bar.dart';
```

Substituir (3 de 7):

```dart
    participantRepository: context.read<ParticipantRepository>(),
    connectivity: context.read<ConnectivityService>(),
```

por:

```dart
    participantRepository: context.read<ParticipantRepository>(),
    assessmentRepository: context.read<AssessmentRepository>(),
    connectivity: context.read<ConnectivityService>(),
```

Substituir (4 de 7):

```dart
    final situation = _viewModel.situationFor(participant);
```

por:

```dart
    final situation = _viewModel.situationFor(participant);
    final local = _viewModel.localAssessmentFor(participant.id);
    final progress = _viewModel.localProgressFor(participant);
    final inQueue =
        progress == LocalProgress.queued || progress == LocalProgress.failed;
```

Substituir (5 de 7):

```dart
      maskedCpf: participant.maskedCpf,
      chip: _buildSituationChip(participant, situation),
      meta: assessedAtLabelFor(participant, situation, _viewModel.now),
      blockedNote: blockedNoteFor(participant, situation),
```

por:

```dart
      maskedCpf: participant.maskedCpf,
      chip: inQueue
          ? _buildQueueChip(progress!)
          : _buildSituationChip(participant, situation),
      meta: inQueue
          ? queueMetaFor(local!, _viewModel.now)
          : assessedAtLabelFor(participant, situation, _viewModel.now),
      // O cronômetro do rascunho, como no canvas "1e" — conta desde a
      // primeira abertura do checklist (relógio corrido, decisão de
      // 29/09/2026).
      liveMeta: progress == LocalProgress.draft
          ? ElapsedClock(
              start: local!.startTime,
              clock: () => _viewModel.now,
              style: AppTypography.meta,
            )
          : null,
      blockedNote: blockedNoteFor(participant, situation),
```

Substituir (6 de 7):

```dart
  /// Para onde a linha leva: o checklist (Fase 4) ou o resultado — este ainda
  /// é uma tela provisória, até a Fase 5. O checklist lê o nome do banco, por
  /// isso não recebe `extra`.
  VoidCallback? _tapActionFor(SessionParticipant participant) {
```

por:

```dart
  /// Para onde a linha leva: o checklist (Fase 4) ou o resultado — este ainda
  /// é uma tela provisória, até a Fase 5B. O checklist lê o nome do banco, por
  /// isso não recebe `extra`. Na fila, a linha não leva a lugar nenhum.
  VoidCallback? _tapActionFor(SessionParticipant participant) {
```

Substituir (7 de 7):

```dart

  Widget _buildSkeleton() {
```

por:

```dart

  /// Confirmada e esperando o servidor (decisão de 29/09/2026): a mesma
  /// pílula "Na fila" da aba Sincronizar, ou "Erro no envio" se o último
  /// envio falhou. O canvas não tem este estado.
  Widget _buildQueueChip(LocalProgress progress) {
    return progress == LocalProgress.failed
        ? const StatusChip(
            label: 'Erro no envio',
            icon: AppIcons.sendFailed,
            tone: StatusTone.danger,
          )
        : const StatusChip(
            label: 'Na fila',
            icon: AppIcons.pending,
            tone: StatusTone.neutral,
          );
  }

  Widget _buildSkeleton() {
```

- [ ] **Step 5: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **348 testes passando**.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/core/date_labels.dart lib/ui/core/widgets/elapsed_clock.dart lib/ui/core/theme/app_icons.dart lib/ui/checklist/checklist_viewmodel.dart lib/ui/session_detail/participant_filter.dart lib/ui/session_detail/participant_row.dart lib/ui/session_detail/session_detail_viewmodel.dart lib/ui/session_detail/session_detail_screen.dart test/ui/core/date_labels_test.dart test/ui/core/widgets/display_widgets_test.dart test/ui/session_detail/participant_filter_test.dart test/ui/session_detail/session_detail_viewmodel_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): chip na fila e cronometro na linha do participante"
```

---

## Task 6: O badge da fila no indicador do cabeçalho e na navbar

Um lugar só para a Home e o detalhe (decisão de 27/09/2026): o `SyncStatusIndicator` lê o serviço e a conexão. O badge segue o canvas `2c`: 16dp, laranja `warningInkStrong`, borda branca de 2, número 9/700. Os testes de tela usam um serviço falso compartilhado em `test/support/` (não é arquivo de teste: o `flutter test` só roda `*_test.dart`).

**Files:**
- Modify: `lib/ui/core/theme/app_typography.dart` — `headerBadge`
- Modify (reescrita): `lib/ui/core/widgets/sync_status_indicator.dart`
- Modify: `lib/ui/sessions/sessions_screen.dart` — badge na aba "Sincronizar"
- Create: `test/support/fake_assessment_sync_service.dart`
- Create: `test/ui/core/widgets/sync_status_indicator_test.dart`
- Test: `test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: `AssessmentSyncService.queue` (Task 3); `ConnectivityService.isOffline`.
- Produces:
  - `SyncStatusIndicator()` — sem fila: `syncDone` cinza; com fila: badge com a contagem sobre `offline` (sem rede) ou `sync` (com rede), em `warningInk`.
  - `AppTypography.headerBadge`.
  - Para os testes: `FakeAssessmentSyncService({List<LocalAssessment> queue, Set<String> sendingIds, DateTime? lastSyncedAt})` com `setQueue(…)` e `syncNowCalls`; `LocalAssessment queuedAssessment(String participantId, {…})`.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/support/fake_assessment_sync_service.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';

class _UnusedApiClient extends Mock implements ApiClient {}

class _UnusedAssessmentRepository extends Mock implements AssessmentRepository {}

class _UnusedParticipantRepository extends Mock implements ParticipantRepository {}

/// `AssessmentSyncService` para testes de tela: o teste define a fila, o
/// envio no ar e a última sincronização, e nada é enviado de verdade. Nunca é
/// iniciado (`start`), então não segue usuário, fila nem conexão.
class FakeAssessmentSyncService extends AssessmentSyncService {
  FakeAssessmentSyncService({
    List<LocalAssessment> queue = const [],
    Set<String> sendingIds = const {},
    DateTime? lastSyncedAt,
  })  : _queue = queue,
        _sendingIds = sendingIds,
        _lastSyncedAt = lastSyncedAt,
        super(
          apiClient: _UnusedApiClient(),
          assessments: _UnusedAssessmentRepository(),
          participants: _UnusedParticipantRepository(),
          connectivity: ConnectivityService(),
          authChanges: ValueNotifier<String?>(null),
          currentUserId: () => null,
        );

  List<LocalAssessment> _queue;
  Set<String> _sendingIds;
  final DateTime? _lastSyncedAt;

  /// Quantas vezes a tela pediu para enviar agora.
  int syncNowCalls = 0;

  @override
  List<LocalAssessment> get queue => _queue;

  @override
  bool get isSending => _sendingIds.isNotEmpty;

  @override
  bool isSendingItem(String localAssessmentId) =>
      _sendingIds.contains(localAssessmentId);

  @override
  DateTime? get lastSyncedAt => _lastSyncedAt;

  @override
  Future<void> syncNow() async => syncNowCalls++;

  /// Troca a fila e avisa a tela, como o stream do banco faria.
  void setQueue(List<LocalAssessment> queue, {Set<String> sendingIds = const {}}) {
    _queue = queue;
    _sendingIds = sendingIds;
    notifyListeners();
  }
}

/// Uma avaliação da fila, do jeito que o `AssessmentRepository` guarda.
LocalAssessment queuedAssessment(
  String participantId, {
  LocalSyncStatus status = LocalSyncStatus.pendingSync,
  String? participantName,
  double? score,
  DateTime? endTime,
  DateTime? lastAttemptAt,
  String? lastError,
}) {
  final at = endTime ?? DateTime.now();
  return LocalAssessment(
    id: 'local-$participantId',
    trainingParticipantId: participantId,
    sessionId: 'sess-1',
    date: at,
    startTime: at.subtract(const Duration(minutes: 14)),
    endTime: at,
    syncStatus: status,
    attemptCount: 0,
    createdAt: at,
    updatedAt: at,
    ownerUserId: 'u1',
    participantName: participantName,
    score: score,
    lastAttemptAt: lastAttemptAt,
    lastError: lastError,
  );
}
```

Criar `test/ui/core/widgets/sync_status_indicator_test.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/sync_status_indicator.dart';

import '../../../support/fake_assessment_sync_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late ConnectivityService connectivity;

  setUp(() => connectivity = ConnectivityService());
  tearDown(() => connectivity.dispose());

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

  Future<void> pump(WidgetTester tester, FakeAssessmentSyncService sync) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AssessmentSyncService>.value(value: sync),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SyncStatusIndicator()),
        ),
      ),
    );
  }

  testWidgets('fila vazia: a nuvem com check, sem badge', (tester) async {
    await pump(tester, FakeAssessmentSyncService());

    expect(find.byIcon(AppIcons.syncDone), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('com fila e rede: a nuvem de sincronização com a contagem',
      (tester) async {
    await pump(
      tester,
      FakeAssessmentSyncService(
        queue: [queuedAssessment('1'), queuedAssessment('2')],
      ),
    );

    expect(find.byIcon(AppIcons.sync), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('com fila e sem rede: a nuvem riscada, como no canvas',
      (tester) async {
    await goOffline();

    await pump(
      tester,
      FakeAssessmentSyncService(queue: [queuedAssessment('1')]),
    );

    expect(find.byIcon(AppIcons.offline), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('a contagem acompanha a fila', (tester) async {
    final sync = FakeAssessmentSyncService(queue: [queuedAssessment('1')]);
    await pump(tester, sync);

    sync.setQueue(const []);
    await tester.pump();

    expect(find.text('1'), findsNothing);
    expect(find.byIcon(AppIcons.syncDone), findsOneWidget);
  });
}
```

Em `test/ui/sessions/sessions_screen_test.dart`:

Substituir (1 de 5):

```dart
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
```

por:

```dart
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
```

Substituir (2 de 5):

```dart
import 'package:simtc/utils/result.dart';
```

por:

```dart
import 'package:simtc/utils/result.dart';

import '../../support/fake_assessment_sync_service.dart';
```

Substituir (3 de 5):

```dart

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
```

por:

```dart

  Future<void> pump(WidgetTester tester, {AssessmentSyncService? sync}) {
    return tester.pumpWidget(
```

Substituir (4 de 5):

```dart
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: const MaterialApp(home: SessionsScreen()),
```

por:

```dart
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
          if (sync != null)
            ChangeNotifierProvider<AssessmentSyncService>.value(value: sync),
        ],
        child: const MaterialApp(home: SessionsScreen()),
```

Substituir (5 de 5):

```dart
      tester.widget<Text>(find.byKey(const Key('sessions-title'))).data!;
```

por:

```dart
      tester.widget<Text>(find.byKey(const Key('sessions-title'))).data!;

  testWidgets(
      'a fila de envio aparece no badge da aba Sincronizar e no indicador do '
      'cabeçalho', (tester) async {
    await pump(
      tester,
      sync: FakeAssessmentSyncService(
        queue: [queuedAssessment('1'), queuedAssessment('2'), queuedAssessment('3')],
      ),
    );
    sessions.add([hoje()]);
    await tester.pump();

    expect(find.text('3'), findsNWidgets(2), reason: 'navbar e cabeçalho');
  });
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/ui/core/widgets/sync_status_indicator_test.dart test/ui/sessions/sessions_screen_test.dart`
Esperado: 3 falhas — no `sync_status_indicator_test.dart`, "com fila e rede…" e "com fila e sem rede…" (o indicador ainda não conhece a fila: `Found 0 widgets with icon …`); no `sessions_screen_test.dart`, "a fila de envio aparece no badge…" (`Expected: exactly 2 matching candidates`). "fila vazia…" e "a contagem acompanha a fila" já passam — fixam o estado de hoje, que continua.

- [ ] **Step 3: Implementar**

Em `lib/ui/core/theme/app_typography.dart`:

Substituir:

```dart

  /// Texto de botão principal
```

por:

```dart

  /// Número do badge da fila no indicador do cabeçalho (canvas "2c")
  static TextStyle get headerBadge =>
      _inter(size: 9, weight: FontWeight.w700, height: 1, color: AppColors.surface);

  /// Texto de botão principal
```

Reescrever `lib/ui/core/widgets/sync_status_indicator.dart` inteiro:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/assessment_sync_service.dart';
import '../../../data/services/connectivity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Indicador da fila de envio, no canto do cabeçalho da Home e do detalhe da
/// sessão — um lugar só para as duas telas (decisão de 27/09/2026):
/// - fila vazia: a nuvem com check, cinza;
/// - com avaliações na fila: o badge laranja com a contagem, sobre a nuvem
///   riscada sem rede (canvas "2c" e "1e") ou a de sincronização com rede.
///
/// Lê o `AssessmentSyncService` e o `ConnectivityService` do app. Sem eles
/// (a galeria do DS, testes de outros widgets), mostra a fila vazia.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<AssessmentSyncService?>()?.queue.length ?? 0;
    final isOffline = context.watch<ConnectivityService?>()?.isOffline ?? false;

    if (count == 0) {
      return const SizedBox(
        width: AppSpacing.touchTarget,
        height: AppSpacing.touchTarget,
        child: Icon(AppIcons.syncDone, color: AppColors.text3),
      );
    }

    return Semantics(
      label: count == 1 ? '1 avaliação na fila' : '$count avaliações na fila',
      child: SizedBox(
        width: AppSpacing.touchTarget,
        height: AppSpacing.touchTarget,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              isOffline ? AppIcons.offline : AppIcons.sync,
              color: AppColors.warningInk,
            ),
            Positioned(
              top: AppSpacing.xs + 2,
              right: AppSpacing.xs + 1,
              child: _CountBadge(count),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs + 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.warningInkStrong,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: Text('$count', style: AppTypography.headerBadge),
    );
  }
}
```

Em `lib/ui/sessions/sessions_screen.dart`:

Substituir (1 de 2):

```dart
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
```

por:

```dart
import '../../data/repositories/session_repository.dart';
import '../../data/services/assessment_sync_service.dart';
import '../../data/services/connectivity_service.dart';
```

Substituir (2 de 2):

```dart
  Widget _buildNavBar(BuildContext context) {
    return PillNavBar(
      currentIndex: 0,
      items: const [
        PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
        PillNavItem(icon: AppIcons.sync, label: 'Sincronizar'),
        PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
      ],
```

por:

```dart
  Widget _buildNavBar(BuildContext context) {
    // O mesmo número do indicador do cabeçalho: a fila de envio.
    final queued = context.watch<AssessmentSyncService?>()?.queue.length ?? 0;

    return PillNavBar(
      currentIndex: 0,
      items: [
        const PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
        PillNavItem(icon: AppIcons.sync, label: 'Sincronizar', badgeCount: queued),
        const PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
      ],
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **353 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/core/theme/app_typography.dart lib/ui/core/widgets/sync_status_indicator.dart lib/ui/sessions/sessions_screen.dart test/support/fake_assessment_sync_service.dart test/ui/core/widgets/sync_status_indicator_test.dart test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): badge da fila no indicador e na navbar"
```

---

## Task 7: A aba "Sincronizar" (1.9)

A tela não tem ViewModel própria: o estado é todo do `AssessmentSyncService`, que o app inteiro compartilha, e as regras de texto ficam puras em `sync_queue_labels.dart`. É uma aba, não uma tela empilhada: entra com `context.go('/sync')`, a navbar leva de volta a Sessões e o voltar do Android também (`PopScope`).

**Files:**
- Create: `lib/ui/sync/sync_queue_labels.dart`
- Create: `lib/ui/sync/sync_screen.dart`
- Modify: `lib/router.dart` — rota `/sync`
- Modify: `lib/ui/core/theme/app_typography.dart` — `screenSubtitle`, `queueNoticeTitle`
- Modify: `lib/ui/core/theme/app_icons.dart` — `retry`
- Modify: `lib/ui/core/widgets/sync_status_indicator.dart` — `onTap`
- Modify: `lib/ui/sessions/sessions_screen.dart` — a aba e o indicador levam a `/sync`
- Modify: `lib/ui/session_detail/session_detail_screen.dart` — o indicador leva a `/sync`
- Create: `test/ui/sync/sync_queue_labels_test.dart`, `test/ui/sync/sync_screen_test.dart`
- Test: `test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: `AssessmentSyncService` (`queue`, `isSending`, `isSendingItem`, `lastSyncedAt`, `syncNow`); `clockLabel`, `atLabel`, `momentLabel`, `percentLabel`; `FakeAssessmentSyncService` (Task 6).
- Produces:
  - `enum QueueItemState { queued, sending, failed }`; `queueItemStateOf(item, {required bool sending})`; `queueItemTitle(item)`; `queueItemMeta(item, state, now)`; `queueCountLabel(count)`; `lastSyncLabel(at, now)`.
  - `SyncScreen({DateTime Function()? clock})`; `AppRoutes.sync = '/sync'`.
  - `SyncStatusIndicator({VoidCallback? onTap})`; `AppIcons.retry`.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/sync/sync_queue_labels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/sync/sync_queue_labels.dart';

import '../../support/fake_assessment_sync_service.dart';

void main() {
  final agora = DateTime(2026, 9, 29, 9);

  test('o estado do item: o envio no ar vence; senão, erro ou na fila', () {
    final queued = queuedAssessment('1');
    final failed = queuedAssessment('2', status: LocalSyncStatus.error);

    expect(queueItemStateOf(queued, sending: false), QueueItemState.queued);
    expect(queueItemStateOf(failed, sending: false), QueueItemState.failed);
    expect(queueItemStateOf(failed, sending: true), QueueItemState.sending);
  });

  test('o título é o nome guardado, ou "Participante" sem ele', () {
    expect(queueItemTitle(queuedAssessment('1', participantName: 'Ana Paula Ribeiro')),
        'Ana Paula Ribeiro');
    expect(queueItemTitle(queuedAssessment('2')), 'Participante');
    expect(queueItemTitle(queuedAssessment('3', participantName: '  ')), 'Participante');
  });

  test('na fila: o tipo, o % e a hora do Confirmar', () {
    expect(
      queueItemMeta(
        queuedAssessment('1', score: 86.6667, endTime: DateTime(2026, 9, 29, 8, 41)),
        QueueItemState.queued,
        agora,
      ),
      'Avaliação prática · 86,7% · 08:41',
    );
    expect(
      queueItemMeta(
        queuedAssessment('2', endTime: DateTime(2026, 9, 28, 17, 2)),
        QueueItemState.queued,
        agora,
      ),
      'Avaliação prática · 28 set 17:02',
      reason: 'sem % (Fase 4) e confirmada ontem',
    );
  });

  test('com erro: quando falhou e por quê', () {
    expect(
      queueItemMeta(
        queuedAssessment(
          '1',
          status: LocalSyncStatus.error,
          lastAttemptAt: DateTime(2026, 9, 29, 7, 58),
          lastError: 'tempo esgotado',
        ),
        QueueItemState.failed,
        agora,
      ),
      'Falhou às 07:58 · tempo esgotado',
    );
  });

  test('a contagem do cartão e a última sincronização', () {
    expect(queueCountLabel(1), '1 avaliação na fila');
    expect(queueCountLabel(3), '3 avaliações na fila');
    expect(lastSyncLabel(DateTime(2026, 9, 29, 7, 12), agora),
        'Última sincronização hoje 07:12');
    expect(lastSyncLabel(null, agora), 'Nenhuma avaliação enviada ainda');
  });
}
```

Criar `test/ui/sync/sync_screen_test.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/sync/sync_screen.dart';

import '../../support/fake_assessment_sync_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late ConnectivityService connectivity;
  late FakeAssessmentSyncService sync;
  final agora = DateTime(2026, 9, 29, 9);

  setUp(() => connectivity = ConnectivityService());
  tearDown(() => connectivity.dispose());

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

  /// A aba aberta pela rota real, com a Home atrás dela no go_router.
  Future<void> pump(
    WidgetTester tester, {
    List<LocalAssessment> queue = const [],
    Set<String> sendingIds = const {},
    DateTime? lastSyncedAt,
  }) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    sync = FakeAssessmentSyncService(
      queue: queue,
      sendingIds: sendingIds,
      lastSyncedAt: lastSyncedAt,
    );
    final router = GoRouter(
      initialLocation: AppRoutes.sync,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: AppRoutes.sync,
          builder: (context, state) => SyncScreen(clock: () => agora),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AssessmentSyncService>.value(value: sync),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  List<LocalAssessment> filaDoCanvas() => [
        queuedAssessment(
          '1',
          participantName: 'Ana Paula Ribeiro',
          score: 86.6667,
          endTime: DateTime(2026, 9, 29, 8, 41),
        ),
        queuedAssessment(
          '2',
          participantName: 'Rodrigo Tavares',
          status: LocalSyncStatus.error,
          lastAttemptAt: DateTime(2026, 9, 29, 7, 58),
          lastError: 'tempo esgotado',
        ),
      ];

  AppCtaButton syncNowButton(WidgetTester tester) =>
      tester.widget<AppCtaButton>(find.byType(AppCtaButton));

  testWidgets(
      'com rede: a última sincronização, cada pendente com a sua pílula e '
      '"Sincronizar agora" habilitado', (tester) async {
    await pump(
      tester,
      queue: filaDoCanvas(),
      lastSyncedAt: DateTime(2026, 9, 29, 7, 12),
    );

    expect(find.text('Última sincronização hoje 07:12'), findsOneWidget);
    expect(find.text('Pendentes'), findsOneWidget);
    expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
    expect(find.text('Avaliação prática · 86,7% · 08:41'), findsOneWidget);
    expect(find.text('Na fila'), findsOneWidget);
    expect(find.text('Rodrigo Tavares'), findsOneWidget);
    expect(find.text('Falhou às 07:58 · tempo esgotado'), findsOneWidget);
    expect(find.text('Erro'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.byKey(const Key('sync-offline-card')), findsNothing);
    expect(syncNowButton(tester).onPressed, isNotNull);
    expect(find.text('Disponível quando houver conexão'), findsNothing);
  });

  testWidgets('durante o envio: pílula "Enviando" e o botão ocupado',
      (tester) async {
    await pump(
      tester,
      queue: [queuedAssessment('1', participantName: 'Ana Paula Ribeiro')],
      sendingIds: {'local-1'},
    );

    expect(find.text('Enviando'), findsOneWidget);
    expect(find.text('Na fila'), findsNothing);
    expect(syncNowButton(tester).isLoading, isTrue);
  });

  testWidgets(
      'sem rede: o cartão âmbar com a contagem, e "Sincronizar agora" '
      'desabilitado com a explicação', (tester) async {
    await goOffline();

    await pump(tester, queue: filaDoCanvas());

    expect(find.byKey(const Key('sync-offline-card')), findsOneWidget);
    expect(find.text('2 avaliações na fila'), findsOneWidget);
    expect(
      find.text('Sem conexão agora. Nada é perdido: a fila sobe sozinha quando '
          'o sinal voltar.'),
      findsOneWidget,
    );
    expect(syncNowButton(tester).onPressed, isNull);
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    final retry = tester.widget<OutlinedButton>(
      find.ancestor(of: find.text('Tentar novamente'), matching: find.byType(OutlinedButton)),
    );
    expect(retry.onPressed, isNull);
  });

  testWidgets('"Sincronizar agora" e "Tentar novamente" pedem o envio',
      (tester) async {
    await pump(tester, queue: filaDoCanvas());

    await tester.tap(find.text('Sincronizar agora'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(sync.syncNowCalls, 2);
  });

  testWidgets('fila vazia: tudo enviado, e nada a sincronizar', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('sync-empty')), findsOneWidget);
    expect(find.text('Nenhuma avaliação na fila'), findsOneWidget);
    expect(find.text('Tudo o que você confirmou já chegou ao servidor.'),
        findsOneWidget);
    expect(find.text('Nenhuma avaliação enviada ainda'), findsOneWidget);
    expect(find.text('Pendentes'), findsNothing);
    expect(syncNowButton(tester).onPressed, isNull);
  });

  testWidgets('a tela acompanha a fila sozinha', (tester) async {
    await pump(tester, queue: filaDoCanvas());

    sync.setQueue(const []);
    await tester.pump();

    expect(find.byKey(const Key('sync-empty')), findsOneWidget);
  });

  testWidgets('"Sessões" na navbar leva para a Home', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Sessões'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('o voltar do Android leva para a Home, em vez de fechar o app',
      (tester) async {
    await pump(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
```

Em `test/ui/sessions/sessions_screen_test.dart`:

Substituir (1 de 4):

```dart
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
import 'package:simtc/ui/sessions/sessions_screen.dart';
import 'package:simtc/utils/result.dart';
```

por:

```dart
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/core/widgets/sync_status_indicator.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
import 'package:simtc/ui/sessions/sessions_screen.dart';
import 'package:simtc/ui/sync/sync_screen.dart';
import 'package:simtc/utils/result.dart';
```

Substituir (2 de 4):

```dart
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('ver-mais-hojeOutras')),
        300,
        scrollable: scrollable,
      );
      await tester.tap(find.byKey(const ValueKey('ver-mais-hojeOutras')));
      await tester.pump();
    }

    // Quase pro topo (não exatamente 0) — os chips ficam sempre visíveis lá,
```

por:

```dart
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('ver-mais-hojeOutras')),
        300,
        scrollable: scrollable,
      );
      // `scrollUntilVisible` para com o botão só entrando pela borda de
      // baixo: o centro dele ficava atrás da navbar, e o toque caía em
      // "Sincronizar" (o aviso de hit-test da Fase 3). Com a aba navegando
      // de verdade (Fase 5A), esse toque errado quebra o teste.
      await tester.ensureVisible(find.byKey(const ValueKey('ver-mais-hojeOutras')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ver-mais-hojeOutras')));
      await tester.pump();
    }

    // Quase pro topo (não exatamente 0) — os chips ficam sempre visíveis lá,
```

Substituir (3 de 4):

```dart
      );
      await tester.tap(find.byKey(const ValueKey('ver-mais-hojeOutras')));
```

por:

```dart
      );
      // `scrollUntilVisible` para com o botão só entrando pela borda de
      // baixo: o centro dele ficava atrás da navbar, e o toque caía em
      // "Sincronizar" (o aviso de hit-test da Fase 3). Com a aba navegando
      // de verdade (Fase 5A), esse toque errado quebra o teste.
      await tester.ensureVisible(find.byKey(const ValueKey('ver-mais-hojeOutras')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ver-mais-hojeOutras')));
```

Substituir (4 de 4):

```dart

}
```

por:

```dart

  testWidgets(
      '"Sincronizar" na navbar e o indicador do cabeçalho abrem a aba, e '
      '"Sessões" volta', (tester) async {
    when(() => auth.isAuthenticated).thenReturn(true);
    final router = createRouter(auth, initialLocation: AppRoutes.home);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: repository),
          Provider<AssessmentCatalogRepository>.value(value: catalog),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
          ChangeNotifierProvider<AssessmentSyncService>.value(
            value: FakeAssessmentSyncService(queue: [queuedAssessment('1')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    sessions.add([hoje()]);
    await tester.pump();

    await tester.tap(find.text('Sincronizar'));
    await tester.pumpAndSettle();
    expect(find.byType(SyncScreen), findsOneWidget);

    // A Home volta com o skeleton animado até a lista chegar de novo: um
    // `pumpAndSettle` aqui não assentaria nunca.
    await tester.tap(find.text('Sessões'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SessionsScreen), findsOneWidget);
    sessions.add([hoje()]);
    await tester.pump();

    await tester.tap(find.byType(SyncStatusIndicator));
    await tester.pumpAndSettle();
    expect(find.byType(SyncScreen), findsOneWidget);
  });

  testWidgets('"Perfil" continua avisando que chega numa próxima versão',
      (tester) async {
    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    await tester.tap(find.text('Perfil'));
    await tester.pump();

    expect(find.text('Disponível em breve.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/ui/sync/ test/ui/sessions/sessions_screen_test.dart`
Esperado: falha de compilação — `sync_queue_labels_test.dart` e `sync_screen_test.dart` não acham `lib/ui/sync/…`, e `sessions_screen_test.dart` não acha o `SyncScreen`.

- [ ] **Step 3: Regras, tela e rota**

Criar `lib/ui/sync/sync_queue_labels.dart`:

```dart
import '../../data/services/local/app_database.dart';
import '../core/date_labels.dart';
import '../core/score_labels.dart';

/// Como um item da fila aparece na aba Sincronizar (canvas "2h").
enum QueueItemState {
  /// Confirmada, esperando o próximo envio: pílula "Na fila".
  queued,

  /// Faz parte do envio no ar: pílula "Enviando" (não está no canvas —
  /// aprovada em 29/09/2026).
  sending,

  /// O último envio falhou: pílula "Erro" e o botão "Tentar novamente".
  failed,
}

QueueItemState queueItemStateOf(LocalAssessment item, {required bool sending}) {
  if (sending) return QueueItemState.sending;
  return item.syncStatus == LocalSyncStatus.error
      ? QueueItemState.failed
      : QueueItemState.queued;
}

/// O nome do participante guardado no "Confirmar" — "Participante" nas
/// avaliações de antes da Fase 5A cujo nome não estava mais no cache.
String queueItemTitle(LocalAssessment item) {
  final name = item.participantName?.trim() ?? '';
  return name.isEmpty ? 'Participante' : name;
}

/// "Avaliação prática · 86,7% · 08:41" ou "Falhou às 07:58 · tempo
/// esgotado". Sem o "+ assinatura" do canvas: a assinatura saiu do app em
/// 20/09/2026.
String queueItemMeta(LocalAssessment item, QueueItemState state, DateTime now) {
  if (state == QueueItemState.failed) {
    final at = item.lastAttemptAt;
    final reason = item.lastError ?? '';
    return [
      at == null ? 'Falhou' : 'Falhou ${atLabel(at, now)}',
      if (reason.isNotEmpty) reason,
    ].join(' · ');
  }

  final score = item.score;
  final end = item.endTime;
  return [
    'Avaliação prática',
    if (score != null) percentLabel(score),
    if (end != null) clockLabel(end, now),
  ].join(' · ');
}

/// "3 avaliações na fila", do cartão âmbar sem rede.
String queueCountLabel(int count) =>
    count == 1 ? '1 avaliação na fila' : '$count avaliações na fila';

/// "Última sincronização hoje 07:12" — o último envio aceito.
String lastSyncLabel(DateTime? at, DateTime now) => at == null
    ? 'Nenhuma avaliação enviada ainda'
    : 'Última sincronização ${momentLabel(at, now)}';
```

Em `lib/ui/core/theme/app_typography.dart`:

Substituir:

```dart
      _inter(size: 22, weight: FontWeight.w700, height: 1.2, letterSpacing: -0.22);
```

por:

```dart
      _inter(size: 22, weight: FontWeight.w700, height: 1.2, letterSpacing: -0.22);

  /// Linha abaixo do título de uma aba ("Última sincronização hoje 07:12")
  static TextStyle get screenSubtitle =>
      _inter(size: 13, weight: FontWeight.w400, height: 1.2, color: AppColors.text3);

  /// Título do cartão âmbar da fila sem rede ("3 avaliações na fila")
  static TextStyle get queueNoticeTitle =>
      _inter(size: 16, weight: FontWeight.w600, height: 1.25, color: AppColors.noteCommentInk);
```

Em `lib/ui/core/theme/app_icons.dart`:

Substituir:

```dart
  static const IconData sendFailed = Icons.error_outline;
}
```

por:

```dart
  static const IconData sendFailed = Icons.error_outline;

  /// "Tentar novamente" de um item da fila (canvas "2h").
  static const IconData retry = Icons.refresh;
}
```

Criar `lib/ui/sync/sync_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/services/assessment_sync_service.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/local/app_database.dart';
import '../../router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/pill_nav_bar.dart';
import '../core/widgets/status_chip.dart';
import 'sync_queue_labels.dart';

/// Tela 1.9 — aba "Sincronizar" (quadro "2h" do canvas, Fase 5A).
///
/// Mostra a fila de envio do consultor logado. O envio é automático; os
/// botões "Sincronizar agora" e "Tentar novamente" só adiantam a próxima
/// tentativa (decisão de 29/09/2026). Não tem ViewModel própria: o estado é
/// todo do `AssessmentSyncService`, que o app inteiro compartilha, e as
/// regras de texto estão em `sync_queue_labels.dart`.
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key, this.clock});

  /// Relógio injetável para os testes; o padrão é `DateTime.now`.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<AssessmentSyncService>();
    final isOffline = context.watch<ConnectivityService>().isOffline;
    final now = (clock ?? DateTime.now)();
    final queue = sync.queue;

    // É uma aba, não uma tela empilhada: o voltar do Android leva para
    // Sessões, em vez de fechar o app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(sync, now),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  children: [
                    if (isOffline && queue.isNotEmpty) _buildOfflineCard(queue.length),
                    if (queue.isEmpty)
                      _buildEmpty()
                    else
                      _buildQueue(sync, queue, isOffline, now),
                    _buildSyncNow(sync, queue, isOffline),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildNavBar(context, queue.length),
      ),
    );
  }

  Widget _buildHeader(AssessmentSyncService sync, DateTime now) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sincronizar', style: AppTypography.screenTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(lastSyncLabel(sync.lastSyncedAt, now), style: AppTypography.screenSubtitle),
        ],
      ),
    );
  }

  Widget _buildOfflineCard(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
      child: Container(
        key: const Key('sync-offline-card'),
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.warningBorder, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(AppIcons.offline, size: 26, color: AppColors.warningInk),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(queueCountLabel(count), style: AppTypography.queueNoticeTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Sem conexão agora. Nada é perdido: a fila sobe sozinha '
                    'quando o sinal voltar.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.noteCommentInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fila vazia — o canvas não desenha este estado (aprovado em 29/09/2026).
  Widget _buildEmpty() {
    return Padding(
      key: const Key('sync-empty'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          const Icon(AppIcons.syncDone, size: 40, color: AppColors.successInk),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nenhuma avaliação na fila',
            style: AppTypography.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tudo o que você confirmou já chegou ao servidor.',
            style: AppTypography.meta,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQueue(
    AssessmentSyncService sync,
    List<LocalAssessment> queue,
    bool isOffline,
    DateTime now,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md + 3,
            AppSpacing.xl,
            AppSpacing.md + 3,
          ),
          child: Text('Pendentes', style: AppTypography.sectionTitle),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in queue) _buildItem(sync, item, isOffline, now),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItem(
    AssessmentSyncService sync,
    LocalAssessment item,
    bool isOffline,
    DateTime now,
  ) {
    final state = queueItemStateOf(item, sending: sync.isSendingItem(item.id));

    return Container(
      key: ValueKey('sync-item-${item.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md + 3,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      queueItemTitle(item),
                      style: AppTypography.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs + 1),
                    Text(queueItemMeta(item, state, now), style: AppTypography.meta),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _buildPill(state),
            ],
          ),
          if (state == QueueItemState.failed) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            _RetryButton(
              onPressed: isOffline || sync.isSending ? null : sync.syncNow,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPill(QueueItemState state) {
    return switch (state) {
      QueueItemState.queued => const StatusChip(
          label: 'Na fila',
          icon: AppIcons.pending,
          tone: StatusTone.neutral,
        ),
      QueueItemState.sending => const StatusChip(
          label: 'Enviando',
          icon: AppIcons.sync,
          tone: StatusTone.info,
        ),
      QueueItemState.failed => const StatusChip(
          label: 'Erro',
          icon: AppIcons.sendFailed,
          tone: StatusTone.danger,
        ),
    };
  }

  Widget _buildSyncNow(
    AssessmentSyncService sync,
    List<LocalAssessment> queue,
    bool isOffline,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCtaButton(
            label: 'Sincronizar agora',
            icon: AppIcons.sync,
            size: AppCtaSize.large,
            isLoading: sync.isSending,
            onPressed: isOffline || queue.isEmpty ? null : sync.syncNow,
          ),
          if (isOffline) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Text(
              'Disponível quando houver conexão',
              style: AppTypography.meta,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, int queued) {
    return PillNavBar(
      currentIndex: 1,
      items: [
        const PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
        PillNavItem(icon: AppIcons.sync, label: 'Sincronizar', badgeCount: queued),
        const PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
      ],
      onSelect: (index) {
        if (index == 0) context.go(AppRoutes.home);
        if (index == 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Disponível em breve.')),
          );
        }
      },
    );
  }
}

/// "Tentar novamente" de um item com erro (canvas "2h"): contorno neutro, com
/// 48dp — o alvo mínimo do DS, como o "Atribuir a mim" (o canvas tem 44).
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(AppIcons.retry, size: 19),
        label: const Text('Tentar novamente'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text2,
          disabledForegroundColor: AppColors.textMuted,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
          textStyle: AppTypography.buttonCompact,
        ),
      ),
    );
  }
}
```

Em `lib/router.dart`:

Substituir (1 de 3):

```dart
import 'ui/summary/summary_screen.dart';
```

por:

```dart
import 'ui/summary/summary_screen.dart';
import 'ui/sync/sync_screen.dart';
```

Substituir (2 de 3):

```dart
  static const String designSystem = '/ds';
```

por:

```dart
  static const String designSystem = '/ds';

  /// Aba "Sincronizar" (tela 1.9, Fase 5A).
  static const String sync = '/sync';
```

Substituir (3 de 3):

```dart
        builder: (context, state) => const SessionsScreen(),
      ),
```

por:

```dart
        builder: (context, state) => const SessionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.sync,
        builder: (context, state) => const SyncScreen(),
      ),
```

- [ ] **Step 4: A navbar e o indicador levam à aba**

Em `lib/ui/core/widgets/sync_status_indicator.dart`:

Substituir (1 de 2):

```dart
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});
```

por:

```dart
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key, this.onTap});

  /// A tela decide para onde o toque leva — hoje, a aba Sincronizar.
  final VoidCallback? onTap;
```

Substituir (2 de 2):

```dart

    if (count == 0) {
      return const SizedBox(
        width: AppSpacing.touchTarget,
        height: AppSpacing.touchTarget,
        child: Icon(AppIcons.syncDone, color: AppColors.text3),
      );
    }

    return Semantics(
      label: count == 1 ? '1 avaliação na fila' : '$count avaliações na fila',
      child: SizedBox(
        width: AppSpacing.touchTarget,
        height: AppSpacing.touchTarget,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              isOffline ? AppIcons.offline : AppIcons.sync,
              color: AppColors.warningInk,
            ),
            Positioned(
              top: AppSpacing.xs + 2,
              right: AppSpacing.xs + 1,
              child: _CountBadge(count),
            ),
          ],
        ),
```

por:

```dart

    final Widget content = count == 0
        ? const Icon(AppIcons.syncDone, color: AppColors.text3)
        : Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                isOffline ? AppIcons.offline : AppIcons.sync,
                color: AppColors.warningInk,
              ),
              Positioned(
                top: AppSpacing.xs + 2,
                right: AppSpacing.xs + 1,
                child: _CountBadge(count),
              ),
            ],
          );

    return Semantics(
      button: onTap != null,
      label: count == 0
          ? 'Nenhuma avaliação na fila'
          : count == 1
              ? '1 avaliação na fila'
              : '$count avaliações na fila',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSpacing.touchTarget,
          height: AppSpacing.touchTarget,
          child: content,
        ),
```

Em `lib/ui/sessions/sessions_screen.dart`:

Substituir (1 de 2):

```dart
              const Spacer(),
              const SyncStatusIndicator(),
            ],
```

por:

```dart
              const Spacer(),
              SyncStatusIndicator(onTap: () => context.go(AppRoutes.sync)),
            ],
```

Substituir (2 de 2):

```dart
      onSelect: (index) {
        if (index == 0) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disponível em breve.')),
        );
      },
```

por:

```dart
      onSelect: (index) {
        if (index == 1) context.go(AppRoutes.sync);
        if (index == 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Disponível em breve.')),
          );
        }
      },
```

Em `lib/ui/session_detail/session_detail_screen.dart`:

Substituir:

```dart
          children: [
            const AppTopBar(
              title: 'Detalhe da sessão',
              trailing: SyncStatusIndicator(),
            ),
```

por:

```dart
          children: [
            AppTopBar(
              title: 'Detalhe da sessão',
              trailing: SyncStatusIndicator(
                onTap: () => context.go(AppRoutes.sync),
              ),
            ),
```

- [ ] **Step 5: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **368 testes passando**, sem nenhum aviso "would not hit test" na saída.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/sync/sync_queue_labels.dart lib/ui/sync/sync_screen.dart lib/router.dart lib/ui/core/theme/app_typography.dart lib/ui/core/theme/app_icons.dart lib/ui/core/widgets/sync_status_indicator.dart lib/ui/sessions/sessions_screen.dart lib/ui/session_detail/session_detail_screen.dart test/ui/sync/sync_queue_labels_test.dart test/ui/sync/sync_screen_test.dart test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): aba sincronizar com a fila de envio"
```

---

## Task 8: "Iniciar avaliação" — o checklist só começa no toque

Pedido do usuário depois do plano pronto (decisão 10): um consultor pode atribuir vários participantes de uma vez e abrir um checklist sem querer, e abrir já gravava o rascunho e ligava o cronômetro. Agora o checklist abre só lendo, e o início é o toque em "Iniciar avaliação". A task vem por último para não reescrever as Tasks 1–7: o `openDraft` continua criando o rascunho com as regras de dono e reavaliação da Task 2, mas só o "Iniciar" o chama; o novo `findCurrent` só lê.

As marcações de uma avaliação já iniciada continuam chegando pelo stream antes do catálogo, como na Fase 4: reabrir o checklist mostra as marcações de cara.

**Files:**
- Modify: `lib/data/repositories/assessment_repository.dart` — `findCurrent`; o `openDraft` devolve a avaliação em andamento sem recomeçar
- Modify: `lib/ui/checklist/checklist_viewmodel.dart` — `init` só lê; `start()`, `isStarted`, `isStarting`
- Modify: `lib/ui/checklist/checklist_screen.dart` — o estado "não iniciada" e o botão
- Modify: `lib/ui/core/theme/app_icons.dart` — `startEvaluation`
- Test: `test/data/repositories/assessment_repository_test.dart`, `test/ui/checklist/checklist_viewmodel_test.dart`, `test/ui/checklist/checklist_screen_test.dart`
- Test: `test/ui/session_detail/session_detail_screen_test.dart` — o checklist aberto pela rota real agora pede o `findCurrent`, não o `openDraft`

**Interfaces:**
- Consumes: `AssessmentRepository.openDraft` e as regras de dono e reavaliação (Task 2); `ChecklistViewModel.expandCategory` (Task 4); `stopwatchLabel` (Task 5).
- Produces:
  - `Future<LocalAssessment?> findCurrent({required String trainingParticipantId, required String ownerUserId})` — nula quando não iniciada: sem linha, avaliação já enviada ou rascunho de outro consultor; a da fila é sempre devolvida; o rascunho sem dono passa a ser de quem abriu. Não apaga nada.
  - `openDraft` devolve a avaliação em andamento (via `findCurrent`) em vez de recomeçar.
  - `ChecklistViewModel`: `init()` não grava; `Future<void> start()` (recusa sem catálogo e não recomeça); `bool get isStarted`; `bool get isStarting`.
  - `AppIcons.startEvaluation`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/data/repositories/assessment_repository_test.dart`:

Substituir:

```dart
      expect(byOther.syncStatus, LocalSyncStatus.pendingSync);
    });
```

por:

```dart
      expect(byOther.syncStatus, LocalSyncStatus.pendingSync);
    });
  });

  group('findCurrent', () {
    Future<LocalAssessment?> current(String participantId, {String owner = 'user-1'}) {
      return repository.findCurrent(trainingParticipantId: participantId, ownerUserId: owner);
    }

    test('sem nada iniciado, é nula e não grava nada — abrir o checklist só lê',
        () async {
      expect(await current('tp-1'), isNull);
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    test('devolve a avaliação em andamento do próprio dono', () async {
      final started = await open('tp-1');

      final found = await current('tp-1');

      expect(found?.id, started.id);
      expect(found?.startTime, started.startTime);
    });

    test(
        'avaliação já enviada e rascunho de outro consultor contam como não '
        'iniciada — e nada é apagado só por abrir', () async {
      final sent = await open('tp-1');
      await repository.confirm(sent.id, participantName: 'A', score: 90);
      await repository.saveSendResults({sent.id: null}, at: DateTime(2026, 9, 29, 9));
      final theirs = await open('tp-2', owner: 'user-2');

      expect(await current('tp-1'), isNull);
      expect(await current('tp-2'), isNull);
      expect((await row(sent.id)).syncStatus, LocalSyncStatus.synced);
      expect((await row(theirs.id)).ownerUserId, 'user-2');
    });

    test('avaliação na fila é devolvida, mesmo de outro consultor', () async {
      final queued = await open('tp-1', owner: 'user-2');
      await repository.confirm(queued.id, participantName: 'A', score: 90);

      expect((await current('tp-1'))?.id, queued.id);
    });

    test('rascunho sem dono passa a ser de quem abriu', () async {
      final legacy = await open('tp-1');
      await write(legacy.id, const LocalAssessmentsCompanion(ownerUserId: Value(null)));

      final found = await current('tp-1');

      expect(found?.id, legacy.id);
      expect(found?.ownerUserId, 'user-1');
      expect((await row(legacy.id)).ownerUserId, 'user-1');
    });
```

Em `test/ui/checklist/checklist_viewmodel_test.dart`:

Substituir (1 de 15):

```dart

  group('init', () {
    test('carrega o participante, o catálogo e sai de loading', () async {
      await seedParticipant();
```

por:

```dart

  group('init e start', () {
    test(
        'abrir só lê: carrega o participante e o catálogo, sem gravar nada — '
        'um participante aberto sem querer não começa', () async {
      await seedParticipant();
```

Substituir (2 de 15):

```dart
      expect(vm.isLoading, isFalse);
      expect(vm.participant?.name, 'Carlos Eduardo Nunes');
      expect(vm.sections, hasLength(1));
      expect(vm.sections.single.infractions, hasLength(1));
      expect(vm.expandedCategoryId, 'cat-1', reason: 'abre com a primeira categoria aberta');
    });

    test('retomar o checklist reabre o mesmo rascunho, sem perder marcações', () async {
      await seedParticipant();
```

por:

```dart
      expect(vm.isLoading, isFalse);
      expect(vm.isStarted, isFalse);
      expect(vm.participant?.name, 'Carlos Eduardo Nunes');
      expect(vm.sections, hasLength(1));
      expect(vm.expandedCategoryId, isNull);
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    test(
        '"Iniciar avaliação" grava o início agora, abre a primeira categoria e '
        'liga o cronômetro', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel(tickInterval: const Duration(milliseconds: 5));
      addTearDown(vm.dispose);
      await vm.init();
      final before = DateTime.now();

      await vm.start();

      expect(vm.isStarted, isTrue);
      expect(vm.isStarting, isFalse);
      expect(vm.expandedCategoryId, 'cat-1', reason: 'abre com a primeira categoria aberta');
      final row = await db.select(db.localAssessments).getSingle();
      expect(row.ownerUserId, 'user-1');
      expect(row.syncStatus, LocalSyncStatus.draft);
      // O banco guarda segundos: o início é o toque, com essa precisão.
      expect(row.startTime.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);

      var notifications = 0;
      vm.addListener(() => notifications++);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(notifications, greaterThan(0), reason: 'o cronômetro está correndo');
    });

    test('um segundo toque em "Iniciar" não recomeça a avaliação', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();
      final first = await db.select(db.localAssessments).getSingle();

      await vm.start();

      final again = await db.select(db.localAssessments).getSingle();
      expect(again.id, first.id);
      expect(again.startTime, first.startTime);
    });

    test(
        'reabrir uma avaliação iniciada volta direto ao checklist, com as '
        'marcações', () async {
      await seedParticipant();
```

Substituir (3 de 15):

```dart
      await first.init();
      await first.toggleNote('inf-1', 'note-pm');
```

por:

```dart
      await first.init();
      await first.start();
      await first.toggleNote('inf-1', 'note-pm');
```

Substituir (4 de 15):

```dart

      expect(second.sections.single.infractions.single.selectedNoteId, 'note-pm');
```

por:

```dart

      expect(second.isStarted, isTrue);
      expect(second.expandedCategoryId, 'cat-1');
      expect(second.sections.single.infractions.single.selectedNoteId, 'note-pm');
```

Substituir (5 de 15):

```dart
      addTearDown(vm.dispose);
      await vm.init();

      await vm.toggleNote('inf-1', 'note-m');
```

por:

```dart
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();

      await vm.toggleNote('inf-1', 'note-m');
```

Substituir (6 de 15):

```dart
      await vm.init();
      await vm.toggleNote('inf-1', 'note-b');
```

por:

```dart
      await vm.init();
      await vm.start();
      await vm.toggleNote('inf-1', 'note-b');
```

Substituir (7 de 15):

```dart
      await vm.init();
      expect(vm.expandedCategoryId, 'cat-1');
```

por:

```dart
      await vm.init();
      await vm.start();
      expect(vm.expandedCategoryId, 'cat-1');
```

Substituir (8 de 15):

```dart
      await seedCatalog();
      // `openDraft` grava `startTime` com o relógio real — a base do relógio
      // falso precisa ser próxima do "agora" de verdade, senão a diferença
```

por:

```dart
      await seedCatalog();
      // O "Iniciar" grava `startTime` com o relógio real — a base do relógio
      // falso precisa ser próxima do "agora" de verdade, senão a diferença
```

Substituir (9 de 15):

```dart
      addTearDown(vm.dispose);
      await vm.init();

      expect(vm.elapsedLabel, '00:00:00');
```

por:

```dart
      addTearDown(vm.dispose);
      await vm.init();
      expect(vm.elapsedLabel, '00:00:00', reason: 'antes do "Iniciar"');
      await vm.start();

      expect(vm.elapsedLabel, '00:00:00');
```

Substituir (10 de 15):

```dart
      addTearDown(vm.dispose);
      await vm.init();

      var notifications = 0;
```

por:

```dart
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();

      var notifications = 0;
```

Substituir (11 de 15):

```dart
      addTearDown(vm.dispose);
      await vm.init();

      vm.expandCategory('cat-2');
```

por:

```dart
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();

      vm.expandCategory('cat-2');
```

Substituir (12 de 15):

```dart
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();

      expect(vm.hasCatalog, isFalse);
    });

    test(
```

por:

```dart
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();

      expect(vm.hasCatalog, isFalse);
      expect(vm.isStarted, isFalse, reason: 'sem catálogo, o "Iniciar" não grava');
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    test(
```

Substituir (13 de 15):

```dart
      await vm.init();

      expect(vm.hasCatalog, isFalse);
    });
```

por:

```dart
      await vm.init();
      await vm.start();

      expect(vm.hasCatalog, isFalse);
      expect(vm.isStarted, isFalse, reason: 'sem catálogo, o "Iniciar" não grava');
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });
```

Substituir (14 de 15):

```dart
    await vm.init();
    expect(vm.isLoading, isFalse, reason: 'o init terminou e ligou o cronômetro');
```

por:

```dart
    await vm.init();
    await vm.start();
    expect(vm.isStarted, isTrue, reason: 'o "Iniciar" ligou o cronômetro');
```

Substituir (15 de 15):

```dart
    final vm = buildViewModel();
    await vm.init();

    final pending = vm.toggleNote('inf-1', 'note-b');
```

por:

```dart
    final vm = buildViewModel();
    await vm.init();
    await vm.start();

    final pending = vm.toggleNote('inf-1', 'note-b');
```

Em `test/ui/checklist/checklist_screen_test.dart`:

Substituir (1 de 3):

```dart

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(withProviders(
```

por:

```dart

  /// A avaliação já iniciada, como se o consultor tivesse tocado em "Iniciar
  /// avaliação" antes — o caminho da maioria dos testes.
  Future<void> startEvaluation() {
    return assessmentRepository.openDraft(
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
  }

  Future<void> pumpScreen(WidgetTester tester, {bool started = true}) async {
    if (started) await startEvaluation();
    await tester.pumpWidget(withProviders(
```

Substituir (2 de 3):

```dart
  /// go_router.
  Future<void> pumpOverOrigin(WidgetTester tester) async {
    final router = GoRouter(
```

por:

```dart
  /// go_router.
  Future<void> pumpOverOrigin(WidgetTester tester, {bool started = true}) async {
    if (started) await startEvaluation();
    final router = GoRouter(
```

Substituir (3 de 3):

```dart
  });
}
```

por:

```dart
  });

  group('antes do "Iniciar avaliação"', () {
    testWidgets(
        'mostra o nome, "não iniciada" e o botão — sem a lista, sem "salvo" '
        'e sem gravar nada', (tester) async {
      await pumpScreen(tester, started: false);

      expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
      expect(find.text('não iniciada'), findsOneWidget);
      expect(find.byKey(const Key('checklist-not-started')), findsOneWidget);
      expect(find.text('A avaliação ainda não começou.'), findsOneWidget);
      expect(find.text('Iniciar avaliação'), findsOneWidget);
      expect(find.text('Excesso de velocidade'), findsNothing);
      expect(find.text('salvo'), findsNothing);
      expect(find.textContaining('categorias revisadas'), findsNothing);
      expect(find.text('Finalizar avaliação'), findsNothing);
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    testWidgets('abrir sem querer e voltar não deixa rastro', (tester) async {
      await pumpOverOrigin(tester, started: false);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    testWidgets(
        '"Iniciar avaliação" grava o início e mostra o checklist, com o '
        'cronômetro do zero', (tester) async {
      await pumpScreen(tester, started: false);

      await tester.tap(find.text('Iniciar avaliação'));
      await tester.pumpAndSettle();

      expect(find.text('Excesso de velocidade'), findsOneWidget);
      expect(find.textContaining('00:00:0'), findsOneWidget);
      expect(find.text('salvo'), findsOneWidget);
      expect(find.text('0 de 1 categorias revisadas'), findsOneWidget);
      expect(find.text('Finalizar avaliação'), findsOneWidget);
      expect(find.text('Iniciar avaliação'), findsNothing);
      final row = await db.select(db.localAssessments).getSingle();
      expect(row.syncStatus, LocalSyncStatus.draft);
    });

    testWidgets('sem catálogo no aparelho, nem dá para iniciar', (tester) async {
      await db.delete(db.infractionNotes).go();
      await db.delete(db.infractions).go();
      await db.delete(db.assessmentCategories).go();

      await pumpScreen(tester, started: false);

      expect(find.byKey(const Key('checklist-no-catalog')), findsOneWidget);
      expect(find.text('Iniciar avaliação'), findsNothing);
    });
  });
}
```

Em `test/ui/session_detail/session_detail_screen_test.dart`:

Substituir:

```dart
    when(() => catalog.loadCatalog()).thenAnswer((_) async => const []);
    when(() => assessments.openDraft(
          trainingParticipantId: any(named: 'trainingParticipantId'),
          sessionId: any(named: 'sessionId'),
          ownerUserId: any(named: 'ownerUserId'),
        )).thenAnswer((invocation) async {
      final now = DateTime(2026, 9, 25, 10);
      return LocalAssessment(
        id: 'assess-1',
        trainingParticipantId:
            invocation.namedArguments[#trainingParticipantId] as String,
        sessionId: invocation.namedArguments[#sessionId] as String,
        date: now,
        startTime: now,
        syncStatus: LocalSyncStatus.draft,
        attemptCount: 0,
        createdAt: now,
        updatedAt: now,
      );
    });
    when(() => assessments.watchItems(any()))
        .thenAnswer((_) => const Stream.empty());
  });
```

por:

```dart
    when(() => catalog.loadCatalog()).thenAnswer((_) async => const []);
    // O checklist abre sem avaliação iniciada: só lê, nada é gravado.
    when(() => assessments.findCurrent(
          trainingParticipantId: any(named: 'trainingParticipantId'),
          ownerUserId: any(named: 'ownerUserId'),
        )).thenAnswer((_) async => null);
  });
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/data/repositories/assessment_repository_test.dart test/ui/checklist/ test/ui/session_detail/session_detail_screen_test.dart`
Esperado: `assessment_repository_test.dart`, `checklist_viewmodel_test.dart` e `session_detail_screen_test.dart` não compilam (`The method 'findCurrent' isn't defined for the type 'AssessmentRepository'`, `The getter 'isStarted' isn't defined for the type 'ChecklistViewModel'`, `The method 'start' isn't defined…`); no `checklist_screen_test.dart`, falham os 3 testes do grupo "antes do 'Iniciar avaliação'" que dependem do botão — hoje abrir já grava e mostra a lista. "sem catálogo no aparelho, nem dá para iniciar" já passa: sem catálogo nunca houve botão.

- [ ] **Step 3: Implementar**

Em `lib/data/repositories/assessment_repository.dart`:

Substituir (1 de 4):

```dart

  /// Abre o rascunho da avaliação do participante para [ownerUserId].
  ///
  /// Retoma o que já existe (`trainingParticipantId` é chave única) em vez de
  /// recriar — o consultor pode ter saído do checklist e voltado. Dois casos
  /// começam um rascunho novo no lugar da linha antiga (decisão de
  /// 29/09/2026):
  /// - a avaliação já foi enviada (`synced`): é uma reavaliação — inclusive
```

por:

```dart

  /// A avaliação em andamento de [ownerUserId] para o participante, ou nula
  /// se ela ainda não foi iniciada — o checklist abre sem gravar nada e mostra
  /// o "Iniciar avaliação" (decisão de 29/09/2026).
  ///
  /// Dois casos contam como não iniciada, mesmo com uma linha no banco, porque
  /// o "Iniciar" começa um rascunho novo no lugar dela (ver [openDraft]):
  /// - a avaliação já foi enviada (`synced`): é uma reavaliação — inclusive
```

Substituir (2 de 4):

```dart
  ///
  /// Uma avaliação na fila (`pendingSync`/`error`) nunca é zerada aqui: ela é
  /// de alguém que confirmou e só espera o envio. Um rascunho sem dono (de
  /// antes da Fase 5A) passa a ser de [ownerUserId], com as marcações.
  ///
```

por:

```dart
  ///
  /// Uma avaliação na fila (`pendingSync`/`error`) é sempre devolvida: ela é
  /// de alguém que confirmou e só espera o envio. Um rascunho sem dono (de
  /// antes da Fase 5A) passa a ser de [ownerUserId], com as marcações.
  Future<LocalAssessment?> findCurrent({
    required String trainingParticipantId,
    required String ownerUserId,
  }) async {
    final existing = await findByParticipant(trainingParticipantId);
    if (existing == null || _startsOver(existing, ownerUserId)) return null;
    if (existing.ownerUserId != null) return existing;
    await (_db.update(_db.localAssessments)
          ..where((t) => t.id.equals(existing.id)))
        .write(LocalAssessmentsCompanion(ownerUserId: Value(ownerUserId)));
    return existing.copyWith(ownerUserId: Value(ownerUserId));
  }

  /// "Iniciar avaliação": cria o rascunho de [ownerUserId] com `startTime`
  /// agora — o cronômetro e a duração enviada contam a partir daqui. Se a
  /// avaliação já está em andamento ([findCurrent]), devolve a mesma, sem
  /// recomeçar: um segundo toque não zera o cronômetro.
  ///
```

Substituir (3 de 4):

```dart
  }) async {
    final existing = await findByParticipant(trainingParticipantId);
    if (existing != null && !_startsOver(existing, ownerUserId)) {
      if (existing.ownerUserId != null) return existing;
      await (_db.update(_db.localAssessments)
            ..where((t) => t.id.equals(existing.id)))
          .write(LocalAssessmentsCompanion(ownerUserId: Value(ownerUserId)));
      return existing.copyWith(ownerUserId: Value(ownerUserId));
    }

    final session = await (_db.select(_db.sessions)
```

por:

```dart
  }) async {
    final current = await findCurrent(
      trainingParticipantId: trainingParticipantId,
      ownerUserId: ownerUserId,
    );
    if (current != null) return current;

    final existing = await findByParticipant(trainingParticipantId);
    final session = await (_db.select(_db.sessions)
```

Substituir (4 de 4):

```dart

  /// Ver [openDraft]: avaliação já enviada, ou rascunho de outro consultor.
  static bool _startsOver(LocalAssessment existing, String ownerUserId) {
```

por:

```dart

  /// Ver [findCurrent]: avaliação já enviada, ou rascunho de outro consultor.
  static bool _startsOver(LocalAssessment existing, String ownerUserId) {
```

Em `lib/ui/checklist/checklist_viewmodel.dart`:

Substituir (1 de 6):

```dart
  bool _loading = true;
  String? _assessmentId;
```

por:

```dart
  bool _loading = true;
  bool _starting = false;
  String? _assessmentId;
```

Substituir (2 de 6):

```dart
  String? get expandedCategoryId => _expandedCategoryId;
```

por:

```dart
  String? get expandedCategoryId => _expandedCategoryId;

  /// A avaliação começou: há rascunho, cronômetro e marcações. Antes disso,
  /// a tela mostra só o "Iniciar avaliação" — abrir um participante sem
  /// querer não grava nada (decisão de 29/09/2026).
  bool get isStarted => _assessmentId != null;

  /// O "Iniciar avaliação" está gravando.
  bool get isStarting => _starting;
```

Substituir (3 de 6):

```dart

  /// "00:12:34" desde o início da avaliação — `00:00:00` antes de o rascunho
  /// abrir.
  String get elapsedLabel {
```

por:

```dart

  /// "00:12:34" desde o "Iniciar avaliação" — `00:00:00` antes dele.
  String get elapsedLabel {
```

Substituir (4 de 6):

```dart

  Future<void> init() async {
    final assessment = await _assessmentRepository.openDraft(
      trainingParticipantId: participantId,
      sessionId: sessionId,
      ownerUserId: ownerUserId,
    );
    if (_disposed) return;

    _assessmentId = assessment.id;
    _startTime = assessment.startTime;

    _participantSubscription ??=
```

por:

```dart

  /// Só lê: a avaliação em andamento, se houver, e o catálogo. Nada é gravado
  /// até o "Iniciar avaliação" ([start]).
  Future<void> init() async {
    _participantSubscription ??=
```

Substituir (5 de 6):

```dart
      notifyListeners();
    });

    _itemsSubscription ??=
```

por:

```dart
      notifyListeners();
    });

    final current = await _assessmentRepository.findCurrent(
      trainingParticipantId: participantId,
      ownerUserId: ownerUserId,
    );
    if (_disposed) return;
    // As marcações primeiro: o stream as entrega enquanto o catálogo carrega,
    // e a tela já abre com elas.
    if (current != null) _attach(current);

    _catalog = await _catalogRepository.loadCatalog();
    if (_disposed) return;
    if (current != null) _openFirstCategory();

    _loading = false;
    notifyListeners();
  }

  /// "Iniciar avaliação": grava o início agora e mostra o checklist. Sem
  /// catálogo não inicia — não há o que avaliar, e a tela nem mostra o botão.
  Future<void> start() async {
    if (isStarted || _starting || !hasCatalog) return;

    _starting = true;
    notifyListeners();
    try {
      final assessment = await _assessmentRepository.openDraft(
        trainingParticipantId: participantId,
        sessionId: sessionId,
        ownerUserId: ownerUserId,
      );
      if (_disposed) return;
      _attach(assessment);
      _openFirstCategory();
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  /// Liga a tela à avaliação em andamento: as marcações e o cronômetro.
  void _attach(LocalAssessment assessment) {
    _assessmentId = assessment.id;
    _startTime = assessment.startTime;

    _itemsSubscription ??=
```

Substituir (6 de 6):

```dart

    _catalog = await _catalogRepository.loadCatalog();
    if (_disposed) return;

    // Como no canvas: a tela sempre abre com a primeira categoria aberta.
    final sections = this.sections;
    _expandedCategoryId = sections.isEmpty ? null : sections.first.id;

    _ticker ??= Timer.periodic(tickInterval, (_) => notifyListeners());

    _loading = false;
    notifyListeners();
  }
```

por:

```dart

    _ticker ??= Timer.periodic(tickInterval, (_) => notifyListeners());
  }

  /// Como no canvas: o checklist começa com a primeira categoria aberta.
  void _openFirstCategory() {
    final sections = this.sections;
    _expandedCategoryId = sections.isEmpty ? null : sections.first.id;
  }
```

Em `lib/ui/core/theme/app_icons.dart`:

Substituir:

```dart
  static const IconData retry = Icons.refresh;
}
```

por:

```dart
  static const IconData retry = Icons.refresh;

  /// "Iniciar avaliação" do checklist (Fase 5A — não está no canvas).
  static const IconData startEvaluation = Icons.play_arrow_rounded;
}
```

Em `lib/ui/checklist/checklist_screen.dart`:

Substituir (1 de 5):

```dart
          ),
          if (!_viewModel.isLoading && _viewModel.hasCatalog)
            Padding(
```

por:

```dart
          ),
          if (!_viewModel.isLoading && _viewModel.hasCatalog && _viewModel.isStarted)
            Padding(
```

Substituir (2 de 5):

```dart
  Widget _buildTimerRow() {
    return Row(
```

por:

```dart
  Widget _buildTimerRow() {
    if (!_viewModel.isLoading && !_viewModel.isStarted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.timer, size: 14, color: AppColors.text3),
          const SizedBox(width: AppSpacing.xs),
          Text('não iniciada', style: AppTypography.meta),
        ],
      );
    }

    return Row(
```

Substituir (3 de 5):

```dart

    // Como no canvas: a categoria aberta é um bloco próprio, e as fechadas
```

por:

```dart

    if (!_viewModel.isStarted) return _buildNotStarted();

    // Como no canvas: a categoria aberta é um bloco próprio, e as fechadas
```

Substituir (4 de 5):

```dart
        ],
      ],
    );
  }
```

por:

```dart
        ],
      ],
    );
  }

  /// Antes do "Iniciar avaliação" (decisão de 29/09/2026): o consultor pode ter
  /// aberto o participante sem querer — nada foi gravado, e voltar não deixa
  /// rastro. O canvas não tem este estado.
  Widget _buildNotStarted() {
    return Padding(
      key: const Key('checklist-not-started'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.huge,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        children: [
          const Icon(AppIcons.timer, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            'A avaliação ainda não começou.',
            style: AppTypography.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'O cronômetro começa quando você tocar em "Iniciar avaliação".',
            style: AppTypography.meta,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
```

Substituir (5 de 5):

```dart
      ),
      child: AppCtaButton(
        label: 'Finalizar avaliação',
        icon: AppIcons.finish,
        size: AppCtaSize.large,
        onPressed: _openSummary,
      ),
    );
```

por:

```dart
      ),
      child: _viewModel.isStarted
          ? AppCtaButton(
              label: 'Finalizar avaliação',
              icon: AppIcons.finish,
              size: AppCtaSize.large,
              onPressed: _openSummary,
            )
          : AppCtaButton(
              label: 'Iniciar avaliação',
              icon: AppIcons.startEvaluation,
              size: AppCtaSize.large,
              isLoading: _viewModel.isStarting,
              onPressed: _viewModel.start,
            ),
    );
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **379 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/assessment_repository.dart lib/ui/checklist/checklist_viewmodel.dart lib/ui/checklist/checklist_screen.dart lib/ui/core/theme/app_icons.dart test/data/repositories/assessment_repository_test.dart test/ui/checklist/checklist_viewmodel_test.dart test/ui/checklist/checklist_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart
git commit -m "feat(mobile): botao iniciar avaliacao antes de gravar o inicio"
```

---

## Task 9: Validação no aparelho físico

Esta task é o portão da fase: sem ela, a Fase 5B não é planejada (decisão do usuário, registrada em 17/09/2026). É o roteiro que só o usuário pode rodar.

**Files:** nenhum arquivo de código.

**Interfaces:**
- Consumes: o app inteiro, montado pelas Tasks 1–8.
- Produces: o aval do usuário para planejar a Fase 5B.

- [ ] **Step 1: Subir o backend e liberar a porta para o aparelho**

Run: `cd apps/backend && npm run start:dev`

Em outro terminal, com o aparelho conectado: `adb reverse tcp:3001 tcp:3001` (o id do aparelho sai de `adb devices`).

- [ ] **Step 2: Instalar no aparelho**

Run (em `apps/mobile/simtc`): `flutter run -d <ID_DO_APARELHO>`

Sem `--dart-define`. **Instale por cima, sem desinstalar**: a migração v3→v4 roda na primeira abertura e preserva o que já está no aparelho. Atenção: as avaliações de teste que foram finalizadas na validação da Fase 4 estão na fila e **vão para o backend local** logo na primeira abertura com rede (ficam com o primeiro usuário que entrar).

- [ ] **Step 3: Percorrer o roteiro de aceite**

Preparação, com rede: na Home, uma sessão "Em andamento" com pelo menos quatro participantes atribuídos a você ("Atribuir a mim").

Iniciar avaliação:
- [ ] toque em "Avaliando · você" de um participante: o checklist abre com o nome, "⏱ não iniciada", "A avaliação ainda não começou." e o botão "Iniciar avaliação" — **sem a lista**;
- [ ] volte sem iniciar: a linha continua "Avaliando · você", **sem** "Iniciada às…" — nada foi gravado;
- [ ] abra de novo e toque em "Iniciar avaliação": aparece o checklist com a primeira categoria aberta, a hora "Iniciada às HH:MM" (sem nada correndo) e "salvo";
- [ ] marque algumas notas: o topo mostra só o percentual e a barra, sem "categorias revisadas"; a barra começa cheia em 100,0% e esvazia conforme as infrações; abaixo de 70% ela fica vermelha. Volte: a linha agora mostra "Iniciada às HH:MM", com a mesma hora do checklist; abrir de novo vai direto ao checklist, com as marcações.

Conferir e finalizar (1.6):
- [ ] "Finalizar avaliação" abre "Conferir e finalizar" **sem diálogo**, com a "Pontuação final" igual ao % do checklist, a pílula "Aprovado" (ou "Necessita reavaliação" abaixo de 70%), a linha "Nome · N infrações · mínimo para aprovação 70%.", a linha "Início HH:MM · Fim HH:MM" (o início é o do checklist) e cada categoria com "sem infração"/"N infrações" e o selo de %;
- [ ] tocar numa categoria volta ao checklist com ela aberta; o "←" volta ao checklist sem mudar nada; ao abrir a 1.6 de novo, o "Fim" é o horário de agora;
- [ ] "Confirmar" (com rede) volta ao detalhe da sessão; em segundos a linha vira "Aprovado · N%"/"Reavaliar · N%" sozinha, e a avaliação aparece no painel web (ou em `GET /api/practical-assessments/by-participant/<id>`), com o início e o fim iguais aos da 1.6 (a hora do toque em "Confirmar" não entra: vale a hora em que a 1.6 abriu);
- [ ] nesse caminho a linha **nunca** volta a "Avaliando · você" depois do envio. Entre "Na fila" e "Aprovado"/"Reavaliar" pode aparecer por um instante o chip azul "Enviada", com "N,N% · enviada às HH:MM"; enquanto ele estiver lá, tocar na linha não abre nada (decisão 11).

Offline — **corte a rede de verdade** (via USB o modo avião não derruba o `adb reverse`): modo avião, confira que o Wi-Fi desligou e rode `adb -s <ID_DO_APARELHO> reverse --remove tcp:3001`.
- [ ] inicie, avalie e confirme o segundo participante (o "Iniciar" funciona sem rede): a linha mostra o chip "Na fila" com "N,N% · aguardando envio" e **não abre** mais o checklist; o indicador do cabeçalho mostra a nuvem riscada com o badge "1", e a aba "Sincronizar" da navbar também;
- [ ] tocar no indicador abre a aba: "1 avaliação na fila" no cartão âmbar, o item em "Pendentes" com "Na fila" e "Avaliação prática · N,N% · HH:MM", e "Sincronizar agora" desabilitado com "Disponível quando houver conexão";
- [ ] feche o app à força e abra de novo, ainda sem rede: ele entra direto (Fase 4), e a avaliação continua "Na fila";
- [ ] **sem tocar em nada**, volte a ficar online — primeiro `adb -s <ID_DO_APARELHO> reverse tcp:3001 tcp:3001`, depois desligue o modo avião: a fila esvazia sozinha, o badge some, a linha vira Aprovado/Reavaliar e "Última sincronização hoje HH:MM" aparece na aba.

Erro e "Tentar novamente" — com rede, mas com o backend parado (`Ctrl+C` no terminal do `npm run start:dev`):
- [ ] confirme o terceiro participante: em segundos, a linha mostra "Erro no envio" com "N,N% · falhou às HH:MM", e na aba o item aparece com "Erro", "Falhou às HH:MM · sem conexão" e o botão "Tentar novamente";
- [ ] suba o backend de novo, feche o app à força e abra de novo **sem tocar em nada**: o item em erro sai sozinho da fila. A primeira leitura da fila, na abertura, envia também o que ficou em erro (correção `54101cb`);
- [ ] pare o backend de novo e confirme o quarto participante até aparecer "Erro no envio". Suba o backend e toque em "Tentar novamente" (ou "Sincronizar agora"): o item passa por "Enviando" e sai da fila.

Sessão e navegação:
- [ ] na aba, "Sessões" na navbar volta para a Home, e o voltar do Android também (o app não fecha); "Perfil" continua com "Disponível em breve.";
- [ ] (se der para esperar o token vencer com o app aberto e sem rede) voltar ao sinal não pede login.

Regressões:
- [ ] depois do "Iniciar", o checklist continua abrindo com a primeira categoria aberta, rolando até a categoria tocada, e marcando B/PM/M;
- [ ] "Atribuir a mim" e o participante concluído (tela provisória "Resultado") continuam como antes.

**Não verificável neste aparelho, e por quê:** o aparelho compartilhado (outro consultor entrando com a fila de alguém) e a recusa do backend a um item só dependem de um segundo usuário ou de apagar dados no banco — ficam cobertos pelos testes das Tasks 2 e 3. A linha "Enviada" parada (o download da sessão falhando logo depois de um envio aceito) exigiria derrubar a rede entre o envio e o download; fica coberta pelos testes do serviço e do detalhe (decisão 11).

- [ ] **Step 4: Registrar o resultado**

Se tudo passar, avisar o usuário e pedir o aval para planejar a Fase 5B. Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio ou de contrato do backend, parar e perguntar.

---

## Pendências levadas para as fases seguintes

Resolvidas nesta fase (saem da lista da Fase 4): renovação do token que deslogava sem rede (prioridade), perfil salvo com tokens de outro usuário, `saveUser` que derrubava a abertura, hora de início na linha "Avaliando · você", badge da fila, "Finalizar" que gravava direto, marcações órfãs no envio, reabrir participante já finalizado, duração enviada, rascunhos por consultor, reavaliação reabrindo o rascunho antigo, formato do `date`, aviso de hit-test dos testes da Home, a linha que voltava a "Avaliando · você" depois do envio aceito (decisão 11).

| Fase | Pendência |
|---|---|
| 5B | Tela 1.8 Resultado no lugar da provisória, "Reavaliar" (chama `assign` antes de abrir o checklist — o `openDraft` já começa um rascunho novo sobre uma avaliação enviada) e "Próximo participante". Depois do "Confirmar", decidir se a 1.6 leva ao Resultado em vez de voltar ao detalhe. |
| 5B | Com o Resultado, o toque na linha "Enviada" (decisão 11) pode ir para ele em vez de não abrir nada. |
| 5B | Com a avaliação na fila, só a linha do detalhe impede abrir o checklist. Se ele for aberto por outro caminho (hoje não há), a avaliação confirmada fica editável. Deixar o checklist somente leitura quando a avaliação não for rascunho. |
| 5B | No serviço de envio: <ul><li>um erro ao entrar (`claimUnowned` ou o stream da fila) não é tratado: a fila não é seguida e a aba diz "Tudo o que você confirmou já chegou ao servidor";</li><li>o `syncNow` devolve o envio no ar antes da rodada repetida;</li><li>`retryDelays` vazio quebra (falta um `assert`);</li><li>todo 401, inclusive depois de uma renovação bem-sucedida, deixa os itens "Na fila" até o próximo gatilho.</li></ul> Tratar junto com a troca de usuário no meio do envio (dois `_follow` no ar, sem nova checagem do usuário antes do POST), que só importa quando houver "Sair" na interface. |
| Backend | `syncOne` apaga os itens e depois atualiza a avaliação fora de uma transação: um reenvio que falhe no meio deixa uma avaliação aceita sem itens. |
| 5B | Os rascunhos que a Fase 4 criou ao abrir o checklist (inclusive os abertos sem querer) contam como iniciados, com o horário antigo. Se aparecer um rascunho vazio e antigo em campo, decidir se o "Iniciar" pode zerá-lo. |
| 5B | "Última sincronização" é o último envio aceito ainda no aparelho: uma reavaliação apaga a linha enviada, e o horário pode voltar para um envio anterior. |
| 5B | Um item que o servidor sempre recusa (participante removido da sessão, nota apagada no painel) fica como "Erro" para sempre, tentando de 10 em 10 minutos com o app aberto. Decidir se o consultor pode descartar. |
| 5B | Uma avaliação na fila de outro consultor, para um participante que agora está com você (reatribuído no painel), é devolvida como está pelo `openDraft` — você veria e editaria as marcações dele. Caso raro (aparelho compartilhado + reatribuição antes do envio). |
| 5B | O envio só acontece com o app aberto (ou voltando do segundo plano). Enviar com o app fechado exige um serviço em segundo plano (WorkManager). |
| 5 | Sessão aberta sem rede usa o perfil guardado (decisão 7 da Fase 4): nome, papel ou consultor alterados no painel só aparecem na próxima abertura com rede. |
| 5 | Uma falha `DioExceptionType.unknown` sem resposta conta como erro de rede — também entra offline e, no envio, vira "sem conexão". |
| 8 | Trocar de aba recria a tela: voltar para Sessões baixa a agenda de novo. Se pesar, manter as abas vivas (`StatefulShellRoute`). |
| 8 | Estados de erro do checklist: uma falha de escrita local em `init`, `toggleNote` ou no "Iniciar avaliação" não mostra mensagem (a da 1.6 mostra; no "Iniciar", o botão volta a ficar ativo). |
| 8 | `AuthSession.start()`: uma falha da keystore no `deleteUser` derruba o login, como já acontecia com o `setKeepSignedIn`. |
| 8 | Acabamento: <ul><li>faltam testes da virada da meia-noite nos rótulos de horário, do toque direto no indicador e da aba offline com a fila vazia;</li><li>a pluralização "N avaliações na fila" está em dois lugares;</li><li>o `atLabel` calcula `_isToday` duas vezes;</li><li>o `claimUnowned` faz uma consulta por linha sem dono;</li><li>o `saveSendResults` ignora em silêncio um id que sumiu;</li><li>o badge do indicador usa tamanhos soltos (16/2), como o da navbar (18/2);</li><li>a 1.6 não tem estado vazio próprio, porque o rodapé do checklist só existe com catálogo;</li><li>os testes do serviço usam esperas curtas em tempo real.</li></ul> |
| 8 | Com rede "conectada mas sem dados", a entrada offline só acontece depois do timeout do `ApiClient` (15 s / 20 s); o envio também espera esse tempo antes de marcar "tempo esgotado". |
| 8 | O toque no cabeçalho da categoria aberta e nos botões B/PM/M não mostra ripple; o "salvo" do cabeçalho do checklist é estático. |
| 8 | Botões B/PM/M sem `Semantics(selected: …)`. |
| 8 | Aparelho compartilhado: os rascunhos e a fila de outro consultor ficam no aparelho (invisíveis para quem entrou) até o dono entrar de novo. Limpar ou avisar, se isso aparecer em campo. |
| — | Canvas: a spec `4z` diz padding 14/16 na linha da infração, e o quadro `1b` usa 15/20; a 1.6 do canvas ainda tem a conta de pontos e o ícone de assinatura, e a 1.9 o "+ assinatura"; o estado "não iniciada" do checklist, a pílula "Enviando", os chips "Na fila" e "Enviada" da linha e a fila vazia não estão desenhados. Atualizar no Claude Design. |
