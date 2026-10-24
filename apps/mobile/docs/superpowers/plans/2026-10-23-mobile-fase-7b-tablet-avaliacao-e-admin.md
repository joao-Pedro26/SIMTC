# App Mobile SIMTC — Fase 7B: Tablet — avaliação em tela larga e janelas de admin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** No tablet, o fluxo de avaliação (Iniciar, Checklist, Conferir e finalizar, Resultado) aproveita a tela larga sem deixar de ser tela cheia, e as três telas de admin (Adicionar participante, Dados do treinamento, Consultores) viram janelas por cima do detalhe da sessão. Girar o tablet continua não perdendo nada — nem as marcações do checklist, nem o que foi digitado numa janela. O celular não muda.

**Architecture:** As telas da avaliação leem o formato (`context.isTablet`, `context.isExpandedLayout`, da 7A) e trocam só a disposição e os tamanhos, com tokens novos do tablet; a regra, a ViewModel e a navegação são as mesmas. As telas de admin continuam sendo rotas do `go_router`: no tablet, a rota devolve uma `AdminDialogPage` (uma `RawDialogRoute` com o fundo escurecido) em vez da `MaterialPage`, e a tela se desenha dentro da moldura `AdminDialogFrame`. Como a rota e a ViewModel são as mesmas, o `push` com resultado, o `PopScope` que pergunta antes de descartar e o estado do formulário atravessam o giro. O detalhe marca o botão que abriu a janela enquanto ela está aberta. Nenhuma regra, dado ou chamada ao backend muda.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · drift 2.31.0 (sem mudança de esquema) · mocktail (testes). Nenhuma dependência nova.

**Spec:** `apps/mobile/docs/superpowers/specs/2026-10-21-mobile-fase-7-tablet-design.md` (desenho aprovado em 21/10/2026; esta é a 7B); plano da 7A, `apps/mobile/docs/superpowers/plans/2026-10-21-mobile-fase-7a-tablet-estrutura.md` (validado no emulador e no aparelho em 23/10/2026); canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html`, bloco Tablet: quadros `6b`/`6c` (1.4.1 Iniciar avaliação, linhas 1934 e 1995), `4f`/`4q` (1.5 Checklist, 2054 e 2122), `4g`/`4r` (1.6 Conferir e finalizar, 2192 e 2240), `4i`/`4t` (1.8 Resultado, 2301 e 2381), `4l`/`4w` (1.11 Adicionar participante, 2685 e 2819), `4m`/`4x` (1.12 Dados do treinamento, 2925 e 3057), `4n`/`4y` (1.13 Consultores da sessão, 3162 e 3290) e as specs `4z` e `5a` (3393 e 3424).

**Validação prévia:** todo o código deste plano foi escrito e rodado numa cópia descartável do app antes de o plano ser fechado, uma task por commit, e depois as tasks foram **reencenadas em ordem** numa segunda cópia limpa: em cada task, os testes da task falharam antes da implementação e passaram depois, e cada checkpoint bateu o número de testes — **976 → 980 → 987 → 991 → 995 → 1001 → 1003 → 1005 → 1007**, com `flutter analyze` sem issues em todos. Os blocos de código foram gerados da primeira cópia por um script que confere cada "substituir / por" contra o estado deixado pelo bloco anterior, e a reencenação conferiu que a árvore de cada task ficou **idêntica** à do commit correspondente. **Cada decisão e cada medida foi conferida por mutação** (o trecho é trocado, e algum teste tem de falhar): **43 mutações, todas acusadas**. Duas falhas só apareceram assim, e foram corrigidas antes de fechar: a janela de admin era recriada ao girar (a moldura trocava `Align` por `Center`), e o cabeçalho do checklist estourava numa janela de 500 (tela dividida). As telas da avaliação e a janela de Adicionar participante foram **desenhadas com as fontes de verdade** em 1280×800 e 800×1280 e conferidas a olho contra os quadros.

## Decisões tomadas com o usuário

Herdadas do desenho da Fase 7 (21/10/2026) e da 7A: o tablet é validado em emulador e o celular no aparelho físico; todas as telas seguem o giro no tablet, inclusive o checklist; o fluxo de avaliação é tela cheia no tablet (nunca lado a lado); as telas de admin viram janela no tablet, com as mesmas ViewModels da Fase 6, e continuam telas cheias no celular; o que reprova a fase é perder as marcações do checklist ao girar.

Em 23/10/2026, ao preparar este plano:

1. **Seguir do canvas, sem pergunta (aprovado):** a avaliação em tela cheia, sem navbar; no checklist, os botões B/PM/M à direita da descrição (312 em paisagem, 264 em retrato) e recuos de 24; o Iniciar avaliação numa coluna de até 760 em paisagem, com o botão de 420 no fim dela, e com o botão num rodapé na largura toda em retrato; o Conferir e finalizar numa coluna de até 940 com o botão de 420 no fim em paisagem, e com recuo de 32 e o botão no rodapé em retrato; o Resultado em dois painéis em paisagem (452 à esquerda com a nota, o desempenho e o botão embaixo; as infrações à direita) e numa coluna só em retrato, com o botão no rodapé; as janelas de admin ancoradas à direita em paisagem (a 40 da borda, 560/600 de largura) e centradas com 640 em retrato, fundo escurecido a 42%, canto 16, cabeçalho com título, subtítulo e X, e o rodapé numa linha só.
2. **Manter como no celular (aprovado):** nada de pontos (ficam a contagem de itens e o selo de %); a barra do checklist continua sendo a nota em % (decisão de 30/09), e não "1 de 4 categorias revisadas"; os botões com os nomes de hoje ("Confirmar", não "Confirmar e assinar"); as janelas de admin com os campos e a ordem do celular — "Início", "Status da sessão" e "Consultor responsável" do canvas não entram.
3. **"Finalizar avaliação" no cabeçalho do checklist**, como no canvas: em paisagem, numa linha com o nome e a nota; em retrato, ao lado do nome, com a nota numa segunda faixa. O aviso "não está mais com você" vai para o topo da lista.
4. **O botão que abriu a janela de admin fica marcado** atrás do fundo escurecido (fundo `#E6F6F7`, borda de 1,5 `#1D9AA4`), como no canvas.
5. **Tocar no fundo escurecido é o mesmo que o X**: fecha e, com algo preenchido, pergunta antes.
6. **O aviso passageiro (SnackBar) sobe para cima da pílula** no tablet em retrato (pendência da 7A).
7. **Tamanhos do canvas do tablet** nas telas da avaliação e nas janelas: barra de topo 18, nome no checklist 18, categoria 16, "A avaliação ainda não começou" 18/19 com ícone de 44/48, nota de 48 na conferência e 44 no resultado, botões principais de 60 com texto de 17. Tokens novos, só do tablet; o celular não muda.

### Ajustes feitos ao preparar o plano (revisar junto com o plano)

A validação na cópia descartável levou a estas escolhas. **Nenhuma muda regra de negócio aprovada**, mas cada uma é uma regra de tela que o código cria, ou uma medida, que o usuário deve conferir.

**Avaliação:**

- **Numa janela mais estreita que 600 (tela dividida), o checklist volta ao do celular**: o "Finalizar avaliação" desce para o rodapé e os botões B/PM/M voltam para baixo da descrição. Em 500 de largura, o cabeçalho com o botão estourava.
- **No checklist em paisagem**, o nome fica com no máximo 320 e a nota (até 360) fica centrada no espaço entre o nome e o botão. **O menu ⋮ (que não está no canvas) fica na ponta direita**, depois do "Finalizar", a 8 dele, nas duas posições.
- **Os blocos de categoria do checklist ficam colados no tablet** (o quadro `4f` não tem os 10 entre eles nem os 12 em cima do celular).
- **Diferenças de meio ponto ficam com o token do celular**: o número do item (12, o quadro diz 12,5), a contagem "N itens" (12, o quadro diz 12,5) e o "salvo" (11,5, o quadro diz 12).
- **O botão do cabeçalho tem 48 de altura e texto de 15** (`AppCtaSize.header`); o das janelas, 52 e 15 (`AppCtaSize.dialog`) — os dois do canvas.
- **Conferir e finalizar:** a linha de categoria tem uma divisória de 1,5 só embaixo (o quadro desenha em cima e embaixo de cada linha, o que somaria 3 entre duas). Com erro ao confirmar, o aviso fica acima do botão, nas duas posições.
- **Resultado em paisagem:** os avisos de envio e de origem dos dados ficam no painel da esquerda, embaixo da nota; o "Reavaliar" (e o "Disponível quando houver conexão") fica no lugar do "Próximo participante". Em retrato, uma linha separa o desempenho das infrações, como no `4t`.
- **A barra de topo passa a 18 em todo o tablet**, inclusive no detalhe da sessão em retrato da 7A, como no quadro `4e`.

**Janelas de admin:**

- **Subtítulos:** "Adicionar participante" mostra "empresa · curso · dia"; "Dados do treinamento", "empresa · curso" (o canvas põe ali o motivo do travamento, mas no app ele continua sendo o aviso dentro da janela); "Consultores da sessão", a frase do canvas ("Cada toque vale na hora — não há botão de salvar."). A faixa da empresa do celular sai da janela.
- **O título de Consultores na janela é "Consultores da sessão"** (do canvas); no celular continua "Consultores".
- **Os botões principais mantêm os rótulos do celular** ("Adicionar participante", "Salvar alterações"); o canvas usa "Adicionar".
- **O motivo de o botão estar apagado sem conexão** ("Disponível quando houver conexão") fica embaixo da linha do rodapé, à direita.
- **Em paisagem, a janela de Adicionar participante fica a 80 do topo da área útil e as outras duas a 68** (os 112 e 100 do quadro menos os 32 da barra de status desenhada). A altura máxima é a do quadro (640/660), menos o que faltar na tela; em retrato, até 1000.
- **Com o teclado aberto, a janela encolhe para caber acima dele**, e o conteúdo rola.
- **O botão marcado tem 48** (o "adicionar" do quadro tem 44).
- **O aviso passageiro de uma janela** ("Fulano entrou na sessão.") aparece na base da tela, atrás do fundo escurecido.
- **A janela não é recriada ao girar**: a moldura tem a mesma árvore nas duas posições (um `Align` que muda de alinhamento).

**Aviso passageiro:** no tablet em retrato, ele flutua a 8 acima da pílula, com os mesmos 120 de recuo dos lados (16 numa janela estreita); em paisagem, continua na base.

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app` (a mesma das fases anteriores). Sem git worktree. Não criar branch, não fazer merge, não fazer push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada, com a mensagem exata dada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem trabalho do usuário fora do git, que **não é desta fase e fica exatamente como está**: um arquivo rastreado **já modificado** (`brainstorm-app-mobile.md`) e os não rastreados `.vscode/`, `IMPLEMENTATION-STATUS.md`, `apps/backend/test-render.js`, `apps/mobile/simtc/devtools_options.yaml`, `apps/web/src/app/(client)/my-company/trainings/[id]/certificates/`, `brainstorm-implementacao-mobile.md`, `prompt-claude-design-mobile.md`, `prompt-implementacao-mobile-claude-code.md`, `test-pdf.js` e `test-render.js`.
- **Proibido `git restore`, `git checkout -- <arquivo>`, `git stash`, `git reset` e `git clean`**, e qualquer outro comando que desfaça mudança que não é da task. Se o `git status` mostrar algo que não é da task, ignorar e seguir.
- **Na execução por subagentes:** antes do primeiro despacho, guardar a linha de base — o `git status --porcelain` inteiro e o `git hash-object brainstorm-app-mobile.md` — e compará-la, sem filtrar nada, depois de **cada** subagente. Todo despacho repete as duas regras acima com todas as letras. Implementadores em **haiku**; revisões com modelo mais forte (sonnet nas Tasks 1, 3, 4, 6, 7 e 8; opus nas Tasks 2 e 5, que mexem no checklist e na rota das janelas).
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-10-23-mobile-fase-7b-tablet/`.

**Mobile (valem para todas as fases)**
- Flutter 3.41.6 / Dart 3.11.4 (o `pubspec.yaml` aceita a partir do 3.4: nada de sintaxe mais nova que isso). App **só Android**, APK sideload. O tablet é validado em emulador; o celular, no aparelho físico.
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

Os casos que o desenho implica, que um consultor no carro (ou um admin no escritório) vai encontrar, e onde cada um ficou preso num teste:

1. **Girar o tablet várias vezes no meio do checklist, agora com o layout largo, com uma marcação gravando** (o caso que reprova a fase) → nenhuma marcação some. Preso em: `girar várias vezes no meio do checklist não perde nenhuma marcação, nem a que ainda está gravando` (o teste da 7A, cujo ajudante passa a achar o botão pela linha da infração — Task 2).
2. **Girar com uma janela de admin aberta e o formulário pela metade** → a janela não é recriada, o texto fica, e o botão continua marcado. Preso em: `girar várias vezes com o formulário preenchido não perde o que foi digitado` (Task 5) e `girar com o local alterado não perde o que foi digitado; o fundo pergunta antes de descartar` (Task 6).
3. **Tocar sem querer no fundo escurecido com o formulário preenchido** → pergunta antes de descartar. Preso em: `tocar no fundo é o mesmo que o X: com algo preenchido, pergunta antes; descartando, a janela fecha e o botão desmarca` (Task 5).
4. **Teclado aberto numa janela em paisagem** (metade da altura) → a janela encolhe acima dele e nada estoura. Preso em: `com o teclado aberto em paisagem, a janela encolhe acima dele e nada estoura` (Task 5).
5. **Tablet em tela dividida (janela de 500)** → o checklist volta ao do celular em vez de estourar o cabeçalho. Preso em: `numa janela estreita (tela dividida), o checklist volta ao do celular: botões embaixo da descrição e "Finalizar" no rodapé` (Task 2).

## Estado herdado (ponto de partida)

HEAD = o commit deste plano, sobre `a9e4e48` (a validação da 7A). App: `flutter analyze` limpo; **976 testes passando**.

Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| Formato | `lib/ui/core/form_factor.dart` | `FormFactorScope`, `context.isTablet`, `context.isExpandedLayout` (tablet com janela a partir de 840), `AppBreakpoints.tabletShortestSide` (600) |
| Rotas | `lib/router.dart` | `AppRoutes.sessionEdit/addParticipant/sessionConsultants(id)`; `_sessionsPage` (a página da lista e do detalhe no tablet) |
| Navbar do tablet | `lib/ui/core/widgets/app_nav_bar.dart` | `AppTab`, `AppNavBar`, `TabletNavFrame` (`railInset` 116, `bottomInset` 100, `bottomSide` 120) |
| Telas da avaliação | `lib/ui/checklist/checklist_screen.dart`, `lib/ui/summary/summary_screen.dart`, `lib/ui/result/result_screen.dart` | o "não iniciada" é o próprio checklist (`_buildNotStarted`); `FinalScoreBlock` (`lib/ui/core/widgets/final_score_block.dart`) no topo da 1.6 e do Resultado |
| Telas de admin | `lib/ui/add_participant/`, `lib/ui/session_edit/`, `lib/ui/session_consultants/` | cada uma com `PopScope` próprio (a de consultores não tem) e os rodapés da Fase 6 |
| Detalhe | `lib/ui/session_detail/session_detail_screen.dart` | `_buildAdminActions`, `_openEdit`, `_openConsultants`, `_openAddParticipant`, o "adicionar" no título "Participantes" |
| Botões | `lib/ui/core/widgets/app_buttons.dart` | `AppCtaButton` (`AppCtaSize.compact`/`large`), `AppTextButton`, `AppIconAction` |
| Testes | `test/ui/…` | `test/ui/sessions/sessions_split_view_test.dart` monta o app inteiro no tablet (`pumpApp`, `rotate`, `settle`), com banco em memória e a API fora do ar |

## Mapa de Arquivos

### Novos

| Arquivo | Task | Responsabilidade |
|---|---|---|
| `lib/ui/core/widgets/admin_dialog.dart` | 5 | `AdminDialogSize`, `AdminDialogPage`, `AdminDialogLayout`, `AdminDialogFrame`, `AdminDialogFooter` |

### Modificados

| Arquivo | Tasks | O que muda |
|---|---|---|
| `lib/ui/core/widgets/app_buttons.dart` | 1, 2, 5 | `AppCtaSize.tabletLarge`/`header`/`dialog`; `AppCtaButton.fullWidth`; `AppTextButton.alignStart`; `AppIconAction.highlighted` |
| `lib/ui/core/theme/app_typography.dart` | 1, 3, 4, 5 | os tokens do tablet |
| `lib/ui/core/theme/app_colors.dart` | 5 | `scrim`, `dialogShadow` |
| `lib/ui/checklist/checklist_screen.dart` | 1, 2 | o "não iniciada" e o checklist no tablet |
| `lib/ui/core/widgets/final_score_block.dart` | 3, 4 | `FinalScoreScale`, `padding` |
| `lib/ui/core/widgets/app_top_bar.dart` | 3 | título de 18 no tablet |
| `lib/ui/summary/summary_screen.dart` | 3 | a conferência no tablet |
| `lib/ui/result/result_screen.dart` | 4 | o Resultado no tablet |
| `lib/router.dart` | 5, 6, 7 | `_adminPage` nas três rotas de admin |
| `lib/ui/session_detail/session_detail_screen.dart` | 5 | o botão marcado |
| `lib/ui/add_participant/add_participant_screen.dart` | 5 | a janela |
| `lib/ui/session_edit/session_edit_screen.dart` | 6 | a janela |
| `lib/ui/session_consultants/session_consultants_screen.dart`, `consultant_row.dart` | 7 | a janela; `ConsultantRow.horizontalInset` |
| `lib/ui/core/widgets/app_nav_bar.dart`, `lib/ui/sessions/sessions_screen.dart`, `lib/ui/sync/sync_screen.dart` | 8 | `TabSnackBarArea`, `TabletNavFrame.sideFor` |
| testes existentes | todas | `checklist_screen_test.dart`, `sessions_split_view_test.dart`, `summary_screen_test.dart`, `result_screen_test.dart`, `app_nav_bar_test.dart` |

---


## Task 1: Iniciar avaliação no tablet

O "não iniciada" do checklist (1.4.1) no tablet: em paisagem, uma coluna de até 760, centrada, com o "Iniciar avaliação" de 420×60 no fim dela e sem rodapé (quadro `6b`); em retrato, recuo de 32 e o botão num rodapé cinza-claro, na largura toda (quadro `6c`). O cabeçalho do checklist ganha as medidas do tablet (nome de 18). Os tamanhos do canvas do tablet viram tokens novos; o celular não muda.

**Files:**
- Modify: `lib/ui/checklist/checklist_screen.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/widgets/app_buttons.dart`
- Modify: `test/ui/checklist/checklist_screen_test.dart`

**Interfaces:**
- Consumes: `context.isTablet`, `context.isExpandedLayout`, `FormFactorScope` (7A).
- Produces:
  - `AppCtaSize.tabletLarge` (60 de altura, texto 17, ícone 24) e `AppCtaButton.tabletLargeHeight`
  - `AppTypography.appBarTitleTablet` (18), `sectionTitleTablet`, `buttonTablet`, `notStartedTitleExpanded`/`notStartedTitleTablet`, `notStartedBodyExpanded`/`notStartedBodyTablet`, `categoryNameTablet` (16)

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/theme/app_colors.dart';
```

por:

```dart
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
Color scoreBarColor(WidgetTester tester) =>
    (scoreBar(tester).valueColor! as AlwaysStoppedAnimation<Color>).value;

