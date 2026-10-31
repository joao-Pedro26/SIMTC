# App Mobile SIMTC — Fase 8D-2: Defeitos de borda do app — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O app deixa de perder ou travar uma avaliação nas bordas do uso em campo: o envio que só o servidor recusa item a item libera o "Descartar", a fila que espera o catálogo sai sozinha, o login e o "Sair" não ficam pela metade, a troca de servidor não leva a fila antiga, o checklist acompanha o participante que saiu das mãos do consultor, a consulta de CPF e a regra de e-mail batem com o servidor, as telas de admin travam com a sessão apagada, e o detalhe, a Home e Consultores mostram o que está acontecendo.

**Architecture:** Só o app muda. Sem backend, sem mudança no banco do aparelho (o esquema do drift continua na versão 5) e sem dependência nova. As correções ficam nas ViewModels, nos repositórios e nos serviços que já existem; um auxiliar novo (`lib/utils/email.dart`, a regra de e-mail do servidor). O que vem do servidor e decide a tela (o 404 da sessão apagada, a recusa do "Iniciar") vira estado das ViewModels, como as recusas que já existem.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · dio · drift 2.31.0 (sem mudança de esquema) · flutter_secure_storage · mocktail (testes). Nenhuma dependência nova.

**Spec:** `apps/mobile/docs/superpowers/specs/2026-10-24-mobile-fase-8-design.md`, seção "Desenho da 8D" → "8D-2 — Defeitos de borda do app" (itens 1 a 23), aprovada pelo usuário em 27/10/2026; e as "Observações levadas para a 8D-2" no fim do plano da 8D-1 (`2026-10-27-mobile-fase-8d1-servidor-confere-regras.md`). O usuário pediu este plano em 30/10/2026 ("ok, pode seguir com o plano da 8D-2").

**Validação prévia:** antes de o plano ser fechado, cada um dos 23 itens do desenho foi conferido no código de hoje, e quatro já estavam resolvidos (ver "Ajustes"). Depois, todo o código das Tasks 1 a 7 foi escrito e rodado numa cópia descartável do app, uma task por commit. As tasks foram **reencenadas em ordem** numa segunda cópia limpa, a partir dos blocos deste plano:
- em cada task, os testes da task falharam antes da implementação e passaram depois;
- cada checkpoint bateu o número de testes — **1170 → 1178 → 1191 → 1194 → 1200 → 1209 → 1217 → 1223** —, com `flutter analyze` sem issues em todos;
- a árvore de cada task ficou **idêntica** à do commit correspondente. A reencenação pegou uma linha em branco que o bloco da Task 7 perdia, e o gerador dos blocos foi corrigido.

**Cada decisão foi conferida por mutação** (o trecho é trocado por uma versão errada, e algum teste tem de falhar): **53 mutações**, 52 acusadas na versão final. Duas sobreviveram na primeira rodada:
- o botão de nota desligado na tela, que a ViewModel também barra. O teste passou a conferir que o botão perde a ação de toque no leitor de tela.
- o `.distinct()` do stream do catálogo. Era código a mais, porque o serviço ignora o mesmo valor repetido, e saiu.

Os casos do e-mail foram conferidos um a um no `isEmail` do class-validator do backend.

As telas novas foram **desenhadas com as fontes de verdade**, sem estouro e conferidas a olho:
- a splash com a troca de servidor que não apagou e a aba Sincronizar com a fila esperando o catálogo, em 412×915, em 360×640 com a fonte em 1,6× e no tablet em 1280×800 e 900×1200;
- a busca numa sessão nunca baixada, em 412×915 e em 360×640 com 1,6×.

## Decisões tomadas com o usuário

O usuário deixou as decisões da 8D para o bom senso ("analise pelo bom senso, como na 8C") e aprovou o desenho escrito com elas. Do "Desenho da 8D" → 8D-2, em resumo:

1. **Envio e sessão:** um 4xx no lote inteiro vira falha que se tenta de novo, sem "Descartar" (item 1); depois do "Limpar cache local", a fila sai assim que o catálogo volta, e a aba Sincronizar diz que ela espera o catálogo (item 4); a renovação do login só derruba a sessão se ainda for a mesma (item 5); o "Sair" que falha no meio termina de limpar (item 6); a troca de servidor que não apagou tudo não segue para o login e avisa (item 7); falha da keystore ao entrar não derruba o login nem deixa o perfil de outro usuário (item 8); o checklist do participante que saiu das mãos do consultor para de marcar notas e de finalizar (item 9); o aviso "Você já está avaliando…" é recalculado quando o aparelho muda (item 10); "Última sincronização" não volta para trás (item 11); a abertura com rede ruim espera no máximo 5 s (item 12).
2. **Admin e CPF:** a resposta atrasada da consulta é reconhecida pela consulta, a máscara mantém o cursor e o foco vai para o nome quando a consulta termina sem cadastro (item 15); a tela travada não pergunta se descarta (item 16); a sessão apagada (404) trava a 1.11 e a 1.12 com "Esta sessão não existe mais." (item 17); o "Cancelar sessão" tira o foco do campo antes do diálogo (item 18).
3. **Telas:** "Não salvo" sai com o descarte, e com a leitura que falhou o "salvo" e o ⋮ somem (item 19); com a fonte ≥1,3×, o chip do detalhe rola só a barra e o campo de busca não abre o teclado sozinho (item 20); "Desatribuindo…" é anunciado pelo leitor de tela (item 21); a busca numa sessão nunca baixada diz por que não acha nada, e em Consultores a frase de nenhum resultado não aparece junto do erro da equipe (item 22); ao fechar a busca da Home, o chip destacado bate com a rolagem (item 23).
4. **Da 8D-1:** alinhar a regra de e-mail do app com a do servidor, e baixar a sessão de novo depois da recusa do "Iniciar" (o app mostrava "Planejado" até a próxima atualização).

### Ajustes feitos ao preparar o plano (revisar junto com o plano)

O desenho conferiu contra o código de hoje só as pendências do backend. Ao preparar este plano, cada item do app foi conferido no código, e a validação na cópia descartável levou a estas escolhas. **Nenhuma muda regra aprovada**; as que divergem do canvas estão marcadas.

**Já resolvidos no código de hoje (nada a fazer):**

- **Item 2 (o 401 no envio):** o `ApiClient` já renova o login e repete o pedido na mesma rodada (desde a 5A). O 401 que chega ao envio é o da sessão encerrada, ou o do servidor que recusou de novo depois da renovação: a fila espera o dono, ou tenta mais tarde.
- **Item 3 (erros ao entrar):** a reivindicação da fila sem dono e o stream da fila já são tratados, o "Sincronizar agora" já espera a rodada repetida e a lista de esperas vazia já é recusada (Fase 8A, commit `4907d99`).
- **Item 13 (data de mais de 90 dias):** a 1.12 já pede confirmação (decisão de 09/10/2026, `dateLeavesTheList`).
- **Item 14 (CPF sem conexão):** sem rede, a consulta já não roda, e roda sozinha quando a rede volta (decisões de 09/10/2026).
- **Item 15, o tempo limite:** a consulta já tem limite próprio, de **8 s** (09/10/2026). *Escolha minha:* fica em 8 s, e não nos 10 s do desenho, que supunha não haver limite.
- **Item 8, em parte:** apagar e gravar o perfil salvo já não derrubam o login (Fase 8A). Falta o resto: o "manter conectado" e os tokens que não gravam, e o perfil de outro usuário que sobra.

**Regras e textos que o código cria:**

- **Envio:** o erro do pedido inteiro (um 4xx, como um 400 de validação) e o item que a resposta não cita ganham um motivo novo, **"erro no envio"** ("Falhou às 07:58 · erro no envio"): sem "Descartar", e a fila tenta de novo sozinha. Só a recusa item a item continua "recusada pelo servidor". Um envio de ADMIN sem perfil de consultor (409 no lote) passa a ficar na fila tentando, em vez de oferecer o "Descartar".
- **Fila esperando o catálogo:** o serviço de envio acompanha o catálogo do aparelho e envia assim que ele volta; a aba Sincronizar mostra, com rede e com a fila cheia, *"A fila espera o catálogo de avaliação, apagado do aparelho pelo "Limpar cache local". Ela sai sozinha quando a aba Sessões baixar o catálogo de novo."* *Não está no canvas.*
- **"Última sincronização"** não volta para trás **enquanto o mesmo usuário está logado** (o serviço guarda o horário mais novo). *Escolha minha:* depois de reabrir o app, ela pode mostrar o envio anterior que ainda está no aparelho. Guardar o horário no banco pediria uma migração nos aparelhos de campo por causa de um rótulo.
- **Renovação do login:** a recusa (4xx) ou a resposta sem tokens só encerra a sessão se o refresh token guardado ainda é o que foi usado. Se outra pessoa entrou no meio, o pedido antigo recebe o 401 e a sessão nova fica.
- **"Sair":** cada passo da limpeza (os tokens, o cache de sessões) roda mesmo que o anterior falhe, e o usuário sai do mesmo jeito. Na prática, o aviso "Não foi possível sair" deixa de aparecer. Se uma chave do armazenamento seguro não apaga, o "manter conectado" é desligado, e a próxima abertura vai ao login em vez de retomar a sessão de quem saiu. A sessão que expira avisa o app mesmo com o armazenamento falhando.
- **Keystore ao entrar:** o "manter conectado" e os tokens que não gravam não derrubam o login, que vale em memória. Os tokens que não gravaram são apagados do aparelho, para a próxima abertura não voltar com um par velho ou pela metade.
- **Entrada sem rede:** o perfil salvo só abre o app se for do dono do token (o `id` do perfil igual ao `sub` do JWT). Se não for, vai para o login.
- **Abertura com rede ruim:** o servidor que não responde em 5 s conta como sem rede, e o app entra com o perfil salvo. Sem perfil salvo, o login mostra *"O servidor demorou para responder. Verifique a internet e tente de novo."*.
- **Troca de servidor que não apagou:** a abertura para na splash com *"Não foi possível preparar o aparelho para o novo servidor. Tente de novo."* e o botão **"Tentar de novo"**, no lugar da barra. O endereço novo não é guardado, então a próxima abertura também tenta de novo. *Diverge do canvas: a splash não tem texto.* *Escolha minha:* o botão, além da "abertura seguinte" do desenho.
- **Checklist:** com o participante liberado, os B/PM/M deixam de responder (o "Finalizar" já ficava desligado). O aviso "Você já está avaliando…" é conferido de novo quando as avaliações do aparelho ou os participantes mudam, e não só ao abrir a tela. Assim, um participante liberado também solta o bloqueio da avaliação dele. Também nesta parte: o "Não salvo" sai com o descarte; com a leitura que falhou, o "salvo" e o ⋮ somem; o "Desatribuindo…" vira região viva.
- **Consulta de CPF:** vale só a resposta da última consulta, contada por um número de geração, e não pelo CPF. O foco vai para o nome só quando a consulta acaba sem cadastro **e o admin ainda está no CPF**; com cadastro, ou já inscrito, o foco não muda. A máscara deixa o cursor depois do mesmo número de dígitos que ele tinha à esquerda.
- **E-mail:** a 1.11 confere o e-mail com a mesma regra do servidor (o `@IsEmail` do class-validator), conferida caso a caso no backend. Recusa `a@b.c`, `maria@empresa..com`, `m@x.com.`, ponto no começo ou no fim do nome, domínio com hífen na ponta, fim do domínio com dígito ou com uma letra só. *Escolha minha:* duas formas que ninguém digita num formulário ficam de fora (o nome entre aspas e o endereço IP entre colchetes), e o app as recusa.
- **Sessão apagada (404) na 1.11 e na 1.12:** a tela trava com *"Esta sessão não existe mais."*, no lugar da mensagem do servidor, e baixa a sessão de novo, como já fazia.
- **Tela travada:** com a 1.11 ou a 1.12 travada (pelo 404, ou porque outra pessoa concluiu ou cancelou a sessão), o fechar não pergunta se descarta: não há o que salvar.
- **Foco antes dos diálogos da 1.12:** tirar o foco só do `FocusScope` da tela não bastava, porque ela guarda o campo e o foco volta a ele (com o teclado) quando o diálogo fecha. Agora o foco sai do próprio campo. *Escolha minha:* vale para o "Cancelar sessão" (item 18) e também para o "Salvar" com a data antiga, que tinha o mesmo defeito.
- **"Iniciar" recusado pelo servidor** (outro aparelho já iniciou ou concluiu a sessão): a mensagem do servidor aparece e a sessão é baixada de novo. Sem rede, nada a baixar.
- **Chips com a fonte ampliada:** a barra de chips rola só a si mesma (`ScrollPosition.ensureVisible` da barra), e não a lista em volta. Vale para o detalhe e para a Home.
- **Campo de busca dentro de uma lista:** fica vivo quando sai de vista (`AutomaticKeepAliveClientMixin`). Ao voltar, não abre o teclado sozinho e o texto continua.
- **Busca numa sessão nunca baixada:** a contagem "0 de 0" some, e a lista diz *"A busca procura nos participantes baixados, e os desta sessão ainda não foram baixados."* *Não está no canvas.*
- **Consultores:** a frase de nenhum resultado some **só com a equipe que falhou ao carregar** ("Não foi possível carregar a equipe"). *Escolha minha:* com a equipe sem conexão, a frase continua junto do aviso, como o teste do tablet já esperava (decisões de 24/10/2026).
- **Home:** ao fechar a busca, o chip destacado é recalculado pela rolagem no quadro seguinte.

**Divergências do canvas:** a splash com o aviso e o "Tentar de novo"; o aviso da fila esperando o catálogo, em Sincronizar; o aviso da busca numa sessão nunca baixada. Os três são estados que o canvas não desenha.

## Review Focus

Os casos que o desenho implica, que um consultor (ou o admin) vai encontrar em campo, e onde cada um ficou preso num teste:

1. **O servidor recusa o lote inteiro (uma versão antiga do app, um 400)** → nenhuma avaliação válida fica com o "Descartar" à mão; a fila tenta sozinha. Preso em: `um 4xx no pedido inteiro não libera o "Descartar": a fila tenta de novo sozinha` (Task 1).
2. **Aparelho compartilhado: o consultor A sai, o B entra enquanto uma renovação do A ainda está no ar** → a sessão do B continua. Preso em: `um 4xx do token antigo não derruba a sessão nova` (Task 2).
3. **Keystore do Android falhando (backup restaurado, bloqueio de tela trocado)** → entrar, sair e abrir sem rede continuam funcionando, e nunca no nome de outra pessoa. Preso em: `o perfil salvo de outra pessoa (a keystore falhou no login) não abre o app sem rede` e no grupo `"Sair" que falha no meio` (Task 2).
4. **O ADMIN desatribui o participante com o checklist aberto no aparelho do consultor** → as notas param de marcar até ele ser atribuído de novo. Preso em: `com o participante liberado, as notas não marcam até ele ser atribuído de novo` (Task 4).
5. **O admin digita o CPF, apaga um dígito e redigita antes da primeira resposta, e corrige o nome** → a resposta atrasada não troca o nome corrigido. Preso em: `a resposta atrasada do mesmo CPF, redigitado, também é ignorada` (Task 5).

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app`. Sem git worktree. Não criar branch, não fazer merge, não fazer push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada, com a mensagem exata dada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem trabalho do usuário fora do git, que **não é desta fase e fica exatamente como está**: um arquivo rastreado **já modificado** (`brainstorm-app-mobile.md`) e os não rastreados `.vscode/`, `IMPLEMENTATION-STATUS.md`, `apps/backend/test-render.js`, `apps/mobile/simtc/devtools_options.yaml`, `apps/web/src/app/(client)/my-company/trainings/[id]/certificates/`, `brainstorm-implementacao-mobile.md`, `prompt-claude-design-mobile.md`, `prompt-implementacao-mobile-claude-code.md`, `test-pdf.js` e `test-render.js`.
- **Proibido `git restore`, `git checkout -- <arquivo>`, `git stash`, `git reset` e `git clean`**, e qualquer outro comando que desfaça mudança que não é da task. Se o `git status` mostrar algo que não é da task, ignorar e seguir.
- **Na execução por subagentes:** antes do primeiro despacho, guardar a linha de base — o `git status --porcelain` inteiro e o `git hash-object brainstorm-app-mobile.md` — e compará-la, sem filtrar nada, depois de **cada** subagente. Todo despacho repete as duas regras acima com todas as letras. Implementadores em **haiku**; revisões em **sonnet**; revisão final em **opus**.
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-10-30-mobile-fase-8d2-defeitos-de-borda/`.

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

## Estado herdado (ponto de partida)

