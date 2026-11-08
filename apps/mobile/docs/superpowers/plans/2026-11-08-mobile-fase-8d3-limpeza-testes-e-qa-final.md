# App Mobile SIMTC — Fase 8D-3: Limpeza, testes e QA final — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fechar a Fase 8: as repetições anotadas pelas revisões viram peças e constantes únicas, os testes que faltam em repositórios, rótulos e utilitários entram, a saída da suíte fica limpa, e o usuário faz o QA final do app nos dois perfis, no celular e no tablet.

**Architecture:** Só o app muda, sem backend, sem mudança no banco do aparelho (drift segue na versão 5) e sem dependência nova. A limpeza **não muda comportamento**: onde mexe em código que já tem teste, os testes que já existem são a rede; onde o código não tem teste (os repositórios), os testes entram **antes** da troca e passam antes e depois dela. Peças novas do Design System (`AppSpinner`, `AppFooterBar`, `showConfirmDialog`, `showTransientMessage`) nascem com teste próprio.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · dio · drift 2.31.0 · mocktail (testes). Nenhuma dependência nova.

**Spec:** `apps/mobile/docs/superpowers/specs/2026-10-24-mobile-fase-8-design.md`, seção "Desenho da 8D" → "8D-3 — Limpeza, testes e QA final", aprovada em 27/10/2026; e as "Observações levadas para a 8D-3" no fim do plano da 8D-2 (`2026-10-30-mobile-fase-8d2-defeitos-de-borda.md`). O usuário pediu este plano em 08/11/2026 ("comece o plano da 8D-3").

**Sem "Validação prévia":** por decisão do usuário (30/10/2026), o código não é escrito antes da execução. Cada item abaixo foi só **conferido no código de hoje** (leitura), e o QA por agente testa o que for implementado.

## Decisões e conferências (revisar junto com o plano)

O inventário do desenho tinha cerca de 60 itens. Conferidos contra o código de hoje (HEAD = `b67d9c3`, 1234 testes passando, `flutter analyze` limpo), o que muda de escopo:

**Já resolvido, nada a fazer:**
- **Ruído do drift e "toque fora do alvo" na saída da suíte:** não aparecem mais. A saída de hoje tem só duas fontes: `Catálogo não atualizado (sem rede)…` (22 linhas) e os `debugPrint` do `AssessmentSyncService` (8 linhas). A Task 1 cuida delas.
- **Perfil e ViewModels da 1.11 e da 1.12:** já têm arquivo de teste próprio (`profile_*_test.dart`, `add_participant_viewmodel_test.dart`, `session_edit_viewmodel_test.dart`), e os casos que as revisões anotaram (404, cancelar e salvar que não correm juntos, consulta que lança, resposta depois do fechar) já estão lá. Não entram.
- **Descarte que falha na aba Sincronizar:** já tem teste (`o descarte deu erro: o mesmo aviso…`).

**Escolhas minhas (o usuário confere na leitura):**
1. **Os testes de diretriz em mais de um estado por tela ficam de fora.** A 8C pôs `expectAccessibleTargets` em cada tela, e estados novos seriam palpite; o QA final no aparelho cobre o resto. *Reabrir se o usuário quiser.*
2. **Os ternários do tablet:** são ~60 em 10 arquivos, e trocar todos é risco alto por pouco ganho. Entram só os dois que as revisões apontaram: `SessionContextHeader` (`spacious`) e `_ProfileRow`.
3. **As duas regras de "mantém a mensagem do servidor" do `SessionRepository` continuam duas:** o `start` mostra a mensagem só em 403 e sem rede (um 404 vira "Não foi possível iniciar…"); o `update` e o `cancel` mostram também no 404. Unificar mudaria o texto que o consultor vê, e isso é decisão do usuário. O esqueleto novo recebe a regra como parâmetro. *Se o usuário quiser unificar, é uma linha na Task 5.*
4. **`lockedReason` durante o carregamento (1.11 e 1.12):** não muda; só ganha um comentário dizendo por que não tem efeito (Task 7).
5. **"Última sincronização" depois de reabrir o app:** não muda. Guardar o horário no banco pediria migração nos aparelhos de campo por causa de um rótulo (já decidido na 8D-2).
6. **O rodapé do Perfil e o da janela de admin não viram `AppFooterBar`:** o do Perfil tem borda de 1,5 e não tem recuo (comentário no código explica), e o da janela de admin é outra peça.
7. **Pendências do backend** (o envio grava o participante sem condição; atribuir e cancelar ao mesmo tempo; iniciar sessão já iniciada não recarrega no web): fora deste plano, só entram com o aval do usuário.

**Fora do plano, já feito:** o toque na aba Sincronizar que abre o participante no treinamento (commit `b67d9c3`) não estava no desenho. Entra no roteiro do QA final (Task 8).

## Review Focus

Casos que o consultor ou o admin vai encontrar, e onde cada um fica preso num teste:

