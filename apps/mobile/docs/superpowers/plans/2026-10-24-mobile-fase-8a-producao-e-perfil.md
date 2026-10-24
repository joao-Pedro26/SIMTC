# App Mobile SIMTC — Fase 8A: Produção e Perfil — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O backend e o painel web desta branch passam a rodar na produção (que é um ambiente de teste), e o app passa a falar com ela por padrão. A aba Perfil (1.10) existe no celular e no tablet, com o "Sair da conta" e o "Limpar cache local". Sair e entrar com outro consultor não deixa nada do anterior aparecer.

**Architecture:** A publicação (Task 1) é feita pelo controlador, sem subagente: envio da `feat/mobile-app` ao GitHub, PR para a `feat/frontend-backend-integration` (a branch que o EasyPanel publica) e merge, cada passo com o OK do usuário. No app, um serviço novo, `DeviceDataService`, cuida dos dados do aparelho como um todo: mede e apaga o que foi baixado ("Limpar cache local") e, na abertura, apaga tudo se o endereço da API mudou desde a última abertura. A aba Perfil tem a sua `ProfileViewModel` e lê a fila e a última sincronização do `AssessmentSyncService`, que já existe. Um contador de "geração" do cache no `AppDatabase` impede que um download que termina depois do "Sair" regrave a agenda de quem saiu. O envio da fila ganha as proteções que os planos 5A e 5B deixaram para "quando houver Sair".

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · drift 2.31.0 (sem mudança de esquema) · flutter_secure_storage 9.2.4 · flutter_cache_manager 3.4.2 · **package_info_plus 9.0.1 (novo)** · mocktail (testes).

**Spec:** `apps/mobile/docs/superpowers/specs/2026-10-24-mobile-fase-8-design.md` (desenho aprovado em 24/10/2026; este plano é a 8A); canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html`: quadros `2i` (1.10 Perfil no celular, linha 1387), `4k` (tablet em paisagem, 2589) e `4v` (tablet em retrato, 2637), com as linhas de `profileRows` (3805).

**Validação prévia:** todo o código das Tasks 2 a 7 foi escrito e rodado numa cópia descartável do app antes de o plano ser fechado, uma task por commit, e depois as tasks foram **reencenadas em ordem** numa segunda cópia limpa, a partir dos blocos deste plano: em cada task, os testes da task falharam antes da implementação e passaram depois, e cada checkpoint bateu o número de testes — **1010 → 1022 → 1029 → 1035 → 1052 → 1067 → 1072**, com `flutter analyze` sem issues em todos. Os blocos de código foram gerados da primeira cópia por um script que confere cada "substituir / por" contra o estado deixado pelo bloco anterior, e a reencenação conferiu que a árvore de cada task ficou **idêntica** à do commit correspondente. **Cada decisão, texto e medida foi conferido por mutação** (o trecho é trocado, e algum teste tem de falhar): **63 mutações, todas acusadas**. As medidas do Perfil são testadas com a Inter de verdade, e as telas foram **desenhadas com as fontes de verdade** em 412×915, 360×640 com fonte em 1,3x e sem rede, 1280×800, 800×1280 e 1000×800, e conferidas a olho contra os quadros `2i`, `4k` e `4v`. A Task 1 (publicação) não tem código: o `migrate deploy` do contêiner já foi commitado (`a90f6b5`) e não pôde ser testado aqui (não há Docker nesta máquina); a prova é o primeiro deploy.

## Decisões tomadas com o usuário

Do desenho da Fase 8 (24/10/2026): a fase se divide em 8A (produção e Perfil), 8B (buscas), 8C (telas e acessibilidade) e 8D (defeitos de borda, limpeza, testes e QA final), nessa ordem; a produção é uma VPS da Hostinger com EasyPanel, que publica backend e web sozinha quando o código chega na `feat/frontend-backend-integration`, e o banco dela é de teste e já tem dados de teste; o contêiner do backend roda `prisma migrate deploy` ao subir (feito em `a90f6b5`).

1. **O app aponta para a produção por padrão, inclusive no `flutter run`.** O backend local continua possível por `--dart-define=API_BASE_URL=http://localhost:3001/api`.
2. **Um app só no aparelho** (desenvolvimento e produção não ficam lado a lado).
3. **Trocar de servidor apaga tudo o que está no aparelho**: sessões, participantes, consultores, catálogo, fila, rascunhos, logos e o login. Apagar a fila sem aviso é intencional.
4. **"Sair da conta" com fila ou rascunho avisa e deixa sair.** A fila e os rascunhos ficam no aparelho e voltam quando a pessoa entrar de novo. Só as sessões baixadas são apagadas.
5. **A linha "Empresa" do Perfil sai** (o backend não liga consultor a empresa).
6. **"Limpar cache local" entra**, com o espaço ocupado.
7. **A tela de Perfil como descrita no desenho** (aprovada em chat).
8. **Escolhas do desenho, sem objeção:** a versão lida pelo `package_info_plus` no formato `1.0.0 (1)`; "Perfil de acesso" mostra "Consultor" ou "Administrador"; "Última sincronização" mostra só o momento ("hoje 07:12") ou "Nenhum envio"; "Limpar cache local" fica desativado sem rede; a confirmação do "Sair" sem rede avisa que entrar de novo exige conexão; o rodapé do Perfil diz "Sair apaga as sessões baixadas neste aparelho. As avaliações na fila ficam guardadas e são enviadas quando você entrar de novo."; o release continua assinado com a chave de debug; o "Sair" sem rede não invalida o token no servidor; os defeitos do envio deixados para "quando houver Sair" entram aqui.

### Ajustes feitos ao preparar o plano (revisar junto com o plano)

A validação na cópia descartável levou a estas escolhas. **Nenhuma muda regra de negócio aprovada**, mas cada uma é uma regra que o código cria, um texto novo ou uma medida, que o usuário deve conferir.

**Textos novos (nenhum está no canvas):**

- **Confirmação do "Sair":** título "Sair da conta?", botões "Cancelar" e "Sair" (vermelho). O corpo tem um parágrafo por assunto, separados por linha em branco:
  - sempre: "As sessões baixadas neste aparelho serão apagadas.";
  - com uma na fila: "A avaliação na fila fica guardada neste aparelho e é enviada quando você entrar de novo."; com mais: "3 avaliações na fila ficam guardadas neste aparelho e são enviadas quando você entrar de novo.";
  - com uma iniciada: "A avaliação iniciada fica guardada para você continuar quando entrar de novo."; com mais: "2 avaliações iniciadas ficam guardadas para você continuar quando entrar de novo.";
  - sem rede: "Sem conexão, você só consegue entrar de novo quando houver rede.".
  - A contagem das iniciadas inclui as presas (sessão concluída, participante liberado), que também ficam no aparelho.
- **Confirmação do "Limpar cache local":** título "Limpar cache local?", texto "As sessões, os participantes, o catálogo e os logos baixados serão apagados e baixados de novo quando você abrir as sessões. A fila e as avaliações iniciadas não são apagadas.", botões "Cancelar" e "Limpar" (na cor da marca, não vermelho: nada se perde).
- **Avisos passageiros:** "Cache local limpo.", "Não foi possível limpar o cache. Tente de novo." e "Não foi possível sair. Tente de novo.".
- **Sem rede**, a linha "Limpar cache local" ganha embaixo do rótulo "Disponível quando houver conexão" (o mesmo texto dos botões apagados das outras telas).
- **Valores:** o espaço em KB abaixo de 1 MB ("36 KB") e com uma casa e vírgula acima ("18,4 MB", "1,3 GB"); "—" enquanto o espaço ou a versão não foram lidos (ou se a leitura falhar).

**Regras que o código cria:**

- **O "Sair" espera o servidor por até 5 segundos.** Com sinal ruim, o `POST /auth/logout` levaria os 15 s do cliente HTTP com o botão girando; depois de 5 s, o aparelho sai do mesmo jeito.
- **"Limpar cache local" e "Sair da conta" não correm juntos:** enquanto um gira, o outro fica apagado.
- **Depois de limpar, nada é baixado na hora:** a Home baixa a agenda e o catálogo quando é aberta, como em toda abertura. O valor da linha é medido de novo e mostra o que sobrou (a fila e os rascunhos ocupam poucos kB).
- **O espaço medido é o do banco local inteiro mais o da pasta dos logos.** O banco inclui a fila e os rascunhos, que não são apagados; o número de depois da limpeza mostra esse resto.
- **Troca de servidor:** nenhum endereço guardado conta como troca (a primeira abertura depois da 8A apaga o aparelho, inclusive a fila feita contra o backend local); se o armazenamento seguro não consegue nem ler o endereço guardado (keystore invalidada), **nada é apagado** — sem saber o servidor anterior, apagar a fila a cada abertura seria pior; falhas ao apagar o login ou os logos não impedem a troca.
- **Um download que termina depois do "Sair" (ou do "Limpar cache local") não grava nada** e vira falha silenciosa: senão, a agenda de quem saiu voltaria para o próximo a entrar. Vale para a lista da Home e para o detalhe da sessão.
- **Envio da fila:** com o usuário trocado enquanto o lote é montado, o lote não é enviado (o token já seria o de quem entrou); um 401 com o usuário ainda logado tenta de novo pela espera crescente, em vez de esperar outro gatilho; uma falha ao dar dono às avaliações antigas, ou numa leitura da fila, não para de seguir a fila; quem toca em "Sincronizar agora" com um envio no ar espera também a rodada repetida.
- **Uma falha da keystore ao apagar o perfil do login anterior não impede o login.** O perfil novo é gravado logo depois; só o app morrendo entre os dois deixaria o antigo.
- **`AppConfig.environment` e `isProduction` saem** (ninguém os usava; com a produção como padrão, o nome "dev" mentiria).

**Medidas (canvas `2i`, `4k`, `4v`):**

- **As linhas do Perfil ficam coladas, com uma divisória de 1,5 só embaixo de cada uma** (e uma em cima do grupo). O quadro desenha em cima e embaixo de cada linha, o que somaria 3 entre duas (o mesmo ajuste da 7B no Conferir e finalizar).
- **O "Sair da conta" usa o contorno vermelho que o app já tem** (`#FCA5A5`, o do "Cancelar sessão"); o quadro usa `#E9A2A2`. É uma das decisões visuais em aberto da 6A, que a 8C decide para todos.
- **No tablet, o "Sair da conta" é o botão compacto do app** (48 de altura, recuo 16, ícone 19, texto 14); o quadro tem recuo 18 e ícone 20.
- **No celular, a navbar fica embaixo da tela** (como em Sessões e Sincronizar), e não flutuando por cima do conteúdo com os 100 de recuo do quadro; a lista termina 24 acima dela.
- **O e-mail corta com reticências** quando não cabe, também no tablet em paisagem (o quadro só corta em retrato).
- **Numa janela de tablet mais estreita que 600 (tela dividida)**, a coluna fica com 24 de margem e o "Sair da conta" continua ao lado do nome.

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app`. Sem git worktree. **Só a Task 1 envia ao GitHub e faz merge**, pelo controlador, com o OK do usuário em cada passo; as outras tasks não criam branch, não fazem merge nem push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada, com a mensagem exata dada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem trabalho do usuário fora do git, que **não é desta fase e fica exatamente como está**: um arquivo rastreado **já modificado** (`brainstorm-app-mobile.md`) e os não rastreados `.vscode/`, `IMPLEMENTATION-STATUS.md`, `apps/backend/test-render.js`, `apps/mobile/simtc/devtools_options.yaml`, `apps/web/src/app/(client)/my-company/trainings/[id]/certificates/`, `brainstorm-implementacao-mobile.md`, `prompt-claude-design-mobile.md`, `prompt-implementacao-mobile-claude-code.md`, `test-pdf.js` e `test-render.js`.
- **Proibido `git restore`, `git checkout -- <arquivo>`, `git stash`, `git reset` e `git clean`**, e qualquer outro comando que desfaça mudança que não é da task. Se o `git status` mostrar algo que não é da task, ignorar e seguir.
- **Na execução por subagentes:** antes do primeiro despacho, guardar a linha de base — o `git status --porcelain` inteiro e o `git hash-object brainstorm-app-mobile.md` — e compará-la, sem filtrar nada, depois de **cada** subagente. Todo despacho repete as duas regras acima com todas as letras. Implementadores em **haiku**; revisões com modelo mais forte (sonnet nas Tasks 2, 5, 6 e 7; opus nas Tasks 3 e 4, que mexem no envio da fila e nas corridas do cache).
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- **Nunca rodar o `seed` nem mexer no banco de produção** sem pedido do usuário.
- Artefatos SDD em `.superpowers/sdd/2026-10-24-mobile-fase-8a-producao-e-perfil/`.

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

Os casos que o desenho implica, que um consultor em campo (ou o usuário testando) vai encontrar, e onde cada um ficou preso num teste:

1. **Sair com a agenda ainda baixando e entrar com outro consultor** → a agenda do anterior não volta. Preso em: `a agenda que chega depois de o cache ser apagado (sair da conta) não grava — senão ela voltaria para o próximo a entrar` (Task 3) e no mesmo para o detalhe da sessão.
2. **Sair com o envio da fila a caminho e outro consultor entrando** → a fila de quem saiu não sai no nome de quem entrou nem ganha "não está mais com você". Preso em: `trocar de usuário com o envio a caminho não manda a fila de quem saiu no nome de quem entrou` (Task 4).
3. **Voltar ao backend local (ou à produção) com avaliações na fila** → tudo é apagado e o app pede login, em vez de mandar a fila ao servidor errado. Preso em: `outro servidor apaga tudo — inclusive a fila e os rascunhos —, o login e os logos, e guarda o endereço novo` (Task 2).
4. **Tocar "Sair" sem sinal, com avaliações na fila** → a confirmação diz o que fica guardado e que entrar de novo exige rede. Preso em: `com fila e rascunho, sem rede, a confirmação avisa o que fica guardado e que entrar de novo precisa de rede` (Task 6).
5. **Girar o tablet com a limpeza do cache em andamento** → a tela não é recriada e o fim da limpeza chega. Preso em: `no tablet, girar com a limpeza em andamento não recria a tela: a linha continua girando e o fim da limpeza chega` (Task 7).

## Estado herdado (ponto de partida)

HEAD = o commit deste plano, sobre `54d6b6d` (o desenho da Fase 8) e `a90f6b5` (o `migrate deploy` no contêiner). App: `flutter analyze` limpo; **1010 testes passando**.

Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| Logout sem tela | `lib/data/repositories/auth_repository.dart` | `logout()` (chama `POST /auth/logout`, limpa tokens e o cache de sessões), `currentUser`, `handleSessionExpired()` |
| Tokens e perfil salvos | `lib/data/services/local/token_storage.dart`, `lib/data/services/auth_session.dart` | `TokenStorage.clear()`, `AuthSession.start()` |
| Banco | `lib/data/services/local/app_database.dart` | `clearSessionsCache()`; tabelas `Sessions`, `Participants`, `SessionConsultants`, `AssessmentCategories`, `Infractions`, `InfractionNotes`, `LocalAssessments`, `LocalAssessmentItems` |
| Envio da fila | `lib/data/services/assessment_sync_service.dart` | `queue`, `lastSyncedAt`, `syncNow()`, `isSending`; segue o usuário por `_onAuthChanged` |
| Aba Sincronizar (modelo da aba Perfil) | `lib/ui/sync/sync_screen.dart` | cabeçalho, `PopScope` que volta a Sessões, `TabSnackBarArea`, `TabletNavFrame` no tablet, `AppNavBar` no celular; `lastSyncLabel` em `sync_queue_labels.dart` |
| Navbar | `lib/ui/core/widgets/app_nav_bar.dart` | `AppTab`, `AppNavBar`, `TabletNavFrame`; hoje o "Perfil" mostra "Disponível em breve." |
| Botão vermelho | `lib/ui/core/widgets/app_buttons.dart` | `AppDangerOutlineButton(compact:)` |
| Rótulos de horário | `lib/ui/core/date_labels.dart` | `momentLabel(moment, now)` |
| Testes | `test/support/fake_assessment_sync_service.dart` | `FakeAssessmentSyncService(queue:, lastSyncedAt:)`, `queuedAssessment(id)` |

## Mapa de Arquivos

### Novos

| Arquivo | Task | Responsabilidade |
|---|---|---|
| `lib/data/services/device_data_service.dart` | 2 | `LogoCache`, `DeviceDataService` (troca de servidor, espaço e limpeza do cache) |
| `lib/ui/profile/profile_labels.dart` | 5 | `roleLabel`, `lastSyncValue`, `sizeLabel`, `logoutMessage` |
| `lib/ui/profile/profile_viewmodel.dart` | 5 | `ProfileViewModel` |
| `lib/ui/profile/profile_screen.dart` | 6, 7 | a aba Perfil no celular e no tablet |
| `test/ui/profile/profile_harness.dart` | 6 | monta a aba com os serviços de mentira (compartilhado pelos testes de comportamento e de medida) |

### Modificados

| Arquivo | Tasks | O que muda |
|---|---|---|
| `lib/config/app_config.dart`, `README.md` | 2 | produção como padrão; saem `environment`/`isProduction` |
| `lib/data/services/local/token_storage.dart` | 2 | `readApiBaseUrl`, `saveApiBaseUrl` |
| `lib/data/services/local/app_database.dart` | 2, 3 | `clearDownloadedData`, `clearAll`, `usedBytes`; `cacheGeneration` |
| `lib/ui/splash/splash_viewmodel.dart`, `splash_screen.dart`, `lib/app_providers.dart` | 2 | a abertura confere o servidor; o `DeviceDataService` no app |
| `lib/data/repositories/session_repository.dart`, `participant_repository.dart` | 3 | download depois do "Sair" não grava |
| `lib/ui/sessions/sessions_list_viewmodel.dart` | 3 | guarda de dispose |
| `lib/data/services/auth_session.dart`, `lib/data/repositories/auth_repository.dart` | 3 | `deleteUser` tolerante; `logoutTimeout` |
| `lib/data/services/assessment_sync_service.dart` | 4 | as proteções do envio |
| `lib/data/repositories/assessment_repository.dart`, `pubspec.yaml`, `pubspec.lock` | 5 | `countDrafts`; `package_info_plus` |
| `lib/ui/core/theme/app_typography.dart`, `app_icons.dart`, `lib/router.dart`, `lib/ui/core/widgets/app_nav_bar.dart` | 6, 7 | tokens do Perfil; `AppIcons.accessRole`/`clearCache`; rota `/profile`; `AppTab.profile` |
| `lib/ui/core/widgets/app_buttons.dart` | 7 | `AppDangerOutlineButton.expand` |
| testes existentes | todas | `app_config_test`, `token_storage_test`, `splash_screen_test`, `app_database_test`, `session_repository_test`, `participant_repository_test`, `auth_repository_test`, `sessions_list_viewmodel_test`, `assessment_sync_service_test`, `assessment_repository_test`, `app_nav_bar_test`, `sessions_screen_test` |

---

## Task 1: Publicar a branch na produção

Feita pelo **controlador**, sem subagente, antes das outras: o resto da fase é testado contra a produção. Cada passo marcado com ⚠ só acontece depois de o usuário dizer "pode" naquele momento.

**Interfaces:**
- Consumes: o commit `a90f6b5` (o contêiner roda `npx prisma migrate deploy && exec node dist/src/main`).
- Produces: a produção (`https://api.simtc.com.br/api` e o painel web) rodando o código da `feat/mobile-app`, com as migrações aplicadas.