HEAD = o commit deste plano, sobre `0230d53` (o registro da validação da 8D-1). App: `flutter analyze` limpo; **1170 testes passando**.

Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| Motivos de falha do envio | `lib/data/services/assessment_sync_service.dart` | `SendFailure.refused`, `refusals`, `_reasonFor` |
| Espera do catálogo | `lib/data/repositories/assessment_repository.dart` | `waitsForCatalog(batch)` |
| Renovação do token | `lib/data/services/api/api_client.dart` | `_performRefresh()`, `onSessionExpired` |
| Abertura e troca de servidor | `lib/ui/splash/`, `lib/data/services/device_data_service.dart` | `SplashViewModel.decideInitialRoute()`, `resetIfServerChanged(url)` |
| Aviso em bloco e botões | `lib/ui/core/widgets/inline_notice.dart`, `app_buttons.dart` | `InlineNotice(icon:, tone:, message:)`, `AppCtaButton(label:, icon:, onPressed:)` |
| Liberado e bloqueio do checklist | `lib/ui/checklist/checklist_viewmodel.dart` | `isReleased`, `_checkBlock()`, `findInProgressOther` |
| Travas das telas de admin | `lib/ui/add_participant/`, `lib/ui/session_edit/` | `lockedReason`, `canAdd`/`canEdit` |

## Mapa de Arquivos

### Novos

| Arquivo | Task | Responsabilidade |
|---|---|---|
| `lib/utils/email.dart` | 5 | `isValidEmail(value)`, a regra do servidor |
| `test/utils/email_test.dart` | 5 | os casos conferidos no backend |

### Modificados

| Arquivo | Task | O que muda |
|---|---|---|
| `lib/data/services/assessment_sync_service.dart`, `lib/data/repositories/assessment_repository.dart`, `lib/ui/sync/sync_screen.dart` | 1, 4 | "erro no envio", espera do catálogo, última sincronização; `watchInProgressChanges` |
| `lib/data/services/api/api_client.dart`, `lib/data/repositories/auth_repository.dart`, `lib/data/services/auth_session.dart`, `lib/data/services/local/token_storage.dart` | 2 | renovação, "Sair", keystore, perfil salvo, limite da abertura |
| `lib/ui/splash/*`, `lib/data/services/device_data_service.dart` | 3 | a troca de servidor que não apagou |
| `lib/ui/checklist/checklist_viewmodel.dart`, `checklist_screen.dart` | 4 | liberado, bloqueio, "Não salvo", leitura que falhou, região viva |
| `lib/ui/add_participant/*`, `lib/ui/core/cpf_input_formatter.dart` | 5, 6 | consulta, foco, cursor, e-mail; 404 e tela travada |
| `lib/ui/session_edit/*` | 6 | 404, tela travada, foco antes dos diálogos |
| `lib/ui/session_detail/*`, `lib/ui/session_consultants/*`, `lib/ui/sessions/sessions_screen.dart`, `lib/ui/core/widgets/filter_chip_bar.dart`, `app_search_field.dart` | 7 | "Iniciar" recusado, chips, busca, nenhum resultado, chip da Home |
| testes existentes e `test/support/fake_assessment_sync_service.dart` | 1–7 | os que conferem o que muda |

---

## Task 1: Envio: o erro do lote inteiro tenta de novo, a fila sai quando o catálogo volta

Itens 1, 4 e 11 do desenho. O 4xx no pedido inteiro (e o item que a resposta não cita) ganha o motivo "erro no envio", que não libera o "Descartar": só a recusa item a item é "recusada pelo servidor". O serviço de envio acompanha o catálogo do aparelho (`watchHasCatalog`): a fila que esperava por ele (`isWaitingForCatalog`) sai assim que ele volta, e a aba Sincronizar diz por que ela não saiu. "Última sincronização" não volta para trás enquanto o mesmo usuário está logado.

**Files:**
- Modify: `lib/data/repositories/assessment_repository.dart`
- Modify: `lib/data/services/assessment_sync_service.dart`
- Modify: `lib/ui/sync/sync_screen.dart`
- Modify: `test/data/repositories/assessment_repository_test.dart`
- Modify: `test/data/services/assessment_sync_service_test.dart`
- Modify: `test/support/fake_assessment_sync_service.dart`
- Modify: `test/ui/sync/sync_screen_test.dart`

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces:
  - `SendFailure.sendFailed` ("erro no envio"), fora de `SendFailure.refusals`
  - `AssessmentSyncService.isWaitingForCatalog` (bool)
  - `AssessmentRepository.watchHasCatalog(): Stream<bool>`
  - `FakeAssessmentSyncService(waitingForCatalog:)` em `test/support/`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/data/repositories/assessment_repository_test.dart`, substituir:

```dart
      );
    });
  });
}
```

por:

```dart
      );
    });

    test('avisa quando o catálogo some e quando ele volta (Fase 8D)', () async {
      final seen = <bool>[];
      final subscription = repository.watchHasCatalog().listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen, [false]);

      await db.into(db.assessmentCategories).insert(AssessmentCategoriesCompanion.insert(
          id: 'cat-1', code: 'A', name: 'Antes', order: 1));
      await db.into(db.infractions).insert(InfractionsCompanion.insert(
          id: 'inf-1', categoryId: 'cat-1', description: 'Cinto', order: 1));
      await pumpEventQueue();
      expect(seen, [false], reason: 'sem nota, ainda não há o que avaliar');

      await db.into(db.infractionNotes).insert(InfractionNotesCompanion.insert(
          id: 'note-m', infractionId: 'inf-1', noteType: 'M', deduction: 3));
      await pumpEventQueue();
      expect(seen, [false, true]);

      await db.clearDownloadedData();
      await pumpEventQueue();
      expect(seen, [false, true, false]);
    });
  });
}
```

Em `test/data/services/assessment_sync_service_test.dart`, substituir:

```dart
    AssessmentRepository? repository,
  }) {
```

por:

```dart
    AssessmentRepository? repository,
    DateTime Function()? now,
  }) {
```

Em `test/data/services/assessment_sync_service_test.dart`, substituir:

```dart
      now: () => DateTime(2026, 9, 29, 9, 15),
```

por:

```dart
      now: now ?? () => DateTime(2026, 9, 29, 9, 15),
```

Em `test/data/services/assessment_sync_service_test.dart`, substituir:

```dart
      (
        const ApiException(message: 'Consultor não identificado', statusCode: 409),
        SendFailure.refused,
```

por:

```dart
      // O pedido inteiro recusado não é a recusa de um item (Fase 8D).
      (
        const ApiException(message: 'Consultor não identificado', statusCode: 409),
        SendFailure.sendFailed,
      ),
      (
        const ApiException(message: 'items must be an array', statusCode: 400),
        SendFailure.sendFailed,
```

Em `test/data/services/assessment_sync_service_test.dart`, substituir:

```dart
    }
  });
```

por:

```dart
    }
  });

  test(
      'um 4xx no pedido inteiro não libera o "Descartar": a fila tenta de novo '
      'sozinha (Fase 8D)', () async {
    failWith(const ApiException(message: 'Bad Request', statusCode: 400));
    final sync = startService(retryDelays: const [Duration(milliseconds: 50)]);

    final a = await confirmed('tp-1');
    await until(() async => await statusOf(a.id) == LocalSyncStatus.error);
    await until(() => !sync.isSending);
    expect((await row(a.id)).lastError, SendFailure.sendFailed);
    expect(SendFailure.refusals, isNot(contains(SendFailure.sendFailed)));
    expect(await sync.discardRefused(a.id), isFalse);
    expect(await db.select(db.localAssessments).get(), hasLength(1));

    acceptAll();

    await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
  });

  test(
      'um item que a resposta não cita não é uma recusa: fica com o erro do '
      'envio, sem o "Descartar" (Fase 8D)', () async {
    when(() => api.post<List<dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      sent.add(payloadOf(invocation));
      return Response<List<dynamic>>(
        requestOptions: RequestOptions(path: AssessmentSyncService.syncPath),
        statusCode: 201,
        data: const [],
      );
    });
    startService();

    final a = await confirmed('tp-1');

    await until(() async => await statusOf(a.id) == LocalSyncStatus.error);
    expect((await row(a.id)).lastError, SendFailure.sendFailed);
  });
```

Em `test/data/services/assessment_sync_service_test.dart`, substituir:

```dart
      'avaliação com marcações não sai vazia: espera o catálogo voltar',
      () async {
    final sync = startService(retryDelays: const [Duration(milliseconds: 20)]);
```

por:

```dart
      'avaliação com marcações não sai vazia: espera o catálogo voltar, e sai '
      'assim que ele volta, sem esperar a próxima tentativa (Fase 8D)',
      () async {
    final sync = startService(retryDelays: const [Duration(hours: 1)]);
```

Em `test/data/services/assessment_sync_service_test.dart`, substituir:

```dart
    expect(sync.queue, hasLength(1));

    // A Home baixa o catálogo de novo: a próxima tentativa leva a marcação.
    await db.into(db.assessmentCategories).insert(
```

por:

```dart
    expect(sync.queue, hasLength(1));
    expect(sync.isWaitingForCatalog, isTrue);

    // A Home baixa o catálogo de novo: o envio sai na hora, com a marcação.
    await db.into(db.assessmentCategories).insert(
```

Em `test/data/services/assessment_sync_service_test.dart`, substituir:

```dart
    ]);
  });
```

por:

```dart
    ]);
    expect(sync.isWaitingForCatalog, isFalse);
  });
```

Em `test/data/services/assessment_sync_service_test.dart`, substituir:

```dart
  });

  test('sair da conta para de seguir a fila de quem saiu', () async {
    failWith(semRede);
```

por:

```dart
  });

  test(
      'a última sincronização não volta para trás quando a reavaliação apaga '
      'a avaliação enviada (Fase 8D)', () async {
    var clock = DateTime(2026, 9, 29, 9, 15);
    final sync = startService(now: () => clock);
    await confirmed('tp-1');
    await until(() => sync.lastSyncedAt == DateTime(2026, 9, 29, 9, 15));
    clock = DateTime(2026, 9, 29, 9, 40);
    await confirmed('tp-2');
    await until(() => sync.lastSyncedAt == DateTime(2026, 9, 29, 9, 40));
    await until(() => !sync.isSending);

    // "Reavaliar" o tp-2: o rascunho novo apaga do aparelho a enviada às 9:40.
    await assessments.openDraft(
      trainingParticipantId: 'tp-2',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
      consultantId: 'c-eu',
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(sync.lastSyncedAt, DateTime(2026, 9, 29, 9, 40));
  });

  test('sair da conta para de seguir a fila de quem saiu', () async {
    failWith(semRede);
```

Em `test/support/fake_assessment_sync_service.dart`, substituir:

```dart
  })  : _queue = queue,
        _sendingIds = sendingIds,
        _lastSyncedAt = lastSyncedAt,
```

por:

```dart
    bool waitingForCatalog = false,
  })  : _queue = queue,
        _sendingIds = sendingIds,
        _lastSyncedAt = lastSyncedAt,
        _waitingForCatalog = waitingForCatalog,
```

Em `test/support/fake_assessment_sync_service.dart`, substituir:

```dart
  Set<String> _sendingIds;
  final DateTime? _lastSyncedAt;

  /// Quantas vezes a tela pediu para enviar agora.
```

por:

```dart
  Set<String> _sendingIds;
  final DateTime? _lastSyncedAt;
  final bool _waitingForCatalog;

  /// Quantas vezes a tela pediu para enviar agora.
```

Em `test/support/fake_assessment_sync_service.dart`, substituir:

```dart
  @override
  DateTime? get lastSyncedAt => _lastSyncedAt;

  @override
```

por:

```dart
  @override
  DateTime? get lastSyncedAt => _lastSyncedAt;

  @override
  bool get isWaitingForCatalog => _waitingForCatalog;

  @override
```

Em `test/ui/sync/sync_screen_test.dart`, substituir:

```dart
    DateTime? lastSyncedAt,
    Size size = const Size(420, 1600),
```

por:

```dart
    DateTime? lastSyncedAt,
    bool waitingForCatalog = false,
    Size size = const Size(420, 1600),
```

Em `test/ui/sync/sync_screen_test.dart`, substituir:

```dart
      lastSyncedAt: lastSyncedAt,
    );
```

por:

```dart
      lastSyncedAt: lastSyncedAt,
      waitingForCatalog: waitingForCatalog,
    );
```

Em `test/ui/sync/sync_screen_test.dart`, substituir:

```dart
  });

  testWidgets(
      'com um envio no ar, o "Descartar" do item recusado fica desabilitado',
```

por:

```dart
  });

  testWidgets('o erro do envio inteiro não tem "Descartar": tenta sozinha (Fase 8D)',
      (tester) async {
    await pump(tester, queue: [
      queuedAssessment(
        '4',
        participantName: 'Rodrigo Tavares',
        status: LocalSyncStatus.error,
        lastAttemptAt: DateTime(2026, 9, 29, 7, 58),
        lastError: SendFailure.sendFailed,
      ),
    ]);

    expect(find.text('Falhou às 07:58 · erro no envio'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Descartar'), findsNothing);
  });

  group('fila esperando o catálogo (Fase 8D)', () {
    const aviso = Key('sync-catalog-notice');

    testWidgets('diz por que a fila não sai, e que sai sozinha', (tester) async {
      await pump(tester, queue: filaDoCanvas(), waitingForCatalog: true);

      expect(find.byKey(aviso), findsOneWidget);
      expect(
        find.text('A fila espera o catálogo de avaliação, apagado do aparelho '
            'pelo "Limpar cache local". Ela sai sozinha quando a aba Sessões '
            'baixar o catálogo de novo.'),
        findsOneWidget,
      );
      // O aviso fica acima da lista de pendentes.
      expect(
        tester.getTopLeft(find.byKey(aviso)).dy,
        lessThan(tester.getTopLeft(find.text('Pendentes')).dy),
      );
    });

    testWidgets('sem rede, vale o cartão de sem conexão', (tester) async {
      await goOffline();
      await pump(tester, queue: filaDoCanvas(), waitingForCatalog: true);

      expect(find.byKey(const Key('sync-offline-card')), findsOneWidget);
      expect(find.byKey(aviso), findsNothing);
    });

    testWidgets('com o catálogo no aparelho, nada a dizer', (tester) async {
      await pump(tester, queue: filaDoCanvas());

      expect(find.byKey(aviso), findsNothing);
    });
  });

  testWidgets(
      'com um envio no ar, o "Descartar" do item recusado fica desabilitado',
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/data/services/assessment_sync_service_test.dart test/data/repositories/assessment_repository_test.dart test/ui/sync`
Esperado: `+5 -3: Some tests failed.` — os arquivos não compilam: `Member not found: 'sendFailed'`, `The getter 'isWaitingForCatalog' isn't defined` e `The method 'watchHasCatalog' isn't defined` (e o `FakeAssessmentSyncService` sem o `waitingForCatalog`).

- [ ] **Step 3: Implementar**

Em `lib/data/repositories/assessment_repository.dart`, substituir:

```dart
  }

  /// Quantas avaliações [ownerUserId] iniciou e ainda não confirmou — todas,
  /// inclusive as presas (sessão concluída, participante liberado): a
```

por:

```dart
  }

  /// Se o catálogo está no aparelho, avisando quando muda — é como a fila que
  /// espera por ele ([waitsForCatalog]) sabe que pode sair (Fase 8D).
  Stream<bool> watchHasCatalog() {
    return (_db.select(_db.infractionNotes)..limit(1))
        .watch()
        .map((notes) => notes.isNotEmpty);
  }

  /// Quantas avaliações [ownerUserId] iniciou e ainda não confirmou — todas,
  /// inclusive as presas (sessão concluída, participante liberado): a
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
  static const String serverDown = 'servidor indisponível';
  static const String refused = 'recusada pelo servidor';

  /// O servidor recusou porque o participante não está mais em avaliação com
```

por:

```dart
  static const String serverDown = 'servidor indisponível';
  static const String refused = 'recusada pelo servidor';

  /// O pedido inteiro voltou com erro (um 4xx, como um 400 de validação), ou
  /// a resposta não falou de um item: nenhum item foi recusado de fato, e a
  /// fila tenta de novo sozinha (Fase 8D). Só a recusa item a item é [refused].
  static const String sendFailed = 'erro no envio';

  /// O servidor recusou porque o participante não está mais em avaliação com
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
  StreamSubscription<DateTime?>? _lastSyncedSubscription;
  StreamSubscription<void>? _reconnectSubscription;
```

por:

```dart
  StreamSubscription<DateTime?>? _lastSyncedSubscription;
  StreamSubscription<bool>? _catalogSubscription;
  StreamSubscription<void>? _reconnectSubscription;
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
  Set<String> _sendingIds = const {};
  DateTime? _lastSyncedAt;

  /// A fila de quem está logado: confirmadas e ainda não aceitas, na ordem
```

por:

```dart
  Set<String> _sendingIds = const {};
  DateTime? _lastSyncedAt;
  bool _waitingForCatalog = false;

  /// A fila de quem está logado: confirmadas e ainda não aceitas, na ordem
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
  /// Quando o último envio foi aceito — nulo se nada foi aceito ainda.
  DateTime? get lastSyncedAt => _lastSyncedAt;
```

por:

```dart
  /// Quando o último envio foi aceito — nulo se nada foi aceito ainda. Nunca
  /// volta para trás enquanto o mesmo usuário está logado: a reavaliação
  /// apaga do aparelho a avaliação já enviada, e sem ela o banco diria o
  /// horário de um envio anterior (Fase 8D).
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// A fila tem marcações e o catálogo não está no aparelho (o "Limpar cache
  /// local" apagou): ela espera, e sai sozinha assim que o catálogo voltar
  /// (Fase 8D). A aba Sincronizar diz por que a fila não saiu.
  bool get isWaitingForCatalog => _waitingForCatalog;
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
    _queue = const [];
    _lastSyncedAt = null;
```

por:

```dart
    _catalogSubscription?.cancel();
    _queue = const [];
    _lastSyncedAt = null;
    _waitingForCatalog = false;
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
        _lastSyncedAt = at;
        notifyListeners();
      },
      onError: (Object error) =>
          debugPrint('Leitura da última sincronização falhou: $error'),