1. **Troca dos diálogos de confirmação:** um "Cancelar", um toque fora do diálogo ou o botão "Voltar" nunca confirmam uma ação destrutiva (descartar avaliação, desatribuir, cancelar sessão). Preso em: `cancelar, tocar fora e o voltar devolvem falso` (Task 4).
2. **Aviso passageiro com a tela já fechada:** a mensagem que chega depois de a tela sair não derruba o app. Preso em: `não mostra nada se a tela saiu antes do quadro` (Task 4).
3. **Tamanho do cache no Perfil perto dos limites:** 1 047 553 bytes aparecia como "1024 KB", e não "1,0 MB". Preso em: `sizeLabel troca de unidade nos limites` (Task 6).
4. **Hora de uma avaliação confirmada às 23:59 e vista às 00:01:** o rótulo diz "hoje 23:59". Preso em: `à meia-noite, o dia anterior não é "hoje"` e `na virada do ano, o ano aparece` (Task 6).
5. **Dois toques rápidos abrem duas telas:** `claimOpen` não tinha teste direto. Preso em: `o segundo pedido no mesmo quadro é recusado` (Task 6).
6. **O esqueleto novo do `SessionRepository` troca a mensagem de falha:** a regra do `start` e a do `update`/`cancel` continuam diferentes. Preso em: `start: 404 vira a mensagem genérica` e `cancel: 404 devolve a mensagem do servidor` (Task 5).

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app`. Sem git worktree. Não criar branch, não fazer merge, não fazer push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada, com a mensagem exata dada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`/`git commit -a`. O working tree pode ter trabalho do usuário fora desta fase (hoje: `apps/backend/src/email/email.service.ts` e quatro arquivos de `apps/web`, modificados e não commitados): **não é desta fase e fica exatamente como está**.
- **Proibido `git restore`, `git checkout -- <arquivo>`, `git stash`, `git reset` e `git clean`.** Se o `git status` mostrar algo que não é da task, ignorar e seguir.
- **Na execução por subagentes:** antes do primeiro despacho, guardar a linha de base (o `git status --porcelain` inteiro) e compará-la, sem filtrar nada, depois de **cada** subagente. Todo despacho repete as duas regras acima. Implementadores em **haiku**; revisões em **sonnet**; revisão final em **opus**.
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-11-08-mobile-fase-8d3-limpeza-testes-e-qa-final/`.

**Mobile (valem para todas as fases)**
- Flutter 3.41.6 / Dart 3.11.4 (o `pubspec.yaml` aceita a partir do 3.4: nada de sintaxe mais nova). App **só Android**. O tablet é validado em emulador; o celular, no aparelho físico.
- MVVM + Repository; tela nunca chama `Dio`/Drift direto. Composição "quebra-cabeça": `Widget _buildX()` num `build()` enxuto.
- Design System: nenhum `Color(0xFF…)`, número mágico de espaçamento ou `TextStyle` literal fora de `lib/ui/core/theme/`; nunca trocar `fontSize` num `.copyWith()` fora do tema. Aritmética sobre tokens e constantes com nome na classe que as usa são aceitas.
- Alvos de toque mínimos de 48dp (`AppSpacing.touchTarget`). TDD: teste falhando pelo motivo certo → implementação → teste passando.
- **Sem `dart format`** e **sem `npm run lint`**. Comentários em português, no tom do código em volta.
- Todos os caminhos de código são relativos a `apps/mobile/simtc/`, e os comandos `flutter` rodam a partir dessa pasta. `git add`/`git commit` rodam **da raiz do repositório**, com os caminhos completos.

## Mapa de Arquivos

### Novos (em `lib/`, com o teste ao lado em `test/`)

| Arquivo | Task | Responsabilidade |
|---|---|---|
| `test/flutter_test_config.dart` | 1 | silencia o `debugPrint` em todos os testes |
| `ui/core/theme/note_colors.dart` | 2 | cores de B/PM/M, num lugar só |
| `ui/core/widgets/app_spinner.dart` | 3 | o indicador de carregamento pequeno |
| `ui/core/widgets/app_footer_bar.dart` | 3 | o rodapé com borda em cima |
| `ui/core/widgets/confirm_dialog.dart` | 4 | o diálogo de confirmação (cancelar / confirmar) |
| `ui/core/transient_message.dart` | 4 | o aviso passageiro (SnackBar no quadro seguinte) |
| `test/ui/core/open_once_test.dart`, `test/data/services/logo_cache_test.dart` | 6 | testes que faltavam |

### Modificados

| Arquivo | Task | O que muda |
|---|---|---|
| `ui/core/date_labels.dart`, `ui/sessions/session_filter.dart` | 2 | `shortMonths` público |
| `ui/core/theme/app_spacing.dart` e 5 arquivos que usam `AppRadius.sm + 2` | 2 | `AppRadius.sm2` |
| `data/models/session_participant.dart`, `participant_filter.dart`, `checklist_viewmodel.dart`, `session_consultants_viewmodel.dart` | 2 | `SessionParticipant.isWith` |
| `ui/checklist/checklist_screen.dart`, `ui/result/result_screen.dart` | 2, 3, 4 | cores, rodapé, diálogos, aviso |
| telas que têm spinner, rodapé, diálogo ou aviso repetidos | 3, 4 | usam as peças novas |
| `data/repositories/session_repository.dart` | 5 | esqueleto de `start`/`update`/`cancel` |
| `data/services/device_data_service.dart` | 6 | `LogoCache` recebe a pasta temporária |
| `ui/profile/profile_labels.dart`, `profile_screen.dart`, `ui/core/widgets/session_context_header.dart`, `README.md` | 6, 7 | `sizeLabel`, ternários, comentários, README |

---

## Task 1: A saída da suíte fica limpa

**Files:**
- Create: `test/flutter_test_config.dart`

**Interfaces:**
- Consumes: nada.
- Produces: nenhum teste imprime mais pelo `debugPrint`. Nenhum teste de hoje lê o `debugPrint` (conferido), então nada quebra.

- [ ] **Step 1: Medir a linha de base**

Run: `flutter test -r expanded 2>&1 | grep -c "Catálogo não atualizado\|recusada:\|Leitura da fila\|dar dono"`
Expected: um número maior que zero (hoje, 30).

- [ ] **Step 2: Criar `test/flutter_test_config.dart`**

O arquivo é o ponto de entrada que o `flutter test` roda antes de cada arquivo de teste:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

/// Os logs do app (`debugPrint`) não têm leitor nos testes: só sujavam a saída
/// da suíte (Fase 8D-3).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  debugPrint = (String? message, {int? wrapWidth}) {};
  await testMain();
}
```

