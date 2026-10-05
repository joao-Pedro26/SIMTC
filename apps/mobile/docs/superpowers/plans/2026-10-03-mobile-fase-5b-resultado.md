# App Mobile SIMTC — Fase 5B: Resultado, reavaliação e descartes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tela 1.8 Resultado ("Avaliação concluída") entra no lugar da provisória — logo depois do "Confirmar" e para quem já foi avaliado —, com o "Reavaliar" para quem está em "Necessita reavaliação". O consultor passa a poder descartar uma avaliação iniciada, desatribuir um participante (endpoint novo no backend) e descartar da fila um item que o servidor recusa; uma avaliação confirmada não é mais editável no checklist.

**Architecture:** O Resultado lê de três fontes, nesta ordem: a avaliação deste aparelho ainda não aceita pelo servidor (dados locais), a do servidor (`GET /practical-assessments/by-participant/:id`) e, sem ela, só a nota e o status que o cache da sessão guarda — nada novo é guardado no aparelho. O "Reavaliar" reserva o participante (`assign`) e abre o checklist em "não iniciada". O "Desatribuir" chama um endpoint novo, `POST /practical-assessments/unassign`, que devolve o participante ao status de antes. Os descartes são locais e conferem a situação na mesma transação: `discardDraft` (rascunho) e `discardFailed` (item recusado).

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · drift 2.31.0 · dio · mocktail (testes) · backend NestJS + Prisma, testes com jest. **Sem mudança de esquema do Drift** (continua v4) e **sem dependência nova**. No backend, um endpoint novo e nenhuma migração nova (a da assinatura já está no working tree).

**Spec:** `brainstorm-implementacao-mobile.md` → "Fase 5 — Resumo + Sincronização automática" (a 5B é o Resultado) e `brainstorm-app-mobile.md` (seção 0, item 4: o "Reavaliar" chama `assign` antes de reabrir o checklist); canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html`, quadro `2g` "1.8 Resultado" (linhas 1239–1318); contrato no backend em `apps/backend/src/practical-assessments/`; pendências marcadas "5B" no plano da 5A (`2026-09-29-mobile-fase-5a-envio.md`). O desenho aprovado em 01/10/2026 está em "Decisões tomadas com o usuário" — a trilha mobile não usa doc de spec separado, o plano é o documento.

**Validação prévia:** todo o código deste plano foi escrito e rodado numa cópia descartável do repositório (app e backend) antes de o plano ser fechado, e depois as tasks foram **reencenadas em ordem** numa segunda cópia limpa: em cada task, os testes falharam antes da implementação pelo motivo descrito no passo "Esperado", e cada checkpoint bateu o número de testes — no app, **403 → 411 → 416 → 422 → 426 → 441 → 451 → 452 → 456**, com `flutter analyze` sem issues em todos; no backend, **70 → 73** (com as 12 falhas antigas de sempre). Os blocos de código foram gerados dessa cópia por um script que confere cada "Substituir / por" contra o estado deixado pela task anterior, e um segundo script aplicou o plano inteiro, como um executor faria, e conferiu o resultado arquivo a arquivo, task a task — o que está aqui é, byte a byte, o código que passou.

## Decisões tomadas com o usuário

Em 01/10/2026, no brainstorm da fase (desenho aprovado em três partes):

1. **Escopo da 5B:** a tela 1.8 Resultado, o "Reavaliar" e o "Próximo participante"; mais o "Descartar avaliação", o "Desatribuir participante", o "Descartar" do item recusado e o checklist somente leitura. As outras pendências da 5A ficam para a Fase 8 (ver "Pendências").
2. **Depois do "Confirmar", o Resultado.** Como no canvas: a 1.6 e o checklist fecham e abre "Avaliação concluída" com os dados do aparelho (a avaliação pode ainda estar na fila). O X, o voltar e o "Próximo participante" levam ao detalhe da sessão.
3. **"Próximo participante" só volta ao detalhe da sessão** — o consultor escolhe na lista quem avaliar em seguida. Aparece só logo depois do "Confirmar".
4. **"Reavaliar":** só para quem está em "Necessita reavaliação" no servidor, com o Resultado aberto pelo detalhe e sem avaliação deste aparelho esperando envio. Reserva o participante (`assign`) e troca o Resultado pelo checklist em "não iniciada": a nova avaliação só começa no "Iniciar avaliação" (decisão 10 da 5A), e a regra de uma por vez (decisão 15 da 5A) continua valendo ali — a reserva acontece mesmo com outra avaliação em andamento, porque atribuir vários é permitido. Precisa de rede: sem ela, fica desabilitado com "Disponível quando houver conexão".
5. **De onde vem o resultado:** a avaliação deste aparelho ainda não aceita (na fila ou com erro de envio) usa os dados do aparelho — as marcações, o catálogo e o % gravado no "Confirmar". Nos outros casos, com rede, vem do servidor: a nota é a do servidor; o % de cada categoria é calculado com o catálogo do aparelho, pela regra do checklist; a lista de infrações vem da resposta (descrição, número do item e comentário).
6. **Sem rede**, se o aparelho tem a avaliação, usa ela; se não tem, mostra só a nota e o status guardados, com o aviso "Sem conexão: as infrações aparecem quando houver internet." **Nada novo é guardado no banco** (sem migração no app).
7. **"Descartar avaliação"** (muda o "iniciar é definitivo" da decisão 10 da 5A): no menu ⋮ do checklist, só com a avaliação iniciada; pede confirmação ("As marcações e a hora de início de Ana Paula Ribeiro serão apagadas. O participante continua com você.") e volta à tela "não iniciada". Funciona offline. É o que destrava a regra de uma por vez quando um rascunho é iniciado por engano ou abandonado.
8. **"Desatribuir participante"**, também no menu ⋮ do checklist: só quem está com o participante; precisa de rede; pede confirmação ("Ana Paula Ribeiro volta para "Pendente" e fica disponível para outro consultor."; numa reavaliação, "volta para "Necessita reavaliação""). Com a avaliação iniciada, a confirmação avisa que "A avaliação iniciada será descartada." — e o rascunho só é apagado depois que o servidor confirma. Depois, o checklist fecha e o detalhe mostra "Participante desatribuído.".
9. **Endpoint novo no backend**, `POST /practical-assessments/unassign` (`{ participantIds }`, igual ao `assign`): recusa com 409 quem não está em avaliação com quem pediu ("Um ou mais participantes não estão atribuídos a você"); os outros perdem a atribuição e voltam ao status de antes — "Pendente" sem avaliação, ou o status da nota da avaliação anterior numa reavaliação. **ADMIN desatribuindo qualquer um fica para a Fase 6.**
10. **As mudanças do backend que já estão no working tree** (remoção da assinatura do participante, decisão de 20/09/2026) são commitadas na Task 1, como estão, antes do endpoint — autorizado pelo usuário ("Pode commitar as minhas mudanças").
11. **"Descartar" na aba Sincronizar**, só nos itens "recusada pelo servidor": confirmação ("A avaliação de Rodrigo Tavares não foi aceita pelo servidor e será apagada deste aparelho."), e o item sai da fila e do badge. Falha de rede ou de servidor continua tentando sozinha, sem descarte.
12. **As linhas "Na fila", "Erro no envio" e "Enviada" do detalhe abrem o Resultado**, só para leitura, com o estado do envio.
13. **Checklist somente leitura:** se uma avaliação já confirmada chegar ao checklist por outro caminho, as marcações aparecem sem B/PM/M clicáveis, sem rodapé e sem menu, com o aviso "Avaliação confirmada — não pode mais ser alterada."
14. **Divergências do canvas aprovadas** (quadro `2g`): sem pontos ("39 de 45 pts", "14 de 18 pts", "−6 pts"); a linha abaixo da nota traz início e fim, sem "duração" (decisão 12 da 5A) e sem "assinatura coletada"; o número do item entra na linha da infração (o canvas o cita no rodapé, mas não o desenha); o aviso de envio é novo; o "Reavaliar" é novo; o menu ⋮ do checklist e o "Descartar" da aba não estão no canvas.
15. **Erros e casos de borda** (parte 3 do desenho): skeleton enquanto carrega; servidor falhou → a avaliação do aparelho, se houver, com "Mostrando a avaliação feita neste aparelho.", senão a nota e o status guardados com "Não foi possível carregar as infrações." e "Tentar novamente"; servidor sem avaliação → "Não há avaliação registrada no servidor para este participante."; sem catálogo no aparelho, o "Desempenho por categoria" some; dois toques no "Reavaliar" reservam uma vez; o descarte da aba só apaga se o item ainda estiver recusado no momento do toque.

### Desvios na execução (03 a 05/10/2026)

A execução foi por subagentes, uma task por vez, cada uma conferida arquivo a arquivo contra o código validado e revisada antes da próxima. As Tasks 1, 2 e 4 a 9 saíram iguais ao plano. Os desvios foram:

**Task 3, posição dos métodos.** `discardDraft`, `discardFailed` e `_discardWhere` ficaram depois de `saveSendResults` em `assessment_repository.dart`, e não depois de `_startsOver`, onde o plano os punha. O código é o mesmo, e nenhuma task posterior edita esse arquivo.

**Task 10, correção `92b76e8`.** A revisão da task achou que a trava do "Descartar" com um envio no ar só valia na hora de desenhar o botão: com o diálogo de confirmação aberto, um reenvio automático podia começar, e o descarte apagava do aparelho uma avaliação que o servidor ainda podia aceitar. Agora o `discardRefused` não apaga (devolve `false`) com um envio em andamento. Isso trouxe 2 testes a mais: 458 ao fim das tasks.

**Revisão final.** Commits `6f16da6` a `f3bf046`, com 17 testes a mais no app e 1 no backend. A revisão do branch inteiro achou lacunas do próprio plano:
- **"Reavaliar" só com a sessão em andamento** (`6f16da6`). O plano não tinha esse portão: numa sessão concluída, o Resultado deixava reservar e iniciar, e o envio sobrescreveria a avaliação que embasou os certificados. É a regra que o detalhe da sessão e o painel web já aplicam. Acrescenta à decisão 4: fora de "em andamento", o botão não aparece.
- **O Resultado recarrega quando a rede volta** (`a40c691`). O aviso "Sem conexão: as infrações aparecem quando houver internet." não se cumpria com a tela aberta.
- **Resultado sem carregamento preso** (`c011333`). Uma falha ao ler o banco do aparelho deixava a tela carregando para sempre; agora mostra a nota guardada, com "Tentar novamente". No mesmo commit, o aviso de envio deixou de poder ficar desatualizado.
- **Desatribuir e descartar se excluem no checklist** (`bfb10ce`). Enquanto o desatribuir espera o backend, ou um descarte está gravando, "Iniciar avaliação", as notas, o menu ⋮ e o "Finalizar avaliação" não reagem: o ⋮ só deixa de abrir, sem mudar de aparência, e o "Finalizar avaliação" fica desabilitado. Se a avaliação iniciada não pôde ser apagada depois do desatribuir, a tela avisa.
- **A aba Sincronizar trata a falha do "Descartar"** (`45bbd8c`): um erro ao apagar mostra o mesmo aviso de "Não foi possível descartar. Tente de novo.".
- **Ajustes pequenos** (`d22ff31`): o efeito de toque passou a aparecer nos grupos de "Infrações registradas"; o diálogo do descarte sem nome diz "deste participante"; comentários do código.
- **Testes que faltavam** (`a982398`, `edd5a06`): o Resultado pela rota real com `?confirmada=1`, o "Reavaliar" com a avaliação anterior enviada deste aparelho, o número do item na linha da infração, o descarte de uma avaliação que foi aceita no reenvio e, no backend, o desatribuir com nota zero.
- **Auditoria da Fase 0** (`f3bf046`): nota sobre a remoção da assinatura do participante.

**Fim da execução:** app com **475 testes passando** e `flutter analyze` sem issues; backend com as 12 falhas antigas e 62 testes passando (74 no total).

### Decisões em aberto (para o usuário)

A execução deixou estas escolhas para o usuário. Nenhuma foi decidida por conta própria:

1. **Avaliação iniciada numa sessão que foi concluída ou cancelada** (regra de negócio). A regra de uma avaliação por vez vale em todas as sessões, mas o detalhe de uma sessão fora de "em andamento" não abre o checklist. Se o responsável concluir ou cancelar a sessão com uma avaliação do consultor iniciada, ela fica inalcançável e bloqueia o "Iniciar avaliação" de todos os outros participantes, em qualquer sessão. Opções: (a) abrir o checklist dessa linha só para leitura, com o "Descartar avaliação" — muda a tela; (b) a regra de uma por vez ignora a avaliação iniciada em sessão que não está em andamento — não muda a tela (recomendada pela revisão); (c) deixar para a Fase 8.
2. **Indicador de progresso no "Desatribuir participante".** Com a rede lenta, o envio pode levar de 15 a 35 segundos, e a tela não mostra que está esperando: só o "Finalizar avaliação" fica desabilitado. Um indicador é visual novo, fora do canvas.
3. **"Tentar novamente" ao lado do "Descartar"** na aba Sincronizar: com os dois botões na mesma linha, o rótulo "Tentar novamente" quebra em duas linhas nas larguras comuns (360 a 412 dp), sem estourar. Opções: aceitar; empilhar os dois botões; dar mais largura ao "Tentar novamente".
4. **A pílula "Necessita reavaliação"** do Resultado e da 1.6 não encolhe: em tela de 360 dp ou com a fonte do sistema ampliada, a nota pode quebrar em duas linhas. Ver no aparelho.
5. **A setinha nas linhas "Na fila", "Erro no envio" e "Enviada"** do detalhe: como agora abrem o Resultado (decisão 12), passaram a mostrar a seta de toque. Confirmar no aparelho.
6. **Texto do aviso quando o "Descartar" da aba não apaga** porque a avaliação deixou de estar recusada (foi reenviada e aceita com o diálogo aberto): hoje diz "Não foi possível descartar. Tente de novo.", mas não há o que tentar de novo.

### Ajustes feitos ao preparar o plano (revisar junto com o plano)

A validação na cópia descartável levou a estes ajustes — **nenhum muda regra de negócio aprovada**, mas cada um é uma escolha que o usuário deve conferir:

- **A busca do resultado no servidor ficou no `ParticipantRepository`** (`fetchAssessment`), em vez de um repositório novo: ele já fala com a API do participante (`syncSession`, `assign`, `unassign`) e já é injetado em todas as telas. O backend responde **200 sem corpo** quando não há avaliação — vira `Success(null)`.
- **"Enviada" (aceita, sessão ainda não baixada) busca no servidor**: a avaliação já foi aceita, então a do servidor é a mesma; a do aparelho fica de reserva se o servidor não responder. Só "Na fila" e "Erro no envio" usam direto os dados do aparelho.
- **Categoria que o catálogo do aparelho não conhece** (catálogo velho) entra no fim das "Infrações registradas", sem %; sem catálogo nenhum, o "Desempenho por categoria" some e as infrações do servidor continuam.
- **O topo da 1.6 e do Resultado virou um widget só** (`FinalScoreBlock`, em `lib/ui/core/widgets/`): "Pontuação final", o %, a pílula e as linhas de detalhe. A pílula saiu da `summary_screen.dart`. A 1.6 continua igual na tela.
- **`AppTopBar` ganhou o ícone da esquerda configurável** (o X de "Fechar" do Resultado, 26dp, como no canvas) e **`AppCtaButton` ganhou um ícone depois do rótulo** (o "›" do "Próximo participante").
- **A hora de início no cabeçalho do checklist passou a encolher com reticências**: com o menu ⋮ ao lado, "Iniciada em 28 set 08:12" não cabia num celular estreito.
- **O "Descartar" da aba é um método do `AssessmentSyncService`** (`discardRefused`): a aba não tem ViewModel própria (o estado dela é todo do serviço), e assim o serviço falso dos testes o registra.
- **O desatribuir recusado com 409 baixa a sessão de novo**, para o detalhe mostrar com quem o participante está.
- **Sem rede no meio do "Reavaliar"**, a mensagem é a do próprio cliente HTTP: "Sem conexão com o servidor. Verifique a internet e tente de novo."
- **Rascunho órfão** — o servidor desatribuiu, mas o aparelho falhou ao apagar o rascunho (só com erro de escrita no banco local): a tela avisa "Participante desatribuído, mas a avaliação iniciada não foi apagada do aparelho." e o rascunho bloquearia o "Iniciar". Risco aceito no desenho.
- **Nada de elementos `?x` em listas** (null-aware elements do Dart 3.8): o `pubspec.yaml` aceita Dart a partir do 3.4 (`sdk: '>=3.4.0 <4.0.0'`), e o analyzer recusa essa sintaxe.

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app` (a mesma das fases anteriores). Sem git worktree. Não criar branch, não fazer merge, não fazer push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada, com a mensagem exata dada. Vale também para o backend (o `apps/backend/CLAUDE.md` pede inglês, mas os commits do backend das Fases 0 e 2 estão em português, e é essa a prática do repositório).
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem arquivos soltos que não são desta fase — `apps/backend/test-render.js`, `apps/web/…`, `apps/mobile/simtc/devtools_options.yaml` e os arquivos da raiz (`brainstorm-*.md`, `prompt-*.md`, `test-*.js`, `IMPLEMENTATION-STATUS.md`, `.vscode/`) — **não tocar neles**. As mudanças do backend em `prisma/` e `src/practical-assessments/` (remoção da assinatura) **são** desta fase: a Task 1 as commita, como estão.
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado. No backend, `npx jest` já tem **12 falhas antigas** (`test/auth.service.spec.ts` e `test/participants.service.spec.ts`, desde 17/09/2026) — esse número não pode subir.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-10-03-mobile-fase-5b-resultado/`.

**Mobile (valem para todas as fases)**
- Flutter 3.41.6 / Dart 3.11.4 (o `pubspec.yaml` aceita a partir do 3.4: nada de sintaxe mais nova que isso). App **só Android**, APK sideload. Validação manual em **aparelho físico** (USB ou Wi-Fi, nunca emulador) — procedimento em `apps/mobile/simtc/README.md`.
- MVVM + Repository: um `ChangeNotifier` por tela; tela nunca chama `Dio`/Drift direto. Repository que fala com a rede devolve o `Result<T>` de `lib/utils/result.dart`; os métodos só locais (como todo o `AssessmentRepository`) devolvem o valor direto.
- `ConnectivityService` e `AssessmentSyncService` únicos, criados no `AppDependencies`, nunca dentro de uma tela.
- Composição "quebra-cabeça": cada tela decompõe a UI em métodos privados `Widget _buildX()` combinados num `build()` enxuto.
- Design System: nenhum `Color(0xFF…)`, nenhum número mágico de espaçamento e nenhum `TextStyle` literal fora de `lib/ui/core/theme/`; **nunca trocar `fontSize` num `.copyWith()`** fora do tema (cor, peso e espaçamento de letra, sim). Aritmética sobre tokens (`AppSpacing.sm + 2`) é o padrão aceito.
- Alvos de toque mínimos de 48dp (`AppSpacing.touchTarget`); skeleton no lugar de spinner; estados de erro e vazio explícitos.
- Contratos reais apenas — nenhum campo ou endpoint não confirmado no código do backend.
- TDD: teste falhando pelo motivo certo → implementação → teste passando.
- **Widget test com Drift de verdade** usa `AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true))`.
- Nos testes que importam `package:drift/drift.dart` inteiro, esconder `isNull` e `isNotNull` (conflitam com os matchers do `flutter_test`).
- Alguns arquivos do app são CRLF (por exemplo `assessment_repository.dart`, `participant_repository.dart`, `assessment_sync_service.dart`, `app_typography.dart`, `session_detail_screen.dart`): ao editar, preservar o fim de linha que o arquivo já usa.

Nas Tasks 1 e 2 (backend), os caminhos são a partir da raiz do repositório. Nas Tasks 3 a 10 (app), todos os caminhos de código são relativos a `apps/mobile/simtc/`, e os comandos rodam a partir dessa pasta.

## Review Focus

Os cinco casos que o desenho implica, que um consultor real vai encontrar, e onde cada um ficou preso num teste:

1. **Dois toques rápidos em "Reavaliar"** (sinal fraco, a resposta demora) → uma reserva só. Preso em: `dois toques rápidos em "Reavaliar" reservam uma vez só` (Task 7).
2. **"Reavaliar" com outra avaliação em andamento** → a reserva acontece mesmo assim, e o checklist mostra o aviso de uma por vez em vez de deixar iniciar. Preso em: `"Reavaliar" com outra avaliação em andamento: reserva mesmo assim, e o checklist avisa que só dá uma por vez` (Task 8).
3. **Desatribuir que o servidor recusa** (o painel passou o participante para outro consultor) com a avaliação iniciada → nada muda no aparelho, o motivo aparece e a sessão é baixada de novo. Preso em: `se o backend recusa, nada muda no aparelho, o motivo aparece e a sessão é baixada de novo` (Task 5).
4. **"Descartar" na aba de algo que deixou de ser recusa** (reenviado e aceito enquanto o diálogo estava aberto, ou falha de rede) → não apaga. Preso em: `descartar uma falha só apaga a avaliação em erro com o motivo pedido` (Task 3) e `"Descartar" não apaga a avaliação que falhou por rede` (Task 10).
5. **Abrir o Resultado logo depois do "Confirmar", sem sinal** → os dados do aparelho na hora, com "Na fila de envio…", sem esperar o servidor. Preso em: `logo depois do "Confirmar": os dados do aparelho, o aviso de fila e nenhuma busca no servidor` (Task 7).

## Estado herdado (ponto de partida)

HEAD = o commit deste plano, sobre `c8ac45b` (registro da validação da 5A no aparelho). App: `flutter analyze` limpo; **403 testes passando**. Backend (com as mudanças da assinatura ainda soltas no working tree): `npx jest` com **12 falhas antigas e 58 testes passando** (70 no total).

Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| Atribuição no backend | `apps/backend/src/practical-assessments/` | `assignParticipants(dto, consultantIdFromJwt, userId)`; `AssignParticipantsDto { participantIds: string[] }`; `resolveConsultantId`; `getApprovalStatus` de `@simtc/shared-types` |
| Avaliação do servidor | backend `findByParticipant` | `GET /practical-assessments/by-participant/:id` → a avaliação com `items[].infractionNote.infraction.category`, ou 200 sem corpo |
| Avaliação local | `lib/data/repositories/assessment_repository.dart` | `findCurrent`, `findInProgressOther`, `openDraft`, `findByParticipant`, `loadItems`, `confirm`, `saveSendResults`, `watchSessionAssessments`; `_delete` (rascunho + marcações) |
| Participantes | `lib/data/repositories/participant_repository.dart` | `syncSession` → `Result<int>`; `watchParticipant`; `findParticipant`; `assign(id, consultantId:, consultantName:)` → `Result<void>` (atualiza o cache na hora) |
| Envio | `lib/data/services/assessment_sync_service.dart` | `queue`, `isSending`, `isSendingItem`, `syncNow`; `SendFailure.refused` ("recusada pelo servidor") |
| Checklist | `lib/ui/checklist/` | `ChecklistViewModel` (`isStarted`, `start`, `isBlocked`, `blockingParticipantName`); `buildChecklistSections`, `overallScoreOf`, `infractionCountLabel`; `CategoryCodeChip`, `ScoreBadge` |
| 1.6 | `lib/ui/summary/summary_screen.dart` | `SummaryExit` (`SummaryConfirmed`, `SummaryReviewCategory`); a pílula `_ResultPill` (sai na Task 8) |
| Detalhe | `lib/ui/session_detail/` | `opensChecklist`, `opensResult`, `localProgressFor` (`draft`/`queued`/`failed`/`sent`); `_tapActionFor` |
| Rotas | `lib/router.dart` | `AppRoutes.participantResult(sessionId, participantId)` → hoje a `EvaluationPlaceholderScreen` (sai na Task 8) |
| Rótulos | `lib/ui/core/date_labels.dart`, `score_labels.dart` | `clockLabel`, `atLabel`; `percentLabel` |
| Widgets do DS | `lib/ui/core/widgets/` | `AppTopBar`, `AppCtaButton`, `AppSecondaryButton`, `InlineNotice` (`NoticeTone`), `SkeletonListItem` |
| Aba Sincronizar | `lib/ui/sync/sync_screen.dart` | sem ViewModel; `_RetryButton`; `queueItemTitle`, `queueItemStateOf` |
| Testes | `test/support/fake_assessment_sync_service.dart` | `FakeAssessmentSyncService`, `queuedAssessment(...)` |

## Mapa de Arquivos

### Novos

| Arquivo | Task | Responsabilidade |
|---|---|---|
| `lib/data/models/remote_assessment.dart` | 6 | `RemoteAssessment`, `RemoteAssessmentItem` (resposta do `by-participant`) |
| `lib/ui/result/result_details.dart` | 7 | `ResultCategory`, `ResultInfraction`; `resultFromLocal`, `resultFromRemote`, `infractionCountOf` |
| `lib/ui/result/result_viewmodel.dart` | 7 | estado da 1.8: fonte dos dados, avisos, "Reavaliar" |
| `lib/ui/result/result_screen.dart` | 8 | tela 1.8 |
| `lib/ui/core/widgets/final_score_block.dart` | 8 | topo da 1.6 e da 1.8 |
| `test/ui/result/result_details_test.dart` | 7 | |
| `test/ui/result/result_viewmodel_test.dart` | 7 | |
| `test/ui/result/result_screen_test.dart` | 8 | |

### Modificados

| Arquivo | Tasks | O que muda |
|---|---|---|
| `apps/backend/prisma/schema.prisma`, `prisma/migrations/20260920120000_…`, `src/practical-assessments/*` | 1 | commit da remoção da assinatura, como está no working tree |
| `apps/backend/src/practical-assessments/practical-assessments.{controller,service}.ts` | 2 | `POST /practical-assessments/unassign`, `unassignParticipants` |
| `lib/data/repositories/assessment_repository.dart` | 3 | `discardDraft`, `discardFailed` |
| `lib/data/repositories/participant_repository.dart` | 3, 6 | `unassign`; (6) `fetchAssessment` |
| `lib/ui/checklist/checklist_viewmodel.dart` | 4, 5 | `isConfirmed`, `discard`, mensagens; (5) `consultantId`, `canUnassign`, `unassign` |
| `lib/ui/checklist/checklist_screen.dart` | 4, 5, 9 | menu ⋮, somente leitura, aviso de uma por vez; (5) "Desatribuir"; (9) "Confirmar" abre o Resultado |
| `lib/ui/core/theme/app_icons.dart` | 4, 8, 10 | `more`; `close`; `discard` |
| `lib/ui/core/theme/app_typography.dart` | 8 | `resultNoteBadge` |
| `lib/ui/core/widgets/app_top_bar.dart`, `app_buttons.dart` | 8 | ícone da esquerda configurável; `trailingIcon` |
| `lib/ui/summary/summary_screen.dart` | 8 | usa o `FinalScoreBlock` |
| `lib/router.dart` | 8 | a rota do Resultado abre a `ResultScreen`; `justConfirmed` |
| `lib/ui/evaluation/evaluation_placeholder_screen.dart` | 8 | **apagado** |
| `lib/ui/session_detail/session_detail_screen.dart` | 8, 9 | sem `extra` no toque; comentário |
| `lib/ui/session_detail/session_detail_viewmodel.dart` | 9 | `opensResult` também para a avaliação confirmada do aparelho |
| `lib/data/services/assessment_sync_service.dart` | 10 | `discardRefused` |
| `lib/ui/sync/sync_screen.dart` | 10 | "Descartar" no item recusado |
| testes existentes | 2–10 | ver cada task |

---

## Task 1: Commitar a remoção da assinatura do participante (mudanças que já estão no working tree)

Em 20/09/2026 a assinatura do participante saiu do app (passou para o formulário web de inscrição), e as mudanças do backend correspondentes ficaram no working tree sem commit: o campo `participantSignatureUrl` sai do schema (com a migração), as rotas de upload e de URL assinada saem do controller, o `StorageModule` sai do módulo e o `assessmentId` sai da resposta do sync (o app nunca o usou). O endpoint da Task 2 mexe nesses mesmos arquivos, então elas vão antes, num commit próprio, **como estão** — esta task não edita nada (autorizado pelo usuário em 01/10/2026). Os comandos rodam a partir da raiz do repositório.

**Files:**
- Commit (já modificados no working tree): `apps/backend/prisma/schema.prisma`, `apps/backend/prisma/migrations/20260920120000_remove_participant_signature_from_assessment/migration.sql` (novo), `apps/backend/src/practical-assessments/practical-assessments.controller.ts`, `apps/backend/src/practical-assessments/practical-assessments.module.ts`, `apps/backend/src/practical-assessments/practical-assessments.service.ts`, `apps/backend/test/practical-assessments.controller.spec.ts` (apagado), `apps/backend/test/practical-assessments.service.spec.ts`

**Interfaces:**
- Consumes: —
- Produces: `PracticalAssessment` sem `participantSignatureUrl`; `PracticalAssessmentsService` sem `StorageService`; a resposta do `POST /practical-assessments/sync` sem `assessmentId`.

- [ ] **Step 1: Conferir o que está no working tree**

Run: `git status --short apps/backend`
Esperado, exatamente:

```
 M apps/backend/prisma/schema.prisma
 M apps/backend/src/practical-assessments/practical-assessments.controller.ts
 M apps/backend/src/practical-assessments/practical-assessments.module.ts
 M apps/backend/src/practical-assessments/practical-assessments.service.ts
 D apps/backend/test/practical-assessments.controller.spec.ts
 M apps/backend/test/practical-assessments.service.spec.ts
?? apps/backend/prisma/migrations/20260920120000_remove_participant_signature_from_assessment/
?? apps/backend/test-render.js
```

O `test-render.js` não é desta fase e fica de fora. **Qualquer outro arquivo do backend na lista: parar e perguntar ao usuário.**

- [ ] **Step 2: Conferir o conteúdo**

Run: `git diff -- apps/backend/prisma/schema.prisma apps/backend/src/practical-assessments apps/backend/test` e `cat apps/backend/prisma/migrations/20260920120000_remove_participant_signature_from_assessment/migration.sql`
Esperado: só remoções ligadas à assinatura — o campo `participantSignatureUrl` (schema), as rotas `PATCH :id/participant-signature` e `GET :id/participant-signature-url` e os imports que só elas usavam (controller), o `StorageModule` (module), o `StorageService`, `uploadParticipantSignature`, `getParticipantSignatureSignedUrl` e o `assessmentId` da resposta do sync (service), e os testes dessas partes. A migração tem uma linha: `ALTER TABLE "PracticalAssessment" DROP COLUMN "participantSignatureUrl";`. **Qualquer outra mudança: parar e perguntar.**

- [ ] **Step 3: Rodar os testes do backend**

Run: `cd apps/backend && npx jest`
Esperado: `Tests: 12 failed, 58 passed, 70 total` — as 12 falhas antigas de `auth.service.spec.ts` e `participants.service.spec.ts`; `practical-assessments.service.spec.ts` passa inteiro.

- [ ] **Step 4: Commit**

A partir da raiz do repositório (o `git add` do arquivo apagado registra a remoção):

```bash
git add apps/backend/prisma/schema.prisma apps/backend/prisma/migrations/20260920120000_remove_participant_signature_from_assessment/migration.sql apps/backend/src/practical-assessments/practical-assessments.controller.ts apps/backend/src/practical-assessments/practical-assessments.module.ts apps/backend/src/practical-assessments/practical-assessments.service.ts apps/backend/test/practical-assessments.controller.spec.ts apps/backend/test/practical-assessments.service.spec.ts
git commit -m "refactor(practical-assessments): remove a assinatura do participante da avaliacao"
```

---

## Task 2: Backend — `POST /practical-assessments/unassign`

O "Desatribuir participante" do app (decisão 8) precisa liberar a reserva no servidor, e não existe endpoint para isso (nem o painel web desatribui). O novo endpoint tem o mesmo corpo do `assign` e a regra da decisão 9: só quem está com o participante libera, e ele volta ao status de antes — "Pendente" sem avaliação, ou o status da nota anterior numa reavaliação (o `assign` recusa aprovados, então na prática é "Necessita reavaliação"). Os comandos rodam a partir da raiz do repositório, exceto os `npx jest`.

**Files:**
- Modify: `apps/backend/src/practical-assessments/practical-assessments.service.ts` — `unassignParticipants`
- Modify: `apps/backend/src/practical-assessments/practical-assessments.controller.ts` — `POST unassign`
- Test: `apps/backend/test/practical-assessments.service.spec.ts`

**Interfaces:**
- Consumes: `AssignParticipantsDto`, `resolveConsultantId`, `getApprovalStatus` (já existem).
- Produces: `POST /practical-assessments/unassign` com `{ participantIds: string[] }` → **201** `{ unassigned: number }`; **409** "Um ou mais participantes não foram encontrados" ou "Um ou mais participantes não estão atribuídos a você".

- [ ] **Step 1: Escrever os testes que falham**

Em `apps/backend/test/practical-assessments.service.spec.ts`:

Substituir:

```ts

  // ─── syncFromMobile ──────────────────────────────────────────────────────
```

por:

```ts

  // ─── unassignParticipants ────────────────────────────────────────────────

  describe('unassignParticipants', () => {
    it('lança ConflictException se algum participante não existe', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: null },
      ]);
      await expect(
        service.unassignParticipants({ participantIds: ['tp-1', 'tp-2'] }, 'meu-consultor'),
      ).rejects.toThrow(ConflictException);
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    it('lança ConflictException se o participante não está em avaliação com quem pediu', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'outro-consultor', assessment: null },
      ]);
      await expect(
        service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor'),
      ).rejects.toThrow('Um ou mais participantes não estão atribuídos a você');

      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'PENDENTE', assignedConsultantId: null, assessment: null },
      ]);
      await expect(
        service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor'),
      ).rejects.toThrow(ConflictException);
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    it('libera a atribuição e devolve o status anterior: Pendente sem avaliação, o da nota numa reavaliação', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: null },
        { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: { score: 62.5 } },
      ]);
      mockPrisma.trainingParticipant.update.mockImplementation((args) => args);
      mockPrisma.$transaction.mockResolvedValue([]);

      const result = await service.unassignParticipants(
        { participantIds: ['tp-1', 'tp-2'] },
        'meu-consultor',
      );

      expect(result).toEqual({ unassigned: 2 });
      expect(mockPrisma.trainingParticipant.findMany).toHaveBeenCalledWith({
        where: { id: { in: ['tp-1', 'tp-2'] } },
        include: { assessment: { select: { score: true } } },
      });
      expect(mockPrisma.$transaction).toHaveBeenCalledWith([
        { where: { id: 'tp-1' }, data: { assignedConsultantId: null, status: 'PENDENTE' } },
        { where: { id: 'tp-2' }, data: { assignedConsultantId: null, status: 'NECESSITA_REAVALIACAO' } },
      ]);
    });
  });

  // ─── syncFromMobile ──────────────────────────────────────────────────────
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `cd apps/backend && npx jest test/practical-assessments.service.spec.ts`
Esperado: a suíte não compila — `TS2551: Property 'unassignParticipants' does not exist on type 'PracticalAssessmentsService'. Did you mean 'assignParticipants'?`.

- [ ] **Step 3: Implementar**

Em `apps/backend/src/practical-assessments/practical-assessments.service.ts`:

Substituir:

```ts
  }
}
```

por:

```ts
  }

  /**
   * Libera participantes atribuídos ao consultor logado (o "Desatribuir" do
   * app mobile). Só quem está com o participante pode liberá-lo; ele volta ao
   * status de antes da atribuição: `PENDENTE` se nunca foi avaliado, ou o
   * status da nota da avaliação anterior numa reavaliação.
   */
  async unassignParticipants(dto: AssignParticipantsDto, consultantIdFromJwt?: string, userId?: string) {
    const consultantId = await this.resolveConsultantId(consultantIdFromJwt, userId);
    const records = await this.prisma.trainingParticipant.findMany({
      where: { id: { in: dto.participantIds } },
      include: { assessment: { select: { score: true } } },
    });

    if (records.length !== dto.participantIds.length) {
      throw new ConflictException('Um ou mais participantes não foram encontrados');
    }

    const notMine = records.filter(
      (r) => r.status !== 'EM_AVALIACAO' || r.assignedConsultantId !== consultantId,
    );
    if (notMine.length > 0) {
      throw new ConflictException('Um ou mais participantes não estão atribuídos a você');
    }

    await this.prisma.$transaction(
      records.map((r) => {
        const score = r.assessment?.score;
        return this.prisma.trainingParticipant.update({
          where: { id: r.id },
          data: {
            assignedConsultantId: null,
            status: score != null ? getApprovalStatus(score) : 'PENDENTE',
          },
        });
      }),
    );

    return { unassigned: records.length };
  }
}
```

Em `apps/backend/src/practical-assessments/practical-assessments.controller.ts`:

Substituir:

```ts

  @Post('sync')