void main() {
```

por:

```dart
Color scoreBarColor(WidgetTester tester) =>
    (scoreBar(tester).valueColor! as AlwaysStoppedAnimation<Color>).value;

const _landscape = Size(1280, 800);
const _portrait = Size(800, 1280);

double fontSizeOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.fontSize!;

void main() {
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
  });
}
```

por:

```dart
  });

  group('no tablet', () {
    /// O checklist num tablet de [size], com o formato que o app decide na
    /// abertura.
    Future<void> pumpTablet(
      WidgetTester tester,
      Size size, {
      bool started = true,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (started) await startEvaluation();
      await tester.pumpWidget(withProviders(
        const FormFactorScope(
          formFactor: FormFactor.tablet,
          child: MaterialApp(
            home: ChecklistScreen(sessionId: 'sess-1', participantId: 'tp-1'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'em paisagem, antes do "Iniciar": uma coluna de 760 centrada, com o '
        'botão de 420×60 no fim dela, sem rodapé (quadro "6b")', (tester) async {
      await addSecondCategory();
      await pumpTablet(tester, _landscape, started: false);

      final column = tester.getRect(find.byKey(const Key('checklist-not-started-column')));
      expect(column.width, 760);
      expect(column.center.dx, 640);

      final cta = find.widgetWithText(AppCtaButton, 'Iniciar avaliação');
      expect(tester.getSize(cta), const Size(420, 60));
      expect(tester.getCenter(cta).dx, 640);
      expect(
        find.descendant(
          of: find.byKey(const Key('checklist-not-started')),
          matching: cta,
        ),
        findsOneWidget,
        reason: 'o botão está na rolagem, no fim da coluna',
      );
      expect(
        tester.getTopLeft(cta).dy,
        greaterThan(tester.getBottomLeft(find.text('Respeito às Regras')).dy),
      );

      expect(tester.getTopLeft(find.text('CV')).dx - column.left, 7,
          reason: 'a linha não tem recuo próprio: o chip começa na coluna (7 é o recuo do chip)');
      expect(fontSizeOf(tester, 'Ana Paula Ribeiro'), 18);
      expect(fontSizeOf(tester, 'A avaliação ainda não começou.'), 18);
      expect(fontSizeOf(tester, 'O que será avaliado'), 13.5);
      expect(fontSizeOf(tester, 'Controle do Veículo'), 16);
      expect(tester.getSize(find.byIcon(AppIcons.timer).last).height, 44);
    });

    testWidgets(
        'em retrato, antes do "Iniciar": recuo de 32 e o botão no rodapé, na '
        'largura toda, com 60 de altura (quadro "6c")', (tester) async {
      await pumpTablet(tester, _portrait, started: false);

      expect(find.byKey(const Key('checklist-not-started-column')), findsNothing);
      expect(tester.getTopLeft(find.text('CV')).dx, 32 + 7);
      expect(tester.getTopLeft(find.text('O que será avaliado')).dx, 32);

      final cta = find.widgetWithText(AppCtaButton, 'Iniciar avaliação');
      expect(tester.getSize(cta), const Size(800 - 2 * 32, 60));
      expect(tester.getBottomLeft(cta).dy, 1280 - 16);
      expect(
        find.descendant(
          of: find.byKey(const Key('checklist-not-started')),
          matching: cta,
        ),
        findsNothing,
        reason: 'o botão fica fora da rolagem',
      );
      expect(fontSizeOf(tester, 'A avaliação ainda não começou.'), 19);
      expect(tester.getSize(find.byIcon(AppIcons.timer).last).height, 48);
    });

    testWidgets(
        'em paisagem, com outra avaliação em andamento, o aviso fica acima do '
        'botão, na coluna', (tester) async {
      await db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-2',
              sessionId: 'sess-1',
              name: 'Marina Lopes',
              cpf: '111.222.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'EM_AVALIACAO',
              assignedConsultantId: const Value('c-eu'),
              cachedAt: DateTime(2026, 9, 25, 8),
            ),
          );
      await assessmentRepository.openDraft(
        trainingParticipantId: 'tp-2',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
        consultantId: 'c-eu',
      );

      await pumpTablet(tester, _landscape, started: false);

      final notice = find.byType(InlineNotice);
      final cta = find.widgetWithText(AppCtaButton, 'Iniciar avaliação');
      expect(tester.getBottomLeft(notice).dy + 12, tester.getTopLeft(cta).dy);
      expect(tester.getSize(notice).width, 760);
      expect(tester.widget<AppCtaButton>(cta).onPressed, isNull);
    });

    testWidgets('"Iniciar avaliação" no tablet começa a avaliação', (tester) async {
      await pumpTablet(tester, _landscape, started: false);

      await tester.tap(find.text('Iniciar avaliação'));
      await tester.pumpAndSettle();

      expect(find.text('Excesso de velocidade'), findsOneWidget);
      expect(find.text('salvo'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/checklist/checklist_screen_test.dart`
Esperado: `+35 -3: Some tests failed.` — os três testes de medida do tablet falham (a coluna de 760, o rodapé de 32 em retrato, o aviso acima do botão); o "Iniciar avaliação" no tablet já funcionava.

- [ ] **Step 3: Implementar**

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
import '../../router.dart';
import '../core/score_labels.dart';
```

por:

```dart
import '../../router.dart';
import '../core/form_factor.dart';
import '../core/score_labels.dart';
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
  final GlobalKey _openHeaderKey = GlobalKey();

  /// Um desatribuir (que espera o backend) ou um descarte no ar: o menu ⋮ e o
  /// "Finalizar avaliação" ficam desabilitados até terminar — outra rota
```

por:

```dart
  final GlobalKey _openHeaderKey = GlobalKey();

  /// Coluna do "não iniciada" no tablet em paisagem (quadro "6b").
  static const double notStartedMaxWidth = 760;

  /// Largura do botão no fim dessa coluna.
  static const double notStartedCtaWidth = 420;

  /// Um desatribuir (que espera o backend) ou um descarte no ar: o menu ⋮ e o
  /// "Finalizar avaliação" ficam desabilitados até terminar — outra rota
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return Scaffold(
```

por:

```dart
  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;
    final footer = _buildFooter();

    return Scaffold(
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
            if (!_viewModel.isLoading && _viewModel.hasCatalog && !_viewModel.isConfirmed)
              _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isOffline) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm + 2,
```

por:

```dart
            if (footer != null) footer,
          ],
        ),
      ),
    );
  }

  /// No tablet (quadros "6b" e "6c"), o cabeçalho tem 12 embaixo e recua 24
  /// à direita em paisagem e 20 em retrato; o nome tem 18.
  Widget _buildHeader(BuildContext context, bool isOffline) {
    final tablet = context.isTablet;
    final double right = !tablet
        ? AppSpacing.sm
        : context.isExpandedLayout
            ? AppSpacing.xxl
            : AppSpacing.xl;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        right,
        tablet ? AppSpacing.md : AppSpacing.sm + 2,
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
              const SizedBox(width: AppSpacing.xs),
```

por:

```dart
              SizedBox(width: tablet ? AppSpacing.md : AppSpacing.xs),
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
                      style: AppTypography.checklistParticipantName,
```

por:

```dart
                      style: tablet
                          ? AppTypography.appBarTitleTablet
                          : AppTypography.checklistParticipantName,
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
  Widget _buildNotStarted() {
    final sections = _viewModel.sections;
    final items = sections.fold<int>(0, (sum, s) => sum + s.infractions.length);

    return ListView(
      key: const Key('checklist-not-started'),
      children: [
        _buildNotStartedHero(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              // Encolhe com reticências: num celular estreito com a fonte
              // ampliada, o título e a contagem não cabem inteiros na linha.
              Expanded(
                child: Text(
                  'O que será avaliado',
                  style: AppTypography.sectionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(_itemsLabel(items), style: AppTypography.categoryCount),
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [for (final category in sections) _buildPreviewCategory(category)],
```

por:

```dart
  ///
  /// No tablet em paisagem (quadro "6b"), tudo numa coluna de até 760,
  /// centrada, com o botão no fim dela; em retrato (quadro "6c"), recuo de 32
  /// e o botão no rodapé.
  Widget _buildNotStarted() {
    final sections = _viewModel.sections;
    final items = sections.fold<int>(0, (sum, s) => sum + s.infractions.length);
    final tablet = context.isTablet;
    final expanded = context.isExpandedLayout;
    final double inset = expanded
        ? 0
        : tablet
            ? AppSpacing.xxxl
            : AppSpacing.xl;

    final children = [
      _buildNotStartedHero(),
      Padding(
        padding: EdgeInsets.fromLTRB(
          inset,
          tablet && !expanded ? AppSpacing.xl : AppSpacing.lg,
          inset,
          AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            // Encolhe com reticências: num celular estreito com a fonte
            // ampliada, o título e a contagem não cabem inteiros na linha.
            Expanded(
              child: Text(
                'O que será avaliado',
                style: tablet
                    ? AppTypography.sectionTitleTablet
                    : AppTypography.sectionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(_itemsLabel(items), style: AppTypography.categoryCount),
          ],
        ),
      ),
      DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          children: [
            for (final category in sections) _buildPreviewCategory(category, inset),
          ],
        ),
      ),
    ];

    if (!expanded) {
      return ListView(key: const Key('checklist-not-started'), children: children);
    }

    return ListView(
      key: const Key('checklist-not-started'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.huge,
        AppSpacing.sm,
        AppSpacing.huge,
        AppSpacing.xxxl,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            key: const Key('checklist-not-started-column'),
            constraints: const BoxConstraints(maxWidth: notStartedMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...children,
                const SizedBox(height: AppSpacing.xxl),
                _buildStartActions(ctaWidth: notStartedCtaWidth),
              ],
            ),
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
    final startedAt = _viewModel.resumableStartedAt;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
        AppSpacing.xxl + 4,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const Icon(AppIcons.timer, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm + 6),
          Text(
            startedAt == null
                ? 'A avaliação ainda não começou.'
                : 'Você começou esta avaliação em $startedAt.',
            style: AppTypography.notStartedTitle,
            textAlign: TextAlign.center,
```

por:

```dart
    final startedAt = _viewModel.resumableStartedAt;
    final tablet = context.isTablet;
    final expanded = context.isExpandedLayout;

    // Quadros "6a" (celular), "6b" (paisagem) e "6c" (retrato).
    final EdgeInsets padding;
    final double iconSize;
    final TextStyle titleStyle;
    final TextStyle bodyStyle;
    if (expanded) {
      padding = const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl + 4,
        AppSpacing.xxl,
        AppSpacing.xxl,
      );
      iconSize = 44;
      titleStyle = AppTypography.notStartedTitleExpanded;
      bodyStyle = AppTypography.notStartedBodyExpanded;
    } else if (tablet) {
      padding = const EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        AppSpacing.huge,
        AppSpacing.xxxl,
        AppSpacing.xxxl + AppSpacing.sm,
      );
      iconSize = 48;
      titleStyle = AppTypography.notStartedTitleTablet;
      bodyStyle = AppTypography.notStartedBodyTablet;
    } else {
      padding = const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
        AppSpacing.xxl + 4,
      );
      iconSize = 40;
      titleStyle = AppTypography.notStartedTitle;
      bodyStyle = AppTypography.notStartedBody;
    }

    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Icon(AppIcons.timer, size: iconSize, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm + 6),
          Text(
            startedAt == null
                ? 'A avaliação ainda não começou.'
                : 'Você começou esta avaliação em $startedAt.',
            style: titleStyle,
            textAlign: TextAlign.center,
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
            style: AppTypography.notStartedBody,
```

por:

```dart
            style: bodyStyle,
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
  Widget _buildPreviewCategory(ChecklistCategory category) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
```

por:

```dart
  Widget _buildPreviewCategory(ChecklistCategory category, double inset) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: inset, vertical: AppSpacing.xl),
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
              category.name,
              style: AppTypography.categoryName,
              maxLines: 1,
```

por:

```dart
              category.name,
              style: context.isTablet
                  ? AppTypography.categoryNameTablet
                  : AppTypography.categoryName,
              maxLines: 1,
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
  Widget _buildFooter() {
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
```

por:

```dart
  /// O rodapé do checklist. No tablet em paisagem, antes do "Iniciar", o
  /// botão fica no fim da coluna (quadro "6b") e não há rodapé; em retrato,
  /// o rodapé tem 16 em cima e embaixo, 32 dos lados e o fundo cinza-claro
  /// (quadro "6c").
  Widget? _buildFooter() {
    if (_viewModel.isLoading || !_viewModel.hasCatalog || _viewModel.isConfirmed) {
      return null;
    }

    final tablet = context.isTablet;
    if (!_viewModel.isStarted && context.isExpandedLayout) return null;
    final tabletStart = tablet && !_viewModel.isStarted;

    return Container(
      decoration: BoxDecoration(
        color: tabletStart ? AppColors.background : AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: tabletStart
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxxl,
              vertical: AppSpacing.lg,
            )
          : const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_viewModel.isBlocked) ...[
                  InlineNotice(
                    icon: AppIcons.timer,
                    tone: NoticeTone.warning,
                    message: _blockedMessage(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppCtaButton(
                  label: _viewModel.isResumable
                      ? 'Continuar avaliação'
                      : 'Iniciar avaliação',
                  icon: AppIcons.startEvaluation,
                  size: AppCtaSize.large,
                  isLoading: _viewModel.isStarting,
                  onPressed: _viewModel.isBlocked ? null : _viewModel.start,
                ),
              ],
            ),
```

por:

```dart
          : _buildStartActions(),
    );
  }

  /// O aviso de outra avaliação em andamento e o "Iniciar avaliação". Com
  /// [ctaWidth], o botão tem essa largura e fica centrado (quadro "6b").
  Widget _buildStartActions({double? ctaWidth}) {
    final button = AppCtaButton(
      label: _viewModel.isResumable ? 'Continuar avaliação' : 'Iniciar avaliação',
      icon: AppIcons.startEvaluation,
      size: context.isTablet ? AppCtaSize.tabletLarge : AppCtaSize.large,
      isLoading: _viewModel.isStarting,
      onPressed: _viewModel.isBlocked ? null : _viewModel.start,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_viewModel.isBlocked) ...[
          InlineNotice(
            icon: AppIcons.timer,
            tone: NoticeTone.warning,
            message: _blockedMessage(),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (ctaWidth == null)
          button
        else
          Center(child: SizedBox(width: ctaWidth, child: button)),
      ],
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
      _inter(size: 17, weight: FontWeight.w600, height: 1.25);

  /// Título de item de lista (nome da empresa, nome do participante)
  static TextStyle get cardTitle =>
```

por:

```dart
      _inter(size: 17, weight: FontWeight.w600, height: 1.25);

  /// O mesmo no tablet, onde também é o nome do participante no cabeçalho
  /// do checklist (quadros "6b", "4f" e "4g")
  static TextStyle get appBarTitleTablet =>
      _inter(size: 18, weight: FontWeight.w600, height: 1.25);

  /// Título de item de lista (nome da empresa, nome do participante)
  static TextStyle get cardTitle =>
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
  static TextStyle get sectionTitle =>
      _inter(size: 13, weight: FontWeight.w700, height: 1.3, color: AppColors.text3);

  /// Rótulo de campo de formulário
```

por:

```dart
  static TextStyle get sectionTitle =>
      _inter(size: 13, weight: FontWeight.w700, height: 1.3, color: AppColors.text3);

  /// "O que será avaliado" no tablet (quadros "6b" e "6c")
  static TextStyle get sectionTitleTablet =>
      _inter(size: 13.5, weight: FontWeight.w700, height: 1.2, color: AppColors.text3);

  /// Rótulo de campo de formulário
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
      _inter(size: 16, weight: FontWeight.w700, height: 1.2, color: AppColors.surface);

  /// Texto de botão compacto, dentro de uma linha de lista ("Atribuir a mim")
  static TextStyle get buttonCompact =>
```

por:

```dart
      _inter(size: 16, weight: FontWeight.w700, height: 1.2, color: AppColors.surface);

  /// Texto do botão principal da avaliação no tablet (quadros "6b" e "4g")
  static TextStyle get buttonTablet =>
      _inter(size: 17, weight: FontWeight.w700, height: 1.2, color: AppColors.ctaInk);

  /// Texto de botão compacto, dentro de uma linha de lista ("Atribuir a mim")
  static TextStyle get buttonCompact =>
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
      _inter(size: 13.5, weight: FontWeight.w400, height: 1.5, color: AppColors.text2);

  /// Código da categoria no chip do acordeão ("CV")
  static TextStyle get categoryCode =>
```

por:

```dart
      _inter(size: 13.5, weight: FontWeight.w400, height: 1.5, color: AppColors.text2);

  /// "A avaliação ainda não começou." no tablet em paisagem (quadro "6b")
  static TextStyle get notStartedTitleExpanded =>
      _inter(size: 18, weight: FontWeight.w700, height: 1.3);

  /// O mesmo no tablet em retrato (quadro "6c")
  static TextStyle get notStartedTitleTablet =>
      _inter(size: 19, weight: FontWeight.w700, height: 1.3);

  /// A explicação no tablet em paisagem (quadro "6b")
  static TextStyle get notStartedBodyExpanded =>
      _inter(size: 14, weight: FontWeight.w400, height: 1.5, color: AppColors.text3);

  /// A explicação no tablet em retrato (quadro "6c")
  static TextStyle get notStartedBodyTablet =>
      _inter(size: 14.5, weight: FontWeight.w400, height: 1.5, color: AppColors.text3);

  /// Código da categoria no chip do acordeão ("CV")
  static TextStyle get categoryCode =>
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
  static TextStyle get categoryName =>
      _inter(size: 15, weight: FontWeight.w600, height: 1.25);

  /// "6 itens", na categoria fechada
```

por:

```dart
  static TextStyle get categoryName =>
      _inter(size: 15, weight: FontWeight.w600, height: 1.25);

  /// O mesmo no tablet (quadros "6b", "4f" e "4g")
  static TextStyle get categoryNameTablet =>
      _inter(size: 16, weight: FontWeight.w600, height: 1.25);

  /// "6 itens", na categoria fechada
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
  large,
}
```

por:

```dart
  large,

  /// 60dp, texto 17 — a ação principal da avaliação no tablet ("Iniciar
  /// avaliação", quadros "6b" e "6c").
  tabletLarge,
}
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
  bool get _large => size == AppCtaSize.large;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _large ? AppSpacing.controlHeight : AppSpacing.touchTarget,
```

por:

```dart
  /// Altura do [AppCtaSize.tabletLarge].
  static const double tabletLargeHeight = 60;

  double get _height => switch (size) {
        AppCtaSize.compact => AppSpacing.touchTarget,
        AppCtaSize.large => AppSpacing.controlHeight,
        AppCtaSize.tabletLarge => tabletLargeHeight,
      };

  TextStyle get _textStyle => switch (size) {
        AppCtaSize.compact => AppTypography.buttonCompact,
        AppCtaSize.large => AppTypography.button,
        AppCtaSize.tabletLarge => AppTypography.buttonTablet,
      };

  double get _iconSize => switch (size) {
        AppCtaSize.compact => 19,
        AppCtaSize.large => 22,
        AppCtaSize.tabletLarge => 24,
      };

  double get _trailingIconSize => size == AppCtaSize.compact ? 21 : 25;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
          textStyle: _large ? AppTypography.button : AppTypography.buttonCompact,
```

por:

```dart
          textStyle: _textStyle,
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
          Icon(icon, size: _large ? 22 : 19),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(trailingIcon, size: _large ? 25 : 21),
```

por:

```dart
          Icon(icon, size: _iconSize),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(trailingIcon, size: _trailingIconSize),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/checklist/checklist_screen_test.dart`
Esperado: `+38: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+980: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/checklist/checklist_screen.dart apps/mobile/simtc/lib/ui/core/theme/app_typography.dart apps/mobile/simtc/lib/ui/core/widgets/app_buttons.dart apps/mobile/simtc/test/ui/checklist/checklist_screen_test.dart
git commit -m "feat(mobile): iniciar avaliacao no tablet"
```

---

## Task 2: Checklist no tablet: o "Finalizar" no cabeçalho e B/PM/M ao lado da descrição

O checklist iniciado no tablet (quadros `4f` e `4q`, spec `4z`). O "Finalizar avaliação" sai do rodapé e vai para o cabeçalho: em paisagem, numa linha com o nome e a nota (até 360); em retrato, ao lado do nome, com a nota numa segunda faixa. Os botões B/PM/M ficam à direita da descrição, em 312 (paisagem) ou 264 (retrato), e as categorias ganham 24 de recuo. Numa janela mais estreita que 600 (tela dividida), o checklist volta ao do celular. O ajudante do teste de giro da 7A passa a achar o botão pela linha da infração (`infraction-<id>`), porque a nota já não fica na coluna da descrição.

**Files:**
- Modify: `lib/ui/checklist/checklist_screen.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/widgets/app_buttons.dart`
- Modify: `test/ui/checklist/checklist_screen_test.dart`
- Modify: `test/ui/sessions/sessions_split_view_test.dart`

**Interfaces:**
- Consumes: `context.isTablet`, `context.isExpandedLayout`, `AppBreakpoints.tabletShortestSide` (7A); `AppTypography.appBarTitleTablet`, `categoryNameTablet` (Task 1).
- Produces:
  - `AppCtaSize.header` (48, texto 15, ícone 21) e `AppCtaButton({…, bool fullWidth = true})` — sem ele, o botão tem a largura do rótulo e guarda essa largura enquanto gira
  - `AppTypography.buttonHeader`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
double fontSizeOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.fontSize!;
```

por:

```dart
/// O tamanho da fonte de um texto — o do próprio `Text` ou, num botão, o
/// que o botão passa adiante.
double fontSizeOf(WidgetTester tester, String text) {
  final finder = find.text(text);
  return tester.widget<Text>(finder).style?.fontSize ??
      DefaultTextStyle.of(tester.element(finder)).style.fontSize!;
}
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
      expect(find.text('salvo'), findsOneWidget);
    });
  });
}
```

por:

```dart
      expect(find.text('salvo'), findsOneWidget);
    });

    Finder finish() => find.widgetWithText(AppCtaButton, 'Finalizar avaliação');

    testWidgets(
        'em paisagem, "Finalizar avaliação" fica no cabeçalho, numa linha com '
        'o nome e a nota, e não há rodapé (quadro "4f")', (tester) async {
      await pumpTablet(tester, _landscape);

      final button = finish();
      expect(tester.getSize(button).height, 48);
      expect(tester.getCenter(button).dy, tester.getCenter(find.byTooltip('Voltar')).dy);
      expect(tester.getTopRight(find.byKey(const Key('checklist-menu'))).dx, 1280 - 24,
          reason: 'o ⋮ fica na ponta, a 24 da borda');
      expect(
        tester.getTopLeft(find.byKey(const Key('checklist-menu'))).dx -
            tester.getTopRight(button).dx,
        8,
      );
      expect(tester.getSize(find.byType(LinearProgressIndicator)).width, 360);
      final bar = tester.getRect(find.byType(LinearProgressIndicator));
      expect(bar.left, greaterThan(tester.getTopRight(find.text('Ana Paula Ribeiro')).dx));
      expect(bar.right, lessThan(tester.getTopLeft(button).dx));
      expect(tester.getBottomLeft(button).dy, lessThan(100),
          reason: 'nada de botão no rodapé');
      expect(fontSizeOf(tester, 'Finalizar avaliação'), 15);
    });

    testWidgets(
        'em retrato, o cabeçalho tem duas faixas: nome e "Finalizar" em cima, a '
        'nota embaixo, com 12 de recuo (quadro "4q")', (tester) async {
      await pumpTablet(tester, _portrait);

      final button = finish();
      final bar = tester.getRect(find.byType(LinearProgressIndicator));
      expect(bar.left, 8 + 12);
      expect(bar.right, 800 - 20 - 12);
      expect(bar.top, greaterThan(tester.getBottomLeft(button).dy));
      expect(tester.getCenter(button).dy, tester.getCenter(find.byTooltip('Voltar')).dy);
      expect(tester.getTopRight(find.byKey(const Key('checklist-menu'))).dx, 800 - 20);
    });

    testWidgets(
        'a linha de infração no tablet: B/PM/M à direita da descrição, em 312 '
        'de largura em paisagem e 264 em retrato (quadros "4f" e "4q")', (tester) async {
      await pumpTablet(tester, _landscape);

      Rect notes() => tester.getRect(find.ancestor(
            of: find.text('PM'),
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && (w.width == 312 || w.width == 264),
            ),
          ));

      expect(notes().width, 312);
      expect(notes().right, 1280 - 24);
      expect(tester.getSize(find.text('B')).height, lessThan(56));
      expect(
        tester.getSize(find.ancestor(of: find.text('B'), matching: find.byType(InkWell)).first).height,
        56,
      );
      expect(tester.getTopLeft(find.text('Excesso de velocidade')).dx, 24 + 18 + 24);
      expect(tester.getTopLeft(find.text('Excesso de velocidade')).dy, notes().top,
          reason: 'a descrição e os botões começam na mesma altura');
      expect(tester.getTopLeft(find.text('CV')).dx, 24 + 7);
      expect(fontSizeOf(tester, 'Controle do Veículo'), 16);

      tester.view.physicalSize = _portrait;
      await tester.pumpAndSettle();

      expect(notes().width, 264);
      expect(notes().right, 800 - 24);
      expect(tester.getTopLeft(find.text('Excesso de velocidade')).dx, 24 + 18 + 16);
    });

    testWidgets(
        'a observação da nota fica embaixo da descrição, com no máximo 620 em '
        'paisagem', (tester) async {
      await pumpTablet(tester, _landscape);

      await tester.tap(find.text('PM'));
      await tester.pumpAndSettle();

      final comment = find.ancestor(of: find.text(pmComment), matching: find.byType(Container)).first;
      expect(tester.getSize(comment).width, 620);
      expect(tester.getTopLeft(comment).dy,
          greaterThan(tester.getBottomLeft(find.text('Excesso de velocidade')).dy));
    });

    testWidgets(
        'participante que saiu das mãos do consultor: o aviso vai para o topo '
        'da lista e o "Finalizar" do cabeçalho fica desabilitado', (tester) async {
      await assignToMe();
      await pumpTablet(tester, _landscape);
      await (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
          .write(const ParticipantsCompanion(status: Value('PENDENTE')));
      await tester.pumpAndSettle();

      const released =
          'Este participante não está mais com você. Atribua de novo para continuar.';
      expect(find.text(released), findsOneWidget);
      expect(tester.getTopLeft(find.text(released)).dy,
          lessThan(tester.getTopLeft(find.text('Controle do Veículo')).dy));
      expect(tester.widget<AppCtaButton>(finish()).onPressed, isNull);
    });

    testWidgets(
        'numa janela estreita (tela dividida), o checklist volta ao do '
        'celular: botões embaixo da descrição e "Finalizar" no rodapé', (tester) async {
      await pumpTablet(tester, const Size(500, 800));

      expect(
        tester.getTopLeft(find.text('PM')).dy,
        greaterThan(tester.getBottomLeft(find.text('Excesso de velocidade')).dy),
      );
      expect(tester.getBottomLeft(finish()).dy, 800 - 16);
      expect(tester.getSize(finish()).width, 500 - 2 * 16);
    });

    testWidgets(
        '"Finalizar avaliação" do cabeçalho abre a conferência', (tester) async {
      tester.view.physicalSize = _landscape;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await startEvaluation();
      final router = GoRouter(
        initialLocation: AppRoutes.participantChecklist('sess-1', 'tp-1'),
        routes: [
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
      await tester.pumpWidget(withProviders(FormFactorScope(
        formFactor: FormFactor.tablet,
        child: MaterialApp.router(routerConfig: router),
      )));
      await tester.pumpAndSettle();

      await tester.tap(finish());
      await tester.pumpAndSettle();

      expect(find.text('Conferir e finalizar'), findsOneWidget);
    });
  });
}
```

Em `test/ui/sessions/sessions_split_view_test.dart`, substituir:

```dart
    Finder note(String infraction, String note) => find.descendant(
          of: find.ancestor(
            of: find.text(infraction),
            matching: find.byType(Column),
          ).first,
```

por:

```dart
    // A linha inteira da infração (`infraction-<id>`): no tablet, os botões
    // B/PM/M ficam ao lado da descrição, fora da coluna dela.
    Finder note(String infraction, String note) => find.descendant(
          of: find.ancestor(
            of: find.text(infraction),
            matching: find.byWidgetPredicate((w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('infraction-')),
          ),
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/checklist/checklist_screen_test.dart test/ui/sessions/sessions_split_view_test.dart`
Esperado: `+48 -5: Some tests failed.` — no tablet, o "Finalizar" ainda está no rodapé e os botões B/PM/M embaixo da descrição. Os que passam são o da janela estreita (que é o celular) e o do "Finalizar" que abre a conferência.

- [ ] **Step 3: Implementar**

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
  /// Um desatribuir (que espera o backend) ou um descarte no ar: o menu ⋮ e o
  /// "Finalizar avaliação" ficam desabilitados até terminar — outra rota
  /// aberta por cima faria o fechamento do desatribuir fechar a tela errada.
  bool get _isBusy => _viewModel.isUnassigning || _viewModel.isDiscarding;
```

por:

```dart
  /// Largura máxima da nota no cabeçalho do tablet em paisagem (quadro "4f").
  static const double headerProgressMaxWidth = 360;

  /// Largura máxima do nome no cabeçalho do tablet em paisagem: a nota fica
  /// com o resto.
  static const double headerNameMaxWidth = 320;

  /// Largura dos três botões B/PM/M ao lado da descrição, no tablet em
  /// paisagem (quadro "4f") e em retrato (quadro "4q").
  static const double notesWidthExpanded = 312;
  static const double notesWidthTablet = 264;

  /// Largura do número do item, no tablet.
  static const double numberWidthTablet = 18;

  /// Largura máxima da observação da nota, no tablet em paisagem.
  static const double commentMaxWidthExpanded = 620;

  /// Um desatribuir (que espera o backend) ou um descarte no ar: o menu ⋮ e o
  /// "Finalizar avaliação" ficam desabilitados até terminar — outra rota
  /// aberta por cima faria o fechamento do desatribuir fechar a tela errada.
  bool get _isBusy => _viewModel.isUnassigning || _viewModel.isDiscarding;

  /// O checklist largo do tablet (quadros "4f" e "4q"): o "Finalizar
  /// avaliação" no cabeçalho e os botões B/PM/M ao lado da descrição. Numa
  /// janela mais estreita que 600 (tela dividida), o botão volta ao rodapé e
  /// os botões B/PM/M voltam para baixo da descrição, como no celular.
  bool get _wideLayout =>
      context.isTablet &&
      MediaQuery.sizeOf(context).width >= AppBreakpoints.tabletShortestSide;

  bool get _finishInHeader =>
      _wideLayout && _showsProgress && !_viewModel.isConfirmed;
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
  /// à direita em paisagem e 20 em retrato; o nome tem 18.
  Widget _buildHeader(BuildContext context, bool isOffline) {
    final tablet = context.isTablet;
    final double right = !tablet
        ? AppSpacing.sm
        : context.isExpandedLayout
            ? AppSpacing.xxl
            : AppSpacing.xl;
```

por:

```dart
  /// à direita em paisagem e 20 em retrato; o nome tem 18. Com a avaliação
  /// iniciada, o "Finalizar avaliação" entra no cabeçalho: em paisagem, numa
  /// linha com o nome e a nota (quadro "4f"); em retrato, ao lado do nome, com
  /// a nota numa segunda faixa (quadro "4q").
  Widget _buildHeader(BuildContext context, bool isOffline) {
    final tablet = context.isTablet;
    final expanded = context.isExpandedLayout;
    final double right = !tablet
        ? AppSpacing.sm
        : expanded
            ? AppSpacing.xxl
            : AppSpacing.xl;
    final showsProgress = _showsProgress;

    if (expanded && _finishInHeader) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, right, AppSpacing.md),
        child: Row(
          children: [
            _buildBackButton(context),
            const SizedBox(width: AppSpacing.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: headerNameMaxWidth),
              child: _buildNameAndTimer(),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: headerProgressMaxWidth),
                  child: _buildProgress(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            _buildHeaderFinish(),
            if (!_viewModel.isLoading &&
                (_viewModel.canDiscard || _viewModel.canUnassign)) ...[
              const SizedBox(width: AppSpacing.sm),
              _buildMenu(isOffline),
            ],
          ],
        ),
      );
    }
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
              SizedBox.square(
                dimension: AppSpacing.touchTarget,
                child: IconButton(
                  tooltip: 'Voltar',
                  icon: const Icon(AppIcons.back, size: 30, color: AppColors.text),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              SizedBox(width: tablet ? AppSpacing.md : AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _viewModel.participant?.name ?? '',
                      style: tablet
                          ? AppTypography.appBarTitleTablet
                          : AppTypography.checklistParticipantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs - 1),
                    _buildTimerRow(),
                  ],
                ),
              ),
              if (!_viewModel.isLoading &&
                  (_viewModel.canDiscard || _viewModel.canUnassign))
                _buildMenu(isOffline),
            ],
          ),
          if (!_viewModel.isLoading && _viewModel.hasCatalog && _viewModel.isStarted)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm + 2,
                AppSpacing.sm,
                0,
              ),
              child: _buildProgress(),
            ),
        ],
      ),
```

por:

```dart
              _buildBackButton(context),
              SizedBox(width: tablet ? AppSpacing.md : AppSpacing.xs),
              Expanded(child: _buildNameAndTimer()),
              if (_finishInHeader) ...[
                const SizedBox(width: AppSpacing.md),
                _buildHeaderFinish(),
              ],
              if (!_viewModel.isLoading &&
                  (_viewModel.canDiscard || _viewModel.canUnassign)) ...[
                if (_finishInHeader) const SizedBox(width: AppSpacing.sm),
                _buildMenu(isOffline),
              ],
            ],
          ),
          if (showsProgress)
            Padding(
              padding: tablet
                  ? const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0)
                  : const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm + 2,
                      AppSpacing.sm,
                      0,
                    ),
              child: _buildProgress(),
            ),
        ],
      ),
    );
  }

  bool get _showsProgress =>
      !_viewModel.isLoading && _viewModel.hasCatalog && _viewModel.isStarted;

  Widget _buildBackButton(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.touchTarget,
      child: IconButton(
        tooltip: 'Voltar',
        icon: const Icon(AppIcons.back, size: 30, color: AppColors.text),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Widget _buildNameAndTimer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _viewModel.participant?.name ?? '',
          style: context.isTablet
              ? AppTypography.appBarTitleTablet
              : AppTypography.checklistParticipantName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs - 1),
        _buildTimerRow(),
      ],
    );
  }

  /// O "Finalizar avaliação" do cabeçalho do tablet: as mesmas regras do
  /// botão do rodapé do celular.
  Widget _buildHeaderFinish() {
    return AppCtaButton(
      label: 'Finalizar avaliação',
      icon: AppIcons.finish,
      size: AppCtaSize.header,
      fullWidth: false,
      onPressed: _isBusy || _viewModel.isReleased ? null : _openSummary,
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md),
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
          if (i > 0) const SizedBox(height: AppSpacing.sm + 2),
          blocks[i],
        ],
      ],
    );
  }
```

por:

```dart
    // No tablet (quadros "4f" e "4q"), os blocos começam no topo e ficam
    // colados, e os avisos vão para o topo da lista, com o recuo de 24.
    final tablet = context.isTablet;
    final double inset = tablet ? AppSpacing.xxl : AppSpacing.xl;

    return ListView(
      padding: EdgeInsets.only(top: tablet ? 0 : AppSpacing.md),
      children: [
        // Só leitura (decisão de 01/10/2026): a avaliação confirmada espera o
        // envio, e o que foi confirmado não muda mais.
        if (_viewModel.isConfirmed)
          Padding(
            padding: tablet
                ? EdgeInsets.fromLTRB(inset, AppSpacing.md, inset, AppSpacing.md)
                : EdgeInsets.fromLTRB(inset, 0, inset, AppSpacing.md),
            child: const InlineNotice(
              icon: AppIcons.finish,
              message: 'Avaliação confirmada — não pode mais ser alterada.',
            ),
          ),
        // No celular, o aviso fica no rodapé, acima do botão.
        if (_wideLayout && _viewModel.isReleased)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, AppSpacing.md, inset, AppSpacing.md),
            child: _buildReleasedNotice(),
          ),
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0 && !tablet) const SizedBox(height: AppSpacing.sm + 2),
          blocks[i],
        ],
      ],
    );
  }

  /// O participante saiu das mãos do consultor com o checklist aberto: o
  /// servidor recusaria o envio (decisão de 09/10/2026). As marcações ficam.
  Widget _buildReleasedNotice() {
    return const InlineNotice(
      icon: AppIcons.lockedByOther,
      tone: NoticeTone.warning,
      message: 'Este participante não está mais com você. '
          'Atribua de novo para continuar.',
    );
  }

  /// Recuo das linhas e cabeçalhos de categoria: 20 no celular, 24 no tablet.
  EdgeInsets get _categoryPadding => context.isTablet
      ? const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xl)
      : const EdgeInsets.all(AppSpacing.xl);

  /// Vão entre as partes da linha de categoria: 10 no celular, 12 no tablet.
  double get _categoryGap => context.isTablet ? AppSpacing.md : AppSpacing.sm + 2;

  TextStyle get _categoryNameStyle =>
      context.isTablet ? AppTypography.categoryNameTablet : AppTypography.categoryName;
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
    return InkWell(
      key: ValueKey('category-${category.id}'),
      onTap: () => _openCategory(category.id),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
        ),
        child: Row(
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
            Text(_itemsLabel(category.infractions.length), style: AppTypography.categoryCount),
            const SizedBox(width: AppSpacing.sm + 2),
```

por:

```dart
    final gap = _categoryGap;

    return InkWell(
      key: ValueKey('category-${category.id}'),
      onTap: () => _openCategory(category.id),
      child: Container(
        padding: _categoryPadding,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
        ),
        child: Row(
          children: [
            CategoryCodeChip(code: category.code),
            SizedBox(width: gap),
            Expanded(
              child: Text(
                category.name,
                style: _categoryNameStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: gap),
            Text(_itemsLabel(category.infractions.length), style: AppTypography.categoryCount),
            SizedBox(width: gap),
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
    return InkWell(
      key: _openHeaderKey,
      onTap: () => _viewModel.toggleCategory(category.id),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
```

por:

```dart
    final gap = _categoryGap;

    return InkWell(
      key: _openHeaderKey,
      onTap: () => _viewModel.toggleCategory(category.id),
      child: Container(
        padding: _categoryPadding,
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
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
            ScoreBadge(score: category.score),
            const SizedBox(width: AppSpacing.sm + 2),
```

por:

```dart
            SizedBox(width: gap),
            Expanded(
              child: Text(
                category.name,
                style: _categoryNameStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: gap),
            ScoreBadge(score: category.score),
            SizedBox(width: gap),
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
  Widget _buildInfractionRow(ChecklistInfraction infraction) {
    final comment = infraction.selectedComment;
```

por:

```dart
  Widget _buildInfractionRow(ChecklistInfraction infraction) {
    if (_wideLayout) return _buildWideInfractionRow(infraction);

    final comment = infraction.selectedComment;
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
          Row(
            children: [
              for (var i = 0; i < infraction.notes.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm - 2),
                Expanded(
                  child: _NoteButton(
                    note: infraction.notes[i],
                    selected: infraction.selectedNoteId == infraction.notes[i].id,
                    onTap: _viewModel.isConfirmed
                        ? null
                        : () => _viewModel.toggleNote(infraction.id, infraction.notes[i].id),
                  ),
                ),
              ],
            ],
          ),
```

por:

```dart
          _buildNoteButtons(infraction),
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
  /// (quadro "6c").
  Widget? _buildFooter() {
```

por:

```dart
  /// (quadro "6c").
  /// A linha de infração no tablet (quadros "4f" e "4q", spec "4z"): o
  /// número, a descrição (com a observação embaixo) e os botões B/PM/M à
  /// direita, em 312 de largura em paisagem e 264 em retrato.
  Widget _buildWideInfractionRow(ChecklistInfraction infraction) {
    final comment = infraction.selectedComment;
    final expanded = context.isExpandedLayout;
    final double gap = expanded ? AppSpacing.xxl : AppSpacing.lg;

    return Container(
      key: ValueKey('infraction-${infraction.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.md + 3,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: numberWidthTablet,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text('${infraction.order}', style: AppTypography.infractionNumber),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(infraction.description, style: AppTypography.infractionDescription),
                if (comment != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: expanded ? commentMaxWidthExpanded : double.infinity,
                    ),
                    child: _NoteComment(comment),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: gap),
          SizedBox(
            width: expanded ? notesWidthExpanded : notesWidthTablet,
            child: _buildNoteButtons(infraction),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteButtons(ChecklistInfraction infraction) {
    return Row(
      children: [
        for (var i = 0; i < infraction.notes.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm - 2),
          Expanded(
            child: _NoteButton(
              note: infraction.notes[i],
              selected: infraction.selectedNoteId == infraction.notes[i].id,
              onTap: _viewModel.isConfirmed
                  ? null
                  : () => _viewModel.toggleNote(infraction.id, infraction.notes[i].id),
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildFooter() {
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
    if (!_viewModel.isStarted && context.isExpandedLayout) return null;
    final tabletStart = tablet && !_viewModel.isStarted;
```

por:

```dart
    if (!_viewModel.isStarted && context.isExpandedLayout) return null;
    // No tablet, o "Finalizar avaliação" fica no cabeçalho.
    if (_viewModel.isStarted && _wideLayout) return null;
    final tabletStart = tablet && !_viewModel.isStarted;
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
                  const InlineNotice(
                    icon: AppIcons.lockedByOther,
                    tone: NoticeTone.warning,
                    message: 'Este participante não está mais com você. '
                        'Atribua de novo para continuar.',
                  ),
```

por:

```dart
                  _buildReleasedNotice(),
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
      _inter(size: 17, weight: FontWeight.w700, height: 1.2, color: AppColors.ctaInk);

  /// Texto de botão compacto, dentro de uma linha de lista ("Atribuir a mim")
  static TextStyle get buttonCompact =>
```

por:

```dart
      _inter(size: 17, weight: FontWeight.w700, height: 1.2, color: AppColors.ctaInk);

  /// Texto do "Finalizar avaliação" no cabeçalho do checklist no tablet
  /// (quadros "4f" e "4q")
  static TextStyle get buttonHeader =>
      _inter(size: 15, weight: FontWeight.w700, height: 1.2, color: AppColors.ctaInk);

  /// Texto de botão compacto, dentro de uma linha de lista ("Atribuir a mim")
  static TextStyle get buttonCompact =>
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
  tabletLarge,
}
```

por:

```dart
  tabletLarge,

  /// 48dp, texto 15 — a ação no cabeçalho do checklist no tablet
  /// ("Finalizar avaliação", quadros "4f" e "4q").
  header,
}
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
    this.trailingIcon,
    this.size = AppCtaSize.compact,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  /// Ícone depois do rótulo — o "›" do "Próximo participante" (canvas "2g").
```

por:

```dart
    this.trailingIcon,
    this.size = AppCtaSize.compact,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  /// Sem ele, o botão tem a largura do rótulo — o "Finalizar avaliação" do
  /// cabeçalho do tablet, numa linha com o nome e a nota.
  final bool fullWidth;

  /// Ícone depois do rótulo — o "›" do "Próximo participante" (canvas "2g").
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
        AppCtaSize.compact => AppSpacing.touchTarget,
```

por:

```dart
        AppCtaSize.compact || AppCtaSize.header => AppSpacing.touchTarget,
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
      };

  double get _iconSize => switch (size) {
        AppCtaSize.compact => 19,
        AppCtaSize.large => 22,
        AppCtaSize.tabletLarge => 24,
      };

  double get _trailingIconSize => size == AppCtaSize.compact ? 21 : 25;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: double.infinity,
```

por:

```dart
        AppCtaSize.header => AppTypography.buttonHeader,
      };

  double get _iconSize => switch (size) {
        AppCtaSize.compact => 19,
        AppCtaSize.header => 21,
        AppCtaSize.large => 22,
        AppCtaSize.tabletLarge => 24,
      };

  double get _trailingIconSize =>
      size == AppCtaSize.compact || size == AppCtaSize.header ? 21 : 25;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: fullWidth ? double.infinity : null,
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
```

por:

```dart
          padding: EdgeInsets.symmetric(
            horizontal: size == AppCtaSize.header ? AppSpacing.xl : AppSpacing.lg,
          ),
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: _iconSize),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
```

por:

```dart
    final text = Text(label, overflow: TextOverflow.ellipsis);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: _iconSize),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (fullWidth) Flexible(child: text) else text,
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/checklist/checklist_screen_test.dart test/ui/sessions/sessions_split_view_test.dart`
Esperado: `+53: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+987: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/checklist/checklist_screen.dart apps/mobile/simtc/lib/ui/core/theme/app_typography.dart apps/mobile/simtc/lib/ui/core/widgets/app_buttons.dart apps/mobile/simtc/test/ui/checklist/checklist_screen_test.dart apps/mobile/simtc/test/ui/sessions/sessions_split_view_test.dart
git commit -m "feat(mobile): checklist no tablet com o finalizar no cabecalho"
```

---

## Task 3: Conferir e finalizar no tablet

A 1.6 no tablet: em paisagem, uma coluna de até 940, centrada, com o "Confirmar" de 420×60 no fim, à esquerda (quadro `4g`); em retrato, recuo de 32 e o "Confirmar" no rodapé (quadro `4r`). A nota tem 48 e a pílula "Aprovado" é a maior do quadro; a linha de categoria tem 76 de altura mínima, com o nome e as infrações lado a lado em paisagem e um embaixo do outro em retrato. A barra de topo passa a 18 em todo o tablet.

**Files:**
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/widgets/app_top_bar.dart`
- Modify: `lib/ui/core/widgets/final_score_block.dart`
- Modify: `lib/ui/summary/summary_screen.dart`
- Modify: `test/ui/summary/summary_screen_test.dart`

**Interfaces:**
- Consumes: `context.isTablet`, `context.isExpandedLayout` (7A); `AppCtaSize.tabletLarge`, `AppTypography.appBarTitleTablet`, `categoryNameTablet` (Task 1).
- Produces:
  - `enum FinalScoreScale { phone, summaryTablet }` e `FinalScoreBlock({…, FinalScoreScale scale = FinalScoreScale.phone, EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.xl)})`
  - `AppTypography.summaryScoreTablet` (48), `summaryScoreLabelTablet`, `resultPillTablet`, `summaryDetailTablet`, `summarySectionTitleTablet`, `summaryCountTablet`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/summary/summary_screen_test.dart`, substituir:

```dart
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/summary/summary_screen.dart';
```

por:

```dart
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/summary/summary_screen.dart';
```

Em `test/ui/summary/summary_screen_test.dart`, substituir:

```dart
  Future<void> pumpSummary(
    WidgetTester tester, {
    AssessmentRepository? assessments,
  }) async {
```

por:

```dart
  ///
  /// Com [tablet], num tablet desse tamanho.
  Future<void> pumpSummary(
    WidgetTester tester, {
    AssessmentRepository? assessments,
    Size? tablet,
  }) async {
    if (tablet != null) {
      tester.view.physicalSize = tablet;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
```

Em `test/ui/summary/summary_screen_test.dart`, substituir:

```dart
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
```

por:

```dart
        child: FormFactorScope(
          formFactor: tablet == null ? FormFactor.phone : FormFactor.tablet,
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
```

Em `test/ui/summary/summary_screen_test.dart`, substituir:

```dart
  });
}
```

por:

```dart
  });

  group('no tablet', () {
    double fontSizeOf(WidgetTester tester, String text) {
      final finder = find.text(text);
      return tester.widget<Text>(finder).style?.fontSize ??
          DefaultTextStyle.of(tester.element(finder)).style.fontSize!;
    }

    Finder confirm() => find.widgetWithText(AppCtaButton, 'Confirmar');

    testWidgets(
        'em paisagem: uma coluna de 940 centrada, com o "Confirmar" de 420×60 '
        'no fim dela, à esquerda, e sem rodapé (quadro "4g")', (tester) async {
      await draftWith({'inf-1': 'inf-1-PM'});
      await pumpSummary(tester, tablet: const Size(1280, 800));

      final column = tester.getRect(find.byKey(const Key('summary-column')));
      expect(column.width, 940);
      expect(column.center.dx, 640);
      expect(tester.getSize(confirm()), const Size(420, 60));
      expect(tester.getTopLeft(confirm()).dx, column.left);
      expect(
        tester.getTopLeft(confirm()).dy,
        greaterThan(tester.getBottomLeft(find.text('Respeito às Regras')).dy),
      );
      expect(tester.getTopLeft(find.text('Pontuação final')).dx, column.left);
      expect(fontSizeOf(tester, '85,0%'), 48);
      expect(fontSizeOf(tester, 'Pontuação final'), 13.5);
      expect(fontSizeOf(tester, 'Aprovado'), 14);
      expect(fontSizeOf(tester, 'Conferir e finalizar'), 18);
      expect(fontSizeOf(tester, 'Controle do Veículo'), 16);
      expect(fontSizeOf(tester, 'Confirmar'), 17);
      // Paisagem: o nome e as infrações lado a lado.
      expect(tester.getCenter(find.text('1 infração')).dy,
          tester.getCenter(find.text('Controle do Veículo')).dy);
      final row = find.byKey(const ValueKey('summary-category-cat-1'));
      expect(tester.getSize(row).height, greaterThanOrEqualTo(76));
    });

    testWidgets(
        'em retrato: recuo de 32, o nome e as infrações um embaixo do outro e o '
        '"Confirmar" no rodapé, na largura toda (quadro "4r")', (tester) async {
      await draftWith({'inf-1': 'inf-1-PM'});
      await pumpSummary(tester, tablet: const Size(800, 1280));

      expect(find.byKey(const Key('summary-column')), findsNothing);
      expect(tester.getTopLeft(find.text('Pontuação final')).dx, 32);
      expect(tester.getSize(confirm()), const Size(800 - 2 * 32, 60));
      expect(tester.getBottomLeft(confirm()).dy, 1280 - 16);
      expect(tester.getTopLeft(find.text('1 infração')).dy,
          greaterThan(tester.getBottomLeft(find.text('Controle do Veículo')).dy));
      expect(tester.getTopRight(find.byKey(const ValueKey('summary-category-cat-1'))).dx,
          800 - 32);
    });

    testWidgets('em paisagem, "Confirmar" do fim da coluna confirma e fecha',
        (tester) async {
      await draftWith({'inf-1': 'inf-1-PM'});
      await pumpSummary(tester, tablet: const Size(1280, 800));

      await tester.tap(confirm());
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(exit, isA<SummaryConfirmed>());
    });

    testWidgets('em paisagem, o erro de confirmar aparece acima do botão',
        (tester) async {
      await draftWith({'inf-1': 'inf-1-PM'});
      await pumpSummary(
        tester,
        assessments: _FailingConfirmRepository(database: db),
        tablet: const Size(1280, 800),
      );

      await tester.tap(confirm());
      await tester.pumpAndSettle();

      const error = 'Não foi possível confirmar a avaliação. Tente de novo.';
      expect(tester.getBottomLeft(find.text(error)).dy,
          lessThan(tester.getTopLeft(confirm()).dy));
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/summary/summary_screen_test.dart`
Esperado: `+8 -2: Some tests failed.` — os dois de medida (coluna de 940 em paisagem; recuo de 32 e rodapé em retrato). O "Confirmar" e o erro já funcionavam.

- [ ] **Step 3: Implementar**

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
  static TextStyle get summarySectionTitle =>
      _inter(size: 13, weight: FontWeight.w600, height: 1.2, color: AppColors.text3);

  // ─── Resultado (quadro "2g" do canvas) ────────────────────────────────────

  /// Nota da infração ("PM") no selo de cor cheia das infrações registradas
```

por:

```dart
  static TextStyle get summarySectionTitle =>
      _inter(size: 13, weight: FontWeight.w600, height: 1.2, color: AppColors.text3);

  // ─── Conferir e finalizar no tablet (quadros "4g" e "4r") ─────────────────

  /// "Pontuação final"
  static TextStyle get summaryScoreLabelTablet =>
      _inter(size: 13.5, weight: FontWeight.w500, height: 1.2, color: AppColors.text3);

  /// O % geral
  static TextStyle get summaryScoreTablet =>
      _inter(size: 48, weight: FontWeight.w800, height: 1, letterSpacing: -0.96);

  /// A pílula "Aprovado"
  static TextStyle get resultPillTablet =>
      _inter(size: 14, weight: FontWeight.w600, height: 1.2);

  /// A linha de detalhe embaixo do %
  static TextStyle get summaryDetailTablet =>
      _inter(size: 14, weight: FontWeight.w400, height: 1.45, color: AppColors.text3);

  /// "Por categoria"
  static TextStyle get summarySectionTitleTablet =>
      _inter(size: 13.5, weight: FontWeight.w600, height: 1.2, color: AppColors.text3);

  /// "1 infração", ao lado (ou embaixo) do nome da categoria
  static TextStyle get summaryCountTablet =>
      _inter(size: 13, weight: FontWeight.w400, height: 1.2, color: AppColors.text3);

  // ─── Resultado (quadro "2g" do canvas) ────────────────────────────────────

  /// Nota da infração ("PM") no selo de cor cheia das infrações registradas
```

Em `lib/ui/core/widgets/app_top_bar.dart`, substituir:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
```

por:

```dart
import 'package:flutter/material.dart';

import '../form_factor.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
```

Em `lib/ui/core/widgets/app_top_bar.dart`, substituir:

```dart
              style: AppTypography.appBarTitle,
```

por:

```dart
              // 18 no tablet (quadros "4e", "4g" e "4i").
              style: context.isTablet
                  ? AppTypography.appBarTitleTablet
                  : AppTypography.appBarTitle,
```

Em `lib/ui/core/widgets/final_score_block.dart`, substituir:

```dart
  });
```

por:

```dart
    this.scale = FinalScoreScale.phone,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  /// Os tamanhos do bloco: o do celular ou o da conferência no tablet.
  final FinalScoreScale scale;
  final EdgeInsetsGeometry padding;
```

Em `lib/ui/core/widgets/final_score_block.dart`, substituir:

```dart
    final lines = details.where((line) => line.isNotEmpty).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
```

por:

```dart
    final lines = details.where((line) => line.isNotEmpty).toList(growable: false);
    final tablet = scale == FinalScoreScale.summaryTablet;

    return Container(
      padding: padding,
      decoration: const BoxDecoration(
```

Em `lib/ui/core/widgets/final_score_block.dart`, substituir:

```dart
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
```

por:

```dart
                    Text(
                      'Pontuação final',
                      style: tablet
                          ? AppTypography.summaryScoreLabelTablet
                          : AppTypography.summaryScoreLabel,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      score == null ? '—' : percentLabel(score),
                      style: tablet
                          ? AppTypography.summaryScoreTablet
                          : AppTypography.summaryScore,
                    ),
                  ],
                ),
              ),
              if (approved != null) ...[
                const SizedBox(width: AppSpacing.md),
                _ResultPill(approved: approved, large: tablet),
              ],
            ],
          ),
          for (var i = 0; i < lines.length; i++) ...[
            SizedBox(height: i == 0 ? AppSpacing.md + 2 : AppSpacing.xs),
            Text(
              lines[i],
              style: tablet ? AppTypography.summaryDetailTablet : AppTypography.summaryDetail,
            ),
```

Em `lib/ui/core/widgets/final_score_block.dart`, substituir:

```dart
/// "Aprovado" ou "Não recomendado", ao lado do % — o corte de 70% do
/// backend. As cores são as dos chips de status do detalhe da sessão.
class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.approved});

  final bool approved;
```

por:

```dart
/// Os tamanhos do [FinalScoreBlock].
enum FinalScoreScale {
  /// Celular (quadros "2e" e "2g").
  phone,

  /// Conferir e finalizar no tablet (quadros "4g" e "4r"): % de 48.
  summaryTablet,
}

/// "Aprovado" ou "Não recomendado", ao lado do % — o corte de 70% do
/// backend. As cores são as dos chips de status do detalhe da sessão.
class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.approved, this.large = false});

  final bool approved;

  /// A pílula da conferência no tablet (quadro "4g"): 8/15/8/12 de recuo,
  /// ícone de 18 e texto de 14.
  final bool large;
```

Em `lib/ui/core/widgets/final_score_block.dart`, substituir:

```dart
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm + 2,
        AppSpacing.xs + 2,
        AppSpacing.md,
        AppSpacing.xs + 2,
      ),
```

por:

```dart
      padding: large
          ? const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md + 3,
              AppSpacing.sm,
            )
          : const EdgeInsets.fromLTRB(
              AppSpacing.sm + 2,
              AppSpacing.xs + 2,
              AppSpacing.md,
              AppSpacing.xs + 2,
            ),
```

Em `lib/ui/core/widgets/final_score_block.dart`, substituir:

```dart
          Icon(icon, size: 16, color: ink),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(label, style: AppTypography.resultPill.copyWith(color: ink)),
```

por:

```dart
          Icon(icon, size: large ? 18 : 16, color: ink),
          SizedBox(width: large ? AppSpacing.xs + 2 : AppSpacing.xs + 1),
          Text(
            label,
            style: (large ? AppTypography.resultPillTablet : AppTypography.resultPill)
                .copyWith(color: ink),
          ),
```

Em `lib/ui/summary/summary_screen.dart`, substituir:

```dart
import '../checklist/checklist_sections.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../checklist/checklist_sections.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/summary/summary_screen.dart`, substituir:

```dart
class _SummaryScreenState extends State<SummaryScreen> {
  late final SummaryViewModel _viewModel = SummaryViewModel(
```

por:

```dart
class _SummaryScreenState extends State<SummaryScreen> {
  /// A coluna da conferência no tablet em paisagem (quadro "4g").
  static const double expandedMaxWidth = 940;

  /// Largura do "Confirmar" no fim dessa coluna.
  static const double expandedCtaWidth = 420;

  /// Altura mínima da linha de categoria no tablet.
  static const double categoryMinHeightTablet = 76;

  late final SummaryViewModel _viewModel = SummaryViewModel(
```

Em `lib/ui/summary/summary_screen.dart`, substituir:

```dart
  Widget _buildScaffold() {
    final ready = !_viewModel.isLoading && _viewModel.sections.isNotEmpty;
```

por:

```dart
  bool get _ready => !_viewModel.isLoading && _viewModel.sections.isNotEmpty;

  Widget _buildScaffold() {
    // No tablet em paisagem, o "Confirmar" fica no fim da coluna (quadro
    // "4g"), e não há rodapé.
    final footer = _ready && !context.isExpandedLayout;
```

Em `lib/ui/summary/summary_screen.dart`, substituir:

```dart
            Expanded(child: _buildBody()),
            if (ready) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
```

por:

```dart
            Expanded(child: _buildBody()),
            if (footer) _buildFooter(),
          ],
        ),
      ),
    );
  }

  /// No tablet, a conferência é uma coluna: de até 940, centrada, em
  /// paisagem (quadro "4g"); com 32 de recuo em retrato (quadro "4r").
  Widget _buildBody() {
```

Em `lib/ui/summary/summary_screen.dart`, substituir:

```dart
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
    return FinalScoreBlock(
      score: _viewModel.overallScore,
      approved: _viewModel.isApproved,
      details: [_detailLine(), if (_viewModel.timesLabel case final times?) times],
```

por:

```dart
    final tablet = context.isTablet;
    final expanded = context.isExpandedLayout;
    final double inset = tablet ? 0 : AppSpacing.xl;
    final children = [
      _buildScore(),
      Padding(
        padding: EdgeInsets.fromLTRB(inset, AppSpacing.md + 3, inset, AppSpacing.md + 3),
        child: Text(
          'Por categoria',
          style: tablet
              ? AppTypography.summarySectionTitleTablet
              : AppTypography.summarySectionTitle,
        ),
      ),
      DecoratedBox(
        decoration: tablet
            ? const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
              )
            : const BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final category in _viewModel.sections) _buildCategory(category),
          ],
        ),
      ),
    ];

    if (expanded) {
      return ListView(
        children: [
          Center(
            child: ConstrainedBox(
              key: const Key('summary-column'),
              constraints: const BoxConstraints(maxWidth: expandedMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...children,
                  if (_ready)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xxl + 4, 0, AppSpacing.xxxl),
                      child: _buildActions(ctaWidth: expandedCtaWidth),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: tablet ? AppSpacing.xxxl : 0),
      children: children,
    );
  }

  Widget _buildScore() {
    final tablet = context.isTablet;
    return FinalScoreBlock(
      score: _viewModel.overallScore,
      approved: _viewModel.isApproved,
      details: [_detailLine(), if (_viewModel.timesLabel case final times?) times],
      scale: tablet ? FinalScoreScale.summaryTablet : FinalScoreScale.phone,
      padding: tablet
          ? const EdgeInsets.symmetric(vertical: AppSpacing.xxl)
          : const EdgeInsets.all(AppSpacing.xl),
```

Em `lib/ui/summary/summary_screen.dart`, substituir:

```dart
  Widget _buildCategory(ChecklistCategory category) {
    return InkWell(
```

por:

```dart
  Widget _buildCategory(ChecklistCategory category) {
    if (context.isTablet) return _buildTabletCategory(category);

    return InkWell(
```

Em `lib/ui/summary/summary_screen.dart`, substituir:

```dart
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
```

por:

```dart
  /// A linha de categoria no tablet (quadros "4g" e "4r"): 76 de altura
  /// mínima, 20 em cima e embaixo, divisórias de 1,5; o nome e as infrações
  /// lado a lado em paisagem e um embaixo do outro em retrato.
  Widget _buildTabletCategory(ChecklistCategory category) {
    final name = Text(
      category.name,
      style: AppTypography.categoryNameTablet,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final count = Text(
      infractionCountLabel(category.markedCount),
      style: AppTypography.summaryCountTablet,
    );

    return InkWell(
      key: ValueKey('summary-category-${category.id}'),
      onTap: () => Navigator.of(context).pop(SummaryReviewCategory(category.id)),
      child: Container(
        constraints: const BoxConstraints(minHeight: categoryMinHeightTablet),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
        ),
        child: Row(
          children: [
            CategoryCodeChip(code: category.code),
            const SizedBox(width: AppSpacing.md + 2),
            Expanded(
              child: context.isExpandedLayout
                  ? Row(
                      children: [
                        Flexible(child: name),
                        const SizedBox(width: AppSpacing.md + 2),
                        count,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [name, const SizedBox(height: AppSpacing.xs), count],
                    ),
            ),
            const SizedBox(width: AppSpacing.md + 2),
            ScoreBadge(score: category.score),
            const SizedBox(width: AppSpacing.md + 2),
            const Icon(AppIcons.chevronRight, size: 22, color: AppColors.text3),
          ],
        ),
      ),
    );
  }

  /// O rodapé: no tablet em retrato, 16 em cima e embaixo e 32 dos lados
  /// (quadro "4r").
  Widget _buildFooter() {
    final tablet = context.isTablet;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: tablet
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl, vertical: AppSpacing.lg)
          : const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
      child: _buildActions(),
    );
  }

  /// O erro do "Confirmar" e o botão. Com [ctaWidth], o botão tem essa
  /// largura, alinhado à esquerda (quadro "4g").
  Widget _buildActions({double? ctaWidth}) {
    final error = _viewModel.errorMessage;
    final button = AppCtaButton(
      label: 'Confirmar',
      icon: AppIcons.check,
      size: context.isTablet ? AppCtaSize.tabletLarge : AppCtaSize.large,
      isLoading: _viewModel.isConfirming,
      onPressed: _viewModel.canConfirm ? _viewModel.confirm : null,
    );

    return Column(
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
        if (ctaWidth == null)
          button
        else
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: ctaWidth, child: button),
          ),
      ],
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/summary/summary_screen_test.dart`
Esperado: `+10: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+991: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/theme/app_typography.dart apps/mobile/simtc/lib/ui/core/widgets/app_top_bar.dart apps/mobile/simtc/lib/ui/core/widgets/final_score_block.dart apps/mobile/simtc/lib/ui/summary/summary_screen.dart apps/mobile/simtc/test/ui/summary/summary_screen_test.dart
git commit -m "feat(mobile): conferir e finalizar no tablet"
```

---

## Task 4: Resultado no tablet

A 1.8 no tablet: em paisagem, dois painéis — à esquerda, em 452, a nota (44), os avisos, o desempenho e o botão ("Próximo participante" ou "Reavaliar") no fim do painel; à direita, as infrações registradas (quadro `4i`). Em retrato, uma coluna só com 24 de recuo, uma linha antes das infrações e o botão no rodapé (quadro `4t`). Os cabeçalhos de grupo e as infrações ganham as medidas do quadro (selo de 34×26).

**Files:**
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/widgets/final_score_block.dart`
- Modify: `lib/ui/result/result_screen.dart`
- Modify: `test/ui/result/result_screen_test.dart`

**Interfaces:**
- Consumes: `context.isTablet`, `context.isExpandedLayout` (7A); `AppCtaSize.tabletLarge` (Task 1); `FinalScoreBlock(scale:, padding:)` (Task 3).
- Produces:
  - `FinalScoreScale.resultTablet`
  - `AppTypography.resultScoreTablet` (44), `resultDetailTablet`, `resultPerformanceNameTablet`, `resultGroupNameTablet`, `resultGroupCountTablet`, `resultInfractionTablet`, `resultNoteBadgeTablet`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/result/result_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

por:

```dart
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

Em `test/ui/result/result_screen_test.dart`, substituir:

```dart
  Future<void> pumpResult(WidgetTester tester, {bool justConfirmed = false}) async {
    tallScreen(tester);
```

por:

```dart
  ///
  /// Com [tablet], num tablet desse tamanho.
  Future<void> pumpResult(
    WidgetTester tester, {
    bool justConfirmed = false,
    Size? tablet,
  }) async {
    tallScreen(tester);
    if (tablet != null) tester.view.physicalSize = tablet;
```

Em `test/ui/result/result_screen_test.dart`, substituir:

```dart
    await tester.pumpWidget(withProviders(MaterialApp.router(routerConfig: router)));
```

por:

```dart
    await tester.pumpWidget(withProviders(FormFactorScope(
      formFactor: tablet == null ? FormFactor.phone : FormFactor.tablet,
      child: MaterialApp.router(routerConfig: router),
    )));
```

Em `test/ui/result/result_screen_test.dart`, substituir:

```dart
  });
}
```

por:

```dart
  });

  group('no tablet', () {
    double fontSizeOf(WidgetTester tester, String text) {
      final finder = find.text(text);
      return tester.widget<Text>(finder).style?.fontSize ??
          DefaultTextStyle.of(tester.element(finder)).style.fontSize!;
    }

    Finder next() => find.widgetWithText(AppCtaButton, 'Próximo participante');

    testWidgets(
        'em paisagem: a nota, o desempenho e o "Próximo participante" num '
        'painel de 452 à esquerda; as infrações à direita (quadro "4i")',
        (tester) async {
      await seedParticipant(status: 'EM_AVALIACAO');
      await confirmedHere({'inf-1': 'inf-1-PM'});

      await pumpResult(tester, justConfirmed: true, tablet: const Size(1280, 800));

      final pane = tester.getRect(find.byKey(const Key('result-summary-pane')));
      expect(pane.left, 0);
      expect(pane.width, 452);
      for (final text in ['Pontuação final', 'Desempenho por categoria']) {
        expect(
          find.descendant(of: find.byKey(const Key('result-summary-pane')), matching: find.text(text)),
          findsOneWidget,
        );
      }
      for (final text in ['Infrações registradas', 'Infração do item 1']) {
        expect(
          find.descendant(of: find.byKey(const Key('result-infractions-pane')), matching: find.text(text)),
          findsOneWidget,
        );
      }
      expect(tester.getTopLeft(find.byKey(const Key('result-infractions-pane'))).dx, 452 + 1);
      final button = tester.getRect(next());
      expect(button.left, 24);
      expect(button.right, 452 - 24);
      expect(button.height, 60);
      expect(button.bottom, 800 - 24, reason: 'o botão fica no fim do painel');
      expect(tester.getTopLeft(find.text('Pontuação final')).dx, 24);
      expect(fontSizeOf(tester, '85,0%'), 44);
      expect(fontSizeOf(tester, 'Avaliação concluída'), 18);
      expect(fontSizeOf(tester, 'Infração do item 1'), 15.5);
      expect(fontSizeOf(tester, 'Próximo participante'), 17);
      expect(tester.getSize(find.text('PM')).height, lessThanOrEqualTo(26));
      expect(
        tester.getSize(find.ancestor(of: find.text('PM'), matching: find.byType(Container)).first),
        const Size(34, 26),
      );
    });

    testWidgets(
        'em retrato: uma coluna com 24 de recuo, uma linha antes das infrações '
        'e o botão no rodapé, na largura toda (quadro "4t")', (tester) async {
      await seedParticipant(status: 'EM_AVALIACAO');
      await confirmedHere({'inf-1': 'inf-1-PM'});

      await pumpResult(tester, justConfirmed: true, tablet: const Size(800, 1280));

      expect(find.byKey(const Key('result-summary-pane')), findsNothing);
      expect(tester.getTopLeft(find.text('Pontuação final')).dx, 24);
      expect(tester.getTopLeft(find.text('Infrações registradas')).dx, 24);
      final button = tester.getRect(next());
      expect(button.width, 800 - 2 * 24);
      expect(button.height, 60);
      expect(button.bottom, 1280 - 16);
    });

    testWidgets(
        'em paisagem, "Reavaliar" fica no fim do painel da esquerda e, sem '
        'rede, diz por quê', (tester) async {
      await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
      when(() => api.get<Object?>(resultPath)).thenThrow(
        const ApiException(message: 'Sem conexão', isNetworkError: true),
      );
      await goOffline();

      await pumpResult(tester, tablet: const Size(1280, 800));

      final button = find.widgetWithText(AppCtaButton, 'Reavaliar');
      expect(tester.getRect(button).right, 452 - 24);
      expect(tester.widget<AppCtaButton>(button).onPressed, isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('result-summary-pane')),
          matching: find.text('Disponível quando houver conexão'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('em paisagem, "Próximo participante" volta à tela de origem',
        (tester) async {
      await seedParticipant(status: 'EM_AVALIACAO');
      await confirmedHere({'inf-1': 'inf-1-PM'});

      await pumpResult(tester, justConfirmed: true, tablet: const Size(1280, 800));
      await tester.tap(next());
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/result/result_screen_test.dart`
Esperado: `+18 -3: Some tests failed.` — os três de disposição (o painel de 452, a coluna de retrato, o "Reavaliar" no painel).

- [ ] **Step 3: Implementar**

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
      _inter(size: 10, weight: FontWeight.w700, height: 1, color: AppColors.surface);

  /// Campo de senha mascarado
  static TextStyle get passwordDots =>
```

por:

```dart
      _inter(size: 10, weight: FontWeight.w700, height: 1, color: AppColors.surface);

  // ─── Resultado no tablet (quadros "4i" e "4t") ────────────────────────────

  /// O % geral
  static TextStyle get resultScoreTablet =>
      _inter(size: 44, weight: FontWeight.w800, height: 1, letterSpacing: -0.88);

  /// A linha de detalhe embaixo do %
  static TextStyle get resultDetailTablet =>
      _inter(size: 13.5, weight: FontWeight.w400, height: 1.45, color: AppColors.text3);

  /// Nome da categoria em "Desempenho por categoria"
  static TextStyle get resultPerformanceNameTablet =>
      _inter(size: 14, weight: FontWeight.w600, height: 1.25);

  /// Nome da categoria no cabeçalho de grupo de "Infrações registradas"
  static TextStyle get resultGroupNameTablet =>
      _inter(size: 15.5, weight: FontWeight.w600, height: 1.25);

  /// "2 infrações", no cabeçalho de grupo
  static TextStyle get resultGroupCountTablet =>
      _inter(size: 12.5, weight: FontWeight.w500, height: 1.2, color: AppColors.textMuted);

  /// Descrição da infração registrada
  static TextStyle get resultInfractionTablet =>
      _inter(size: 15.5, weight: FontWeight.w400, height: 1.4);

  /// A nota no selo da infração registrada
  static TextStyle get resultNoteBadgeTablet =>
      _inter(size: 12, weight: FontWeight.w700, height: 1, color: AppColors.surface);

  /// Campo de senha mascarado
  static TextStyle get passwordDots =>
```

Em `lib/ui/core/widgets/final_score_block.dart`, substituir:

```dart
    final lines = details.where((line) => line.isNotEmpty).toList(growable: false);
    final tablet = scale == FinalScoreScale.summaryTablet;

    return Container(
```

por:

```dart
    final lines = details.where((line) => line.isNotEmpty).toList(growable: false);
    final tablet = scale == FinalScoreScale.summaryTablet;
    final result = scale == FinalScoreScale.resultTablet;

    return Container(
```

Em `lib/ui/core/widgets/final_score_block.dart`, substituir:

```dart
                          : AppTypography.summaryScore,
```

por:

```dart
                          : result
                              ? AppTypography.resultScoreTablet
                              : AppTypography.summaryScore,
```

Em `lib/ui/core/widgets/final_score_block.dart`, substituir:

```dart
              style: tablet ? AppTypography.summaryDetailTablet : AppTypography.summaryDetail,
```

por:

```dart
              style: tablet
                  ? AppTypography.summaryDetailTablet
                  : result
                      ? AppTypography.resultDetailTablet
                      : AppTypography.summaryDetail,
```

Em `lib/ui/core/widgets/final_score_block.dart`, substituir:

```dart
  summaryTablet,
}
```

por:

```dart
  summaryTablet,

  /// Resultado no tablet (quadros "4i" e "4t"): % de 44 e a pílula do
  /// celular.
  resultTablet,
}
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
import '../checklist/checklist_sections.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../checklist/checklist_sections.dart';
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
class _ResultScreenState extends State<ResultScreen> {
  late final ResultViewModel _viewModel = _createViewModel()..init();
```

por:

```dart
class _ResultScreenState extends State<ResultScreen> {
  /// O painel da nota no tablet em paisagem (quadro "4i").
  static const double summaryPaneWidth = 452;

  /// Altura mínima do cabeçalho de grupo de "Infrações registradas" no
  /// tablet.
  static const double groupMinHeightTablet = 56;

  /// O selo da nota da infração no tablet: 34×26.
  static const Size noteBadgeSizeTablet = Size(34, 26);

  late final ResultViewModel _viewModel = _createViewModel()..init();
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;
    final footer = _buildFooter(isOffline);
```

por:

```dart
  /// Recuo das laterais: 20 no celular, 24 no tablet.
  double get _inset => context.isTablet ? AppSpacing.xxl : AppSpacing.xl;

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;
    final expanded = context.isExpandedLayout && !_viewModel.isLoading;
    final footer = expanded ? null : _buildFooter(isOffline);
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
            Expanded(child: _buildBody()),
```

por:

```dart
            Expanded(child: expanded ? _buildTwoPanes(isOffline) : _buildBody()),
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
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
```

por:

```dart
    return ListView(
      children: [..._buildSummaryPart(), ..._buildInfractionsPart(divider: context.isTablet)],
    );
  }

  /// Tablet em paisagem (quadro "4i"): à esquerda, num painel de 452, a nota,
  /// os avisos, o desempenho e o botão embaixo; à direita, as infrações.
  Widget _buildTwoPanes(bool isOffline) {
    final actions = _buildFooterContent(isOffline);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const Key('result-summary-pane'),
          width: summaryPaneWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: ListView(children: _buildSummaryPart())),
              if (actions != null)
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                  ),
                  child: actions,
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
        Expanded(
          child: ListView(
            key: const Key('result-infractions-pane'),
            children: _buildInfractionsPart(divider: false),
          ),
        ),
      ],
    );
  }

  /// A nota, os avisos e o desempenho por categoria.
  List<Widget> _buildSummaryPart() {
    final withScore = [
      for (final category in _viewModel.categories ?? const <ResultCategory>[])
        if (category.score != null) category,
    ];

    return [
      _buildScore(),
      ..._buildNotices(),
      if (withScore.isNotEmpty) ...[
        _buildSectionHeader(
          'Desempenho por categoria',
          bottom: context.isTablet ? AppSpacing.lg : AppSpacing.sm + 2,
        ),
        _buildPerformance(withScore),
      ],
    ];
  }

  /// "Infrações registradas". Com [divider], uma linha em cima e 20 de
  /// recuo — o tablet em retrato (quadro "4t").
  List<Widget> _buildInfractionsPart({required bool divider}) {
    final categories = _viewModel.categories;
    if (categories == null) return const [];
    final count = _viewModel.infractionCount;
    final header = _buildSectionHeader(
      'Infrações registradas',
      trailing: count == 0 ? null : infractionCountLabel(count),
      top: divider ? AppSpacing.xl : AppSpacing.lg,
    );

    return [
      if (divider)
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: header,
        )
      else
        header,
      ..._buildInfractions(categories),
    ];
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
    ].join(' · ');

    return FinalScoreBlock(
      score: _viewModel.score,
      approved: _viewModel.isApproved,
      details: [detail],
    );