- [ ] **Step 1: O usuário confere o EasyPanel**

Pedir ao usuário que confira, no serviço do **backend**: a variável `DIRECT_URL` definida (conexão direta ao banco, usada pelo `migrate deploy`); o Dockerfile `Dockerfile.backend`; nenhum comando de partida próprio (passaria por cima do `CMD`). No serviço do **web**: a variável `NEXT_PUBLIC_API_URL` (usada no build) apontando para `https://api.simtc.com.br/api`; o Dockerfile `Dockerfile.web`. Esperar a confirmação.

- [ ] **Step 2: Conferir o que vai subir**

Run (da raiz): `git log --oneline origin/feat/frontend-backend-integration..feat/mobile-app | wc -l` e `git ls-files | grep -iE "(^|/)\.env|\.pem$|\.jks$|\.keystore$|key\.properties"`
Esperado: o número de commits só locais (225 em 24/10/2026, mais os deste plano) e **nenhum** arquivo de segredo listado (em 24/10/2026, só aparece a migração `add_consultant_credentials`, que não é segredo). Se aparecer um `.env` ou chave, parar e avisar o usuário.

- [ ] **Step 3: ⚠ Enviar a branch**

Run: `git push -u origin feat/mobile-app`
Esperado: a branch aparece no GitHub.

- [ ] **Step 4: ⚠ Abrir o PR**

Run: `gh pr create --base feat/frontend-backend-integration --head feat/mobile-app --title "App mobile (fases 0 a 8A) e ajustes de backend e web" --body-file <arquivo>`, com um corpo curto em português (o que entra: o app mobile, as rotas novas do backend, as 11 migrações, o `migrate deploy` no contêiner e os ajustes do painel web) terminando com a linha `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
Esperado: o link do PR. Mostrar ao usuário.

- [ ] **Step 5: ⚠ Fazer o merge**

Com o OK do usuário: `gh pr merge <número> --merge` (merge comum; a `feat/mobile-app` contém a `feat/frontend-backend-integration`, então não há conflito).
Esperado: a `feat/frontend-backend-integration` do GitHub aponta para o último commit da `feat/mobile-app`. Atualizar a local: `git fetch origin` (não trocar de branch).

- [ ] **Step 6: Conferir a produção**

Esperar o EasyPanel publicar (o usuário acompanha o log do deploy; o do backend mostra o `prisma migrate deploy` aplicando as migrações). Depois:

Run: `curl -s -X POST https://api.simtc.com.br/api/training-sessions/x/participants/lookup -H "Content-Type: application/json" -d '{}'`
Esperado: `{"message":"Unauthorized","statusCode":401}` (antes era 404: a rota existe agora).

Se o log do backend mostrar o erro `P3005` ("The database schema is not empty"), o banco foi criado sem o histórico de migrações: **parar e avisar o usuário**, sem tentar nenhum ajuste no banco. Se o backend não subir por outro motivo, mostrar o log ao usuário antes de qualquer coisa.

- [ ] **Step 7: Conferir o login do web**

Pedir ao usuário que entre no painel web de produção com uma conta de teste e abra uma sessão. Esperar a confirmação.

Não há commit nesta task.

---

## Task 2: Produção como padrão e limpeza dos dados do aparelho

O app passa a falar com `https://api.simtc.com.br/api` por padrão, inclusive no `flutter run`; o backend local fica pelo `--dart-define` (decisões 1 e 2). Nasce o `DeviceDataService`: na abertura, antes de retomar a sessão, ele compara o endereço da API com o da abertura anterior e, se mudou, apaga tudo — sessões, catálogo, fila, rascunhos, logos e o login (decisão 3). Ele também mede e apaga o que foi baixado, para o "Limpar cache local" da Task 6. O `README.md` do app troca a tabela de ambientes.

**Files:**
- Create: `lib/data/services/device_data_service.dart`
- Create: `test/data/services/device_data_service_test.dart`
- Create: `test/ui/splash/splash_viewmodel_test.dart`
- Modify: `README.md`
- Modify: `lib/app_providers.dart`
- Modify: `lib/config/app_config.dart`
- Modify: `lib/data/services/local/app_database.dart`
- Modify: `lib/data/services/local/token_storage.dart`
- Modify: `lib/ui/splash/splash_screen.dart`
- Modify: `lib/ui/splash/splash_viewmodel.dart`
- Modify: `test/config/app_config_test.dart`
- Modify: `test/data/services/local/token_storage_test.dart`
- Modify: `test/ui/splash/splash_screen_test.dart`

**Interfaces:**
- Consumes: as tabelas do `AppDatabase`, o `TokenStorage` e o `DefaultCacheManager` do `flutter_cache_manager` (já existentes).
- Produces:
  - `AppConfig.apiBaseUrl` com o padrão `https://api.simtc.com.br/api` (saem `AppConfig.environment` e `isProduction`)
  - `TokenStorage.readApiBaseUrl() → Future<String?>` e `saveApiBaseUrl(String)` (chave `app.apiBaseUrl`, que o `clear()` não apaga)
  - `AppDatabase.clearDownloadedData()`, `clearAll()` e `usedBytes() → Future<int>`
  - `LogoCache` (`sizeInBytes()`, `clear()`) e `DeviceDataService({database, storage, logos})`: `resetIfServerChanged(String apiBaseUrl) → Future<bool>`, `downloadedBytes() → Future<int>`, `clearDownloaded()`
  - `SplashViewModel({authRepository, deviceData, apiBaseUrl})`; `Provider<DeviceDataService>` em `AppDependencies.providers`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/config/app_config_test.dart`, substituir:

```dart
    test('sem --dart-define, aponta para o backend local com o prefixo /api', () {
      expect(AppConfig.apiBaseUrl, 'http://localhost:3001/api');
      expect(AppConfig.environment, 'dev');
      expect(AppConfig.isProduction, isFalse);
```

por:

```dart
    test('sem --dart-define, aponta para a API de produção com o prefixo /api',
        () {
      expect(AppConfig.apiBaseUrl, 'https://api.simtc.com.br/api');
```

Criar `test/data/services/device_data_service_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/services/device_data_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/data/services/local/token_storage.dart';

class _MockTokenStorage extends Mock implements TokenStorage {}

class _FakeLogoCache implements LogoCache {
  int bytes = 0;
  int clears = 0;
  bool failClear = false;

  @override
  Future<int> sizeInBytes() async => bytes;

  @override
  Future<void> clear() async {
    clears++;
    if (failClear) throw Exception('pasta presa');
  }
}

void main() {
  const production = 'https://api.simtc.com.br/api';
  const local = 'http://localhost:3001/api';

  late AppDatabase db;
  late _MockTokenStorage storage;
  late _FakeLogoCache logos;
  late DeviceDataService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    storage = _MockTokenStorage();
    logos = _FakeLogoCache();
    service = DeviceDataService(database: db, storage: storage, logos: logos);
    when(() => storage.clear()).thenAnswer((_) async {});
    when(() => storage.saveApiBaseUrl(any())).thenAnswer((_) async {});
  });

  tearDown(() => db.close());

  /// Uma sessão com [participants] participantes e um consultor, o catálogo
  /// com uma nota, e um rascunho com uma marcação.
  Future<void> seed({int participants = 1}) async {
    final at = DateTime(2026, 10, 24, 8);
    await db.into(db.sessions).insert(SessionsCompanion.insert(
          id: 'sess-1',
          companyName: 'Bracell Celulose',
          courseName: 'Direção Preventiva',
          city: 'Lençóis Paulista',
          state: 'SP',
          status: 'EM_ANDAMENTO',
          cachedAt: at,
        ));
    for (var i = 0; i < participants; i++) {
      await db.into(db.participants).insert(ParticipantsCompanion.insert(
            id: 'tp-$i',
            sessionId: 'sess-1',
            name: 'Participante com um nome bem comprido para ocupar espaço $i',
            cpf: '***.456.789-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'PENDENTE',
            cachedAt: at,
          ));
    }
    await db.into(db.sessionConsultants).insert(SessionConsultantsCompanion.insert(
          sessionId: 'sess-1',
          consultantId: 'c-1',
          name: 'Carla Mendes',
        ));
    await db.into(db.assessmentCategories).insert(
        AssessmentCategoriesCompanion.insert(id: 'cat-1', code: 'A', name: 'Antes', order: 1));
    await db.into(db.infractions).insert(InfractionsCompanion.insert(
        id: 'inf-1', categoryId: 'cat-1', description: 'Cinto', order: 1));
    await db.into(db.infractionNotes).insert(InfractionNotesCompanion.insert(
        id: 'note-1', infractionId: 'inf-1', noteType: 'M', deduction: 3));
    await db.into(db.localAssessments).insert(LocalAssessmentsCompanion.insert(
          id: 'local-1',
          trainingParticipantId: 'tp-0',
          sessionId: 'sess-1',
          date: DateTime(2026, 10, 24),
          startTime: at,
          syncStatus: LocalSyncStatus.pendingSync,
          createdAt: at,
          updatedAt: at,
        ));
    await db.into(db.localAssessmentItems).insert(LocalAssessmentItemsCompanion.insert(
          id: 'item-1',
          localAssessmentId: 'local-1',
          infractionId: 'inf-1',
          infractionNoteId: 'note-1',
          updatedAt: at,
        ));
  }

  Future<Map<String, int>> counts() async => {
        'sessões': (await db.select(db.sessions).get()).length,
        'participantes': (await db.select(db.participants).get()).length,
        'consultores': (await db.select(db.sessionConsultants).get()).length,
        'categorias': (await db.select(db.assessmentCategories).get()).length,
        'infrações': (await db.select(db.infractions).get()).length,
        'notas': (await db.select(db.infractionNotes).get()).length,
        'avaliações': (await db.select(db.localAssessments).get()).length,
        'marcações': (await db.select(db.localAssessmentItems).get()).length,
      };

  const everything = {
    'sessões': 1,
    'participantes': 1,
    'consultores': 1,
    'categorias': 1,
    'infrações': 1,
    'notas': 1,
    'avaliações': 1,
    'marcações': 1,
  };

  const nothing = {
    'sessões': 0,
    'participantes': 0,
    'consultores': 0,
    'categorias': 0,
    'infrações': 0,
    'notas': 0,
    'avaliações': 0,
    'marcações': 0,
  };

  group('troca de servidor', () {
    test('o mesmo servidor da última abertura não apaga nada', () async {
      await seed();
      when(() => storage.readApiBaseUrl()).thenAnswer((_) async => production);

      expect(await service.resetIfServerChanged(production), isFalse);

      expect(await counts(), everything);
      verifyNever(() => storage.clear());
      verifyNever(() => storage.saveApiBaseUrl(any()));
      expect(logos.clears, 0);
    });

    test('outro servidor apaga tudo — inclusive a fila e os rascunhos —, o '
        'login e os logos, e guarda o endereço novo', () async {
      await seed();
      when(() => storage.readApiBaseUrl()).thenAnswer((_) async => local);

      expect(await service.resetIfServerChanged(production), isTrue);

      expect(await counts(), nothing);
      verify(() => storage.clear()).called(1);
      expect(logos.clears, 1);
      verify(() => storage.saveApiBaseUrl(production)).called(1);
    });

    test('nenhum endereço guardado conta como troca', () async {
      await seed();
      when(() => storage.readApiBaseUrl()).thenAnswer((_) async => null);

      expect(await service.resetIfServerChanged(production), isTrue);

      expect(await counts(), nothing);
      verify(() => storage.saveApiBaseUrl(production)).called(1);
    });

    test('sem conseguir ler o endereço guardado, não apaga nada', () async {
      await seed();
      when(() => storage.readApiBaseUrl()).thenThrow(Exception('keystore'));

      expect(await service.resetIfServerChanged(production), isFalse);

      expect(await counts(), everything);
      verifyNever(() => storage.saveApiBaseUrl(any()));
    });

    test('falha ao apagar o login ou os logos não impede a troca', () async {
      await seed();
      when(() => storage.readApiBaseUrl()).thenAnswer((_) async => local);
      when(() => storage.clear()).thenThrow(Exception('keystore'));
      logos.failClear = true;

      expect(await service.resetIfServerChanged(production), isTrue);

      expect(await counts(), nothing);
      verify(() => storage.saveApiBaseUrl(production)).called(1);
    });
  });

  group('limpar cache local', () {
    test('apaga sessões, participantes, consultores, catálogo e logos, e '
        'mantém a fila e os rascunhos', () async {
      await seed();

      await service.clearDownloaded();

      expect(await counts(), {
        ...nothing,
        'avaliações': 1,
        'marcações': 1,
      });
      expect(logos.clears, 1);
      verifyNever(() => storage.clear());
    });

    test('o espaço é o do banco mais o dos logos, e cai depois de limpar',
        () async {
      await seed(participants: 400);
      logos.bytes = 5000;

      final before = await service.downloadedBytes();
      expect(before, await db.usedBytes() + 5000);

      await service.clearDownloaded();
      logos.bytes = 0;

      expect(await service.downloadedBytes(), lessThan(before - 5000));
    });

    test('uma falha ao apagar os logos não desfaz a limpeza do banco',
        () async {
      await seed();
      logos.failClear = true;

      await service.clearDownloaded();

      expect((await counts())['sessões'], 0);
    });
  });
}
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
      'o endereço da API tem chave própria, que o clear não apaga — sair da '
      'conta não muda de servidor', () async {
    final secure = _MockSecureStorage();
    when(() => secure.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(() => secure.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    when(() => secure.read(key: 'app.apiBaseUrl'))
        .thenAnswer((_) async => 'https://api.simtc.com.br/api');
    final storage = TokenStorage(storage: secure);

    await storage.saveApiBaseUrl('https://api.simtc.com.br/api');
    expect(await storage.readApiBaseUrl(), 'https://api.simtc.com.br/api');
    await storage.clear();

    verify(() => secure.write(
          key: 'app.apiBaseUrl',
          value: 'https://api.simtc.com.br/api',
        )).called(1);
    verifyNever(() => secure.delete(key: 'app.apiBaseUrl'));
  });

  test('deleteUser apaga só o perfil salvo, sem mexer nos tokens', () async {
    final secure = _MockSecureStorage();
```

Em `test/ui/splash/splash_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/splash/splash_screen.dart';
import 'package:simtc/utils/result.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository auth;
  late Completer<Result<AuthUser>> restore;

  setUp(() {
    auth = _MockAuthRepository();
```

por:

```dart
import 'package:simtc/data/services/device_data_service.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/splash/splash_screen.dart';
import 'package:simtc/utils/result.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockDeviceData extends Mock implements DeviceDataService {}

void main() {
  late _MockAuthRepository auth;
  late _MockDeviceData deviceData;
  late Completer<Result<AuthUser>> restore;

  setUp(() {
    auth = _MockAuthRepository();
    deviceData = _MockDeviceData();
    when(() => deviceData.resetIfServerChanged(any()))
        .thenAnswer((_) async => false);
```

Em `test/ui/splash/splash_screen_test.dart`, substituir:

```dart
      ChangeNotifierProvider<AuthRepository>.value(
        value: auth,
```

por:

```dart
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          Provider<DeviceDataService>.value(value: deviceData),
        ],
```

Criar `test/ui/splash/splash_viewmodel_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/config/app_config.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/services/device_data_service.dart';
import 'package:simtc/ui/splash/splash_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockDeviceData extends Mock implements DeviceDataService {}

void main() {
  late _MockAuthRepository auth;
  late _MockDeviceData deviceData;

  setUp(() {
    auth = _MockAuthRepository();
    deviceData = _MockDeviceData();
    when(() => deviceData.resetIfServerChanged(any()))
        .thenAnswer((_) async => true);
  });

  test('confere o servidor antes de retomar a sessão salva', () async {
    when(auth.restoreSession).thenAnswer(
      (_) async => const Success(AuthUser(
        id: 'user-1',
        name: 'Carla Mendes',
        email: 'carla@simtc.com.br',
        role: AppUserRole.consultant,
      )),
    );
    final viewModel = SplashViewModel(
      authRepository: auth,
      deviceData: deviceData,
      apiBaseUrl: 'http://localhost:3001/api',
    );
    addTearDown(viewModel.dispose);

    expect(await viewModel.decideInitialRoute(), isTrue);

    verifyInOrder([
      () => deviceData.resetIfServerChanged('http://localhost:3001/api'),
      () => auth.restoreSession(),
    ]);
  });

  test('sem sessão salva, vai para o login', () async {
    when(auth.restoreSession)
        .thenAnswer((_) async => Failure(Exception('sem sessão'), 'Entre.'));
    final viewModel = SplashViewModel(authRepository: auth, deviceData: deviceData);
    addTearDown(viewModel.dispose);

    expect(await viewModel.decideInitialRoute(), isFalse);
  });

  test('o endereço conferido é, por padrão, o deste build', () {
    final viewModel = SplashViewModel(authRepository: auth, deviceData: deviceData);
    addTearDown(viewModel.dispose);

    expect(viewModel.apiBaseUrl, AppConfig.apiBaseUrl);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/data/services/device_data_service_test.dart test/ui/splash test/config test/data/services/local/token_storage_test.dart`
Esperado: `Some tests failed.` — não compilam `device_data_service_test.dart`, `splash_viewmodel_test.dart`, `splash_screen_test.dart` e `token_storage_test.dart` (`DeviceDataService`, `LogoCache`, `readApiBaseUrl`, `saveApiBaseUrl` e `usedBytes` não existem), e o `app_config_test.dart` falha porque o padrão ainda é `http://localhost:3001/api`.

- [ ] **Step 3: Implementar**

Em `README.md`, substituir:

```
A URL da API é resolvida em tempo de compilação por `--dart-define`:

| Ambiente | Comando | URL |
|---|---|---|
| Desenvolvimento (padrão) | `flutter run -d <ID>` | `http://localhost:3001/api` (backend do PC, via `adb reverse`) |
| Produção | `flutter build apk --release --dart-define=API_BASE_URL=https://api.simtc.com.br/api --dart-define=APP_ENV=prod` | `https://api.simtc.com.br/api` |

Sem `--dart-define`, o app sempre aponta para o backend local — nenhuma build de desenvolvimento fala com produção por engano.
```

por:

```
A URL da API é resolvida em tempo de compilação por `--dart-define`. Desde a Fase 8A (24/10/2026) o padrão é a API de produção, que por enquanto é um ambiente de teste:

| Ambiente | Comando | URL |
|---|---|---|
| Produção (padrão) | `flutter run -d <ID>` ou `flutter build apk --release` | `https://api.simtc.com.br/api` |
| Backend do PC | `flutter run -d <ID> --dart-define=API_BASE_URL=http://localhost:3001/api` (com o `adb reverse` abaixo) | `http://localhost:3001/api` |

**Trocar de endereço apaga os dados do aparelho.** Na abertura, o app compara o endereço da API com o da abertura anterior; se for outro, apaga sessões, catálogo, fila, rascunhos, logos e o login, e pede para entrar de novo. Sem isso, uma avaliação feita contra um servidor seria enviada ao outro. A primeira abertura depois da Fase 8A também passa por essa limpeza.

O APK de release continua assinado com a chave de debug enquanto o app não for distribuído: assim o `flutter run` e o APK instalam um por cima do outro, sem desinstalar (e sem perder a fila).
```

Em `README.md`, substituir:

```
Com isso, `http://localhost:3001/api` **no aparelho** chega ao backend do PC. Para um teste rápido, abra `http://localhost:3001/docs` no Chrome do aparelho: deve aparecer o Swagger da API.
```

por:

```
Com isso, `http://localhost:3001/api` **no aparelho** chega ao backend do PC (só para quem roda com o `--dart-define` do backend do PC, ver "Ambientes"). Para um teste rápido, abra `http://localhost:3001/docs` no Chrome do aparelho: deve aparecer o Swagger da API.
```

Em `lib/app_providers.dart`, substituir:

```dart
import 'data/services/connectivity_service.dart';
import 'data/services/local/app_database.dart';
```

por:

```dart
import 'data/services/connectivity_service.dart';
import 'data/services/device_data_service.dart';
import 'data/services/local/app_database.dart';
```

Em `lib/app_providers.dart`, substituir:

```dart
    required this.assessmentSyncService,
  });
```

por:

```dart
    required this.assessmentSyncService,
    required this.deviceDataService,
  });
```

Em `lib/app_providers.dart`, substituir:

```dart
      assessmentSyncService: assessmentSyncService,
    );
```

por:

```dart
      assessmentSyncService: assessmentSyncService,
      deviceDataService: DeviceDataService(
        database: database,
        storage: tokenStorage,
      ),
    );
```

Em `lib/app_providers.dart`, substituir:

```dart
  final ConnectivityService connectivityService;
  final AssessmentSyncService assessmentSyncService;

  /// Providers na ordem de dependência, para o `MultiProvider` do app.
```

por:

```dart
  final ConnectivityService connectivityService;
  final AssessmentSyncService assessmentSyncService;
  final DeviceDataService deviceDataService;

  /// Providers na ordem de dependência, para o `MultiProvider` do app.
```

Em `lib/app_providers.dart`, substituir:

```dart
        ),
      ];
```

por:

```dart
        ),
        Provider<DeviceDataService>.value(value: deviceDataService),
      ];
```

Em `lib/config/app_config.dart`, substituir:

```dart
/// Desenvolvimento (padrão): o app fala com o backend rodando no PC, alcançado
/// pelo aparelho via `adb reverse tcp:3001` (ver README).
///
/// Produção:
/// ```
/// flutter build apk --release \
///   --dart-define=API_BASE_URL=https://api.simtc.com.br/api \
///   --dart-define=APP_ENV=prod
/// ```
abstract final class AppConfig {
  /// URL base da API, sempre sem barra no final.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/api',
  );

  /// Nome do ambiente: `dev` ou `prod`.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static bool get isProduction => environment == 'prod';
```

por:

```dart
/// Padrão: a API de produção, também no `flutter run` — por enquanto ela é um
/// ambiente de teste (decisão de 24/10/2026). Para falar com o backend do PC,
/// alcançado pelo aparelho via `adb reverse tcp:3001` (ver README):
/// ```
/// flutter run --dart-define=API_BASE_URL=http://localhost:3001/api
/// ```
/// Trocar de endereço apaga os dados do aparelho na abertura seguinte (ver
/// `DeviceDataService.resetIfServerChanged`).
abstract final class AppConfig {
  /// URL base da API, sempre sem barra no final.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.simtc.com.br/api',
  );
```

Criar `lib/data/services/device_data_service.dart`:

```dart
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'local/app_database.dart';
import 'local/token_storage.dart';

/// O cache em disco dos logos das empresas: o `DefaultCacheManager`, usado
/// pelo `CompanyLogo` e pelo `cached_network_image`. Os arquivos ficam na
/// pasta temporária do app, numa subpasta com a chave do gerenciador.
class LogoCache {
  const LogoCache();

  Future<int> sizeInBytes() async {
    final temp = await getTemporaryDirectory();
    final folder = Directory(
      '${temp.path}${Platform.pathSeparator}${DefaultCacheManager.key}',
    );
    if (!await folder.exists()) return 0;
    var total = 0;
    await for (final entry in folder.list(recursive: true, followLinks: false)) {
      if (entry is File) total += await entry.length();
    }
    return total;
  }

  Future<void> clear() => DefaultCacheManager().emptyCache();
}

/// Os dados guardados no aparelho como um todo (Fase 8A): o "Limpar cache
/// local" do Perfil e a limpeza ao trocar de servidor.
class DeviceDataService {
  DeviceDataService({
    required AppDatabase database,
    required TokenStorage storage,
    LogoCache logos = const LogoCache(),
  })  : _db = database,
        _storage = storage,
        _logos = logos;

  final AppDatabase _db;
  final TokenStorage _storage;
  final LogoCache _logos;

  /// Na abertura, antes de retomar a sessão: se o app fala agora com outro
  /// servidor ([apiBaseUrl]) que não o da última abertura, apaga tudo o que
  /// está no aparelho — sessões, catálogo, fila, rascunhos, logos e o login —
  /// e guarda o endereço novo (decisão de 24/10/2026). Sem isso, a fila feita
  /// contra um servidor iria para o outro, com ids que lá não existem, e
  /// ficaria como "Erro" para sempre. Devolve se apagou.
  ///
  /// Nenhum endereço guardado (a primeira abertura depois da Fase 8A, ou do
  /// app recém-instalado) conta como troca. Se o armazenamento seguro não
  /// consegue nem ler o endereço (keystore invalidada), nada é apagado: sem
  /// saber o servidor anterior, apagar a fila a cada abertura seria pior do
  /// que o risco que a limpeza evita.
  Future<bool> resetIfServerChanged(String apiBaseUrl) async {
    final String? saved;
    try {
      saved = await _storage.readApiBaseUrl();
    } catch (_) {
      return false;
    }
    if (saved == apiBaseUrl) return false;

    await _db.clearAll();
    try {
      await _storage.clear();
    } catch (_) {
      // Tokens de outro servidor que sobrarem são recusados por este, e a
      // primeira chamada leva ao login.
    }
    await _clearLogos();
    try {
      await _storage.saveApiBaseUrl(apiBaseUrl);
    } catch (_) {
      // Sem gravar, a próxima abertura apaga de novo — o banco já está vazio.
    }
    return true;
  }

  /// O espaço que o "Limpar cache local" libera, em bytes: o banco local e os
  /// logos baixados. A fila e os rascunhos também moram no banco, mas ocupam
  /// poucos kB.
  Future<int> downloadedBytes() async {
    final database = await _db.usedBytes();
    var logos = 0;
    try {
      logos = await _logos.sizeInBytes();
    } catch (_) {
      // Pasta ilegível: conta só o banco.
    }
    return database + logos;
  }

  /// "Limpar cache local": apaga sessões, participantes, consultores,
  /// catálogo e logos baixados — nunca a fila nem os rascunhos. A Home baixa
  /// tudo de novo na próxima vez que abrir.
  Future<void> clearDownloaded() async {
    await _db.clearDownloadedData();
    await _clearLogos();
  }

  Future<void> _clearLogos() async {
    try {
      await _logos.clear();
    } catch (_) {
      // Logos são só imagem: os que sobrarem não fazem mal a ninguém.
    }
  }
}
```

Em `lib/data/services/local/app_database.dart`, substituir:

```dart
  }

  /// Troca os consultores de uma sessão no cache pelos de [rows] (Fase 6B).
  ///
```

por:

```dart
  }

  /// "Limpar cache local" do Perfil (Fase 8A): apaga o que foi baixado do
  /// servidor — sessões, participantes, consultores e catálogo —, sem tocar
  /// na fila nem nos rascunhos.
  Future<void> clearDownloadedData() {
    return transaction(() async {
      await delete(sessionConsultants).go();
      await delete(participants).go();
      await delete(sessions).go();
      // Notas antes das infrações, e infrações antes das categorias: a mesma
      // ordem das chaves estrangeiras.
      await delete(infractionNotes).go();
      await delete(infractions).go();
      await delete(assessmentCategories).go();
    });
  }

  /// Apaga tudo, inclusive a fila e os rascunhos: a troca de servidor
  /// (decisão de 24/10/2026, ver `DeviceDataService.resetIfServerChanged`).
  Future<void> clearAll() {
    return transaction(() async {
      await delete(localAssessmentItems).go();
      await delete(localAssessments).go();
      await clearDownloadedData();
    });
  }

  /// O espaço que o banco ocupa, em bytes, sem as páginas livres: depois de
  /// um [clearDownloadedData], o número cai sem precisar de `VACUUM`.
  Future<int> usedBytes() async {
    Future<int> pragma(String name) async {
      final row = await customSelect('PRAGMA $name').getSingle();
      return row.read<int>(name);
    }

    final pages = await pragma('page_count') - await pragma('freelist_count');
    return pages * await pragma('page_size');
  }

  /// Troca os consultores de uma sessão no cache pelos de [rows] (Fase 6B).
  ///
```

Em `lib/data/services/local/token_storage.dart`, substituir:

```dart
  static const String _keepSignedInKey = 'auth.keepSignedIn';
  static const String _userKey = 'auth.user';

  Future<String?> readAccess() => _storage.read(key: _accessKey);
```

por:

```dart
  static const String _keepSignedInKey = 'auth.keepSignedIn';
  static const String _userKey = 'auth.user';
  static const String _apiBaseUrlKey = 'app.apiBaseUrl';

  Future<String?> readAccess() => _storage.read(key: _accessKey);
```

Em `lib/data/services/local/token_storage.dart`, substituir:

```dart
  }

  /// Padrão: manter conectado (app de campo, usado várias vezes por dia).
  Future<bool> readKeepSignedIn() async {
```

por:

```dart
  }

  /// O endereço da API com que o app falou na última abertura (ver
  /// `DeviceDataService.resetIfServerChanged`). Fica fora do [clear]: sair da
  /// conta não muda de servidor.
  Future<String?> readApiBaseUrl() => _storage.read(key: _apiBaseUrlKey);

  Future<void> saveApiBaseUrl(String url) =>
      _storage.write(key: _apiBaseUrlKey, value: url);

  /// Padrão: manter conectado (app de campo, usado várias vezes por dia).
  Future<bool> readKeepSignedIn() async {
```

Em `lib/ui/splash/splash_screen.dart`, substituir:

```dart
import '../../data/repositories/auth_repository.dart';
import '../../router.dart';
```

por:

```dart
import '../../data/repositories/auth_repository.dart';
import '../../data/services/device_data_service.dart';
import '../../router.dart';
```

Em `lib/ui/splash/splash_screen.dart`, substituir:

```dart
      authRepository: context.read<AuthRepository>(),
    );
