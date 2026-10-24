# Fase 8 — Acabamento, QA final e produção (desenho)

Conversa de 24/10/2026. Base: `brainstorm-implementacao-mobile.md` (Fase 8), as
seções "Pendências" dos planos das Fases 2 a 7B em `apps/mobile/docs/superpowers/plans/`,
`apps/mobile/docs/fase-0-auditoria.md`, o canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html`
(1.10 Perfil: quadros `2i` na linha 1387, `4k` na 2589 e `4v` na 2637; dados `profileRows`
na 3805) e o código atual de `apps/mobile/simtc/`.

## Intenção

O app **ainda não vai para os consultores**. Depois da Fase 8 o usuário vai refinar
pendências do painel web (e do app, se precisar). A fase fecha o app: a tela de Perfil
com o "Sair", as buscas, o acabamento visual e de acessibilidade, os defeitos de borda
anotados ao longo das fases, a limpeza de código e os testes que faltam. E passa a
testar **contra a API de produção**, que é um ambiente de teste.

## Fatos levantados (24/10/2026)

- **Produção** é uma VPS da Hostinger com EasyPanel. Backend (`Dockerfile.backend`) e
  web (`Dockerfile.web`) são publicados **sozinhos quando o código chega na
  `feat/frontend-backend-integration`** (a branch configurada nos dois serviços do
  EasyPanel, confirmada pelo usuário). É a única branch no GitHub e a padrão do
  repositório; está parada em 12/09/2026 (`1c377a3`), igual à local.
- A `main` existe **só neste computador** (parada em 01/08/2026, `f108e34`, sem os
  Dockerfiles) e fica de lado. Os workflows do GitHub (`.github/workflows/backend.yml` →
  Railway, `web.yml` → Vercel) só disparam na `main`: não rodam e não são o caminho real.
- O **banco de produção é de teste** e **já tem dados de teste** (contas e sessões).
- A produção responde (`POST /api/auth/check-email` → 201), mas não tem as rotas das
  Fases 6A/6B (`POST /api/training-sessions/:id/participants/lookup` e
  `POST /api/practical-assessments/unassign` → 404).
- A `feat/mobile-app` parte da `feat/frontend-backend-integration` (o merge é direto) e
  traz as migrações que a produção ainda não tem (até
  `20261006120000_rename_necessita_reavaliacao_to_nao_recomendado`). Ela **nunca foi
  enviada ao GitHub** (223 commits só locais).
- O app já sai com o id definitivo (`br.com.simtc.app`, Fase 1). O endereço de
  produção `https://api.simtc.com.br/api` foi confirmado na Fase 1. O app lê o endereço
  por `--dart-define=API_BASE_URL` (`lib/config/app_config.dart`); hoje o padrão é
  `http://localhost:3001/api`.
- O release é assinado com a chave de debug (`android/app/build.gradle.kts`).
- **Já feito nesta conversa** (commit `a90f6b5`): o contêiner do backend roda
  `npx prisma migrate deploy && exec node dist/src/main`. O `migrate deploy` usa
  `DIRECT_URL` (`apps/backend/prisma.config.ts`).
- O logout já existe sem tela: `AuthRepository.logout()` chama `POST /auth/logout`,
  limpa os tokens (`AuthSession.clear`) e o cache de sessões
  (`AppDatabase.clearSessionsCache`). A fila e os rascunhos (`LocalAssessments`) têm
  `ownerUserId` e sobrevivem à troca de usuário; o `AssessmentSyncService` segue a fila
  de quem entrou (`_onAuthChanged` → `_follow`).
- O consultor não tem empresa no backend (`Consultant`/`User` em `schema.prisma`), e
  `GET /auth/me` devolve só `{ id, name, email, role }`.

## Decisões do usuário (24/10/2026)

1. **Escopo:** entram as quatro frentes, além do Perfil e da produção: telas e
   acessibilidade, buscas, defeitos de borda, limpeza e testes.
