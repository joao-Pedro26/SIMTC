# App Mobile SIMTC — Fase 4: Checklist de Avaliação (offline-first) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar a tela provisória da rota `…/checklist` pela tela 1.5 de verdade: o checklist B/PM/M de um participante, 100% funcional sem internet — rascunho gravado no aparelho a cada toque, cronômetro, score por categoria e geral calculados no app com os mesmos números do backend, e "Finalizar avaliação" que deixa a avaliação pronta na fila local e volta para o detalhe da sessão.

**Architecture:** Mesma regra das fases anteriores — a tela lê só do banco local. O novo `AssessmentRepository` abre ou retoma o rascunho (`LocalAssessments`, tabela que existe desde a Fase 1) e grava cada marcação em `LocalAssessmentItems`; o catálogo já está no aparelho desde a Fase 3 (`AssessmentCatalogRepository.loadCatalog()`). A junção catálogo × marcações é uma função pura (`checklist_sections.dart`, no padrão do `participant_filter.dart`), e o score usa um port 1:1 de `packages/shared-types/src/scoring.ts`. A `ChecklistViewModel` tem um `Timer.periodic` de 1s para o cronômetro, com a guarda de dispose que a revisão final da Fase 3 pediu. Nada nesta fase chama a rede: o envio da fila é da Fase 5.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · drift 2.31.0 · uuid 4.4.2 (já é dependência direta) · connectivity_plus 6.1.5 · mocktail (testes). **Nenhuma mudança de backend, de esquema do Drift nem de dependências.**

**Spec:** `brainstorm-implementacao-mobile.md` → "Fase 4 — Checklist de Avaliação (offline-first)"; canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html`, quadro `1b` (linhas 1050–1121; dados de exemplo em 3424–3516), spec `4z` (3213–3242) e spec `5a` (3244–3268); pendências da Fase 3 na última seção de `2026-09-23-mobile-fase-3-detalhe-da-sessao.md`. O desenho aprovado em 26/09/2026 está na seção "Decisões tomadas com o usuário" abaixo — a trilha mobile não usa doc de spec separado, o plano é o documento.

**Validação prévia:** todo o código deste plano foi escrito e rodado numa cópia descartável do app antes de o plano ser fechado, e depois as tasks foram **reencenadas em ordem** numa segunda cópia limpa do app (HEAD `5536fcf`): em cada task, o teste falhou antes da implementação pelo motivo descrito no passo "Esperado", e cada checkpoint bateu o número de testes — **215 → 217 → 230 → 242 → 255 → 265 → 275**, com `flutter analyze` sem issues em todos. Os blocos de código do plano foram gerados a partir dessa cópia por um script que confere cada "Substituir / por" contra o arquivo real — o que está aqui é, byte a byte, o código que passou.

## Decisões tomadas com o usuário

Em 26/09/2026, no brainstorm da fase:

1. **"Finalizar avaliação" marca local e volta para o detalhe.** Grava `endTime`, põe o rascunho em `pendingSync` e volta à tela 1.4 — sem tela de resumo nesta fase (a 1.6 é da Fase 5). O score já aparece no próprio checklist.
2. **Categoria "revisada" = com pelo menos uma infração marcada.** Derivável do que já está em `LocalAssessmentItems`: sobrevive a fechar e reabrir o app sem coluna nova.
3. **Desenho aprovado, parte 1 (dados):** port 1:1 do scoring (três funções); `AssessmentRepository` com `openDraft`/`watchItems`/`mark`/`unmark`/`finish`, sem rede; `date` da avaliação = data de calendário da sessão, ou hoje se ela não tiver; marcação cuja nota ou infração sumiu do catálogo aparece como "sem infração" e fica órfã no banco, sem quebrar nada.
4. **Desenho aprovado, parte 2 (tela):** `ChecklistViewModel` com cronômetro de 1s e guarda de dispose; nome do participante lido do banco (`ParticipantRepository.watchParticipant`), não do `extra` da navegação; a tela abre sempre com a **primeira categoria aberta**, e abrir outra fecha a anterior; `toggleNote` único (mesmo botão desmarca, outro troca); confirmação do "Finalizar" só quando há categoria não revisada; cabeçalho próprio de duas linhas (não o `AppTopBar`); **`ConnectivityBanner` embaixo do cabeçalho** em vez do ícone de wifi do canvas; categoria fechada mostra só "N itens", aberta mostra o selo de score; botões B/PM/M com as cores exatas da spec `4z`; "Finalizar avaliação" no `AppCtaButton` da Fase 3 com 56dp; a rota troca o builder e `EvaluationPlaceholderKind.checklist` sai.
5. **Três botões B/PM/M, não "4 estados".** O brainstorm da fase fala em seletor de 4 estados (Sem infração/B/PM/M); o canvas (`segOpts` e o título do quadro `1b`) tem 3 botões, e "sem infração" é nenhum pressionado.

Em 27/09/2026, ao preparar este plano:

6. **Cronômetro na linha "Avaliando · você" e badge da fila no indicador de sincronização vão para a Fase 5.** A Fase 3 tinha deixado os dois para a Fase 4 (decisão 13 e pendências), mas o desenho aprovado não os incluiu; o usuário escolheu levá-los para a Fase 5, junto com a fila que de fato envia.

Em 27/09/2026, depois da revisão final do branch (ver "Correções da revisão final", antes da Task 7):

7. **Entrar offline com o perfil salvo.** A revisão achou que, fechado à força (ou com o celular reiniciado) sem sinal, o app abria no Login — que exige rede — porque `restoreSession()` (Fase 1) sempre confere a sessão no `GET /auth/me`. Com sessão salva ("manter conectado"), se essa checagem falhar **por falta de rede**, o app entra com o último perfil que o servidor confirmou, guardado no armazenamento seguro junto com os tokens (e apagado com eles). A sessão é conferida na primeira chamada com rede: 401 → renovação → `handleSessionExpired`, como em qualquer momento do uso. 401 e erro de servidor continuam indo para o login. Risco aceito: um usuário desativado no painel continua vendo o que já estava baixado até o aparelho ficar online.
8. **Rolar até a categoria aberta.** Abrir a próxima categoria fecha a de cima; a lista encolhia e o cabeçalho da recém-aberta ficava acima da tela. Agora a lista rola até ele, com a mesma animação da Home (300 ms, `easeInOut`).

### Ajustes feitos ao preparar o plano (revisar junto com o plano)

A validação na cópia descartável e a conferência pixel a pixel com o quadro `1b` levaram a estes ajustes — **nenhum muda regra de negócio aprovada**, mas cada um é uma escolha que o usuário deve conferir:

- **Sem catálogo no aparelho, não há "Finalizar".** Se a descida do catálogo junto com a Home falhou, o checklist mostra um aviso ("O catálogo de infrações ainda não foi baixado neste aparelho…") e esconde o botão; `finish()` também recusa. Sem isso, uma avaliação sem categoria nenhuma daria 100%, "Aprovado".
- **O número da infração é o `order`** (o item na ficha oficial, por onde a infração é achada numa contestação), não a posição na lista.
- **`AppCtaSize.large` em vez de só `height`.** O canvas desenha o "Finalizar avaliação" com 56dp **e** texto 16 e ícone 22 (o "Atribuir a mim" tem texto 14 e ícone 19); a variante leva os três juntos.
- **Onde o quadro `1b` e a spec `4z` divergem, vale o `1b`:** a linha da infração tem padding 15/20 no quadro (ajuste mais recente, feito por cima do 14/16 da spec).
- **Selo de score com 11px** (quadro `1b`); o 11,5 da spec `5a` é da tela de resultado (Fase 5).
- **Categoria aberta no meio da lista:** o canvas só desenha a primeira aberta; quando outra abre, as fechadas antes e depois dela formam dois grupos, com a mesma borda e o mesmo espaço de 10 do canvas.
- **Caixa da observação da nota** com as medidas do `1b` (texto 13,5 em `#5C3A10`, ícone 16), num widget próprio — o `InlineNotice` tem texto 13 e mais claro.
- **Textos novos:** faixa offline "Sem conexão — as marcações continuam sendo salvas no aparelho." e o diálogo "N categorias estão sem nenhuma infração marcada e contam como 100% no cálculo. Finalizar assim mesmo?".
- **Detalhes de interface:** `openDraft` devolve a linha (`LocalAssessment`), não só o id — a tela precisa do `startTime`; `mark`/`unmark` devolvem as marcações atualizadas, para a tela mostrar a própria escrita sem esperar o stream; `mark` é um upsert numa instrução só, pela chave única (`localAssessmentId`, `infractionId`).

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app` (a mesma das Fases 0–3). Sem git worktree. Não criar branch, não fazer merge, não fazer push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento (como nas fases anteriores) e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem arquivos soltos que não são desta fase (backend, `apps/web/…`, `devtools_options.yaml`, arquivos na raiz) — **não tocar neles**.
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-09-27-mobile-fase-4-checklist-de-avaliacao/`.

**Mobile (valem para todas as fases)**
- Flutter 3.41.6 / Dart 3.11.4. App **só Android**, APK sideload. Validação manual em **aparelho físico** (USB ou Wi-Fi, nunca emulador) — procedimento em `apps/mobile/simtc/README.md`.
- MVVM + Repository: um `ChangeNotifier` por tela; tela nunca chama `Dio`/Drift direto. Repository que fala com a rede devolve o `Result<T>` de `lib/utils/result.dart`; os métodos só locais (como `loadCatalog()` e todo o `AssessmentRepository`) devolvem o valor direto.
- `ConnectivityService` único, criado no `MultiProvider` do app, nunca dentro de uma tela.
- Composição "quebra-cabeça": cada tela decompõe a UI em métodos privados `Widget _buildX()` combinados num `build()` enxuto.
- Design System: nenhum `Color(0xFF…)`, nenhum número mágico de espaçamento e nenhum `TextStyle` literal fora de `lib/ui/core/theme/`; **nunca trocar `fontSize` num `.copyWith()`** fora do tema (cor, peso e espaçamento de letra, sim). Aritmética sobre tokens (`AppSpacing.sm + 2`) é o padrão aceito. Cores por `AppColors`, espaçamento por `AppSpacing`/`AppRadius`, texto por `AppTypography`, ícones por `AppIcons`.
- Alvos de toque mínimos de 48dp (`AppSpacing.touchTarget`); skeleton no lugar de spinner; estados de erro e vazio explícitos.
- Contratos reais apenas — nenhum campo ou endpoint não confirmado no código do backend.
- TDD: teste falhando pelo motivo certo → implementação → teste passando.
- **Widget test com Drift de verdade** usa `AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true))`: sem isso, o `Timer` de duração zero que o drift agenda ao cancelar um stream nasce no relógio falso do `testWidgets`, o teste falha com "A Timer is still pending" e o `await db.close()` do tearDown trava.

Todos os caminhos de código são relativos a `apps/mobile/simtc/`; os comandos rodam a partir dessa pasta.

## Review Focus

Os cinco casos que o spec implica, que um usuário real vai encontrar, e onde cada um ficou preso num teste:

1. **App fechado à força no meio do checklist, offline** (é o critério de aceite da fase) → reabrir retoma o mesmo rascunho, com as marcações e o `startTime` original. Preso em: `retoma o rascunho existente do participante, sem duplicar` (Task 3) e `retomar o checklist reabre o mesmo rascunho, sem perder marcações` (Task 5).
2. **Catálogo ausente no aparelho** → aviso, sem "Finalizar", e `finish()` recusa. Preso em: `sem catálogo no aparelho, não finaliza — uma avaliação vazia daria 100%` (Task 5) e `sem catálogo no aparelho, avisa e não oferece "Finalizar"` (Task 6).
3. **Catálogo mudou depois da marcação** (o admin removeu a infração ou a nota no painel web) → a marcação some da tela e do score, sem quebrar e sem contar como revisada. Preso em: `marcação de infração que não existe mais no catálogo é ignorada, sem quebrar` e `marcação com nota que não existe mais no catálogo aparece como "sem infração" …` (Task 4).
4. **Reabrir um participante já finalizado** (até a Fase 5 enviar, o detalhe continua mostrando "Avaliando · você") → retoma a mesma avaliação, sem estourar a chave única de `trainingParticipantId`. Preso em: `reabrir o checklist de um participante já finalizado retoma a mesma avaliação, sem estourar a chave única` (Task 3).
5. **Sair da tela com o cronômetro correndo, ou com uma escrita ainda em voo** → o cronômetro é cancelado, nada notifica a tela morta, e o cronômetro também para ao finalizar. Preso em: `dispose cancela o cronômetro: nenhum timer fica pendente`, `uma escrita que termina depois do dispose não notifica a tela morta` e `marca local, sinaliza isFinished e para o cronômetro` (Task 5).

## Estado herdado (ponto de partida)

HEAD `5536fcf` (registro da validação da Fase 3 no aparelho). `flutter analyze` limpo; **215 testes passando**.

Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| Tabelas do rascunho | `lib/data/services/local/tables.dart` | `LocalAssessments` (id local uuid, `trainingParticipantId` **único**, `sessionId`, `date`, `startTime`, `endTime?`, `syncStatus`, `createdAt`, `updatedAt`…) e `LocalAssessmentItems` (`localAssessmentId` FK, `infractionId`, `infractionNoteId`, `updatedAt`; **único** `{localAssessmentId, infractionId}`); `enum LocalSyncStatus { draft, pendingSync, synced, … }`. Esquema v3, **sem migração nesta fase** |
| Catálogo no aparelho | `lib/data/repositories/assessment_catalog_repository.dart` | `Future<List<CatalogCategory>> loadCatalog()` — categorias e infrações em ordem de `order` |
| Modelos do catálogo | `lib/data/models/assessment_catalog.dart` | `CatalogCategory(id, code, name, order, infractions)` > `CatalogInfraction(id, categoryId, description, order, notes)` > `CatalogNote(id, infractionId, noteType, deduction, comment?)` |
| Participantes | `lib/data/repositories/participant_repository.dart` | `watchBySession`, `syncSession`, `assign`; `SessionParticipant.fromRow` |
| `TrainingSession.date` | `lib/data/models/training_session.dart` | data de calendário (meia-noite local), nula se a sessão não tiver data |
| Conectividade | `lib/data/services/connectivity_service.dart`, `lib/ui/core/widgets/connectivity_banner.dart` | `isOffline`; `ConnectivityBanner(isOffline, message)` |
| Widgets do DS | `lib/ui/core/widgets/` | `AppCtaButton(label, onPressed, isLoading, icon)` (48dp, laranja), `InlineNotice(icon, message, tone)`, `SkeletonListItem` |
| Ícones | `lib/ui/core/theme/app_icons.dart` | `back`, `notes` (sticky_note_2), `syncDone` (cloud_done), `offline` |
| Rotas | `lib/router.dart` | `AppRoutes.participantChecklist(sessionId, participantId)` → `/sessions/:sessionId/participants/:participantId/checklist`, hoje com `EvaluationPlaceholderScreen(kind: checklist)` |
| `AppDependencies` | `lib/app_providers.dart` | fábrica única das dependências + `providers` |
| `uuid` | `pubspec.yaml` | `uuid: ^4.4.2`, dependência direta desde a Fase 1 |