```

por:

```ts

  @Post('unassign')
  @ApiOperation({ summary: 'Libera participantes atribuídos ao consultor logado (voltam ao status anterior)' })
  unassign(@Body() dto: AssignParticipantsDto, @CurrentUser() user: JwtPayload) {
    return this.service.unassignParticipants(dto, user.consultantId, user.sub);
  }

  @Post('sync')
```

- [ ] **Step 4: Rodar tudo**

Run: `cd apps/backend && npx jest`
Esperado: `Tests: 12 failed, 61 passed, 73 total` — as mesmas 12 falhas antigas.

- [ ] **Step 5: Commit**

```bash
git add apps/backend/src/practical-assessments/practical-assessments.service.ts apps/backend/src/practical-assessments/practical-assessments.controller.ts apps/backend/test/practical-assessments.service.spec.ts
git commit -m "feat(practical-assessments): libera o participante atribuido ao consultor"
```

---

## Task 3: Descartar e desatribuir nos repositórios

A base local das ações novas. Os dois descartes conferem a situação **na mesma transação** em que apagam: um rascunho confirmado no meio do caminho não é apagado pelo "Descartar avaliação", e um item reenviado e aceito enquanto o diálogo da aba estava aberto não é apagado pelo "Descartar" de lá. O `unassign` segue o padrão do `assign`: chama o backend e, com sucesso, já muda a linha do cache — pela mesma regra do backend.

**Files:**
- Modify: `lib/data/repositories/assessment_repository.dart` — `discardDraft`, `discardFailed`
- Modify: `lib/data/repositories/participant_repository.dart` — `unassign`
- Test: `test/data/repositories/assessment_repository_test.dart`, `test/data/repositories/participant_repository_test.dart`

**Interfaces:**
- Consumes: `POST /practical-assessments/unassign` (Task 2); `getApprovalStatus` de `lib/utils/scoring.dart`.
- Produces:
  - `Future<bool> AssessmentRepository.discardDraft(String localAssessmentId)` — apaga só rascunho; `false` se a avaliação foi confirmada ou não existe.
  - `Future<bool> AssessmentRepository.discardFailed(String localAssessmentId, {required String reason})` — apaga só a avaliação em `error` com `lastError == reason`.
  - `Future<Result<void>> ParticipantRepository.unassign(String participantId)` — mensagens: a do 409 e a de rede como vêm; o resto, "Não foi possível desatribuir o participante. Tente de novo.".

- [ ] **Step 1: Escrever os testes que falham**

Em `test/data/repositories/assessment_repository_test.dart`:

Substituir:

```dart

  group('confirm', () {
```

por:

```dart

  group('descartar', () {
    test(
        'descartar o rascunho apaga a avaliação e as marcações — o participante '
        'volta a "não iniciada"', () async {
      final draft = await open('tp-1');
      await repository.mark(
        localAssessmentId: draft.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );

      final discarded = await repository.discardDraft(draft.id);

      expect(discarded, isTrue);
      expect(await db.select(db.localAssessments).get(), isEmpty);
      expect(await db.select(db.localAssessmentItems).get(), isEmpty);
      expect(
        await repository.findCurrent(trainingParticipantId: 'tp-1', ownerUserId: 'user-1'),
        isNull,
      );
    });

    test('avaliação confirmada não é rascunho: descartar não apaga nada', () async {
      final queued = await open('tp-1');
      await repository.confirm(queued.id, participantName: 'Ana', score: 90);

      expect(await repository.discardDraft(queued.id), isFalse);
      expect((await row(queued.id)).syncStatus, LocalSyncStatus.pendingSync);
    });

    test(
        'descartar uma falha só apaga a avaliação em erro com o motivo pedido',
        () async {
      final refused = await open('tp-1');
      await repository.confirm(refused.id, participantName: 'Ana', score: 90);
      await repository.saveSendResults(
        {refused.id: 'recusada pelo servidor'},
        at: DateTime(2026, 9, 30, 9),
      );
      final queued = await insertDraft('tp-2');
      await repository.confirm(queued.id, participantName: 'Bia', score: 90);

      expect(
        await repository.discardFailed(refused.id, reason: 'sem conexão'),
        isFalse,
        reason: 'outro motivo',
      );
      expect(
        await repository.discardFailed(queued.id, reason: 'recusada pelo servidor'),
        isFalse,
        reason: 'na fila, sem erro',
      );
      expect(
        await repository.discardFailed(refused.id, reason: 'recusada pelo servidor'),
        isTrue,
      );
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.id), [queued.id]);
    });
  });

  group('confirm', () {
```

Em `test/data/repositories/participant_repository_test.dart`:

Substituir (1 de 2):

```dart
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
```

por:

```dart
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
```

Substituir (2 de 2):

```dart
  });
}
```

por:

```dart
  });

  group('unassign', () {
    const unassignPath = '/practical-assessments/unassign';

    Future<void> seedMine({double? score}) async {
      await seedSession();
      await db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-1',
              sessionId: 'sess-1',
              name: 'Carlos Eduardo Nunes',
              cpf: '187.443.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'EM_AVALIACAO',
              assignedConsultantId: const Value('c-1'),
              assignedConsultantName: const Value('Carla Souza'),
              score: Value(score),
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );
    }

    void answerOk() {
      when(() => api.post<Map<String, dynamic>>(unassignPath,
          data: any(named: 'data'))).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: unassignPath),
          statusCode: 201,
          data: {'unassigned': 1},
        ),
      );
    }

    test('libera no backend e já devolve a linha local a "Pendente"', () async {
      await seedMine();
      answerOk();

      final result = await repository.unassign('tp-1');

      expect(result.isSuccess, isTrue);
      final sent = verify(() => api.post<Map<String, dynamic>>(unassignPath,
          data: captureAny(named: 'data'))).captured.single;
      expect(sent, {
        'participantIds': ['tp-1'],
      });
      final row = await db.select(db.participants).getSingle();
      expect(row.status, ParticipantStatus.pendente.wireValue);
      expect(row.assignedConsultantId, isNull);
      expect(row.assignedConsultantName, isNull);
    });

    test('numa reavaliação, a linha volta ao status da nota anterior', () async {
      await seedMine(score: 62.5);
      answerOk();

      await repository.unassign('tp-1');

      final row = await db.select(db.participants).getSingle();
      expect(row.status, ParticipantStatus.necessitaReavaliacao.wireValue);
      expect(row.score, 62.5);
    });

    test('409 devolve o motivo e não mexe na linha local', () async {
      await seedMine();
      when(() => api.post<Map<String, dynamic>>(unassignPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(
          message: 'Um ou mais participantes não estão atribuídos a você',
          statusCode: 409,
        ),
      );

      final result = await repository.unassign('tp-1');

      expect(
        result,
        isA<Failure<void>>().having((f) => f.message, 'message',
            'Um ou mais participantes não estão atribuídos a você'),
      );
      final row = await db.select(db.participants).getSingle();
      expect(row.status, 'EM_AVALIACAO');
      expect(row.assignedConsultantId, 'c-1');
    });

    test('sem rede, a mensagem de falta de conexão', () async {
      await seedMine();
      when(() => api.post<Map<String, dynamic>>(unassignPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(message: 'Sem conexão', isNetworkError: true),
      );

      final result = await repository.unassign('tp-1');

      expect(
        result,
        isA<Failure<void>>().having((f) => f.message, 'message', 'Sem conexão'),
      );
    });

    test('erro inesperado do servidor vira uma mensagem genérica', () async {
      await seedMine();
      when(() => api.post<Map<String, dynamic>>(unassignPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(message: 'Internal server error', statusCode: 500),
      );

      final result = await repository.unassign('tp-1');

      expect(
        result,
        isA<Failure<void>>().having((f) => f.message, 'message',
            'Não foi possível desatribuir o participante. Tente de novo.'),
      );
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/data/repositories/assessment_repository_test.dart test/data/repositories/participant_repository_test.dart`
Esperado: os dois arquivos não compilam — `The method 'discardDraft' isn't defined for the type 'AssessmentRepository'` (e `discardFailed`), `The method 'unassign' isn't defined for the type 'ParticipantRepository'`.

- [ ] **Step 3: Implementar**

Em `lib/data/repositories/assessment_repository.dart`:

Substituir:

```dart
    };
  }
```

por:

```dart
    };
  }

  /// "Descartar avaliação" (decisão de 01/10/2026): apaga o rascunho e as
  /// marcações — o participante volta a "não iniciada" e continua com quem
  /// estava. Só apaga rascunho: devolve `false` (e não mexe em nada) se a
  /// avaliação já foi confirmada ou não existe mais.
  Future<bool> discardDraft(String localAssessmentId) {
    return _discardWhere(
      localAssessmentId,
      (row) => row.syncStatus == LocalSyncStatus.draft,
    );
  }

  /// "Descartar" da aba Sincronizar: apaga a avaliação que o envio deixou em
  /// erro com o motivo [reason] — na prática, "recusada pelo servidor". Se no
  /// meio do caminho ela foi reenviada e aceita, ou o motivo mudou, devolve
  /// `false` e não apaga.
  Future<bool> discardFailed(String localAssessmentId, {required String reason}) {
    return _discardWhere(
      localAssessmentId,
      (row) => row.syncStatus == LocalSyncStatus.error && row.lastError == reason,
    );
  }

  Future<bool> _discardWhere(
    String localAssessmentId,
    bool Function(LocalAssessment row) allowed,
  ) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.localAssessments)
            ..where((t) => t.id.equals(localAssessmentId)))
          .getSingleOrNull();
      if (row == null || !allowed(row)) return false;
      await _delete(localAssessmentId);
      return true;
    });
  }
```

Em `lib/data/repositories/participant_repository.dart`:

Substituir (1 de 4):

```dart
import '../../utils/result.dart';
import '../models/session_participant.dart';
```

por:

```dart
import '../../utils/result.dart';
import '../../utils/scoring.dart';
import '../models/session_participant.dart';
```

Substituir (2 de 4):

```dart
  static const String _assignPath = '/practical-assessments/assign';
```

por:

```dart
  static const String _assignPath = '/practical-assessments/assign';
  static const String _unassignPath = '/practical-assessments/unassign';
```

Substituir (3 de 4):

```dart
      'Não foi possível atribuir o participante. Tente de novo.';
```

por:

```dart
      'Não foi possível atribuir o participante. Tente de novo.';
  static const String _unassignFailed =
      'Não foi possível desatribuir o participante. Tente de novo.';
```

Substituir (4 de 4):

```dart
  }
}
```

por:

```dart
  }

  /// "Desatribuir participante" (decisão de 01/10/2026): libera no backend
  /// (`POST /practical-assessments/unassign`) o participante reservado para o
  /// consultor logado.
  ///
  /// Precisa de conexão, como o [assign]. Com sucesso, a linha local muda na
  /// hora pela mesma regra do backend: sem atribuição, e de volta ao status de
  /// antes — "Pendente" se nunca foi avaliado, ou o da nota anterior numa
  /// reavaliação.
  Future<Result<void>> unassign(String participantId) async {
    try {
      await _api.post<Map<String, dynamic>>(
        _unassignPath,
        data: {
          'participantIds': [participantId],
        },
      );
    } on ApiException catch (error) {
      // 409: "não estão atribuídos a você" (o painel passou o participante
      // para outro consultor, por exemplo). Sem rede, a mensagem do
      // `ApiException` já diz o que fazer.
      final ownMessage = error.statusCode == 409 || error.isNetworkError;
      return Failure(error, ownMessage ? error.message : _unassignFailed);
    } catch (error) {
      return Failure(Exception('$error'), _unassignFailed);
    }

    try {
      final row = await (_db.select(_db.participants)
            ..where((t) => t.id.equals(participantId)))
          .getSingleOrNull();
      final score = row?.score;
      await (_db.update(_db.participants)
            ..where((t) => t.id.equals(participantId)))
          .write(
        ParticipantsCompanion(
          status: Value(score != null
              ? getApprovalStatus(score)
              : ParticipantStatus.pendente.wireValue),
          assignedConsultantId: const Value(null),
          assignedConsultantName: const Value(null),
        ),
      );
    } catch (_) {
      // O backend já liberou — isso é o que importa. O próximo sync da
      // sessão corrige a linha.
    }
    return const Success<void>(null);
  }
}
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **411 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/assessment_repository.dart lib/data/repositories/participant_repository.dart test/data/repositories/assessment_repository_test.dart test/data/repositories/participant_repository_test.dart
git commit -m "feat(mobile): descartar avaliacao e desatribuir participante nos repositorios"
```

---

## Task 4: Checklist — "Descartar avaliação" e somente leitura

O menu ⋮ entra no canto direito do cabeçalho com o "Descartar avaliação" (decisão 7): confirmação, e a tela volta a "não iniciada" — conferindo de novo a regra de uma por vez. A avaliação já confirmada (na fila ou com erro) abre só para leitura (decisão 13). O aviso de uma por vez passa a falar em "finalizar ou descartar". Com o menu ao lado, a hora de início do cabeçalho encolhe com reticências.

**Files:**
- Modify: `lib/ui/checklist/checklist_viewmodel.dart`
- Modify: `lib/ui/checklist/checklist_screen.dart`
- Modify: `lib/ui/core/theme/app_icons.dart` — `more`
- Test: `test/ui/checklist/checklist_viewmodel_test.dart`, `test/ui/checklist/checklist_screen_test.dart`

**Interfaces:**
- Consumes: `AssessmentRepository.discardDraft` (Task 3); `findInProgressOther`.
- Produces:
  - `ChecklistViewModel`: `bool isConfirmed`, `bool canDiscard`, `bool isDiscarding`, `Future<void> discard()`, `String? message`, `void clearMessage()`.
  - `AppIcons.more` (`Icons.more_vert`); o menu tem a chave `Key('checklist-menu')`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/checklist/checklist_viewmodel_test.dart`:

Substituir:

```dart

  group('startedText', () {
```

por:

```dart

  group('descartar', () {
    test(
        'descartar apaga o rascunho e volta a "não iniciada" — e o "Iniciar" '
        'volta a valer', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();
      await vm.toggleNote('inf-1', 'note-m');
      expect(vm.canDiscard, isTrue);

      await vm.discard();

      expect(vm.isStarted, isFalse);
      expect(vm.canDiscard, isFalse);
      expect(vm.startedText, isNull);
      expect(vm.overallScore, 100, reason: 'as marcações saíram junto');
      expect(await db.select(db.localAssessments).get(), isEmpty);
      expect(await db.select(db.localAssessmentItems).get(), isEmpty);

      await vm.start();

      expect(vm.isStarted, isTrue);
      expect(vm.overallScore, 100);
    });

    test(
        'avaliação confirmada abre só para leitura: não muda nota nem é '
        'descartada', () async {
      await seedParticipant();
      await seedCatalog();
      final draft = await assessmentRepository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
      );
      await assessmentRepository.mark(
        localAssessmentId: draft.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      await assessmentRepository.confirm(draft.id, participantName: 'Carlos', score: 96);
      final vm = buildViewModel();
      addTearDown(vm.dispose);

      await vm.init();

      expect(vm.isStarted, isTrue);
      expect(vm.isConfirmed, isTrue);
      expect(vm.canDiscard, isFalse);

      await vm.toggleNote('inf-1', 'note-m');
      await vm.discard();

      final item = await db.select(db.localAssessmentItems).getSingle();
      expect(item.infractionNoteId, 'note-b', reason: 'a nota não mudou');
      final row = await db.select(db.localAssessments).getSingle();
      expect(row.syncStatus, LocalSyncStatus.pendingSync);
    });
  });

  group('startedText', () {
```

Em `test/ui/checklist/checklist_screen_test.dart`:

Substituir (1 de 3):

```dart

  testWidgets('sem catálogo no aparelho, avisa e não oferece "Finalizar"',
```

por:

```dart

  testWidgets(
      'menu ⋮ "Descartar avaliação" pede confirmação: "Cancelar" não muda '
      'nada, "Descartar" volta a "não iniciada"', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checklist-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar avaliação'));
    await tester.pumpAndSettle();

    expect(find.text('Descartar a avaliação?'), findsOneWidget);
    expect(
      find.text('As marcações e a hora de início de Ana Paula Ribeiro serão '
          'apagadas. O participante continua com você.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text(pmComment), findsOneWidget, reason: 'nada mudou');

    await tester.tap(find.byKey(const Key('checklist-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar avaliação'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('não iniciada'), findsOneWidget);
    expect(find.text('Iniciar avaliação'), findsOneWidget);
    expect(find.text('Excesso de velocidade'), findsNothing);
    expect(await db.select(db.localAssessments).get(), isEmpty);
    expect(await db.select(db.localAssessmentItems).get(), isEmpty);
  });

  testWidgets(
      'avaliação já confirmada: as marcações à vista, sem mudar nota, sem '
      '"Finalizar" e sem menu', (tester) async {
    final draft = await assessmentRepository.openDraft(
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    await assessmentRepository.mark(
      localAssessmentId: draft.id,
      infractionId: 'inf-1',
      infractionNoteId: 'note-pm',
    );
    await assessmentRepository.confirm(draft.id, participantName: 'Ana', score: 88);

    await pumpScreen(tester, started: false);

    expect(find.text('Avaliação confirmada — não pode mais ser alterada.'),
        findsOneWidget);
    expect(find.text(pmComment), findsOneWidget, reason: 'a nota marcada aparece');
    expect(find.text('Finalizar avaliação'), findsNothing);
    expect(find.byKey(const Key('checklist-menu')), findsNothing);

    await tester.tap(find.text('M'));
    await tester.pumpAndSettle();

    final item = await db.select(db.localAssessmentItems).getSingle();
    expect(item.infractionNoteId, 'note-pm');
  });

  testWidgets('sem catálogo no aparelho, avisa e não oferece "Finalizar"',
```

Substituir (2 de 3):

```dart
      expect(
        find.text('Você já está avaliando Marina Lopes. Finalize essa '
            'avaliação para iniciar outra.'),
        findsOneWidget,
```

por:

```dart
      expect(
        find.text('Você já está avaliando Marina Lopes. Finalize ou descarte '
            'essa avaliação para iniciar outra.'),
        findsOneWidget,
```

Substituir (3 de 3):

```dart
      expect(rows.map((r) => r.trainingParticipantId), ['tp-2']);
    });
```

por:

```dart
      expect(rows.map((r) => r.trainingParticipantId), ['tp-2']);
    });

    testWidgets('antes de iniciar, não há o que descartar: sem menu ⋮',
        (tester) async {
      await pumpScreen(tester, started: false);

      expect(find.byKey(const Key('checklist-menu')), findsNothing);
    });
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/ui/checklist/checklist_viewmodel_test.dart test/ui/checklist/checklist_screen_test.dart`
Esperado: `checklist_viewmodel_test.dart` não compila (`The getter 'canDiscard' isn't defined…`, `The method 'discard' isn't defined…`, `The getter 'isConfirmed' isn't defined…`); no `checklist_screen_test.dart`, falham 3: o menu ⋮ "Descartar avaliação", a avaliação já confirmada e o aviso de outro participante em andamento (texto novo). "antes de iniciar, não há o que descartar: sem menu ⋮" já passa.

- [ ] **Step 3: Implementar**

Em `lib/ui/core/theme/app_icons.dart`:

Substituir:

```dart
  static const IconData startEvaluation = Icons.play_arrow_rounded;
}
```

por:

```dart
  static const IconData startEvaluation = Icons.play_arrow_rounded;

  /// Menu ⋮ do cabeçalho do checklist (Fase 5B — não está no canvas).
  static const IconData more = Icons.more_vert;
}
```

Em `lib/ui/checklist/checklist_viewmodel.dart`:

Substituir (1 de 8):

```dart

  StreamSubscription<SessionParticipant?>? _participantSubscription;
```

por:

```dart

  static const String _discardFailed = 'Não foi possível descartar. Tente de novo.';

  StreamSubscription<SessionParticipant?>? _participantSubscription;
```

Substituir (2 de 8):

```dart
  bool _starting = false;
  String? _assessmentId;
  DateTime? _startTime;
  SessionParticipant? _participant;
```

por:

```dart
  bool _starting = false;
  bool _discarding = false;
  String? _assessmentId;
  DateTime? _startTime;
  LocalSyncStatus? _status;
  String? _message;
  SessionParticipant? _participant;
```

Substituir (3 de 8):

```dart
  bool get isStarting => _starting;
```

por:

```dart
  bool get isStarting => _starting;

  /// A avaliação já foi confirmada (na fila ou com erro de envio): o checklist
  /// mostra as marcações sem deixar mudar nada (decisão de 01/10/2026). O
  /// detalhe da sessão abre o Resultado nesses casos; aqui só se chega por
  /// outro caminho.
  bool get isConfirmed => _status != null && _status != LocalSyncStatus.draft;

  /// "Descartar avaliação" do menu ⋮: só com a avaliação iniciada e ainda em
  /// rascunho.
  bool get canDiscard => isStarted && !isConfirmed;

  /// O "Descartar avaliação" está apagando.
  bool get isDiscarding => _discarding;

  /// Aviso passageiro para a tela (SnackBar); limpo por [clearMessage].
  String? get message => _message;
```

Substituir (4 de 8):

```dart
    } else {
      final inProgress = await _assessmentRepository.findInProgressOther(
        ownerUserId: ownerUserId,
        exceptTrainingParticipantId: participantId,
      );
      if (_disposed) return;
      if (inProgress != null) {
        await _block(inProgress.trainingParticipantId);
        if (_disposed) return;
      }
    }
```

por:

```dart
    } else {
      await _checkBlock();
      if (_disposed) return;
    }
```

Substituir (5 de 8):

```dart

  /// Guarda quem está em andamento e o nome dele, para o aviso.
```

por:

```dart

  /// "Descartar avaliação" (decisão de 01/10/2026): apaga o rascunho e as
  /// marcações, e a tela volta a "não iniciada" — o participante continua com
  /// o consultor. A tela pede confirmação antes.
  Future<void> discard() async {
    final assessmentId = _assessmentId;
    if (assessmentId == null || !canDiscard || _discarding) return;

    _discarding = true;
    notifyListeners();
    try {
      final discarded = await _assessmentRepository.discardDraft(assessmentId);
      if (_disposed) return;
      if (!discarded) {
        _message = _discardFailed;
        return;
      }
      _detach();
      await _checkBlock();
    } catch (_) {
      _message = _discardFailed;
    } finally {
      _discarding = false;
      notifyListeners();
    }
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  /// Só uma avaliação por vez: confere se outro participante do consultor
  /// está em andamento, para o aviso e o "Iniciar" desabilitado.
  Future<void> _checkBlock() async {
    _blockingParticipantId = null;
    _blockingName = null;
    final inProgress = await _assessmentRepository.findInProgressOther(
      ownerUserId: ownerUserId,
      exceptTrainingParticipantId: participantId,
    );
    if (inProgress != null) await _block(inProgress.trainingParticipantId);
  }

  /// Guarda quem está em andamento e o nome dele, para o aviso.
```

Substituir (6 de 8):

```dart
    _startTime = assessment.startTime;
```

por:

```dart
    _startTime = assessment.startTime;
    _status = assessment.syncStatus;
```

Substituir (7 de 8):

```dart
    });
  }
```

por:

```dart
    });
  }

  /// Desliga a tela da avaliação descartada: volta a "não iniciada".
  void _detach() {
    _itemsSubscription?.cancel();
    _itemsSubscription = null;
    _assessmentId = null;
    _startTime = null;
    _status = null;
    _items = const [];
    _expandedCategoryId = null;
  }
```

Substituir (8 de 8):

```dart
    final assessmentId = _assessmentId;
    if (assessmentId == null) return;
```

por:

```dart
    final assessmentId = _assessmentId;
    if (assessmentId == null || isConfirmed) return;
```

Em `lib/ui/checklist/checklist_screen.dart`:

Substituir (1 de 11):

```dart
  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
```

por:

```dart
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

  /// Mesmo padrão do detalhe da sessão: o aviso é passageiro, e a mensagem é
  /// limpa assim que é agendada.
  void _showMessageWhenItArrives() {
    final message = _viewModel.message;
    if (message == null) return;
    _viewModel.clearMessage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
  }
```

Substituir (2 de 11):

```dart
            Expanded(child: _buildBody()),
            if (!_viewModel.isLoading && _viewModel.hasCatalog) _buildFooter(),
          ],
```

por:

```dart
            Expanded(child: _buildBody()),
            if (!_viewModel.isLoading && _viewModel.hasCatalog && !_viewModel.isConfirmed)
              _buildFooter(),
          ],
```

Substituir (3 de 11):

```dart
                ),
              ),
            ],
          ),
```

por:

```dart
                ),
              ),
              if (!_viewModel.isLoading && _viewModel.canDiscard) _buildMenu(),
            ],
          ),
```

Substituir (4 de 11):

```dart
        ],
      ),
    );
  }

  Widget _buildTimerRow() {
```

por:

```dart
        ],
      ),
    );
  }

  /// Menu ⋮ (decisão de 01/10/2026 — não está no canvas): "Descartar
  /// avaliação", com a avaliação iniciada.
  Widget _buildMenu() {
    return SizedBox.square(
      dimension: AppSpacing.touchTarget,
      child: PopupMenuButton<_MenuAction>(
        key: const Key('checklist-menu'),
        tooltip: 'Mais opções',
        icon: const Icon(AppIcons.more, color: AppColors.text),
        onSelected: (action) => switch (action) {
          _MenuAction.discard => _confirmDiscard(),
        },
        itemBuilder: (context) => [
          if (_viewModel.canDiscard)
            const PopupMenuItem(
              value: _MenuAction.discard,
              child: Text('Descartar avaliação'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDiscard() async {
    final name = _viewModel.participant?.name ?? 'este participante';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar a avaliação?'),
        content: Text(
          'As marcações e a hora de início de $name serão apagadas. O '
          'participante continua com você.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _viewModel.discard();
  }

  Widget _buildTimerRow() {
```

Substituir (5 de 11):

```dart
        const SizedBox(width: AppSpacing.xs),
        Text(_viewModel.startedText ?? '', style: AppTypography.meta),
        const SizedBox(width: AppSpacing.sm),
```

por:

```dart
        const SizedBox(width: AppSpacing.xs),
        // Encolhe com reticências: com o menu ⋮ ao lado, "Iniciada em 28 set
        // 08:12" não cabe inteiro num celular estreito.
        Flexible(
          child: Text(
            _viewModel.startedText ?? '',
            style: AppTypography.meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
```

Substituir (6 de 11):

```dart
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
```

por:

```dart
      children: [
        // Só leitura (decisão de 01/10/2026): a avaliação confirmada espera o
        // envio, e o que foi confirmado não muda mais.
        if (_viewModel.isConfirmed)
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
            child: InlineNotice(
              icon: AppIcons.finish,
              message: 'Avaliação confirmada — não pode mais ser alterada.',
            ),
          ),
        for (var i = 0; i < blocks.length; i++) ...[
```

Substituir (7 de 11):

```dart
                    selected: infraction.selectedNoteId == infraction.notes[i].id,
                    onTap: () => _viewModel.toggleNote(infraction.id, infraction.notes[i].id),
                  ),
```

por:

```dart
                    selected: infraction.selectedNoteId == infraction.notes[i].id,
                    onTap: _viewModel.isConfirmed
                        ? null
                        : () => _viewModel.toggleNote(infraction.id, infraction.notes[i].id),
                  ),
```

Substituir (8 de 11):

```dart
  /// Só uma avaliação por vez (decisão de 01/10/2026): o consultor precisa
  /// finalizar a que está em andamento antes de iniciar outra.
  String _blockedMessage() {
```

por:

```dart
  /// Só uma avaliação por vez (decisão de 01/10/2026): o consultor precisa
  /// finalizar ou descartar a que está em andamento antes de iniciar outra.
  String _blockedMessage() {
```

Substituir (9 de 11):

```dart
    final who = name == null ? 'com outra avaliação em andamento' : 'avaliando $name';
    return 'Você já está $who. Finalize essa avaliação para iniciar outra.';
  }
```

por:

```dart
    final who = name == null ? 'com outra avaliação em andamento' : 'avaliando $name';
    return 'Você já está $who. Finalize ou descarte essa avaliação para iniciar outra.';
  }
```

Substituir (10 de 11):

```dart

/// Um dos 3 botões B/PM/M (spec "4z"): raio 8, nunca pílula, para não se
/// confundir com os chips de status.
class _NoteButton extends StatelessWidget {
```

por:

```dart

/// O que o menu ⋮ do cabeçalho oferece.
enum _MenuAction { discard }

/// Um dos 3 botões B/PM/M (spec "4z"): raio 8, nunca pílula, para não se
/// confundir com os chips de status. Sem [onTap], é só leitura.
class _NoteButton extends StatelessWidget {
```

Substituir (11 de 11):

```dart
  final bool selected;
  final VoidCallback onTap;
```

por:

```dart
  final bool selected;
  final VoidCallback? onTap;
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **416 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/checklist/checklist_viewmodel.dart lib/ui/checklist/checklist_screen.dart lib/ui/core/theme/app_icons.dart test/ui/checklist/checklist_viewmodel_test.dart test/ui/checklist/checklist_screen_test.dart
git commit -m "feat(mobile): descartar avaliacao e checklist so leitura"
```

---

## Task 5: Checklist — "Desatribuir participante"

O segundo item do menu ⋮ (decisão 8): só quem está com o participante, com rede, e com confirmação que avisa quando a avaliação iniciada vai junto. O rascunho só é apagado depois que o backend confirma; com o 409, nada muda no aparelho, o motivo aparece e a sessão é baixada de novo. Com sucesso, o checklist fecha e o detalhe mostra "Participante desatribuído." (o SnackBar é do `ScaffoldMessenger` do app e continua na tela de baixo).

**Files:**
- Modify: `lib/ui/checklist/checklist_viewmodel.dart`
- Modify: `lib/ui/checklist/checklist_screen.dart`
- Test: `test/ui/checklist/checklist_viewmodel_test.dart`, `test/ui/checklist/checklist_screen_test.dart`