```

por:

```dart
      authRepository: context.read<AuthRepository>(),
      deviceData: context.read<DeviceDataService>(),
    );
```

Em `lib/ui/splash/splash_viewmodel.dart`, substituir:

```dart
import '../../data/repositories/auth_repository.dart';
import '../../utils/result.dart';

/// Decide, na abertura, se o app vai para a Home ou para o Login.
class SplashViewModel extends ChangeNotifier {
  SplashViewModel({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  /// Tenta retomar a sessão salva. Devolve true quando consegue.
  Future<bool> decideInitialRoute() async {
```

por:

```dart
import '../../config/app_config.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/device_data_service.dart';
import '../../utils/result.dart';

/// Decide, na abertura, se o app vai para a Home ou para o Login.
class SplashViewModel extends ChangeNotifier {
  SplashViewModel({
    required AuthRepository authRepository,
    required DeviceDataService deviceData,
    this.apiBaseUrl = AppConfig.apiBaseUrl,
  })  : _authRepository = authRepository,
        _deviceData = deviceData;

  final AuthRepository _authRepository;
  final DeviceDataService _deviceData;

  /// O endereço da API deste build.
  final String apiBaseUrl;

  /// Confere se o servidor mudou (e, se mudou, apaga o aparelho) e depois
  /// tenta retomar a sessão salva. Devolve true quando consegue.
  Future<bool> decideInitialRoute() async {
    await _deviceData.resetIfServerChanged(apiBaseUrl);
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/data/services/device_data_service_test.dart test/ui/splash test/config test/data/services/local/token_storage_test.dart`
Esperado: `+19: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1022: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/data/services/device_data_service.dart apps/mobile/simtc/test/data/services/device_data_service_test.dart apps/mobile/simtc/test/ui/splash/splash_viewmodel_test.dart apps/mobile/simtc/README.md apps/mobile/simtc/lib/app_providers.dart apps/mobile/simtc/lib/config/app_config.dart apps/mobile/simtc/lib/data/services/local/app_database.dart apps/mobile/simtc/lib/data/services/local/token_storage.dart apps/mobile/simtc/lib/ui/splash/splash_screen.dart apps/mobile/simtc/lib/ui/splash/splash_viewmodel.dart apps/mobile/simtc/test/config/app_config_test.dart apps/mobile/simtc/test/data/services/local/token_storage_test.dart apps/mobile/simtc/test/ui/splash/splash_screen_test.dart
git commit -m "feat(mobile): producao como padrao e limpeza ao trocar de servidor"
```

---

## Task 3: O que chega depois do "Sair" não grava; reforços do login e do sair

Um download da agenda ou do detalhe que termina depois do "Sair" (ou do "Limpar cache local") não grava mais nada: o `AppDatabase` conta as limpezas (`cacheGeneration`), e os dois downloads conferem a conta antes de gravar. A Home ganha a guarda de dispose que o detalhe já tinha (pendência da Fase 3). O login segue mesmo se a keystore falhar ao apagar o perfil anterior (pendência da 5A), e o "Sair" espera o servidor por no máximo 5 segundos (ver "Ajustes").

**Files:**
- Modify: `lib/data/repositories/auth_repository.dart`
- Modify: `lib/data/repositories/participant_repository.dart`
- Modify: `lib/data/repositories/session_repository.dart`
- Modify: `lib/data/services/auth_session.dart`
- Modify: `lib/data/services/local/app_database.dart`
- Modify: `lib/ui/sessions/sessions_list_viewmodel.dart`
- Modify: `test/data/repositories/auth_repository_test.dart`
- Modify: `test/data/repositories/participant_repository_test.dart`
- Modify: `test/data/repositories/session_repository_test.dart`
- Modify: `test/data/services/local/app_database_test.dart`
- Modify: `test/ui/sessions/sessions_list_viewmodel_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.clearDownloadedData()` (Task 2).
- Produces:
  - `AppDatabase.cacheGeneration` (sobe em `clearSessionsCache()` e `clearDownloadedData()`)
  - `AuthRepository({…, logoutTimeout})` e `AuthRepository.defaultLogoutTimeout` (5 segundos)

- [ ] **Step 1: Escrever os testes que falham**

Em `test/data/repositories/auth_repository_test.dart`, substituir:

```dart
import 'dart:convert';
```

por:

```dart
import 'dart:async';
import 'dart:convert';
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

    test('falha ao apagar o perfil do login anterior não impede o login',
        () async {
      stubLogin(token: fakeJwt({'sub': 'user-2'}));
      stubMe({'id': 'user-2', 'name': 'Bruno', 'email': 'b@s.com', 'role': 'CONSULTANT'});
      when(() => storage.deleteUser())
          .thenThrow(PlatformException(code: 'keystore'));

      final result = await repository.login(
        email: 'b@s.com',
        password: '123456',
        keepSignedIn: true,
      );

      expect(result, isA<Success<AuthUser>>());
      verify(() => storage.persistUser(any())).called(1);
    });

    test('falha ao gravar o perfil não impede o login', () async {
      stubLogin(token: fakeJwt({'sub': 'user-1'}));
```

Em `test/data/repositories/auth_repository_test.dart`, substituir:

```dart
  test(
      'logout apaga o cache de sessões — senão o próximo consultor a entrar '
```

por:

```dart
  test(
      'logout não espera o servidor além do limite: sem resposta, sai do '
      'mesmo jeito', () async {
    repository = AuthRepository(
      apiClient: api,
      session: session,
      clearLocalCache: db.clearSessionsCache,
      logoutTimeout: const Duration(milliseconds: 10),
    );
    stubLogin(token: fakeJwt({'sub': 'user-1'}));
    stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});
    await repository.login(email: 'c@s.com', password: '123456', keepSignedIn: true);
    when(() => api.post<void>('/auth/logout'))
        .thenAnswer((_) => Completer<Response<void>>().future);

    await repository.logout();

    expect(repository.isAuthenticated, isFalse);
    expect(await session.readAccessToken(), isNull);
  });

  test('o limite padrão de espera do logout é de 5 segundos', () {
    expect(AuthRepository.defaultLogoutTimeout, const Duration(seconds: 5));
  });

  test(
      'logout apaga o cache de sessões — senão o próximo consultor a entrar '
```

Em `test/data/repositories/participant_repository_test.dart`, substituir:

```dart
            'Não foi possível atualizar. Mostrando os dados já baixados.'),
      );
    });
  });
```

por:

```dart
            'Não foi possível atualizar. Mostrando os dados já baixados.'),
      );
    });

    test(
        'o detalhe que chega depois de o cache ser apagado (sair da conta) não '
        'grava', () async {
      await seedSession();
      final response = Completer<Response<Map<String, dynamic>>>();
      when(() => api.get<Map<String, dynamic>>(detailPath))
          .thenAnswer((_) => response.future);

      final sync = repository.syncSession('sess-1');
      await db.clearSessionsCache();
      response.complete(ok(detailJson([participantJson('tp-1')])));

      expect(await sync, isA<Failure<int>>());
      expect(await db.select(db.sessions).get(), isEmpty);
      expect(await db.select(db.participants).get(), isEmpty);
    });
  });
```

Em `test/data/repositories/session_repository_test.dart`, substituir:

```dart
import 'package:dio/dio.dart';
```

por:

```dart
import 'dart:async';

import 'package:dio/dio.dart';
```

Em `test/data/repositories/session_repository_test.dart`, substituir:

```dart
    expect(await db.select(db.sessions).get(), hasLength(1));
  });
```

por:

```dart
    expect(await db.select(db.sessions).get(), hasLength(1));
  });

  test(
      'a agenda que chega depois de o cache ser apagado (sair da conta) não '
      'grava — senão ela voltaria para o próximo a entrar', () async {
    final response = Completer<Response<Map<String, dynamic>>>();
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) => response.future);

    final sync = repository.syncAll();
    await db.clearSessionsCache();
    response.complete(page([sessionJson('s1')], pageNumber: 1, totalPages: 1));

    expect((await sync).isFailure, isTrue);
    expect(await db.select(db.sessions).get(), isEmpty);
  });