## Mapa de Arquivos

### Novos

| Arquivo | Responsabilidade |
|---|---|
| `lib/utils/scoring.dart` | port 1:1 do `scoring.ts`: `calculateCategoryScore`, `calculateOverallScore`, `getApprovalStatus` |
| `lib/data/repositories/assessment_repository.dart` | rascunho local: `openDraft`, `watchItems`, `mark`, `unmark`, `finish` |
| `lib/ui/checklist/checklist_sections.dart` | regras puras: seções, revisada, score da categoria e geral, órfãs, cor do selo |
| `lib/ui/checklist/checklist_viewmodel.dart` | estado da tela 1.5 |
| `lib/ui/checklist/checklist_screen.dart` | tela 1.5 |
| `test/utils/scoring_test.dart` | os mesmos casos do spec do backend, mais o "86,7%" do canvas |
| `test/data/repositories/assessment_repository_test.dart` | rascunho, marcações, upsert, finalizar, reabrir |
| `test/ui/checklist/checklist_sections_test.dart` | regras puras |
| `test/ui/checklist/checklist_viewmodel_test.dart` | VM, cronômetro com relógio injetável |
| `test/ui/checklist/checklist_screen_test.dart` | tela, com Drift em memória |

### Modificados

| Arquivo | O que muda |
|---|---|
| `lib/ui/core/theme/app_colors.dart` | Task 1: 15 tons B/PM/M da spec `4z` + chip, cabeçalho aberto, "salvo", observação |
| `lib/ui/core/theme/app_typography.dart` | Task 1: 11 estilos do checklist |
| `lib/ui/core/theme/app_icons.dart` | Task 1: `timer`, `expandMore`, `expandLess`, `finish` |
| `lib/ui/core/widgets/app_buttons.dart` | Task 1: `AppCtaSize` e `AppCtaButton.size` |
| `lib/data/repositories/participant_repository.dart` | Task 3: `watchParticipant` |
| `lib/router.dart` | Task 6: o builder do checklist vira `ChecklistScreen` |
| `lib/app_providers.dart` | Task 6: `AssessmentRepository` |
| `lib/ui/evaluation/evaluation_placeholder_screen.dart` | Task 6: sai `EvaluationPlaceholderKind.checklist` |
| `test/ui/core/widgets/form_widgets_test.dart` | Task 1 |
| `test/data/repositories/participant_repository_test.dart` | Task 3 |
| `test/ui/session_detail/session_detail_screen_test.dart` | Task 6: a rota real agora abre o `ChecklistScreen` |

---

## Task 1: Tokens do checklist e a variante grande do `AppCtaButton`

Os valores vêm do canvas: tons B/PM/M da spec `4z` (os mesmos do `SEV` no script do canvas, linha 3424), o resto do quadro `1b`. A escala genérica `severityGoodBg`/… da Fase 1 **não é** a do checklist e continua sem consumidor — não mexa nela. Os tokens desta task só ganham consumidor nas Tasks 4 e 6; o que se testa aqui é a variante nova do botão.

**Files:**
- Modify: `lib/ui/core/theme/app_colors.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/theme/app_icons.dart`
- Modify: `lib/ui/core/widgets/app_buttons.dart`
- Test: `test/ui/core/widgets/form_widgets_test.dart`

**Interfaces:**
- Consumes: nada novo.
- Produces:
  - `AppColors`: `noteBBg`, `noteBBorder`, `noteBInk`, `noteBFill`, `noteBSelectedInk` e o mesmo quinteto para `notePm…` e `noteM…`; `categoryChipBg`, `categoryExpandedBg`, `categoryExpandedBorder`, `savedInk`, `noteCommentInk`.
  - `AppTypography`: `savedLabel`, `checklistProgress`, `checklistProgressValue`, `categoryCode`, `categoryName`, `categoryCount`, `scoreBadge`, `infractionNumber`, `infractionDescription`, `noteButton`, `noteComment`.
  - `AppIcons`: `timer`, `expandMore`, `expandLess`, `finish`.
  - `enum AppCtaSize { compact, large }` e `AppCtaButton({…, AppCtaSize size = AppCtaSize.compact})` — `large`: 56dp, texto 16 (`AppTypography.button`), ícone 22; `compact`: 48dp, texto 14, ícone 19 (como hoje).

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/core/widgets/form_widgets_test.dart`:

Substituir (1 de 2):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
```