```

por:

```dart
    ].join(' · ');
    final tablet = context.isTablet;

    return FinalScoreBlock(
      score: _viewModel.score,
      approved: _viewModel.isApproved,
      details: [detail],
      scale: tablet ? FinalScoreScale.resultTablet : FinalScoreScale.phone,
      padding: EdgeInsets.all(_inset),
    );
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
```

por:

```dart
          padding: EdgeInsets.fromLTRB(_inset, AppSpacing.lg, _inset, 0),
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
  Widget _buildSectionHeader(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.sm + 2,
      ),
```

por:

```dart
  Widget _buildSectionHeader(
    String title, {
    String? trailing,
    double top = AppSpacing.lg,
    double bottom = AppSpacing.sm + 2,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(_inset, top, _inset, bottom),
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
  Widget _buildPerformance(List<ResultCategory> categories) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xs),
      child: Column(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xl),
```

por:

```dart
  /// No tablet (quadros "4i" e "4t"), 25 entre as linhas e 20 embaixo.
  Widget _buildPerformance(List<ResultCategory> categories) {
    final tablet = context.isTablet;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _inset,
        AppSpacing.xs,
        _inset,
        tablet ? AppSpacing.xl : AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) SizedBox(height: tablet ? AppSpacing.xxl + 1 : AppSpacing.xl),
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
            category.name,
            style: AppTypography.categoryName,
            maxLines: 1,
```

por:

```dart
            category.name,
            style: context.isTablet
                ? AppTypography.resultPerformanceNameTablet
                : AppTypography.categoryName,
            maxLines: 1,
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
```

por:

```dart
          padding: EdgeInsets.fromLTRB(_inset, 0, _inset, _inset),
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
  Widget _buildGroupHeader(ResultCategory category, bool isOpen) {
    final hasInfractions = category.infractions.isNotEmpty;
```

por:

```dart
  ///
  /// No tablet (quadros "4i" e "4t"): 16 em cima e embaixo, 24 dos lados,
  /// 56 de altura mínima, nome de 15,5 e vão de 12.
  Widget _buildGroupHeader(ResultCategory category, bool isOpen) {
    final hasInfractions = category.infractions.isNotEmpty;
    final tablet = context.isTablet;
    final double gap = tablet ? AppSpacing.md : AppSpacing.sm + 2;
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
          padding: const EdgeInsets.all(AppSpacing.xl),
```

por:

```dart
          constraints: BoxConstraints(minHeight: tablet ? groupMinHeightTablet : 0),
          padding: tablet
              ? const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg)
              : const EdgeInsets.all(AppSpacing.xl),
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
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
```

por:

```dart
              SizedBox(width: gap),
              Expanded(
                child: Text(
                  category.name,
                  style: tablet
                      ? AppTypography.resultGroupNameTablet
                      : AppTypography.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: gap),
              Text(
                infractionCountLabel(category.infractions.length),
                style: tablet
                    ? AppTypography.resultGroupCountTablet
                    : AppTypography.categoryCount,
              ),
              if (hasInfractions) ...[
                SizedBox(width: tablet ? gap : AppSpacing.sm),
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
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
```

por:

```dart
  /// No tablet (quadros "4i" e "4t"): 16 em cima e embaixo, 24 dos lados, o
  /// selo de 34×26 e a descrição de 15,5, centrados na linha.
  Widget _buildInfraction(ResultInfraction infraction) {
    final comment = infraction.comment;
    final tablet = context.isTablet;

    return Container(
      padding: tablet
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg)
          : const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: Row(
        crossAxisAlignment: tablet ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          _NoteBadge(noteType: infraction.noteType, large: tablet),
          SizedBox(width: tablet ? AppSpacing.md + 2 : AppSpacing.md),
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
                      child: Text(infraction.description, style: AppTypography.infractionDescription),
                    ),
                  ],
                ),
                if (comment != null) ...[
                  const SizedBox(height: AppSpacing.xs + 1),
```

por:

```dart
                      child: Text(
                        infraction.description,
                        style: tablet
                            ? AppTypography.resultInfractionTablet
                            : AppTypography.infractionDescription,
                      ),
                    ),
                  ],
                ),
                if (comment != null) ...[
                  SizedBox(height: tablet ? AppSpacing.xs : AppSpacing.xs + 1),
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
    if (_viewModel.isLoading) return null;

    final Widget content;
    if (_viewModel.justConfirmed) {
      content = AppCtaButton(
        label: 'Próximo participante',
        trailingIcon: AppIcons.chevronRight,
        size: AppCtaSize.large,
```

por:

```dart
    final content = _buildFooterContent(isOffline);
    if (content == null) return null;
    final tablet = context.isTablet;

    // No tablet em retrato, 16 em cima e embaixo e 24 dos lados (quadro "4t").
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: tablet
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg)
          : const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
      child: content,
    );
  }

  Widget? _buildFooterContent(bool isOffline) {
    if (_viewModel.isLoading) return null;

    final size = context.isTablet ? AppCtaSize.tabletLarge : AppCtaSize.large;
    final Widget content;
    if (_viewModel.justConfirmed) {
      content = AppCtaButton(
        label: 'Próximo participante',
        trailingIcon: AppIcons.chevronRight,
        size: size,
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
            size: AppCtaSize.large,
```

por:

```dart
            size: size,
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
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
```

por:

```dart
    }
    return content;
  }
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
  const _NoteBadge({required this.noteType});

  final String noteType;
```

por:

```dart
  const _NoteBadge({required this.noteType, this.large = false});

  final String noteType;

  /// O selo do tablet (quadros "4i" e "4t"): 34×26, canto 6, nota de 12.
  final bool large;
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
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
```

por:

```dart
      constraints: large
          ? BoxConstraints.tight(_ResultScreenState.noteBadgeSizeTablet)
          : const BoxConstraints(
              minWidth: AppSpacing.xxl + 1,
              minHeight: AppSpacing.xl,
            ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(
        noteType,
        style: large ? AppTypography.resultNoteBadgeTablet : AppTypography.resultNoteBadge,
      ),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/result/result_screen_test.dart`
Esperado: `+21: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+995: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/theme/app_typography.dart apps/mobile/simtc/lib/ui/core/widgets/final_score_block.dart apps/mobile/simtc/lib/ui/result/result_screen.dart apps/mobile/simtc/test/ui/result/result_screen_test.dart
git commit -m "feat(mobile): resultado no tablet em dois paineis"
```

---

## Task 5: Janela de admin no tablet: a base e o Adicionar participante

No tablet, as telas de admin viram janela por cima do detalhe. A rota continua a mesma: o `_adminPage` do router devolve, no tablet, uma `AdminDialogPage` (uma `RawDialogRoute` com o fundo escurecido a 42%), e a tela se desenha na `AdminDialogFrame` (cabeçalho com título, subtítulo e X; conteúdo que rola; rodapé `AdminDialogFooter` numa linha). Tocar no fundo passa pelo `PopScope` da tela — o mesmo que o X. Em paisagem a janela fica a 40 da borda direita; em retrato, no centro, com 640; com o teclado, encolhe acima dele; e a árvore é a mesma nas duas posições, para o giro não recriar a tela. O detalhe marca o botão que abriu a janela enquanto ela está aberta. Esta task leva o Adicionar participante (quadros `4l` e `4w`); no celular, nada muda.

**Files:**
- Create: `lib/ui/core/widgets/admin_dialog.dart`
- Modify: `lib/router.dart`
- Modify: `lib/ui/add_participant/add_participant_screen.dart`
- Modify: `lib/ui/core/theme/app_colors.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/widgets/app_buttons.dart`
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Modify: `test/ui/sessions/sessions_split_view_test.dart`

**Interfaces:**
- Consumes: `FormFactorScope.of`, `context.isTablet`, `context.isExpandedLayout` (7A); `AppCtaButton(fullWidth:)`, `AppTypography.buttonHeader` (Task 2).
- Produces:
  - `enum AdminDialogSize { addParticipant(560, top 80, máx. 640), sessionEdit(600, 68, 660), consultants(600, 68, 660) }`, com `right` (40), `portraitWidth` (640) e `portraitMaxHeight` (1000)
  - `AdminDialogPage<T>({required AdminDialogSize size, required Widget child})`, `AdminDialogLayout`
  - `AdminDialogFrame({required String title, required String subtitle, required VoidCallback onClose, required Widget body, Widget? banner, Widget? footer})` — a lista do `body` precisa de `shrinkWrap`
  - `AdminDialogFooter({required Widget secondary, required Widget primary, Widget? notice, String? caption})`
  - `Page<void> _adminPage(BuildContext, GoRouterState, AdminDialogSize, Widget)` em `lib/router.dart`
  - `AppCtaSize.dialog` (52), `AppTextButton({…, bool alignStart = false})`, `AppIconAction({…, bool highlighted = false})`
  - `AppColors.scrim`, `AppColors.dialogShadow`; `AppTypography.dialogTitle` (19), `dialogSubtitle` (13)

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/sessions/sessions_split_view_test.dart`, substituir:

```dart
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/form_factor.dart';
```

por:

```dart
import 'package:simtc/ui/add_participant/add_participant_screen.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/date_labels.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

Em `test/ui/sessions/sessions_split_view_test.dart`, substituir:

```dart
  });
}
```

por:

```dart
  });

  group('janelas de admin', () {
    setUp(() {
      when(() => auth.currentUser).thenReturn(const AuthUser(
        id: 'user-1',
        name: 'Carla Souza',
        email: 'carla@simtc.com.br',
        role: AppUserRole.admin,
        consultantId: 'c-eu',
      ));
    });

    Finder dialog() => find.byKey(const Key('admin-dialog'));

    bool highlighted(WidgetTester tester, String tooltip) => tester
        .widget<AppIconAction>(find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(AppIconAction),
        ))
        .highlighted;

    Finder nameField() => find.descendant(
          of: find.byKey(const Key('campo-nome')),
          matching: find.byType(EditableText),
        );

    testWidgets(
        'em paisagem, "Adicionar participante" abre numa janela de 560 ancorada '
        'à direita, por cima do lado a lado, com o botão marcado (quadro "4l")',
        (tester) async {
      await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
      expect(highlighted(tester, 'Adicionar participante'), isFalse);

      await tester.tap(find.byTooltip('Adicionar participante'));
      await settle(tester);

      expect(find.byType(AddParticipantScreen), findsOneWidget);
      final rect = tester.getRect(dialog());
      expect(rect.width, 560);
      expect(rect.right, 1280 - 40);
      expect(rect.top, 80);
      expect(rect.height, lessThanOrEqualTo(640));
      expect(find.byType(SessionsScreen), findsOneWidget, reason: 'o lado a lado fica embaixo');
      expect(find.text('Escolha uma sessão na lista'), findsNothing);
      expect(highlighted(tester, 'Adicionar participante'), isTrue);
      expect(find.text('Bracell · Direção Defensiva · ${dayMonthLabel(DateTime.now())}'),
          findsOneWidget, reason: 'a empresa e a sessão no subtítulo');
      final cta = find.widgetWithText(AppCtaButton, 'Adicionar participante');
      expect(tester.getSize(cta).height, 52);
      expect(tester.getTopRight(cta).dx, rect.right - 24);
      expect(
        tester.getCenter(find.text('Salvar e adicionar outro')).dy,
        tester.getCenter(cta).dy,
        reason: 'o rodapé é uma linha só',
      );
    });

    testWidgets(
        'em retrato, a janela fica no centro, com 640 de largura (quadro "4w")',
        (tester) async {
      await pumpApp(tester, location: AppRoutes.addParticipant('sess-1'), size: _portrait);

      final rect = tester.getRect(dialog());
      expect(rect.width, 640);
      expect(rect.center.dx, 400);
      expect(rect.center.dy, 640);
    });

    testWidgets(
        'girar várias vezes com o formulário preenchido não perde o que foi '
        'digitado', (tester) async {
      await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
      await tester.tap(find.byTooltip('Adicionar participante'));
      await settle(tester);
      final form = tester.state(find.byType(AddParticipantScreen));

      await tester.enterText(nameField(), 'Fernanda Lopes Meireles');
      await tester.pump();

      for (final size in [_portrait, _landscape, _portrait, _landscape]) {
        await rotate(tester, size);
        expect(identical(tester.state(find.byType(AddParticipantScreen)), form), isTrue,
            reason: 'a janela não pode ser recriada ao girar');
        expect(find.text('Fernanda Lopes Meireles'), findsOneWidget);
      }
      expect(highlighted(tester, 'Adicionar participante'), isTrue,
          reason: 'o botão continua marcado depois de girar');
    });

    testWidgets(
        'tocar no fundo é o mesmo que o X: com algo preenchido, pergunta antes; '
        'descartando, a janela fecha e o botão desmarca', (tester) async {
      final router = await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
      await tester.tap(find.byTooltip('Adicionar participante'));
      await settle(tester);
      await tester.enterText(nameField(), 'Fernanda');
      await tester.pump();

      await tester.tapAt(const Offset(200, 400));
      await settle(tester);

      expect(find.text('Descartar o que foi preenchido?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await settle(tester);

      expect(dialog(), findsNothing);
      expect(location(router), AppRoutes.sessionDetail('sess-1'));
      expect(highlighted(tester, 'Adicionar participante'), isFalse);
    });

    testWidgets('sem nada preenchido, tocar no fundo fecha a janela', (tester) async {
      final router = await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
      await tester.tap(find.byTooltip('Adicionar participante'));
      await settle(tester);

      await tester.tapAt(const Offset(200, 400));
      await settle(tester);

      expect(dialog(), findsNothing);
      expect(location(router), AppRoutes.sessionDetail('sess-1'));
    });

    testWidgets(
        'com o teclado aberto em paisagem, a janela encolhe acima dele e nada '
        'estoura', (tester) async {
      await pumpApp(tester, location: AppRoutes.addParticipant('sess-1'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      addTearDown(tester.view.resetViewInsets);
      await settle(tester);

      final rect = tester.getRect(dialog());
      expect(rect.bottom, lessThanOrEqualTo(800 - 400));
      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/sessions/sessions_split_view_test.dart`
Esperado: não compila — `Error: The getter 'highlighted' isn't defined for the type 'AppIconAction'.`

- [ ] **Step 3: Implementar**

Em `lib/router.dart`, substituir:

```dart
import 'ui/core/form_factor.dart';
import 'ui/debug/ds_gallery_screen.dart';
```

por:

```dart
import 'ui/core/form_factor.dart';
import 'ui/core/widgets/admin_dialog.dart';
import 'ui/debug/ds_gallery_screen.dart';
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

/// As telas de admin: no tablet, uma janela por cima do detalhe (decisão de
/// 21/10/2026); no celular, uma tela cheia, como antes.
Page<void> _adminPage(
  BuildContext context,
  GoRouterState state,
  AdminDialogSize size,
  Widget child,
) {
  if (FormFactorScope.of(context) == FormFactor.tablet) {
    return AdminDialogPage<void>(key: state.pageKey, size: size, child: child);
  }
  return MaterialPage<void>(key: state.pageKey, child: child);
}

/// Rotas do app. O redirecionamento observa o `AuthRepository`: entrar ou sair
/// da sessão troca a tela sem nenhuma navegação manual espalhada pelo código.
```

Em `lib/router.dart`, substituir:

```dart
            builder: (context, state) => AddParticipantScreen(
              sessionId: state.pathParameters['sessionId']!,
```

por:

```dart
            pageBuilder: (context, state) => _adminPage(
              context,
              state,
              AdminDialogSize.addParticipant,
              AddParticipantScreen(sessionId: state.pathParameters['sessionId']!),
```

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
```

por:

```dart
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/admin_dialog.dart';
```

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              // Sem toque: abrir a aba Sincronizar daqui largaria o formulário.
              const AppTopBar(
                title: 'Adicionar participante',
                leadingIcon: AppIcons.close,
                leadingIconSize: 26,
                leadingTooltip: 'Fechar',
                trailing: SyncStatusIndicator(),
              ),
              ConnectivityBanner(
                isOffline: isOffline,
                message: 'Sem conexão — adicionar participante precisa de internet.',
              ),
              Expanded(child: _buildBody()),
              if (_viewModel.session != null)
                _buildFooter(isOffline, keyboardOpen),
            ],
          ),
        ),
      ),
```

por:

```dart
      child: context.isTablet
          ? _buildDialog(isOffline, keyboardOpen)
          : _buildPage(isOffline, keyboardOpen),
    );
  }

  Widget _buildPage(bool isOffline, bool keyboardOpen) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Sem toque: abrir a aba Sincronizar daqui largaria o formulário.
            const AppTopBar(
              title: 'Adicionar participante',
              leadingIcon: AppIcons.close,
              leadingIconSize: 26,
              leadingTooltip: 'Fechar',
              trailing: SyncStatusIndicator(),
            ),
            ConnectivityBanner(
              isOffline: isOffline,
              message: 'Sem conexão — adicionar participante precisa de internet.',
            ),
            Expanded(child: _buildBody()),
            if (_viewModel.session != null)
              _buildFooter(isOffline, keyboardOpen),
          ],
        ),
      ),
    );
  }

  /// No tablet, a tela é uma janela por cima do detalhe (quadros "4l" e
  /// "4w"): a empresa e a sessão vão para o subtítulo, e o rodapé fica numa
  /// linha só. Os campos são os do celular.
  Widget _buildDialog(bool isOffline, bool keyboardOpen) {
    final session = _viewModel.session;

    return AdminDialogFrame(
      title: 'Adicionar participante',
      subtitle: session == null ? '' : '${session.companyName} · ${_contextLine(session)}',
      onClose: _close,
      banner: ConnectivityBanner(
        isOffline: isOffline,
        message: 'Sem conexão — adicionar participante precisa de internet.',
      ),
      body: _buildBody(),
      footer: session == null ? null : _buildDialogFooter(isOffline, keyboardOpen),
```

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
    }

    final registryNotice = _viewModel.registryNotice;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
```

por:

```dart
    }

    final registryNotice = _viewModel.registryNotice;
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lockedReason != null) ...[
          InlineNotice(icon: AppIcons.lockedByOther, message: lockedReason),
          const SizedBox(height: AppSpacing.lg + 2),
        ],
        _buildCpfField(),
        if (registryNotice != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineNotice(icon: AppIcons.profile, message: registryNotice),
        ],
        const SizedBox(height: AppSpacing.lg + 2),
        _buildNameField(),
        const SizedBox(height: AppSpacing.lg + 2),
        _buildEmailField(),
        const SizedBox(height: AppSpacing.lg + 2),
        _buildTypeSelector(),
      ],
    );

    // Na janela do tablet, sem a faixa da empresa (o subtítulo diz a
    // sessão), com 20 em cima e embaixo e 24 dos lados.
    if (context.isTablet) {
      return ListView(
        shrinkWrap: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        children: [form],
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
```

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lockedReason != null) ...[
                InlineNotice(icon: AppIcons.lockedByOther, message: lockedReason),
                const SizedBox(height: AppSpacing.lg + 2),
              ],
              _buildCpfField(),
              if (registryNotice != null) ...[
                const SizedBox(height: AppSpacing.md),
                InlineNotice(icon: AppIcons.profile, message: registryNotice),
              ],
              const SizedBox(height: AppSpacing.lg + 2),
              _buildNameField(),
              const SizedBox(height: AppSpacing.lg + 2),
              _buildEmailField(),
              const SizedBox(height: AppSpacing.lg + 2),
              _buildTypeSelector(),
            ],
          ),
        ),
```

por:

```dart
        Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: form),
```

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
  }

  Future<void> _submit({required bool addAnother}) async {
    FocusScope.of(context).unfocus();
```

por:

```dart
  }

  /// O rodapé da janela do tablet: "Salvar e adicionar outro" à esquerda e
  /// o botão principal à direita, com as mesmas regras do rodapé do celular.
  Widget _buildDialogFooter(bool isOffline, bool keyboardOpen) {
    final canSubmit = _viewModel.canSubmit && !isOffline;
    final error = _viewModel.errorMessage;

    return AdminDialogFooter(
      notice: error != null && !keyboardOpen
          ? InlineNotice(
              icon: AppIcons.needsReview,
              message: error,
              tone: NoticeTone.danger,
            )
          : null,
      caption: isOffline && _viewModel.canAdd && !keyboardOpen
          ? 'Disponível quando houver conexão'
          : null,
      secondary: AppTextButton(
        label: 'Salvar e adicionar outro',
        alignStart: true,
        onPressed: canSubmit ? () => _submit(addAnother: true) : null,
      ),
      primary: AppCtaButton(
        label: 'Adicionar participante',
        icon: AppIcons.addParticipant,
        size: AppCtaSize.dialog,
        fullWidth: false,
        isLoading: _viewModel.isSubmitting,
        onPressed: canSubmit ? () => _submit(addAnother: false) : null,
      ),
    );
  }

  Future<void> _submit({required bool addAnother}) async {
    FocusScope.of(context).unfocus();
```

Em `lib/ui/core/theme/app_colors.dart`, substituir:

```dart
  static const Color navShadowTablet = Color(0x2E0F172A);

  /// Trilho da barra de progresso da abertura
  static const Color progressTrack = Color(0x24000000);
```

por:

```dart
  static const Color navShadowTablet = Color(0x2E0F172A);

  /// Fundo escurecido atrás das janelas de admin do tablet (42%, quadro "4l")
  static const Color scrim = Color(0x6B0F172A);

  /// Sombra das janelas de admin do tablet (34%, quadro "4l")
  static const Color dialogShadow = Color(0x570F172A);

  /// Trilho da barra de progresso da abertura
  static const Color progressTrack = Color(0x24000000);
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
      _inter(size: 11.5, weight: FontWeight.w400, height: 1.2, color: AppColors.textMuted);

  /// Empresa na faixa de contexto dos formulários de ADMIN (canvas "3b")
  static TextStyle get contextTitle =>
```

por:

```dart
      _inter(size: 11.5, weight: FontWeight.w400, height: 1.2, color: AppColors.textMuted);

  /// Título da janela de admin no tablet ("Adicionar participante", quadro
  /// "4l")
  static TextStyle get dialogTitle =>
      _inter(size: 19, weight: FontWeight.w600, height: 1.25);

  /// Subtítulo da janela de admin no tablet
  static TextStyle get dialogSubtitle =>
      _inter(size: 13, weight: FontWeight.w400, height: 1.35, color: AppColors.text3);

  /// Empresa na faixa de contexto dos formulários de ADMIN (canvas "3b")
  static TextStyle get contextTitle =>
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
  /// (quadros "4f" e "4q")
```

por:

```dart
  /// (quadros "4f" e "4q") e do botão principal das janelas de admin (quadro
  /// "4l")
```

Criar `lib/ui/core/widgets/admin_dialog.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../form_factor.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Onde e com que tamanho cada janela de admin abre no tablet. Em paisagem,
/// ancorada à direita, a [top] do topo da área útil (quadros "4l", "4m" e
/// "4n"); em retrato, no centro, com 640 (quadros "4w", "4x" e "4y").
enum AdminDialogSize {
  addParticipant(width: 560, top: 80, maxHeight: 640),
  sessionEdit(width: 600, top: 68, maxHeight: 660),
  consultants(width: 600, top: 68, maxHeight: 660);

  const AdminDialogSize({
    required this.width,
    required this.top,
    required this.maxHeight,
  });

  /// Largura em paisagem.
  final double width;

  /// Distância do topo da área útil, em paisagem.
  final double top;

  /// Altura máxima em paisagem.
  final double maxHeight;

  /// Distância da borda direita, em paisagem.
  static const double right = 40;

  /// Largura em retrato.
  static const double portraitWidth = 640;

  /// Altura máxima em retrato.
  static const double portraitMaxHeight = 1000;
}

/// A rota de uma janela de admin no tablet: o fundo escurecido a 42% e a
/// janela por cima da tela de onde ela abriu. Tocar no fundo faz o mesmo que
/// o X e o voltar do Android — passa pelo `PopScope` da tela, que pergunta
/// antes de descartar o que foi preenchido (decisão de 23/10/2026).
class AdminDialogPage<T> extends Page<T> {
  const AdminDialogPage({super.key, required this.size, required this.child});

  final AdminDialogSize size;
  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return RawDialogRoute<T>(
      settings: this,
      barrierColor: AppColors.scrim,
      barrierLabel: 'Fechar',
      pageBuilder: (context, animation, secondaryAnimation) =>
          AdminDialogLayout(size: size, child: child),
    );
  }
}

/// Põe a janela no lugar: ancorada à direita em paisagem, no centro em
/// retrato. Com o teclado aberto, ela encolhe para caber acima dele, e o
/// conteúdo rola.
class AdminDialogLayout extends StatelessWidget {
  const AdminDialogLayout({super.key, required this.size, required this.child});

  final AdminDialogSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final available = media.size.height -
        media.viewInsets.bottom -
        media.padding.top -
        media.padding.bottom;
    final expanded = context.isExpandedLayout;

    // A mesma árvore nas duas posições: girar com a janela aberta não pode
    // recriar a tela de dentro (o que foi digitado).
    final EdgeInsets padding;
    final double width;
    final double maxHeight;
    if (expanded) {
      padding = EdgeInsets.only(
        top: media.padding.top + size.top,
        right: AdminDialogSize.right,
      );
      width = size.width;
      maxHeight = math.min(size.maxHeight, available - size.top - AppSpacing.xxl);
    } else {
      padding = EdgeInsets.only(
        top: media.padding.top,
        bottom: media.viewInsets.bottom + media.padding.bottom,
      );
      width = math.min(
        AdminDialogSize.portraitWidth,
        media.size.width - 2 * AppSpacing.lg,
      );
      maxHeight = math.min(
        AdminDialogSize.portraitMaxHeight,
        available - 2 * AppSpacing.xxl,
      );
    }

    return Padding(
      padding: padding,
      child: Align(
        alignment: expanded ? Alignment.topRight : Alignment.center,
        child: SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: math.max(0, maxHeight)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A janela de admin do tablet: cabeçalho com título, subtítulo e o X; o
/// conteúdo, que rola; e o rodapé, quando há (quadros "4l", "4m" e "4n").
/// A janela tem a altura do conteúdo, até o limite do [AdminDialogLayout].
class AdminDialogFrame extends StatelessWidget {
  const AdminDialogFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.body,
    this.banner,
    this.footer,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  /// O conteúdo. Uma lista aqui dentro precisa de `shrinkWrap`.
  final Widget body;

  /// A faixa de sem conexão, embaixo do cabeçalho.
  final Widget? banner;
  final Widget? footer;

  /// Canto da janela.
  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('admin-dialog'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.dialogShadow,
            offset: Offset(0, AppSpacing.xxl),
            blurRadius: 64,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            if (banner != null) banner!,
            Flexible(child: body),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }

  /// 18 em cima, 16 embaixo, 24 dos lados; o X sobe 10 e avança 10, para o
  /// ícone ficar alinhado com o título e a margem.
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg + 2,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTypography.dialogTitle),
                const SizedBox(height: AppSpacing.xxs + 1),
                // Uma linha em paisagem (quadro "4l"); quebra em retrato
                // (quadro "4w").
                Text(
                  subtitle,
                  style: AppTypography.dialogSubtitle,
                  maxLines: context.isExpandedLayout ? 1 : null,
                  overflow: context.isExpandedLayout ? TextOverflow.ellipsis : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Transform.translate(
            offset: const Offset(AppSpacing.sm + 2, -(AppSpacing.sm + 2)),
            child: SizedBox.square(
              dimension: AppSpacing.touchTarget,
              child: IconButton(
                tooltip: 'Fechar',
                icon: const Icon(AppIcons.close, size: 24, color: AppColors.text3),
                onPressed: onClose,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// O rodapé de uma janela de admin: o erro, quando há; numa linha, a ação
/// secundária à esquerda e a principal à direita; e o motivo de a principal
/// estar apagada, embaixo. Fundo cinza-claro, 14 em cima, 18 embaixo e 24
/// dos lados (quadros "4l" e "4m").
class AdminDialogFooter extends StatelessWidget {
  const AdminDialogFooter({
    super.key,
    required this.secondary,
    required this.primary,
    this.notice,
    this.caption,
  });

  final Widget secondary;
  final Widget primary;
  final Widget? notice;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.md + 2,
        AppSpacing.xxl,
        AppSpacing.lg + 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null) ...[notice!, const SizedBox(height: AppSpacing.sm)],
          Row(
            children: [
              Expanded(child: secondary),
              const SizedBox(width: AppSpacing.md),
              primary,
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(caption, style: AppTypography.meta, textAlign: TextAlign.end),
          ],
        ],
      ),
    );
  }
}
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
  header,
}
```

por:

```dart
  header,

  /// 52dp, texto 15 — a ação principal das janelas de admin no tablet
  /// ("Adicionar participante", quadro "4l").
  dialog,
}
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
  double get _height => switch (size) {
        AppCtaSize.compact || AppCtaSize.header => AppSpacing.touchTarget,
```

por:

```dart
  /// Altura do [AppCtaSize.dialog].
  static const double dialogHeight = 52;

  double get _height => switch (size) {
        AppCtaSize.compact || AppCtaSize.header => AppSpacing.touchTarget,
        AppCtaSize.dialog => dialogHeight,
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
        AppCtaSize.header => AppTypography.buttonHeader,
      };

  double get _iconSize => switch (size) {
        AppCtaSize.compact => 19,
        AppCtaSize.header => 21,
        AppCtaSize.large => 22,
        AppCtaSize.tabletLarge => 24,
      };

  double get _trailingIconSize =>
      size == AppCtaSize.compact || size == AppCtaSize.header ? 21 : 25;
```

por:

```dart
        AppCtaSize.header || AppCtaSize.dialog => AppTypography.buttonHeader,
      };

  double get _iconSize => switch (size) {
        AppCtaSize.compact => 19,
        AppCtaSize.header || AppCtaSize.dialog => 21,
        AppCtaSize.large => 22,
        AppCtaSize.tabletLarge => 24,
      };

  double get _trailingIconSize => switch (size) {
        AppCtaSize.compact || AppCtaSize.header || AppCtaSize.dialog => 21,
        AppCtaSize.large || AppCtaSize.tabletLarge => 25,
      };
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
            horizontal: size == AppCtaSize.header ? AppSpacing.xl : AppSpacing.lg,
```

por:

```dart
            horizontal: switch (size) {
              AppCtaSize.header => AppSpacing.xl,
              AppCtaSize.dialog => AppSpacing.xxl,
              _ => AppSpacing.lg,
            },
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
          textStyle: _textStyle,
        ),
        child: isLoading ? _buildSpinner() : _buildContent(),
      ),
    );
  }
