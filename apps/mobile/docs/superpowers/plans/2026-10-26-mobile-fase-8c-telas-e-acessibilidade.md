# App Mobile SIMTC — Fase 8C: Telas e acessibilidade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O app fica confortável para quem enxerga pouco, usa a fonte grande do Android ou o TalkBack, sem toques "mortos" nem cores fora do canvas: contraste, ondulação do toque, alvos de 48, toque duplo, leitor de tela, fonte ampliada, falhas de gravação do checklist e erro da primeira descida — e as decisões visuais em aberto das Fases 5B, 6A, 8A e 8B.

**Architecture:** Nada muda de regra, de banco ou de backend. Os tokens novos (`mauveInk`, `textSubtle`) e os estilos com nome (`progressLabel`, `blockTitle`, `contextTitleCompact`, `fieldValueMultiline`) entram no tema; três auxiliares pequenos em `lib/ui/core/` (`open_once.dart`, `text_fscale.dart`) e dois de teste (`test/support/ripple.dart`, `a11y.dart`) são usados pelas telas. A ondulação do toque segue o padrão que o Resultado e o Perfil já usam: o fundo vai para um `Material` embaixo do `InkWell`. As falhas de gravação do checklist e da primeira descida viram estado das ViewModels.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · drift 2.31.0 (sem mudança de esquema) · mocktail (testes). Nenhuma dependência nova.

**Spec:** `apps/mobile/docs/superpowers/specs/2026-10-24-mobile-fase-8-design.md`, seção "8C — Telas e acessibilidade" e o "Desenho da 8C (26/10/2026)", aprovado pelo usuário em 26/10/2026; canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html` (quadros `1f`, `2c`, `2i`, `3a`, `3b`, `3c`, `4c`, `4k`, `4u`, `4v`).

**Validação prévia:** antes de o plano ser fechado, os testes de diretriz do Flutter (alvo de 48, rótulo e contraste) rodaram em todos os testes de tela do app, e as telas rodaram com a fonte do sistema em 1,3×, 1,6× e 2× com a Inter de verdade — é daí que saíram os achados em "Ajustes". Depois, todo o código das Tasks 1 a 8 foi escrito e rodado numa cópia descartável do app, uma task por commit, e as tasks foram **reencenadas em ordem** numa segunda cópia limpa, a partir dos blocos deste plano: em cada task, os testes da task falharam antes da implementação e passaram depois, e cada checkpoint bateu o número de testes — **1114 → 1123 → 1129 → 1135 → 1141 → 1144 → 1153 → 1157 → 1170**, com `flutter analyze` sem issues em todos; a árvore de cada task ficou **idêntica** à do commit correspondente. A reencenação pegou uma falha da primeira versão da Task 4: com 50 ms entre os toques, a tela nova já cobria o card e o teste passava sem a guarda; os testes passaram a tocar duas vezes no mesmo quadro, e a guarda passou a reservar a abertura até o próximo quadro (ver "Ajustes"). **Cada decisão e cada medida foi conferida por mutação** (o trecho é trocado, e algum teste tem de falhar): **79 mutações, 78 acusadas**; a que sobreviveu é equivalente — sem o `MergeSemantics` do chip de filtro, o `Semantics` de botão em volta já junta o chip num nó de 48, com o mesmo rótulo; ele fica no código para deixar a intenção explícita. Duas mutações da primeira versão sobreviveram e levaram a código a menos: a guarda do lápis do ADMIN (as telas de admin já não entram duas vezes, pela chave de página do go_router) e uma trava própria do "Sair da conta" (a reserva depois da contagem já basta). As telas foram **desenhadas com as fontes de verdade** — a Home, o detalhe, o checklist com o "Não salvo", o Resultado, Sincronizar, a 1.11, a 1.12, Consultores e o Perfil em 412×915; a Home, o detalhe, o checklist, o Resultado, Sincronizar e a 1.11 (sem conexão, com o teclado aberto) em 360×640 com a fonte em 1,3× e 2×; o lado a lado do tablet em 1280×800, 800×1280 e 900×700 — sem estouro, e conferidas a olho.

## Decisões tomadas com o usuário

O usuário deixou as decisões da 8C para o bom senso ("pode analisar essas pendências pelo bom senso", 26/10/2026) e aprovou o desenho escrito com elas ("ok, pode seguir com o plano"). Em resumo, do "Desenho da 8C":

1. **Cores:** o contorno vermelho é o `#E9A2A2` do canvas em todo lugar (`dangerBorder`); o "Somente teórica" escreve em `mauveInk` `#6B4A7A`; a navbar do celular usa os tons do tablet (ativo `primaryDark` sobre `primarySurface`, inativo `text3`); o texto informativo pequeno passa ao `textSubtle` `#64748B`.
2. **Toque:** a ondulação aparece no card da sessão, na linha do participante, no cabeçalho da categoria aberta, nos B/PM/M e nos cartões de tipo (e nos chips e na navbar, pelo mesmo motivo); dois toques rápidos abrem uma tela só; tudo o que se toca tem 48 e rótulo, conferido pelos testes de diretriz do Flutter.
3. **Fonte ampliada:** com a fonte do sistema em 1,3× ou mais, o cabeçalho do detalhe e os filtros rolam com a lista (celular e tablet); a pílula "Não recomendado" desce para baixo do % quando não cabe; "Tentar novamente" e "Descartar" ficam um embaixo do outro quando não cabem lado a lado; nenhuma tela estoura em 360×640 com 1,3× e 2×.
4. **Leitor de tela:** B/PM/M dizem se estão marcados; a data da 1.12 é um nó só; os cartões de tipo dizem selecionado e desativado; a janela de admin é anunciada pelo título; a contagem e as frases de nenhum resultado das buscas são anunciadas; os títulos de tela e de seção são cabeçalhos.
5. **Falhas:** o checklist avisa quando não grava (ao abrir, ao marcar uma nota, no "Iniciar avaliação") e o "salvo" vira "Não salvo"; o ⋮ vira o indicador de carregamento enquanto o "Desatribuir" espera; o descarte de uma avaliação já aceita diz que não há o que descartar.
6. **Medidas herdadas:** a faixa de contexto e as observações nas medidas dos quadros `3a`/`3b`/`3c`; o ícone de adicionar do detalhe com 20; o "Atribuir a mim" com canto 10; os vãos do Perfil com 14 e 16; o "Sair da conta" do tablet guarda a largura enquanto sai.
7. **Ficam como estão:** a setinha das linhas da fila; o título "Participantes" sem conexão; o campo de busca da 8B.

### Ajustes feitos ao preparar o plano (revisar junto com o plano)

A validação na cópia descartável levou a estas escolhas. **Nenhuma muda regra aprovada**; as que divergem do canvas estão marcadas.

**Achados da auditoria** (os testes de diretriz rodados em todas as telas, e as telas desenhadas com a fonte ampliada e a Inter de verdade):

- **O link verde-azulado** ("Esqueci a senha", "Ver mais") passa ao `primaryHover` `#167F8A` (4,7:1); o `primary` dava 3,4:1 em texto de 13,5. *Diverge do canvas, que usa `#1D9AA4`.* A cor da marca como **fundo** (botões, chip selecionado) fica: trocá-la mudaria a cara do app.
- **Os campos de texto** só focavam tocando na faixa do texto (21 de altura), e não no contorno de 56: agora o toque em qualquer ponto da caixa — inclusive no ícone — foca o campo, e o campo tem 48 de alvo dentro da caixa de 56. O desenho não muda.
- **Os chips de filtro** desenham 34 de altura (canvas) e agora tocam em 48: a margem de toque sai do recuo da barra, que continua com 54. O desenho não muda.
- **Com a Inter de verdade, nada estoura em 1,3× nem em 1,6×.** Em 2×, só a navbar estourava: **os rótulos dela crescem até 1,6× e param**, porque a barra tem altura fixa.
- **Na 1.11 e na 1.12, sem conexão, com a fonte em 2× e o teclado aberto**, a faixa "Sem conexão" ocupava o espaço do formulário e o rodapé estourava: **com menos de 300 de altura entre a barra do topo e o rodapé, a faixa rola junto com o formulário**, e os botões continuam à vista. Ela fica sempre no primeiro lugar da rolagem (vazia quando está fixa), para o formulário não perder o foco quando o teclado abre.
- **A Home e o detalhe com a primeira descida falhando:** a Home dizia "Nenhuma sessão para hoje." e o detalhe "Puxe para atualizar quando houver conexão" com conexão. Agora, sem nada no aparelho e com a descida que falhou, a Home mostra "Não foi possível baixar as sessões. Confira a conexão e tente de novo." e o detalhe "Não foi possível baixar os participantes desta sessão.", os dois com "Tentar novamente" — no lugar do aviso passageiro, um aviso só. Antes de ler o cache, a falha continua passageira (não dá para saber se há algo guardado).
- **Os diálogos de confirmação já usam a Inter** (conferido num teste): a observação da 8A não se confirmou, e nada muda.
- **O campo de busca da 8B já entrega o exemplo como rótulo** ao leitor de tela, mesmo depois de digitar: nada muda.

**Regras que o código cria:**

- **Toque duplo:** um toque que abre uma tela ou uma janela reserva a abertura (`context.claimOpen()`); outro toque não faz nada até o fim do próximo quadro — é nele que o go_router monta a rota nova — nem enquanto outra tela estiver por cima da atual, inclusive durante a animação de entrada (`ModalRoute.isCurrentOf`). A reserva solta sozinha no quadro seguinte, mesmo que nada abra, então não trava. (Só olhar a rota por cima não bastava: o segundo toque do mesmo quadro passava antes de a rota existir — foi o que a reencenação mostrou.) Vale para os cards da Home, as linhas do detalhe, o "Finalizar avaliação", o "Reavaliar" e a confirmação do "Sair da conta". As telas de admin ficaram sem a guarda: o teste de dois toques no lápis, no mesmo quadro, abre uma tela só mesmo sem ela, e a revisão final não achou cenário real de duas telas (a tela nova cobre os ícones). *Correção depois da execução:* a primeira versão deste texto atribuía isso à chave de página do go_router, o que a revisão final desmentiu — no go_router 14.8.1 o `push` usa uma chave aleatória. O teste do lápis fica como rede.
- **"Sair da conta":** o segundo toque, enquanto as avaliações iniciadas são contadas, conta de novo, mas não abre outra confirmação (a reserva da abertura é feita depois da contagem) — em vez de o botão ficar desativado, que piscaria cinza a cada toque.
- **"Tentar novamente" e "Descartar":** lado a lado quando a largura, descontada a fonte ampliada, passa de 480 (o tablet); senão, um embaixo do outro, na largura inteira — o caso de todo celular.
- **A pílula do resultado** usa um `Wrap`: à direita do % quando cabe, embaixo dele quando não cabe.
- **"Não salvo"** fica até a próxima nota que grava; ao abrir com falha de leitura, "Não foi possível abrir a avaliação neste aparelho." com "Tentar novamente", que lê de novo.
- **O descarte que não apagou** diz "Esta avaliação já foi aceita pelo servidor; não há o que descartar." quando a avaliação saiu da fila (foi aceita); senão, continua "Não foi possível descartar. Tente de novo.".

**Textos novos:** "Não salvo"; "Não foi possível salvar a nota. Tente de novo."; "Não foi possível iniciar a avaliação. Tente de novo."; "Não foi possível abrir a avaliação neste aparelho."; "Desatribuindo…" (só para o leitor de tela); "Esta avaliação já foi aceita pelo servidor; não há o que descartar."; "Não foi possível baixar as sessões. Confira a conexão e tente de novo."; "Não foi possível baixar os participantes desta sessão.".

**Divergências do canvas (todas do desenho, mais o link):** a navbar do celular nos tons do tablet; o `textSubtle`; o link em `#167F8A`; o cabeçalho do detalhe rolando com a fonte em 1,3× ou mais; a pílula descendo e os botões da fila empilhados quando não cabem; o "Não salvo" e o indicador no lugar do ⋮; a lupa do detalhe com 48 de alvo.

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app`. Sem git worktree. Não criar branch, não fazer merge, não fazer push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada, com a mensagem exata dada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem trabalho do usuário fora do git, que **não é desta fase e fica exatamente como está**: um arquivo rastreado **já modificado** (`brainstorm-app-mobile.md`) e os não rastreados `.vscode/`, `IMPLEMENTATION-STATUS.md`, `apps/backend/test-render.js`, `apps/mobile/simtc/devtools_options.yaml`, `apps/web/src/app/(client)/my-company/trainings/[id]/certificates/`, `brainstorm-implementacao-mobile.md`, `prompt-claude-design-mobile.md`, `prompt-implementacao-mobile-claude-code.md`, `test-pdf.js` e `test-render.js`.
- **Proibido `git restore`, `git checkout -- <arquivo>`, `git stash`, `git reset` e `git clean`**, e qualquer outro comando que desfaça mudança que não é da task. Se o `git status` mostrar algo que não é da task, ignorar e seguir.
- **Na execução por subagentes:** antes do primeiro despacho, guardar a linha de base — o `git status --porcelain` inteiro e o `git hash-object brainstorm-app-mobile.md` — e compará-la, sem filtrar nada, depois de **cada** subagente. Todo despacho repete as duas regras acima com todas as letras. Implementadores em **haiku**; revisões em **sonnet**.
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-10-26-mobile-fase-8c-telas-e-acessibilidade/`.

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

1. **Dois toques rápidos num card ou numa linha** (dedo nervoso, luva) → abre uma tela só. Preso em: `dois toques rápidos num card abrem um detalhe só` (Task 4) e nos testes irmãos da linha, do lápis, do "Finalizar", do "Reavaliar" e do "Sair".
2. **Disco cheio, ou banco do aparelho com problema, no meio de uma avaliação** → a nota não fica marcada em silêncio: o aviso aparece e o cabeçalho diz "Não salvo". Preso em: `uma nota que não grava avisa, o botão não marca e o "salvo" vira "Não salvo" até a próxima que grava` (Task 7).
3. **Fonte do sistema no máximo, celular baixo, sem conexão, digitando** → nada estoura e o campo não perde o foco. Preso em: `sem conexão, com o teclado aberto num celular de 360x640 e a fonte em 2×: …` (Task 6, na 1.11 e na 1.12) e no teste dos rótulos da navbar.
4. **Primeiro login com o servidor fora** → a Home diz que não baixou, e não "nenhuma sessão". Preso em: `a primeira descida falhou com o aparelho vazio: o motivo e "Tentar novamente", e não as seções vazias` (Task 8).
5. **TalkBack percorrendo o checklist** → cada B/PM/M diz se está marcado. Preso em: `o leitor de tela diz qual dos B/PM/M está marcado` (Task 5).

## Estado herdado (ponto de partida)

HEAD = o commit deste plano, sobre `e66ec3c` (o desenho da 8C). App: `flutter analyze` limpo; **1114 testes passando**.

Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| Fundo num `Material` embaixo do toque | `lib/ui/result/result_screen.dart`, `lib/ui/profile/profile_screen.dart` | o padrão que a Task 3 repete |
| Indicador de carregamento pequeno | `lib/ui/session_detail/session_detail_screen.dart` (`_buildAdminMenu`) | 20 de lado, traço 2,5, `text3`, num alvo de 48 |
| Aviso e botão de tentar de novo | `lib/ui/core/widgets/inline_notice.dart`, `app_buttons.dart` | `InlineNotice(icon:, tone:, message:)`, `AppSecondaryButton(label:, icon:, onPressed:)` |
| Faixa de contexto | `lib/ui/core/widgets/session_context_header.dart` | `SessionContextHeader(companyName:, subtitle:, title:, logoUrl:, muted:)` |
| Testes | `test/ui/…` | os auxiliares de cada tela (`show`, `pump`, `pumpScreen`, `pumpOverOrigin`, `pumpResult`, `pumpAdd`, `pumpEdit`, `h.pump`) |

## Mapa de Arquivos

### Novos

| Arquivo | Task | Responsabilidade |
|---|---|---|
| `test/ui/core/theme/app_contrast_test.dart` | 1 | os contrastes dos tokens, pela fórmula do WCAG |
| `test/support/ripple.dart` | 3 | `expectVisibleRipple` |
| `lib/ui/core/open_once.dart` | 4 | `context.claimOpen()` |
| `lib/ui/core/text_scale.dart` | 6 | `largeTextScale`, `context.textScale`, `context.isLargeText` |
| `test/support/a11y.dart` | 8 | `expectAccessibleTargets` |

### Modificados

| Arquivo | Task | O que muda |
|---|---|---|
| `lib/ui/core/theme/app_colors.dart`, `app_typography.dart`, `app_icons.dart` | 1, 2, 7 | tokens, estilos com nome, `notSaved` |
| `lib/ui/core/widgets/*` (navbar, chips, card, botões, campo, faixa de contexto, logo, janela de admin, barra do topo, nota final, faixa de sem conexão) | 1–6 | cores, ondulação, alvos, semântica, medidas, fonte ampliada |
| telas (`sessions`, `session_detail`, `checklist`, `result`, `sync`, `profile`, `add_participant`, `session_edit`, `session_consultants`) e as ViewModels do checklist, da Home e do detalhe | 1–8 | o que cada task diz |
| testes existentes | 1–8 | os que conferem o que muda |

---

## Task 1: Cores e contraste

O contorno vermelho passa ao `#E9A2A2` do canvas (`dangerBorder`, em todo lugar); o "Somente teórica" ganha a tinta do canvas (`mauveInk` `#6B4A7A`, no chip e no ícone do cartão da 1.11); o texto informativo pequeno passa ao `textSubtle` `#64748B` ("opcional", "N itens", o número da infração, "N infrações" do tablet, "SIM Treinamentos"); o link passa ao `primaryHover`; e a navbar do celular usa os tons do tablet. Um teste novo confere os contrastes pela fórmula do WCAG.

**Files:**
- Create: `test/ui/core/theme/app_contrast_test.dart`
- Modify: `lib/ui/add_participant/add_participant_screen.dart`
- Modify: `lib/ui/core/theme/app_colors.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/widgets/pill_nav_bar.dart`
- Modify: `lib/ui/core/widgets/status_chip.dart`
- Modify: `lib/ui/session_consultants/session_consultants_screen.dart`
- Modify: `test/ui/add_participant/add_participant_screen_test.dart`
- Modify: `test/ui/core/widgets/display_widgets_test.dart`
- Modify: `test/ui/session_consultants/session_consultants_screen_test.dart`

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces:
  - `AppColors.mauveInk` (`#6B4A7A`) e `AppColors.textSubtle` (`#64748B`); `AppColors.dangerBorder` passa a `#E9A2A2`
  - `contrast(Color, Color) → double` em `test/ui/core/theme/app_contrast_test.dart`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/add_participant/add_participant_screen_test.dart`, substituir:

```dart
    expect(borderOf('tipo-teoricaEPratica'), AppColors.primary);
    expect(borderOf('tipo-somenteTeorica'), AppColors.borderStrong);

    expect(addButton(tester).onPressed, isNull, reason: 'nada preenchido');
```

por:

```dart
    expect(borderOf('tipo-teoricaEPratica'), AppColors.primary);
    expect(borderOf('tipo-somenteTeorica'), AppColors.borderStrong);
    // O ícone do "Somente teórica" é o do canvas (Fase 8C).
    expect(
      tester.widget<Icon>(find.byIcon(AppIcons.theoryOnly)).color,
      AppColors.mauveInk,
    );

    expect(addButton(tester).onPressed, isNull, reason: 'nada preenchido');
```

Criar `test/ui/core/theme/app_contrast_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_typography.dart';