**Interfaces:**
- Consumes: `ParticipantRepository.unassign` e `AssessmentRepository.discardDraft` (Task 3); `syncSession`.
- Produces: `ChecklistViewModel({..., required String? consultantId, ...})` — `AuthUser.consultantId`; `bool canUnassign`, `bool isUnassigning`, `Future<bool> unassign()` (`true`: liberado, a tela fecha).

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/checklist/checklist_viewmodel_test.dart`:

Substituir (1 de 5):

```dart
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
```

por:

```dart
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
```

Substituir (2 de 5):

```dart
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/local/app_database.dart';
```

por:

```dart
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';
```

Substituir (3 de 5):

```dart

  ChecklistViewModel buildViewModel({DateTime Function()? now}) {
    return ChecklistViewModel(
```

por:

```dart

  ChecklistViewModel buildViewModel({
    DateTime Function()? now,
    String? consultantId = 'c-eu',
  }) {
    return ChecklistViewModel(
```

Substituir (4 de 5):

```dart
      ownerUserId: 'user-1',
      assessmentRepository: assessmentRepository,
```

por:

```dart
      ownerUserId: 'user-1',
      consultantId: consultantId,
      assessmentRepository: assessmentRepository,
```

Substituir (5 de 5):

```dart

  group('startedText', () {
```

por:

```dart

  group('desatribuir', () {
    const unassignPath = '/practical-assessments/unassign';

    Future<void> assignTo(String consultantId) {
      return (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
          .write(ParticipantsCompanion(assignedConsultantId: Value(consultantId)));
    }

    test(
        'desatribuir libera o participante no backend e apaga a avaliação '
        'iniciada', () async {
      await seedParticipant();
      await seedCatalog();
      await assignTo('c-eu');
      when(() => api.post<Map<String, dynamic>>(unassignPath, data: any(named: 'data')))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: unassignPath),
                statusCode: 201,
                data: {'unassigned': 1},
              ));
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();
      await vm.toggleNote('inf-1', 'note-b');
      expect(vm.canUnassign, isTrue);

      final unassigned = await vm.unassign();

      expect(unassigned, isTrue);
      expect(await db.select(db.localAssessments).get(), isEmpty);
      expect(await db.select(db.localAssessmentItems).get(), isEmpty);
      final row = await db.select(db.participants).getSingle();
      expect(row.status, 'PENDENTE');
      expect(row.assignedConsultantId, isNull);
    });

    test('só quem está com o participante pode desatribuir', () async {
      await seedParticipant();
      await seedCatalog();
      await assignTo('c-outro');
      final ofOther = buildViewModel();
      addTearDown(ofOther.dispose);
      await ofOther.init();
      expect(ofOther.canUnassign, isFalse, reason: 'está com outro consultor');

      await assignTo('c-eu');
      final noProfile = buildViewModel(consultantId: null);
      addTearDown(noProfile.dispose);
      await noProfile.init();
      expect(noProfile.canUnassign, isFalse, reason: 'sem perfil de consultor');

      final mine = buildViewModel();
      addTearDown(mine.dispose);
      await mine.init();
      expect(mine.canUnassign, isTrue, reason: 'antes de iniciar também');
    });

    test(
        'se o backend recusa, nada muda no aparelho, o motivo aparece e a '
        'sessão é baixada de novo', () async {
      await seedParticipant();
      await seedCatalog();
      await assignTo('c-eu');
      when(() => api.post<Map<String, dynamic>>(unassignPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Um ou mais participantes não estão atribuídos a você',
        statusCode: 409,
      ));
      when(() => api.get<Map<String, dynamic>>(any()))
          .thenThrow(const ApiException(message: 'Sem conexão', isNetworkError: true));
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();

      final unassigned = await vm.unassign();

      expect(unassigned, isFalse);
      expect(vm.message, 'Um ou mais participantes não estão atribuídos a você');
      expect(vm.isStarted, isTrue);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
      verify(() => api.get<Map<String, dynamic>>('/training-sessions/sess-1')).called(1);
    });
  });

  group('startedText', () {
```

Em `test/ui/checklist/checklist_screen_test.dart`:

Substituir (1 de 4):

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
```

por:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
```

Substituir (2 de 4):

```dart
            ),
          );
    }
  }

  Future<void> goOffline() async {
```

por:

```dart
            ),
          );
    }
  }

  /// O participante reservado para a consultora logada (`c-eu`).
  Future<void> assignToMe() {
    return (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
        .write(const ParticipantsCompanion(assignedConsultantId: Value('c-eu')));
  }

  Future<void> goOffline() async {
```

Substituir (3 de 4):

```dart

  testWidgets('sem catálogo no aparelho, avisa e não oferece "Finalizar"',
```

por:

```dart

  testWidgets(
      '"Desatribuir participante" avisa que a avaliação iniciada será '
      'descartada e, confirmado, fecha o checklist', (tester) async {
    await assignToMe();
    when(() => api.post<Map<String, dynamic>>('/practical-assessments/unassign',
        data: any(named: 'data'))).thenAnswer((_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/practical-assessments/unassign'),
          statusCode: 201,
          data: {'unassigned': 1},
        ));
    await pumpOverOrigin(tester);

    await tester.tap(find.byKey(const Key('checklist-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desatribuir participante'));
    await tester.pumpAndSettle();

    expect(find.text('Desatribuir Ana Paula Ribeiro?'), findsOneWidget);
    expect(
      find.text('Ana Paula Ribeiro volta para "Pendente" e fica disponível para '
          'outro consultor. A avaliação iniciada será descartada.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Desatribuir'));
    await tester.pumpAndSettle();

    expect(find.text('origem'), findsOneWidget);
    expect(find.text('Participante desatribuído.'), findsOneWidget);
    expect(await db.select(db.localAssessments).get(), isEmpty);
    final row = await db.select(db.participants).getSingle();
    expect(row.status, 'PENDENTE');
  });

  testWidgets('sem rede, "Desatribuir participante" fica desabilitado',
      (tester) async {
    await assignToMe();
    await goOffline();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('checklist-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    final item = tester.widget<PopupMenuItem<Object?>>(find.ancestor(
      of: find.text('Desatribuir participante'),
      matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
    ));
    expect(item.enabled, isFalse);
  });

  testWidgets('sem catálogo no aparelho, avisa e não oferece "Finalizar"',
```

Substituir (4 de 4):

```dart

    testWidgets('antes de iniciar, não há o que descartar: sem menu ⋮',
        (tester) async {
      await pumpScreen(tester, started: false);
```

por:

```dart

    testWidgets(
        'antes de iniciar, o menu ⋮ só tem "Desatribuir participante" — não '
        'há o que descartar', (tester) async {
      await assignToMe();
      await pumpScreen(tester, started: false);

      await tester.tap(find.byKey(const Key('checklist-menu')));
      await tester.pumpAndSettle();

      expect(find.text('Desatribuir participante'), findsOneWidget);
      expect(find.text('Descartar avaliação'), findsNothing);
    });

    testWidgets('de outro consultor, sem menu ⋮', (tester) async {
      await pumpScreen(tester, started: false);
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/ui/checklist/checklist_viewmodel_test.dart test/ui/checklist/checklist_screen_test.dart`
Esperado: `checklist_viewmodel_test.dart` não compila (`No named parameter with the name 'consultantId'`, `The getter 'canUnassign' isn't defined…`, `The method 'unassign' isn't defined…`); no `checklist_screen_test.dart`, falham 3: o "Desatribuir participante" com avaliação iniciada, o desabilitado sem rede e o menu antes de iniciar. "de outro consultor, sem menu ⋮" já passa.

- [ ] **Step 3: Implementar**

Em `lib/ui/checklist/checklist_viewmodel.dart`:

Substituir (1 de 7):

```dart
import '../../data/repositories/participant_repository.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/scoring.dart';
```

por:

```dart
import '../../data/repositories/participant_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/result.dart';
import '../../utils/scoring.dart';
```

Substituir (2 de 7):

```dart
    required this.ownerUserId,
    required AssessmentRepository assessmentRepository,
```

por:

```dart
    required this.ownerUserId,
    required this.consultantId,
    required AssessmentRepository assessmentRepository,
```

Substituir (3 de 7):

```dart
  final String ownerUserId;
  final AssessmentRepository _assessmentRepository;
```

por:

```dart
  final String ownerUserId;

  /// `AuthUser.consultantId` do consultor logado — quem a reserva do
  /// participante aponta. Nulo para um usuário sem perfil de consultor.
  final String? consultantId;
  final AssessmentRepository _assessmentRepository;
```

Substituir (4 de 7):

```dart
  static const String _discardFailed = 'Não foi possível descartar. Tente de novo.';
```

por:

```dart
  static const String _discardFailed = 'Não foi possível descartar. Tente de novo.';
  static const String _unassignFailed =
      'Não foi possível desatribuir o participante. Tente de novo.';
  static const String _draftNotDiscarded =
      'Participante desatribuído, mas a avaliação iniciada não foi apagada do aparelho.';
```

Substituir (5 de 7):

```dart
  bool _discarding = false;
  String? _assessmentId;
```

por:

```dart
  bool _discarding = false;
  bool _unassigning = false;
  String? _assessmentId;
```

Substituir (6 de 7):

```dart
  bool get isDiscarding => _discarding;
```

por:

```dart
  bool get isDiscarding => _discarding;

  /// "Desatribuir participante" do menu ⋮ (decisão de 01/10/2026): só quem
  /// está com o participante, e só enquanto a avaliação não foi confirmada.
  bool get canUnassign {
    final participant = _participant;
    return !isConfirmed &&
        consultantId != null &&
        participant != null &&
        participant.status == ParticipantStatus.emAvaliacao &&
        participant.assignedConsultantId == consultantId;
  }

  /// O "Desatribuir participante" está esperando o backend.
  bool get isUnassigning => _unassigning;
```

Substituir (7 de 7):

```dart

  void clearMessage() {
```

por:

```dart

  /// "Desatribuir participante": libera a reserva no backend e, se havia
  /// avaliação iniciada, apaga o rascunho — só depois que o backend confirmou;
  /// se ele recusar ou a rede falhar, nada muda no aparelho. Devolve `true`
  /// quando o participante foi liberado: a tela fecha. A tela pede
  /// confirmação antes, e só oferece com rede.
  Future<bool> unassign() async {
    if (!canUnassign || _unassigning) return false;

    _unassigning = true;
    notifyListeners();
    try {
      final result = await _participantRepository.unassign(participantId);
      switch (result) {
        case Failure(:final exception, :final message):
          _message = message ?? _unassignFailed;
          // Recusado (409): o painel passou o participante para outro
          // consultor, por exemplo — baixar a sessão mostra quem está com ele.
          if (exception is ApiException && exception.statusCode == 409) {
            unawaited(_participantRepository.syncSession(sessionId));
          }
          return false;
        case Success():
          final assessmentId = _assessmentId;
          if (assessmentId != null) {
            try {
              await _assessmentRepository.discardDraft(assessmentId);
            } catch (_) {
              _message = _draftNotDiscarded;
            }
          }
          return true;
      }
    } catch (_) {
      _message = _unassignFailed;
      return false;
    } finally {
      _unassigning = false;
      notifyListeners();
    }
  }

  void clearMessage() {
```

Em `lib/ui/checklist/checklist_screen.dart`:

Substituir (1 de 8):

```dart
    ownerUserId: context.read<AuthRepository>().currentUser!.id,
    assessmentRepository: context.read<AssessmentRepository>(),
```

por:

```dart
    ownerUserId: context.read<AuthRepository>().currentUser!.id,
    consultantId: context.read<AuthRepository>().currentUser!.consultantId,
    assessmentRepository: context.read<AssessmentRepository>(),
```

Substituir (2 de 8):

```dart
          children: [
            _buildHeader(context),
            ConnectivityBanner(
```

por:

```dart
          children: [
            _buildHeader(context, isOffline),
            ConnectivityBanner(
```

Substituir (3 de 8):

```dart

  Widget _buildHeader(BuildContext context) {
    return Container(
```

por:

```dart

  Widget _buildHeader(BuildContext context, bool isOffline) {
    return Container(
```

Substituir (4 de 8):

```dart
              ),
              if (!_viewModel.isLoading && _viewModel.canDiscard) _buildMenu(),
            ],
```

por:

```dart
              ),
              if (!_viewModel.isLoading &&
                  (_viewModel.canDiscard || _viewModel.canUnassign))
                _buildMenu(isOffline),
            ],
```

Substituir (5 de 8):

```dart
  /// Menu ⋮ (decisão de 01/10/2026 — não está no canvas): "Descartar
  /// avaliação", com a avaliação iniciada.
  Widget _buildMenu() {
    return SizedBox.square(
```

por:

```dart
  /// Menu ⋮ (decisão de 01/10/2026 — não está no canvas): "Descartar
  /// avaliação", com a avaliação iniciada, e "Desatribuir participante", que
  /// precisa de rede — offline, aparece desabilitado e diz por quê.
  Widget _buildMenu(bool isOffline) {
    return SizedBox.square(
```

Substituir (6 de 8):

```dart
          _MenuAction.discard => _confirmDiscard(),
        },
```

por:

```dart
          _MenuAction.discard => _confirmDiscard(),
          _MenuAction.unassign => _confirmUnassign(),
        },
```

Substituir (7 de 8):

```dart
              child: Text('Descartar avaliação'),
            ),
        ],
      ),
    );
  }
```

por:

```dart
              child: Text('Descartar avaliação'),
            ),
          if (_viewModel.canUnassign)
            PopupMenuItem(
              value: _MenuAction.unassign,
              enabled: !isOffline,
              child: isOffline
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Desatribuir participante'),
                        Text('Disponível quando houver conexão', style: AppTypography.meta),
                      ],
                    )
                  : const Text('Desatribuir participante'),
            ),
        ],
      ),
    );
  }

  /// Volta para "Pendente" ou, numa reavaliação, para "Necessita
  /// reavaliação" — a mesma regra do backend.
  Future<void> _confirmUnassign() async {
    final participant = _viewModel.participant;
    final name = participant?.name;
    final status = participant?.hasPreviousAssessment == true
        ? 'Necessita reavaliação'
        : 'Pendente';
    final discardNote =
        _viewModel.isStarted ? ' A avaliação iniciada será descartada.' : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(name == null ? 'Desatribuir o participante?' : 'Desatribuir $name?'),
        content: Text(
          '${name ?? 'O participante'} volta para "$status" e fica disponível '
          'para outro consultor.$discardNote',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desatribuir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final unassigned = await _viewModel.unassign();
    if (!unassigned || !mounted) return;
    // O SnackBar é do `ScaffoldMessenger` do app: continua na tela de baixo.
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Participante desatribuído.')));
    await Navigator.of(context).maybePop();
  }
```

Substituir (8 de 8):

```dart
/// O que o menu ⋮ do cabeçalho oferece.
enum _MenuAction { discard }
```

por:

```dart
/// O que o menu ⋮ do cabeçalho oferece.
enum _MenuAction { discard, unassign }
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **422 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/checklist/checklist_viewmodel.dart lib/ui/checklist/checklist_screen.dart test/ui/checklist/checklist_viewmodel_test.dart test/ui/checklist/checklist_screen_test.dart
git commit -m "feat(mobile): desatribuir participante pelo checklist"
```

---

## Task 6: A avaliação do servidor para o Resultado

O modelo da resposta do `by-participant` e a busca. Cada item vem achatado (a nota, a infração e a categoria), e um item sem as partes aninhadas fica de fora. 200 sem corpo é "sem avaliação"; resposta fora do formato vira falha com a mensagem genérica, e a falta de rede mantém a mensagem do cliente HTTP — a ViewModel da Task 7 decide o aviso pelo tipo da exceção.

**Files:**
- Create: `lib/data/models/remote_assessment.dart`
- Modify: `lib/data/repositories/participant_repository.dart` — `fetchAssessment`
- Test: `test/data/repositories/participant_repository_test.dart`

**Interfaces:**
- Consumes: `GET /practical-assessments/by-participant/:id` (já existe no backend).
- Produces:
  - `RemoteAssessment { DateTime startTime; DateTime? endTime; double? score; List<RemoteAssessmentItem> items }` e `static RemoteAssessment? tryParse(Object? json)`.
  - `RemoteAssessmentItem { infractionNoteId, noteType, comment?, deduction, infractionId, infractionDescription, infractionOrder, categoryId, categoryCode, categoryName, categoryOrder }`.
  - `Future<Result<RemoteAssessment?>> ParticipantRepository.fetchAssessment(String participantId)` — falha genérica: "Não foi possível carregar o resultado.".

- [ ] **Step 1: Escrever os testes que falham**

Em `test/data/repositories/participant_repository_test.dart`:

Substituir (1 de 2):

```dart
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/session_participant.dart';
```

por:

```dart
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/remote_assessment.dart';
import 'package:simtc/data/models/session_participant.dart';
```

Substituir (2 de 2):

```dart

  group('unassign', () {
```

por:

```dart

  group('fetchAssessment', () {
    const path = '/practical-assessments/by-participant/tp-1';

    void answer(Object? body) {
      when(() => api.get<Object?>(path)).thenAnswer(
        (_) async => Response<Object?>(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: body,
        ),
      );
    }

    /// Como o `findByParticipant` do backend devolve: cada item com a nota, a
    /// infração e a categoria aninhadas.
    Map<String, dynamic> assessmentJson() => {
          'id': 'assess-1',
          'trainingParticipantId': 'tp-1',
          'consultantId': 'c-1',
          'date': '2026-09-30T00:00:00.000Z',
          'startTime': '2026-09-30T11:12:00.000Z',
          'endTime': '2026-09-30T11:31:00.000Z',
          'synced': true,
          'score': 86.7,
          'items': [
            {
              'id': 'item-1',
              'assessmentId': 'assess-1',
              'infractionNoteId': 'note-pm-1',
              'infractionNote': {
                'id': 'note-pm-1',
                'infractionId': 'inf-1',
                'noteType': 'PM',
                'comment': 'Ajuste feito somente após solicitação',
                'deduction': 3,
                'infraction': {
                  'id': 'inf-1',
                  'categoryId': 'cat-cv',
                  'description': 'Não ajustou o banco, cinto ou espelhos',
                  'order': 1,
                  'category': {
                    'id': 'cat-cv',
                    'code': 'CV',
                    'name': 'Controle do Veículo',
                    'description': null,
                    'order': 1,
                  },
                },
              },
            },
            // Um item sem a nota aninhada não tem o que mostrar: fica de fora.
            {'id': 'item-2', 'assessmentId': 'assess-1', 'infractionNoteId': 'x'},
          ],
        };

    test('traz a avaliação do backend, com cada item achatado', () async {
      answer(assessmentJson());

      final result = await repository.fetchAssessment('tp-1');

      final assessment = result.dataOrNull!;
      expect(assessment.score, 86.7);
      expect(assessment.startTime, DateTime.utc(2026, 9, 30, 11, 12));
      expect(assessment.endTime, DateTime.utc(2026, 9, 30, 11, 31));
      final item = assessment.items.single;
      expect(item.infractionNoteId, 'note-pm-1');
      expect(item.noteType, 'PM');
      expect(item.comment, 'Ajuste feito somente após solicitação');
      expect(item.deduction, 3);
      expect(item.infractionId, 'inf-1');
      expect(item.infractionDescription, 'Não ajustou o banco, cinto ou espelhos');
      expect(item.infractionOrder, 1);
      expect(item.categoryId, 'cat-cv');
      expect(item.categoryCode, 'CV');
      expect(item.categoryName, 'Controle do Veículo');
      expect(item.categoryOrder, 1);
    });

    test('sem avaliação no backend (200 sem corpo), sucesso vazio', () async {
      answer(null);

      final result = await repository.fetchAssessment('tp-1');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
    });

    test('resposta fora do formato vira falha, com a mensagem genérica', () async {
      answer({'id': 'assess-1'});

      final result = await repository.fetchAssessment('tp-1');

      expect(
        result,
        isA<Failure<RemoteAssessment?>>().having(
            (f) => f.message, 'message', 'Não foi possível carregar o resultado.'),
      );
    });

    test('sem rede, a mensagem de falta de conexão', () async {
      when(() => api.get<Object?>(path)).thenThrow(
        const ApiException(message: 'Sem conexão', isNetworkError: true),
      );

      final result = await repository.fetchAssessment('tp-1');

      expect(
        result,
        isA<Failure<RemoteAssessment?>>()
            .having((f) => f.message, 'message', 'Sem conexão')
            .having((f) => f.exception, 'exception', isA<ApiException>()),
      );
    });
  });

  group('unassign', () {
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/data/repositories/participant_repository_test.dart`
Esperado: não compila — `Error when reading 'lib/data/models/remote_assessment.dart'` e `The method 'fetchAssessment' isn't defined for the type 'ParticipantRepository'`.

- [ ] **Step 3: Implementar**

Criar `lib/data/models/remote_assessment.dart`:

```dart
/// Uma avaliação prática como o backend a guarda — a resposta de
/// `GET /practical-assessments/by-participant/:id` (Fase 5B). É o que a tela
/// de Resultado mostra de quem foi avaliado em outro aparelho, no painel web,
/// ou já foi aceito pelo servidor. Nada disto é guardado no aparelho
/// (decisão de 01/10/2026).
class RemoteAssessment {
  const RemoteAssessment({
    required this.startTime,
    required this.items,
    this.endTime,
    this.score,
  });

  final DateTime startTime;
  final DateTime? endTime;

  /// Calculado pelo backend no envio; nulo enquanto ele não calculou.
  final double? score;
  final List<RemoteAssessmentItem> items;

  /// Nulo se [json] não tem o formato esperado — sem `startTime` não há
  /// avaliação que se possa mostrar. Item sem a nota, a infração ou a
  /// categoria aninhadas fica de fora.
  static RemoteAssessment? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final start = DateTime.tryParse(json['startTime'] as String? ?? '');
    if (start == null) return null;

    final items = json['items'];
    return RemoteAssessment(
      startTime: start,
      endTime: DateTime.tryParse(json['endTime'] as String? ?? ''),
      score: (json['score'] as num?)?.toDouble(),
      items: items is List
          ? items
              .whereType<Map<String, dynamic>>()
              .map(RemoteAssessmentItem.tryParse)
              .whereType<RemoteAssessmentItem>()
              .toList(growable: false)
          : const [],
    );
  }
}

/// Uma infração marcada, achatada: a nota escolhida, a infração e a
/// categoria dela — o backend devolve os três aninhados em cada item.
class RemoteAssessmentItem {
  const RemoteAssessmentItem({
    required this.infractionNoteId,
    required this.noteType,
    required this.deduction,
    required this.infractionId,
    required this.infractionDescription,
    required this.infractionOrder,
    required this.categoryId,
    required this.categoryCode,
    required this.categoryName,
    required this.categoryOrder,
    this.comment,
  });

  final String infractionNoteId;

  /// `B`, `PM` ou `M`.
  final String noteType;
  final String? comment;
  final int deduction;
  final String infractionId;
  final String infractionDescription;

  /// Número do item na ficha oficial.
  final int infractionOrder;
  final String categoryId;
  final String categoryCode;
  final String categoryName;
  final int categoryOrder;

  static RemoteAssessmentItem? tryParse(Map<String, dynamic> json) {
    final note = json['infractionNote'];
    if (note is! Map<String, dynamic>) return null;
    final infraction = note['infraction'];
    if (infraction is! Map<String, dynamic>) return null;
    final category = infraction['category'];
    if (category is! Map<String, dynamic>) return null;

    return RemoteAssessmentItem(
      infractionNoteId: note['id'] as String? ?? '',
      noteType: note['noteType'] as String? ?? '',
      comment: note['comment'] as String?,
      deduction: (note['deduction'] as num?)?.toInt() ?? 0,
      infractionId: infraction['id'] as String? ?? '',
      infractionDescription: infraction['description'] as String? ?? '',
      infractionOrder: (infraction['order'] as num?)?.toInt() ?? 0,
      categoryId: category['id'] as String? ?? '',
      categoryCode: category['code'] as String? ?? '',
      categoryName: category['name'] as String? ?? '',
      categoryOrder: (category['order'] as num?)?.toInt() ?? 0,
    );
  }
}
```

Em `lib/data/repositories/participant_repository.dart`:

Substituir (1 de 3):

```dart
import '../../utils/scoring.dart';
import '../models/session_participant.dart';
```

por:

```dart
import '../../utils/scoring.dart';
import '../models/remote_assessment.dart';
import '../models/session_participant.dart';
```

Substituir (2 de 3):

```dart
      'Não foi possível desatribuir o participante. Tente de novo.';
```

por:

```dart
      'Não foi possível desatribuir o participante. Tente de novo.';
  static const String _resultFailed = 'Não foi possível carregar o resultado.';
```

Substituir (3 de 3):

```dart

  /// "Desatribuir participante" (decisão de 01/10/2026): libera no backend
```

por:

```dart

  /// A avaliação do participante no backend
  /// (`GET /practical-assessments/by-participant/:id`), para a tela de
  /// Resultado (Fase 5B). `Success(null)` quando o backend não tem avaliação
  /// dele. Nada é guardado no aparelho (decisão de 01/10/2026): sem rede, a
  /// tela mostra o que o cache da sessão já tem.
  Future<Result<RemoteAssessment?>> fetchAssessment(String participantId) async {
    try {
      final response = await _api
          .get<Object?>('/practical-assessments/by-participant/$participantId');
      final body = response.data;
      // O NestJS responde 200 sem corpo quando a avaliação não existe.
      if (body == null || body == '') return const Success(null);

      final assessment = RemoteAssessment.tryParse(body);
      if (assessment == null) {
        return Failure(
          Exception('resposta de by-participant/$participantId fora do formato'),
          _resultFailed,
        );
      }
      return Success(assessment);
    } on ApiException catch (error) {
      return Failure(error, error.isNetworkError ? error.message : _resultFailed);
    } catch (error) {
      return Failure(Exception('$error'), _resultFailed);
    }
  }

  /// "Desatribuir participante" (decisão de 01/10/2026): libera no backend
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **426 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/remote_assessment.dart lib/data/repositories/participant_repository.dart test/data/repositories/participant_repository_test.dart
git commit -m "feat(mobile): avaliacao do servidor para a tela de resultado"
```

---

## Task 7: Os dados do Resultado

Duas peças sem tela. `result_details.dart` monta as categorias e as infrações das duas fontes — do aparelho, pela mesma junção do checklist e da 1.6 (`buildChecklistSections`), e do servidor, com o % pelo catálogo do aparelho. A `ResultViewModel` decide a fonte (decisões 5 e 6 e a parte 3 do desenho), acompanha o envio da avaliação do aparelho pelo stream do banco, e cuida do "Reavaliar".

**Files:**
- Create: `lib/ui/result/result_details.dart`
- Create: `lib/ui/result/result_viewmodel.dart`
- Create: `test/ui/result/result_details_test.dart`, `test/ui/result/result_viewmodel_test.dart`

**Interfaces:**
- Consumes: `buildChecklistSections`, `overallScoreOf` (checklist); `calculateCategoryScore`, `getApprovalStatus` (`lib/utils/scoring.dart`); `RemoteAssessment` e `fetchAssessment` (Task 6); `assign`, `watchParticipant` (já existem); `findByParticipant`, `loadItems`, `watchSessionAssessments` (já existem); `clockLabel`, `atLabel`.
- Produces:
  - `ResultInfraction { int number; String description; String noteType; String? comment }`; `ResultCategory { id, code, name, double? score, List<ResultInfraction> infractions }`.
  - `List<ResultCategory> resultFromLocal(List<CatalogCategory>, List<LocalAssessmentItem>)`, `resultFromRemote(List<CatalogCategory>, RemoteAssessment)`, `int infractionCountOf(List<ResultCategory>)`.
  - `enum ResultSource { device, server, cacheOnly }`; `enum ResultDataNotice { deviceFallback, offline, serverFailed, notOnServer }`.
  - `ResultViewModel({required sessionId, participantId, ownerUserId, justConfirmed, assessmentRepository, participantRepository, catalogRepository, String? consultantId, String? consultantName, DateTime Function()? now})`: `isLoading`, `participant`, `source`, `dataNotice`, `canRetry`, `categories`, `infractionCount`, `score`, `bool? isApproved`, `startTime`, `endTime`, `timesLabel`, `LocalSyncStatus? sendStatus`, `sendNotice`, `canReevaluate`, `isReevaluating`, `reevaluateError`, `init()`, `retry()`, `Future<bool> reevaluate()`.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/result/result_details_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/assessment_catalog.dart';
import 'package:simtc/data/models/remote_assessment.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/result/result_details.dart';

void main() {
  CatalogInfraction infraction(String id, String categoryId, int order) {
    return CatalogInfraction(
      id: id,
      categoryId: categoryId,
      description: 'Infração do item $order',
      order: order,
      notes: [
        CatalogNote(id: '$id-B', infractionId: id, noteType: 'B', deduction: 1),
        CatalogNote(
          id: '$id-PM',
          infractionId: id,
          noteType: 'PM',
          deduction: 3,
          comment: 'Comentário PM do item $order',
        ),
        CatalogNote(id: '$id-M', infractionId: id, noteType: 'M', deduction: 5),
      ],
    );
  }

  // CV com os itens 1 e 4; RR com o item 3.
  final catalog = [
    CatalogCategory(
      id: 'cat-cv',
      code: 'CV',
      name: 'Controle do Veículo',
      order: 1,
      infractions: [infraction('inf-1', 'cat-cv', 1), infraction('inf-4', 'cat-cv', 4)],
    ),
    CatalogCategory(
      id: 'cat-rr',
      code: 'RR',
      name: 'Respeito às Regras',
      order: 2,
      infractions: [infraction('inf-3', 'cat-rr', 3)],
    ),
  ];

  LocalAssessmentItem item(String infractionId, String noteId) {
    return LocalAssessmentItem(
      id: 'item-$infractionId',
      localAssessmentId: 'assess-1',
      infractionId: infractionId,
      infractionNoteId: noteId,
      updatedAt: DateTime(2026, 9, 30),
    );
  }

  RemoteAssessmentItem remoteItem({
    required String infractionId,
    required int order,
    required String noteType,
    required int deduction,
    String categoryId = 'cat-cv',
    String categoryCode = 'CV',
    String categoryName = 'Controle do Veículo',
    int categoryOrder = 1,
    String? comment,
  }) {
    return RemoteAssessmentItem(
      infractionNoteId: '$infractionId-$noteType',
      noteType: noteType,
      comment: comment,
      deduction: deduction,
      infractionId: infractionId,
      infractionDescription: 'Do servidor, item $order',
      infractionOrder: order,
      categoryId: categoryId,
      categoryCode: categoryCode,
      categoryName: categoryName,
      categoryOrder: categoryOrder,
    );
  }

  group('resultFromLocal', () {
    test(
        'cada categoria com o % do checklist e as infrações marcadas, com a nota '
        'e o comentário, na ordem do item', () {
      final categories = resultFromLocal(catalog, [
        item('inf-4', 'inf-4-B'),
        item('inf-1', 'inf-1-PM'),
      ]);

      expect(categories.map((c) => c.code), ['CV', 'RR']);
      final cv = categories.first;
      // Duas infrações em CV: PM (3/5 de 50) e B (1/5 de 50) descontam 40.
      expect(cv.score, 60);
      expect(cv.infractions.map((i) => i.number), [1, 4]);
      expect(cv.infractions.first.noteType, 'PM');
      expect(cv.infractions.first.description, 'Infração do item 1');
      expect(cv.infractions.first.comment, 'Comentário PM do item 1');
      expect(cv.infractions.last.comment, isNull);
      expect(categories.last.score, 100);
      expect(categories.last.infractions, isEmpty);
      expect(infractionCountOf(categories), 2);
    });
  });

  group('resultFromRemote', () {
    test('as infrações vêm da resposta, e o % de cada categoria do catálogo',
        () {
      final remote = RemoteAssessment(
        startTime: DateTime.utc(2026, 9, 30, 11),
        score: 85,
        items: [
          remoteItem(infractionId: 'inf-1', order: 1, noteType: 'PM', deduction: 3, comment: 'Do servidor'),
        ],
      );

      final categories = resultFromRemote(catalog, remote);

      expect(categories.map((c) => c.code), ['CV', 'RR']);
      expect(categories.first.score, 70, reason: 'PM numa categoria de 2 itens');
      expect(categories.first.infractions.single.description, 'Do servidor, item 1');
      expect(categories.first.infractions.single.comment, 'Do servidor');
      expect(categories.last.score, 100);
    });

    test('categoria que o catálogo do aparelho não conhece entra no fim, sem %',
        () {
      final remote = RemoteAssessment(
        startTime: DateTime.utc(2026, 9, 30, 11),
        items: [
          remoteItem(
            infractionId: 'inf-9',
            order: 2,
            noteType: 'M',
            deduction: 5,
            categoryId: 'cat-tp',
            categoryCode: 'TP',
            categoryName: 'Técnica de Pista',
            categoryOrder: 4,
          ),
        ],
      );

      final categories = resultFromRemote(catalog, remote);

      expect(categories.map((c) => c.code), ['CV', 'RR', 'TP']);
      expect(categories.last.score, isNull);
      expect(categories.last.infractions.single.number, 2);
    });

    test('sem catálogo no aparelho, só as categorias da resposta, sem %', () {
      final remote = RemoteAssessment(
        startTime: DateTime.utc(2026, 9, 30, 11),
        items: [
          remoteItem(infractionId: 'inf-4', order: 4, noteType: 'B', deduction: 1),
          remoteItem(infractionId: 'inf-1', order: 1, noteType: 'M', deduction: 5),
        ],
      );

      final categories = resultFromRemote(const [], remote);

      expect(categories.single.code, 'CV');
      expect(categories.single.score, isNull);
      expect(categories.single.infractions.map((i) => i.number), [1, 4]);
    });
  });
}
```

Criar `test/ui/result/result_viewmodel_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/result/result_viewmodel.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;

  const resultPath = '/practical-assessments/by-participant/tp-1';
  const assignPath = '/practical-assessments/assign';
  final now = DateTime(2026, 9, 30, 9);

  setUp(() async {
    api = _MockApiClient();
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
            cachedAt: DateTime(2026, 9, 30, 7),
          ),
        );
    // CV com os itens 1 e 4, RR com o item 3: uma PM em CV dá 70% em CV e
    // 85% no geral.
    for (final (id, code, name, order) in [
      ('cat-cv', 'CV', 'Controle do Veículo', 1),
      ('cat-rr', 'RR', 'Respeito às Regras', 2),
    ]) {
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(id: id, code: code, name: name, order: order),
          );
    }
    for (final (id, category, order) in [
      ('inf-1', 'cat-cv', 1),
      ('inf-4', 'cat-cv', 4),
      ('inf-3', 'cat-rr', 3),
    ]) {
      await db.into(db.infractions).insert(
            InfractionsCompanion.insert(
              id: id,
              categoryId: category,
              description: 'Infração do item $order',
              order: order,
            ),
          );
      for (final (type, deduction) in [('B', 1), ('PM', 3), ('M', 5)]) {
        await db.into(db.infractionNotes).insert(
              InfractionNotesCompanion.insert(
                id: '$id-$type',
                infractionId: id,
                noteType: type,
                deduction: deduction,
                comment: Value(type == 'PM' ? 'Ajuste feito somente após solicitação' : null),
              ),
            );
      }
    }
  });

  tearDown(() => db.close());

  Future<void> seedParticipant({
    String status = 'APROVADO',
    double? score,
    String? assignedTo,
  }) {
    return db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-1',
            sessionId: 'sess-1',
            name: 'Ana Paula Ribeiro',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: status,
            assignedConsultantId: Value(assignedTo),
            score: Value(score),
            cachedAt: DateTime(2026, 9, 30, 7),
          ),
        );
  }

  /// Uma avaliação feita neste aparelho e confirmada na 1.6: PM no item 1
  /// (85%), das 08:12 às 08:31.
  Future<LocalAssessment> confirmedHere() async {
    final draft = await assessmentRepository.openDraft(
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    await assessmentRepository.mark(
      localAssessmentId: draft.id,
      infractionId: 'inf-1',
      infractionNoteId: 'inf-1-PM',
    );
    await (db.update(db.localAssessments)..where((t) => t.id.equals(draft.id)))
        .write(LocalAssessmentsCompanion(startTime: Value(DateTime(2026, 9, 30, 8, 12))));
    await assessmentRepository.confirm(
      draft.id,
      participantName: 'Ana Paula Ribeiro',
      score: 85,
      endTime: DateTime(2026, 9, 30, 8, 31),
    );
    return draft;
  }

  /// O que o backend devolve de uma avaliação aceita: B no item 4.
  Map<String, dynamic> serverJson() => {
        'id': 'assess-1',
        'trainingParticipantId': 'tp-1',
        'startTime': '2026-09-30T11:12:00.000Z',
        'endTime': '2026-09-30T11:31:00.000Z',
        'score': 90,
        'items': [
          {
            'id': 'item-1',
            'infractionNoteId': 'inf-4-B',
            'infractionNote': {
              'id': 'inf-4-B',
              'noteType': 'B',
              'comment': 'Frenagem um pouco brusca',
              'deduction': 1,
              'infraction': {
                'id': 'inf-4',
                'description': 'Uso excessivo ou tardio do freio',
                'order': 4,
                'category': {'id': 'cat-cv', 'code': 'CV', 'name': 'Controle do Veículo', 'order': 1},
              },
            },
          },
        ],
      };

  void serverAnswers(Object? body) {
    when(() => api.get<Object?>(resultPath)).thenAnswer(
      (_) async => Response<Object?>(
        requestOptions: RequestOptions(path: resultPath),
        statusCode: 200,
        data: body,
      ),
    );
  }

  void serverFails(ApiException error) {
    when(() => api.get<Object?>(resultPath)).thenThrow(error);
  }

  ResultViewModel buildViewModel({bool justConfirmed = false, String? consultantId = 'c-eu'}) {
    return ResultViewModel(
      sessionId: 'sess-1',
      participantId: 'tp-1',
      ownerUserId: 'user-1',
      consultantId: consultantId,
      consultantName: 'Carla Souza',
      justConfirmed: justConfirmed,
      assessmentRepository: assessmentRepository,
      participantRepository: participantRepository,
      catalogRepository: catalogRepository,
      now: () => now,
    );
  }

  /// Deixa os streams do banco entregarem o que acabou de ser gravado.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  test(
      'logo depois do "Confirmar": os dados do aparelho, o aviso de fila e '
      'nenhuma busca no servidor', () async {
    await seedParticipant(status: 'EM_AVALIACAO', assignedTo: 'c-eu');
    await confirmedHere();
    final vm = buildViewModel(justConfirmed: true);
    addTearDown(vm.dispose);

    await vm.init();
    await settle();

    expect(vm.isLoading, isFalse);
    expect(vm.source, ResultSource.device);
    expect(vm.score, 85);
    expect(vm.isApproved, isTrue);
    expect(vm.timesLabel, 'Início 08:12 · Fim 08:31');
    expect(vm.sendNotice, 'Na fila de envio — sai sozinha quando houver conexão.');
    expect(vm.categories!.first.score, 70);
    expect(vm.categories!.first.infractions.single.comment,
        'Ajuste feito somente após solicitação');
    expect(vm.infractionCount, 1);
    expect(vm.justConfirmed, isTrue);
    expect(vm.canReevaluate, isFalse);
    verifyNever(() => api.get<Object?>(any()));
  });

  test('o aviso de envio acompanha a fila: erro e, depois, enviada', () async {
    await seedParticipant(status: 'EM_AVALIACAO', assignedTo: 'c-eu');
    final local = await confirmedHere();
    final vm = buildViewModel(justConfirmed: true);
    addTearDown(vm.dispose);
    await vm.init();

    await assessmentRepository.saveSendResults(
      {local.id: 'sem conexão'},
      at: DateTime(2026, 9, 30, 8, 40),
    );
    await settle();
    expect(vm.sendStatus, LocalSyncStatus.error);
    expect(vm.sendNotice, 'Erro no envio · falhou às 08:40 · sem conexão.');

    await assessmentRepository.saveSendResults({local.id: null}, at: DateTime(2026, 9, 30, 8, 45));
    await settle();
    expect(vm.sendStatus, LocalSyncStatus.synced);
    expect(vm.sendNotice, 'Enviada às 08:45.');
  });

  test(
      'avaliação aceita: a nota e as infrações do servidor, e o % de cada '
      'categoria pelo catálogo do aparelho', () async {
    await seedParticipant(status: 'APROVADO', score: 90);
    serverAnswers(serverJson());
    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await vm.init();

    expect(vm.source, ResultSource.server);
    expect(vm.score, 90);
    expect(vm.isApproved, isTrue);
    expect(vm.startTime, DateTime.utc(2026, 9, 30, 11, 12));
    expect(vm.endTime, DateTime.utc(2026, 9, 30, 11, 31));
    expect(vm.categories!.first.score, 90, reason: 'B num dos 2 itens de CV');
    final infraction = vm.categories!.first.infractions.single;
    expect(infraction.number, 4);
    expect(infraction.description, 'Uso excessivo ou tardio do freio');
    expect(infraction.comment, 'Frenagem um pouco brusca');
    expect(vm.sendStatus, isNull);
    expect(vm.sendNotice, isNull);
    expect(vm.dataNotice, isNull);
  });

  test(
      'sem rede e sem avaliação no aparelho: a nota e o status guardados, com '
      'o aviso', () async {
    await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
    serverFails(const ApiException(message: 'Sem conexão', isNetworkError: true));
    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await vm.init();
    await settle();

    expect(vm.source, ResultSource.cacheOnly);
    expect(vm.score, 62.5);
    expect(vm.isApproved, isFalse);
    expect(vm.categories, isNull);
    expect(vm.dataNotice, ResultDataNotice.offline);
    expect(vm.canRetry, isFalse);
  });

  test(
      'o servidor falhou e o aparelho tem a avaliação aceita: mostra a do '
      'aparelho, com aviso', () async {
    await seedParticipant(status: 'APROVADO', score: 85);
    final local = await confirmedHere();
    await assessmentRepository.saveSendResults({local.id: null}, at: DateTime(2026, 9, 30, 8, 45));
    serverFails(const ApiException(message: 'Internal server error', statusCode: 500));
    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await vm.init();
    await settle();

    expect(vm.source, ResultSource.device);
    expect(vm.dataNotice, ResultDataNotice.deviceFallback);
    expect(vm.score, 85);
    expect(vm.sendNotice, 'Enviada às 08:45.');
  });

  test('o servidor não tem avaliação: a nota e o status guardados, com aviso',
      () async {
    await seedParticipant(status: 'APROVADO', score: 88);
    serverAnswers(null);
    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await vm.init();
    await settle();

    expect(vm.source, ResultSource.cacheOnly);
    expect(vm.dataNotice, ResultDataNotice.notOnServer);
    expect(vm.score, 88);
  });

  test(
      'o servidor falhou sem avaliação no aparelho: "Tentar novamente" busca '
      'de novo', () async {
    await seedParticipant(status: 'APROVADO', score: 90);
    serverFails(const ApiException(message: 'Internal server error', statusCode: 500));
    final vm = buildViewModel();
    addTearDown(vm.dispose);
    await vm.init();
    expect(vm.dataNotice, ResultDataNotice.serverFailed);
    expect(vm.canRetry, isTrue);

    serverAnswers(serverJson());
    await vm.retry();

    expect(vm.source, ResultSource.server);
    expect(vm.dataNotice, isNull);
    expect(vm.categories, isNotNull);
  });

  group('Reavaliar', () {
    test(
        'só para "Necessita reavaliação", fora do "Confirmar", com perfil de '
        'consultor e sem avaliação do aparelho esperando envio', () async {
      await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
      serverAnswers(serverJson());

      final fromDetail = buildViewModel();
      addTearDown(fromDetail.dispose);
      await fromDetail.init();
      await settle();
      expect(fromDetail.canReevaluate, isTrue);

      final afterConfirm = buildViewModel(justConfirmed: true);
      addTearDown(afterConfirm.dispose);
      await afterConfirm.init();
      await settle();
      expect(afterConfirm.canReevaluate, isFalse);

      final noProfile = buildViewModel(consultantId: null);
      addTearDown(noProfile.dispose);
      await noProfile.init();
      await settle();
      expect(noProfile.canReevaluate, isFalse);

      await confirmedHere();
      final waitingToSend = buildViewModel();
      addTearDown(waitingToSend.dispose);
      await waitingToSend.init();
      await settle();
      expect(waitingToSend.canReevaluate, isFalse);
    });

    test('dois toques rápidos em "Reavaliar" reservam uma vez só', () async {
      await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
      serverAnswers(serverJson());
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: assignPath),
                statusCode: 201,
                data: {'assigned': 1},
              ));
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await settle();

      final first = vm.reevaluate();
      final second = vm.reevaluate();

      expect(await first, isTrue);
      expect(await second, isFalse);
      verify(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .called(1);
    });

    test('aprovado não tem "Reavaliar"', () async {
      await seedParticipant(status: 'APROVADO', score: 90);
      serverAnswers(serverJson());
      final vm = buildViewModel();
      addTearDown(vm.dispose);

      await vm.init();
      await settle();

      expect(vm.canReevaluate, isFalse);
    });

    test('reserva o participante para quem tocou; um 409 mostra o motivo',
        () async {
      await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
      serverAnswers(serverJson());
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Um ou mais participantes já estão em avaliação com outro consultor',
        statusCode: 409,
      ));
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await settle();

      expect(await vm.reevaluate(), isFalse);
      expect(vm.reevaluateError,
          'Um ou mais participantes já estão em avaliação com outro consultor');

      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: assignPath),
                statusCode: 201,
                data: {'assigned': 1},
              ));

      expect(await vm.reevaluate(), isTrue);
      expect(vm.reevaluateError, isNull);
      final row = await db.select(db.participants).getSingle();
      expect(row.status, 'EM_AVALIACAO');
      expect(row.assignedConsultantId, 'c-eu');
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/ui/result`
Esperado: os dois arquivos não compilam — `Error when reading 'lib/ui/result/result_details.dart'` e `Error when reading 'lib/ui/result/result_viewmodel.dart'`.

- [ ] **Step 3: Implementar**

Criar `lib/ui/result/result_details.dart`:

```dart
import '../../data/models/assessment_catalog.dart';
import '../../data/models/remote_assessment.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/scoring.dart';
import '../checklist/checklist_sections.dart';

/// Uma infração registrada, como o Resultado lista (canvas "2g"): o número do
/// item na ficha oficial, a descrição, a nota e o comentário dela.
class ResultInfraction {
  const ResultInfraction({
    required this.number,
    required this.description,
    required this.noteType,
    this.comment,
  });

  final int number;
  final String description;

  /// `B`, `PM` ou `M`.
  final String noteType;
  final String? comment;
}

/// Uma categoria do Resultado: o % dela e as infrações marcadas, na ordem do
/// item. O % é nulo quando o catálogo do aparelho não conhece a categoria —
/// sem o total de itens dela, não há como calcular.
class ResultCategory {
  const ResultCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.score,
    required this.infractions,
  });

  final String id;
  final String code;
  final String name;
  final double? score;
  final List<ResultInfraction> infractions;
}

