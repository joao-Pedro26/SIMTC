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
endpoint de busca).

### Desenho da 8B (conversa de 24/10/2026, depois da validação da 8A)

O canvas só desenha as lupas (quadros `2c` linha 774, `1e`/`1f` linhas 904/994, `3c`
linha 625; no tablet, `4c`, `4d`, `4e`, `4n`, `4y`) — nenhum quadro mostra o campo aberto
nem o resultado. O comportamento abaixo foi decidido em chat, com desenhos no navegador.

**Decisões do usuário:**

1. **O que cada lupa busca:**
   - **Detalhe da sessão:** participantes, por **nome ou CPF**.
   - **Home:** sessões, pela **empresa**.
   - **Consultores da sessão (ADMIN):** consultores, pelo **nome**.
2. **Como a busca abre (o "jeito A", como o canvas desenha):** tocar na lupa troca a faixa
   onde ela mora por um campo de busca, com o teclado aberto; a lista filtra enquanto se
   digita; o X fecha a busca e a tela volta ao que era.
   - **Detalhe:** o campo toma o lugar da barra dos filtros (chips). A busca procura em
     **todos** os participantes, ignorando o filtro que estava marcado; ao fechar, o filtro
     de antes volta. Embaixo da lista, "N de M participantes".
   - **Home:** o campo toma o lugar do título e dos chips. As três seções (Hoje, Esta
     semana, Concluídas) continuam, só com as sessões da empresa buscada.
   - **Consultores:** o campo abre embaixo do cabeçalho e filtra as duas listas (quem está
     na sessão e quem pode entrar).
3. **CPF: comparar os primeiros dígitos digitados com os 6 que o aparelho já guarda** desde
   a Fase 3 (`maskCpf`: `123.456.***-**`). Com 6 dígitos ou mais digitados (inclusive o CPF
   inteiro, que o participante dita), compara os 6 primeiros; com menos, compara o que foi
   digitado com o começo do CPF guardado. **Nada novo é guardado** e o banco não muda.
   Numa sessão, os 6 primeiros praticamente identificam a pessoa; no caso raro de dois
   participantes com o mesmo começo, os dois aparecem e o nome desempata. (Uma primeira
   proposta, guardar uma "impressão" do CPF inteiro, foi descartada: somada aos 6 dígitos
   guardados, ela deixaria só ~1.000 combinações — seria o mesmo que guardar o CPF.)
4. **As regras gerais abaixo (marcadas "minhas") foram mostradas no navegador e aceitas.**

**Escolhas minhas (aceitas pelo usuário, sem objeção):**

- Não diferencia maiúscula nem acento ("jose" acha "José"); o trecho pode estar em qualquer
  parte do nome ou da empresa ("ana" acha "Mariana").
- No CPF, só os dígitos contam (pontos e traço são ignorados). O campo aceita o CPF com ou
  sem máscara. Um texto que tem letras é busca por nome; um texto só de dígitos (e
  pontuação de CPF) é busca por CPF.
- Sem resultado: "Nenhum participante encontrado para “xyz”." (e "Nenhuma sessão…",
  "Nenhum consultor…" nas outras).
- Funciona sem rede, sobre o que já está no aparelho.
- No tablet vale o mesmo jeito em cada painel: a lupa da lista da esquerda (Home), a da
  barra de filtros do detalhe e a do cabeçalho da janela de Consultores.

**Escolhas minhas depois da revisão do desenho (a conferir na leitura):**

- **Cabeçalho da Home com a busca aberta:** a linha do logo e do indicador de sincronização
  continua em cima (o indicador é a entrada da aba Sincronizar e mostra a fila); o campo
  toma o lugar da saudação, do título e dos chips; o X fica dentro do campo. O mesmo no
  painel da lista do tablet.
- **Vazios durante a busca:** a seção (Home) ou a lista (Consultores) sem resultado some,
  com o título; se tudo ficar vazio, aparece a frase "Nenhum… encontrado para “xyz”.". Em
  Consultores, os avisos próprios da lista de disponíveis (sem conexão, todos já na sessão)
  continuam valendo e vencem a busca.
- **Quanto a busca dura:** o texto vive na ViewModel da tela — continua ao abrir um
  resultado e voltar, e ao girar o tablet; trocar de aba recria a tela e fecha a busca.