- [ ] **Step 3: Rodar e ver zerar**

Run: o mesmo comando do Step 1.
Expected: `0`. E `flutter test` inteiro: `All tests passed!` com 1234 testes.

- [ ] **Step 4: Commit**

```bash
git add apps/mobile/simtc/test/flutter_test_config.dart
git commit -m "test(mobile): saida da suite sem os logs do catalogo e do envio"
```

---

## Task 2: Constantes e regras num lugar só

**Files:**
- Modify: `lib/ui/core/date_labels.dart`, `lib/ui/sessions/session_filter.dart`
- Modify: `lib/ui/core/theme/app_spacing.dart`; trocar `AppRadius.sm + 2` em `lib/ui/core/widgets/app_buttons.dart` (3 lugares), `lib/ui/core/widgets/company_logo.dart` e `lib/ui/sync/sync_screen.dart` (2 lugares)
- Create: `lib/ui/core/theme/note_colors.dart`; modify `lib/ui/checklist/checklist_screen.dart` (`_NoteButton._colors`), `lib/ui/result/result_screen.dart` (`_NoteBadge._fill`)
- Modify: `lib/data/models/session_participant.dart`, `lib/ui/session_detail/participant_filter.dart`, `lib/ui/checklist/checklist_viewmodel.dart` (`canUnassign`), `lib/ui/session_consultants/session_consultants_viewmodel.dart` (a lista `inProgress`)
- Test: `test/ui/core/date_labels_test.dart`, `test/ui/core/theme/note_colors_test.dart` (novo), `test/data/models/session_participant_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `const List<String> shortMonths` em `date_labels.dart` (12 siglas, `'jan'` a `'dez'`); a lista privada `_meses` de `date_labels.dart` e a de `session_filter.dart` somem.
  - `AppRadius.sm2 = 10` (documentado: "o canto de 10 dos botões compactos e do logo de contexto").
  - `Color noteFillColor(String noteType)` e `({Color bg, Color border, Color ink}) noteButtonColors(String noteType, {required bool selected})` em `note_colors.dart`. `'B'` e `'PM'` são as notas; **qualquer outro valor é "M"** (como os `switch` de hoje).
  - `bool SessionParticipant.isWith(String? consultantId)`: verdadeiro quando `status == ParticipantStatus.emAvaliacao`, `consultantId != null` e `assignedConsultantId == consultantId`.

- [ ] **Step 1: Escrever os testes novos (falham: nada existe ainda)**

`note_colors_test.dart`: `noteFillColor` devolve `AppColors.noteBFill`, `notePmFill` e `noteMFill` para `'B'`, `'PM'` e `'M'`, e o `noteMFill` também para um valor desconhecido (`'X'`). `noteButtonColors('PM', selected: false)` é `(bg: AppColors.notePmBg, border: AppColors.notePmBorder, ink: AppColors.notePmInk)`, e com `selected: true` é `(bg: notePmFill, border: notePmFill, ink: notePmSelectedInk)`; o mesmo vale para B e M.

`date_labels_test.dart`: `shortMonths` tem 12 itens, o primeiro é `'jan'` e o último `'dez'`.

`session_participant_test.dart`: `isWith` é verdadeiro para `emAvaliacao` com o mesmo consultor; falso para outro consultor, para consultor `null`, e para `pendente` ou `aprovado` mesmo com o consultor igual.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core test/data/models/session_participant_test.dart`
Expected: não compilam (`shortMonths`, `noteFillColor`, `isWith` indefinidos).

- [ ] **Step 3: Implementar**

- `shortMonths` pública em `date_labels.dart` (com o comentário que a lista privada já tem); `session_filter.dart` importa `../core/date_labels.dart` e usa `shortMonths`.
- `AppRadius.sm2` em `app_spacing.dart`; trocar os 6 `AppRadius.sm + 2` por ele.
- `note_colors.dart` com as duas funções, tendo os mesmos 3 `switch` que hoje estão no checklist e no Resultado; as duas telas passam a chamá-las, e os `switch` sobem para o arquivo novo.
- `isWith` em `SessionParticipant`, e usar nos três lugares (`situationOf` no `participant_filter.dart`, `canUnassign` do checklist, `inProgress` de Consultores). O `isWithMe` do checklist e o `assessedByConsultantId` do `participant_filter.dart` são **outras regras: não mexer**.

- [ ] **Step 4: Rodar tudo e ver passar**