/// As categorias de uma avaliação feita neste aparelho: as marcações e o
/// catálogo, pela mesma junção do checklist e da tela 1.6
/// (`buildChecklistSections`) — os mesmos números que o consultor confirmou.
List<ResultCategory> resultFromLocal(
  List<CatalogCategory> catalog,
  List<LocalAssessmentItem> items,
) {
  return [
    for (final section in buildChecklistSections(catalog, items))
      ResultCategory(
        id: section.id,
        code: section.code,
        name: section.name,
        score: section.score,
        infractions: _sorted([
          for (final infraction in section.infractions)
            if (infraction.selectedNote case final note?)
              ResultInfraction(
                number: infraction.order,
                description: infraction.description,
                noteType: note.noteType,
                comment: note.comment,
              ),
        ]),
      ),
  ];
}

/// As categorias de uma avaliação vinda do servidor: as infrações saem da
/// resposta (descrição, número e comentário, como o backend guardou), e o %
/// de cada categoria é calculado com o catálogo do aparelho, pela regra do
/// checklist (`calculateCategoryScore`). Uma categoria que o catálogo do
/// aparelho não conhece entra no fim, sem %.
List<ResultCategory> resultFromRemote(
  List<CatalogCategory> catalog,
  RemoteAssessment remote,
) {
  final itemsByCategory = <String, List<RemoteAssessmentItem>>{};
  for (final item in remote.items) {
    itemsByCategory.putIfAbsent(item.categoryId, () => []).add(item);
  }

  final categories = <ResultCategory>[];
  for (final category in catalog) {
    if (category.id.isEmpty) continue;
    final items = itemsByCategory.remove(category.id) ?? const <RemoteAssessmentItem>[];
    final total = category.infractions.where((i) => i.id.isNotEmpty).length;
    categories.add(ResultCategory(
      id: category.id,
      code: category.code,
      name: category.name,
      score: calculateCategoryScore([for (final item in items) item.deduction], total),
      infractions: _remoteInfractions(items),
    ));
  }

  final unknown = itemsByCategory.values.toList()
    ..sort((a, b) => a.first.categoryOrder.compareTo(b.first.categoryOrder));
  for (final items in unknown) {
    final first = items.first;
    categories.add(ResultCategory(
      id: first.categoryId,
      code: first.categoryCode,
      name: first.categoryName,
      score: null,
      infractions: _remoteInfractions(items),
    ));
  }
  return categories;
}

/// Quantas infrações a avaliação registrou — o "N infrações" do Resultado.
int infractionCountOf(List<ResultCategory> categories) =>
    categories.fold(0, (total, category) => total + category.infractions.length);

List<ResultInfraction> _remoteInfractions(List<RemoteAssessmentItem> items) {
  return _sorted([
    for (final item in items)
      ResultInfraction(
        number: item.infractionOrder,
        description: item.infractionDescription,
        noteType: item.noteType,
        comment: item.comment,
      ),
  ]);
}

List<ResultInfraction> _sorted(List<ResultInfraction> infractions) =>
    infractions..sort((a, b) => a.number.compareTo(b.number));
```

Criar `lib/ui/result/result_viewmodel.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/assessment_catalog.dart';
import '../../data/models/remote_assessment.dart';
import '../../data/models/session_participant.dart';
import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/result.dart';
import '../../utils/scoring.dart';
import '../checklist/checklist_sections.dart';
import '../core/date_labels.dart';
import 'result_details.dart';

/// De onde vêm os dados do Resultado (decisão de 01/10/2026).
enum ResultSource {
  /// A avaliação feita neste aparelho — ainda não aceita pelo servidor, ou
  /// aceita e o servidor não respondeu agora.
  device,

  /// `GET /practical-assessments/by-participant/:id`.
  server,

  /// Só a nota e o status que o cache da sessão guarda, sem as infrações.
  cacheOnly,
}

/// O aviso sobre os dados que a tela mostra (Parte 3 do desenho de
/// 01/10/2026).
enum ResultDataNotice {
  /// O servidor não respondeu, e a tela mostra a avaliação deste aparelho.
  deviceFallback,

  /// Sem rede, e o aparelho não tem a avaliação: as infrações chegam com a
  /// internet.
  offline,

  /// O servidor falhou (5xx, resposta fora do formato) — "Tentar novamente".
  serverFailed,

  /// O servidor não tem avaliação deste participante.
  notOnServer,
}

/// Estado da tela 1.8 Resultado (Fase 5B).
///
/// Uma avaliação deste aparelho ainda não aceita (na fila ou com erro de
/// envio) é mostrada com os dados do aparelho: o servidor ainda não a tem.
/// Nos outros casos, os dados vêm do servidor; se ele não responde, a
/// avaliação aceita deste aparelho, ou só a nota e o status do cache. Nada
/// novo é guardado no aparelho.
class ResultViewModel extends ChangeNotifier {
  ResultViewModel({
    required this.sessionId,
    required this.participantId,
    required this.ownerUserId,
    required this.justConfirmed,
    required AssessmentRepository assessmentRepository,
    required ParticipantRepository participantRepository,
    required AssessmentCatalogRepository catalogRepository,
    this.consultantId,
    this.consultantName,
    DateTime Function()? now,
  })  : _assessmentRepository = assessmentRepository,
        _participantRepository = participantRepository,
        _catalogRepository = catalogRepository,
        _now = now ?? DateTime.now;

  final String sessionId;
  final String participantId;

  /// `AuthUser.id` do consultor logado — o dono das avaliações do aparelho.
  final String ownerUserId;

  /// Aberta logo depois do "Confirmar" da tela 1.6: o rodapé é o "Próximo
  /// participante".
  final bool justConfirmed;

  /// `AuthUser.consultantId` e `AuthUser.name` — o "Reavaliar" reserva o
  /// participante em nome dele.
  final String? consultantId;
  final String? consultantName;

  final AssessmentRepository _assessmentRepository;
  final ParticipantRepository _participantRepository;
  final AssessmentCatalogRepository _catalogRepository;
  final DateTime Function() _now;

  static const String _reevaluateFailed =
      'Não foi possível reservar o participante. Tente de novo.';

  StreamSubscription<SessionParticipant?>? _participantSubscription;
  StreamSubscription<List<LocalAssessment>>? _localSubscription;

  bool _disposed = false;
  bool _loading = true;
  bool _reevaluating = false;
  SessionParticipant? _participant;
  LocalAssessment? _local;
  ResultSource? _source;
  ResultDataNotice? _dataNotice;
  List<ResultCategory>? _categories;
  double? _score;
  DateTime? _startTime;
  DateTime? _endTime;
  String? _reevaluateError;

  bool get isLoading => _loading;
  SessionParticipant? get participant => _participant;
  ResultSource? get source => _source;
  ResultDataNotice? get dataNotice => _dataNotice;

  /// Só a falha do servidor tem "Tentar novamente"; sem rede, o aviso já diz
  /// que as infrações chegam com a internet.
  bool get canRetry => _dataNotice == ResultDataNotice.serverFailed;

  /// Nulo quando só há a nota e o status do cache ([ResultSource.cacheOnly]).
  List<ResultCategory>? get categories => _categories;

  int get infractionCount => infractionCountOf(_categories ?? const []);

  /// A nota da avaliação mostrada; sem ela (o backend ainda não calculou, ou
  /// só há o cache), a que o cache da sessão guarda.
  double? get score => _score ?? _participant?.score;

  /// Mesmo corte do backend (`getApprovalStatus`). Sem nota, o status do
  /// cache decide; nulo se nem ele diz.
  bool? get isApproved {
    final score = this.score;
    if (score != null) return getApprovalStatus(score) == 'APROVADO';
    return switch (_participant?.status) {
      ParticipantStatus.aprovado => true,
      ParticipantStatus.necessitaReavaliacao => false,
      _ => null,
    };
  }

  DateTime? get startTime => _startTime;
  DateTime? get endTime => _endTime;

  /// "Início 08:12 · Fim 08:31" — o mesmo formato da tela 1.6.
  String? get timesLabel {
    final start = _startTime;
    if (start == null) return null;
    final now = _now();
    final end = _endTime;
    final started = 'Início ${clockLabel(start, now)}';
    return end == null ? started : '$started · Fim ${clockLabel(end, now)}';
  }

  /// A situação de envio da avaliação deste aparelho, quando é ela que a
  /// tela mostra — a tela escolhe o tom do aviso por ela. Nula nos outros
  /// casos.
  LocalSyncStatus? get sendStatus {
    final local = _local;
    if (_source != ResultSource.device || local == null) return null;
    return local.syncStatus == LocalSyncStatus.draft ? null : local.syncStatus;
  }