```

por:

```dart
          textStyle: _textStyle,
        ),
        child: isLoading ? _buildLoading() : _buildContent(),
      ),
    );
  }

  /// Sem [fullWidth], o botão guarda a largura do rótulo enquanto gira — não
  /// encolhe no meio do rodapé.
  Widget _buildLoading() {
    if (fullWidth) return _buildSpinner();
    return Stack(
      alignment: Alignment.center,
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: _buildContent(),
        ),
        _buildSpinner(),
      ],
    );
  }
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
  });

  final String label;
  final VoidCallback? onPressed;
  final AppTextButtonTone tone;
```

por:

```dart
    this.alignStart = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppTextButtonTone tone;

  /// O rótulo encostado à esquerda — a ação secundária do rodapé das janelas
  /// de admin no tablet (quadro "4l").
  final bool alignStart;
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
          textStyle: AppTypography.textAction,
        ),
```

por:

```dart
          textStyle: AppTypography.textAction,
          alignment: alignStart ? Alignment.centerLeft : Alignment.center,
          padding: alignStart ? EdgeInsets.zero : null,
        ),
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.touchTarget,
```

por:

```dart
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// A janela que este botão abriu está aberta: o botão fica marcado atrás
  /// do fundo escurecido (quadros "4l", "4m" e "4n").
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.touchTarget,
      height: AppSpacing.touchTarget,
      decoration: highlighted
          ? BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            )
          : null,
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
        tooltip: 'Editar dados do treinamento',
        onPressed: _adminActionsEnabled(isOffline) ? _openEdit : null,