**Fora da 8B:** buscar participante em todas as sessões a partir da Home; buscar por
curso ou cidade; busca no servidor.

**Deixado para quem planeja:** a aparência do campo (sem quadro no canvas: usar os tokens do Design System e levar os
desenhos ao usuário na revisão do plano), o comportamento do botão voltar do Android com a
busca aberta, e o que acontece com as âncoras/chips da Home e a paginação de exibição
("ver mais") durante a busca.

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

### Desenho da 8C (26/10/2026, depois da validação da 8B)

Nas validações até aqui, nada incomodou o usuário em especial. Ele **deixou as decisões
da 8C para o meu bom senso** ("pode analisar essas pendências pelo bom senso"). Por isso,
**tudo abaixo é escolha minha**, e o usuário confere na leitura. Isso vale também para as
divergências do canvas, que ficam juntas em "Divergências do canvas", no fim. O
levantamento juntou as pendências marcadas "8" nos planos 2 a 7B e as observações da
8A e da 8B. As que mudam regra de tela ou de negócio ficam para a 8D:

- as decisões em aberto 1 a 4 da 6A;
- os textos da consulta de CPF;
- a tela travada que ainda pergunta se descarta.

Ficam também para a 8D a limpeza de código e as lacunas de teste.

**Intenção:** o app fica confortável para quem enxerga pouco, usa a fonte grande do
Android ou o TalkBack. Ele também não pode ter toques "mortos" nem cores fora do canvas.
Nada muda de regra, nada muda no backend, e a 8C não tem publicação.

#### 1. Cores e contraste

1. **Contorno vermelho:** o `dangerBorder` passa de `#FCA5A5` para **`#E9A2A2`**. É a cor
   que o canvas usa em todo lugar: 11 vezes, sem nenhum `#FCA5A5`. Muda o "Cancelar
   sessão", o "Remover da sessão", o "Sair da conta", a pílula e os chips de "Não
   recomendado" e todo o resto que usa o token. Isso fecha a decisão 5 da 6A e o
   contorno do "Sair" da 8A.
2. **"Somente teórica":** entra o token **`mauveInk` `#6B4A7A`** para o ícone e o texto
   do chip e do cartão de tipo da 1.11. É a cor do canvas, que aparece 9 vezes. O `mauve`
   `#9B80A8` continua como tom de marca do tema. Fecha a outra metade da decisão 5 da 6A.
3. **Navbar do celular:** hoje o item ativo, `#38BEC8` sobre o próprio tom a 16%, dá
   cerca de 2,3:1. O inativo, `#94A3B8`, dá cerca de 2,5:1. A navbar do celular passa a
   usar **os tons que os quadros do tablet já usam**: ativo em `primaryDark` sobre
   `primarySurface`, com cerca de 5:1, e inativo em `text3`. É a pendência de contraste
   da Fase 1.
4. **Texto informativo pequeno em cinza-claro:** o `#94A3B8` sobre o branco dá cerca de
   2,6:1. Entra o token **`textSubtle` `#64748B`**, com cerca de 4,8:1. Ele substitui o
   `textMuted` onde o cinza-claro é texto que se lê:
   - o "opcional" dos campos (decisão 6 da 6A);
   - o "N itens" da categoria fechada;
   - o número do item da infração;
   - o "N infrações" do Resultado no tablet;
   - o "SIM Treinamentos" ao lado de "Disponíveis na equipe".

   O `textMuted` continua no exemplo dos campos, no que está desativado e nos ícones
   decorativos.

#### 2. Toque

1. **Ondulação do toque** onde ela não aparece, porque o fundo pinta por cima da
   animação:
   - o card da sessão;
   - a linha do participante;
   - o cabeçalho da categoria aberta;
   - os botões B/PM/M;
   - os cartões de tipo da 1.11.

   Quem planeja procura os outros casos do mesmo padrão: um `InkWell` com um
   `Container` colorido dentro.
2. **Dois toques rápidos** em algo que abre uma tela abrem uma tela só. O segundo toque
   é ignorado enquanto a primeira tela está abrindo. Vale para:
   - os cards da Home;
   - as linhas de participante;
   - os botões e ícones que abrem tela (Iniciar, Conferir, Resultado, ações de admin,
     Consultores);
   - o "Sair da conta", que hoje empilha dois diálogos. Ele fica desativado enquanto
     as avaliações iniciadas são contadas.