```

Em `test/data/services/local/app_database_test.dart`, substituir:

```dart
      expect(await db.select(db.sessions).get(), isEmpty);
    });
```

por:

```dart
      expect(await db.select(db.sessions).get(), isEmpty);
    });

    test(
        'cada limpeza do cache baixado sobe a geração — um download no ar '
        'confere isso antes de gravar', () async {
      expect(db.cacheGeneration, 0);

      await db.clearSessionsCache();
      expect(db.cacheGeneration, 1);
      await db.clearDownloadedData();
      expect(db.cacheGeneration, 2);
      await db.clearAll();
      expect(db.cacheGeneration, 3);
    });
```

Em `test/ui/sessions/sessions_list_viewmodel_test.dart`, substituir:

```dart
    verify(repository.syncAll).called(2);
  });
```

por:

```dart
    verify(repository.syncAll).called(2);
  });

  test(
      'a tela fechada com a atualização no ar (o "Sair" logo depois de abrir a '
      'Home) não recebe aviso depois', () async {
    final sync = Completer<Result<int>>();
    when(repository.syncAll).thenAnswer((_) => sync.future);
    final vm = build()..init();
    await Future<void>.delayed(Duration.zero);

    vm.dispose();
    sync.complete(const Success(1));
    await Future<void>.delayed(Duration.zero);

    expect(vm.isRefreshing, isFalse);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/data/repositories/session_repository_test.dart test/data/repositories/participant_repository_test.dart test/data/repositories/auth_repository_test.dart test/ui/sessions/sessions_list_viewmodel_test.dart test/data/services/local/app_database_test.dart`
Esperado: `+77 -6: Some tests failed.` — não compilam `auth_repository_test.dart` (`logoutTimeout`, `defaultLogoutTimeout`) e `app_database_test.dart` (`cacheGeneration`); falham a agenda e o detalhe que chegam depois de o cache ser apagado (gravam) e a Home fechada com a atualização no ar (avisa depois do dispose).

- [ ] **Step 3: Implementar**

Em `lib/data/repositories/auth_repository.dart`, substituir:

```dart
import 'package:flutter/foundation.dart';
```

por:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
```

Em `lib/data/repositories/auth_repository.dart`, substituir:

```dart
  })  : _api = apiClient,
        _session = session,
        _clearLocalCache = clearLocalCache;
```

por:

```dart
    this.logoutTimeout = defaultLogoutTimeout,
  })  : _api = apiClient,
        _session = session,
        _clearLocalCache = clearLocalCache;

  /// Quanto o "Sair" espera o `POST /auth/logout`. Com sinal ruim ("conectado
  /// mas sem dados") a chamada levaria os 15 s do `ApiClient`, com o botão
  /// girando; passado isto, o aparelho sai do mesmo jeito (Fase 8A). O token
  /// que o servidor não chegou a invalidar continua valendo até vencer.
  final Duration logoutTimeout;

  static const Duration defaultLogoutTimeout = Duration(seconds: 5);
```

Em `lib/data/repositories/auth_repository.dart`, substituir:

```dart
      await _api.post<void>('/auth/logout');
    } on ApiException {
      // Sem rede ou token já inválido: a sessão local é limpa de qualquer forma.
```

por:

```dart
      await _api.post<void>('/auth/logout').timeout(logoutTimeout);
    } on ApiException {
      // Sem rede ou token já inválido: a sessão local é limpa de qualquer forma.
    } on TimeoutException {
      // Ver [logoutTimeout].
```

Em `lib/data/repositories/participant_repository.dart`, substituir:

```dart
    final requestedAt = _now();
    try {
```

por:

```dart
    final requestedAt = _now();
    final generation = _db.cacheGeneration;
    try {
```

Em `lib/data/repositories/participant_repository.dart`, substituir:

```dart
      await _write(
        session,
        participants,
        SessionConsultant.listFromJson(body),
        requestedAt,
      );
```

por:

```dart
      final written = await _write(
        session,
        participants,
        SessionConsultant.listFromJson(body),
        requestedAt,
        generation,
      );
      if (!written) {
        return Failure(
          Exception('cache apagado durante o download'),
          _refreshFailed,
        );
      }
```

Em `lib/data/repositories/participant_repository.dart`, substituir:

```dart
  Future<void> _write(
    TrainingSession session,
    List<SessionParticipant> participants,
    List<SessionConsultant>? consultants,
    DateTime now,
```

por:

```dart
  /// Devolve `false`, sem gravar nada, se o cache foi apagado depois que o
  /// download começou ([AppDatabase.cacheGeneration]).
  Future<bool> _write(
    TrainingSession session,
    List<SessionParticipant> participants,
    List<SessionConsultant>? consultants,
    DateTime now,
    int generation,
```

Em `lib/data/repositories/participant_repository.dart`, substituir:

```dart
    return _db.transaction(() async {
      // `cachedAt` só entra se a linha for nova: é a idade da agenda inteira
```

por:

```dart
    return _db.transaction(() async {
      if (_db.cacheGeneration != generation) return false;
      // `cachedAt` só entra se a linha for nova: é a idade da agenda inteira
```

Em `lib/data/repositories/participant_repository.dart`, substituir:

```dart
      }
    });
```

por:

```dart
      }
      return true;
    });
```

Em `lib/data/repositories/session_repository.dart`, substituir:

```dart
    final sessions = <TrainingSession>[];
    var reachedEnd = false;

    // Calculado uma vez antes do laço: uma virada de meia-noite no meio do
```

por:

```dart
    final sessions = <TrainingSession>[];
    var reachedEnd = false;
    final generation = _db.cacheGeneration;

    // Calculado uma vez antes do laço: uma virada de meia-noite no meio do
```

Em `lib/data/repositories/session_repository.dart`, substituir:

```dart
      await _write(sessions, prune: reachedEnd);
```

por:

```dart
      final written =
          await _write(sessions, prune: reachedEnd, generation: generation);
      if (!written) {
        return Failure(
          Exception('cache apagado durante o download'),
          _offlineMessage,
        );
      }
```

Em `lib/data/repositories/session_repository.dart`, substituir:

```dart
  Future<void> _write(List<TrainingSession> sessions, {required bool prune}) {
    final now = DateTime.now();

    return _db.transaction(() async {
```

por:

```dart
  /// Devolve `false`, sem gravar nada, se o cache foi apagado depois que o
  /// download começou ([AppDatabase.cacheGeneration]).
  Future<bool> _write(
    List<TrainingSession> sessions, {
    required bool prune,
    required int generation,
  }) {
    final now = DateTime.now();

    return _db.transaction(() async {
      if (_db.cacheGeneration != generation) return false;
```

Em `lib/data/repositories/session_repository.dart`, substituir:

```dart
      }
    });
```

por:

```dart
      }
      return true;
    });
```

Em `lib/data/services/auth_session.dart`, substituir:

```dart
    // pessoa — nem se o app morrer antes do `saveUser` deste login.
    await _storage.deleteUser();
```

por:

```dart
    // pessoa — nem se o app morrer antes do `saveUser` deste login. Se a
    // keystore falhar aqui, o login segue: o `saveUser` logo depois grava por
    // cima o perfil certo, e só o app morrendo entre os dois deixaria o
    // perfil antigo — melhor do que não deixar ninguém entrar.
    try {
      await _storage.deleteUser();
    } catch (_) {
      // Ver acima.
    }
```

Em `lib/data/services/local/app_database.dart`, substituir:

```dart
  static QueryExecutor _openConnection() => driftDatabase(name: 'simtc');

  /// Apaga o cache de sessões e participantes (os consultores de cada sessão
  /// vão junto, pela chave estrangeira em cascata).
```

por:

```dart
  static QueryExecutor _openConnection() => driftDatabase(name: 'simtc');

  /// Sobe a cada limpeza do cache baixado — sair da conta, "Limpar cache
  /// local", troca de servidor. Um download que começou antes de uma limpeza
  /// confere isto antes de gravar e desiste se mudou: senão, a agenda de quem
  /// saiu voltaria para o aparelho de quem entrar depois (Fase 8A). Só vale
  /// enquanto o app está aberto, que é o tempo de vida de um download.
  int get cacheGeneration => _cacheGeneration;
  int _cacheGeneration = 0;

  /// Apaga o cache de sessões e participantes (os consultores de cada sessão
  /// vão junto, pela chave estrangeira em cascata).
```

Em `lib/data/services/local/app_database.dart`, substituir:

```dart
  Future<void> clearSessionsCache() {
    return transaction(() async {
```

por:

```dart
  Future<void> clearSessionsCache() {
    _cacheGeneration++;
    return transaction(() async {
```

Em `lib/data/services/local/app_database.dart`, substituir:

```dart
  Future<void> clearDownloadedData() {
    return transaction(() async {
```

por:

```dart
  Future<void> clearDownloadedData() {
    _cacheGeneration++;
    return transaction(() async {
```

Em `lib/ui/sessions/sessions_list_viewmodel.dart`, substituir:

```dart
  String? _errorMessage;
  DateTime? _lastSyncedAt;

  SessionFilter get filter => _filter;
```

por:

```dart
  String? _errorMessage;
  DateTime? _lastSyncedAt;

  // A Home é fechada no "Sair" com o sync da abertura ainda no ar (ele é
  // `unawaited`). Sem esta guarda, o `finally` do `refresh` chamaria
  // notifyListeners depois do dispose — a mesma da `SessionDetailViewModel`.
  bool _disposed = false;

  SessionFilter get filter => _filter;
```

Em `lib/ui/sessions/sessions_list_viewmodel.dart`, substituir:

```dart
  void dispose() {
```

por:

```dart
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/data/repositories/session_repository_test.dart test/data/repositories/participant_repository_test.dart test/data/repositories/auth_repository_test.dart test/ui/sessions/sessions_list_viewmodel_test.dart test/data/services/local/app_database_test.dart`
Esperado: `+123: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1029: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/data/repositories/auth_repository.dart apps/mobile/simtc/lib/data/repositories/participant_repository.dart apps/mobile/simtc/lib/data/repositories/session_repository.dart apps/mobile/simtc/lib/data/services/auth_session.dart apps/mobile/simtc/lib/data/services/local/app_database.dart apps/mobile/simtc/lib/ui/sessions/sessions_list_viewmodel.dart apps/mobile/simtc/test/data/repositories/auth_repository_test.dart apps/mobile/simtc/test/data/repositories/participant_repository_test.dart apps/mobile/simtc/test/data/repositories/session_repository_test.dart apps/mobile/simtc/test/data/services/local/app_database_test.dart apps/mobile/simtc/test/ui/sessions/sessions_list_viewmodel_test.dart
git commit -m "fix(mobile): download que termina depois do sair nao grava"
```

---

## Task 4: Envio da fila seguro na troca de usuário

As pendências do `AssessmentSyncService` que os planos 5A e 5B mandaram "tratar junto com a troca de usuário": o lote de quem saiu não é enviado no nome de quem entrou; um 401 com o usuário ainda logado tenta de novo pela espera crescente; uma falha ao dar dono às avaliações antigas, ou numa leitura da fila, não para de seguir a fila; quem chama `syncNow()` com um envio no ar espera também a rodada repetida; e `retryDelays` vazia é recusada.

**Files:**
- Modify: `lib/data/services/assessment_sync_service.dart`
- Modify: `test/data/services/assessment_sync_service_test.dart`

**Interfaces:**
- Consumes: nada das tasks anteriores.
- Produces:
  - nenhuma assinatura nova; `syncNow()` passa a devolver o futuro da rodada inteira (com as repetições), e o construtor recusa `retryDelays` vazia com um `assert`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/data/services/assessment_sync_service_test.dart`, substituir:

```dart
class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late AppDatabase db;
```

por:

```dart
class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

/// O repositório de verdade, com uma falha ao entrar: o `claimUnowned` e a
/// primeira leitura da fila podem quebrar (erro do banco local).
class _FailingEntryRepository extends AssessmentRepository {
  _FailingEntryRepository({
    required super.database,
    this.failClaim = false,
    this.failFirstQueueRead = false,
  });

  final bool failClaim;
  final bool failFirstQueueRead;

  @override
  Future<void> claimUnowned(String ownerUserId) async {
    if (failClaim) throw Exception('disco cheio');
    return super.claimUnowned(ownerUserId);
  }

  @override
  Stream<List<LocalAssessment>> watchQueue(String ownerUserId) {
    final real = super.watchQueue(ownerUserId);
    if (!failFirstQueueRead) return real;
    return Stream<List<LocalAssessment>>.multi((controller) {
      controller.addError(Exception('leitura falhou'));
      final subscription = real.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }
}

void main() {
  late AppDatabase db;
```

Em `test/data/services/assessment_sync_service_test.dart`, substituir:

```dart
  }) {
    final started = AssessmentSyncService(
      apiClient: api,
      assessments: assessments,
```

por:

```dart
    AssessmentRepository? repository,
  }) {
    final started = AssessmentSyncService(
      apiClient: api,
      assessments: repository ?? assessments,
```

Em `test/data/services/assessment_sync_service_test.dart`, substituir:

```dart
  });

  test('"Sincronizar agora" não espera a próxima tentativa', () async {
    failWith(semRede);
```

por:

```dart
  });

  test(
      '401 com o usuário ainda logado (a renovação passou e o servidor recusou '
      'de novo) tenta mais tarde, sem esperar outro gatilho', () async {
    failWith(const ApiException(message: 'Unauthorized', statusCode: 401));
    startService(retryDelays: const [Duration(milliseconds: 20)]);

    final a = await confirmed('tp-1');
    await until(() => sent.length >= 2);

    expect(await statusOf(a.id), LocalSyncStatus.pendingSync);
    expect((await row(a.id)).lastError, isNull);
  });

  test(
      'trocar de usuário com o envio a caminho não manda a fila de quem saiu '
      'no nome de quem entrou', () async {
    failWith(semRede);
    final sync = startService();
    final a = await confirmed('tp-1');
    await until(() async => await statusOf(a.id) == LocalSyncStatus.error);
    acceptAll();
    sent.clear();

    final sending = sync.syncNow();
    user.value = 'user-2';
    await sending;
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(sent, isEmpty);
    expect(await statusOf(a.id), LocalSyncStatus.error);
  });

  test('uma falha ao entrar (dar dono às avaliações antigas) não impede '
      'seguir a fila', () async {
    final sync = startService(
      repository: _FailingEntryRepository(database: db, failClaim: true),
    );

    final a = await confirmed('tp-1');

    await until(() async => await statusOf(a.id) == LocalSyncStatus.synced);
    expect(sync.queue, isEmpty);
  });

  test('uma leitura da fila que falha não para de seguir a fila', () async {
    final sync = startService(
      repository: _FailingEntryRepository(database: db, failFirstQueueRead: true),
    );
    failWith(semRede);

    await confirmed('tp-1');

    await until(() => sync.queue.length == 1);
  });

  test('a espera entre tentativas não pode ser uma lista vazia', () {
    expect(
      () => AssessmentSyncService(
        apiClient: api,
        assessments: assessments,
        participants: participants,
        connectivity: connectivity,
        authChanges: user,
        currentUserId: () => user.value,
        retryDelays: const [],
      ),
      throwsAssertionError,
    );
  });

  test('"Sincronizar agora" não espera a próxima tentativa', () async {
    failWith(semRede);
```

Em `test/data/services/assessment_sync_service_test.dart`, substituir:

```dart
    expect(sent, hasLength(2));
    expect(sent[1].map((p) => p['trainingParticipantId']), ['tp-2']);
    await until(() => !sync.isSending);
  });

  test('"Descartar" apaga a avaliação que o servidor recusou e tira da fila',
```

por:

```dart
    expect(sent, hasLength(2));
    expect(sent[1].map((p) => p['trainingParticipantId']), ['tp-2']);
    await until(() => !sync.isSending);
  });

  test(
      'quem espera o "Sincronizar agora" com um envio no ar espera também a '
      'rodada repetida', () async {
    final gate = Completer<void>();
    when(() => api.post<List<dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      final payload = payloadOf(invocation);
      sent.add(payload);
      if (sent.length == 1) await gate.future;
      return reply(payload, (_) => null);
    });
    final sync = startService();
    await confirmed('tp-1');
    await until(() => sent.length == 1);
    final second = await confirmed('tp-2');

    final done = sync.syncNow();
    gate.complete();
    await done;

    expect(await statusOf(second.id), LocalSyncStatus.synced);
    expect(sync.isSending, isFalse);
  });

  test('"Descartar" apaga a avaliação que o servidor recusou e tira da fila',
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/data/services/assessment_sync_service_test.dart`
Esperado: `+23 -6: Some tests failed.` — os seis testes novos: o 401 com o usuário logado, a troca de usuário com o envio a caminho, a falha no `claimUnowned`, a leitura da fila que falha, a lista de esperas vazia e o "Sincronizar agora" que não espera a rodada repetida.

- [ ] **Step 3: Implementar**

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
  })  : _api = apiClient,
```

por:

```dart
  })  : assert(retryDelays.isNotEmpty, 'retryDelays não pode ser vazia'),
        _api = apiClient,
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
  int _failures = 0;
  Future<void>? _running;
```

por:

```dart
  int _failures = 0;

  /// A rodada de envio no ar, com as repetições pedidas no meio dela
  /// ([_again]): quem chama [syncNow] durante uma rodada espera até a última.
  Future<void>? _running;
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
    await _assessments.claimUnowned(userId);
    if (_disposed || _userId != userId) return;

    _firstQueueEmission = true;
    _queueSubscription = _assessments.watchQueue(userId).listen(_onQueue);
    _lastSyncedSubscription =
        _assessments.watchLastSyncedAt(userId).listen((at) {
      _lastSyncedAt = at;
      notifyListeners();
    });
```

por:

```dart
    try {
      await _assessments.claimUnowned(userId);
    } catch (error) {
      // Uma falha do banco ao dar dono às avaliações antigas (da Fase 4) não
      // pode deixar a fila sem ser seguida: a aba diria "Tudo o que você
      // confirmou já chegou ao servidor" com a fila cheia. As sem dono ficam
      // para a próxima entrada.
      debugPrint('Não foi possível dar dono às avaliações antigas: $error');
    }
    if (_disposed || _userId != userId) return;

    _firstQueueEmission = true;
    // Com `onError`, um erro numa leitura não derruba a assinatura: a
    // próxima mudança na fila chega normalmente.
    _queueSubscription = _assessments.watchQueue(userId).listen(
          _onQueue,
          onError: (Object error) => debugPrint('Leitura da fila falhou: $error'),
        );
    _lastSyncedSubscription = _assessments.watchLastSyncedAt(userId).listen(
      (at) {
        _lastSyncedAt = at;
        notifyListeners();
      },
      onError: (Object error) =>
          debugPrint('Leitura da última sincronização falhou: $error'),
    );
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
  /// dele, para levar o que entrou na fila no meio do caminho.
  Future<void> syncNow() async {
    if (_disposed) return;
```

por:

```dart
  /// dele, para levar o que entrou na fila no meio do caminho — e quem chamou
  /// espera até essa repetição terminar.
  Future<void> syncNow() {
    if (_disposed) return Future<void>.value();
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
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
```

por:

```dart
    final round = _runRounds();
    _running = round;
    notifyListeners();
    return round;
  }

  Future<void> _runRounds() async {
    try {
      do {
        _again = false;
        try {
          await _sendQueue();
        } catch (error) {
          // Rede de segurança: os erros esperados já viram motivo na fila. Um
          // erro inesperado (do banco, por exemplo) não pode travar o envio.
          debugPrint('Envio da fila falhou: $error');
          _scheduleRetry();
        } finally {
          _sendingIds = const {};
          notifyListeners();
        }
      } while (_again && !_disposed);
    } finally {
      _running = null;
      notifyListeners();
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
      final payload = await _assessments.syncPayload(batch);
      final response = await _api.post<List<dynamic>>(syncPath, data: payload);
```

por:

```dart
      final payload = await _assessments.syncPayload(batch);
      // Quem saiu (e quem entrou) no meio da montagem do lote: o POST levaria
      // o token de quem está logado agora, com a fila de quem saiu — e o
      // servidor recusaria tudo como "não está mais com você".
      if (_userId != userId) return;
      final response = await _api.post<List<dynamic>>(syncPath, data: payload);
```

Em `lib/data/services/assessment_sync_service.dart`, substituir:

```dart
      // Sessão encerrada no meio do envio: nada falhou por culpa da
      // avaliação. A fila espera o dono entrar de novo.
      if (error.statusCode == 401) return;
```

por:

```dart
      // 401: nada falhou por culpa da avaliação, e a fila não ganha erro. Se
      // a sessão acabou de vez, o usuário já saiu (o `ApiClient` avisou) e a
      // fila espera o dono entrar de novo. Se ele continua logado (a
      // renovação passou e o servidor recusou de novo), tenta mais tarde.
      if (error.statusCode == 401) {
        if (_userId == userId) _scheduleRetry();
        return;
      }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/data/services/assessment_sync_service_test.dart`
Esperado: `+29: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1035: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/data/services/assessment_sync_service.dart apps/mobile/simtc/test/data/services/assessment_sync_service_test.dart
git commit -m "fix(mobile): envio da fila seguro na troca de usuario"
```

---

## Task 5: ViewModel e textos do Perfil

A `ProfileViewModel` e os textos da aba, antes da tela: quem entrou, a versão do app (pelo `package_info_plus`, dependência nova), o espaço do cache, o "Limpar cache local" e o "Sair da conta" — que não correm juntos — e a contagem das avaliações iniciadas para a confirmação do "Sair". Os textos ficam em `profile_labels.dart` (ver "Ajustes").

**Files:**
- Create: `lib/ui/profile/profile_labels.dart`
- Create: `lib/ui/profile/profile_viewmodel.dart`
- Create: `test/ui/profile/profile_labels_test.dart`
- Create: `test/ui/profile/profile_viewmodel_test.dart`
- Modify: `lib/data/repositories/assessment_repository.dart`
- Modify: `pubspec.lock`
- Modify: `pubspec.yaml`
- Modify: `test/data/repositories/assessment_repository_test.dart`

**Interfaces:**
- Consumes: `DeviceDataService` (Task 2) e `AuthRepository.logout()`.
- Produces:
  - `AssessmentRepository.countDrafts(String ownerUserId) → Future<int>`
  - `roleLabel(AppUserRole)`, `lastSyncValue(DateTime?, DateTime now)`, `sizeLabel(int bytes)`, `logoutMessage({queued, drafts, offline})` em `lib/ui/profile/profile_labels.dart`
  - `ProfileViewModel({auth, assessments, deviceData, loadVersion})`: `user`, `version`, `cacheBytes`, `isClearing`, `isLoggingOut`, `init()`, `measureCache()`, `clearCache() → Future<bool>`, `countStartedDrafts() → Future<int>`, `logout() → Future<bool>`; `ProfileViewModel.platformVersion()`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/data/repositories/assessment_repository_test.dart`, substituir:

```dart
  });

  group('fila', () {
    test(
```

por:

```dart
  });

  test(
      'countDrafts conta as iniciadas e não confirmadas do dono, inclusive as '
      'presas', () async {
    await insertDraft('tp-1');
    await insertDraft('tp-2', sessionId: 'sess-concluida');
    final confirmed = await insertDraft('tp-3');
    await repository.confirm(confirmed.id, participantName: 'P', score: 90);
    await insertDraft('tp-4', owner: 'user-2');

    expect(await repository.countDrafts('user-1'), 2);
    expect(await repository.countDrafts('user-2'), 1);
    expect(await repository.countDrafts('ninguem'), 0);
  });

  group('fila', () {
    test(
```

Criar `test/ui/profile/profile_labels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/ui/profile/profile_labels.dart';

void main() {
  test('perfil de acesso', () {
    expect(roleLabel(AppUserRole.consultant), 'Consultor');
    expect(roleLabel(AppUserRole.admin), 'Administrador');
  });

  test('última sincronização: só o momento, ou "Nenhum envio"', () {
    final now = DateTime(2026, 10, 24, 9);
    expect(lastSyncValue(DateTime(2026, 10, 24, 7, 12), now), 'hoje 07:12');
    expect(lastSyncValue(DateTime(2026, 10, 20, 7, 12), now), '20 out 07:12');
    expect(lastSyncValue(null, now), 'Nenhum envio');
  });

  test('tamanho em KB abaixo de 1 MB, com uma casa e vírgula acima', () {
    expect(sizeLabel(0), '0 KB');
    expect(sizeLabel(1), '1 KB');
    expect(sizeLabel(36 * 1024), '36 KB');
    expect(sizeLabel(1024 * 1024 - 1), '1024 KB');
    expect(sizeLabel(1024 * 1024), '1,0 MB');
    expect(sizeLabel((18.4 * 1024 * 1024).round()), '18,4 MB');
    expect(sizeLabel((1.25 * 1024 * 1024 * 1024).round()), '1,3 GB');
  });

  group('confirmação do "Sair"', () {
    test('sem fila nem rascunho, com rede: só as sessões', () {
      expect(
        logoutMessage(queued: 0, drafts: 0, offline: false),
        'As sessões baixadas neste aparelho serão apagadas.',
      );
    });

    test('com fila e rascunho, sem rede: um parágrafo por assunto', () {
      expect(
        logoutMessage(queued: 3, drafts: 1, offline: true),
        'As sessões baixadas neste aparelho serão apagadas.\n\n'
        '3 avaliações na fila ficam guardadas neste aparelho e são enviadas '
        'quando você entrar de novo.\n\n'
        'A avaliação iniciada fica guardada para você continuar quando entrar '
        'de novo.\n\n'
        'Sem conexão, você só consegue entrar de novo quando houver rede.',
      );
    });

    test('singular e plural', () {
      expect(
        logoutMessage(queued: 1, drafts: 2, offline: false),
        'As sessões baixadas neste aparelho serão apagadas.\n\n'
        'A avaliação na fila fica guardada neste aparelho e é enviada quando '
        'você entrar de novo.\n\n'
        '2 avaliações iniciadas ficam guardadas para você continuar quando '
        'entrar de novo.',
      );
    });
  });
}
```

Criar `test/ui/profile/profile_viewmodel_test.dart`:

```dart
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/services/device_data_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/profile/profile_viewmodel.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockDeviceData extends Mock implements DeviceDataService {}

void main() {
  const carla = AuthUser(
    id: 'user-1',
    name: 'Carla Mendes',
    email: 'carla.mendes@simtreinamentos.com.br',
    role: AppUserRole.consultant,
  );

  late _MockAuthRepository auth;
  late _MockDeviceData deviceData;
  late AppDatabase db;
  late AssessmentRepository assessments;

  setUp(() {
    auth = _MockAuthRepository();
    deviceData = _MockDeviceData();
    db = AppDatabase(NativeDatabase.memory());
    assessments = AssessmentRepository(database: db);
    when(() => auth.currentUser).thenReturn(carla);
    when(() => deviceData.downloadedBytes()).thenAnswer((_) async => 2048);
    when(() => deviceData.clearDownloaded()).thenAnswer((_) async {});
    when(() => auth.logout()).thenAnswer((_) async {});
  });

  tearDown(() => db.close());

  ProfileViewModel build({Future<String> Function()? loadVersion}) {
    final vm = ProfileViewModel(
      auth: auth,
      assessments: assessments,
      deviceData: deviceData,
      loadVersion: loadVersion ?? () async => '1.0.0 (1)',
    );
    addTearDown(vm.dispose);
    return vm;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('mostra quem entrou, a versão e o espaço do cache', () async {
    final vm = build()..init();
    expect(vm.user, carla);
    expect(vm.version, isNull);
    expect(vm.cacheBytes, isNull);

    await settle();

    expect(vm.version, '1.0.0 (1)');
    expect(vm.cacheBytes, 2048);
  });

  test('uma falha ao ler a versão ou medir o cache deixa o valor vazio',
      () async {
    when(() => deviceData.downloadedBytes()).thenThrow(Exception('disco'));
    final vm = build(loadVersion: () async => throw Exception('plugin'))..init();

    await settle();

    expect(vm.version, isNull);
    expect(vm.cacheBytes, isNull);
  });

  test('limpar o cache apaga, mede de novo e devolve que limpou', () async {
    final gate = Completer<void>();
    when(() => deviceData.clearDownloaded()).thenAnswer((_) => gate.future);
    final vm = build()..init();
    await settle();

    final clearing = vm.clearCache();
    expect(vm.isClearing, isTrue);
    when(() => deviceData.downloadedBytes()).thenAnswer((_) async => 512);
    gate.complete();

    expect(await clearing, isTrue);
    expect(vm.isClearing, isFalse);
    expect(vm.cacheBytes, 512);
  });

  test('uma falha ao limpar devolve que não limpou', () async {
    when(() => deviceData.clearDownloaded()).thenThrow(Exception('disco'));
    final vm = build();

    expect(await vm.clearCache(), isFalse);
    expect(vm.isClearing, isFalse);
  });

  test('conta as avaliações iniciadas de quem entrou', () async {
    Future<void> draft(String participantId, String owner, LocalSyncStatus status) {
      return db.into(db.localAssessments).insert(LocalAssessmentsCompanion.insert(
            id: 'a-$participantId',
            trainingParticipantId: participantId,
            sessionId: 'sess-1',
            date: DateTime(2026, 10, 24),
            startTime: DateTime(2026, 10, 24, 8),
            syncStatus: status,
            createdAt: DateTime(2026, 10, 24, 8),
            updatedAt: DateTime(2026, 10, 24, 8),
            ownerUserId: Value(owner),
          ));
    }

    await draft('tp-1', 'user-1', LocalSyncStatus.draft);
    await draft('tp-2', 'user-1', LocalSyncStatus.pendingSync);
    await draft('tp-3', 'user-2', LocalSyncStatus.draft);

    expect(await build().countStartedDrafts(), 1);
  });

  test('sem ninguém logado, nenhuma avaliação iniciada', () async {
    when(() => auth.currentUser).thenReturn(null);

    expect(await build().countStartedDrafts(), 0);
  });

  test('sair chama o logout e devolve que saiu', () async {
    final gate = Completer<void>();
    when(() => auth.logout()).thenAnswer((_) => gate.future);
    final vm = build();

    final leaving = vm.logout();
    expect(vm.isLoggingOut, isTrue);
    gate.complete();

    expect(await leaving, isTrue);
    expect(vm.isLoggingOut, isFalse);
    verify(() => auth.logout()).called(1);
  });

  test('uma falha ao sair devolve que não saiu', () async {
    when(() => auth.logout()).thenThrow(Exception('keystore'));
    final vm = build();

    expect(await vm.logout(), isFalse);
    expect(vm.isLoggingOut, isFalse);
  });

  test('dois toques no "Sair" chamam o logout uma vez só', () async {
    final gate = Completer<void>();
    when(() => auth.logout()).thenAnswer((_) => gate.future);
    final vm = build();

    final first = vm.logout();
    expect(await vm.logout(), isFalse);
    gate.complete();
    await first;

    verify(() => auth.logout()).called(1);
  });

  test('a tela fechada com a medida no ar não recebe aviso depois', () async {
    final gate = Completer<int>();
    when(() => deviceData.downloadedBytes()).thenAnswer((_) => gate.future);
    final vm = ProfileViewModel(
      auth: auth,
      assessments: assessments,
      deviceData: deviceData,
      loadVersion: () async => '1.0.0 (1)',
    )..init();
    await settle();

    vm.dispose();
    gate.complete(10);
    await settle();

    expect(vm.cacheBytes, 10);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/profile test/data/repositories/assessment_repository_test.dart`
Esperado: `Some tests failed.` — não compilam `profile_labels_test.dart`, `profile_viewmodel_test.dart` e `assessment_repository_test.dart` (`roleLabel`, `lastSyncValue`, `sizeLabel`, `logoutMessage`, `ProfileViewModel` e `countDrafts` não existem).

- [ ] **Step 3: Implementar**

Em `lib/data/repositories/assessment_repository.dart`, substituir:

```dart
      _queueOf(ownerUserId).get();

  SimpleSelectStatement<$LocalAssessmentsTable, LocalAssessment> _queueOf(
    String ownerUserId,
```

por:

```dart
      _queueOf(ownerUserId).get();

  /// Quantas avaliações [ownerUserId] iniciou e ainda não confirmou — todas,
  /// inclusive as presas (sessão concluída, participante liberado): a
  /// confirmação do "Sair" avisa que elas ficam no aparelho (Fase 8A).
  Future<int> countDrafts(String ownerUserId) async {
    final drafts = await (_db.select(_db.localAssessments)
          ..where((t) =>
              t.ownerUserId.equals(ownerUserId) &
              t.syncStatus.equalsValue(LocalSyncStatus.draft)))
        .get();
    return drafts.length;
  }

  SimpleSelectStatement<$LocalAssessmentsTable, LocalAssessment> _queueOf(
    String ownerUserId,
```

Criar `lib/ui/profile/profile_labels.dart`:

```dart
import '../../data/models/auth_user.dart';
import '../core/date_labels.dart';

/// Os textos da tela 1.10 Perfil (Fase 8A), separados da tela para os testes.

/// "Consultor" ou "Administrador" — a linha "Perfil de acesso", que faz as
/// vezes do selo "Admin" do brainstorm.
String roleLabel(AppUserRole role) => switch (role) {
      AppUserRole.consultant => 'Consultor',
      AppUserRole.admin => 'Administrador',
    };

/// A linha "Última sincronização": só o momento ("hoje 07:12"), porque o
/// rótulo da linha já diz o que é. O mesmo instante da aba Sincronizar.
String lastSyncValue(DateTime? at, DateTime now) =>
    at == null ? 'Nenhum envio' : momentLabel(at, now);

/// "36 KB", "18,4 MB", "1,2 GB" — o espaço do "Limpar cache local".
String sizeLabel(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  String oneDecimal(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');

  if (bytes >= gb) return '${oneDecimal(bytes / gb)} GB';
  if (bytes >= mb) return '${oneDecimal(bytes / mb)} MB';
  return '${(bytes / kb).ceil()} KB';
}

/// O corpo da confirmação do "Sair da conta" (decisão de 24/10/2026: avisa e
/// deixa sair). Um parágrafo por assunto, separados por linha em branco.
String logoutMessage({
  required int queued,
  required int drafts,
  required bool offline,
}) {
  return [
    'As sessões baixadas neste aparelho serão apagadas.',
    if (queued == 1)
      'A avaliação na fila fica guardada neste aparelho e é enviada quando '
          'você entrar de novo.',
    if (queued > 1)
      '$queued avaliações na fila ficam guardadas neste aparelho e são '
          'enviadas quando você entrar de novo.',
    if (drafts == 1)
      'A avaliação iniciada fica guardada para você continuar quando entrar '
          'de novo.',
    if (drafts > 1)
      '$drafts avaliações iniciadas ficam guardadas para você continuar '
          'quando entrar de novo.',
    if (offline) 'Sem conexão, você só consegue entrar de novo quando houver rede.',
  ].join('\n\n');
}
```

Criar `lib/ui/profile/profile_viewmodel.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/models/auth_user.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/device_data_service.dart';

/// Estado da tela 1.10 Perfil (Fase 8A): quem entrou, o espaço do cache, a
/// versão do app e as duas ações — "Limpar cache local" e "Sair da conta".
///
/// A fila e a última sincronização vêm do `AssessmentSyncService`, que a tela
/// já observa; esta ViewModel não as repete.
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required AuthRepository auth,
    required AssessmentRepository assessments,
    required DeviceDataService deviceData,
    Future<String> Function()? loadVersion,
  })  : _auth = auth,
        _assessments = assessments,
        _deviceData = deviceData,
        _loadVersion = loadVersion ?? platformVersion;

  final AuthRepository _auth;
  final AssessmentRepository _assessments;
  final DeviceDataService _deviceData;
  final Future<String> Function() _loadVersion;

  /// "1.0.0 (1)": o `version` e o `buildNumber` do `pubspec.yaml`.
  static Future<String> platformVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  }

  String? _version;
  int? _cacheBytes;
  bool _isClearing = false;
  bool _isLoggingOut = false;
  bool _disposed = false;

  /// Quem entrou. Nulo só no instante entre o "Sair" e a ida para o login.
  AuthUser? get user => _auth.currentUser;

  /// Nulo até ler (ou se a leitura falhar).
  String? get version => _version;

  /// O espaço que o "Limpar cache local" libera; nulo enquanto mede (ou se a
  /// medida falhar).
  int? get cacheBytes => _cacheBytes;

  bool get isClearing => _isClearing;
  bool get isLoggingOut => _isLoggingOut;

  /// Lê a versão e mede o cache. Chamado uma vez pela tela.
  void init() {
    unawaited(_readVersion());
    unawaited(measureCache());
  }

  Future<void> _readVersion() async {
    try {
      _version = await _loadVersion();
    } catch (_) {
      _version = null;
    }
    notifyListeners();
  }

  Future<void> measureCache() async {
    try {
      _cacheBytes = await _deviceData.downloadedBytes();
    } catch (_) {
      _cacheBytes = null;
    }
    notifyListeners();
  }

  /// "Limpar cache local", já confirmado. Devolve se limpou; em seguida mede
  /// de novo, para a linha mostrar o que sobrou.
  Future<bool> clearCache() async {
    if (_isClearing) return false;
    _isClearing = true;
    notifyListeners();

    var cleared = false;
    try {
      await _deviceData.clearDownloaded();
      cleared = true;
    } catch (_) {
      // A tela avisa; o que não foi apagado continua valendo.
    } finally {
      _isClearing = false;
      notifyListeners();
    }
    await measureCache();
    return cleared;
  }

  /// As avaliações iniciadas e ainda não confirmadas de quem entrou — o aviso
  /// da confirmação do "Sair". Na dúvida (sem usuário, erro do banco), zero.
  Future<int> countStartedDrafts() async {
    final userId = user?.id;
    if (userId == null) return 0;
    try {
      return await _assessments.countDrafts(userId);
    } catch (_) {
      return 0;
    }
  }

  /// "Sair da conta", já confirmado. Devolve se saiu; o roteador leva ao
  /// login sozinho quando o usuário some.
  Future<bool> logout() async {
    if (_isLoggingOut) return false;
    _isLoggingOut = true;
    notifyListeners();

    try {
      await _auth.logout();
      return true;
    } catch (_) {
      return false;
    } finally {
      _isLoggingOut = false;
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
    super.dispose();
  }
}
```

Em `pubspec.lock`, substituir:

```
    version: "2.2.0"
  path:
```

por:

```
    version: "2.2.0"
  package_info_plus:
    dependency: "direct main"
    description:
      name: package_info_plus
      sha256: "468c26b4254ab01979fa5e4a98cb343ea3631b9acee6f21028997419a80e1a20"
      url: "https://pub.dev"
    source: hosted
    version: "9.0.1"
  package_info_plus_platform_interface:
    dependency: transitive
    description:
      name: package_info_plus_platform_interface
      sha256: "202a487f08836a592a6bd4f901ac69b3a8f146af552bbd14407b6b41e1c3f086"
      url: "https://pub.dev"
    source: hosted
    version: "3.2.1"
  path:
```

Em `pubspec.yaml`, substituir:

```
  uuid: ^4.4.2

  # Visualizar relatórios PDF
  pdfx: ^2.7.0
```

por:

```
  uuid: ^4.4.2

  # Versão do app na tela de Perfil (Fase 8A)
  package_info_plus: ^9.0.1

  # Visualizar relatórios PDF
  pdfx: ^2.7.0
```

Run: `flutter pub get` (o `pubspec.yaml` ganhou o `package_info_plus`; o `pubspec.lock` do bloco acima já traz a versão resolvida).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/profile test/data/repositories/assessment_repository_test.dart`
Esperado: `+68: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1052: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/profile/profile_labels.dart apps/mobile/simtc/lib/ui/profile/profile_viewmodel.dart apps/mobile/simtc/test/ui/profile/profile_labels_test.dart apps/mobile/simtc/test/ui/profile/profile_viewmodel_test.dart apps/mobile/simtc/lib/data/repositories/assessment_repository.dart apps/mobile/simtc/pubspec.lock apps/mobile/simtc/pubspec.yaml apps/mobile/simtc/test/data/repositories/assessment_repository_test.dart
git commit -m "feat(mobile): viewmodel e textos do perfil"
```

---

## Task 6: A aba Perfil no celular

A tela 1.10 no celular (quadro `2i`): o cabeçalho "Perfil", nome e e-mail, as quatro linhas (sem "Empresa"), o "Sair da conta" e o texto novo embaixo dele; as duas confirmações; o voltar do Android leva a Sessões, como na aba Sincronizar. A rota `/profile` entra no roteador, e o "Perfil" da navbar passa a abrir a aba (sai o "Disponível em breve."). As medidas são conferidas com a Inter de verdade num arquivo de teste próprio (`profile_layout_test.dart`): a fonte de teste é mais larga e quebraria os rótulos numa tela de 412.

**Files:**
- Create: `lib/ui/profile/profile_screen.dart`
- Create: `test/ui/profile/profile_harness.dart`
- Create: `test/ui/profile/profile_layout_test.dart`
- Create: `test/ui/profile/profile_screen_test.dart`
- Modify: `lib/router.dart`
- Modify: `lib/ui/core/theme/app_icons.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/widgets/app_nav_bar.dart`
- Modify: `test/ui/core/widgets/app_nav_bar_test.dart`
- Modify: `test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: `ProfileViewModel` e `profile_labels.dart` (Task 5); `DeviceDataService` (Task 2); `AssessmentSyncService.queue`/`lastSyncedAt`; `ConnectivityService.isOffline`.
- Produces:
  - `ProfileScreen({clock})` em `lib/ui/profile/profile_screen.dart`, com as linhas `Key('profile-row-role'|'profile-row-sync'|'profile-row-cache'|'profile-row-version')` e `Key('profile-identity')`
  - `AppRoutes.profile` (`/profile`) e `AppTab.profile`
  - `AppTypography.profileEmail`, `profileRowLabel`, `profileRowValue`, `profileNote`; `AppIcons.accessRole`, `AppIcons.clearCache`
  - `ProfileHarness` em `test/ui/profile/profile_harness.dart` (monta a aba com os serviços de mentira)

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/core/widgets/app_nav_bar_test.dart`, substituir:

```dart
  /// A aba [current] dentro da moldura do tablet, com as rotas das duas abas.
```

por:

```dart
  /// A aba [current] dentro da moldura do tablet, com as rotas das três abas.
```

Em `test/ui/core/widgets/app_nav_bar_test.dart`, substituir:

```dart
      initialLocation:
          current == AppTab.sessions ? AppRoutes.home : AppRoutes.sync,
      routes: [
        GoRoute(
            path: AppRoutes.home, builder: (_, __) => tab(AppTab.sessions)),
        GoRoute(path: AppRoutes.sync, builder: (_, __) => tab(AppTab.sync)),
```

por:

```dart
      initialLocation: switch (current) {
        AppTab.sessions => AppRoutes.home,
        AppTab.sync => AppRoutes.sync,
        AppTab.profile => AppRoutes.profile,
      },
      routes: [
        GoRoute(
            path: AppRoutes.home, builder: (_, __) => tab(AppTab.sessions)),
        GoRoute(path: AppRoutes.sync, builder: (_, __) => tab(AppTab.sync)),
        GoRoute(
            path: AppRoutes.profile, builder: (_, __) => tab(AppTab.profile)),
```

Em `test/ui/core/widgets/app_nav_bar_test.dart`, substituir:

```dart
  testWidgets('"Perfil" avisa que chega numa próxima versão', (tester) async {
    screen(tester, const Size(1280, 800));
    await pumpFrame(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pump();
    expect(find.text('Disponível em breve.'), findsOneWidget);
```

por:

```dart
  testWidgets('"Perfil" leva à aba Perfil, que fica marcada; Sessões volta',
      (tester) async {
    screen(tester, const Size(1280, 800));
    await pumpFrame(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('aba profile'), findsOneWidget);
    expect(tester.widget<PillNavBar>(find.byType(PillNavBar)).currentIndex, 2);
    expect(find.text('Disponível em breve.'), findsNothing);

    await tester.tap(find.text('Sessões'));
    await tester.pumpAndSettle();
    expect(find.text('aba sessions'), findsOneWidget);
```

Criar `test/ui/profile/profile_harness.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/device_data_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/profile/profile_screen.dart';

import '../../support/fake_assessment_sync_service.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDeviceData extends Mock implements DeviceDataService {}

class _MockConnectivity extends Mock implements Connectivity {}

const AuthUser carla = AuthUser(
  id: 'user-1',
  name: 'Carla Mendes',
  email: 'carla.mendes@simtreinamentos.com.br',
  role: AppUserRole.consultant,
);

/// 18,4 MB: o valor do canvas na linha "Limpar cache local".
final int canvasCacheBytes = (18.4 * 1024 * 1024).round();

/// A aba Perfil aberta pela rota real, com a Home atrás dela no go_router, e
/// os serviços de mentira: o login, a medida do cache, a fila e a conexão. O
/// banco é de verdade, em memória — o "Sair" conta os rascunhos nele.
class ProfileHarness {
  ProfileHarness() {
    PackageInfo.setMockInitialValues(
      appName: 'SIMTC',
      packageName: 'br.com.simtc.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    when(() => auth.currentUser).thenReturn(carla);
    when(() => auth.logout()).thenAnswer((_) async {});
    when(() => deviceData.downloadedBytes())
        .thenAnswer((_) async => canvasCacheBytes);
    when(() => deviceData.clearDownloaded()).thenAnswer((_) async {});
  }

  final MockAuthRepository auth = MockAuthRepository();
  final MockDeviceData deviceData = MockDeviceData();
  final AppDatabase db = AppDatabase(DatabaseConnection(
    NativeDatabase.memory(),
    closeStreamsSynchronously: true,
  ));
  ConnectivityService connectivity = ConnectivityService();
  late FakeAssessmentSyncService sync;

  final DateTime now = DateTime(2026, 10, 24, 9);

  Future<void> dispose() async {
    connectivity.dispose();
    await db.close();
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

  /// Um rascunho de [owner] no banco: o "Sair" conta as avaliações iniciadas.
  Future<void> seedDraft({String owner = 'user-1', String participantId = 'tp-9'}) {
    return db.into(db.localAssessments).insert(LocalAssessmentsCompanion.insert(
          id: 'draft-$participantId',
          trainingParticipantId: participantId,
          sessionId: 'sess-1',
          date: DateTime(2026, 10, 24),
          startTime: DateTime(2026, 10, 24, 8),
          syncStatus: LocalSyncStatus.draft,
          createdAt: DateTime(2026, 10, 24, 8),
          updatedAt: DateTime(2026, 10, 24, 8),
          ownerUserId: Value(owner),
        ));
  }

  Future<void> pump(
    WidgetTester tester, {
    List<LocalAssessment> queue = const [],
    DateTime? lastSyncedAt,
    Size size = const Size(412, 915),
    FormFactor formFactor = FormFactor.phone,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    sync = FakeAssessmentSyncService(queue: queue, lastSyncedAt: lastSyncedAt);
    final router = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => ProfileScreen(clock: () => now),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          Provider<AssessmentRepository>.value(
            value: AssessmentRepository(database: db),
          ),
          Provider<DeviceDataService>.value(value: deviceData),
          ChangeNotifierProvider<AssessmentSyncService>.value(value: sync),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: FormFactorScope(
          formFactor: formFactor,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Uma das quatro linhas: `role`, `sync`, `cache` ou `version`.
  static Finder row(String name) => find.byKey(Key('profile-row-$name'));
}
```

Criar `test/ui/profile/profile_layout_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';

import 'profile_harness.dart';

/// As medidas da aba Perfil contra os quadros do canvas, com a Inter de
/// verdade: a fonte de teste é mais larga e quebraria "Última sincronização"
/// em duas linhas numa tela de 412. Carregar a fonte vale para o arquivo
/// inteiro, por isso estas medidas moram aqui, longe dos outros testes.
void main() {
  setUpAll(() async {
    final loader = FontLoader('Inter')
      ..addFont(Future.value(
        ByteData.sublistView(File('assets/fonts/Inter.ttf').readAsBytesSync()),
      ));
    await loader.load();
  });

  late ProfileHarness h;

  setUp(() => h = ProfileHarness());
  tearDown(() => h.dispose());

  Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

  testWidgets('celular (quadro "2i"): 20 de recuo, linhas de 56 coladas, '
      '"Sair da conta" de 56 a 24 delas e o texto a 12 dele', (tester) async {
    await h.pump(tester);

    final header = rectOf(tester, find.ancestor(
      of: find.text('Perfil').first,
      matching: find.byType(Container),
    ).first);
    final name = rectOf(tester, find.text('Carla Mendes'));
    expect(name.left, 20);
    expect(name.top, header.bottom + 20);
    final email = rectOf(tester, find.text('carla.mendes@simtreinamentos.com.br'));
    expect(email.top, name.bottom + 4);

    final rows = [
      for (final r in ['role', 'sync', 'cache', 'version'])
        rectOf(tester, ProfileHarness.row(r)),
    ];
    expect(rows.first.top, email.bottom + 20 + 1.5);
    for (final r in rows) {
      expect(r.height, 56);
      expect(r.left, 0);
      expect(r.width, 412);
    }
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].top, rows[i - 1].bottom);
    }
    final icon = rectOf(tester, find.descendant(
      of: ProfileHarness.row('role'),
      matching: find.byType(Icon),
    ));
    expect(icon.left, 20);
    expect(icon.width, 22);
    expect(rectOf(tester, find.text('Perfil de acesso')).left, icon.right + 14);
    expect(rectOf(tester, find.text('Consultor')).right, 412 - 20);

    final button = rectOf(tester, find.byType(AppDangerOutlineButton));
    expect(button.height, 56);
    expect(button.left, 20);
    expect(button.right, 412 - 20);
    expect(button.top, rows.last.bottom + 24);
    expect(
      rectOf(tester, find.textContaining('Sair apaga as sessões')).top,
      button.bottom + 12,
    );
  });
}
```

Criar `test/ui/profile/profile_screen_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/profile/profile_labels.dart';

import '../../support/fake_assessment_sync_service.dart';
import 'profile_harness.dart';

void main() {
  late ProfileHarness h;

  setUp(() => h = ProfileHarness());
  tearDown(() => h.dispose());

  Finder row(String name) => ProfileHarness.row(name);

  /// Um quadro e o fim da animação do diálogo, sem esperar o resto assentar
  /// (o indicador de carregamento gira para sempre).
  Future<void> closeDialog(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('mostra quem entrou e as quatro linhas, sem "Empresa"',
      (tester) async {
    await h.pump(tester, lastSyncedAt: DateTime(2026, 10, 24, 7, 12));

    expect(find.text('Carla Mendes'), findsOneWidget);
    expect(find.text('carla.mendes@simtreinamentos.com.br'), findsOneWidget);
    expect(
      find.descendant(of: row('role'), matching: find.text('Consultor')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('sync'), matching: find.text('hoje 07:12')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('cache'), matching: find.text('18,4 MB')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('version'), matching: find.text('1.0.0 (1)')),
      findsOneWidget,
    );
    expect(find.text('Empresa'), findsNothing);
    expect(
      find.text(
        'Sair apaga as sessões baixadas neste aparelho. As avaliações na fila '
        'ficam guardadas e são enviadas quando você entrar de novo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('o administrador vê "Administrador", e quem nunca enviou, '
      '"Nenhum envio"', (tester) async {
    when(() => h.auth.currentUser).thenReturn(const AuthUser(
      id: 'user-2',
      name: 'Bruno Lima',
      email: 'bruno@simtc.com.br',
      role: AppUserRole.admin,
    ));
    await h.pump(tester);

    expect(
      find.descendant(of: row('role'), matching: find.text('Administrador')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('sync'), matching: find.text('Nenhum envio')),
      findsOneWidget,
    );
  });

  testWidgets('a navbar marca o Perfil', (tester) async {
    await h.pump(tester);

    expect(tester.widget<PillNavBar>(find.byType(PillNavBar)).currentIndex, 2);
  });

  testWidgets('o voltar do Android leva para Sessões', (tester) async {
    await h.pump(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  group('limpar cache local', () {
    testWidgets('pergunta antes; confirmando, limpa, mede de novo e avisa',
        (tester) async {
      await h.pump(tester);

      await tester.tap(row('cache'));
      await tester.pumpAndSettle();
      expect(find.text('Limpar cache local?'), findsOneWidget);
      expect(
        find.text(
          'As sessões, os participantes, o catálogo e os logos baixados serão '
          'apagados e baixados de novo quando você abrir as sessões. A fila e '
          'as avaliações iniciadas não são apagadas.',
        ),
        findsOneWidget,
      );

      when(() => h.deviceData.downloadedBytes())
          .thenAnswer((_) async => 36 * 1024);
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();

      verify(() => h.deviceData.clearDownloaded()).called(1);
      expect(find.text('Cache local limpo.'), findsOneWidget);
      expect(
        find.descendant(of: row('cache'), matching: find.text('36 KB')),
        findsOneWidget,
      );
    });

    testWidgets('cancelar não limpa', (tester) async {
      await h.pump(tester);

      await tester.tap(row('cache'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => h.deviceData.clearDownloaded());
    });

    testWidgets('enquanto limpa, a linha gira, não aceita outro toque e o '
        '"Sair da conta" espera', (tester) async {
      final gate = Completer<void>();
      when(() => h.deviceData.clearDownloaded()).thenAnswer((_) => gate.future);
      await h.pump(tester);

      await tester.tap(row('cache'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar'));
      await closeDialog(tester);

      expect(
        find.descendant(
          of: row('cache'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(row('cache'));
      await closeDialog(tester);
      expect(find.text('Limpar cache local?'), findsNothing);
      expect(
        tester
            .widget<AppDangerOutlineButton>(find.byType(AppDangerOutlineButton))
            .onPressed,
        isNull,
      );

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a falha avisa', (tester) async {
      when(() => h.deviceData.clearDownloaded()).thenThrow(Exception('disco'));
      await h.pump(tester);

      await tester.tap(row('cache'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível limpar o cache. Tente de novo.'),
        findsOneWidget,
      );
    });

    testWidgets('sem conexão, fica desativado e diz por quê', (tester) async {
      await h.goOffline();
      await h.pump(tester);

      expect(
        find.descendant(
          of: row('cache'),
          matching: find.text('Disponível quando houver conexão'),
        ),
        findsOneWidget,
      );
      await tester.tap(row('cache'));
      await tester.pumpAndSettle();

      expect(find.text('Limpar cache local?'), findsNothing);
    });
  });

  group('sair da conta', () {
    testWidgets('sem fila nem rascunho, a confirmação é a simples; '
        'confirmando, sai', (tester) async {
      await h.pump(tester);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsOneWidget);
      expect(
        find.text(logoutMessage(queued: 0, drafts: 0, offline: false)),
        findsOneWidget,
      );
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      verify(() => h.auth.logout()).called(1);
    });

    testWidgets('com fila e rascunho, sem rede, a confirmação avisa o que '
        'fica guardado e que entrar de novo precisa de rede', (tester) async {
      await h.goOffline();
      await h.seedDraft();
      await h.seedDraft(owner: 'outra-pessoa', participantId: 'tp-8');
      await h.pump(tester, queue: [
        queuedAssessment('tp-1'),
        queuedAssessment('tp-2'),
      ]);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(
        find.text(logoutMessage(queued: 2, drafts: 1, offline: true)),
        findsOneWidget,
      );
    });

    testWidgets('cancelar não sai', (tester) async {
      await h.pump(tester);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => h.auth.logout());
    });

    testWidgets('enquanto sai, o botão gira e o "Limpar cache local" espera',
        (tester) async {
      final gate = Completer<void>();
      when(() => h.auth.logout()).thenAnswer((_) => gate.future);
      await h.pump(tester);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await closeDialog(tester);

      expect(
        tester
            .widget<AppDangerOutlineButton>(find.byType(AppDangerOutlineButton))
            .isLoading,
        isTrue,
      );
      await tester.tap(row('cache'));
      await closeDialog(tester);
      expect(find.text('Limpar cache local?'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a falha avisa', (tester) async {
      when(() => h.auth.logout()).thenThrow(Exception('keystore'));
      await h.pump(tester);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível sair. Tente de novo.'), findsOneWidget);
    });
  });
}
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
```

por:

```dart
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
```

por:

```dart
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/device_data_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/sync_status_indicator.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
```

por:

```dart
import 'package:simtc/ui/core/widgets/sync_status_indicator.dart';
import 'package:simtc/ui/profile/profile_screen.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
    implements SessionConsultantRepository {}

class _MockAssessmentRepository extends Mock implements AssessmentRepository {}

void main() {
  late _MockSessionRepository repository;
```

por:

```dart
    implements SessionConsultantRepository {}

class _MockAssessmentRepository extends Mock implements AssessmentRepository {}

class _MockDeviceData extends Mock implements DeviceDataService {}

void main() {
  late _MockSessionRepository repository;
```

Em `test/ui/sessions/sessions_screen_test.dart`, substituir:

```dart
  testWidgets('"Perfil" continua avisando que chega numa próxima versão',
      (tester) async {
    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    await tester.tap(find.text('Perfil'));
    await tester.pump();

    expect(find.text('Disponível em breve.'), findsOneWidget);
```

por:

```dart
  testWidgets('"Perfil" na navbar abre a aba, e "Sessões" volta',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'SIMTC',
      packageName: 'br.com.simtc.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final deviceData = _MockDeviceData();
    when(deviceData.downloadedBytes).thenAnswer((_) async => 0);
    when(() => auth.isAuthenticated).thenReturn(true);
    final router = createRouter(auth, initialLocation: AppRoutes.home);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: repository),
          Provider<AssessmentCatalogRepository>.value(value: catalog),
          Provider<AssessmentRepository>.value(value: _MockAssessmentRepository()),
          Provider<DeviceDataService>.value(value: deviceData),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
          ChangeNotifierProvider<AssessmentSyncService>.value(
            value: FakeAssessmentSyncService(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    sessions.add([hoje()]);
    await tester.pump();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.tap(find.text('Sessões'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SessionsScreen), findsOneWidget);
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/profile test/ui/core/widgets/app_nav_bar_test.dart test/ui/sessions/sessions_screen_test.dart`
Esperado: `+16 -5: Some tests failed.` — não compilam `profile_screen_test.dart`, `profile_layout_test.dart`, `app_nav_bar_test.dart` e `sessions_screen_test.dart` (`AppRoutes.profile`, `AppTab.profile` e `ProfileScreen` não existem).

- [ ] **Step 3: Implementar**

Em `lib/router.dart`, substituir:

```dart
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/result/result_screen.dart';
```

por:

```dart
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/profile/profile_screen.dart';
import 'ui/result/result_screen.dart';
```

Em `lib/router.dart`, substituir:

```dart
  /// Aba "Sincronizar" (tela 1.9, Fase 5A).
  static const String sync = '/sync';

  /// Detalhe da sessão (tela 1.4).
```

por:

```dart
  /// Aba "Sincronizar" (tela 1.9, Fase 5A).
  static const String sync = '/sync';

  /// Aba "Perfil" (tela 1.10, Fase 8A).
  static const String profile = '/profile';

  /// Detalhe da sessão (tela 1.4).
```

Em `lib/router.dart`, substituir:

```dart
      GoRoute(
        path: '/sessions/:sessionId',
```

por:

```dart
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/sessions/:sessionId',
```

Em `lib/ui/core/theme/app_icons.dart`, substituir:

```dart
  static const IconData info = Icons.info_outlined;
  static const IconData addConsultant = Icons.person_add_alt_outlined;
```

por:

```dart
  static const IconData info = Icons.info_outlined;

  /// Perfil (Fase 8A, canvas "2i"): a linha "Perfil de acesso" e a "Limpar
  /// cache local".
  static const IconData accessRole = Icons.badge_outlined;
  static const IconData clearCache = Icons.delete_sweep_outlined;
  static const IconData addConsultant = Icons.person_add_alt_outlined;
```

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
  static TextStyle get screenSubtitleTablet =>
      _inter(size: 13.5, weight: FontWeight.w400, height: 1.2, color: AppColors.text3);

  /// Título do cartão âmbar da fila sem rede ("3 avaliações na fila")
```

por:

```dart
  static TextStyle get screenSubtitleTablet =>
      _inter(size: 13.5, weight: FontWeight.w400, height: 1.2, color: AppColors.text3);

  // ─── Perfil (quadro "2i" do canvas) ───────────────────────────────────────

  /// E-mail embaixo do nome
  static TextStyle get profileEmail =>
      _inter(size: 13, weight: FontWeight.w400, height: 1.3, color: AppColors.text3);

  /// Rótulo de uma linha ("Perfil de acesso")
  static TextStyle get profileRowLabel =>
      _inter(size: 15, weight: FontWeight.w500, height: 1.3);

  /// Valor de uma linha ("Consultor", "hoje 07:12")
  static TextStyle get profileRowValue =>
      _inter(size: 14, weight: FontWeight.w400, height: 1.3);

  /// O texto embaixo do "Sair da conta"
  static TextStyle get profileNote =>
      _inter(size: 12.5, weight: FontWeight.w400, height: 1.45, color: AppColors.text3);

  /// Título do cartão âmbar da fila sem rede ("3 avaliações na fila")
```

Em `lib/ui/core/widgets/app_nav_bar.dart`, substituir:

```dart
/// As abas que têm tela. "Perfil" ainda não tem (Fase 8).
enum AppTab { sessions, sync }
```

por:

```dart
/// As três abas da navbar, na ordem dos itens.
enum AppTab { sessions, sync, profile }
```

Em `lib/ui/core/widgets/app_nav_bar.dart`, substituir:

```dart
/// abas Sessões e Sincronizar, em qualquer formato.
```

por:

```dart
/// três abas, em qualquer formato.
```

Em `lib/ui/core/widgets/app_nav_bar.dart`, substituir:

```dart
        if (index == 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Disponível em breve.')),
          );
```

por:

```dart
        if (index == AppTab.profile.index && current != AppTab.profile) {
          context.go(AppRoutes.profile);
```

Criar `lib/ui/profile/profile_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/auth_user.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/assessment_sync_service.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/device_data_service.dart';
import '../../router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_nav_bar.dart';
import 'profile_labels.dart';
import 'profile_viewmodel.dart';

/// Tela 1.10 — aba "Perfil" (quadro "2i" do canvas, Fase 8A).
///
/// Quem entrou, o perfil de acesso, a última sincronização, o "Limpar cache
/// local" e a versão do app; e o "Sair da conta", que pede confirmação. Sem a
/// linha "Empresa" do canvas: o backend não liga consultor a nenhuma empresa
/// (decisão de 24/10/2026).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.clock});

  /// Relógio injetável para os testes; o padrão é `DateTime.now`.
  final DateTime Function()? clock;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileViewModel _viewModel = ProfileViewModel(
    auth: context.read<AuthRepository>(),
    assessments: context.read<AssessmentRepository>(),
    deviceData: context.read<DeviceDataService>(),
  )..init();

  /// O texto do rodapé do canvas mandava sincronizar antes de sair; com a
  /// fila guardada no "Sair" (decisão de 24/10/2026), ele diz isso.
  static const String _footnote =
      'Sair apaga as sessões baixadas neste aparelho. As avaliações na fila '
      'ficam guardadas e são enviadas quando você entrar de novo.';

  static const String _clearMessage =
      'As sessões, os participantes, o catálogo e os logos baixados serão '
      'apagados e baixados de novo quando você abrir as sessões. A fila e as '
      'avaliações iniciadas não são apagadas.';

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<AssessmentSyncService>();
    final isOffline = context.watch<ConnectivityService>().isOffline;
    final now = (widget.clock ?? DateTime.now)();
    final content = Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) => _buildBody(sync, isOffline, now),
          ),
        ),
      ],
    );

    // É uma aba, não uma tela empilhada: o voltar do Android leva para
    // Sessões, em vez de fechar o app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: TabSnackBarArea(
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(child: content),
          bottomNavigationBar: const AppNavBar(current: AppTab.profile),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
      child: Text('Perfil', style: AppTypography.screenTitle),
    );
  }

  Widget _buildBody(AssessmentSyncService sync, bool isOffline, DateTime now) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.xxl),
      children: [
        _buildIdentity(_viewModel.user),
        _buildRows(sync, isOffline, now),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
            0,
          ),
          child: _buildLogoutButton(isOffline),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            0,
          ),
          child: Text(_footnote, style: AppTypography.profileNote),
        ),
      ],
    );
  }

  /// Nome e e-mail: 20 de recuo, 4 entre os dois e 20 até as linhas.
  Widget _buildIdentity(AuthUser? user) {
    return Padding(
      key: const Key('profile-identity'),
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user?.name ?? '', style: AppTypography.detailTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            user?.email ?? '',
            style: AppTypography.profileEmail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// As quatro linhas, coladas: uma divisória de 1,5 em cima do grupo e uma
  /// embaixo de cada linha (o quadro desenha em cima e embaixo de cada uma,
  /// o que somaria 3 entre duas).
  Widget _buildRows(AssessmentSyncService sync, bool isOffline, DateTime now) {
    final user = _viewModel.user;
    final bytes = _viewModel.cacheBytes;
    final busy = _viewModel.isClearing || _viewModel.isLoggingOut;

    // Um `Container`, e não um `DecoratedBox`: a divisória de cima ocupa o
    // seu 1,5 em vez de ser pintada por cima da primeira linha.
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileRow(
            key: const Key('profile-row-role'),
            icon: AppIcons.accessRole,
            label: 'Perfil de acesso',
            value: user == null ? '' : roleLabel(user.role),
          ),
          _ProfileRow(
            key: const Key('profile-row-sync'),
            icon: AppIcons.sync,
            label: 'Última sincronização',
            value: lastSyncValue(sync.lastSyncedAt, now),
          ),
          _ProfileRow(
            key: const Key('profile-row-cache'),
            icon: AppIcons.clearCache,
            label: 'Limpar cache local',
            note: isOffline ? 'Disponível quando houver conexão' : null,
            value: bytes == null ? '—' : sizeLabel(bytes),
            isLoading: _viewModel.isClearing,
            onTap: isOffline || busy ? null : _confirmClear,
          ),
          _ProfileRow(
            key: const Key('profile-row-version'),
            icon: AppIcons.info,
            label: 'Versão do app',
            value: _viewModel.version ?? '—',
            valueColor: AppColors.text3,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(bool isOffline) {
    return AppDangerOutlineButton(
      label: 'Sair da conta',
      icon: AppIcons.logout,
      isLoading: _viewModel.isLoggingOut,
      onPressed: _viewModel.isClearing ? null : () => _confirmLogout(isOffline),
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar cache local?'),
        content: const Text(_clearMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final cleared = await _viewModel.clearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cleared
              ? 'Cache local limpo.'
              : 'Não foi possível limpar o cache. Tente de novo.',
        ),
      ),
    );
  }

  /// Avisa e deixa sair (decisão de 24/10/2026): a confirmação diz o que fica
  /// guardado no aparelho e, sem rede, que entrar de novo vai exigir conexão.
  Future<void> _confirmLogout(bool isOffline) async {
    final queued = context.read<AssessmentSyncService>().queue.length;
    final drafts = await _viewModel.countStartedDrafts();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: Text(
          logoutMessage(queued: queued, drafts: drafts, offline: isOffline),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Saindo, o roteador leva ao login sozinho; aqui só a falha importa.
    final left = await _viewModel.logout();
    if (left || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível sair. Tente de novo.')),
    );
  }
}

/// Uma linha do Perfil (quadro "2i"): ícone de 22, rótulo e valor; 15 em
/// cima e embaixo, 20 dos lados, 14 entre o ícone e o rótulo, e pelo menos
/// 56 de altura. Com [onTap], a linha inteira é o alvo do toque; [note]
/// aparece embaixo do rótulo (o motivo de estar desativada).
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.note,
    this.isLoading = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final String? note;
  final bool isLoading;
  final VoidCallback? onTap;

  static const double _iconSize = 22;
  static const double _iconGap = AppSpacing.md + 2;
  static const double _spinnerSize = 16;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md + 3,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
          ),
          child: Row(
            children: [
              Icon(icon, size: _iconSize, color: AppColors.text3),
              const SizedBox(width: _iconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTypography.profileRowLabel),
                    if (note != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(note, style: AppTypography.meta),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (isLoading)
                const SizedBox(
                  width: _spinnerSize,
                  height: _spinnerSize,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  value,
                  style: AppTypography.profileRowValue.copyWith(
                    color: valueColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/profile test/ui/core/widgets/app_nav_bar_test.dart test/ui/sessions/sessions_screen_test.dart`
Esperado: `+66: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1067: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/profile/profile_screen.dart apps/mobile/simtc/test/ui/profile/profile_harness.dart apps/mobile/simtc/test/ui/profile/profile_layout_test.dart apps/mobile/simtc/test/ui/profile/profile_screen_test.dart apps/mobile/simtc/lib/router.dart apps/mobile/simtc/lib/ui/core/theme/app_icons.dart apps/mobile/simtc/lib/ui/core/theme/app_typography.dart apps/mobile/simtc/lib/ui/core/widgets/app_nav_bar.dart apps/mobile/simtc/test/ui/core/widgets/app_nav_bar_test.dart apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): aba perfil no celular com sair e limpar cache"
```

---

## Task 7: A aba Perfil no tablet

Os quadros `4k` (paisagem) e `4v` (retrato): a navbar do tablet (`TabletNavFrame`), o cabeçalho de 24, uma coluna de até 820 centrada com 24 de margem, o "Sair da conta" compacto ao lado do nome e as linhas de 64. Girar não recria a tela: a árvore é a mesma nas duas posições.

**Files:**
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/widgets/app_buttons.dart`
- Modify: `lib/ui/profile/profile_screen.dart`
- Modify: `test/ui/profile/profile_layout_test.dart`
- Modify: `test/ui/profile/profile_screen_test.dart`

**Interfaces:**
- Consumes: `ProfileScreen` (Task 6); `TabletNavFrame` e `context.isTablet` (Fase 7A).
- Produces:
  - `AppDangerOutlineButton.expand` (padrão `true`; sem ele, a largura é a do rótulo)
  - `AppTypography.profileNameTablet`, `profileEmailTablet`, `profileRowLabelTablet`, `profileRowValueTablet`, `profileNoteTablet`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/profile/profile_layout_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
```

por:

```dart
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
```

Em `test/ui/profile/profile_layout_test.dart`, substituir:

```dart
  });
}
```

por:

```dart
  });

  /// O tablet numa janela de [size]: confere a coluna de [columnLeft] a
  /// [columnRight] (quadros "4k" e "4v").
  Future<void> checkTablet(
    WidgetTester tester,
    Size size, {
    required double columnLeft,
    required double columnRight,
  }) async {
    await h.pump(tester, size: size, formFactor: FormFactor.tablet);

    final title = tester.widget<Text>(find.text('Perfil').first);
    expect(title.style!.fontSize, 24);
    final header = rectOf(tester, find.ancestor(
      of: find.text('Perfil').first,
      matching: find.byType(Container),
    ).first);
    expect(rectOf(tester, find.text('Perfil').first).left, header.left + 24);

    final name = rectOf(tester, find.text('Carla Mendes'));
    expect(tester.widget<Text>(find.text('Carla Mendes')).style!.fontSize, 22);
    expect(name.left, columnLeft);
    expect(name.top, header.bottom + 24);
    final email = rectOf(tester, find.text('carla.mendes@simtreinamentos.com.br'));
    expect(email.top, name.bottom + 5);

    final button = rectOf(tester, find.byType(AppDangerOutlineButton));
    expect(button.height, 48);
    expect(button.right, columnRight);
    expect(button.width, lessThan(240));

    final identity = rectOf(tester, find.byKey(const Key('profile-identity')));
    final rows = [
      for (final r in ['role', 'sync', 'cache', 'version'])
        rectOf(tester, ProfileHarness.row(r)),
    ];
    expect(rows.first.top, identity.bottom + 1.5);
    expect(identity.height, email.bottom - name.top + 22);
    for (final r in rows) {
      expect(r.height, 64);
      expect(r.left, columnLeft);
      expect(r.right, columnRight);
    }
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].top, rows[i - 1].bottom);
    }
    final icon = rectOf(tester, find.descendant(
      of: ProfileHarness.row('role'),
      matching: find.byType(Icon),
    ));
    expect(icon.left, columnLeft);
    expect(icon.width, 23);
    expect(rectOf(tester, find.text('Perfil de acesso')).left, icon.right + 16);
    expect(
      tester.widget<Text>(find.text('Perfil de acesso')).style!.fontSize,
      16,
    );
    expect(rectOf(tester, find.text('Consultor')).right, columnRight);
    expect(tester.widget<Text>(find.text('Consultor')).style!.fontSize, 14.5);

    final note = find.textContaining('Sair apaga as sessões');
    expect(rectOf(tester, note).top, rows.last.bottom + 16);
    expect(tester.widget<Text>(note).style!.fontSize, 13);
  }

  testWidgets('tablet em paisagem (quadro "4k"): navbar na lateral e coluna '
      'de 820 centrada no espaço que sobra', (tester) async {
    // O conteúdo começa em 116 (a navbar lateral): sobram 1164, e a coluna
    // de 820 fica a 172 de cada lado.
    await checkTablet(
      tester,
      const Size(1280, 800),
      columnLeft: 116 + 172,
      columnRight: 116 + 172 + 820,
    );
    expect(
      tester.widget<PillNavBar>(find.byType(PillNavBar)).layout,
      PillNavLayout.rail,
    );
  });

  testWidgets('tablet em retrato (quadro "4v"): pílula na base e a coluna na '
      'largura toda, com 24 de margem', (tester) async {
    await checkTablet(
      tester,
      const Size(800, 1280),
      columnLeft: 24,
      columnRight: 800 - 24,
    );
    expect(
      tester.widget<PillNavBar>(find.byType(PillNavBar)).layout,
      PillNavLayout.tabletBottom,
    );
  });

  testWidgets('tablet numa janela de 1000: a coluna continua com 820, centrada',
      (tester) async {
    // 1000 − 116 = 884 de conteúdo: 32 de cada lado da coluna.
    await checkTablet(
      tester,
      const Size(1000, 800),
      columnLeft: 116 + 32,
      columnRight: 116 + 32 + 820,
    );
  });

  testWidgets('tablet numa janela estreita (tela dividida, 500): a coluna fica '
      'com 24 de margem e nada estoura', (tester) async {
    await h.pump(tester, size: const Size(500, 900), formFactor: FormFactor.tablet);

    expect(tester.takeException(), isNull);
    expect(rectOf(tester, ProfileHarness.row('role')).left, 24);
    expect(rectOf(tester, find.byType(AppDangerOutlineButton)).right, 500 - 24);
  });
}
```

Em `test/ui/profile/profile_screen_test.dart`, substituir:

```dart
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/profile/profile_labels.dart';
```

por:

```dart
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/profile/profile_labels.dart';
import 'package:simtc/ui/profile/profile_screen.dart';
```

Em `test/ui/profile/profile_screen_test.dart`, substituir:

```dart
    expect(tester.widget<PillNavBar>(find.byType(PillNavBar)).currentIndex, 2);
  });