```

por:

```dart
        // Ver [lastSyncedAt]: um horário anterior ao que a tela já mostra é
        // o de um envio mais antigo, que sobrou no banco.
        final last = _lastSyncedAt;
        if (at == null || (last != null && !at.isAfter(last))) return;
        _lastSyncedAt = at;
        notifyListeners();
      },
      onError: (Object error) =>
          debugPrint('Leitura da última sincronização falhou: $error'),
    );
    _catalogSubscription = _assessments.watchHasCatalog().listen(
      (hasCatalog) {
        if (!hasCatalog || !_waitingForCatalog) return;
        _waitingForCatalog = false;
        notifyListeners();
        unawaited(syncNow());
      },
      onError: (Object error) =>
          debugPrint('Leitura do catálogo falhou: $error'),
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
      return;
    }
    if (await _assessments.waitsForCatalog(batch)) {
      // Ver `AssessmentRepository.waitsForCatalog`: a fila espera, sem erro,
      // e tenta de novo pela espera crescente — até a Home baixar o catálogo.
      _scheduleRetry();
      return;
    }
```

por:

```dart
      _setWaitingForCatalog(false);
      return;
    }
    if (await _assessments.waitsForCatalog(batch)) {
      // Ver `AssessmentRepository.waitsForCatalog`: a fila espera, sem erro.
      // Ela sai assim que o catálogo voltar (ver [isWaitingForCatalog]); a
      // espera crescente fica como rede de segurança.
      _setWaitingForCatalog(true);
      _scheduleRetry();
      return;
    }
    _setWaitingForCatalog(false);
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
            outcome.containsKey(id) ? outcome[id] : SendFailure.refused;
```

por:

```dart
            outcome.containsKey(id) ? outcome[id] : SendFailure.sendFailed;
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
    return SendFailure.refused;
```

por:

```dart
    return SendFailure.sendFailed;
  }

  void _setWaitingForCatalog(bool waiting) {
    if (_waitingForCatalog == waiting) return;
    _waitingForCatalog = waiting;
    notifyListeners();
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
    _lastSyncedSubscription?.cancel();
    _reconnectSubscription?.cancel();
```

por:

```dart
    _lastSyncedSubscription?.cancel();
    _catalogSubscription?.cancel();
    _reconnectSubscription?.cancel();
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
import '../core/widgets/app_nav_bar.dart';
import '../core/widgets/status_chip.dart';
```

por:

```dart
import '../core/widgets/app_nav_bar.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/status_chip.dart';
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
            if (isOffline && queue.isNotEmpty) _buildOfflineCard(queue.length),
            if (queue.isEmpty)
```

por:

```dart
            if (isOffline && queue.isNotEmpty) _buildOfflineCard(queue.length),
            if (!isOffline && queue.isNotEmpty && sync.isWaitingForCatalog)
              _buildCatalogNotice(),
            if (queue.isEmpty)
```

Em `lib/ui/sync/sync_screen.dart`, substituir:

```dart
          ],
        ),
      ),
    );
