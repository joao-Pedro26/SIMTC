# App Mobile SIMTC — Fase 7A: Tablet — estrutura, lado a lado e telas de consulta — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O mesmo app passa a funcionar bem num tablet Android, que o consultor usa no carro, durante a avaliação, girando o aparelho o tempo todo. Em paisagem, a lista de sessões e o detalhe ficam lado a lado, com a navbar na lateral; em retrato, uma tela por vez, com a navbar em pílula na base. Abertura, Entrar e Sincronizar ganham a versão larga. Girar o tablet não perde nada — principalmente as marcações do checklist. O celular passa a ficar travado em retrato e, fora isso, não muda.

**Architecture:** Um `FormFactor` (celular ou tablet), decidido uma vez na abertura pelo tamanho da tela física, desce pela árvore num `InheritedWidget`; sem ele, as telas se comportam como celular, e por isso nenhum teste antigo muda. No tablet, `/home` e `/sessions/:id` viram uma página só (`SessionsSplitView`), com a mesma chave nas duas rotas: o `Navigator` atualiza a página em vez de trocar, e a lista e o detalhe têm `GlobalKey`, então mudam de lugar na árvore ao girar sem recriar estado. As telas que já existem ganham parâmetros (`embedded`, `selectedSessionId`, `onOpenSession`, `onBack`, recuos) e leem o formato; a navbar ganha duas formas novas no mesmo componente. Nenhuma regra, dado ou chamada ao backend muda.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · drift 2.31.0 (sem mudança de esquema) · mocktail (testes). **Nenhuma dependência nova**: o `flutter_adaptive_scaffold` do roteiro geral foi descontinuado pela equipe do Flutter e não entra.

**Spec:** `apps/mobile/docs/superpowers/specs/2026-10-21-mobile-fase-7-tablet-design.md` (desenho aprovado em 21/10/2026; a Fase 7 foi dividida em 7A e 7B, e esta é a 7A); `brainstorm-implementacao-mobile.md` → "Fase 7 — Adaptação para tablet"; canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html`, bloco Tablet (linhas 1439–3453): quadros `4a`/`4o` (1.1 Abertura, 1444 e 1458), `4b`/`4p` (1.2 Entrar, 1469 e 1526), `4c` (1.3 + 1.4 lado a lado, 1572), `4d` (variante ADMIN, 1730), `4e` (retrato, 1863) e `4j`/`4u` (1.9 Sincronizar, 2459 e 2523).

**Validação prévia:** todo o código deste plano foi escrito e rodado numa cópia descartável do app antes de o plano ser fechado, uma task por commit, e depois as tasks foram **reencenadas em ordem** numa segunda cópia limpa: em cada task, os testes da task falharam antes da implementação e passaram depois, e cada checkpoint bateu o número de testes — **930 → 938 → 945 → 953 → 957 → 963 → 968 → 976**, com `flutter analyze` sem issues em todos. Os blocos de código foram gerados da primeira cópia por um script que confere cada "substituir / por" contra o estado deixado pelo bloco anterior, e um segundo script aplicou o plano inteiro numa cópia limpa e conferiu que a árvore de cada task ficou **idêntica** à do commit correspondente. **Cada decisão e cada medida foi conferida por mutação** (o trecho é trocado, e algum teste tem de falhar): 30 mutações, 29 acusadas por algum teste; a que sobreviveu é equivalente (tirar o `onBack` do detalhe em retrato: o voltar da barra cai no mesmo tratamento do voltar do Android, que leva à lista). As mutações que sobreviveram na primeira passada — a altura do card destacado e a rolagem do Entrar com o teclado aberto — viraram teste antes de a task ser fechada. As telas do lado a lado (consultor e ADMIN), da lista e do detalhe em retrato e do Entrar foram **desenhadas com as fontes de verdade** em 1280×800 e 800×1280 e conferidas a olho contra o canvas.

## Decisões tomadas com o usuário

Em 21/10/2026, no brainstorm da fase:

1. **Uso:** o tablet fica no carro, durante a avaliação. **O que reprova a fase:** perder as marcações do checklist ao girar o tablet.
2. **Validação em emulador de tablet**, porque o usuário não tem tablet físico — primeira exceção à regra "aparelho físico, nunca emulador", e vale **só para o tablet**: o roteiro de aceite tem uma passada no celular Android físico para confirmar que nada piorou.
3. **Perfil (1.10) e o "Sair" ficam na Fase 8**, e com eles o item de roteiro herdado da Fase 2 ("sair e entrar com outro consultor"). Os quadros `4k` e `4v` não entram.
4. **A Fase 7 é dividida em 7A e 7B.** A 7A é a estrutura (lado a lado, navbar lateral, giro) e as telas de consulta; a 7B, a avaliação em tela larga e as três janelas de admin. A 7B só é planejada depois da validação da 7A.
5. **Todas as telas seguem o giro do aparelho no tablet**, inclusive o checklist.

Aprovadas pelo usuário na mesma conversa (propostas minhas, sem objeção):

6. **É tablet o aparelho com o lado menor da tela a partir de 600dp**; abaixo disso é celular, travado em retrato (o roteiro geral já dizia; hoje o app não trava). O formato sai da **tela física**, não da janela: em tela dividida o tablet continua tablet; o layout de cada tela segue a largura da janela.
7. **Lado a lado a partir de 840dp de largura** (o tablet em paisagem); em retrato, uma tela por vez, com o voltar — é o "master-detail colapsado" do quadro `4e`.
8. **Sem o `flutter_adaptive_scaffold`** (descontinuado): a adaptação usa `MediaQuery` e widgets próprios.
9. **Na navbar do tablet, o "Perfil" continua com o aviso "Disponível em breve."** até a Fase 8.

Respostas do usuário sobre o que o canvas não desenha ou desenha diferente do celular:

10. **Paisagem sem sessão escolhida:** o lado direito mostra o aviso "Escolha uma sessão na lista"; nada abre sozinho.
11. **Cards da lista no tablet: iguais aos do celular** (logo, seções, "Ver mais"); só ganham o destaque da sessão aberta do quadro `4c` (fundo `#F1FAFB`, borda de 1,5 `#7FC9D1` em cima e embaixo, traço de 3 `#1D9AA4` à esquerda).
12. **Detalhe em paisagem: segue o quadro** — sem a barra de topo; o lápis e o ícone de pessoas do ADMIN na linha da empresa; o progresso, com 240 de largura, à direita (do nome da empresa para o consultor, da linha de local e data para o ADMIN). O indicador de envio fica no cabeçalho da lista.
13. **Lista em retrato: a do celular, alargada**, com a navbar em pílula do quadro `4u` (120 das laterais, 68 de altura); o detalhe abre por cima, com o voltar, como no `4e`.
14. **Diferenças do canvas aprovadas** (quase todas para continuar igual ao celular):
    - **Entrar:** o formulário mantém as medidas do celular (campos de 56, não 60) e o aviso de sem conexão atual do app; muda só a disposição.
    - **Sincronizar:** o "Sincronizar agora" fica no fim da lista, como no celular, e não dentro do cartão âmbar dos quadros `4j`/`4u`; os itens são os do celular.
    - **Detalhe:** o "Atribuir a mim" fica embaixo da linha do participante, como no celular (no `4c` fica ao lado do chip), e o chip de status do cabeçalho é o do celular.
    - **Lista em paisagem:** o título do ADMIN continua "Sessões" (o `4d` diz "Todas as sessões").
    - **Sem conexão em paisagem:** a faixa de aviso aparece nos dois painéis (o canvas não desenha a faixa).
    - **Pílula do tablet:** recuo interno de 5, e não 6, para fechar 68 de altura com itens de 56.
    - **Regras novas:** o voltar do Android em paisagem tira a sessão aberta; trocar para Sincronizar e voltar traz a lista sem sessão aberta.
15. **Fora da 7A:** a avaliação em tela larga (1.4.1, 1.5, 1.6, 1.8 — quadros `6b`/`6c`, `4f`/`4q`, `4g`/`4r`, `4i`/`4t`) e as janelas de admin como diálogo ancorado (`4l`/`4w`, `4m`/`4x`, `4n`/`4y`) — **Fase 7B**; nesta fase elas abrem em tela cheia, como no celular, e já seguem o giro. Perfil, "Sair" e as buscas (as lupas dos quadros) — Fase 8. As quatro decisões visuais em aberto da 6A. Qualquer mudança de backend.

### Ajustes feitos ao preparar o plano (revisar junto com o plano)

A validação na cópia descartável levou a estas escolhas. **Nenhuma muda regra de negócio aprovada**, mas cada uma é uma regra de tela que o código cria, ou uma medida, que o usuário deve conferir.

**Formato e giro:**

- **Sem o `FormFactorScope` na árvore, vale celular.** Os testes de tela antigos montam as telas sem ele (e a tela padrão do `flutter_test` tem 800×600, que pelo corte de 600 seria tablet): por isso o formato não sai do `MediaQuery`, e nenhum teste antigo mudou.
- **A trava de retrato do celular é pedida em `main`**, antes do `runApp`, pelo `SystemChrome`; o tablet manda a lista vazia, que devolve ao sistema todas as orientações. O `AndroidManifest` não muda.
- **No tablet, a lista e o detalhe são uma página só, com a mesma chave nas duas rotas.** Tocar num card faz `go` (não `push`) para `/sessions/:id`. As rotas de dentro da sessão (checklist, resumo, resultado, editar, adicionar, consultores) continuam empilhadas por cima, em tela cheia.
- **Em retrato com a sessão aberta, a lista fica montada embaixo, escondida** (`Offstage`, com as animações paradas), e volta exatamente como estava — rolagem e chip ativo.
- **Trocar de sessão cria um detalhe novo**; girar com a mesma sessão aberta reaproveita o detalhe (a ViewModel, o filtro, a rolagem).
- **O voltar do Android com a sessão aberta fecha a sessão**, nos dois sentidos (retrato: volta à lista; paisagem: tira a seleção). Sem sessão aberta, fecha o app, como no celular.

**Navbar (`PillNavBar` e o novo `AppNavBar`):**

- **A navbar com os três itens e o destino de cada um virou um widget só, `AppNavBar`**, usado pela Home e pela Sincronizar (cada tela montava a sua). No celular, nada muda.
- **A lateral (quadro `4c`):** coluna de 88 a 14 da borda esquerda, centrada na altura; itens de 64×64; ícone de 23 e rótulo de 10, com "Sincr." no lugar de "Sincronizar"; badge a 6 do topo e 8 da direita. O conteúdo começa em 116.
- **A pílula (quadro `4u`):** 68 de altura, a 120 das laterais e 16 do fundo; itens de 56; rótulo de 11; o conteúdo termina 100 acima do fundo. **Numa janela mais estreita que 600 (tela dividida), a pílula volta aos 16 de recuo do celular.**
- **As cores das formas do tablet são as dos quadros**: item ativo em `primarySurface` (`#E6F6F7`) com `primaryDark` (`#0A6E80`), os outros em `text3` (`#475569`), contorno `border` e sombra de 18% (`navShadowTablet`, token novo). A nota do `4u` diz "mesmos tokens da pílula do celular", mas o quadro desenha estes; vale o desenho.
- **O leitor de tela lê "Sincronizar" também na lateral**, onde aparece "Sincr.".

**Telas:**

- **Abertura (quadros `4a`/`4o`, iguais nas duas posições):** logo de 200 e barra de 220, com 66 entre elas (os 30 de recuo da caixa da logo mais os 36 do quadro).
- **Entrar:** em paisagem, a logo de 230 num painel de 520 (56 de recuo) e o formulário em até 440, centrado no resto (64 de recuo); em retrato, a logo em cima (56 de recuo, 32 embaixo) e o formulário na mesma coluna de 440. **Os dois rolam quando o teclado sobe** — o teste usa teclado em 55% da altura e fonte ampliada.
- **Sincronizar:** cabeçalho com 14 em cima e embaixo e 24 dos lados, título de 24 (o `homeTitle`) e linha de 13,5 (token novo `screenSubtitleTablet`); **a fila numa coluna de no máximo 860, centrada** (os itens trazem os próprios 20 de recuo: o texto fica em até 820, como no quadro, e com 24 de margem em retrato); 20 em cima e 28 embaixo.
- **Detalhe no tablet (`4c`/`4e`):** recuo de 24 dos lados em tudo (cabeçalho, chips, avisos, título "Participantes", linhas); cabeçalho com 16 em cima e 18 embaixo e 14 entre as partes; logo de 56 com canto 10 (`CompanyLogo.headerLarge`); nome da empresa em 20 e curso em 14 (tokens novos `detailTitleTablet` e `detailCourseTablet`). O ⋮ e o "adicionar" continuam com o ícone na margem da lista.
- **No painel de paisagem, o progresso diz "2 de 5 avaliados"** (`ParticipantProgress.shortLabel`, como no `4c`); em retrato e no celular, "2 de 5 participantes avaliados", como antes.
- **O "Iniciar sessão" continua embaixo do cabeçalho** também no painel (não está no canvas; vem da Fase 3).
- **Lista no painel de paisagem:** cabeçalho com 12/12/12/20 de recuo, saudação de 13 (`screenSubtitle`) e título de 22 (`screenTitle`), como no `4c`; em retrato, o cabeçalho do celular.
- **O card destacado não muda de altura nem tira o texto do lugar** ao ser tocado: o recuo dele desconta as bordas mais grossas.
- **O aviso de "Escolha uma sessão na lista"**: ícone de sessões de 40 em `textMuted` e o texto em `cardTitle` na cor `text3`, centrados.
- **Um divisor de 1 (`border`) separa a lista do detalhe**, como no quadro.

**Conhecido e aceito nesta fase:**

- **No tablet em retrato, o aviso passageiro (SnackBar) cobre a pílula** enquanto aparece: sem `bottomNavigationBar`, ele sobe do fundo da tela. Some sozinho.

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app` (a mesma das fases anteriores). Sem git worktree. Não criar branch, não fazer merge, não fazer push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada, com a mensagem exata dada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem trabalho do usuário fora do git, que **não é desta fase e fica exatamente como está**: um arquivo rastreado **já modificado** (`brainstorm-app-mobile.md`) e os não rastreados `.vscode/`, `IMPLEMENTATION-STATUS.md`, `apps/backend/test-render.js`, `apps/mobile/simtc/devtools_options.yaml`, `apps/web/src/app/(client)/my-company/trainings/[id]/certificates/`, `brainstorm-implementacao-mobile.md`, `prompt-claude-design-mobile.md`, `prompt-implementacao-mobile-claude-code.md`, `test-pdf.js` e `test-render.js`.
- **Proibido `git restore`, `git checkout -- <arquivo>`, `git stash`, `git reset` e `git clean`**, e qualquer outro comando que desfaça mudança que não é da task. Se o `git status` mostrar algo que não é da task, ignorar e seguir.
- **Na execução por subagentes:** antes do primeiro despacho, guardar a linha de base — o `git status --porcelain` inteiro e o `git hash-object brainstorm-app-mobile.md` — e compará-la, sem filtrar nada, depois de **cada** subagente. Todo despacho repete as duas regras acima com todas as letras. Implementadores em **haiku**; revisões com modelo mais forte (sonnet nas Tasks 1 a 4 e 6; opus nas Tasks 5 e 7, que mexem no detalhe, nas rotas e no giro).
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-10-21-mobile-fase-7a-tablet/`.

**Mobile (valem para todas as fases)**
- Flutter 3.41.6 / Dart 3.11.4 (o `pubspec.yaml` aceita a partir do 3.4: nada de sintaxe mais nova que isso). App **só Android**, APK sideload. Validação manual em aparelho físico (USB ou Wi-Fi) — **nesta fase, o tablet é validado em emulador** (decisão 2); o celular, no aparelho físico.
- MVVM + Repository: um `ChangeNotifier` por tela; tela nunca chama `Dio`/Drift direto.
- Composição "quebra-cabeça": cada tela decompõe a UI em métodos privados `Widget _buildX()` combinados num `build()` enxuto.
- Design System: nenhum `Color(0xFF…)`, nenhum número mágico de espaçamento e nenhum `TextStyle` literal fora de `lib/ui/core/theme/`; **nunca trocar `fontSize` num `.copyWith()`** fora do tema. Aritmética sobre tokens (`AppSpacing.sm + 2`) e constantes com nome, na classe que as usa, são o padrão aceito.
- Alvos de toque mínimos de 48dp (`AppSpacing.touchTarget`).
- TDD: teste falhando pelo motivo certo → implementação → teste passando.
- **Widget test com Drift de verdade** usa `AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true))`.
- **Sem `dart format`**: o projeto não está formatado por ele, e rodá-lo reformata o arquivo inteiro. Os blocos do plano já vêm no formato certo.
- Posição dos testes novos: cada bloco de teste entra **no lugar que o plano dá** (o "substituir / por" diz onde), e não no fim do arquivo.
- No passo "Rodar e ver falhar": quando um arquivo de teste não compila, o `flutter test` pode marcar com `[E]` também outros arquivos da mesma rodada. O que vale são os erros que o passo cita; os outros voltam a passar no "Rodar e ver passar".