/// Contraste entre duas cores opacas, pela fórmula do WCAG 2.
double contrast(Color a, Color b) {
  double channel(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('cores do canvas (Fase 8C)', () {
    test('o contorno vermelho é o #E9A2A2 do canvas', () {
      expect(AppColors.dangerBorder, const Color(0xFFE9A2A2));
    });

    test('"Somente teórica" escreve em #6B4A7A; o mauve continua o da marca',
        () {
      expect(AppColors.mauveInk, const Color(0xFF6B4A7A));
      expect(AppColors.mauve, const Color(0xFF9B80A8));
    });
  });

  group('contraste do texto (Fase 8C)', () {
    test('o cinza do texto informativo pequeno passa de 4,5:1', () {
      expect(AppColors.textSubtle, const Color(0xFF64748B));
      expect(contrast(AppColors.textSubtle, AppColors.surface),
          greaterThanOrEqualTo(4.5));
      expect(contrast(AppColors.textSubtle, AppColors.background),
          greaterThanOrEqualTo(4.5));
    });

    test('o texto informativo pequeno usa esse cinza', () {
      expect(AppTypography.fieldOptional.color, AppColors.textSubtle);
      expect(AppTypography.categoryCount.color, AppColors.textSubtle);
      expect(AppTypography.infractionNumber.color, AppColors.textSubtle);
      expect(AppTypography.resultGroupCountTablet.color, AppColors.textSubtle);
    });

    test('o link é o verde da marca mais escuro, que passa de 4,5:1', () {
      expect(AppTypography.link.color, AppColors.primaryHover);
      expect(contrast(AppColors.primaryHover, AppColors.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('"Somente teórica" passa de 4,5:1 sobre o fundo do chip', () {
      expect(contrast(AppColors.mauveInk, AppColors.mauveSoft),
          greaterThanOrEqualTo(4.5));
    });

    test('a navbar do celular passa de 4,5:1 no ativo e no inativo', () {
      expect(contrast(AppColors.primaryDark, AppColors.primarySurface),
          greaterThanOrEqualTo(4.5));
      expect(contrast(AppColors.text3, AppColors.background),
          greaterThanOrEqualTo(4.5));
    });
  });
}
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
  });

  testWidgets('SkeletonListItem anima sem quebrar o layout', (tester) async {
    await _pump(tester, const SkeletonListItem());
```

por:

```dart
  });

  testWidgets(
      'PillNavBar do celular usa os tons do tablet: ativo em primaryDark '
      'sobre primarySurface, inativo em text3 (Fase 8C)', (tester) async {
    await _pump(
      tester,
      PillNavBar(
        currentIndex: 0,
        onSelect: (_) {},
        items: const [
          PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
          PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
        ],
      ),
    );

    expect(tester.widget<Text>(find.text('Sessões')).style!.color,
        AppColors.primaryDark);
    expect(tester.widget<Icon>(find.byIcon(AppIcons.sessions)).color,
        AppColors.primaryDark);
    expect(tester.widget<Text>(find.text('Perfil')).style!.color,
        AppColors.text3);
    expect(tester.widget<Icon>(find.byIcon(AppIcons.profile)).color,
        AppColors.text3);
    final active = tester.widget<Container>(find
        .ancestor(of: find.text('Sessões'), matching: find.byType(Container))
        .first);
    expect((active.decoration! as BoxDecoration).color, AppColors.primarySurface);
  });

  testWidgets('StatusChip mauve escreve em mauveInk (Fase 8C)', (tester) async {
    await _pump(
      tester,
      const StatusChip(
        label: 'Somente teórica',
        icon: AppIcons.theoryOnly,
        tone: StatusTone.mauve,
      ),
    );

    expect(tester.widget<Text>(find.text('Somente teórica')).style!.color,
        AppColors.mauveInk);
    expect(tester.widget<Icon>(find.byIcon(AppIcons.theoryOnly)).color,
        AppColors.mauveInk);
  });

  testWidgets('SkeletonListItem anima sem quebrar o layout', (tester) async {
    await _pump(tester, const SkeletonListItem());
```

Em `test/ui/session_consultants/session_consultants_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/app_localization.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
```

por:

```dart
import 'package:simtc/ui/core/app_localization.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
```

Em `test/ui/session_consultants/session_consultants_screen_test.dart`, substituir:

```dart
    expect(teamRow.top - teamTitle.bottom, closeTo(10, 0.5));
    expect(tester.getRect(find.text('SIM Treinamentos')).right, 412 - 20);

    // A nota do fim: 16 acima, 20 dos lados, 24 abaixo.
```

por:

```dart
    expect(teamRow.top - teamTitle.bottom, closeTo(10, 0.5));
    expect(tester.getRect(find.text('SIM Treinamentos')).right, 412 - 20);
    // Texto que se lê: o cinza que passa de 4,5:1 (Fase 8C).
    expect(
      tester.widget<Text>(find.text('SIM Treinamentos')).style!.color,
      AppColors.textSubtle,
    );

    // A nota do fim: 16 acima, 20 dos lados, 24 abaixo.
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/theme/app_contrast_test.dart test/ui/core/widgets/display_widgets_test.dart test/ui/add_participant/add_participant_screen_test.dart test/ui/session_consultants/session_consultants_screen_test.dart`
Esperado: `+0 -4: Some tests failed.` — os quatro arquivos não compilam: `AppColors.mauveInk` e `AppColors.textSubtle` não existem.

- [ ] **Step 3: Implementar**

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
                iconColor: AppColors.mauve,
```

por:

```dart
                iconColor: AppColors.mauveInk,
```

Em `lib/ui/core/theme/app_colors.dart`, substituir:

```dart
  static const Color mauve = Color(0xFF9B80A8);
  static const Color mauveSoft = Color(0xFFF5F0F8);
```

por:

```dart
  static const Color mauve = Color(0xFF9B80A8);

  /// Tinta do "Somente teórica" — ícone e texto do chip e do cartão de tipo
  /// da 1.11. É a do canvas; o [mauve] fica como tom de marca do tema.
  static const Color mauveInk = Color(0xFF6B4A7A);
  static const Color mauveSoft = Color(0xFFF5F0F8);
```

Em `lib/ui/core/theme/app_colors.dart`, substituir:

```dart
  static const Color text3 = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // ─── Severidade B/PM/M — mesma escala do painel web ───────────────────────
```

por:

```dart
  static const Color text3 = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  /// Texto informativo pequeno que se lê ("opcional", "6 itens"): o
  /// [textMuted] dá 2,6:1 sobre o branco; este dá 4,8:1 (Fase 8C). O
  /// [textMuted] fica no exemplo dos campos, no desativado e nos ícones
  /// decorativos.
  static const Color textSubtle = Color(0xFF64748B);

  // ─── Severidade B/PM/M — mesma escala do painel web ───────────────────────
```

Em `lib/ui/core/theme/app_colors.dart`, substituir:

```dart
  static const Color dangerBorder = Color(0xFFFCA5A5);
```

por:

```dart
  /// O contorno vermelho do canvas, em todo lugar (Fase 8C).
  static const Color dangerBorder = Color(0xFFE9A2A2);
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
      _inter(size: 11.5, weight: FontWeight.w400, height: 1.2, color: AppColors.textMuted);
```

por:

```dart
      _inter(size: 11.5, weight: FontWeight.w400, height: 1.2, color: AppColors.textSubtle);
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
  static TextStyle get link =>
      _inter(size: 13.5, weight: FontWeight.w600, height: 1.2, color: AppColors.primary);
```

por:

```dart
  /// O verde da marca um tom abaixo: o `primary` dá 3,4:1 sobre o branco
  /// (Fase 8C).
  static TextStyle get link =>
      _inter(size: 13.5, weight: FontWeight.w600, height: 1.2, color: AppColors.primaryHover);
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
      _inter(size: 12, weight: FontWeight.w400, height: 1.3, color: AppColors.textMuted);
```

por:

```dart
      _inter(size: 12, weight: FontWeight.w400, height: 1.3, color: AppColors.textSubtle);
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
      _mono(size: 12, weight: FontWeight.w600, height: 1.55, color: AppColors.textMuted);
```

por:

```dart
      _mono(size: 12, weight: FontWeight.w600, height: 1.55, color: AppColors.textSubtle);
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
      _inter(size: 12.5, weight: FontWeight.w500, height: 1.2, color: AppColors.textMuted);
```

por:

```dart
      _inter(size: 12.5, weight: FontWeight.w500, height: 1.2, color: AppColors.textSubtle);
```

Em `lib/ui/core/widgets/pill_nav_bar.dart`, substituir:

```dart
  /// Os quadros do tablet desenham a barra com borda, e o item ativo em
  /// `primarySurface`/`primaryDark` — não nos tons da pílula do celular.
```

por:

```dart
  /// Os quadros do tablet desenham a barra com borda. O item ativo em
  /// `primarySurface`/`primaryDark` vale também para o celular (Fase 8C).
```

Em `lib/ui/core/widgets/pill_nav_bar.dart`, substituir:

```dart
  Widget _buildItem(PillNavItem item, bool isSelected, VoidCallback onTap) {
    final ink = isSelected ? AppColors.accent : AppColors.textMuted;
```

por:

```dart
  /// O canvas do celular desenha o ativo em `accent` sobre o próprio tom e o
  /// inativo em `textMuted` (2,3:1 e 2,5:1); o app usa os tons do tablet, que
  /// passam de 4,5:1 (Fase 8C).
  Widget _buildItem(PillNavItem item, bool isSelected, VoidCallback onTap) {
    final ink = isSelected ? AppColors.primaryDark : AppColors.text3;
```

Em `lib/ui/core/widgets/pill_nav_bar.dart`, substituir:

```dart
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.16)
                : Colors.transparent,
```

por:

```dart
            color: isSelected ? AppColors.primarySurface : Colors.transparent,
```

Em `lib/ui/core/widgets/status_chip.dart`, substituir:

```dart
        StatusTone.mauve => AppColors.mauve,
```

por:

```dart
        StatusTone.mauve => AppColors.mauveInk,
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
            style: AppTypography.meta.copyWith(color: AppColors.textMuted),
```

por:

```dart
            style: AppTypography.meta.copyWith(color: AppColors.textSubtle),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/theme/app_contrast_test.dart test/ui/core/widgets/display_widgets_test.dart test/ui/add_participant/add_participant_screen_test.dart test/ui/session_consultants/session_consultants_screen_test.dart`
Esperado: `+93: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1123: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/test/ui/core/theme/app_contrast_test.dart apps/mobile/simtc/lib/ui/add_participant/add_participant_screen.dart apps/mobile/simtc/lib/ui/core/theme/app_colors.dart apps/mobile/simtc/lib/ui/core/theme/app_typography.dart apps/mobile/simtc/lib/ui/core/widgets/pill_nav_bar.dart apps/mobile/simtc/lib/ui/core/widgets/status_chip.dart apps/mobile/simtc/lib/ui/session_consultants/session_consultants_screen.dart apps/mobile/simtc/test/ui/add_participant/add_participant_screen_test.dart apps/mobile/simtc/test/ui/core/widgets/display_widgets_test.dart apps/mobile/simtc/test/ui/session_consultants/session_consultants_screen_test.dart
git commit -m "feat(mobile): cores e contraste do acabamento"
```

---

## Task 2: Tipografia e medidas do canvas

Os três `copyWith(fontWeight: …)` que não mudavam o peso (a Inter é variável, e o peso vem do `fontVariations`) viram estilos com nome: `progressLabel` (500) e `blockTitle` (600). A faixa de contexto fica nas medidas dos quadros: `3a`/`3c` com 12 de recuo, logo de 40, empresa em 14 e 2 até a linha de apoio; `3b` (a 1.12, `spacious`) com 14, 44, 15 e 3. As observações da 1.12 em 15/1,45; o adicionar do detalhe com ícone de 20; o "Atribuir a mim" com canto 10; o vão entre rótulo e valor do Perfil com 14 no celular e 16 no tablet; e o "Sair da conta" do tablet guarda a largura enquanto sai (o indicador por cima do rótulo escondido).

**Files:**
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/widgets/app_buttons.dart`
- Modify: `lib/ui/core/widgets/app_text_field.dart`
- Modify: `lib/ui/core/widgets/company_logo.dart`
- Modify: `lib/ui/core/widgets/session_card.dart`
- Modify: `lib/ui/core/widgets/session_context_header.dart`
- Modify: `lib/ui/profile/profile_screen.dart`
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Modify: `lib/ui/session_edit/session_edit_screen.dart`
- Modify: `lib/ui/sessions/sessions_screen.dart`
- Modify: `test/ui/core/theme/app_theme_test.dart`
- Modify: `test/ui/core/widgets/display_widgets_test.dart`
- Modify: `test/ui/core/widgets/form_widgets_test.dart`
- Modify: `test/ui/profile/profile_layout_test.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`
- Modify: `test/ui/session_edit/session_edit_screen_test.dart`
- Modify: `test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: nada das tasks anteriores.
- Produces:
  - `AppTypography.progressLabel`, `blockTitle`, `contextTitleCompact` e `fieldValueMultiline`
  - `SessionContextHeader(spacious:)`, `CompanyLogo.context` (40) e `AppIconAction(iconSize:)` (padrão 22)

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/core/theme/app_theme_test.dart`, substituir:

```dart
    });

    test('estilos variáveis carregam o eixo wght correspondente ao peso', () {
      final style = AppTypography.button;
```

por:

```dart
    });

    test('os pesos médios do "meta" são estilos próprios, com o eixo wght '
        '(Fase 8C)', () {
      // Um `copyWith(fontWeight:)` não mexe no `fontVariations`: o peso
      // pedido não aparecia.
      expect(AppTypography.progressLabel.fontSize, AppTypography.meta.fontSize);
      expect(AppTypography.progressLabel.color, AppTypography.meta.color);
      expect(AppTypography.progressLabel.fontVariations,
          contains(const FontVariation('wght', 500)));
      expect(AppTypography.blockTitle.fontSize, AppTypography.meta.fontSize);
      expect(AppTypography.blockTitle.fontVariations,
          contains(const FontVariation('wght', 600)));
    });

    test('estilos variáveis carregam o eixo wght correspondente ao peso', () {
      final style = AppTypography.button;
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

por:

```dart
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/theme/app_typography.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Bracell'));
    expect(taps, 1);
  });

  testWidgets('SessionCard mostra o logo da empresa antes do nome', (tester) async {
    await _pump(
```

por:

```dart
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Bracell'));
    expect(taps, 1);
  });

  testWidgets('SessionCard escreve o progresso no peso 500 de verdade (Fase 8C)',
      (tester) async {
    await _pump(
      tester,
      const SessionCard(
        companyName: 'Bracell',
        courseName: 'Direção Preventiva',
        meta: 'Hoje · Itabira/MG',
        statusChip: StatusChip(
          label: 'Em andamento',
          icon: AppIcons.sessions,
          tone: StatusTone.info,
        ),
        progressLabel: '3 de 8 avaliados',
        progressValue: 0.375,
      ),
    );

    expect(tester.widget<Text>(find.text('3 de 8 avaliados')).style,
        AppTypography.progressLabel);
  });

  testWidgets('SessionCard mostra o logo da empresa antes do nome', (tester) async {
    await _pump(
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
    });

    testWidgets('nome e apoio compridos encolhem com reticências, sem estourar',
        (tester) async {
```

por:

```dart
    });

    testWidgets('a normal tem as medidas dos quadros "3a" e "3c": 12 de recuo, '
        'logo de 40, empresa em 14 e 2 até a linha de apoio (Fase 8C)',
        (tester) async {
      await _pump(
        tester,
        const Column(
          children: [
            SessionContextHeader(companyName: 'Bracell', subtitle: 'Curso'),
          ],
        ),
      );

      expect(tester.getSize(find.byType(CompanyLogo)), const Size(40, 40));
      expect(tester.widget<Text>(find.text('Bracell')).style!.fontSize, 14);
      expect(
        tester.getRect(find.text('Curso')).top -
            tester.getRect(find.text('Bracell')).bottom,
        2,
      );
      expect(tester.getSize(find.byType(SessionContextHeader)).height,
          12 + 40 + 12 + 1);
    });

    testWidgets('a espaçosa tem as do quadro "3b": 14 de recuo, logo de 44, '
        'empresa em 15 e 3 até a linha de apoio (Fase 8C)', (tester) async {
      await _pump(
        tester,
        const Column(
          children: [
            SessionContextHeader(
              companyName: 'Bracell',
              subtitle: 'Curso',
              spacious: true,
            ),
          ],
        ),
      );

      expect(tester.getSize(find.byType(CompanyLogo)), const Size(44, 44));
      expect(tester.widget<Text>(find.text('Bracell')).style!.fontSize, 15);
      expect(
        tester.getRect(find.text('Curso')).top -
            tester.getRect(find.text('Bracell')).bottom,
        3,
      );
      expect(tester.getSize(find.byType(SessionContextHeader)).height,
          14 + 44 + 14 + 1);
    });

    testWidgets('nome e apoio compridos encolhem com reticências, sem estourar',
        (tester) async {
```

Em `test/ui/core/widgets/form_widgets_test.dart`, substituir:

```dart
      expect(tester.getSize(find.byType(AppTextField)).height, greaterThan(96));
    });
```

por:

```dart
      expect(tester.getSize(find.byType(AppTextField)).height, greaterThan(96));
      // O texto das observações do quadro "3b": 15/1,45 (Fase 8C).
      expect(field.style!.fontSize, 15);
      expect(field.style!.height, 1.45);
    });
```

Em `test/ui/core/widgets/form_widgets_test.dart`, substituir:

```dart
      expect(find.text('Cancelar sessão'), findsNothing);
```

por:

```dart
      // O rótulo fica escondido embaixo do indicador, guardando a largura
      // (Fase 8C): não se vê nem é lido.
      expect(find.bySemanticsLabel('Cancelar sessão'), findsNothing);
```

Em `test/ui/core/widgets/form_widgets_test.dart`, substituir:

```dart
        button.style!.shape!.resolve(const {}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    });

    testWidgets('o tamanho padrão continua com texto 15, ícone 20 e canto 12',
```

por:

```dart
        button.style!.shape!.resolve(const {}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    });

    testWidgets('em carregamento, o compacto sem expandir guarda a largura do '
        'rótulo (Fase 8C)', (tester) async {
      Widget button({required bool loading}) => Align(
            alignment: Alignment.topLeft,
            child: AppDangerOutlineButton(
              label: 'Sair da conta',
              icon: AppIcons.logout,
              compact: true,
              expand: false,
              isLoading: loading,
              onPressed: () {},
            ),
          );

      await _pump(tester, button(loading: false));
      final width = tester.getSize(find.byType(AppDangerOutlineButton)).width;

      await _pump(tester, button(loading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getSize(find.byType(AppDangerOutlineButton)).width, width);
      expect(find.bySemanticsLabel('Sair da conta'), findsNothing,
          reason: 'o rótulo escondido não é lido');
    });

    testWidgets('o tamanho padrão continua com texto 15, ícone 20 e canto 12',
```

Em `test/ui/core/widgets/form_widgets_test.dart`, substituir:

```dart
      expect(text.text.style?.fontSize, 14);
    });

    testWidgets('em carregamento mostra o indicador e não responde ao toque',
        (tester) async {
      var taps = 0;
```

por:

```dart
      expect(text.text.style?.fontSize, 14);
    });

    testWidgets('o compacto tem canto 10, como no quadro; o do cabeçalho '
        'continua com 12 (Fase 8C)', (tester) async {
      ShapeBorder? shape() => tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!
          .shape!
          .resolve(const {});

      await _pump(tester, AppCtaButton(label: 'Atribuir a mim', onPressed: () {}));
      expect(
        shape(),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

      await _pump(
        tester,
        AppCtaButton(
          label: 'Iniciar avaliação',
          size: AppCtaSize.header,
          fullWidth: false,
          onPressed: () {},
        ),
      );
      expect(
        shape(),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
    });

    testWidgets('em carregamento mostra o indicador e não responde ao toque',
        (tester) async {
      var taps = 0;
```

Em `test/ui/profile/profile_layout_test.dart`, substituir:

```dart
    expect(rectOf(tester, find.text('Perfil de acesso')).left, icon.right + 14);
    expect(rectOf(tester, find.text('Consultor')).right, 412 - 20);

    final button = rectOf(tester, find.byType(AppDangerOutlineButton));
```

por:

```dart
    expect(rectOf(tester, find.text('Perfil de acesso')).left, icon.right + 14);
    expect(rectOf(tester, find.text('Consultor')).right, 412 - 20);
    // 14 entre o rótulo e o valor, como no quadro (Fase 8C).
    expect(
      rectOf(tester, find.text('Consultor')).left -
          rectOf(tester, find.ancestor(
            of: find.text('Perfil de acesso'),
            matching: find.byType(Expanded),
          ).first).right,
      14,
    );

    final button = rectOf(tester, find.byType(AppDangerOutlineButton));
```

Em `test/ui/profile/profile_layout_test.dart`, substituir:

```dart
    expect(rectOf(tester, find.text('Consultor')).right, columnRight);
    expect(tester.widget<Text>(find.text('Consultor')).style!.fontSize, 14.5);

    final note = find.textContaining('Sair apaga as sessões');
```

por:

```dart
    expect(rectOf(tester, find.text('Consultor')).right, columnRight);
    expect(tester.widget<Text>(find.text('Consultor')).style!.fontSize, 14.5);
    // 16 entre o rótulo e o valor, como nos quadros (Fase 8C).
    expect(
      rectOf(tester, find.text('Consultor')).left -
          rectOf(tester, find.ancestor(
            of: find.text('Perfil de acesso'),
            matching: find.byType(Expanded),
          ).first).right,
      16,
    );

    final note = find.textContaining('Sair apaga as sessões');
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/theme/app_spacing.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

por:

```dart
import 'package:simtc/ui/core/theme/app_spacing.dart';
import 'package:simtc/ui/core/theme/app_typography.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
    expect(find.text('BC'), findsOneWidget, reason: 'iniciais no lugar do logo');
  });
```

por:

```dart
    expect(find.text('BC'), findsOneWidget, reason: 'iniciais no lugar do logo');
    // O peso 500 de verdade, do eixo wght (Fase 8C).
    expect(
      tester.widget<Text>(find.text('1 de 2 participantes avaliados')).style,
      AppTypography.progressLabel,
    );
  });
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
          const Size(48, 48));
    });