Run: `flutter analyze` e `flutter test`
Expected: sem issues, `All tests passed!` (1234 + os novos).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/simtc/lib apps/mobile/simtc/test/ui/core apps/mobile/simtc/test/data/models/session_participant_test.dart
git commit -m "refactor(mobile): meses, canto de 10, cores das notas e isWith num lugar so"
```

(`git add` de `lib` e `test/ui/core` aqui é o caminho explícito e inclui só o que esta task mexeu; conferir o `git status` antes: nada de fora da task pode entrar.)

---

## Task 3: Peças do Design System: o spinner e o rodapé

**Files:**
- Create: `lib/ui/core/widgets/app_spinner.dart`, `lib/ui/core/widgets/app_footer_bar.dart`
- Modify (spinner): `lib/ui/add_participant/add_participant_screen.dart` (`_buildCpfTrailing`), `lib/ui/checklist/checklist_screen.dart` (o "Desatribuindo…"), `lib/ui/profile/profile_screen.dart` (o do `_ProfileRow`), `lib/ui/session_detail/session_detail_screen.dart` (o "Desatribuindo…"), `lib/ui/core/widgets/app_buttons.dart` (os 4 spinners dos botões)
- Modify (rodapé): `lib/ui/add_participant/add_participant_screen.dart`, `lib/ui/session_edit/session_edit_screen.dart`, `lib/ui/summary/summary_screen.dart`, `lib/ui/result/result_screen.dart`, `lib/ui/checklist/checklist_screen.dart` (cada `_buildFooter`)
- Test: `test/ui/core/widgets/app_spinner_test.dart`, `test/ui/core/widgets/app_footer_bar_test.dart` (novos)

**Interfaces:**
- Consumes: nada.
- Produces:
  - `AppSpinner({super.key, double size = 20, double strokeWidth = 2.5, Color? color})`: um `SizedBox.square(dimension: size)` com um `CircularProgressIndicator(strokeWidth: strokeWidth)`; com `color`, o `valueColor` é `AlwaysStoppedAnimation(color)`, e sem ele fica o padrão do tema.
  - `AppFooterBar({super.key, required Widget child, EdgeInsetsGeometry padding = <12 em cima, 16 nos lados e embaixo>, Color color = AppColors.surface})`: um `Container` com `color`, borda **só em cima** de 1 em `AppColors.border` e o `padding`. O padrão é `EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg)`.

- [ ] **Step 1: Escrever os testes (falham: as peças não existem)**

`app_spinner_test.dart`: sem argumentos, o `SizedBox` tem 20×20 e o indicador tem `strokeWidth` 2,5 e `valueColor` nulo; com `size: 22, strokeWidth: 2, color: AppColors.surface`, as três medidas passam adiante (o `valueColor.value` é `AppColors.surface`).

`app_footer_bar_test.dart`: o `Container` filho tem fundo `AppColors.surface`, borda `Border(top: BorderSide(color: AppColors.border))` e o recuo padrão; com `padding` e `color` próprios, eles passam adiante; o `child` aparece.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/widgets/app_spinner_test.dart test/ui/core/widgets/app_footer_bar_test.dart`
Expected: não compilam.

- [ ] **Step 3: Implementar as duas peças** com as assinaturas acima, e trocar os usos:

- **Spinner:** os 8 `CircularProgressIndicator(` viram `AppSpinner(`, **com os mesmos números de hoje** (tamanho, espessura e cor de cada um; os dos botões têm 22, 2,5 e `AppColors.surface` em `app_buttons.dart:53`, e os outros três: ler o valor de cada um e repassá-lo). Os "Desatribuindo…" (checklist e detalhe) usam o padrão, com `color: AppColors.text3`; o da consulta de CPF é `size: AppSpacing.lg + 2, strokeWidth: 2, color: AppColors.primary`; o do Perfil é `size: _spinnerSize, strokeWidth: 2`, sem cor. Fim: `grep -rn "CircularProgressIndicator(" lib` só acha `app_spinner.dart`.
- **Rodapé:** cada `_buildFooter` listado passa a devolver `AppFooterBar(...)`. O de Adicionar participante e o de Dados do treinamento usam o recuo padrão; o do Resumo e o do Resultado passam o recuo do tablet que já têm (`symmetric(horizontal: xxxl / xxl, vertical: lg)`) quando `tablet`; o do checklist passa a cor (`background` no início do tablet) e o recuo que já tem. O comentário "os mesmos dos rodapés irmãos" nos dois primeiros some. O rodapé do Perfil e o da janela de admin **ficam como estão** (ver "Decisões", 6).

- [ ] **Step 4: Rodar tudo e ver passar**