Todos os caminhos de código são relativos a `apps/mobile/simtc/`, e os comandos `flutter` rodam a partir dessa pasta. Os `git add`/`git commit` rodam **da raiz do repositório**, com os caminhos completos dados.

## Review Focus

Os casos que o desenho implica, que um consultor no carro vai encontrar, e onde cada um ficou preso num teste:

1. **Girar o tablet várias vezes no meio do checklist, com uma marcação ainda gravando** (o caso que reprova a fase) → nenhuma marcação some, o checklist não é recriado, e a que estava gravando termina e aparece. Preso em: `girar várias vezes no meio do checklist não perde nenhuma marcação, nem a que ainda está gravando` (Task 7).
2. **Girar com a sessão aberta e um filtro escolhido** → em retrato o detalhe ocupa a tela, com o voltar; voltando à paisagem, fica ao lado da lista; o detalhe, a lista e o filtro são os mesmos depois de três idas e voltas. Preso em: `girar com a sessão aberta: em retrato o detalhe ocupa a tela, com o voltar; o detalhe e o filtro atravessam vários giros` (Task 7).
3. **O voltar do Android com a sessão aberta** → fecha a sessão em vez de fechar o app. Preso em: `o voltar do Android fecha a sessão: em retrato volta à lista, em paisagem tira a seleção` e `em retrato, o voltar da barra leva à lista, que volta como estava` (Task 7).
4. **Teclado aberto com a fonte do sistema ampliada no Entrar do tablet** → nada estoura e o "Entrar" continua alcançável, nas duas posições. Preso em: `tablet em $name com o teclado aberto e a fonte ampliada: nada estoura e o "Entrar" continua alcançável` (Task 3).
5. **Tela dividida (o tablet numa janela estreita)** → continua tablet (não trava em retrato), não fica em dois painéis, e a pílula volta ao recuo do celular. Preso em: `celular deitado continua celular` e `tablet só fica em dois painéis a partir de 840 de largura` (Task 1); `em janela estreita (tela dividida) a pílula volta aos 16` (Task 2).

## Estado herdado (ponto de partida)