  /// Como está o envio da avaliação deste aparelho, quando é ela que a tela
  /// mostra. Muda sozinho com a tela aberta.
  String? get sendNotice {
    final local = _local;
    if (_source != ResultSource.device || local == null) return null;
    final at = local.lastAttemptAt;
    final now = _now();
    return switch (local.syncStatus) {
      LocalSyncStatus.pendingSync =>
        'Na fila de envio — sai sozinha quando houver conexão.',
      LocalSyncStatus.error => '${[
          'Erro no envio',
          if (at != null) 'falhou ${atLabel(at, now)}',
          if (local.lastError != null) local.lastError!,
        ].join(' · ')}.',
      LocalSyncStatus.synced => at == null ? 'Enviada.' : 'Enviada ${atLabel(at, now)}.',
      LocalSyncStatus.draft => null,
    };
  }

  /// "Reavaliar" (decisão de 01/10/2026): só fora do "Confirmar", para quem
  /// está em "Necessita reavaliação", com perfil de consultor e sem avaliação
  /// deste aparelho esperando envio — essa é mais nova que a do servidor.
  bool get canReevaluate {
    final local = _local;
    final waiting = local != null &&
        (local.syncStatus == LocalSyncStatus.pendingSync ||
            local.syncStatus == LocalSyncStatus.error);
    return !justConfirmed &&
        consultantId != null &&
        !waiting &&
        _participant?.status == ParticipantStatus.necessitaReavaliacao;
  }

  bool get isReevaluating => _reevaluating;

  /// Por que o último "Reavaliar" não reservou — a tela mostra num aviso.
  String? get reevaluateError => _reevaluateError;

  Future<void> init() async {
    _participantSubscription ??=
        _participantRepository.watchParticipant(participantId).listen((p) {
      _participant = p;
      notifyListeners();
    });
    _localSubscription ??= _assessmentRepository
        .watchSessionAssessments(sessionId, ownerUserId)
        .listen((rows) {
      _local = rows
          .where((r) =>
              r.trainingParticipantId == participantId &&
              r.syncStatus != LocalSyncStatus.draft)
          .firstOrNull;
      notifyListeners();
    });
    await _load();
  }

  /// "Tentar novamente", depois de uma falha do servidor.
  Future<void> retry() async {
    if (_loading) return;
    await _load();
  }

  /// "Reavaliar": reserva o participante para o consultor logado
  /// (`POST /practical-assessments/assign`) — o backend tira a atribuição
  /// depois de cada envio. Com sucesso, devolve `true` e a tela abre o
  /// checklist em "não iniciada".
  Future<bool> reevaluate() async {
    final consultantId = this.consultantId;
    if (!canReevaluate || _reevaluating || consultantId == null) return false;

    _reevaluating = true;
    _reevaluateError = null;
    notifyListeners();
    try {
      final result = await _participantRepository.assign(
        participantId,
        consultantId: consultantId,
        consultantName: consultantName ?? '',
      );
      switch (result) {
        case Success():
          return true;
        case Failure(:final message):
          _reevaluateError = message ?? _reevaluateFailed;
          return false;
      }
    } catch (_) {
      _reevaluateError = _reevaluateFailed;
      return false;
    } finally {
      _reevaluating = false;
      notifyListeners();
    }
  }

  Future<void> _load() async {
    _loading = true;
    _dataNotice = null;
    notifyListeners();

    final local = await _ownLocal();
    final catalog = await _catalogRepository.loadCatalog();
    if (_disposed) return;
    _local = local;

    if (local != null && local.syncStatus != LocalSyncStatus.synced) {
      // Confirmada e ainda não aceita: o servidor ainda não tem esta.
      await _showDevice(local, catalog);
    } else {
      final result = await _participantRepository.fetchAssessment(participantId);
      if (_disposed) return;
      switch (result) {
        case Success(data: final remote?):
          _showServer(remote, catalog);
        case Success():
          _showCacheOnly(ResultDataNotice.notOnServer);
        case Failure(:final exception):
          if (local != null) {
            await _showDevice(local, catalog);
            _dataNotice = ResultDataNotice.deviceFallback;
          } else {
            final offline = exception is ApiException && exception.isNetworkError;
            _showCacheOnly(offline ? ResultDataNotice.offline : ResultDataNotice.serverFailed);
          }
      }
    }
    if (_disposed) return;

    _loading = false;
    notifyListeners();
  }

  /// A avaliação confirmada deste aparelho, do consultor logado.
  Future<LocalAssessment?> _ownLocal() async {
    final local = await _assessmentRepository.findByParticipant(participantId);
    if (local == null || local.syncStatus == LocalSyncStatus.draft) return null;
    return local.ownerUserId == ownerUserId ? local : null;
  }

  Future<void> _showDevice(LocalAssessment local, List<CatalogCategory> catalog) async {
    final items = await _assessmentRepository.loadItems(local.id);
    _source = ResultSource.device;
    _categories = resultFromLocal(catalog, items);
    _score = local.score ?? overallScoreOf(buildChecklistSections(catalog, items));
    _startTime = local.startTime;
    _endTime = local.endTime;
  }

  void _showServer(RemoteAssessment remote, List<CatalogCategory> catalog) {
    _source = ResultSource.server;
    _categories = resultFromRemote(catalog, remote);
    _score = remote.score;
    _startTime = remote.startTime;
    _endTime = remote.endTime;
  }

  void _showCacheOnly(ResultDataNotice notice) {
    _source = ResultSource.cacheOnly;
    _categories = null;
    _score = null;
    _startTime = null;
    _endTime = null;
    _dataNotice = notice;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _participantSubscription?.cancel();
    _localSubscription?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **441 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/result/result_details.dart lib/ui/result/result_viewmodel.dart test/ui/result/result_details_test.dart test/ui/result/result_viewmodel_test.dart
git commit -m "feat(mobile): dados da tela de resultado"
```

---

## Task 8: A tela 1.8 Resultado

A tela do quadro `2g`, com as divergências da decisão 14, no lugar da provisória (que é apagada). O topo da 1.6 e do Resultado vira o `FinalScoreBlock`; o `AppTopBar` passa a aceitar o X de "Fechar"; o `AppCtaButton` ganha o ícone depois do rótulo. A rota do Resultado leva `?confirmada=1` quando abre logo depois do "Confirmar" (a Task 9 liga isso).

**Files:**
- Create: `lib/ui/core/widgets/final_score_block.dart`
- Create: `lib/ui/result/result_screen.dart`
- Modify: `lib/ui/summary/summary_screen.dart` — usa o `FinalScoreBlock`; sai o `_ResultPill`
- Modify: `lib/ui/core/widgets/app_top_bar.dart` — `leadingIcon`, `leadingIconSize`, `leadingTooltip`
- Modify: `lib/ui/core/widgets/app_buttons.dart` — `AppCtaButton.trailingIcon`
- Modify: `lib/ui/core/theme/app_icons.dart` — `close`
- Modify: `lib/ui/core/theme/app_typography.dart` — `resultNoteBadge`
- Modify: `lib/router.dart` — a rota abre a `ResultScreen`
- Modify: `lib/ui/session_detail/session_detail_screen.dart` — sem `extra` no toque do concluído
- Delete: `lib/ui/evaluation/evaluation_placeholder_screen.dart`
- Create: `test/ui/result/result_screen_test.dart`
- Test: `test/ui/session_detail/session_detail_screen_test.dart`

**Interfaces:**
- Consumes: `ResultViewModel` e `result_details.dart` (Task 7); `CategoryCodeChip`, `ScoreBadge`, `infractionCountLabel`; `AppSecondaryButton`, `InlineNotice`.
- Produces:
  - `ResultScreen({required String sessionId, required String participantId, bool justConfirmed = false})`; chaves `ValueKey('result-group-<id>')` nos cabeçalhos dos grupos e `ValueKey('result-performance-<id>')` nas linhas de desempenho.
  - `AppRoutes.participantResult(sessionId, participantId, {bool justConfirmed = false})` → `…/result` ou `…/result?confirmada=1`.
  - `FinalScoreBlock({required double? score, required bool? approved, List<String> details})`.
  - `AppTopBar(title, trailing, leadingIcon = AppIcons.back, leadingIconSize = 30, leadingTooltip = 'Voltar')`; `AppCtaButton(trailingIcon: …)`; `AppIcons.close`; `AppTypography.resultNoteBadge`.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/result/result_screen_test.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/result/result_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockApiClient api;
  late _MockAuthRepository auth;
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;
  late ConnectivityService connectivity;

  const resultPath = '/practical-assessments/by-participant/tp-1';
  const comment = 'Ajuste feito somente após solicitação';
  final today = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(today.year, today.month, today.day, hour, minute);

  setUp(() async {
    api = _MockApiClient();
    auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(const AuthUser(
      id: 'user-1',
      name: 'Carla Souza',
      email: 'carla@simtc.com.br',
      role: AppUserRole.consultant,
      consultantId: 'c-eu',
    ));
    when(() => auth.isAuthenticated).thenReturn(true);
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    assessmentRepository = AssessmentRepository(database: db);
    participantRepository = ParticipantRepository(apiClient: api, database: db);
    catalogRepository = AssessmentCatalogRepository(apiClient: api, database: db);
    connectivity = ConnectivityService();

    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva',
            city: 'Itabira',
            state: 'MG',
            status: 'EM_ANDAMENTO',
            cachedAt: DateTime(2026, 9, 30, 7),
          ),
        );
    // CV com os itens 1 e 4, RR com o item 3.
    for (final (id, code, name, order) in [
      ('cat-cv', 'CV', 'Controle do Veículo', 1),
      ('cat-rr', 'RR', 'Respeito às Regras', 2),
    ]) {
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(id: id, code: code, name: name, order: order),
          );
    }
    for (final (id, category, order) in [
      ('inf-1', 'cat-cv', 1),
      ('inf-4', 'cat-cv', 4),
      ('inf-3', 'cat-rr', 3),
    ]) {
      await db.into(db.infractions).insert(
            InfractionsCompanion.insert(
              id: id,
              categoryId: category,
              description: 'Infração do item $order',
              order: order,
            ),
          );
      for (final (type, deduction) in [('B', 1), ('PM', 3), ('M', 5)]) {
        await db.into(db.infractionNotes).insert(
              InfractionNotesCompanion.insert(
                id: '$id-$type',
                infractionId: id,
                noteType: type,
                deduction: deduction,
                comment: Value(type == 'PM' ? comment : null),
              ),
            );
      }
    }
  });

  tearDown(() async {
    await db.close();
    connectivity.dispose();
  });

  Future<void> seedParticipant({required String status, double? score}) {
    return db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-1',
            sessionId: 'sess-1',
            name: 'Ana Paula Ribeiro',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: status,
            score: Value(score),
            cachedAt: DateTime(2026, 9, 30, 7),
          ),
        );
  }

  /// Confirmada neste aparelho, das 08:12 às 08:31 de hoje, com [marks]
  /// (infração → nota).
  Future<void> confirmedHere(Map<String, String> marks, {double score = 85}) async {
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
    await (db.update(db.localAssessments)..where((t) => t.id.equals(draft.id)))
        .write(LocalAssessmentsCompanion(startTime: Value(at(8, 12))));
    await assessmentRepository.confirm(
      draft.id,
      participantName: 'Ana Paula Ribeiro',
      score: score,
      endTime: at(8, 31),
    );
  }

  void serverAnswers(Object? body) {
    when(() => api.get<Object?>(resultPath)).thenAnswer(
      (_) async => Response<Object?>(
        requestOptions: RequestOptions(path: resultPath),
        statusCode: 200,
        data: body,
      ),
    );
  }

  Map<String, dynamic> serverJson() => {
        'id': 'assess-1',
        'startTime': '2026-09-30T11:12:00.000Z',
        'endTime': '2026-09-30T11:31:00.000Z',
        'score': 62.5,
        'items': [
          {
            'infractionNoteId': 'inf-1-M',
            'infractionNote': {
              'id': 'inf-1-M',
              'noteType': 'M',
              'comment': 'Não realizou nenhum ajuste',
              'deduction': 5,
              'infraction': {
                'id': 'inf-1',
                'description': 'Não ajustou o banco, cinto ou espelhos',
                'order': 1,
                'category': {'id': 'cat-cv', 'code': 'CV', 'name': 'Controle do Veículo', 'order': 1},
              },
            },
          },
        ],
      };

  Future<void> goOffline() async {
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => const Stream.empty());
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  Widget withProviders(Widget child) {
    return MultiProvider(
      providers: [
        Provider<AssessmentRepository>.value(value: assessmentRepository),
        Provider<ParticipantRepository>.value(value: participantRepository),
        Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        ChangeNotifierProvider<AuthRepository>.value(value: auth),
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
      ],
      child: child,
    );
  }

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// O Resultado empilhado sobre uma origem, pelas rotas reais do Resultado e
  /// do checklist.
  Future<void> pumpResult(WidgetTester tester, {bool justConfirmed = false}) async {
    tallScreen(tester);
    final router = GoRouter(
      initialLocation: '/origem',
      routes: [
        GoRoute(
          path: '/origem',
          builder: (context, state) => const Scaffold(body: Text('origem')),
        ),
        GoRoute(
          path: '/sessions/:sessionId/participants/:participantId/result',
          builder: (context, state) => ResultScreen(
            sessionId: state.pathParameters['sessionId']!,
            participantId: state.pathParameters['participantId']!,
            justConfirmed: state.uri.queryParameters['confirmada'] == '1',
          ),
        ),
        GoRoute(
          path: AppRoutes.participantChecklist('sess-1', 'tp-1'),
          builder: (context, state) =>
              const ChecklistScreen(sessionId: 'sess-1', participantId: 'tp-1'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(withProviders(MaterialApp.router(routerConfig: router)));
    router.push(AppRoutes.participantResult('sess-1', 'tp-1', justConfirmed: justConfirmed));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'logo depois do "Confirmar": a nota, a linha de detalhe, o aviso de '
      'fila, as categorias, as infrações e "Próximo participante"',
      (tester) async {
    await seedParticipant(status: 'EM_AVALIACAO');
    await confirmedHere({'inf-1': 'inf-1-PM'});

    await pumpResult(tester, justConfirmed: true);

    expect(find.text('Avaliação concluída'), findsOneWidget);
    expect(find.byTooltip('Fechar'), findsOneWidget);
    expect(find.text('Pontuação final'), findsOneWidget);
    expect(find.text('85,0%'), findsOneWidget);
    expect(find.text('Aprovado'), findsOneWidget);
    expect(
      find.text('Ana Paula Ribeiro · 042.118.***-** · Início 08:12 · Fim 08:31'),
      findsOneWidget,
    );
    expect(find.text('Na fila de envio — sai sozinha quando houver conexão.'),
        findsOneWidget);
    expect(find.text('Desempenho por categoria'), findsOneWidget);
    expect(find.text('70,0%'), findsOneWidget, reason: 'o selo de CV');
    expect(find.text('100,0%'), findsOneWidget, reason: 'o selo de RR');
    expect(find.text('Infrações registradas'), findsOneWidget);
    expect(find.text('Infração do item 1'), findsOneWidget);
    expect(find.text(comment), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
    expect(find.textContaining('O número de cada linha é o item'), findsOneWidget);
    expect(find.text('Próximo participante'), findsOneWidget);
    expect(find.text('Reavaliar'), findsNothing);
    expect(find.textContaining('pts'), findsNothing, reason: 'o app não tem pontos');
  });

  testWidgets(
      'os grupos de "Infrações registradas" abrem e fecham; categoria sem '
      'infração não abre', (tester) async {
    await seedParticipant(status: 'EM_AVALIACAO');
    await confirmedHere({'inf-1': 'inf-1-PM'});
    await pumpResult(tester, justConfirmed: true);

    expect(find.text('Infração do item 1'), findsOneWidget, reason: 'CV abre sozinho');

    await tester.tap(find.byKey(const ValueKey('result-group-cat-cv')));
    await tester.pumpAndSettle();
    expect(find.text('Infração do item 1'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('result-group-cat-cv')));
    await tester.pumpAndSettle();
    expect(find.text('Infração do item 1'), findsOneWidget);

    final rr = find.byKey(const ValueKey('result-group-cat-rr'));
    expect(find.descendant(of: rr, matching: find.text('sem infração')), findsOneWidget);
    expect(tester.widget<InkWell>(rr).onTap, isNull);
  });

  testWidgets('sem nenhuma infração: "Nenhuma infração registrada."', (tester) async {
    await seedParticipant(status: 'EM_AVALIACAO');
    await confirmedHere({}, score: 100);

    await pumpResult(tester, justConfirmed: true);

    expect(find.text('Nenhuma infração registrada.'), findsOneWidget);
    expect(find.textContaining('O número de cada linha é o item'), findsNothing);
  });

  testWidgets(
      'avaliação do servidor: a nota dele e as infrações da resposta, sem aviso '
      'de envio', (tester) async {
    await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
    serverAnswers(serverJson());

    await pumpResult(tester);

    expect(find.text('62,5%'), findsOneWidget);
    expect(find.text('Necessita reavaliação'), findsOneWidget);
    expect(find.text('Não ajustou o banco, cinto ou espelhos'), findsOneWidget);
    expect(find.text('Não realizou nenhum ajuste'), findsOneWidget);
    expect(find.textContaining('Na fila de envio'), findsNothing);
    expect(find.text('Reavaliar'), findsOneWidget);
  });

  testWidgets(
      'sem rede e sem avaliação no aparelho: só a nota e o status, com o aviso',
      (tester) async {
    await seedParticipant(status: 'APROVADO', score: 90);
    when(() => api.get<Object?>(resultPath)).thenThrow(
      const ApiException(message: 'Sem conexão', isNetworkError: true),
    );

    await pumpResult(tester);

    expect(find.text('90,0%'), findsOneWidget);
    expect(find.text('Aprovado'), findsOneWidget);
    expect(find.text('Sem conexão: as infrações aparecem quando houver internet.'),
        findsOneWidget);
    expect(find.text('Desempenho por categoria'), findsNothing);
    expect(find.text('Infrações registradas'), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('o servidor falhou: "Tentar novamente" busca de novo', (tester) async {
    await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
    when(() => api.get<Object?>(resultPath)).thenThrow(
      const ApiException(message: 'Internal server error', statusCode: 500),
    );
    await pumpResult(tester);
    expect(find.text('Não foi possível carregar as infrações.'), findsOneWidget);

    serverAnswers(serverJson());
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar as infrações.'), findsNothing);
    expect(find.text('Não ajustou o banco, cinto ou espelhos'), findsOneWidget);
  });

  testWidgets(
      '"Reavaliar" reserva o participante e abre o checklist em "não '
      'iniciada"; o voltar leva à tela de origem', (tester) async {
    await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
    serverAnswers(serverJson());
    when(() => api.post<Map<String, dynamic>>('/practical-assessments/assign',
        data: any(named: 'data'))).thenAnswer((_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/practical-assessments/assign'),
          statusCode: 201,
          data: {'assigned': 1},
        ));
    await pumpResult(tester);

    await tester.tap(find.text('Reavaliar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen), findsOneWidget);
    expect(find.text('não iniciada'), findsOneWidget);
    expect(find.text('Iniciar avaliação'), findsOneWidget);
    final row = await db.select(db.participants).getSingle();
    expect(row.status, 'EM_AVALIACAO');
    expect(row.assignedConsultantId, 'c-eu');

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('origem'), findsOneWidget);
  });

  testWidgets(
      '"Reavaliar" com outra avaliação em andamento: reserva mesmo assim, e o '
      'checklist avisa que só dá uma por vez', (tester) async {
    await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
    await db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-2',
            sessionId: 'sess-1',
            name: 'Marina Lopes',
            cpf: '111.222.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'EM_AVALIACAO',
            cachedAt: DateTime(2026, 9, 30, 7),
          ),
        );
    await assessmentRepository.openDraft(
      trainingParticipantId: 'tp-2',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    serverAnswers(serverJson());
    when(() => api.post<Map<String, dynamic>>('/practical-assessments/assign',
        data: any(named: 'data'))).thenAnswer((_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/practical-assessments/assign'),
          statusCode: 201,
          data: {'assigned': 1},
        ));
    await pumpResult(tester);

    await tester.tap(find.text('Reavaliar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen), findsOneWidget);
    expect(
      find.text('Você já está avaliando Marina Lopes. Finalize ou descarte essa '
          'avaliação para iniciar outra.'),
      findsOneWidget,
    );
    final row = await (db.select(db.participants)..where((t) => t.id.equals('tp-1')))
        .getSingle();
    expect(row.status, 'EM_AVALIACAO', reason: 'a reserva aconteceu');
  });

  testWidgets('sem rede, "Reavaliar" fica desabilitado e diz por quê', (tester) async {
    await seedParticipant(status: 'NECESSITA_REAVALIACAO', score: 62.5);
    when(() => api.get<Object?>(resultPath)).thenThrow(
      const ApiException(message: 'Sem conexão', isNetworkError: true),
    );
    await goOffline();

    await pumpResult(tester);

    final button = tester.widget<AppCtaButton>(find.widgetWithText(AppCtaButton, 'Reavaliar'));
    expect(button.onPressed, isNull);
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
  });

  testWidgets('o X e o "Próximo participante" voltam à tela de origem', (tester) async {
    await seedParticipant(status: 'EM_AVALIACAO');
    await confirmedHere({'inf-1': 'inf-1-PM'});

    await pumpResult(tester, justConfirmed: true);
    await tester.tap(find.text('Próximo participante'));
    await tester.pumpAndSettle();
    expect(find.text('origem'), findsOneWidget);

    await pumpResult(tester, justConfirmed: true);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('origem'), findsOneWidget);
  });
}
```

Em `test/ui/session_detail/session_detail_screen_test.dart`:

Substituir (1 de 4):

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/evaluation/evaluation_placeholder_screen.dart';
import 'package:simtc/ui/session_detail/participant_row.dart';
```

por:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/session_detail/participant_row.dart';
```

Substituir (2 de 4):

```dart

    testWidgets('um concluído abre o resultado (provisório)', (tester) async {
      await showWithRouter(tester, [
        participant('4', 'Juliana Freitas Costa',
            status: ParticipantStatus.aprovado, score: 86),
      ]);
```

por:

```dart

    testWidgets('um concluído abre o Resultado', (tester) async {
      final juliana = participant('4', 'Juliana Freitas Costa',
          status: ParticipantStatus.aprovado, score: 86);
      when(() => participants.watchParticipant('4'))
          .thenAnswer((_) => Stream.value(juliana));
      when(() => participants.fetchAssessment('4'))
          .thenAnswer((_) async => const Success(null));
      when(() => assessments.findByParticipant('4')).thenAnswer((_) async => null);
      await showWithRouter(tester, [juliana]);
```

Substituir (3 de 4):

```dart

      final screen = tester.widget<EvaluationPlaceholderScreen>(
        find.byType(EvaluationPlaceholderScreen),
      );
      expect(screen.kind, EvaluationPlaceholderKind.result);
    });
```

por:

```dart

      final screen = tester.widget<ResultScreen>(find.byType(ResultScreen));
      expect(screen.participantId, '4');
      expect(screen.justConfirmed, isFalse);
      expect(find.text('Avaliação concluída'), findsOneWidget);
      expect(find.text('86,0%'), findsOneWidget);
    });
```

Substituir (4 de 4):

```dart

      expect(find.byType(EvaluationPlaceholderScreen), findsNothing);
    });
```

por:

```dart

      expect(find.byType(ResultScreen), findsNothing);
      expect(find.byType(ChecklistScreen), findsNothing);
    });
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/ui/result/result_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart`
Esperado: os dois arquivos não compilam — `Error when reading 'lib/ui/result/result_screen.dart'`, `Method not found: 'ResultScreen'` e `No named parameter with the name 'justConfirmed'`.

- [ ] **Step 3: O bloco da nota, a barra de topo, o botão e os tokens**

Criar `lib/ui/core/widgets/final_score_block.dart`:

```dart
import 'package:flutter/material.dart';

import '../score_labels.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// O topo da tela 1.6 e do Resultado (canvas "2e" e "2g"): "Pontuação final",
/// o % em destaque e a pílula "Aprovado"/"Necessita reavaliação", com as
/// linhas de detalhe embaixo.
class FinalScoreBlock extends StatelessWidget {
  const FinalScoreBlock({
    super.key,
    required this.score,
    required this.approved,
    this.details = const [],
  });

  /// Nulo quando não há nota a mostrar: aparece "—".
  final double? score;

  /// Nulo esconde a pílula.
  final bool? approved;

  /// Linhas abaixo do % — as vazias não aparecem.
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final score = this.score;
    final approved = this.approved;
    final lines = details.where((line) => line.isNotEmpty).toList(growable: false);

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
                      score == null ? '—' : percentLabel(score),
                      style: AppTypography.summaryScore,
                    ),
                  ],
                ),
              ),
              if (approved != null) ...[
                const SizedBox(width: AppSpacing.md),
                _ResultPill(approved: approved),
              ],
            ],
          ),
          for (var i = 0; i < lines.length; i++) ...[
            SizedBox(height: i == 0 ? AppSpacing.md + 2 : AppSpacing.xs),
            Text(lines[i], style: AppTypography.summaryDetail),
          ],
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

Em `lib/ui/summary/summary_screen.dart`:

Substituir (1 de 4):

```dart
import '../checklist/checklist_sections.dart';
import '../core/score_labels.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../checklist/checklist_sections.dart';
import '../core/theme/app_colors.dart';
```

Substituir (2 de 4):

```dart
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/inline_notice.dart';
```

por:

```dart
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/final_score_block.dart';
import '../core/widgets/inline_notice.dart';
```

Substituir (3 de 4):

```dart
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
          if (_viewModel.timesLabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_viewModel.timesLabel!, style: AppTypography.summaryDetail),
          ],
        ],
      ),
    );