Run: `flutter analyze` e `flutter test`
Expected: sem issues, `All tests passed!`. Os testes de medida que já existem dos rodapés e dos spinners (altura, recuo, "Desatribuindo…") continuam passando sem edição: se algum falhar, o `AppSpinner` ou o `AppFooterBar` mudou uma medida — corrigir a peça, e não o teste.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/simtc/lib apps/mobile/simtc/test/ui/core/widgets
git commit -m "refactor(mobile): spinner e rodape com borda viram pecas do design system"
```

---

## Task 4: Peças do Design System: o diálogo de confirmação e o aviso passageiro

**Files:**
- Create: `lib/ui/core/widgets/confirm_dialog.dart`, `lib/ui/core/transient_message.dart`
- Modify (diálogo): `lib/ui/sync/sync_screen.dart` (`_confirmDiscard`), `lib/ui/checklist/checklist_screen.dart` (os dois `AlertDialog`), `lib/ui/session_detail/session_detail_screen.dart` (`_confirmStart` e `_confirmUnassign`), `lib/ui/session_edit/session_edit_screen.dart` (os três), `lib/ui/add_participant/add_participant_screen.dart`, `lib/ui/profile/profile_screen.dart` (os dois), `lib/ui/session_consultants/session_consultants_screen.dart`
- Modify (aviso): `lib/ui/sessions/sessions_screen.dart` (`_showErrorWhenItArrives`), `lib/ui/session_detail/session_detail_screen.dart`, `lib/ui/session_consultants/session_consultants_screen.dart`, `lib/ui/checklist/checklist_screen.dart` (cada `_showMessageWhenItArrives`)
- Test: `test/ui/core/widgets/confirm_dialog_test.dart`, `test/ui/core/transient_message_test.dart` (novos)

**Interfaces:**
- Consumes: nada.
- Produces:
  - `Future<bool> showConfirmDialog(BuildContext context, {required String title, required String message, required String confirmLabel, String cancelLabel = 'Cancelar', bool destructive = true})`: um `AlertDialog` com `Text(title)`, `Text(message)` e dois botões, um `TextButton` com `cancelLabel` e um `FilledButton` com `confirmLabel`. `destructive` pinta o `FilledButton` de `AppColors.dangerInk`. Devolve `true` só se o confirmar foi tocado: cancelar, tocar fora do diálogo e o voltar do sistema devolvem `false`.
  - `void showTransientMessage(State state, String message)`: agenda, para o quadro seguinte, um `SnackBar(content: Text(message))` no `ScaffoldMessenger` do `state.context`, e não faz nada se o `state` já saiu da tela (`!state.mounted`).

- [ ] **Step 1: Escrever os testes (falham: as peças não existem)**

`confirm_dialog_test.dart` (um botão abre o diálogo e guarda o resultado):
- `mostra o título, a mensagem e os dois botões com os rótulos dados`.
- `confirmar devolve verdadeiro`.
- `cancelar, tocar fora e o voltar devolvem falso` (os três, um depois do outro; este é o item 1 do Review Focus).
- `destructive pinta o confirmar de dangerInk; sem ele, fica o estilo padrão` (ler o `style` do `FilledButton`).
- `cancelLabel troca o texto do cancelar` (`'Voltar'`).

`transient_message_test.dart` (um `StatefulWidget` de teste dentro de um `Scaffold`):
- `mostra o aviso no quadro seguinte` (`find.text(message)` aparece depois de um `pump`, não antes).
- `não mostra nada se a tela saiu antes do quadro` (chamar e tirar o widget da árvore antes do `pump`; sem exceção e sem `SnackBar`; Review Focus 2).

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/widgets/confirm_dialog_test.dart test/ui/core/transient_message_test.dart`
Expected: não compilam.

- [ ] **Step 3: Implementar as duas peças** com as assinaturas acima, e trocar os usos:

- **Diálogo:** troca só o `AlertDialog` que tem `title` em `Text`, `content` em `Text` e as `actions` `[TextButton(pop false), FilledButton(pop true)]`. Os confirmar de destruir (Descartar, Desatribuir, Cancelar sessão, Sair, Limpar cache) são `destructive: true`; "Iniciar a sessão" é `destructive: false`; o "Voltar" do detalhe passa `cancelLabel: 'Voltar'`. O diálogo que tem conteúdo próprio (vários parágrafos, `RichText`, outro botão) **fica como está**. O resultado deixa de ser `bool?`: `if (confirmed != true …)` vira `if (!confirmed …)`.
- **Aviso:** os quatro métodos ficam como `message == null → return`, `clear…()`, e então `showTransientMessage(this, message)`. O comentário "limpar antes de agendar evita reentrância" sobe para a peça nova.

- [ ] **Step 4: Rodar tudo e ver passar**

Run: `flutter analyze` e `flutter test`
Expected: sem issues, `All tests passed!`. Os testes das telas que tocam "Descartar", "Desatribuir", "Cancelar sessão" etc. continuam passando sem edição, porque os rótulos e os tipos dos botões (`TextButton`, `FilledButton`) são os mesmos.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/simtc/lib apps/mobile/simtc/test/ui/core
git commit -m "refactor(mobile): dialogo de confirmacao e aviso passageiro viram pecas do design system"
```

---

## Task 5: Bordas dos repositórios e o esqueleto do `SessionRepository`

**Files:**
- Test: `test/data/repositories/session_repository_test.dart`, `test/data/repositories/participant_repository_test.dart`
- Modify: `lib/data/repositories/session_repository.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `Future<Result<void>> _run({required Future<void> Function() request, required String failureMessage, required bool Function(ApiException error) keepsServerMessage, required SessionsCompanion localChange})` privado no `SessionRepository`: chama `request`; um `ApiException` vira `Failure(error, keepsServerMessage(error) ? error.message : failureMessage)`, qualquer outra exceção vira `Failure(Exception('$error'), failureMessage)`; no sucesso, grava `localChange` na linha da sessão e **ignora** a falha dessa gravação (o backend já aceitou; o re-sync corrige a linha). `start`, `update` (depois do `body.isEmpty`) e `cancel` passam a usar `_run`, cada um com a regra que tem hoje.