3. **Alvos de toque de 48dp** e rótulo em tudo o que se toca. As telas principais ganham
   os testes de diretriz do Flutter: `androidTapTargetGuideline`,
   `labeledTapTargetGuideline` e `textContrastGuideline`. Assim nada novo escapa. A lupa
   do detalhe continua com 48 de alvo, mesmo com o quadro desenhando 36 (pendência da
   8B).

#### 3. Fonte do sistema ampliada (o Android vai até 2×)

1. **Cabeçalho do detalhe (1.4):** continua fixo, como no canvas. Com a fonte do sistema
   em **1,3× ou mais**, ele rola junto com a lista e sai de cena ao rolar. Com fonte
   grande e observações longas, ele ocupava a maior parte da tela. A regra vale também
   no painel do detalhe do tablet (escolha minha, pelo mesmo motivo).
2. **1.11 com o teclado aberto:** sobrou um estouro em 640dp de altura, sem conexão e
   com fonte em 1,6×. Quando o rodapé não cabe, ele entra na rolagem. A regra vale para
   a 1.11 e para a 1.12.
3. **Pílula "Não recomendado"** do Resultado e da 1.6 (decisão 4 da 5B): quando não cabe
   ao lado do %, ela desce para baixo dele, sem quebrar o texto.
4. **"Tentar novamente" e "Descartar"** da aba Sincronizar (decisão 3 da 5B): ficam lado
   a lado quando os dois cabem com o texto numa linha. Se não couberem, ficam um embaixo
   do outro, cada um na largura inteira.
5. **Meta:** nenhum estouro (as faixas amarelas) em nenhuma tela, em 360×640 com fonte
   em 1,3× e em 2×. Vale também no tablet em 1,3×.

#### 4. Leitor de tela (TalkBack)

1. **B/PM/M:** cada botão diz a própria letra e se está **selecionado**. O rótulo
   continua o que se vê ("B", "PM", "M"); não invento nome por extenso.
2. **Data da 1.12:** é um nó só, lido como "Data do treinamento, 12/10/2026, botão",
   e não três soltos.
3. **Cartões de tipo da 1.11:** dizem se estão selecionados e se estão desativados.
4. **Janelas de admin no tablet:** o título é anunciado ao abrir. O fundo escurecido
   continua com o rótulo "Fechar".
5. **Buscas (8B):** a contagem "N de M participantes" é anunciada quando muda, e a
   frase de nenhum resultado também. O campo tem rótulo, e não só o exemplo.
6. **Cabeçalhos de seção** (Hoje, Próximas, Concluídas, as seções de Consultores e os
   títulos de tela) são marcados como cabeçalho, para o TalkBack navegar por eles.

#### 5. Carregamento, erro e vazio

1. **Regra:** toda tela que carrega dados mostra o skeleton enquanto carrega. Se a carga
   falha, mostra o erro com "Tentar novamente". Lista vazia mostra uma frase própria. As
   janelas de admin do tablet também seguem a regra. Quem planeja confere tela por tela
   e lista as que faltam. Já se sabe que a 1.6 não tem estado vazio próprio (pendência
   da 5A).
2. **Checklist**, hoje calado diante de uma falha de escrita no aparelho:
   - **ao abrir** (`init`): no lugar das categorias, "Não foi possível abrir a avaliação
     neste aparelho.", com "Tentar novamente";
   - **ao marcar uma nota** (`toggleNote`): aviso passageiro "Não foi possível salvar a
     nota. Tente de novo.". O botão continua mostrando só o que foi gravado, como já é
     hoje;
   - **no "Iniciar avaliação"**: aviso passageiro "Não foi possível iniciar a avaliação.
     Tente de novo.";
   - **o "salvo" do cabeçalho** passa a refletir a falha. Depois de uma escrita que
     falhou, ele mostra **"Não salvo"** em vermelho (`dangerInk`, com o ícone de alerta),
     até a próxima escrita que der certo.
3. **"Desatribuir participante" (decisão 2 da 5B):** enquanto o pedido está no ar, o ⋮
   do checklist vira o indicador de carregamento pequeno que o app já usa, e o TalkBack
   lê "Desatribuindo…". Hoje nada mostra a espera, que dura de 15 a 35 s com a rede
   lenta.