```

por:

```dart
  Widget _buildScore() {
    return FinalScoreBlock(
      score: _viewModel.overallScore,
      approved: _viewModel.isApproved,
      details: [_detailLine(), if (_viewModel.timesLabel case final times?) times],
    );
```

Substituir (4 de 4):

```dart
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

por:

```dart
}
```

Em `lib/ui/core/widgets/app_top_bar.dart`:

Substituir (1 de 4):

```dart

/// Barra superior das telas empilhadas (detalhe da sessão e, nas próximas
/// fases, checklist, resumo e resultado): voltar à esquerda, título
/// centralizado e, opcionalmente, um atalho à direita.
///
```

por:

```dart

/// Barra superior das telas empilhadas (detalhe da sessão, resumo e
/// resultado): voltar à esquerda, título centralizado e, opcionalmente, um
/// atalho à direita.
///
```

Substituir (2 de 4):

```dart
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, required this.title, this.trailing});
```

por:

```dart
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.trailing,
    this.leadingIcon = AppIcons.back,
    this.leadingIconSize = 30,
    this.leadingTooltip = 'Voltar',
  });
```

Substituir (3 de 4):

```dart
  final Widget? trailing;
```

por:

```dart
  final Widget? trailing;

  /// O botão da esquerda: o voltar, ou o fechar do Resultado (canvas "2g").
  final IconData leadingIcon;
  final double leadingIconSize;
  final String leadingTooltip;
```

Substituir (4 de 4):

```dart
            child: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(AppIcons.back, size: 30, color: AppColors.text),
              // `maybePop` funciona igual sob o go_router e num
```

por:

```dart
            child: IconButton(
              tooltip: leadingTooltip,
              icon: Icon(leadingIcon, size: leadingIconSize, color: AppColors.text),
              // `maybePop` funciona igual sob o go_router e num
```

Em `lib/ui/core/widgets/app_buttons.dart`:

Substituir (1 de 3):

```dart
    this.icon,
    this.size = AppCtaSize.compact,
```

por:

```dart
    this.icon,
    this.trailingIcon,
    this.size = AppCtaSize.compact,
```

Substituir (2 de 3):

```dart
  final IconData? icon;
  final AppCtaSize size;
```

por:

```dart
  final IconData? icon;

  /// Ícone depois do rótulo — o "›" do "Próximo participante" (canvas "2g").
  final IconData? trailingIcon;
  final AppCtaSize size;
```

Substituir (3 de 3):

```dart
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
```

por:

```dart
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(trailingIcon, size: _large ? 25 : 21),
        ],
      ],
```

Em `lib/ui/core/theme/app_icons.dart`:

Substituir:

```dart
  static const IconData more = Icons.more_vert;
}
```

por:

```dart
  static const IconData more = Icons.more_vert;

  /// Fechar o Resultado (canvas "2g").
  static const IconData close = Icons.close;
}
```

Em `lib/ui/core/theme/app_typography.dart`:

Substituir:

```dart

  /// Campo de senha mascarado
```

por:

```dart

  // ─── Resultado (quadro "2g" do canvas) ────────────────────────────────────

  /// Nota da infração ("PM") no selo de cor cheia das infrações registradas
  static TextStyle get resultNoteBadge =>
      _inter(size: 10, weight: FontWeight.w700, height: 1, color: AppColors.surface);

  /// Campo de senha mascarado
```

- [ ] **Step 4: A tela, a rota e o fim da provisória**

Criar `lib/ui/result/result_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/local/app_database.dart';
import '../../router.dart';
import '../checklist/checklist_badges.dart';
import '../checklist/checklist_sections.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/final_score_block.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/skeleton.dart';
import 'result_details.dart';
import 'result_viewmodel.dart';

/// Tela 1.8 — Resultado ("Avaliação concluída", quadro "2g" do canvas),
/// adaptada em 01/10/2026: sem pontos, com início e fim no lugar da duração,
/// o número do item em cada infração, o aviso de envio e o "Reavaliar".
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.sessionId,
    required this.participantId,
    this.justConfirmed = false,
  });

  final String sessionId;
  final String participantId;

  /// Aberta logo depois do "Confirmar" da tela 1.6: o rodapé é o "Próximo
  /// participante".
  final bool justConfirmed;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final ResultViewModel _viewModel = _createViewModel()..init();

  /// Categorias abertas em "Infrações registradas". Começa com a primeira que
  /// tem infração, como no canvas; nulo até os dados chegarem.
  Set<String>? _open;

  ResultViewModel _createViewModel() {
    // A rota só abre com sessão (redirecionamento do `router.dart`).
    final user = context.read<AuthRepository>().currentUser!;
    return ResultViewModel(
      sessionId: widget.sessionId,
      participantId: widget.participantId,
      ownerUserId: user.id,
      consultantId: user.consultantId,
      consultantName: user.name,
      justConfirmed: widget.justConfirmed,
      assessmentRepository: context.read<AssessmentRepository>(),
      participantRepository: context.read<ParticipantRepository>(),
      catalogRepository: context.read<AssessmentCatalogRepository>(),
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
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
    final footer = _buildFooter(isOffline);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(
              title: 'Avaliação concluída',
              leadingIcon: AppIcons.close,
              leadingIconSize: 26,
              leadingTooltip: 'Fechar',
            ),
            Expanded(child: _buildBody()),
            if (footer != null) footer,
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return ListView(
        key: const Key('result-skeleton'),
        children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
      );
    }

    final categories = _viewModel.categories;
    final withScore = [
      for (final category in categories ?? const <ResultCategory>[])
        if (category.score != null) category,
    ];
    final count = _viewModel.infractionCount;

    return ListView(
      children: [
        _buildScore(),
        ..._buildNotices(),
        if (withScore.isNotEmpty) ...[
          _buildSectionHeader('Desempenho por categoria'),
          _buildPerformance(withScore),
        ],
        if (categories != null) ...[
          _buildSectionHeader(
            'Infrações registradas',
            trailing: count == 0 ? null : infractionCountLabel(count),
          ),
          ..._buildInfractions(categories),
        ],
      ],
    );
  }

  /// "Ana Paula Ribeiro · 042.118.***-** · Início 08:12 · Fim 08:31".
  Widget _buildScore() {
    final participant = _viewModel.participant;
    final detail = [
      if (participant != null && participant.name.isNotEmpty) participant.name,
      if (participant != null) participant.maskedCpf,
      if (_viewModel.timesLabel case final times?) times,
    ].join(' · ');

    return FinalScoreBlock(
      score: _viewModel.score,
      approved: _viewModel.isApproved,
      details: [detail],
    );
  }

  /// O estado do envio da avaliação deste aparelho e o aviso sobre de onde
  /// vieram os dados — os dois só aparecem quando há o que dizer.
  List<Widget> _buildNotices() {
    final send = _viewModel.sendNotice;
    final data = _viewModel.dataNotice;
    final notices = <Widget>[
      if (send != null) _sendNotice(send, _viewModel.sendStatus),
      if (data != null) _dataNotice(data),
      if (_viewModel.canRetry)
        AppSecondaryButton(
          label: 'Tentar novamente',
          icon: AppIcons.retry,
          onPressed: _viewModel.retry,
        ),
    ];

    return [
      for (final notice in notices)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
          child: notice,
        ),
    ];
  }

  Widget _sendNotice(String message, LocalSyncStatus? status) {
    final (icon, tone) = switch (status) {
      LocalSyncStatus.error => (AppIcons.sendFailed, NoticeTone.danger),
      LocalSyncStatus.synced => (AppIcons.syncDone, NoticeTone.success),
      _ => (AppIcons.pending, NoticeTone.neutral),
    };
    return InlineNotice(icon: icon, tone: tone, message: message);
  }

  Widget _dataNotice(ResultDataNotice notice) {
    final (icon, tone, message) = switch (notice) {
      ResultDataNotice.deviceFallback => (
          AppIcons.offline,
          NoticeTone.neutral,
          'Mostrando a avaliação feita neste aparelho.',
        ),
      ResultDataNotice.offline => (
          AppIcons.offline,
          NoticeTone.warning,
          'Sem conexão: as infrações aparecem quando houver internet.',
        ),
      ResultDataNotice.serverFailed => (
          AppIcons.needsReview,
          NoticeTone.danger,
          'Não foi possível carregar as infrações.',
        ),
      ResultDataNotice.notOnServer => (
          AppIcons.needsReview,
          NoticeTone.neutral,
          'Não há avaliação registrada no servidor para este participante.',
        ),
    };
    return InlineNotice(icon: icon, tone: tone, message: message);
  }

  Widget _buildSectionHeader(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.sectionTitle)),
          if (trailing != null) Text(trailing, style: AppTypography.categoryCount),
        ],
      ),
    );
  }

  /// "Desempenho por categoria": o código, o nome, quantas infrações e o
  /// selo de % — no lugar dos pontos do canvas, que o app não tem.
  Widget _buildPerformance(List<ResultCategory> categories) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xs),
      child: Column(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xl),
            _buildPerformanceRow(categories[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(ResultCategory category) {
    return Row(
      key: ValueKey('result-performance-${category.id}'),
      children: [
        CategoryCodeChip(code: category.code),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Text(
            category.name,
            style: AppTypography.categoryName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Text(infractionCountLabel(category.infractions.length), style: AppTypography.categoryCount),
        const SizedBox(width: AppSpacing.sm + 2),
        ScoreBadge(score: category.score!),
      ],
    );
  }

  List<Widget> _buildInfractions(List<ResultCategory> categories) {
    if (_viewModel.infractionCount == 0) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          child: Text('Nenhuma infração registrada.', style: AppTypography.body),
        ),
      ];
    }

    final open = _open ??= {
      if (categories.where((c) => c.infractions.isNotEmpty).firstOrNull case final first?)
        first.id,
    };

    return [
      for (final category in categories) ...[
        _buildGroupHeader(category, open.contains(category.id)),
        if (open.contains(category.id))
          for (final infraction in category.infractions) _buildInfraction(infraction),
      ],
      _buildFootnote(),
    ];
  }

  /// Cabeçalho de um grupo de "Infrações registradas": abre e fecha o grupo.
  /// Sem infração na categoria, não há o que abrir.
  Widget _buildGroupHeader(ResultCategory category, bool isOpen) {
    final hasInfractions = category.infractions.isNotEmpty;

    return InkWell(
      key: ValueKey('result-group-${category.id}'),
      onTap: hasInfractions
          ? () => setState(() {
                final open = _open!;
                if (!open.remove(category.id)) open.add(category.id);
              })
          : null,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: isOpen ? AppColors.categoryExpandedBg : AppColors.surface,
          border: const Border.symmetric(
            horizontal: BorderSide(color: AppColors.categoryExpandedBorder),
          ),
        ),
        child: Row(
          children: [
            CategoryCodeChip(
              code: category.code,
              background: isOpen ? AppColors.primary : AppColors.categoryChipBg,
              ink: isOpen ? AppColors.surface : AppColors.primaryDark,
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                category.name,
                style: AppTypography.categoryName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Text(
              infractionCountLabel(category.infractions.length),
              style: AppTypography.categoryCount,
            ),
            if (hasInfractions) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                isOpen ? AppIcons.expandLess : AppIcons.expandMore,
                size: 22,
                color: AppColors.text3,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfraction(ResultInfraction infraction) {
    final comment = infraction.comment;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoteBadge(noteType: infraction.noteType),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // O número é o item na ficha oficial, como no checklist.
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 14),
                      child: Text('${infraction.number}', style: AppTypography.infractionNumber),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(infraction.description, style: AppTypography.infractionDescription),
                    ),
                  ],
                ),
                if (comment != null) ...[
                  const SizedBox(height: AppSpacing.xs + 1),
                  Text(comment, style: AppTypography.summaryDetail),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFootnote() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md + 2,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Text(
        'O número de cada linha é o item da categoria na ficha oficial — é por '
        'ele que a infração é localizada em caso de contestação.',
        style: AppTypography.meta,
      ),
    );
  }

  /// Um botão no máximo: "Próximo participante" logo depois do "Confirmar",
  /// ou "Reavaliar" para quem está em "Necessita reavaliação". Nos outros
  /// casos, o X fecha a tela.
  Widget? _buildFooter(bool isOffline) {
    if (_viewModel.isLoading) return null;

    final Widget content;
    if (_viewModel.justConfirmed) {
      content = AppCtaButton(
        label: 'Próximo participante',
        trailingIcon: AppIcons.chevronRight,
        size: AppCtaSize.large,
        // Volta ao detalhe da sessão, onde o consultor escolhe quem avaliar
        // em seguida (decisão de 01/10/2026).
        onPressed: () => Navigator.of(context).maybePop(),
      );
    } else if (_viewModel.canReevaluate) {
      final error = _viewModel.reevaluateError;
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            InlineNotice(icon: AppIcons.needsReview, tone: NoticeTone.danger, message: error),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppCtaButton(
            label: 'Reavaliar',
            icon: AppIcons.retry,
            size: AppCtaSize.large,
            isLoading: _viewModel.isReevaluating,
            onPressed: isOffline ? null : _reevaluate,
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
      );
    } else {
      return null;
    }

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
      child: content,
    );
  }

  /// "Reavaliar": reserva o participante e troca o Resultado pelo checklist
  /// em "não iniciada" — a nova avaliação só começa no "Iniciar avaliação".
  /// O voltar do checklist leva ao detalhe da sessão.
  Future<void> _reevaluate() async {
    final reserved = await _viewModel.reevaluate();
    if (!reserved || !mounted) return;
    context.pushReplacement(
      AppRoutes.participantChecklist(widget.sessionId, widget.participantId),
    );
  }
}

/// A nota da infração ("PM") na cor cheia dela — o selo das linhas de
/// "Infrações registradas" (canvas "2g").
class _NoteBadge extends StatelessWidget {
  const _NoteBadge({required this.noteType});

  final String noteType;

  Color get _fill => switch (noteType) {
        'B' => AppColors.noteBFill,
        'PM' => AppColors.notePmFill,
        _ => AppColors.noteMFill,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: AppSpacing.xxl + 1,
        minHeight: AppSpacing.xl,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(noteType, style: AppTypography.resultNoteBadge),
    );
  }
}
```

Em `lib/router.dart`:

Substituir (1 de 3):

```dart
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/evaluation/evaluation_placeholder_screen.dart';
import 'ui/session_detail/session_detail_screen.dart';
```

por:

```dart
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/result/result_screen.dart';
import 'ui/session_detail/session_detail_screen.dart';
```

Substituir (2 de 3):

```dart

  /// Resultado do participante (Fase 5) — por ora, uma tela provisória.
  static String participantResult(String sessionId, String participantId) =>
      '/sessions/$sessionId/participants/$participantId/result';
}
```

por:

```dart

  /// Resultado do participante (tela 1.8, Fase 5B). [justConfirmed]: aberto
  /// logo depois do "Confirmar" da tela 1.6 — o rodapé é o "Próximo
  /// participante".
  static String participantResult(
    String sessionId,
    String participantId, {
    bool justConfirmed = false,
  }) =>
      '/sessions/$sessionId/participants/$participantId/result'
      '${justConfirmed ? '?confirmada=1' : ''}';
}
```

Substituir (3 de 3):

```dart
            path: 'participants/:participantId/result',
            builder: (context, state) => EvaluationPlaceholderScreen(
              kind: EvaluationPlaceholderKind.result,
              participantName: state.extra as String?,
            ),
```

por:

```dart
            path: 'participants/:participantId/result',
            builder: (context, state) => ResultScreen(
              sessionId: state.pathParameters['sessionId']!,
              participantId: state.pathParameters['participantId']!,
              justConfirmed: state.uri.queryParameters['confirmada'] == '1',
            ),
```

Em `lib/ui/session_detail/session_detail_screen.dart`:

Substituir (1 de 2):

```dart

  /// Para onde a linha leva: o checklist (Fase 4) ou o resultado — este ainda
  /// é uma tela provisória, até a Fase 5B. O checklist lê o nome do banco, por
  /// isso não recebe `extra`. Na fila ou enviada, a linha não leva a lugar
  /// nenhum.
  VoidCallback? _tapActionFor(SessionParticipant participant) {
```

por:

```dart

  /// Para onde a linha leva: o checklist (Fase 4) ou o Resultado (Fase 5B).
  /// Os dois leem o participante do banco, por isso não recebem `extra`. Na
  /// fila ou enviada, a linha não leva a lugar nenhum.
  VoidCallback? _tapActionFor(SessionParticipant participant) {
```

Substituir (2 de 2):

```dart
            AppRoutes.participantResult(widget.sessionId, participant.id),
            extra: participant.name,
          );
```

por:

```dart
            AppRoutes.participantResult(widget.sessionId, participant.id),
          );
```

Apagar `lib/ui/evaluation/evaluation_placeholder_screen.dart`.

(A pasta `lib/ui/evaluation/` fica vazia e sai junto.)

- [ ] **Step 5: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **451 testes passando**.

- [ ] **Step 6: Commit**

O `git add` do arquivo apagado registra a remoção:

```bash
git add lib/ui/core/widgets/final_score_block.dart lib/ui/result/result_screen.dart lib/ui/summary/summary_screen.dart lib/ui/core/widgets/app_top_bar.dart lib/ui/core/widgets/app_buttons.dart lib/ui/core/theme/app_icons.dart lib/ui/core/theme/app_typography.dart lib/router.dart lib/ui/session_detail/session_detail_screen.dart lib/ui/evaluation/evaluation_placeholder_screen.dart test/ui/result/result_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart
git commit -m "feat(mobile): tela 1.8 de resultado no lugar da provisoria"
```

---

## Task 9: O "Confirmar" e as linhas da fila abrem o Resultado

A navegação das decisões 2 e 12: o "Confirmar" da 1.6 troca o checklist pelo Resultado (`pushReplacement`, com `justConfirmed`), e as linhas "Na fila", "Erro no envio" e "Enviada" do detalhe passam a abrir o Resultado — o checklist continua fechado para avaliação confirmada.

**Files:**
- Modify: `lib/ui/checklist/checklist_screen.dart` — `_openSummary`
- Modify: `lib/ui/session_detail/session_detail_viewmodel.dart` — `opensResult`
- Modify: `lib/ui/session_detail/session_detail_screen.dart` — comentário do `_tapActionFor`
- Test: `test/ui/checklist/checklist_screen_test.dart`, `test/ui/session_detail/session_detail_viewmodel_test.dart`, `test/ui/session_detail/session_detail_screen_test.dart`

**Interfaces:**
- Consumes: `AppRoutes.participantResult(…, justConfirmed: true)` e `ResultScreen` (Task 8); `localProgressFor` (5A).
- Produces: `SessionDetailViewModel.opensResult` também para `LocalProgress.queued`, `failed` e `sent`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/checklist/checklist_screen_test.dart`:

Substituir (1 de 5):

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/summary/summary_screen.dart';
```

por:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/summary/summary_screen.dart';
```

Substituir (2 de 5):

```dart
          builder: (context, state) => const SummaryScreen(participantId: 'tp-1'),
        ),
```

por:

```dart
          builder: (context, state) => const SummaryScreen(participantId: 'tp-1'),
        ),
        GoRoute(
          path: '/sessions/:sessionId/participants/:participantId/result',
          builder: (context, state) => ResultScreen(
            sessionId: state.pathParameters['sessionId']!,
            participantId: state.pathParameters['participantId']!,
            justConfirmed: state.uri.queryParameters['confirmada'] == '1',
          ),
        ),
```

Substituir (3 de 5):

```dart
  testWidgets(
      '"Confirmar" na conferência põe na fila e fecha o checklist junto, '
      'de volta à tela de origem', (tester) async {
    await pumpOverOrigin(tester);
```

por:

```dart
  testWidgets(
      '"Confirmar" na conferência põe na fila e troca o checklist pelo '
      'Resultado; "Próximo participante" volta à tela de origem', (tester) async {
    await pumpOverOrigin(tester);
```

Substituir (4 de 5):

```dart
    expect(find.byType(ChecklistScreen), findsNothing);
    expect(find.text('origem'), findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
```

por:

```dart
    expect(find.byType(ChecklistScreen), findsNothing);
    final result = tester.widget<ResultScreen>(find.byType(ResultScreen));
    expect(result.justConfirmed, isTrue);
    expect(find.text('Avaliação concluída'), findsOneWidget);
    expect(find.text('Na fila de envio — sai sozinha quando houver conexão.'),
        findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
```

Substituir (5 de 5):

```dart
    expect(row.participantName, 'Ana Paula Ribeiro');
  });
```

por:

```dart
    expect(row.participantName, 'Ana Paula Ribeiro');

    await tester.tap(find.text('Próximo participante'));
    await tester.pumpAndSettle();

    expect(find.text('origem'), findsOneWidget);
  });
```

Em `test/ui/session_detail/session_detail_viewmodel_test.dart`:

Substituir (1 de 2):

```dart
      expect(vm.opensChecklist(erro), isFalse);
    });
```

por:

```dart
      expect(vm.opensChecklist(erro), isFalse);
      // Confirmada, a linha abre o Resultado, só para leitura (decisão de
      // 01/10/2026).
      expect(vm.opensResult(rascunho), isFalse);
      expect(vm.opensResult(fila), isTrue);
      expect(vm.opensResult(erro), isTrue);
    });
```

Substituir (2 de 2):

```dart
      expect(vm.opensChecklist(meu), isFalse);
    });
```

por:

```dart
      expect(vm.opensChecklist(meu), isFalse);
      expect(vm.opensResult(meu), isTrue);
    });
```

Em `test/ui/session_detail/session_detail_screen_test.dart`:

Substituir (1 de 5):

```dart
      expect(find.text('86,7% · aguardando envio'), findsOneWidget);
      expect(find.text('Avaliando · você'), findsNothing);
      expect(row(tester).onTap, isNull);
    });
```

por:

```dart
      expect(find.text('86,7% · aguardando envio'), findsOneWidget);
      expect(find.text('Avaliando · você'), findsNothing);
      expect(row(tester).onTap, isNotNull, reason: 'abre o Resultado');
    });
```

Substituir (2 de 5):

```dart
      expect(find.text('62,0% · falhou às 07:58'), findsOneWidget);
      expect(row(tester).onTap, isNull);
    });
```

por:

```dart
      expect(find.text('62,0% · falhou às 07:58'), findsOneWidget);
      expect(row(tester).onTap, isNotNull, reason: 'abre o Resultado');
    });
```

Substituir (3 de 5):

```dart
        'enviada e aceita, mas a sessão ainda não foi baixada de novo: chip '
        '"Enviada" e a linha não abre mais nada', (tester) async {
      final now = DateTime.now();
```

por:

```dart
        'enviada e aceita, mas a sessão ainda não foi baixada de novo: chip '
        '"Enviada", e a linha abre o Resultado', (tester) async {
      final now = DateTime.now();
```

Substituir (4 de 5):

```dart
      expect(find.text('Avaliando · você'), findsNothing);
      expect(row(tester).onTap, isNull);
    });
```

por:

```dart
      expect(find.text('Avaliando · você'), findsNothing);
      expect(row(tester).onTap, isNotNull, reason: 'abre o Resultado');
    });