**Os testes entram antes e passam antes da troca** (eles descrevem o comportamento de hoje): cada teste copia a montagem do vizinho, na mesma `group`. O esperado nos erros: a mensagem é a do `ApiException` quando o status é "da casa" e a constante genérica do repositório nos demais (as constantes `_startFailed`, `_cancelFailed` etc. estão no topo do arquivo de cada repositório).

- [ ] **Step 1: Escrever os testes que faltam (passam já, antes de mexer no código)**

`session_repository_test.dart`:
- grupo `start`: `sem rede, a mensagem de falta de conexão e o status local não muda`; `start: 404 vira a mensagem genérica` (Review Focus 6) e `erro do servidor (500) vira a mensagem genérica de iniciar`; `exceção que não é da API vira a mensagem genérica e não mexe no status`.
- grupo `update`: `404 (sessão apagada) devolve a mensagem do servidor, e o Failure traz a ApiException com statusCode 404, sem mexer no cache`.
- grupo `cancel`: `cancel: 404 devolve a mensagem do servidor` e `sem rede, a mensagem de falta de conexão e o status local não muda`.

`participant_repository_test.dart`:
- grupo `syncSession`: `404 devolve a mensagem do servidor e preserva o cache`.
- grupo `assign`: `sem rede, a mensagem de falta de conexão e a linha local não muda`; `404 vira a mensagem genérica de atribuir`.
- grupo `add`: `sem rede, a mensagem de falta de conexão` e `404 (sessão apagada) devolve a mensagem do servidor`.

- [ ] **Step 2: Rodar e ver passar (a linha de base do comportamento)**

Run: `flutter test test/data/repositories`
Expected: `All tests passed!`. Se algum dos testes novos falhar, o comportamento de hoje é **outro** do que o plano descreve: parar e avisar o usuário, e não ajustar o código para o teste passar.

- [ ] **Step 3: Implementar `_run` e passar `start`, `update` e `cancel` por ele**

`start` passa `keepsServerMessage: (e) => e.statusCode == 403 || e.isNetworkError`; `update` e `cancel` passam `_ownMessage`. Os textos de falha continuam os mesmos, e os comentários de cada método (o que o backend recusa, o que o cache faz) ficam, menos o `catch` repetido do cache, que sobe para o `_run`.

- [ ] **Step 4: Rodar tudo e ver passar**

Run: `flutter analyze` e `flutter test`
Expected: sem issues, `All tests passed!`: os testes antigos e os novos passam **sem edição** depois da troca.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/simtc/lib/data/repositories/session_repository.dart apps/mobile/simtc/test/data/repositories/session_repository_test.dart apps/mobile/simtc/test/data/repositories/participant_repository_test.dart
git commit -m "refactor(mobile): esqueleto unico de start, update e cancel e as bordas dos repositorios testadas"
```

---

## Task 6: Os testes que faltam em utilitários e rótulos

**Files:**
- Create: `test/ui/core/open_once_test.dart`, `test/data/services/logo_cache_test.dart`
- Modify: `lib/data/services/device_data_service.dart` (`LogoCache`), `lib/ui/profile/profile_labels.dart` (`sizeLabel`)
- Test: `test/ui/core/date_labels_test.dart`, `test/ui/profile/profile_labels_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `const LogoCache({Future<Directory> Function() temporaryDirectory = getTemporaryDirectory})`: a pasta temporária passa a ser injetável; o padrão é a de sempre (o `DeviceDataService` e o resto do app não mudam).

- [ ] **Step 1: Escrever os testes (os de `sizeLabel` e o do `LogoCache` falham; os outros passam e fixam o que já funciona)**

`date_labels_test.dart` (usar `DateTime` locais, sem UTC, para não depender do fuso):
- `à meia-noite, o dia anterior não é "hoje"`: um momento às 23:59 do dia 29/09/2026 e `now` às 00:01 do dia 30 dão `momentLabel` `'29 set 23:59'`, `clockLabel` `'29 set 23:59'`, `atLabel` `'em 29 set 23:59'` e `startedLabel` `'Iniciada em 29 set 23:59'`; e às 00:00 do dia 30 com `now` às 00:00 do dia 30 diz `'hoje 00:00'`.
- `na virada do ano, o ano aparece`: 31/12/2025 às 23:59 com `now` em 01/01/2026 às 00:01 dá `'31 dez 2025 23:59'`.

`profile_labels_test.dart`: `sizeLabel troca de unidade nos limites`: `1047552` (1023 × 1024) é `'1023 KB'`, `1047553` é `'1,0 MB'`; `1048576` é `'1,0 MB'`; `1073741823` é `'1,0 GB'`; `1073741824` é `'1,0 GB'`; `0` é `'0 KB'`.

`open_once_test.dart` (um `MaterialApp` com um botão que chama `context.claimOpen()` e guarda o resultado):
- `o segundo pedido no mesmo quadro é recusado`: dois `claimOpen()` seguidos, `true` e depois `false`.
- `depois do quadro, a trava solta`: depois de um `pump`, `claimOpen()` volta a ser `true`.
- `com outra tela por cima, é recusado`: com uma rota empilhada sobre a do botão (`Navigator.push`), `claimOpen()` da tela de baixo é `false`.

