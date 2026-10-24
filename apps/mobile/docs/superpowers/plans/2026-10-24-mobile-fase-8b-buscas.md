# App Mobile SIMTC — Fase 8B: Buscas — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** As lupas do canvas passam a buscar: no detalhe da sessão, participantes por nome ou CPF; na Home, sessões pela empresa; em Consultores (ADMIN), consultores pelo nome. Tudo sobre o que já está no aparelho, sem rede.

**Architecture:** Três peças comuns, numa task só: as regras de comparação (`search_text.dart`: sem maiúscula nem acento, em qualquer parte do texto, e o começo do CPF contra os 6 dígitos que o aparelho já guarda), o estado da busca (`ListSearch`, um mixin das ViewModels — vive nelas para atravessar o giro e a ida a um resultado) e o campo com a lupa (`AppSearchButton` e `AppSearchField`, no Design System). Depois, uma task por tela: cada ViewModel ganha o `ListSearch` e filtra a própria lista; cada tela troca a faixa onde a lupa mora pelo campo. Nada muda no banco nem no backend.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · drift 2.31.0 (sem mudança de esquema) · mocktail (testes). Nenhuma dependência nova.

**Spec:** `apps/mobile/docs/superpowers/specs/2026-10-24-mobile-fase-8-design.md`, seção "8B — Buscas" (desenho aprovado em 24/10/2026); canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html`: as lupas dos quadros `2c` (Home, linha 774), `1e`/`1f` (detalhe, 904/994), `3c` (Consultores, 625) e, no tablet, `4c`, `4d`, `4e`. Nenhum quadro desenha o campo aberto nem o resultado.

**Validação prévia:** todo o código das Tasks 1 a 4 foi escrito e rodado numa cópia descartável do app antes de o plano ser fechado, uma task por commit, e depois as tasks foram **reencenadas em ordem** numa segunda cópia limpa, a partir dos blocos deste plano: em cada task, os testes da task falharam antes da implementação e passaram depois, e cada checkpoint bateu o número de testes — **1074 → 1091 → 1098 → 1104 → 1110**, com `flutter analyze` sem issues em todos; a árvore de cada task ficou **idêntica** à do commit correspondente. **Cada regra e cada medida foi conferida por mutação** (o trecho é trocado, e algum teste tem de falhar): **42 mutações, 40 acusadas**; as duas que sobreviveram são equivalentes — tirar `if (wanted.isEmpty) return true;` não muda nada (`"x".contains("")` já é verdadeiro), nem tirar a guarda do CPF desconhecido (`"".startsWith("042")` já é falso); ficam no código pela clareza. As telas foram **desenhadas com as fontes de verdade** — o detalhe, a Home e Consultores no celular (412×915 e a Home em 360×640 com fonte em 1,3x) e o lado a lado do tablet com a janela de Consultores — e conferidas a olho.

## Decisões tomadas com o usuário

Do desenho da 8B (24/10/2026):

1. **O que cada lupa busca:** detalhe da sessão — participantes, por **nome ou CPF**; Home — sessões, pela **empresa**; Consultores da sessão (ADMIN) — consultores, pelo **nome**.
2. **Como a busca abre (como o canvas desenha):** tocar na lupa troca a faixa onde ela mora por um campo de busca, com o teclado aberto; a lista filtra enquanto se digita; o X fecha a busca e a tela volta ao que era.
   - **Detalhe:** o campo toma o lugar da barra dos filtros; a busca procura em **todos** os participantes, ignorando o chip marcado; ao fechar, o chip de antes volta; embaixo da lista, "N de M participantes".
   - **Home:** o campo toma o lugar da saudação e do título, e os chips saem; as três seções continuam, só com as sessões da empresa buscada.
   - **Consultores:** o campo abre embaixo do cabeçalho e filtra as duas listas.
3. **CPF: comparar os primeiros dígitos digitados com os 6 que o aparelho já guarda** (`maskCpf`: `123.456.***-**`). Com 6 ou mais (inclusive o CPF inteiro, que o participante dita), compara os 6 primeiros; com menos, o começo. **Nada novo é guardado.** (A "impressão" do CPF inteiro foi descartada: somada aos 6 dígitos, deixaria só ~1.000 combinações.)
4. **Regras mostradas no navegador e aceitas:** sem maiúscula nem acento ("jose" acha "José"); o trecho em qualquer parte ("ana" acha "Mariana"); no CPF só os dígitos contam (com ou sem máscara) e texto com letras é busca por nome; sem resultado, "Nenhum participante encontrado para “xyz”." (e "Nenhuma sessão…", "Nenhum consultor…"); funciona sem rede; no tablet, o mesmo jeito em cada painel.
5. **Escolhas depois da revisão do desenho (aceitas):** na Home, a linha do logo e do indicador de envio continua em cima e o X fica dentro do campo; durante a busca, a seção (Home) ou a lista (Consultores) sem resultado some com o título, e se tudo ficar vazio aparece a frase; em Consultores, os avisos próprios da equipe (sem conexão, todos já na sessão) vencem a busca; o texto vive na ViewModel — continua ao abrir um resultado e voltar e ao girar o tablet; trocar de aba fecha a busca.

### Ajustes feitos ao preparar o plano (revisar junto com o plano)

A validação na cópia descartável levou a estas escolhas. **Nenhuma muda regra aprovada**, mas cada uma é um texto, uma regra de tela ou uma medida que o código cria — o canvas não desenha o campo.

**O campo (sem quadro no canvas):** 48 de altura, canto 12, contorno de 1,5 na cor da marca (sempre, não só com o foco), fundo branco; a lupa de 20 em cinza à esquerda; o texto em 16 (`AppTypography.fieldValue`) e o exemplo em cinza-claro; à direita, o X de 20 em cinza (rótulo "Fechar a busca"). Abre com o teclado à mostra.

**Textos novos:** os exemplos dos campos — "Buscar por nome ou CPF" (detalhe), "Buscar pela empresa" (Home) e "Buscar consultor pelo nome" (Consultores); o rótulo da lupa para o leitor de tela, "Buscar"; a contagem "2 de 18 participantes" (singular "participante" quando a sessão tem um só).

**Regras que o código cria:**

- **Aberta e vazia, a busca não filtra:** a lista é a de sempre — com uma exceção no detalhe: como os chips saem de cena, aparecem todos os participantes (sem a contagem).
- **Na Home, a busca mostra todas as sessões que batem**, sem o "Ver mais" de 10 em 10; e a lupa some enquanto o campo está aberto (o X dele fecha).
- **O voltar com a busca aberta fecha a busca** no celular (Home e detalhe) e em Consultores (celular e janela do tablet). Vale para o voltar do Android, para a seta da barra de cima e para o X da janela de Consultores: o primeiro toque fecha a busca, o segundo fecha a tela. **No lado a lado do tablet** (lista e detalhe), o voltar continua fechando a sessão aberta, e a busca fica como estava.

**Medidas:**

- **Detalhe:** a lupa fica na ponta direita da barra dos filtros, com 48 de alvo e ícone de 19 (o quadro desenha uma caixa de 36), com o ícone alinhado à margem, como o "adicionar participante"; os chips rolam por baixo dela. O campo ocupa a barra inteira, na mesma altura dela (54), sem a lista pular.
- **Home:** a lupa, com 48 de alvo e ícone de 22, a 4 do indicador de envio (como o quadro `2c`).
- **Consultores, no celular:** a lupa no lugar da direita da barra de cima (como o quadro `3c`); o campo embaixo da barra, com o recuo da lista e 8 em cima e embaixo.
- **Consultores, no tablet:** **a lupa entra no cabeçalho da janela, ao lado do X** — os quadros `4n` e `4y` não a desenham; o campo abre embaixo do cabeçalho, acima dos avisos.

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app`. Sem git worktree. Não criar branch, não fazer merge, não fazer push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada, com a mensagem exata dada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem trabalho do usuário fora do git, que **não é desta fase e fica exatamente como está**: um arquivo rastreado **já modificado** (`brainstorm-app-mobile.md`) e os não rastreados `.vscode/`, `IMPLEMENTATION-STATUS.md`, `apps/backend/test-render.js`, `apps/mobile/simtc/devtools_options.yaml`, `apps/web/src/app/(client)/my-company/trainings/[id]/certificates/`, `brainstorm-implementacao-mobile.md`, `prompt-claude-design-mobile.md`, `prompt-implementacao-mobile-claude-code.md`, `test-pdf.js` e `test-render.js`.
- **Proibido `git restore`, `git checkout -- <arquivo>`, `git stash`, `git reset` e `git clean`**, e qualquer outro comando que desfaça mudança que não é da task. Se o `git status` mostrar algo que não é da task, ignorar e seguir.
- **Na execução por subagentes:** antes do primeiro despacho, guardar a linha de base — o `git status --porcelain` inteiro e o `git hash-object brainstorm-app-mobile.md` — e compará-la, sem filtrar nada, depois de **cada** subagente. Todo despacho repete as duas regras acima com todas as letras. Implementadores em **haiku**; revisões em **sonnet** (as quatro tasks são de tela e de regra simples, sem concorrência).
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-10-24-mobile-fase-8b-buscas/`.

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

Os casos que o desenho implica, que um consultor (ou o admin) vai encontrar em campo, e onde cada um ficou preso num teste:

1. **O participante dita o CPF inteiro, com ou sem pontos** → a busca acha pelos 6 primeiros dígitos. Preso em: `pelo CPF: com o CPF inteiro, compara os 6 primeiros dígitos; com menos, o começo` (Task 2) e no grupo `matchesCpfStart` (Task 1).
2. **Nome digitado sem acento ou em maiúscula** ("JOSE", "jose antonio") → acha "José Antônio". Preso em: `procura em todos, ignorando o chip, pelo nome sem acento nem maiúscula, e diz quantos achou` (Task 2) e `filtra pela empresa, sem acento nem maiúscula; a seção sem resultado some` (Task 3).
3. **O voltar do Android com a busca aberta, no celular** → fecha a busca e fica na tela. Preso em: `no celular, o voltar com a busca aberta fecha a busca e fica na tela` (Task 2), `no celular, o voltar com a busca aberta fecha a busca` (Task 3) e `o voltar com a busca aberta fecha a busca e fica na tela` (Task 4).
4. **Girar o tablet com o texto digitado na janela de Consultores** → o texto e o resultado continuam. Preso em: `na janela de consultores, a lupa fica ao lado do X e abre o campo embaixo do cabeçalho; o texto atravessa o giro` (Task 4).
5. **Uma busca que não acha nada** → uma frase diz que não achou, e as seções/listas vazias somem. Preso em: `sem resultado, diz que não achou` (Tasks 2 e 3) e `sem ninguém nas duas, diz que não achou` (Task 4).

## Estado herdado (ponto de partida)

HEAD = o commit deste plano, sobre `0bf9c94` (o desenho da 8B). App: `flutter analyze` limpo; **1074 testes passando**.

Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| Tirar acento e maiúscula | `lib/ui/core/name_sort.dart` | `nameSortKey(String)` |
| CPF guardado | `lib/data/models/session_participant.dart` | `maskCpf` → `123.456.***-**`; `SessionParticipant.maskedCpf` |
| Chips do detalhe | `lib/ui/session_detail/participant_filter.dart`, `lib/ui/core/widgets/filter_chip_bar.dart` | `ParticipantFilter`, `matchesFilter`, `FilterChipBar(horizontalPadding:)` |
| Seções da Home | `lib/ui/sessions/session_filter.dart` | `buildSections(sessions, now, visibleCounts)`, `SessionBlockId`, `SessionSection.isEmpty` |
| Barra de cima | `lib/ui/core/widgets/app_top_bar.dart` | `AppTopBar(title:, actions:, trailing:)`; a seta usa `Navigator.maybePop` |
| Janela de admin | `lib/ui/core/widgets/admin_dialog.dart` | `AdminDialogFrame(title:, subtitle:, onClose:, body:, banner:, footer:)` |
| Testes | `test/ui/…` | `session_detail_screen_test.dart` (`show`, `participant`), `sessions_screen_test.dart` (`pump`, `sessions`), `session_consultants_screen_test.dart` (`seedFromServer`, `pumpScreen`, `rowOf`, `serverUnreachable`, `goOffline`), `sessions_split_view_test.dart` (`pumpApp`, `rotate`, `settle`, `dialog`) |

## Mapa de Arquivos

### Novos

| Arquivo | Task | Responsabilidade |
|---|---|---|
| `lib/ui/core/search_text.dart` | 1 | `containsSearch`, `cpfSearchDigits`, `matchesCpfStart`, `knownCpfDigits` |
| `lib/ui/core/list_search.dart` | 1 | o mixin `ListSearch` (estado da busca nas ViewModels) |
| `lib/ui/core/widgets/app_search_field.dart` | 1 | `AppSearchButton` (a lupa) e `AppSearchField` (o campo) |

### Modificados

| Arquivo | Task | O que muda |
|---|---|---|
| `lib/ui/session_detail/participant_filter.dart`, `session_detail_viewmodel.dart`, `session_detail_screen.dart` | 2 | `matchesSearch`; `ListSearch`, `visibleParticipants`, `searchCountLabel`; a lupa na barra e o campo |
| `lib/ui/sessions/sessions_list_viewmodel.dart`, `sessions_screen.dart` | 3 | `ListSearch` e as seções filtradas; a lupa e o campo no cabeçalho |
| `lib/ui/session_consultants/session_consultants_viewmodel.dart`, `session_consultants_screen.dart`, `lib/ui/core/widgets/admin_dialog.dart` | 4 | `ListSearch` e as listas filtradas; a lupa e o campo; `AdminDialogFrame.actions` |
| testes existentes | 2–4 | `session_detail_screen_test.dart`, `sessions_screen_test.dart`, `session_consultants_screen_test.dart`, `sessions_split_view_test.dart` |

---


## Task 1: Regras, estado e campo da busca

As peças que as três telas usam. As regras de comparação: sem maiúscula nem acento, o trecho em qualquer parte do texto, e o CPF pelo começo — com 6 ou mais dígitos digitados (inclusive o CPF inteiro), compara os 6 primeiros, que são os que o aparelho guarda; com menos, o começo (decisão 3). O estado da busca, num mixin das ViewModels (`ListSearch`). E, no Design System, a lupa (`AppSearchButton`) e o campo (`AppSearchField`, ver "Ajustes").

**Files:**
- Create: `lib/ui/core/list_search.dart`
- Create: `lib/ui/core/search_text.dart`
- Create: `lib/ui/core/widgets/app_search_field.dart`
- Create: `test/ui/core/search_text_test.dart`
- Create: `test/ui/core/widgets/app_search_field_test.dart`

**Interfaces:**
- Consumes: `nameSortKey` (`lib/ui/core/name_sort.dart`).
- Produces:
  - `containsSearch(String text, String query) → bool`, `cpfSearchDigits(String query) → String?`, `matchesCpfStart(String maskedCpf, String digits) → bool` e `knownCpfDigits` (6) em `lib/ui/core/search_text.dart`
  - `mixin ListSearch on ChangeNotifier`: `isSearching`, `searchQuery`, `isFiltering`, `openSearch()`, `setSearchQuery(String)`, `closeSearch()` em `lib/ui/core/list_search.dart`
  - `AppSearchButton({onPressed, iconSize = 22})` com `AppSearchButton.filtersIconSize` (19) e `AppSearchField({hintText, onChanged, onClose, initialText = ''})` em `lib/ui/core/widgets/app_search_field.dart`

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/core/search_text_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/list_search.dart';
import 'package:simtc/ui/core/search_text.dart';

class _List extends ChangeNotifier with ListSearch {}

void main() {
  group('containsSearch', () {
    test('não diferencia maiúscula nem acento', () {
      expect(containsSearch('José Antônio', 'jose'), isTrue);
      expect(containsSearch('JOSE ANTONIO', 'antônio'), isTrue);
      expect(containsSearch('Ângela', 'ANGELA'), isTrue);
    });

    test('acha o trecho em qualquer parte do texto', () {
      expect(containsSearch('Mariana Costa', 'ana'), isTrue);
      expect(containsSearch('Bracell Celulose', 'celul'), isTrue);
      expect(containsSearch('Bracell Celulose', 'suzano'), isFalse);
    });

    test('busca vazia ou só com espaços acha tudo', () {
      expect(containsSearch('Bracell', ''), isTrue);
      expect(containsSearch('Bracell', '   '), isTrue);
    });

    test('os espaços das pontas da busca não contam', () {
      expect(containsSearch('Ana Paula', ' ana '), isTrue);
    });
  });

  group('cpfSearchDigits', () {
    test('só dígitos, com ou sem máscara, é busca por CPF', () {
      expect(cpfSearchDigits('042'), '042');
      expect(cpfSearchDigits('042.118.990-01'), '04211899001');
      expect(cpfSearchDigits(' 042 118 '), '042118');
    });

    test('com letras é busca por nome', () {
      expect(cpfSearchDigits('ana 042'), isNull);
      expect(cpfSearchDigits('Ana'), isNull);
    });

    test('sem nenhum dígito não é CPF', () {
      expect(cpfSearchDigits(''), isNull);
      expect(cpfSearchDigits('.-'), isNull);
    });
  });

  group('matchesCpfStart', () {
    const stored = '042.118.***-**';

    test('com menos de 6 dígitos compara o começo', () {
      expect(matchesCpfStart(stored, '0'), isTrue);
      expect(matchesCpfStart(stored, '04211'), isTrue);
      expect(matchesCpfStart(stored, '04212'), isFalse);
      expect(matchesCpfStart(stored, '118'), isFalse);
    });

    test('com 6 ou mais (inclusive o CPF inteiro) compara os 6 primeiros', () {
      expect(matchesCpfStart(stored, '042118'), isTrue);
      expect(matchesCpfStart(stored, '04211899001'), isTrue);
      expect(matchesCpfStart(stored, '04211812345'), isTrue);
      expect(matchesCpfStart(stored, '04211999001'), isFalse);
    });

    test('um CPF que o aparelho não conhece nunca é achado', () {
      expect(matchesCpfStart('***.***.***-**', '042'), isFalse);
    });

    test('o aparelho guarda 6 dígitos', () {
      expect(knownCpfDigits, 6);
    });
  });

  group('ListSearch', () {
    test('a lupa abre, o texto filtra, o X fecha e esquece o texto', () {
      final list = _List();
      var notified = 0;
      list.addListener(() => notified++);

      expect(list.isSearching, isFalse);
      expect(list.isFiltering, isFalse);

      list.openSearch();
      expect(list.isSearching, isTrue);
      expect(list.isFiltering, isFalse, reason: 'aberta e vazia, sem filtro');

      list.setSearchQuery('ana');
      expect(list.searchQuery, 'ana');
      expect(list.isFiltering, isTrue);

      list.setSearchQuery('   ');
      expect(list.isFiltering, isFalse, reason: 'só espaços não filtra');

      list.setSearchQuery('ana');
      list.closeSearch();
      expect(list.isSearching, isFalse);
      expect(list.searchQuery, '');
      expect(list.isFiltering, isFalse);
      expect(notified, 5);
    });

    test('repetir o mesmo passo não avisa de novo', () {
      final list = _List()..openSearch()..setSearchQuery('a');
      var notified = 0;
      list.addListener(() => notified++);

      list.openSearch();
      list.setSearchQuery('a');
      expect(notified, 0);

      list.closeSearch();
      list.closeSearch();
      expect(notified, 1);
    });
  });
}
```