2. **Dividir em 8A, 8B, 8C e 8D** (abaixo), nessa ordem, cada uma com plano, execução
   e validação próprios. A seguinte só é planejada depois da validação da anterior.
3. **Testar contra a produção.** O app passa a apontar para
   `https://api.simtc.com.br/api` **por padrão, inclusive no `flutter run`**. O backend
   local continua possível por `--dart-define=API_BASE_URL=http://localhost:3001/api`
   (o usuário pode pedir para voltar a ele às vezes).
4. **Um app só no aparelho** (dev e produção não ficam lado a lado).
5. **Trocar de servidor apaga tudo o que está no aparelho.** O app guarda o endereço
   da API com que falou da última vez. Ao abrir com outro endereço, apaga sessões,
   participantes, consultores, catálogo, fila, rascunhos, logos baixados e o login, e
   vai para a tela Entrar.
6. **O contêiner roda `prisma migrate deploy` ao subir** (feito, `a90f6b5`).
7. **"Sair da conta" com fila ou rascunho: avisa e deixa sair.** A confirmação diz
   quantas avaliações estão na fila (e se há rascunho iniciado) e que elas ficam
   guardadas no aparelho e são enviadas quando a pessoa entrar de novo. Só as sessões
   baixadas são apagadas. Sem fila, a confirmação é a simples.
8. **A linha "Empresa" do Perfil sai** (divergência do canvas).
9. **"Limpar cache local" entra na 8A**, com o espaço ocupado.
10. **A tela de Perfil como descrita em "8A" foi aprovada** em chat.
11. **A publicação vai para a `feat/frontend-backend-integration`** (a branch do
    EasyPanel), com os dados de teste que já estão na produção.
12. **A limpeza da troca de servidor (decisão 5) apaga a fila sem aviso**: confirmado
    como intencional (o revisor perguntou; a escolha do usuário foi "apagar tudo").

## Escolhas minhas (a conferir pelo usuário na leitura)

- **Versão do app** lida pelo pacote `package_info_plus` (dependência nova), no
  formato `1.0.0 (1)` (`version` e `buildNumber` do `pubspec.yaml`).
- **"Perfil de acesso"** mostra "Consultor" ou "Administrador". É o selo "Admin" que o
  brainstorm pedia.
- **"Última sincronização"** é o mesmo momento da aba Sincronizar (o último envio de
  avaliação aceito, `AssessmentSyncService.lastSyncedAt`), mas só o horário à direita
  ("hoje 07:12", sem repetir o rótulo da linha), e "Nenhum envio" quando nunca houve.
- **"Sair" sem rede** limpa só o lado do aparelho: o refresh token continua válido no
  servidor até vencer. Aceito (ambiente de teste); nada de revogação pendente.
- **"Limpar cache local" fica desativado sem rede**: o checklist precisa do catálogo, e
  a Home precisa de rede para baixar tudo de novo.
- **A confirmação do "Sair" sem rede** avisa que só dá para entrar de novo quando houver
  conexão (o login exige rede).
- **Texto do rodapé do Perfil** (divergência do canvas, porque o original contradiz a
  decisão 7): "Sair apaga as sessões baixadas neste aparelho. As avaliações na fila ficam
  guardadas e são enviadas quando você entrar de novo."
- **Assinatura do release continua com a chave de debug** enquanto o app não for
  distribuído. Com um app só (decisão 4), assinar o release com outra chave obrigaria
  desinstalar o app (e perder a fila) a cada troca entre `flutter run` e APK. A keystore
  própria fica para a distribuição.
- **Os defeitos do envio que os planos 5A/5B mandaram "tratar junto com a troca de
  usuário"** entram na 8A (lista abaixo).

## 8A — Produção e Perfil

### Publicação em produção

Ordem: primeiro a publicação, depois o código do app, para o resto da fase já ser
testado contra a produção. **Cada passo difícil de desfazer (envio, PR, merge) só com o
OK do usuário na hora.**