```

por:

```dart
          const Size(48, 48));
      // O ícone de 20 do quadro "1f" (Fase 8C).
      expect(tester.widget<Icon>(find.byIcon(AppIcons.addParticipant)).size, 20);
    });
```

Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/app_text_field.dart';
import 'package:simtc/ui/session_edit/session_edit_screen.dart';
```

por:

```dart
import 'package:simtc/ui/core/widgets/app_text_field.dart';
import 'package:simtc/ui/core/widgets/session_context_header.dart';
import 'package:simtc/ui/session_edit/session_edit_screen.dart';
```

Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:

```dart
    expect(find.text('Pátio 3 — portaria B.'), findsOneWidget);
    expect(find.text('Observações para os consultores'), findsOneWidget);

    expect(saveButton(tester).onPressed, isNull, reason: 'nada mudou ainda');
```

por:

```dart
    expect(find.text('Pátio 3 — portaria B.'), findsOneWidget);
    expect(find.text('Observações para os consultores'), findsOneWidget);
    // A faixa de contexto do quadro "3b" (Fase 8C).
    expect(
      tester.widget<SessionContextHeader>(find.byType(SessionContextHeader)).spacious,
      isTrue,
    );

    expect(saveButton(tester).onPressed, isNull, reason: 'nada mudou ainda');
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/theme/app_spacing.dart';
import 'package:simtc/ui/core/widgets/app_search_field.dart';
```

por:

```dart
import 'package:simtc/ui/core/theme/app_spacing.dart';
import 'package:simtc/ui/core/theme/app_typography.dart';
import 'package:simtc/ui/core/widgets/app_search_field.dart';
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
    expect(find.text('Outras · 1'), findsOneWidget);
    expect(find.text('Suzano Papel'), findsOneWidget);

    // O aviso vem ANTES de "Outras" — não depois.
```

por:

```dart
    expect(find.text('Outras · 1'), findsOneWidget);
    expect(find.text('Suzano Papel'), findsOneWidget);
    // O peso 600 de verdade, do eixo wght (Fase 8C).
    expect(tester.widget<Text>(find.text('Outras · 1')).style,
        AppTypography.blockTitle);

    // O aviso vem ANTES de "Outras" — não depois.
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/theme/app_theme_test.dart test/ui/core/widgets/display_widgets_test.dart test/ui/core/widgets/form_widgets_test.dart test/ui/profile/profile_layout_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/session_edit/session_edit_screen_test.dart test/ui/sessions/sessions_screen_test.dart`
Esperado: `+34 -12: Some tests failed.` — `app_theme_test.dart`, `display_widgets_test.dart`, `session_detail_screen_test.dart`, `session_edit_screen_test.dart` e `sessions_screen_test.dart` não compilam (`progressLabel`, `blockTitle` e `spacious` não existem); falham os quatro testes de `profile_layout_test.dart` (o vão de 12), o das observações em 15/1,45, o do "Sair" que guarda a largura e o do canto 10.

- [ ] **Step 3: Implementar**

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
      _inter(size: 12.5, weight: FontWeight.w400, height: 1.3, color: AppColors.text3);

  /// Cabeçalho de seção de lista ("Hoje · 23 set", "Concluídas")
  static TextStyle get sectionTitle =>
```

por:

```dart
      _inter(size: 12.5, weight: FontWeight.w400, height: 1.3, color: AppColors.text3);

  /// O [meta] no peso 500: o progresso do card e do detalhe ("3 de 8
  /// avaliados").
  static TextStyle get progressLabel =>
      _inter(size: 12.5, weight: FontWeight.w500, height: 1.3, color: AppColors.text3);

  /// O [meta] no peso 600: o título de um bloco da Home ("Outras · 2").
  static TextStyle get blockTitle =>
      _inter(size: 12.5, weight: FontWeight.w600, height: 1.3, color: AppColors.text3);

  /// Cabeçalho de seção de lista ("Hoje · 23 set", "Concluídas")
  static TextStyle get sectionTitle =>
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
      _mono(size: 16, weight: FontWeight.w600, height: 1.3);

  /// Nota à direita do rótulo de um campo ("opcional")
  static TextStyle get fieldOptional =>
```

por:

```dart
      _mono(size: 16, weight: FontWeight.w600, height: 1.3);

  /// Valor de um campo de várias linhas (as observações do quadro "3b")
  static TextStyle get fieldValueMultiline =>
      _inter(size: 15, weight: FontWeight.w400, height: 1.45);

  /// Nota à direita do rótulo de um campo ("opcional")
  static TextStyle get fieldOptional =>
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
  static TextStyle get contextTitle =>
      _inter(size: 15, weight: FontWeight.w600, height: 1.25);

  /// Nome do consultor na tela "Consultores" (canvas "3c")
```

por:

```dart
  static TextStyle get contextTitle =>
      _inter(size: 15, weight: FontWeight.w600, height: 1.25);

  /// A mesma, na faixa de contexto dos quadros "3a" e "3c"
  static TextStyle get contextTitleCompact =>
      _inter(size: 14, weight: FontWeight.w600, height: 1.25);

  /// Nome do consultor na tela "Consultores" (canvas "3c")
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
```

por:

```dart
          ),
          // O compacto ("Atribuir a mim") tem o canto 10 do quadro, como os
          // outros botões de linha de lista (Fase 8C).
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              size == AppCtaSize.compact ? AppRadius.sm + 2 : AppRadius.md,
            ),
          ),
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
              compact ? AppTypography.buttonCompact : AppTypography.buttonDanger,
        ),
        child: isLoading ? _buildSpinner() : _buildContent(),
      ),
    );
  }
```

por:

```dart
              compact ? AppTypography.buttonCompact : AppTypography.buttonDanger,
        ),
        child: isLoading ? _buildLoading() : _buildContent(),
      ),
    );
  }

  /// O indicador por cima do rótulo escondido: sem [expand], o botão guarda a
  /// largura do rótulo em vez de encolher para a do indicador (Fase 8C).
  Widget _buildLoading() {
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
    this.highlighted = false,
  });
```

por:

```dart
    this.highlighted = false,
    this.iconSize = 22,
  });
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
  /// do fundo escurecido (quadros "4l", "4m" e "4n").
  final bool highlighted;

  @override
```

por:

```dart
  /// do fundo escurecido (quadros "4l", "4m" e "4n").
  final bool highlighted;

  /// 22 na barra do topo; 20 no adicionar da linha "Participantes" (quadro
  /// "1f").
  final double iconSize;

  @override
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
        icon: Icon(icon, size: 22),
```

por:

```dart
        icon: Icon(icon, size: iconSize),
```

Em `lib/ui/core/widgets/app_text_field.dart`, substituir:

```dart
    if (widget.obscureText) return AppTypography.passwordDots;
    return widget.mono ? AppTypography.fieldValueMono : AppTypography.fieldValue;
```

por:

```dart
    if (widget.obscureText) return AppTypography.passwordDots;
    if (_isMultiline) return AppTypography.fieldValueMultiline;
    return widget.mono ? AppTypography.fieldValueMono : AppTypography.fieldValue;
```

Em `lib/ui/core/widgets/company_logo.dart`, substituir:

```dart
class CompanyLogo extends StatelessWidget {
  /// 44 de lado, para o card da Home (tela 1.3).
```

por:

```dart
class CompanyLogo extends StatelessWidget {
  /// 40 de lado, na faixa de contexto das telas de admin (quadros "3a" e
  /// "3c").
  const CompanyLogo.context({super.key, required this.companyName, this.url})
      : _size = AppSpacing.huge - AppSpacing.sm,
        _radius = AppRadius.sm;

  /// 44 de lado, para o card da Home (tela 1.3).
```

Em `lib/ui/core/widgets/session_card.dart`, substituir:

```dart
              style: AppTypography.meta.copyWith(fontWeight: FontWeight.w500),
```

por:

```dart
              style: AppTypography.progressLabel,
```

Em `lib/ui/core/widgets/session_context_header.dart`, substituir:

```dart
    this.muted = false,
  });
```

por:

```dart
    this.muted = false,
    this.spacious = false,
  });
```

Em `lib/ui/core/widgets/session_context_header.dart`, substituir:

```dart
  final bool muted;

  @override
  Widget build(BuildContext context) {
```

por:

```dart
  final bool muted;

  /// As medidas do quadro "3b" (Dados do treinamento): 14 de recuo, logo de
  /// 44, empresa em 15 e 3 até a linha de apoio. Sem ela, as dos quadros
  /// "3a" e "3c": 12, 40, 14 e 2 (Fase 8C).
  final bool spacious;

  @override
  Widget build(BuildContext context) {
```

Em `lib/ui/core/widgets/session_context_header.dart`, substituir:

```dart
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          CompanyLogo.card(companyName: companyName, url: logoUrl),
```

por:

```dart
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: spacious ? AppSpacing.md + 2 : AppSpacing.md,
      ),
      child: Row(
        children: [
          if (spacious)
            CompanyLogo.card(companyName: companyName, url: logoUrl)
          else
            CompanyLogo.context(companyName: companyName, url: logoUrl),
```

Em `lib/ui/core/widgets/session_context_header.dart`, substituir:

```dart
                  style: AppTypography.contextTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs + 1),
```

por:

```dart
                  style: spacious
                      ? AppTypography.contextTitle
                      : AppTypography.contextTitleCompact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(
                  height: spacious ? AppSpacing.xxs + 1 : AppSpacing.xxs,
                ),
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
              const SizedBox(width: AppSpacing.md),
```

por:

```dart
              // 14 no celular ("2i") e 16 no tablet ("4k"/"4v") (Fase 8C).
              SizedBox(width: tablet ? AppSpacing.lg : AppSpacing.md + 2),
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
                style: AppTypography.meta.copyWith(fontWeight: FontWeight.w500),
```

por:

```dart
                style: AppTypography.progressLabel,
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
            icon: AppIcons.addParticipant,
            tooltip: 'Adicionar participante',
```

por:

```dart
            icon: AppIcons.addParticipant,
            iconSize: 20,
            tooltip: 'Adicionar participante',
```

Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:

```dart
          subtitle: session.courseName,
        ),
```

por:

```dart
          subtitle: session.courseName,
          spacious: true,
        ),
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
            style: AppTypography.meta.copyWith(fontWeight: FontWeight.w600),
```

por:

```dart
            style: AppTypography.blockTitle,
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/theme/app_theme_test.dart test/ui/core/widgets/display_widgets_test.dart test/ui/core/widgets/form_widgets_test.dart test/ui/profile/profile_layout_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/session_edit/session_edit_screen_test.dart test/ui/sessions/sessions_screen_test.dart`
Esperado: `+206: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1129: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/theme/app_typography.dart apps/mobile/simtc/lib/ui/core/widgets/app_buttons.dart apps/mobile/simtc/lib/ui/core/widgets/app_text_field.dart apps/mobile/simtc/lib/ui/core/widgets/company_logo.dart apps/mobile/simtc/lib/ui/core/widgets/session_card.dart apps/mobile/simtc/lib/ui/core/widgets/session_context_header.dart apps/mobile/simtc/lib/ui/profile/profile_screen.dart apps/mobile/simtc/lib/ui/session_detail/session_detail_screen.dart apps/mobile/simtc/lib/ui/session_edit/session_edit_screen.dart apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart apps/mobile/simtc/test/ui/core/theme/app_theme_test.dart apps/mobile/simtc/test/ui/core/widgets/display_widgets_test.dart apps/mobile/simtc/test/ui/core/widgets/form_widgets_test.dart apps/mobile/simtc/test/ui/profile/profile_layout_test.dart apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart apps/mobile/simtc/test/ui/session_edit/session_edit_screen_test.dart apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): tipografia e medidas do canvas"
```

---

## Task 3: Ondulação e alvos de toque

A ondulação do toque não aparecia onde o fundo era pintado por um `Container` filho do `InkWell`: o fundo vai para um `Material` embaixo dele (o padrão do Resultado e do Perfil) no card da sessão, na linha do participante, no cabeçalho da categoria aberta, nos B/PM/M, nos cartões de tipo da 1.11, nos chips de filtro e no item ativo da navbar. Os chips ganham 48 de toque (o desenho continua com 34, e a barra com 54), e o campo de texto foca com um toque em qualquer ponto da caixa, com 48 de alvo dentro dos 56.

**Files:**
- Create: `test/support/ripple.dart`
- Modify: `lib/ui/add_participant/add_participant_screen.dart`
- Modify: `lib/ui/checklist/checklist_screen.dart`
- Modify: `lib/ui/core/widgets/app_text_field.dart`
- Modify: `lib/ui/core/widgets/filter_chip_bar.dart`
- Modify: `lib/ui/core/widgets/pill_nav_bar.dart`
- Modify: `lib/ui/core/widgets/session_card.dart`
- Modify: `lib/ui/session_detail/participant_row.dart`
- Modify: `test/ui/add_participant/add_participant_screen_test.dart`
- Modify: `test/ui/checklist/checklist_screen_test.dart`
- Modify: `test/ui/core/widgets/display_widgets_test.dart`
- Modify: `test/ui/core/widgets/form_widgets_test.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`
- Modify: `test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: nada das tasks anteriores.
- Produces:
  - `expectVisibleRipple(WidgetTester, Finder inkWell, {required Color background})` em `test/support/ripple.dart`

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/support/ripple.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A ondulação do toque aparece (Fase 8C): o fundo é de um `Material` acima
/// do [inkWell] na árvore — pintado embaixo da ondulação —, e não de um
/// `Container` filho dele, que pintaria por cima.
void expectVisibleRipple(
  WidgetTester tester,
  Finder inkWell, {
  required Color background,
}) {
  final child = tester.widget<InkWell>(inkWell).child;
  final decoration = child is Container ? child.decoration : null;
  expect(
    decoration is BoxDecoration ? decoration.color : null,
    isNull,
    reason: 'um fundo no filho do InkWell cobre a ondulação',
  );
  final material = tester.widget<Material>(
    find.ancestor(of: inkWell, matching: find.byType(Material)).first,
  );
  expect(material.color, background);
}
```

Em `test/ui/add_participant/add_participant_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_text_field.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

por:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_text_field.dart';

import '../../support/ripple.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

Em `test/ui/add_participant/add_participant_screen_test.dart`, substituir:

```dart
      AppColors.mauveInk,
    );

    expect(addButton(tester).onPressed, isNull, reason: 'nada preenchido');
```

por:

```dart
      AppColors.mauveInk,
    );
    // E os dois cartões mostram a ondulação do toque.
    expectVisibleRipple(tester, find.byKey(const Key('tipo-teoricaEPratica')),
        background: AppColors.primarySurface);
    expectVisibleRipple(tester, find.byKey(const Key('tipo-somenteTeorica')),
        background: AppColors.surface);

    expect(addButton(tester).onPressed, isNull, reason: 'nada preenchido');
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

por:

```dart
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

import '../../support/ripple.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
    expect(find.text('1 item'), findsOneWidget);
  });
```

por:

```dart
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets(
      'o cabeçalho da categoria aberta e os botões B/PM/M mostram a '
      'ondulação do toque (Fase 8C)', (tester) async {
    await pumpScreen(tester);

    Finder inkOf(String text) =>
        find.ancestor(of: find.text(text), matching: find.byType(InkWell)).first;

    expectVisibleRipple(tester, inkOf('Controle do Veículo'),
        background: AppColors.categoryExpandedBg);
    expectVisibleRipple(tester, inkOf('B'), background: AppColors.noteBBg);

    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();
    expectVisibleRipple(tester, inkOf('PM'), background: AppColors.notePmFill);
  });
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/status_chip.dart';
import 'package:simtc/ui/core/widgets/sync_status_indicator.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
```

por:

```dart
import 'package:simtc/ui/core/widgets/status_chip.dart';
import 'package:simtc/ui/core/widgets/sync_status_indicator.dart';

import '../../../support/ripple.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
  testWidgets(
      'quando selectedIndex muda por fora (ex.: destaque por scroll manual), '
```

por:

```dart
  testWidgets(
      'FilterChipBar: o chip tem 34 de desenho e 48 de toque; a barra '
      'continua com 54 (Fase 8C)', (tester) async {
    int? selected;
    await _pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: FilterChipBar(
          selectedIndex: 0,
          onSelect: (i) => selected = i,
          items: const [
            FilterChipData(label: 'Todos', count: 8),
            FilterChipData(label: 'Pendentes', count: 3),
          ],
        ),
      ),
    );

    final chip = find.ancestor(
      of: find.text('Pendentes'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(chip).height, 34);
    expect(tester.getSize(find.byType(FilterChipBar)).height, 54);

    // 6 acima do desenho do chip ainda é dele.
    final rect = tester.getRect(chip);
    await tester.tapAt(Offset(rect.center.dx, rect.top - 6));
    expect(selected, 1);

    // Para o leitor de tela e o alvo de toque, o chip tem 48.
    expect(
      tester.getSemantics(find.text('Pendentes')).rect.height,
      48,
    );
    expect(tester.getSemantics(find.text('Todos')),
        isSemantics(isSelected: true, hasSelectedState: true,
            isButton: true, hasTapAction: true, label: 'Todos\n8'));
  });

  testWidgets('FilterChipBar mostra a ondulação do toque (Fase 8C)',
      (tester) async {
    await _pump(
      tester,
      FilterChipBar(
        selectedIndex: 0,
        onSelect: (_) {},
        items: const [
          FilterChipData(label: 'Todos'),
          FilterChipData(label: 'Pendentes'),
        ],
      ),
    );

    expectVisibleRipple(
      tester,
      find.ancestor(of: find.text('Todos'), matching: find.byType(InkWell)),
      background: AppColors.primary,
    );
    expectVisibleRipple(
      tester,
      find.ancestor(of: find.text('Pendentes'), matching: find.byType(InkWell)),
      background: AppColors.surface,
    );
  });

  testWidgets(
      'quando selectedIndex muda por fora (ex.: destaque por scroll manual), '
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Bracell'));
    expect(taps, 1);
  });

  testWidgets('SessionCard escreve o progresso no peso 500 de verdade (Fase 8C)',
      (tester) async {
```

por:

```dart
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Bracell'));
    expect(taps, 1);
  });

  testWidgets('SessionCard mostra a ondulação do toque, comum e destacado '
      '(Fase 8C)', (tester) async {
    Widget card({required bool selected}) => SessionCard(
          companyName: 'Bracell',
          courseName: 'Direção Preventiva',
          meta: 'Hoje · Itabira/MG',
          statusChip: const StatusChip(
            label: 'Planejado',
            icon: AppIcons.sessions,
            tone: StatusTone.info,
          ),
          selected: selected,
          onTap: () {},
        );

    await _pump(tester, card(selected: false));
    expectVisibleRipple(tester, find.byType(InkWell),
        background: AppColors.surface);

    await _pump(tester, card(selected: true));
    expectVisibleRipple(tester, find.byType(InkWell),
        background: AppColors.categoryExpandedBg);
  });

  testWidgets('SessionCard escreve o progresso no peso 500 de verdade (Fase 8C)',
      (tester) async {
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
    final active = tester.widget<Container>(find
        .ancestor(of: find.text('Sessões'), matching: find.byType(Container))
        .first);
    expect((active.decoration! as BoxDecoration).color, AppColors.primarySurface);
```

por:

```dart
    expectVisibleRipple(
      tester,
      find.ancestor(of: find.text('Sessões'), matching: find.byType(InkWell)),
      background: AppColors.primarySurface,
    );
```

Em `test/ui/core/widgets/form_widgets_test.dart`, substituir:

```dart
      expect(field.style!.height, 1.45);
    });
```

por:

```dart
      expect(field.style!.height, 1.45);
    });

    testWidgets('o campo de uma linha tem 48 de toque, e tocar no ícone foca o '
        'campo; a caixa continua com 56 (Fase 8C)', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(
          label: 'E-mail',
          icon: AppIcons.email,
          controller: controller,
        ),
      );

      expect(tester.getSize(find.byType(TextField)).height,
          greaterThanOrEqualTo(48));
      final box = find.descendant(
        of: find.byType(AppTextField),
        matching: find.byWidgetPredicate((w) =>
            w is Container && w.constraints?.minHeight == 56),
      );
      expect(tester.getSize(box).height, 56);

      await tester.tap(find.byIcon(AppIcons.email));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue);
    });
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/session_edit/session_edit_screen.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}
```

por:

```dart
import 'package:simtc/ui/session_edit/session_edit_screen.dart';
import 'package:simtc/utils/result.dart';