Criar `test/ui/core/widgets/app_search_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/widgets/app_search_field.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
  }

  group('AppSearchButton', () {
    testWidgets('alvo de 48 com a lupa cinza e o rótulo "Buscar"', (tester) async {
      var taps = 0;
      await pump(tester, AppSearchButton(onPressed: () => taps++));

      expect(tester.getSize(find.byType(AppSearchButton)), const Size(48, 48));
      final icon = tester.widget<Icon>(find.byIcon(AppIcons.search));
      expect(icon.size, 22);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).color,
        AppColors.text3,
      );
      expect(find.byTooltip('Buscar'), findsOneWidget);

      await tester.tap(find.byType(AppSearchButton));
      expect(taps, 1);
    });

    testWidgets('na barra dos filtros, o ícone tem 19', (tester) async {
      await pump(
        tester,
        AppSearchButton(
          onPressed: () {},
          iconSize: AppSearchButton.filtersIconSize,
        ),
      );

      expect(tester.widget<Icon>(find.byIcon(AppIcons.search)).size, 19);
    });
  });

  group('AppSearchField', () {
    testWidgets('48 de altura, abre com o foco e começa com o texto dado',
        (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: AppSearchField(
            hintText: 'Buscar pela empresa',
            initialText: 'brac',
            onChanged: (_) {},
            onClose: () {},
          ),
        ),
      );

      expect(tester.getSize(find.byType(AppSearchField)).height, 48);
      expect(tester.getSize(find.byType(TextField)).height, 48);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
      expect(field.controller!.text, 'brac');
      expect(field.decoration!.hintText, 'Buscar pela empresa');
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isTrue,
      );
    });

    testWidgets('cada letra avisa o texto; o X fecha a busca', (tester) async {
      final changes = <String>[];
      var closes = 0;
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: AppSearchField(
            hintText: 'Buscar por nome ou CPF',
            onChanged: changes.add,
            onClose: () => closes++,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ana');
      expect(changes.last, 'ana');

      await tester.tap(find.byTooltip('Fechar a busca'));
      expect(closes, 1);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/search_text_test.dart test/ui/core/widgets/app_search_field_test.dart`