`logo_cache_test.dart` (uma pasta de verdade, criada em `Directory.systemTemp.createTemp`, apagada no `tearDown`; a subpasta é `DefaultCacheManager.key`):
- `sem a subpasta, são 0 bytes`.
- `soma os arquivos, inclusive os das subpastas, e ignora as pastas` (arquivos de 3, 5 e 7 bytes, um deles numa subpasta → 15).

- [ ] **Step 2: Rodar e ver falhar o que tem de falhar**

Run: `flutter test test/ui/core/date_labels_test.dart test/ui/core/open_once_test.dart test/ui/profile/profile_labels_test.dart test/data/services/logo_cache_test.dart`
Expected: `logo_cache_test.dart` não compila (`temporaryDirectory`); em `profile_labels_test.dart` falham `1047553` (`'1024 KB'` no lugar de `'1,0 MB'`) e `1073741823` (`'1024,0 MB'` no lugar de `'1,0 GB'`); `date_labels_test.dart` e `open_once_test.dart` passam.

- [ ] **Step 3: Implementar**

- `LogoCache` guarda o parâmetro e o usa no lugar de `getTemporaryDirectory()`.
- `sizeLabel`: escolhe a unidade depois de arredondar. O que valeria "1024 KB" (arredondado para cima) já é MB, e o que valeria "1024,0 MB" (com uma casa decimal) já é GB. Os casos do Step 1 são o contrato.

- [ ] **Step 4: Rodar tudo e ver passar**

Run: `flutter analyze` e `flutter test`
Expected: sem issues, `All tests passed!`.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/simtc/lib/data/services/device_data_service.dart apps/mobile/simtc/lib/ui/profile/profile_labels.dart apps/mobile/simtc/test/ui/core/date_labels_test.dart apps/mobile/simtc/test/ui/core/open_once_test.dart apps/mobile/simtc/test/ui/profile/profile_labels_test.dart apps/mobile/simtc/test/data/services/logo_cache_test.dart
git commit -m "test(mobile): meia-noite nos rotulos, claimopen, logocache e tamanho do cache nos limites"
```

---

## Task 7: Ternários do tablet, comentários imprecisos e README

**Files:**
- Modify: `lib/ui/core/widgets/session_context_header.dart`, `lib/ui/profile/profile_screen.dart` (`_ProfileRow`)
- Modify (comentários): `lib/data/services/assessment_sync_service.dart`, `lib/data/repositories/session_repository.dart`, `lib/data/repositories/participant_repository.dart`, `lib/ui/add_participant/add_participant_viewmodel.dart`, `lib/ui/session_edit/session_edit_viewmodel.dart`; renomear um teste em `test/data/services/assessment_sync_service_test.dart`
- Modify: `README.md`

**Interfaces:**
- Consumes: nada.
- Produces: nenhuma assinatura pública muda (os `spacious` e `tablet` dos construtores ficam).

- [ ] **Step 1: Rodar a linha de base**

Run: `flutter test test/ui/profile test/ui/session_edit test/ui/add_participant`
Expected: `All tests passed!` (a rede desta task).

- [ ] **Step 2: Implementar**

- **`SessionContextHeader`:** os 5 ternários de `spacious` viram uma escolha só no começo do `build`, entre duas constantes com nome (as medidas do quadro "3b" e as dos quadros "3a" e "3c": recuo vertical, estilo do título e vão até a linha de apoio). O logo, que são dois construtores, continua num `if`. Os números não mudam.
- **`_ProfileRow`:** o mesmo, para os ternários do `tablet` do `build` (altura mínima, recuo, tamanho do ícone, estilo): duas constantes com nome (`_phoneMetrics` e `_tabletMetrics`), e uma escolha só.
- **Comentários e um nome de teste:**
  - `assessment_sync_service.dart`: o comentário do `onError` do stream da fila diz hoje mais do que o código faz; reescrever dizendo só o que ele faz (registra e segue, a fila volta no próximo evento).
  - `session_repository.dart`: o comentário do `update` sobre a data vazia diz que o servidor "ignora data vazia" e que não há como apagar a data; deixar só isso, sem prometer mais.
  - `participant_repository.dart`: o `add` devolve um participante sem `id` quando a resposta vem fora do formato; dizer isso no comentário.
  - `add_participant_viewmodel.dart` e `session_edit_viewmodel.dart`: no `lockedReason`, um comentário dizendo que, antes da primeira leitura do cache, ele devolve "Esta sessão não está mais disponível neste aparelho.", e que isso não tem efeito porque as telas olham o carregamento antes (Decisões, 4).
  - `assessment_sync_service_test.dart`: o teste "401 no envio (sessão encerrada)" engana (o 401 é o da sessão encerrada, ou o do servidor que recusou de novo depois da renovação); renomear para dizer isso, sem mudar o que ele confere.
- **`README.md`:** a seção "Acessar o backend local a partir do aparelho" abre dizendo "Em desenvolvimento, o app fala com o backend que roda no PC". Desde a 8A, o padrão é a produção. Reescrever a abertura: o app usa a produção por padrão; só quem roda com `--dart-define=API_BASE_URL=http://localhost:3001/api` (ver "Ambientes") fala com o backend do PC, e para esse caso vale o `adb reverse` abaixo. O resto da seção fica.