1. O usuário confere no EasyPanel, no serviço do backend: `DIRECT_URL` definida;
   Dockerfile `Dockerfile.backend`; nenhum comando de partida próprio (passaria por cima
   do `CMD`). No serviço do web: a variável do endereço da API usada no build
   (`NEXT_PUBLIC_API_URL`) apontando para a produção.
2. Enviar a `feat/mobile-app` ao GitHub.
3. Abrir o PR da `feat/mobile-app` para a `feat/frontend-backend-integration`.
4. Merge → o EasyPanel publica backend (com as migrações) e web.
5. Conferir: a rota de consulta de CPF passa de 404 para 401; o login do app e do web
   funciona contra a produção. Se o `migrate deploy` recusar porque o banco não tem
   histórico de migrações (P3005, banco criado por `db push`), **parar e avisar o
   usuário** antes de qualquer ajuste no banco.
6. Nunca rodar o `seed` contra a produção sem pedido do usuário: os dados de teste já
   estão lá.
7. Depois de cada parte seguinte (8B a 8D) que mexer no backend ou no web, publicar do
   mesmo jeito (PR para a `feat/frontend-backend-integration`, com OK).

### Endereço da API

- `AppConfig.apiBaseUrl` passa a ter `https://api.simtc.com.br/api` como padrão. O
  `README.md` do app troca a tabela de ambientes: produção é o padrão; o backend local
  fica pelo `--dart-define` (com o `adb reverse` de sempre).
- **Troca de servidor (decisão 5):** na abertura, antes de restaurar a sessão, o app
  compara o endereço atual com o guardado. Diferente (ou nenhum guardado com dados já no
  aparelho), apaga tudo e vai para o Entrar. Na primeira abertura depois desta fase, os
  aparelhos de teste que falavam com o backend local vão passar por essa limpeza:
  esperado.

### Tela 1.10 Perfil (celular `2i`, tablet `4k` paisagem e `4v` retrato)

- Cabeçalho "Perfil". Nome e e-mail de quem entrou (também sem rede, do perfil guardado).
- Linhas, na ordem: **Perfil de acesso**, **Última sincronização**, **Limpar cache
  local** (com o espaço ocupado), **Versão do app**. Ícones, medidas e cores do canvas;
  a linha "Empresa" sai.
- **Limpar cache local:** pede confirmação; apaga sessões, participantes, consultores,
  catálogo e logos baixados; **nunca** a fila nem os rascunhos; desativado sem rede. O
  valor da linha é o espaço que o app ocupa com o que será apagado.
- **Sair da conta:** sempre pede confirmação (variantes: simples; com N na fila e/ou
  rascunho iniciado; sem rede). Depois de sair, tela Entrar. No celular o botão fica
  abaixo das linhas (`2i`); no tablet, ao lado do nome (`4k`/`4v`).
- Rodapé com o texto novo (ver "Escolhas minhas").
- A aba Perfil da navbar (celular, pílula e barra lateral do tablet) passa a abrir a
  tela; sai o aviso "Disponível em breve." (`app_nav_bar.dart`). O enum `AppTab` ganha
  o perfil.

### O que a troca de usuário destrava (pendências herdadas)

- Item de roteiro da Fase 2: sair e entrar com outro consultor **não** mostra a agenda
  do anterior, nem com rede nem sem.
- `SessionsListViewModel` chama `notifyListeners` depois de `await` sem guarda de dispose
  (Fase 3): aplicar a mesma guarda da `SessionDetailViewModel`.
- No `AssessmentSyncService` (planos 5A e 5B): troca de usuário com envio no ar (dois
  `_follow` ao mesmo tempo, sem conferir o usuário de novo antes do POST); erro ao entrar
  (`claimUnowned` ou o stream da fila) sem tratamento, com a aba dizendo "Tudo o que você
  confirmou já chegou ao servidor"; `syncNow` devolvendo o envio no ar antes da rodada
  repetida; `retryDelays` vazio sem `assert`; todo 401 deixando os itens "Na fila" até o
  próximo gatilho.