por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
```

Substituir (2 de 2):

```dart

    testWidgets('em carregamento mostra o indicador e não responde ao toque',
```

por:

```dart

    testWidgets('o tamanho large tem 56dp, texto 16 e ícone 22, como o '
        '"Finalizar avaliação" do canvas', (tester) async {
      await _pump(
        tester,
        const AppCtaButton(
          label: 'Finalizar avaliação',
          icon: AppIcons.check,
          size: AppCtaSize.large,
        ),
      );

      expect(tester.getSize(find.byType(AppCtaButton)).height, 56);
      expect(tester.widget<Icon>(find.byIcon(AppIcons.check)).size, 22);
      final text = tester.renderObject<RenderParagraph>(find.text('Finalizar avaliação'));
      expect(text.text.style?.fontSize, 16);
    });

    testWidgets('o tamanho padrão continua compacto: 48dp e texto 14',
        (tester) async {
      await _pump(tester, AppCtaButton(label: 'Atribuir a mim', onPressed: () {}));

      expect(tester.getSize(find.byType(AppCtaButton)).height, 48);
      final text = tester.renderObject<RenderParagraph>(find.text('Atribuir a mim'));
      expect(text.text.style?.fontSize, 14);
    });

    testWidgets('em carregamento mostra o indicador e não responde ao toque',
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/ui/core/widgets/form_widgets_test.dart`
Esperado: falha de compilação — `Undefined name 'AppCtaSize'` e `No named parameter with the name 'size'`.

- [ ] **Step 3: A variante no `AppCtaButton`**

Em `lib/ui/core/widgets/app_buttons.dart`:

Substituir (1 de 5):

```dart

/// Botão de chamada para ação em laranja, na altura mínima de toque — para
/// ações dentro de uma linha de lista, como "Atribuir a mim". O canvas o
/// desenha com 36dp; aqui ele tem 48dp, o alvo mínimo do DS (o consultor usa
/// o app dentro do veículo).
class AppCtaButton extends StatelessWidget {
```

por:

```dart

/// Tamanho do [AppCtaButton].
enum AppCtaSize {
  /// 48dp, texto 14 — ação dentro de uma linha de lista ("Atribuir a mim").
  compact,

  /// 56dp, texto 16 — ação principal isolada no rodapé ("Finalizar
  /// avaliação", quadro "1b").
  large,
}

/// Botão de chamada para ação em laranja. No tamanho `compact`, é a ação de
/// uma linha de lista, como "Atribuir a mim": o canvas o desenha com 36dp,
/// aqui ele tem 48dp, o alvo mínimo do DS (o consultor usa o app dentro do
/// veículo).
class AppCtaButton extends StatelessWidget {
```

Substituir (2 de 5):

```dart
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
```

por:

```dart
  const AppCtaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.size = AppCtaSize.compact,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final AppCtaSize size;

  bool get _large => size == AppCtaSize.large;
```

Substituir (3 de 5):

```dart
    return SizedBox(
      height: AppSpacing.touchTarget,
      width: double.infinity,
```

por:

```dart
    return SizedBox(
      height: _large ? AppSpacing.controlHeight : AppSpacing.touchTarget,
      width: double.infinity,
```

Substituir (4 de 5):

```dart
          ),
          textStyle: AppTypography.buttonCompact,
        ),
```

por:

```dart
          ),
          // A cor do `textStyle` não vale num botão — quem pinta o rótulo é o
          // `foregroundColor`. Daqui só saem o tamanho e o peso.
          textStyle: _large ? AppTypography.button : AppTypography.buttonCompact,
        ),
```

Substituir (5 de 5):

```dart
        if (icon != null) ...[
          Icon(icon, size: 19),
          const SizedBox(width: AppSpacing.sm),
```

por:

```dart
        if (icon != null) ...[
          Icon(icon, size: _large ? 22 : 19),
          const SizedBox(width: AppSpacing.sm),
```

- [ ] **Step 4: Tokens de cor, tipografia e ícones**

Em `lib/ui/core/theme/app_colors.dart`:

Substituir:

```dart

  /// Sombra da navbar flutuante
```

por:

```dart

  // ─── Checklist: notas B/PM/M e o selo de score da categoria ───────────────
  // Escala própria da spec "4z" do canvas (Checklist), diferente da escala
  // genérica de severidade acima (`severityGoodBg` etc., que hoje não tem
  // nenhum consumidor real — a Fase 4 é a primeira tela a mostrar B/PM/M de
  // verdade, e usa os valores exatos desta spec, não os da escala genérica).
  static const Color noteBBg = Color(0xFFE7F5EC);
  static const Color noteBBorder = Color(0xFF8FCDA6);
  static const Color noteBInk = Color(0xFF1B7940);
  static const Color noteBFill = Color(0xFF22A55A);
  static const Color noteBSelectedInk = Color(0xFF0B2D18);

  static const Color notePmBg = Color(0xFFFFF6D9);
  static const Color notePmBorder = Color(0xFFE3C24D);
  static const Color notePmInk = Color(0xFF7A5900);
  static const Color notePmFill = Color(0xFFE0A500);
  static const Color notePmSelectedInk = Color(0xFF3D2E00);

  static const Color noteMBg = Color(0xFFFDE2E1);
  static const Color noteMBorder = Color(0xFFE2857A);
  static const Color noteMInk = Color(0xFF9B2C22);
  static const Color noteMFill = Color(0xFFE63946);
  static const Color noteMSelectedInk = Color(0xFF3C0805);

  /// Selo de score por faixa (spec "5a"): ≥85% reaproveita `successBg`/
  /// `successInk`; 70–84% e <70% reaproveitam `notePmBg`/`notePmInk` e
  /// `noteMBg`/`noteMInk` acima — não por coincidência, a spec usa os mesmos
  /// tons da severidade PM/M para as faixas média/baixa do score.
  static const Color categoryChipBg = Color(0xFFEEF4F5);

  /// Cabeçalho da categoria aberta no acordeão do checklist (quadro "1b").
  static const Color categoryExpandedBg = Color(0xFFF1FAFB);
  static const Color categoryExpandedBorder = Color(0xFFD6EDF0);

  /// Indicador "salvo" do cabeçalho do checklist (quadro "1b") — um verde
  /// próprio, mais vivo que o `successInk` dos chips.
  static const Color savedInk = Color(0xFF15803D);

  /// Texto da observação da nota escolhida (quadro "1b"). A caixa usa
  /// `warningBg`/`warningBorder`/`warningInk`; só o texto é mais escuro.
  static const Color noteCommentInk = Color(0xFF5C3A10);

  /// Sombra da navbar flutuante
```

Em `lib/ui/core/theme/app_typography.dart`:

Substituir:

```dart

  /// Campo de senha mascarado
```

por:

```dart

  // ─── Checklist (quadro "1b" do canvas) ────────────────────────────────────

  /// "salvo", ao lado do cronômetro
  static TextStyle get savedLabel =>
      _inter(size: 11.5, weight: FontWeight.w500, height: 1.2, color: AppColors.savedInk);

  /// "1 de 4 categorias revisadas"
  static TextStyle get checklistProgress =>
      _inter(size: 12, weight: FontWeight.w500, height: 1.2, color: AppColors.text3);

  /// Score geral ao lado do progresso ("86,7%")
  static TextStyle get checklistProgressValue =>
      _inter(size: 12, weight: FontWeight.w600, height: 1.2, color: AppColors.primaryDark);

  /// Código da categoria no chip do acordeão ("CV")
  static TextStyle get categoryCode =>
      _mono(size: 11, weight: FontWeight.w700, height: 1.2, letterSpacing: 0.44);

  /// Nome da categoria no acordeão ("Controle do Veículo")
  static TextStyle get categoryName =>
      _inter(size: 15, weight: FontWeight.w600, height: 1.25);

  /// "6 itens", na categoria fechada
  static TextStyle get categoryCount =>
      _inter(size: 12, weight: FontWeight.w400, height: 1.3, color: AppColors.textMuted);

  /// Selo de score da categoria aberta ("86,7%"). A tela de resultado (quadro
  /// "5a", Fase 5) desenha o dela com 11,5.
  static TextStyle get scoreBadge =>
      _inter(size: 11, weight: FontWeight.w700, height: 1.3);

  /// Número do item da infração na ficha oficial
  static TextStyle get infractionNumber =>
      _mono(size: 12, weight: FontWeight.w600, height: 1.55, color: AppColors.textMuted);

  /// Descrição da infração ("bodyLarge" da escala do canvas)
  static TextStyle get infractionDescription =>
      _inter(size: 16, weight: FontWeight.w400, height: 1.4);

  /// Código B/PM/M dentro do botão de nota
  static TextStyle get noteButton =>
      _inter(size: 15, weight: FontWeight.w700, height: 1.1);

  /// Observação da nota escolhida, na caixa abaixo dos botões
  static TextStyle get noteComment =>
      _inter(size: 13.5, weight: FontWeight.w400, height: 1.45, color: AppColors.noteCommentInk);

  /// Campo de senha mascarado
```

Em `lib/ui/core/theme/app_icons.dart`:

Substituir:

```dart
  static const IconData lockedByOther = Icons.lock_outline;
}
```

por:

```dart
  static const IconData lockedByOther = Icons.lock_outline;

  /// Checklist (Fase 4): cronômetro, acordeão e "Finalizar avaliação".
  static const IconData timer = Icons.timer_outlined;
  static const IconData expandMore = Icons.expand_more;
  static const IconData expandLess = Icons.expand_less;
  static const IconData finish = Icons.task_alt;
}
```

- [ ] **Step 5: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **217 testes passando**.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/core/theme/app_colors.dart lib/ui/core/theme/app_typography.dart lib/ui/core/theme/app_icons.dart lib/ui/core/widgets/app_buttons.dart test/ui/core/widgets/form_widgets_test.dart
git commit -m "feat(mobile): tokens do checklist e botao de cta grande"
```

---

## Task 2: Port do scoring

Cópia 1:1 de `packages/shared-types/src/scoring.ts`, que é o que o backend usa ao receber a avaliação (`practical-assessments.service.ts`, linhas 135–144: **todas** as categorias entram na média, e a sem marcação vale 100). O peso de cada nota vem do catálogo (`CatalogNote.deduction`), nunca de constante — `maxNoteWeight` só normaliza, como o `MAX_NOTE_WEIGHT` do TS. Os testes marcados "(backend)" repetem, com os mesmos números, os casos de `apps/backend/test/practical-assessments.service.spec.ts`; os outros três fixam o "86,7%" do canvas, a média com categorias sem marcação e o corte sem arredondamento.

**Files:**
- Create: `lib/utils/scoring.dart`
- Test: `test/utils/scoring_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `const int maxNoteWeight = 5`
  - `double calculateCategoryScore(List<int> noteWeights, int totalInfractionsInCategory)` — 100 se `total <= 0`; senão `max(0, 100 − Σ (peso / 5) × (100 / total))`.
  - `double calculateOverallScore(List<double> categoryScores)` — média simples; 100 se vazia.
  - `String getApprovalStatus(double score)` — `'APROVADO'` se `>= 70`, senão `'NECESSITA_REAVALIACAO'`.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/utils/scoring_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/utils/scoring.dart';

/// Os casos marcados "(backend)" são os mesmos, com os mesmos números, de
/// `apps/backend/test/practical-assessments.service.spec.ts` — o app e o
/// backend têm de dar o mesmo score para a mesma avaliação.
void main() {
  group('calculateCategoryScore', () {
    test('(backend) retorna 100 se não há infrações cadastradas na categoria', () {
      expect(calculateCategoryScore(const [], 0), 100);
    });

    test('(backend) retorna 100 se há infrações cadastradas mas nenhuma foi marcada',
        () {
      expect(calculateCategoryScore(const [], 5), 100);
    });

    test('(backend) desconta proporcionalmente ao número de infrações da categoria',
        () {
      // 5 infrações → cada uma vale 20%; uma M (peso máximo) desconta os 20%.
      expect(calculateCategoryScore(const [5], 5), 80);
    });

    test('(backend) nota B desconta só 1/5 do peso máximo dentro da fatia da infração',
        () {
      // Fatia de 20%; B (peso 1 de 5) desconta 1/5 de 20% = 4%.
      expect(calculateCategoryScore(const [1], 5), 96);
    });

    test('(backend) não vai abaixo de 0', () {
      expect(calculateCategoryScore(const [5, 5, 5], 3), 0);
    });

    test(
        'categoria "CV" do canvas: 6 infrações, uma PM (peso 3) e uma B '
        '(peso 1) marcadas — bate com o "86,7%" do quadro 1b', () {
      expect(calculateCategoryScore(const [3, 1], 6), closeTo(86.6666, 0.001));
    });
  });

  group('calculateOverallScore', () {
    test('(backend) retorna 100 se não há categorias', () {
      expect(calculateOverallScore(const []), 100);
    });

    test('(backend) retorna a média das categorias', () {
      expect(calculateOverallScore(const [80, 60]), 70);
    });

    test('(backend) retorna o valor único se só há uma categoria', () {
      expect(calculateOverallScore(const [85]), 85);
    });

    test('categorias sem marcação (100) entram na média, como no backend', () {
      final overall = calculateOverallScore(const [86.6666666666, 100, 100, 100]);
      expect(overall, closeTo(96.6666, 0.001));
    });
  });

  group('getApprovalStatus', () {
    test('(backend) APROVADO se score >= 70', () {
      expect(getApprovalStatus(70), 'APROVADO');
      expect(getApprovalStatus(85), 'APROVADO');
      expect(getApprovalStatus(100), 'APROVADO');
    });

    test('(backend) NECESSITA_REAVALIACAO se score < 70', () {
      expect(getApprovalStatus(69), 'NECESSITA_REAVALIACAO');
      expect(getApprovalStatus(0), 'NECESSITA_REAVALIACAO');
    });

    test('o corte não arredonda: 69,9 ainda precisa de reavaliação', () {
      expect(getApprovalStatus(69.9), 'NECESSITA_REAVALIACAO');
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/utils/scoring_test.dart`
Esperado: falha de compilação — `Error when reading 'lib/utils/scoring.dart'` e `Method not found: 'calculateCategoryScore'`.

- [ ] **Step 3: Implementar**

Criar `lib/utils/scoring.dart`:

```dart
/// Cálculo de score da avaliação prática — cópia 1:1 de
/// `packages/shared-types/src/scoring.ts` (a fonte de verdade, compartilhada
/// com o backend e o painel web). Qualquer mudança aqui tem que mudar lá
/// também, e vice-versa. Sem nenhuma dependência de Flutter ou do resto do
/// app — só números entram, só números (ou o texto fixo do status) saem.
const int maxNoteWeight = 5; // NOTE_DEDUCTIONS.M no TS

/// Score de uma categoria, de 0 a 100.
///
/// Cada infração cadastrada na categoria (marcada ou não) vale uma fração
/// igual de 100. A nota escolhida (peso de `InfractionNote.deduction`)
/// modula quanto dessa fatia é descontada, normalizada pelo peso máximo
/// (M = 5) — a mesma proporção 1:3:5 de `NOTE_DEDUCTIONS`. Uma infração não
/// marcada não aparece em [noteWeights], e por isso não desconta nada da sua
/// fatia: fica com o valor cheio.
double calculateCategoryScore(
  List<int> noteWeights,
  int totalInfractionsInCategory,
) {
  if (totalInfractionsInCategory <= 0) return 100;

  final perInfractionShare = 100 / totalInfractionsInCategory;
  final totalDeduction = noteWeights.fold<double>(
    0,
    (acc, weight) => acc + (weight / maxNoteWeight) * perInfractionShare,
  );
  final score = 100 - totalDeduction;
  return score < 0 ? 0 : score;
}

/// Média simples entre todas as categorias do catálogo — inclusive as que o
/// consultor nunca abriu, que contam 100.
double calculateOverallScore(List<double> categoryScores) {
  if (categoryScores.isEmpty) return 100;
  final total = categoryScores.fold<double>(0, (acc, score) => acc + score);
  return total / categoryScores.length;
}

/// `'APROVADO'` com 70 ou mais; `'NECESSITA_REAVALIACAO'` abaixo disso —
/// mesmo corte e mesmas strings do backend (`getApprovalStatus`,
/// `ParticipantStatus`). Devolve o texto puro, não o enum do app: quem
/// consumir aqui decide se quer `ParticipantStatus.parse()` sobre o
/// resultado, ou só o texto mesmo.
String getApprovalStatus(double score) {
  return score >= 70 ? 'APROVADO' : 'NECESSITA_REAVALIACAO';
}
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **230 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/scoring.dart test/utils/scoring_test.dart
git commit -m "feat(mobile): porta o calculo de score do backend para o app"
```

---

## Task 3: `AssessmentRepository` e `ParticipantRepository.watchParticipant`

O rascunho da avaliação no aparelho. Só fala com o Drift — nenhuma chamada de rede. `openDraft` procura pela chave única `trainingParticipantId` **sem olhar o status**: reabrir um participante já finalizado retoma a mesma linha (inserir outra estouraria a chave). `mark` é um upsert pela chave única `{localAssessmentId, infractionId}`, numa instrução só.

**Files:**
- Create: `lib/data/repositories/assessment_repository.dart`
- Modify: `lib/data/repositories/participant_repository.dart`
- Test: `test/data/repositories/assessment_repository_test.dart`
- Test: `test/data/repositories/participant_repository_test.dart`

**Interfaces:**
- Consumes: `LocalAssessments`, `LocalAssessmentItems`, `Sessions` (Drift, já existem); `SessionParticipant.fromRow`.
- Produces:
  - `AssessmentRepository({required AppDatabase database})`
  - `Future<LocalAssessment> openDraft({required String trainingParticipantId, required String sessionId})` — retoma a linha existente do participante ou cria uma em `draft`, com `startTime` = agora e `date` = data da sessão em cache (ou hoje, à meia-noite local).
  - `Stream<List<LocalAssessmentItem>> watchItems(String localAssessmentId)`
  - `Future<List<LocalAssessmentItem>> mark({required String localAssessmentId, required String infractionId, required String infractionNoteId})` — devolve as marcações da avaliação depois da escrita.
  - `Future<List<LocalAssessmentItem>> unmark({required String localAssessmentId, required String infractionId})` — idem.
  - `Future<void> finish(String localAssessmentId)` — `endTime` = agora, `syncStatus` = `pendingSync`.
  - `ParticipantRepository.watchParticipant(String participantId)` → `Stream<SessionParticipant?>` (nulo se não estiver no aparelho).

- [ ] **Step 1: Escrever os testes que falham — rascunho**

Criar `test/data/repositories/assessment_repository_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
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

  group('openDraft', () {
    test('cria um rascunho novo em draft, com startTime agora', () async {
      final assessment = await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      );

      final row = await db.select(db.localAssessments).getSingle();
      expect(row.id, assessment.id);
      expect(assessment.trainingParticipantId, 'tp-1');
      expect(assessment.sessionId, 'sess-1');
      expect(assessment.syncStatus, LocalSyncStatus.draft);
      expect(assessment.endTime, isNull);
      expect(assessment.startTime, isNotNull);
    });

    test('a data da avaliação é a data de calendário da sessão', () async {
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: 'sess-1',
              companyName: 'Bracell',
              courseName: 'Direção Defensiva',
              city: 'Itabira',
              state: 'MG',
              status: 'EM_ANDAMENTO',
              date: Value(DateTime(2026, 9, 12)),
              cachedAt: DateTime(2026, 9, 12, 8),
            ),
          );

      final assessment = await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      );

      expect(assessment.date, DateTime(2026, 9, 12));
    });

    test('sessão sem data (ou fora do cache) usa a data de hoje', () async {
      final assessment = await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-sem-cache',
      );

      final now = DateTime.now();
      expect(assessment.date, DateTime(now.year, now.month, now.day));
    });

    test('retoma o rascunho existente do participante, sem duplicar', () async {
      final first = await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      );

      final second = await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      );

      expect(second.id, first.id);
      expect(second.startTime, first.startTime);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });
  });

  group('mark / unmark / watchItems', () {
    test('marca uma infração e ela aparece em watchItems', () async {
      final assessmentId = (await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      )).id;

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
      final assessmentId = (await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      )).id;

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
      final assessmentId = (await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      )).id;
      await repository.mark(
        localAssessmentId: assessmentId,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );

      await repository.unmark(localAssessmentId: assessmentId, infractionId: 'inf-1');

      expect(await repository.watchItems(assessmentId).first, isEmpty);
    });

    test('marcações de avaliações diferentes não se misturam', () async {
      final a1 = (await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      )).id;
      final a2 = (await repository.openDraft(
        trainingParticipantId: 'tp-2',
        sessionId: 'sess-1',
      )).id;

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

      expect((await repository.watchItems(a1).first).single.infractionNoteId, 'note-b');
      expect((await repository.watchItems(a2).first).single.infractionNoteId, 'note-m');
    });
  });

  group('finish', () {
    test('grava endTime e põe em pendingSync', () async {
      final assessmentId = (await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      )).id;

      await repository.finish(assessmentId);

      final row = await db.select(db.localAssessments).getSingle();
      expect(row.syncStatus, LocalSyncStatus.pendingSync);
      expect(row.endTime, isNotNull);
    });

    test(
        'reabrir o checklist de um participante já finalizado retoma a mesma '
        'avaliação, sem estourar a chave única', () async {
      final assessmentId = (await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      )).id;
      await repository.finish(assessmentId);

      final reopened = await repository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
      );

      expect(reopened.id, assessmentId);
      expect(reopened.syncStatus, LocalSyncStatus.pendingSync);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });
  });
}
```

- [ ] **Step 2: Escrever os testes que falham — participante**

Em `test/data/repositories/participant_repository_test.dart`:

Substituir:

```dart

  group('assign', () {
```

por:

```dart

  group('watchParticipant', () {
    test('traz o participante do cache pelo id', () async {
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

      final participant = await repository.watchParticipant('tp-1').first;

      expect(participant?.name, 'Carlos Eduardo Nunes');
    });

    test('emite nulo se o participante não estiver no aparelho', () async {
      final participant = await repository.watchParticipant('tp-inexistente').first;

      expect(participant, isNull);
    });
  });

  group('assign', () {
```

- [ ] **Step 3: Rodar e confirmar que falham**

Run: `flutter test test/data/repositories/assessment_repository_test.dart test/data/repositories/participant_repository_test.dart`
Esperado: falha de compilação — `Error when reading 'lib/data/repositories/assessment_repository.dart'` e `The method 'watchParticipant' isn't defined for the type 'ParticipantRepository'`.

- [ ] **Step 4: Implementar o repositório do rascunho**

Criar `lib/data/repositories/assessment_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../services/local/app_database.dart';

/// A avaliação prática rascunhada no aparelho (Fase 4 — Checklist).
///
/// Só fala com o `AppDatabase`: não há chamada de rede aqui. O envio ao
/// backend (a fila de `pendingSync`) é de uma fase futura — esta classe só
/// precisa deixar a avaliação pronta e completa no aparelho, mesmo sem sinal.
class AssessmentRepository {
  AssessmentRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  /// Abre o rascunho da avaliação do participante, retomando o que já existe
  /// (`trainingParticipantId` é chave única) em vez de recriar — o consultor
  /// pode ter saído do checklist e voltado antes do próximo sync. Devolve a
  /// linha (a tela lê `startTime` dela para o cronômetro).
  ///
  /// `date` é a data de calendário da sessão (como `TrainingSession.date`,
  /// meia-noite local); sessão sem data, ou fora do cache, usa a de hoje.
  Future<LocalAssessment> openDraft({
    required String trainingParticipantId,
    required String sessionId,
  }) async {
    final existing = await (_db.select(_db.localAssessments)
          ..where(
              (t) => t.trainingParticipantId.equals(trainingParticipantId)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final session = await (_db.select(_db.sessions)
          ..where((t) => t.id.equals(sessionId)))
        .getSingleOrNull();
    final id = _uuid.v4();
    final now = DateTime.now();
    final companion = LocalAssessmentsCompanion.insert(
      id: id,
      trainingParticipantId: trainingParticipantId,
      sessionId: sessionId,
      date: session?.date ?? DateTime(now.year, now.month, now.day),
      startTime: now,
      syncStatus: LocalSyncStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.localAssessments).insert(companion);
    return await (_db.select(_db.localAssessments)
          ..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Marcações da avaliação — uma linha por infração marcada. A tela junta
  /// isto com o catálogo (`AssessmentCatalogRepository.loadCatalog`) para
  /// montar as seções do acordeão.
  Stream<List<LocalAssessmentItem>> watchItems(String localAssessmentId) {
    final query = _db.select(_db.localAssessmentItems)
      ..where((t) => t.localAssessmentId.equals(localAssessmentId));
    return query.watch();
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
    return _itemsOf(localAssessmentId);
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
    return _itemsOf(localAssessmentId);
  }

  Future<List<LocalAssessmentItem>> _itemsOf(String localAssessmentId) {
    return (_db.select(_db.localAssessmentItems)
          ..where((t) => t.localAssessmentId.equals(localAssessmentId)))
        .get();
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
}
```

- [ ] **Step 5: `watchParticipant`**

Em `lib/data/repositories/participant_repository.dart`:

Substituir:

```dart
              rows.map(SessionParticipant.fromRow).toList(growable: false),
        );
```

por:

```dart
              rows.map(SessionParticipant.fromRow).toList(growable: false),
        );
  }

  /// Um participante do cache — o cabeçalho do checklist (Fase 4). Emite
  /// nulo se ele não estiver no aparelho.
  Stream<SessionParticipant?> watchParticipant(String participantId) {
    final query = _db.select(_db.participants)
      ..where((t) => t.id.equals(participantId));
    return query.watchSingleOrNull().map(
          (row) => row == null ? null : SessionParticipant.fromRow(row),
        );
```

- [ ] **Step 6: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **242 testes passando**.

- [ ] **Step 7: Commit**

```bash
git add lib/data/repositories/assessment_repository.dart lib/data/repositories/participant_repository.dart test/data/repositories/assessment_repository_test.dart test/data/repositories/participant_repository_test.dart
git commit -m "feat(mobile): rascunho local da avaliacao no aparelho"
```

---

## Task 4: Regras puras do checklist

A junção catálogo × marcações, sem widget, no padrão do `participant_filter.dart` da Fase 3. Cada categoria do catálogo vira uma seção com as infrações (botões sempre na ordem B, PM, M, mesmo que o admin tenha cadastrado fora de ordem), a nota escolhida, a observação dela, o score (`calculateCategoryScore` com o `deduction` das notas marcadas e o total de infrações da categoria) e se está revisada. Marcações órfãs e itens do catálogo sem id (o `fromJson` aceita id ausente como `''` — pendência da Fase 3) ficam de fora.

**Files:**
- Create: `lib/ui/checklist/checklist_sections.dart`
- Test: `test/ui/checklist/checklist_sections_test.dart`

**Interfaces:**
- Consumes: `CatalogCategory`/`CatalogInfraction`/`CatalogNote`; `LocalAssessmentItem`; `calculateCategoryScore`, `calculateOverallScore` (Task 2); `AppColors.successBg/successInk`, `notePmBg/notePmInk`, `noteMBg/noteMInk` (Task 1).
- Produces:
  - `const List<String> noteTypeOrder = ['B', 'PM', 'M']`
  - `ChecklistNoteOption(id, noteType, comment, deduction)`
  - `ChecklistInfraction(id, description, order, notes, selectedNoteId)` com `isMarked`, `selectedNote`, `selectedComment`
  - `ChecklistCategory(id, code, name, infractions, score)` com `isReviewed` (≥ 1 infração marcada)
  - `List<ChecklistCategory> buildChecklistSections(List<CatalogCategory> catalog, List<LocalAssessmentItem> items)`
  - `double overallScoreOf(List<ChecklistCategory> sections)`
  - `({Color bg, Color ink}) scoreBadgeColorsFor(double score)` — ≥ 85 sucesso, 70–84,9 PM, < 70 M (spec `5a`).

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/checklist/checklist_sections_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/assessment_catalog.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/checklist/checklist_sections.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';

void main() {
  CatalogNote note(String id, String noteType, int deduction, {String? comment}) {
    return CatalogNote(
      id: id,
      infractionId: 'inf-shared',
      noteType: noteType,
      deduction: deduction,
      comment: comment,
    );
  }

  CatalogInfraction infraction(
    String id, {
    required int order,
    List<CatalogNote> notes = const [],
    String description = 'Descrição',
  }) {
    return CatalogInfraction(
      id: id,
      categoryId: 'cat-1',
      description: description,
      order: order,
      notes: notes,
    );
  }

  LocalAssessmentItem item(String infractionId, String noteId) {
    return LocalAssessmentItem(
      id: 'item-$infractionId',
      localAssessmentId: 'assess-1',
      infractionId: infractionId,
      infractionNoteId: noteId,
      updatedAt: DateTime(2026, 9, 25),
    );
  }

  group('buildChecklistSections', () {
    test('categoria sem nenhuma infração marcada vale 100 e não é revisada', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [
              note('note-b-1', 'B', 1),
              note('note-pm-1', 'PM', 3),
              note('note-m-1', 'M', 5),
            ]),
          ],
        ),
      ];

      final sections = buildChecklistSections(catalog, const []);

      expect(sections, hasLength(1));
      expect(sections.single.score, 100);
      expect(sections.single.isReviewed, isFalse);
      expect(sections.single.infractions.single.isMarked, isFalse);
    });

    test(
        'categoria "CV" do canvas: 6 infrações, uma PM e uma B marcadas — '
        'bate com o "86,7%" da spec', () {
      final infractions = [
        for (var i = 1; i <= 6; i++)
          infraction('inf-$i', order: i, notes: [
            note('note-b-$i', 'B', 1),
            note('note-pm-$i', 'PM', 3),
            note('note-m-$i', 'M', 5),
          ]),
      ];
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: infractions,
        ),
      ];
      final items = [item('inf-1', 'note-pm-1'), item('inf-2', 'note-b-2')];

      final sections = buildChecklistSections(catalog, items);

      expect(sections.single.score, closeTo(86.6666, 0.001));
      expect(sections.single.isReviewed, isTrue);
    });

    test('a nota escolhida traz sua observação, e as demais infrações ficam sem', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [
              note('note-b-1', 'B', 1, comment: 'Leve, sem risco imediato.'),
              note('note-pm-1', 'PM', 3, comment: 'Atenção reforçada.'),
              note('note-m-1', 'M', 5, comment: 'Risco grave.'),
            ]),
          ],
        ),
      ];

      final sections = buildChecklistSections(catalog, [item('inf-1', 'note-m-1')]);

      expect(sections.single.infractions.single.selectedComment, 'Risco grave.');
    });

    test('os 3 botões vêm sempre na ordem B, PM, M, mesmo se o catálogo vier fora de ordem', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [
              note('note-m-1', 'M', 5),
              note('note-b-1', 'B', 1),
              note('note-pm-1', 'PM', 3),
            ]),
          ],
        ),
      ];

      final sections = buildChecklistSections(catalog, const []);

      expect(
        sections.single.infractions.single.notes.map((n) => n.noteType),
        ['B', 'PM', 'M'],
      );
    });

    test('marcação de infração que não existe mais no catálogo é ignorada, sem quebrar', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [
              note('note-b-1', 'B', 1),
              note('note-pm-1', 'PM', 3),
              note('note-m-1', 'M', 5),
            ]),
          ],
        ),
      ];
      final items = [item('inf-1', 'note-b-1'), item('inf-orfa', 'note-x')];

      final sections = buildChecklistSections(catalog, items);

      expect(sections.single.infractions, hasLength(1));
      expect(sections.single.infractions.single.selectedNoteId, 'note-b-1');
    });

    test(
        'marcação com nota que não existe mais no catálogo aparece como "sem '
        'infração" — não conta como revisada nem no score', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [
              note('note-b-1', 'B', 1),
              note('note-pm-novo', 'PM', 3),
              note('note-m-1', 'M', 5),
            ]),
          ],
        ),
      ];

      final sections =
          buildChecklistSections(catalog, [item('inf-1', 'note-pm-antigo')]);

      final infraction1 = sections.single.infractions.single;
      expect(infraction1.selectedNoteId, isNull);
      expect(infraction1.isMarked, isFalse);
      expect(sections.single.isReviewed, isFalse);
      expect(sections.single.score, 100);
    });

    test('itens do catálogo sem id são descartados', () {
      final catalog = [
        const CatalogCategory(id: '', code: '??', name: 'Sem id', order: 0, infractions: []),
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('', order: 1),
            infraction('inf-1', order: 2, notes: [
              note('', 'B', 1),
              note('note-pm-1', 'PM', 3),
            ]),
          ],
        ),
      ];

      final sections = buildChecklistSections(catalog, const []);

      expect(sections.map((s) => s.id), ['cat-1']);
      expect(sections.single.infractions.map((i) => i.id), ['inf-1']);
      expect(sections.single.infractions.single.notes.map((n) => n.id), ['note-pm-1']);
    });

    test('duas categorias, uma revisada e outra não', () {
      final catalog = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CV',
          name: 'Controle do Veículo',
          order: 1,
          infractions: [
            infraction('inf-1', order: 1, notes: [note('note-b-1', 'B', 1)]),
          ],
        ),
        CatalogCategory(
          id: 'cat-2',
          code: 'TP',
          name: 'Transporte',
          order: 2,
          infractions: [
            infraction('inf-2', order: 1, notes: [note('note-b-2', 'B', 1)]),
          ],
        ),
      ];
      final items = [item('inf-1', 'note-b-1')];

      final sections = buildChecklistSections(catalog, items);

      expect(sections[0].isReviewed, isTrue);
      expect(sections[1].isReviewed, isFalse);
    });
  });

  group('overallScoreOf', () {
    test('é a média simples dos scores das categorias, mesmo as não abertas', () {
      final sections = [
        const ChecklistCategory(
            id: 'cat-1', code: 'CV', name: 'A', infractions: [], score: 86.6666666666),
        const ChecklistCategory(id: 'cat-2', code: 'TP', name: 'B', infractions: [], score: 100),
        const ChecklistCategory(id: 'cat-3', code: 'EQ', name: 'C', infractions: [], score: 100),
        const ChecklistCategory(id: 'cat-4', code: 'DO', name: 'D', infractions: [], score: 100),
      ];

      expect(overallScoreOf(sections), closeTo(96.6666, 0.001));
    });

    test('sem categorias, vale 100', () {
      expect(overallScoreOf(const []), 100);
    });
  });

  group('scoreBadgeColorsFor', () {
    test('85% ou mais usa o tom de sucesso', () {
      final colors = scoreBadgeColorsFor(85);
      expect(colors.bg, AppColors.successBg);
      expect(colors.ink, AppColors.successInk);
    });

    test('de 70% a 84,9% usa o tom PM', () {
      final colors = scoreBadgeColorsFor(80);
      expect(colors.bg, AppColors.notePmBg);
      expect(colors.ink, AppColors.notePmInk);
    });

    test('abaixo de 70% usa o tom M', () {
      final colors = scoreBadgeColorsFor(69.9);
      expect(colors.bg, AppColors.noteMBg);
      expect(colors.ink, AppColors.noteMInk);
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/ui/checklist/checklist_sections_test.dart`
Esperado: falha de compilação — `Error when reading 'lib/ui/checklist/checklist_sections.dart'` e `Method not found: 'buildChecklistSections'`.

- [ ] **Step 3: Implementar**

Criar `lib/ui/checklist/checklist_sections.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../data/models/assessment_catalog.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/scoring.dart';
import '../core/theme/app_colors.dart';

/// Uma nota (B/PM/M) disponível para uma infração, na ordem fixa do canvas —
/// não a ordem em que o backend devolveu (o admin pode ter cadastrado M antes
/// de B).
const List<String> noteTypeOrder = ['B', 'PM', 'M'];

class ChecklistNoteOption {
  const ChecklistNoteOption({
    required this.id,
    required this.noteType,
    required this.comment,
    required this.deduction,
  });

  final String id;

  /// `B`, `PM` ou `M`.
  final String noteType;
  final String? comment;
  final int deduction;
}

class ChecklistInfraction {
  const ChecklistInfraction({
    required this.id,
    required this.description,
    required this.order,
    required this.notes,
    required this.selectedNoteId,
  });

  final String id;
  final String description;
  final int order;

  /// Sempre 3, na ordem B/PM/M — os 3 botões do seletor.
  final List<ChecklistNoteOption> notes;

  /// Nulo quando nenhum botão está pressionado.
  final String? selectedNoteId;

  bool get isMarked => selectedNoteId != null;

  ChecklistNoteOption? get selectedNote => selectedNoteId == null
      ? null
      : notes.where((n) => n.id == selectedNoteId).firstOrNull;

  /// Observação da nota escolhida, mostrada sob o seletor — nula se não há
  /// nota escolhida ou se ela não tem observação cadastrada.
  String? get selectedComment => selectedNote?.comment;
}

class ChecklistCategory {
  const ChecklistCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.infractions,
    required this.score,
  });

  final String id;
  final String code;
  final String name;
  final List<ChecklistInfraction> infractions;

  /// 0–100, por `calculateCategoryScore` — 100 quando nada foi marcado.
  final double score;

  /// Regra decidida com o usuário em 26/09/2026: uma categoria conta como
  /// "revisada" (não pendente, para o aviso do "Finalizar avaliação") quando
  /// tem pelo menos uma infração marcada — não precisa marcar as demais como
  /// "sem infração" para contar.
  bool get isReviewed => infractions.any((i) => i.isMarked);
}

/// Monta as seções do acordeão a partir do catálogo e das marcações
/// salvas — é a junção que a `AssessmentCatalogRepository` (catálogo) e a
/// `AssessmentRepository` (marcações) não fazem sozinhas, porque cada uma só
/// conhece a própria tabela.
///
/// Marcação órfã (o admin mudou o catálogo no painel web depois da marcação):
/// se a infração sumiu, a marcação nunca é lida — o laço percorre o catálogo,
/// não as marcações; se só a nota sumiu, a infração aparece como "sem
/// infração". Nos dois casos a linha antiga fica no banco, sem quebrar nada.
///
/// Itens do catálogo sem `id` são descartados: `CatalogCategory.fromJson` (e
/// os das infrações e notas) aceitam o id ausente como `''`, e um id vazio
/// não serve para marcar nada.
List<ChecklistCategory> buildChecklistSections(
  List<CatalogCategory> catalog,
  List<LocalAssessmentItem> items,
) {
  final itemByInfraction = {for (final item in items) item.infractionId: item};

  return [
    for (final category in catalog)
      if (category.id.isNotEmpty) _buildCategory(category, itemByInfraction),
  ];
}

ChecklistCategory _buildCategory(
  CatalogCategory category,
  Map<String, LocalAssessmentItem> itemByInfraction,
) {
  final infractions = [
    for (final infraction in category.infractions)
      if (infraction.id.isNotEmpty)
        _buildInfraction(infraction, itemByInfraction[infraction.id]),
  ];

  final noteWeights = [
    for (final infraction in infractions)
      if (infraction.selectedNote != null) infraction.selectedNote!.deduction,
  ];

  return ChecklistCategory(
    id: category.id,
    code: category.code,
    name: category.name,
    infractions: infractions,
    score: calculateCategoryScore(noteWeights, infractions.length),
  );
}

ChecklistInfraction _buildInfraction(
  CatalogInfraction infraction,
  LocalAssessmentItem? item,
) {
  final notes = [
    for (final note in infraction.notes)
      if (note.id.isNotEmpty) note,
  ]..sort(
      (a, b) => noteTypeOrder
          .indexOf(a.noteType)
          .compareTo(noteTypeOrder.indexOf(b.noteType)),
    );
  final selectedNoteId = item?.infractionNoteId;

  return ChecklistInfraction(
    id: infraction.id,
    description: infraction.description,
    order: infraction.order,
    notes: [
      for (final note in notes)
        ChecklistNoteOption(
          id: note.id,
          noteType: note.noteType,
          comment: note.comment,
          deduction: note.deduction,
        ),
    ],
    selectedNoteId:
        notes.any((n) => n.id == selectedNoteId) ? selectedNoteId : null,
  );
}

/// Score geral do checklist — a média simples das categorias
/// (`calculateOverallScore`), incluindo as ainda não abertas (valem 100).
double overallScoreOf(List<ChecklistCategory> sections) {
  return calculateOverallScore([for (final s in sections) s.score]);
}

/// Cor do selo de score (spec "5a"): as mesmas faixas de severidade PM/M
/// reaproveitadas para as faixas média/baixa — não há tokens próprios de
/// "faixa de score".
({Color bg, Color ink}) scoreBadgeColorsFor(double score) {
  if (score >= 85) return (bg: AppColors.successBg, ink: AppColors.successInk);
  if (score >= 70) return (bg: AppColors.notePmBg, ink: AppColors.notePmInk);
  return (bg: AppColors.noteMBg, ink: AppColors.noteMInk);
}
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **255 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/checklist/checklist_sections.dart test/ui/checklist/checklist_sections_test.dart
git commit -m "feat(mobile): regras do checklist - secoes, revisadas e score"
```

---

## Task 5: `ChecklistViewModel`

O estado da tela 1.5. O catálogo é lido uma vez (não muda durante a avaliação); as marcações vêm de um stream, mas `toggleNote` usa a lista que `mark`/`unmark` devolvem — o stream de uma assinatura já aberta pode notificar um turno de evento depois da escrita, e o botão tem de aparecer pressionado na hora. O cronômetro é um `Timer.periodic` de verdade: nos testes, um intervalo bem curto e um relógio próprio (`now`) que o teste avança, sem `fake_async`. A guarda de dispose segue o padrão de `402838c`: `notifyListeners` sobrescrito para não notificar depois do dispose, e `init()` parando depois de cada `await` se a tela já saiu (para não criar o cronômetro nem assinaturas que ninguém vai cancelar). O teste do cancelamento é um `testWidgets` de propósito: o binding falha o teste se ele terminar com um `Timer` pendente — por isso o banco dos testes desta task também fecha os streams na hora (ver Global Constraints).

**Files:**
- Create: `lib/ui/checklist/checklist_viewmodel.dart`
- Test: `test/ui/checklist/checklist_viewmodel_test.dart`

**Interfaces:**
- Consumes: `AssessmentRepository` e `ParticipantRepository.watchParticipant` (Task 3); `AssessmentCatalogRepository.loadCatalog()`; `buildChecklistSections`, `overallScoreOf`, `ChecklistCategory` (Task 4).
- Produces:
  - `ChecklistViewModel({required String sessionId, required String participantId, required AssessmentRepository assessmentRepository, required ParticipantRepository participantRepository, required AssessmentCatalogRepository catalogRepository, DateTime Function()? now, Duration tickInterval = const Duration(seconds: 1)})`
  - `Future<void> init()` — abre/retoma o rascunho, assina participante e marcações, carrega o catálogo, abre a primeira categoria e liga o cronômetro.
  - getters: `isLoading`, `participant`, `expandedCategoryId`, `isFinished`, `sections`, `overallScore`, `reviewedCount`, `totalCategories`, `unreviewedCount`, `hasUnreviewedCategories`, `hasCatalog`, `elapsedLabel` (`"HH:MM:SS"`).
  - `void toggleCategory(String categoryId)`; `Future<void> toggleNote(String infractionId, String noteId)`; `Future<void> finish()` (recusa sem catálogo; para o cronômetro).

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/ui/checklist/checklist_viewmodel_test.dart`:

```dart
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/checklist/checklist_viewmodel.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// Relógio mutável para o cronômetro nos testes: em vez de `fake_async`, o
/// `Timer.periodic` roda de verdade (com um intervalo bem curto) e o teste
/// avança este valor entre os ticks.
class _MutableClock {
  _MutableClock(this.value);
  DateTime value;
  DateTime call() => value;
}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;

  setUp(() {
    api = _MockApiClient();
    // Um dos testes é `testWidgets` (relógio falso): sem fechar os streams na
    // hora, o `Timer` de duração zero que o drift agenda ao cancelar um
    // stream ficaria pendente e derrubaria o teste.
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    assessmentRepository = AssessmentRepository(database: db);
    participantRepository = ParticipantRepository(apiClient: api, database: db);
    catalogRepository = AssessmentCatalogRepository(apiClient: api, database: db);
  });

  tearDown(() => db.close());

  Future<void> seedParticipant({String id = 'tp-1', String name = 'Carlos Eduardo Nunes'}) async {
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
            id: id,
            sessionId: 'sess-1',
            name: name,
            cpf: '187.443.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'EM_AVALIACAO',
            cachedAt: DateTime(2026, 9, 25, 8),
          ),
        );
  }

  Future<void> seedCatalog() async {
    await db.into(db.assessmentCategories).insert(
          AssessmentCategoriesCompanion.insert(
            id: 'cat-1',
            code: 'CV',
            name: 'Controle do Veículo',
            order: 1,
          ),
        );
    await db.into(db.infractions).insert(
          InfractionsCompanion.insert(
            id: 'inf-1',
            categoryId: 'cat-1',
            description: 'Excesso de velocidade',
            order: 1,
          ),
        );
    for (final n in [('note-b', 'B', 1), ('note-pm', 'PM', 3), ('note-m', 'M', 5)]) {
      await db.into(db.infractionNotes).insert(
            InfractionNotesCompanion.insert(
              id: n.$1,
              infractionId: 'inf-1',
              noteType: n.$2,
              deduction: n.$3,
            ),
          );
    }
  }

  ChecklistViewModel buildViewModel({DateTime Function()? now, Duration? tickInterval}) {
    return ChecklistViewModel(
      sessionId: 'sess-1',
      participantId: 'tp-1',
      assessmentRepository: assessmentRepository,
      participantRepository: participantRepository,
      catalogRepository: catalogRepository,
      now: now,
      tickInterval: tickInterval ?? const Duration(seconds: 1),
    );
  }

  group('init', () {
    test('carrega o participante, o catálogo e sai de loading', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);

      expect(vm.isLoading, isTrue);
      await vm.init();

      expect(vm.isLoading, isFalse);
      expect(vm.participant?.name, 'Carlos Eduardo Nunes');
      expect(vm.sections, hasLength(1));
      expect(vm.sections.single.infractions, hasLength(1));
      expect(vm.expandedCategoryId, 'cat-1', reason: 'abre com a primeira categoria aberta');
    });

    test('retomar o checklist reabre o mesmo rascunho, sem perder marcações', () async {
      await seedParticipant();
      await seedCatalog();

      final first = buildViewModel();
      await first.init();
      await first.toggleNote('inf-1', 'note-pm');
      first.dispose();

      final second = buildViewModel();
      addTearDown(second.dispose);
      await second.init();

      expect(second.sections.single.infractions.single.selectedNoteId, 'note-pm');
    });
  });

  group('toggleNote', () {
    test('marca a infração e o score da categoria cai', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();

      await vm.toggleNote('inf-1', 'note-m');

      expect(vm.sections.single.infractions.single.selectedNoteId, 'note-m');
      expect(vm.sections.single.score, 0);
      expect(vm.reviewedCount, 1);
      expect(vm.unreviewedCount, 0);
      expect(vm.hasUnreviewedCategories, isFalse);
    });

    test('apertar a mesma nota de novo desmarca a infração', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.toggleNote('inf-1', 'note-b');

      await vm.toggleNote('inf-1', 'note-b');

      expect(vm.sections.single.infractions.single.selectedNoteId, isNull);
      expect(vm.sections.single.score, 100);
      expect(vm.unreviewedCount, 1);
      expect(vm.hasUnreviewedCategories, isTrue);
    });
  });

  group('toggleCategory', () {
    test('abrir outra categoria fecha a aberta; tocar na aberta fecha', () async {
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
      await vm.init();
      expect(vm.expandedCategoryId, 'cat-1');

      vm.toggleCategory('cat-2');
      expect(vm.expandedCategoryId, 'cat-2');

      vm.toggleCategory('cat-2');
      expect(vm.expandedCategoryId, isNull);
    });
  });

  group('elapsedLabel', () {
    test('avança conforme o relógio injetado, sem esperar tempo real', () async {
      await seedParticipant();
      await seedCatalog();
      // `openDraft` grava `startTime` com o relógio real — a base do relógio
      // falso precisa ser próxima do "agora" de verdade, senão a diferença
      // fica negativa e o formato trava em zero.
      final clock = _MutableClock(DateTime.now());
      final vm = buildViewModel(now: clock.call, tickInterval: const Duration(milliseconds: 5));
      addTearDown(vm.dispose);
      await vm.init();

      expect(vm.elapsedLabel, '00:00:00');

      clock.value = clock.value.add(const Duration(hours: 1, minutes: 2, seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(vm.elapsedLabel, '01:02:03');
    });
  });

  group('finish', () {
    test('marca local, sinaliza isFinished e para o cronômetro', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel(tickInterval: const Duration(milliseconds: 5));
      addTearDown(vm.dispose);
      await vm.init();

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
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();

      expect(vm.hasCatalog, isFalse);
      await vm.finish();

      expect(vm.isFinished, isFalse);
      final row = await db.select(db.localAssessments).getSingle();
      expect(row.syncStatus, LocalSyncStatus.draft);
    });
  });

  testWidgets('dispose cancela o cronômetro: nenhum timer fica pendente', (tester) async {
    await seedParticipant();
    await seedCatalog();
    final vm = buildViewModel();
    await vm.init();
    expect(vm.isLoading, isFalse, reason: 'o init terminou e ligou o cronômetro');

    vm.dispose();
    // O `testWidgets` falha sozinho se terminar com um `Timer` pendente: um
    // `Timer.periodic` que o dispose esquecesse de cancelar ficaria aqui.
  });

  test('uma escrita que termina depois do dispose não notifica a tela morta',
      () async {
    await seedParticipant();
    await seedCatalog();
    final vm = buildViewModel();
    await vm.init();

    final pending = vm.toggleNote('inf-1', 'note-b');
    vm.dispose();

    // Sem a guarda, o `notifyListeners` do fim do `toggleNote` lançaria
    // "used after being disposed" e esta escrita terminaria com erro.
    await expectLater(pending, completes);
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `flutter test test/ui/checklist/checklist_viewmodel_test.dart`
Esperado: falha de compilação — `Error when reading 'lib/ui/checklist/checklist_viewmodel.dart'` e `'ChecklistViewModel' isn't a type`.

- [ ] **Step 3: Implementar**

Criar `lib/ui/checklist/checklist_viewmodel.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/assessment_catalog.dart';
import '../../data/models/session_participant.dart';
import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/services/local/app_database.dart';
import 'checklist_sections.dart';

/// Estado da tela do checklist (Fase 4).
///
/// O catálogo é lido uma vez (`loadCatalog`, sem stream — não muda durante a
/// avaliação); as marcações, sim, vêm de um stream, porque `toggleNote`
/// escreve no banco e a tela precisa reagir à própria escrita. Nada aqui fala
/// com o backend: a avaliação só é gravada no aparelho, e a fila de envio é de
/// uma fase futura.
class ChecklistViewModel extends ChangeNotifier {
  ChecklistViewModel({
    required this.sessionId,
    required this.participantId,
    required AssessmentRepository assessmentRepository,
    required ParticipantRepository participantRepository,
    required AssessmentCatalogRepository catalogRepository,
    DateTime Function()? now,
    this.tickInterval = const Duration(seconds: 1),
  })  : _assessmentRepository = assessmentRepository,
        _participantRepository = participantRepository,
        _catalogRepository = catalogRepository,
        _now = now ?? DateTime.now;

  final String sessionId;
  final String participantId;
  final AssessmentRepository _assessmentRepository;
  final ParticipantRepository _participantRepository;
  final AssessmentCatalogRepository _catalogRepository;
  final DateTime Function() _now;

  /// Intervalo real do `Timer` do cronômetro — os testes passam um intervalo
  /// bem curto e avançam um relógio próprio (`now`) entre os ticks, em vez de
  /// usar `fake_async`: o `Timer` roda de verdade, só que rápido.
  final Duration tickInterval;

  StreamSubscription<SessionParticipant?>? _participantSubscription;
  StreamSubscription<List<LocalAssessmentItem>>? _itemsSubscription;
  Timer? _ticker;

  bool _disposed = false;
  bool _loading = true;
  String? _assessmentId;
  DateTime? _startTime;
  SessionParticipant? _participant;
  List<CatalogCategory> _catalog = const [];
  List<LocalAssessmentItem> _items = const [];
  String? _expandedCategoryId;
  bool _finished = false;

  bool get isLoading => _loading;
  SessionParticipant? get participant => _participant;
  String? get expandedCategoryId => _expandedCategoryId;

  /// Uma vez `true`, a tela navega de volta ao detalhe da sessão — regra
  /// decidida com o usuário em 26/09/2026: finalizar marca local e volta.
  bool get isFinished => _finished;

  List<ChecklistCategory> get sections =>
      buildChecklistSections(_catalog, _items);

  double get overallScore => overallScoreOf(sections);

  int get reviewedCount => sections.where((s) => s.isReviewed).length;
  int get totalCategories => sections.length;
  int get unreviewedCount => totalCategories - reviewedCount;

  /// Há categoria sem nenhuma infração marcada — só então o "Finalizar
  /// avaliação" pede confirmação (roteiro da Fase 4).
  bool get hasUnreviewedCategories => unreviewedCount > 0;

  /// O catálogo nunca chegou a este aparelho (a descida junto com a Home
  /// falhou). Sem ele não há o que avaliar — e finalizar uma avaliação sem
  /// categoria nenhuma daria 100%, "Aprovado".
  bool get hasCatalog => _catalog.isNotEmpty;

  /// "00:12:34" desde o início da avaliação — `00:00:00` antes de o rascunho
  /// abrir.
  String get elapsedLabel {
    final start = _startTime;
    if (start == null) return '00:00:00';
    return _formatElapsed(_now().difference(start));
  }

  Future<void> init() async {
    final assessment = await _assessmentRepository.openDraft(
      trainingParticipantId: participantId,
      sessionId: sessionId,
    );
    if (_disposed) return;

    _assessmentId = assessment.id;
    _startTime = assessment.startTime;

    _participantSubscription ??=
        _participantRepository.watchParticipant(participantId).listen((p) {
      _participant = p;
      notifyListeners();
    });

    _itemsSubscription ??=
        _assessmentRepository.watchItems(assessment.id).listen((items) {
      _items = items;
      notifyListeners();
    });

    _catalog = await _catalogRepository.loadCatalog();
    if (_disposed) return;

    // Como no canvas: a tela sempre abre com a primeira categoria aberta.
    final sections = this.sections;
    _expandedCategoryId = sections.isEmpty ? null : sections.first.id;

    _ticker ??= Timer.periodic(tickInterval, (_) => notifyListeners());

    _loading = false;
    notifyListeners();
  }

  /// Acordeão de uma seção só — abrir outra fecha a anterior, como no canvas.
  void toggleCategory(String categoryId) {
    _expandedCategoryId = _expandedCategoryId == categoryId ? null : categoryId;
    notifyListeners();
  }

  /// Aperta um dos 3 botões de nota. O mesmo botão já selecionado desmarca a
  /// infração (nenhuma nota); um botão diferente troca a nota.
  ///
  /// Usa a lista que `mark`/`unmark` devolvem, em vez de esperar o
  /// `_itemsSubscription` reagir — o stream de uma assinatura já aberta pode
  /// notificar um turno de evento depois da escrita, e a tela precisa
  /// mostrar o botão pressionado na hora.
  Future<void> toggleNote(String infractionId, String noteId) async {
    final assessmentId = _assessmentId;
    if (assessmentId == null) return;

    final current = _items
        .where((i) => i.infractionId == infractionId)
        .map((i) => i.infractionNoteId)
        .firstOrNull;

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
    notifyListeners();
  }

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
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _participantSubscription?.cancel();
    _itemsSubscription?.cancel();
    super.dispose();
  }
}

String _formatElapsed(Duration elapsed) {
  final total = elapsed.isNegative ? Duration.zero : elapsed;
  final hours = total.inHours.toString().padLeft(2, '0');
  final minutes = (total.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (total.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
```

- [ ] **Step 4: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **265 testes passando**.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/checklist/checklist_viewmodel.dart test/ui/checklist/checklist_viewmodel_test.dart
git commit -m "feat(mobile): viewmodel do checklist com cronometro e rascunho"
```

---

## Task 6: Tela 1.5, rota e providers

A tela do quadro `1b`: cabeçalho de duas linhas (nome; cronômetro e "salvo") com o progresso de categorias e o score geral, `ConnectivityBanner` embaixo dele, acordeão com a categoria aberta como bloco próprio e as fechadas em grupos, os 3 botões com as cores da `4z`, a observação da nota escolhida e o "Finalizar avaliação" no rodapé. Depois, a rota troca o builder, o `AssessmentRepository` entra nos providers e a tela provisória perde o caso do checklist.

**Files:**
- Create: `lib/ui/checklist/checklist_screen.dart`
- Modify: `lib/router.dart`
- Modify: `lib/app_providers.dart`
- Modify: `lib/ui/evaluation/evaluation_placeholder_screen.dart`
- Test: `test/ui/checklist/checklist_screen_test.dart`
- Test: `test/ui/session_detail/session_detail_screen_test.dart`

**Interfaces:**
- Consumes: `ChecklistViewModel` (Task 5); `ChecklistCategory`, `ChecklistInfraction`, `ChecklistNoteOption`, `scoreBadgeColorsFor` (Task 4); tokens e `AppCtaSize.large` (Task 1); `AssessmentRepository` (Task 3).
- Produces:
  - `ChecklistScreen({required String sessionId, required String participantId})`, lendo `AssessmentRepository`, `ParticipantRepository`, `AssessmentCatalogRepository` e `ConnectivityService` do `provider`.
  - `AppDependencies.assessmentRepository` e o `Provider<AssessmentRepository>`.
  - `enum EvaluationPlaceholderKind { result }`.

- [ ] **Step 1: Escrever os testes da tela**

Criar `test/ui/checklist/checklist_screen_test.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;
  late ConnectivityService connectivity;

  const pmComment = 'Excedeu o limite em trecho sinalizado';

  setUp(() async {
    api = _MockApiClient();
    // Ao cancelar um stream, o drift adia o fechamento com um `Timer` de
    // duração zero. Dentro do relógio falso do `testWidgets`, esse timer
    // nasce no dispose da tela (no fim do teste) e nunca roda: o teste
    // reclama de timer pendente e o `db.close()` do tearDown espera por ele
    // para sempre. Fechar os streams na hora elimina o timer.
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
    await db.into(db.assessmentCategories).insert(
          AssessmentCategoriesCompanion.insert(
            id: 'cat-1',
            code: 'CV',
            name: 'Controle do Veículo',
            order: 1,
          ),
        );
    await db.into(db.infractions).insert(
          InfractionsCompanion.insert(
            id: 'inf-1',
            categoryId: 'cat-1',
            description: 'Excesso de velocidade',
            order: 1,
          ),
        );
    for (final n in [
      ('note-b', 'B', 1, null),
      ('note-pm', 'PM', 3, pmComment),
      ('note-m', 'M', 5, null),
    ]) {
      await db.into(db.infractionNotes).insert(
            InfractionNotesCompanion.insert(
              id: n.$1,
              infractionId: 'inf-1',
              noteType: n.$2,
              deduction: n.$3,
              comment: Value(n.$4),
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
    connectivity.dispose();
  });

  Widget withProviders(Widget child) {
    return MultiProvider(
      providers: [
        Provider<AssessmentRepository>.value(value: assessmentRepository),
        Provider<ParticipantRepository>.value(value: participantRepository),
        Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
      ],
      child: child,
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(withProviders(
      const MaterialApp(
        home: ChecklistScreen(sessionId: 'sess-1', participantId: 'tp-1'),
      ),
    ));
    await tester.pumpAndSettle();
  }

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
  }

  Future<void> addSecondCategory() async {
    await db.into(db.assessmentCategories).insert(
          AssessmentCategoriesCompanion.insert(
            id: 'cat-2',
            code: 'RR',
            name: 'Respeito às Regras',
            order: 2,
          ),
        );
    for (final (id, order) in [('inf-3', 3), ('inf-7', 7)]) {
      await db.into(db.infractions).insert(
            InfractionsCompanion.insert(
              id: id,
              categoryId: 'cat-2',
              description: 'Infração da ficha, item $order',
              order: order,
            ),
          );
    }
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

  testWidgets('abre com o nome do participante e a primeira categoria aberta',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
    expect(find.text('CV'), findsOneWidget);
    expect(find.text('Excesso de velocidade'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('salvo'), findsOneWidget);
    expect(find.text('0 de 1 categorias revisadas'), findsOneWidget);
  });

  testWidgets('tocar na categoria aberta fecha, e a fechada mostra "N itens"',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Controle do Veículo'));
    await tester.pumpAndSettle();

    expect(find.text('Excesso de velocidade'), findsNothing);
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets(
      'abrir outra categoria fecha a aberta, e o número da infração é o item '
      'da ficha (order), não a posição', (tester) async {
    await addSecondCategory();
    await pumpScreen(tester);
    expect(find.text('2 itens'), findsOneWidget);

    await tester.tap(find.text('Respeito às Regras'));
    await tester.pumpAndSettle();

    expect(find.text('Excesso de velocidade'), findsNothing);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('Infração da ficha, item 7'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('marcar a nota M zera o score da categoria e do geral', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('M'));
    await tester.pumpAndSettle();

    expect(find.text('0,0%'), findsNWidgets(2), reason: 'selo da categoria e geral');
    expect(find.text('1 de 1 categorias revisadas'), findsOneWidget);
  });

  testWidgets(
      'a observação da nota escolhida aparece embaixo dos botões, e some ao '
      'desmarcar', (tester) async {
    await pumpScreen(tester);
    expect(find.text(pmComment), findsNothing);

    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();
    expect(find.text(pmComment), findsOneWidget);

    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();
    expect(find.text(pmComment), findsNothing);
    expect(find.text('100,0%'), findsNWidgets(2), reason: 'selo da categoria e geral');
    expect(find.text('0 de 1 categorias revisadas'), findsOneWidget);
  });

  testWidgets('sem conexão, a faixa avisa que as marcações continuam salvas',
      (tester) async {
    await goOffline();
    await pumpScreen(tester);

    expect(
      find.text('Sem conexão — as marcações continuam sendo salvas no aparelho.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'finalizar com categoria sem marcação pergunta e, ao confirmar, grava e '
      'volta para a tela anterior', (tester) async {
    await pumpOverOrigin(tester);

    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();

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
    expect(row.syncStatus, LocalSyncStatus.draft);
  });

  testWidgets('com todas as categorias revisadas, finaliza sem perguntar',
      (tester) async {
    await pumpOverOrigin(tester);
    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ChecklistScreen), findsNothing);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
  });

  testWidgets('sem catálogo no aparelho, avisa e não oferece "Finalizar"',
      (tester) async {
    await db.delete(db.infractionNotes).go();
    await db.delete(db.infractions).go();
    await db.delete(db.assessmentCategories).go();

    await pumpScreen(tester);

    expect(find.byKey(const Key('checklist-no-catalog')), findsOneWidget);
    expect(find.text('Finalizar avaliação'), findsNothing);
    expect(find.textContaining('categorias revisadas'), findsNothing);
  });
}
```

- [ ] **Step 2: A rota real passa a esperar o checklist de verdade**

Em `test/ui/session_detail/session_detail_screen_test.dart`:

Substituir (1 de 9):

```dart
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
```

por:

```dart
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
```

Substituir (2 de 9):

```dart
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

por:

```dart
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

Substituir (3 de 9):

```dart

class _MockAuthRepository extends Mock implements AuthRepository {}
```

por:

```dart

class _MockAssessmentRepository extends Mock implements AssessmentRepository {}

class _MockAssessmentCatalogRepository extends Mock
    implements AssessmentCatalogRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}
```

Substituir (4 de 9):

```dart
  late _MockParticipantRepository participants;
  late _MockAuthRepository auth;
```

por:

```dart
  late _MockParticipantRepository participants;
  late _MockAssessmentRepository assessments;
  late _MockAssessmentCatalogRepository catalog;
  late _MockAuthRepository auth;
```

Substituir (5 de 9):

```dart
    participants = _MockParticipantRepository();
    auth = _MockAuthRepository();
```

por:

```dart
    participants = _MockParticipantRepository();
    assessments = _MockAssessmentRepository();
    catalog = _MockAssessmentCatalogRepository();
    auth = _MockAuthRepository();
```

Substituir (6 de 9):

```dart
    when(() => auth.isAuthenticated).thenReturn(true);
  });
```

por:

```dart
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => catalog.loadCatalog()).thenAnswer((_) async => const []);
    when(() => assessments.openDraft(
          trainingParticipantId: any(named: 'trainingParticipantId'),
          sessionId: any(named: 'sessionId'),
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

Substituir (7 de 9):

```dart
        Provider<ParticipantRepository>.value(value: participants),
        ChangeNotifierProvider<AuthRepository>.value(value: auth),
```

por:

```dart
        Provider<ParticipantRepository>.value(value: participants),
        Provider<AssessmentRepository>.value(value: assessments),
        Provider<AssessmentCatalogRepository>.value(value: catalog),
        ChangeNotifierProvider<AuthRepository>.value(value: auth),
```

Substituir (8 de 9):

```dart

    testWidgets('o meu participante abre o checklist (provisório)',
        (tester) async {
      await showWithRouter(tester, [
        participant('1', 'Ana Paula Ribeiro',
            status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu'),
      ]);
```

por:

```dart

    testWidgets('o meu participante abre o checklist de verdade',
        (tester) async {
      final ana = participant('1', 'Ana Paula Ribeiro',
          status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      when(() => participants.watchParticipant('1'))
          .thenAnswer((_) => Stream.value(ana));
      await showWithRouter(tester, [ana]);
```

Substituir (9 de 9):

```dart

      final screen = tester.widget<EvaluationPlaceholderScreen>(
        find.byType(EvaluationPlaceholderScreen),
      );
      expect(screen.kind, EvaluationPlaceholderKind.checklist);
      expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
```

por:

```dart

      expect(find.byType(ChecklistScreen), findsOneWidget);
      expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
```

- [ ] **Step 3: Rodar e confirmar que falham**

Run: `flutter test test/ui/checklist/checklist_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart`
Esperado: falha de compilação — `Error when reading 'lib/ui/checklist/checklist_screen.dart'` e `Method not found: 'ChecklistScreen'`.

- [ ] **Step 4: Implementar a tela**

Criar `lib/ui/checklist/checklist_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/skeleton.dart';
import 'checklist_sections.dart';
import 'checklist_viewmodel.dart';

/// Tela 1.5 — checklist da avaliação prática (Fase 4), quadro "1b" do canvas.
///
/// Tudo aqui é offline-first: cada toque num botão B/PM/M grava direto no
/// banco local (`ChecklistViewModel.toggleNote`), sem esperar rede — por isso
/// o "salvo" do cabeçalho não depende de conexão.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({
    super.key,
    required this.sessionId,
    required this.participantId,
  });

  final String sessionId;
  final String participantId;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  late final ChecklistViewModel _viewModel = ChecklistViewModel(
    sessionId: widget.sessionId,
    participantId: widget.participantId,
    assessmentRepository: context.read<AssessmentRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    catalogRepository: context.read<AssessmentCatalogRepository>(),
  )..init();

  bool _poppedForFinish = false;

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
  }

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            ConnectivityBanner(
              isOffline: isOffline,
              message: 'Sem conexão — as marcações continuam sendo salvas no aparelho.',
            ),
            Expanded(child: _buildBody()),
            if (!_viewModel.isLoading && _viewModel.hasCatalog) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: AppSpacing.touchTarget,
                child: IconButton(
                  tooltip: 'Voltar',
                  icon: const Icon(AppIcons.back, size: 30, color: AppColors.text),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _viewModel.participant?.name ?? '',
                      style: AppTypography.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs - 1),
                    _buildTimerRow(),
                  ],
                ),
              ),
            ],
          ),
          if (!_viewModel.isLoading && _viewModel.hasCatalog)
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
    );
  }

  Widget _buildTimerRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(AppIcons.timer, size: 14, color: AppColors.text3),
        const SizedBox(width: AppSpacing.xs),
        Text(_viewModel.elapsedLabel, style: AppTypography.code),
        const SizedBox(width: AppSpacing.sm),
        Container(width: 1, height: 11, color: AppColors.borderStrong),
        const SizedBox(width: AppSpacing.sm),
        const Icon(AppIcons.syncDone, size: 14, color: AppColors.savedInk),
        const SizedBox(width: AppSpacing.xs),
        Text('salvo', style: AppTypography.savedLabel),
      ],
    );
  }

  Widget _buildProgress() {
    final reviewed = _viewModel.reviewedCount;
    final total = _viewModel.totalCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$reviewed de $total categorias revisadas',
                style: AppTypography.checklistProgress,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _percentLabel(_viewModel.overallScore),
              style: AppTypography.checklistProgressValue,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: total <= 0 ? 0 : reviewed / total,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return ListView(
        key: const Key('checklist-skeleton'),
        children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
      );
    }

    if (!_viewModel.hasCatalog) {
      return const Padding(
        key: Key('checklist-no-catalog'),
        padding: EdgeInsets.all(AppSpacing.xl),
        child: InlineNotice(
          icon: AppIcons.offline,
          tone: NoticeTone.warning,
          message: 'O catálogo de infrações ainda não foi baixado neste '
              'aparelho. Com internet, atualize a lista de sessões na Home — '
              'o catálogo desce junto.',
        ),
      );
    }

    // Como no canvas: a categoria aberta é um bloco próprio, e as fechadas
    // antes e depois dela formam grupos — cada bloco com borda em cima e
    // embaixo, separados por 10.
    final sections = _viewModel.sections;
    final open = sections.indexWhere((s) => s.id == _viewModel.expandedCategoryId);
    final before = open < 0 ? sections : sections.sublist(0, open);
    final after = open < 0 ? const <ChecklistCategory>[] : sections.sublist(open + 1);
    final blocks = [
      if (before.isNotEmpty) _buildCollapsedGroup(before),
      if (open >= 0) _buildExpandedCategory(sections[open]),
      if (after.isNotEmpty) _buildCollapsedGroup(after),
    ];

    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm + 2),
          blocks[i],
        ],
      ],
    );
  }

  Widget _buildCollapsedGroup(List<ChecklistCategory> categories) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final category in categories) _buildCollapsedCategory(category)],
      ),
    );
  }

  Widget _buildCollapsedCategory(ChecklistCategory category) {
    final count = category.infractions.length;

    return InkWell(
      key: ValueKey('category-${category.id}'),
      onTap: () => _viewModel.toggleCategory(category.id),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
        ),
        child: Row(
          children: [
            _CodeChip(
              code: category.code,
              background: AppColors.categoryChipBg,
              ink: AppColors.primaryDark,
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
            Text(count == 1 ? '1 item' : '$count itens', style: AppTypography.categoryCount),
            const SizedBox(width: AppSpacing.sm + 2),
            const Icon(AppIcons.expandMore, size: 22, color: AppColors.text3),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedCategory(ChecklistCategory category) {
    return DecoratedBox(
      key: ValueKey('category-${category.id}'),
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildExpandedHeader(category),
          for (final infraction in category.infractions) _buildInfractionRow(infraction),
        ],
      ),
    );
  }

  Widget _buildExpandedHeader(ChecklistCategory category) {
    return InkWell(
      onTap: () => _viewModel.toggleCategory(category.id),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: const BoxDecoration(
          color: AppColors.categoryExpandedBg,
          border: Border(bottom: BorderSide(color: AppColors.categoryExpandedBorder)),
        ),
        child: Row(
          children: [
            _CodeChip(
              code: category.code,
              background: AppColors.primary,
              ink: AppColors.surface,
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
            _ScoreBadge(score: category.score),
            const SizedBox(width: AppSpacing.sm + 2),
            const Icon(AppIcons.expandLess, size: 22, color: AppColors.text3),
          ],
        ),
      ),
    );
  }

  Widget _buildInfractionRow(ChecklistInfraction infraction) {
    final comment = infraction.selectedComment;

    return Container(
      key: ValueKey('infraction-${infraction.id}'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // O número é o item na ficha oficial (`order`), não a posição
              // na lista — é por ele que a infração é achada numa contestação.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 14),
                child: Text('${infraction.order}', style: AppTypography.infractionNumber),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(infraction.description, style: AppTypography.infractionDescription),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              for (var i = 0; i < infraction.notes.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm - 2),
                Expanded(
                  child: _NoteButton(
                    note: infraction.notes[i],
                    selected: infraction.selectedNoteId == infraction.notes[i].id,
                    onTap: () => _viewModel.toggleNote(infraction.id, infraction.notes[i].id),
                  ),
                ),
              ],
            ],
          ),
          if (comment != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            _NoteComment(comment),
          ],
        ],
      ),
    );
  }

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
      child: AppCtaButton(
        label: 'Finalizar avaliação',
        icon: AppIcons.finish,
        size: AppCtaSize.large,
        onPressed: _finish,
      ),
    );
  }

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
}

/// Um dos 3 botões B/PM/M (spec "4z"): raio 8, nunca pílula, para não se
/// confundir com os chips de status.
class _NoteButton extends StatelessWidget {
  const _NoteButton({required this.note, required this.selected, required this.onTap});

  final ChecklistNoteOption note;
  final bool selected;
  final VoidCallback onTap;

  ({Color bg, Color border, Color ink}) get _colors => switch (note.noteType) {
        'B' => selected
            ? (bg: AppColors.noteBFill, border: AppColors.noteBFill, ink: AppColors.noteBSelectedInk)
            : (bg: AppColors.noteBBg, border: AppColors.noteBBorder, ink: AppColors.noteBInk),
        'PM' => selected
            ? (bg: AppColors.notePmFill, border: AppColors.notePmFill, ink: AppColors.notePmSelectedInk)
            : (bg: AppColors.notePmBg, border: AppColors.notePmBorder, ink: AppColors.notePmInk),
        _ => selected
            ? (bg: AppColors.noteMFill, border: AppColors.noteMFill, ink: AppColors.noteMSelectedInk)
            : (bg: AppColors.noteMBg, border: AppColors.noteMBorder, ink: AppColors.noteMInk),
      };

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
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
      ),
    );
  }
}

/// A observação da nota escolhida, abaixo dos botões (quadro "1b").
class _NoteComment extends StatelessWidget {
  const _NoteComment(this.comment);

  final String comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        border: Border.all(color: AppColors.warningBorder),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.notes, size: 16, color: AppColors.warningInk),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(comment, style: AppTypography.noteComment)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Rodar — a tela passa, a rota ainda não**

Run: `flutter test test/ui/checklist/checklist_screen_test.dart`
Esperado: **10 testes passando**.

Run: `flutter test test/ui/session_detail/session_detail_screen_test.dart`
Esperado: 1 falha, em "o meu participante abre o checklist de verdade" — `Found 0 widgets with type "ChecklistScreen"`: a rota ainda monta a tela provisória.

- [ ] **Step 6: Rota, providers e a tela provisória**

Em `lib/router.dart`:

Substituir (1 de 3):

```dart
import 'ui/auth/login_screen.dart';
import 'ui/debug/ds_gallery_screen.dart';
```

por:

```dart
import 'ui/auth/login_screen.dart';
import 'ui/checklist/checklist_screen.dart';
import 'ui/debug/ds_gallery_screen.dart';
```

Substituir (2 de 3):

```dart

  /// Checklist do participante (Fase 4) — por ora, uma tela provisória.
  static String participantChecklist(String sessionId, String participantId) =>
```

por:

```dart

  /// Checklist do participante (Fase 4).
  static String participantChecklist(String sessionId, String participantId) =>
```

Substituir (3 de 3):

```dart
            path: 'participants/:participantId/checklist',
            builder: (context, state) => EvaluationPlaceholderScreen(
              kind: EvaluationPlaceholderKind.checklist,
              participantName: state.extra as String?,
            ),
```

por:

```dart
            path: 'participants/:participantId/checklist',
            builder: (context, state) => ChecklistScreen(
              sessionId: state.pathParameters['sessionId']!,
              participantId: state.pathParameters['participantId']!,
            ),
```

Em `lib/app_providers.dart`:

Substituir (1 de 6):

```dart
import 'data/repositories/assessment_catalog_repository.dart';
import 'data/repositories/auth_repository.dart';
```

por:

```dart
import 'data/repositories/assessment_catalog_repository.dart';
import 'data/repositories/assessment_repository.dart';
import 'data/repositories/auth_repository.dart';
```

Substituir (2 de 6):

```dart
    required this.catalogRepository,
    required this.connectivityService,
```

por:

```dart
    required this.catalogRepository,
    required this.assessmentRepository,
    required this.connectivityService,
```

Substituir (3 de 6):

```dart
      database: database,
    );

    return AppDependencies._(
```

por:

```dart
      database: database,
    );
    final assessmentRepository = AssessmentRepository(database: database);

    return AppDependencies._(
```

Substituir (4 de 6):

```dart
      catalogRepository: catalogRepository,
      connectivityService: ConnectivityService()..initialize(),
```

por:

```dart
      catalogRepository: catalogRepository,
      assessmentRepository: assessmentRepository,
      connectivityService: ConnectivityService()..initialize(),
```

Substituir (5 de 6):

```dart
  final AssessmentCatalogRepository catalogRepository;
  final ConnectivityService connectivityService;
```

por:

```dart
  final AssessmentCatalogRepository catalogRepository;
  final AssessmentRepository assessmentRepository;
  final ConnectivityService connectivityService;
```

Substituir (6 de 6):

```dart
        Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        ChangeNotifierProvider<ConnectivityService>.value(
```

por:

```dart
        Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        Provider<AssessmentRepository>.value(value: assessmentRepository),
        ChangeNotifierProvider<ConnectivityService>.value(
```

Em `lib/ui/evaluation/evaluation_placeholder_screen.dart`:

Substituir (1 de 2):

```dart
/// Qual tela a provisória está ocupando.
enum EvaluationPlaceholderKind { checklist, result }

/// Tela provisória atrás das rotas definitivas do participante. A Fase 4
/// troca a do checklist e a Fase 5 a do resultado — e aí este arquivo sai.
class EvaluationPlaceholderScreen extends StatelessWidget {
```

por:

```dart
/// Qual tela a provisória está ocupando.
enum EvaluationPlaceholderKind { result }

/// Tela provisória atrás da rota de resultado do participante. A Fase 4 já
/// trocou a do checklist (`ChecklistScreen`); a Fase 5 troca esta, e aí este
/// arquivo sai.
class EvaluationPlaceholderScreen extends StatelessWidget {
```

Substituir (2 de 2):

```dart
    final (title, message) = switch (kind) {
      EvaluationPlaceholderKind.checklist => (
          'Avaliação',
          'O checklist de avaliação chega na próxima versão do app.',
        ),
      EvaluationPlaceholderKind.result => (
```

por:

```dart
    final (title, message) = switch (kind) {
      EvaluationPlaceholderKind.result => (
```

- [ ] **Step 7: Rodar tudo**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` e **275 testes passando**.

- [ ] **Step 8: Commit**

```bash
git add lib/ui/checklist/checklist_screen.dart lib/router.dart lib/app_providers.dart lib/ui/evaluation/evaluation_placeholder_screen.dart test/ui/checklist/checklist_screen_test.dart test/ui/session_detail/session_detail_screen_test.dart
git commit -m "feat(mobile): tela de checklist de avaliacao offline"
```

---

## Correções da revisão final

Executadas depois das Tasks 1–6, numa rodada só de correção (código pré-validado numa cópia do app e reencenado sobre o HEAD, 275 → 284 → 287 testes):

1. **Abertura sem rede com o último perfil salvo** (decisão 7) — `AuthUser.toJson`/`fromJson`; `TokenStorage` com a chave `auth.user` (apagada em `clear()`); `AuthSession.saveUser` (só com "manter conectado") e `readSavedUser` (nunca lança); `AuthRepository.restoreSession` entra com o perfil salvo quando o `/auth/me` falha por rede. Commit `fix(mobile): abre o app sem rede com o ultimo perfil salvo`.
2. **Rolagem até a categoria aberta** (decisão 8), mais: um teste que prova que o cronômetro avisa a tela a cada tick (o `elapsedLabel` é calculado na leitura); `hasCatalog` passa a olhar as seções (catálogo só com itens sem id conta como sem catálogo); o nome do participante com a altura de linha do canvas (`AppTypography.checklistParticipantName`, 16/1.25). Commit `fix(mobile): rola ate a categoria aberta e fecha lacunas do checklist`.
3. **Comentários desatualizados** — o das faixas de score estava sobre `categoryChipBg`; o detalhe da sessão ainda chamava o checklist de provisório e passava um `extra` que ele não lê mais; o `SyncStatusIndicator` ainda prometia o badge na Fase 4. Commit `chore(mobile): atualiza comentarios e tira o extra do checklist`.

---

## Task 7: Validação no aparelho físico

Esta task é o portão da fase: sem ela, a Fase 5 não é planejada (decisão do usuário, registrada em 17/09/2026). É o roteiro que só o usuário pode rodar.

**Files:** nenhum arquivo de código.

**Interfaces:**
- Consumes: o app inteiro, montado pelas Tasks 1–6 e pelas correções da revisão final.
- Produces: o aval do usuário para planejar a Fase 5.

- [ ] **Step 1: Subir o backend e liberar a porta para o aparelho**

Run: `cd apps/backend && npm run start:dev`

Em outro terminal, com o aparelho conectado: `adb reverse tcp:3001 tcp:3001`

- [ ] **Step 2: Instalar no aparelho**

Descubra o id com `flutter devices` e rode, em `apps/mobile/simtc`:

Run: `flutter run -d <ID_DO_APARELHO>`

Sem `--dart-define` — o padrão já aponta para o backend local. Esta fase não muda o esquema do banco: instale por cima, sem desinstalar.

- [ ] **Step 3: Percorrer o roteiro de aceite**

Preparação: com rede, abra na Home uma sessão "Em andamento" e atribua a você pelo menos dois participantes ("Atribuir a mim").

Checklist:
- [ ] tocar em "Avaliando · você" abre o checklist de verdade (não mais a tela provisória), com o nome do participante, o cronômetro contando e "salvo";
- [ ] a primeira categoria já vem aberta; as outras aparecem fechadas, com "N itens"; tocar numa fechada abre ela e fecha a anterior; tocar na aberta fecha;
- [ ] com a primeira categoria aberta, role até a próxima (fechada, logo abaixo) e toque nela: a lista vai até o cabeçalho da recém-aberta — ela começa na primeira infração, sem deixar o consultor no meio;
- [ ] o número de cada infração é o item da ficha — confira com o catálogo no painel web;
- [ ] tocar em B, PM ou M marca (o botão fica cheio); tocar em outro troca; tocar no mesmo desmarca;
- [ ] com uma nota escolhida, aparece embaixo a observação dela (para as notas que o admin cadastrou com observação);
- [ ] o selo da categoria e o % geral mudam na hora — por exemplo, numa categoria com 6 infrações, uma PM e uma B dão 86,7%;
- [ ] "X de Y categorias revisadas" conta as categorias com pelo menos uma marcação.

Offline (o critério da fase) — **corte a rede de verdade**: via USB, o modo avião não derruba o `adb reverse`, e o app continuaria alcançando o backend do PC (README, "Testes offline"). Ative o modo avião, confira que o Wi-Fi também desligou e rode `adb -s <ID_DO_APARELHO> reverse --remove tcp:3001`. Deixe "Manter conectado" como estava no login (marcado — é o padrão).
- [ ] abra o checklist do segundo participante e marque B/PM/M em várias categorias — aparece a faixa "Sem conexão — as marcações continuam sendo salvas no aparelho." e tudo funciona;
- [ ] ainda sem rede, feche o app à força (recentes → deslizar) e abra de novo: ele vai **direto para a Home**, sem pedir login, com a agenda em cache e o aviso de sem conexão;
- [ ] volte ao mesmo participante: o rascunho reaparece exatamente como estava, e o cronômetro continua contando desde o início (não zera);
- [ ] para voltar a ficar online, recrie o redirecionamento (`adb -s <ID_DO_APARELHO> reverse tcp:3001 tcp:3001`) e desligue o modo avião: a Home volta a atualizar sozinha.

Finalizar:
- [ ] com alguma categoria sem marcação, "Finalizar avaliação" pergunta ("N categorias estão sem nenhuma infração marcada…"); "Cancelar" fica na tela; "Finalizar" volta para o detalhe da sessão;
- [ ] com todas as categorias marcadas, finaliza direto, sem pergunta;
- [ ] depois de finalizar, o participante continua "Avaliando · você" no detalhe (o envio é da Fase 5), e tocar nele reabre o mesmo checklist, com as marcações.

Regressões:
- [ ] "Atribuir a mim" continua com o mesmo tamanho de antes (48dp, texto menor que o do "Finalizar avaliação");
- [ ] um participante concluído continua abrindo a tela provisória "Resultado".

**Não verificável neste aparelho, e por quê:** "sem catálogo no aparelho, aviso e sem 'Finalizar'" depende de o catálogo nunca ter descido, o que não acontece num aparelho que já abriu a Home com rede. Fica coberto pelos testes das Tasks 5 e 6.

**Observação para o campo:** com a regra da decisão 2 (revisada = pelo menos uma infração marcada), um participante que não cometeu nenhuma infração aparece como "0 de N categorias revisadas", com a barra vazia, e o "Finalizar avaliação" sempre pergunta. É a regra aprovada funcionando; se isso atrapalhar no campo, é para rever junto com a Fase 5.

- [x] **Step 4: Registrar o resultado**

Se tudo passar, avisar o usuário e pedir o aval para planejar a Fase 5. Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio ou de contrato do backend, parar e perguntar.

**Validado em 29/09/2026, no aparelho físico, pelo usuário — roteiro completo, incluindo a entrada offline depois de fechar o app à força e a rolagem até a categoria aberta (correções da revisão final).**

---

## Pendências levadas para as fases seguintes

| Fase | Pendência |
|---|---|
| 5 | Cronômetro na linha "Avaliando · você" do detalhe da sessão (vem do `startTime` do rascunho) — decisão de 27/09/2026. |
| 5 | `SyncStatusIndicator` ganha o badge com a contagem da fila local (`pendingSync`), um lugar só para a Home e o detalhe — decisão de 27/09/2026. |
| 5 | O "Finalizar avaliação" desta fase grava `pendingSync` direto (decisão 1). A Fase 5 põe a tela 1.6 (Resumo) no meio, com o "Confirmar" que de fato fecha a avaliação. |
| 5 | Marcações órfãs (nota ou infração removida do catálogo depois da marcação) ficam no banco: o envio precisa ignorá-las, senão o backend recebe um `infractionNoteId` que não existe mais. |
| 5 | Reabrir um participante já finalizado reabre o checklist (o status no servidor só muda com o envio). Decidir, com o Resumo/Resultado da Fase 5, o que esse toque deve abrir. |
| 5 | O cronômetro e a duração enviada (`endTime − startTime`) contam desde a criação do rascunho, inclusive o tempo com o app fechado. Confirmar com o usuário se é isso que o painel deve mostrar. |
| 5 | Estados de erro do checklist: uma falha de escrita local (disco cheio, por exemplo) em `init`, `toggleNote` ou `finish` não mostra mensagem — o `init` ficaria no skeleton para sempre, e o `finish` só não voltaria para o detalhe. Nada se perde. |
| 5 | Reavaliação: `openDraft` retoma a linha do participante em qualquer status, inclusive `synced`. O "Reavaliar" precisa começar um rascunho novo — senão reabre as marcações e o `startTime` da avaliação anterior. |
| 5 | Rascunhos não são separados por consultor (a chave é só o `trainingParticipantId`) e sobrevivem ao logout: num aparelho compartilhado, se o participante mudar de consultor, o novo herdaria o rascunho do anterior. |
| 5 | Formato do `date` (data de calendário, meia-noite local) no payload do `POST /practical-assessments/sync`. |
| 5 | Sessão aberta sem rede usa o perfil guardado (decisão 7): nome, papel ou consultor alterados no painel só aparecem na próxima abertura com rede. |
| 5 — **prioridade** | `api_client.dart` trata **qualquer** falha da renovação do token (timeout, conexão caída) como sessão expirada e leva ao Login, que exige rede. Com a entrada offline (decisão 7), "voltar com sinal fraco e token vencido" fica comum no campo: o consultor seria deslogado até ter sinal bom (os rascunhos sobrevivem). Direção: expirar só com 401/403 do `/auth/refresh`; erro de rede mantém a sessão e falha só a chamada. O envio da Fase 5 vai passar por esse caminho o tempo todo. |
| 5 | Endurecer a entrada offline: exigir que o `id` do perfil salvo seja o `sub` do JWT (ou apagar `auth.user` em `AuthSession.start()`). Numa sequência muito improvável — abertura anterior falhou sem 401, outro usuário entra e uma escrita falha entre `start()` e `saveUser` — os tokens de um usuário ficariam com o perfil de outro. |
| 5 | A abertura com rede grava o perfil (`saveUser`) sem tratar erro do armazenamento: uma falha rara da keystore ali manda para o login naquela abertura. Tornar a gravação do perfil tolerante a falha. |
| 5 | Uma falha `DioExceptionType.unknown` sem resposta conta como erro de rede, então também leva à entrada offline — mesmo estado "não conferido até a próxima chamada" do risco aceito na decisão 7. |
| 8 | O toque no cabeçalho da categoria aberta e nos botões B/PM/M não mostra ripple (mesma causa da pendência da Fase 3: `Container` com cor por cima do `InkWell`). As linhas fechadas mostram, porque não têm fundo próprio. |
| 8 | O "salvo" do cabeçalho é estático — não reflete uma escrita que falhou (os botões, sim: só mostram o que foi gravado). |
| 8 | A tela inteira reconstrói a cada tick do cronômetro, e `buildChecklistSections` roda algumas vezes por build — barato no tamanho real do catálogo. Se crescer: isolar o rótulo do cronômetro num widget e guardar as seções na VM. |
| 8 | Botões B/PM/M sem `Semantics(selected: …)` para leitores de tela; "0 de 1 categorias revisadas" no plural (só aparece com catálogo de uma categoria); uma nota fora de B/PM/M iria para a frente da ordem e ganharia as cores do M (o backend só tem B/PM/M). |
| 8 | O aviso de hit-test do `tap()` em `test/ui/sessions/sessions_screen_test.dart` (Fase 3) aparece na suíte inteira. |
| 8 | Com rede "conectada mas sem dados", a entrada offline só acontece depois do timeout do `ApiClient` (15 s de conexão / 20 s de resposta), com a splash na tela o tempo todo. Considerar um timeout menor só para a checagem da abertura. |
| — | Testes que ficaram de fora, de baixo risco: sessão em cache com `date` nulo no `openDraft`; `unmark` numa infração nunca marcada; bordas exatas do selo (70 e 84,9); ausência da faixa offline nos testes com rede; o teste da rolagem compara com as bordas da tela (0 e 915), não com a área da lista — uma regressão parcial, com o cabeçalho escondido atrás do cabeçalho fixo, passaria. |
| — | Canvas: a spec `4z` diz padding 14/16 na linha da infração, e o quadro `1b` (mais recente) usa 15/20. Atualizar a spec no Claude Design. |
| — | As pendências da Fase 3 que não eram da Fase 4 continuam valendo — ver o fim do plano da Fase 3. |