Esperado: `Some tests failed.` — `search_text_test.dart` e `app_search_field_test.dart` não compilam (`search_text.dart`, `list_search.dart` e `app_search_field.dart` não existem).

- [ ] **Step 3: Implementar**

Criar `lib/ui/core/list_search.dart`:

```dart
import 'package:flutter/foundation.dart';

/// O estado da busca de uma lista (Fase 8B), para a ViewModel da tela: a
/// lupa abre o campo, o texto filtra, o X fecha e limpa. Vive na ViewModel
/// para atravessar o giro do tablet e a ida a um resultado e a volta.
mixin ListSearch on ChangeNotifier {
  bool _searching = false;
  String _query = '';

  /// O campo de busca está aberto (no lugar da faixa onde mora a lupa).
  bool get isSearching => _searching;

  String get searchQuery => _query;

  /// A lista está filtrada: o campo está aberto e tem algum texto. Aberto e
  /// vazio, a lista é a de sempre.
  bool get isFiltering => _searching && _query.trim().isNotEmpty;

  void openSearch() {
    if (_searching) return;
    _searching = true;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  /// O X do campo: fecha a busca e esquece o texto.
  void closeSearch() {
    if (!_searching && _query.isEmpty) return;
    _searching = false;
    _query = '';
    notifyListeners();
  }
}
```

Criar `lib/ui/core/search_text.dart`:

```dart
import 'name_sort.dart';

/// As regras da busca local das listas (Fase 8B): sem diferença de
/// maiúscula nem de acento, e o trecho em qualquer parte do texto — "jose"
/// acha "José", "ana" acha "Mariana". Busca vazia acha tudo.
bool containsSearch(String text, String query) {
  final wanted = nameSortKey(query.trim());
  if (wanted.isEmpty) return true;
  return nameSortKey(text).contains(wanted);
}

/// Só dígitos, pontos, traço e espaços: o jeito de digitar um CPF.
final RegExp _cpfLike = RegExp(r'^[\d.\-\s]+$');

/// Os dígitos de uma busca que é um CPF (com ou sem máscara); nulo quando
/// ela tem letras — aí é busca por nome.
String? cpfSearchDigits(String query) {
  final trimmed = query.trim();
  if (!_cpfLike.hasMatch(trimmed)) return null;
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty ? null : digits;
}

/// Quantos dígitos do CPF o aparelho guarda (`maskCpf`: `123.456.***-**`).
const int knownCpfDigits = 6;

/// O começo do CPF: o aparelho só guarda os 6 primeiros dígitos (decisão de
/// 24/10/2026 — nada novo é guardado). Com 6 ou mais digitados, inclusive o
/// CPF inteiro que o participante dita, compara os 6 primeiros; com menos,
/// compara o começo. Um CPF que o aparelho não conhece (`***.***.***-**`)
/// nunca é achado.
bool matchesCpfStart(String maskedCpf, String digits) {
  final known = maskedCpf.replaceAll(RegExp(r'\D'), '');
  if (known.length < knownCpfDigits) return false;
  final wanted = digits.length > knownCpfDigits
      ? digits.substring(0, knownCpfDigits)
      : digits;
  return known.startsWith(wanted);
}
```

Criar `lib/ui/core/widgets/app_search_field.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A lupa das listas (canvas "2c", "1e"/"1f" e "3c"): um alvo de 48 com o
/// ícone em cinza. O detalhe da sessão a desenha com ícone de 19, ao lado dos
/// filtros; a Home e Consultores, com 22.
class AppSearchButton extends StatelessWidget {
  const AppSearchButton({
    super.key,
    required this.onPressed,
    this.iconSize = defaultIconSize,
  });

  final VoidCallback onPressed;
  final double iconSize;

  static const double defaultIconSize = 22;

  /// O tamanho do ícone na barra dos filtros do detalhe (quadros "1e", "1f").
  static const double filtersIconSize = 19;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.touchTarget,
      child: IconButton(
        tooltip: 'Buscar',
        icon: Icon(AppIcons.search, size: iconSize),
        color: AppColors.text3,
        onPressed: onPressed,
      ),
    );
  }
}

/// O campo que a lupa abre (Fase 8B — o canvas só desenha a lupa): o ícone de
/// busca, o texto e o X que fecha a busca. Tem 48 de altura e abre com o
/// teclado à mostra. Guarda o próprio texto: começa com [initialText] e avisa
/// cada mudança em [onChanged].
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    required this.onClose,
    this.initialText = '',
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final String initialText;

  static const double _iconSize = 20;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    );

    return SizedBox(
      height: AppSpacing.touchTarget,
      child: TextField(
        controller: _controller,
        autofocus: true,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: AppTypography.fieldValue,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTypography.fieldValue.copyWith(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surface,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
          prefixIcon: const Icon(
            AppIcons.search,
            size: AppSearchField._iconSize,
            color: AppColors.text3,
          ),
          suffixIcon: IconButton(
            tooltip: 'Fechar a busca',
            icon: const Icon(AppIcons.close, size: AppSearchField._iconSize),
            color: AppColors.text3,
            onPressed: widget.onClose,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/search_text_test.dart test/ui/core/widgets/app_search_field_test.dart`
Esperado: `+17: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1091: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/list_search.dart apps/mobile/simtc/lib/ui/core/search_text.dart apps/mobile/simtc/lib/ui/core/widgets/app_search_field.dart apps/mobile/simtc/test/ui/core/search_text_test.dart apps/mobile/simtc/test/ui/core/widgets/app_search_field_test.dart
git commit -m "feat(mobile): regras e campo da busca local"
```