- `AuthSession.start()`: uma falha da keystore no `deleteUser` derruba o login (5A).

### Validação da 8A

Celular Android físico **contra a API de produção**; tablet no emulador (exceção da
Fase 7). Roteiro: entrar como CONSULTANT e como ADMIN; Perfil nas três larguras; sair
com e sem fila, com e sem rede; entrar com outro consultor; limpar cache; trocar para o
backend local e voltar (confere a limpeza da decisão 5).

## 8B — Buscas

As lupas do canvas: Home (1.3), lista de participantes do detalhe (1.4) e Consultores
da sessão (1.13, quadro `3c`). Busca **local**, nos dados já baixados (não existe
endpoint de busca). Comportamento (campos buscados, onde o campo abre, como convive com
os chips e as âncoras da Home) a desenhar com o usuário no início da 8B.

## 8C — Telas e acessibilidade

- Carregamento (skeleton), erro e lista vazia em todas as telas, inclusive as janelas de
  admin; estados de erro do checklist (falha de escrita local em `init`, `toggleNote` e
  "Iniciar avaliação"; o "salvo" estático do cabeçalho).
- Fonte do sistema ampliada sem quebrar (cabeçalho fixo da 1.4; o estouro restante da
  1.11 em 640dp com teclado e 1,6x).
- Leitor de tela (TalkBack): `Semantics(selected:)` nos B/PM/M; campo de data da 1.12;
  cartões de tipo da 1.11; título das janelas de admin.
- Contraste do item ativo da navbar (2,3:1, Fase 1); alvos de 48dp.
- Ondulação do toque que falta (cards, linhas de participante, cabeçalho de categoria,
  B/PM/M, cartões de tipo); dois toques rápidos que abrem duas telas iguais.
- As decisões visuais em aberto (2 a 6 da 5B; 5 a 8 da 6A; o canto 12 do "Atribuir a
  mim"), decididas com o usuário no início da 8C.

## 8D — Defeitos de borda, limpeza, testes e QA final

- O restante das pendências "8" dos planos 3 a 7B (envio, admin, consulta de CPF,
  corridas do cache, rascunhos presos, aparelho compartilhado etc.).
- Limpeza de código e as lacunas de teste anotadas pelas revisões.
- Quais pendências de **backend** e de **web** registradas nos planos entram: a decidir
  com o usuário no início da 8D.
- QA final: os dois perfis (CONSULTANT e ADMIN), celular e tablet, incluindo dois
  consultores no mesmo participante e queda de rede no meio do envio.

## Fora da Fase 8

Keystore própria e distribuição do app; envio com o app fechado (WorkManager), salvo se
o usuário trouxer de volta na 8D; atualizar o canvas no Claude Design.

## Restrições que seguem valendo

- Canvas é a fonte de medidas, fielmente; toda divergência é levada ao usuário antes do
  plano (o bloco "Fundações" do canvas é desconsiderado).
- Cada plano tem "Validação prévia" numa cópia descartável (um commit por task, mutação
  por JSON, desenho com as fontes de verdade em 412×915, 360×640 com fonte ampliada,
  1280×800, 800×1280 e uma largura entre 840 e 1000).
- Execução por subagentes: implementadores em haiku; revisões em sonnet ou opus. Todo
  despacho proíbe `git restore/checkout/stash/reset/clean`, e o `git status` inteiro é
  comparado com a linha de base depois de cada subagente.
- Commits em português, `tipo(escopo)`, uma linha, sem `Co-Authored-By`.

## Deixado para quem planeja

- Onde guardar o endereço da API (armazenamento seguro ou banco) e como apagar "tudo"
  (uma função única no `AppDatabase` mais tokens, perfil e cache de logos).
- Como medir o espaço do "Limpar cache local" (arquivo do banco, cache do
  `DefaultCacheManager`) de forma que o número corresponda ao que será apagado.
- A rota do Perfil no `go_router` e como ela entra no lado a lado do tablet.
- O passo a passo do roteiro de aceite da 8A.