- [ ] **Step 3: Rodar tudo e ver passar**

Run: `flutter analyze` e `flutter test`
Expected: sem issues, `All tests passed!`, sem editar nenhum teste além do renomeado.

- [ ] **Step 4: Commit**

```bash
git add apps/mobile/simtc/lib apps/mobile/simtc/test/data/services/assessment_sync_service_test.dart apps/mobile/simtc/README.md
git commit -m "docs(mobile): medidas do tablet em constantes, comentarios precisos e readme do backend local"
```

---

## Task 8: QA final da Fase 8, no aparelho e no emulador

O portão final, que só o usuário pode rodar: o celular no **aparelho físico** e o tablet no **emulador**, contra a produção, numa sessão de teste. Esta fase não muda o backend: não há publicação.

**Interfaces:**
- Consumes: o app com as Tasks 1 a 7, a 8D-2 e o toque da aba Sincronizar.
- Produces: o aval do usuário para fechar a Fase 8.

- [ ] **Step 1: Instalar**

Em `apps/mobile/simtc/`: `flutter run -d <id do celular>` e, depois, `flutter run -d emulator-5554`.

- [ ] **Step 2: Roteiro novo (celular e tablet)**

Com uma conta CONSULTANT e uma ADMIN, numa sessão de teste em andamento:

1. **Os dois perfis, de ponta a ponta:** o CONSULTANT atribui, avalia e confirma um participante e vê o Resultado; o ADMIN edita os dados da sessão, adiciona um participante, vê os consultores e desatribui um participante que está com outro consultor.
2. **Dois consultores no mesmo participante:** os dois tocam em "Atribuir a mim" no mesmo participante, em dois aparelhos ou num aparelho e no painel web. Só um consegue; o outro vê o motivo, e a linha mostra com quem o participante está.
3. **Queda de rede no meio do envio:** confirmar uma avaliação com rede, ligar o modo avião durante o "Enviando". A avaliação fica "Na fila" ou com "Erro", sem sumir; ao desligar o modo avião, ela sobe sozinha.
4. **Aparelho compartilhado:** um consultor sai da conta com avaliações na fila e outro entra. O segundo não vê a fila do primeiro, e quando o primeiro volta, a fila dele continua lá.
5. **Toque na aba Sincronizar (novo):** com a fila de 2 ou mais itens e a sessão com muitos participantes, tocar num item. O app abre o treinamento, rola até o participante e a linha **pisca duas vezes**. No celular, o voltar volta à aba Sincronizar; no tablet, abre a aba Sessões com a sessão escolhida. Repetir com um filtro ("Pendentes") ligado: o app volta para "Todos" e mostra a linha.
6. **Fonte ampliada (1,3× ou mais):** os rodapés, os diálogos de confirmação e os avisos continuam inteiros, sem estouro, na tela de Adicionar participante, Dados do treinamento, Resumo, Resultado e Checklist.
7. **Perfil:** o tamanho do cache aparece como "KB", "MB" ou "GB" e nunca como "1024 KB".

- [ ] **Step 3: Roteiro das telas das 8A, 8B, 8C e 8D-2, de novo**

Repetir os roteiros das Tasks de validação já escritas, sem criar roteiro novo:
- `2026-10-24-mobile-fase-8a-producao-e-perfil.md`;
- `2026-10-24-mobile-fase-8b-buscas.md`;
- `2026-10-26-mobile-fase-8c-telas-e-acessibilidade.md`;
- `2026-10-30-mobile-fase-8d2-defeitos-de-borda.md` (Task 8).

- [ ] **Step 4: Registrar o resultado**

Se tudo passar, acrescentar ao fim desta task a linha "**Validado em <data>: celular no aparelho físico e tablet no emulador; roteiro inteiro passou. Fase 8 concluída.**" e commitar:

```bash
git add apps/mobile/docs/superpowers/plans/2026-11-08-mobile-fase-8d3-limpeza-testes-e-qa-final.md
git commit -m "docs(mobile): registra a validacao da fase 8d-3 e o fim da fase 8"
```

Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio, parar e perguntar.

Depois do aval, e só com o OK do usuário, um passo de cada vez: enviar a `feat/mobile-app` ao GitHub e, se o usuário quiser, avançar a `feat/frontend-backend-integration` (que publica na produção). As mudanças do app não pedem deploy do servidor.

---

## Observações para depois da Fase 8

- **Do painel web** (o usuário vai refinar depois da Fase 8): o painel não usa a consulta de CPF e troca o nome do cadastro sem avisar; não apaga as observações de uma sessão; o `PATCH` que troca o responsável sem a lista não recria os vínculos.
- **Do backend** (precisam do aval do usuário): o envio grava o participante sem condição; atribuir e cancelar ao mesmo tempo; iniciar uma sessão já iniciada não recarrega no web.
- **Do app, não feitas** (Decisões 1, 2, 3 e 5): testes de diretriz em mais de um estado por tela; os demais ternários do tablet (~55 em `result_screen`, `checklist_screen` e outros); unificar a regra de mensagem do `start` com a do `update`/`cancel`; guardar a "Última sincronização" no banco.
- **Coisas novas, fora da Fase 8:** enviar com o app fechado (WorkManager), guardar o Resultado no aparelho, buscar participante em todas as sessões, a agenda do consultor, apagar a data de uma sessão.