---

## Task 2: Busca de participantes no detalhe da sessão

A lupa entra na ponta direita da barra dos filtros (quadros `1e`/`1f`). Tocando nela, o campo toma o lugar da barra, na mesma altura; a lista passa a ser a de todos os participantes, filtrada por nome ou pelo começo do CPF, com "N de M participantes" embaixo; o X fecha e o chip de antes volta. No celular, o voltar com a busca aberta fecha a busca (ver "Ajustes").

**Files:**
- Modify: `lib/ui/session_detail/participant_filter.dart`
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Modify: `lib/ui/session_detail/session_detail_viewmodel.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`

**Interfaces:**
- Consumes: `ListSearch`, `containsSearch`, `cpfSearchDigits`, `matchesCpfStart`, `AppSearchButton`, `AppSearchField` (Task 1).
- Produces:
  - `matchesSearch(SessionParticipant, String query) → bool` em `participant_filter.dart`
  - `SessionDetailViewModel` com `ListSearch` e `searchCountLabel → String?`
  - `Key('participants-filter-bar')` na barra dos filtros

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_top_bar.dart';
import 'package:simtc/ui/core/widgets/company_logo.dart';
```

por:

```dart
import 'package:simtc/ui/core/theme/app_spacing.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_search_field.dart';
import 'package:simtc/ui/core/widgets/app_top_bar.dart';
import 'package:simtc/ui/core/widgets/company_logo.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
  }) {
    return SessionParticipant(
      id: id,
      sessionId: 'sess-1',
      name: name,
      maskedCpf: '042.118.***-**',
```

por:

```dart
    String cpf = '042.118.***-**',
  }) {
    return SessionParticipant(
      id: id,
      sessionId: 'sess-1',
      name: name,
      maskedCpf: cpf,
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
    expect(find.text('Carlos Eduardo Nunes'), findsNothing);
  });
```

por:

```dart
    expect(find.text('Carlos Eduardo Nunes'), findsNothing);
  });

  group('busca de participantes (Fase 8B)', () {
    List<SessionParticipant> turma() => [
          participant('1', 'Ana Paula Ribeiro', cpf: '042.118.***-**'),
          participant('2', 'Mariana Costa',
              status: ParticipantStatus.aprovado,
              score: 90,
              cpf: '311.902.***-**'),
          participant('3', 'José Antônio Lima', cpf: '555.123.***-**'),
        ];

    Future<void> openSearch(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pump();
    }

    testWidgets(
        'a lupa na ponta da barra abre o campo no lugar dos chips, na mesma '
        'altura; o X fecha e o filtro de antes volta', (tester) async {
      await show(tester, withParticipants: turma());
      await tester.tap(find.widgetWithText(InkWell, 'Pendentes'));
      await tester.pump();
      final bar = find.byKey(const Key('participants-filter-bar'));
      final barHeight = tester.getSize(bar).height;
      expect(
        tester.getRect(find.byTooltip('Buscar')).right,
        420 - (AppSpacing.xl - AppSpacing.md),
      );

      await openSearch(tester);

      expect(find.byType(FilterChipBar), findsNothing);
      expect(find.byType(AppSearchField), findsOneWidget);
      expect(find.text('Buscar por nome ou CPF'), findsOneWidget);
      expect(tester.getSize(bar).height, barHeight);
      expect(barHeight, 54 + 1);

      await tester.tap(find.byTooltip('Fechar a busca'));
      await tester.pump();

      expect(find.byType(AppSearchField), findsNothing);
      expect(find.byType(FilterChipBar), findsOneWidget);
      expect(find.text('Mariana Costa'), findsNothing,
          reason: 'o filtro "Pendentes" voltou');
      expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
    });

    testWidgets(
        'procura em todos, ignorando o chip, pelo nome sem acento nem '
        'maiúscula, e diz quantos achou', (tester) async {
      await show(tester, withParticipants: turma());
      await tester.tap(find.widgetWithText(InkWell, 'Pendentes'));
      await tester.pump();
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), 'ANA');
      await tester.pump();

      expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
      expect(find.text('Mariana Costa'), findsOneWidget,
          reason: 'aprovada, fora do chip "Pendentes", aparece na busca');
      expect(find.text('José Antônio Lima'), findsNothing);
      expect(find.text('2 de 3 participantes'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'jose antonio');
      await tester.pump();

      expect(find.text('José Antônio Lima'), findsOneWidget);
      expect(find.text('1 de 3 participantes'), findsOneWidget);
    });

    testWidgets('aberta e vazia, mostra todos, sem a contagem', (tester) async {
      await show(tester, withParticipants: turma());
      await tester.tap(find.widgetWithText(InkWell, 'Pendentes'));
      await tester.pump();
      await openSearch(tester);

      expect(find.text('Mariana Costa'), findsOneWidget);
      expect(find.text('3 de 3 participantes'), findsNothing);
    });

    testWidgets(
        'pelo CPF: com o CPF inteiro, compara os 6 primeiros dígitos; com '
        'menos, o começo', (tester) async {
      await show(tester, withParticipants: turma());
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), '311.902.555-01');
      await tester.pump();
      expect(find.text('Mariana Costa'), findsOneWidget);
      expect(find.text('Ana Paula Ribeiro'), findsNothing);
      expect(find.text('José Antônio Lima'), findsNothing);

      await tester.enterText(find.byType(TextField), '04');
      await tester.pump();
      expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
      expect(find.text('Mariana Costa'), findsNothing);
    });

    testWidgets('sem resultado, diz que não achou', (tester) async {
      await show(tester, withParticipants: turma());
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), ' xyz ');
      await tester.pump();

      expect(
        find.text('Nenhum participante encontrado para “xyz”.'),
        findsOneWidget,
      );
      expect(find.text('0 de 3 participantes'), findsOneWidget);
    });

    testWidgets(
        'no celular, o voltar com a busca aberta fecha a busca e fica na tela',
        (tester) async {
      await show(tester, withParticipants: turma());
      await openSearch(tester);
      await tester.enterText(find.byType(TextField), 'ana');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.byType(AppSearchField), findsNothing);
      expect(find.byType(FilterChipBar), findsOneWidget);
      expect(find.byType(SessionDetailScreen), findsOneWidget);
      expect(find.text('José Antônio Lima'), findsOneWidget);
    });

    testWidgets('o texto continua quando a lista se atualiza',
        (tester) async {
      await show(tester, withParticipants: turma());
      await openSearch(tester);
      await tester.enterText(find.byType(TextField), 'mari');
      await tester.pump();

      participantsStream.add(turma());
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'mari',
      );
      expect(find.text('Mariana Costa'), findsOneWidget);
      expect(find.text('Ana Paula Ribeiro'), findsNothing);
    });
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_detail/session_detail_screen_test.dart`
Esperado: `+58 -7: Some tests failed.` — os sete testes do grupo `busca de participantes (Fase 8B)` falham: não há a lupa (`find.byTooltip('Buscar')` não acha nada).

- [ ] **Step 3: Implementar**

Em `lib/ui/session_detail/participant_filter.dart`, substituir:

```dart
import '../core/name_sort.dart';
import '../core/score_labels.dart';

/// Os quatro chips da tela 1.4. Aqui eles filtram de verdade (o canvas tem
```

por:

```dart
import '../core/name_sort.dart';
import '../core/score_labels.dart';
import '../core/search_text.dart';

/// Os quatro chips da tela 1.4. Aqui eles filtram de verdade (o canvas tem
```

Em `lib/ui/session_detail/participant_filter.dart`, substituir:

```dart
    situation == ParticipantSituation.approved ||
    situation == ParticipantSituation.needsReview;

/// Regra dos chips (decidida com o usuário em 23/09/2026):
```

por:

```dart
    situation == ParticipantSituation.approved ||
    situation == ParticipantSituation.needsReview;

/// A busca do detalhe (Fase 8B): pelo nome, ou pelo começo do CPF quando o
/// texto é só de dígitos — o aparelho guarda só os 6 primeiros.
bool matchesSearch(SessionParticipant participant, String query) {
  final digits = cpfSearchDigits(query);
  return digits == null
      ? containsSearch(participant.name, query)
      : matchesCpfStart(participant.maskedCpf, digits);
}