import '../../support/ripple.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
      expect(find.text('Mariana Costa'), findsOneWidget);
      expect(find.text('Ana Paula Ribeiro'), findsNothing);
    });
  });

  group('avaliação deste aparelho na linha "comigo"', () {
```

por:

```dart
      expect(find.text('Mariana Costa'), findsOneWidget);
      expect(find.text('Ana Paula Ribeiro'), findsNothing);
    });
  });

  testWidgets(
      'a linha mostra a ondulação do toque; a de outro consultor, sobre o '
      'fundo apagado (Fase 8C)', (tester) async {
    await show(tester, withParticipants: [
      participant('1', 'Ana Paula Ribeiro'),
      participant('3', 'Marcos Vinícius Alves',
          status: ParticipantStatus.emAvaliacao,
          assignedTo: 'c-outro',
          assignedName: 'Rafael Lima'),
    ]);

    Finder inkOf(String id) => find
        .descendant(
          of: find.byKey(ValueKey('participante-$id')),
          matching: find.byType(InkWell),
        )
        .first;

    expectVisibleRipple(tester, inkOf('1'), background: AppColors.surface);
    expectVisibleRipple(tester, inkOf('3'), background: AppColors.background);
  });

  group('avaliação deste aparelho na linha "comigo"', () {
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
    final inkWell = tester.widget<InkWell>(find.widgetWithText(InkWell, label));
    final container = inkWell.child! as Container;
    final decoration = container.decoration! as BoxDecoration;
    return decoration.color == AppColors.primary;
```

por:

```dart
    // O fundo do chip é do `Material` embaixo do `InkWell` (Fase 8C).
    final material = tester.widget<Material>(find
        .ancestor(
          of: find.widgetWithText(InkWell, label),
          matching: find.byType(Material),
        )
        .first);
    return material.color == AppColors.primary;
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
      expect(decoration.color, AppColors.categoryExpandedBg);
```

por:

```dart
      // O fundo é do `Material` embaixo do toque (Fase 8C).
      expect(
        tester
            .widget<Material>(find
                .ancestor(of: selected.first, matching: find.byType(Material))
                .first)
            .color,
        AppColors.categoryExpandedBg,
      );
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/widgets/display_widgets_test.dart test/ui/core/widgets/form_widgets_test.dart test/ui/add_participant/add_participant_screen_test.dart test/ui/checklist/checklist_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/sessions/sessions_screen_test.dart`
Esperado: `+229 -15: Some tests failed.` — os testes novos da ondulação (chips, card, navbar, linha, cabeçalho aberto e B/PM/M, cartões de tipo), o dos 48 de toque do chip e o do campo de texto; e os da Home que leem o chip destacado e o card destacado, que agora olham o `Material` (`isChipSelected`).

- [ ] **Step 3: Implementar**

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: Key('tipo-${type.name}'),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: _fieldsEnabled
            ? () => _viewModel.setParticipationType(type)
            : null,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.touchTarget + AppSpacing.lg,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs + 2,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderStrong,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.primaryDark : iconColor,
              ),
              const SizedBox(height: AppSpacing.xxs + 1),
              Text(
                label,
                style: selected
                    ? AppTypography.optionCardSelected
                    : AppTypography.optionCard,
                textAlign: TextAlign.center,
              ),
            ],
```

por:

```dart
    // O fundo é do `Material`, embaixo do `InkWell`, para a ondulação do
    // toque aparecer (Fase 8C).
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primarySurface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          key: Key('tipo-${type.name}'),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: _fieldsEnabled
              ? () => _viewModel.setParticipationType(type)
              : null,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.touchTarget + AppSpacing.lg,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs + 2,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.borderStrong,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppColors.primaryDark : iconColor,
                ),
                const SizedBox(height: AppSpacing.xxs + 1),
                Text(
                  label,
                  style: selected
                      ? AppTypography.optionCardSelected
                      : AppTypography.optionCard,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
    return InkWell(
      key: _openHeaderKey,
      onTap: () => _viewModel.toggleCategory(category.id),
      child: Container(
        padding: _categoryPadding,
        decoration: const BoxDecoration(
          color: AppColors.categoryExpandedBg,
          border: Border(bottom: BorderSide(color: AppColors.categoryExpandedBorder)),
        ),
        child: Row(
          children: [
            CategoryCodeChip(
              code: category.code,
              background: AppColors.primary,
              ink: AppColors.surface,
            ),
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
            const Icon(AppIcons.expandLess, size: 22, color: AppColors.text3),
          ],
```

por:

```dart
    // O fundo é do `Material`, embaixo do `InkWell`, para a ondulação do
    // toque aparecer (Fase 8C).
    return Material(
      color: AppColors.categoryExpandedBg,
      child: InkWell(
        key: _openHeaderKey,
        onTap: () => _viewModel.toggleCategory(category.id),
        child: Container(
          padding: _categoryPadding,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.categoryExpandedBorder)),
          ),
          child: Row(
            children: [
              CategoryCodeChip(
                code: category.code,
                background: AppColors.primary,
                ink: AppColors.surface,
              ),
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
              const Icon(AppIcons.expandLess, size: 22, color: AppColors.text3),
            ],
          ),
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        height: AppSpacing.controlHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.bg,
          border: Border.all(color: colors.border, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(note.noteType, style: AppTypography.noteButton.copyWith(color: colors.ink)),
```

por:

```dart
    // O fundo é do `Material`, embaixo do `InkWell`, para a ondulação do
    // toque aparecer (Fase 8C).
    return Material(
      color: colors.bg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: AppSpacing.controlHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: colors.border, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(note.noteType, style: AppTypography.noteButton.copyWith(color: colors.ink)),
        ),
```

Em `lib/ui/core/widgets/app_text_field.dart`, substituir:

```dart
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  bool get _isMultiline => widget.maxLines != 1;

  @override
  void initState() {
```

por:

```dart
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  bool get _isMultiline => widget.maxLines != 1;

  static const double _singleLinePadding = AppSpacing.md + 2;

  @override
  void initState() {
```

Em `lib/ui/core/widgets/app_text_field.dart`, substituir:

```dart
    if (!widget.readOnly) return box;
```

por:

```dart
    // Um toque em qualquer ponto da caixa (no ícone, ou acima e abaixo do
    // texto) foca o campo, e não só na linha do texto (Fase 8C).
    if (!widget.readOnly) {
      return GestureDetector(
        excludeFromSemantics: true,
        onTap: widget.enabled ? _focusNode.requestFocus : null,
        child: box,
      );
    }
```

Em `lib/ui/core/widgets/app_text_field.dart`, substituir:

```dart
        contentPadding: EdgeInsets.zero,
```

por:

```dart
        // Numa linha, 14 em cima e embaixo dão ao campo os 48 do alvo de
        // toque, dentro da caixa de 56 (Fase 8C).
        contentPadding: _isMultiline
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(vertical: _singleLinePadding),
```

Em `lib/ui/core/widgets/filter_chip_bar.dart`, substituir:

```dart
      padding: EdgeInsets.symmetric(
        horizontal: widget.horizontalPadding,
        vertical: AppSpacing.sm + 2,
```

por:

```dart
      // Os 10 de cima e de baixo do canvas, menos a margem de toque que cada
      // chip já tem: a barra continua com a mesma altura.
      padding: EdgeInsets.symmetric(
        horizontal: widget.horizontalPadding,
        vertical: AppSpacing.sm + 2 - _tapMargin,
```

Em `lib/ui/core/widgets/filter_chip_bar.dart`, substituir:

```dart
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.xxxl + 2),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.borderStrong,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: AppTypography.chipLabel.copyWith(color: ink, fontSize: 12.5),
            ),
            if (item.count != null) ...[
              const SizedBox(width: AppSpacing.xs + 1),
              Text(
                '${item.count}',
                style: AppTypography.counter.copyWith(
                  color: ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
```

por:

```dart
    // O chip desenha 34 de altura (canvas), mas o toque vale nos 48 em volta
    // dele, e o leitor de tela o lê como um nó só, desse tamanho (Fase 8C).
    return MergeSemantics(
      key: key,
      child: Semantics(
        button: true,
        selected: isSelected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: _tapMargin),
            child: _buildChipFace(item, isSelected, ink, onTap),
          ),
        ),
      ),
    );
  }

  /// O fundo é do `Material`, embaixo do `InkWell`, para a ondulação do
  /// toque aparecer (Fase 8C).
  Widget _buildChipFace(
    FilterChipData item,
    bool isSelected,
    Color ink,
    VoidCallback onTap,
  ) {
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: _chipHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: isSelected ? AppColors.primaryDark : AppColors.borderStrong,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: AppTypography.chipLabel.copyWith(color: ink, fontSize: 12.5),
              ),
              if (item.count != null) ...[
                const SizedBox(width: AppSpacing.xs + 1),
                Text(
                  '${item.count}',
                  style: AppTypography.counter.copyWith(
                    color: ink.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// A altura que o chip desenha (canvas) e a margem de toque em cima e
  /// embaixo, que completa os 48 do alvo mínimo.
  static const double _chipHeight = AppSpacing.xxxl + 2;
  static const double _tapMargin = (AppSpacing.touchTarget - _chipHeight) / 2;
```

Em `lib/ui/core/widgets/pill_nav_bar.dart`, substituir:

```dart
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
```

por:

```dart
    // O fundo do ativo é do `Material`, embaixo do `InkWell`, para a
    // ondulação do toque aparecer (Fase 8C).
    return Semantics(
      selected: isSelected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? AppColors.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox(
            height: height,
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
```

Em `lib/ui/core/widgets/pill_nav_bar.dart`, substituir:

```dart
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 52,
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
                  Icon(item.icon, size: 22, color: ink),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(item.label, style: AppTypography.navLabel.copyWith(color: ink)),
                ],
              ),
              if (item.badgeCount > 0) _buildBadge(item.badgeCount),
            ],
```

por:

```dart
      child: Material(
        color: isSelected ? AppColors.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 22, color: ink),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(item.label, style: AppTypography.navLabel.copyWith(color: ink)),
                  ],
                ),
                if (item.badgeCount > 0) _buildBadge(item.badgeCount),
              ],
            ),
```

Em `lib/ui/core/widgets/session_card.dart`, substituir:

```dart
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
```

por:

```dart
    // O fundo é do `Material`, embaixo do `InkWell`: num `Container` filho
    // dele, pintaria por cima da ondulação do toque (Fase 8C).
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? AppColors.categoryExpandedBg : AppColors.surface,
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
```

Em `lib/ui/core/widgets/session_card.dart`, substituir:

```dart
        color: AppColors.surface,
        border: Border(top: BorderSide(color: accentColor, width: _accentWidth)),
      );

  static const BoxDecoration _selectedDecoration = BoxDecoration(
    color: AppColors.categoryExpandedBg,
```

por:

```dart
        border: Border(top: BorderSide(color: accentColor, width: _accentWidth)),
      );

  static const BoxDecoration _selectedDecoration = BoxDecoration(
```

Em `lib/ui/session_detail/participant_row.dart`, substituir:

```dart
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg - 1),
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
              Padding(
                padding: _sides,
                child: Text(blockedNote!, style: AppTypography.meta),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              Padding(padding: _sides, child: action!),
            ],
          ],
```

por:

```dart
    // O fundo é do `Material`, embaixo do `InkWell`: num `Container` filho
    // dele, pintaria por cima da ondulação do toque (Fase 8C).
    return Material(
      color: muted ? AppColors.background : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg - 1),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: accentColor, width: 0.8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              if (blockedNote != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: _sides,
                  child: Text(blockedNote!, style: AppTypography.meta),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.md),
                Padding(padding: _sides, child: action!),
              ],
            ],
          ),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/widgets/display_widgets_test.dart test/ui/core/widgets/form_widgets_test.dart test/ui/add_participant/add_participant_screen_test.dart test/ui/checklist/checklist_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/sessions/sessions_screen_test.dart`
Esperado: `+244: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1135: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/test/support/ripple.dart apps/mobile/simtc/lib/ui/add_participant/add_participant_screen.dart apps/mobile/simtc/lib/ui/checklist/checklist_screen.dart apps/mobile/simtc/lib/ui/core/widgets/app_text_field.dart apps/mobile/simtc/lib/ui/core/widgets/filter_chip_bar.dart apps/mobile/simtc/lib/ui/core/widgets/pill_nav_bar.dart apps/mobile/simtc/lib/ui/core/widgets/session_card.dart apps/mobile/simtc/lib/ui/session_detail/participant_row.dart apps/mobile/simtc/test/ui/add_participant/add_participant_screen_test.dart apps/mobile/simtc/test/ui/checklist/checklist_screen_test.dart apps/mobile/simtc/test/ui/core/widgets/display_widgets_test.dart apps/mobile/simtc/test/ui/core/widgets/form_widgets_test.dart apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): ondulacao e alvos de toque"
```

---

## Task 4: Toque duplo abre uma tela só

Um toque que abre uma tela ou uma janela reserva a abertura até o próximo quadro, e não abre nada se outra tela já estiver por cima (ver "Ajustes"). Vale para os cards da Home no celular, as linhas do detalhe, o "Finalizar avaliação", o "Reavaliar" e a confirmação do "Sair da conta", reservada depois de contar as avaliações iniciadas. As telas de admin já não entram duas vezes (a chave de página do go_router); o teste do lápis fica como rede.

**Files:**
- Create: `lib/ui/core/open_once.dart`
- Modify: `lib/ui/checklist/checklist_screen.dart`
- Modify: `lib/ui/profile/profile_screen.dart`
- Modify: `lib/ui/result/result_screen.dart`
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Modify: `lib/ui/sessions/sessions_screen.dart`
- Modify: `test/ui/checklist/checklist_screen_test.dart`
- Modify: `test/ui/profile/profile_screen_test.dart`
- Modify: `test/ui/result/result_screen_test.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`
- Modify: `test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: nada das tasks anteriores.
- Produces:
  - `extension OpenOnce on BuildContext` com `bool claimOpen()` em `lib/ui/core/open_once.dart`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
      find.text('Sem conexão — as marcações continuam sendo salvas no aparelho.'),
      findsOneWidget,
    );
  });

  testWidgets(
```

por:

```dart
      find.text('Sem conexão — as marcações continuam sendo salvas no aparelho.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'dois toques rápidos em "Finalizar avaliação" abrem uma conferência só '
      '(Fase 8C)', (tester) async {
    await pumpOverOrigin(tester);

    await tester.tap(find.text('Finalizar avaliação'));
    // O segundo toque antes do próximo quadro: a rota nova ainda não
    // está montada.
    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets(
```

Em `test/ui/profile/profile_screen_test.dart`, substituir:

```dart
  group('sair da conta', () {
    testWidgets('sem fila nem rascunho, a confirmação é a simples; '
```

por:

```dart
  group('sair da conta', () {
    testWidgets(
        'dois toques rápidos abrem uma confirmação só, mesmo enquanto as '
        'avaliações iniciadas são contadas (Fase 8C)', (tester) async {
      await h.pump(tester);

      await tester.tap(find.text('Sair da conta'));
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsOneWidget);
    });

    testWidgets('sem fila nem rascunho, a confirmação é a simples; '
```

Em `test/ui/result/result_screen_test.dart`, substituir:

```dart
  });

  testWidgets(
      '"Reavaliar" abre o checklist em "não iniciada" por cima do Resultado: '
```

por:

```dart
  });

  testWidgets('dois toques rápidos em "Reavaliar" abrem um checklist só '
      '(Fase 8C)', (tester) async {
    await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
    serverAnswers(serverJson());
    await pumpResult(tester);

    await tester.tap(find.text('Reavaliar'));
    // O segundo toque antes do próximo quadro: a rota nova ainda não
    // está montada.
    await tester.tap(find.text('Reavaliar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets(
      '"Reavaliar" abre o checklist em "não iniciada" por cima do Resultado: '
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
    });

    testWidgets('um concluído abre o Resultado', (tester) async {
      final juliana = participant('4', 'Juliana Freitas Costa',
```

por:

```dart
    });

    testWidgets('dois toques rápidos na linha abrem um checklist só (Fase 8C)',
        (tester) async {
      final ana = participant('1', 'Ana Paula Ribeiro',
          status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      when(() => participants.watchParticipant('1'))
          .thenAnswer((_) => Stream.value(ana));
      await showWithRouter(tester, [ana]);

      await tester.tap(find.text('Ana Paula Ribeiro'));
      // O segundo toque antes do próximo quadro: a rota nova ainda não
      // está montada.
      await tester.tap(find.text('Ana Paula Ribeiro'));
      await tester.pumpAndSettle();

      expect(find.byType(ChecklistScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets(
        'dois toques rápidos no lápis do ADMIN abrem uma tela só (Fase 8C)',
        (tester) async {
      when(() => auth.currentUser).thenReturn(admin);
      await showWithRouter(tester, [participant('1', 'Ana Paula Ribeiro')]);

      await tester.tap(find.byTooltip('Editar dados do treinamento'));
      // O segundo toque antes do próximo quadro: a rota nova ainda não
      // está montada.
      await tester.tap(find.byTooltip('Editar dados do treinamento'));
      // A 1.12 anima o skeleton enquanto carrega: sem `pumpAndSettle`.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SessionEditScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('um concluído abre o Resultado', (tester) async {
      final juliana = participant('4', 'Juliana Freitas Costa',
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

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

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
  String titleText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('sessions-title'))).data!;

  testWidgets(
```

por:

```dart
  String titleText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('sessions-title'))).data!;

  testWidgets(
      'dois toques rápidos num card abrem um detalhe só (Fase 8C)',
      (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const SessionsScreen(),
        ),
        GoRoute(
          path: '/sessions/:id',
          builder: (_, __) => const Scaffold(body: Text('detalhe')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: repository),
          Provider<AssessmentCatalogRepository>.value(value: catalog),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    sessions.add([hoje()]);
    await tester.pump();

    await tester.tap(find.byType(SessionCard));
    // O segundo toque antes do próximo quadro: a rota nova ainda não
    // está montada.
    await tester.tap(find.byType(SessionCard));
    await tester.pumpAndSettle();

    expect(find.text('detalhe', skipOffstage: false), findsOneWidget);
  });

  testWidgets(
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/sessions/sessions_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/checklist/checklist_screen_test.dart test/ui/result/result_screen_test.dart test/ui/profile/profile_screen_test.dart`
Esperado: `+182 -5: Some tests failed.` — os testes de dois toques rápidos no card da Home, na linha do detalhe, no "Finalizar avaliação", no "Reavaliar" e no "Sair da conta" (o do lápis do ADMIN já passa: é rede para a guarda). Os toques são no mesmo quadro: o segundo chega antes de o go_router montar a rota nova.

- [ ] **Step 3: Implementar**

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
import '../core/form_factor.dart';
import '../core/score_labels.dart';
```

por:

```dart
import '../core/form_factor.dart';
import '../core/open_once.dart';
import '../core/score_labels.dart';
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
  Future<void> _openSummary() async {
    final exit = await context.push<SummaryExit>(
```

por:

```dart
  Future<void> _openSummary() async {
    if (!context.claimOpen()) return;
    final exit = await context.push<SummaryExit>(
```

Criar `lib/ui/core/open_once.dart`:

```dart
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Dois toques rápidos no que abre uma tela abrem uma só (Fase 8C).
extension OpenOnce on BuildContext {
  /// Reserva a abertura de uma tela ou janela a partir desta. Falso — e o
  /// toque não faz nada — quando outra abertura já foi pedida e a tela nova
  /// ainda não chegou ao próximo quadro (o go_router só monta a rota nele),
  /// ou quando outra tela já está por cima desta, inclusive enquanto entra.
  bool claimOpen() {
    if (_OpenGate.pending || !(ModalRoute.isCurrentOf(this) ?? true)) {
      return false;
    }
    _OpenGate.hold();
    return true;
  }
}

/// A trava vale até o fim do próximo quadro: aí a rota nova já está no
/// `Navigator`, e o `ModalRoute.isCurrentOf` assume. Ela não depende de a
/// tela abrir — se nada abrir, solta do mesmo jeito.
abstract final class _OpenGate {
  static bool pending = false;

  static void hold() {
    pending = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => pending = false)
      ..ensureVisualUpdate();
  }
}
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../core/form_factor.dart';
import '../core/open_once.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
    final queued = context.read<AssessmentSyncService>().queue.length;
    final drafts = await _viewModel.countStartedDrafts();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
```

por:

```dart
    final queued = context.read<AssessmentSyncService>().queue.length;
    final drafts = await _viewModel.countStartedDrafts();
    // A confirmação só abre depois de contar as avaliações iniciadas: o
    // segundo de dois toques rápidos conta de novo, mas não abre outra
    // (Fase 8C).
    if (!mounted || !context.claimOpen()) return;

    final confirmed = await showDialog<bool>(
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../core/form_factor.dart';
import '../core/open_once.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
  void _reevaluate() {
    context.push(
```

por:

```dart
  void _reevaluate() {
    if (!context.claimOpen()) return;
    context.push(
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../core/form_factor.dart';
import '../core/open_once.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
      return () => context.push(
            AppRoutes.participantChecklist(widget.sessionId, participant.id),
          );
    }
    if (_viewModel.opensResult(participant)) {
      return () => context.push(
            AppRoutes.participantResult(widget.sessionId, participant.id),
          );
```

por:

```dart
      return () {
        if (!context.claimOpen()) return;
        context.push(
          AppRoutes.participantChecklist(widget.sessionId, participant.id),
        );
      };
    }
    if (_viewModel.opensResult(participant)) {
      return () {
        if (!context.claimOpen()) return;
        context.push(
          AppRoutes.participantResult(widget.sessionId, participant.id),
        );
      };
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../core/form_factor.dart';
import '../core/open_once.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
        } else {
```

por:

```dart
        } else if (context.claimOpen()) {
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/sessions/sessions_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/checklist/checklist_screen_test.dart test/ui/result/result_screen_test.dart test/ui/profile/profile_screen_test.dart`
Esperado: `+187: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1141: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/open_once.dart apps/mobile/simtc/lib/ui/checklist/checklist_screen.dart apps/mobile/simtc/lib/ui/profile/profile_screen.dart apps/mobile/simtc/lib/ui/result/result_screen.dart apps/mobile/simtc/lib/ui/session_detail/session_detail_screen.dart apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart apps/mobile/simtc/test/ui/checklist/checklist_screen_test.dart apps/mobile/simtc/test/ui/profile/profile_screen_test.dart apps/mobile/simtc/test/ui/result/result_screen_test.dart apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): toque duplo abre uma tela so"
```

---

## Task 5: Leitor de tela

Os B/PM/M dizem se estão marcados; a data da 1.12 vira um nó só ("Data, 12 set 2026, botão"); os cartões de tipo dizem selecionado e desativado; o título da janela de admin é cabeçalho e nomeia a janela (`namesRoute`), para o TalkBack anunciá-la; os títulos de tela e de seção são cabeçalhos; e a contagem "N de M participantes" e as frases de nenhum resultado das buscas são anunciadas quando mudam (`liveRegion`).

**Files:**
- Modify: `lib/ui/add_participant/add_participant_screen.dart`
- Modify: `lib/ui/checklist/checklist_screen.dart`
- Modify: `lib/ui/core/widgets/admin_dialog.dart`
- Modify: `lib/ui/core/widgets/app_text_field.dart`
- Modify: `lib/ui/core/widgets/app_top_bar.dart`
- Modify: `lib/ui/profile/profile_screen.dart`
- Modify: `lib/ui/result/result_screen.dart`
- Modify: `lib/ui/session_consultants/session_consultants_screen.dart`
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Modify: `lib/ui/sessions/sessions_screen.dart`
- Modify: `lib/ui/sync/sync_screen.dart`
- Modify: `test/ui/add_participant/add_participant_screen_test.dart`
- Modify: `test/ui/checklist/checklist_screen_test.dart`
- Modify: `test/ui/core/widgets/display_widgets_test.dart`
- Modify: `test/ui/profile/profile_screen_test.dart`
- Modify: `test/ui/result/result_screen_test.dart`
- Modify: `test/ui/session_consultants/session_consultants_screen_test.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`
- Modify: `test/ui/session_edit/session_edit_screen_test.dart`
- Modify: `test/ui/sessions/sessions_screen_test.dart`
- Modify: `test/ui/sync/sync_screen_test.dart`

**Interfaces:**
- Consumes: o fundo no `Material` dos B/PM/M e dos cartões de tipo (Task 3).
- Produces:
  - nada que outra task use

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/add_participant/add_participant_screen_test.dart`, substituir:

```dart
      AppColors.mauveInk,
    );
```

por:

```dart
      AppColors.mauveInk,
    );
    // O leitor de tela diz qual cartão está escolhido e que eles respondem
    // ao toque (Fase 8C).
    expect(
      tester.getSemantics(find.byKey(const Key('tipo-teoricaEPratica'))),
      isSemantics(
        isButton: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
```

Em `test/ui/add_participant/add_participant_screen_test.dart`, substituir:

```dart
      );
      expect(addButton(tester).onPressed, isNull);
    });
  });
```

por:

```dart
      );
      expect(addButton(tester).onPressed, isNull);
      // O leitor de tela diz que os cartões de tipo estão desativados
      // (Fase 8C).
      expect(
        tester.getSemantics(find.byKey(const Key('tipo-somenteTeorica'))),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
    });
  });
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
    expectVisibleRipple(tester, inkOf('PM'), background: AppColors.notePmFill);
  });
```

por:

```dart
    expectVisibleRipple(tester, inkOf('PM'), background: AppColors.notePmFill);
  });

  testWidgets(
      'o leitor de tela diz qual dos B/PM/M está marcado (Fase 8C)',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('PM')),
      isSemantics(label: 'PM', isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('B')),
      isSemantics(label: 'B', isButton: true, isSelected: false),
    );
  });
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
      expect(find.text('O que será avaliado'), findsOneWidget);
      expect(find.text('PM'), findsNothing);
```

por:

```dart
      expect(find.text('O que será avaliado'), findsOneWidget);
      // O título da lista é cabeçalho para o leitor de tela (Fase 8C).
      expect(tester.getSemantics(find.text('O que será avaliado')),
          isSemantics(isHeader: true));
      expect(find.text('PM'), findsNothing);
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/theme/app_typography.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

por:

```dart
import 'package:simtc/ui/core/theme/app_typography.dart';
import 'package:simtc/ui/core/widgets/admin_dialog.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
  });

  testWidgets('AppTopBar põe os atalhos entre o título e o indicador',
      (tester) async {
```

por:

```dart
  });

  testWidgets('AppTopBar: o título é cabeçalho para o leitor de tela (Fase 8C)',
      (tester) async {
    await _pump(tester, const AppTopBar(title: 'Detalhe da sessão'));

    expect(
      tester.getSemantics(find.text('Detalhe da sessão')),
      isSemantics(label: 'Detalhe da sessão', isHeader: true),
    );
  });

  testWidgets(
      'AdminDialogFrame: o título é cabeçalho e nomeia a janela, para o '
      'leitor de tela anunciá-la ao abrir (Fase 8C)', (tester) async {
    await _pump(
      tester,
      AdminDialogFrame(
        title: 'Adicionar participante',
        subtitle: 'Bracell · Direção Defensiva',
        onClose: () {},
        body: const SizedBox(height: 40),
      ),
    );

    expect(
      tester.getSemantics(find.text('Adicionar participante')),
      isSemantics(
        label: 'Adicionar participante',
        isHeader: true,
        namesRoute: true,
      ),
    );
  });

  testWidgets('AppTopBar põe os atalhos entre o título e o indicador',
      (tester) async {
```

Em `test/ui/profile/profile_screen_test.dart`, substituir:

```dart
    expect(tester.widget<PillNavBar>(find.byType(PillNavBar)).currentIndex, 2);
  });
```

por:

```dart
    expect(tester.widget<PillNavBar>(find.byType(PillNavBar)).currentIndex, 2);
    // O título da aba é cabeçalho para o leitor de tela (Fase 8C).
    expect(tester.getSemantics(find.text('Perfil').first),
        isSemantics(isHeader: true));
  });
```

Em `test/ui/result/result_screen_test.dart`, substituir:

```dart
    expect(find.text('Desempenho por categoria'), findsOneWidget);
    expect(find.text('70,0%'), findsOneWidget, reason: 'o selo de CV');
```

por:

```dart
    expect(find.text('Desempenho por categoria'), findsOneWidget);
    // Os títulos das seções são cabeçalhos (Fase 8C).
    expect(tester.getSemantics(find.text('Desempenho por categoria')),
        isSemantics(isHeader: true));
    expect(find.text('70,0%'), findsOneWidget, reason: 'o selo de CV');
```

Em `test/ui/session_consultants/session_consultants_screen_test.dart`, substituir:

```dart
    expect(tester.getRect(find.text('SIM Treinamentos')).right, 412 - 20);
    // Texto que se lê: o cinza que passa de 4,5:1 (Fase 8C).
```

por:

```dart
    expect(tester.getRect(find.text('SIM Treinamentos')).right, 412 - 20);
    // Os títulos das seções são cabeçalhos para o leitor de tela (Fase 8C).
    expect(
      tester.getSemantics(find.text('Na sessão')),
      isSemantics(label: 'Na sessão', isHeader: true),
    );
    expect(
      tester.getSemantics(find.text('Disponíveis na equipe')),
      isSemantics(label: 'Disponíveis na equipe', isHeader: true),
    );
    // Texto que se lê: o cinza que passa de 4,5:1 (Fase 8C).
```

Em `test/ui/session_consultants/session_consultants_screen_test.dart`, substituir:

```dart
      );
      expect(find.text('Na sessão'), findsNothing);
```

por:

```dart
      );
      // A frase é anunciada quando aparece (Fase 8C).
      expect(
        tester.getSemantics(find.text('Nenhum consultor encontrado para “xyz”.')),
        isSemantics(isLiveRegion: true),
      );
      expect(find.text('Na sessão'), findsNothing);
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
    expect(find.text('BC'), findsOneWidget, reason: 'iniciais no lugar do logo');
    // O peso 500 de verdade, do eixo wght (Fase 8C).
```

por:

```dart
    expect(find.text('BC'), findsOneWidget, reason: 'iniciais no lugar do logo');
    // "Participantes" é cabeçalho para o leitor de tela (Fase 8C).
    expect(
      tester.getSemantics(find.text('Participantes')),
      isSemantics(label: 'Participantes', isHeader: true),
    );
    // O peso 500 de verdade, do eixo wght (Fase 8C).
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
      expect(find.text('0 de 3 participantes'), findsOneWidget);
    });
```

por:

```dart
      expect(find.text('0 de 3 participantes'), findsOneWidget);
      // A frase e a contagem são anunciadas quando mudam (Fase 8C).
      expect(
        tester.getSemantics(
            find.text('Nenhum participante encontrado para “xyz”.')),
        isSemantics(isLiveRegion: true),
      );
      expect(
        tester.getSemantics(find.text('0 de 3 participantes')),
        isSemantics(isLiveRegion: true),
      );
    });