```

por:

```dart
    expect(tester.widget<PillNavBar>(find.byType(PillNavBar)).currentIndex, 2);
  });

  testWidgets(
      'no tablet, girar com a limpeza em andamento não recria a tela: a linha '
      'continua girando e o fim da limpeza chega', (tester) async {
    final gate = Completer<void>();
    when(() => h.deviceData.clearDownloaded()).thenAnswer((_) => gate.future);
    await h.pump(tester, size: const Size(1280, 800), formFactor: FormFactor.tablet);
    final state = tester.state(find.byType(ProfileScreen));

    await tester.tap(row('cache'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar'));
    await closeDialog(tester);
    for (final size in const [Size(800, 1280), Size(1280, 800), Size(800, 1280)]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(tester.state(find.byType(ProfileScreen)), same(state));
      expect(
        find.descendant(
          of: row('cache'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    }

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Cache local limpo.'), findsOneWidget);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/profile`
Esperado: `+32 -4: Some tests failed.` — os quatro testes de medida do tablet (paisagem, retrato, janela de 1000 e tela dividida); o de girar com a limpeza em andamento já passa.

- [ ] **Step 3: Implementar**

Em `lib/ui/core/theme/app_typography.dart`, substituir:

```dart
  static TextStyle get profileNote =>
      _inter(size: 12.5, weight: FontWeight.w400, height: 1.45, color: AppColors.text3);

  /// Título do cartão âmbar da fila sem rede ("3 avaliações na fila")
```

por:

```dart
  static TextStyle get profileNote =>
      _inter(size: 12.5, weight: FontWeight.w400, height: 1.45, color: AppColors.text3);

  /// Os mesmos no tablet (quadros "4k" e "4v"), mais o nome
  static TextStyle get profileNameTablet =>
      _inter(size: 22, weight: FontWeight.w600, height: 1.25);

  static TextStyle get profileEmailTablet =>
      _inter(size: 14, weight: FontWeight.w400, height: 1.3, color: AppColors.text3);

  static TextStyle get profileRowLabelTablet =>
      _inter(size: 16, weight: FontWeight.w500, height: 1.3);

  static TextStyle get profileRowValueTablet =>
      _inter(size: 14.5, weight: FontWeight.w400, height: 1.3);

  static TextStyle get profileNoteTablet =>
      _inter(size: 13, weight: FontWeight.w400, height: 1.45, color: AppColors.text3);

  /// Título do cartão âmbar da fila sem rede ("3 avaliações na fila")
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
/// alvo mínimo do DS.
```

por:

```dart
/// alvo mínimo do DS. Sem [expand], tem a largura do rótulo em vez da do pai
/// — o "Sair da conta" ao lado do nome, no Perfil do tablet.
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
    this.compact = false,
  });
```

por:

```dart
    this.compact = false,
    this.expand = true,
  });
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
  final IconData? icon;
  final bool compact;

  @override
```

por:

```dart
  final IconData? icon;
  final bool compact;
  final bool expand;

  @override
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
      height: compact ? AppSpacing.touchTarget : AppSpacing.controlHeight,
      width: double.infinity,
      child: OutlinedButton(
```

por:

```dart
      height: compact ? AppSpacing.touchTarget : AppSpacing.controlHeight,
      width: expand ? double.infinity : null,
      child: OutlinedButton(
```

Em `lib/ui/core/widgets/app_buttons.dart`, substituir:

```dart
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 19 : 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
```

por:

```dart
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 19 : 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        // Sem [expand], a largura é a do rótulo: não há o que encolher.
        if (expand)
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis))
        else
          Text(label),
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
import 'package:flutter/material.dart';
```

por:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

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

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
/// Tela 1.10 — aba "Perfil" (quadro "2i" do canvas, Fase 8A).
```

por:

```dart
/// Tela 1.10 — aba "Perfil" (quadros "2i" do celular e "4k"/"4v" do tablet,
/// Fase 8A).
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
    final content = Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) => _buildBody(sync, isOffline, now),
```

por:

```dart
    final tablet = context.isTablet;
    final content = Column(
      children: [
        _buildHeader(tablet: tablet),
        Expanded(
          child: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) => tablet
                ? _buildTabletBody(sync, isOffline, now)
                : _buildBody(sync, isOffline, now),
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
          body: SafeArea(child: content),
          bottomNavigationBar: const AppNavBar(current: AppTab.profile),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
      child: Text('Perfil', style: AppTypography.screenTitle),
```

por:

```dart
          body: SafeArea(
            child: tablet
                ? TabletNavFrame(current: AppTab.profile, child: content)
                : content,
          ),
          bottomNavigationBar:
              tablet ? null : const AppNavBar(current: AppTab.profile),
        ),
      ),
    );
  }

  /// Tablet: 14 em cima e embaixo, 24 dos lados e título de 24 (quadros
  /// "4k" e "4v").
  Widget _buildHeader({required bool tablet}) {
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
      child: Text(
        'Perfil',
        style: tablet ? AppTypography.homeTitle : AppTypography.screenTitle,
      ),
    );
  }

  /// No tablet, uma coluna de no máximo 820, centrada, com 24 de margem
  /// pelo menos (quadros "4k" e "4v").
  static const double _tabletColumnWidth = 820;

  Widget _buildTabletBody(
    AssessmentSyncService sync,
    bool isOffline,
    DateTime now,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(
          AppSpacing.xxl,
          (constraints.maxWidth - _tabletColumnWidth) / 2,
        );
        return ListView(
          padding: EdgeInsets.fromLTRB(
            side,
            AppSpacing.xxl,
            side,
            AppSpacing.xxxl,
          ),
          children: [
            _buildTabletIdentity(_viewModel.user, isOffline),
            _buildRows(sync, isOffline, now, tablet: true),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Text(_footnote, style: AppTypography.profileNoteTablet),
            ),
          ],
        );
      },
    );
  }

  /// Tablet: o nome e o e-mail à esquerda, o "Sair da conta" à direita, 16
  /// entre os dois e 22 até as linhas.
  Widget _buildTabletIdentity(AuthUser? user, bool isOffline) {
    return Padding(
      key: const Key('profile-identity'),
      padding: const EdgeInsets.only(bottom: AppSpacing.xl + 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.name ?? '', style: AppTypography.profileNameTablet),
                const SizedBox(height: AppSpacing.xs + 1),
                Text(
                  user?.email ?? '',
                  style: AppTypography.profileEmailTablet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          _buildLogoutButton(isOffline, compact: true),
        ],
      ),
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
  Widget _buildRows(AssessmentSyncService sync, bool isOffline, DateTime now) {
```

por:

```dart
  Widget _buildRows(
    AssessmentSyncService sync,
    bool isOffline,
    DateTime now, {
    bool tablet = false,
  }) {
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
            icon: AppIcons.accessRole,
            label: 'Perfil de acesso',
            value: user == null ? '' : roleLabel(user.role),
          ),
          _ProfileRow(
            key: const Key('profile-row-sync'),
            icon: AppIcons.sync,
            label: 'Última sincronização',
            value: lastSyncValue(sync.lastSyncedAt, now),
          ),
          _ProfileRow(
            key: const Key('profile-row-cache'),
```

por:

```dart
            tablet: tablet,
            icon: AppIcons.accessRole,
            label: 'Perfil de acesso',
            value: user == null ? '' : roleLabel(user.role),
          ),
          _ProfileRow(
            key: const Key('profile-row-sync'),
            tablet: tablet,
            icon: AppIcons.sync,
            label: 'Última sincronização',
            value: lastSyncValue(sync.lastSyncedAt, now),
          ),
          _ProfileRow(
            key: const Key('profile-row-cache'),
            tablet: tablet,
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
            key: const Key('profile-row-version'),
            icon: AppIcons.info,
```

por:

```dart
            key: const Key('profile-row-version'),
            tablet: tablet,
            icon: AppIcons.info,
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
  Widget _buildLogoutButton(bool isOffline) {
    return AppDangerOutlineButton(
      label: 'Sair da conta',
      icon: AppIcons.logout,
```

por:

```dart
  /// No tablet, [compact]: o botão de 48 ao lado do nome, da largura do
  /// rótulo (quadros "4k" e "4v").
  Widget _buildLogoutButton(bool isOffline, {bool compact = false}) {
    return AppDangerOutlineButton(
      label: 'Sair da conta',
      icon: AppIcons.logout,
      compact: compact,
      expand: !compact,
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
/// 56 de altura. Com [onTap], a linha inteira é o alvo do toque; [note]
/// aparece embaixo do rótulo (o motivo de estar desativada).
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    super.key,
```

por:

```dart
/// 56 de altura. No [tablet] (quadros "4k" e "4v"): ícone de 23, 18 em cima e
/// embaixo, sem recuo dos lados (a coluna já tem), 16 entre o ícone e o
/// rótulo e pelo menos 64. Com [onTap], a linha inteira é o alvo do toque;
/// [note] aparece embaixo do rótulo (o motivo de estar desativada).
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    super.key,
    this.tablet = false,
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
  });

  final IconData icon;
  final String label;
```

por:

```dart
  });

  final bool tablet;
  final IconData icon;
  final String label;
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
  static const double _iconGap = AppSpacing.md + 2;
  static const double _spinnerSize = 16;
```

por:

```dart
  static const double _iconGap = AppSpacing.md + 2;
  static const double _tabletIconSize = 23;
  static const double _tabletMinHeight = AppSpacing.controlHeight + AppSpacing.sm;
  static const double _spinnerSize = 16;
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
          constraints: const BoxConstraints(minHeight: AppSpacing.controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md + 3,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
          ),
          child: Row(
            children: [
              Icon(icon, size: _iconSize, color: AppColors.text3),
              const SizedBox(width: _iconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTypography.profileRowLabel),
```

por:

```dart
          constraints: BoxConstraints(
            minHeight: tablet ? _tabletMinHeight : AppSpacing.controlHeight,
          ),
          padding: tablet
              ? const EdgeInsets.symmetric(vertical: AppSpacing.lg + 2)
              : const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md + 3,
                ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: tablet ? _tabletIconSize : _iconSize,
                color: AppColors.text3,
              ),
              SizedBox(width: tablet ? AppSpacing.lg : _iconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: tablet
                          ? AppTypography.profileRowLabelTablet
                          : AppTypography.profileRowLabel,
                    ),
```

Em `lib/ui/profile/profile_screen.dart`, substituir:

```dart
                  style: AppTypography.profileRowValue.copyWith(
                    color: valueColor,
                  ),
```

por:

```dart
                  style: (tablet
                          ? AppTypography.profileRowValueTablet
                          : AppTypography.profileRowValue)
                      .copyWith(color: valueColor),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/profile`
Esperado: `+36: All tests passed!`

- [ ] **Step 5: Conferir o projeto inteiro**

Run: `flutter analyze` e depois `flutter test -r failures-only`
Esperado: `No issues found!` e `+1072: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/simtc/lib/ui/core/theme/app_typography.dart apps/mobile/simtc/lib/ui/core/widgets/app_buttons.dart apps/mobile/simtc/lib/ui/profile/profile_screen.dart apps/mobile/simtc/test/ui/profile/profile_layout_test.dart apps/mobile/simtc/test/ui/profile/profile_screen_test.dart
git commit -m "feat(mobile): aba perfil no tablet"
```

---
## Task 8: Validação no aparelho e no emulador, contra a produção

O portão da 8A, que só o usuário pode rodar. O celular é conferido no **aparelho físico** e o tablet no **emulador** (o mesmo Pixel Tablet da Fase 7), os dois falando com a **API de produção**.

**Interfaces:**
- Consumes: a produção publicada (Task 1) e o app com as Tasks 2 a 7.
- Produces: o aval do usuário para planejar a 8B.

- [ ] **Step 1: Instalar no celular, apontando para a produção**

Sem backend local e sem `adb reverse`: em `apps/mobile/simtc/`, `flutter run -d <id do celular>`.
Esperado: o app abre na Abertura e vai para a tela Entrar — a primeira abertura depois da 8A apaga o que havia no aparelho (o endereço mudou de `localhost` para a produção).

- [ ] **Step 2: Roteiro no celular**

Com uma conta CONSULTANT de teste da produção, depois com uma ADMIN, e com um segundo consultor:

1. **Entrar e ver a agenda da produção:** as sessões de teste da produção aparecem na Home.
2. **Perfil:** tocar em "Perfil" na navbar. Nome e e-mail de quem entrou; "Perfil de acesso" com "Consultor" (ou "Administrador" na conta ADMIN); "Última sincronização"; "Limpar cache local" com o espaço; "Versão do app" com "1.0.0 (1)"; sem a linha "Empresa"; o "Sair da conta" em vermelho e o texto embaixo dele. O voltar do Android leva a Sessões.
3. **Limpar cache local:** tocar, ler a confirmação, "Limpar". Aparece "Cache local limpo." e o espaço cai. Voltar a Sessões: a agenda baixa de novo. No modo avião, a linha fica apagada com "Disponível quando houver conexão".
4. **Sair sem nada na fila:** "Sair da conta" → a confirmação simples → "Sair": o app vai para a tela Entrar.
5. **Sair e entrar com outro consultor (item herdado da Fase 2):** entrar com o segundo consultor e conferir que a agenda do primeiro **não** aparece, nem por um instante. Repetir no modo avião logo depois de entrar (a Home sem rede não mostra a agenda do anterior).
6. **Sair com avaliação na fila e sem rede:** com o primeiro consultor, confirmar uma avaliação no modo avião (fica "Na fila"), ir ao Perfil e tocar "Sair da conta": a confirmação diz que a avaliação fica guardada e que entrar de novo precisa de rede. Sair, desligar o modo avião, entrar de novo com o mesmo consultor: a avaliação sai sozinha (aba Sincronizar vazia, e o painel web mostra a avaliação).
7. **Sair com avaliação iniciada:** iniciar uma avaliação e sair: a confirmação fala da avaliação iniciada; entrar de novo com o mesmo consultor e abrir o participante: o checklist continua de onde parou.
8. **Voltar ao backend local e à produção (a limpeza da troca de servidor):** com o backend local rodando e o `adb reverse tcp:3001 tcp:3001`, rodar `flutter run -d <id> --dart-define=API_BASE_URL=http://localhost:3001/api`: o app abre na tela Entrar, sem nada do que havia (nem a fila). Rodar de novo sem o `--dart-define`: volta para a tela Entrar outra vez.

- [ ] **Step 3: Roteiro no tablet (emulador)**

Com o emulador ligado e com internet (sem `adb reverse`): `flutter run -d emulator-5554`.

1. **Perfil em paisagem:** a navbar na lateral; nome, e-mail e o "Sair da conta" na mesma faixa, à direita; as quatro linhas numa coluna centrada.
2. **Girar para retrato:** a pílula na base; a coluna ocupa a largura com margem. Girar de novo no meio do "Limpar cache local" (logo depois de confirmar): a tela não pisca nem perde o aviso "Cache local limpo.".
3. **Sair e entrar com outro consultor** no tablet: a agenda do anterior não aparece.

- [ ] **Step 4: Registrar o resultado**

Se tudo passar, acrescentar ao fim desta task a linha "**Validado em <data>: celular no aparelho físico e tablet no emulador, contra a produção; roteiro inteiro passou. Aval dado para planejar a 8B.**" e commitar:

```bash
git add apps/mobile/docs/superpowers/plans/2026-10-24-mobile-fase-8a-producao-e-perfil.md
git commit -m "docs(mobile): registra a validacao da fase 8a contra a producao"
```

Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio, parar e perguntar.

**Validado em 24/10/2026: celular no aparelho físico e tablet no emulador, contra a produção; roteiro inteiro passou. Aval dado para planejar a 8B.** A produção foi publicada pelo avanço direto da `feat/frontend-backend-integration` até `d5e4b9c` (sem PR: o `gh` não está instalado), e o usuário confirmou o login no web. Durante a execução entraram duas correções de revisão: a renovação de token que termina depois do "Sair" não grava os tokens de volta (`8760e00`), e a fila espera o catálogo antes de enviar depois do "Limpar cache local" (`3485f22`). Suíte final: 1074 testes.

---

## Pendências levadas para a 8B, a 8C e a 8D

- **8B:** as buscas (as lupas dos quadros `1e`/`1f`, `3c`, `4c`, `4d` e `4e`), a desenhar com o usuário no início da 8B.
- **8C:** a lista do desenho da Fase 8 (carregamento, erro e vazio em todas as telas; fonte ampliada; leitor de tela; contraste; ondulação do toque; toque duplo); as decisões visuais em aberto da 5B e da 6A — que agora incluem o contorno vermelho e o botão compacto do "Sair da conta" no tablet (ver "Ajustes"); os diálogos de confirmação usam a fonte padrão do Material, e não a Inter, em todo o app.
- **8D:** as pendências "8" dos planos 3 a 7B que não entraram aqui; o aparelho compartilhado (a fila e os rascunhos de quem saiu ficam no aparelho até o dono entrar de novo — agora de propósito, pela decisão 4); o perfil salvo de outro usuário, se o app morrer entre o login e a gravação do perfil depois de uma falha da keystore (ver "Ajustes"); e quais pendências de backend e de web entram.
- **Distribuição (fora da Fase 8):** a keystore própria do release.

### Observações das revisões da execução (24/10/2026)

**8C (telas):**
- O vão entre o rótulo e o valor das linhas do Perfil é 12; o canvas desenha 14 no celular (`2i`) e 16 no tablet (`4k`/`4v`). Só aparece com rótulo longo. Decidir com o usuário, junto com as outras decisões visuais.
- No tablet, o "Sair da conta" compacto encolhe para a largura do indicador enquanto sai (até 5 s), e o nome e o e-mail se realinham.
- Dois toques rápidos no "Sair da conta" podem empilhar dois diálogos (o botão continua ativo enquanto as avaliações iniciadas são contadas).

**8D (borda, limpeza e testes):**
- Renovação de token: os ramos que encerram a sessão (4xx, token nulo, resposta sem token) não conferem se a sessão ainda é a mesma — um 4xx com o token antigo depois de um login novo derruba a sessão nova; falta o teste do caso "outro login" em `api_client_test.dart`.
- Logout que lança no meio (keystore ou banco) deixa o estado pela metade e mostra "Não foi possível sair".
- Troca de servidor: se o `clearAll` falhar, a abertura vai ao login e a fila antiga fica (e iria ao servidor novo).
- Depois do "Limpar cache local", a fila espera o catálogo; quando ele volta, o envio só sai no próximo gatilho (até 10 min); a aba Sincronizar não diz por que a fila não saiu; a espera vale para o lote inteiro.
- Envio da fila: falta o teste do 401 com o usuário trocado durante o POST; o nome do teste "401 no envio (sessão encerrada)" engana; o comentário do `onError` é impreciso; o recuo dos dois `listen` difere.
- Perfil: `countDrafts` carrega as linhas em vez de `COUNT(*)`; `_isClearing` volta a `false` antes de medir de novo; o `catch` de `countStartedDrafts` não tem teste nem log; `sizeLabel` perto dos limites ("1024 KB"); faltam testes de `mounted` falso, linha com o motivo de sem rede, e-mail longo, `expand: false` isolado; o teste do giro confere o `State` acima da moldura; os ternários do tablet em `_ProfileRow`.
- Testes que conferem pouco: o de dispose da Home (olha `isRefreshing`); o do timeout do logout não confere a limpeza do cache; `LogoCache` sem teste automático.
- Ruído na saída da suíte: "Catálogo não atualizado (sem rede)" e os `debugPrint` novos do envio.
- `README.md` do app: a seção do backend local ainda diz "Em desenvolvimento, o app fala com o backend que roda no PC".