```

Substituir (5 de 5):

```dart

    testWidgets('pendente e de outro consultor não abrem nada', (tester) async {
```

por:

```dart

    testWidgets('a linha "Na fila" abre o Resultado, só para leitura', (tester) async {
      final ana = participant('1', 'Ana Paula Ribeiro',
          status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final queued = local('1', LocalSyncStatus.pendingSync, score: 86.6667);
      when(() => participants.watchParticipant('1'))
          .thenAnswer((_) => Stream.value(ana));
      when(() => assessments.findByParticipant('1')).thenAnswer((_) async => queued);
      when(() => assessments.loadItems(queued.id)).thenAnswer((_) async => const []);
      await showWithRouter(tester, [ana]);
      localStream.add([queued]);
      await tester.pump();

      await tester.tap(find.text('Ana Paula Ribeiro'));
      await tester.pumpAndSettle();

      final screen = tester.widget<ResultScreen>(find.byType(ResultScreen));
      expect(screen.justConfirmed, isFalse);
      expect(find.byType(ChecklistScreen), findsNothing);
      expect(find.text('Avaliação concluída'), findsOneWidget);
    });

    testWidgets('pendente e de outro consultor não abrem nada', (tester) async {
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/ui/checklist/checklist_screen_test.dart test/ui/session_detail`
Esperado: 7 falhas — no `session_detail_viewmodel_test.dart`, as duas que agora esperam `opensResult` nas linhas confirmadas; no `checklist_screen_test.dart`, o "Confirmar" que agora troca o checklist pelo Resultado (hoje volta à origem); no `session_detail_screen_test.dart`, as linhas "Na fila", "Erro no envio" e "Enviada" (hoje sem toque) e "a linha "Na fila" abre o Resultado".

- [ ] **Step 3: Implementar**

Em `lib/ui/checklist/checklist_screen.dart`:

Substituir:

```dart
      case SummaryConfirmed():
        // Confirmada: o checklist sai também, de volta ao detalhe da sessão.
        await Navigator.of(context).maybePop();
      case SummaryReviewCategory(:final categoryId):
```

por:

```dart
      case SummaryConfirmed():
        // Confirmada: o Resultado ("Avaliação concluída") toma o lugar do
        // checklist, como no canvas — o X e o "Próximo participante" de lá
        // voltam ao detalhe da sessão (decisão de 01/10/2026).
        context.pushReplacement(
          AppRoutes.participantResult(
            widget.sessionId,
            widget.participantId,
            justConfirmed: true,
          ),
        );
      case SummaryReviewCategory(:final categoryId):
```

Em `lib/ui/session_detail/session_detail_viewmodel.dart`:

Substituir:

```dart

  bool opensResult(SessionParticipant participant) {
    final situation = situationFor(participant);
    return situation == ParticipantSituation.approved ||
        situation == ParticipantSituation.needsReview;
  }
```

por:

```dart

  /// Os concluídos no servidor, e a avaliação confirmada deste aparelho —
  /// na fila, com erro ou enviada esperando o novo download: o Resultado, só
  /// para leitura (decisão de 01/10/2026).
  bool opensResult(SessionParticipant participant) {
    final situation = situationFor(participant);
    if (situation == ParticipantSituation.approved ||
        situation == ParticipantSituation.needsReview) {
      return true;
    }
    return switch (localProgressFor(participant)) {
      LocalProgress.queued || LocalProgress.failed || LocalProgress.sent => true,
      LocalProgress.draft || null => false,
    };
  }
```

Em `lib/ui/session_detail/session_detail_screen.dart`:

Substituir:

```dart

  /// Para onde a linha leva: o checklist (Fase 4) ou o Resultado (Fase 5B).
  /// Os dois leem o participante do banco, por isso não recebem `extra`. Na
  /// fila ou enviada, a linha não leva a lugar nenhum.
  VoidCallback? _tapActionFor(SessionParticipant participant) {
```

por:

```dart

  /// Para onde a linha leva: o checklist (Fase 4) ou o Resultado (Fase 5B) —
  /// também o da avaliação confirmada neste aparelho. Os dois leem o
  /// participante do banco, por isso não recebem `extra`.
  VoidCallback? _tapActionFor(SessionParticipant participant) {
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **452 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/checklist/checklist_screen.dart lib/ui/session_detail/session_detail_viewmodel.dart lib/ui/session_detail/session_detail_screen.dart test/ui/checklist/checklist_screen_test.dart test/ui/session_detail/session_detail_viewmodel_test.dart test/ui/session_detail/session_detail_screen_test.dart
git commit -m "feat(mobile): confirmar e linhas da fila abrem o resultado"
```

---

## Task 10: "Descartar" o item que o servidor recusa

A decisão 11. A aba não tem ViewModel: o estado é todo do `AssessmentSyncService`, que ganha o `discardRefused`; o serviço falso dos testes o registra e tira o item da fila, como o stream do banco faria. O botão aparece só nos itens com "recusada pelo servidor", ao lado do "Tentar novamente", e fica desabilitado enquanto há um envio no ar.

**Files:**
- Modify: `lib/data/services/assessment_sync_service.dart` — `discardRefused`
- Modify: `lib/ui/core/theme/app_icons.dart` — `discard`
- Modify: `lib/ui/sync/sync_screen.dart` — "Descartar"
- Modify: `test/support/fake_assessment_sync_service.dart` — `discardRefused`, `discardCalls`
- Test: `test/data/services/assessment_sync_service_test.dart`, `test/ui/sync/sync_screen_test.dart`

**Interfaces:**
- Consumes: `AssessmentRepository.discardFailed` (Task 3); `SendFailure.refused`; `queueItemTitle`.
- Produces: `Future<bool> AssessmentSyncService.discardRefused(String localAssessmentId)`; `AppIcons.discard` (`Icons.delete_outline`); `FakeAssessmentSyncService.discardCalls`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/data/services/assessment_sync_service_test.dart`:

Substituir:

```dart

  test('mostra à tela a última sincronização aceita', () async {
```

por:

```dart

  test('"Descartar" apaga a avaliação que o servidor recusou e tira da fila',
      () async {
    answer((_) => 'Participante removido da sessão');
    final sync = startService();
    final refused = await confirmed('tp-1');
    await until(() async => await statusOf(refused.id) == LocalSyncStatus.error);
    expect((await row(refused.id)).lastError, SendFailure.refused);

    expect(await sync.discardRefused(refused.id), isTrue);

    await until(() => sync.queue.isEmpty);
    expect(await db.select(db.localAssessments).get(), isEmpty);
  });

  test('"Descartar" não apaga a avaliação que falhou por rede', () async {
    failWith(semRede);
    final sync = startService();
    final failed = await confirmed('tp-1');
    await until(() async => await statusOf(failed.id) == LocalSyncStatus.error);

    expect(await sync.discardRefused(failed.id), isFalse);
    expect(await statusOf(failed.id), LocalSyncStatus.error);
  });

  test('mostra à tela a última sincronização aceita', () async {
```

O serviço falso não é arquivo de teste — o `flutter test` só roda `*_test.dart`.

Em `test/support/fake_assessment_sync_service.dart`:

Substituir (1 de 2):

```dart
  int syncNowCalls = 0;

  @override
  List<LocalAssessment> get queue => _queue;
```

por:

```dart
  int syncNowCalls = 0;

  /// As avaliações que a tela pediu para descartar.
  final List<String> discardCalls = [];

  @override
  List<LocalAssessment> get queue => _queue;
```

Substituir (2 de 2):

```dart
  Future<void> syncNow() async => syncNowCalls++;
```

por:

```dart
  Future<void> syncNow() async => syncNowCalls++;

  /// Descarta e tira da fila, como o stream do banco faria.
  @override
  Future<bool> discardRefused(String localAssessmentId) async {
    discardCalls.add(localAssessmentId);
    setQueue(
      [for (final item in _queue) if (item.id != localAssessmentId) item],
      sendingIds: _sendingIds,
    );
    return true;
  }
```

Em `test/ui/sync/sync_screen_test.dart`:

Substituir:

```dart
      ];
```

por:

```dart
      ];

  testWidgets(
      'item recusado pelo servidor: "Descartar" pede confirmação e tira a '
      'avaliação da fila', (tester) async {
    final refused = queuedAssessment(
      '3',
      participantName: 'Marcos Vinícius Alves',
      status: LocalSyncStatus.error,
      lastAttemptAt: DateTime(2026, 9, 29, 8, 5),
      lastError: SendFailure.refused,
    );
    await pump(tester, queue: [refused]);

    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar a avaliação?'), findsOneWidget);
    expect(
      find.text('A avaliação de Marcos Vinícius Alves não foi aceita pelo '
          'servidor e será apagada deste aparelho.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(sync.discardCalls, isEmpty);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await tester.pumpAndSettle();

    expect(sync.discardCalls, [refused.id]);
    expect(find.text('Marcos Vinícius Alves'), findsNothing);
  });

  testWidgets('falha de rede ou de tempo não tem "Descartar": tenta sozinha',
      (tester) async {
    await pump(tester, queue: filaDoCanvas());

    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Descartar'), findsNothing);
  });
```

- [ ] **Step 2: Rodar e confirmar que falham**

Run: `flutter test test/data/services/assessment_sync_service_test.dart test/ui/sync/sync_screen_test.dart`
Esperado: `assessment_sync_service_test.dart` não compila (`The method 'discardRefused' isn't defined for the type 'AssessmentSyncService'`); no `sync_screen_test.dart`, falha "item recusado pelo servidor: "Descartar"…" (não há o botão). "falha de rede ou de tempo não tem "Descartar"" já passa.

- [ ] **Step 3: Implementar**

Em `lib/data/services/assessment_sync_service.dart`:

Substituir:

```dart

  /// Envia a fila agora, sem esperar a próxima tentativa. Sem rede, não tenta:
```

por:

```dart

  /// "Descartar" da aba Sincronizar (decisão de 01/10/2026): apaga do
  /// aparelho a avaliação que o servidor recusou — só se ela ainda estiver
  /// recusada; uma reenviada e aceita no meio do caminho não é apagada, e
  /// falha de rede ou de servidor nunca é descartada (tenta de novo sozinha).
  /// A fila se atualiza pelo stream do banco.
  Future<bool> discardRefused(String localAssessmentId) {
    return _assessments.discardFailed(localAssessmentId, reason: SendFailure.refused);
  }

  /// Envia a fila agora, sem esperar a próxima tentativa. Sem rede, não tenta:
```

Em `lib/ui/core/theme/app_icons.dart`:

Substituir:

```dart
  static const IconData close = Icons.close;
}
```

por:

```dart
  static const IconData close = Icons.close;

  /// "Descartar" do item que o servidor recusou, na aba Sincronizar (Fase
  /// 5B — não está no canvas).
  static const IconData discard = Icons.delete_outline;
}
```

Em `lib/ui/sync/sync_screen.dart`:

Substituir (1 de 7):

```dart
/// botões "Sincronizar agora" e "Tentar novamente" só adiantam a próxima
/// tentativa (decisão de 29/09/2026). Não tem ViewModel própria: o estado é
/// todo do `AssessmentSyncService`, que o app inteiro compartilha, e as
/// regras de texto estão em `sync_queue_labels.dart`.
class SyncScreen extends StatelessWidget {
```

por:

```dart
/// botões "Sincronizar agora" e "Tentar novamente" só adiantam a próxima
/// tentativa (decisão de 29/09/2026), e o "Descartar" tira da fila o que o
/// servidor recusou (decisão de 01/10/2026). Não tem ViewModel própria: o
/// estado é todo do `AssessmentSyncService`, que o app inteiro compartilha, e
/// as regras de texto estão em `sync_queue_labels.dart`.
class SyncScreen extends StatelessWidget {
```

Substituir (2 de 7):

```dart
                    else
                      _buildQueue(sync, queue, isOffline, now),
                    _buildSyncNow(sync, queue, isOffline),
```

por:

```dart
                    else
                      _buildQueue(context, sync, queue, isOffline, now),
                    _buildSyncNow(sync, queue, isOffline),
```

Substituir (3 de 7):

```dart
  Widget _buildQueue(
    AssessmentSyncService sync,
```

por:

```dart
  Widget _buildQueue(
    BuildContext context,
    AssessmentSyncService sync,
```

Substituir (4 de 7):

```dart
            children: [
              for (final item in queue) _buildItem(sync, item, isOffline, now),
            ],
```

por:

```dart
            children: [
              for (final item in queue) _buildItem(context, sync, item, isOffline, now),
            ],
```

Substituir (5 de 7):

```dart
  Widget _buildItem(
    AssessmentSyncService sync,
```

por:

```dart
  Widget _buildItem(
    BuildContext context,
    AssessmentSyncService sync,
```

Substituir (6 de 7):

```dart
            const SizedBox(height: AppSpacing.sm + 2),
            _RetryButton(
              onPressed: isOffline || sync.isSending ? null : sync.syncNow,
            ),
          ],
        ],
      ),
    );
  }
```

por:

```dart
            const SizedBox(height: AppSpacing.sm + 2),
            _buildFailedActions(context, sync, item, isOffline),
          ],
        ],
      ),
    );
  }

  /// "Tentar novamente" e, só no que o servidor recusou, "Descartar" — falha
  /// de rede ou de servidor continua tentando sozinha.
  Widget _buildFailedActions(
    BuildContext context,
    AssessmentSyncService sync,
    LocalAssessment item,
    bool isOffline,
  ) {
    final retry = _RetryButton(
      onPressed: isOffline || sync.isSending ? null : sync.syncNow,
    );
    if (item.lastError != SendFailure.refused) return retry;

    return Row(
      children: [
        Expanded(child: retry),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _DiscardButton(
            onPressed: sync.isSending ? null : () => _confirmDiscard(context, sync, item),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDiscard(
    BuildContext context,
    AssessmentSyncService sync,
    LocalAssessment item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar a avaliação?'),
        content: Text(
          'A avaliação de ${queueItemTitle(item)} não foi aceita pelo servidor '
          'e será apagada deste aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final discarded = await sync.discardRefused(item.id);
    if (discarded || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível descartar. Tente de novo.')),
    );
  }
```

Substituir (7 de 7):

```dart

/// "Tentar novamente" de um item com erro (canvas "2h"): contorno neutro, com
```

por:

```dart

/// "Descartar" de um item que o servidor recusou (decisão de 01/10/2026 — não
/// está no canvas): o formato do "Tentar novamente", em vermelho.
class _DiscardButton extends StatelessWidget {
  const _DiscardButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(AppIcons.discard, size: 19),
        label: const Text('Descartar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.dangerInk,
          disabledForegroundColor: AppColors.textMuted,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.dangerBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
          textStyle: AppTypography.buttonCompact,
        ),
      ),
    );
  }
}

/// "Tentar novamente" de um item com erro (canvas "2h"): contorno neutro, com
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **456 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/data/services/assessment_sync_service.dart lib/ui/core/theme/app_icons.dart lib/ui/sync/sync_screen.dart test/data/services/assessment_sync_service_test.dart test/support/fake_assessment_sync_service.dart test/ui/sync/sync_screen_test.dart
git commit -m "feat(mobile): descartar da fila o item recusado pelo servidor"
```

---

## Task 11: Validação no aparelho físico

Esta task é o portão da fase: sem ela, a próxima fase não é planejada (decisão do usuário, registrada em 17/09/2026). É o roteiro que só o usuário pode rodar.

**Files:** nenhum arquivo de código.

**Interfaces:**
- Consumes: o app inteiro e o backend com o `unassign`.
- Produces: o aval do usuário para planejar a próxima fase.

- [ ] **Step 1: Subir o backend com o endpoint novo e liberar a porta**

Run: `cd apps/backend && npx prisma migrate status` — se a migração `20260920120000_remove_participant_signature_from_assessment` aparecer pendente no banco local, `npx prisma migrate deploy`. Depois, `npm run start:dev`.

Em outro terminal, com o aparelho conectado: `adb reverse tcp:3001 tcp:3001` (o id do aparelho sai de `adb devices`).

- [ ] **Step 2: Instalar no aparelho**

Run (em `apps/mobile/simtc`): `flutter run -d <ID_DO_APARELHO>`

Sem `--dart-define`. Instale por cima, sem desinstalar.

- [ ] **Step 3: Percorrer o roteiro de aceite**

Preparação, com rede: na Home, uma sessão "Em andamento" com pelo menos quatro participantes atribuídos a você; tenha à mão o painel web.

Resultado depois do "Confirmar":
- [ ] inicie a avaliação de um participante, marque algumas notas (pelo menos uma PM com comentário), "Finalizar avaliação" e "Confirmar": abre **"Avaliação concluída"** com o X no canto, a "Pontuação final", a pílula, a linha "Nome · CPF · Início HH:MM · Fim HH:MM", o aviso "Na fila de envio — sai sozinha…" que em segundos vira "Enviada às HH:MM.", o "Desempenho por categoria" (código, nome, "N infrações", selo de %), as "Infrações registradas" com o grupo da primeira categoria com infração já aberto (selo B/PM/M, número do item, descrição e o comentário da nota), o rodapé sobre o número do item e o botão **"Próximo participante ›"**;
- [ ] os grupos abrem e fecham no toque; uma categoria "sem infração" não abre;
- [ ] "Próximo participante" volta ao detalhe da sessão; o X também;
- [ ] não há "pts" em lugar nenhum.

Resultado pelo detalhe:
- [ ] toque num participante "Aprovado · N%": abre o Resultado com a nota e as infrações do servidor (as mesmas do painel web), sem botão no rodapé;
- [ ] **offline** (modo avião + `adb -s <ID> reverse --remove tcp:3001`): confirme outro participante; a linha "Na fila" abre o Resultado com os dados do aparelho e "Na fila de envio…"; um "Aprovado" que não foi avaliado neste aparelho abre só com a nota, a pílula e "Sem conexão: as infrações aparecem quando houver internet.";
- [ ] com esse Resultado ainda aberto, volte a ficar online (`adb reverse` primeiro, depois desligue o modo avião): as infrações aparecem sozinhas, sem sair da tela;
- [ ] o Início e o Fim de uma avaliação vinda do servidor batem com os do painel web.

Reavaliar:
- [ ] avalie um participante com várias M até ficar abaixo de 70% e confirme; com o envio aceito, a linha vira "Reavaliar · N%"; abra o Resultado: o rodapé tem **"Reavaliar"**;
- [ ] numa sessão **concluída** que tenha um participante "Reavaliar · N%", o Resultado abre sem o botão "Reavaliar";
- [ ] offline, o "Reavaliar" fica desabilitado com "Disponível quando houver conexão";
- [ ] com rede, toque em "Reavaliar": abre o checklist em "não iniciada" ("Iniciar avaliação"), e no detalhe a linha vira "Reavaliando · você"; o voltar leva ao detalhe;
- [ ] com outra avaliação em andamento, o "Reavaliar" reserva e o checklist mostra "Você já está avaliando … Finalize ou descarte essa avaliação para iniciar outra.".

Descartar avaliação:
- [ ] inicie a avaliação de um participante e marque notas; no menu **⋮** do cabeçalho, "Descartar avaliação": o diálogo pede confirmação; "Cancelar" não muda nada; "Descartar" volta à tela "não iniciada" e as marcações somem;
- [ ] com uma avaliação em andamento, o aviso de uma por vez aparece em outro participante; descarte a primeira e o outro já pode ser iniciado;
- [ ] funciona offline.

Desatribuir participante:
- [ ] num participante seu sem avaliação iniciada, ⋮ → "Desatribuir participante": o diálogo diz que ele volta para "Pendente"; confirme: o checklist fecha, o detalhe mostra "Participante desatribuído." e a linha volta a "Pendente" com "Atribuir a mim" — no painel web, também;
- [ ] num participante com a avaliação iniciada, o diálogo avisa que "A avaliação iniciada será descartada."; confirme e confira que a avaliação sumiu;
- [ ] num participante em reavaliação ("Reavaliando · você"), o diálogo diz que ele volta para "Necessita reavaliação", e é o que aparece no detalhe e no web;
- [ ] offline, o item do menu aparece desabilitado com "Disponível quando houver conexão".

Regressões:
- [ ] a 1.6 "Conferir e finalizar" continua igual no topo (nota, pílula, linha do participante, início e fim);
- [ ] a aba "Sincronizar", o badge e o envio automático continuam como na 5A.

Visual (ver "Decisões em aberto"):
- [ ] o cabeçalho do checklist, com o menu ⋮ e a hora de início, e a pílula "Necessita reavaliação" ao lado da nota, numa tela estreita ou com a fonte do sistema ampliada;
- [ ] as linhas "Na fila", "Erro no envio" e "Enviada" do detalhe, agora com a setinha de toque;
- [ ] o efeito de toque nos grupos de "Infrações registradas";
- [ ] depois do "Confirmar", o voltar do Android no Resultado leva ao detalhe da sessão.

**Não verificável neste aparelho, e por quê:** o "Descartar" da aba depende de o servidor **recusar** uma avaliação (participante removido da sessão ou nota apagada no painel com a avaliação ainda na fila) — difícil de provocar de propósito; fica coberto pelos testes das Tasks 3 e 10, e é só nesse item que o "Tentar novamente" aparece ao lado do "Descartar". O bloqueio do menu ⋮ e do "Finalizar avaliação" durante o desatribuir só aparece com a rede lenta; fica coberto pelos testes do checklist. O checklist somente leitura só aparece por um caminho que a interface não oferece (o detalhe abre o Resultado para a avaliação confirmada); fica coberto pelos testes da Task 4. O servidor sem avaliação para um participante concluído (apagada no painel) e a falha do servidor com "Tentar novamente" ficam cobertos pelos testes das Tasks 7 e 8.

- [ ] **Step 4: Registrar o resultado**

Se tudo passar, avisar o usuário e pedir o aval para planejar a próxima fase. Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio ou de contrato do backend, parar e perguntar.

---

## Pendências levadas para as fases seguintes

Resolvidas nesta fase (saem da lista da 5A): a tela 1.8 Resultado no lugar da provisória, o "Reavaliar", o "Próximo participante", o destino do "Confirmar", o toque na linha "Enviada", o checklist editável com a avaliação na fila, os rascunhos da Fase 4 que bloqueavam o "Iniciar" (agora há o "Descartar avaliação"; o caso da sessão concluída ou cancelada está em "Decisões em aberto") e o item sempre recusado que não saía da fila.

| Fase | Pendência |
|---|---|
| 6 | ADMIN desatribuir participante de qualquer consultor (o `unassign` só libera os do próprio consultor). O painel web também não tem como desatribuir. |
| 8 | No serviço de envio: um erro ao entrar (`claimUnowned` ou o stream da fila) não é tratado; o `syncNow` devolve o envio no ar antes da rodada repetida; `retryDelays` vazio quebra (falta um `assert`); todo 401 deixa os itens "Na fila" até o próximo gatilho. Tratar junto com a troca de usuário no meio do envio, quando houver "Sair" na interface. |
| 8 | "Última sincronização" é o último envio aceito ainda no aparelho: uma reavaliação apaga a linha enviada, e o horário pode voltar para um envio anterior. |
| 8 | O envio só acontece com o app aberto (ou voltando do segundo plano). Enviar com o app fechado exige um serviço em segundo plano (WorkManager). |
| 8 | Uma avaliação na fila de outro consultor, para um participante que agora está com você (reatribuído no painel), é devolvida como está pelo `openDraft`. Caso raro (aparelho compartilhado + reatribuição antes do envio). |
| 8 | Rascunho órfão: o servidor desatribuiu, mas o aparelho não conseguiu apagar o rascunho (erro de escrita local) — ele bloquearia o "Iniciar" de outro participante, sem caminho na interface para descartá-lo. |
| 8 | O Resultado não é guardado no aparelho: sem rede, quem não foi avaliado neste aparelho aparece só com a nota e o status. Se isso pesar em campo, guardar o resultado aberto com rede (tabela nova, migração v5). |
| 8 | Um erro 4xx no lote inteiro marca todos os itens como "recusada pelo servidor" e libera o "Descartar" em todos (regra do `_reasonFor`, da 5A). |
| 8 | Depois de um desatribuir recusado (409), o checklist continua aberto e ainda deixa "Finalizar" e "Confirmar" para um participante que pode estar com outro consultor. |
| 8 | O % por categoria do Resultado vindo do servidor usa o total de infrações do catálogo do aparelho (decisão 5): com o catálogo defasado, uma infração que o aparelho não conhece muda o % em relação ao servidor. A nota geral é sempre a do servidor. |
| 8 | Limpeza: o bloco do aviso (SnackBar) repetido em três telas, o rodapé com borda em três, o mapa B/PM/M → cor em duas, os diálogos de confirmação e os botões da aba parecidos, e "confirmada neste aparelho" (`queued`/`failed`/`sent`) escrito duas vezes no detalhe. |
| 8 | Testes que faltam, registrados nas revisões: caminhos de falha do descarte e do desatribuir no checklist, bordas do `RemoteAssessment`, ramos do `FinalScoreBlock`, categoria sem % na tela do Resultado; e a saída da suíte ainda traz avisos do drift e um log de recusa. |
| Backend | `syncOne` apaga os itens e depois atualiza a avaliação fora de uma transação: um reenvio que falhe no meio deixa uma avaliação aceita sem itens. |
| Backend | `unassign`: a atualização não reafirma status e consultor (janela de concorrência, como no `assign`), e um participante que suma no meio vira erro 500; ids repetidos no corpo dão um 409 enganoso. |
| Backend | `syncOne` não confere se o participante ainda está com quem envia nem se a sessão está em andamento; `GET /practical-assessments/by-participant/:id` não confere papel nem dono. |
| Backend | Remover um consultor zera o `assignedConsultantId` sem mexer no status (`consultants.service.ts`): o participante fica "em avaliação" sem dono, e nem `assign` nem `unassign` o liberam. |
| Backend | Os arquivos das assinaturas de participante continuam no bucket `signatures/participants/` depois da remoção da coluna. |
| — | Canvas: o Resultado sem pontos, com início e fim, o número do item, o aviso de envio e o "Reavaliar"; o menu ⋮ do checklist; o "Descartar" da aba. Atualizar no Claude Design. |

As pendências da Fase 8 que vieram da 5A e não estão acima continuam valendo como estão no plano da 5A.