```

Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:

```dart
    expect(find.text('Observações para os consultores'), findsOneWidget);
    // A faixa de contexto do quadro "3b" (Fase 8C).
```

por:

```dart
    expect(find.text('Observações para os consultores'), findsOneWidget);
    // A data é um nó só para o leitor de tela: "Data, 12 set 2026, botão"
    // (Fase 8C).
    expect(
      tester.getSemantics(find.byKey(const Key('campo-data'))),
      isSemantics(
        label: 'Data',
        value: '12 set 2026',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('Data'), findsOneWidget);
    // A faixa de contexto do quadro "3b" (Fase 8C).
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
    expect(find.text('Suzano Papel'), findsOneWidget);
    // O peso 600 de verdade, do eixo wght (Fase 8C).
```

por:

```dart
    expect(find.text('Suzano Papel'), findsOneWidget);
    // O título da tela e os das seções são cabeçalhos (Fase 8C).
    expect(
      tester.getSemantics(find.byKey(const Key('sessions-title'))),
      isSemantics(isHeader: true),
    );
    expect(
      tester.getSemantics(find.textContaining('Hoje · ')),
      isSemantics(isHeader: true),
    );
    // O peso 600 de verdade, do eixo wght (Fase 8C).
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
      expect(find.textContaining('Hoje · '), findsNothing);
    });
```

por:

```dart
      expect(find.textContaining('Hoje · '), findsNothing);
      // A frase é anunciada quando aparece (Fase 8C).
      expect(
        tester.getSemantics(find.text('Nenhuma sessão encontrada para “xyz”.')),
        isSemantics(isLiveRegion: true),
      );
    });
```

Em `test/ui/sync/sync_screen_test.dart`, substituir:

```dart
    expect(find.text('Pendentes'), findsOneWidget);
    expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
```

por:

```dart
    expect(find.text('Pendentes'), findsOneWidget);
    // O título da aba e o da lista são cabeçalhos (Fase 8C).
    expect(tester.getSemantics(find.text('Sincronizar').first),
        isSemantics(isHeader: true));
    expect(tester.getSemantics(find.text('Pendentes')),
        isSemantics(isHeader: true));
    expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/widgets/display_widgets_test.dart test/ui/checklist/checklist_screen_test.dart test/ui/add_participant/add_participant_screen_test.dart test/ui/session_edit/session_edit_screen_test.dart test/ui/sessions/sessions_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/session_consultants/session_consultants_screen_test.dart test/ui/sync/sync_screen_test.dart test/ui/result/result_screen_test.dart test/ui/profile/profile_screen_test.dart`
Esperado: `+320 -16: Some tests failed.` — os testes de semântica novos: títulos como cabeçalho (barra do topo, janela de admin, Home, detalhe, Consultores, Sincronizar, Perfil, Resultado, checklist), B/PM/M com selecionado, a data num nó só, os cartões de tipo, e as frases e a contagem anunciadas.

- [ ] **Step 3: Implementar**

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
      selected: selected,
      child: Material(
```

por:

```dart
      selected: selected,
      enabled: _fieldsEnabled,
      child: Material(
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
              child: Text(
                'O que será avaliado',
                style: tablet
                    ? AppTypography.sectionTitleTablet
                    : AppTypography.sectionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
```

por:

```dart
              child: Semantics(
                header: true,
                child: Text(
                  'O que será avaliado',
                  style: tablet
                      ? AppTypography.sectionTitleTablet
                      : AppTypography.sectionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
    // toque aparecer (Fase 8C).
    return Material(
      color: colors.bg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: AppSpacing.controlHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: colors.border, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(note.noteType, style: AppTypography.noteButton.copyWith(color: colors.ink)),
```

por:

```dart
    // toque aparecer. O leitor de tela diz qual está marcado (Fase 8C).
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            height: AppSpacing.controlHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: colors.border, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(note.noteType, style: AppTypography.noteButton.copyWith(color: colors.ink)),
          ),
```

Em `lib/ui/core/widgets/admin_dialog.dart`, substituir:

```dart
                Text(title, style: AppTypography.dialogTitle),
```

por:

```dart
                // O leitor de tela anuncia a janela pelo título (Fase 8C).
                Semantics(
                  header: true,
                  namesRoute: true,
                  child: Text(title, style: AppTypography.dialogTitle),
                ),
```

Em `lib/ui/core/widgets/app_text_field.dart`, substituir:

```dart
    return Column(
```

por:

```dart
    final field = Column(
```

Em `lib/ui/core/widgets/app_text_field.dart`, substituir:

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
    if (!widget.readOnly) return field;

    // Só leitura (a data): um nó só para o leitor de tela, com o rótulo, o
    // valor e o toque — e não três soltos (Fase 8C).
    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      value: widget.controller.text,
      onTap: widget.enabled ? widget.onTap : null,
      excludeSemantics: true,
      child: field,
    );
  }
```

Em `lib/ui/core/widgets/app_text_field.dart`, substituir:

```dart
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: IgnorePointer(child: box),
      ),