```

por:

```dart
        tooltip: 'Editar dados do treinamento',
        highlighted: _openAdmin == _AdminScreen.edit,
        onPressed: _adminActionsEnabled(isOffline) ? _openEdit : null,
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
        onPressed: _openConsultants,
      ),
    ];
```

por:

```dart
        highlighted: _openAdmin == _AdminScreen.consultants,
        onPressed: _openConsultants,
      ),
    ];
  }

  /// A tela de admin aberta a partir deste detalhe. No tablet, ela é uma
  /// janela por cima, e o botão que a abriu fica marcado (quadros "4l", "4m"
  /// e "4n").
  _AdminScreen? _openAdmin;

  Future<T?> _pushAdmin<T>(_AdminScreen screen, String location) async {
    setState(() => _openAdmin = screen);
    try {
      return await context.push<T>(location);
    } finally {
      if (mounted) setState(() => _openAdmin = null);
    }
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
    final saved =
        await context.push<bool>(AppRoutes.sessionEdit(widget.sessionId));
    if (saved == true && mounted) unawaited(_viewModel.refresh());
  }

  /// Quem entra ou sai por lá muda o cache, e este detalhe lê do cache: não
  /// há o que fazer na volta.
  void _openConsultants() {
    context.push(AppRoutes.sessionConsultants(widget.sessionId));
  }

  /// Entrou gente lá: a linha nova já está no cache, e baixar de novo acerta
  /// os contadores.
  Future<void> _openAddParticipant() async {
    final added =
        await context.push<bool>(AppRoutes.addParticipant(widget.sessionId));
```

por:

```dart
    final saved = await _pushAdmin<bool>(
      _AdminScreen.edit,
      AppRoutes.sessionEdit(widget.sessionId),
    );
    if (saved == true && mounted) unawaited(_viewModel.refresh());
  }

  /// Quem entra ou sai por lá muda o cache, e este detalhe lê do cache: não
  /// há o que fazer na volta.
  Future<void> _openConsultants() async {
    await _pushAdmin<Object?>(
      _AdminScreen.consultants,
      AppRoutes.sessionConsultants(widget.sessionId),
    );
  }

  /// Entrou gente lá: a linha nova já está no cache, e baixar de novo acerta
  /// os contadores.
  Future<void> _openAddParticipant() async {
    final added = await _pushAdmin<bool>(
      _AdminScreen.addParticipant,
      AppRoutes.addParticipant(widget.sessionId),
    );
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
            tooltip: 'Adicionar participante',
            onPressed:
```

por:

```dart
            tooltip: 'Adicionar participante',
            highlighted: _openAdmin == _AdminScreen.addParticipant,
            onPressed:
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
enum _RowAction { unassign }
```

por:

```dart
enum _RowAction { unassign }

/// As telas de admin que o detalhe abre (ver `_openAdmin`).
enum _AdminScreen { edit, consultants, addParticipant }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/sessions/sessions_split_view_test.dart`
Esperado: `+14: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1001: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/widgets/admin_dialog.dart apps/mobile/simtc/lib/router.dart apps/mobile/simtc/lib/ui/add_participant/add_participant_screen.dart apps/mobile/simtc/lib/ui/core/theme/app_colors.dart apps/mobile/simtc/lib/ui/core/theme/app_typography.dart apps/mobile/simtc/lib/ui/core/widgets/app_buttons.dart apps/mobile/simtc/lib/ui/session_detail/session_detail_screen.dart apps/mobile/simtc/test/ui/sessions/sessions_split_view_test.dart
git commit -m "feat(mobile): janela de adicionar participante no tablet"
```

---

## Task 6: Janela de Dados do treinamento no tablet

A 1.12 vira janela no tablet (quadros `4m` e `4x`): 600 de largura, a 68 do topo em paisagem, com o lápis marcado; "Descartar" à esquerda e "Salvar alterações" à direita no rodapé. O X e o fundo passam pelo voltar da tela, que pergunta antes de descartar uma mudança. Os campos são os do celular.

**Files:**
- Modify: `lib/router.dart`
- Modify: `lib/ui/session_edit/session_edit_screen.dart`
- Modify: `test/ui/sessions/sessions_split_view_test.dart`

**Interfaces:**
- Consumes: `_adminPage`, `AdminDialogSize.sessionEdit`, `AdminDialogFrame`, `AdminDialogFooter`, `AppCtaSize.dialog`, `AppTextButton(alignStart:)` (Task 5).
- Produces:
  - nada que outra task use.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/sessions/sessions_split_view_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
```

por:

```dart
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/session_edit/session_edit_screen.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
```

Em `test/ui/sessions/sessions_split_view_test.dart`, substituir:

```dart
      expect(tester.takeException(), isNull);
    });
  });
}
```

por:

```dart
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'em paisagem, "Editar dados do treinamento" abre numa janela de 600, a '
        '68 do topo, com o lápis marcado e o rodapé numa linha (quadro "4m")',
        (tester) async {
      await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));

      await tester.tap(find.byTooltip('Editar dados do treinamento'));
      await settle(tester);

      expect(find.byType(SessionEditScreen), findsOneWidget);
      final rect = tester.getRect(dialog());
      expect(rect.width, 600);
      expect(rect.right, 1280 - 40);
      expect(rect.top, 68);
      expect(highlighted(tester, 'Editar dados do treinamento'), isTrue);
      expect(highlighted(tester, 'Consultores da sessão'), isFalse);
      expect(find.text('Bracell · Direção Defensiva'), findsOneWidget);
      final cta = find.widgetWithText(AppCtaButton, 'Salvar alterações');
      expect(tester.getSize(cta).height, 52);
      expect(tester.getCenter(find.text('Descartar')).dy, tester.getCenter(cta).dy);
    });

    testWidgets(
        'girar com o local alterado não perde o que foi digitado; o fundo '
        'pergunta antes de descartar', (tester) async {
      await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
      await tester.tap(find.byTooltip('Editar dados do treinamento'));
      await settle(tester);
      final form = tester.state(find.byType(SessionEditScreen));
      final city = find.descendant(
        of: find.byKey(const Key('campo-cidade')),
        matching: find.byType(EditableText),
      );

      await tester.enterText(city, 'Itabirito');
      await tester.pump();

      for (final size in [_portrait, _landscape, _portrait, _landscape]) {
        await rotate(tester, size);
        expect(identical(tester.state(find.byType(SessionEditScreen)), form), isTrue);
        expect(find.text('Itabirito'), findsOneWidget);
      }

      await tester.tapAt(const Offset(200, 400));
      await settle(tester);
      expect(find.text('Descartar as alterações?'), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Descartar'),
      ));
      await settle(tester);

      expect(dialog(), findsNothing);
      expect(highlighted(tester, 'Editar dados do treinamento'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/sessions/sessions_split_view_test.dart`
Esperado: `+14 -2: Some tests failed.` — a tela de Dados do treinamento ainda abre em tela cheia.

- [ ] **Step 3: Implementar**

Em `lib/router.dart`, substituir:

```dart
            builder: (context, state) => SessionEditScreen(
              sessionId: state.pathParameters['sessionId']!,
```

por:

```dart
            pageBuilder: (context, state) => _adminPage(
              context,
              state,
              AdminDialogSize.sessionEdit,
              SessionEditScreen(sessionId: state.pathParameters['sessionId']!),
```

Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:

```dart
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
```

por:

```dart
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/admin_dialog.dart';
```

Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:

```dart
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              // Sem toque: abrir a aba Sincronizar daqui largaria o formulário.
              const AppTopBar(
                title: 'Dados do treinamento',
                trailing: SyncStatusIndicator(),
              ),
              ConnectivityBanner(
                isOffline: isOffline,
                message: 'Sem conexão — salvar e cancelar precisam de internet.',
              ),
              Expanded(child: _buildBody(isOffline)),
              if (_viewModel.session != null)
                _buildFooter(isOffline, keyboardOpen),
            ],
          ),
```

por:

```dart
      child: context.isTablet
          ? _buildDialog(isOffline, keyboardOpen)
          : _buildPage(isOffline, keyboardOpen),
    );
  }

  Widget _buildPage(bool isOffline, bool keyboardOpen) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Sem toque: abrir a aba Sincronizar daqui largaria o formulário.
            const AppTopBar(
              title: 'Dados do treinamento',
              trailing: SyncStatusIndicator(),
            ),
            ConnectivityBanner(
              isOffline: isOffline,
              message: 'Sem conexão — salvar e cancelar precisam de internet.',
            ),
            Expanded(child: _buildBody(isOffline)),
            if (_viewModel.session != null)
              _buildFooter(isOffline, keyboardOpen),
          ],
```

Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:

```dart
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
```

por:

```dart
    }

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lockedReason != null) ...[
          InlineNotice(icon: AppIcons.lockedByOther, message: lockedReason),
          const SizedBox(height: AppSpacing.lg + 2),
        ],
        _buildDateField(),
        const SizedBox(height: AppSpacing.lg + 2),
        _buildPlaceRow(),
        const SizedBox(height: AppSpacing.lg + 2),
        _buildNotesField(),
        // O vão de 18 dos campos mais os 4 do botão: 22, como no quadro
        // "3b" (o gap do bloco e o `padding-top` do botão).
        const SizedBox(height: AppSpacing.lg + 2 + AppSpacing.xs),
        _buildCancelButton(isOffline),
      ],
    );

    // Na janela do tablet, sem a faixa da empresa (o subtítulo diz a
    // sessão), com 20 em cima e embaixo e 24 dos lados.
    if (context.isTablet) {
      return ListView(
        shrinkWrap: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        children: [form],
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
```

Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:

```dart
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lockedReason != null) ...[
                InlineNotice(icon: AppIcons.lockedByOther, message: lockedReason),
                const SizedBox(height: AppSpacing.lg + 2),
              ],
              _buildDateField(),
              const SizedBox(height: AppSpacing.lg + 2),
              _buildPlaceRow(),
              const SizedBox(height: AppSpacing.lg + 2),
              _buildNotesField(),
              // O vão de 18 dos campos mais os 4 do botão: 22, como no quadro
              // "3b" (o gap do bloco e o `padding-top` do botão).
              const SizedBox(height: AppSpacing.lg + 2 + AppSpacing.xs),
              _buildCancelButton(isOffline),
            ],
          ),
        ),
      ],
```

por:

```dart
        Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: form),
      ],
    );
  }

  /// No tablet, a tela é uma janela por cima do detalhe (quadros "4m" e
  /// "4x"): a empresa e o curso vão para o subtítulo, e o rodapé fica numa
  /// linha só. Os campos são os do celular. O X e o fundo passam pelo voltar,
  /// que pergunta antes de descartar uma mudança.
  Widget _buildDialog(bool isOffline, bool keyboardOpen) {
    final session = _viewModel.session;

    return AdminDialogFrame(
      title: 'Dados do treinamento',
      subtitle: session == null ? '' : '${session.companyName} · ${session.courseName}',
      onClose: () => Navigator.of(context).maybePop(),
      banner: ConnectivityBanner(
        isOffline: isOffline,
        message: 'Sem conexão — salvar e cancelar precisam de internet.',
      ),
      body: _buildBody(isOffline),
      footer: session == null ? null : _buildDialogFooter(isOffline, keyboardOpen),
    );
  }

  /// O rodapé da janela do tablet: "Descartar" à esquerda e "Salvar
  /// alterações" à direita, com as mesmas regras do rodapé do celular.
  Widget _buildDialogFooter(bool isOffline, bool keyboardOpen) {
    final error = _viewModel.errorMessage;

    return AdminDialogFooter(
      notice: error != null && !keyboardOpen
          ? InlineNotice(
              icon: AppIcons.needsReview,
              message: error,
              tone: NoticeTone.danger,
            )
          : null,
      caption: isOffline && _viewModel.canEdit && !keyboardOpen
          ? 'Disponível quando houver conexão'
          : null,
      secondary: AppTextButton(
        label: 'Descartar',
        tone: AppTextButtonTone.neutral,
        alignStart: true,
        onPressed: _viewModel.isBusy ? null : _discard,
      ),
      primary: AppCtaButton(
        label: 'Salvar alterações',
        icon: AppIcons.save,
        size: AppCtaSize.dialog,
        fullWidth: false,
        isLoading: _viewModel.isSaving,
        onPressed: _viewModel.canSave && !isOffline ? _save : null,
      ),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/sessions/sessions_split_view_test.dart`
Esperado: `+16: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1003: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/router.dart apps/mobile/simtc/lib/ui/session_edit/session_edit_screen.dart apps/mobile/simtc/test/ui/sessions/sessions_split_view_test.dart
git commit -m "feat(mobile): janela de dados do treinamento no tablet"
```

---

## Task 7: Janela de Consultores da sessão no tablet

A 1.13 vira janela no tablet (quadros `4n` e `4y`): 600 de largura, a 68 do topo em paisagem, com o ícone de pessoas marcado, sem rodapé (cada toque vale na hora) e 24 de recuo nas linhas. A faixa de sem conexão e a falha do último toque ficam fora da rolagem, embaixo do cabeçalho.

**Files:**
- Modify: `lib/router.dart`
- Modify: `lib/ui/session_consultants/consultant_row.dart`
- Modify: `lib/ui/session_consultants/session_consultants_screen.dart`
- Modify: `test/ui/sessions/sessions_split_view_test.dart`

**Interfaces:**
- Consumes: `_adminPage`, `AdminDialogSize.consultants`, `AdminDialogFrame` (Task 5).
- Produces:
  - `ConsultantRow({…, double horizontalInset = AppSpacing.xl})`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/sessions/sessions_split_view_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_top_bar.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
```

por:

```dart
import 'package:simtc/ui/core/widgets/admin_dialog.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_top_bar.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/session_consultants/session_consultants_screen.dart';
```

Em `test/ui/sessions/sessions_split_view_test.dart`, substituir:

```dart
      expect(highlighted(tester, 'Editar dados do treinamento'), isFalse);
    });
  });
}
```

por:

```dart
      expect(highlighted(tester, 'Editar dados do treinamento'), isFalse);
    });

    testWidgets(
        'em paisagem, "Consultores da sessão" abre numa janela de 600, a 68 do '
        'topo, sem rodapé e com o ícone de pessoas marcado (quadro "4n")',
        (tester) async {
      await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));

      await tester.tap(find.byTooltip('Consultores da sessão'));
      await settle(tester);

      expect(find.byType(SessionConsultantsScreen), findsOneWidget);
      final rect = tester.getRect(dialog());
      expect(rect.width, 600);
      expect(rect.right, 1280 - 40);
      expect(rect.top, 68);
      expect(highlighted(tester, 'Consultores da sessão'), isTrue);
      expect(find.text('Cada toque vale na hora — não há botão de salvar.'), findsOneWidget);
      expect(find.descendant(of: dialog(), matching: find.byType(AdminDialogFooter)), findsNothing,
          reason: 'sem rodapé');
      expect(tester.getTopLeft(find.text('Na sessão')).dx, rect.left + 24);
    });

    testWidgets(
        'em retrato, consultores fica no centro, com 640, e atravessa o giro '
        'sem ser recriada (quadro "4y")', (tester) async {
      await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
      await tester.tap(find.byTooltip('Consultores da sessão'));
      await settle(tester);
      final screen = tester.state(find.byType(SessionConsultantsScreen));

      await rotate(tester, _portrait);

      final rect = tester.getRect(dialog());
      expect(rect.width, 640);
      expect(rect.center.dx, 400);
      expect(identical(tester.state(find.byType(SessionConsultantsScreen)), screen), isTrue);

      await tester.tapAt(const Offset(400, 60));
      await settle(tester);
      expect(dialog(), findsNothing, reason: 'tocar no fundo fecha');
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/sessions/sessions_split_view_test.dart`
Esperado: `+16 -2: Some tests failed.` — a tela de Consultores ainda abre em tela cheia.

- [ ] **Step 3: Implementar**

Em `lib/router.dart`, substituir:

```dart
            builder: (context, state) => SessionConsultantsScreen(
              sessionId: state.pathParameters['sessionId']!,
```

por:

```dart
            pageBuilder: (context, state) => _adminPage(
              context,
              state,
              AdminDialogSize.consultants,
              SessionConsultantsScreen(sessionId: state.pathParameters['sessionId']!),
```

Em `lib/ui/session_consultants/consultant_row.dart`, substituir:

```dart
    this.action,
  });
```

por:

```dart
    this.action,
    this.horizontalInset = AppSpacing.xl,
  });