4. **Descarte que não apagou (decisão 6 da 5B):** quando a avaliação deixou de estar
   recusada, porque foi reenviada e aceita com o diálogo aberto, o aviso passa a ser
   "Esta avaliação já foi aceita pelo servidor; não há o que descartar.".

#### 6. Tipografia e medidas herdadas

1. **Diálogos de confirmação em Inter:** hoje usam a fonte padrão do Material. O título
   e o texto passam aos estilos do app, pelo tema, em todos os diálogos de uma vez.
2. **Pesos que não aparecem:** três `copyWith(fontWeight: …)` não mudam o peso, porque
   a Inter é variável e o peso vem do `fontVariations`. Estão no card da sessão, na Home
   e na linha do progresso do detalhe. Viram estilos com nome no `AppTypography`, como
   o próprio arquivo manda.
3. **Medidas alinhadas ao canvas** (decisão 8 da 6A):
   - o texto das observações da 1.12 em 15/1,45;
   - o recuo vertical do cabeçalho de contexto em 14;
   - na 1.11, o nome da empresa em 14 com vão de 2;
   - o ícone de adicionar do detalhe com 20.

   O widget compartilhado ganha os parâmetros que precisar, e cada tela passa os do
   próprio quadro.
4. **"Atribuir a mim":** canto 10, como no quadro e nos outros botões compactos (hoje
   12).
5. **Perfil:** o vão entre o rótulo e o valor passa a 14 no celular (`2i`) e 16 no
   tablet (`4k`/`4v`), como no canvas (hoje 12). No tablet, o "Sair da conta" compacto
   mantém a largura enquanto sai, sem encolher para a do indicador.

#### 7. Ficam como estão (decisão minha)

- **A setinha** nas linhas "Na fila", "Erro no envio" e "Enviada" (decisão 5 da 5B):
  fica. As linhas abrem o Resultado, e a seta diz isso.
- **O título "Participantes"** sem conexão (decisão 7 da 6A): não apaga. Só o ícone
  de adicionar apaga, porque é ele que não funciona. O título não é ação.
- **O campo de busca da 8B,** que não tem quadro: fica como está.

#### Divergências do canvas (todas escolha minha, a conferir)

- **Navbar do celular** nos tons do tablet (1.3).
- **`textSubtle`** no texto informativo pequeno (1.4).
- **Cabeçalho do detalhe** rolando com fonte em 1,3× ou mais (3.1).
- **Pílula "Não recomendado"** descendo para baixo do % e **botões da fila** empilhados
  quando não cabem (3.3 e 3.4).
- **"Não salvo"** no cabeçalho do checklist e o indicador no lugar do ⋮ (5.2 e 5.3).
- **A lupa do detalhe** com 48 de alvo (2.3).

Já o contorno `#E9A2A2`, o `mauveInk`, as medidas da decisão 8 da 6A, o canto 10 e os
vãos do Perfil **aproximam** o app do canvas.

#### Validação da 8C

No **aparelho físico** e no **emulador do tablet**, contra a produção:

- a fonte do sistema no máximo e em 1,3×;
- o TalkBack ligado, percorrendo Home, detalhe, checklist, Resultado, Sincronizar,
  Perfil e as telas de admin;
- toques rápidos repetidos nos cards e nas linhas;
- a conferência das cores novas.

A validação prévia do plano desenha as telas com as fontes de verdade em 412×915,
360×640 com 1,3× e 2×, 1280×800 e 800×1280.

#### Deixado para quem planeja

- A lista exata de telas sem carregamento, erro ou vazio, e o texto de cada vazio que
  faltar, no tom dos que já existem.
- Como ignorar o segundo toque: um auxiliar único usado por todos, ou uma guarda em
  cada tela.
- Onde ligar os testes de diretriz. Antes de decidir os ajustes, quem planeja roda
  esses testes nas telas antigas e lista o que eles acusarem. O que for divergência do
  canvas volta ao usuário antes do plano.
- O limite de 1,3× é um ponto de partida. Se o desenho com as fontes de verdade mostrar
  outro ponto melhor, quem planeja propõe.

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