```

por:

```dart
          ],
        ),
      ),
    );
  }

  /// A fila espera o catálogo que o "Limpar cache local" apagou (Fase 8D —
  /// não está no canvas): diz por que ela não sai, e que sai sozinha.
  Widget _buildCatalogNotice() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
      child: InlineNotice(
        key: Key('sync-catalog-notice'),
        icon: AppIcons.info,
        message: 'A fila espera o catálogo de avaliação, apagado do aparelho '
            'pelo "Limpar cache local". Ela sai sozinha quando a aba Sessões '
            'baixar o catálogo de novo.',
      ),
    );
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/data/services/assessment_sync_service_test.dart test/data/repositories/assessment_repository_test.dart test/ui/sync`
Esperado: `+117: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1178: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/data/repositories/assessment_repository.dart apps/mobile/simtc/lib/data/services/assessment_sync_service.dart apps/mobile/simtc/lib/ui/sync/sync_screen.dart apps/mobile/simtc/test/data/repositories/assessment_repository_test.dart apps/mobile/simtc/test/data/services/assessment_sync_service_test.dart apps/mobile/simtc/test/support/fake_assessment_sync_service.dart apps/mobile/simtc/test/ui/sync/sync_screen_test.dart
git commit -m "fix(mobile): envio que tenta de novo o erro do lote e sai quando o catalogo volta"
```

---

## Task 2: Login e saída que não ficam pela metade

Itens 5, 6, 8 e 12 do desenho. A recusa da renovação só encerra a sessão se o refresh token guardado ainda é o que foi usado. O "Sair" roda cada passo da limpeza mesmo que o anterior falhe, e o `TokenStorage.clear` apaga cada chave e, se alguma ficou, desliga o "manter conectado". A keystore que falha ao entrar não derruba o login. A entrada sem rede só usa o perfil salvo do dono do token. E a abertura espera o servidor no máximo 5 s.

**Files:**
- Modify: `lib/data/repositories/auth_repository.dart`
- Modify: `lib/data/services/api/api_client.dart`
- Modify: `lib/data/services/auth_session.dart`
- Modify: `lib/data/services/local/token_storage.dart`
- Modify: `test/data/repositories/auth_repository_test.dart`
- Modify: `test/data/services/api/api_client_test.dart`
- Modify: `test/data/services/local/token_storage_test.dart`

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces:
  - `AuthRepository(restoreTimeout:)`, com `AuthRepository.defaultRestoreTimeout` = 5 s
  - `AuthSession.updateTokens`, `start` e `expire` que não lançam por falha do armazenamento
  - `TokenStorage.clear()` que tenta todas as chaves e lança a primeira falha no fim

- [ ] **Step 1: Escrever os testes que falham**

Em `test/data/repositories/auth_repository_test.dart`, substituir:

```dart
    void stubSavedTokens() {
      when(() => storage.readAccess()).thenAnswer((_) async => accessToken);
      when(() => storage.readRefresh()).thenAnswer((_) async => 'refresh-1');
```

por:

```dart
    /// O token salvo é da Carla (`user-1`): o perfil salvo só vale se for
    /// dela (Fase 8D).
    final tokenDaCarla = fakeJwt({'sub': 'user-1'});

    void stubSavedTokens() {
      when(() => storage.readAccess()).thenAnswer((_) async => tokenDaCarla);
      when(() => storage.readRefresh()).thenAnswer((_) async => 'refresh-1');
    }

    void stubSavedUser(String id) {
      when(() => storage.readUser()).thenAnswer((_) async => jsonEncode(AuthUser(
            id: id,
            name: 'Carla',
            email: 'c@s.com',
            role: AppUserRole.consultant,
          ).toJson()));
```

Em `test/data/repositories/auth_repository_test.dart`, substituir:

```dart
    });

    test('falha ao gravar o perfil não impede o login', () async {
      stubLogin(token: fakeJwt({'sub': 'user-1'}));
```

por:

```dart
    });

    test(
        'falha ao gravar o "manter conectado" ou os tokens não impede o login '
        '(Fase 8D)', () async {
      stubLogin(token: fakeJwt({'sub': 'user-1'}));
      stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});
      when(() => storage.setKeepSignedIn(any()))
          .thenThrow(PlatformException(code: 'keystore'));
      when(() => storage.persist(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          )).thenThrow(PlatformException(code: 'keystore'));

      final result = await repository.login(
        email: 'c@s.com',
        password: '123456',
        keepSignedIn: true,
      );

      expect(result, isA<Success<AuthUser>>());
      expect(repository.isAuthenticated, isTrue);
      expect(await session.readRefreshToken(), 'refresh-1',
          reason: 'a sessão vale em memória');
      verify(() => storage.clear()).called(1);
    });

    test('falha ao gravar o perfil não impede o login', () async {
      stubLogin(token: fakeJwt({'sub': 'user-1'}));
```

Em `test/data/repositories/auth_repository_test.dart`, substituir:

```dart
      expect(await session.readAccessToken(), accessToken,
          reason: 'quando a rede voltar, é este token que o servidor confere');
```

por:

```dart
      expect(await session.readAccessToken(), tokenDaCarla,
          reason: 'quando a rede voltar, é este token que o servidor confere');
    });

    test(
        'o perfil salvo de outra pessoa (a keystore falhou no login) não abre '
        'o app sem rede: vai para o login (Fase 8D)', () async {
      stubSavedTokens();
      when(() => api.get<Map<String, dynamic>>('/auth/me')).thenThrow(semRede);
      stubSavedUser('user-2');

      final result = await repository.restoreSession();

      expect(result, isA<Failure<AuthUser>>());
      expect(repository.isAuthenticated, isFalse);
    });

    test(
        'um token que não se lê também não abre o app com o perfil salvo '
        '(Fase 8D)', () async {
      when(() => storage.readAccess()).thenAnswer((_) async => 'não-é-jwt');
      when(() => storage.readRefresh()).thenAnswer((_) async => 'refresh-1');
      when(() => api.get<Map<String, dynamic>>('/auth/me')).thenThrow(semRede);
      stubSavedUser('user-1');

      final result = await repository.restoreSession();

      expect(result, isA<Failure<AuthUser>>());
    });

    test(
        'com sinal ruim, a abertura não espera o servidor além do limite: '
        'entra com o perfil salvo (Fase 8D)', () async {
      repository = AuthRepository(
        apiClient: api,
        session: session,
        clearLocalCache: db.clearSessionsCache,
        restoreTimeout: const Duration(milliseconds: 10),
      );
      stubSavedTokens();
      when(() => api.get<Map<String, dynamic>>('/auth/me'))
          .thenAnswer((_) => Completer<Response<Map<String, dynamic>>>().future);
      stubSavedUser('user-1');

      final result = await repository.restoreSession();

      expect(result, isA<Success<AuthUser>>());
      expect(repository.currentUser!.id, 'user-1');
      verifyNever(() => storage.clear());
    });

    test(
        'com sinal ruim e sem perfil salvo, vai para o login com o motivo '
        '(Fase 8D)', () async {
      repository = AuthRepository(
        apiClient: api,
        session: session,
        clearLocalCache: db.clearSessionsCache,
        restoreTimeout: const Duration(milliseconds: 10),
      );
      stubSavedTokens();
      when(() => api.get<Map<String, dynamic>>('/auth/me'))
          .thenAnswer((_) => Completer<Response<Map<String, dynamic>>>().future);

      final result = await repository.restoreSession();

      expect(result, isA<Failure<AuthUser>>());
      expect((result as Failure<AuthUser>).message,
          'O servidor demorou para responder. Verifique a internet e tente de '
          'novo.');
    });

    test('o limite padrão de espera da abertura é de 5 segundos (Fase 8D)', () {
      expect(AuthRepository.defaultRestoreTimeout, const Duration(seconds: 5));
```

Em `test/data/repositories/auth_repository_test.dart`, substituir:

```dart
  });

  test('o limite padrão de espera do logout é de 5 segundos', () {
    expect(AuthRepository.defaultLogoutTimeout, const Duration(seconds: 5));
```

por:

```dart
  });

  group('"Sair" que falha no meio (Fase 8D)', () {
    Future<void> loggedIn() async {
      stubLogin(token: fakeJwt({'sub': 'user-1'}));
      stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});
      await repository.login(email: 'c@s.com', password: '123456', keepSignedIn: true);
      when(() => api.post<void>('/auth/logout')).thenAnswer(
          (_) async => Response<void>(requestOptions: RequestOptions(path: '/auth/logout')));
    }

    test('a keystore que não apaga não impede apagar o cache, e o usuário sai',
        () async {
      await loggedIn();
      await seedCache();
      when(() => storage.clear()).thenThrow(PlatformException(code: 'keystore'));

      await repository.logout();

      expect(repository.isAuthenticated, isFalse);
      expect(await session.readAccessToken(), isNull);
      expect(await db.select(db.sessions).get(), isEmpty);
    });

    test('o banco que não apaga também não segura o usuário', () async {
      repository = AuthRepository(
        apiClient: api,
        session: session,
        clearLocalCache: () async => throw Exception('disco cheio'),
      );
      await loggedIn();

      await repository.logout();

      expect(repository.isAuthenticated, isFalse);
      verify(() => storage.clear()).called(greaterThanOrEqualTo(1));
    });
  });

  test(
      'a sessão que expira avisa o app mesmo que o armazenamento falhe ao '
      'apagar (Fase 8D)', () async {
    when(() => storage.clear()).thenThrow(PlatformException(code: 'keystore'));
    final expired = session.onExpired.first;

    await session.expire();

    await expectLater(expired, completes);
    expect(await session.readAccessToken(), isNull);
  });

  test('o limite padrão de espera do logout é de 5 segundos', () {
    expect(AuthRepository.defaultLogoutTimeout, const Duration(seconds: 5));
```

Em `test/data/services/api/api_client_test.dart`, substituir:

```dart
  const _Reply(this.statusCode, [this.body = const <String, dynamic>{}])
      : networkError = null;

  /// A requisição falha sem chegar a ter resposta (sem rede, tempo esgotado).
  const _Reply.network(DioExceptionType this.networkError)
      : statusCode = 0,
        body = const <String, dynamic>{};

  final int statusCode;
  final Map<String, dynamic> body;
  final DioExceptionType? networkError;
```

por:

```dart
  const _Reply(
    this.statusCode, [
    this.body = const <String, dynamic>{},
    this.delay = Duration.zero,
  ]) : networkError = null;

  /// A requisição falha sem chegar a ter resposta (sem rede, tempo esgotado).
  const _Reply.network(DioExceptionType this.networkError)
      : statusCode = 0,
        body = const <String, dynamic>{},
        delay = Duration.zero;

  final int statusCode;
  final Map<String, dynamic> body;
  final DioExceptionType? networkError;

  /// Quanto a resposta demora a chegar.
  final Duration delay;
```

Em `test/data/services/api/api_client_test.dart`, substituir:

```dart
    final reply = replies.removeAt(0);
    if (reply.networkError != null) {
```

por:

```dart
    final reply = replies.removeAt(0);
    await Future<void>.delayed(reply.delay);
    if (reply.networkError != null) {
```

Em `test/data/services/api/api_client_test.dart`, substituir:

```dart
    expect(accessToken, isNull);
    expect(refreshToken, isNull);
    expect(sessionExpiredCalls, 0);
  });

  group('renovação sem resposta do servidor mantém a sessão', () {
```

por:

```dart
    expect(accessToken, isNull);
    expect(refreshToken, isNull);
    expect(sessionExpiredCalls, 0);
  });

  group('a recusa da renovação que chega depois de um login novo (Fase 8D)', () {
    /// O 401 da chamada e a resposta da renovação, que demora 50 ms: no
    /// meio dela, outra pessoa entra no aparelho.
    Future<void> loginDuringRefresh(_Reply refreshReply) async {
      final client = buildClient([
        const _Reply(401, {'message': 'Unauthorized'}),
        refreshReply,
      ]);

      final request = client.get<Map<String, dynamic>>('/training-sessions');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      accessToken = 'token-de-quem-entrou';
      refreshToken = 'refresh-de-quem-entrou';

      await expectLater(
        request,
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    }

    test('um 4xx do token antigo não derruba a sessão nova', () async {
      await loginDuringRefresh(const _Reply(
        401,
        {'message': 'Refresh token inválido ou expirado'},
        Duration(milliseconds: 50),
      ));

      expect(sessionExpiredCalls, 0);
      expect(accessToken, 'token-de-quem-entrou');
      expect(refreshToken, 'refresh-de-quem-entrou');
    });

    test('nem a resposta sem tokens', () async {
      await loginDuringRefresh(
        const _Reply(200, <String, dynamic>{}, Duration(milliseconds: 50)),
      );

      expect(sessionExpiredCalls, 0);
      expect(refreshToken, 'refresh-de-quem-entrou');
    });

    test('a mesma recusa, sem login no meio, encerra a sessão', () async {
      final client = buildClient([
        const _Reply(401, {'message': 'Unauthorized'}),
        const _Reply(200, <String, dynamic>{}),
      ]);

      await expectLater(
        client.get<Map<String, dynamic>>('/training-sessions'),
        throwsA(isA<ApiException>()),
      );
      expect(sessionExpiredCalls, 1);
    });
  });

  group('renovação sem resposta do servidor mantém a sessão', () {
```

Em `test/data/services/local/token_storage_test.dart`, substituir:

```dart
  });

  test('deleteUser apaga só o perfil salvo, sem mexer nos tokens', () async {
    final secure = _MockSecureStorage();
```

por:

```dart
  });

  test(
      'uma chave que não apaga não impede as outras; o "manter conectado" é '
      'desligado e a falha sobe no fim (Fase 8D)', () async {
    final secure = _MockSecureStorage();
    when(() => secure.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(() => secure.delete(key: 'auth.accessToken'))
        .thenThrow(Exception('keystore'));
    when(() => secure.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    final storage = TokenStorage(storage: secure);

    await expectLater(storage.clear(), throwsException);

    verify(() => secure.delete(key: 'auth.refreshToken')).called(1);
    verify(() => secure.delete(key: 'auth.user')).called(1);
    verify(() => secure.write(key: 'auth.keepSignedIn', value: 'false')).called(1);
  });

  test('deleteUser apaga só o perfil salvo, sem mexer nos tokens', () async {
    final secure = _MockSecureStorage();
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/data/services/api/api_client_test.dart test/data/repositories/auth_repository_test.dart test/data/services/local/token_storage_test.dart`
Esperado: `+21 -5: Some tests failed.` — `auth_repository_test.dart` não compila (`No named parameter with the name 'restoreTimeout'`, `Member not found: 'defaultRestoreTimeout'`); falham os dois testes da renovação depois de um login novo e o do `clear` que tenta todas as chaves.

- [ ] **Step 3: Implementar**

Em `lib/data/repositories/auth_repository.dart`, substituir:

```dart
    this.logoutTimeout = defaultLogoutTimeout,
  })  : _api = apiClient,
```

por:

```dart
    this.logoutTimeout = defaultLogoutTimeout,
    this.restoreTimeout = defaultRestoreTimeout,
  })  : _api = apiClient,
```

Em `lib/data/repositories/auth_repository.dart`, substituir:

```dart
  final Duration logoutTimeout;

  static const Duration defaultLogoutTimeout = Duration(seconds: 5);

  final ApiClient _api;
  final AuthSession _session;
```

por:

```dart
  final Duration logoutTimeout;

  static const Duration defaultLogoutTimeout = Duration(seconds: 5);

  /// Quanto a abertura espera o servidor confirmar a sessão salva. Com sinal
  /// ruim ("conectado mas sem dados") seriam até 35 s de splash; passado
  /// isto, a abertura entra como se estivesse sem rede (Fase 8D).
  final Duration restoreTimeout;

  static const Duration defaultRestoreTimeout = Duration(seconds: 5);

  final ApiClient _api;
  final AuthSession _session;
```

Em `lib/data/repositories/auth_repository.dart`, substituir:

```dart
  /// offline: aí o problema não é o sinal.
```

por:

```dart
  /// offline: aí o problema não é o sinal. O servidor que não responde em
  /// [restoreTimeout] conta como sem rede.
  ///
  /// O perfil salvo só vale se for de quem é dono do token (Fase 8D): uma
  /// falha da keystore no login pode ter deixado o perfil de quem entrou
  /// antes, e a entrada sem rede não pode abrir o app no nome de outra pessoa.
```

Em `lib/data/repositories/auth_repository.dart`, substituir:

```dart
    try {
      final accessToken = await _session.readAccessToken();
      final user = await _loadCurrentUser(accessToken ?? '');
```

por:

```dart
    final accessToken = await _session.readAccessToken() ?? '';
    try {
      final user = await _loadCurrentUser(accessToken).timeout(restoreTimeout);
```

Em `lib/data/repositories/auth_repository.dart`, substituir:

```dart
    } on ApiException catch (error) {
      if (error.isNetworkError) {
        final saved = await _session.readSavedUser();
        if (saved != null) {
          _currentUser = saved;
          notifyListeners();
          return Success(saved);
        }
        return Failure(error, error.message);
      }
      if (error.statusCode == 401) await _session.clear();
      return Failure(error, _sessionEnded);
    }
```

por:

```dart
    } on TimeoutException {
      return _enterOffline(accessToken, _restoreTimedOut);
    } on ApiException catch (error) {
      if (error.isNetworkError) return _enterOffline(accessToken, error);
      if (error.statusCode == 401) await _session.clear();
      return Failure(error, _sessionEnded);
    }
  }

  static const ApiException _restoreTimedOut = ApiException(
    message: 'O servidor demorou para responder. Verifique a internet e tente '
        'de novo.',
    isNetworkError: true,
    isTimeout: true,
  );

  /// A abertura sem resposta do servidor: entra com o perfil salvo, se ele
  /// for do dono do token (ver [restoreSession]).
  Future<Result<AuthUser>> _enterOffline(
    String accessToken,
    ApiException error,
  ) async {
    final saved = await _session.readSavedUser();
    final owner = decodeJwtPayload(accessToken)?['sub'];
    if (saved != null && saved.id == owner) {
      _currentUser = saved;
      notifyListeners();
      return Success(saved);
    }
    return Failure(error, error.message);
```

Em `lib/data/repositories/auth_repository.dart`, substituir:

```dart
  }

  Future<void> logout() async {
    try {
```

por:

```dart
  }

  /// Nunca para no meio (Fase 8D): cada passo da limpeza roda mesmo que o
  /// anterior falhe (a keystore, o banco), e o usuário sai do mesmo jeito.
  /// Deixar o aparelho pela metade seria pior: o "Sair" de novo pode falhar
  /// igual, e o próximo a entrar herdaria a sessão.
  Future<void> logout() async {
    try {
```

Em `lib/data/repositories/auth_repository.dart`, substituir:

```dart
    await _session.clear();
    await _clearLocalCache();
```

por:

```dart
    try {
      await _session.clear();
    } catch (_) {
      // Os tokens já saíram da memória, e `TokenStorage.clear` desligou o
      // "manter conectado": a próxima abertura vai ao login.
    }
    try {
      await _clearLocalCache();
    } catch (_) {
      // O cache de sessões que sobrar é baixado de novo por quem entrar.
    }
```

Em `lib/data/services/api/api_client.dart`, substituir:

```dart
      if (accessToken == null || newRefreshToken == null) {
        await onSessionExpired();
        return const _Refresh.expired();
      }
```

por:

```dart
      if (accessToken == null || newRefreshToken == null) {
        return _expire(refreshToken);
      }
```

Em `lib/data/services/api/api_client.dart`, substituir:

```dart
        await onSessionExpired();
        return const _Refresh.expired();
      }
      return _Refresh.failed(refreshError);
    }
```

por:

```dart
        return _expire(refreshToken);
      }
      return _Refresh.failed(refreshError);
    }
  }

  /// O servidor não renovou [usedRefreshToken]: a sessão dele acabou. Só
  /// avisa o app se ela ainda é a sessão de agora — a resposta pode chegar
  /// depois de um login novo, e derrubar a sessão nova por causa do token
  /// antigo mandaria quem acabou de entrar de volta ao login (Fase 8D).
  Future<_Refresh> _expire(String usedRefreshToken) async {
    if (await readRefreshToken() == usedRefreshToken) await onSessionExpired();
    return const _Refresh.expired();
```

Em `lib/data/services/auth_session.dart`, substituir:

```dart
    await _storage.setKeepSignedIn(keepSignedIn);
    // O perfil salvo é do login anterior. Apagá-lo antes de gravar os tokens
    // novos garante que um par de tokens nunca fique com o perfil de outra
    // pessoa — nem se o app morrer antes do `saveUser` deste login. Se a
    // keystore falhar aqui, o login segue: o `saveUser` logo depois grava por
    // cima o perfil certo, e só o app morrendo entre os dois deixaria o
    // perfil antigo — melhor do que não deixar ninguém entrar.
```

por:

```dart
    // Uma falha da keystore não derruba o login (Fase 8D): a sessão vale em
    // memória do mesmo jeito, e só a próxima abertura sente a falta.
    try {
      await _storage.setKeepSignedIn(keepSignedIn);
    } catch (_) {
      // Ver acima.
    }
    // O perfil salvo é do login anterior. Apagá-lo antes de gravar os tokens
    // novos garante que um par de tokens nunca fique com o perfil de outra
    // pessoa — nem se o app morrer antes do `saveUser` deste login. Se a
    // keystore falhar aqui, o login segue: o `saveUser` logo depois grava por
    // cima o perfil certo. Se ele também falhar, o perfil antigo fica, mas a
    // entrada sem rede confere de quem ele é (`AuthRepository.restoreSession`).
```

Em `lib/data/services/auth_session.dart`, substituir:

```dart
  Future<void> updateTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (_keepSignedIn) {
      await _storage.persist(accessToken: accessToken, refreshToken: refreshToken);
```

por:

```dart
  ///
  /// Nunca lança (Fase 8D): sem gravar, a sessão vale enquanto o app estiver
  /// aberto. O que sobrou no aparelho é apagado, para a próxima abertura não
  /// voltar com um par de tokens velho ou pela metade.
  Future<void> updateTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (!_keepSignedIn) return;
    try {
      await _storage.persist(accessToken: accessToken, refreshToken: refreshToken);
    } catch (_) {
      try {
        await _storage.clear();
      } catch (_) {
        // Tokens que sobrarem são recusados pelo servidor na próxima abertura.
      }
```

Em `lib/data/services/auth_session.dart`, substituir:

```dart
  /// Chamado pelo `ApiClient` quando não dá mais para renovar o token.
  Future<void> expire() async {
    await clear();
```

por:

```dart
  /// Chamado pelo `ApiClient` quando não dá mais para renovar o token. Avisa
  /// mesmo que o armazenamento falhe ao apagar (Fase 8D): os tokens já saíram
  /// da memória, e o app precisa ir ao login.
  Future<void> expire() async {
    try {
      await clear();
    } catch (_) {
      // Ver acima; `TokenStorage.clear` já desligou o "manter conectado".
    }
```

Em `lib/data/services/local/token_storage.dart`, substituir:

```dart
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
```

por:

```dart
  /// Apaga cada chave mesmo que outra falhe, e lança a primeira falha no
  /// fim (Fase 8D). Se algo ficou, desliga o "manter conectado": a próxima
  /// abertura não retoma a sessão de quem saiu, e vai ao login.
  Future<void> clear() async {
    Object? failure;
    for (final key in [_accessKey, _refreshKey, _userKey]) {
      try {
        await _storage.delete(key: key);
      } catch (error) {
        failure ??= error;
      }
    }
    if (failure == null) return;
    try {
      await setKeepSignedIn(false);
    } catch (_) {
      // A keystore inteira falhou: não há o que mais fazer aqui.
    }
    throw failure;
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/data/services/api/api_client_test.dart test/data/repositories/auth_repository_test.dart test/data/services/local/token_storage_test.dart`
Esperado: `+59: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1191: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/data/repositories/auth_repository.dart apps/mobile/simtc/lib/data/services/api/api_client.dart apps/mobile/simtc/lib/data/services/auth_session.dart apps/mobile/simtc/lib/data/services/local/token_storage.dart apps/mobile/simtc/test/data/repositories/auth_repository_test.dart apps/mobile/simtc/test/data/services/api/api_client_test.dart apps/mobile/simtc/test/data/services/local/token_storage_test.dart
git commit -m "fix(mobile): login e saida que nao ficam pela metade"
```

---

## Task 3: Troca de servidor que não apagou o aparelho

Item 7 do desenho. Se o banco não consegue apagar tudo na troca de servidor, a abertura não segue nem para o login, que levaria a fila do servidor antigo para o novo. A splash mostra o aviso e o "Tentar de novo" no lugar da barra, e o endereço novo não é guardado: a próxima abertura também tenta de novo.

**Files:**
- Modify: `lib/data/services/device_data_service.dart`
- Modify: `lib/ui/splash/splash_screen.dart`
- Modify: `lib/ui/splash/splash_viewmodel.dart`
- Modify: `test/data/services/device_data_service_test.dart`
- Modify: `test/ui/splash/splash_screen_test.dart`
- Modify: `test/ui/splash/splash_viewmodel_test.dart`

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces:
  - `enum SplashOutcome { home, login, resetFailed }`
  - `SplashViewModel.decideInitialRoute(): Future<SplashOutcome>` (antes devolvia `bool`)

- [ ] **Step 1: Escrever os testes que falham**

Em `test/data/services/device_data_service_test.dart`, substituir:

```dart
  }
}
```

por:

```dart
  }
}

/// O banco que não consegue apagar tudo (disco cheio, arquivo preso).
class _FailingClearDatabase extends AppDatabase {
  _FailingClearDatabase() : super(NativeDatabase.memory());

  @override
  Future<void> clearAll() async => throw Exception('disco cheio');
}
```

Em `test/data/services/device_data_service_test.dart`, substituir:

```dart
    });

    test('falha ao apagar o login ou os logos não impede a troca', () async {
      await seed();
```

por:

```dart
    });

    test(
        'o banco que não apaga: lança, e o endereço novo não é guardado — a '
        'próxima tentativa apaga de novo (Fase 8D)', () async {
      final failing = _FailingClearDatabase();
      addTearDown(failing.close);
      final service = DeviceDataService(
        database: failing,
        storage: storage,
        logos: logos,
      );
      when(() => storage.readApiBaseUrl()).thenAnswer((_) async => local);

      await expectLater(service.resetIfServerChanged(production), throwsException);

      verifyNever(() => storage.saveApiBaseUrl(any()));
    });

    test('falha ao apagar o login ou os logos não impede a troca', () async {
      await seed();
```

Em `test/ui/splash/splash_screen_test.dart`, substituir:

```dart
  }
}
```

por:

```dart
  }

  group('troca de servidor que não apagou o aparelho (Fase 8D)', () {
    testWidgets('avisa no lugar da barra, e o "Tentar de novo" confere de novo',
        (tester) async {
      var attempts = 0;
      when(() => deviceData.resetIfServerChanged(any())).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) throw Exception('disco cheio');
        return true;
      });

      await show(tester, size: const Size(412, 915));
      await tester.pump();

      expect(find.byKey(const Key('splash-reset-failed')), findsOneWidget);
      expect(
        find.text('Não foi possível preparar o aparelho para o novo servidor. '
            'Tente de novo.'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      verifyNever(() => auth.restoreSession());

      await tester.tap(find.text('Tentar de novo'));
      await tester.pump();
      await tester.pump();

      expect(attempts, 2);
      expect(find.byKey(const Key('splash-reset-failed')), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      verify(() => auth.restoreSession()).called(1);
    });
  });
}
```

Em `test/ui/splash/splash_viewmodel_test.dart`, substituir:

```dart
    expect(await viewModel.decideInitialRoute(), isTrue);
```

por:

```dart
    expect(await viewModel.decideInitialRoute(), SplashOutcome.home);
```

Em `test/ui/splash/splash_viewmodel_test.dart`, substituir:

```dart
    expect(await viewModel.decideInitialRoute(), isFalse);