```

Em `lib/ui/session_consultants/consultant_row.dart`, substituir:

```dart
  // O vão entre o cabeçalho, o aviso e a ação (10 no canvas).
  static const double _gap = AppSpacing.md - AppSpacing.xxs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
```

por:

```dart
  /// Recuo das laterais: 20 no celular, 24 na janela do tablet (quadro "4n").
  final double horizontalInset;

  // O vão entre o cabeçalho, o aviso e a ação (10 no canvas).
  static const double _gap = AppSpacing.md - AppSpacing.xxs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
```

por:

```dart
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/admin_dialog.dart';
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;
    final error = _viewModel.errorMessage;
```

por:

```dart
  /// Recuo das laterais: 20 no celular, 24 na janela do tablet (quadro "4n").
  double get _inset => context.isTablet ? AppSpacing.xxl : AppSpacing.xl;

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;
    if (context.isTablet) return _buildDialog(isOffline);
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
            ConnectivityBanner(
              isOffline: isOffline,
              message: 'Sem conexão — mudar os consultores precisa de internet.',
            ),
            // Fora da rolagem: a falha de um botão do fim da lista não pode
            // ficar escondida lá em cima.
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: InlineNotice(
                  icon: AppIcons.needsReview,
                  message: error,
                  tone: NoticeTone.danger,
                ),
              ),
            Expanded(child: _buildBody(isOffline)),
          ],
        ),
      ),
    );