HEAD = o commit deste plano, sobre `3b97415` (o desenho da Fase 7). App: `flutter analyze` limpo; **930 testes passando**.

Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| App | `lib/main.dart`, `lib/app.dart` | `main()` cria o `AppDatabase` e roda `SimtcApp(database:)`; `SimtcApp` cria o `GoRouter` uma vez (`createRouter(auth)`) e monta o `MaterialApp.router` sob o `MultiProvider` |
| Rotas | `lib/router.dart` | `AppRoutes.home` (`/home`), `sync`, `sessionDetail(id)` (`/sessions/:id`) e as rotas filhas; `createRouter(auth, {initialLocation})` |
| Home | `lib/ui/sessions/sessions_screen.dart` | `SessionsScreen` (`_buildScaffold`, `_buildHeader`, `_buildCard` → `context.push(AppRoutes.sessionDetail(id))`) |
| Detalhe | `lib/ui/session_detail/session_detail_screen.dart` | `SessionDetailScreen(sessionId:)` com `AppTopBar`, `_buildSessionHeader`, `_buildCompanyRow`, `_buildMetaRow`, `_buildProgress`, `_buildFilters`, `_buildListHeader` |
| Sincronizar | `lib/ui/sync/sync_screen.dart` | `SyncScreen` com `PopScope` que leva à Home e `_buildHeader` |
| Peças do DS | `lib/ui/core/widgets/` | `PillNavBar`/`PillNavItem`, `SessionCard`, `ParticipantRow` (`session_detail/`), `FilterChipBar`, `CompanyLogo.card`/`.header`, `AppTopBar` (o voltar faz `maybePop`), `AppIconAction` |
| Tema | `lib/ui/core/theme/` | `AppColors`, `AppSpacing` (`xxs` 2, `xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 20, `xxl` 24, `xxxl` 32, `huge` 48, `touchTarget` 48), `AppRadius`, `AppTypography` |
| Testes | `test/ui/…` | telas montadas com `MultiProvider` + `MaterialApp(home:)`; rotas reais com `createRouter`; `FakeAssessmentSyncService` e `queuedAssessment` em `test/support/` |

## Mapa de Arquivos

### Novos

| Arquivo | Task | Responsabilidade |
|---|---|---|
| `lib/ui/core/form_factor.dart` | 1 | `FormFactor`, `AppBreakpoints`, `formFactorFor`, `applyOrientationPolicy`, `FormFactorScope`, `context.isTablet`/`isExpandedLayout` |
| `lib/ui/core/widgets/app_nav_bar.dart` | 2 | `AppTab`, `AppNavBar` (os três itens e os destinos), `TabletNavFrame` (onde a navbar flutua no tablet) |
| `lib/ui/sessions/sessions_split_view.dart` | 7 | a página da lista e do detalhe no tablet |
| `test/ui/core/form_factor_test.dart` | 1 | |
| `test/ui/core/widgets/app_nav_bar_test.dart` | 2 | |
| `test/ui/splash/splash_screen_test.dart`, `test/ui/auth/login_screen_test.dart` | 3 | |
| `test/ui/sessions/sessions_split_view_test.dart` | 7 | |

### Modificados

| Arquivo | Tasks | O que muda |
|---|---|---|
| `lib/main.dart`, `lib/app.dart` | 1 | o formato na abertura; a trava; o `FormFactorScope` |
| `lib/ui/core/theme/app_colors.dart` | 2, 6 | `navShadowTablet`; `selectedCardBorder` |
| `lib/ui/core/theme/app_typography.dart` | 2, 4, 5 | `navLabelTabletBottom`; `screenSubtitleTablet`; `detailTitleTablet`, `detailCourseTablet` |
| `lib/ui/core/widgets/pill_nav_bar.dart` | 2 | `PillNavLayout` (`phone`, `tabletBottom`, `rail`); `PillNavItem.shortLabel` |
| `lib/ui/sessions/sessions_screen.dart` | 2, 6 | usa o `AppNavBar`; `embedded`, `selectedSessionId`, `onOpenSession` |
| `lib/ui/sync/sync_screen.dart` | 2, 4 | usa o `AppNavBar`; a versão do tablet |
| `lib/ui/splash/splash_screen.dart`, `lib/ui/auth/login_screen.dart` | 3 | as versões do tablet |
| `lib/ui/core/widgets/app_top_bar.dart` | 5 | `onBack` |
| `lib/ui/core/widgets/company_logo.dart` | 5 | `CompanyLogo.headerLarge` |
| `lib/ui/core/widgets/filter_chip_bar.dart` | 5 | `horizontalPadding` |
| `lib/ui/session_detail/participant_filter.dart` | 5 | `ParticipantProgress.shortLabel` |
| `lib/ui/session_detail/participant_row.dart` | 5 | `horizontalInset` |
| `lib/ui/session_detail/session_detail_screen.dart` | 5 | `embedded`, `onBack`, os recuos e o cabeçalho do tablet |
| `lib/ui/core/widgets/session_card.dart` | 6 | `selected` |
| `lib/router.dart` | 7 | a página da lista e do detalhe no tablet |
| testes existentes | 1, 4, 5, 6 | `test/widget_test.dart`; `test/ui/sync/sync_screen_test.dart`; `test/ui/session_detail/session_detail_screen_test.dart` e `participant_filter_test.dart`; `test/ui/sessions/sessions_screen_test.dart` e `test/ui/core/widgets/display_widgets_test.dart` |

---

## Task 1: O formato do aparelho e a trava de retrato do celular

O app decide uma vez, na abertura, se é celular ou tablet — pelo tamanho da tela física, não da janela — e leva isso para a árvore. O celular fica travado em retrato; o tablet segue o giro em todas as telas. Sem o `FormFactorScope` na árvore, as telas se comportam como celular: é o que deixa todos os testes antigos como estão.

**Files:**
- Create: `lib/ui/core/form_factor.dart`
- Create: `test/ui/core/form_factor_test.dart`
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `SystemChrome.setPreferredOrientations`; `PlatformDispatcher.displays`.
- Produces:
  - `enum FormFactor { phone, tablet }`
  - `abstract final class AppBreakpoints { static const double tabletShortestSide = 600; static const double expandedWidth = 840; }`
  - `FormFactor formFactorFor(Size logicalScreenSize)`
  - `Future<void> applyOrientationPolicy(FormFactor formFactor)`
  - `class FormFactorScope extends InheritedWidget { FormFactorScope({required FormFactor formFactor, required Widget child}); static FormFactor of(BuildContext context); }` — sem o scope, `FormFactor.phone`
  - `extension FormFactorContext on BuildContext { bool get isTablet; bool get isExpandedLayout; }` — `isExpandedLayout` é tablet com a janela a partir de 840 de largura
  - `SimtcApp({required AppDatabase database, FormFactor formFactor = FormFactor.phone})`

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/core/form_factor_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/form_factor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formFactorFor', () {
    test('celular abaixo de 600 de lado menor, tablet a partir dele', () {
      expect(formFactorFor(const Size(412, 915)), FormFactor.phone);
      expect(formFactorFor(const Size(360, 640)), FormFactor.phone);
      expect(formFactorFor(const Size(599, 960)), FormFactor.phone);
      expect(formFactorFor(const Size(600, 960)), FormFactor.tablet);
      expect(formFactorFor(const Size(800, 1280)), FormFactor.tablet);
      expect(formFactorFor(const Size(1280, 800)), FormFactor.tablet);
    });

    test('celular deitado continua celular', () {
      expect(formFactorFor(const Size(915, 412)), FormFactor.phone);
    });
  });

  group('applyOrientationPolicy', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('celular trava em retrato', () async {
      await applyOrientationPolicy(FormFactor.phone);

      final call = calls.single;
      expect(call.method, 'SystemChrome.setPreferredOrientations');
      expect(call.arguments, ['DeviceOrientation.portraitUp']);
    });

    test('tablet libera todas as orientações', () async {
      await applyOrientationPolicy(FormFactor.tablet);

      final call = calls.single;
      expect(call.method, 'SystemChrome.setPreferredOrientations');
      expect(call.arguments, isEmpty);
    });
  });

  group('FormFactorScope', () {
    Future<(bool, bool)> read(
      WidgetTester tester, {
      FormFactor? formFactor,
      required Size size,
    }) async {
      late bool tablet;
      late bool expanded;
      final probe = Builder(builder: (context) {
        tablet = context.isTablet;
        expanded = context.isExpandedLayout;
        return const SizedBox();
      });
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: formFactor == null
              ? probe
              : FormFactorScope(formFactor: formFactor, child: probe),
        ),
      );
      return (tablet, expanded);
    }

    testWidgets('sem o scope, vale celular mesmo em tela larga',
        (tester) async {
      expect(await read(tester, size: const Size(1280, 800)), (false, false));
    });

    testWidgets('tablet só fica em dois painéis a partir de 840 de largura',
        (tester) async {
      expect(
        await read(tester,
            formFactor: FormFactor.tablet, size: const Size(1280, 800)),
        (true, true),
      );
      expect(
        await read(tester,
            formFactor: FormFactor.tablet, size: const Size(840, 600)),
        (true, true),
      );
      expect(
        await read(tester,
            formFactor: FormFactor.tablet, size: const Size(839, 600)),
        (true, false),
      );
      expect(
        await read(tester,
            formFactor: FormFactor.tablet, size: const Size(800, 1280)),
        (true, false),
      );
    });

    testWidgets('celular nunca fica em dois painéis', (tester) async {
      expect(
        await read(tester,
            formFactor: FormFactor.phone, size: const Size(915, 412)),
        (false, false),
      );
    });
  });
}
```

Em `test/widget_test.dart`, substituir:

```dart
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/splash/splash_screen.dart';
```

por:

```dart
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/splash/splash_screen.dart';
```

Em `test/widget_test.dart`, substituir:

```dart
  });
}
```

por:

```dart
  });

  testWidgets('o formato do aparelho chega às telas; sem ele, vale celular',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(SimtcApp(database: database));
    await tester.pump();
    expect(
      FormFactorScope.of(tester.element(find.byType(SplashScreen))),
      FormFactor.phone,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      SimtcApp(database: database, formFactor: FormFactor.tablet),
    );
    await tester.pump();
    expect(
      FormFactorScope.of(tester.element(find.byType(SplashScreen))),
      FormFactor.tablet,
    );
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/form_factor_test.dart test/widget_test.dart`
Esperado: não compila — `Error: Error when reading 'lib/ui/core/form_factor.dart'` e, no `widget_test.dart`, `No named parameter with the name 'formFactor'`.

- [ ] **Step 3: Implementar**

Em `lib/app.dart`, substituir:

```dart
import 'ui/core/app_localization.dart';
import 'ui/core/theme/app_theme.dart';

class SimtcApp extends StatefulWidget {
  const SimtcApp({super.key, required this.database});

  final AppDatabase database;
```

por:

```dart
import 'ui/core/form_factor.dart';
import 'ui/core/app_localization.dart';
import 'ui/core/theme/app_theme.dart';

class SimtcApp extends StatefulWidget {
  const SimtcApp({
    super.key,
    required this.database,
    this.formFactor = FormFactor.phone,
  });

  final AppDatabase database;

  /// Decidido em `main`, pela tela física do aparelho.
  final FormFactor formFactor;
```

Em `lib/app.dart`, substituir:

```dart
      child: MaterialApp.router(
        title: 'SIMTC',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: AppLocalization.locale,
        supportedLocales: AppLocalization.supportedLocales,
        localizationsDelegates: AppLocalization.delegates,
        routerConfig: _router,
```

por:

```dart
      child: FormFactorScope(
        formFactor: widget.formFactor,
        child: MaterialApp.router(
          title: 'SIMTC',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: AppLocalization.locale,
          supportedLocales: AppLocalization.supportedLocales,
          localizationsDelegates: AppLocalization.delegates,
          routerConfig: _router,
        ),
```

Em `lib/main.dart`, substituir:

```dart
import 'data/services/local/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SimtcApp(database: AppDatabase()));
}
```

por:

```dart
import 'data/services/local/app_database.dart';
import 'ui/core/form_factor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final display = WidgetsBinding.instance.platformDispatcher.displays.first;
  final formFactor = formFactorFor(display.size / display.devicePixelRatio);
  await applyOrientationPolicy(formFactor);
  runApp(SimtcApp(database: AppDatabase(), formFactor: formFactor));
}
```

Criar `lib/ui/core/form_factor.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Celular ou tablet. Decidido uma vez, na abertura, pelo tamanho da tela
/// física — não da janela: em tela dividida o tablet continua sendo tablet
/// (decisão de 21/10/2026).
enum FormFactor { phone, tablet }

/// Os dois cortes da Fase 7.
abstract final class AppBreakpoints {
  /// Lado menor da tela, em dp, a partir do qual o aparelho é tablet.
  static const double tabletShortestSide = 600;

  /// Largura da janela, em dp, a partir da qual lista e detalhe ficam lado a
  /// lado (o tablet em paisagem).
  static const double expandedWidth = 840;
}

/// [logicalScreenSize] é a tela inteira em dp (pixels físicos divididos pela
/// densidade).
FormFactor formFactorFor(Size logicalScreenSize) =>
    logicalScreenSize.shortestSide >= AppBreakpoints.tabletShortestSide
        ? FormFactor.tablet
        : FormFactor.phone;

/// O celular fica travado em retrato; o tablet segue o giro do aparelho em
/// todas as telas, inclusive no checklist (decisão de 21/10/2026). Lista vazia
/// devolve ao sistema todas as orientações.
Future<void> applyOrientationPolicy(FormFactor formFactor) {
  return SystemChrome.setPreferredOrientations(
    formFactor == FormFactor.phone
        ? const [DeviceOrientation.portraitUp]
        : const [],
  );
}

/// Leva o [FormFactor] para a árvore. Sem ele (os testes de tela), vale
/// celular: é o que todas as telas faziam antes da Fase 7.
class FormFactorScope extends InheritedWidget {
  const FormFactorScope({
    super.key,
    required this.formFactor,
    required super.child,
  });

  final FormFactor formFactor;

  static FormFactor of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FormFactorScope>()
          ?.formFactor ??
      FormFactor.phone;

  @override
  bool updateShouldNotify(FormFactorScope oldWidget) =>
      formFactor != oldWidget.formFactor;
}

/// Atalhos para as telas.
extension FormFactorContext on BuildContext {
  bool get isTablet => FormFactorScope.of(this) == FormFactor.tablet;

  /// Tablet com a janela larga o bastante para dois painéis.
  bool get isExpandedLayout =>
      isTablet &&
      MediaQuery.sizeOf(this).width >= AppBreakpoints.expandedWidth;
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/form_factor_test.dart test/widget_test.dart`
Esperado: `+10: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+938: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/form_factor.dart apps/mobile/simtc/lib/main.dart apps/mobile/simtc/lib/app.dart apps/mobile/simtc/test/ui/core/form_factor_test.dart apps/mobile/simtc/test/widget_test.dart
git commit -m "feat(mobile): detecta o tablet e trava o celular em retrato"
```

---

## Task 2: A navbar do tablet: lateral em paisagem, pílula larga em retrato

A `PillNavBar` ganha as duas formas do tablet no mesmo componente (quadros `4c` e `4u`). A navbar com os três itens e o destino de cada um, que a Home e a Sincronizar montavam cada uma, vira o `AppNavBar`; o `TabletNavFrame` põe a navbar por cima do conteúdo do tablet e recua o conteúdo. No celular, nada muda.

**Files:**
- Create: `lib/ui/core/widgets/app_nav_bar.dart`
- Create: `test/ui/core/widgets/app_nav_bar_test.dart`
- Modify: `lib/ui/core/widgets/pill_nav_bar.dart`
- Modify: `lib/ui/core/theme/app_colors.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/sessions/sessions_screen.dart`
- Modify: `lib/ui/sync/sync_screen.dart`

**Interfaces:**
- Consumes: `context.isExpandedLayout`, `AppBreakpoints.tabletShortestSide` (Task 1); `AssessmentSyncService.queue`; `AppRoutes.home`, `AppRoutes.sync`.
- Produces:
  - `enum PillNavLayout { phone, tabletBottom, rail }` e `PillNavBar({…, PillNavLayout layout = PillNavLayout.phone})`
  - `PillNavItem({…, String? shortLabel})` — o rótulo da lateral
  - `enum AppTab { sessions, sync }`
  - `AppNavBar({required AppTab current, PillNavLayout layout = PillNavLayout.phone})`
  - `TabletNavFrame({required AppTab current, required Widget child})`, com `railInset` (116) e `bottomInset` (100)
  - `AppColors.navShadowTablet`; `AppTypography.navLabelTabletBottom`

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/core/widgets/app_nav_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/widgets/app_nav_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';

import '../../../support/fake_assessment_sync_service.dart';

void main() {
  void screen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// A aba [current] dentro da moldura do tablet, com as rotas das duas abas.
  Future<GoRouter> pumpFrame(
    WidgetTester tester, {
    AppTab current = AppTab.sessions,
    int queued = 0,
  }) async {
    Widget tab(AppTab tab) => Scaffold(
          body: TabletNavFrame(
            current: tab,
            child: ColoredBox(
              key: const Key('conteudo'),
              color: Colors.white,
              child: Text('aba ${tab.name}'),
            ),
          ),
        );
    final router = GoRouter(
      initialLocation:
          current == AppTab.sessions ? AppRoutes.home : AppRoutes.sync,
      routes: [
        GoRoute(
            path: AppRoutes.home, builder: (_, __) => tab(AppTab.sessions)),
        GoRoute(path: AppRoutes.sync, builder: (_, __) => tab(AppTab.sync)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AssessmentSyncService>.value(
        value: FakeAssessmentSyncService(
          queue: [for (var i = 0; i < queued; i++) queuedAssessment('$i')],
        ),
        child: FormFactorScope(
          formFactor: FormFactor.tablet,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    return router;
  }

  group('paisagem (quadro "4c")', () {
    testWidgets('coluna de 88 a 14 da borda, centrada na altura; o conteúdo '
        'começa em 116', (tester) async {
      screen(tester, const Size(1280, 800));
      await pumpFrame(tester);

      final bar = tester.getRect(find.byType(PillNavBar));
      expect(bar.left, 14);
      expect(bar.width, 88);
      expect(bar.center.dy, 400);
      expect(tester.getRect(find.byKey(const Key('conteudo'))).left, 116);
    });

    testWidgets('itens de 64 por 64, "Sincr." no lugar de "Sincronizar"',
        (tester) async {
      screen(tester, const Size(1280, 800));
      await pumpFrame(tester, queued: 3);

      expect(find.text('Sincr.'), findsOneWidget);
      expect(find.text('Sincronizar'), findsNothing);
      expect(find.text('3'), findsOneWidget);
      final item = find.ancestor(
        of: find.text('Sessões'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(item), const Size(64, 64));
    });

    testWidgets('o item ativo usa primarySurface e primaryDark',
        (tester) async {
      screen(tester, const Size(1280, 800));
      await pumpFrame(tester);

      final label = tester.widget<Text>(find.text('Sessões'));
      expect(label.style!.color, AppColors.primaryDark);
      expect(label.style!.fontSize, 10);
      final other = tester.widget<Text>(find.text('Perfil'));
      expect(other.style!.color, AppColors.text3);
    });

    testWidgets('a lateral leva de uma aba à outra', (tester) async {
      screen(tester, const Size(1280, 800));
      await pumpFrame(tester);

      await tester.tap(find.text('Sincr.'));
      await tester.pumpAndSettle();
      expect(find.text('aba sync'), findsOneWidget);

      await tester.tap(find.text('Sessões'));
      await tester.pumpAndSettle();
      expect(find.text('aba sessions'), findsOneWidget);
    });
  });

  group('retrato (quadro "4u")', () {
    testWidgets('pílula de 68 a 120 das laterais e 16 do fundo; o conteúdo '
        'termina 100 acima', (tester) async {
      screen(tester, const Size(800, 1280));
      await pumpFrame(tester, current: AppTab.sync, queued: 2);

      final bar = tester.getRect(find.byType(PillNavBar));
      expect(bar, const Rect.fromLTRB(120, 1196, 680, 1264));
      expect(tester.getRect(find.byKey(const Key('conteudo'))).bottom, 1180);
      expect(find.text('Sincronizar'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Sincronizar')).style!.fontSize, 11);
      final item = find.ancestor(
        of: find.text('Sessões'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(item).height, 56);
    });

    testWidgets('em janela estreita (tela dividida) a pílula volta aos 16',
        (tester) async {
      screen(tester, const Size(500, 900));
      await pumpFrame(tester);

      final bar = tester.getRect(find.byType(PillNavBar));
      expect(bar.left, 16);
      expect(bar.right, 484);
    });
  });

  testWidgets('"Perfil" avisa que chega numa próxima versão', (tester) async {
    screen(tester, const Size(1280, 800));
    await pumpFrame(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pump();
    expect(find.text('Disponível em breve.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/widgets/app_nav_bar_test.dart`
Esperado: não compila — `Error: Error when reading 'lib/ui/core/widgets/app_nav_bar.dart'`.

- [ ] **Step 3: Implementar**

Em `lib/ui/core/theme/app_colors.dart`, substituir:

```dart
  static const Color navShadow = Color(0x4715172A);

  /// Trilho da barra de progresso da abertura
  static const Color progressTrack = Color(0x24000000);
```

por:

```dart
  static const Color navShadow = Color(0x4715172A);

  /// Sombra da navbar do tablet, lateral e em pílula (quadros "4c" e "4u")
  static const Color navShadowTablet = Color(0x2E0F172A);

  /// Trilho da barra de progresso da abertura
  static const Color progressTrack = Color(0x24000000);
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
  /// Rótulo de item da navbar
  static TextStyle get navLabel =>
      _inter(size: 10, weight: FontWeight.w600, height: 1);
```

por:

```dart
  /// Rótulo de item da navbar (também a lateral do tablet, quadro "4c")
  static TextStyle get navLabel =>
      _inter(size: 10, weight: FontWeight.w600, height: 1);

  /// Rótulo de item da pílula do tablet em retrato (quadro "4u")
  static TextStyle get navLabelTabletBottom =>
      _inter(size: 11, weight: FontWeight.w600, height: 1);
```

Criar `lib/ui/core/widgets/app_nav_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/services/assessment_sync_service.dart';
import '../../../router.dart';
import '../form_factor.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import 'pill_nav_bar.dart';

/// As abas que têm tela. "Perfil" ainda não tem (Fase 8).
enum AppTab { sessions, sync }

/// A navbar do app, com os três itens e o destino de cada um — a mesma nas
/// abas Sessões e Sincronizar, em qualquer formato.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.current,
    this.layout = PillNavLayout.phone,
  });

  final AppTab current;
  final PillNavLayout layout;

  @override
  Widget build(BuildContext context) {
    // O mesmo número do indicador do cabeçalho: a fila de envio.
    final queued = context.watch<AssessmentSyncService?>()?.queue.length ?? 0;

    return PillNavBar(
      currentIndex: current.index,
      layout: layout,
      items: [
        const PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
        PillNavItem(
          icon: AppIcons.sync,
          label: 'Sincronizar',
          shortLabel: 'Sincr.',
          badgeCount: queued,
        ),
        const PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
      ],
      onSelect: (index) {
        if (index == AppTab.sessions.index && current != AppTab.sessions) {
          context.go(AppRoutes.home);
        }
        if (index == AppTab.sync.index && current != AppTab.sync) {
          context.go(AppRoutes.sync);
        }
        if (index == 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Disponível em breve.')),
          );
        }
      },
    );
  }
}

/// Moldura das abas no tablet: a navbar flutua por cima do conteúdo, que
/// recua para não ficar embaixo dela.
///
/// - Paisagem (dois painéis): coluna na lateral esquerda, a 14 da borda e
///   centrada na altura; o conteúdo começa em 116 (quadro "4c").
/// - Retrato: pílula na base, a 16 do fundo e a 120 das laterais; o conteúdo
///   termina 100 acima do fundo (quadro "4u"). Numa janela estreita (tela
///   dividida), a pílula volta aos 16 de recuo do celular.
class TabletNavFrame extends StatelessWidget {
  const TabletNavFrame({
    super.key,
    required this.current,
    required this.child,
  });

  final AppTab current;
  final Widget child;

  static const double railInset = 116;
  static const double bottomInset = 100;

  /// Distância da navbar à borda da tela: a lateral fica a 14 da esquerda;
  /// a pílula, a 16 do fundo e a 120 das laterais.
  static const double railLeft = AppSpacing.md + 2;
  static const double bottomSide = 120;

  @override
  Widget build(BuildContext context) {
    if (context.isExpandedLayout) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: railInset),
            child: child,
          ),
          Positioned(
            left: railLeft,
            top: 0,
            bottom: 0,
            child: Center(
              widthFactor: 1,
              child: AppNavBar(current: current, layout: PillNavLayout.rail),
            ),
          ),
        ],
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final side = width >= AppBreakpoints.tabletShortestSide
        ? bottomSide
        : AppSpacing.lg;
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: bottomInset),
          child: child,
        ),
        Positioned(
          left: side,
          right: side,
          bottom: AppSpacing.lg,
          child: AppNavBar(current: current, layout: PillNavLayout.tabletBottom),
        ),
      ],
    );
  }
}
```

Em `lib/ui/core/widgets/pill_nav_bar.dart`, substituir:

```dart
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// Quantidade pendente exibida em cima do ícone; 0 esconde o badge.
  final int badgeCount;
```

por:

```dart
    this.shortLabel,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// Rótulo da navbar lateral, onde o item tem 64 de largura ("Sincr.", no
  /// quadro "4c"). Sem ele, vale [label].
  final String? shortLabel;

  /// Quantidade pendente exibida em cima do ícone; 0 esconde o badge.
  final int badgeCount;
}

/// As três formas da mesma navbar.
enum PillNavLayout {
  /// Pílula na base do celular, com o recuo das bordas embutido.
  phone,

  /// Pílula na base do tablet em retrato (quadro "4u"). Quem posiciona é o
  /// `TabletNavFrame`: a barra não traz recuo próprio.
  tabletBottom,

  /// Coluna na lateral do tablet em paisagem (quadro "4c"). Também
  /// posicionada pelo `TabletNavFrame`.
  rail,
```

Em `lib/ui/core/widgets/pill_nav_bar.dart`, substituir:

```dart
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<PillNavItem> items;

  @override
  Widget build(BuildContext context) {
```

por:

```dart
    this.layout = PillNavLayout.phone,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<PillNavItem> items;
  final PillNavLayout layout;

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      PillNavLayout.phone => _buildPhone(),
      PillNavLayout.tabletBottom => _buildTabletBottom(),
      PillNavLayout.rail => _buildRail(),
    };
  }

  Widget _buildPhone() {
```

Em `lib/ui/core/widgets/pill_nav_bar.dart`, substituir:

```dart
              Expanded(child: _buildItem(items[i], i == currentIndex, () => onSelect(i))),
          ],
        ),
      ),
```

por:

```dart
              Expanded(child: _buildItem(items[i], i == currentIndex, () => onSelect(i))),
          ],
        ),
      ),
    );
  }

  /// Os quadros do tablet desenham a barra com borda, e o item ativo em
  /// `primarySurface`/`primaryDark` — não nos tons da pílula do celular.
  static final BoxDecoration _tabletDecoration = BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(AppRadius.pill),
    border: Border.all(color: AppColors.border),
    boxShadow: const [
      BoxShadow(
        color: AppColors.navShadowTablet,
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ],
  );

  /// Medidas do tablet (quadros "4c" e "4u").
  static const double tabletBottomHeight = 68;
  static const double tabletBottomItemHeight = 56;
  static const double railWidth = 88;
  static const double railItemSize = 64;

  /// O quadro "4u" desenha a barra com 68, borda de 1 e itens de 56: o recuo
  /// interno fica em 5 (o quadro diz 6, que não fecha a conta).
  Widget _buildTabletBottom() {
    return Container(
      height: tabletBottomHeight,
      padding: const EdgeInsets.all(AppSpacing.xs + 1),
      decoration: _tabletDecoration,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _buildTabletItem(
                items[i],
                i == currentIndex,
                () => onSelect(i),
                height: tabletBottomItemHeight,
                labelStyle: AppTypography.navLabelTabletBottom,
                label: items[i].label,
                // O badge começa 8 à direita do centro do item (quadro
                // "4u"): o centro dele fica 8 + 9 adiante.
                badge: (count) => Positioned(
                  top: AppSpacing.xs,
                  child: Transform.translate(
                    offset: const Offset(AppSpacing.sm + 9, 0),
                    child: _badge(count),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRail() {
    return Container(
      width: railWidth,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: _tabletDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: railItemSize,
              child: _buildTabletItem(
                items[i],
                i == currentIndex,
                () => onSelect(i),
                height: railItemSize,
                labelStyle: AppTypography.navLabel,
                label: items[i].shortLabel ?? items[i].label,
                badge: (count) => Positioned(
                  top: AppSpacing.sm - 2,
                  right: AppSpacing.sm,
                  child: _badge(count),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabletItem(
    PillNavItem item,
    bool isSelected,
    VoidCallback onTap, {
    required double height,
    required TextStyle labelStyle,
    required String label,
    required Widget Function(int count) badge,
  }) {
    final ink = isSelected ? AppColors.primaryDark : AppColors.text3;

    return Semantics(
      selected: isSelected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySurface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 23, color: ink),
                  const SizedBox(height: AppSpacing.xxs + 1),
                  Text(label, style: labelStyle.copyWith(color: ink)),
                ],
              ),
              if (item.badgeCount > 0) badge(item.badgeCount),
            ],
          ),
        ),
      ),
```

Em `lib/ui/core/widgets/pill_nav_bar.dart`, substituir:

```dart
        child: Container(
          constraints: const BoxConstraints(minWidth: 18),
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.warningInkStrong,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.background, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: AppTypography.navLabel.copyWith(
              color: AppColors.surface,
              fontWeight: FontWeight.w700,
            ),
          ),
```

por:

```dart
        child: _badge(count),
      ),
    );
  }

  Widget _badge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.warningInkStrong,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.background, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: AppTypography.navLabel.copyWith(
          color: AppColors.surface,
          fontWeight: FontWeight.w700,
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
import '../../data/repositories/session_repository.dart';
import '../../data/services/assessment_sync_service.dart';
import '../../data/services/connectivity_service.dart';
```

por:

```dart
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
import '../core/widgets/company_logo.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/filter_chip_bar.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/pill_nav_bar.dart';
```

por:

```dart
import '../core/widgets/app_nav_bar.dart';
import '../core/widgets/company_logo.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/filter_chip_bar.dart';
import '../core/widgets/inline_notice.dart';
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
      bottomNavigationBar: _buildNavBar(context),
```

por:

```dart
      bottomNavigationBar: const AppNavBar(current: AppTab.sessions),
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
  }

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
      onSelect: (index) {
        if (index == 1) context.go(AppRoutes.sync);
        if (index == 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Disponível em breve.')),
          );
        }
      },
    );
  }
}
```

por:

```dart
  }
}
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
import '../core/widgets/pill_nav_bar.dart';
```

por:

```dart
import '../core/widgets/app_nav_bar.dart';
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
        bottomNavigationBar: _buildNavBar(context, queue.length),
```

por:

```dart
        bottomNavigationBar: const AppNavBar(current: AppTab.sync),
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
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
```

por:

```dart
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/widgets/app_nav_bar_test.dart`
Esperado: `+7: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+945: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/widgets/app_nav_bar.dart apps/mobile/simtc/lib/ui/core/widgets/pill_nav_bar.dart apps/mobile/simtc/lib/ui/core/theme/app_colors.dart apps/mobile/simtc/lib/ui/core/theme/app_typography.dart apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart apps/mobile/simtc/lib/ui/sync/sync_screen.dart apps/mobile/simtc/test/ui/core/widgets/app_nav_bar_test.dart
git commit -m "feat(mobile): navbar lateral e em pilula do tablet"
```

---

## Task 3: Abertura e Entrar no tablet

A Abertura cresce (quadros `4a` e `4o`). O Entrar ganha as duas disposições do tablet — logo num painel ao lado do formulário em paisagem (`4b`), logo em cima em retrato (`4p`) —, com o formulário do celular numa coluna de 440, e as duas rolam quando o teclado sobe. As duas telas ainda não tinham teste de tela.

**Files:**
- Create: `test/ui/splash/splash_screen_test.dart`
- Create: `test/ui/auth/login_screen_test.dart`
- Modify: `lib/ui/splash/splash_screen.dart`
- Modify: `lib/ui/auth/login_screen.dart`

**Interfaces:**
- Consumes: `context.isTablet`, `context.isExpandedLayout`, `FormFactorScope` (Task 1).
- Produces:
  - nada que outra task use.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/auth/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/auth/login_screen.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository auth;
  late ConnectivityService connectivity;

  setUp(() {
    auth = _MockAuthRepository();
    connectivity = ConnectivityService();
  });

  tearDown(() => connectivity.dispose());

  Future<void> show(
    WidgetTester tester, {
    required Size size,
    FormFactor formFactor = FormFactor.phone,
    double keyboard = 0,
    double textScale = 1,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: FormFactorScope(
          formFactor: formFactor,
          child: const MaterialApp(home: LoginScreen()),
        ),
      ),
    );
  }

  Rect logo(WidgetTester tester) => tester.getRect(find.byType(Image));
  Rect field(WidgetTester tester, String label) => tester.getRect(
        find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      );
  Rect button(WidgetTester tester) =>
      tester.getRect(find.byType(AppPrimaryButton));

  testWidgets('celular: logo de 150 em cima do formulário, como antes',
      (tester) async {
    await show(tester, size: const Size(412, 915));

    expect(logo(tester).height, 150);
    expect(button(tester).width, 412 - 2 * 24);
    expect(logo(tester).bottom, lessThan(field(tester, 'E-mail').top));
  });

  testWidgets('tablet em paisagem (quadro "4b"): logo de 230 no painel de 520, '
      'formulário de 440 centrado no resto', (tester) async {
    await show(
      tester,
      size: const Size(1280, 800),
      formFactor: FormFactor.tablet,
    );

    expect(logo(tester).height, 230);
    expect(logo(tester).center, const Offset(260, 400));
    expect(button(tester).width, 440);
    expect(button(tester).center.dx, 520 + (1280 - 520) / 2);
  });

  testWidgets('tablet em retrato (quadro "4p"): logo em cima e formulário de '
      '440 na mesma coluna', (tester) async {
    await show(
      tester,
      size: const Size(800, 1280),
      formFactor: FormFactor.tablet,
    );

    expect(logo(tester).height, 230);
    expect(logo(tester).center.dx, 400);
    expect(button(tester).width, 440);
    expect(button(tester).center.dx, 400);
    expect(field(tester, 'E-mail').top - logo(tester).bottom, 32);
  });

  for (final (name, size) in const [
    ('paisagem', Size(1280, 800)),
    ('retrato', Size(800, 1280)),
  ]) {
    testWidgets('tablet em $name com o teclado aberto e a fonte ampliada: '
        'nada estoura e o "Entrar" continua alcançável', (tester) async {
      await show(
        tester,
        size: size,
        formFactor: FormFactor.tablet,
        keyboard: size.height * 0.55,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byType(AppPrimaryButton));
      await tester.pump();
      expect(button(tester).bottom, lessThanOrEqualTo(size.height * 0.45));
    });
  }
}
```

Criar `test/ui/splash/splash_screen_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/splash/splash_screen.dart';
import 'package:simtc/utils/result.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository auth;
  late Completer<Result<AuthUser>> restore;

  setUp(() {
    auth = _MockAuthRepository();
    // A retomada fica no ar: a abertura não sai da tela durante o teste.
    restore = Completer<Result<AuthUser>>();
    when(auth.restoreSession).thenAnswer((_) => restore.future);
  });

  Future<void> show(
    WidgetTester tester, {
    required Size size,
    FormFactor formFactor = FormFactor.phone,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthRepository>.value(
        value: auth,
        child: FormFactorScope(
          formFactor: formFactor,
          child: const MaterialApp(home: SplashScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  Rect logo(WidgetTester tester) => tester.getRect(find.byType(Image));
  Rect bar(WidgetTester tester) =>
      tester.getRect(find.byType(LinearProgressIndicator));

  testWidgets('celular: logo de 130 e barra de 140, 28 abaixo', (tester) async {
    await show(tester, size: const Size(412, 915));

    expect(logo(tester).height, 130);
    expect(bar(tester).width, 140);
    expect(bar(tester).top - logo(tester).bottom, 28);
  });

  for (final size in const [Size(1280, 800), Size(800, 1280)]) {
    testWidgets('tablet ${size.width.toInt()}x${size.height.toInt()} '
        '(quadros "4a" e "4o"): logo de 200 e barra de 220, 66 abaixo',
        (tester) async {
      await show(tester, size: size, formFactor: FormFactor.tablet);

      expect(logo(tester).height, 200);
      expect(bar(tester).width, 220);
      expect(bar(tester).top - logo(tester).bottom, 66);
      expect(bar(tester).center.dx, size.width / 2);
    });
  }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/splash/splash_screen_test.dart test/ui/auth/login_screen_test.dart`
Esperado: `+3 -5: Some tests failed.` — no tablet, a logo continua com as medidas do celular (`Expected: <200>` / `Actual: <130.0>` na Abertura, `Expected: <230>` / `Actual: <150.0>` no Entrar), e com o teclado aberto o Entrar estoura (`A RenderFlex overflowed by 212 pixels on the bottom.`). Os três que passam são os do celular, que já era assim.

- [ ] **Step 3: Implementar**

Em `lib/ui/auth/login_screen.dart`, substituir:

```dart
import '../../data/services/connectivity_service.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../../data/services/connectivity_service.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/auth/login_screen.dart`, substituir:

```dart
    final isOffline = context.watch<ConnectivityService>().isOffline;
```

por:

```dart
    final form = _buildForm(context, viewModel);
    if (context.isExpandedLayout) return _buildTabletLandscape(form);
    if (context.isTablet) return _buildTabletPortrait(form);
```

Em `lib/ui/auth/login_screen.dart`, substituir:

```dart
              _buildEmailField(viewModel),
              const SizedBox(height: AppSpacing.lg + 2),
              _buildPasswordField(viewModel),
              const SizedBox(height: AppSpacing.md),
              _buildOptionsRow(viewModel),
              if (viewModel.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                InlineNotice(
                  icon: AppIcons.needsReview,
                  message: viewModel.errorMessage!,
                  tone: NoticeTone.danger,
                ),
              ],
              if (viewModel.infoMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                InlineNotice(
                  icon: AppIcons.email,
                  message: viewModel.infoMessage!,
                  tone: NoticeTone.success,
                ),
              ],
              const SizedBox(height: AppSpacing.lg + 2),
              _buildSubmitButton(context, viewModel),
              if (isOffline) ...[
                const SizedBox(height: AppSpacing.xxl),
                _buildOfflineNotice(),
              ],
```

por:

```dart
              form,
```

Em `lib/ui/auth/login_screen.dart`, substituir:

```dart
  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/images/logo-simtc.png',
        height: 150,
```

por:

```dart
  /// Quadro "4b": a logo num painel de 520 à esquerda; o formulário, com até
  /// 440 de largura, centrado no resto. Rola quando o teclado sobe.
  Widget _buildTabletLandscape(Widget form) {
    return Row(
      children: [
        SizedBox(
          width: _tabletLogoPanelWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _tabletLogoInset),
            child: Center(child: _buildLogo(height: _tabletLogoHeight)),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: _tabletFormInset,
                vertical: AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _tabletFormWidth),
                child: form,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Quadro "4p": os dois painéis empilham — a logo em cima (56 de recuo, 32
  /// embaixo), o formulário na mesma coluna de 440, e o conjunto centrado na
  /// altura.
  Widget _buildTabletPortrait(Widget form) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _tabletFormInset,
          0,
          _tabletFormInset,
          AppSpacing.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                0,
                _tabletLogoInset,
                0,
                AppSpacing.xxxl,
              ),
              child: _buildLogo(height: _tabletLogoHeight),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _tabletFormWidth),
              child: form,
            ),
          ],
        ),
      ),
    );
  }

  /// Medidas dos quadros "4b" e "4p".
  static const double _tabletLogoHeight = 230;
  static const double _tabletLogoPanelWidth = 520;
  static const double _tabletLogoInset = AppSpacing.huge + AppSpacing.sm;
  static const double _tabletFormWidth = 440;
  static const double _tabletFormInset = AppSpacing.huge + AppSpacing.lg;

  /// Os campos, o "Entrar" e os avisos — os mesmos em qualquer formato.
  Widget _buildForm(BuildContext context, LoginViewModel viewModel) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEmailField(viewModel),
        const SizedBox(height: AppSpacing.lg + 2),
        _buildPasswordField(viewModel),
        const SizedBox(height: AppSpacing.md),
        _buildOptionsRow(viewModel),
        if (viewModel.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineNotice(
            icon: AppIcons.needsReview,
            message: viewModel.errorMessage!,
            tone: NoticeTone.danger,
          ),
        ],
        if (viewModel.infoMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineNotice(
            icon: AppIcons.email,
            message: viewModel.infoMessage!,
            tone: NoticeTone.success,
          ),
        ],
        const SizedBox(height: AppSpacing.lg + 2),
        _buildSubmitButton(context, viewModel),
        if (isOffline) ...[
          const SizedBox(height: AppSpacing.xxl),
          _buildOfflineNotice(),
        ],
      ],
    );
  }

  Widget _buildLogo({double height = 150}) {
    return Center(
      child: Image.asset(
        'assets/images/logo-simtc.png',
        height: height,
```

Em `lib/ui/splash/splash_screen.dart`, substituir:

```dart
import '../../router.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../../router.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/splash/splash_screen.dart`, substituir:

```dart
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(),
            const SizedBox(height: AppSpacing.xxl + AppSpacing.xs),
            _buildProgress(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo-simtc.png',
      height: 130,
      semanticLabel: 'SIM Treinamentos',
    );
  }

  Widget _buildProgress() {
    return SizedBox(
      width: 140,
```

por:

```dart
    // Tablet (quadros "4a" e "4o", iguais nas duas posições): logo de 200 e
    // barra de 220. O quadro põe a logo numa caixa branca com 30 de recuo
    // e 36 de vão até a barra — 66 entre a logo e a barra.
    final tablet = context.isTablet;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(height: tablet ? _tabletLogoHeight : 130),
            SizedBox(
              height: tablet ? _tabletGap : AppSpacing.xxl + AppSpacing.xs,
            ),
            _buildProgress(width: tablet ? _tabletBarWidth : 140),
          ],
        ),
      ),
    );
  }

  static const double _tabletLogoHeight = 200;
  static const double _tabletGap = AppSpacing.huge + AppSpacing.lg + 2;
  static const double _tabletBarWidth = 220;

  Widget _buildLogo({required double height}) {
    return Image.asset(
      'assets/images/logo-simtc.png',
      height: height,
      semanticLabel: 'SIM Treinamentos',
    );
  }

  Widget _buildProgress({required double width}) {
    return SizedBox(
      width: width,
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/splash/splash_screen_test.dart test/ui/auth/login_screen_test.dart`
Esperado: `+8: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+953: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/splash/splash_screen.dart apps/mobile/simtc/lib/ui/auth/login_screen.dart apps/mobile/simtc/test/ui/splash/splash_screen_test.dart apps/mobile/simtc/test/ui/auth/login_screen_test.dart
git commit -m "feat(mobile): abertura e entrar no tablet"
```

---

## Task 4: Sincronizar no tablet

A aba Sincronizar no tablet (quadros `4j` e `4u`): a navbar do `TabletNavFrame` no lugar da do celular, o cabeçalho com 24 de recuo e título de 24, e a fila numa coluna centrada de no máximo 860 (texto em até 820).

**Files:**
- Modify: `lib/ui/sync/sync_screen.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `test/ui/sync/sync_screen_test.dart`

**Interfaces:**
- Consumes: `context.isTablet` (Task 1); `TabletNavFrame`, `AppNavBar`, `AppTab` (Task 2).
- Produces:
  - `AppTypography.screenSubtitleTablet`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/sync/sync_screen_test.dart`, substituir:

```dart
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

por:

```dart
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/theme/app_typography.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

Em `test/ui/sync/sync_screen_test.dart`, substituir:

```dart
  }) async {
    tester.view.physicalSize = const Size(420, 1600);
```

por:

```dart
    Size size = const Size(420, 1600),
    FormFactor formFactor = FormFactor.phone,
  }) async {
    tester.view.physicalSize = size;
```

Em `test/ui/sync/sync_screen_test.dart`, substituir:

```dart
        child: MaterialApp.router(routerConfig: router),
```

por:

```dart
        child: FormFactorScope(
          formFactor: formFactor,
          child: MaterialApp.router(routerConfig: router),
        ),
```

Em `test/ui/sync/sync_screen_test.dart`, substituir:

```dart
  });
}
```

por:

```dart
  });

  group('tablet', () {
    PillNavBar navBar(WidgetTester tester) =>
        tester.widget<PillNavBar>(find.byType(PillNavBar));
    Rect item(WidgetTester tester, String id) =>
        tester.getRect(find.byKey(ValueKey('sync-item-$id')));

    testWidgets('paisagem (quadro "4j"): navbar na lateral e a fila numa '
        'coluna de 860 centrada à direita dela', (tester) async {
      await pump(
        tester,
        queue: filaDoCanvas(),
        size: const Size(1280, 800),
        formFactor: FormFactor.tablet,
      );

      expect(navBar(tester).layout, PillNavLayout.rail);
      final id = filaDoCanvas().first.id;
      expect(item(tester, id).width, 860);
      expect(item(tester, id).center.dx, 116 + (1280 - 116) / 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('retrato (quadro "4u"): pílula na base e a fila com 24 de '
        'recuo do texto', (tester) async {
      await pump(
        tester,
        queue: filaDoCanvas(),
        size: const Size(800, 1280),
        formFactor: FormFactor.tablet,
      );

      expect(navBar(tester).layout, PillNavLayout.tabletBottom);
      final id = filaDoCanvas().first.id;
      expect(item(tester, id).left, 4);
      expect(item(tester, id).right, 796);
      final title = find.descendant(
        of: find.byKey(ValueKey('sync-item-$id')),
        matching: find.byType(Text),
      );
      expect(tester.getRect(title.first).left, 24);
    });

    testWidgets('cabeçalho com título de 24 e 24 de recuo', (tester) async {
      await pump(
        tester,
        size: const Size(800, 1280),
        formFactor: FormFactor.tablet,
      );

      final title = find.text('Sincronizar').first;
      expect(tester.widget<Text>(title).style!.fontSize,
          AppTypography.homeTitle.fontSize);
      expect(tester.getRect(title).left, 24);
    });

    testWidgets('"Sessões" na pílula leva para a Home', (tester) async {
      await pump(
        tester,
        size: const Size(800, 1280),
        formFactor: FormFactor.tablet,
      );

      await tester.tap(find.text('Sessões'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/sync/sync_screen_test.dart`
Esperado: `+15 -3: Some tests failed.` — no tablet a navbar ainda é a do celular (`Expected: PillNavLayout:<PillNavLayout.rail>` / `Actual: PillNavLayout:<PillNavLayout.phone>`, e o mesmo com `tabletBottom`) e o título tem 22 (`Expected: <24.0>` / `Actual: <22.0>`). O "Sessões" da pílula já levava à Home.

- [ ] **Step 3: Implementar**

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
  static TextStyle get screenSubtitle =>
      _inter(size: 13, weight: FontWeight.w400, height: 1.2, color: AppColors.text3);

  /// Título do cartão âmbar da fila sem rede ("3 avaliações na fila")
```

por:

```dart
  static TextStyle get screenSubtitle =>
      _inter(size: 13, weight: FontWeight.w400, height: 1.2, color: AppColors.text3);

  /// A mesma linha na aba Sincronizar do tablet (quadros "4j" e "4u")
  static TextStyle get screenSubtitleTablet =>
      _inter(size: 13.5, weight: FontWeight.w400, height: 1.2, color: AppColors.text3);

  /// Título do cartão âmbar da fila sem rede ("3 avaliações na fila")
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
import 'package:flutter/material.dart';
```

por:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
import '../../router.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../../router.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
    final now = (clock ?? DateTime.now)();
    final queue = sync.queue;

    // É uma aba, não uma tela empilhada: o voltar do Android leva para
```

por:

```dart
    final now = (clock ?? DateTime.now)();
    final queue = sync.queue;
    final tablet = context.isTablet;
    final content = Column(
      children: [
        _buildHeader(sync, now, tablet: tablet),
        Expanded(
          child: _buildList(context, sync, queue, isOffline, now, tablet: tablet),
        ),
      ],
    );

    // É uma aba, não uma tela empilhada: o voltar do Android leva para
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
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
                      _buildQueue(context, sync, queue, isOffline, now),
                    _buildSyncNow(sync, queue, isOffline),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const AppNavBar(current: AppTab.sync),
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
```

por:

```dart
          child: tablet
              ? TabletNavFrame(current: AppTab.sync, child: content)
              : content,
        ),
        bottomNavigationBar:
            tablet ? null : const AppNavBar(current: AppTab.sync),
      ),
    );
  }

  /// No tablet (quadros "4j" e "4u"), a fila fica numa coluna de no máximo
  /// 820 de texto, centrada — os itens trazem os próprios 20 de recuo, por
  /// isso a coluna tem 860 e nunca menos de 4 de margem (24 no total, o
  /// recuo do quadro em retrato).
  static const double _tabletColumnWidth = 860;

  Widget _buildList(
    BuildContext context,
    AssessmentSyncService sync,
    List<LocalAssessment> queue,
    bool isOffline,
    DateTime now, {
    required bool tablet,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = tablet
            ? math.max(
                AppSpacing.xs,
                (constraints.maxWidth - _tabletColumnWidth) / 2,
              )
            : 0.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            side,
            tablet ? AppSpacing.xl : AppSpacing.lg,
            side,
            tablet ? AppSpacing.xxl + AppSpacing.xs : AppSpacing.lg,
          ),
          children: [
            if (isOffline && queue.isNotEmpty) _buildOfflineCard(queue.length),
            if (queue.isEmpty)
              _buildEmpty()
            else
              _buildQueue(context, sync, queue, isOffline, now),
            _buildSyncNow(sync, queue, isOffline),
          ],
        );
      },
    );
  }

  /// Tablet: 14 em cima e embaixo, 24 dos lados, título de 24 e linha de
  /// 13,5 (quadros "4j" e "4u").
  Widget _buildHeader(
    AssessmentSyncService sync,
    DateTime now, {
    required bool tablet,
  }) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: tablet
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.md + 2,
            )
          : const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm + 2,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sincronizar',
            style: tablet ? AppTypography.homeTitle : AppTypography.screenTitle,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            lastSyncLabel(sync.lastSyncedAt, now),
            style: tablet
                ? AppTypography.screenSubtitleTablet
                : AppTypography.screenSubtitle,
          ),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/sync/sync_screen_test.dart`
Esperado: `+18: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+957: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/sync/sync_screen.dart apps/mobile/simtc/lib/ui/core/theme/app_typography.dart apps/mobile/simtc/test/ui/sync/sync_screen_test.dart
git commit -m "feat(mobile): aba sincronizar no tablet"
```

---

## Task 5: Detalhe da sessão no tablet: recuos de 24 e o painel de paisagem

No tablet, o detalhe passa a ter 24 de recuo dos lados em tudo, logo de 56 e nome da empresa em 20 (quadros `4c` e `4e`). Com `embedded`, ele é o painel da direita em paisagem: sem a barra de topo, com o lápis e o ícone de pessoas do ADMIN na linha da empresa e o progresso curto, de 240, à direita (`4c` e `4d`). O `onBack` deixa o detalhe em retrato voltar à lista pela rota (Task 7). No celular, nada muda.

**Files:**
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Modify: `lib/ui/session_detail/participant_row.dart`
- Modify: `lib/ui/session_detail/participant_filter.dart`
- Modify: `lib/ui/core/widgets/app_top_bar.dart`
- Modify: `lib/ui/core/widgets/company_logo.dart`
- Modify: `lib/ui/core/widgets/filter_chip_bar.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`
- Modify: `test/ui/session_detail/participant_filter_test.dart`

**Interfaces:**
- Consumes: `context.isTablet`, `FormFactorScope` (Task 1).
- Produces:
  - `SessionDetailScreen({required String sessionId, bool embedded = false, VoidCallback? onBack})`
  - `AppTopBar({…, VoidCallback? onBack})` — sem ele, `maybePop`
  - `CompanyLogo.headerLarge({required String companyName, String? url})` — 56, canto 10
  - `FilterChipBar({…, double horizontalPadding = AppSpacing.xl})`
  - `ParticipantRow({…, double horizontalInset = AppSpacing.xl})`
  - `ParticipantProgress.shortLabel` — "2 de 5 avaliados"
  - `AppTypography.detailTitleTablet`, `AppTypography.detailCourseTablet`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/session_detail/participant_filter_test.dart`, substituir:

```dart
    expect(progresso.label, '2 de 4 participantes avaliados');
    expect(progresso.percentLabel, '50%');
```

por:

```dart
    expect(progresso.label, '2 de 4 participantes avaliados');
    expect(progresso.shortLabel, '2 de 4 avaliados');
    expect(progresso.percentLabel, '50%');
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

por:

```dart
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_top_bar.dart';
import 'package:simtc/ui/core/widgets/company_logo.dart';
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
  });
}
```

por:

```dart
  });

  group('tablet (Fase 7A)', () {
    /// O detalhe num tablet. [embedded]: o painel da direita em paisagem,
    /// que no app tem 1280 - 116 - 392 - 1 = 771 de largura.
    Future<void> showTablet(
      WidgetTester tester, {
      bool embedded = false,
      Size size = const Size(800, 2400),
      VoidCallback? onBack,
      List<SessionParticipant> withParticipants = const [],
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        withProviders(
          FormFactorScope(
            formFactor: FormFactor.tablet,
            child: MaterialApp(
              home: SessionDetailScreen(
                sessionId: 'sess-1',
                embedded: embedded,
                onBack: onBack,
              ),
            ),
          ),
        ),
      );
      sessionStream.add(session());
      participantsStream.add(withParticipants);
      localStream.add(const []);
      await tester.pump();
    }

    /// A linha (`Row`) mais próxima que tem a barra de progresso dentro.
    Finder progressRow() => find
        .ancestor(
          of: find.byType(LinearProgressIndicator),
          matching: find.byType(Row),
        )
        .first;

    final dois = [
      participant('1', 'Ana Paula Ribeiro',
          status: ParticipantStatus.aprovado, score: 86.4),
      participant('2', 'Carlos Eduardo Nunes'),
    ];

    testWidgets('retrato (quadro "4e"): barra de topo, logo de 56, título de 20 '
        'e 24 de recuo em tudo', (tester) async {
      await showTablet(tester, withParticipants: dois);

      expect(find.byType(AppTopBar), findsOneWidget);
      expect(tester.getSize(find.byType(CompanyLogo)), const Size(56, 56));
      expect(tester.getRect(find.byType(CompanyLogo)).left, 24);
      final title = tester.widget<Text>(find.text('Bracell Celulose'));
      expect(title.style!.fontSize, 20);
      expect(tester.getRect(find.text('Participantes')).left, 24);
      expect(tester.getRect(find.text('Ana Paula Ribeiro')).left, 24);
      expect(tester.getRect(find.text('Todos')).left, greaterThanOrEqualTo(24));
      expect(find.text('1 de 2 participantes avaliados'), findsOneWidget);
    });

    testWidgets('celular continua com logo de 52 e recuo de 20', (tester) async {
      await show(tester, withParticipants: dois);

      expect(tester.getSize(find.byType(CompanyLogo)), const Size(52, 52));
      expect(tester.getRect(find.text('Ana Paula Ribeiro')).left, 20);
      expect(
        tester.widget<Text>(find.text('Bracell Celulose')).style!.fontSize,
        18,
      );
    });

    testWidgets('o voltar da barra chama o onBack, quando ele vem',
        (tester) async {
      var backs = 0;
      await showTablet(tester, onBack: () => backs++);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pump();

      expect(backs, 1);
    });

    testWidgets('painel em paisagem, consultor (quadro "4c"): sem barra de '
        'topo e o progresso curto, de 240, à direita do nome', (tester) async {
      await showTablet(
        tester,
        embedded: true,
        size: const Size(771, 2400),
        withParticipants: dois,
      );

      expect(find.byType(AppTopBar), findsNothing);
      expect(find.text('Detalhe da sessão'), findsNothing);
      expect(find.text('1 de 2 avaliados'), findsOneWidget);
      expect(find.text('1 de 2 participantes avaliados'), findsNothing);
      final bar = tester.getRect(find.byType(LinearProgressIndicator));
      expect(bar.width, 240);
      expect(bar.right, 771 - 24);
      expect(
        find.descendant(of: progressRow(), matching: find.text('Bracell Celulose')),
        findsOneWidget,
      );
    });

    testWidgets('painel em paisagem, ADMIN (quadro "4d"): lápis e pessoas na '
        'linha da empresa, progresso na linha de local e data', (tester) async {
      when(() => auth.currentUser).thenReturn(admin);
      await showTablet(
        tester,
        embedded: true,
        size: const Size(771, 2400),
        withParticipants: dois,
      );

      final company = tester.getRect(find.text('Bracell Celulose'));
      final edit = tester.getRect(find.byTooltip('Editar dados do treinamento'));
      final people = tester.getRect(find.byTooltip('Consultores da sessão'));
      expect(edit.top, lessThan(company.bottom));
      expect(people.right, 771 - 24);
      expect(edit.right, people.left);

      final bar = tester.getRect(find.byType(LinearProgressIndicator));
      expect(bar.width, 240);
      expect(bar.right, 771 - 24);
      expect(
        find.descendant(of: progressRow(), matching: find.text('Itabira/MG')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: progressRow(), matching: find.text('Bracell Celulose')),
        findsNothing,
      );
    });

    testWidgets('no tablet, o ⋮ do ADMIN fica na margem de 24', (tester) async {
      when(() => auth.currentUser).thenReturn(admin);
      await showTablet(tester, withParticipants: [
        participant(
          '3',
          'Marcos Vinícius Alves',
          status: ParticipantStatus.emAvaliacao,
          assignedTo: 'c-outro',
          assignedName: 'Rafael Lima',
        ),
      ]);

      // O ícone do ⋮ (24) fica na margem; o "adicionar" (22) tem o alvo
      // de 48 na mesma posição, como no celular.
      expect(tester.getRect(find.byIcon(AppIcons.more)).right, 800 - 24);
      expect(
        tester.getRect(find.byTooltip('Adicionar participante')).right,
        800 - 12,
      );
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_detail/session_detail_screen_test.dart test/ui/session_detail/participant_filter_test.dart`
Esperado: não compila — `Error: No named parameter with the name 'embedded'.` no `session_detail_screen_test.dart` e `Error: The getter 'shortLabel' isn't defined for the type 'ParticipantProgress'.` no `participant_filter_test.dart`.

- [ ] **Step 3: Implementar**

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
  static TextStyle get detailTitle =>
      _inter(size: 18, weight: FontWeight.w600, height: 1.25);

  /// Iniciais da empresa no lugar do logo (card da Home, detalhe da sessão)
```

por:

```dart
  static TextStyle get detailTitle =>
      _inter(size: 18, weight: FontWeight.w600, height: 1.25);

  /// O mesmo no tablet (quadros "4c" e "4e")
  static TextStyle get detailTitleTablet =>
      _inter(size: 20, weight: FontWeight.w600, height: 1.25);

  /// Nome do curso no cabeçalho do detalhe, no tablet (quadros "4c" e "4e");
  /// no celular é o `body`
  static TextStyle get detailCourseTablet =>
      _inter(size: 14, weight: FontWeight.w400, height: 1.35, color: AppColors.text3);

  /// Iniciais da empresa no lugar do logo (card da Home, detalhe da sessão)
```

Em `lib/ui/core/widgets/app_top_bar.dart`, substituir:

```dart
    this.leadingTooltip = 'Voltar',
  });
```

por:

```dart
    this.leadingTooltip = 'Voltar',
    this.onBack,
  });
```

Em `lib/ui/core/widgets/app_top_bar.dart`, substituir:

```dart
  final double leadingIconSize;
  final String leadingTooltip;

  @override
```

por:

```dart
  final double leadingIconSize;
  final String leadingTooltip;

  /// O que o botão da esquerda faz. Sem ele, desempilha a tela — o detalhe
  /// do tablet em retrato não está empilhado sobre a lista e volta para ela
  /// pela rota.
  final VoidCallback? onBack;

  @override
```

Em `lib/ui/core/widgets/app_top_bar.dart`, substituir:

```dart
              onPressed: () => Navigator.of(context).maybePop(),
```

por:

```dart
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
```

Em `lib/ui/core/widgets/company_logo.dart`, substituir:

```dart
      : _size = AppSpacing.huge - AppSpacing.xs,
        _radius = AppRadius.sm;

  /// 52 de lado, para o cabeçalho do detalhe da sessão (tela 1.4).
```

por:

```dart
      : _size = AppSpacing.huge - AppSpacing.xs,
        _radius = AppRadius.sm;

  /// 56 de lado, para o cabeçalho do detalhe da sessão no tablet (quadros
  /// "4c" e "4e").
  const CompanyLogo.headerLarge({super.key, required this.companyName, this.url})
      : _size = AppSpacing.huge + AppSpacing.sm,
        _radius = AppRadius.sm + 2;

  /// 52 de lado, para o cabeçalho do detalhe da sessão (tela 1.4).
```

Em `lib/ui/core/widgets/filter_chip_bar.dart`, substituir:

```dart
  });

  final List<FilterChipData> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
```

por:

```dart
    this.horizontalPadding = AppSpacing.xl,
  });

  final List<FilterChipData> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Recuo das pontas: 20 no celular, 24 no detalhe do tablet.
  final double horizontalPadding;
```

Em `lib/ui/core/widgets/filter_chip_bar.dart`, substituir:

```dart
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
```

por:

```dart
      padding: EdgeInsets.symmetric(
        horizontal: widget.horizontalPadding,
```

Em `lib/ui/session_detail/participant_filter.dart`, substituir:

```dart
  double? get fraction => assessable <= 0 ? null : assessed / assessable;

  String get label => '$assessed de $assessable participantes avaliados';

  String get percentLabel => '${((fraction ?? 0) * 100).round()}%';
}
```

por:

```dart
  double? get fraction => assessable <= 0 ? null : assessed / assessable;

  String get label => '$assessed de $assessable participantes avaliados';

  /// A versão curta do painel de detalhe em paisagem, onde o progresso tem
  /// 240 de largura (quadro "4c").
  String get shortLabel => '$assessed de $assessable avaliados';

  String get percentLabel => '${((fraction ?? 0) * 100).round()}%';
}
```

Em `lib/ui/session_detail/participant_row.dart`, substituir:

```dart
    this.muted = false,
  });
```

por:

```dart
    this.muted = false,
    this.horizontalInset = AppSpacing.xl,
  });
```

Em `lib/ui/session_detail/participant_row.dart`, substituir:

```dart
  // O recuo lateral é de cada parte da linha, e não do contêiner: o cabeçalho
  // com o menu tem um recuo próprio à direita.
  static const EdgeInsets _sides =
      EdgeInsets.symmetric(horizontal: AppSpacing.xl);
```

por:

```dart
  /// Recuo das laterais: 20 no celular, 24 no tablet (quadros "4c" e "4e").
  final double horizontalInset;

  // O recuo lateral é de cada parte da linha, e não do contêiner: o cabeçalho
  // com o menu tem um recuo próprio à direita.
  EdgeInsets get _sides => EdgeInsets.symmetric(horizontal: horizontalInset);
```

Em `lib/ui/session_detail/participant_row.dart`, substituir:

```dart
        left: AppSpacing.xl,
        right: menu == null ? AppSpacing.xl : AppSpacing.sm,
```

por:

```dart
        left: horizontalInset,
        right: menu == null ? horizontalInset : horizontalInset - AppSpacing.md,
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
import '../core/date_labels.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../core/date_labels.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;
```

por:

```dart
///
/// No tablet, o recuo das laterais passa de 16/20 para 24 (quadros "4c" e
/// "4e"). Em paisagem a tela é o painel da direita, ao lado da lista
/// ([embedded]): sem a barra de topo, com as ações do ADMIN na linha da
/// empresa e o progresso à direita (quadros "4c" e "4d").
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    this.embedded = false,
    this.onBack,
  });

  final String sessionId;

  /// Painel ao lado da lista (tablet em paisagem).
  final bool embedded;

  /// O voltar da barra de topo. Sem ele, desempilha a tela.
  final VoidCallback? onBack;
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
  }

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;
```

por:

```dart
  }

  /// Recuo das laterais da lista: 20 no celular, 24 no tablet.
  double get _inset => context.isTablet ? AppSpacing.xxl : AppSpacing.xl;

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
            AppTopBar(
              title: 'Detalhe da sessão',
              actions: [
                if (_viewModel.isAdmin) ...[
                  AppIconAction(
                    icon: AppIcons.edit,
                    tooltip: 'Editar dados do treinamento',
                    onPressed: _adminActionsEnabled(isOffline) ? _openEdit : null,
                  ),
                  // Sempre ligado: sem conexão ou com a sessão encerrada, a
                  // tela de lá abre só para leitura.
                  AppIconAction(
                    icon: AppIcons.consultants,
                    tooltip: 'Consultores da sessão',
                    onPressed: _openConsultants,
                  ),
                ],
              ],
              trailing: SyncStatusIndicator(
                onTap: () => context.go(AppRoutes.sync),
              ),
            ),
```

por:

```dart
            if (!widget.embedded)
              AppTopBar(
                title: 'Detalhe da sessão',
                onBack: widget.onBack,
                actions: [
                  if (_viewModel.isAdmin) ..._buildAdminActions(isOffline),
                ],
                trailing: SyncStatusIndicator(
                  onTap: () => context.go(AppRoutes.sync),
                ),
              ),
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
        ),
      ),
    );
  }

  /// As ações de ADMIN (canvas "1f") precisam de conexão e de uma sessão