```

por:

```dart
    expect(await viewModel.decideInitialRoute(), SplashOutcome.login);
  });

  test(
      'a troca de servidor que não apagou o aparelho não segue nem para o '
      'login (Fase 8D)', () async {
    when(() => deviceData.resetIfServerChanged(any()))
        .thenThrow(Exception('disco cheio'));
    final viewModel = SplashViewModel(authRepository: auth, deviceData: deviceData);
    addTearDown(viewModel.dispose);

    expect(await viewModel.decideInitialRoute(), SplashOutcome.resetFailed);
    verifyNever(() => auth.restoreSession());
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/splash test/data/services/device_data_service_test.dart`
Esperado: `+12 -3: Some tests failed.` — `splash_viewmodel_test.dart` não compila (`Undefined name 'SplashOutcome'`), e falha o teste da splash com a troca de servidor que não apagou.

- [ ] **Step 3: Implementar**

Em `lib/data/services/device_data_service.dart`, substituir:

```dart
  /// que o risco que a limpeza evita.
  Future<bool> resetIfServerChanged(String apiBaseUrl) async {
```

por:

```dart
  /// que o risco que a limpeza evita.
  ///
  /// Se o banco não consegue apagar, lança, e o endereço novo não é guardado:
  /// a abertura não segue com a fila antiga, e a próxima tentativa apaga de
  /// novo (Fase 8D).
  Future<bool> resetIfServerChanged(String apiBaseUrl) async {
```

Em `lib/ui/splash/splash_screen.dart`, substituir:

```dart
import '../core/theme/app_spacing.dart';
import 'splash_viewmodel.dart';

/// Tela 1.1 do canvas: logo centralizada e uma barra fina de progresso,
/// enquanto o app tenta retomar a sessão salva. Sem texto de carregamento.
```

por:

```dart
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import 'splash_viewmodel.dart';

/// Tela 1.1 do canvas: logo centralizada e uma barra fina de progresso,
/// enquanto o app tenta retomar a sessão salva. Sem texto de carregamento.
///
/// Só a troca de servidor que não conseguiu apagar o aparelho tem texto
/// (Fase 8D — não está no canvas): o aviso e o "Tentar de novo" no lugar da
/// barra.
```

Em `lib/ui/splash/splash_screen.dart`, substituir:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
```

por:

```dart
  bool _resetFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  void _retry() {
    setState(() => _resetFailed = false);
    _decide();
```

Em `lib/ui/splash/splash_screen.dart`, substituir:

```dart
    var isSignedIn = false;
    try {
      isSignedIn = await viewModel.decideInitialRoute();
```

por:

```dart
    var outcome = SplashOutcome.login;
    try {
      outcome = await viewModel.decideInitialRoute();
```

Em `lib/ui/splash/splash_screen.dart`, substituir:

```dart
    context.go(isSignedIn ? AppRoutes.home : AppRoutes.login);
```

por:

```dart
    if (outcome == SplashOutcome.resetFailed) {
      setState(() => _resetFailed = true);
      return;
    }
    context.go(outcome == SplashOutcome.home ? AppRoutes.home : AppRoutes.login);
```

Em `lib/ui/splash/splash_screen.dart`, substituir:

```dart
            _buildProgress(width: tablet ? _tabletBarWidth : 140),
```

por:

```dart
            if (_resetFailed)
              _buildResetFailed()
            else
              _buildProgress(width: tablet ? _tabletBarWidth : 140),
```

Em `lib/ui/splash/splash_screen.dart`, substituir:

```dart
  }

  Widget _buildProgress({required double width}) {
    return SizedBox(
```

por:

```dart
  }

  static const double _noticeMaxWidth = 360;

  Widget _buildResetFailed() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _noticeMaxWidth),
        child: Column(
          key: const Key('splash-reset-failed'),
          children: [
            Text(
              'Não foi possível preparar o aparelho para o novo servidor. '
              'Tente de novo.',
              style: AppTypography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCtaButton(
              label: 'Tentar de novo',
              icon: AppIcons.retry,
              onPressed: _retry,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress({required double width}) {
    return SizedBox(
```

Em `lib/ui/splash/splash_viewmodel.dart`, substituir:

```dart
import '../../data/services/device_data_service.dart';
import '../../utils/result.dart';

/// Decide, na abertura, se o app vai para a Home ou para o Login.
```

por:

```dart
import '../../data/services/device_data_service.dart';
import '../../utils/result.dart';

/// Para onde a abertura vai.
enum SplashOutcome {
  home,
  login,

  /// O app fala com outro servidor e não conseguiu apagar o que era do
  /// anterior: a abertura para e avisa (Fase 8D).
  resetFailed,
}

/// Decide, na abertura, se o app vai para a Home ou para o Login.
```

Em `lib/ui/splash/splash_viewmodel.dart`, substituir:

```dart
  /// tenta retomar a sessão salva. Devolve true quando consegue.
  Future<bool> decideInitialRoute() async {
    await _deviceData.resetIfServerChanged(apiBaseUrl);
    final result = await _authRepository.restoreSession();
    return result is Success;
```

por:

```dart
  /// tenta retomar a sessão salva.
  ///
  /// Se a troca de servidor não conseguiu apagar o aparelho, não segue nem
  /// para o login: quem entrasse levaria a fila do servidor anterior para o
  /// novo, com ids que lá não existem.
  Future<SplashOutcome> decideInitialRoute() async {
    try {
      await _deviceData.resetIfServerChanged(apiBaseUrl);
    } catch (_) {
      return SplashOutcome.resetFailed;
    }
    final result = await _authRepository.restoreSession();
    return result is Success ? SplashOutcome.home : SplashOutcome.login;
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/splash test/data/services/device_data_service_test.dart`
Esperado: `+17: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1194: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/data/services/device_data_service.dart apps/mobile/simtc/lib/ui/splash/splash_screen.dart apps/mobile/simtc/lib/ui/splash/splash_viewmodel.dart apps/mobile/simtc/test/data/services/device_data_service_test.dart apps/mobile/simtc/test/ui/splash/splash_screen_test.dart apps/mobile/simtc/test/ui/splash/splash_viewmodel_test.dart
git commit -m "fix(mobile): troca de servidor que nao apagou avisa na abertura"
```

---

## Task 4: Checklist com o participante liberado e o aviso de outra avaliação em dia

Itens 9, 10, 19 e 21 do desenho. Com o participante fora das mãos do consultor, os B/PM/M não marcam. O aviso "Você já está avaliando…" é conferido de novo sempre que as avaliações do aparelho ou os participantes mudam (`watchInProgressChanges`). O "Não salvo" sai com o descarte. Com a leitura que falhou, o "salvo" e o ⋮ somem. E o "Desatribuindo…" é região viva para o leitor de tela.

**Files:**
- Modify: `lib/data/repositories/assessment_repository.dart`
- Modify: `lib/ui/checklist/checklist_screen.dart`
- Modify: `lib/ui/checklist/checklist_viewmodel.dart`
- Modify: `test/ui/checklist/checklist_screen_test.dart`
- Modify: `test/ui/checklist/checklist_viewmodel_test.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`

**Interfaces:**
- Consumes: `AssessmentRepository` da Task 1 (o mesmo arquivo; esta task acrescenta outro método).
- Produces:
  - `AssessmentRepository.watchInProgressChanges(): Stream<void>` (não emite ao assinar)
  - o `ChecklistViewModel` assina esse stream no `init`: todo dublê de `AssessmentRepository` em teste de tela que abre o checklist precisa responder a ele

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
    testWidgets(
        '"Iniciar avaliação" que não grava avisa e continua "não iniciada", '
```

por:

```dart
    testWidgets(
        'o "Não salvo" vai embora com a avaliação descartada (Fase 8D)',
        (tester) async {
      await pumpScreen(tester);
      await failWrites('local_assessment_items');
      await tester.tap(find.text('PM'));
      await tester.pumpAndSettle();
      expect(find.text('Não salvo'), findsOneWidget);
      await allowWrites('local_assessment_items');
      // O aviso passageiro da nota que não gravou sai antes de seguir.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checklist-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar avaliação'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar avaliação'));
      await tester.pumpAndSettle();

      expect(find.text('salvo'), findsOneWidget);
      expect(find.text('Não salvo'), findsNothing);
    });

    testWidgets(
        'com a leitura que falhou, o "salvo" e o ⋮ somem (Fase 8D)',
        (tester) async {
      await db.customStatement(
          'ALTER TABLE infraction_notes RENAME TO infraction_notes_fora');
      await pumpScreen(tester);

      expect(find.text('Não foi possível abrir a avaliação neste aparelho.'),
          findsOneWidget);
      expect(find.text('salvo'), findsNothing);
      expect(find.byKey(const Key('checklist-menu')), findsNothing);
    });

    testWidgets(
        '"Iniciar avaliação" que não grava avisa e continua "não iniciada", '
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
    expect(find.bySemanticsLabel('Desatribuindo…'), findsOneWidget);
    final finish = tester.widget<AppCtaButton>(
```

por:

```dart
    expect(find.bySemanticsLabel('Desatribuindo…'), findsOneWidget);
    // O leitor de tela anuncia a espera sozinho (Fase 8D).
    expect(
      tester.getSemantics(find.bySemanticsLabel('Desatribuindo…')),
      isSemantics(label: 'Desatribuindo…', isLiveRegion: true),
    );
    final finish = tester.widget<AppCtaButton>(
```

Em `test/ui/checklist/checklist_screen_test.dart`, substituir:

```dart
      // As marcações continuam na tela.
      expect(find.text(pmComment), findsOneWidget);
```

por:

```dart
      // As marcações continuam na tela, e as notas não marcam (Fase 8D).
      expect(find.text(pmComment), findsOneWidget);
      await tester.tap(find.text('M'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.text('M')),
          isSemantics(isSelected: false, hasTapAction: false));
      expect(tester.getSemantics(find.text('PM')), isSemantics(isSelected: true));
```

Em `test/ui/checklist/checklist_viewmodel_test.dart`, substituir:

```dart
        unorderedEquals(['tp-1', 'tp-2']),
      );
    });
  });

  // O participante saiu das mãos do consultor com a avaliação pela metade
```

por:

```dart
        unorderedEquals(['tp-1', 'tp-2']),
      );
    });

    test(
        'o aviso some sem reabrir a tela quando a outra avaliação é '
        'descartada (Fase 8D)', () async {
      await seedParticipant();
      await seedCatalog();
      await startOtherParticipant();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      expect(vm.isBlocked, isTrue);
      var notified = 0;
      vm.addListener(() => notified++);

      final other = await assessmentRepository.findByParticipant('tp-2');
      await assessmentRepository.discardDraft(other!.id);
      await pumpEventQueue();

      expect(vm.isBlocked, isFalse);
      expect(notified, greaterThan(0));
    });

    test(
        'o aviso some sem reabrir a tela quando o outro participante é '
        'liberado: a avaliação dele fica presa e não bloqueia (Fase 8D)',
        () async {
      await seedParticipant();
      await seedCatalog();
      await startOtherParticipant();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      expect(vm.isBlocked, isTrue);

      await (db.update(db.participants)..where((t) => t.id.equals('tp-2')))
          .write(const ParticipantsCompanion(
        status: Value('PENDENTE'),
        assignedConsultantId: Value(null),
      ));
      await pumpEventQueue();

      expect(vm.isBlocked, isFalse);
    });

    test(
        'o aviso aparece sem reabrir a tela quando outra avaliação começa '
        '(Fase 8D)', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      expect(vm.isBlocked, isFalse);

      await startOtherParticipant();
      await pumpEventQueue();

      expect(vm.isBlocked, isTrue);
      expect(vm.blockingParticipantName, 'Marina Lopes');
    });
  });

  // O participante saiu das mãos do consultor com a avaliação pela metade
```

Em `test/ui/checklist/checklist_viewmodel_test.dart`, substituir:

```dart
    });

    test('desatribuir com a avaliação antiga à espera também a apaga',
        () async {
```

por:

```dart
    });

    test(
        'com o participante liberado, as notas não marcam até ele ser '
        'atribuído de novo (Fase 8D)', () async {
      await seedParticipant(assignedConsultantId: 'c-eu');
      await seedCatalog();
      await seedOldDraft();
      final vm = await open();

      await setParticipant(status: 'PENDENTE');
      await pumpEventQueue();
      await vm.toggleNote('inf-1', 'note-m');

      expect(vm.isReleased, isTrue);
      expect(
        vm.sections.single.infractions.single.selectedNoteId,
        isNot('note-m'),
      );

      await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-eu');
      await pumpEventQueue();
      await vm.toggleNote('inf-1', 'note-m');

      expect(vm.sections.single.infractions.single.selectedNoteId, 'note-m');
    });

    test('desatribuir com a avaliação antiga à espera também a apaga',
        () async {
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
        )).thenAnswer((_) async => null);
  });
```

por:

```dart
        )).thenAnswer((_) async => null);
    // O checklist confere de novo se outra avaliação está em andamento
    // quando o aparelho muda (Fase 8D): aqui, nada muda.
    when(() => assessments.watchInProgressChanges())
        .thenAnswer((_) => const Stream.empty());
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/checklist test/ui/session_detail/session_detail_screen_test.dart`
Esperado: `+113 -10: Some tests failed.` — `session_detail_screen_test.dart` não compila (`The method 'watchInProgressChanges' isn't defined for the type '_MockAssessmentRepository'`); falham os testes novos do checklist (as notas com o liberado, o aviso recalculado, o "Não salvo" no descarte, a leitura que falhou e a região viva).

- [ ] **Step 3: Implementar**

Em `lib/data/repositories/assessment_repository.dart`, substituir:

```dart
  }

  /// Quantas avaliações [ownerUserId] iniciou e ainda não confirmou — todas,
  /// inclusive as presas (sessão concluída, participante liberado): a
```

por:

```dart
  }

  /// Avisa quando muda algo que decide se outra avaliação está em andamento
  /// ([findInProgressOther]): as avaliações do aparelho ou os participantes
  /// (um deles liberado prende a avaliação dele). Não emite ao assinar. O
  /// checklist confere de novo o "Você já está avaliando…" (Fase 8D).
  Stream<void> watchInProgressChanges() {
    return _db
        .tableUpdates(TableUpdateQuery.onAllTables([
          _db.localAssessments,
          _db.participants,
        ]))
        .map((_) {});
  }

  /// Quantas avaliações [ownerUserId] iniciou e ainda não confirmou — todas,
  /// inclusive as presas (sessão concluída, participante liberado): a
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
            if (!_viewModel.isLoading &&
                (_viewModel.canDiscard || _viewModel.canUnassign)) ...[
```

por:

```dart
            if (_showsMenu) ...[
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
              if (!_viewModel.isLoading &&
                  (_viewModel.canDiscard || _viewModel.canUnassign)) ...[
```

por:

```dart
              if (_showsMenu) ...[
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
  bool get _showsProgress =>
      !_viewModel.isLoading && _viewModel.hasCatalog && _viewModel.isStarted;

  Widget _buildBackButton(BuildContext context) {
```

por:

```dart
  bool get _showsProgress =>
      !_viewModel.isLoading && _viewModel.hasCatalog && _viewModel.isStarted;

  /// O ⋮ some com a leitura que falhou (Fase 8D): o que ele descartaria ou
  /// desatribuiria é o que a tela não conseguiu ler.
  bool get _showsMenu =>
      !_viewModel.isLoading &&
      !_viewModel.loadFailed &&
      (_viewModel.canDiscard || _viewModel.canUnassign);

  Widget _buildBackButton(BuildContext context) {
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
        child: Semantics(
          label: 'Desatribuindo…',
```

por:

```dart
        // `liveRegion`: o leitor de tela anuncia a espera assim que ela
        // aparece, sem o consultor tocar nela (Fase 8D).
        child: Semantics(
          label: 'Desatribuindo…',
          liveRegion: true,
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
        const SizedBox(width: AppSpacing.sm),
        Container(width: 1, height: 11, color: AppColors.borderStrong),
        const SizedBox(width: AppSpacing.sm),
        ..._buildSavedState(),
```

por:

```dart
        // Com a leitura que falhou, não há o que dizer que está salvo
        // (Fase 8D).
        if (!_viewModel.loadFailed) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(width: 1, height: 11, color: AppColors.borderStrong),
          const SizedBox(width: AppSpacing.sm),
          ..._buildSavedState(),
        ],
```

Em `lib/ui/checklist/checklist_screen.dart`, substituir:

```dart
              onTap: _viewModel.isConfirmed
```

por:

```dart
              onTap: _viewModel.isConfirmed || _viewModel.isReleased
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
  StreamSubscription<SessionParticipant?>? _participantSubscription;
  StreamSubscription<List<LocalAssessmentItem>>? _itemsSubscription;

  bool _disposed = false;
```

por:

```dart
  StreamSubscription<SessionParticipant?>? _participantSubscription;
  StreamSubscription<List<LocalAssessmentItem>>? _itemsSubscription;
  StreamSubscription<void>? _inProgressSubscription;

  bool _disposed = false;
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
  /// "Iniciar avaliação".
```

por:

```dart
  /// "Iniciar avaliação". Conferido de novo sempre que as avaliações do
  /// aparelho ou os participantes mudam, e não só ao abrir a tela (Fase 8D).
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
      notifyListeners();
    });

    try {
```

por:

```dart
      notifyListeners();
    });
    _inProgressSubscription ??= _assessmentRepository
        .watchInProgressChanges()
        .listen((_) => unawaited(_refreshBlock()));

    try {
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
  }

  /// Guarda quem está em andamento e o nome dele, para o aviso.
  Future<void> _block(String blockingParticipantId) async {
```

por:

```dart
  }

  /// Ver [isBlocked]: só antes de a avaliação começar, e nunca no meio de
  /// outra leitura ou gravação desta tela — elas conferem por conta própria.
  Future<void> _refreshBlock() async {
    if (_disposed || _loading || isStarted || _starting || _busy) return;
    final blockingBefore = _blockingParticipantId;
    final nameBefore = _blockingName;
    try {
      await _checkBlock(startedAfter: _resumable?.startTime);
    } catch (_) {
      // Uma falha do banco deixa o aviso como estava.
      _blockingParticipantId = blockingBefore;
      _blockingName = nameBefore;
      return;
    }
    if (_blockingParticipantId != blockingBefore || _blockingName != nameBefore) {
      notifyListeners();
    }
  }

  /// Guarda quem está em andamento e o nome dele, para o aviso.
  Future<void> _block(String blockingParticipantId) async {
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
  /// Desliga a tela da avaliação descartada: volta a "não iniciada".
```

por:

```dart
  /// Desliga a tela da avaliação descartada: volta a "não iniciada" — e o
  /// "Não salvo" de uma nota que não gravou vai junto com ela (Fase 8D).
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
    _expandedCategoryId = null;
  }
```

por:

```dart
    _expandedCategoryId = null;
    _saveFailed = false;
  }
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
  Future<void> toggleNote(String infractionId, String noteId) async {
    final assessmentId = _assessmentId;
    if (assessmentId == null || isConfirmed || _busy) return;
```

por:

```dart
  ///
  /// Com o participante fora das mãos do consultor ([isReleased]), não marca
  /// nada (Fase 8D): as marcações ficam como estavam até ele ser atribuído
  /// de novo.
  Future<void> toggleNote(String infractionId, String noteId) async {
    final assessmentId = _assessmentId;
    if (assessmentId == null || isConfirmed || isReleased || _busy) return;
```

Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:

```dart
    _itemsSubscription?.cancel();
    super.dispose();
```

por:

```dart
    _itemsSubscription?.cancel();
    _inProgressSubscription?.cancel();
    super.dispose();
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/checklist test/ui/session_detail/session_detail_screen_test.dart`
Esperado: `+193: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1200: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/data/repositories/assessment_repository.dart apps/mobile/simtc/lib/ui/checklist/checklist_screen.dart apps/mobile/simtc/lib/ui/checklist/checklist_viewmodel.dart apps/mobile/simtc/test/ui/checklist/checklist_screen_test.dart apps/mobile/simtc/test/ui/checklist/checklist_viewmodel_test.dart apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart
git commit -m "fix(mobile): checklist com participante liberado e aviso de outra avaliacao em dia"
```

---

## Task 5: Consulta de CPF, cursor da máscara e a regra de e-mail do servidor

Item 15 do desenho e a primeira observação da 8D-1. Vale só a resposta da última consulta, contada por geração, e não pelo CPF. A consulta que acaba sem cadastro, com o admin ainda no CPF, leva o foco para o nome. A máscara do CPF deixa o cursor onde se digita. O e-mail da 1.11 segue a regra do servidor (`isValidEmail`, em `lib/utils/email.dart`).

**Files:**
- Create: `lib/utils/email.dart`
- Create: `test/utils/email_test.dart`
- Modify: `lib/ui/add_participant/add_participant_screen.dart`
- Modify: `lib/ui/add_participant/add_participant_viewmodel.dart`
- Modify: `lib/ui/core/cpf_input_formatter.dart`
- Modify: `test/ui/add_participant/add_participant_screen_test.dart`
- Modify: `test/ui/add_participant/add_participant_viewmodel_test.dart`
- Modify: `test/ui/core/cpf_input_formatter_test.dart`

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces:
  - `isValidEmail(String value): bool` em `lib/utils/email.dart`
  - `AddParticipantViewModel.takeNameFocus(): bool` (vale uma vez)

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/add_participant/add_participant_screen_test.dart`, substituir:

```dart
    expect(row.cpf, '529.982.***-**');
  });
```

por:

```dart
    expect(row.cpf, '529.982.***-**');
  });

  testWidgets(
      'a consulta sem cadastro leva o foco para o nome (Fase 8D)',
      (tester) async {
    await seedSession();
    cpfIsFree();
    await pumpAdd(tester);

    await typeCpf(tester);

    final name = tester.widget<EditableText>(find.descendant(
      of: field('campo-nome'),
      matching: find.byType(EditableText),
    ));
    expect(name.focusNode.hasFocus, isTrue);
  });
```

Em `test/ui/add_participant/add_participant_viewmodel_test.dart`, substituir:

```dart
    });

    test('enquanto consulta, não dá para adicionar', () async {
      final answer = Completer<Result<CpfLookup>>();
```

por:

```dart
    });

    test(
        'a resposta atrasada do mesmo CPF, redigitado, também é ignorada — '
        'vale a última consulta (Fase 8D)', () async {
      final first = Completer<Result<CpfLookup>>();
      final second = Completer<Result<CpfLookup>>();
      final answers = [first, second];
      when(() => participants.lookupCpf('sess-1', cpf))
          .thenAnswer((_) => answers.removeAt(0).future);
      final vm = await open();

      vm.setCpf(cpf);
      vm.setCpf(cpf.substring(0, 10));
      vm.setCpf(cpf);
      second.complete(const Success(free));
      await pumpEventQueue();
      vm.setName('Fernanda corrigida à mão');

      first.complete(const Success(registered));
      await pumpEventQueue();

      expect(vm.name, 'Fernanda corrigida à mão');
      expect(vm.filledFromRegistry, isFalse);
      expect(vm.cpfCheck, CpfCheck.available);
    });

    test(
        'a consulta que acaba sem cadastro pede o foco no nome, uma vez só '
        '(Fase 8D)', () async {
      final vm = await open();

      vm.setCpf(cpf);
      expect(vm.takeNameFocus(), isFalse, reason: 'a consulta ainda está no ar');
      await pumpEventQueue();

      expect(vm.takeNameFocus(), isTrue);
      expect(vm.takeNameFocus(), isFalse);
    });

    test('com cadastro, ou já inscrito, o foco não muda (Fase 8D)', () async {
      lookupAnswers(registered);
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();
      expect(vm.takeNameFocus(), isFalse);

      lookupAnswers(
        const CpfLookup(registered: true, enrolled: true, name: 'Ana'),
        forCpf: otherCpf,
      );
      vm.setCpf(otherCpf);
      await pumpEventQueue();
      expect(vm.takeNameFocus(), isFalse);
    });

    test('enquanto consulta, não dá para adicionar', () async {
      final answer = Completer<Result<CpfLookup>>();
```

Em `test/ui/add_participant/add_participant_viewmodel_test.dart`, substituir:

```dart
      for (final wrong in ['fernanda', 'fernanda@', 'fernanda@empresa', 'a b@c.com']) {
```

por:

```dart
      // A regra do servidor (Fase 8D): `a@b.c` e o ponto repetido também não.
      for (final wrong in [
        'fernanda',
        'fernanda@',
        'fernanda@empresa',
        'a b@c.com',
        'a@b.c',
        'maria@empresa..com',
        'm@x.com.',
      ]) {
```

Em `test/ui/core/cpf_input_formatter_test.dart`, substituir:

```dart
    expect(value.selection, const TextSelection.collapsed(offset: 9));
  });
```

por:

```dart
    expect(value.selection, const TextSelection.collapsed(offset: 9));
  });

  group('o cursor fica onde a pessoa digita (Fase 8D)', () {
    TextEditingValue edited(String text, int cursor) {
      return formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: cursor),
        ),
      );
    }

    test('um dígito posto no meio deixa o cursor logo depois dele', () {
      // "529.9|82.247" e o 1 digitado no lugar da barra.
      final value = edited('529.9182.247', 6);

      expect(value.text, '529.918.224-7');
      expect(value.selection, const TextSelection.collapsed(offset: 6));
    });

    test('um dígito apagado no meio deixa o cursor onde ele estava', () {
      // "529.98|2.247" com o backspace: sai o 8.
      final value = edited('529.92.247', 5);

      expect(value.text, '529.922.47');
      expect(value.selection, const TextSelection.collapsed(offset: 5));
    });

    test('o cursor no começo continua no começo', () {
      final value = edited('1529.982', 1);

      expect(value.text, '152.998.2');
      expect(value.selection, const TextSelection.collapsed(offset: 1));
    });
  });
```

Criar `test/utils/email_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/utils/email.dart';

void main() {
  // A resposta do `isEmail` do class-validator para cada caso, conferida no
  // backend em 30/10/2026.
  test('aceita o que o servidor aceita', () {
    for (final email in [
      'fernanda@empresa.com.br',
      'f.l+cert@sub.empresa.com',
      'a@b.co',
      'joão@empresa.com.br',
      'maria@empresá.com.br',
      'MARIA@EMPRESA.COM',
      'maria_silva-2@x-y.com',
      'maria@1.2.3.com',
      'm@x.xn--p1ai',
    ]) {
      expect(isValidEmail(email), isTrue, reason: email);
    }
  });

  test('recusa o que o servidor recusa', () {
    for (final email in [
      'a@b.c',
      'maria@empresa..com',
      'm@x.com.',
      '.maria@x.com',
      'maria.@x.com',
      'ma..ria@x.com',
      'maria@-empresa.com',
      'maria@empresa-.com',
      'maria@empresa.c0m',
      'maria@empresa.123',
      'a b@c.com',
      'maria@empresa',
      'maria@@x.com',
      'maria@empresa.com.b',
      'maria@x.com.br.',
      'maria@localhost',
      'maria@x.co.u_k',
    ]) {
      expect(isValidEmail(email), isFalse, reason: email);
    }
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/add_participant test/ui/core/cpf_input_formatter_test.dart test/utils/email_test.dart`
Esperado: `+39 -7: Some tests failed.` — não compilam `add_participant_viewmodel_test.dart` (`The method 'takeNameFocus' isn't defined`) e `email_test.dart` (`Method not found: 'isValidEmail'`); falham o foco no nome da tela e os testes do cursor da máscara.

- [ ] **Step 3: Implementar**

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
  final FocusNode _cpfFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
```

por:

```dart
  final FocusNode _cpfFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
```

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
    _cpfFocus.dispose();
    _emailFocus.dispose();
```

por:

```dart
    _cpfFocus.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
```

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
      _cpfController.clear();
    }
```

por:

```dart
      _cpfController.clear();
    }
    // A consulta acabou sem cadastro, com o admin ainda no CPF: o nome é o
    // próximo a digitar (Fase 8D). O campo só destrava no quadro seguinte.
    if (_viewModel.takeNameFocus() && _cpfFocus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _cpfFocus.hasFocus) _nameFocus.requestFocus();
      });
    }
```

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
      controller: _nameController,
      icon: AppIcons.profile,
```

por:

```dart
      controller: _nameController,
      focusNode: _nameFocus,
      icon: AppIcons.profile,
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
import '../../utils/cpf.dart';
import '../../utils/result.dart';
```

por:

```dart
import '../../utils/cpf.dart';
import '../../utils/email.dart';
import '../../utils/result.dart';
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
      'Não foi possível adicionar o participante. Tente de novo.';

  /// Só para barrar erro de digitação no endereço que recebe o certificado:
  /// algo, arroba, algo, ponto, algo — sem espaços. O backend não confere.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<void>? _reconnectSubscription;
```

por:

```dart
      'Não foi possível adicionar o participante. Tente de novo.';

  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<void>? _reconnectSubscription;
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
  String? _autoEmail;
  bool _filledFromRegistry = false;

  bool _submitting = false;
```

por:

```dart
  String? _autoEmail;
  bool _filledFromRegistry = false;

  /// Conta as consultas: a resposta só vale se for a da última (Fase 8D).
  /// Pelo CPF não dá — digitar, apagar um dígito e redigitar o mesmo CPF
  /// dispara duas consultas iguais, e a primeira a voltar poria o nome do
  /// cadastro por cima de uma correção feita depois da segunda.
  int _lookupGeneration = 0;

  /// A consulta acabou sem cadastro: o foco vai para o nome (Fase 8D). Ver
  /// [takeNameFocus].
  bool _nameFocusPending = false;

  bool _submitting = false;
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
  /// Vazio vale: o e-mail é opcional.
  bool get isEmailValid {
    final email = _email.trim();
    return email.isEmpty || _emailPattern.hasMatch(email);
```

por:

```dart
  /// Vazio vale: o e-mail é opcional. Preenchido, segue a regra do servidor
  /// (`isValidEmail`).
  bool get isEmailValid {
    final email = _email.trim();
    return email.isEmpty || isValidEmail(email);
  }

  /// A tela pergunta, a cada mudança, se deve levar o foco ao nome — e a
  /// pergunta vale uma vez só.
  bool takeNameFocus() {
    final pending = _nameFocusPending;
    _nameFocusPending = false;
    return pending;
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
    unawaited(_lookup(_cpf));
```

por:

```dart
    unawaited(_lookup(_cpf, ++_lookupGeneration));
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
    _enrolledName = null;
    _clearRegistryFill();

    if (cpf.length < 11) {
```

por:

```dart
    _enrolledName = null;
    _clearRegistryFill();
    // A consulta no ar, se houver, deixa de valer.
    final generation = ++_lookupGeneration;

    if (cpf.length < 11) {
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
      unawaited(_lookup(cpf));
```

por:

```dart
      unawaited(_lookup(cpf, generation));
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
  Future<void> _lookup(String cpf) async {
```

por:

```dart
  Future<void> _lookup(String cpf, int generation) async {
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
    // Resposta atrasada: a tela fechou, ou o CPF já é outro.
    if (_disposed || cpf != _cpf) return;
```

por:

```dart
    // Resposta atrasada: a tela fechou, ou outra consulta veio depois.
    if (_disposed || generation != _lookupGeneration) return;
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
        if (data.registered) _fillFromRegistry(data);
```

por:

```dart
        if (data.registered) {
          _fillFromRegistry(data);
        } else {
          _nameFocusPending = true;
        }
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
    _autoName = null;
    _autoEmail = null;
    _filledFromRegistry = false;
  }

  // A consulta e o "adicionar" podem responder depois de a tela fechar.
```

por:

```dart
    _autoName = null;
    _autoEmail = null;
    _filledFromRegistry = false;
    _nameFocusPending = false;
  }

  // A consulta e o "adicionar" podem responder depois de a tela fechar.
```

Em `lib/ui/core/cpf_input_formatter.dart`, substituir:

```dart
/// O cursor vai sempre para o fim: o campo é curto e digitado de uma vez, e
/// reposicionar o cursor no meio da máscara custaria mais do que vale.
```

por:

```dart
/// O cursor fica onde a pessoa está digitando (Fase 8D): depois do mesmo
/// número de dígitos que ele tinha à esquerda, e não no fim do campo — quem
/// corrige um dígito no meio continua corrigindo dali.
```

Em `lib/ui/core/cpf_input_formatter.dart`, substituir:

```dart
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
```

por:

```dart
    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, newValue.text.length)
        : newValue.text.length;
    final digitsBefore = cpfDigits(newValue.text.substring(0, cursor)).length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: _offsetAfter(text, digitsBefore)),
    );
  }

  /// A posição logo depois do [digits]-ésimo dígito de [text].
  static int _offsetAfter(String text, int digits) {
    if (digits <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < text.length; i++) {
      if (cpfDigits(text[i]).isNotEmpty) seen++;
      if (seen == digits) return i + 1;
    }
    return text.length;
  }
```

Criar `lib/utils/email.dart`:

```dart
/// Confere o e-mail com a mesma regra do servidor (o `@IsEmail` do
/// class-validator, desde a Fase 8D-1): o que passa aqui, o servidor aceita, e
/// o erro de digitação aparece na tela, antes do envio (Fase 8D). Ficam de
/// fora só formas que ninguém digita num formulário de inscrição (o nome entre
/// aspas antes do "@", o endereço IP entre colchetes).
bool isValidEmail(String value) => _email.hasMatch(value);

/// Cada pedaço do nome antes do "@": sem ponto no começo, no fim ou repetido.
const String _localAtom =
    r"[a-zA-Z0-9!#$%&'*+\-/=?^_`{|}~ -퟿豈-﷏ﷰ-￯]+";

/// Cada parte do domínio: letras (com acento), dígitos e hífen, sem hífen nas
/// pontas.
const String _label =
    r'[a-zA-Z0-9¡-￿](?:[a-zA-Z0-9¡-￿-]*[a-zA-Z0-9¡-￿])?';

/// O fim do domínio: duas letras ou mais, sem dígito ("com", "br").
const String _topLevel =
    r'(?:[a-zA-Z¡-¨ª-퟿豈-﷏ﷰ-￯]{2,}|xn[a-zA-Z0-9-]{2,})';

final RegExp _email =
    RegExp('^$_localAtom(?:\\.$_localAtom)*@(?:$_label\\.)+$_topLevel\$');
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/add_participant test/ui/core/cpf_input_formatter_test.dart test/utils/email_test.dart`
Esperado: `+96: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1209: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/utils/email.dart apps/mobile/simtc/test/utils/email_test.dart apps/mobile/simtc/lib/ui/add_participant/add_participant_screen.dart apps/mobile/simtc/lib/ui/add_participant/add_participant_viewmodel.dart apps/mobile/simtc/lib/ui/core/cpf_input_formatter.dart apps/mobile/simtc/test/ui/add_participant/add_participant_screen_test.dart apps/mobile/simtc/test/ui/add_participant/add_participant_viewmodel_test.dart apps/mobile/simtc/test/ui/core/cpf_input_formatter_test.dart
git commit -m "fix(mobile): consulta de cpf, cursor da mascara e regra de email do servidor"
```

---

## Task 6: Telas de admin: a sessão apagada trava, a tela travada fecha sem perguntar

Itens 16, 17 e 18 do desenho. O 404 do salvar, do cancelar ou do adicionar trava a 1.11 e a 1.12 com "Esta sessão não existe mais.", no lugar da mensagem do servidor, e a sessão é baixada de novo. A tela travada fecha sem perguntar se descarta. Antes dos diálogos da 1.12, o foco sai do próprio campo, e não só do `FocusScope`: assim o teclado não volta sozinho.

**Files:**
- Modify: `lib/ui/add_participant/add_participant_screen.dart`
- Modify: `lib/ui/add_participant/add_participant_viewmodel.dart`
- Modify: `lib/ui/session_edit/session_edit_screen.dart`
- Modify: `lib/ui/session_edit/session_edit_viewmodel.dart`
- Modify: `test/ui/add_participant/add_participant_screen_test.dart`
- Modify: `test/ui/add_participant/add_participant_viewmodel_test.dart`
- Modify: `test/ui/session_edit/session_edit_screen_test.dart`
- Modify: `test/ui/session_edit/session_edit_viewmodel_test.dart`

**Interfaces:**
- Consumes: `AddParticipantViewModel` e `AddParticipantScreen` da Task 5 (os mesmos arquivos).
- Produces:
  - `lockedReason` = "Esta sessão não existe mais." depois de um 404, nas duas ViewModels

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/add_participant/add_participant_screen_test.dart`, substituir:

```dart
    });

    testWidgets('o voltar do Android, com algo preenchido, também pergunta',
        (tester) async {
```