```

por:

```dart
            ..._buildBanners(isOffline),
            Expanded(child: _buildBody(isOffline)),
          ],
        ),
      ),
    );
  }

  /// No tablet, a tela é uma janela por cima do detalhe (quadros "4n" e
  /// "4y"), sem rodapé: cada toque vale na hora. A lista é a do celular.
  Widget _buildDialog(bool isOffline) {
    return AdminDialogFrame(
      title: 'Consultores da sessão',
      subtitle: 'Cada toque vale na hora — não há botão de salvar.',
      onClose: () => Navigator.of(context).maybePop(),
      banner: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildBanners(isOffline),
      ),
      body: _buildBody(isOffline),
    );
  }

  /// A faixa de sem conexão e a falha do último toque — fora da rolagem: a
  /// falha de um botão do fim da lista não pode ficar escondida lá em cima.
  List<Widget> _buildBanners(bool isOffline) {
    final error = _viewModel.errorMessage;

    return [
      ConnectivityBanner(
        isOffline: isOffline,
        message: 'Sem conexão — mudar os consultores precisa de internet.',
      ),
      if (error != null)
        Padding(
          padding: EdgeInsets.fromLTRB(_inset, AppSpacing.md, _inset, AppSpacing.md),
          child: InlineNotice(
            icon: AppIcons.needsReview,
            message: error,
            tone: NoticeTone.danger,
          ),
        ),
    ];
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
    final notice = _buildNotice();

    return RefreshIndicator(
      color: AppColors.primary,
```

por:

```dart
    final notice = _buildNotice();

    final tablet = context.isTablet;

    return RefreshIndicator(
      color: AppColors.primary,
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
        children: [
          SessionContextHeader(
            companyName: session.companyName,
            logoUrl: session.companyLogoUrl,
            title: _viewModel.contextTitle,
            subtitle: _viewModel.contextSubtitle,
            muted: true,
          ),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                0,
              ),
```

por:

```dart
        // Na janela do tablet, a lista tem a altura do que mostra.
        shrinkWrap: tablet,
        children: [
          // Na janela do tablet, sem a faixa da empresa: a janela fica por
          // cima do detalhe da sessão.
          if (!tablet)
            SessionContextHeader(
              companyName: session.companyName,
              logoUrl: session.companyLogoUrl,
              title: _viewModel.contextTitle,
              subtitle: _viewModel.contextSubtitle,
              muted: true,
            ),
          if (notice != null)
            Padding(
              padding: EdgeInsets.fromLTRB(_inset, AppSpacing.md, _inset, 0),
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
```

por:

```dart
      padding: EdgeInsets.symmetric(
        horizontal: _inset,
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
      metaWraps: true,
      trailing: LabelPill(
```

por:

```dart
      metaWraps: true,
      horizontalInset: _inset,
      trailing: LabelPill(
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl + AppSpacing.xxs,
        AppSpacing.xl,
```

por:

```dart
      padding: EdgeInsets.fromLTRB(
        _inset,
        AppSpacing.xl + AppSpacing.xxs,
        _inset,
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
```

por:

```dart
          padding: EdgeInsets.symmetric(horizontal: _inset),
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
      meta: consultant.email,
      trailing: AppCompactOutlineButton(
```

por:

```dart
      meta: consultant.email,
      horizontalInset: _inset,
      trailing: AppCompactOutlineButton(
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: InlineNotice(
```

por:

```dart
    return Padding(
      padding: EdgeInsets.fromLTRB(_inset, AppSpacing.lg, _inset, AppSpacing.xxl),
      child: const InlineNotice(
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/sessions/sessions_split_view_test.dart`
Esperado: `+18: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1005: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/router.dart apps/mobile/simtc/lib/ui/session_consultants/consultant_row.dart apps/mobile/simtc/lib/ui/session_consultants/session_consultants_screen.dart apps/mobile/simtc/test/ui/sessions/sessions_split_view_test.dart
git commit -m "feat(mobile): janela de consultores no tablet"
```

---

## Task 8: Aviso passageiro acima da pílula no tablet

No tablet em retrato, o aviso passageiro (SnackBar) das abas Sessões e Sincronizar flutua a 8 acima da pílula, com os recuos dela, em vez de cobri-la (pendência da 7A). O `TabSnackBarArea` fica sempre na árvore em volta do `Scaffold` da aba — só o tema muda —, para o giro não recriar a tela.

**Files:**
- Modify: `lib/ui/core/widgets/app_nav_bar.dart`
- Modify: `lib/ui/sessions/sessions_screen.dart`
- Modify: `lib/ui/sync/sync_screen.dart`
- Modify: `test/ui/core/widgets/app_nav_bar_test.dart`

**Interfaces:**
- Consumes: `context.isTablet`, `context.isExpandedLayout` (7A); `TabletNavFrame.bottomInset` (7A).
- Produces:
  - `TabSnackBarArea({required Widget child})`
  - `TabletNavFrame.sideFor(double width)` — 120, ou 16 numa janela mais estreita que 600

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/core/widgets/app_nav_bar_test.dart`, substituir:

```dart
  });

  testWidgets('"Perfil" avisa que chega numa próxima versão', (tester) async {
    screen(tester, const Size(1280, 800));
```

por:

```dart
  });

  group('aviso passageiro (SnackBar)', () {
    /// Uma aba com a navbar do tablet, mostrando um aviso.
    Future<void> pumpWithSnackBar(WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AssessmentSyncService>.value(
          value: FakeAssessmentSyncService(),
          child: FormFactorScope(
            formFactor: FormFactor.tablet,
            child: MaterialApp(
              home: TabSnackBarArea(
                child: Scaffold(
                  body: Builder(
                    builder: (context) => TabletNavFrame(
                      current: AppTab.sessions,
                      child: TextButton(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('aviso'))),
                        child: const Text('mostrar'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mostrar'));
      await tester.pumpAndSettle();
    }

    testWidgets('no tablet em retrato, flutua acima da pílula, sem cobri-la',
        (tester) async {
      screen(tester, const Size(800, 1280));
      await pumpWithSnackBar(tester);

      // O corpo do aviso: o `SnackBar` inclui o recuo em volta.
      final snack = tester.getRect(find
          .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
          .first);
      final bar = tester.getRect(find.byType(PillNavBar));
      expect(snack.bottom, lessThanOrEqualTo(bar.top - 8));
      expect(snack.left, 120);
      expect(snack.right, 800 - 120);
    });

    testWidgets('em paisagem, com a navbar na lateral, fica embaixo, como sempre',
        (tester) async {
      screen(tester, const Size(1280, 800));
      await pumpWithSnackBar(tester);

      final snack = tester.getRect(find
          .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
          .first);
      expect(snack.bottom, 800);
      expect(snack.width, 1280);
    });
  });

  testWidgets('"Perfil" avisa que chega numa próxima versão', (tester) async {
    screen(tester, const Size(1280, 800));
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/widgets/app_nav_bar_test.dart`
Esperado: não compila — `Error: Method not found: 'TabSnackBarArea'.`

- [ ] **Step 3: Implementar**

Em `lib/ui/core/widgets/app_nav_bar.dart`, substituir:

```dart
/// As abas que têm tela. "Perfil" ainda não tem (Fase 8).
enum AppTab { sessions, sync }

/// A navbar do app, com os três itens e o destino de cada um — a mesma nas
```

por:

```dart
/// As abas que têm tela. "Perfil" ainda não tem (Fase 8).
enum AppTab { sessions, sync }

/// Em volta do `Scaffold` de uma aba: no tablet com a pílula na base, o aviso
/// passageiro (SnackBar) flutua acima dela, em vez de cobri-la (decisão de
/// 23/10/2026). O `Theme` fica sempre na árvore — girar não pode recriar o
/// `Scaffold` de dentro.
class TabSnackBarArea extends StatelessWidget {
  const TabSnackBarArea({super.key, required this.child});

  final Widget child;

  /// Folga entre o aviso e a pílula.
  static const double gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!context.isTablet || context.isExpandedLayout) {
      return Theme(data: theme, child: child);
    }

    final side = TabletNavFrame.sideFor(MediaQuery.sizeOf(context).width);
    return Theme(
      data: theme.copyWith(
        snackBarTheme: theme.snackBarTheme.copyWith(
          behavior: SnackBarBehavior.floating,
          insetPadding: EdgeInsets.fromLTRB(
            side,
            0,
            side,
            TabletNavFrame.bottomInset + gap,
          ),
        ),
      ),
      child: child,
    );
  }
}

/// A navbar do app, com os três itens e o destino de cada um — a mesma nas
```

Em `lib/ui/core/widgets/app_nav_bar.dart`, substituir:

```dart
  static const double bottomSide = 120;

  @override
  Widget build(BuildContext context) {
```

por:

```dart
  static const double bottomSide = 120;

  /// Recuo da pílula às laterais numa janela de [width]: 120, ou os 16 do
  /// celular numa janela mais estreita que 600 (tela dividida).
  static double sideFor(double width) =>
      width >= AppBreakpoints.tabletShortestSide ? bottomSide : AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
```

Em `lib/ui/core/widgets/app_nav_bar.dart`, substituir:

```dart
    final width = MediaQuery.sizeOf(context).width;
    final side = width >= AppBreakpoints.tabletShortestSide
        ? bottomSide
        : AppSpacing.lg;
```

por:

```dart
    final side = sideFor(MediaQuery.sizeOf(context).width);
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
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
```

por:

```dart
    return TabSnackBarArea(
      child: Scaffold(
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
      ),
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: tablet
              ? TabletNavFrame(current: AppTab.sync, child: content)
              : content,
        ),
        bottomNavigationBar:
            tablet ? null : const AppNavBar(current: AppTab.sync),
```

por:

```dart
      child: TabSnackBarArea(
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: tablet
                ? TabletNavFrame(current: AppTab.sync, child: content)
                : content,
          ),
          bottomNavigationBar:
              tablet ? null : const AppNavBar(current: AppTab.sync),
        ),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/widgets/app_nav_bar_test.dart`
Esperado: `+9: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1007: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/widgets/app_nav_bar.dart apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart apps/mobile/simtc/lib/ui/sync/sync_screen.dart apps/mobile/simtc/test/ui/core/widgets/app_nav_bar_test.dart
git commit -m "feat(mobile): aviso passageiro acima da pilula no tablet"
```

---
## Task 9: Validação no emulador de tablet e no celular

O portão da fase, que só o usuário pode rodar. O tablet é conferido no **emulador** (o mesmo Pixel Tablet da 7A); o celular, no **aparelho físico**, para confirmar que nada piorou.

**Interfaces:**
- Consumes: o app inteiro, com as Tasks 1 a 8.
- Produces: o aval do usuário para planejar a Fase 8.

- [ ] **Step 1: Instalar e rodar no emulador**

Com o backend local rodando (`npm run dev:backend`) e o emulador ligado:

Run: `adb -s emulator-5554 reverse tcp:3001 tcp:3001` e depois, em `apps/mobile/simtc/`, `flutter run -d emulator-5554`
Esperado: o app abre na Abertura, em tela de tablet.

- [ ] **Step 2: Roteiro no tablet (emulador)**

Com um CONSULTANT que tenha um participante para avaliar, e depois com um ADMIN:

1. **Iniciar avaliação:** abrir um participante ainda não avaliado. Em paisagem, a mensagem, "O que será avaliado" e o "Iniciar avaliação" numa coluna centrada, com o botão no fim dela; girar para retrato: o botão vai para o rodapé, na largura toda.
2. **Checklist:** tocar em "Iniciar avaliação". Em paisagem, o "Finalizar avaliação" no cabeçalho, na linha do nome e da nota; os botões B/PM/M à direita de cada descrição. Em retrato, o cabeçalho em duas faixas (nome e "Finalizar" em cima, a nota embaixo).
3. **Girar no meio do checklist (o que reprova a fase):** marcar notas em categorias diferentes e **girar várias vezes, inclusive logo depois de tocar numa nota**: todas as marcações e a nota continuam.
4. **Conferir e finalizar:** em paisagem, uma coluna centrada com o "Confirmar" no fim, à esquerda; em retrato, o "Confirmar" no rodapé. Tocar numa categoria volta ao checklist nela.
5. **Resultado:** depois de confirmar, em paisagem a nota, o desempenho e o "Próximo participante" à esquerda e as infrações à direita; em retrato, uma coluna só, com o botão no rodapé. O "Próximo participante" volta ao detalhe.
6. **ADMIN — Adicionar participante:** no detalhe em paisagem, tocar no "adicionar": a janela abre à direita, por cima do lado a lado, e o botão fica marcado atrás do fundo escurecido. Preencher o nome, **girar algumas vezes**: a janela vai para o centro em retrato e volta, com o nome lá. Tocar no fundo: pergunta antes de descartar. Abrir o teclado em paisagem: a janela encolhe e dá para rolar até o "Adicionar participante".
7. **ADMIN — Dados do treinamento e Consultores:** o lápis e o ícone de pessoas abrem as janelas deles, com o botão marcado; salvar dados fecha a janela e atualiza o detalhe; em Consultores, adicionar e remover funcionam como no celular.
8. **Sem conexão** (desligar a rede do emulador): nas janelas, a faixa de sem conexão e o "Disponível quando houver conexão" embaixo do botão apagado.
9. **Aviso passageiro:** no tablet em retrato, com a lista à vista, algo que mostre um aviso (por exemplo, o "Perfil" da navbar, "Disponível em breve."): ele aparece acima da pílula, sem cobri-la.
10. **Tela dividida:** o checklist numa janela estreita fica como o do celular (botões embaixo da descrição, "Finalizar" no rodapé).

- [ ] **Step 3: Roteiro no celular (aparelho físico)**

Instalar no celular de sempre (`flutter run -d <id do celular>`) e conferir que o Iniciar avaliação, o checklist, o Conferir e finalizar, o Resultado e as três telas de admin estão como antes: telas cheias, os mesmos botões e rodapés, o checklist com os botões embaixo da descrição.

- [ ] **Step 4: Registrar o resultado**

Se tudo passar, acrescentar ao fim desta task a linha "**Validado em <data>: tablet no emulador e celular no aparelho físico; roteiro inteiro passou. Aval dado para planejar a Fase 8.**" e commitar:

```bash
git add apps/mobile/docs/superpowers/plans/2026-10-23-mobile-fase-7b-tablet-avaliacao-e-admin.md
git commit -m "docs(mobile): registra a validacao da fase 7b no emulador e no aparelho"
```

Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio, parar e perguntar.

---

## Pendências levadas para a Fase 8

- O Perfil (`4k`/`4v` no tablet) com o "Sair", e o item de roteiro herdado da Fase 2 ("sair e entrar com outro consultor não mostra a agenda do anterior"); as buscas (as lupas dos quadros `4c`, `4d` e `4e`).
- Os skeletons e estados de erro gerais e a revisão de acessibilidade, que agora incluem as janelas de admin (o leitor de tela anuncia o título da janela; o fundo escurecido tem o rótulo "Fechar").