```

por:

```dart
        ),
      ),
    );
  }

  List<Widget> _buildAdminActions(bool isOffline) {
    return [
      AppIconAction(
        icon: AppIcons.edit,
        tooltip: 'Editar dados do treinamento',
        onPressed: _adminActionsEnabled(isOffline) ? _openEdit : null,
      ),
      // Sempre ligado: sem conexão ou com a sessão encerrada, a tela de lá
      // abre só para leitura.
      AppIconAction(
        icon: AppIcons.consultants,
        tooltip: 'Consultores da sessão',
        onPressed: _openConsultants,
      ),
    ];
  }

  /// As ações de ADMIN (canvas "1f") precisam de conexão e de uma sessão
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
  Widget _buildSessionHeader(TrainingSession session, bool isOffline) {
    final notes = session.notes?.trim() ?? '';
    final progress = _viewModel.progress;
```

por:

```dart
  /// Tablet: 16 em cima, 18 embaixo, 24 dos lados e 14 entre as partes; no
  /// celular, 14/16/16 e 12.
  Widget _buildSessionHeader(TrainingSession session, bool isOffline) {
    final notes = session.notes?.trim() ?? '';
    final progress = _viewModel.progress;
    final tablet = context.isTablet;
    final gap = tablet ? AppSpacing.md + 2 : AppSpacing.md;
    // Em paisagem o progresso sai da pilha e vai para a direita (do nome da
    // empresa, ou da linha de local e data quando há as ações do ADMIN).
    final inlineProgress = widget.embedded && progress.fraction != null;
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
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
```

por:

```dart
      padding: tablet
          ? const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xxl,
              AppSpacing.lg + 2,
            )
          : const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md + 2,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCompanyRow(
            session,
            isOffline,
            trailingProgress: inlineProgress && !_viewModel.isAdmin,
          ),
          SizedBox(height: gap),
          _buildMetaRow(
            session,
            trailingProgress: inlineProgress && _viewModel.isAdmin,
          ),
          if (notes.isNotEmpty) ...[
            SizedBox(height: gap),
            InlineNotice(icon: AppIcons.notes, message: notes),
          ],
          if (progress.fraction != null && !inlineProgress) ...[
            SizedBox(height: gap),
            _buildProgress(progress),
          ],
          if (_viewModel.canStartSession) ...[
            SizedBox(height: gap),
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
  Widget _buildCompanyRow(TrainingSession session) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompanyLogo.header(
          companyName: session.companyName,
          url: session.companyLogoUrl,
        ),
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

  Widget _buildMetaRow(TrainingSession session) {
```

por:

```dart
  /// O progresso de 240 de largura do painel em paisagem.
  static const double _inlineProgressWidth = 240;

  Widget _buildCompanyRow(
    TrainingSession session,
    bool isOffline, {
    required bool trailingProgress,
  }) {
    final tablet = context.isTablet;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tablet
            ? CompanyLogo.headerLarge(
                companyName: session.companyName,
                url: session.companyLogoUrl,
              )
            : CompanyLogo.header(
                companyName: session.companyName,
                url: session.companyLogoUrl,
              ),
        SizedBox(width: tablet ? AppSpacing.md + 2 : AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.companyName,
                style: tablet
                    ? AppTypography.detailTitleTablet
                    : AppTypography.detailTitle,
              ),
              SizedBox(height: tablet ? AppSpacing.xs : AppSpacing.xxs + 1),
              Text(
                session.courseName,
                style: tablet
                    ? AppTypography.detailCourseTablet
                    : AppTypography.body,
              ),
            ],
          ),
        ),
        if (widget.embedded && _viewModel.isAdmin) ...[
          const SizedBox(width: AppSpacing.md + 2),
          ..._buildAdminActions(isOffline),
        ],
        if (trailingProgress) ...[
          const SizedBox(width: AppSpacing.md + 2),
          SizedBox(
            width: _inlineProgressWidth,
            child: _buildProgress(_viewModel.progress, short: true),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaRow(TrainingSession session, {required bool trailingProgress}) {
    final wrap = _buildMetaWrap(session);
    if (!trailingProgress) return wrap;

    return Row(
      children: [
        Expanded(child: wrap),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(
          width: _inlineProgressWidth,
          child: _buildProgress(_viewModel.progress, short: true),
        ),
      ],
    );
  }

  Widget _buildMetaWrap(TrainingSession session) {
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
  Widget _buildProgress(ParticipantProgress progress) {
```

por:

```dart
  Widget _buildProgress(ParticipantProgress progress, {bool short = false}) {
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
                progress.label,
```

por:

```dart
                short ? progress.shortLabel : progress.label,
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
            _viewModel.setFilter(ParticipantFilter.values[index]),
      ),
```

por:

```dart
            _viewModel.setFilter(ParticipantFilter.values[index]),
        horizontalPadding: _inset,
      ),
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                0,
              ),
```

por:

```dart
              padding: EdgeInsets.fromLTRB(_inset, AppSpacing.md, _inset, 0),
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
```

por:

```dart
        padding: EdgeInsets.symmetric(
          horizontal: _inset,
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm - 1,
        AppSpacing.sm,
```

por:

```dart
      padding: EdgeInsets.fromLTRB(
        _inset,
        AppSpacing.sm - 1,
        _inset - AppSpacing.md,
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
```

por:

```dart
      padding: EdgeInsets.fromLTRB(_inset, 0, _inset, AppSpacing.md),
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
      muted: situation == ParticipantSituation.other,
      accentColor: situation == ParticipantSituation.mine
```

por:

```dart
      muted: situation == ParticipantSituation.other,
      horizontalInset: _inset,
      accentColor: situation == ParticipantSituation.mine
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_detail/session_detail_screen_test.dart test/ui/session_detail/participant_filter_test.dart`
Esperado: `+80: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+963: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/session_detail/session_detail_screen.dart apps/mobile/simtc/lib/ui/session_detail/participant_row.dart apps/mobile/simtc/lib/ui/session_detail/participant_filter.dart apps/mobile/simtc/lib/ui/core/widgets/app_top_bar.dart apps/mobile/simtc/lib/ui/core/widgets/company_logo.dart apps/mobile/simtc/lib/ui/core/widgets/filter_chip_bar.dart apps/mobile/simtc/lib/ui/core/theme/app_typography.dart apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart apps/mobile/simtc/test/ui/session_detail/participant_filter_test.dart
git commit -m "feat(mobile): detalhe da sessao com recuos e painel do tablet"
```

---

## Task 6: Lista de sessões no tablet e o card da sessão aberta

A Home no tablet: em retrato, a lista do celular com a pílula do tablet; com `embedded`, o painel da esquerda em paisagem — sem navbar própria e com o cabeçalho do quadro `4c`. O card da sessão aberta ganha o destaque do `4c`, sem mudar de altura. O `onOpenSession` deixa a Task 7 decidir o que o toque no card faz.

**Files:**
- Modify: `lib/ui/sessions/sessions_screen.dart`
- Modify: `lib/ui/core/widgets/session_card.dart`
- Modify: `lib/ui/core/theme/app_colors.dart`
- Modify: `test/ui/sessions/sessions_screen_test.dart`
- Modify: `test/ui/core/widgets/display_widgets_test.dart`

**Interfaces:**
- Consumes: `context.isTablet` (Task 1); `TabletNavFrame`, `AppNavBar`, `AppTab` (Task 2).
- Produces:
  - `SessionsScreen({bool embedded = false, String? selectedSessionId, ValueChanged<String>? onOpenSession})` — sem `onOpenSession`, o toque empilha o detalhe, como antes
  - `SessionCard({…, bool selected = false})`
  - `AppColors.selectedCardBorder`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
  });
}
```

por:

```dart
  });

  testWidgets('SessionCard destacado tem a mesma altura e o texto no mesmo '
      'lugar do card comum', (tester) async {
    Future<(Rect, Rect)> measure(bool selected) async {
      // Numa lista, como na Home: solto no corpo do Scaffold, o card
      // esticaria até o fim da tela e a altura nunca mudaria.
      await _pump(
        tester,
        ListView(
          children: [
            SessionCard(
              companyName: 'Bracell',
              courseName: 'Direção Defensiva',
              meta: 'Itabira/MG · 07:30',
              statusChip: const SizedBox(height: 24, width: 80),
              selected: selected,
            ),
          ],
        ),
      );
      return (
        tester.getRect(find.byType(SessionCard)),
        tester.getRect(find.text('Bracell')),
      );
    }

    final (plainCard, plainText) = await measure(false);
    final (selectedCard, selectedText) = await measure(true);
    expect(selectedCard.height, closeTo(plainCard.height, 0.001));
    expect(selectedText.topLeft.dx, closeTo(plainText.topLeft.dx, 0.001));
    expect(selectedText.topLeft.dy, closeTo(plainText.topLeft.dy, 0.001));
  });
}
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/theme/app_colors.dart';
```

por:

```dart
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
  Future<void> pump(WidgetTester tester, {AssessmentSyncService? sync}) {
```

por:

```dart
  Future<void> pump(
    WidgetTester tester, {
    AssessmentSyncService? sync,
    FormFactor formFactor = FormFactor.phone,
    Widget home = const SessionsScreen(),
  }) {
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
        child: const MaterialApp(home: SessionsScreen()),
```

por:

```dart
        child: FormFactorScope(
          formFactor: formFactor,
          child: MaterialApp(home: home),
        ),
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
  });
}
```

por:

```dart
  });

  group('tablet (Fase 7A)', () {
    void screen(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('retrato: a lista do celular, com a pílula do tablet na base',
        (tester) async {
      screen(tester, const Size(800, 1280));
      await pump(tester, formFactor: FormFactor.tablet);
      sessions.add([hoje()]);
      await tester.pump();

      final bar = tester.widget<PillNavBar>(find.byType(PillNavBar));
      expect(bar.layout, PillNavLayout.tabletBottom);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
        isNull,
      );
      expect(tester.getRect(find.byType(SessionCard)).width, 800);
      expect(
        tester.widget<Text>(find.byKey(const Key('sessions-title'))).style!.fontSize,
        24,
      );
    });

    testWidgets('painel de paisagem (quadro "4c"): sem navbar própria, '
        'saudação de 13 e título de 22', (tester) async {
      screen(tester, const Size(392, 800));
      await pump(
        tester,
        formFactor: FormFactor.tablet,
        home: const SessionsScreen(embedded: true),
      );
      sessions.add([hoje()]);
      await tester.pump();

      expect(find.byType(PillNavBar), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('sessions-title'))).style!.fontSize,
        22,
      );
      expect(tester.widget<Text>(find.textContaining('Carla')).style!.fontSize, 13);
      expect(tester.getRect(find.byKey(const Key('sessions-title'))).left, 20);
    });

    testWidgets('o card da sessão aberta fica destacado, sem mudar de tamanho',
        (tester) async {
      screen(tester, const Size(392, 1600));
      final outra = TrainingSession(
        id: 'sess-2',
        companyName: 'Transportes Vale Norte',
        courseName: 'Operação de Empilhadeira',
        city: 'Betim',
        state: 'MG',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 8,
        assessableParticipants: 8,
        assessedParticipants: 0,
      );
      await pump(
        tester,
        formFactor: FormFactor.tablet,
        home: const SessionsScreen(embedded: true, selectedSessionId: 'sess-1'),
      );
      sessions.add([hoje(), outra]);
      await tester.pump();

      SessionCard card(String company) => tester.widget<SessionCard>(
            find.ancestor(
              of: find.text(company),
              matching: find.byType(SessionCard),
            ),
          );
      expect(card('Bracell Celulose').selected, isTrue);
      expect(card('Transportes Vale Norte').selected, isFalse);

      final selected = find.ancestor(
        of: find.text('Bracell Celulose'),
        matching: find.byType(Container),
      );
      final decoration =
          tester.widget<Container>(selected.first).decoration! as BoxDecoration;
      expect(decoration.color, AppColors.categoryExpandedBg);
      final border = decoration.border! as Border;
      expect(border.left, const BorderSide(color: AppColors.primary, width: 3));
      expect(border.top.color, AppColors.selectedCardBorder);
      expect(border.top.width, 1.5);
      expect(border.bottom.width, 1.5);
      final semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(SessionCard).first,
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.selected, isTrue);
    });

    testWidgets('com onOpenSession, o toque no card avisa em vez de empilhar',
        (tester) async {
      screen(tester, const Size(392, 1600));
      String? opened;
      await pump(
        tester,
        formFactor: FormFactor.tablet,
        home: SessionsScreen(embedded: true, onOpenSession: (id) => opened = id),
      );
      sessions.add([hoje()]);
      await tester.pump();

      await tester.tap(find.byType(SessionCard));
      await tester.pump();

      expect(opened, 'sess-1');
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/sessions/sessions_screen_test.dart test/ui/core/widgets/display_widgets_test.dart`
Esperado: não compila — `Error: No named parameter with the name 'embedded'.`, `Error: The getter 'selected' isn't defined for the type 'SessionCard'.` e `Error: Member not found: 'selectedCardBorder'.` no `sessions_screen_test.dart`; `Error: No named parameter with the name 'selected'.` no `display_widgets_test.dart`.

- [ ] **Step 3: Implementar**

Em `lib/ui/core/theme/app_colors.dart`, substituir:

```dart
  static const Color categoryExpandedBorder = Color(0xFFD6EDF0);

  /// Indicador "salvo" do cabeçalho do checklist (quadro "1b") — um verde
  /// próprio, mais vivo que o `successInk` dos chips.
```

por:

```dart
  static const Color categoryExpandedBorder = Color(0xFFD6EDF0);

  /// Borda de cima e de baixo do card da sessão aberta ao lado da lista, no
  /// tablet em paisagem (quadro "4c"). O fundo é o `categoryExpandedBg`.
  static const Color selectedCardBorder = Color(0xFF7FC9D1);

  /// Indicador "salvo" do cabeçalho do checklist (quadro "1b") — um verde
  /// próprio, mais vivo que o `successInk` dos chips.
```

Em `lib/ui/core/widgets/session_card.dart`, substituir:

```dart
    this.onTap,
  });
```

por:

```dart
    this.onTap,
    this.selected = false,
  });
```

Em `lib/ui/core/widgets/session_card.dart`, substituir:

```dart
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
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: accentColor, width: 0.8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.md),
            _buildStatusRow(),
            if (progressValue != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildProgressBar(),
            ],
          ],
        ),
      ),
    );
  }
```

por:

```dart
  /// A sessão aberta ao lado da lista (tablet em paisagem, quadro "4c"):
  /// fundo claro, borda de 1,5 em cima e embaixo e um traço de 3 à esquerda,
  /// no lugar do traço de status.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // As bordas somam ao recuo (`Container` conta a borda da
          // decoração): o recuo do card destacado desconta a diferença, e
          // nem o texto nem a altura do card mudam ao tocar.
          padding: selected
              ? const EdgeInsets.fromLTRB(
                  AppSpacing.xl - _selectedStripe,
                  AppSpacing.lg - 1 + _accentWidth - _selectedEdge,
                  AppSpacing.xl,
                  AppSpacing.lg - 1 - _selectedEdge,
                )
              : const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg - 1,
                ),
          decoration: selected ? _selectedDecoration : _decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: AppSpacing.md),
              _buildStatusRow(),
              if (progressValue != null) ...[
                const SizedBox(height: AppSpacing.md),
                _buildProgressBar(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Traço de status em cima do card comum.
  static const double _accentWidth = 0.8;

  /// Bordas do card destacado (quadro "4c").
  static const double _selectedEdge = 1.5;
  static const double _selectedStripe = 3;

  BoxDecoration get _decoration => BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: accentColor, width: _accentWidth)),
      );

  static const BoxDecoration _selectedDecoration = BoxDecoration(
    color: AppColors.categoryExpandedBg,
    border: Border(
      top: BorderSide(color: AppColors.selectedCardBorder, width: _selectedEdge),
      bottom: BorderSide(color: AppColors.selectedCardBorder, width: _selectedEdge),
      left: BorderSide(color: AppColors.primary, width: _selectedStripe),
    ),
  );
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
import '../core/date_labels.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../core/date_labels.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
```

por:

```dart
///
/// No tablet em retrato é a mesma lista do celular, alargada, com a navbar
/// em pílula do tablet. Em paisagem é o painel da esquerda ([embedded]), ao
/// lado do detalhe: sem navbar própria (a lateral é da moldura), com o
/// cabeçalho do quadro "4c" e o card da sessão aberta destacado.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({
    super.key,
    this.embedded = false,
    this.selectedSessionId,
    this.onOpenSession,
  });

  /// Painel da esquerda do tablet em paisagem.
  final bool embedded;

  /// A sessão aberta ao lado da lista, que o card destaca.
  final String? selectedSessionId;

  /// O toque no card. Sem ele, o detalhe é empilhado por cima da lista.
  final ValueChanged<String>? onOpenSession;
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            ConnectivityBanner(
              isOffline: isOffline,
              message: offlineDataMessage(viewModel.lastSyncedAt),
            ),
            _buildFilters(viewModel),
            Expanded(child: _buildBody(viewModel)),
          ],
        ),
      ),
      bottomNavigationBar: const AppNavBar(current: AppTab.sessions),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;
    final title = user?.isAdmin == true ? 'Sessões' : 'Minhas sessões';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm + 2,
        AppSpacing.md,
        AppSpacing.sm + 2,
      ),
      child: Column(
```

por:

```dart
    final isOffline = context.watch<ConnectivityService>().isOffline;
    // Tablet em retrato: a pílula do tablet, posta pela moldura. Em paisagem
    // quem põe a navbar é a moldura de fora, que envolve os dois painéis.
    final tabletPortrait = context.isTablet && !widget.embedded;
    final content = Column(
      children: [
        _buildHeader(context),
        ConnectivityBanner(
          isOffline: isOffline,
          message: offlineDataMessage(viewModel.lastSyncedAt),
        ),
        _buildFilters(viewModel),
        Expanded(child: _buildBody(viewModel)),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: tabletPortrait,
        child: tabletPortrait
            ? TabletNavFrame(current: AppTab.sessions, child: content)
            : content,
      ),
      bottomNavigationBar: context.isTablet
          ? null
          : const AppNavBar(current: AppTab.sessions),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;
    final title = user?.isAdmin == true ? 'Sessões' : 'Minhas sessões';
    final embedded = widget.embedded;

    // Painel de paisagem (quadro "4c"): 12/12/12/20 de recuo, saudação de 13
    // e título de 22.
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: embedded
          ? const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            )
          : const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm + 2,
              AppSpacing.md,
              AppSpacing.sm + 2,
            ),
      child: Column(
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
          Text(_greeting(user?.name), style: AppTypography.homeGreeting),
          const SizedBox(height: AppSpacing.xxs),
          // O key desambigua o título do rótulo 'Sessões' da navbar, que tem o
          // mesmo texto quando o usuário é ADMIN.
          Text(
            title,
            key: const Key('sessions-title'),
            style: AppTypography.homeTitle,
```

por:

```dart
          Text(
            _greeting(user?.name),
            style: embedded
                ? AppTypography.screenSubtitle
                : AppTypography.homeGreeting,
          ),
          const SizedBox(height: AppSpacing.xxs),
          // O key desambigua o título do rótulo 'Sessões' da navbar, que tem o
          // mesmo texto quando o usuário é ADMIN.
          Text(
            title,
            key: const Key('sessions-title'),
            style: embedded ? AppTypography.screenTitle : AppTypography.homeTitle,
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
      onTap: () => context.push(AppRoutes.sessionDetail(session.id)),
```

por:

```dart
      selected: session.id == widget.selectedSessionId,
      onTap: () {
        final open = widget.onOpenSession;
        if (open != null) {
          open(session.id);
        } else {
          context.push(AppRoutes.sessionDetail(session.id));
        }
      },
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/sessions/sessions_screen_test.dart test/ui/core/widgets/display_widgets_test.dart`
Esperado: `+48: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+968: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart apps/mobile/simtc/lib/ui/core/widgets/session_card.dart apps/mobile/simtc/lib/ui/core/theme/app_colors.dart apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart apps/mobile/simtc/test/ui/core/widgets/display_widgets_test.dart
git commit -m "feat(mobile): lista de sessoes no tablet com o card da sessao aberta"
```

---

## Task 7: Lista e detalhe lado a lado, sem perder nada ao girar

A peça central da fase. No tablet, `/home` e `/sessions/:id` passam a ser a mesma página (`SessionsSplitView`), com a mesma chave nas duas rotas: tocar num card faz `go` para a sessão, e o `Navigator` atualiza a página em vez de trocar. Em paisagem, lista de 392 e detalhe lado a lado, com a navbar lateral; em retrato, uma tela por vez. A lista e o detalhe têm `GlobalKey` e mudam de lugar na árvore ao girar sem recriar o estado. Os testes desta task usam o banco de verdade em memória e as rotas de produção — inclusive o caso que reprova a fase: girar no meio do checklist com uma marcação ainda gravando.

**Files:**
- Create: `lib/ui/sessions/sessions_split_view.dart`
- Create: `test/ui/sessions/sessions_split_view_test.dart`
- Modify: `lib/router.dart`

**Interfaces:**
- Consumes: `FormFactorScope.of`, `context.isExpandedLayout` (Task 1); `TabletNavFrame`, `AppTab` (Task 2); `SessionDetailScreen(embedded:, onBack:)` (Task 5); `SessionsScreen(embedded:, selectedSessionId:, onOpenSession:)` (Task 6).
- Produces:
  - `SessionsSplitView({String? selectedSessionId})`

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/sessions/sessions_split_view_test.dart`:

```dart
import 'dart:async';

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
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_top_bar.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
import 'package:simtc/ui/sessions/sessions_screen.dart';
import 'package:simtc/ui/sessions/sessions_split_view.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Repositório de verdade com a gravação da marcação presa num portão: o
/// teste decide quando ela termina.
class _GatedAssessmentRepository extends AssessmentRepository {
  _GatedAssessmentRepository({required super.database});

  Completer<void>? gate;

  @override
  Future<List<LocalAssessmentItem>> mark({
    required String localAssessmentId,
    required String infractionId,
    required String infractionNoteId,
  }) async {
    await gate?.future;
    return super.mark(
      localAssessmentId: localAssessmentId,
      infractionId: infractionId,
      infractionNoteId: infractionNoteId,
    );
  }
}

const _landscape = Size(1280, 800);
const _portrait = Size(800, 1280);

void main() {
  late _MockApiClient api;
  late _MockAuthRepository auth;
  late AppDatabase db;
  late _GatedAssessmentRepository assessments;
  late ConnectivityService connectivity;

  setUp(() async {
    api = _MockApiClient();
    // O servidor nunca responde: tudo sai do banco local.
    const offline = ApiException(message: 'sem rede', isNetworkError: true);
    when(() => api.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
        .thenThrow(offline);
    when(() => api.get<Map<String, dynamic>>(any(),
        queryParameters: any(named: 'queryParameters'))).thenThrow(offline);
    when(() => api.get<List<dynamic>>(any(),
        queryParameters: any(named: 'queryParameters'))).thenThrow(offline);
    auth = _MockAuthRepository();
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => auth.currentUser).thenReturn(const AuthUser(
      id: 'user-1',
      name: 'Carla Souza',
      email: 'carla@simtc.com.br',
      role: AppUserRole.consultant,
      consultantId: 'c-eu',
    ));
    // Ver `checklist_screen_test.dart`: fechar os streams na hora evita o
    // timer pendente do drift no fim do teste.
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    assessments = _GatedAssessmentRepository(database: db);
    connectivity = ConnectivityService();

    final now = DateTime.now();
    for (final (id, company) in [
      ('sess-1', 'Bracell'),
      ('sess-2', 'Transportes Vale Norte'),
    ]) {
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: id,
              companyName: company,
              courseName: 'Direção Defensiva',
              city: 'Itabira',
              state: 'MG',
              status: 'EM_ANDAMENTO',
              date: Value(now),
              participantsSyncedAt: Value(now),
              cachedAt: now,
            ),
          );
    }
    await db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-1',
            sessionId: 'sess-1',
            name: 'Ana Paula Ribeiro',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'EM_AVALIACAO',
            assignedConsultantId: const Value('c-eu'),
            cachedAt: now,
          ),
        );
    await db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-2',
            sessionId: 'sess-1',
            name: 'Carlos Eduardo Nunes',
            cpf: '118.042.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'PENDENTE',
            cachedAt: now,
          ),
        );
    await db.into(db.assessmentCategories).insert(
          AssessmentCategoriesCompanion.insert(
            id: 'cat-1',
            code: 'CV',
            name: 'Controle do Veículo',
            order: 1,
          ),
        );
    for (final (id, description) in [
      ('inf-1', 'Excesso de velocidade'),
      ('inf-2', 'Freada brusca'),
    ]) {
      await db.into(db.infractions).insert(
            InfractionsCompanion.insert(
              id: id,
              categoryId: 'cat-1',
              description: description,
              order: id == 'inf-1' ? 1 : 2,
            ),
          );
      for (final (note, deduction) in [('B', 1), ('PM', 3), ('M', 5)]) {
        await db.into(db.infractionNotes).insert(
              InfractionNotesCompanion.insert(
                id: '$id-$note',
                infractionId: id,
                noteType: note,
                deduction: deduction,
              ),
            );
      }
    }
  });

  tearDown(() async {
    await db.close();
    connectivity.dispose();
  });

  void screen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
  }

  /// O app no tablet, pelas rotas reais, aberto em [location].
  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    required String location,
    Size size = _landscape,
  }) async {
    screen(tester, size);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = createRouter(auth, initialLocation: location);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(
            value: SessionRepository(apiClient: api, database: db),
          ),
          Provider<ParticipantRepository>.value(
            value: ParticipantRepository(apiClient: api, database: db),
          ),
          Provider<SessionConsultantRepository>.value(
            value: SessionConsultantRepository(apiClient: api, database: db),
          ),
          Provider<AssessmentCatalogRepository>.value(
            value: AssessmentCatalogRepository(apiClient: api, database: db),
          ),
          Provider<AssessmentRepository>.value(value: assessments),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: FormFactorScope(
          formFactor: FormFactor.tablet,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await settle(tester);
    return router;
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> rotate(WidgetTester tester, Size size) async {
    screen(tester, size);
    await settle(tester);
  }

  Finder card(String company) =>
      find.ancestor(of: find.text(company), matching: find.byType(SessionCard));

  int detailFilter(WidgetTester tester) => tester
      .widget<FilterChipBar>(
        find.descendant(
          of: find.byType(SessionDetailScreen),
          matching: find.byType(FilterChipBar),
        ),
      )
      .selectedIndex;

  testWidgets('paisagem sem sessão escolhida: navbar lateral, lista de 392 e '
      'o aviso no lugar do detalhe', (tester) async {
    await pumpApp(tester, location: AppRoutes.home);

    expect(tester.widget<PillNavBar>(find.byType(PillNavBar)).layout,
        PillNavLayout.rail);
    expect(tester.getRect(find.byType(SessionsScreen)),
        const Rect.fromLTWH(116, 0, 392, 800));
    expect(find.text('Escolha uma sessão na lista'), findsOneWidget);
    expect(find.byType(SessionDetailScreen), findsNothing);
  });

  testWidgets('tocar no card abre o detalhe ao lado, destaca o card e a lista '
      'continua a mesma', (tester) async {
    final router = await pumpApp(tester, location: AppRoutes.home);
    final listState = tester.state(find.byType(SessionsScreen));

    await tester.tap(card('Bracell'));
    await settle(tester);

    expect(location(router), AppRoutes.sessionDetail('sess-1'));
    expect(find.text('Escolha uma sessão na lista'), findsNothing);
    final detail = tester.widget<SessionDetailScreen>(
      find.byType(SessionDetailScreen),
    );
    expect(detail.sessionId, 'sess-1');
    expect(detail.embedded, isTrue);
    expect(tester.getRect(find.byType(SessionDetailScreen)).left, 116 + 392 + 1);
    expect(tester.widget<SessionCard>(card('Bracell')).selected, isTrue);
    expect(identical(tester.state(find.byType(SessionsScreen)), listState), isTrue);
  });

  testWidgets('trocar de sessão abre outro detalhe, do zero', (tester) async {
    await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
    final first = tester.state(find.byType(SessionDetailScreen));

    await tester.tap(card('Transportes Vale Norte'));
    await settle(tester);

    expect(
      tester.widget<SessionDetailScreen>(find.byType(SessionDetailScreen)).sessionId,
      'sess-2',
    );
    expect(identical(tester.state(find.byType(SessionDetailScreen)), first), isFalse);
    expect(tester.widget<SessionCard>(card('Transportes Vale Norte')).selected, isTrue);
    expect(tester.widget<SessionCard>(card('Bracell')).selected, isFalse);
  });

  testWidgets('girar com a sessão aberta: em retrato o detalhe ocupa a tela, '
      'com o voltar; o detalhe e o filtro atravessam vários giros',
      (tester) async {
    await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
    await tester.tap(find.descendant(
      of: find.byType(SessionDetailScreen),
      matching: find.text('Pendentes'),
    ));
    await settle(tester);
    final filter = detailFilter(tester);
    final detailState = tester.state(find.byType(SessionDetailScreen));
    final listState = tester.state(find.byType(SessionsScreen));

    for (var i = 0; i < 3; i++) {
      await rotate(tester, _portrait);
      expect(find.byType(AppTopBar), findsOneWidget);
      expect(tester.getRect(find.byType(SessionDetailScreen)),
          const Rect.fromLTWH(0, 0, 800, 1280));
      expect(tester.widget<SessionDetailScreen>(
        find.byType(SessionDetailScreen),
      ).embedded, isFalse);
      expect(find.byType(PillNavBar), findsNothing);
      expect(identical(tester.state(find.byType(SessionDetailScreen)), detailState),
          isTrue);
      expect(detailFilter(tester), filter);

      await rotate(tester, _landscape);
      expect(find.byType(AppTopBar), findsNothing);
      expect(identical(tester.state(find.byType(SessionDetailScreen)), detailState),
          isTrue);
      expect(identical(tester.state(find.byType(SessionsScreen)), listState),
          isTrue);
      expect(detailFilter(tester), filter);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('em retrato, o voltar da barra leva à lista, que volta como '
      'estava', (tester) async {
    final router = await pumpApp(
      tester,
      location: AppRoutes.home,
      size: _portrait,
    );
    final listState = tester.state(find.byType(SessionsScreen));
    expect(tester.widget<PillNavBar>(find.byType(PillNavBar)).layout,
        PillNavLayout.tabletBottom);

    await tester.tap(card('Bracell'));
    await settle(tester);
    expect(location(router), AppRoutes.sessionDetail('sess-1'));
    expect(find.byType(AppTopBar), findsOneWidget);
    // A lista fica montada embaixo, escondida.
    expect(find.byType(SessionsScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await settle(tester);

    expect(location(router), AppRoutes.home);
    expect(find.byType(SessionDetailScreen), findsNothing);
    expect(identical(tester.state(find.byType(SessionsScreen)), listState), isTrue);
  });

  testWidgets('o voltar do Android fecha a sessão: em retrato volta à lista, '
      'em paisagem tira a seleção', (tester) async {
    final router = await pumpApp(
      tester,
      location: AppRoutes.sessionDetail('sess-1'),
      size: _portrait,
    );

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(location(router), AppRoutes.home);
    expect(find.byType(SessionDetailScreen), findsNothing);

    await rotate(tester, _landscape);
    await tester.tap(card('Bracell'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(location(router), AppRoutes.home);
    expect(find.text('Escolha uma sessão na lista'), findsOneWidget);
  });

  testWidgets('a lista e o detalhe são uma página só: ir de uma rota à outra '
      'não empilha nada', (tester) async {
    final router = await pumpApp(tester, location: AppRoutes.home);
    final split = tester.state(find.byType(SessionsSplitView));

    router.go(AppRoutes.sessionDetail('sess-1'));
    await settle(tester);
    router.go(AppRoutes.home);
    await settle(tester);

    expect(identical(tester.state(find.byType(SessionsSplitView)), split), isTrue);
    expect(find.byType(SessionsSplitView), findsOneWidget);
  });

  group('checklist (o que reprova a fase)', () {
    Finder note(String infraction, String note) => find.descendant(
          of: find.ancestor(
            of: find.text(infraction),
            matching: find.byType(Column),
          ).first,
          matching: find.text(note),
        );

    testWidgets('girar várias vezes no meio do checklist não perde nenhuma '
        'marcação, nem a que ainda está gravando', (tester) async {
      await assessments.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
        consultantId: 'c-eu',
      );
      await pumpApp(
        tester,
        location: AppRoutes.participantChecklist('sess-1', 'tp-1'),
      );
      final checklist = tester.state(find.byType(ChecklistScreen));

      await tester.tap(note('Excesso de velocidade', 'PM'));
      await settle(tester);

      // A segunda marcação fica gravando enquanto o tablet gira.
      assessments.gate = Completer<void>();
      await tester.tap(note('Freada brusca', 'M'));
      await tester.pump();

      for (final size in [_portrait, _landscape, _portrait, _landscape]) {
        await rotate(tester, size);
        expect(identical(tester.state(find.byType(ChecklistScreen)), checklist),
            isTrue, reason: 'o checklist não pode ser recriado ao girar');
      }

      assessments.gate!.complete();
      await settle(tester);

      final saved = await assessments.loadItems(
        (await assessments.findByParticipant('tp-1'))!.id,
      );
      expect(
        {for (final item in saved) item.infractionId: item.infractionNoteId},
        {'inf-1': 'inf-1-PM', 'inf-2': 'inf-2-M'},
      );
      await rotate(tester, _portrait);
      // A tela mostra o que está gravado: a categoria vale 10 (dois itens de
      // até 5), e PM (3) + M (5) deixam 2 — 20%.
      expect(find.text('20,0%'), findsWidgets);
    });
  });
}

/// `pumpAndSettle` com teto: a Home anima o skeleton até a lista chegar.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/sessions/sessions_split_view_test.dart`
Esperado: não compila — `Error when reading 'lib/ui/sessions/sessions_split_view.dart'`.

- [ ] **Step 3: Implementar**

Em `lib/router.dart`, substituir:

```dart
import 'package:go_router/go_router.dart';

import 'data/repositories/auth_repository.dart';
import 'ui/add_participant/add_participant_screen.dart';
import 'ui/auth/login_screen.dart';
import 'ui/checklist/checklist_screen.dart';
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/result/result_screen.dart';
import 'ui/session_consultants/session_consultants_screen.dart';
import 'ui/session_detail/session_detail_screen.dart';
import 'ui/session_edit/session_edit_screen.dart';
import 'ui/sessions/sessions_screen.dart';
```

por:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/repositories/auth_repository.dart';
import 'ui/add_participant/add_participant_screen.dart';
import 'ui/auth/login_screen.dart';
import 'ui/checklist/checklist_screen.dart';
import 'ui/core/form_factor.dart';
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/result/result_screen.dart';
import 'ui/session_consultants/session_consultants_screen.dart';
import 'ui/session_detail/session_detail_screen.dart';
import 'ui/session_edit/session_edit_screen.dart';
import 'ui/sessions/sessions_screen.dart';
import 'ui/sessions/sessions_split_view.dart';
```

Em `lib/router.dart`, substituir:

```dart
}

/// Rotas do app. O redirecionamento observa o `AuthRepository`: entrar ou sair
/// da sessão troca a tela sem nenhuma navegação manual espalhada pelo código.
```

por:

```dart
}

/// No tablet, `/home` e `/sessions/:id` são a mesma página (a lista e o
/// detalhe juntos, `SessionsSplitView`): a chave igual faz o `Navigator`
/// atualizar a página em vez de trocar uma por outra, e o estado de lista e
/// detalhe atravessa a troca de rota e o giro do aparelho.
const ValueKey<String> _sessionsSplitPageKey = ValueKey('sessions-split');

Page<void> _sessionsPage(
  BuildContext context,
  GoRouterState state, {
  required Widget phone,
  String? selectedSessionId,
}) {
  if (FormFactorScope.of(context) == FormFactor.tablet) {
    return NoTransitionPage<void>(
      key: _sessionsSplitPageKey,
      child: SessionsSplitView(selectedSessionId: selectedSessionId),
    );
  }
  return MaterialPage<void>(key: state.pageKey, child: phone);
}

/// Rotas do app. O redirecionamento observa o `AuthRepository`: entrar ou sair
/// da sessão troca a tela sem nenhuma navegação manual espalhada pelo código.
```

Em `lib/router.dart`, substituir:

```dart
        builder: (context, state) => const SessionsScreen(),
```

por:

```dart
        pageBuilder: (context, state) =>
            _sessionsPage(context, state, phone: const SessionsScreen()),
```

Em `lib/router.dart`, substituir:

```dart
        builder: (context, state) => SessionDetailScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
```

por:

```dart
        pageBuilder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return _sessionsPage(
            context,
            state,
            phone: SessionDetailScreen(sessionId: sessionId),
            selectedSessionId: sessionId,
          );
        },
```

Criar `lib/ui/sessions/sessions_split_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_nav_bar.dart';
import '../session_detail/session_detail_screen.dart';
import 'sessions_screen.dart';

/// Lista de sessões e detalhe no tablet — uma página só para `/home` e
/// `/sessions/:id`, que o router reaproveita entre as duas rotas.
///
/// - Paisagem (quadros "4c" e "4d"): navbar lateral, lista de 392 à esquerda
///   e o detalhe da [selectedSessionId] à direita. Sem sessão escolhida, um
///   aviso no lugar do detalhe (decisão de 21/10/2026).
/// - Retrato (quadro "4e"): uma tela por vez. Com sessão escolhida, o
///   detalhe ocupa a tela, com o voltar; a lista continua montada embaixo,
///   escondida, e volta do jeito que estava.
///
/// Girar o aparelho não perde nada: a lista e o detalhe têm `GlobalKey`, e
/// mudam de lugar na árvore sem recriar o estado (a ViewModel, o filtro, a
/// rolagem).
class SessionsSplitView extends StatefulWidget {
  const SessionsSplitView({super.key, this.selectedSessionId});

  final String? selectedSessionId;

  @override
  State<SessionsSplitView> createState() => _SessionsSplitViewState();
}

class _SessionsSplitViewState extends State<SessionsSplitView> {
  /// Largura da lista em paisagem.
  static const double listWidth = 392;

  final GlobalKey _listKey = GlobalKey(debugLabel: 'lista-de-sessoes');

  /// Uma chave por sessão aberta: trocar de sessão cria um detalhe novo; a
  /// mesma sessão, girando, reaproveita o que já existe.
  GlobalKey? _detailKey;
  String? _detailKeyId;

  GlobalKey _detailKeyFor(String sessionId) {
    if (_detailKeyId != sessionId) {
      _detailKeyId = sessionId;
      _detailKey = GlobalKey(debugLabel: 'detalhe-$sessionId');
    }
    return _detailKey!;
  }

  void _open(String sessionId) =>
      context.go(AppRoutes.sessionDetail(sessionId));

  void _backToList() => context.go(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    final expanded = context.isExpandedLayout;
    final selected = widget.selectedSessionId;

    final list = SessionsScreen(
      key: _listKey,
      embedded: expanded,
      selectedSessionId: expanded ? selected : null,
      onOpenSession: _open,
    );

    final Widget body;
    if (expanded) {
      body = _buildTwoPanes(list, selected);
    } else if (selected == null) {
      body = list;
    } else {
      body = Stack(
        fit: StackFit.expand,
        children: [
          Offstage(child: TickerMode(enabled: false, child: list)),
          SessionDetailScreen(
            key: _detailKeyFor(selected),
            sessionId: selected,
            onBack: _backToList,
          ),
        ],
      );
    }

    // Com uma sessão aberta, o voltar do Android fecha a sessão em vez de
    // fechar o app: em retrato volta para a lista; em paisagem, tira a
    // seleção.
    return PopScope(
      canPop: selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToList();
      },
      child: body,
    );
  }

  Widget _buildTwoPanes(Widget list, String? selected) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: TabletNavFrame(
          current: AppTab.sessions,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: listWidth, child: list),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.border,
              ),
              Expanded(
                child: selected == null
                    ? const _NoSessionSelected()
                    : SessionDetailScreen(
                        key: _detailKeyFor(selected),
                        sessionId: selected,
                        embedded: true,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O lado direito antes de escolher uma sessão (o canvas não desenha este
/// estado; aprovado em 21/10/2026).
class _NoSessionSelected extends StatelessWidget {
  const _NoSessionSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('no-session-selected'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.sessions, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Escolha uma sessão na lista',
              style: AppTypography.cardTitle.copyWith(color: AppColors.text3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/sessions/sessions_split_view_test.dart`
Esperado: `+8: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+976: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/sessions/sessions_split_view.dart apps/mobile/simtc/lib/router.dart apps/mobile/simtc/test/ui/sessions/sessions_split_view_test.dart
git commit -m "feat(mobile): lista e detalhe lado a lado no tablet sem perder estado ao girar"
```

---
## Task 8: Validação no emulador de tablet e no celular

Esta task é o portão da fase: sem ela, a 7B não é planejada. É o roteiro que só o usuário pode rodar. O tablet é conferido num **emulador** (decisão 2); o celular, no **aparelho físico**, para confirmar que nada piorou.

**Interfaces:**
- Consumes: o app inteiro, com as Tasks 1 a 7.
- Produces: o aval do usuário para planejar a 7B.

- [ ] **Step 1: Preparar o emulador de tablet**

No Android Studio → Device Manager → "Create Virtual Device" → categoria **Tablet** → **Pixel Tablet** (2560×1600, 1280×800 em dp) → uma imagem de sistema Android 14 ou mais nova → concluir. Ligar o emulador e conferir que o Flutter o enxerga:

Run: `flutter devices`
Esperado: uma linha com `sdk gphone64` (ou o nome dado ao emulador) e `emulator-5554`.

Girar o emulador: os botões de girar da barra lateral dele, ou `Ctrl` + `←`/`→`. A rotação automática do sistema do emulador precisa estar ligada (Configurações rápidas → "Girar automaticamente").

- [ ] **Step 2: Instalar e rodar**

Com o backend local rodando (`npm run dev:backend`, como nas fases anteriores), ligar a porta do emulador à do PC — o mesmo `adb reverse` do celular, `apps/mobile/simtc/README.md`:

Run: `adb -s emulator-5554 reverse tcp:3001 tcp:3001` e depois, em `apps/mobile/simtc/`, `flutter run -d emulator-5554`
Esperado: o app abre na Abertura, em tela de tablet.

- [ ] **Step 3: Roteiro no tablet (emulador)**

Com um usuário CONSULTANT que tenha sessões de hoje, e depois com um ADMIN:

1. **Abertura e Entrar:** a logo grande; em paisagem, a logo à esquerda e o formulário à direita; girar para retrato: a logo em cima. Tocar no e-mail (teclado aberto) e girar: o "Entrar" continua alcançável rolando.
2. **Lista em paisagem:** navbar lateral à esquerda com "Sessões", "Sincr." e "Perfil"; a lista à esquerda e, à direita, "Escolha uma sessão na lista".
3. **Abrir uma sessão:** o detalhe aparece à direita, sem a barra "Detalhe da sessão"; o card dela fica destacado; o progresso "N de M avaliados" no alto, à direita. Tocar noutra sessão troca o detalhe e o destaque.
4. **Girar com a sessão aberta:** escolher o chip "Pendentes" e rolar a lista de participantes; girar para retrato: o detalhe ocupa a tela, com a seta de voltar, o mesmo chip escolhido; girar de volta: tudo no lugar. Repetir umas três vezes, rápido.
5. **Voltar:** em retrato, a seta leva à lista, na mesma posição de rolagem em que ela estava; o voltar do Android também. Em paisagem, o voltar do Android tira a sessão aberta (volta o "Escolha uma sessão na lista"); outro voltar fecha o app.
6. **Checklist (o que reprova a fase):** atribuir-se um participante e abrir o checklist; marcar várias notas, em categorias diferentes; **girar o tablet várias vezes, inclusive logo depois de tocar numa nota**; conferir que **todas** as marcações e o percentual continuam. Finalizar, confirmar e conferir o Resultado.
7. **Sincronizar:** em paisagem, a navbar lateral e a fila numa coluna central; em retrato, a pílula na base, a 120 das laterais. A navbar leva de uma aba à outra; "Perfil" diz "Disponível em breve.".
8. **ADMIN em paisagem:** o lápis e o ícone de pessoas na linha da empresa; o progresso na linha de local e data; o "adicionar" no título "Participantes". Os três abrem as telas de admin em tela cheia (a janela ancorada é da 7B); voltar delas traz o lado a lado como estava.
9. **Sem conexão** (desligar a rede do emulador): a faixa de aviso nos dois painéis; as ações de ADMIN apagadas, com o motivo.
10. **Tela dividida:** abrir o app junto com outro app em tela dividida (botão de apps recentes → ícone do app → "Dividir tela"): o app continua funcionando, numa tela por vez, sem travar em retrato.

11. **Abrir a frio já deitado** (fechar o app, girar o emulador para paisagem e abrir): ele abre como tablet, com a navbar lateral, e gira. Se abrir como celular (travado em retrato, pílula do celular), parar: o formato é lido antes do primeiro quadro (`lib/main.dart`), e a correção é uma guarda ali.
12. **Nome de empresa longo** no painel de paisagem: o nome quebra de linha sem empurrar o progresso para fora.
13. **Navegação do sistema:** em retrato, a pílula não fica cortada nem sobreposta à barra do Android, com navegação por gestos e com os 3 botões (Configurações → Sistema → Navegação).
14. **TalkBack** (opcional): o card da sessão aberta é anunciado como selecionado.
- [ ] **Step 4: Roteiro no celular (aparelho físico)**

Instalar no celular de sempre (`flutter run -d <id do celular>`, como nas fases anteriores) e conferir:

1. **Girar o celular não gira o app**: ele fica em retrato em todas as telas.
2. A Home, o detalhe, o checklist, a Sincronizar e o Entrar estão como antes: a navbar em pílula na base, o detalhe empilhado com a seta de voltar, os mesmos recuos.

- [ ] **Step 5: Registrar o resultado**

Se tudo passar, acrescentar ao fim desta task a linha "**Validado em <data>: tablet no emulador e celular no aparelho físico; roteiro inteiro passou. Aval dado para planejar a 7B.**" e commitar:

```bash
git add apps/mobile/docs/superpowers/plans/2026-10-21-mobile-fase-7a-tablet-estrutura.md
git commit -m "docs(mobile): registra a validacao da fase 7a no emulador e no aparelho"
```

Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio, parar e perguntar.

---

## Pendências levadas para a 7B e a 8

- **7B:** a avaliação em tela larga — 1.4.1 Iniciar avaliação (`6b`/`6c`), 1.5 Checklist (`4f`/`4q`), 1.6 Conferir e finalizar (`4g`/`4r`), 1.8 Resultado (`4i`/`4t`), mais as specs `4z` e `5a` — e as três telas de admin como diálogo ancorado (`4l`/`4w`, `4m`/`4x`, `4n`/`4y`). O teste de giro do checklist da Task 7 tem de continuar passando quando o checklist ganhar o layout largo.
- **7B (a decidir):** o aviso passageiro (SnackBar) cobre a pílula do tablet em retrato enquanto aparece.
- **8:** o Perfil (`4k`/`4v` no tablet) com o "Sair", e o item de roteiro herdado da Fase 2 ("sair e entrar com outro consultor não mostra a agenda do anterior"); as buscas (as lupas dos quadros `4c`, `4d` e `4e`).