por:

```dart
    });

    testWidgets(
        'a sessão concluída por outra pessoa com algo preenchido: o X fecha '
        'sem perguntar (Fase 8D)', (tester) async {
      await seedSession();
      await pumpAdd(tester);
      await tester.enterText(field('campo-nome'), 'Fernanda');
      await tester.pump();

      await db.customUpdate(
        "UPDATE sessions SET status = 'CONCLUIDO' WHERE id = 'sess-1'",
        updates: {db.sessions},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('origem'), findsOneWidget);
    });

    testWidgets(
        'a sessão apagada no servidor (404): a tela trava com o motivo e o X '
        'fecha sem perguntar (Fase 8D)', (tester) async {
      await seedSession();
      cpfIsFree();
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Treinamento não encontrado',
        statusCode: 404,
      ));
      when(() => api.get<Map<String, dynamic>>(sessionPath)).thenThrow(
        const ApiException(message: 'Treinamento não encontrado', statusCode: 404),
      );
      await pumpAdd(tester);
      await typeCpf(tester);
      await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');
      await tester.pump();

      await tester.tap(find.widgetWithText(AppCtaButton, 'Adicionar participante'));
      await tester.pumpAndSettle();

      expect(find.text('Esta sessão não existe mais.'), findsOneWidget);
      expect(find.text('Treinamento não encontrado'), findsNothing);
      expect(addButton(tester).onPressed, isNull);
      verify(() => api.get<Map<String, dynamic>>(sessionPath)).called(1);

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('origem'), findsOneWidget);
    });

    testWidgets('o voltar do Android, com algo preenchido, também pergunta',
        (tester) async {
```

Em `test/ui/add_participant/add_participant_viewmodel_test.dart`, substituir:

```dart
    });

    test('sem rede: mostra o motivo, e o que foi digitado continua', () async {
      addAnswers(const Failure<SessionParticipant>(
```

por:

```dart
    });

    test(
        'a sessão apagada no servidor (404): trava com "Esta sessão não '
        'existe mais.", sem a mensagem do servidor, e baixa de novo (Fase 8D)',
        () async {
      addAnswers(const Failure<SessionParticipant>(
        ApiException(message: 'Treinamento não encontrado', statusCode: 404),
        'Treinamento não encontrado',
      ));
      final vm = await filled();

      expect(await vm.submit(), isNull);

      expect(vm.lockedReason, 'Esta sessão não existe mais.');
      expect(vm.canAdd, isFalse);
      expect(vm.errorMessage, isNull);
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('sem rede: mostra o motivo, e o que foi digitado continua', () async {
      addAnswers(const Failure<SessionParticipant>(
```

Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:

```dart
    });

    testWidgets('confirmando, salva a data antiga e fecha a tela', (tester) async {
      await seedSession();
```

por:

```dart
    });

    testWidgets(
        '"Voltar" da pergunta não devolve o foco ao campo em edição (Fase 8D)',
        (tester) async {
      await seedSession();
      patchAnswers();
      await pumpEdit(tester, clock: () => DateTime(2027, 1, 20, 9));
      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();

      await pickDay15AndSave(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
      await tester.pumpAndSettle();

      final city = tester.widget<EditableText>(find.descendant(
        of: field('campo-cidade'),
        matching: find.byType(EditableText),
      ));
      expect(city.focusNode.hasFocus, isFalse);
    });

    testWidgets('confirmando, salva a data antiga e fecha a tela', (tester) async {
      await seedSession();
```

Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:

```dart
    });

    testWidgets('o voltar do Android, com mudança, também pergunta',
        (tester) async {
```

por:

```dart
    });

    testWidgets(
        'a sessão concluída por outra pessoa com mudança por salvar: o voltar '
        'sai sem perguntar (Fase 8D)', (tester) async {
      await seedSession();
      await pumpEdit(tester);
      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();

      await db.customUpdate(
        "UPDATE sessions SET status = 'CONCLUIDO' WHERE id = 'sess-1'",
        updates: {db.sessions},
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Sessão concluída: os dados não podem mais ser alterados.'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('origem'), findsOneWidget);
    });

    testWidgets('o voltar do Android, com mudança, também pergunta',
        (tester) async {
```

Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:

```dart
    });

    testWidgets('recusado pelo servidor: o motivo aparece, e a tela fica',
        (tester) async {
```

por:

```dart
    });

    testWidgets(
        'o "Cancelar sessão" tira o foco do campo antes do diálogo (Fase 8D)',
        (tester) async {
      await seedSession();
      await pumpEdit(tester);
      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();

      await tester.tap(find.text('Cancelar sessão'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      final city = tester.widget<EditableText>(find.descendant(
        of: field('campo-cidade'),
        matching: find.byType(EditableText),
      ));
      expect(city.focusNode.hasFocus, isFalse);
    });

    testWidgets(
        'a sessão apagada no servidor (404): a tela trava com o motivo, baixa '
        'a sessão de novo e o voltar sai sem perguntar (Fase 8D)',
        (tester) async {
      await seedSession();
      when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Treinamento não encontrado',
        statusCode: 404,
      ));
      when(() => api.get<Map<String, dynamic>>(path)).thenThrow(
        const ApiException(message: 'Treinamento não encontrado', statusCode: 404),
      );
      await pumpEdit(tester);
      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();

      await tester.tap(find.widgetWithText(AppCtaButton, 'Salvar alterações'));
      await tester.pumpAndSettle();

      expect(find.text('Esta sessão não existe mais.'), findsOneWidget);
      expect(find.text('Treinamento não encontrado'), findsNothing);
      expect(saveButton(tester).onPressed, isNull);
      verify(() => api.get<Map<String, dynamic>>(path)).called(1);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('origem'), findsOneWidget);
    });

    testWidgets('recusado pelo servidor: o motivo aparece, e a tela fica',
        (tester) async {
```

Em `test/ui/session_edit/session_edit_viewmodel_test.dart`, substituir:

```dart
    });

    test('uma exceção inesperada vira a mensagem genérica, sem travar a tela',
        () async {
```

por:

```dart
    });

    test(
        'a sessão apagada no servidor (404): trava com "Esta sessão não '
        'existe mais.", sem a mensagem do servidor, e baixa de novo (Fase 8D)',
        () async {
      when(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).thenAnswer(
        (_) async => const Failure<void>(
          ApiException(message: 'Treinamento não encontrado', statusCode: 404),
          'Treinamento não encontrado',
        ),
      );
      final vm = await open();
      vm.setCity('Betim');

      expect(await vm.save(), isFalse);

      expect(vm.lockedReason, 'Esta sessão não existe mais.');
      expect(vm.canEdit, isFalse);
      expect(vm.canSave, isFalse);
      expect(vm.errorMessage, isNull);
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('uma exceção inesperada vira a mensagem genérica, sem travar a tela',
        () async {
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_edit test/ui/add_participant`
Esperado: `+165 -8: Some tests failed.` — os testes novos do 404, da tela travada que fecha sem perguntar e do foco antes dos diálogos.

- [ ] **Step 3: Implementar**

Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:

```dart
  /// preenchido, pergunta antes; e devolve `true` se alguém entrou na sessão
  /// desde que a tela abriu, para o detalhe se atualizar.
  Future<void> _close() async {
    if (_viewModel.isSubmitting) return;
    if (_viewModel.hasInput && !await _confirmDiscard()) return;
```

por:

```dart
  /// preenchido, pergunta antes — a não ser com a tela travada, em que não
  /// há o que adicionar (Fase 8D); e devolve `true` se alguém entrou na
  /// sessão desde que a tela abriu, para o detalhe se atualizar.
  Future<void> _close() async {
    if (_viewModel.isSubmitting) return;
    if (_viewModel.hasInput && _viewModel.canAdd && !await _confirmDiscard()) {
      return;
    }
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
  int _addedCount = 0;

  /// Antes da primeira leitura do cache.
  bool get isLoading => !_loaded;
```

por:

```dart
  int _addedCount = 0;

  /// O servidor disse que a sessão não existe mais (404): a tela trava
  /// (Fase 8D).
  bool _gone = false;

  /// Antes da primeira leitura do cache.
  bool get isLoading => !_loaded;
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
    }
    final session = _session;
```

por:

```dart
    }
    if (_gone) return 'Esta sessão não existe mais.';
    final session = _session;
```

Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:

```dart
    _error = message ?? _addFailed;
```

por:

```dart
    // A sessão apagada (404) trava a tela com o motivo ([lockedReason]), no
    // lugar da mensagem do servidor (Fase 8D).
    if (status == 404) {
      _gone = true;
    } else {
      _error = message ?? _addFailed;
    }
```

Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:

```dart
    // não passa por aqui.
    return PopScope<Object?>(
      canPop: !_viewModel.isDirty && !_viewModel.isBusy,
```

por:

```dart
    // não passa por aqui. Com a tela travada (outra pessoa concluiu ou
    // cancelou a sessão, ou ela foi apagada), não há o que salvar: sai sem
    // perguntar (Fase 8D).
    return PopScope<Object?>(
      canPop: (!_viewModel.isDirty || !_viewModel.canEdit) && !_viewModel.isBusy,
```

Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:

```dart
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
```

por:

```dart
  /// Tira o foco do campo em edição antes de um diálogo (Fase 8D). Tirar só
  /// do `FocusScope` da tela não basta: ela guarda o campo, e o foco volta
  /// para ele — com o teclado — quando o diálogo fecha, cobrindo o aviso de
  /// um salvar ou cancelar que falhou.
  void _dropFocus() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _save() async {
    _dropFocus();
```

Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:

```dart
  Future<void> _confirmCancel() async {
    final count = _viewModel.inEvaluationCount;
```

por:

```dart
  Future<void> _confirmCancel() async {
    _dropFocus();
    final count = _viewModel.inEvaluationCount;
```

Em `lib/ui/session_edit/session_edit_viewmodel.dart`, substituir:

```dart
  String? _error;

  /// Antes da primeira leitura do cache.
  bool get isLoading => !_loaded;
```

por:

```dart
  String? _error;

  /// O servidor disse que a sessão não existe mais (404): a tela trava
  /// (Fase 8D). O cache ainda pode tê-la — a sessão apagada no painel só
  /// some do aparelho no próximo sync da Home.
  bool _gone = false;

  /// Antes da primeira leitura do cache.
  bool get isLoading => !_loaded;
```

Em `lib/ui/session_edit/session_edit_viewmodel.dart`, substituir:

```dart
    }
    final session = _session;
```

por:

```dart
    }
    if (_gone) return 'Esta sessão não existe mais.';
    final session = _session;
```

Em `lib/ui/session_edit/session_edit_viewmodel.dart`, substituir:

```dart
          _error = message ?? _saveFailed;
          _resyncIfRefused(exception);
```

por:

```dart
          _refused(exception, message ?? _saveFailed);
```

Em `lib/ui/session_edit/session_edit_viewmodel.dart`, substituir:

```dart
          _error = message ?? _cancelFailed;
          _resyncIfRefused(exception);
```

por:

```dart
          _refused(exception, message ?? _cancelFailed);
```

Em `lib/ui/session_edit/session_edit_viewmodel.dart`, substituir:

```dart
  /// O servidor recusou (403) ou não achou a sessão (404): alguém a concluiu,
  /// cancelou ou apagou. Baixar de novo põe o cache — e o status desta tela —
  /// em dia.
  void _resyncIfRefused(Exception exception) {
    if (exception is! ApiException) return;
    if (exception.statusCode == 403 || exception.statusCode == 404) {
```

por:

```dart
  /// O motivo da recusa fica na tela, a não ser a sessão apagada (404): aí a
  /// tela trava com "Esta sessão não existe mais." ([lockedReason]).
  void _refused(Exception exception, String message) {
    final status = exception is ApiException ? exception.statusCode : null;
    if (status == 404) {
      _gone = true;
    } else {
      _error = message;
    }
    // O servidor recusou (403) ou não achou a sessão (404): alguém a
    // concluiu, cancelou ou apagou. Baixar de novo põe o cache — e o status
    // desta tela — em dia.
    if (status == 403 || status == 404) {
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_edit test/ui/add_participant`
Esperado: `+173: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1217: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/add_participant/add_participant_screen.dart apps/mobile/simtc/lib/ui/add_participant/add_participant_viewmodel.dart apps/mobile/simtc/lib/ui/session_edit/session_edit_screen.dart apps/mobile/simtc/lib/ui/session_edit/session_edit_viewmodel.dart apps/mobile/simtc/test/ui/add_participant/add_participant_screen_test.dart apps/mobile/simtc/test/ui/add_participant/add_participant_viewmodel_test.dart apps/mobile/simtc/test/ui/session_edit/session_edit_screen_test.dart apps/mobile/simtc/test/ui/session_edit/session_edit_viewmodel_test.dart
git commit -m "fix(mobile): telas de admin travam com a sessao apagada e fecham sem perguntar"
```

---

## Task 7: Detalhe, Home e Consultores: o "Iniciar" recusado, os chips e as buscas

Itens 20, 22 e 23 do desenho e a segunda observação da 8D-1. O "Iniciar" recusado pelo servidor baixa a sessão de novo. A barra de chips rola só a si mesma. O campo de busca fica vivo dentro da lista. A busca numa sessão nunca baixada diz por que não acha nada, e não "0 de 0". Em Consultores, a frase de nenhum resultado some com a equipe que falhou. E o chip da Home volta a bater com a rolagem quando a busca fecha.

**Files:**
- Modify: `lib/ui/core/widgets/app_search_field.dart`
- Modify: `lib/ui/core/widgets/filter_chip_bar.dart`
- Modify: `lib/ui/session_consultants/session_consultants_screen.dart`
- Modify: `lib/ui/session_consultants/session_consultants_viewmodel.dart`
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Modify: `lib/ui/session_detail/session_detail_viewmodel.dart`
- Modify: `lib/ui/sessions/sessions_screen.dart`
- Modify: `test/ui/core/widgets/app_search_field_test.dart`
- Modify: `test/ui/core/widgets/display_widgets_test.dart`
- Modify: `test/ui/session_consultants/session_consultants_screen_test.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`
- Modify: `test/ui/session_detail/session_detail_viewmodel_test.dart`
- Modify: `test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces:
  - `SessionConsultantsViewModel.teamFailed` (bool)
  - `AppSearchField` com `AutomaticKeepAliveClientMixin`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/core/widgets/app_search_field_test.dart`, substituir:

```dart
    });

    testWidgets('cada letra avisa o texto; o X fecha a busca', (tester) async {
      final changes = <String>[];
```

por:

```dart
    });

    testWidgets(
        'dentro de uma lista, sair de vista e voltar não abre o teclado nem '
        'perde o texto (Fase 8D)', (tester) async {
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final list = ScrollController();
      addTearDown(list.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: list,
            children: [
              AppSearchField(
                hintText: 'Buscar por nome ou CPF',
                onChanged: (_) {},
                onClose: () {},
              ),
              const SizedBox(height: 3000),
            ],
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), 'ana');
      // O teclado fechado: o campo perde o foco.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      list.jumpTo(2000);
      await tester.pump();
      list.jumpTo(0);
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isFalse);
      expect(editable.controller.text, 'ana');
    });

    testWidgets('cada letra avisa o texto; o X fecha a busca', (tester) async {
      final changes = <String>[];
```

Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:

```dart
    expect(find.text('3'), findsOneWidget);
  });
```

por:

```dart
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets(
      'FilterChipBar dentro de uma lista: o chip escolhido rola só a barra, '
      'não a lista (Fase 8D)', (tester) async {
    tester.view.physicalSize = const Size(300, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final list = ScrollController();
    addTearDown(list.dispose);
    const items = [
      FilterChipData(label: 'Todos', count: 8),
      FilterChipData(label: 'Pendentes', count: 3),
      FilterChipData(label: 'Meus', count: 2),
      FilterChipData(label: 'Concluídos', count: 1),
    ];

    Widget screen(int selected) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(
              controller: list,
              children: [
                const SizedBox(height: 400),
                FilterChipBar(selectedIndex: selected, onSelect: (_) {}, items: items),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        );

    await tester.pumpWidget(screen(0));
    list.jumpTo(300);
    await tester.pump();

    await tester.pumpWidget(screen(3));
    await tester.pumpAndSettle();

    expect(list.offset, 300, reason: 'a lista fica onde estava');
    final bar = tester.getRect(find.byType(FilterChipBar));
    final chip = tester.getRect(find.text('Concluídos'));
    expect(chip.right, lessThanOrEqualTo(bar.right),
        reason: 'a barra rolou até o chip escolhido');
  });
```

Em `test/ui/session_consultants/session_consultants_screen_test.dart`, substituir:

```dart
    });
  });
```

por:

```dart
    });

    testWidgets(
        'com a equipe que não carregou, a busca sem resultado não diz que não '
        'achou: vale o aviso da equipe (Fase 8D)', (tester) async {
      await seedFromServer();
      when(() => api.get<List<dynamic>>(
            teamPath,
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(
          const ApiException(message: 'Internal server error', statusCode: 500));
      await pumpScreen(tester, screen: const Size(412, 900));
      await openSearch(tester);

      await type(tester, 'zzz');

      expect(find.byKey(const Key('consultants-no-results')), findsNothing);
      expect(
        find.text('Não foi possível carregar a equipe. Puxe para atualizar.'),
        findsOneWidget,
      );
    });
  });
```

Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:

```dart
    expect(find.text('Nenhum participante inscrito nesta sessão.'), findsNothing);
  });
```

por:

```dart
    expect(find.text('Nenhum participante inscrito nesta sessão.'), findsNothing);
  });

  testWidgets(
      'sessão nunca baixada: a busca diz por que não acha nada, sem "0 de 0" '
      '(Fase 8D)', (tester) async {
    await show(tester, withSession: session(downloaded: false));

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'ana');
    await tester.pump();

    expect(
      find.text('A busca procura nos participantes baixados, e os desta '
          'sessão ainda não foram baixados.'),
      findsOneWidget,
    );
    expect(find.textContaining('de 0'), findsNothing);
  });
```

Em `test/ui/session_detail/session_detail_viewmodel_test.dart`, substituir:

```dart
      expect(vm.isStarting, isFalse);
      verify(() => participants.syncSession('sess-1')).called(1);
    });
  });

  test('falha ao atualizar vira mensagem, sem apagar a lista', () async {
```

por:

```dart
      expect(vm.isStarting, isFalse);
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test(
        'recusa do servidor (outro aparelho já iniciou): mostra o motivo e '
        'baixa a sessão de novo (Fase 8D)', () async {
      when(() => sessions.start('sess-1')).thenAnswer(
        (_) async => const Failure<void>(
          ApiException(
            message: 'Só dá para iniciar um treinamento planejado',
            statusCode: 403,
          ),
          'Só dá para iniciar um treinamento planejado',
        ),
      );
      final vm = await ready(
        withSession: session(status: SessionStatus.planejado, responsible: 'c-eu'),
      );

      await vm.startSession();
      await Future<void>.delayed(Duration.zero);

      expect(vm.message, 'Só dá para iniciar um treinamento planejado');
      verify(() => participants.syncSession('sess-1')).called(2);
    });
  });

  test('falha ao atualizar vira mensagem, sem apagar a lista', () async {
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
    expect(isChipSelected(tester, 'Concluídas'), isTrue);
  });
```

por:

```dart
    expect(isChipSelected(tester, 'Concluídas'), isTrue);
  });

  testWidgets(
      'ao fechar a busca, o chip destacado volta a bater com a rolagem '
      '(Fase 8D)', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final muitasHoje = List.generate(
      15,
      (i) => TrainingSession(
        id: 'h$i',
        companyName: 'Empresa Hoje $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    final concluida = TrainingSession(
      id: 'concluida-0',
      companyName: 'Empresa Concluída 0',
      courseName: 'Curso',
      city: 'Bauru',
      state: 'SP',
      date: DateTime(2026, 8, 1),
      status: SessionStatus.concluido,
      totalParticipants: 1,
      assessableParticipants: 1,
      assessedParticipants: 1,
    );
    await pump(tester);
    sessions.add([...muitasHoje, concluida]);
    await tester.pump();
    await tester.fling(find.byType(ListView), const Offset(0, -2200), 3000);
    await tester.pumpAndSettle();
    expect(isChipSelected(tester, 'Concluídas'), isTrue);

    // A busca encurta a lista: a rolagem volta para o meio de "Hoje".
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Hoje 1');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fechar a busca'));
    await tester.pumpAndSettle();

    expect(isChipSelected(tester, 'Hoje'), isTrue);
    expect(isChipSelected(tester, 'Concluídas'), isFalse);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_detail test/ui/session_consultants test/ui/sessions test/ui/core/widgets`
Esperado: `+400 -6: Some tests failed.` — os testes novos do "Iniciar" recusado, da barra de chips dentro da lista, do campo de busca que sai de vista, da busca na sessão nunca baixada, de Consultores com a equipe que falhou e do chip da Home.

- [ ] **Step 3: Implementar**

Em `lib/ui/core/widgets/app_search_field.dart`, substituir:

```dart
/// cada mudança em [onChanged].
class AppSearchField extends StatefulWidget {
```

por:

```dart
/// cada mudança em [onChanged].
///
/// Dentro de uma lista (o detalhe com a fonte grande), continua vivo quando
/// sai de vista (Fase 8D): recriado ao voltar, o `autofocus` abriria o
/// teclado sozinho, e o texto voltaria ao [initialText].
class AppSearchField extends StatefulWidget {
```

Em `lib/ui/core/widgets/app_search_field.dart`, substituir:

```dart
class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);
```

por:

```dart
class _AppSearchFieldState extends State<AppSearchField>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  bool get wantKeepAlive => true;
```

Em `lib/ui/core/widgets/app_search_field.dart`, substituir:

```dart
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
```

por:

```dart
  Widget build(BuildContext context) {
    super.build(context);
    final border = OutlineInputBorder(
```

Em `lib/ui/core/widgets/filter_chip_bar.dart`, substituir:

```dart
  /// de destaque neste build, e `Scrollable.ensureVisible` precisa do
  /// `RenderObject` já montado com essa geometria pra calcular quanto rolar.
  void _ensureSelectedVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _chipKeys[widget.selectedIndex].currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
```

por:

```dart
  /// de destaque neste build, e o `ensureVisible` precisa do `RenderObject`
  /// já montado com essa geometria pra calcular quanto rolar.
  ///
  /// Rola só a própria barra (Fase 8D): o `Scrollable.ensureVisible` rolaria
  /// também a lista vertical em volta dela — com a fonte grande, a barra rola
  /// junto com a lista do detalhe, e o toque num chip a levava até o topo.
  void _ensureSelectedVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _chipKeys[widget.selectedIndex].currentContext;
      final chip = context?.findRenderObject();
      if (context == null || chip == null) return;
      Scrollable.of(context).position.ensureVisible(
            chip,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
```

Em `lib/ui/session_consultants/session_consultants_screen.dart`, substituir:

```dart
      // Com a equipe ainda carregando, não dá para dizer que não achou.
      if (filtering &&
          inSession.isEmpty &&
          _viewModel.available.isEmpty &&
          !_viewModel.isTeamLoading)
```

por:

```dart
      // Com a equipe ainda carregando, ou que falhou ao carregar, não dá para
      // dizer que não achou.
      if (filtering &&
          inSession.isEmpty &&
          _viewModel.available.isEmpty &&
          !_viewModel.isTeamLoading &&
          !_viewModel.teamFailed)
```

Em `lib/ui/session_consultants/session_consultants_viewmodel.dart`, substituir:

```dart
  /// enquanto ela carrega).
  String? get teamNotice {
```

por:

```dart
  /// enquanto ela carrega).
  /// A equipe não carregou por uma falha do servidor: o aviso dela ("Não foi
  /// possível carregar a equipe") explica a lista vazia, e a busca não diz
  /// junto que não achou (Fase 8D).
  bool get teamFailed => _team == null && _teamFailure == _TeamFailure.failed;

  String? get teamNotice {
```

Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:

```dart
  Widget _buildEmpty() {
    // Nunca baixada: o aviso de cima já explica, e "nenhum participante"
    // seria uma afirmação que o app não tem como fazer.
    if (_viewModel.neverDownloaded) return const SizedBox.shrink();

    final query = _viewModel.searchQuery.trim();
    final message = !_viewModel.hasParticipants
```

por:

```dart
  Widget _buildEmpty() {
    final query = _viewModel.searchQuery.trim();

    // Nunca baixada: o aviso de cima já explica, e "nenhum participante"
    // seria uma afirmação que o app não tem como fazer. Só a busca diz por
    // que não acha nada (Fase 8D).
    if (_viewModel.neverDownloaded) {
      if (!_viewModel.isFiltering) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.fromLTRB(_inset, 0, _inset, AppSpacing.md),
        child: Semantics(
          liveRegion: true,
          child: const InlineNotice(
            icon: AppIcons.search,
            message: 'A busca procura nos participantes baixados, e os desta '
                'sessão ainda não foram baixados.',
          ),
        ),
      );
    }

    final message = !_viewModel.hasParticipants
```

Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:

```dart
  /// quando a busca não filtra nada.
  String? get searchCountLabel {
    if (!isFiltering) return null;
```

por:

```dart
  /// quando a busca não filtra nada — ou quando a sessão nunca foi baixada,
  /// em que "0 de 0" não diria nada (Fase 8D).
  String? get searchCountLabel {
    if (!isFiltering || neverDownloaded) return null;
```

Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:

```dart
  /// "Iniciar sessão" — só o responsável ou um ADMIN chegam a ver o botão.
  Future<void> startSession() async {
```

por:

```dart
  /// "Iniciar sessão" — só o responsável ou um ADMIN chegam a ver o botão.
  ///
  /// Recusado pelo servidor — outro aparelho já iniciou (ou concluiu) a
  /// sessão, e ela não está mais planejada (Fase 8D) —, a mensagem dele
  /// aparece e a sessão é baixada de novo: a tela deixa de mostrar
  /// "Planejado" e o botão. Sem rede, nada a baixar.
  Future<void> startSession() async {
```

Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:

```dart
        case Failure(:final message):
          _message = message ?? _startFailed;
```

por:

```dart
        case Failure(:final exception, :final message):
          _message = message ?? _startFailed;
          resync = exception is ApiException && !exception.isNetworkError;
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_showErrorWhenItArrives);
```

por:

```dart
  /// Ver [_resyncChipAfterSearch].
  bool _wasSearching = false;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_showErrorWhenItArrives);
    _viewModel.addListener(_resyncChipAfterSearch);
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
    _viewModel.removeListener(_showErrorWhenItArrives);
    _viewModel.dispose();
```

por:

```dart
    _viewModel.removeListener(_showErrorWhenItArrives);
    _viewModel.removeListener(_resyncChipAfterSearch);
    _viewModel.dispose();
```

Em `lib/ui/sessions/sessions_screen.dart`, substituir:

```dart
      listenable: _viewModel,
      builder: (context, _) => _buildScaffold(context, _viewModel),
    );
  }

  /// Toque num chip: marca a seção correspondente e rola até ela.
```

por:

```dart
      listenable: _viewModel,
      builder: (context, _) => _buildScaffold(context, _viewModel),
    );
  }

  /// A busca fechou: a lista volta inteira, na rolagem que tiver, e o chip
  /// destacado passa a ser o da seção que está na tela (Fase 8D). Sem isso,
  /// ficava o de antes da busca até a próxima rolagem.
  void _resyncChipAfterSearch() {
    final searching = _viewModel.isSearching;
    if (_wasSearching && !searching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateActiveChipFromScroll();
      });
    }
    _wasSearching = searching;
  }

  /// Toque num chip: marca a seção correspondente e rola até ela.
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_detail test/ui/session_consultants test/ui/sessions test/ui/core/widgets`
Esperado: `+406: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1223: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/widgets/app_search_field.dart apps/mobile/simtc/lib/ui/core/widgets/filter_chip_bar.dart apps/mobile/simtc/lib/ui/session_consultants/session_consultants_screen.dart apps/mobile/simtc/lib/ui/session_consultants/session_consultants_viewmodel.dart apps/mobile/simtc/lib/ui/session_detail/session_detail_screen.dart apps/mobile/simtc/lib/ui/session_detail/session_detail_viewmodel.dart apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart apps/mobile/simtc/test/ui/core/widgets/app_search_field_test.dart apps/mobile/simtc/test/ui/core/widgets/display_widgets_test.dart apps/mobile/simtc/test/ui/session_consultants/session_consultants_screen_test.dart apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart apps/mobile/simtc/test/ui/session_detail/session_detail_viewmodel_test.dart apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart
git commit -m "fix(mobile): detalhe, home e consultores com o iniciar recusado, os chips e as buscas"
```

---
## Task 8: Validação no aparelho e no emulador

O portão da 8D-2, que só o usuário pode rodar: o celular no **aparelho físico** e o tablet no **emulador**, contra a produção, numa sessão de teste. A 8D-2 não muda o backend: não há publicação.

**Interfaces:**
- Consumes: o app com as Tasks 1 a 7.
- Produces: o aval do usuário para planejar a 8D-3.

- [ ] **Step 1: Instalar**

Em `apps/mobile/simtc/`: `flutter run -d <id do celular>` e, depois, `flutter run -d emulator-5554`.

- [ ] **Step 2: Roteiro no celular**

Com uma conta CONSULTANT e uma ADMIN, numa sessão de teste em andamento:

1. **Fila esperando o catálogo (CONSULTANT):**
   - Com o modo avião ligado, avaliar um participante com pelo menos uma nota marcada e confirmar.
   - Em Perfil, tocar em "Limpar cache local" e desligar o modo avião.
   - Na aba Sincronizar, o aviso "A fila espera o catálogo de avaliação…" aparece.
   - Abrir a aba Sessões: a avaliação sai sozinha, sem tocar em "Sincronizar agora", e o aviso some.
2. **Checklist com o participante liberado:**
   - Com o checklist de um participante aberto no app, desatribuí-lo pelo painel web (ADMIN).
   - No app, puxar para atualizar o detalhe e voltar ao checklist, ou abrir de novo.
   - O aviso "Este participante não está mais com você" aparece, e os B/PM/M não respondem.
3. **Adicionar participante (ADMIN):**
   - Digitar um CPF novo: quando a consulta termina, o cursor vai sozinho para o nome.
   - Corrigir um dígito no meio do CPF: o cursor fica onde se está digitando.
   - No e-mail, digitar `maria@empresa..com` e sair do campo: aparece "E-mail inválido.".
4. **Dados do treinamento (ADMIN):**
   - Com o teclado aberto na cidade, tocar em "Cancelar sessão" e depois em "Voltar": o teclado não volta sozinho.
   - Criar pelo painel web uma sessão de teste sem participantes, abri-la no app (1.12), apagá-la pelo painel, mudar a cidade no app e tocar em "Salvar alterações".
   - A tela trava com "Esta sessão não existe mais.", e o voltar sai sem perguntar.
5. **Iniciar recusado:**
   - Abrir o detalhe de uma sessão planejada no app e iniciá-la pelo painel web.
   - No app, sem atualizar, tocar em "Iniciar sessão" e confirmar.
   - A recusa "Só dá para iniciar um treinamento planejado" aparece, e o detalhe passa a "Em andamento" sozinho.
6. **Fonte ampliada:** em Configurações, pôr o tamanho da fonte acima do normal (1,3× ou mais).
   - No detalhe, tocar no chip "Concluídos": só a barra dos chips rola, e o cabeçalho continua no lugar.
   - Abrir a busca, fechar o teclado, rolar a lista até o campo sumir e voltar: o teclado não abre sozinho, e o texto continua.
   - Voltar a fonte para o normal.
7. **Busca sem a sessão baixada:** com o modo avião ligado, abrir uma sessão que nunca foi aberta e buscar um nome.
   - A frase "A busca procura nos participantes baixados…" aparece, sem "0 de 0".
8. **Home:** rolar até "Concluídas", abrir a busca, digitar um nome e fechar a busca. O chip destacado é o da seção que está na tela.

- [ ] **Step 3: Roteiro no tablet (emulador)**

1. **Sincronizar:** repetir o passo 1 do celular. O aviso do catálogo aparece na coluna da fila, e ela sai sozinha.
2. **Consultores (ADMIN):** com o modo avião ligado, abrir a janela de consultores e buscar um nome que não existe. A frase "Nenhum consultor encontrado" aparece junto de "A equipe aparece quando houver conexão." (fica como antes).

- [ ] **Step 4: Registrar o resultado**

Se tudo passar, acrescentar ao fim desta task a linha "**Validado em <data>: celular no aparelho físico e tablet no emulador; roteiro inteiro passou. Aval dado para planejar a 8D-3.**" e commitar:

```bash
git add apps/mobile/docs/superpowers/plans/2026-10-30-mobile-fase-8d2-defeitos-de-borda.md
git commit -m "docs(mobile): registra a validacao da fase 8d-2"
```

Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio, parar e perguntar.

O que não dá para provocar pelas telas fica coberto só pelos testes:
- o 4xx no lote inteiro;
- a recusa da renovação depois de outro login;
- a keystore que falha;
- a troca de servidor que não apaga;
- a abertura com rede ruim (o limite de 5 s);
- o aviso "Você já está avaliando…" que some sozinho;
- o "Não salvo" com o descarte e com a leitura que falhou;
- o "Desatribuindo…" do leitor de tela.

---

## Observações levadas para a 8D-3

- **"Última sincronização" depois de reabrir o app:** pode mostrar o envio anterior que ainda está no aparelho, se a reavaliação apagou o mais novo (ver "Ajustes"). Resolver de vez pede guardar o horário no banco.
- **`lockedReason` enquanto a tela carrega:** na 1.11 e na 1.12, ele devolve "Esta sessão não está mais disponível neste aparelho." antes da primeira leitura do cache. Hoje não tem efeito, porque as telas olham o carregamento antes. É do inventário da 6A.
- **Do backend, da revisão final da 8D-1:** o envio grava o participante sem condição, e atribuir e cancelar podem acontecer ao mesmo tempo. São janelas de milissegundos, registradas no plano da 8D-1, e só entram com o aval do usuário.