/// Regra dos chips (decidida com o usuário em 23/09/2026):
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_top_bar.dart';
```

por:

```dart
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_search_field.dart';
import '../core/widgets/app_top_bar.dart';
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return Scaffold(
      backgroundColor: AppColors.surface,
```

por:

```dart
    final isOffline = context.watch<ConnectivityService>().isOffline;

    // No celular, o voltar (o do Android e a seta da barra) fecha a busca
    // antes de sair da tela. No tablet o detalhe é um painel do lado a lado,
    // e o voltar segue fechando a sessão.
    return PopScope(
      canPop: context.isTablet || !_viewModel.isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _viewModel.isSearching) _viewModel.closeSearch();
      },
      child: _buildPage(context, isOffline),
    );
  }

  Widget _buildPage(BuildContext context, bool isOffline) {
    return Scaffold(
      backgroundColor: AppColors.surface,
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
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
        horizontalPadding: _inset,
```

por:

```dart
  /// A barra dos filtros, com a lupa na ponta direita (quadros "1e" e "1f").
  /// Com a busca aberta, o campo toma o lugar dela, na mesma altura: 54, os
  /// 34 de um chip mais 10 em cima e embaixo.
  Widget _buildFilters() {
    return Container(
      key: const Key('participants-filter-bar'),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: _viewModel.isSearching ? _buildSearchField() : _buildChips(),
    );
  }

  /// Os 3 que sobram dos 54 da barra em volta do campo de 48.
  static const double _searchBarPadding = AppSpacing.xs - 1;

  Widget _buildChips() {
    final counts = _viewModel.counts;

    return Row(
      children: [
        Expanded(
          child: FilterChipBar(
            items: [
              for (final filter in ParticipantFilter.values)
                FilterChipData(label: filter.label, count: counts[filter]),
            ],
            selectedIndex: ParticipantFilter.values.indexOf(_viewModel.filter),
            onSelect: (index) =>
                _viewModel.setFilter(ParticipantFilter.values[index]),
            horizontalPadding: _inset,
          ),
        ),
        // O ícone, e não o alvo de toque, fica alinhado com a margem.
        Padding(
          padding: EdgeInsets.only(right: _inset - AppSpacing.md),
          child: AppSearchButton(
            iconSize: AppSearchButton.filtersIconSize,
            onPressed: _viewModel.openSearch,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _inset,
        vertical: _searchBarPadding,
      ),
      child: AppSearchField(
        hintText: 'Buscar por nome ou CPF',
        initialText: _viewModel.searchQuery,
        onChanged: _viewModel.setSearchQuery,
        onClose: _viewModel.closeSearch,
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
              _buildParticipant(participant, isOffline),
        ],
```

por:

```dart
              _buildParticipant(participant, isOffline),
          if (_viewModel.searchCountLabel case final label?)
            Padding(
              padding: EdgeInsets.fromLTRB(_inset, AppSpacing.md, _inset, 0),
              child: Text(label, style: AppTypography.meta),
            ),
        ],
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
    final message = !_viewModel.hasParticipants
        ? 'Nenhum participante inscrito nesta sessão.'
```

por:

```dart
    final query = _viewModel.searchQuery.trim();
    final message = !_viewModel.hasParticipants
        ? 'Nenhum participante inscrito nesta sessão.'
        : _viewModel.isFiltering
        ? 'Nenhum participante encontrado para “$query”.'
```

Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:

```dart
import '../../utils/result.dart';
import 'participant_filter.dart';
```

por:

```dart
import '../../utils/result.dart';
import '../core/list_search.dart';
import 'participant_filter.dart';
```

Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:

```dart
class SessionDetailViewModel extends ChangeNotifier {
```

por:

```dart
class SessionDetailViewModel extends ChangeNotifier with ListSearch {
```

Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:

```dart
  /// A lista do chip escolhido, na ordem do canvas.
  List<SessionParticipant> get visibleParticipants => sortForDisplay(
        _participants
            .where((p) => matchesFilter(p, _filter, myConsultantId))
            .toList(growable: false),
        myConsultantId,
      );
```

por:

```dart
  /// A lista do chip escolhido, na ordem do canvas. Com a busca aberta, os
  /// chips saem de cena e a lista é a de todos os participantes, filtrada
  /// pelo texto (decisão de 24/10/2026).
  List<SessionParticipant> get visibleParticipants => sortForDisplay(
        _participants
            .where((p) => isSearching
                ? matchesSearch(p, searchQuery)
                : matchesFilter(p, _filter, myConsultantId))
            .toList(growable: false),
        myConsultantId,
      );

  /// "2 de 18 participantes", embaixo da lista filtrada pela busca; nulo
  /// quando a busca não filtra nada.
  String? get searchCountLabel {
    if (!isFiltering) return null;
    final total = _participants.length;
    final noun = total == 1 ? 'participante' : 'participantes';
    return '${visibleParticipants.length} de $total $noun';
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_detail/session_detail_screen_test.dart`
Esperado: `+65: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1098: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/session_detail/participant_filter.dart apps/mobile/simtc/lib/ui/session_detail/session_detail_screen.dart apps/mobile/simtc/lib/ui/session_detail/session_detail_viewmodel.dart apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart
git commit -m "feat(mobile): busca de participantes no detalhe da sessao"
```

---

## Task 3: Busca de sessões na Home

A lupa entra ao lado do indicador de envio (quadro `2c`). Tocando nela, o campo toma o lugar da saudação e do título e os chips saem; as três seções continuam, só com as sessões da empresa buscada, todas de uma vez (sem "Ver mais"); a seção sem resultado some com o título, e sem nenhum aparece "Nenhuma sessão encontrada para “…”.". No celular, o voltar com a busca aberta fecha a busca; no tablet, a lista do lado a lado tem o mesmo cabeçalho.

**Files:**
- Modify: `lib/ui/sessions/sessions_list_viewmodel.dart`
- Modify: `lib/ui/sessions/sessions_screen.dart`
- Modify: `test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: `ListSearch`, `containsSearch`, `AppSearchButton`, `AppSearchField` (Task 1).
- Produces:
  - `SessionsListViewModel` com `ListSearch`; `sections` filtradas pela empresa enquanto `isFiltering`
  - `Key('sessions-no-results')` na frase de nenhum resultado

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
```

por:

```dart
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_spacing.dart';
import 'package:simtc/ui/core/widgets/app_search_field.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
  });

  group('tablet (Fase 7A)', () {
    void screen(WidgetTester tester, Size size) {
```

por:

```dart
  });

  group('busca de sessões pela empresa (Fase 8B)', () {
    TrainingSession sessao(
      String id,
      String company, {
      int daysFromToday = 0,
      SessionStatus status = SessionStatus.emAndamento,
    }) {
      return TrainingSession(
        id: id,
        companyName: company,
        courseName: 'Direção Preventiva',
        city: 'Lençóis Paulista',
        state: 'SP',
        date: DateTime.now().add(Duration(days: daysFromToday)),
        status: status,
        totalParticipants: 8,
        assessableParticipants: 8,
        assessedParticipants: 2,
      );
    }

    Future<void> showSessions(
      WidgetTester tester,
      List<TrainingSession> list,
    ) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester);
      sessions.add(list);
      await tester.pump();
    }

    Future<void> search(WidgetTester tester, String text) async {
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
    }

    testWidgets(
        'a lupa, ao lado do indicador de envio, abre o campo no lugar da '
        'saudação e do título; os chips saem; o X volta tudo', (tester) async {
      await showSessions(tester, [sessao('s1', 'Bracell Celulose')]);
      final lupa = tester.getRect(find.byTooltip('Buscar'));
      final indicador = tester.getRect(find.byType(SyncStatusIndicator));
      expect(indicador.left - lupa.right, AppSpacing.xs);

      await tester.tap(find.byTooltip('Buscar'));
      await tester.pump();

      expect(find.byType(AppSearchField), findsOneWidget);
      expect(find.text('Buscar pela empresa'), findsOneWidget);
      expect(find.byKey(const Key('sessions-title')), findsNothing);
      expect(find.text('Bom dia, Carla'), findsNothing);
      expect(find.textContaining(', Carla'), findsNothing);
      expect(find.byType(FilterChipBar), findsNothing);
      expect(find.byType(SyncStatusIndicator), findsOneWidget);
      expect(find.byTooltip('Buscar'), findsNothing);

      await tester.tap(find.byTooltip('Fechar a busca'));
      await tester.pump();

      expect(find.byKey(const Key('sessions-title')), findsOneWidget);
      expect(find.byType(FilterChipBar), findsOneWidget);
      expect(find.byType(AppSearchField), findsNothing);
    });

    testWidgets(
        'filtra pela empresa, sem acento nem maiúscula; a seção sem resultado '
        'some', (tester) async {
      await showSessions(tester, [
        sessao('s1', 'Bracell Celulose'),
        sessao('s2', 'Suzano Papel'),
        sessao('s3', 'Bracell Celulose',
            daysFromToday: -3, status: SessionStatus.concluido),
        sessao('s4', 'Suzano Papel', daysFromToday: 2),
      ]);

      await search(tester, 'BRÁC');

      expect(find.text('Bracell Celulose'), findsNWidgets(2));
      expect(find.text('Suzano Papel'), findsNothing);
      expect(find.textContaining('Hoje · '), findsOneWidget);
      expect(find.text('Esta semana'), findsNothing,
          reason: 'a semana só tem a Suzano');
      expect(find.text('Concluídas'), findsOneWidget);
      expect(find.text('Nada agendado para os próximos 7 dias.'), findsNothing);
    });

    testWidgets('todas as que batem aparecem, sem "Ver mais"', (tester) async {
      await showSessions(tester, [
        for (var i = 0; i < 12; i++) sessao('s$i', 'Bracell Unidade $i'),
      ]);
      expect(find.text('Ver mais', skipOffstage: false), findsOneWidget);

      await search(tester, 'bracell');

      expect(find.byType(SessionCard, skipOffstage: false), findsNWidgets(12));
      expect(find.text('Ver mais', skipOffstage: false), findsNothing);
    });

    testWidgets('sem resultado, diz que não achou', (tester) async {
      await showSessions(tester, [sessao('s1', 'Bracell Celulose')]);

      await search(tester, ' xyz ');

      expect(
        find.text('Nenhuma sessão encontrada para “xyz”.'),
        findsOneWidget,
      );
      expect(find.textContaining('Hoje · '), findsNothing);
    });

    testWidgets('aberta e vazia, a lista é a de sempre', (tester) async {
      await showSessions(tester, [sessao('s1', 'Bracell Celulose')]);

      await tester.tap(find.byTooltip('Buscar'));
      await tester.pump();

      expect(find.text('Bracell Celulose'), findsOneWidget);
      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('Nada agendado para os próximos 7 dias.'), findsOneWidget);
    });

    testWidgets('no celular, o voltar com a busca aberta fecha a busca',
        (tester) async {
      await showSessions(tester, [
        sessao('s1', 'Bracell Celulose'),
        sessao('s2', 'Suzano Papel'),
      ]);
      await search(tester, 'brac');

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.byType(AppSearchField), findsNothing);
      expect(find.text('Suzano Papel'), findsOneWidget);
    });
  });

  group('tablet (Fase 7A)', () {
    void screen(WidgetTester tester, Size size) {
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/sessions/sessions_screen_test.dart`
Esperado: `+26 -6: Some tests failed.` — os seis testes do grupo `busca de sessões pela empresa (Fase 8B)` falham: não há a lupa na Home.

- [ ] **Step 3: Implementar**

Em `lib/ui/sessions/sessions_list_viewmodel.dart`, substituir:

```dart
import '../../utils/result.dart';
import 'session_filter.dart';
```

por:

```dart
import '../../utils/result.dart';
import '../core/list_search.dart';
import '../core/search_text.dart';
import 'session_filter.dart';
```

Em `lib/ui/sessions/sessions_list_viewmodel.dart`, substituir:

```dart
class SessionsListViewModel extends ChangeNotifier {
```

por:

```dart
class SessionsListViewModel extends ChangeNotifier with ListSearch {
```

Em `lib/ui/sessions/sessions_list_viewmodel.dart`, substituir:

```dart
  List<SessionSection> get sections =>
      buildSections(_sessions, _now(), _visibleCounts);
```

por:

```dart
  /// Com a busca filtrando, só as sessões da empresa buscada, e todas elas: nada de "Ver
  /// mais" no meio de um resultado (Fase 8B).
  List<SessionSection> get sections {
    if (!isFiltering) return buildSections(_sessions, _now(), _visibleCounts);

    final found = _sessions
        .where((s) => containsSearch(s.companyName, searchQuery))
        .toList(growable: false);
    return buildSections(found, _now(), {
      for (final id in SessionBlockId.values) id: found.length,
    });
  }
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
import '../core/widgets/app_nav_bar.dart';
import '../core/widgets/company_logo.dart';
```

por:

```dart
import '../core/widgets/app_nav_bar.dart';
import '../core/widgets/app_search_field.dart';
import '../core/widgets/company_logo.dart';
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
  void _updateActiveChipFromScroll() {
    if (_programmaticScrollCount > 0) return;
```

por:

```dart
  void _updateActiveChipFromScroll() {
    // Com a busca aberta, os chips saem de cena: não há o que destacar.
    if (_viewModel.isSearching) return;
    if (_programmaticScrollCount > 0) return;
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
        ),
        _buildFilters(viewModel),
        Expanded(child: _buildBody(viewModel)),
      ],
    );

    return TabSnackBarArea(
```

por:

```dart
        ),
        if (!viewModel.isSearching) _buildFilters(viewModel),
        Expanded(child: _buildBody(viewModel)),
      ],
    );

    // No celular, o voltar do Android fecha a busca antes de fechar o app.
    // No tablet, quem cuida do voltar é o lado a lado (`SessionsSplitView`).
    return PopScope(
      canPop: context.isTablet || !viewModel.isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && viewModel.isSearching) viewModel.closeSearch();
      },
      child: _buildPage(content, tabletPortrait: tabletPortrait),
    );
  }

  Widget _buildPage(Widget content, {required bool tabletPortrait}) {
    return TabSnackBarArea(
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
  Widget _buildHeader(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;
    final title = user?.isAdmin == true ? 'Sessões' : 'Minhas sessões';
```

por:

```dart
  /// Com a busca aberta (Fase 8B), o campo toma o lugar da saudação e do
  /// título; a linha do logo e do indicador de envio continua em cima.
  Widget _buildHeader(BuildContext context) {
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
              SyncStatusIndicator(onTap: () => context.go(AppRoutes.sync)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
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
          ),
        ],
      ),
    );
```

por:

```dart
              // A lupa, a 4 do indicador (quadro "2c"); some enquanto o campo
              // está aberto, que já tem o X.
              if (!_viewModel.isSearching) ...[
                AppSearchButton(onPressed: _viewModel.openSearch),
                const SizedBox(width: AppSpacing.xs),
              ],
              SyncStatusIndicator(onTap: () => context.go(AppRoutes.sync)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          if (_viewModel.isSearching)
            AppSearchField(
              hintText: 'Buscar pela empresa',
              initialText: _viewModel.searchQuery,
              onChanged: _viewModel.setSearchQuery,
              onClose: _viewModel.closeSearch,
            )
          else
            ..._buildTitle(context),
        ],
      ),
    );
  }

  List<Widget> _buildTitle(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;
    final title = user?.isAdmin == true ? 'Sessões' : 'Minhas sessões';
    final embedded = widget.embedded;

    return [
      Text(
        _greeting(user?.name),
        style:
            embedded ? AppTypography.screenSubtitle : AppTypography.homeGreeting,
      ),
      const SizedBox(height: AppSpacing.xxs),
      // O key desambigua o título do rótulo 'Sessões' da navbar, que tem o
      // mesmo texto quando o usuário é ADMIN.
      Text(
        title,
        key: const Key('sessions-title'),
        style: embedded ? AppTypography.screenTitle : AppTypography.homeTitle,
      ),
    ];
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
    if (viewModel.isLoading) return _buildSkeleton();

    return RefreshIndicator(
      color: AppColors.primary,
```

por:

```dart
    if (viewModel.isLoading) return _buildSkeleton();

    // Na busca, a seção sem resultado some com o título; sem nenhum, uma
    // frase diz que não achou (decisões de 24/10/2026).
    final sections = viewModel.isFiltering
        ? viewModel.sections.where((s) => !s.isEmpty).toList(growable: false)
        : viewModel.sections;

    return RefreshIndicator(
      color: AppColors.primary,
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
          for (final section in viewModel.sections)
            ..._buildSection(viewModel, section),
```

por:

```dart
          if (viewModel.isFiltering && sections.isEmpty)
            _buildNoResults(viewModel.searchQuery.trim()),
          for (final section in sections) ..._buildSection(viewModel, section),
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
  }

  /// A seção nunca some, mesmo vazia — é o que garante que o chip sempre tem
  /// um lugar real pra rolar até.
```

por:

```dart
  }

  Widget _buildNoResults(String query) {
    return Padding(
      key: const Key('sessions-no-results'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: InlineNotice(
        icon: AppIcons.search,
        message: 'Nenhuma sessão encontrada para “$query”.',
      ),
    );
  }

  /// A seção nunca some, mesmo vazia — é o que garante que o chip sempre tem
  /// um lugar real pra rolar até.
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/sessions/sessions_screen_test.dart`
Esperado: `+32: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1104: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/sessions/sessions_list_viewmodel.dart apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): busca de sessoes pela empresa na home"
```

---

## Task 4: Busca de consultores da sessão

A lupa entra à direita da barra de "Consultores" (quadro `3c`) e, no tablet, no cabeçalho da janela, ao lado do X (os quadros `4n`/`4y` não a desenham — ver "Ajustes"). O campo abre embaixo do cabeçalho e filtra pelo nome as duas listas; a lista sem ninguém some com o título, a não ser que a equipe tenha um aviso próprio (sem conexão, todos já na sessão), que vence a busca; sem ninguém nas duas, "Nenhum consultor encontrado para “…”.". O voltar com a busca aberta fecha a busca.

**Files:**
- Modify: `lib/ui/core/widgets/admin_dialog.dart`
- Modify: `lib/ui/session_consultants/session_consultants_screen.dart`
- Modify: `lib/ui/session_consultants/session_consultants_viewmodel.dart`
- Modify: `test/ui/session_consultants/session_consultants_screen_test.dart`
- Modify: `test/ui/sessions/sessions_split_view_test.dart`

**Interfaces:**
- Consumes: `ListSearch`, `containsSearch`, `AppSearchButton`, `AppSearchField` (Task 1).
- Produces:
  - `SessionConsultantsViewModel` com `ListSearch`; `inSession` e `available` filtrados enquanto `isFiltering` (o `teamNotice` olha a equipe inteira)
  - `AdminDialogFrame.actions` (atalhos antes do X)
  - `Key('consultants-no-results')` na frase de nenhum resultado

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/session_consultants/session_consultants_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

por:

```dart
import 'package:simtc/ui/core/theme/app_spacing.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_search_field.dart';
import 'package:simtc/ui/core/widgets/app_top_bar.dart';
```

Em `test/ui/session_consultants/session_consultants_screen_test.dart`, substituir:

```dart
    // Sem a lupa do quadro: a busca é da Fase 8.
    expect(find.byIcon(AppIcons.search), findsNothing);
```

por:

```dart
    // A lupa do quadro, que busca pelo nome (Fase 8B).
    expect(find.byIcon(AppIcons.search), findsOneWidget);
```

Em `test/ui/session_consultants/session_consultants_screen_test.dart`, substituir:

```dart
  });

  testWidgets('falha ao buscar a equipe: pede para puxar, e puxar traz a equipe',
      (tester) async {
```

por:

```dart
  });

  group('busca de consultores (Fase 8B)', () {
    Future<void> openSearch(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pumpAndSettle();
    }

    testWidgets(
        'a lupa fica à direita do título e abre o campo embaixo do cabeçalho; '
        'o X fecha', (tester) async {
      await seedFromServer();
      await pumpScreen(tester);
      final bar = tester.getRect(find.byType(AppTopBar));
      expect(tester.getRect(find.byTooltip('Buscar')).right, bar.right - 8);

      await openSearch(tester);

      expect(find.byType(AppSearchField), findsOneWidget);
      expect(find.text('Buscar consultor pelo nome'), findsOneWidget);
      expect(
        tester.getRect(find.byType(AppSearchField)).top,
        bar.bottom + AppSpacing.sm,
      );
      expect(find.byTooltip('Buscar'), findsNothing);

      await tester.tap(find.byTooltip('Fechar a busca'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSearchField), findsNothing);
      expect(find.byTooltip('Buscar'), findsOneWidget);
    });

    testWidgets(
        'filtra as duas listas pelo nome; a lista sem ninguém some com o '
        'título', (tester) async {
      await seedFromServer();
      await pumpScreen(tester);
      await openSearch(tester);

      await type(tester, 'TAT');
      expect(rowOf('consultor-c-tatiane'), findsOneWidget);
      expect(rowOf('consultor-c-carla'), findsNothing);
      expect(find.text('Na sessão'), findsOneWidget);
      expect(find.text('Disponíveis na equipe'), findsNothing);

      await type(tester, 'patricia');
      expect(rowOf('equipe-c-patricia'), findsOneWidget);
      expect(rowOf('equipe-c-diego'), findsNothing);
      expect(find.text('Na sessão'), findsNothing);
      expect(find.text('Disponíveis na equipe'), findsOneWidget);
    });

    testWidgets('sem ninguém nas duas, diz que não achou', (tester) async {
      await seedFromServer();
      await pumpScreen(tester);
      await openSearch(tester);

      await type(tester, ' xyz ');

      expect(
        find.text('Nenhum consultor encontrado para “xyz”.'),
        findsOneWidget,
      );
      expect(find.text('Na sessão'), findsNothing);
      expect(find.text('Disponíveis na equipe'), findsNothing);
    });

    testWidgets(
        'sem conexão, o aviso da equipe vence a busca: a lista dela continua '
        'com o motivo', (tester) async {
      await seedFromServer();
      serverUnreachable();
      await goOffline();
      await pumpScreen(tester);
      await openSearch(tester);

      await type(tester, 'tat');

      expect(rowOf('consultor-c-tatiane'), findsOneWidget);
      expect(find.text('Disponíveis na equipe'), findsOneWidget);
      expect(find.text('A equipe aparece quando houver conexão.'), findsOneWidget);
    });

    testWidgets('o voltar com a busca aberta fecha a busca e fica na tela',
        (tester) async {
      await seedFromServer();
      await pumpScreen(tester);
      await openSearch(tester);
      await type(tester, 'tat');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(AppSearchField), findsNothing);
      expect(find.byType(SessionConsultantsScreen), findsOneWidget);
      expect(rowOf('consultor-c-carla'), findsOneWidget);
    });
  });

  testWidgets('falha ao buscar a equipe: pede para puxar, e puxar traz a equipe',
      (tester) async {
```

Em `test/ui/sessions/sessions_split_view_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/admin_dialog.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

por:

```dart
import 'package:simtc/ui/core/widgets/admin_dialog.dart';
import 'package:simtc/ui/core/widgets/app_search_field.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

Em `test/ui/sessions/sessions_split_view_test.dart`, substituir:

```dart
      expect(dialog(), findsNothing, reason: 'tocar no fundo fecha');
    });
  });
}
```

por:

```dart
      expect(dialog(), findsNothing, reason: 'tocar no fundo fecha');
    });

    testWidgets(
        'na janela de consultores, a lupa fica ao lado do X e abre o campo '
        'embaixo do cabeçalho; o texto atravessa o giro', (tester) async {
      await pumpApp(tester, location: AppRoutes.sessionDetail('sess-1'));
      await tester.tap(find.byTooltip('Consultores da sessão'));
      await settle(tester);
      Finder inDialog(Finder matching) =>
          find.descendant(of: dialog(), matching: matching);

      final lupa = tester.getRect(inDialog(find.byTooltip('Buscar')));
      final fechar = tester.getRect(inDialog(find.byTooltip('Fechar')));
      expect(lupa.right, fechar.left);
      expect(lupa.top, fechar.top);

      await tester.tap(inDialog(find.byTooltip('Buscar')));
      await settle(tester);
      expect(inDialog(find.byType(AppSearchField)), findsOneWidget);
      await tester.enterText(inDialog(find.byType(TextField)), 'xyz');
      await settle(tester);
      expect(find.textContaining('Nenhum consultor encontrado'), findsOneWidget);

      await rotate(tester, _portrait);

      expect(
        tester
            .widget<TextField>(inDialog(find.byType(TextField)))
            .controller!
            .text,
        'xyz',
      );
      expect(find.textContaining('Nenhum consultor encontrado'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_consultants/session_consultants_screen_test.dart test/ui/sessions/sessions_split_view_test.dart`
Esperado: `+42 -7: Some tests failed.` — os cinco testes do grupo `busca de consultores (Fase 8B)`, o da janela no tablet (`sessions_split_view_test.dart`) e o teste antigo do quadro "3c", que agora espera a lupa.

- [ ] **Step 3: Implementar**

Em `lib/ui/core/widgets/admin_dialog.dart`, substituir:

```dart
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
```

por:

```dart
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  /// Atalhos antes do X, cada um com o próprio alvo de 48 — a lupa da janela
  /// de Consultores (Fase 8B).
  final List<Widget> actions;
```

Em `lib/ui/core/widgets/admin_dialog.dart`, substituir:

```dart
            child: SizedBox.square(
              dimension: AppSpacing.touchTarget,
              child: IconButton(
                tooltip: 'Fechar',
                icon: const Icon(AppIcons.close, size: 24, color: AppColors.text3),
                onPressed: onClose,
              ),
```

por:

```dart
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...actions,
                SizedBox.square(
                  dimension: AppSpacing.touchTarget,
                  child: IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(
                      AppIcons.close,
                      size: 24,
                      color: AppColors.text3,
                    ),
                    onPressed: onClose,
                  ),
                ),
              ],
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_top_bar.dart';
```

por:

```dart
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_search_field.dart';
import '../core/widgets/app_top_bar.dart';
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
/// Diferenças do canvas, aprovadas em 09/10/2026: sem a lupa (a busca é da
/// Fase 8); o e-mail no lugar da agenda de quem está na equipe (o backend não
/// tem agenda de consultor); a confirmação antes de remover quem tem
/// avaliação em andamento; e os botões com 48dp (o quadro tem 44).
```

por:

```dart
/// Diferenças do canvas, aprovadas em 09/10/2026: o e-mail no lugar da agenda
/// de quem está na equipe (o backend não tem agenda de consultor); a
/// confirmação antes de remover quem tem avaliação em andamento; e os botões
/// com 48dp (o quadro tem 44). A lupa do quadro busca pelo nome (Fase 8B); no
/// tablet ela fica no cabeçalho da janela, ao lado do X (os quadros "4n" e
/// "4y" não a desenham).
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
    if (context.isTablet) return _buildDialog(isOffline);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(title: 'Consultores'),
            ..._buildBanners(isOffline),
            Expanded(child: _buildBody(isOffline)),
          ],
        ),
```

por:

```dart

    // O voltar (o do Android, a seta e o X da janela) fecha a busca antes de
    // fechar a tela.
    return PopScope(
      canPop: !_viewModel.isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _viewModel.isSearching) _viewModel.closeSearch();
      },
      child: context.isTablet
          ? _buildDialog(isOffline)
          : _buildPage(isOffline),
    );
  }

  Widget _buildPage(bool isOffline) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Consultores',
              trailing: _viewModel.isSearching ? null : _buildSearchButton(),
            ),
            if (_viewModel.isSearching) _buildSearchField(),
            ..._buildBanners(isOffline),
            Expanded(child: _buildBody(isOffline)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton() =>
      AppSearchButton(onPressed: _viewModel.openSearch);

  /// O campo abre embaixo do cabeçalho, com o recuo da lista.
  Widget _buildSearchField() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _inset,
        vertical: AppSpacing.sm,
      ),
      child: AppSearchField(
        hintText: 'Buscar consultor pelo nome',
        initialText: _viewModel.searchQuery,
        onChanged: _viewModel.setSearchQuery,
        onClose: _viewModel.closeSearch,
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
      banner: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildBanners(isOffline),
```

por:

```dart
      actions: [if (!_viewModel.isSearching) _buildSearchButton()],
      banner: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_viewModel.isSearching) _buildSearchField(),
          ..._buildBanners(isOffline),
        ],
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
          _buildSessionTitle(),
          for (final item in _viewModel.inSession)
            _buildSessionRow(item, enabled),
          _buildTeamTitle(),
          ..._buildTeam(enabled),
          _buildFooterNote(),
        ],
      ),
    );