```

por:

```dart
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      child: IgnorePointer(child: box),
```

Em `lib/ui/core/widgets/app_top_bar.dart`, substituir:

```dart
            child: Text(
              title,
              // 18 no tablet (quadros "4e", "4g" e "4i").
              style: context.isTablet
                  ? AppTypography.appBarTitleTablet
                  : AppTypography.appBarTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
```

por:

```dart
            child: Semantics(
              header: true,
              child: Text(
                title,
                // 18 no tablet (quadros "4e", "4g" e "4i").
                style: context.isTablet
                    ? AppTypography.appBarTitleTablet
                    : AppTypography.appBarTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
      child: Text(
        'Perfil',
        style: tablet ? AppTypography.homeTitle : AppTypography.screenTitle,
```

por:

```dart
      child: Semantics(
        header: true,
        child: Text(
          'Perfil',
          style: tablet ? AppTypography.homeTitle : AppTypography.screenTitle,
        ),
```

Em `lib/ui/result/result_screen.dart`, substituir:

```dart
          Expanded(child: Text(title, style: AppTypography.sectionTitle)),
```

por:

```dart
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: AppTypography.sectionTitle),
            ),
          ),
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
          child: InlineNotice(
            icon: AppIcons.search,
            message: 'Nenhum consultor encontrado para '
                '“${_viewModel.searchQuery.trim()}”.',
```

por:

```dart
          // Anunciada quando aparece, enquanto se digita (Fase 8C).
          child: Semantics(
            liveRegion: true,
            child: InlineNotice(
              icon: AppIcons.search,
              message: 'Nenhum consultor encontrado para '
                  '“${_viewModel.searchQuery.trim()}”.',
            ),
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
      child: Text('Na sessão', style: AppTypography.sectionTitle),
```

por:

```dart
      child: Semantics(
        header: true,
        child: Text('Na sessão', style: AppTypography.sectionTitle),
      ),
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
            child: Text(
              'Disponíveis na equipe',
              style: AppTypography.sectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
```

por:

```dart
            child: Semantics(
              container: true,
              header: true,
              child: Text(
                'Disponíveis na equipe',
                style: AppTypography.sectionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
          if (_viewModel.searchCountLabel case final label?)
            Padding(
              padding: EdgeInsets.fromLTRB(_inset, AppSpacing.md, _inset, 0),
              child: Text(label, style: AppTypography.meta),
```

por:

```dart
          // Anunciada quando muda, enquanto se digita (Fase 8C).
          if (_viewModel.searchCountLabel case final label?)
            Padding(
              padding: EdgeInsets.fromLTRB(_inset, AppSpacing.md, _inset, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(label, style: AppTypography.meta),
              ),
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
    final title = Text('Participantes', style: AppTypography.sectionTitle);
```

por:

```dart
    final title = Semantics(
      header: true,
      child: Text('Participantes', style: AppTypography.sectionTitle),
    );
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
    return Padding(
      padding: EdgeInsets.fromLTRB(_inset, 0, _inset, AppSpacing.md),
      child: InlineNotice(icon: AppIcons.profile, message: message),
```

por:

```dart
    // Anunciada quando aparece, enquanto se digita a busca (Fase 8C).
    return Padding(
      padding: EdgeInsets.fromLTRB(_inset, 0, _inset, AppSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: InlineNotice(icon: AppIcons.profile, message: message),
      ),
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
      Text(
        title,
        key: const Key('sessions-title'),
        style: embedded ? AppTypography.screenTitle : AppTypography.homeTitle,
```

por:

```dart
      Semantics(
        header: true,
        child: Text(
          title,
          key: const Key('sessions-title'),
          style: embedded ? AppTypography.screenTitle : AppTypography.homeTitle,
        ),
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
        child: Text(section.title, style: AppTypography.sectionTitle),
```

por:

```dart
        child: Semantics(
          header: true,
          child: Text(section.title, style: AppTypography.sectionTitle),
        ),
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
      child: InlineNotice(
        icon: AppIcons.search,
        message: 'Nenhuma sessão encontrada para “$query”.',
```

por:

```dart
      // Anunciada quando aparece, enquanto se digita (Fase 8C).
      child: Semantics(
        liveRegion: true,
        child: InlineNotice(
          icon: AppIcons.search,
          message: 'Nenhuma sessão encontrada para “$query”.',
        ),
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
          Text(
            'Sincronizar',
            style: tablet ? AppTypography.homeTitle : AppTypography.screenTitle,
```

por:

```dart
          Semantics(
            header: true,
            child: Text(
              'Sincronizar',
              style: tablet ? AppTypography.homeTitle : AppTypography.screenTitle,
            ),
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
          child: Text('Pendentes', style: AppTypography.sectionTitle),
```

por:

```dart
          child: Semantics(
            header: true,
            child: Text('Pendentes', style: AppTypography.sectionTitle),
          ),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/widgets/display_widgets_test.dart test/ui/checklist/checklist_screen_test.dart test/ui/add_participant/add_participant_screen_test.dart test/ui/session_edit/session_edit_screen_test.dart test/ui/sessions/sessions_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/session_consultants/session_consultants_screen_test.dart test/ui/sync/sync_screen_test.dart test/ui/result/result_screen_test.dart test/ui/profile/profile_screen_test.dart`
Esperado: `+336: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1144: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/add_participant/add_participant_screen.dart apps/mobile/simtc/lib/ui/checklist/checklist_screen.dart apps/mobile/simtc/lib/ui/core/widgets/admin_dialog.dart apps/mobile/simtc/lib/ui/core/widgets/app_text_field.dart apps/mobile/simtc/lib/ui/core/widgets/app_top_bar.dart apps/mobile/simtc/lib/ui/profile/profile_screen.dart apps/mobile/simtc/lib/ui/result/result_screen.dart apps/mobile/simtc/lib/ui/session_consultants/session_consultants_screen.dart apps/mobile/simtc/lib/ui/session_detail/session_detail_screen.dart apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart apps/mobile/simtc/lib/ui/sync/sync_screen.dart apps/mobile/simtc/test/ui/add_participant/add_participant_screen_test.dart apps/mobile/simtc/test/ui/checklist/checklist_screen_test.dart apps/mobile/simtc/test/ui/core/widgets/display_widgets_test.dart apps/mobile/simtc/test/ui/profile/profile_screen_test.dart apps/mobile/simtc/test/ui/result/result_screen_test.dart apps/mobile/simtc/test/ui/session_consultants/session_consultants_screen_test.dart apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart apps/mobile/simtc/test/ui/session_edit/session_edit_screen_test.dart apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart apps/mobile/simtc/test/ui/sync/sync_screen_test.dart
git commit -m "feat(mobile): leitor de tela"
```

---

## Task 6: Fonte do sistema ampliada

Com a fonte do sistema em 1,3× ou mais, o cabeçalho do detalhe e os filtros rolam junto com a lista (celular e tablet). A pílula do resultado desce para baixo do % quando não cabe; "Tentar novamente" e "Descartar" ficam um embaixo do outro onde não cabem lado a lado; os rótulos da navbar crescem até 1,6× e param; e, na 1.11 e na 1.12, a faixa de sem conexão rola com o formulário quando sobra pouca altura (ver "Ajustes").

**Files:**
- Create: `lib/ui/core/text_scale.dart`
- Modify: `lib/ui/add_participant/add_participant_screen.dart`
- Modify: `lib/ui/core/widgets/connectivity_banner.dart`
- Modify: `lib/ui/core/widgets/final_score_block.dart`
- Modify: `lib/ui/core/widgets/pill_nav_bar.dart`
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Modify: `lib/ui/session_edit/session_edit_screen.dart`
- Modify: `lib/ui/sync/sync_screen.dart`
- Modify: `test/ui/add_participant/add_participant_screen_test.dart`
- Modify: `test/ui/core/widgets/display_widgets_test.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`
- Modify: `test/ui/session_edit/session_edit_screen_test.dart`
- Modify: `test/ui/sync/sync_screen_test.dart`

**Interfaces:**
- Consumes: nada das tasks anteriores.
- Produces:
  - `largeTextScale` (1,3) e `extension TextScaleContext on BuildContext` com `textScale` e `isLargeText`, em `lib/ui/core/text_scale.dart`
  - `PillNavBar.maxLabelScale` (1,6) e `ConnectivityBanner.scrollsBelow` (300)

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/add_participant/add_participant_screen_test.dart`, substituir:

```dart
      findsOneWidget,
    );
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    // Dá para ir preenchendo o resto.
```

por:

```dart
      findsOneWidget,
    );
    // Com espaço, a faixa fica fixa embaixo da barra do topo (Fase 8C).
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text(
          'Sem conexão — adicionar participante precisa de internet.',
        ),
      ),
      findsNothing,
    );
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    // Dá para ir preenchendo o resto.
```

Em `test/ui/add_participant/add_participant_screen_test.dart`, substituir:

```dart
    testWidgets(
        'CPF inscrito por outra pessoa entre a consulta e o toque: o aviso '
```

por:

```dart
    testWidgets(
        'sem conexão, com o teclado aberto num celular de 360x640 e a fonte '
        'em 2×: a faixa rola com o formulário, nada estoura e o campo '
        'continua com o foco (Fase 8C)', (tester) async {
      await seedSession();
      await goOffline();
      await pumpAdd(tester, screen: const Size(360, 640), textScale: 2);
      const banner = 'Sem conexão — adicionar participante precisa de internet.';

      // Em 2×, a faixa e o contexto empurram o CPF para baixo da dobra.
      await tester.scrollUntilVisible(
        field('campo-cpf'),
        200,
        scrollable: find
            .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
            .first,
      );
      await tester.tap(field('campo-cpf'));
      await setKeyboard(tester, 280);

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<TextField>(field('campo-cpf')).focusNode!.hasFocus,
        isTrue,
      );
      // A faixa está no começo da rolagem, e não fixa no topo.
      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      await tester.pump();
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text(banner)),
        findsOneWidget,
      );
    });

    testWidgets(
        'CPF inscrito por outra pessoa entre a consulta e o toque: o aviso '
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
```

por:

```dart
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/final_score_block.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
  });

  testWidgets('SkeletonListItem anima sem quebrar o layout', (tester) async {
    await _pump(tester, const SkeletonListItem());
```

por:

```dart
  });

  group('FinalScoreBlock: a pílula (Fase 8C)', () {
    Future<void> pumpBlock(WidgetTester tester, double width) => _pump(
          tester,
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: const FinalScoreBlock(score: 62.5, approved: false),
            ),
          ),
        );

    testWidgets('cabendo, fica à direita do %, embaixo alinhada com ele',
        (tester) async {
      await pumpBlock(tester, 700);

      final percent = tester.getRect(find.text('62,5%'));
      final pill = tester.getRect(find.text('Não recomendado'));
      expect(pill.left, greaterThan(percent.right));
      expect(pill.top, lessThan(percent.bottom));
    });

    testWidgets('sem espaço, desce para baixo do %, sem quebrar o texto',
        (tester) async {
      await pumpBlock(tester, 330);

      final percent = tester.getRect(find.text('62,5%'));
      final pill = tester.getRect(find.text('Não recomendado'));
      expect(pill.top, greaterThan(percent.bottom));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
      'PillNavBar: os rótulos crescem com a fonte do sistema até 1,6× e '
      'param, sem estourar os itens (Fase 8C)', (tester) async {
    await _pump(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: PillNavBar(
          currentIndex: 0,
          onSelect: (_) {},
          items: const [
            PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
            PillNavItem(icon: AppIcons.sync, label: 'Sincronizar'),
            PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
          ],
        ),
      ),
    );

    final label = tester.renderObject<RenderParagraph>(find.text('Sincronizar'));
    expect(label.textScaler.scale(10), 16);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SkeletonListItem anima sem quebrar o layout', (tester) async {
    await _pump(tester, const SkeletonListItem());
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
      expect(find.text('Ana Paula Ribeiro'), findsNothing);
    });
```

por:

```dart
      expect(find.text('Ana Paula Ribeiro'), findsNothing);
    });
  });

  group('fonte do sistema grande (Fase 8C)', () {
    Finder inList(Finder finder) =>
        find.descendant(of: find.byType(ListView), matching: finder);

    testWidgets('na fonte normal, o cabeçalho e os filtros ficam fixos',
        (tester) async {
      await show(tester, withParticipants: [participant('1', 'Ana Paula Ribeiro')]);

      expect(find.text('Bracell Celulose'), findsOneWidget);
      expect(inList(find.text('Bracell Celulose')), findsNothing);
      expect(inList(find.byType(FilterChipBar)), findsNothing);
    });

    testWidgets('em 1,3×, o cabeçalho e os filtros rolam junto com a lista',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await show(tester, withParticipants: [participant('1', 'Ana Paula Ribeiro')]);

      expect(inList(find.text('Bracell Celulose')), findsOneWidget);
      expect(inList(find.byType(FilterChipBar)), findsOneWidget);
      final header = tester.getTopLeft(find.text('Bracell Celulose')).dy;
      final chips = tester.getTopLeft(find.byType(FilterChipBar)).dy;
      final row = tester.getTopLeft(find.text('Ana Paula Ribeiro')).dy;
      expect(header, lessThan(chips));
      expect(chips, lessThan(row));
    });
```

Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:

```dart
  testWidgets(
      'salvar recusado pelo servidor (403): o motivo aparece, a sessão é '
```

por:

```dart
  testWidgets(
      'sem conexão, com o teclado aberto num celular de 360x640 e a fonte em '
      '2×: a faixa rola com o formulário, nada estoura e o campo continua '
      'com o foco (Fase 8C)', (tester) async {
    await seedSession();
    await goOffline();
    await pumpEdit(tester, screen: const Size(360, 640), textScale: 2);
    const banner = 'Sem conexão — salvar e cancelar precisam de internet.';

    await tester.ensureVisible(field('campo-cidade'));
    await tester.pump();
    await tester.tap(field('campo-cidade'));
    await setKeyboard(tester, 280);

    expect(tester.takeException(), isNull);
    expect(
      tester.widget<TextField>(field('campo-cidade')).focusNode!.hasFocus,
      isTrue,
    );
    // A faixa está no começo da rolagem, e não fixa no topo.
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pump();
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text(banner)),
      findsOneWidget,
    );
  });

  testWidgets(
      'salvar recusado pelo servidor (403): o motivo aparece, a sessão é '
```

Em `test/ui/sync/sync_screen_test.dart`, substituir:

```dart
        ),
      ];

  testWidgets(
```

por:

```dart
        ),
      ];

  group('"Tentar novamente" e "Descartar" (Fase 8C)', () {
    LocalAssessment refused() => queuedAssessment(
          '3',
          participantName: 'Marcos Vinícius Alves',
          status: LocalSyncStatus.error,
          lastAttemptAt: DateTime(2026, 9, 29, 8, 5),
          lastError: SendFailure.refused,
        );

    testWidgets('no celular, um embaixo do outro, na largura inteira e com o '
        'texto numa linha', (tester) async {
      await pump(tester, queue: [refused()], size: const Size(412, 1600));

      final retry = tester.getRect(find.widgetWithText(OutlinedButton, 'Tentar novamente'));
      final discard = tester.getRect(find.widgetWithText(OutlinedButton, 'Descartar'));
      expect(discard.top, retry.bottom + 8);
      expect(retry.width, discard.width);
      expect(retry.left, discard.left);
      expect(tester.getSize(find.text('Tentar novamente')).height,
          lessThan(2 * 14), reason: 'uma linha só');
    });

    testWidgets('com largura (o tablet), lado a lado', (tester) async {
      await pump(
        tester,
        queue: [refused()],
        size: const Size(1280, 800),
        formFactor: FormFactor.tablet,
      );

      final retry = tester.getRect(find.widgetWithText(OutlinedButton, 'Tentar novamente'));
      final discard = tester.getRect(find.widgetWithText(OutlinedButton, 'Descartar'));
      expect(discard.top, retry.top);
      expect(discard.left, retry.right + 8);
    });
  });

  testWidgets(
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/widgets/display_widgets_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/sync/sync_screen_test.dart test/ui/add_participant/add_participant_screen_test.dart test/ui/session_edit/session_edit_screen_test.dart`
Esperado: `+189 -6: Some tests failed.` — a pílula que desce, os rótulos da navbar até 1,6×, os botões da fila empilhados no celular, o cabeçalho do detalhe rolando em 1,3× e a faixa de sem conexão que rola na 1.11 e na 1.12 (o estouro de 2×).

- [ ] **Step 3: Implementar**

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
            ConnectivityBanner(
              isOffline: isOffline,
              message: 'Sem conexão — adicionar participante precisa de internet.',
            ),
            Expanded(child: _buildBody()),
```

por:

```dart
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final banner = ConnectivityBanner(
                    isOffline: isOffline,
                    message: 'Sem conexão — adicionar participante precisa de '
                        'internet.',
                  );
                  // Pouca altura (o teclado aberto num celular baixo): a faixa
                  // rola junto com o formulário, e os botões continuam à
                  // vista (Fase 8C).
                  final bannerScrolls =
                      constraints.maxHeight < ConnectivityBanner.scrollsBelow;
                  return Column(
                    children: [
                      if (!bannerScrolls) banner,
                      Expanded(
                        child: _buildBody(
                          leading: bannerScrolls ? banner : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
```

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
      body: _buildBody(),
      footer: session == null ? null : _buildDialogFooter(isOffline, keyboardOpen),
    );
  }

  Widget _buildBody() {
```

por:

```dart
      body: _buildBody(leading: const SizedBox.shrink()),
      footer: session == null ? null : _buildDialogFooter(isOffline, keyboardOpen),
    );
  }

  /// [leading] é o primeiro item da rolagem: a faixa de sem conexão, quando
  /// ela rola, ou nada. Fica sempre no mesmo lugar, para o formulário não ser
  /// recriado (e perder o foco) quando o teclado abre.
  Widget _buildBody({required Widget leading}) {
```

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
      children: [
        SessionContextHeader(
```

por:

```dart
      children: [
        leading,
        SessionContextHeader(
```

Criar `lib/ui/core/text_scale.dart`:

```dart
import 'package:flutter/widgets.dart';

/// A fonte do sistema em 1,3× ou mais — o "grande" do Android (Fase 8C).
const double largeTextScale = 1.3;

extension TextScaleContext on BuildContext {
  /// Quanto a fonte do sistema amplia o texto (1 é o normal).
  double get textScale => MediaQuery.textScalerOf(this).scale(1);

  /// A fonte do sistema em [largeTextScale] ou mais.
  bool get isLargeText => textScale >= largeTextScale;
}
```

Em `lib/ui/core/widgets/connectivity_banner.dart`, substituir:

```dart
  final bool isOffline;
  final String? message;

  @override
```

por:

```dart
  final bool isOffline;
  final String? message;

  /// Nos formulários de admin (1.11 e 1.12), com menos que isto de altura
  /// entre a barra do topo e o rodapé — o teclado aberto num celular baixo —,
  /// a faixa rola junto com o formulário, em vez de ficar fixa (Fase 8C).
  static const double scrollsBelow = 300;

  @override
```

Em `lib/ui/core/widgets/final_score_block.dart`, substituir:

```dart
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          : result
                              ? AppTypography.resultScoreTablet
                              : AppTypography.summaryScore,
                    ),
                  ],
                ),
              ),
              if (approved != null) ...[
                const SizedBox(width: AppSpacing.md),
                _ResultPill(approved: approved, large: tablet),
              ],
```

por:

```dart
          // A pílula fica à direita do %; quando não cabe ao lado dele
          // (tela estreita ou fonte do sistema grande), desce para baixo,
          // sem quebrar o texto (Fase 8C).
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
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
                        : result
                            ? AppTypography.resultScoreTablet
                            : AppTypography.summaryScore,
                  ),
                ],
              ),
              if (approved != null) _ResultPill(approved: approved, large: tablet),
```

Em `lib/ui/core/widgets/pill_nav_bar.dart`, substituir:

```dart
  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      PillNavLayout.phone => _buildPhone(),
      PillNavLayout.tabletBottom => _buildTabletBottom(),
      PillNavLayout.rail => _buildRail(),
    };
```

por:

```dart
  /// Os rótulos crescem com a fonte do sistema até aqui e param: a barra tem
  /// altura fixa, e em 2× eles estouravam os itens (Fase 8C).
  static const double maxLabelScale = 1.6;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxLabelScale,
      child: switch (layout) {
        PillNavLayout.phone => _buildPhone(),
        PillNavLayout.tabletBottom => _buildTabletBottom(),
        PillNavLayout.rail => _buildRail(),
      },
    );
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
import '../core/open_once.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../core/open_once.dart';
import '../core/text_scale.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
    final session = _viewModel.session;
    if (session == null) return _buildMissingSession();

    // Cabeçalho e chips fixos, lista rolando embaixo — como no canvas.
```

por:

```dart
    final session = _viewModel.session;
    if (session == null) return _buildMissingSession();

    // Com a fonte do sistema grande, o cabeçalho e os filtros rolam junto
    // com a lista: fixos, ocupariam a maior parte da tela (Fase 8C).
    if (context.isLargeText) {
      return _buildParticipantList(
        session,
        isOffline,
        leading: [_buildSessionHeader(session, isOffline), _buildFilters()],
      );
    }

    // Cabeçalho e chips fixos, lista rolando embaixo — como no canvas.
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
  Widget _buildParticipantList(TrainingSession session, bool isOffline) {
```

por:

```dart
  /// [leading] vem antes de tudo, dentro da rolagem: o cabeçalho e os
  /// filtros, com a fonte do sistema grande.
  Widget _buildParticipantList(
    TrainingSession session,
    bool isOffline, {
    List<Widget> leading = const [],
  }) {
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
        children: [
          if (notice != null)
```

por:

```dart
        children: [
          ...leading,
          if (notice != null)
```

Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:

```dart
            ConnectivityBanner(
              isOffline: isOffline,
              message: 'Sem conexão — salvar e cancelar precisam de internet.',
            ),
            Expanded(child: _buildBody(isOffline)),
```

por:

```dart
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final banner = ConnectivityBanner(
                    isOffline: isOffline,
                    message: 'Sem conexão — salvar e cancelar precisam de '
                        'internet.',
                  );
                  // Pouca altura (o teclado aberto num celular baixo): a faixa
                  // rola junto com o formulário, e os botões continuam à
                  // vista (Fase 8C).
                  final bannerScrolls =
                      constraints.maxHeight < ConnectivityBanner.scrollsBelow;
                  return Column(
                    children: [
                      if (!bannerScrolls) banner,
                      Expanded(
                        child: _buildBody(
                          isOffline,
                          leading: bannerScrolls ? banner : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
```

Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:

```dart
  Widget _buildBody(bool isOffline) {
```

por:

```dart
  /// [leading] é o primeiro item da rolagem: a faixa de sem conexão, quando
  /// ela rola, ou nada. Fica sempre no mesmo lugar, para o formulário não ser
  /// recriado (e perder o foco) quando o teclado abre.
  Widget _buildBody(bool isOffline, {required Widget leading}) {
```

Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:

```dart
      children: [
        SessionContextHeader(
```

por:

```dart
      children: [
        leading,
        SessionContextHeader(
```

Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:

```dart
      body: _buildBody(isOffline),
```

por:

```dart
      body: _buildBody(isOffline, leading: const SizedBox.shrink()),
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
import '../core/form_factor.dart';
import '../core/theme/app_colors.dart';
```

por:

```dart
import '../core/form_factor.dart';
import '../core/text_scale.dart';
import '../core/theme/app_colors.dart';
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
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
```

por:

```dart
    final discard = _DiscardButton(
      onPressed: sync.isSending ? null : () => _confirmDiscard(context, sync, item),
    );

    // Lado a lado só onde os dois cabem com o texto numa linha (o tablet);
    // no celular, "Tentar novamente" quebrava em duas linhas: um embaixo do
    // outro, cada um na largura inteira (Fase 8C).
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth / context.textScale >= _sideBySideMinWidth) {
          return Row(
            children: [
              Expanded(child: retry),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: discard),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [retry, const SizedBox(height: AppSpacing.sm), discard],
        );
      },
    );
  }

  /// A largura (na fonte normal) a partir da qual "Tentar novamente" e
  /// "Descartar" cabem lado a lado, cada um com o texto numa linha.
  static const double _sideBySideMinWidth = 480;
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/widgets/display_widgets_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/sync/sync_screen_test.dart test/ui/add_participant/add_participant_screen_test.dart test/ui/session_edit/session_edit_screen_test.dart`
Esperado: `+195: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1153: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/text_scale.dart apps/mobile/simtc/lib/ui/add_participant/add_participant_screen.dart apps/mobile/simtc/lib/ui/core/widgets/connectivity_banner.dart apps/mobile/simtc/lib/ui/core/widgets/final_score_block.dart apps/mobile/simtc/lib/ui/core/widgets/pill_nav_bar.dart apps/mobile/simtc/lib/ui/session_detail/session_detail_screen.dart apps/mobile/simtc/lib/ui/session_edit/session_edit_screen.dart apps/mobile/simtc/lib/ui/sync/sync_screen.dart apps/mobile/simtc/test/ui/add_participant/add_participant_screen_test.dart apps/mobile/simtc/test/ui/core/widgets/display_widgets_test.dart apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart apps/mobile/simtc/test/ui/session_edit/session_edit_screen_test.dart apps/mobile/simtc/test/ui/sync/sync_screen_test.dart
git commit -m "feat(mobile): telas com a fonte do sistema ampliada"
```

---

## Task 7: Falhas do checklist, espera do desatribuir e descarte aceito

O checklist deixa de ficar calado diante de uma falha de gravação no aparelho: ao abrir, "Não foi possível abrir a avaliação neste aparelho." com "Tentar novamente"; ao marcar uma nota, um aviso e o "Não salvo" no cabeçalho até a próxima que grava; no "Iniciar avaliação", um aviso, e o botão volta a ficar ativo. Enquanto o "Desatribuir" espera o backend, o ⋮ vira o indicador de carregamento pequeno. Na aba Sincronizar, o descarte de uma avaliação que foi aceita no meio do caminho diz que não há o que descartar.

**Files:**
- Modify: `lib/ui/checklist/checklist_screen.dart`
- Modify: `lib/ui/checklist/checklist_viewmodel.dart`
- Modify: `lib/ui/core/theme/app_icons.dart`
- Modify: `lib/ui/sync/sync_screen.dart`
- Modify: `test/support/fake_assessment_sync_service.dart`
- Modify: `test/ui/checklist/checklist_screen_test.dart`
- Modify: `test/ui/sync/sync_screen_test.dart`

**Interfaces:**
- Consumes: nada das tasks anteriores.
- Produces:
  - `ChecklistViewModel.loadFailed`, `saveFailed` e `retryLoad()`
  - `AppIcons.notSaved`; `FakeAssessmentSyncService.queueAfterRefusal` (teste)

- [ ] **Step 1: Escrever os testes que falham**

Em `test/support/fake_assessment_sync_service.dart`, substituir:

```dart
  bool discardResult = true;

  /// Se não for nulo, o "Descartar" lança isto — uma falha do banco local.
  Object? discardError;
```

por:

```dart
  bool discardResult = true;

  /// A fila depois de um descarte recusado ([discardResult] falso) — nula,
  /// ela não muda.
  List<LocalAssessment>? queueAfterRefusal;

  /// Se não for nulo, o "Descartar" lança isto — uma falha do banco local.
  Object? discardError;
```

Em `test/support/fake_assessment_sync_service.dart`, substituir:

```dart
    if (!discardResult) return false;
```

por:

```dart
    if (!discardResult) {
      // A avaliação deixou de ser recusa no meio do caminho (reenviada e
      // aceita): ela sai da fila, e o descarte não apaga nada.
      final after = queueAfterRefusal;
      if (after != null) setQueue(after, sendingIds: _sendingIds);
      return false;
    }
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
  });

  testWidgets(
      'a observação da nota escolhida aparece embaixo dos botões, e some ao '
```

por:

```dart
  });

  group('falha ao gravar no aparelho (Fase 8C)', () {
    /// O banco do aparelho recusa gravar em [table] — como um disco cheio.
    Future<void> failWrites(String table) => db.customStatement(
          'CREATE TRIGGER falha_$table BEFORE INSERT ON $table '
          "BEGIN SELECT RAISE(ABORT, 'disco cheio'); END",
        );

    Future<void> allowWrites(String table) =>
        db.customStatement('DROP TRIGGER falha_$table');

    testWidgets(
        'uma nota que não grava avisa, o botão não marca e o "salvo" vira '
        '"Não salvo" até a próxima que grava', (tester) async {
      await pumpScreen(tester);
      await failWrites('local_assessment_items');

      await tester.tap(find.text('PM'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível salvar a nota. Tente de novo.'),
          findsOneWidget);
      expect(find.text('Não salvo'), findsOneWidget);
      expect(find.text('salvo'), findsNothing);
      expect(find.byIcon(AppIcons.notSaved), findsOneWidget);
      expect(tester.getSemantics(find.text('PM')), isSemantics(isSelected: false));

      await allowWrites('local_assessment_items');
      await tester.tap(find.text('PM'));
      await tester.pumpAndSettle();

      expect(find.text('salvo'), findsOneWidget);
      expect(find.text('Não salvo'), findsNothing);
      expect(tester.getSemantics(find.text('PM')), isSemantics(isSelected: true));
    });

    testWidgets(
        '"Iniciar avaliação" que não grava avisa e continua "não iniciada", '
        'com o botão ativo', (tester) async {
      await pumpScreen(tester, started: false);
      await failWrites('local_assessments');

      await tester.tap(find.text('Iniciar avaliação'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível iniciar a avaliação. Tente de novo.'),
          findsOneWidget);
      expect(find.text('não iniciada'), findsOneWidget);
      expect(
        tester
            .widget<AppCtaButton>(
                find.widgetWithText(AppCtaButton, 'Iniciar avaliação'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
        'abrir sem conseguir ler o aparelho: o motivo e "Tentar novamente", '
        'que abre quando a leitura volta', (tester) async {
      await db.customStatement(
          'ALTER TABLE local_assessments RENAME TO local_assessments_fora');
      await pumpScreen(tester, started: false);

      expect(find.text('Não foi possível abrir a avaliação neste aparelho.'),
          findsOneWidget);
      expect(find.text('Iniciar avaliação'), findsNothing);

      await db.customStatement(
          'ALTER TABLE local_assessments_fora RENAME TO local_assessments');
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível abrir a avaliação neste aparelho.'),
          findsNothing);
      expect(find.text('Iniciar avaliação'), findsOneWidget);
    });
  });

  testWidgets(
      'a observação da nota escolhida aparece embaixo dos botões, e some ao '
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
      'com o desatribuir esperando o backend, o menu ⋮ e o "Finalizar" ficam '
      'desabilitados', (tester) async {
```

por:

```dart
      'com o desatribuir esperando o backend, o ⋮ vira o indicador de '
      'carregamento e o "Finalizar" fica desabilitado', (tester) async {
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
    await tester.pumpAndSettle();

    final menu = tester.widget<PopupMenuButton<Object?>>(
      find.byKey(const Key('checklist-menu')),
    );
    expect(menu.enabled, isFalse);
```

por:

```dart
    // O indicador gira enquanto espera: sem `pumpAndSettle`.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // A espera aparece no lugar do ⋮ (Fase 8C).
    expect(find.byKey(const Key('checklist-menu')), findsNothing);
    final waiting = find.byKey(const Key('checklist-desatribuindo'));
    expect(
      find.descendant(of: waiting, matching: find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
    expect(tester.getSize(waiting), const Size(48, 48));
    expect(find.bySemanticsLabel('Desatribuindo…'), findsOneWidget);
```

Em `test/ui/sync/sync_screen_test.dart`, substituir:

```dart
    });

    testWidgets('o descarte deu erro: o mesmo aviso, e o item continua na fila',
        (tester) async {
```

por:

```dart
    });

    testWidgets(
        'a avaliação foi reenviada e aceita com o diálogo aberto: o aviso diz '
        'que não há o que descartar (Fase 8C)', (tester) async {
      await confirmDiscard(
        tester,
        arrange: () {
          sync.discardResult = false;
          sync.queueAfterRefusal = const [];
        },
      );

      expect(
        find.text('Esta avaliação já foi aceita pelo servidor; não há o que '
            'descartar.'),
        findsOneWidget,
      );
      expect(find.text(notDiscarded), findsNothing);
    });

    testWidgets('o descarte deu erro: o mesmo aviso, e o item continua na fila',
        (tester) async {
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/checklist/checklist_screen_test.dart test/ui/sync/sync_screen_test.dart`
Esperado: `+20 -2: Some tests failed.` — `checklist_screen_test.dart` não compila (`AppIcons.notSaved` não existe) e falha o teste do descarte aceito em `sync_screen_test.dart`.

- [ ] **Step 3: Implementar**

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
  Widget _buildMenu(bool isOffline) {
    return KeyedSubtree(
```

por:

```dart
  Widget _buildMenu(bool isOffline) {
    // Com o desatribuir esperando o backend (de 15 a 35 s com a rede lenta),
    // o ⋮ vira o indicador de carregamento pequeno (Fase 8C).
    if (_viewModel.isUnassigning) {
      return KeyedSubtree(
        key: _menuKey,
        child: Semantics(
          label: 'Desatribuindo…',
          child: const SizedBox.square(
            key: Key('checklist-desatribuindo'),
            dimension: AppSpacing.touchTarget,
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.text3),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return KeyedSubtree(
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
        const Icon(AppIcons.syncDone, size: 14, color: AppColors.savedInk),
        const SizedBox(width: AppSpacing.xs),
        Text('salvo', style: AppTypography.savedLabel),
      ],
    );
```

por:

```dart
        ..._buildSavedState(),
      ],
    );
  }

  /// "salvo", ou "Não salvo" em vermelho depois de uma nota que não gravou
  /// (Fase 8C).
  List<Widget> _buildSavedState() {
    if (_viewModel.saveFailed) {
      return [
        const Icon(AppIcons.notSaved, size: 14, color: AppColors.dangerInk),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Não salvo',
          style: AppTypography.savedLabel.copyWith(color: AppColors.dangerInk),
        ),
      ];
    }
    return [
      const Icon(AppIcons.syncDone, size: 14, color: AppColors.savedInk),
      const SizedBox(width: AppSpacing.xs),
      Text('salvo', style: AppTypography.savedLabel),
    ];
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
        children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
      );
```

por:

```dart
        children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
      );
    }

    if (_viewModel.loadFailed) {
      return Padding(
        key: const Key('checklist-load-failed'),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const InlineNotice(
              icon: AppIcons.notSaved,
              tone: NoticeTone.danger,
              message: 'Não foi possível abrir a avaliação neste aparelho.',
            ),
            const SizedBox(height: AppSpacing.md),
            AppSecondaryButton(
              label: 'Tentar novamente',
              icon: AppIcons.retry,
              onPressed: _viewModel.retryLoad,
            ),
          ],
        ),
      );
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
  static const String _draftNotDiscarded =
      'Participante desatribuído, mas a avaliação iniciada não foi apagada do aparelho.';

  StreamSubscription<SessionParticipant?>? _participantSubscription;
```

por:

```dart
  static const String _draftNotDiscarded =
      'Participante desatribuído, mas a avaliação iniciada não foi apagada do aparelho.';
  static const String _noteNotSaved =
      'Não foi possível salvar a nota. Tente de novo.';
  static const String _startFailed =
      'Não foi possível iniciar a avaliação. Tente de novo.';

  StreamSubscription<SessionParticipant?>? _participantSubscription;
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
  bool _unassigning = false;
  String? _assessmentId;
```

por:

```dart
  bool _unassigning = false;
  bool _loadFailed = false;
  bool _saveFailed = false;
  String? _assessmentId;
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
  bool get isLoading => _loading;
  SessionParticipant? get participant => _participant;
```

por:

```dart
  bool get isLoading => _loading;

  /// A leitura do aparelho falhou ao abrir: a tela mostra o motivo e o
  /// "Tentar novamente" ([retryLoad]) no lugar das categorias (Fase 8C).
  bool get loadFailed => _loadFailed;

  /// A última nota marcada não gravou: o "salvo" do cabeçalho vira "Não
  /// salvo" até a próxima que grava (Fase 8C).
  bool get saveFailed => _saveFailed;
  SessionParticipant? get participant => _participant;
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
    final current = await _assessmentRepository.findCurrent(
      trainingParticipantId: participantId,
      ownerUserId: ownerUserId,
    );
    if (_disposed) return;
    // As marcações primeiro: o stream as entrega enquanto o catálogo carrega,
    // e a tela já abre com elas.
    if (current == null) {
      await _checkBlock();
    } else if (await _waits(current)) {
      _resumable = current;
    } else {
      _attach(current);
    }
    if (_disposed) return;

    _catalog = await _catalogRepository.loadCatalog();
    if (_disposed) return;
    if (isStarted) _openFirstCategory();

    _loading = false;
    notifyListeners();
```

por:

```dart
    try {
      final current = await _assessmentRepository.findCurrent(
        trainingParticipantId: participantId,
        ownerUserId: ownerUserId,
      );
      if (_disposed) return;
      // As marcações primeiro: o stream as entrega enquanto o catálogo
      // carrega, e a tela já abre com elas.
      if (current == null) {
        await _checkBlock();
      } else if (await _waits(current)) {
        _resumable = current;
      } else {
        _attach(current);
      }
      if (_disposed) return;

      _catalog = await _catalogRepository.loadCatalog();
      if (_disposed) return;
      if (isStarted) _openFirstCategory();
    } catch (_) {
      // Uma falha do banco do aparelho: sem ela, a tela ficaria no
      // carregamento para sempre (Fase 8C).
      _loadFailed = true;
    }

    _loading = false;
    notifyListeners();
  }

  /// "Tentar novamente" depois de uma leitura que falhou ao abrir.
  Future<void> retryLoad() {
    _loadFailed = false;
    _loading = true;
    notifyListeners();
    return init();
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
      await _block(e.trainingParticipantId);
    } finally {
```

por:

```dart
      await _block(e.trainingParticipantId);
    } catch (_) {
      // Uma falha do banco do aparelho: nada começou, e o botão volta a
      // ficar ativo (Fase 8C).
      _message = _startFailed;
    } finally {
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
    _items = current == noteId
        ? await _assessmentRepository.unmark(
            localAssessmentId: assessmentId,
            infractionId: infractionId,
          )
        : await _assessmentRepository.mark(
            localAssessmentId: assessmentId,
            infractionId: infractionId,
            infractionNoteId: noteId,
          );
```

por:

```dart
    try {
      _items = current == noteId
          ? await _assessmentRepository.unmark(
              localAssessmentId: assessmentId,
              infractionId: infractionId,
            )
          : await _assessmentRepository.mark(
              localAssessmentId: assessmentId,
              infractionId: infractionId,
              infractionNoteId: noteId,
            );
      _saveFailed = false;
    } catch (_) {
      // Não gravou: o botão continua mostrando o que está gravado, e o
      // cabeçalho diz "Não salvo" (Fase 8C).
      _saveFailed = true;
      _message = _noteNotSaved;
    }
```

Em `lib/ui/core/theme/app_icons.dart`, substituir:

```dart
  static const IconData syncDone = Icons.cloud_done_outlined;
  static const IconData sessions = Icons.event_note_outlined;
```

por:

```dart
  static const IconData syncDone = Icons.cloud_done_outlined;

  /// "Não salvo" no cabeçalho do checklist: a última marcação não gravou.
  static const IconData notSaved = Icons.error_outline;
  static const IconData sessions = Icons.event_note_outlined;
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível descartar. Tente de novo.')),
```

por:

```dart
    // Saiu da fila no meio do caminho: foi reenviada e aceita, e não há o que
    // descartar nem tentar de novo (Fase 8C).
    final accepted = !sync.queue.any((queued) => queued.id == item.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accepted
              ? 'Esta avaliação já foi aceita pelo servidor; não há o que '
                  'descartar.'
              : 'Não foi possível descartar. Tente de novo.',
        ),
      ),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/checklist/checklist_screen_test.dart test/ui/sync/sync_screen_test.dart`
Esperado: `+73: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1157: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/checklist/checklist_screen.dart apps/mobile/simtc/lib/ui/checklist/checklist_viewmodel.dart apps/mobile/simtc/lib/ui/core/theme/app_icons.dart apps/mobile/simtc/lib/ui/sync/sync_screen.dart apps/mobile/simtc/test/support/fake_assessment_sync_service.dart apps/mobile/simtc/test/ui/checklist/checklist_screen_test.dart apps/mobile/simtc/test/ui/sync/sync_screen_test.dart
git commit -m "feat(mobile): falhas de gravacao do checklist e espera do desatribuir"
```

---

## Task 8: Erro da primeira descida e diretrizes de acessibilidade

Sem nada no aparelho e com a descida que falhou, a Home mostra o motivo e "Tentar novamente" no lugar das seções vazias, e o detalhe faz o mesmo no lugar do "Puxe para atualizar quando houver conexão" — um aviso só, sem o passageiro. E as telas principais ganham os testes de diretriz do Flutter (alvo de 48 e rótulo em tudo o que se toca), que já passam com as Tasks 3 e 5 e ficam como rede para o que vier depois.

**Files:**
- Create: `test/support/a11y.dart`
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Modify: `lib/ui/session_detail/session_detail_viewmodel.dart`
- Modify: `lib/ui/sessions/sessions_list_viewmodel.dart`
- Modify: `lib/ui/sessions/sessions_screen.dart`
- Modify: `test/ui/add_participant/add_participant_screen_test.dart`
- Modify: `test/ui/auth/login_screen_test.dart`
- Modify: `test/ui/checklist/checklist_screen_test.dart`
- Modify: `test/ui/profile/profile_screen_test.dart`
- Modify: `test/ui/result/result_screen_test.dart`
- Modify: `test/ui/session_consultants/session_consultants_screen_test.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`
- Modify: `test/ui/session_edit/session_edit_screen_test.dart`
- Modify: `test/ui/sessions/sessions_screen_test.dart`
- Modify: `test/ui/summary/summary_screen_test.dart`
- Modify: `test/ui/sync/sync_screen_test.dart`

**Interfaces:**
- Consumes: os alvos e os rótulos das Tasks 3 e 5.
- Produces:
  - `SessionsListViewModel.downloadFailed` e `SessionDetailViewModel.downloadFailed`
  - `expectAccessibleTargets(WidgetTester)` em `test/support/a11y.dart`

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/support/a11y.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

/// As diretrizes de acessibilidade do Flutter para o que se toca (Fase 8C):
/// alvo de pelo menos 48x48 e um rótulo para o leitor de tela. O contraste é
/// conferido nos tokens (`app_contrast_test.dart`): a fonte de teste desenha
/// cada letra como um bloco, e a medida na tela engana.
Future<void> expectAccessibleTargets(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}
```

Em `test/ui/add_participant/add_participant_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_text_field.dart';

import '../../support/ripple.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

por:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_text_field.dart';

import '../../support/a11y.dart';
import '../../support/ripple.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

Em `test/ui/add_participant/add_participant_screen_test.dart`, substituir:

```dart
    expect(find.text('Consultor responsável'), findsNothing);
  });
```

por:

```dart
    expect(find.text('Consultor responsável'), findsNothing);
  });

  testWidgets('tudo o que se toca tem 48 e rótulo (Fase 8C)', (tester) async {
    await seedSession();
    await pumpAdd(tester);

    await expectAccessibleTargets(tester);
  });
```

Em `test/ui/auth/login_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}
```

por:

```dart
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';

import '../../support/a11y.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}
```

Em `test/ui/auth/login_screen_test.dart`, substituir:

```dart
  Rect button(WidgetTester tester) =>
      tester.getRect(find.byType(AppPrimaryButton));

  testWidgets('celular: logo de 150 em cima do formulário, como antes',
```

por:

```dart
  Rect button(WidgetTester tester) =>
      tester.getRect(find.byType(AppPrimaryButton));

  testWidgets('tudo o que se toca tem 48 e rótulo (Fase 8C)', (tester) async {
    await show(tester, size: const Size(412, 915));

    await expectAccessibleTargets(tester);
  });

  testWidgets('celular: logo de 150 em cima do formulário, como antes',
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

import '../../support/ripple.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

por:

```dart
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

import '../../support/a11y.dart';
import '../../support/ripple.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
        reason: 'abaixo de 70% a barra avisa que não aprova');
  });
```

por:

```dart
        reason: 'abaixo de 70% a barra avisa que não aprova');
  });

  testWidgets('tudo o que se toca tem 48 e rótulo, antes e depois de iniciar '
      '(Fase 8C)', (tester) async {
    await pumpScreen(tester, started: false);
    await expectAccessibleTargets(tester);

    await tester.tap(find.text('Iniciar avaliação'));
    await tester.pumpAndSettle();
    await expectAccessibleTargets(tester);
  });
```

Em `test/ui/profile/profile_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/profile/profile_screen.dart';

import '../../support/fake_assessment_sync_service.dart';
import 'profile_harness.dart';
```

por:

```dart
import 'package:simtc/ui/profile/profile_screen.dart';

import '../../support/a11y.dart';
import '../../support/fake_assessment_sync_service.dart';
import 'profile_harness.dart';
```

Em `test/ui/profile/profile_screen_test.dart`, substituir:

```dart
      find.descendant(of: row('sync'), matching: find.text('Nenhum envio')),
      findsOneWidget,
    );
  });

  testWidgets('a navbar marca o Perfil', (tester) async {
```

por:

```dart
      find.descendant(of: row('sync'), matching: find.text('Nenhum envio')),
      findsOneWidget,
    );
  });

  testWidgets('tudo o que se toca tem 48 e rótulo (Fase 8C)', (tester) async {
    await h.pump(tester);

    await expectAccessibleTargets(tester);
  });

  testWidgets('a navbar marca o Perfil', (tester) async {
```

Em `test/ui/result/result_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

por:

```dart
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

import '../../support/a11y.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

Em `test/ui/result/result_screen_test.dart`, substituir:

```dart
    await tester.pumpAndSettle();
  }

  testWidgets(
```

por:

```dart
    await tester.pumpAndSettle();
  }

  testWidgets('tudo o que se toca tem 48 e rótulo (Fase 8C)', (tester) async {
    await seedParticipant(status: 'EM_AVALIACAO');
    await confirmedHere({'inf-1': 'inf-1-PM'});
    await pumpResult(tester, justConfirmed: true);

    await expectAccessibleTargets(tester);
  });

  testWidgets(
```

Em `test/ui/session_consultants/session_consultants_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/session_consultants/consultant_row.dart';
import 'package:simtc/ui/session_consultants/session_consultants_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

por:

```dart
import 'package:simtc/ui/session_consultants/consultant_row.dart';
import 'package:simtc/ui/session_consultants/session_consultants_screen.dart';

import '../../support/a11y.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

Em `test/ui/session_consultants/session_consultants_screen_test.dart`, substituir:

```dart
    expect(find.textContaining('Sem conexão'), findsNothing);
  });
```

por:

```dart
    expect(find.textContaining('Sem conexão'), findsNothing);
  });

  testWidgets('tudo o que se toca tem 48 e rótulo (Fase 8C)', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    await expectAccessibleTargets(tester);
  });
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/session_edit/session_edit_screen.dart';
import 'package:simtc/utils/result.dart';

import '../../support/ripple.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}
```

por:

```dart
import 'package:simtc/ui/session_edit/session_edit_screen.dart';
import 'package:simtc/utils/result.dart';

import '../../support/a11y.dart';
import '../../support/ripple.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
  });

  testWidgets('os chips filtram a lista', (tester) async {
    await show(tester, withParticipants: [
```

por:

```dart
  });

  testWidgets(
      'sessão nunca baixada cuja descida falhou com conexão: o motivo e '
      '"Tentar novamente" (Fase 8C)', (tester) async {
    // A sessão sai do cache antes da resposta do servidor, como no aparelho.
    final reply = Completer<Result<int>>();
    when(() => participants.syncSession('sess-1')).thenAnswer((_) => reply.future);
    await show(tester, withSession: session(downloaded: false));
    reply.complete(Failure(Exception('erro'), 'Erro no servidor.'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Não foi possível baixar os participantes desta sessão.'),
      findsOneWidget,
    );
    expect(find.textContaining('Puxe para atualizar'), findsNothing);
    expect(find.byType(SnackBar), findsNothing, reason: 'um aviso só');

    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    verify(() => participants.syncSession('sess-1')).called(2);
    expect(
      find.text('Não foi possível baixar os participantes desta sessão.'),
      findsNothing,
    );
  });

  testWidgets('os chips filtram a lista', (tester) async {
    await show(tester, withParticipants: [
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
      expect(find.text('Mariana Costa'), findsOneWidget);
      expect(find.text('Ana Paula Ribeiro'), findsNothing);
    });
  });

  group('fonte do sistema grande (Fase 8C)', () {
```

por:

```dart
      expect(find.text('Mariana Costa'), findsOneWidget);
      expect(find.text('Ana Paula Ribeiro'), findsNothing);
    });
  });

  testWidgets('tudo o que se toca tem 48 e rótulo, no consultor e no ADMIN '
      '(Fase 8C)', (tester) async {
    await show(tester, withParticipants: [
      participant('1', 'Ana Paula Ribeiro'),
      participant('3', 'Marcos Vinícius Alves',
          status: ParticipantStatus.emAvaliacao,
          assignedTo: 'c-outro',
          assignedName: 'Rafael Lima'),
    ]);
    await expectAccessibleTargets(tester);

    when(() => auth.currentUser).thenReturn(admin);
    await show(tester, withParticipants: [participant('1', 'Ana Paula Ribeiro')]);
    await expectAccessibleTargets(tester);
  });

  group('fonte do sistema grande (Fase 8C)', () {
```

Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/session_context_header.dart';
import 'package:simtc/ui/session_edit/session_edit_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

por:

```dart
import 'package:simtc/ui/core/widgets/session_context_header.dart';
import 'package:simtc/ui/session_edit/session_edit_screen.dart';

import '../../support/a11y.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:

```dart
  AppDangerOutlineButton cancelButton(WidgetTester tester) =>
      tester.widget<AppDangerOutlineButton>(find.byType(AppDangerOutlineButton));

  testWidgets('mostra o contexto da sessão e os campos com os valores dela',
```

por:

```dart
  AppDangerOutlineButton cancelButton(WidgetTester tester) =>
      tester.widget<AppDangerOutlineButton>(find.byType(AppDangerOutlineButton));

  testWidgets('tudo o que se toca tem 48 e rótulo (Fase 8C)', (tester) async {
    await seedSession();
    await pumpEdit(tester);

    await expectAccessibleTargets(tester);
  });

  testWidgets('mostra o contexto da sessão e os campos com os valores dela',
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/sync/sync_screen.dart';
import 'package:simtc/utils/result.dart';

import '../../support/fake_assessment_sync_service.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}
```

por:

```dart
import 'package:simtc/ui/sync/sync_screen.dart';
import 'package:simtc/utils/result.dart';

import '../../support/a11y.dart';
import '../../support/fake_assessment_sync_service.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
  String titleText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('sessions-title'))).data!;

  testWidgets(
```

por:

```dart
  String titleText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('sessions-title'))).data!;

  testWidgets('tudo o que se toca tem 48 e rótulo (Fase 8C)', (tester) async {
    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    await expectAccessibleTargets(tester);
  });

  testWidgets(
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
    expect(find.byType(SessionCard), findsOneWidget);
  });
```

por:

```dart
    expect(find.byType(SessionCard), findsOneWidget);
  });

  testWidgets(
      'a primeira descida falhou com o aparelho vazio: o motivo e "Tentar '
      'novamente", e não as seções vazias (Fase 8C)', (tester) async {
    final reply = Completer<Result<int>>();
    when(repository.syncAll).thenAnswer((_) => reply.future);

    await pump(tester);
    sessions.add(const []);
    await tester.pump();
    reply.complete(Failure(Exception('sem rede'), 'Sem conexão.'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(
      find.text('Não foi possível baixar as sessões. Confira a conexão e '
          'tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Nenhuma sessão para hoje.'), findsNothing);
    expect(find.byType(SnackBar), findsNothing, reason: 'um aviso só');

    when(repository.syncAll).thenAnswer((_) async => const Success(1));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    sessions.add([hoje()]);
    await tester.pump();

    verify(repository.syncAll).called(2);
    expect(find.byType(SessionCard), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });
```

Em `test/ui/summary/summary_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

por:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

import '../../support/a11y.dart';

class _MockApiClient extends Mock implements ApiClient {}
```

Em `test/ui/summary/summary_screen_test.dart`, substituir:

```dart
  });

  testWidgets('abaixo de 70% mostra "Não recomendado"', (tester) async {
    await draftWith({'inf-1': 'inf-1-M', 'inf-2': 'inf-2-M'});
```

por:

```dart
  });

  testWidgets('tudo o que se toca tem 48 e rótulo (Fase 8C)', (tester) async {
    await draftWith({'inf-1': 'inf-1-PM'});
    await pumpSummary(tester);

    await expectAccessibleTargets(tester);
  });

  testWidgets('abaixo de 70% mostra "Não recomendado"', (tester) async {
    await draftWith({'inf-1': 'inf-1-M', 'inf-2': 'inf-2-M'});
```

Em `test/ui/sync/sync_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/sync/sync_screen.dart';

import '../../support/fake_assessment_sync_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}
```

por:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/sync/sync_screen.dart';

import '../../support/a11y.dart';
import '../../support/fake_assessment_sync_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}
```

Em `test/ui/sync/sync_screen_test.dart`, substituir:

```dart
        ),
      ];

  group('"Tentar novamente" e "Descartar" (Fase 8C)', () {
```

por:

```dart
        ),
      ];

  testWidgets('tudo o que se toca tem 48 e rótulo (Fase 8C)', (tester) async {
    await pump(tester, queue: filaDoCanvas());

    await expectAccessibleTargets(tester);
  });

  group('"Tentar novamente" e "Descartar" (Fase 8C)', () {
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/sessions/sessions_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/checklist/checklist_screen_test.dart test/ui/summary/summary_screen_test.dart test/ui/result/result_screen_test.dart test/ui/sync/sync_screen_test.dart test/ui/profile/profile_screen_test.dart test/ui/auth/login_screen_test.dart test/ui/add_participant/add_participant_screen_test.dart test/ui/session_edit/session_edit_screen_test.dart test/ui/session_consultants/session_consultants_screen_test.dart`
Esperado: `+341 -2: Some tests failed.` — os dois testes da primeira descida que falhou (Home e detalhe). Os testes de diretriz já passam: as Tasks 3 e 5 cobriram o que eles conferem.

- [ ] **Step 3: Implementar**

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
  Widget? _buildNotice(TrainingSession session, bool isOffline) {
    if (_viewModel.neverDownloaded) {
```

por:

```dart
  Widget? _buildNotice(TrainingSession session, bool isOffline) {
    // Com conexão, a descida falhou de fato: o motivo e o "Tentar de novo"
    // (Fase 8C).
    if (_viewModel.downloadFailed && !isOffline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InlineNotice(
            icon: AppIcons.noSignal,
            tone: NoticeTone.warning,
            message: 'Não foi possível baixar os participantes desta sessão.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppSecondaryButton(
            label: 'Tentar novamente',
            icon: AppIcons.retry,
            onPressed: _viewModel.refresh,
          ),
        ],
      );
    }

    if (_viewModel.neverDownloaded) {
```

Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:

```dart
  bool _isRefreshing = false;
  bool _isStarting = false;
```

por:

```dart
  bool _isRefreshing = false;

  /// A descida falhou com a sessão nunca baixada: ver [downloadFailed].
  bool _downloadFailed = false;
  bool _isStarting = false;
```

Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:

```dart
      (neverDownloaded && _participants.isEmpty && _isRefreshing);

  bool get hasParticipants => _participants.isNotEmpty;

  /// Atribuir e abrir o checklist só valem com a sessão em andamento.
  bool get evaluationOpen => _session?.status == SessionStatus.emAndamento;
```

por:

```dart
      (neverDownloaded && _participants.isEmpty && _isRefreshing);

  bool get hasParticipants => _participants.isNotEmpty;

  /// Os participantes nunca foram baixados e a última descida falhou: a tela
  /// mostra o motivo e o "Tentar novamente" no lugar do aviso de baixar com
  /// conexão — um aviso só, sem o passageiro (Fase 8C).
  bool get downloadFailed => _downloadFailed && neverDownloaded;

  /// Atribuir e abrir o checklist só valem com a sessão em andamento.
  bool get evaluationOpen => _session?.status == SessionStatus.emAndamento;
```

Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:

```dart
  }

  /// Abertura da tela, puxar para atualizar e volta da conexão caem aqui.
  Future<void> refresh() async {
```

por:

```dart
  }

  /// Com participantes baixados, a falha é um aviso passageiro; nunca
  /// baixada, é o estado da tela ([downloadFailed]). Antes de a sessão sair
  /// do cache, não dá para saber: fica o aviso passageiro.
  void _refreshFailedWith(String message) {
    if (_sessionLoaded && neverDownloaded) {
      _downloadFailed = true;
    } else {
      _message = message;
    }
  }

  /// Abertura da tela, puxar para atualizar e volta da conexão caem aqui.
  Future<void> refresh() async {
```

Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:

```dart
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
```

por:

```dart
    _downloadFailed = false;
    notifyListeners();

    try {
      final result = await _participantRepository.syncSession(sessionId);
      if (result case Failure(:final message)) {
        _refreshFailedWith(message ?? _refreshFailed);
      }
    } catch (_) {
      // Rede de segurança: `syncSession` já devolve `Result` para todo erro
      // esperado. Sem ela, `_isRefreshing` travaria em `true`.
      _refreshFailedWith(_refreshFailed);
```

Em `lib/ui/sessions/sessions_list_viewmodel.dart`, substituir:

```dart
  bool _isRefreshing = false;
  String? _errorMessage;
```

por:

```dart
  bool _isRefreshing = false;
  bool _downloadFailed = false;
  String? _errorMessage;
```

Em `lib/ui/sessions/sessions_list_viewmodel.dart`, substituir:

```dart
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  /// Quando o cache foi atualizado pela última vez — a faixa de offline usa
```

por:

```dart
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  /// A descida falhou e o aparelho não tem sessão nenhuma, nunca baixada: a
  /// tela mostra o motivo e o "Tentar novamente", e não as seções vazias —
  /// "nenhuma sessão" seria uma afirmação que o app não tem como fazer
  /// (Fase 8C).
  bool get downloadFailed =>
      _downloadFailed && _sessions.isEmpty && _lastSyncedAt == null;

  /// Quando o cache foi atualizado pela última vez — a faixa de offline usa
```

Em `lib/ui/sessions/sessions_list_viewmodel.dart`, substituir:

```dart
    _isRefreshing = true;
    _errorMessage = null;
```

por:

```dart
    _isRefreshing = true;
    _downloadFailed = false;
    _errorMessage = null;
```

Em `lib/ui/sessions/sessions_list_viewmodel.dart`, substituir:

```dart
        _errorMessage = message ?? 'Não foi possível atualizar as sessões.';
      }
    } catch (_) {
      // `syncAll` já devolve `Result` para todo erro esperado; isto é uma
      // rede de segurança contra o que escapar dele. Sem ela, `_isRefreshing`
      // travaria em `true` e todo refresh seguinte (puxar, voltar a conexão,
      // reabrir a tela) cairia no guard-clause de início deste método.
      _errorMessage = 'Não foi possível atualizar as sessões.';
    } finally {
      _isRefreshing = false;
      notifyListeners();
```

por:

```dart
        _failed(message ?? 'Não foi possível atualizar as sessões.');
      }
    } catch (_) {
      // `syncAll` já devolve `Result` para todo erro esperado; isto é uma
      // rede de segurança contra o que escapar dele. Sem ela, `_isRefreshing`
      // travaria em `true` e todo refresh seguinte (puxar, voltar a conexão,
      // reabrir a tela) cairia no guard-clause de início deste método.
      _failed('Não foi possível atualizar as sessões.');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Com sessões no aparelho, a falha é um aviso passageiro; sem nenhuma,
  /// nunca baixada, é o estado da tela ([downloadFailed]) — um aviso só.
  /// Antes da primeira leitura do cache, não dá para saber: fica o aviso
  /// passageiro.
  void _failed(String message) {
    if (_hasLoadedOnce && _sessions.isEmpty && _lastSyncedAt == null) {
      _downloadFailed = true;
    } else {
      _errorMessage = message;
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
import '../core/theme/app_typography.dart';
import '../core/widgets/app_nav_bar.dart';
```

por:

```dart
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_nav_bar.dart';
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
  Widget _buildBody(SessionsListViewModel viewModel) {
    if (viewModel.isLoading) return _buildSkeleton();

    // Na busca, a seção sem resultado some com o título; sem nenhum, uma
```

por:

```dart
  Widget _buildBody(SessionsListViewModel viewModel) {
    if (viewModel.isLoading) return _buildSkeleton();
    if (viewModel.downloadFailed) return _buildDownloadFailed(viewModel);

    // Na busca, a seção sem resultado some com o título; sem nenhum, uma
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
  }

  Widget _buildNoResults(String query) {
    return Padding(
```

por:

```dart
  }

  /// A primeira descida falhou e não há sessão nenhuma no aparelho (Fase 8C).
  Widget _buildDownloadFailed(SessionsListViewModel viewModel) {
    return ListView(
      key: const Key('sessions-download-failed'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const InlineNotice(
          icon: AppIcons.noSignal,
          tone: NoticeTone.warning,
          message: 'Não foi possível baixar as sessões. Confira a conexão e '
              'tente de novo.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppSecondaryButton(
          label: 'Tentar novamente',
          icon: AppIcons.retry,
          onPressed: viewModel.refresh,
        ),
      ],
    );
  }

  Widget _buildNoResults(String query) {
    return Padding(
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/sessions/sessions_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart test/ui/checklist/checklist_screen_test.dart test/ui/summary/summary_screen_test.dart test/ui/result/result_screen_test.dart test/ui/sync/sync_screen_test.dart test/ui/profile/profile_screen_test.dart test/ui/auth/login_screen_test.dart test/ui/add_participant/add_participant_screen_test.dart test/ui/session_edit/session_edit_screen_test.dart test/ui/session_consultants/session_consultants_screen_test.dart`
Esperado: `+343: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1170: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/test/support/a11y.dart apps/mobile/simtc/lib/ui/session_detail/session_detail_screen.dart apps/mobile/simtc/lib/ui/session_detail/session_detail_viewmodel.dart apps/mobile/simtc/lib/ui/sessions/sessions_list_viewmodel.dart apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart apps/mobile/simtc/test/ui/add_participant/add_participant_screen_test.dart apps/mobile/simtc/test/ui/auth/login_screen_test.dart apps/mobile/simtc/test/ui/checklist/checklist_screen_test.dart apps/mobile/simtc/test/ui/profile/profile_screen_test.dart apps/mobile/simtc/test/ui/result/result_screen_test.dart apps/mobile/simtc/test/ui/session_consultants/session_consultants_screen_test.dart apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart apps/mobile/simtc/test/ui/session_edit/session_edit_screen_test.dart apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart apps/mobile/simtc/test/ui/summary/summary_screen_test.dart apps/mobile/simtc/test/ui/sync/sync_screen_test.dart
git commit -m "feat(mobile): erro da primeira descida e diretrizes de acessibilidade"
```

---
## Task 9: Validação no aparelho e no emulador

O portão da 8C, que só o usuário pode rodar: o celular no **aparelho físico** e o tablet no **emulador**, contra a produção (o padrão desde a 8A). A 8C não muda o backend: não há publicação.

**Interfaces:**
- Consumes: o app com as Tasks 1 a 8.
- Produces: o aval do usuário para planejar a 8D.

- [ ] **Step 1: Instalar**

Em `apps/mobile/simtc/`: `flutter run -d <id do celular>` e, depois, `flutter run -d emulator-5554`.

- [ ] **Step 2: Roteiro no celular**

Com uma conta CONSULTANT e depois com uma ADMIN, numa sessão de teste:

1. **Cores:** a navbar com o item ativo em verde-escuro sobre verde-claro; o "Esqueci a senha" e o "Ver mais" num verde mais escuro; o contorno do "Cancelar sessão", do "Remover da sessão" e do "Sair da conta" num vermelho mais suave; o "opcional" e o "N itens" num cinza mais escuro que antes.
2. **Toque:** tocar e segurar num card da Home, numa linha do detalhe, no cabeçalho da categoria aberta, num B/PM/M e num cartão de tipo da 1.11 — a ondulação aparece. Dois toques rápidos num card e numa linha: abre uma tela só. Tocar no ícone de um campo de texto: o teclado abre.
3. **Fonte ampliada:** em Configurações → Tela → Tamanho da fonte, pôr no máximo e percorrer Home, detalhe, checklist, Resultado, Sincronizar, Perfil e as telas de admin: nada cortado com faixas amarelas; no detalhe, o cabeçalho rola junto com a lista; no Resultado, a pílula desce para baixo do %. Voltar a fonte para o normal.
4. **TalkBack:** ligar e percorrer o checklist (os B/PM/M dizem "selecionado"), a 1.12 (a data é lida de uma vez), a 1.11 (os cartões de tipo) e a busca do detalhe (a contagem é anunciada enquanto se digita). Desligar.
5. **Falhas:** no checklist de uma avaliação iniciada, ⋮ → "Desatribuir participante" com a rede lenta (ou o modo avião ligado logo depois de confirmar): o ⋮ vira o indicador enquanto espera.

- [ ] **Step 3: Roteiro no tablet (emulador)**

1. **Paisagem e retrato:** a navbar lateral e a pílula, os chips com a ondulação, e as janelas de admin anunciadas pelo título com o TalkBack.
2. **Sincronizar:** com um item recusado, "Tentar novamente" e "Descartar" lado a lado.
3. **Fonte ampliada:** no máximo, o lado a lado sem cortes.

- [ ] **Step 4: Registrar o resultado**

Se tudo passar, acrescentar ao fim desta task a linha "**Validado em <data>: celular no aparelho físico e tablet no emulador; roteiro inteiro passou. Aval dado para planejar a 8D.**" e commitar:

```bash
git add apps/mobile/docs/superpowers/plans/2026-10-26-mobile-fase-8c-telas-e-acessibilidade.md
git commit -m "docs(mobile): registra a validacao da fase 8c"
```

Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio, parar e perguntar.

**Validado em 27/10/2026: celular no aparelho físico e tablet no emulador; roteiro inteiro passou. Aval dado para planejar a 8D.**

---

## Pendências levadas para a 8D

- As da lista da 8D no desenho da Fase 8 e as observações das revisões das Fases 8A e 8B (no fim dos planos delas).
- **Os testes de diretriz conferem o alvo e o rótulo**, não o contraste na tela: a fonte de teste desenha cada letra como um bloco e engana a medida. O contraste fica conferido nos tokens (`app_contrast_test.dart`); um teste de contraste com a fonte de verdade fica para a 8D, se fizer falta.
- **A cor da marca como fundo** (botões e chip selecionado, branco sobre `#1D9AA4`, 3,4:1) ficou como está, por ser a identidade do app; o texto ali é em negrito de 14 a 16. Retomar só se o usuário pedir.

### Observações das revisões da 8C

Nenhuma muda o que se vê no uso normal; todas vão para a 8D, salvo as que o roteiro da Task 9 confere no aparelho:

- **Conferir no aparelho (Task 9):** a ondulação na margem de toque do chip (a margem de 7 não mostra ondulação); o B/PM/M "selecionado" no TalkBack; com a fonte ≥1,3×, tocar num chip do detalhe faz a lista inteira rolar até o chip (o `Scrollable.ensureVisible` da barra percorre também a lista vertical) e o cabeçalho sai de cena — um salto que ninguém decidiu.
- **8D (comportamento de borda):** "Não salvo" sobrevive ao "Descartar avaliação" (`_detach` não zera `_saveFailed`), e com a leitura do checklist que falhou o "salvo" e o ⋮ continuam à vista — corrigir os dois juntos; com a fonte ≥1,3× e a busca do detalhe aberta, o campo é recriado com `autofocus` ao voltar à vista (o teclado pode abrir sozinho); "Desatribuindo…" não é anunciado como região viva; o descarte "já aceito" é deduzido pela saída da fila.
- **8D (testes):** `claimOpen` sem teste unitário, e a trava estática dele pode vazar entre testes que terminam sem quadro; falha repetida ao marcar nota; detalhe com fonte grande no tablet; testes de diretriz em mais de um estado por tela; o contraste só sobre fundos claros; `expectVisibleRipple` assume um `Container` como filho do `InkWell`.
- **8D (limpeza):** `AppRadius.sm + 2` repetido (vale um token); os quatro ternários do `spacious`; o vão do Perfil sem constante nomeada; o `LayoutBuilder` da faixa de sem conexão quase igual na 1.11 e na 1.12; `catch (_)` do abrir do checklist sem registro; comentários e ordem de campos (link, `dangerBorder`, constantes do chip, `_downloadFailed`, "Tentar de novo"); o `14` solto no teste da fila; o `GestureDetector` do campo sem `behavior`.