```

por:

```dart
          ..._buildLists(enabled),
          _buildFooterNote(),
        ],
      ),
    );
  }

  /// As duas listas. Com a busca filtrando, a lista sem ninguém some com o
  /// título — a não ser que a equipe tenha um aviso próprio (sem conexão,
  /// todos já na sessão), que vence a busca; sem ninguém nas duas, uma frase
  /// diz que não achou (decisões de 24/10/2026).
  List<Widget> _buildLists(bool enabled) {
    final inSession = _viewModel.inSession;
    final filtering = _viewModel.isFiltering;
    final showTeam = !filtering ||
        _viewModel.available.isNotEmpty ||
        _viewModel.isTeamLoading ||
        _viewModel.teamNotice != null;

    return [
      if (filtering && inSession.isEmpty && _viewModel.available.isEmpty)
        Padding(
          key: const Key('consultants-no-results'),
          padding: EdgeInsets.fromLTRB(_inset, AppSpacing.md, _inset, 0),
          child: InlineNotice(
            icon: AppIcons.search,
            message: 'Nenhum consultor encontrado para '
                '“${_viewModel.searchQuery.trim()}”.',
          ),
        ),
      if (!filtering || inSession.isNotEmpty) ...[
        _buildSessionTitle(),
        for (final item in inSession) _buildSessionRow(item, enabled),
      ],
      if (showTeam) ...[
        _buildTeamTitle(),
        ..._buildTeam(enabled),
      ],
    ];
```

Em `lib/ui/session_consultants/session_consultants_viewmodel.dart`, substituir:

```dart
import '../core/name_sort.dart';
```

por:

```dart
import '../core/list_search.dart';
import '../core/name_sort.dart';
import '../core/search_text.dart';
```

Em `lib/ui/session_consultants/session_consultants_viewmodel.dart`, substituir:

```dart
class SessionConsultantsViewModel extends ChangeNotifier {
```

por:

```dart
class SessionConsultantsViewModel extends ChangeNotifier with ListSearch {
```

Em `lib/ui/session_consultants/session_consultants_viewmodel.dart`, substituir:

```dart
  /// "Na sessão": o responsável primeiro, e os outros por nome.
  List<SessionConsultantItem> get inSession {
    final responsibleId = _session?.responsibleConsultantId;
    final sorted = [..._consultants]..sort((a, b) {
```

por:

```dart
  /// "Na sessão": o responsável primeiro, e os outros por nome. Com a busca
  /// filtrando, só quem tem o texto no nome (Fase 8B).
  List<SessionConsultantItem> get inSession {
    final responsibleId = _session?.responsibleConsultantId;
    final sorted = [
      for (final consultant in _consultants)
        if (_matches(consultant)) consultant,
    ]..sort((a, b) {
```

Em `lib/ui/session_consultants/session_consultants_viewmodel.dart`, substituir:

```dart
  /// "Disponíveis na equipe": os ativos que ainda não estão na sessão, por
  /// nome.
  List<SessionConsultant> get available {
```

por:

```dart
  bool _matches(SessionConsultant consultant) =>
      !isFiltering || containsSearch(consultant.name, searchQuery);

  /// "Disponíveis na equipe": os ativos que ainda não estão na sessão, por
  /// nome — com a busca filtrando, só quem tem o texto no nome.
  List<SessionConsultant> get available =>
      [for (final c in _allAvailable) if (_matches(c)) c];

  List<SessionConsultant> get _allAvailable {
```

Em `lib/ui/session_consultants/session_consultants_viewmodel.dart`, substituir:

```dart
      return available.isEmpty
```

por:

```dart
      return _allAvailable.isEmpty
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_consultants/session_consultants_screen_test.dart test/ui/sessions/sessions_split_view_test.dart`
Esperado: `+49: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1110: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/widgets/admin_dialog.dart apps/mobile/simtc/lib/ui/session_consultants/session_consultants_screen.dart apps/mobile/simtc/lib/ui/session_consultants/session_consultants_viewmodel.dart apps/mobile/simtc/test/ui/session_consultants/session_consultants_screen_test.dart apps/mobile/simtc/test/ui/sessions/sessions_split_view_test.dart
git commit -m "feat(mobile): busca de consultores da sessao"
```

---
## Task 5: Validação no aparelho e no emulador

O portão da 8B, que só o usuário pode rodar: o celular no **aparelho físico** e o tablet no **emulador**, contra a produção (o padrão desde a 8A). A 8B não muda o backend: não há publicação.

**Interfaces:**
- Consumes: o app com as Tasks 1 a 4.
- Produces: o aval do usuário para planejar a 8C.

- [ ] **Step 1: Instalar**

Em `apps/mobile/simtc/`: `flutter run -d <id do celular>` e, depois, `flutter run -d emulator-5554`.

- [ ] **Step 2: Roteiro no celular**

Com uma conta CONSULTANT e depois com uma ADMIN, numa sessão de teste com vários participantes:

1. **Detalhe da sessão:** a lupa na ponta direita da barra dos filtros. Tocar: o campo toma o lugar dos chips e o teclado abre. Digitar parte de um nome sem acento (por exemplo, "jose"): aparecem só os que batem, de qualquer chip, e embaixo "N de M participantes". Digitar o CPF inteiro de um participante, com os pontos: ele aparece. Digitar algo que não existe: "Nenhum participante encontrado para “…”.". O X fecha e o chip de antes volta. Com a busca aberta, o voltar do Android fecha a busca e fica no detalhe.
2. **Abrir um resultado e voltar:** com a busca filtrando, tocar num participante e voltar: o texto continua lá.
3. **Home:** a lupa ao lado do indicador de envio. Tocar: o campo toma o lugar da saudação e do título, e os chips somem. Digitar parte do nome de uma empresa: só as sessões dela, nas seções que têm alguma (as vazias somem). O X volta tudo. O voltar do Android com a busca aberta fecha a busca (e não o app).
4. **Consultores (ADMIN):** a lupa à direita de "Consultores". Tocar: o campo abre embaixo da barra. Digitar parte de um nome: as duas listas filtram, e a que fica sem ninguém some com o título. No modo avião, o aviso "A equipe aparece quando houver conexão." continua lá mesmo com a busca.
5. **Sem rede:** no modo avião, as três buscas continuam funcionando.

- [ ] **Step 3: Roteiro no tablet (emulador)**

1. **Lado a lado em paisagem:** a lupa da lista e a da barra dos filtros do detalhe, cada uma no seu painel, com o mesmo comportamento do celular.
2. **Consultores numa janela:** a lupa no cabeçalho da janela, ao lado do X. Abrir, digitar um nome e girar o tablet: o texto e o resultado continuam.
3. **Retrato:** as mesmas buscas, uma tela por vez.

- [ ] **Step 4: Registrar o resultado**

Se tudo passar, acrescentar ao fim desta task a linha "**Validado em <data>: celular no aparelho físico e tablet no emulador; roteiro inteiro passou. Aval dado para planejar a 8C.**" e commitar:

```bash
git add apps/mobile/docs/superpowers/plans/2026-10-24-mobile-fase-8b-buscas.md
git commit -m "docs(mobile): registra a validacao da fase 8b"
```

Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio, parar e perguntar.

---

## Pendências levadas para a 8C e a 8D

- **8C:** a aparência do campo de busca e a lupa do detalhe com 48 de alvo (o quadro desenha 36) entram na conferência visual da 8C; o leitor de tela nas buscas (o campo anuncia o exemplo; a contagem "N de M" não é anunciada quando muda).
- **8D:** buscar participante em todas as sessões a partir da Home, por curso ou por cidade, e no servidor — fora da 8B por decisão do usuário; retomar só se fizer falta em campo.
- As observações das revisões da 8A continuam valendo como estão no fim do plano da 8A.
