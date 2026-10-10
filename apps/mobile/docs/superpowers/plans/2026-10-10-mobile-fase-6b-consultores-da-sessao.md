# App Mobile SIMTC — Fase 6B: Consultores da sessão, desatribuir pelo ADMIN e avaliação que volta — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Um ADMIN passa a ver e mudar, no celular, os consultores de uma sessão (tela 1.13) e a desatribuir um participante que está com outro consultor. Tirar um consultor da sessão libera quem estava em avaliação com ele — no backend, valendo também para o painel web —, e o servidor passa a recusar a avaliação de quem não está mais com o participante. No aparelho, a avaliação que ficou pela metade continua de onde parou quando o participante volta, e quatro comportamentos das telas da 6A são acertados.

**Architecture:** No backend, duas rotas novas de consultor da sessão (um consultor por chamada, só ADMIN) e duas regras novas em rotas que já existem: o `unassign` aceita o ADMIN, e o `sync` confere a atribuição. No app, uma tabela nova no cache guarda os consultores de cada sessão, gravados junto com o detalhe; um repositório novo fala com as rotas; e uma tela cheia nova, com rota e ViewModel próprios, é aberta por um ícone que só o ADMIN vê no detalhe. O resto são mudanças em telas que já existem: o detalhe (contagem de consultores e o ⋮ da linha), o checklist (a avaliação parada), a aba Sincronizar (o motivo da recusa), a 1.11 e a 1.12. Depois de cada mudança aceita — e de cada recusa do servidor —, a sessão é baixada de novo, e as telas leem do cache.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · drift 2.31.0 (**o esquema vai de v4 para v5**: uma tabela nova, com migração que preserva os dados) · dio · mocktail (testes) · backend NestJS + Prisma, testes com jest (duas rotas novas; **sem migração de banco**). Nenhuma dependência nova, no app nem no backend.

**Spec:** `brainstorm-implementacao-mobile.md` → "Fase 6 — Ações administrativas inline" (dividida em 6A e 6B em 06/10/2026; esta é a 6B) e `brainstorm-app-mobile.md` (tela 1.4.3); canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html`, quadros `3c` "1.13 Consultores da sessão" (linhas 618–686, com os dados de exemplo nas linhas 3813–3826) e `1f` "1.4 Detalhe da Sessão · variante ADMIN" (951–1048); contratos no backend em `apps/backend/src/training-sessions/`, `apps/backend/src/practical-assessments/` e `apps/backend/src/consultants/`; as pendências "6B" e as "Decisões em aberto" 1 a 4 do plano da 6A (`2026-10-07-mobile-fase-6a-acoes-de-admin.md`); e as pendências marcadas "5" e "6" em `apps/mobile/docs/fase-0-auditoria.md`. O desenho aprovado em 09/10/2026 está em "Decisões tomadas com o usuário" — a trilha mobile não usa doc de spec separado, o plano é o documento.

**Validação prévia:** todo o código deste plano foi escrito e rodado numa cópia descartável do repositório (app e backend) antes de o plano ser fechado, uma task por commit, e depois as tasks foram **reencenadas em ordem** numa segunda cópia limpa: em cada task, os testes falharam antes da implementação pelo motivo descrito no passo "Esperado", e cada checkpoint bateu o número de testes — no app, **698 → 712 → 729 → 743 → 796 → 820 → 831 → 852 → 886 → 892 → 906 → 920**, com `flutter analyze` sem issues em todos; no backend, de `12 failed, 72 passed, 84 total` para `12 failed, 93 passed, 105 total`, `12 failed, 97 passed, 109 total` e `12 failed, 108 passed, 120 total` (as 12 falhas são as antigas de sempre), com o `tsc --noEmit` limpo. Os blocos de código foram gerados da primeira cópia por um script que confere cada "substituir / por" contra o estado deixado pela task anterior, e um segundo script aplicou o plano inteiro, como um executor faria — achando os blocos pelos títulos dos passos —, e conferiu que a árvore de arquivos de cada task ficou idêntica à do commit correspondente: o que está aqui é, byte a byte, o código que passou. Duas conferências a mais do que na 6A, pelas lições de lá: **cada regra e cada medida foi conferida por mutação** — o trecho é trocado, e algum teste tem de falhar: foram 299 mutações (32 no backend e 267 no app), todas acusadas por algum teste, menos duas que não mudavam o comportamento; as que sobreviveram na primeira passada viraram teste novo antes de a task ser fechada — e as três telas com desenho novo (Consultores, detalhe do ADMIN e checklist) foram **desenhadas com as fontes de verdade** em 412×915 e em 360×640 com a fonte ampliada, e conferidas a olho contra as medidas tiradas do HTML do canvas (o que difere está em "Ajustes"). (O passo da auditoria, na Task 3, é só documentação e ficou fora das cópias.)

## Decisões tomadas com o usuário

Em 09/10/2026, com a 6A validada no aparelho, no brainstorm da fase (duas rodadas de perguntas):

1. **Contrato dos consultores: rotas novas, um consultor por chamada**, só ADMIN — `POST /training-sessions/:id/consultants` (corpo `{ consultantId }`) e `DELETE /training-sessions/:id/consultants/:consultantId`. A regra de liberar os participantes fica no backend e vale também para o `PATCH /training-sessions/:id` do painel web. Recusado: o app mandar a lista inteira pelo `PATCH` que já existe — dois ADMINs mexendo ao mesmo tempo desfariam a mudança um do outro.
2. **Envio tardio: o servidor recusa.** A avaliação de quem não está mais com o participante — foi tirado da sessão, ou desatribuído pelo ADMIN, com a avaliação pela metade — não é gravada. No aparelho, ela aparece como recusada na aba Sincronizar, com o "Descartar" que já existe. Recusado: aceitar a avaliação mesmo assim (o participante pode já estar com outro consultor, ou avaliado por ele).
3. **"Disponíveis na equipe": a segunda linha é o e-mail.** O canvas mostra a agenda do consultor ("Sem sessão hoje", "Empilhadeira · Betim 13:00"), que o backend não tem.
4. **Das oito "Decisões em aberto" da 6A, entram as quatro de comportamento** (1 a 4 de lá; decisões 5 a 7 e 13 daqui). As quatro visuais (5 a 8 de lá: as cores do canvas que o app não tem, o contraste do "opcional", o título "Participantes" apagado sem conexão e as medidas pequenas) continuam em aberto.
5. **Cadastro × digitação (1.11): travar enquanto consulta.** Nome e e-mail ficam travados durante o "Consultando o CPF…", e a consulta ganha um limite de tempo de cerca de 8 segundos; passou disso, destrava como "não foi possível consultar".
6. **Data antiga (1.12): pedir confirmação** ao salvar uma data anterior à janela de 90 dias da lista de sessões.
7. **CPF sem conexão (1.11): consultar ao reconectar.** Sem conexão, o app não consulta e não mostra o aviso de falha; quando a rede volta, consulta sozinho o CPF que está no campo.
8. **Avaliação antiga que volta: continuar de onde parou** — com as respostas e a hora de início originais —, passando pela tela de iniciar quando o participante ainda não está com o consultor. Vale a regra de uma avaliação por vez, e o "Descartar avaliação" serve para quem prefere começar limpo.
9. **Já decidido na 6A** (decisão 6 de lá, de 06/10/2026): tirar um consultor com avaliação em andamento devolve os participantes dele para "Pendente" — ou para o status da nota anterior, numa reavaliação —, com uma mudança no backend que vale também para o painel web; e o ADMIN desatribui um participante de outro consultor por um menu ⋮ na linha do participante.

Em 09/10/2026, o desenho, aprovado em quatro partes:

10. **Backend:**
    - As duas rotas novas devolvem a lista de consultores da sessão depois da mudança. Recusam sessão concluída ou cancelada (403, como o editar). Adicionar recusa consultor que não existe ou está inativo; remover recusa o responsável (trocar o responsável continua no painel web). Repetir o pedido não é erro.
    - **Remover libera:** na mesma operação, quem estava "em avaliação" com o consultor que saiu fica sem consultor e volta para "Pendente", ou para o status da nota anterior. Vale na rota nova e no `PATCH` do web, quando a lista nova deixa alguém de fora.
    - **Desatribuir pelo ADMIN:** `POST /practical-assessments/unassign` deixa o ADMIN liberar o participante de qualquer consultor; o consultor comum continua liberando só os dele.
    - **Envio só de quem está com o participante:** `POST /practical-assessments/sync` recusa (item `rejected`, com o motivo) a avaliação de um participante que não está "em avaliação" com quem envia. Exceção, o reenvio: se a avaliação já gravada é a mesma (mesmo consultor e mesma hora de início), responde como aceita, sem regravar. O painel web já atribui antes de avaliar.
11. **Tela "Consultores" (quadro `3c`), só ADMIN:**
    - **Banco local:** uma tabela nova com os consultores de cada sessão, gravada junto com os participantes quando o detalhe é baixado; versão nova do banco (v5), com migração que preserva os dados. A equipe ("Disponíveis na equipe") vem do servidor ao abrir a tela e não fica guardada.
    - **Faixa de contexto:** "Empresa · 12 set" e "5 participantes · 3 consultores".
    - **"Na sessão":** o nome (com "(você)" no do usuário logado), o papel ("Responsável" ou "Consultor") e o "Remover da sessão" — que o responsável não tem. A segunda linha sai dos participantes do aparelho: "2 participantes · 1 em andamento", "2 participantes concluídos" ou "Sem participantes".
    - **Aviso de quem tem avaliação em andamento:** com uma, "Tem 1 avaliação em andamento. Remover devolve Marcos Vinícius para Pendente." (ou "para Não recomendado", numa reavaliação); com duas ou mais, "Tem 2 avaliações em andamento. Remover libera esses participantes para outro consultor."
    - **"Disponíveis na equipe":** nome, e-mail e "Adicionar".
    - **Fim da lista:** a nota do canvas, "Entrar e sair da sessão vale na hora e precisa de conexão. Offline, a lista fica só de leitura."
    - **Comportamento:** adicionar vale no toque, com "Rafael Lima entrou na sessão."; remover vale no toque, com "Rafael Lima saiu da sessão." — e, se o consultor tem avaliação em andamento, antes vem o diálogo "Remover Rafael Lima da sessão?", com a consequência e os botões "Voltar" e "Remover". Durante o envio, os botões travam e o que foi tocado mostra o carregamento. Na falha, o motivo fica num aviso no topo da lista.
    - **Sem conexão:** a faixa "Sem conexão — mudar os consultores precisa de internet.", os botões à vista e apagados e, no lugar da equipe, "A equipe aparece quando houver conexão."; quando a rede volta, a equipe carrega sozinha.
    - **Sessão concluída ou cancelada:** só leitura, com o motivo escrito.
    - **Detalhe da sessão (quadro `1f`), para o ADMIN:** a barra passa a ter o lápis, o ícone de pessoas e o indicador de envio, nessa ordem; o ícone de pessoas fica **sempre** habilitado (sem conexão, a tela de lá abre para leitura); e o cabeçalho ganha "3 consultores" ao lado da data. Para o consultor comum, nada muda.
12. **Desatribuir pelo ADMIN, avaliação antiga e envio recusado:**
    - **⋮ na linha:** no detalhe, para o ADMIN, as linhas "em avaliação com outro consultor" ganham um ⋮ à direita, com "Desatribuir participante". A confirmação: "Desatribuir Marcos Vinícius?" / "Está em avaliação com Rafael Lima. Ao desatribuir, volta para Pendente e pode ser avaliado por outro consultor." (ou "volta para Não recomendado", numa reavaliação) / "Voltar" e "Desatribuir". Depois, a linha vira "Pendente" na hora e aparece "Marcos Vinícius foi desatribuído." O ⋮ segue a regra das ações de ADMIN: sem conexão, ou com a sessão concluída ou cancelada, fica à vista e apagado — o motivo é o aviso que a lista já mostra. Os participantes do próprio ADMIN continuam pelo ⋮ do checklist.
    - **Avaliação antiga que volta:** uma avaliação só fica "em andamento" enquanto o participante está com o consultor. Se ele voltou pela linha ("Atribuir a mim" de novo), o checklist abre direto na avaliação antiga. Se voltou pelo "Reavaliar" (ainda não está com o consultor), a tela de iniciar mostra o botão "Continuar avaliação" e a nota "Você começou esta avaliação em 08/10 às 08:12. As respostas voltam ao continuar."; o toque reserva o participante (precisa de conexão) e reabre a avaliação. Uma por vez: se ele iniciou outra nesse meio-tempo, a antiga espera — abre com o aviso de sempre ("Você já está avaliando…") até a outra ser concluída ou descartada.
    - **Checklist aberto na hora da liberação:** o "Finalizar avaliação" desabilita, com o aviso "Este participante não está mais com você. Atribua de novo para continuar."
    - **Envio recusado**, no aparelho de quem foi removido: na aba Sincronizar, o item aparece com o motivo próprio "o participante não está mais com você" (no lugar de "recusada pelo servidor"), com o "Descartar" que já existe. Para isso, a recusa do servidor passa a vir com um código, além da mensagem.
13. **Ajustes nas telas da 6A:**
    - **1.11 Adicionar participante:** durante o "Consultando o CPF…", nome e e-mail ficam travados, e o CPF continua editável; a consulta tem limite próprio de 8 segundos (passou, destrava com "Não foi possível consultar o CPF. Preencha os dados e adicione assim mesmo."); sem conexão, não consulta e não mostra o aviso de falha sob o CPF (ficam a faixa de offline e a dica do botão); quando a rede volta, consulta sozinho o CPF completo e válido do campo.
    - **1.12 Dados do treinamento:** ao salvar uma data que o admin **mudou** para antes da janela de 90 dias da lista de sessões, um diálogo — título "Esta data é de mais de 90 dias atrás."; texto "A sessão vai sair da lista do app em todos os aparelhos; depois disso, só o painel web consegue alterá-la. Salvar assim mesmo?"; botões "Voltar" e "Salvar". A sessão que já tinha data antiga não pergunta quando só outro campo muda. A faixa de sem conexão passa a dizer "Sem conexão — salvar e cancelar precisam de internet."
14. **Divergências do canvas aprovadas:**
    - **Quadro `3c`:** sem a lupa (a busca é da Fase 8); o e-mail no lugar da agenda (decisão 3); o diálogo antes de remover quem tem avaliação em andamento; e os botões com alvo de 48dp (o quadro desenha 44).
    - **Quadro `1f`:** o ⋮ na linha de quem está com outro consultor e o diálogo de desatribuir, que o canvas não desenha. (O alvo de 48dp dos ícones, o chip de status e as observações no cabeçalho já vinham da 6A.)
15. **Fora da 6B:** as buscas (Fase 8); trocar o responsável da sessão (painel web); a agenda do consultor; as quatro decisões visuais em aberto da 6A; e o tablet (Fase 7; os quadros `4n` e `4y` desenham a 1.13 para ele).

### Ajustes feitos ao preparar o plano (revisar junto com o plano)

A validação na cópia descartável levou a estes ajustes. **Nenhum muda regra de negócio aprovada**, mas cada um é uma escolha — uma regra de tela que o código cria, ou uma medida que difere do quadro — que o usuário deve conferir.

**Um achado que pede atenção, fora do app:**

- **O painel web trata o `POST /practical-assessments/sync` como salvo com qualquer resposta 2xx** e não lê o resultado item a item (`apps/web/src/features/training-sessions/assessment-drawer.tsx`, linha 182). Com a regra nova da decisão 2, uma avaliação recusada no web apareceria como salva. Só acontece se o participante for liberado — por outro ADMIN, ou por quem tirou o consultor da sessão — com o checklist do web já aberto: o painel sempre atribui antes de abrir o checklist (`session-management-drawer.tsx`, linhas 279–305). Este plano não mexe no web; fica como pendência "Web", e o roteiro do aparelho confere que avaliar pelo painel continua funcionando.

**Backend:**

- **A regra de liberar mora num arquivo só**, `src/participants/participant-release.util.ts`, usado pelos três lugares que liberam: a rota nova de remover, o `PATCH` do web e o `unassign`. O `unassign` fazia a mesma conta à mão.
- **Os testes das rotas novas estão num arquivo novo**, `test/session-consultants.spec.ts`, com o service e o controller juntos; a trava de "só ADMIN" é conferida lendo os metadados das rotas.
- **Tirar da sessão quem já não estava não é erro**, como pôr quem já estava: o app manda um consultor por vez e pode reenviar depois de uma resposta que se perdeu.
- **Mensagens novas do backend:** "Consultor não encontrado" (404); "Consultor inativo não pode entrar em um treinamento" (400); "O consultor responsável não pode ser removido do treinamento. Troque o responsável antes." (400); "Um ou mais participantes não estão em avaliação" (409, no desatribuir do ADMIN); "Este participante não está mais em avaliação com você. A avaliação não foi registrada." (a recusa do `sync`, com o código `NOT_ASSIGNED`); "Participante não encontrado" (o `sync` de um participante que não existe — antes, o erro vinha do banco).
- **O ADMIN desatribui mesmo sem ter perfil de consultor**: para ele, o backend nem procura o perfil.
- **O reenvio é reconhecido pelo consultor e pela hora de início** da avaliação já gravada. O código da recusa sai num campo novo do item, `code`, ao lado de `error`; só essa recusa tem código.

**Dados no app:**

- **A tabela nova não guarda "se é o responsável"** (o desenho falava em guardar): o responsável já está na linha da sessão (`responsible_consultant_id`), e a tela compara com ele.
- **A linha de consultor some com a sessão** (`ON DELETE CASCADE`): quem apaga sessões do cache — a Home, ao tirar o que saiu da agenda, e a troca de usuário — não precisou mudar.
- **O responsável entra na lista mesmo que o vínculo dele falte** na resposta: o detalhe traz o `responsibleConsultant` inteiro. E um detalhe que venha sem a lista de consultores não apaga os que estão no cache.
- **Depois da atualização do app, as sessões que já estavam no cache ficam sem consultores** até o detalhe delas ser baixado de novo (a tabela nasce vazia). Sem conexão nesse meio-tempo, o "N consultores" do detalhe não aparece — a tela não afirma "0 consultores" —, e a tela de Consultores diz "Os consultores desta sessão ainda não foram baixados. Puxe para atualizar quando houver conexão."

**Tela de Consultores:**

- **De onde sai a segunda linha de cada consultor:** "em andamento" são os participantes em avaliação atribuídos a ele; "concluídos", os aprovados e não recomendados cuja avaliação foi feita por ele; o total é a soma dos dois. Quem está pendente, com outro consultor ou só na teórica não entra.
- **O aviso da avaliação em andamento só aparece em quem pode sair**: o responsável não tem o botão nem o aviso. O texto do diálogo de remover é o próprio aviso da linha.
- **Ordem:** o responsável primeiro, e os outros por nome, sem o acento mandar para o fim ("Ângela" antes de "Bruno"); a equipe também fica por nome, sem depender da ordem do servidor. A chave de ordenação que o detalhe já usava para os participantes passou para `lib/ui/core/name_sort.dart`.
- **"(você)" só aparece em "Na sessão"**; os avisos ("… saiu da sessão.") e o título do diálogo usam o nome puro.
- **A tela abre buscando a equipe e baixando a sessão de novo**, porque é dos participantes que saem a segunda linha e o aviso de cada consultor. O mesmo acontece ao **puxar para atualizar** (que a tela passa a ter) e quando a rede volta.
- **O que aparece no lugar da equipe:** o esqueleto, enquanto ela não chega; "A equipe aparece quando houver conexão.", também quando a busca falha por rede com o aparelho se dizendo conectado; "Não foi possível carregar a equipe. Puxe para atualizar.", nas outras falhas; e "Todos os consultores ativos da equipe já estão nesta sessão.", quando não sobra ninguém.
- **A falha de adicionar ou remover fica fora da rolagem**, entre a faixa de offline e a lista: com a lista rolada até o fim, um aviso no topo dela ficaria escondido. Some na tentativa seguinte.
- **A sessão é baixada de novo depois de toda mudança aceita e de toda recusa do servidor** (400, 403, 404 e 409); na recusa, a equipe é buscada de novo também. Sem rede e erro do servidor (5xx) não baixam nada.
- **Voltar com o envio no ar não é barrado:** a tela fecha, e a sessão é baixada de novo quando a resposta chega — o detalhe, que fica embaixo, lê do mesmo cache.
- **Sessão concluída ou cancelada, e a tela aberta por quem não é ADMIN** (sem caminho pela interface): a mesma tela, com os botões à vista e apagados e o motivo no topo da lista. A equipe é buscada do mesmo jeito.
- **"SIM Treinamentos" à direita de "Disponíveis na equipe"** é um texto fixo, como no quadro.
- **Entre duas linhas seguidas a linha divisória fica dupla** (1,5 + 1,5): o quadro desenha o contorno em cima e embaixo de cada linha.
- **A segunda linha de quem está na sessão quebra em duas** num celular estreito, em vez de perder o "em andamento" nas reticências; o e-mail de quem está na equipe encolhe com reticências. É como o quadro faz.
- **O botão "Adicionar" tem a largura do rótulo** e a mantém enquanto gira, para a linha não pular.
- **Sem ícone à direita da barra:** a lupa saiu (decisão 14), e o quadro `3c` não tem o indicador de envio.
- **Medidas que diferem do quadro `3c` por reaproveitar as peças do app** — a mesma natureza das decisões em aberto 5 e 8 da 6A, que continuam em aberto:
  - a faixa de contexto é a das outras duas telas de ADMIN: nome em 15 (o quadro tem 14), vão de 3 entre as linhas (2) e logo de 44 (40);
  - os avisos são o `InlineNotice` do app: recuo de 12 (o quadro tem 10 × 12 no aviso da linha), ícone de 18 (16) e o texto do aviso âmbar na tinta #8A4100 (#5C3A10); no aviso cinza do fim, o ícone sai em #334155 (#475569);
  - as pastilhas do papel usam os tons dos chips do app: "Consultor" com fundo #F1F5F9 (o quadro tem #EEF2F7) e "Responsável" com contorno #1D9AA4 (#7FC9D1);
  - o contorno do "Remover da sessão" é o `dangerBorder` #FCA5A5 (#E9A2A2);
  - os títulos de seção têm altura de linha 1,3 (1,2).
- **O que segue o quadro à risca:** os recuos das linhas (15 × 20) e dos títulos, os vãos (12, 10, 4), o contorno de 1,5, o nome em 15,5 / 600 (um token novo), a pastilha sem ícone com recuo 5 × 10, os botões com canto 10, ícone de 19 e texto 14 / 700, e os recuos da nota do fim (16, 20, 24).

**Detalhe da sessão:**

- **"N consultores" só aparece com N maior que zero**, e o consultor comum nem assina a lista de consultores. No cabeçalho, o chip de status continua por último (o quadro `1f` não o desenha; vem da 6A).
- **O ícone de pessoas está ligado desde antes de a sessão carregar.**
- **A linha com ⋮ fica cerca de 5dp mais alta** que as outras (o alvo de 48dp é mais alto que o nome mais o CPF), e o recuo à direita dela é menor (8dp), para o ícone do ⋮ — e não a área de toque — ficar na margem da lista, como o "adicionar" do título. Para isso, o recuo lateral da linha passou a ser de cada parte dela; um teste novo trava os recuos de sempre (20 dos lados, 15 em cima e embaixo) nas linhas com e sem ⋮.
- **Com um desatribuir no ar,** a linha gira no lugar do ⋮, e o ⋮ das outras linhas não abre. A falha aparece no aviso passageiro de baixo, como a do "Atribuir a mim".
- **Sem o nome do consultor no aparelho,** a confirmação diz "Está em avaliação com outro consultor."
- **O ⋮ usa a chamada de desatribuir que o app já tinha** (a do ⋮ do checklist), que muda a linha na hora; o que mudou foi o backend aceitar o ADMIN.

**Checklist:**

- **A tela de "continuar" é a de "não iniciada"** com três trocas: o bloco do topo diz "Você começou esta avaliação em 08/10 às 08:12." (título) e "As respostas voltam ao continuar." (texto) — a nota aprovada, dividida em duas linhas; o cabeçalho mostra "Iniciada em 8 out 08:12" no lugar de "não iniciada"; e o botão é "Continuar avaliação". A lista "O que será avaliado" continua lá.
- **O ⋮ da tela de "continuar" oferece o "Descartar avaliação"**, sem precisar continuar antes; o diálogo não diz "O participante continua com você" quando ele não está com o consultor.
- **Desatribuir pelo ⋮ do checklist com a avaliação parada à espera também a apaga**, como já apagava a avaliação aberta.
- **Com o participante liberado e o checklist aberto, só o "Finalizar avaliação" trava**: as notas continuam marcáveis, e ficam guardadas para quando ele for atribuído de novo.
- **Quando é a sessão que sai do aparelho** (o consultor foi tirado dela), o participante some do cache e o checklist não tem como saber que foi liberado: o "Finalizar avaliação" continua valendo, e a recusa chega pela aba Sincronizar (decisão 2).
- **"Vale a mais nova" também é regra do repositório:** continuar uma avaliação antiga é recusado enquanto outra, começada depois, está em andamento — inclusive se ela começou depois de a tela abrir.
- **A avaliação já confirmada (na fila) não vira "continuar"**: abre só para leitura, como antes.
- **O título "O que será avaliado" passou a encolher com reticências.** O teste novo da tela de "continuar" em 360dp com a fonte ampliada acusou um estouro que essa linha já tinha.

**Aba Sincronizar:**

- **O item recusado por esse motivo continua com o "Tentar novamente"** ao lado do "Descartar": se o participante voltar para o consultor, o reenvio é aceito. O texto do diálogo de descartar é o mesmo.

**1.11 Adicionar participante:**

- **A consulta que falhou também é refeita quando a rede volta**, e não só a do CPF digitado sem conexão (fecha uma pendência "8" da 6A).
- **Sem conexão, nome e e-mail continuam editáveis.** Quando a rede volta e a consulta roda, eles travam enquanto ela dura, e o cadastro toma o lugar do que tiver sido digitado — a regra da 6A, agora sem trocar o texto sob o cursor.
- **Com nome e e-mail travados, o "próximo" do teclado no CPF não tem campo de texto para onde ir** enquanto a consulta dura; depois da resposta, o admin toca no campo que quiser. O que o teclado faz nesse instante não foi conferido em aparelho — está no roteiro da Task 15.
- **O limite de 8 segundos é do app:** a chamada continua no ar até o limite da API, e a resposta que chegar depois é ignorada.

**1.12 Dados do treinamento:**

- **O primeiro dia da janela ainda está na lista:** a pergunta só aparece da véspera para trás. Trocar uma data antiga por outra data antiga também pergunta.
- **O botão "Salvar" do diálogo tem a cor de marca**, e não o vermelho dos diálogos destrutivos.
- **A janela de 90 dias é uma constante só**, a da lista de sessões (`SessionRepository.historyWindowDays`, que passou a ser pública).

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app` (a mesma das fases anteriores). Sem git worktree. Não criar branch, não fazer merge, não fazer push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada, com a mensagem exata dada. Vale também para o backend (o `apps/backend/CLAUDE.md` pede inglês, mas a prática do repositório é português).
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem trabalho do usuário fora do git, que **não é desta fase e fica exatamente como está**: um arquivo rastreado **já modificado** (`brainstorm-app-mobile.md`) e os não rastreados `.vscode/`, `IMPLEMENTATION-STATUS.md`, `apps/backend/test-render.js`, `apps/mobile/simtc/devtools_options.yaml`, `apps/web/src/app/(client)/my-company/trainings/[id]/certificates/`, `brainstorm-implementacao-mobile.md`, `prompt-claude-design-mobile.md`, `prompt-implementacao-mobile-claude-code.md`, `test-pdf.js` e `test-render.js`.
- **Proibido `git restore`, `git checkout -- <arquivo>`, `git stash`, `git reset` e `git clean`**, e qualquer outro comando que desfaça mudança que não é da task. Se o `git status` mostrar algo que não é da task, ignorar e seguir. Na 6A, um subagente leu "não tocar" como "esse arquivo não pode estar modificado" e desfez o `brainstorm-app-mobile.md`.
- **Na execução por subagentes:** antes do primeiro despacho, guardar a linha de base — o `git status --porcelain` inteiro e o `git hash-object brainstorm-app-mobile.md` — e compará-la, sem filtrar nada, depois de **cada** subagente. Todo despacho repete as duas regras acima com todas as letras.
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado. No backend, `npx jest` já tem **12 falhas antigas** (`test/auth.service.spec.ts` e `test/participants.service.spec.ts`, desde 17/09/2026) — esse número não pode subir, e esses dois arquivos não são tocados.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-10-10-mobile-fase-6b-consultores-da-sessao/`.

**Mobile (valem para todas as fases)**
- Flutter 3.41.6 / Dart 3.11.4 (o `pubspec.yaml` aceita a partir do 3.4: nada de sintaxe mais nova que isso — por exemplo, nada de elementos `?x` em listas). App **só Android**, APK sideload. Validação manual em **aparelho físico** (USB ou Wi-Fi, nunca emulador) — procedimento em `apps/mobile/simtc/README.md`.
- MVVM + Repository: um `ChangeNotifier` por tela; tela nunca chama `Dio`/Drift direto. Repository que fala com a rede devolve o `Result<T>` de `lib/utils/result.dart`; os métodos só locais (como todo o `AssessmentRepository`) devolvem o valor direto.
- `ConnectivityService` e `AssessmentSyncService` únicos, criados no `AppDependencies`, nunca dentro de uma tela.
- Composição "quebra-cabeça": cada tela decompõe a UI em métodos privados `Widget _buildX()` combinados num `build()` enxuto.
- Design System: nenhum `Color(0xFF…)`, nenhum número mágico de espaçamento e nenhum `TextStyle` literal fora de `lib/ui/core/theme/`; **nunca trocar `fontSize` num `.copyWith()`** fora do tema (cor, peso e espaçamento de letra, sim). Aritmética sobre tokens (`AppSpacing.sm + 2`) é o padrão aceito.
- Alvos de toque mínimos de 48dp (`AppSpacing.touchTarget`); skeleton no lugar de spinner em listas; estados de erro e vazio explícitos.
- Ações de ADMIN exigem conexão: offline, ficam **visíveis e desabilitadas**, com o motivo escrito — nunca somem.
- Contratos reais apenas — nenhum campo ou endpoint não confirmado no código do backend.
- TDD: teste falhando pelo motivo certo → implementação → teste passando.
- **Widget test com Drift de verdade** usa `AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true))`.
- Nos testes que importam `package:drift/drift.dart` inteiro, esconder `isNull` e `isNotNull` (conflitam com os matchers do `flutter_test`).
- Alguns arquivos do app são CRLF: ao editar, preservar o fim de linha que o arquivo já usa.
- Posição dos testes novos: cada bloco de teste entra **no lugar que o plano dá** (o "substituir / por" diz antes de qual teste ou grupo), e não no fim do arquivo.
- No passo "Rodar e ver falhar": quando um arquivo de teste não compila, o `flutter test` pode marcar com `[E]` também outros arquivos da mesma rodada (`Error: The Dart compiler exited unexpectedly.`). O que vale são os erros de compilação que o passo cita; os outros arquivos voltam a passar no "Rodar e ver passar".

Nas Tasks 1 a 3 (backend), os caminhos são a partir da raiz do repositório, e os comandos `npx` rodam em `apps/backend`. Nas Tasks 4 a 14 (app), todos os caminhos de código são relativos a `apps/mobile/simtc/`, e os comandos `flutter` e `dart` rodam a partir dessa pasta. Os `git add`/`git commit` de todas as tasks rodam **da raiz do repositório**, com os caminhos completos dados.

## Review Focus

Os cinco casos que o desenho implica, que um ADMIN ou um consultor em campo vai encontrar, e onde cada um ficou preso num teste:

1. **Dois toques rápidos em "Adicionar", "Remover da sessão" ou "Desatribuir"** (sinal fraco, a resposta demora) → uma requisição só, e nenhuma outra ação no meio. Preso em: `durante o envio, só aquele consultor aparece ocupado, e outro toque não manda nada` e `dois toques rápidos removem uma vez só` (Task 7); `com a resposta demorando: o botão tocado gira, os outros travam, e tudo volta quando ela chega` (Task 8); `durante o envio só aquele participante aparece ocupado, e outro toque não manda nada` (Task 10).
2. **Voltar com o envio ainda no ar** → a tela fecha sem derrubar o app, e o detalhe que ficou embaixo recebe o estado novo. Preso em: `fechar a tela com a resposta ainda viajando não derruba o app — e a sessão é baixada de novo mesmo assim` (Task 7) e `voltar com o envio ainda no ar: a tela fecha sem derrubar nada, e a sessão é baixada de novo quando a resposta chega` (Task 8).
3. **O que o aparelho tem está velho** — a sessão foi concluída por outra pessoa, o consultor ficou inativo, o participante já saiu das mãos de quem o ADMIN ia desatribuir → o servidor recusa, o motivo aparece e a sessão é baixada de novo. Preso em: `recusado pelo servidor: mostra o motivo, baixa a sessão e busca a equipe de novo`, `recusa $status também baixa a sessão de novo` (um teste para cada: 403, 404 e 409) e `a sessão ser concluída por outra pessoa trava a tela aberta` (Task 7); `recusado pelo servidor: mostra o motivo e baixa o detalhe, para a linha se acertar` (Task 10).
4. **Celular estreito (360dp) com a fonte do sistema ampliada** → nada estoura: a tela nova, a barra do ADMIN com três ícones, a linha com chip e ⋮, a tela de "continuar" e o rodapé com o aviso de liberado. Preso em: `em 360 de largura e com a fonte ampliada, o nome e o e-mail compridos encolhem com reticências e o botão continua inteiro` (Task 6); os dois testes `num celular de 360x640 com a fonte ampliada…` (Task 8); `num celular de 360 de largura, a barra do ADMIN com os três ícones e o cabeçalho com a contagem não estouram` (Task 9); `num celular de 360 de largura com a fonte ampliada, a linha com o chip e o ⋮ não estoura` (Task 10); `num celular de 360x640 com a fonte ampliada, a tela de continuar e o rodapé com o aviso de liberado não estouram` (Task 11); `num celular de 360x640 com a fonte ampliada, a pergunta cabe na tela` (Task 14).
5. **O app atualizado por cima de um cache antigo, aberto sem conexão** → o banco migra sem perder nada, o detalhe não afirma "0 consultores" e a tela de Consultores diz que ainda não baixou. Preso em: `migra do esquema 4 para o 5 criando a tabela de consultores da sessão, sem mexer nas sessões já cacheadas` (Task 4); `sem os consultores no aparelho, o contexto só conta os participantes, e a tela diz que ainda não foram baixados` (Task 7); `sessão em cache sem os consultores, e sem conexão: avisa que ainda não foram baixados` (Task 8); `com um consultor só, o singular; sem nenhum no aparelho, some` (Task 9).

E um sexto, do lado do servidor: **o reenvio de uma avaliação que já foi aceita** (a resposta do primeiro envio se perdeu) → não é recusado nem regravado. Preso nos testes do `sync` da Task 3.

## Estado herdado (ponto de partida)

HEAD = o commit deste plano, sobre `37d4941`. App: `flutter analyze` limpo; **698 testes passando**. Backend: `npx jest` com **12 falhas antigas e 72 testes passando** (84 no total); `npx tsc --noEmit` sem saída.

Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| Sessões no backend | `apps/backend/src/training-sessions/` | `findTrainingSessionById` inclui `responsibleConsultant`, `consultants` (com `consultant`) e os participantes com `assignedConsultant { id, name }` e `assessment`; `updateSession` (`PATCH :id`, ADMIN) recria os vínculos quando recebe `additionalConsultantsIds` e recusa sessão concluída ou cancelada com 403 "Não é possível editar um treinamento concluído ou cancelado"; controller com `@UseGuards(JwtAuthGuard, RolesGuard)` e `@Roles('ADMIN' as any)` |
| Avaliações no backend | `apps/backend/src/practical-assessments/` | `assignParticipants`; `unassignParticipants(dto, consultantIdFromJwt, userId)` — só os do próprio consultor (409 "Um ou mais participantes não estão atribuídos a você"); `syncFromMobile` devolve `[{ trainingParticipantId, status, error }]`; `syncOne`; `resolveConsultantId` |
| Equipe no backend | `apps/backend/src/consultants/` | `GET /consultants?active=true` (ADMIN e CONSULTANT): os consultores ativos, por nome, com `id`, `name`, `email` |
| Score e status | `packages/shared-types` | `getApprovalStatus(score)` → `'APROVADO'` com 70 ou mais, `'NAO_RECOMENDADO'` abaixo |
| Cliente HTTP | `lib/data/services/api/api_client.dart` | `get<T>(path, {queryParameters})`, `post<T>(path, {data})`, `patch`, `delete<T>(path)`; lança `ApiException` (`message` já com o texto do backend, `statusCode`, `isNetworkError`, `isTimeout`) |
| Banco local | `lib/data/services/local/` | `AppDatabase` (`schemaVersion` 4, `migration`, `clearSessionsCache`), `tables.dart` (`Sessions` com `responsibleConsultantId`; `Participants` com `assignedConsultantId`, `assignedConsultantName`, `assessedByConsultantId`, `score`); o `app_database.g.dart` é gerado e versionado |
| Participantes | `lib/data/repositories/participant_repository.dart` | `watchBySession(id)`, `watchParticipant(id)`, `findParticipant(id)`; `syncSession(id)` → `Result<int>` (baixa o detalhe e regrava o cache numa transação); `assign(id, consultantId:, consultantName:)`; `unassign(id)` — já muda a linha local na hora; `lookupCpf`, `add` |
| Sessões | `lib/data/repositories/session_repository.dart` | `watchSession(id)`; `syncAll()` com a janela `_historyWindowDays = 90`; `update`, `cancel` |
| Avaliação local | `lib/data/repositories/assessment_repository.dart` | `findCurrent`, `findInProgressOther`, `openDraft`, `EvaluationInProgressException`, `loadItems`, `discardDraft`, `discardFailed(id, reason:)`, `saveSendResults` |
| Envio | `lib/data/services/assessment_sync_service.dart` | `SendFailure` (`refused` = "recusada pelo servidor"), `discardRefused(id)`, `_outcomeByParticipant` |
| Conexão | `lib/data/services/connectivity_service.dart` | `isOffline`, `onReconnected` (só na volta da rede) |
| Modelos | `lib/data/models/` | `TrainingSession` (`responsibleConsultantId`, `totalParticipants`, `date` de calendário), `SessionStatus.acceptsChanges`; `SessionParticipant` (`status`, `assignedConsultantId`, `assignedConsultantName`, `assessedByConsultantId`, `isAssessed`, `hasPreviousAssessment`); `AuthUser` (`isAdmin`, `consultantId`) |
| Detalhe | `lib/ui/session_detail/` | `SessionDetailViewModel` (`isAdmin`, `adminActionsAllowed`, `situationFor`, `refresh()`, `assign`), `_adminActionsEnabled`, `_buildMetaRow`/`_buildMetaItem`; `ParticipantRow`; `situationOf`, `ParticipantSituation.other`, `sortForDisplay` (`participant_filter.dart`) |
| Checklist | `lib/ui/checklist/` | `ChecklistViewModel` (`init`, `start`, `_reserve`, `_needsReservation`, `discard`, `unassign`, `_checkBlock`, `isBlocked`); `_buildNotStarted`, `_buildFooter`, `_buildMenu`, `_confirmUnassign` (o molde do ⋮ e do diálogo) |
| Telas da 6A | `lib/ui/add_participant/`, `lib/ui/session_edit/` | `AddParticipantViewModel` (`CpfCheck`, `_lookup`, `cpfHelper`), `SessionEditViewModel` (`_dateChanged`, `save`), `lockedReason` nas duas |
| Widgets do DS | `lib/ui/core/widgets/` | `AppTopBar` (`actions`, `trailing`), `AppIconAction`, `AppCtaButton`, `AppDangerOutlineButton`, `SessionContextHeader`, `StatusChip` e `StatusTone`, `InlineNotice` e `NoticeTone`, `ConnectivityBanner(isOffline, message)`, `SkeletonListItem` |
| Rótulos | `lib/ui/core/date_labels.dart` | `dayMonthLabel`, `startedLabel`, `offlineDataMessage` |
| Padrões de tela | `lib/ui/session_edit/session_edit_screen.dart` | aviso de falha em `NoticeTone.danger`; diálogo de confirmação com "Voltar" e `FilledButton` em `AppColors.dangerInk`; SnackBar pelo `ScaffoldMessenger` do app |
| Testes | `test/ui/session_edit/session_edit_screen_test.dart`, `test/ui/session_detail/session_detail_screen_test.dart` | tela com Drift em memória e `ApiClient` simulado, empilhada sobre uma rota "origem" (`pumpEdit`, com tamanho de tela e escala de fonte); `goOffline()`; `showWithRouter` e `showAdmin`, com o `createRouter` de produção; resposta presa num `Completer` e `pumpTransitions` |

## Mapa de Arquivos

### Novos

| Arquivo | Task | Responsabilidade |
|---|---|---|
| `apps/backend/src/participants/participant-release.util.ts` | 1 | `statusAfterRelease`, `releaseParticipantsOfConsultants` |
| `apps/backend/src/training-sessions/dto/add-session-consultant.dto.ts` | 1 | corpo do `POST …/consultants` |
| `apps/backend/test/session-consultants.spec.ts` | 1 | |
| `apps/backend/src/practical-assessments/sync-refused.exception.ts` | 3 | a recusa do `sync` com código |
| `lib/data/models/session_consultant.dart` | 4 | um consultor de uma sessão |
| `lib/data/repositories/session_consultant_repository.dart` | 5 | consultores da sessão no cache, a equipe, entrar e sair |
| `lib/ui/session_consultants/consultant_row.dart` | 6 | uma linha da tela de Consultores |
| `lib/ui/core/name_sort.dart` | 7 | `nameSortKey` (saiu do detalhe) |
| `lib/ui/session_consultants/session_consultants_viewmodel.dart` | 7 | estado da 1.13 |
| `lib/ui/session_consultants/session_consultants_screen.dart` | 8 | tela 1.13 |
| `test/data/models/session_consultant_test.dart` | 4 | |
| `test/data/repositories/session_consultant_repository_test.dart` | 5 | |
| `test/ui/session_consultants/consultant_row_test.dart` | 6 | |
| `test/ui/core/name_sort_test.dart`, `test/ui/session_consultants/session_consultants_viewmodel_test.dart` | 7 | |
| `test/ui/session_consultants/session_consultants_screen_test.dart` | 8 | |

### Modificados

| Arquivo | Tasks | O que muda |
|---|---|---|
| `apps/backend/src/training-sessions/training-sessions.{controller,service}.ts` | 1 | `addConsultant`, `removeConsultant`; o `updateSession` libera quem ficou de fora |
| `apps/backend/src/practical-assessments/practical-assessments.{controller,service}.ts` | 2, 3 | (2) o `unassign` do ADMIN; (3) o `sync` confere a atribuição e devolve `code` |
| `apps/backend/test/practical-assessments.service.spec.ts` | 2, 3 | |
| `apps/mobile/docs/fase-0-auditoria.md` | 3 | nota: as três mudanças do backend |
| `lib/data/services/local/tables.dart`, `app_database.dart`, `app_database.g.dart` | 4 | tabela `SessionConsultants`; esquema v5; `replaceSessionConsultants` |
| `lib/data/repositories/participant_repository.dart` | 4 | o `syncSession` grava os consultores |
| `lib/app_providers.dart` | 5 | o repositório novo |
| `lib/ui/core/theme/app_icons.dart` | 6, 8, 9 | `info`; (8) `addConsultant`, `removeConsultant`; (9) `consultants`, `consultantCount` |
| `lib/ui/core/theme/app_typography.dart` | 6 | `consultantName` |
| `lib/ui/core/widgets/app_buttons.dart` | 6 | `AppDangerOutlineButton(compact:)`; `AppCompactOutlineButton` |
| `lib/ui/core/widgets/status_chip.dart` | 6 | `LabelPill`; as cores do tom numa extensão |
| `lib/ui/core/widgets/session_context_header.dart` | 6 | `title` |
| `lib/ui/session_detail/participant_filter.dart` | 7 | usa o `nameSortKey` |
| `lib/router.dart` | 8 | `AppRoutes.sessionConsultants` |
| `lib/ui/session_detail/session_detail_viewmodel.dart` | 9, 10 | (9) `consultantsLabel`; (10) `showsAdminMenu`, `unassignAsAdmin` |
| `lib/ui/session_detail/session_detail_screen.dart` | 9, 10 | (9) o ícone de pessoas e a contagem; (10) o ⋮ e o diálogo |
| `lib/ui/session_detail/participant_row.dart` | 10 | `menu` |
| `lib/data/repositories/assessment_repository.dart` | 11, 12 | (11) `startedAfter`; (12) `discardFailed(reasons:)` |
| `lib/ui/core/date_labels.dart` | 11 | `dayAndClockLabel` |
| `lib/ui/checklist/checklist_viewmodel.dart`, `checklist_screen.dart` | 11 | a avaliação parada e o participante liberado |
| `lib/data/services/assessment_sync_service.dart` | 12 | `SendFailure.notAssigned` |
| `lib/ui/sync/sync_screen.dart` | 12 | "Descartar" nas duas recusas |
| `lib/ui/add_participant/add_participant_viewmodel.dart`, `add_participant_screen.dart` | 13 | trava, limite de tempo e conexão |
| `lib/data/repositories/session_repository.dart` | 14 | `historyWindowDays` público |
| `lib/ui/session_edit/session_edit_viewmodel.dart`, `session_edit_screen.dart` | 14 | a pergunta da data antiga; a faixa |
| testes existentes | 2–14 | ver cada task |

---

## Task 1: Backend — rotas de consultor da sessão, e liberar os participantes ao remover

O app precisa pôr e tirar um consultor da sessão sem mandar a lista inteira (decisão 1). E quem sai da sessão não pode continuar "com" participante nenhum: os que estavam em avaliação com ele voltam para a fila na mesma operação — pela rota nova e pelo `PATCH` do painel web (decisões 9 e 10). A regra de para onde o participante volta já existia dentro do `unassign`; aqui ela ganha um arquivo próprio, que a Task 2 passa a usar. Os caminhos desta task são a partir da raiz do repositório.

**Files:**
- Create: `apps/backend/src/participants/participant-release.util.ts`
- Create: `apps/backend/src/training-sessions/dto/add-session-consultant.dto.ts`
- Create: `apps/backend/test/session-consultants.spec.ts`
- Modify: `apps/backend/src/training-sessions/training-sessions.controller.ts`
- Modify: `apps/backend/src/training-sessions/training-sessions.service.ts`

**Interfaces:**
- Consumes: `getApprovalStatus(score)` (`@simtc/shared-types`); `PrismaService` (`trainingSession`, `consultant`, `sessionConsultant`, `trainingParticipant`, `$transaction`); `findTrainingSessionById` (já traz `consultants`); `JwtAuthGuard`, `RolesGuard`, `@Roles('ADMIN' as any)`.
- Produces:
  - `statusAfterRelease(previousScore: number | null | undefined)` → `'PENDENTE'` sem nota anterior; senão, `getApprovalStatus(previousScore)`.
  - `releaseParticipantsOfConsultants(tx: Prisma.TransactionClient, trainingSessionId: string, consultantIds: string[]): Promise<void>` — os participantes da sessão em `EM_AVALIACAO` com um desses consultores ficam com `assignedConsultantId: null` e o status de `statusAfterRelease`.
  - `POST /api/training-sessions/:id/consultants` (só ADMIN), corpo `{ "consultantId": string }`, e `DELETE /api/training-sessions/:id/consultants/:consultantId` (só ADMIN). As duas devolvem `{ responsibleConsultantId: string | null, consultants: [{ trainingSessionId, consultantId, consultant: { id, name, email } }] }`, por nome.
  - Recusas: `404 "Sessão de treinamento não encontrada"`; `403 "Não é possível editar um treinamento concluído ou cancelado"`; no POST, `404 "Consultor não encontrado"` e `400 "Consultor inativo não pode entrar em um treinamento"`; no DELETE, `400 "O consultor responsável não pode ser removido do treinamento. Troque o responsável antes."`. Repetir o POST de quem já está, ou o DELETE de quem já saiu, devolve a lista sem erro.
  - No service: `addConsultant(id: string, consultantId: string)` e `removeConsultant(id: string, consultantId: string)`. O `updateSession`, quando recebe `additionalConsultantsIds`, passa a liberar os participantes de quem ficou fora da lista nova.

- [ ] **Step 1: Escrever os testes que falham**

**Criar `apps/backend/test/session-consultants.spec.ts`:**

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from 'src/auth/decorators/roles.decorator';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { RolesGuard } from 'src/auth/guards/roles.guard';
import { TrainingSessionsController } from 'src/training-sessions/training-sessions.controller';
import { TrainingSessionsService } from 'src/training-sessions/training-sessions.service';
import { QrCodeService } from 'src/training-sessions/qr-code.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { EmailService } from 'src/email/email.service';
import { StorageService } from 'src/storage/storage.service';

const mockPrisma = {
  trainingSession: { findUnique: jest.fn(), update: jest.fn() },
  consultant: { findUnique: jest.fn() },
  sessionConsultant: {
    upsert: jest.fn(),
    deleteMany: jest.fn(),
    createMany: jest.fn(),
    findMany: jest.fn(),
  },
  trainingParticipant: { findMany: jest.fn(), update: jest.fn() },
  $transaction: jest.fn(),
};

// Vínculos da sessão, no formato que o detalhe da sessão já devolve.
const links = [
  { trainingSessionId: 's1', consultantId: 'c1', consultant: { id: 'c1', name: 'Carla Mendes', email: 'carla@sim.com' } },
  { trainingSessionId: 's1', consultantId: 'c2', consultant: { id: 'c2', name: 'Rafael Lima', email: 'rafael@sim.com' } },
];

function openSession(status = 'EM_ANDAMENTO') {
  return { status, responsibleConsultantId: 'c1' };
}

// Participante em avaliação, com a nota da avaliação anterior (ou sem avaliação).
function held(id: string, score?: number | null) {
  return {
    id,
    status: 'EM_AVALIACAO',
    assignedConsultantId: 'c2',
    assessment: score === undefined ? null : { score },
  };
}

describe('TrainingSessionsService: consultores da sessão', () => {
  let service: TrainingSessionsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TrainingSessionsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: EmailService, useValue: {} },
        { provide: StorageService, useValue: {} },
      ],
    }).compile();

    service = module.get(TrainingSessionsService);
    jest.resetAllMocks();
    mockPrisma.$transaction.mockImplementation(async (run: (tx: typeof mockPrisma) => unknown) =>
      run(mockPrisma),
    );
    mockPrisma.sessionConsultant.findMany.mockResolvedValue(links);
    mockPrisma.trainingParticipant.findMany.mockResolvedValue([]);
  });

  describe('addConsultant', () => {
    it('sessão que não existe: 404', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(null);

      await expect(service.addConsultant('s1', 'c2')).rejects.toThrow(NotFoundException);
      expect(mockPrisma.sessionConsultant.upsert).not.toHaveBeenCalled();
    });

    it.each(['CONCLUIDO', 'CANCELADO'])('sessão com status %s: 403, sem gravar nada', async (status) => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(openSession(status));

      await expect(service.addConsultant('s1', 'c2')).rejects.toThrow(ForbiddenException);
      expect(mockPrisma.sessionConsultant.upsert).not.toHaveBeenCalled();
    });

    it('consultor que não existe: 404', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(openSession());
      mockPrisma.consultant.findUnique.mockResolvedValue(null);

      await expect(service.addConsultant('s1', 'c9')).rejects.toThrow(NotFoundException);
      expect(mockPrisma.sessionConsultant.upsert).not.toHaveBeenCalled();
    });

    it('consultor inativo: 400', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(openSession());
      mockPrisma.consultant.findUnique.mockResolvedValue({ active: false });

      await expect(service.addConsultant('s1', 'c2')).rejects.toThrow(BadRequestException);
      expect(mockPrisma.sessionConsultant.upsert).not.toHaveBeenCalled();
    });

    it.each(['PLANEJADO', 'EM_ANDAMENTO'])(
      'sessão com status %s: põe o consultor e devolve os consultores da sessão',
      async (status) => {
        mockPrisma.trainingSession.findUnique.mockResolvedValue(openSession(status));
        mockPrisma.consultant.findUnique.mockResolvedValue({ active: true });

        const result = await service.addConsultant('s1', 'c2');

        // `upsert` com `update` vazio: repetir o pedido (toque duplo, resposta
        // que se perdeu) não é erro nem duplica o vínculo.
        expect(mockPrisma.sessionConsultant.upsert).toHaveBeenCalledWith({
          where: { trainingSessionId_consultantId: { trainingSessionId: 's1', consultantId: 'c2' } },
          create: { trainingSessionId: 's1', consultantId: 'c2' },
          update: {},
        });
        expect(mockPrisma.sessionConsultant.findMany).toHaveBeenCalledWith({
          where: { trainingSessionId: 's1' },
          include: { consultant: { select: { id: true, name: true, email: true } } },
          orderBy: { consultant: { name: 'asc' } },
        });
        expect(result).toEqual({ responsibleConsultantId: 'c1', consultants: links });
      },
    );
  });

  describe('removeConsultant', () => {
    it('sessão que não existe: 404', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(null);

      await expect(service.removeConsultant('s1', 'c2')).rejects.toThrow(NotFoundException);
      expect(mockPrisma.sessionConsultant.deleteMany).not.toHaveBeenCalled();
    });

    it.each(['CONCLUIDO', 'CANCELADO'])('sessão com status %s: 403, sem apagar nada', async (status) => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(openSession(status));

      await expect(service.removeConsultant('s1', 'c2')).rejects.toThrow(ForbiddenException);
      expect(mockPrisma.sessionConsultant.deleteMany).not.toHaveBeenCalled();
    });

    it('o responsável não sai por aqui: 400, sem apagar nada', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(openSession());

      await expect(service.removeConsultant('s1', 'c1')).rejects.toThrow(BadRequestException);
      expect(mockPrisma.sessionConsultant.deleteMany).not.toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.update).not.toHaveBeenCalled();
    });

    it('tira o consultor e, na mesma transação, libera quem estava em avaliação com ele', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(openSession());
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        held('tp-nunca-avaliado'),
        held('tp-aprovado-antes', 85),
        held('tp-reprovado-antes', 40),
        held('tp-nota-zero', 0),
        held('tp-avaliacao-sem-nota', null),
      ]);

      const result = await service.removeConsultant('s1', 'c2');

      expect(mockPrisma.$transaction).toHaveBeenCalledTimes(1);
      expect(mockPrisma.sessionConsultant.deleteMany).toHaveBeenCalledWith({
        where: { trainingSessionId: 's1', consultantId: 'c2' },
      });
      // Só os desta sessão, em avaliação, com quem saiu.
      expect(mockPrisma.trainingParticipant.findMany).toHaveBeenCalledWith({
        where: {
          trainingSessionId: 's1',
          status: 'EM_AVALIACAO',
          assignedConsultantId: { in: ['c2'] },
        },
        include: { assessment: { select: { score: true } } },
      });
      const released = (id: string, status: string) => ({
        where: { id },
        data: { assignedConsultantId: null, status },
      });
      expect(mockPrisma.trainingParticipant.update.mock.calls.map(([call]) => call)).toEqual([
        released('tp-nunca-avaliado', 'PENDENTE'),
        released('tp-aprovado-antes', 'APROVADO'),
        released('tp-reprovado-antes', 'NAO_RECOMENDADO'),
        // Nota zero é avaliação anterior: volta a "Não recomendado", não a "Pendente".
        released('tp-nota-zero', 'NAO_RECOMENDADO'),
        released('tp-avaliacao-sem-nota', 'PENDENTE'),
      ]);
      expect(result).toEqual({ responsibleConsultantId: 'c1', consultants: links });
    });

    it('quem já não estava na sessão: não é erro', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(openSession());
      mockPrisma.sessionConsultant.deleteMany.mockResolvedValue({ count: 0 });

      await expect(service.removeConsultant('s1', 'c7')).resolves.toEqual({
        responsibleConsultantId: 'c1',
        consultants: links,
      });
      expect(mockPrisma.trainingParticipant.update).not.toHaveBeenCalled();
    });
  });

  describe('updateSession (o PATCH que o painel web usa)', () => {
    function sessionWith(consultantIds: string[]) {
      return {
        id: 's1',
        status: 'EM_ANDAMENTO',
        responsibleConsultantId: 'c1',
        consultants: consultantIds.map((consultantId) => ({ consultantId })),
      };
    }

    it('quem fica de fora da lista nova tem os participantes liberados', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(sessionWith(['c1', 'c2', 'c3']));
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([held('tp-1')]);

      await service.updateSession('s1', { additionalConsultantsIds: ['c3'] });

      expect(mockPrisma.trainingParticipant.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            trainingSessionId: 's1',
            status: 'EM_AVALIACAO',
            assignedConsultantId: { in: ['c2'] },
          },
        }),
      );
      expect(mockPrisma.trainingParticipant.update).toHaveBeenCalledWith({
        where: { id: 'tp-1' },
        data: { assignedConsultantId: null, status: 'PENDENTE' },
      });
    });

    it('lista nova com os mesmos consultores: ninguém é liberado', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(sessionWith(['c1', 'c2']));

      await service.updateSession('s1', { additionalConsultantsIds: ['c2'] });

      expect(mockPrisma.sessionConsultant.createMany).toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.findMany).not.toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.update).not.toHaveBeenCalled();
    });

    it('sem additionalConsultantsIds: não mexe em consultor nem em participante', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(sessionWith(['c1', 'c2']));

      await service.updateSession('s1', { city: 'Betim' });

      expect(mockPrisma.sessionConsultant.deleteMany).not.toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.findMany).not.toHaveBeenCalled();
    });
  });
});

describe('TrainingSessionsController: consultores da sessão', () => {
  const service = { addConsultant: jest.fn(), removeConsultant: jest.fn() };
  const controller = new TrainingSessionsController(
    service as unknown as TrainingSessionsService,
    {} as QrCodeService,
  );
  const reflector = new Reflector();

  it('POST :id/consultants passa a sessão e o consultor do corpo', () => {
    service.addConsultant.mockReturnValue('lista');

    expect(controller.addConsultant('s1', { consultantId: 'c2' })).toBe('lista');
    expect(service.addConsultant).toHaveBeenCalledWith('s1', 'c2');
  });

  it('DELETE :id/consultants/:consultantId passa a sessão e o consultor da rota', () => {
    service.removeConsultant.mockReturnValue('lista');

    expect(controller.removeConsultant('s1', 'c2')).toBe('lista');
    expect(service.removeConsultant).toHaveBeenCalledWith('s1', 'c2');
  });

  // Os testes acima chamam os métodos direto e passam por cima dos guards;
  // quem tranca as rotas é o metadado que o Nest lê. Mexer nos consultores de
  // uma sessão é só para ADMIN (decisão 1 da Fase 6B).
  it.each([
    ['addConsultant', TrainingSessionsController.prototype.addConsultant],
    ['removeConsultant', TrainingSessionsController.prototype.removeConsultant],
  ])('%s exige o papel ADMIN', (_name, handler) => {
    expect(reflector.get<string[]>(ROLES_KEY, handler)).toEqual(['ADMIN']);
  });

  it('a classe passa pelo JwtAuthGuard e, depois dele, pelo RolesGuard, que é quem lê o papel', () => {
    expect(reflector.get(GUARDS_METADATA, TrainingSessionsController)).toEqual([
      JwtAuthGuard,
      RolesGuard,
    ]);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd apps/backend && npx jest test/session-consultants.spec.ts`
Esperado: a suíte não compila — `TS2339: Property 'addConsultant' does not exist on type 'TrainingSessionsService'` (e `removeConsultant`, e os dois métodos do controller).

- [ ] **Step 3: Implementar**

**Criar `apps/backend/src/participants/participant-release.util.ts`:**

```typescript
import { Prisma } from '@prisma/client';
import { getApprovalStatus } from '@simtc/shared-types';

/**
 * Status de um participante que deixa de estar em avaliação sem ter sido
 * avaliado agora — foi desatribuído, ou o consultor que estava com ele saiu
 * do treinamento: `PENDENTE` se nunca foi avaliado, ou o status da nota da
 * avaliação anterior, numa reavaliação. Nota zero é nota: volta a
 * "Não recomendado", não a "Pendente".
 */
export function statusAfterRelease(previousScore: number | null | undefined) {
  return previousScore != null ? getApprovalStatus(previousScore) : 'PENDENTE';
}

/**
 * Libera os participantes do treinamento que estavam em avaliação com algum
 * dos consultores de `consultantIds`: ficam sem consultor e voltam ao status
 * de antes da atribuição (ver `statusAfterRelease`).
 *
 * É o que acontece quando um consultor sai do treinamento (decisão de
 * 06/10/2026, Fase 6B do app mobile): sem isso, o participante ficaria "em
 * avaliação" com alguém que não está mais lá, e ninguém mais conseguiria
 * pegá-lo. Chamar na MESMA transação que tira o vínculo do consultor.
 */
export async function releaseParticipantsOfConsultants(
  tx: Prisma.TransactionClient,
  trainingSessionId: string,
  consultantIds: string[],
): Promise<void> {
  if (consultantIds.length === 0) return;

  const held = await tx.trainingParticipant.findMany({
    where: {
      trainingSessionId,
      status: 'EM_AVALIACAO',
      assignedConsultantId: { in: consultantIds },
    },
    include: { assessment: { select: { score: true } } },
  });

  for (const participant of held) {
    await tx.trainingParticipant.update({
      where: { id: participant.id },
      data: {
        assignedConsultantId: null,
        status: statusAfterRelease(participant.assessment?.score),
      },
    });
  }
}
```

**Criar `apps/backend/src/training-sessions/dto/add-session-consultant.dto.ts`:**

```typescript
import { IsNotEmpty, IsString } from 'class-validator';

/** Corpo do `POST /training-sessions/:id/consultants`: quem entra na sessão. */
export class AddSessionConsultantDto {
  @IsString()
  @IsNotEmpty()
  consultantId!: string;
}
```

**Em `apps/backend/src/training-sessions/training-sessions.controller.ts`, substituir:**

```typescript
import { JwtPayload } from '@simtc/shared-types';
import { CreateTrainingSessionDto } from './dto/create-training-session.dto';
import { UpdateTrainingSessionDto } from './dto/update-training-session.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

@ApiTags('training-sessions')
```

**por:**

```typescript
import { JwtPayload } from '@simtc/shared-types';
import { CreateTrainingSessionDto } from './dto/create-training-session.dto';
import { UpdateTrainingSessionDto } from './dto/update-training-session.dto';
import { AddSessionConsultantDto } from './dto/add-session-consultant.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

@ApiTags('training-sessions')
```

**Em `apps/backend/src/training-sessions/training-sessions.controller.ts`, substituir:**

```typescript
  updateTrainingSession(@Param('id') id: string, @Body() dto: UpdateTrainingSessionDto) {
    return this.service.updateSession(id, dto);
  }
}
```

**por:**

```typescript
  updateTrainingSession(@Param('id') id: string, @Body() dto: UpdateTrainingSessionDto) {
    return this.service.updateSession(id, dto);
  }

  @Post(':id/consultants')
  @Roles('ADMIN' as any)
  @ApiOperation({ summary: 'Põe um consultor na sessão (app mobile) — devolve os consultores da sessão' })
  addConsultant(@Param('id') id: string, @Body() dto: AddSessionConsultantDto) {
    return this.service.addConsultant(id, dto.consultantId);
  }

  @Delete(':id/consultants/:consultantId')
  @Roles('ADMIN' as any)
  @ApiOperation({ summary: 'Tira um consultor da sessão e libera quem estava em avaliação com ele (app mobile) — devolve os consultores da sessão' })
  removeConsultant(@Param('id') id: string, @Param('consultantId') consultantId: string) {
    return this.service.removeConsultant(id, consultantId);
  }
}
```

**Em `apps/backend/src/training-sessions/training-sessions.service.ts`, substituir:**

```typescript
import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import * as fs from 'fs';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';
```

**por:**

```typescript
import { BadRequestException, Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import * as fs from 'fs';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';
```

**Em `apps/backend/src/training-sessions/training-sessions.service.ts`, substituir:**

```typescript
import { UpdateTrainingSessionDto } from './dto/update-training-session.dto';
import { PaginationDto } from '../common/dto/pagination.dto';
import { deleteOrphanedParticipants } from '../participants/participant-cleanup.util';

@Injectable()
export class TrainingSessionsService {
```

**por:**

```typescript
import { UpdateTrainingSessionDto } from './dto/update-training-session.dto';
import { PaginationDto } from '../common/dto/pagination.dto';
import { deleteOrphanedParticipants } from '../participants/participant-cleanup.util';
import { releaseParticipantsOfConsultants } from '../participants/participant-release.util';

@Injectable()
export class TrainingSessionsService {
```

**Em `apps/backend/src/training-sessions/training-sessions.service.ts`, substituir:**

```typescript
    });
  }

  async updateSession (id: string, dto: UpdateTrainingSessionDto) {
    const session = await this.findTrainingSessionById(id);

    if (session.status === 'CONCLUIDO' || session.status === 'CANCELADO') {
      throw new ForbiddenException('Não é possível editar um treinamento concluído ou cancelado');
    }

    return this.prisma.$transaction(async (tx) => {
      if(dto.additionalConsultantsIds !== undefined) {
```

**por:**

```typescript
    });
  }

  /** Sessão concluída ou cancelada não muda mais: nem os dados, nem os consultores. */
  private assertEditable(status: string) {
    if (status === 'CONCLUIDO' || status === 'CANCELADO') {
      throw new ForbiddenException('Não é possível editar um treinamento concluído ou cancelado');
    }
  }

  /**
   * Os consultores da sessão, no formato que o detalhe (`GET :id`) já devolve
   * em `consultants`, mais quem é o responsável. É a resposta das duas rotas
   * de consultor do app mobile.
   */
  private async consultantsOf(id: string, responsibleConsultantId: string | null) {
    const consultants = await this.prisma.sessionConsultant.findMany({
      where: { trainingSessionId: id },
      include: { consultant: { select: { id: true, name: true, email: true } } },
      orderBy: { consultant: { name: 'asc' } },
    });
    return { responsibleConsultantId, consultants };
  }

  /**
   * Põe um consultor na sessão (app mobile, Fase 6B). Repetir o pedido não é
   * erro: o app manda um consultor por vez e pode reenviar depois de uma
   * resposta que se perdeu.
   */
  async addConsultant(id: string, consultantId: string) {
    const session = await this.prisma.trainingSession.findUnique({
      where: { id },
      select: { status: true, responsibleConsultantId: true },
    });
    if (!session) {
      throw new NotFoundException('Sessão de treinamento não encontrada');
    }
    this.assertEditable(session.status);

    const consultant = await this.prisma.consultant.findUnique({
      where: { id: consultantId },
      select: { active: true },
    });
    if (!consultant) {
      throw new NotFoundException('Consultor não encontrado');
    }
    if (!consultant.active) {
      throw new BadRequestException('Consultor inativo não pode entrar em um treinamento');
    }

    await this.prisma.sessionConsultant.upsert({
      where: { trainingSessionId_consultantId: { trainingSessionId: id, consultantId } },
      create: { trainingSessionId: id, consultantId },
      update: {},
    });

    return this.consultantsOf(id, session.responsibleConsultantId);
  }

  /**
   * Tira um consultor da sessão (app mobile, Fase 6B) e, na mesma transação,
   * libera quem estava em avaliação com ele. O responsável não sai por aqui:
   * trocar o responsável é do painel (`PATCH :id`). Tirar quem já não estava
   * não é erro.
   */
  async removeConsultant(id: string, consultantId: string) {
    const session = await this.prisma.trainingSession.findUnique({
      where: { id },
      select: { status: true, responsibleConsultantId: true },
    });
    if (!session) {
      throw new NotFoundException('Sessão de treinamento não encontrada');
    }
    this.assertEditable(session.status);

    if (session.responsibleConsultantId === consultantId) {
      throw new BadRequestException(
        'O consultor responsável não pode ser removido do treinamento. Troque o responsável antes.',
      );
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.sessionConsultant.deleteMany({ where: { trainingSessionId: id, consultantId } });
      await releaseParticipantsOfConsultants(tx, id, [consultantId]);
    });

    return this.consultantsOf(id, session.responsibleConsultantId);
  }

  async updateSession (id: string, dto: UpdateTrainingSessionDto) {
    const session = await this.findTrainingSessionById(id);

    this.assertEditable(session.status);

    return this.prisma.$transaction(async (tx) => {
      if(dto.additionalConsultantsIds !== undefined) {
```

**Em `apps/backend/src/training-sessions/training-sessions.service.ts`, substituir:**

```typescript
            consultantId,
          })),
        });
      }

      return tx.trainingSession.update({
```

**por:**

```typescript
            consultantId,
          })),
        });

        // Quem ficou de fora da lista nova saiu da sessão: os participantes
        // que estavam em avaliação com ele são liberados (Fase 6B).
        const removedIds = session.consultants
          .map((link) => link.consultantId)
          .filter((consultantId) => !allConsultantIds.includes(consultantId));
        await releaseParticipantsOfConsultants(tx, id, removedIds);
      }

      return tx.trainingSession.update({
```

O `removeConsultant` tira o vínculo e libera os participantes na **mesma transação**: sem isso, uma falha no meio deixaria um participante "em avaliação" com quem já não está na sessão. O `ValidationPipe` global roda com `forbidNonWhitelisted`: o corpo do POST só pode ter `consultantId`.

- [ ] **Step 4: Rodar e ver passar**

Run: `cd apps/backend && npx jest test/session-consultants.spec.ts`
Esperado: `Tests: 21 passed, 21 total`.

- [ ] **Step 5: Suíte inteira e tipos**

Run: `cd apps/backend && npx jest` e `npx tsc --noEmit`
Esperado: `Tests: 12 failed, 93 passed, 105 total` — as 12 falhas antigas de `auth.service.spec.ts` e `participants.service.spec.ts` — e o `tsc` sem nenhuma saída.

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/backend/src/participants/participant-release.util.ts \
  apps/backend/src/training-sessions/dto/add-session-consultant.dto.ts \
  apps/backend/src/training-sessions/training-sessions.controller.ts \
  apps/backend/src/training-sessions/training-sessions.service.ts \
  apps/backend/test/session-consultants.spec.ts
git commit -m "feat(training-sessions): rotas de consultor da sessao e liberar participantes ao remover"
```

---

## Task 2: Backend — o ADMIN desatribui participante de qualquer consultor

O `POST /practical-assessments/unassign` só liberava os participantes do próprio consultor logado. O ⋮ do ADMIN no detalhe (decisão 12) precisa liberar quem está com **outro** consultor. A rota e o corpo não mudam; o service passa a receber o papel de quem chama. A conta de para onde o participante volta passa a ser a do `statusAfterRelease` da Task 1 — a mesma de antes, agora num lugar só.

**Files:**
- Modify: `apps/backend/src/practical-assessments/practical-assessments.controller.ts`
- Modify: `apps/backend/src/practical-assessments/practical-assessments.service.ts`
- Modify: `apps/backend/test/practical-assessments.service.spec.ts`

**Interfaces:**
- Consumes: `statusAfterRelease` (Task 1); `JwtPayload.role`; `resolveConsultantId`.
- Produces: `unassignParticipants(dto: AssignParticipantsDto, consultantIdFromJwt?: string, userId?: string, role?: string)`. Com `role === 'ADMIN'`: libera qualquer participante em `EM_AVALIACAO`, sem procurar o perfil de consultor de quem chama; `409 "Um ou mais participantes não estão em avaliação"` se algum não estiver. Para os outros papéis, nada muda (`409 "Um ou mais participantes não estão atribuídos a você"`). O controller passa `user.role`.

- [ ] **Step 1: Escrever os testes que falham**

**Em `apps/backend/test/practical-assessments.service.spec.ts`, substituir:**

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException } from '@nestjs/common';
import { PracticalAssessmentsService } from 'src/practical-assessments/practical-assessments.service';
import { PrismaService } from 'src/prisma/prisma.service';
import {
  calculateCategoryScore,
  calculateOverallScore,
  getApprovalStatus,
} from '@simtc/shared-types';

const mockPrisma = {
```

**por:**

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException } from '@nestjs/common';
import { PracticalAssessmentsController } from 'src/practical-assessments/practical-assessments.controller';
import { PracticalAssessmentsService } from 'src/practical-assessments/practical-assessments.service';
import { PrismaService } from 'src/prisma/prisma.service';
import {
  calculateCategoryScore,
  calculateOverallScore,
  getApprovalStatus,
  JwtPayload,
} from '@simtc/shared-types';

const mockPrisma = {
```

**Em `apps/backend/test/practical-assessments.service.spec.ts`, substituir:**

```typescript
        { where: { id: 'tp-1' }, data: { assignedConsultantId: null, status: 'NAO_RECOMENDADO' } },
      ]);
    });
  });

  // ─── syncFromMobile ──────────────────────────────────────────────────────
```

**por:**

```typescript
        { where: { id: 'tp-1' }, data: { assignedConsultantId: null, status: 'NAO_RECOMENDADO' } },
      ]);
    });

    it('ADMIN libera participante que está com outro consultor, sem precisar de perfil de consultor', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'outro-consultor', assessment: null },
        { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'mais-um', assessment: { score: 90 } },
      ]);
      mockPrisma.trainingParticipant.update.mockImplementation((args) => args);
      mockPrisma.$transaction.mockResolvedValue([]);

      // Sem `consultantId` no token: só o papel. Se o serviço fosse procurar o
      // perfil de consultor do usuário, o mock (que não tem `user`) estouraria.
      const result = await service.unassignParticipants(
        { participantIds: ['tp-1', 'tp-2'] },
        undefined,
        'user-admin',
        'ADMIN',
      );

      expect(result).toEqual({ unassigned: 2 });
      expect(mockPrisma.$transaction).toHaveBeenCalledWith([
        { where: { id: 'tp-1' }, data: { assignedConsultantId: null, status: 'PENDENTE' } },
        { where: { id: 'tp-2' }, data: { assignedConsultantId: null, status: 'APROVADO' } },
      ]);
    });

    it('ADMIN: quem não está em avaliação não tem o que liberar', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'PENDENTE', assignedConsultantId: null, assessment: null },
      ]);

      await expect(
        service.unassignParticipants({ participantIds: ['tp-1'] }, undefined, 'user-admin', 'ADMIN'),
      ).rejects.toThrow('Um ou mais participantes não estão em avaliação');
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    it('o papel de consultor não libera participante de outro consultor', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'outro-consultor', assessment: null },
      ]);

      await expect(
        service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor', 'user-1', 'CONSULTANT'),
      ).rejects.toThrow('Um ou mais participantes não estão atribuídos a você');
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });
  });

  // ─── syncFromMobile ──────────────────────────────────────────────────────
```

**Em `apps/backend/test/practical-assessments.service.spec.ts`, substituir:**

```typescript
  });
});
```

**por:**

```typescript
  });
});

describe('PracticalAssessmentsController.unassign', () => {
  it('passa o papel de quem pediu: é ele que deixa o ADMIN liberar participante de outro consultor', () => {
    const service = { unassignParticipants: jest.fn().mockReturnValue('ok') };
    const controller = new PracticalAssessmentsController(
      service as unknown as PracticalAssessmentsService,
    );
    const dto = { participantIds: ['tp-1'] };
    const admin = { sub: 'user-admin', email: 'admin@sim.com', role: 'ADMIN' } as JwtPayload;

    expect(controller.unassign(dto, admin)).toBe('ok');
    expect(service.unassignParticipants).toHaveBeenCalledWith(dto, undefined, 'user-admin', 'ADMIN');
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd apps/backend && npx jest test/practical-assessments.service.spec.ts`
Esperado: a suíte não compila — `TS2554: Expected 1-3 arguments, but got 4.` nas chamadas de `unassignParticipants` com o papel.

- [ ] **Step 3: Implementar**

**Em `apps/backend/src/practical-assessments/practical-assessments.controller.ts`, substituir:**

```typescript
  }

  @Post('unassign')
  @ApiOperation({ summary: 'Libera participantes atribuídos ao consultor logado (voltam ao status anterior)' })
  unassign(@Body() dto: AssignParticipantsDto, @CurrentUser() user: JwtPayload) {
    return this.service.unassignParticipants(dto, user.consultantId, user.sub);
  }

  @Post('sync')
```

**por:**

```typescript
  }

  @Post('unassign')
  @ApiOperation({ summary: 'Libera participantes em avaliação (voltam ao status anterior) — o consultor, os dele; o ADMIN, os de qualquer consultor' })
  unassign(@Body() dto: AssignParticipantsDto, @CurrentUser() user: JwtPayload) {
    return this.service.unassignParticipants(dto, user.consultantId, user.sub, user.role);
  }

  @Post('sync')
```

**Em `apps/backend/src/practical-assessments/practical-assessments.service.ts`, substituir:**

```typescript
import { SyncPracticalAssessmentDto } from '@simtc/shared-types';
import { AssignParticipantsDto } from './dto/assign-participants.dto';
import { calculateCategoryScore, calculateOverallScore, getApprovalStatus } from '@simtc/shared-types';

@Injectable()
export class PracticalAssessmentsService {
```

**por:**

```typescript
import { SyncPracticalAssessmentDto } from '@simtc/shared-types';
import { AssignParticipantsDto } from './dto/assign-participants.dto';
import { calculateCategoryScore, calculateOverallScore, getApprovalStatus } from '@simtc/shared-types';
import { statusAfterRelease } from '../participants/participant-release.util';

@Injectable()
export class PracticalAssessmentsService {
```

**Em `apps/backend/src/practical-assessments/practical-assessments.service.ts`, substituir:**

```typescript
  }

  /**
   * Libera participantes atribuídos ao consultor logado (o "Desatribuir" do
   * app mobile). Só quem está com o participante pode liberá-lo; ele volta ao
   * status de antes da atribuição: `PENDENTE` se nunca foi avaliado, ou o
   * status da nota da avaliação anterior numa reavaliação.
   */
  async unassignParticipants(dto: AssignParticipantsDto, consultantIdFromJwt?: string, userId?: string) {
    const consultantId = await this.resolveConsultantId(consultantIdFromJwt, userId);
    const records = await this.prisma.trainingParticipant.findMany({
      where: { id: { in: dto.participantIds } },
      include: { assessment: { select: { score: true } } },
```

**por:**

```typescript
  }

  /**
   * Libera participantes em avaliação (o "Desatribuir" do app mobile). O
   * consultor só libera os que estão com ele; o ADMIN libera os de qualquer
   * consultor (Fase 6B do app) e não precisa ter perfil de consultor. O
   * participante volta ao status de antes da atribuição: `PENDENTE` se nunca
   * foi avaliado, ou o status da nota da avaliação anterior numa reavaliação.
   */
  async unassignParticipants(
    dto: AssignParticipantsDto,
    consultantIdFromJwt?: string,
    userId?: string,
    role?: string,
  ) {
    const isAdmin = role === 'ADMIN';
    const consultantId = isAdmin
      ? undefined
      : await this.resolveConsultantId(consultantIdFromJwt, userId);
    const records = await this.prisma.trainingParticipant.findMany({
      where: { id: { in: dto.participantIds } },
      include: { assessment: { select: { score: true } } },
```

**Em `apps/backend/src/practical-assessments/practical-assessments.service.ts`, substituir:**

```typescript
      throw new ConflictException('Um ou mais participantes não foram encontrados');
    }

    const notMine = records.filter(
      (r) => r.status !== 'EM_AVALIACAO' || r.assignedConsultantId !== consultantId,
    );
    if (notMine.length > 0) {
      throw new ConflictException('Um ou mais participantes não estão atribuídos a você');
    }

    await this.prisma.$transaction(
      records.map((r) => {
        const score = r.assessment?.score;
        return this.prisma.trainingParticipant.update({
          where: { id: r.id },
          data: {
            assignedConsultantId: null,
            status: score != null ? getApprovalStatus(score) : 'PENDENTE',
          },
        });
      }),
    );

    return { unassigned: records.length };
```

**por:**

```typescript
      throw new ConflictException('Um ou mais participantes não foram encontrados');
    }

    if (isAdmin) {
      if (records.some((r) => r.status !== 'EM_AVALIACAO')) {
        throw new ConflictException('Um ou mais participantes não estão em avaliação');
      }
    } else {
      const notMine = records.filter(
        (r) => r.status !== 'EM_AVALIACAO' || r.assignedConsultantId !== consultantId,
      );
      if (notMine.length > 0) {
        throw new ConflictException('Um ou mais participantes não estão atribuídos a você');
      }
    }

    await this.prisma.$transaction(
      records.map((r) =>
        this.prisma.trainingParticipant.update({
          where: { id: r.id },
          data: {
            assignedConsultantId: null,
            status: statusAfterRelease(r.assessment?.score),
          },
        }),
      ),
    );

    return { unassigned: records.length };
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd apps/backend && npx jest test/practical-assessments.service.spec.ts`
Esperado: `Tests: 25 passed, 25 total`.

- [ ] **Step 5: Suíte inteira e tipos**

Run: `cd apps/backend && npx jest` e `npx tsc --noEmit`
Esperado: `Tests: 12 failed, 97 passed, 109 total` e o `tsc` sem nenhuma saída.

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/backend/src/practical-assessments/practical-assessments.controller.ts \
  apps/backend/src/practical-assessments/practical-assessments.service.ts \
  apps/backend/test/practical-assessments.service.spec.ts
git commit -m "feat(practical-assessments): admin desatribui participante de qualquer consultor"
```

---

## Task 3: Backend — o `sync` só aceita a avaliação de quem está com o participante

Até aqui o `sync` não conferia nada: gravava a avaliação de qualquer consultor para qualquer participante. Com as Tasks 1 e 2, um participante pode sair das mãos de um consultor com a avaliação pela metade — e o envio tardio dele sobrescreveria o trabalho de quem assumiu. A regra nova (decisão 2): só é gravada a avaliação de um participante que está `EM_AVALIACAO` com quem envia. A exceção é o reenvio (decisão 10): se o primeiro envio já foi aceito, o participante não está mais "em avaliação", e o app pode tentar de novo por ter perdido a resposta — reconhecido pela avaliação já gravada, do mesmo consultor e com a mesma hora de início.

A recusa leva um código (`NOT_ASSIGNED`), para o app mostrar um motivo próprio na aba Sincronizar (Task 12).

**Files:**
- Create: `apps/backend/src/practical-assessments/sync-refused.exception.ts`
- Modify: `apps/backend/src/practical-assessments/practical-assessments.service.ts`
- Modify: `apps/backend/test/practical-assessments.service.spec.ts`
- Modify: `apps/mobile/docs/fase-0-auditoria.md`

**Interfaces:**
- Consumes: `PrismaService.trainingParticipant.findUnique`; o `existing` que o `syncOne` já lê (a avaliação gravada do participante); `ConflictException`.
- Produces:
  - `SYNC_REFUSAL_NOT_ASSIGNED = 'NOT_ASSIGNED'` e `class SyncRefusedException extends ConflictException { constructor(readonly code: string, message: string) }`.
  - `POST /api/practical-assessments/sync` → cada item da resposta passa a ser `{ trainingParticipantId, status: 'fulfilled' | 'rejected', error?, code? }`. Participante que não está em avaliação com quem envia: `rejected`, `error: "Este participante não está mais em avaliação com você. A avaliação não foi registrada."`, `code: "NOT_ASSIGNED"`. Reenvio da avaliação já gravada: `fulfilled`, sem regravar. Participante que não existe: `rejected`, `error: "Participante não encontrado"`, sem `code`.

- [ ] **Step 1: Escrever os testes que falham**

**Em `apps/backend/test/practical-assessments.service.spec.ts`, substituir:**

```typescript

const mockPrisma = {
  practicalAssessment: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn(), findUniqueOrThrow: jest.fn() },
  trainingParticipant: { findMany: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
  assessmentItem: { deleteMany: jest.fn() },
  assessmentCategory: { findMany: jest.fn() },
  $transaction: jest.fn(),
```

**por:**

```typescript

const mockPrisma = {
  practicalAssessment: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn(), findUniqueOrThrow: jest.fn() },
  trainingParticipant: { findMany: jest.fn(), findUnique: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
  assessmentItem: { deleteMany: jest.fn() },
  assessmentCategory: { findMany: jest.fn() },
  $transaction: jest.fn(),
```

**Em `apps/backend/test/practical-assessments.service.spec.ts`, substituir:**

```typescript
    beforeEach(() => {
      mockPrisma.assessmentCategory.findMany.mockResolvedValue([]);
      mockPrisma.$transaction.mockResolvedValue([]);
    });

    it('sincroniza uma avaliação nova com sucesso', async () => {
```

**por:**

```typescript
    beforeEach(() => {
      mockPrisma.assessmentCategory.findMany.mockResolvedValue([]);
      mockPrisma.$transaction.mockResolvedValue([]);
      // Quem envia está com o participante: é o caso de todo envio normal.
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
        status: 'EM_AVALIACAO',
        assignedConsultantId: 'consultant-1',
      });
    });

    it('sincroniza uma avaliação nova com sucesso', async () => {
```

**Em `apps/backend/test/practical-assessments.service.spec.ts`, substituir:**

```typescript
        { trainingParticipantId: 'tp-1', status: 'rejected', error: 'falha no banco' },
      ]);
    });
  });
});
```

**por:**

```typescript
        { trainingParticipantId: 'tp-1', status: 'rejected', error: 'falha no banco' },
      ]);
    });

    // Só envia avaliação quem está com o participante (decisão 2 da Fase 6B do
    // app mobile): quem foi removido do treinamento, ou desatribuído pelo
    // ADMIN, não grava mais nada — nem por cima da avaliação de quem assumiu.
    describe('quem não está com o participante', () => {
      const refused = {
        trainingParticipantId: 'tp-1',
        status: 'rejected',
        error: 'Este participante não está mais em avaliação com você. A avaliação não foi registrada.',
        code: 'NOT_ASSIGNED',
      };

      it.each([
        ['foi liberado e voltou a Pendente', { status: 'PENDENTE', assignedConsultantId: null }],
        ['está em avaliação com outro consultor', { status: 'EM_AVALIACAO', assignedConsultantId: 'consultant-2' }],
        ['já foi avaliado por outro consultor', { status: 'APROVADO', assignedConsultantId: null }],
        ['está em avaliação sem consultor na linha', { status: 'EM_AVALIACAO', assignedConsultantId: null }],
        ['já tem nota, com o consultor ainda na linha', { status: 'APROVADO', assignedConsultantId: 'consultant-1' }],
      ])('%s: recusa com o código, sem gravar nada', async (_caso, participant) => {
        mockPrisma.trainingParticipant.findUnique.mockResolvedValue(participant);
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result).toEqual([refused]);
        expect(mockPrisma.practicalAssessment.create).not.toHaveBeenCalled();
        expect(mockPrisma.practicalAssessment.update).not.toHaveBeenCalled();
        expect(mockPrisma.assessmentItem.deleteMany).not.toHaveBeenCalled();
        expect(mockPrisma.$transaction).not.toHaveBeenCalled();
      });

      it('não sobrescreve a avaliação que outro consultor gravou depois', async () => {
        mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
          status: 'APROVADO',
          assignedConsultantId: null,
        });
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue({
          id: 'assess-1',
          consultantId: 'consultant-2',
          startTime: new Date('2026-09-17T10:00:00.000Z'),
        });

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result).toEqual([refused]);
        expect(mockPrisma.practicalAssessment.update).not.toHaveBeenCalled();
        expect(mockPrisma.assessmentItem.deleteMany).not.toHaveBeenCalled();
      });

      it('reenvio da mesma avaliação (a resposta do primeiro envio se perdeu): aceita sem regravar', async () => {
        // O primeiro envio foi aceito: o participante já tem a nota e ficou sem consultor.
        mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
          status: 'APROVADO',
          assignedConsultantId: null,
        });
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue({
          id: 'assess-1',
          consultantId: 'consultant-1',
          startTime: new Date('2026-09-17T10:00:00.000Z'),
        });

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result).toEqual([{ trainingParticipantId: 'tp-1', status: 'fulfilled' }]);
        expect(mockPrisma.practicalAssessment.update).not.toHaveBeenCalled();
        expect(mockPrisma.assessmentItem.deleteMany).not.toHaveBeenCalled();
        expect(mockPrisma.$transaction).not.toHaveBeenCalled();
      });

      it('avaliação antiga do mesmo consultor, com outra hora de início, não conta como reenvio', async () => {
        mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
          status: 'NAO_RECOMENDADO',
          assignedConsultantId: null,
        });
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue({
          id: 'assess-1',
          consultantId: 'consultant-1',
          startTime: new Date('2026-09-10T08:00:00.000Z'),
        });

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result).toEqual([refused]);
        expect(mockPrisma.practicalAssessment.update).not.toHaveBeenCalled();
      });

      it('participante que não existe: recusa, sem o código', async () => {
        mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result).toEqual([
          { trainingParticipantId: 'tp-1', status: 'rejected', error: 'Participante não encontrado' },
        ]);
        expect(mockPrisma.practicalAssessment.create).not.toHaveBeenCalled();
      });
    });

    it('confere quem está com o participante pela linha dele', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);
      mockPrisma.practicalAssessment.create.mockResolvedValue({ id: 'assess-1', items: [] });

      await service.syncFromMobile([dto], 'consultant-1');

      expect(mockPrisma.trainingParticipant.findUnique).toHaveBeenCalledWith({
        where: { id: 'tp-1' },
        select: { status: true, assignedConsultantId: true },
      });
    });

    it('num lote, recusa só a avaliação de quem não está com o participante', async () => {
      const outro = { ...dto, trainingParticipantId: 'tp-2' };
      mockPrisma.trainingParticipant.findUnique.mockImplementation(
        ({ where }: { where: { id: string } }) =>
          Promise.resolve(
            where.id === 'tp-1'
              ? { status: 'EM_AVALIACAO', assignedConsultantId: 'consultant-1' }
              : { status: 'PENDENTE', assignedConsultantId: null },
          ),
      );
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);
      mockPrisma.practicalAssessment.create.mockResolvedValue({ id: 'assess-1', items: [] });

      const result = await service.syncFromMobile([dto, outro], 'consultant-1');

      expect(result).toEqual([
        { trainingParticipantId: 'tp-1', status: 'fulfilled' },
        expect.objectContaining({
          trainingParticipantId: 'tp-2',
          status: 'rejected',
          code: 'NOT_ASSIGNED',
        }),
      ]);
      expect(mockPrisma.practicalAssessment.create).toHaveBeenCalledTimes(1);
    });
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd apps/backend && npx jest test/practical-assessments.service.spec.ts`
Esperado: 8 testes novos falham, todos do grupo `quem não está com o participante` — o `sync` ainda grava a avaliação sem conferir com quem o participante está. Os demais passam.

- [ ] **Step 3: Implementar**

**Em `apps/backend/src/practical-assessments/practical-assessments.service.ts`, substituir:**

```typescript
import { AssignParticipantsDto } from './dto/assign-participants.dto';
import { calculateCategoryScore, calculateOverallScore, getApprovalStatus } from '@simtc/shared-types';
import { statusAfterRelease } from '../participants/participant-release.util';

@Injectable()
export class PracticalAssessmentsService {
```

**por:**

```typescript
import { AssignParticipantsDto } from './dto/assign-participants.dto';
import { calculateCategoryScore, calculateOverallScore, getApprovalStatus } from '@simtc/shared-types';
import { statusAfterRelease } from '../participants/participant-release.util';
import { SYNC_REFUSAL_NOT_ASSIGNED, SyncRefusedException } from './sync-refused.exception';

@Injectable()
export class PracticalAssessmentsService {
```

**Em `apps/backend/src/practical-assessments/practical-assessments.service.ts`, substituir:**

```typescript
      trainingParticipantId: dtos[i].trainingParticipantId,
      status: r.status,
      error: r.status === 'rejected' ? (r.reason as Error).message : undefined,
    }));
  }
```

**por:**

```typescript
      trainingParticipantId: dtos[i].trainingParticipantId,
      status: r.status,
      error: r.status === 'rejected' ? (r.reason as Error).message : undefined,
      // Só a recusa que o app mobile trata à parte leva código.
      code:
        r.status === 'rejected' && r.reason instanceof SyncRefusedException
          ? r.reason.code
          : undefined,
    }));
  }
```

**Em `apps/backend/src/practical-assessments/practical-assessments.service.ts`, substituir:**

```typescript
    const existing = await this.prisma.practicalAssessment.findUnique({
      where: { trainingParticipantId: dto.trainingParticipantId },
    });

    if (existing) {
      // Reavaliação: apaga os itens anteriores e atualiza o registro
```

**por:**

```typescript
    const existing = await this.prisma.practicalAssessment.findUnique({
      where: { trainingParticipantId: dto.trainingParticipantId },
    });

    // Só envia avaliação quem está com o participante (Fase 6B do app
    // mobile). Quem foi removido do treinamento, ou desatribuído pelo ADMIN,
    // com a avaliação em andamento não grava mais nada: o participante voltou
    // para a fila, e outro consultor pode já ter assumido — ou avaliado.
    const participant = await this.prisma.trainingParticipant.findUnique({
      where: { id: dto.trainingParticipantId },
      select: { status: true, assignedConsultantId: true },
    });
    if (!participant) {
      throw new ConflictException('Participante não encontrado');
    }
    const isWithSender =
      participant.status === 'EM_AVALIACAO' && participant.assignedConsultantId === consultantId;
    if (!isWithSender) {
      // Reenvio: o primeiro envio desta mesma avaliação já foi aceito (por
      // isso o participante não está mais "em avaliação"), mas a resposta se
      // perdeu e o app tentou de novo. Não há o que regravar.
      const alreadySaved =
        existing != null &&
        existing.consultantId === consultantId &&
        existing.startTime.getTime() === new Date(dto.startTime).getTime();
      if (alreadySaved) return existing;

      throw new SyncRefusedException(
        SYNC_REFUSAL_NOT_ASSIGNED,
        'Este participante não está mais em avaliação com você. A avaliação não foi registrada.',
      );
    }

    if (existing) {
      // Reavaliação: apaga os itens anteriores e atualiza o registro
```

**Criar `apps/backend/src/practical-assessments/sync-refused.exception.ts`:**

```typescript
import { ConflictException } from '@nestjs/common';

/**
 * Código da recusa "o participante não está mais com quem enviou". O app
 * mobile o reconhece para mostrar um motivo próprio na aba Sincronizar, no
 * lugar do genérico "recusada pelo servidor".
 */
export const SYNC_REFUSAL_NOT_ASSIGNED = 'NOT_ASSIGNED';

/**
 * Recusa de uma avaliação no `POST /practical-assessments/sync` que leva um
 * código além da mensagem. O código sai no item da resposta (`code`), ao lado
 * de `error`.
 */
export class SyncRefusedException extends ConflictException {
  constructor(
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd apps/backend && npx jest test/practical-assessments.service.spec.ts`
Esperado: `Tests: 36 passed, 36 total`.

- [ ] **Step 5: Suíte inteira e tipos**

Run: `cd apps/backend && npx jest` e `npx tsc --noEmit`
Esperado: `Tests: 12 failed, 108 passed, 120 total` e o `tsc` sem nenhuma saída.

- [ ] **Step 6: Registrar na auditoria da Fase 0**

A auditoria é leitura obrigatória antes de planejar cada fase, e diz que o `sync` não valida a atribuição. Em `apps/mobile/docs/fase-0-auditoria.md`, no fim da seção 2.2, substituir:

```markdown
**Nota de 07/10/2026:** a Fase 6A criou a consulta de participante por CPF que faltava: `POST /api/training-sessions/:id/participants/lookup` (só ADMIN; corpo `{ cpf }` → `{ registered, name, email, enrolled }`). O `POST /training-sessions/:id/participants` continua como descrito acima: deduplica por CPF e sobrescreve o `name` do cadastro.

### 2.3 Testes do backend
```

por:

```markdown
**Nota de 07/10/2026:** a Fase 6A criou a consulta de participante por CPF que faltava: `POST /api/training-sessions/:id/participants/lookup` (só ADMIN; corpo `{ cpf }` → `{ registered, name, email, enrolled }`). O `POST /training-sessions/:id/participants` continua como descrito acima: deduplica por CPF e sobrescreve o `name` do cadastro.

**Nota de 10/10/2026:** a Fase 6B mudou três pontos do backend. (1) Entraram `POST /api/training-sessions/:id/consultants` (corpo `{ consultantId }`) e `DELETE /api/training-sessions/:id/consultants/:consultantId`, só ADMIN: um consultor por chamada, e as duas devolvem `{ responsibleConsultantId, consultants }`. O `PATCH /training-sessions/:id` com `additionalConsultantsIds` continua como descrito acima. Tirar um consultor da sessão — pela rota nova ou pelo `PATCH` — libera quem estava em avaliação com ele: o participante fica sem consultor e volta para `PENDENTE`, ou para o status da nota anterior, numa reavaliação. (2) O `POST /practical-assessments/unassign` aceita que um ADMIN libere o participante de qualquer consultor. (3) O `sync` passou a conferir a atribuição — a primeira linha "5" acima deixou de valer: a avaliação de um participante que não está em avaliação com quem envia é recusada, e o item rejeitado ganha `code: 'NOT_ASSIGNED'`; reenviar a mesma avaliação (mesmo consultor e mesma hora de início) continua sendo aceito, sem regravar. O painel web ainda não lê o resultado item a item (pendência "Web" do plano da 6B).

### 2.3 Testes do backend
```

- [ ] **Step 7: Commit**

A partir da raiz do repositório:

```bash
git add apps/backend/src/practical-assessments/practical-assessments.service.ts \
  apps/backend/src/practical-assessments/sync-refused.exception.ts \
  apps/backend/test/practical-assessments.service.spec.ts \
  apps/mobile/docs/fase-0-auditoria.md
git commit -m "feat(practical-assessments): sync recusa avaliacao de quem nao esta com o participante"
```

---

## Task 4: Banco v5 — os consultores da sessão no cache

A tela de Consultores e o "N consultores" do detalhe precisam abrir sem conexão, como o resto do detalhe. Os consultores já vêm no corpo do `GET /training-sessions/:id` que o app baixa ao abrir a sessão (`consultants[]` e `responsibleConsultant`): falta guardá-los. Entra uma tabela, e o esquema do banco vai de v4 para v5, com uma migração que só cria a tabela — vazia; o próximo download do detalhe a preenche.

A linha some junto com a sessão (`ON DELETE CASCADE`), e por isso quem já apaga sessões do cache — a Home, ao tirar o que saiu da agenda, e a troca de usuário — não muda.

**Files:**
- Create: `lib/data/models/session_consultant.dart`
- Create: `test/data/models/session_consultant_test.dart`
- Modify: `lib/data/services/local/tables.dart`
- Modify: `lib/data/services/local/app_database.dart`
- Modify: `lib/data/services/local/app_database.g.dart` (gerado pelo `build_runner`)
- Modify: `lib/data/repositories/participant_repository.dart`
- Modify: `test/data/repositories/participant_repository_test.dart`
- Modify: `test/data/repositories/session_repository_test.dart`
- Modify: `test/data/services/local/app_database_test.dart`

**Interfaces:**
- Consumes: o corpo do `GET /training-sessions/:id` (`consultants[].consultant { id, name, email }` e `responsibleConsultant`); `ParticipantRepository.syncSession` e o `_write` dela; `AppDatabase.migration`.
- Produces:
  - Tabela `SessionConsultants` (classe de linha `SessionConsultantRow`): `sessionId` (referência a `Sessions.id`, apagada em cascata), `consultantId`, `name`, `email` (nulo permitido); chave primária `{sessionId, consultantId}`. `AppDatabase.schemaVersion` = 5.
  - `Future<void> AppDatabase.replaceSessionConsultants(String sessionId, Iterable<SessionConsultantsCompanion> rows)` — troca os consultores daquela sessão; entra na transação de quem chama.
  - `class SessionConsultant { final String id; final String name; final String? email; }` (o `id` é o `Consultant.id`), com `static SessionConsultant? tryParse(Object? json)`, `static List<SessionConsultant>? listFromJson(Map<String, dynamic> body)` (nulo se `consultants` não vier como lista), `factory SessionConsultant.fromRow(SessionConsultantRow row)`, `SessionConsultantsCompanion toCompanion(String sessionId)`, e `==`/`hashCode` por valor.
  - `ParticipantRepository.syncSession` passa a gravar também os consultores, na mesma transação.

- [ ] **Step 1: Escrever os testes que falham**

**Criar `test/data/models/session_consultant_test.dart`:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/session_consultant.dart';

void main() {
  Map<String, dynamic> link(String id, String name, {Object? email}) {
    return {
      'trainingSessionId': 'sess-1',
      'consultantId': id,
      'consultant': {'id': id, 'name': name, 'email': email},
    };
  }

  group('SessionConsultant.listFromJson', () {
    test('lê os consultores de consultants[].consultant, na ordem em que vêm',
        () {
      final list = SessionConsultant.listFromJson({
        'responsibleConsultantId': 'c-1',
        'consultants': [
          link('c-2', 'Rafael Lima', email: 'rafael@sim.com'),
          link('c-1', 'Carla Mendes', email: 'carla@sim.com'),
        ],
      });

      expect(list, const [
        SessionConsultant(id: 'c-2', name: 'Rafael Lima', email: 'rafael@sim.com'),
        SessionConsultant(id: 'c-1', name: 'Carla Mendes', email: 'carla@sim.com'),
      ]);
    });

    test('sem a lista de consultores, devolve nulo — e não uma lista vazia', () {
      expect(SessionConsultant.listFromJson({'id': 'sess-1'}), isNull);
      expect(
        SessionConsultant.listFromJson({'consultants': 'quebrado'}),
        isNull,
      );
      expect(SessionConsultant.listFromJson({'consultants': <dynamic>[]}), isEmpty);
    });

    test('o responsável entra mesmo sem o vínculo dele na lista', () {
      final list = SessionConsultant.listFromJson({
        'responsibleConsultantId': 'c-1',
        'responsibleConsultant': {
          'id': 'c-1',
          'name': 'Carla Mendes',
          'email': 'carla@sim.com',
        },
        'consultants': [link('c-2', 'Rafael Lima')],
      });

      expect(list!.map((c) => c.id), ['c-2', 'c-1']);
    });

    test('o responsável que já está na lista não entra duas vezes', () {
      final list = SessionConsultant.listFromJson({
        'responsibleConsultant': {'id': 'c-1', 'name': 'Carla Mendes'},
        'consultants': [
          link('c-1', 'Carla Mendes', email: 'carla@sim.com'),
          link('c-1', 'Carla Mendes', email: 'carla@sim.com'),
        ],
      });

      expect(list, const [
        SessionConsultant(id: 'c-1', name: 'Carla Mendes', email: 'carla@sim.com'),
      ]);
    });

    test('ignora o que vier sem id ou sem nome; e-mail em branco vira nulo', () {
      final list = SessionConsultant.listFromJson({
        'consultants': [
          link('', 'Sem Id'),
          link('c-3', '   '),
          {'consultantId': 'c-4'},
          'lixo',
          link('c-5', '  Tatiane Souza ', email: '   '),
          link('c-6', 'Diego Barbosa', email: 42),
        ],
      });

      expect(list, const [
        SessionConsultant(id: 'c-5', name: 'Tatiane Souza'),
        SessionConsultant(id: 'c-6', name: 'Diego Barbosa'),
      ]);
    });
  });
}
```

**Em `test/data/repositories/participant_repository_test.dart`, substituir:**

```dart
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
```

**por:**

```dart
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
```

**Em `test/data/repositories/participant_repository_test.dart`, substituir:**

```dart
    };
  }

  /// O detalhe como `findTrainingSessionById` devolve (`company: true`, por
  /// isso o logo vem junto).
  Map<String, dynamic> detailJson(List<Map<String, dynamic>> participants) {
    return {
      'id': 'sess-1',
      'responsibleConsultantId': 'c-resp',
      'city': 'Itabira',
```

**por:**

```dart
    };
  }

  /// Um vínculo de `consultants[]` do detalhe (`include: { consultant: true }`).
  Map<String, dynamic> consultantLink(String id, String name, {String? email}) {
    return {
      'trainingSessionId': 'sess-1',
      'consultantId': id,
      'consultant': {'id': id, 'name': name, 'email': email, 'active': true},
    };
  }

  /// O detalhe como `findTrainingSessionById` devolve (`company: true`, por
  /// isso o logo vem junto). Sem [consultants], o corpo nem traz a chave.
  Map<String, dynamic> detailJson(
    List<Map<String, dynamic>> participants, {
    List<Map<String, dynamic>>? consultants,
  }) {
    return {
      if (consultants != null) 'consultants': consultants,
      'id': 'sess-1',
      'responsibleConsultantId': 'c-resp',
      'city': 'Itabira',
```

**Em `test/data/repositories/participant_repository_test.dart`, substituir:**

```dart
      expect(session.participantsSyncedAt, isNotNull);
      expect(session.cachedAt, DateTime(2026, 9, 22, 8),
          reason: 'a idade da agenda da Home não muda por abrir uma sessão');
    });

    test('quem saiu da sessão no servidor sai do cache', () async {
```

**por:**

```dart
      expect(session.participantsSyncedAt, isNotNull);
      expect(session.cachedAt, DateTime(2026, 9, 22, 8),
          reason: 'a idade da agenda da Home não muda por abrir uma sessão');
    });

    test('grava os consultores da sessão que vêm no detalhe', () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson(
          [participantJson('tp-1')],
          consultants: [
            consultantLink('c-resp', 'Carla Mendes', email: 'carla@sim.com'),
            consultantLink('c-2', 'Rafael Lima'),
          ],
        )),
      );

      await repository.syncSession('sess-1');

      final rows = await (db.select(db.sessionConsultants)
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();
      expect(rows.map((r) => r.sessionId), everyElement('sess-1'));
      expect(rows.map((r) => (r.consultantId, r.name, r.email)), [
        ('c-resp', 'Carla Mendes', 'carla@sim.com'),
        ('c-2', 'Rafael Lima', null),
      ]);
    });

    test('o consultor que saiu da sessão no servidor sai do cache', () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson(
          const [],
          consultants: [
            consultantLink('c-resp', 'Carla Mendes'),
            consultantLink('c-2', 'Rafael Lima'),
          ],
        )),
      );
      await repository.syncSession('sess-1');

      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson(
          const [],
          consultants: [
            consultantLink('c-resp', 'Carla Mendes'),
            consultantLink('c-3', 'Tatiane Souza'),
          ],
        )),
      );
      await repository.syncSession('sess-1');

      final rows = await db.select(db.sessionConsultants).get();
      expect(rows.map((r) => r.consultantId).toSet(), {'c-resp', 'c-3'});
    });

    test('detalhe sem a lista de consultores não apaga os que estão no cache',
        () async {
      await seedSession();
      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson(
          const [],
          consultants: [consultantLink('c-resp', 'Carla Mendes')],
        )),
      );
      await repository.syncSession('sess-1');

      when(() => api.get<Map<String, dynamic>>(detailPath)).thenAnswer(
        (_) async => ok(detailJson([participantJson('tp-1')])),
      );
      final result = await repository.syncSession('sess-1');

      expect(result.dataOrNull, 1);
      final rows = await db.select(db.sessionConsultants).get();
      expect(rows.map((r) => r.consultantId), ['c-resp']);
    });

    test('quem saiu da sessão no servidor sai do cache', () async {
```

**Em `test/data/repositories/session_repository_test.dart`, substituir:**

```dart

    final ids = (await db.select(db.sessions).get()).map((r) => r.id).toList();
    expect(ids, ['s2']);
  });

  test('falha de rede preserva o que já estava no cache', () async {
```

**por:**

```dart

    final ids = (await db.select(db.sessions).get()).map((r) => r.id).toList();
    expect(ids, ['s2']);
  });

  test('a sessão que sumiu do servidor leva os consultores dela do cache',
      () async {
    // Os consultores têm chave estrangeira para a sessão (Fase 6B): se não
    // saíssem junto, apagar a sessão derrubaria a transação inteira do sync.
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page(
              [sessionJson('s1'), sessionJson('s2')],
              pageNumber: 1,
              totalPages: 1,
            ));
    await repository.syncAll();
    for (final sessionId in ['s1', 's2']) {
      await db.into(db.sessionConsultants).insert(
            SessionConsultantsCompanion.insert(
              sessionId: sessionId,
              consultantId: 'c-1',
              name: 'Carla Mendes',
            ),
          );
    }

    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('s2')], pageNumber: 1, totalPages: 1));
    final result = await repository.syncAll();

    expect(result.isSuccess, isTrue);
    final rows = await db.select(db.sessionConsultants).get();
    expect(rows.map((r) => r.sessionId), ['s2']);
  });

  test('falha de rede preserva o que já estava no cache', () async {
```

**Em `test/data/services/local/app_database_test.dart`, substituir:**

```dart
  )
''';

/// A tabela `local_assessments` como a Fase 1 a criou — nenhuma migração
/// mexeu nela até a Fase 5A (esquema 4).
const String _localAssessmentsV3 = '''
```

**por:**

```dart
  )
''';

/// A tabela `sessions` como as Fases 3 a 6A a deixaram (esquemas 3 e 4): a do
/// esquema 2 mais o responsável e a hora do download dos participantes.
const String _sessionsV4 = '''
  CREATE TABLE IF NOT EXISTS sessions (
    id TEXT NOT NULL,
    company_name TEXT NOT NULL,
    company_logo_url TEXT NULL,
    course_name TEXT NOT NULL,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    date INTEGER NULL,
    status TEXT NOT NULL,
    notes TEXT NULL,
    total_participants INTEGER NOT NULL DEFAULT 0,
    assessable_participants INTEGER NOT NULL DEFAULT 0,
    assessed_participants INTEGER NOT NULL DEFAULT 0,
    responsible_consultant_id TEXT NULL,
    participants_synced_at INTEGER NULL,
    cached_at INTEGER NOT NULL,
    PRIMARY KEY (id)
  )
''';

/// A tabela `local_assessments` como a Fase 1 a criou — nenhuma migração
/// mexeu nela até a Fase 5A (esquema 4).
const String _localAssessmentsV3 = '''
```

**Em `test/data/services/local/app_database_test.dart`, substituir:**

```dart

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());
```

**por:**

```dart

void main() {
  late AppDatabase db;

  // Os testes de migração abrem um `AppDatabase` próprio com o do `setUp`
  // ainda aberto. Cada um tem o seu arquivo (ou a sua memória), então o aviso
  // do drift sobre o mesmo banco aberto duas vezes não se aplica — e sujava a
  // saída da suíte.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());
```

**Em `test/data/services/local/app_database_test.dart`, substituir:**

```dart
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('avaliação local guarda o status de sincronização como enum', () async {
```

**por:**

```dart
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  group('consultores da sessão', () {
    SessionConsultantsCompanion consultant(String sessionId, String id) {
      return SessionConsultantsCompanion.insert(
        sessionId: sessionId,
        consultantId: id,
        name: 'Carla Mendes',
      );
    }

    test('exigem uma sessão existente e não se repetem na mesma sessão',
        () async {
      await expectLater(
        db.into(db.sessionConsultants).insert(consultant('nao-existe', 'c-1')),
        throwsA(isA<SqliteException>()),
      );

      await insertSession('sess-1');
      await insertSession('sess-2');
      await db.into(db.sessionConsultants).insert(consultant('sess-1', 'c-1'));
      // O mesmo consultor em outra sessão é outra linha.
      await db.into(db.sessionConsultants).insert(consultant('sess-2', 'c-1'));

      await expectLater(
        db.into(db.sessionConsultants).insert(consultant('sess-1', 'c-1')),
        throwsA(isA<SqliteException>()),
      );
    });

    test('somem junto com a sessão, sem ninguém precisar apagá-los antes',
        () async {
      await insertSession('sess-1');
      await insertSession('sess-2');
      await db.into(db.sessionConsultants).insert(consultant('sess-1', 'c-1'));
      await db.into(db.sessionConsultants).insert(consultant('sess-2', 'c-1'));

      await (db.delete(db.sessions)..where((t) => t.id.equals('sess-1'))).go();

      final left = await db.select(db.sessionConsultants).get();
      expect(left.map((r) => r.sessionId), ['sess-2']);
    });

    test('clearSessionsCache não deixa consultor de sessão para trás', () async {
      await insertSession('sess-1');
      await db.into(db.sessionConsultants).insert(consultant('sess-1', 'c-1'));

      await db.clearSessionsCache();

      expect(await db.select(db.sessionConsultants).get(), isEmpty);
      expect(await db.select(db.sessions).get(), isEmpty);
    });

    test('replaceSessionConsultants troca só os da sessão pedida', () async {
      await insertSession('sess-1');
      await insertSession('sess-2');
      await db.into(db.sessionConsultants).insert(consultant('sess-1', 'c-1'));
      await db.into(db.sessionConsultants).insert(consultant('sess-1', 'c-2'));
      await db.into(db.sessionConsultants).insert(consultant('sess-2', 'c-9'));

      await db.replaceSessionConsultants('sess-1', [
        consultant('sess-1', 'c-2'),
        consultant('sess-1', 'c-3'),
      ]);

      final rows = await db.select(db.sessionConsultants).get();
      expect(
        rows.map((r) => (r.sessionId, r.consultantId)).toSet(),
        {('sess-1', 'c-2'), ('sess-1', 'c-3'), ('sess-2', 'c-9')},
      );
    });
  });

  test('avaliação local guarda o status de sincronização como enum', () async {
```

**Em `test/data/services/local/app_database_test.dart`, substituir:**

```dart
        reason: 'sem a transação, a 2ª tentativa quebraria com "duplicate '
            'column name: owner_user_id"');
  });
}
```

**por:**

```dart
        reason: 'sem a transação, a 2ª tentativa quebraria com "duplicate '
            'column name: owner_user_id"');
  });

  test(
      'migra do esquema 4 para o 5 criando a tabela de consultores da sessão, '
      'sem mexer nas sessões já cacheadas', () async {
    final directory = Directory.systemTemp.createTempSync('simtc_migracao_v5');
    final file = File('${directory.path}/simtc.sqlite');

    final migrated = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(_sessionsV4);
          raw.execute('''
            INSERT INTO sessions (id, company_name, course_name, city, state,
                                  status, responsible_consultant_id, cached_at)
            VALUES ('sess-1', 'Bracell', 'Direção Defensiva', 'Itabira', 'MG',
                    'EM_ANDAMENTO', 'c-1', 1758600000)
          ''');
          raw.execute('PRAGMA user_version = 4');
        },
      ),
    );

    addTearDown(() async {
      await migrated.close();
      directory.deleteSync(recursive: true);
    });

    // A tabela nova nasce vazia: o próximo download do detalhe a preenche.
    expect(await migrated.select(migrated.sessionConsultants).get(), isEmpty);

    final session = await migrated.select(migrated.sessions).getSingle();
    expect(session.companyName, 'Bracell');
    expect(session.responsibleConsultantId, 'c-1');

    await migrated.into(migrated.sessionConsultants).insert(
          SessionConsultantsCompanion.insert(
            sessionId: 'sess-1',
            consultantId: 'c-1',
            name: 'Carla Mendes',
          ),
        );
    final row = await migrated.select(migrated.sessionConsultants).getSingle();
    expect(row.name, 'Carla Mendes');
    expect(row.email, isNull);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/data/models/session_consultant_test.dart test/data/repositories/participant_repository_test.dart test/data/repositories/session_repository_test.dart test/data/services/local/app_database_test.dart`
Esperado: nenhum dos quatro compila — no do modelo, `Error when reading 'lib/data/models/session_consultant.dart'` e `Undefined name 'SessionConsultant'`; os outros três usam a tabela `sessionConsultants` e o `SessionConsultantsCompanion`, que ainda não existem.

- [ ] **Step 3: Implementar**

**Criar `lib/data/models/session_consultant.dart`:**

```dart
import 'package:drift/drift.dart' show Value;

import '../services/local/app_database.dart';

/// Um consultor de uma sessão: a linha da tela "Consultores" e a contagem
/// "N consultores" do detalhe (Fase 6B).
class SessionConsultant {
  const SessionConsultant({required this.id, required this.name, this.email});

  /// `Consultant.id`.
  final String id;
  final String name;
  final String? email;

  /// Um consultor a partir de `{ id, name, email }`, o formato de `Consultant`
  /// no backend. Nulo se faltar o id ou o nome; e-mail em branco vira nulo.
  static SessionConsultant? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    final email = json['email'];
    return SessionConsultant(
      id: id,
      name: name.trim(),
      email: email is String && email.trim().isNotEmpty ? email.trim() : null,
    );
  }

  /// Os consultores de uma sessão, do corpo de `GET /training-sessions/:id` ou
  /// da resposta das rotas `…/consultants`: os dois trazem
  /// `consultants[].consultant`, com `id`, `name` e `email`.
  ///
  /// O responsável entra mesmo que o vínculo dele falte na lista: o detalhe
  /// traz `responsibleConsultant` inteiro, e a tela precisa mostrar quem
  /// responde pela sessão. Devolve nulo se `consultants` não vier como lista —
  /// uma resposta fora do formato não pode virar "sessão sem consultor" no
  /// cache.
  static List<SessionConsultant>? listFromJson(Map<String, dynamic> body) {
    final links = body['consultants'];
    if (links is! List) return null;

    final byId = <String, SessionConsultant>{};
    void add(SessionConsultant? consultant) {
      if (consultant != null) byId.putIfAbsent(consultant.id, () => consultant);
    }

    for (final link in links) {
      if (link is Map<String, dynamic>) add(tryParse(link['consultant']));
    }
    add(tryParse(body['responsibleConsultant']));
    return byId.values.toList(growable: false);
  }

  factory SessionConsultant.fromRow(SessionConsultantRow row) {
    return SessionConsultant(
      id: row.consultantId,
      name: row.name,
      email: row.email,
    );
  }

  /// A linha deste consultor no cache da sessão [sessionId].
  SessionConsultantsCompanion toCompanion(String sessionId) {
    return SessionConsultantsCompanion.insert(
      sessionId: sessionId,
      consultantId: id,
      name: name,
      email: Value(email),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SessionConsultant &&
      other.id == id &&
      other.name == name &&
      other.email == email;

  @override
  int get hashCode => Object.hash(id, name, email);

  @override
  String toString() => 'SessionConsultant($id, $name, $email)';
}
```

**Em `lib/data/repositories/participant_repository.dart`, substituir:**

```dart
import '../../utils/scoring.dart';
import '../models/cpf_lookup.dart';
import '../models/remote_assessment.dart';
import '../models/session_participant.dart';
import '../models/training_session.dart';
import '../services/api/api_client.dart';
```

**por:**

```dart
import '../../utils/scoring.dart';
import '../models/cpf_lookup.dart';
import '../models/remote_assessment.dart';
import '../models/session_consultant.dart';
import '../models/session_participant.dart';
import '../models/training_session.dart';
import '../services/api/api_client.dart';
```

**Em `lib/data/repositories/participant_repository.dart`, substituir:**

```dart
    return row == null ? null : SessionParticipant.fromRow(row);
  }

  /// Baixa `GET /training-sessions/:id` e regrava a sessão e os participantes
  /// dela numa transação só. Devolve quantos participantes ficaram.
  ///
  /// O `participantsSyncedAt` é a hora em que o GET foi **pedido**, não a da
  /// escrita: os dados valem a partir de quando foram pedidos. Um GET
```

**por:**

```dart
    return row == null ? null : SessionParticipant.fromRow(row);
  }

  /// Baixa `GET /training-sessions/:id` e regrava a sessão, os participantes e
  /// os consultores dela numa transação só. Devolve quantos participantes
  /// ficaram.
  ///
  /// O `participantsSyncedAt` é a hora em que o GET foi **pedido**, não a da
  /// escrita: os dados valem a partir de quando foram pedidos. Um GET
```

**Em `lib/data/repositories/participant_repository.dart`, substituir:**

```dart
          .where((p) => p.id.isNotEmpty)
          .toList(growable: false);

      await _write(session, participants, requestedAt);
      return Success(participants.length);
    } on ApiException catch (error) {
      // 403 (consultor saiu da sessão) e 404 (sessão apagada) têm mensagem
```

**por:**

```dart
          .where((p) => p.id.isNotEmpty)
          .toList(growable: false);

      await _write(
        session,
        participants,
        SessionConsultant.listFromJson(body),
        requestedAt,
      );
      return Success(participants.length);
    } on ApiException catch (error) {
      // 403 (consultor saiu da sessão) e 404 (sessão apagada) têm mensagem
```

**Em `lib/data/repositories/participant_repository.dart`, substituir:**

```dart
  Future<void> _write(
    TrainingSession session,
    List<SessionParticipant> participants,
    DateTime now,
  ) {
    final assessable = participants
```

**por:**

```dart
  Future<void> _write(
    TrainingSession session,
    List<SessionParticipant> participants,
    List<SessionConsultant>? consultants,
    DateTime now,
  ) {
    final assessable = participants
```

**Em `lib/data/repositories/participant_repository.dart`, substituir:**

```dart
                cachedAt: now,
              ),
            );
      }
    });
  }
```

**por:**

```dart
                cachedAt: now,
              ),
            );
      }

      // Os consultores vêm no mesmo corpo (Fase 6B). Nulo: a resposta não
      // trouxe a lista, e o que já está no cache fica.
      if (consultants != null) {
        await _db.replaceSessionConsultants(
          session.id,
          consultants.map((c) => c.toCompanion(session.id)),
        );
      }
    });
  }
```

**Em `lib/data/services/local/app_database.dart`, substituir:**

```dart
  tables: [
    Sessions,
    Participants,
    AssessmentCategories,
    Infractions,
    InfractionNotes,
```

**por:**

```dart
  tables: [
    Sessions,
    Participants,
    SessionConsultants,
    AssessmentCategories,
    Infractions,
    InfractionNotes,
```

**Em `lib/data/services/local/app_database.dart`, substituir:**

```dart
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
```

**por:**

```dart
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
```

**Em `lib/data/services/local/app_database.dart`, substituir:**

```dart
              );
              await m.addColumn(localAssessments, localAssessments.score);
            }
          });
        },
        beforeOpen: (details) async {
```

**por:**

```dart
              );
              await m.addColumn(localAssessments, localAssessments.score);
            }
            if (from < 5) {
              // Fase 6B: os consultores de cada sessão, para a tela
              // "Consultores" e o "N consultores" do detalhe abrirem offline.
              // Tabela nova e vazia: o próximo download do detalhe a preenche.
              await m.createTable(sessionConsultants);
            }
          });
        },
        beforeOpen: (details) async {
```

**Em `lib/data/services/local/app_database.dart`, substituir:**

```dart

  static QueryExecutor _openConnection() => driftDatabase(name: 'simtc');

  /// Apaga o cache de sessões e participantes.
  ///
  /// Chamado ao trocar de consultor (logout ou expiração do refresh token):
  /// `watchSessions()` não tem escopo de usuário, então sem isto a Home do
```

**por:**

```dart

  static QueryExecutor _openConnection() => driftDatabase(name: 'simtc');

  /// Apaga o cache de sessões e participantes (os consultores de cada sessão
  /// vão junto, pela chave estrangeira em cascata).
  ///
  /// Chamado ao trocar de consultor (logout ou expiração do refresh token):
  /// `watchSessions()` não tem escopo de usuário, então sem isto a Home do
```

**Em `lib/data/services/local/app_database.dart`, substituir:**

```dart
      await delete(sessions).go();
    });
  }
}
```

**por:**

```dart
      await delete(sessions).go();
    });
  }

  /// Troca os consultores de uma sessão no cache pelos de [rows] (Fase 6B).
  ///
  /// Tem transação própria, e entra na de quem chama quando há uma aberta: o
  /// detalhe da sessão grava participantes e consultores de uma vez só.
  Future<void> replaceSessionConsultants(
    String sessionId,
    Iterable<SessionConsultantsCompanion> rows,
  ) {
    return transaction(() async {
      await (delete(sessionConsultants)
            ..where((t) => t.sessionId.equals(sessionId)))
          .go();
      for (final row in rows) {
        await into(sessionConsultants).insert(row);
      }
    });
  }
}
```

**Em `lib/data/services/local/tables.dart`, substituir:**

```dart

  @override
  Set<Column> get primaryKey => {id};
}

/// Catálogo: categorias de avaliação (`GET /assessment-categories`).
```

**por:**

```dart

  @override
  Set<Column> get primaryKey => {id};
}

/// Cache dos consultores de uma sessão (`SessionConsultant` do backend): a
/// tela "Consultores" e o "N consultores" do detalhe, que abrem offline
/// (Fase 6B). Vem do detalhe da sessão, junto com os participantes.
///
/// A linha some com a sessão (`ON DELETE CASCADE`): quem apaga sessões do
/// cache — a Home, ao tirar o que saiu da agenda, e a troca de usuário — não
/// precisa saber desta tabela.
@DataClassName('SessionConsultantRow')
class SessionConsultants extends Table {
  TextColumn get sessionId =>
      text().references(Sessions, #id, onDelete: KeyAction.cascade)();

  /// `Consultant.id`.
  TextColumn get consultantId => text()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId, consultantId};
}

/// Catálogo: categorias de avaliação (`GET /assessment-categories`).
```

Depois de editar o `tables.dart` e o `app_database.dart`, gerar de novo o código do Drift:

Run: `dart run build_runner build --delete-conflicting-outputs`
Esperado: termina com `Built with build_runner/aot in …; wrote N outputs.`, e o `lib/data/services/local/app_database.g.dart` passa a ter `$SessionConsultantsTable`, `SessionConsultantRow` e `SessionConsultantsCompanion`. Nenhum outro arquivo gerado muda. **Não editar o `.g.dart` à mão.**

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/data/models/session_consultant_test.dart test/data/repositories/participant_repository_test.dart test/data/repositories/session_repository_test.dart test/data/services/local/app_database_test.dart`
Esperado: `+83: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+712: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/data/models/session_consultant.dart \
  apps/mobile/simtc/lib/data/repositories/participant_repository.dart \
  apps/mobile/simtc/lib/data/services/local/app_database.dart \
  apps/mobile/simtc/lib/data/services/local/app_database.g.dart \
  apps/mobile/simtc/lib/data/services/local/tables.dart \
  apps/mobile/simtc/test/data/models/session_consultant_test.dart \
  apps/mobile/simtc/test/data/repositories/participant_repository_test.dart \
  apps/mobile/simtc/test/data/repositories/session_repository_test.dart \
  apps/mobile/simtc/test/data/services/local/app_database_test.dart
git commit -m "feat(mobile): banco v5 com os consultores da sessao no cache"
```

---

## Task 5: Repositório — consultores da sessão, a equipe, entrar e sair

O repositório que a tela de Consultores usa. Como os outros, a tela lê do banco: `watchBySession` serve o que o detalhe baixou. `add` e `remove` chamam as rotas da Task 1 e gravam no cache a lista que elas devolvem. A equipe é a exceção combinada: vem do servidor a cada abertura da tela e não fica guardada (decisão 11).

**Files:**
- Create: `lib/data/repositories/session_consultant_repository.dart`
- Create: `test/data/repositories/session_consultant_repository_test.dart`
- Modify: `lib/app_providers.dart`

**Interfaces:**
- Consumes: as rotas da Task 1; `GET /consultants?active=true`; `ApiClient.get<List<dynamic>>`, `post<Map<String, dynamic>>`, `delete<Map<String, dynamic>>`; `SessionConsultant.tryParse`/`listFromJson`/`fromRow`/`toCompanion` e `AppDatabase.replaceSessionConsultants` (Task 4).
- Produces: `SessionConsultantRepository({required ApiClient apiClient, required AppDatabase database})`, registrado no `AppDependencies` como `Provider<SessionConsultantRepository>`, com:
  - `Stream<List<SessionConsultant>> watchBySession(String sessionId)` — por nome.
  - `Future<Result<List<SessionConsultant>>> fetchTeam()` — a mensagem do `Failure` é a de falta de rede ou "Não foi possível carregar a equipe."
  - `Future<Result<void>> add(String sessionId, String consultantId)` e `Future<Result<void>> remove(String sessionId, String consultantId)` — a mensagem do `Failure` é a do backend em 400, 403 e 404 e a de falta de rede; no resto, "Não foi possível adicionar o consultor. Tente de novo." / "Não foi possível remover o consultor. Tente de novo." A exceção do `Failure` é a `ApiException`, com o `statusCode`. Com sucesso, a lista devolvida pelo backend vai para o cache; se a resposta vier fora do formato, ou a sessão não estiver no cache, o resultado continua sendo sucesso.

- [ ] **Step 1: Escrever os testes que falham**

**Criar `test/data/repositories/session_consultant_repository_test.dart`:**

```dart
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/session_consultant.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/utils/result.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late SessionConsultantRepository repository;

  const addPath = '/training-sessions/sess-1/consultants';
  const removePath = '/training-sessions/sess-1/consultants/c-2';

  Future<void> seedSession(String id) {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: id,
            companyName: 'Bracell',
            courseName: 'Direção Defensiva',
            city: 'Itabira',
            state: 'MG',
            status: 'EM_ANDAMENTO',
            cachedAt: DateTime(2026, 10, 9, 8),
          ),
        );
  }

  Future<void> seedConsultant(String sessionId, String id, String name) {
    return db.into(db.sessionConsultants).insert(
          SessionConsultantsCompanion.insert(
            sessionId: sessionId,
            consultantId: id,
            name: name,
          ),
        );
  }

  Future<Set<String>> cachedIds(String sessionId) async {
    final rows = await (db.select(db.sessionConsultants)
          ..where((t) => t.sessionId.equals(sessionId)))
        .get();
    return rows.map((r) => r.consultantId).toSet();
  }

  Map<String, dynamic> link(String id, String name, {String? email}) {
    return {
      'trainingSessionId': 'sess-1',
      'consultantId': id,
      'consultant': {'id': id, 'name': name, 'email': email},
    };
  }

  /// A resposta das duas rotas de consultor: quem é o responsável e os
  /// consultores da sessão depois da mudança.
  Response<Map<String, dynamic>> changed(List<Map<String, dynamic>> links) {
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: addPath),
      statusCode: 200,
      data: {'responsibleConsultantId': 'c-1', 'consultants': links},
    );
  }

  setUp(() {
    api = _MockApiClient();
    db = AppDatabase(NativeDatabase.memory());
    repository = SessionConsultantRepository(apiClient: api, database: db);
  });

  tearDown(() => db.close());

  test('watchBySession traz só os consultores da sessão pedida, por nome',
      () async {
    await seedSession('sess-1');
    await seedSession('sess-2');
    await seedConsultant('sess-1', 'c-2', 'Rafael Lima');
    await seedConsultant('sess-1', 'c-1', 'Carla Mendes');
    await seedConsultant('sess-2', 'c-9', 'Diego Barbosa');

    final list = await repository.watchBySession('sess-1').first;

    expect(list, const [
      SessionConsultant(id: 'c-1', name: 'Carla Mendes'),
      SessionConsultant(id: 'c-2', name: 'Rafael Lima'),
    ]);
  });

  group('fetchTeam', () {
    Response<List<dynamic>> team(List<dynamic>? body) {
      return Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/consultants'),
        statusCode: 200,
        data: body,
      );
    }

    test('pede só os ativos e devolve quem veio com id e nome', () async {
      when(() => api.get<List<dynamic>>(
            '/consultants',
            queryParameters: {'active': 'true'},
          )).thenAnswer((_) async => team([
            {'id': 'c-2', 'name': 'Rafael Lima', 'email': 'rafael@sim.com', 'active': true},
            {'id': 'c-1', 'name': 'Carla Mendes', 'email': null, 'active': true},
            {'id': '', 'name': 'Sem Id'},
            'lixo',
          ]));

      final result = await repository.fetchTeam();

      expect(result.dataOrNull, const [
        SessionConsultant(id: 'c-2', name: 'Rafael Lima', email: 'rafael@sim.com'),
        SessionConsultant(id: 'c-1', name: 'Carla Mendes'),
      ]);
    });

    test('resposta sem corpo vira falha, não "equipe vazia"', () async {
      when(() => api.get<List<dynamic>>(
            '/consultants',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => team(null));

      final result = await repository.fetchTeam();

      expect(
        result,
        isA<Failure<List<SessionConsultant>>>().having(
          (f) => f.message,
          'message',
          'Não foi possível carregar a equipe.',
        ),
      );
    });

    test('sem rede, a mensagem de falta de conexão', () async {
      when(() => api.get<List<dynamic>>(
            '/consultants',
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(const ApiException(
        message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        isNetworkError: true,
      ));

      final result = await repository.fetchTeam();

      expect(
        result,
        isA<Failure<List<SessionConsultant>>>().having(
          (f) => f.message,
          'message',
          'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        ),
      );
    });

    test('erro do servidor vira a mensagem genérica', () async {
      when(() => api.get<List<dynamic>>(
            '/consultants',
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(const ApiException(message: 'Internal server error', statusCode: 500));

      final result = await repository.fetchTeam();

      expect(
        result,
        isA<Failure<List<SessionConsultant>>>().having(
          (f) => f.message,
          'message',
          'Não foi possível carregar a equipe.',
        ),
      );
    });
  });

  group('add', () {
    test('manda um consultor só e grava no cache a lista que o backend devolve',
        () async {
      await seedSession('sess-1');
      await seedConsultant('sess-1', 'c-1', 'Carla Mendes');
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenAnswer((_) async => changed([
                link('c-1', 'Carla Mendes', email: 'carla@sim.com'),
                link('c-2', 'Rafael Lima'),
              ]));

      final result = await repository.add('sess-1', 'c-2');

      expect(result.isSuccess, isTrue);
      final sent = verify(
        () => api.post<Map<String, dynamic>>(addPath, data: captureAny(named: 'data')),
      ).captured.single;
      expect(sent, {'consultantId': 'c-2'});
      expect(await repository.watchBySession('sess-1').first, const [
        SessionConsultant(id: 'c-1', name: 'Carla Mendes', email: 'carla@sim.com'),
        SessionConsultant(id: 'c-2', name: 'Rafael Lima'),
      ]);
    });

    test('resposta fora do formato: o backend aceitou, e o cache fica como está',
        () async {
      await seedSession('sess-1');
      await seedConsultant('sess-1', 'c-1', 'Carla Mendes');
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: addPath),
                statusCode: 201,
                data: {'ok': true},
              ));

      final result = await repository.add('sess-1', 'c-2');

      expect(result.isSuccess, isTrue);
      expect(await cachedIds('sess-1'), {'c-1'});
    });

    test('sessão fora do cache: o backend aceitou, e isso basta', () async {
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenAnswer((_) async => changed([link('c-2', 'Rafael Lima')]));

      final result = await repository.add('sess-1', 'c-2');

      expect(result.isSuccess, isTrue);
      expect(await cachedIds('sess-1'), isEmpty);
    });

    for (final refusal in const [
      (400, 'Consultor inativo não pode entrar em um treinamento'),
      (403, 'Não é possível editar um treinamento concluído ou cancelado'),
      (404, 'Consultor não encontrado'),
    ]) {
      test('${refusal.$1} devolve o motivo do backend e não mexe no cache',
          () async {
        await seedSession('sess-1');
        await seedConsultant('sess-1', 'c-1', 'Carla Mendes');
        when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
            .thenThrow(ApiException(message: refusal.$2, statusCode: refusal.$1));

        final result = await repository.add('sess-1', 'c-2');

        expect(
          result,
          isA<Failure<void>>()
              .having((f) => f.message, 'message', refusal.$2)
              .having(
                (f) => f.exception,
                'exception',
                isA<ApiException>().having((e) => e.statusCode, 'statusCode', refusal.$1),
              ),
        );
        expect(await cachedIds('sess-1'), {'c-1'});
      });
    }

    test('sem rede, a mensagem de falta de conexão', () async {
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        isNetworkError: true,
      ));

      final result = await repository.add('sess-1', 'c-2');

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.message,
          'message',
          'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        ),
      );
    });

    test('erro inesperado do servidor vira uma mensagem genérica', () async {
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenThrow(const ApiException(message: 'Internal server error', statusCode: 500));

      final result = await repository.add('sess-1', 'c-2');

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.message,
          'message',
          'Não foi possível adicionar o consultor. Tente de novo.',
        ),
      );
    });

    test('exceção que não é da API também vira a mensagem genérica', () async {
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenThrow(StateError('quebrou'));

      final result = await repository.add('sess-1', 'c-2');

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.message,
          'message',
          'Não foi possível adicionar o consultor. Tente de novo.',
        ),
      );
    });
  });

  group('remove', () {
    test('chama a rota do consultor e grava no cache a lista que sobrou',
        () async {
      await seedSession('sess-1');
      await seedConsultant('sess-1', 'c-1', 'Carla Mendes');
      await seedConsultant('sess-1', 'c-2', 'Rafael Lima');
      when(() => api.delete<Map<String, dynamic>>(removePath))
          .thenAnswer((_) async => changed([link('c-1', 'Carla Mendes')]));

      final result = await repository.remove('sess-1', 'c-2');

      expect(result.isSuccess, isTrue);
      verify(() => api.delete<Map<String, dynamic>>(removePath)).called(1);
      expect(await cachedIds('sess-1'), {'c-1'});
    });

    test('400 (o responsável não sai) devolve o motivo e não mexe no cache',
        () async {
      const reason =
          'O consultor responsável não pode ser removido do treinamento. Troque o responsável antes.';
      await seedSession('sess-1');
      await seedConsultant('sess-1', 'c-2', 'Rafael Lima');
      when(() => api.delete<Map<String, dynamic>>(removePath))
          .thenThrow(const ApiException(message: reason, statusCode: 400));

      final result = await repository.remove('sess-1', 'c-2');

      expect(
        result,
        isA<Failure<void>>().having((f) => f.message, 'message', reason),
      );
      expect(await cachedIds('sess-1'), {'c-2'});
    });

    test('erro inesperado do servidor vira uma mensagem genérica', () async {
      when(() => api.delete<Map<String, dynamic>>(removePath))
          .thenThrow(const ApiException(message: 'Internal server error', statusCode: 502));

      final result = await repository.remove('sess-1', 'c-2');

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.message,
          'message',
          'Não foi possível remover o consultor. Tente de novo.',
        ),
      );
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/data/repositories/session_consultant_repository_test.dart`
Esperado: não compila — `Error when reading 'lib/data/repositories/session_consultant_repository.dart'`.

- [ ] **Step 3: Implementar**

**Substituir o conteúdo inteiro de `lib/app_providers.dart` por:**

```dart
import 'dart:async';

import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'config/app_config.dart';
import 'data/repositories/assessment_catalog_repository.dart';
import 'data/repositories/assessment_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/participant_repository.dart';
import 'data/repositories/session_consultant_repository.dart';
import 'data/repositories/session_repository.dart';
import 'data/services/api/api_client.dart';
import 'data/services/assessment_sync_service.dart';
import 'data/services/auth_session.dart';
import 'data/services/connectivity_service.dart';
import 'data/services/local/app_database.dart';
import 'data/services/local/token_storage.dart';

/// Dependências vivas do app, criadas uma única vez na abertura.
///
/// O `ApiClient` recebe do `AuthSession` as funções de leitura e gravação de
/// token; o `AuthRepository` recebe os dois. Assim o cliente HTTP não conhece o
/// repositório e não há ciclo entre eles.
class AppDependencies {
  AppDependencies._({
    required this.database,
    required this.tokenStorage,
    required this.session,
    required this.apiClient,
    required this.authRepository,
    required this.sessionRepository,
    required this.participantRepository,
    required this.sessionConsultantRepository,
    required this.catalogRepository,
    required this.assessmentRepository,
    required this.connectivityService,
    required this.assessmentSyncService,
  });

  factory AppDependencies.create({required AppDatabase database}) {
    final tokenStorage = TokenStorage();
    final session = AuthSession(tokenStorage);
    late final AuthRepository authRepository;

    final apiClient = ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      readAccessToken: session.readAccessToken,
      readRefreshToken: session.readRefreshToken,
      onTokensRenewed: session.updateTokens,
      onSessionExpired: () async {
        await session.expire();
        await authRepository.handleSessionExpired();
      },
    );

    authRepository = AuthRepository(
      apiClient: apiClient,
      session: session,
      clearLocalCache: database.clearSessionsCache,
    );
    final sessionRepository = SessionRepository(
      apiClient: apiClient,
      database: database,
    );
    final participantRepository = ParticipantRepository(
      apiClient: apiClient,
      database: database,
    );
    final sessionConsultantRepository = SessionConsultantRepository(
      apiClient: apiClient,
      database: database,
    );
    final catalogRepository = AssessmentCatalogRepository(
      apiClient: apiClient,
      database: database,
    );
    final assessmentRepository = AssessmentRepository(database: database);
    final connectivityService = ConnectivityService();
    final assessmentSyncService = AssessmentSyncService(
      apiClient: apiClient,
      assessments: assessmentRepository,
      participants: participantRepository,
      connectivity: connectivityService,
      authChanges: authRepository,
      currentUserId: () => authRepository.currentUser?.id,
    );
    // O envio só começa depois da primeira leitura da conexão: antes dela o
    // app acha que está online (o padrão), e abrir sem sinal marcaria a fila
    // com erro em vez de deixá-la "Na fila".
    unawaited(
      connectivityService.initialize().whenComplete(assessmentSyncService.start),
    );

    return AppDependencies._(
      database: database,
      tokenStorage: tokenStorage,
      session: session,
      apiClient: apiClient,
      authRepository: authRepository,
      sessionRepository: sessionRepository,
      participantRepository: participantRepository,
      sessionConsultantRepository: sessionConsultantRepository,
      catalogRepository: catalogRepository,
      assessmentRepository: assessmentRepository,
      connectivityService: connectivityService,
      assessmentSyncService: assessmentSyncService,
    );
  }

  final AppDatabase database;
  final TokenStorage tokenStorage;
  final AuthSession session;
  final ApiClient apiClient;
  final AuthRepository authRepository;
  final SessionRepository sessionRepository;
  final ParticipantRepository participantRepository;
  final SessionConsultantRepository sessionConsultantRepository;
  final AssessmentCatalogRepository catalogRepository;
  final AssessmentRepository assessmentRepository;
  final ConnectivityService connectivityService;
  final AssessmentSyncService assessmentSyncService;

  /// Providers na ordem de dependência, para o `MultiProvider` do app.
  ///
  /// Todos entram por `.value` porque quem cria é esta classe — e é ela quem
  /// libera os recursos em `dispose()`.
  List<SingleChildWidget> get providers => [
        Provider<AppDatabase>.value(value: database),
        Provider<TokenStorage>.value(value: tokenStorage),
        Provider<AuthSession>.value(value: session),
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<AuthRepository>.value(value: authRepository),
        Provider<SessionRepository>.value(value: sessionRepository),
        Provider<ParticipantRepository>.value(value: participantRepository),
        Provider<SessionConsultantRepository>.value(
          value: sessionConsultantRepository,
        ),
        Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        Provider<AssessmentRepository>.value(value: assessmentRepository),
        ChangeNotifierProvider<ConnectivityService>.value(
          value: connectivityService,
        ),
        ChangeNotifierProvider<AssessmentSyncService>.value(
          value: assessmentSyncService,
        ),
      ];

  void dispose() {
    assessmentSyncService.dispose();
    connectivityService.dispose();
    authRepository.dispose();
    session.dispose();
  }
}
```

**Criar `lib/data/repositories/session_consultant_repository.dart`:**

```dart
import 'package:drift/drift.dart';

import '../../utils/result.dart';
import '../models/session_consultant.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/local/app_database.dart';

/// Consultores de uma sessão (tela "Consultores", Fase 6B).
///
/// Como nos outros repositórios, a tela lê do banco: [watchBySession] serve os
/// consultores que o detalhe da sessão baixou. [add] e [remove] mandam um
/// consultor por vez ao backend e gravam no cache a lista que ele devolve. A
/// equipe ([fetchTeam]) é a exceção: vem do servidor a cada abertura da tela
/// e não fica guardada.
class SessionConsultantRepository {
  SessionConsultantRepository({
    required ApiClient apiClient,
    required AppDatabase database,
  })  : _api = apiClient,
        _db = database;

  final ApiClient _api;
  final AppDatabase _db;

  static const String _teamPath = '/consultants';

  static const String _teamFailed = 'Não foi possível carregar a equipe.';
  static const String _addFailed =
      'Não foi possível adicionar o consultor. Tente de novo.';
  static const String _removeFailed =
      'Não foi possível remover o consultor. Tente de novo.';

  /// Os consultores da sessão que estão no cache. A ordem de exibição (o
  /// responsável primeiro) é regra de tela e fica na ViewModel.
  Stream<List<SessionConsultant>> watchBySession(String sessionId) {
    final query = _db.select(_db.sessionConsultants)
      ..where((t) => t.sessionId.equals(sessionId))
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);

    return query.watch().map(
          (rows) => rows.map(SessionConsultant.fromRow).toList(growable: false),
        );
  }

  /// Os consultores ativos da equipe (`GET /consultants?active=true`, aberto a
  /// ADMIN e a consultor), na ordem em que o backend manda. Quem já está na
  /// sessão também vem: tirar esses da lista é da ViewModel.
  Future<Result<List<SessionConsultant>>> fetchTeam() async {
    try {
      final response = await _api.get<List<dynamic>>(
        _teamPath,
        queryParameters: {'active': 'true'},
      );
      final body = response.data;
      if (body == null) {
        return Failure(
          Exception('resposta de $_teamPath fora do formato'),
          _teamFailed,
        );
      }
      return Success(
        body
            .map(SessionConsultant.tryParse)
            .whereType<SessionConsultant>()
            .toList(growable: false),
      );
    } on ApiException catch (error) {
      return Failure(error, error.isNetworkError ? error.message : _teamFailed);
    } catch (error) {
      return Failure(Exception('$error'), _teamFailed);
    }
  }

  /// Põe um consultor na sessão
  /// (`POST /training-sessions/:id/consultants`, só ADMIN).
  Future<Result<void>> add(String sessionId, String consultantId) {
    return _change(
      sessionId,
      () async {
        final response = await _api.post<Map<String, dynamic>>(
          '/training-sessions/$sessionId/consultants',
          data: {'consultantId': consultantId},
        );
        return response.data;
      },
      _addFailed,
    );
  }

  /// Tira um consultor da sessão
  /// (`DELETE /training-sessions/:id/consultants/:consultantId`, só ADMIN). O
  /// backend libera, na mesma operação, quem estava em avaliação com ele: quem
  /// chama baixa a sessão de novo para a lista de participantes acompanhar.
  Future<Result<void>> remove(String sessionId, String consultantId) {
    return _change(
      sessionId,
      () async {
        final response = await _api.delete<Map<String, dynamic>>(
          '/training-sessions/$sessionId/consultants/$consultantId',
        );
        return response.data;
      },
      _removeFailed,
    );
  }

  /// Manda a mudança e grava no cache os consultores que o backend devolve
  /// (`{ responsibleConsultantId, consultants: [...] }`).
  Future<Result<void>> _change(
    String sessionId,
    Future<Map<String, dynamic>?> Function() send,
    String fallback,
  ) async {
    final Map<String, dynamic>? body;
    try {
      body = await send();
    } on ApiException catch (error) {
      // 400 (consultor inativo, ou tentar tirar o responsável), 403 (sessão
      // concluída ou cancelada) e 404 (a sessão ou o consultor não existem
      // mais) têm mensagem própria do backend; sem rede, a do `ApiException`
      // já diz o que fazer.
      final status = error.statusCode;
      final ownMessage =
          status == 400 || status == 403 || status == 404 || error.isNetworkError;
      return Failure(error, ownMessage ? error.message : fallback);
    } catch (error) {
      return Failure(Exception('$error'), fallback);
    }

    try {
      final consultants =
          body == null ? null : SessionConsultant.listFromJson(body);
      if (consultants != null) {
        await _db.replaceSessionConsultants(
          sessionId,
          consultants.map((c) => c.toCompanion(sessionId)),
        );
      }
    } catch (_) {
      // O backend já mudou — isso é o que importa. Com a resposta fora do
      // formato, ou a sessão fora do cache, o próximo download do detalhe
      // acerta a lista.
    }
    return const Success<void>(null);
  }
}
```

Quem baixa a sessão de novo depois de um `remove` — para a lista de participantes acompanhar quem foi liberado — é a ViewModel da tela (Task 7), e não o repositório.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/data/repositories/session_consultant_repository_test.dart`
Esperado: `+17: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+729: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/app_providers.dart \
  apps/mobile/simtc/lib/data/repositories/session_consultant_repository.dart \
  apps/mobile/simtc/test/data/repositories/session_consultant_repository_test.dart
git commit -m "feat(mobile): repositorio de consultores da sessao"
```

---

## Task 6: Design System — as peças da tela de Consultores

O que a tela nova pede e o DS não tinha, sem regra de negócio: o botão de contorno vermelho ganha o tamanho compacto ("Remover da sessão"); entra o botão de contorno cinza com a largura do rótulo ("Adicionar"); a pastilha só de texto para o papel do consultor; a faixa de contexto aceita uma primeira linha que não é só o nome da empresa; e a linha de consultor, em arquivo próprio, como a do participante.

As medidas vêm do quadro `3c`: recuo da linha de 15 × 20, contorno de 1,5 em cima e embaixo, vão de 12 até o que fica à direita, de 4 entre o nome e a segunda linha e de 10 até o aviso e o botão; pastilha com recuo de 5 × 10; botões com canto 10, ícone de 19 e texto 14 / 700 — com 48dp de altura, e não os 44 do quadro (decisão 14). As cores são as dos tons que o app já tem (ver "Ajustes").

**Files:**
- Create: `lib/ui/session_consultants/consultant_row.dart`
- Create: `test/ui/session_consultants/consultant_row_test.dart`
- Modify: `lib/ui/core/theme/app_icons.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/widgets/app_buttons.dart`
- Modify: `lib/ui/core/widgets/session_context_header.dart`
- Modify: `lib/ui/core/widgets/status_chip.dart`
- Modify: `test/ui/core/widgets/display_widgets_test.dart`
- Modify: `test/ui/core/widgets/form_widgets_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography.buttonCompact`/`chipLabel`/`meta`; `InlineNotice`, `NoticeTone`; `StatusTone`.
- Produces:
  - `AppDangerOutlineButton({..., bool compact = false})` — compacto: 48dp, canto 10, texto 14 / 700, ícone de 19.
  - `AppCompactOutlineButton({required String label, VoidCallback? onPressed, bool isLoading = false, IconData? icon})` — 48dp, largura do conteúdo, contorno `borderStrong`, tinta `primaryDark`; carregando, mantém a largura; sem ação, fica à vista e apagado.
  - `LabelPill({required String label, required StatusTone tone})` (em `status_chip.dart`).
  - `SessionContextHeader({..., String? title})` — a primeira linha, no lugar do nome da empresa.
  - `ConsultantRow({required String name, required Widget trailing, String? meta, bool metaWraps = false, String? note, Widget? action})`.
  - `AppTypography.consultantName` (15,5 / 600 / 1,25); `AppIcons.info`.

- [ ] **Step 1: Escrever os testes que falham**

**Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:**

```dart

    expect(find.text('Aprovado'), findsOneWidget);
    expect(find.byIcon(AppIcons.approved), findsOneWidget);
  });

  testWidgets('SeverityBadge usa os rótulos literais B, PM e M', (tester) async {
```

**por:**

```dart

    expect(find.text('Aprovado'), findsOneWidget);
    expect(find.byIcon(AppIcons.approved), findsOneWidget);
  });

  testWidgets('LabelPill mostra só o texto, nas cores do tom e com o recuo do '
      'canvas', (tester) async {
    await _pump(
      tester,
      const Row(
        children: [
          LabelPill(label: 'Responsável', tone: StatusTone.info),
          LabelPill(label: 'Consultor', tone: StatusTone.neutral),
        ],
      ),
    );

    expect(find.byType(Icon), findsNothing);

    BoxDecoration boxOf(String label) {
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      return container.decoration! as BoxDecoration;
    }

    Color? inkOf(String label) =>
        tester.renderObject<RenderParagraph>(find.text(label)).text.style?.color;

    expect(boxOf('Responsável').color, AppColors.primarySurface);
    expect(
      boxOf('Responsável').border,
      Border.all(color: AppColors.primary, width: 1.5),
    );
    expect(inkOf('Responsável'), AppColors.primaryDark);
    expect(boxOf('Consultor').color, AppColors.neutralBg);
    expect(
      boxOf('Consultor').border,
      Border.all(color: AppColors.neutralBorder, width: 1.5),
    );
    expect(inkOf('Consultor'), AppColors.neutralInk);

    // Recuo de 10 dos lados e 5 em cima e embaixo, por dentro do contorno
    // de 1,5 (canvas "3c").
    final pill = tester.getRect(find.byType(LabelPill).first);
    final text = tester.getRect(find.text('Responsável'));
    expect(text.left - pill.left, 11.5);
    expect(pill.right - text.right, 11.5);
    expect(text.top - pill.top, 6.5);
    expect(pill.bottom - text.bottom, 6.5);
  });

  testWidgets('SeverityBadge usa os rótulos literais B, PM e M', (tester) async {
```

**Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:**

```dart
      expect(find.text('Direção Defensiva — Veículo Pesado'), findsOneWidget);
    });

    testWidgets('apagada usa o fundo da tela; a normal, o da superfície',
        (tester) async {
      Color? background() {
```

**por:**

```dart
      expect(find.text('Direção Defensiva — Veículo Pesado'), findsOneWidget);
    });

    testWidgets('com título, a primeira linha é ele, e as iniciais continuam '
        'sendo as da empresa', (tester) async {
      await _pump(
        tester,
        const SessionContextHeader(
          companyName: 'Bracell Celulose',
          title: 'Bracell Celulose · 12 set',
          subtitle: '5 participantes · 3 consultores',
        ),
      );

      expect(find.text('BC'), findsOneWidget);
      expect(find.text('Bracell Celulose · 12 set'), findsOneWidget);
      expect(find.text('Bracell Celulose'), findsNothing);
      expect(find.text('5 participantes · 3 consultores'), findsOneWidget);
    });

    testWidgets('apagada usa o fundo da tela; a normal, o da superfície',
        (tester) async {
      Color? background() {
```

**Em `test/ui/core/widgets/form_widgets_test.dart`, substituir:**

```dart
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('AppTextButton', () {
```

**por:**

```dart
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('compacto tem 48dp, texto 14, ícone 19 e canto 10, como o '
        '"Remover da sessão" do canvas', (tester) async {
      await _pump(
        tester,
        AppDangerOutlineButton(
          label: 'Remover da sessão',
          icon: AppIcons.discard,
          compact: true,
          onPressed: () {},
        ),
      );

      expect(tester.getSize(find.byType(AppDangerOutlineButton)).height, 48);
      expect(tester.widget<Icon>(find.byIcon(AppIcons.discard)).size, 19);
      final text =
          tester.renderObject<RenderParagraph>(find.text('Remover da sessão'));
      expect(text.text.style?.fontSize, 14);
      expect(text.text.style?.color, AppColors.dangerInk);

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(
        button.style!.shape!.resolve(const {}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    });

    testWidgets('o tamanho padrão continua com texto 15, ícone 20 e canto 12',
        (tester) async {
      await _pump(
        tester,
        AppDangerOutlineButton(
          label: 'Cancelar sessão',
          icon: AppIcons.cancelSession,
          onPressed: () {},
        ),
      );

      expect(tester.widget<Icon>(find.byIcon(AppIcons.cancelSession)).size, 20);
      final text =
          tester.renderObject<RenderParagraph>(find.text('Cancelar sessão'));
      expect(text.text.style?.fontSize, 15);

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(
        button.style!.shape!.resolve(const {}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
    });
  });

  group('AppCompactOutlineButton', () {
    // Como na tela: ao lado de um texto que ocupa o resto da linha.
    Widget inRow(Widget button) {
      return Row(
        children: [const Expanded(child: Text('Diego Barbosa')), button],
      );
    }

    testWidgets('dispara a ação, com 48dp de altura, a largura do rótulo e as '
        'medidas do "Adicionar" do canvas', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        inRow(
          AppCompactOutlineButton(
            label: 'Adicionar',
            icon: AppIcons.assign,
            onPressed: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('Adicionar'));
      expect(taps, 1);

      final box = tester.getRect(find.byType(AppCompactOutlineButton));
      final icon = tester.getRect(find.byIcon(AppIcons.assign));
      final label = tester.getRect(find.text('Adicionar'));
      expect(box.height, 48);
      // Recuo de 14, ícone de 19, vão de 6, o rótulo e mais 14.
      expect(icon.left - box.left, 14);
      expect(icon.width, 19);
      expect(label.left - icon.right, 6);
      expect(box.right - label.right, 14);

      final outlined = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(
        outlined.style!.side!.resolve(const {}),
        const BorderSide(color: AppColors.borderStrong, width: 1.5),
      );
      expect(
        outlined.style!.shape!.resolve(const {}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
      final text = tester.renderObject<RenderParagraph>(find.text('Adicionar'));
      expect(text.text.style?.fontSize, 14);
      expect(text.text.style?.color, AppColors.primaryDark);
    });

    testWidgets('em carregamento mostra o indicador, não responde ao toque e '
        'mantém a largura', (tester) async {
      var taps = 0;
      Widget build({required bool loading}) {
        return inRow(
          AppCompactOutlineButton(
            label: 'Adicionar',
            icon: AppIcons.assign,
            isLoading: loading,
            onPressed: () => taps++,
          ),
        );
      }

      await _pump(tester, build(loading: false));
      final idle = tester.getSize(find.byType(AppCompactOutlineButton));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await _pump(tester, build(loading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // A linha não pula quando o botão troca o rótulo pelo indicador.
      expect(tester.getSize(find.byType(AppCompactOutlineButton)), idle);

      await tester.tap(find.byType(AppCompactOutlineButton));
      expect(taps, 0);
    });

    testWidgets('sem ação, continua à vista, apagado', (tester) async {
      await _pump(
        tester,
        inRow(
          const AppCompactOutlineButton(
            label: 'Adicionar',
            icon: AppIcons.assign,
          ),
        ),
      );

      final outlined = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(outlined.onPressed, isNull);
      expect(
        outlined.style!.side!.resolve(const {}),
        const BorderSide(color: AppColors.border, width: 1.5),
      );
      final text = tester.renderObject<RenderParagraph>(find.text('Adicionar'));
      expect(text.text.style?.color, AppColors.textMuted);
    });
  });

  group('AppTextButton', () {
```

**Criar `test/ui/session_consultants/consultant_row_test.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/inline_notice.dart';
import 'package:simtc/ui/core/widgets/status_chip.dart';
import 'package:simtc/ui/session_consultants/consultant_row.dart';

/// A linha numa tela de [width] de largura, dentro de uma lista — como na
/// tela "Consultores".
Future<void> _pump(
  WidgetTester tester,
  Widget row, {
  double width = 412,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: ListView(children: [row])),
    ),
  );
}

const _note =
    'Tem 1 avaliação em andamento. Remover devolve Marcos Vinícius para Pendente.';

void main() {
  testWidgets('mostra o nome, a linha de apoio e o que vai à direita',
      (tester) async {
    await _pump(
      tester,
      const ConsultantRow(
        name: 'Carla Mendes (você)',
        meta: '2 participantes · 1 em andamento',
        trailing: LabelPill(label: 'Responsável', tone: StatusTone.info),
      ),
    );

    expect(find.text('Carla Mendes (você)'), findsOneWidget);
    expect(find.text('2 participantes · 1 em andamento'), findsOneWidget);
    expect(find.text('Responsável'), findsOneWidget);
    // Sem aviso e sem ação, a linha é só o cabeçalho.
    expect(find.byType(InlineNotice), findsNothing);

    // A pastilha fica à direita do nome, com 12 de vão (canvas "3c").
    final name = tester.getRect(find.text('Carla Mendes (você)'));
    final pill = tester.getRect(find.byType(LabelPill));
    expect(pill.left, greaterThan(name.left));
    expect(pill.right, 412 - 20);

    final nameStyle = tester
        .renderObject<RenderParagraph>(find.text('Carla Mendes (você)'))
        .text
        .style;
    expect(nameStyle?.fontSize, 15.5);
    expect(nameStyle?.fontWeight, FontWeight.w600);
  });

  testWidgets('tem o recuo de 15 por 20 e o contorno de 1,5 em cima e embaixo',
      (tester) async {
    await _pump(
      tester,
      const ConsultantRow(
        name: 'Tatiane Souza',
        meta: '2 participantes concluídos',
        trailing: LabelPill(label: 'Consultor', tone: StatusTone.neutral),
      ),
    );

    final row = tester.getRect(find.byType(ConsultantRow));
    final name = tester.getRect(find.text('Tatiane Souza'));
    final meta = tester.getRect(find.text('2 participantes concluídos'));
    expect(row.width, 412);
    expect(name.left - row.left, 20);
    // 1,5 do contorno mais os 15 do recuo.
    expect(name.top - row.top, 16.5);
    expect(row.bottom - meta.bottom, 16.5);
    // 4 entre o nome e a linha de apoio.
    expect(meta.top - name.bottom, 4);

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ConsultantRow),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.surface);
    expect(
      decoration.border,
      const Border(
        top: BorderSide(color: AppColors.border, width: 1.5),
        bottom: BorderSide(color: AppColors.border, width: 1.5),
      ),
    );
  });

  testWidgets('com aviso e ação, empilha os dois sob o nome, com 10 de vão',
      (tester) async {
    await _pump(
      tester,
      ConsultantRow(
        name: 'Rafael Lima',
        meta: '1 participante · 1 em andamento',
        trailing: const LabelPill(label: 'Consultor', tone: StatusTone.neutral),
        note: _note,
        action: AppDangerOutlineButton(
          label: 'Remover da sessão',
          icon: AppIcons.discard,
          compact: true,
          onPressed: () {},
        ),
      ),
    );

    final notice = tester.widget<InlineNotice>(find.byType(InlineNotice));
    expect(notice.message, _note);
    expect(notice.tone, NoticeTone.warning);
    expect(notice.icon, AppIcons.info);

    final meta = tester.getRect(find.text('1 participante · 1 em andamento'));
    final noticeBox = tester.getRect(find.byType(InlineNotice));
    final button = tester.getRect(find.byType(AppDangerOutlineButton));
    final row = tester.getRect(find.byType(ConsultantRow));
    expect(noticeBox.top - meta.bottom, 10);
    expect(button.top - noticeBox.bottom, 10);
    expect(row.bottom - button.bottom, 16.5);
    // O aviso e o botão vão de uma margem à outra.
    expect(noticeBox.left, 20);
    expect(noticeBox.right, 412 - 20);
    expect(button.left, 20);
    expect(button.right, 412 - 20);
  });

  testWidgets('sem a linha de apoio, mostra só o nome', (tester) async {
    await _pump(
      tester,
      ConsultantRow(
        name: 'Diego Barbosa',
        trailing: AppCompactOutlineButton(
          label: 'Adicionar',
          icon: AppIcons.assign,
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('Diego Barbosa'), findsOneWidget);
    // Só o nome e o rótulo do botão.
    expect(find.byType(Text), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('em 360 de largura e com a fonte ampliada, o nome e o e-mail '
      'compridos encolhem com reticências e o botão continua inteiro',
      (tester) async {
    const nome = 'Patrícia Vasconcelos de Albuquerque Figueiredo';
    const email = 'patricia.vasconcelos.albuquerque@simtreinamentos.com.br';

    await _pump(
      tester,
      ConsultantRow(
        name: nome,
        meta: email,
        trailing: AppCompactOutlineButton(
          label: 'Adicionar',
          icon: AppIcons.assign,
          onPressed: () {},
        ),
      ),
      width: 360,
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.renderObject<RenderParagraph>(find.text(nome)).didExceedMaxLines,
      isTrue,
    );
    expect(
      tester.renderObject<RenderParagraph>(find.text(email)).didExceedMaxLines,
      isTrue,
    );
    final button = tester.getRect(find.byType(AppCompactOutlineButton));
    expect(button.right, 360 - 20);
    expect(button.height, 48);
    // O nome vai até 12 antes do botão (o vão do canvas "3c").
    expect(button.left - tester.getRect(find.text(nome)).right, 12);
    expect(
      tester.renderObject<RenderParagraph>(find.text('Adicionar')).didExceedMaxLines,
      isFalse,
    );
  });

  testWidgets('a linha de apoio de quem está na sessão quebra em vez de '
      'encolher: o "em andamento" não some num celular estreito',
      (tester) async {
    const meta = '12 participantes · 3 em andamento';

    Future<RenderParagraph> pumpRow({required bool wraps}) async {
      await _pump(
        tester,
        ConsultantRow(
          name: 'Rafael Lima',
          meta: meta,
          metaWraps: wraps,
          trailing: const LabelPill(label: 'Consultor', tone: StatusTone.neutral),
        ),
        width: 360,
        textScale: 1.3,
      );
      return tester.renderObject<RenderParagraph>(find.text(meta));
    }

    final cut = await pumpRow(wraps: false);
    expect(cut.didExceedMaxLines, isTrue);
    final oneLine = cut.size.height;

    final whole = await pumpRow(wraps: true);
    expect(whole.didExceedMaxLines, isFalse);
    expect(whole.size.height, greaterThan(oneLine));
    expect(tester.takeException(), isNull);
  });

  testWidgets('o aviso comprido quebra em linhas, sem estourar, em 360 de '
      'largura e com a fonte ampliada', (tester) async {
    await _pump(
      tester,
      ConsultantRow(
        name: 'Rafael Lima',
        meta: '3 participantes · 2 em andamento',
        trailing: const LabelPill(label: 'Consultor', tone: StatusTone.neutral),
        note: 'Tem 2 avaliações em andamento. Remover libera esses '
            'participantes para outro consultor.',
        action: AppDangerOutlineButton(
          label: 'Remover da sessão',
          icon: AppIcons.discard,
          compact: true,
          onPressed: () {},
        ),
      ),
      width: 360,
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    final noticeBox = tester.getRect(find.byType(InlineNotice));
    expect(noticeBox.left, 20);
    expect(noticeBox.right, 360 - 20);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/widgets test/ui/session_consultants/consultant_row_test.dart`
Esperado: não compilam — `Method not found: 'LabelPill'` e `No named parameter with the name 'title'` no `display_widgets_test.dart`; `No named parameter with the name 'compact'` e `Method not found: 'AppCompactOutlineButton'` no `form_widgets_test.dart`; `Error when reading 'lib/ui/session_consultants/consultant_row.dart'` no teste da linha.

- [ ] **Step 3: Implementar**

**Em `lib/ui/core/theme/app_icons.dart`, substituir:**

```dart
  static const IconData cpf = Icons.badge_outlined;
  static const IconData practice = Icons.directions_car_outlined;
  static const IconData addParticipant = Icons.person_add_outlined;
}
```

**por:**

```dart
  static const IconData cpf = Icons.badge_outlined;
  static const IconData practice = Icons.directions_car_outlined;
  static const IconData addParticipant = Icons.person_add_outlined;

  /// O aviso de uma linha da tela "Consultores" (Fase 6B, canvas "3c").
  static const IconData info = Icons.info_outlined;
}
```

**Em `lib/ui/core/theme/app_typography.dart`, substituir:**

```dart
  /// Empresa na faixa de contexto dos formulários de ADMIN (canvas "3b")
  static TextStyle get contextTitle =>
      _inter(size: 15, weight: FontWeight.w600, height: 1.25);

  /// Rótulo de um cartão de opção ("Somente teórica", canvas "3a"). São dois
  /// estilos, e não um `copyWith(fontWeight:)`: o `copyWith` não mexe no
```

**por:**

```dart
  /// Empresa na faixa de contexto dos formulários de ADMIN (canvas "3b")
  static TextStyle get contextTitle =>
      _inter(size: 15, weight: FontWeight.w600, height: 1.25);

  /// Nome do consultor na tela "Consultores" (canvas "3c")
  static TextStyle get consultantName =>
      _inter(size: 15.5, weight: FontWeight.w600, height: 1.25);

  /// Rótulo de um cartão de opção ("Somente teórica", canvas "3a"). São dois
  /// estilos, e não um `copyWith(fontWeight:)`: o `copyWith` não mexe no
```

**Em `lib/ui/core/widgets/app_buttons.dart`, substituir:**

```dart
  }
}

/// Ação destrutiva em contorno vermelho, na caixa do botão principal —
/// "Cancelar sessão" (canvas "3b"): mora no fim da tela, longe do salvar.
class AppDangerOutlineButton extends StatelessWidget {
  const AppDangerOutlineButton({
    super.key,
```

**por:**

```dart
  }
}

/// Ação destrutiva em contorno vermelho. No tamanho padrão, tem a caixa do
/// botão principal — "Cancelar sessão" (canvas "3b"): mora no fim da tela,
/// longe do salvar. Com [compact], é a ação de uma linha de lista — "Remover
/// da sessão" (canvas "3c"): o quadro a desenha com 44dp, aqui ela tem 48dp, o
/// alvo mínimo do DS.
class AppDangerOutlineButton extends StatelessWidget {
  const AppDangerOutlineButton({
    super.key,
```

**Em `lib/ui/core/widgets/app_buttons.dart`, substituir:**

```dart
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final available = onPressed != null || isLoading;

    return SizedBox(
      height: AppSpacing.controlHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
```

**por:**

```dart
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final available = onPressed != null || isLoading;

    return SizedBox(
      height: compact ? AppSpacing.touchTarget : AppSpacing.controlHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
```

**Em `lib/ui/core/widgets/app_buttons.dart`, substituir:**

```dart
            color: available ? AppColors.dangerBorder : AppColors.border,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          // A cor vem do `foregroundColor`; daqui só o tamanho e o peso.
          textStyle: AppTypography.buttonDanger,
        ),
        child: isLoading ? _buildSpinner() : _buildContent(),
      ),
```

**por:**

```dart
            color: available ? AppColors.dangerBorder : AppColors.border,
            width: 1.5,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.lg : AppSpacing.xl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              compact ? AppRadius.sm + 2 : AppRadius.md,
            ),
          ),
          // A cor vem do `foregroundColor`; daqui só o tamanho e o peso.
          textStyle:
              compact ? AppTypography.buttonCompact : AppTypography.buttonDanger,
        ),
        child: isLoading ? _buildSpinner() : _buildContent(),
      ),
```

**Em `lib/ui/core/widgets/app_buttons.dart`, substituir:**

```dart
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
```

**por:**

```dart
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 19 : 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// Ação em contorno cinza ao lado de um item de lista — o "Adicionar" da tela
/// "Consultores" (canvas "3c"). Tem a largura do rótulo, e não a da linha; o
/// quadro a desenha com 44dp, aqui ela tem 48dp, o alvo mínimo do DS.
class AppCompactOutlineButton extends StatelessWidget {
  const AppCompactOutlineButton({
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

  @override
  Widget build(BuildContext context) {
    final available = onPressed != null || isLoading;

    return SizedBox(
      height: AppSpacing.touchTarget,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          disabledForegroundColor:
              isLoading ? AppColors.primaryDark : AppColors.textMuted,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: available ? AppColors.borderStrong : AppColors.border,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
          // A cor vem do `foregroundColor`; daqui só o tamanho e o peso.
          textStyle: AppTypography.buttonCompact,
        ),
        // O rótulo continua ocupando o lugar dele enquanto o indicador gira:
        // o botão tem a largura do conteúdo, e sem isso a linha pularia.
        child: Stack(
          alignment: Alignment.center,
          children: [
            Visibility(
              visible: !isLoading,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _buildContent(),
            ),
            if (isLoading) _buildSpinner(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpinner() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
      ),
    );
  }

  Widget _buildContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 19),
          const SizedBox(width: AppSpacing.sm - AppSpacing.xxs),
        ],
        Text(label),
      ],
    );
  }
```

**Em `lib/ui/core/widgets/session_context_header.dart`, substituir:**

```dart
import '../theme/app_typography.dart';
import 'company_logo.dart';

/// Faixa de contexto no topo dos formulários de ADMIN (canvas "3a" e "3b"):
/// o logo da empresa e duas linhas dizendo em que sessão o admin está
/// mexendo — ele cadastra em sequência e precisa saber onde está.
class SessionContextHeader extends StatelessWidget {
```

**por:**

```dart
import '../theme/app_typography.dart';
import 'company_logo.dart';

/// Faixa de contexto no topo das telas de ADMIN (canvas "3a", "3b" e "3c"):
/// o logo da empresa e duas linhas dizendo em que sessão o admin está
/// mexendo — ele cadastra em sequência e precisa saber onde está.
class SessionContextHeader extends StatelessWidget {
```

**Em `lib/ui/core/widgets/session_context_header.dart`, substituir:**

```dart
    super.key,
    required this.companyName,
    required this.subtitle,
    this.logoUrl,
    this.muted = false,
  });

  final String companyName;
  final String? logoUrl;

  /// A segunda linha: o curso e, quando ajuda, a data ("… · 12 set").
  final String subtitle;
```

**por:**

```dart
    super.key,
    required this.companyName,
    required this.subtitle,
    this.title,
    this.logoUrl,
    this.muted = false,
  });

  /// De onde saem o logo e as iniciais — e a primeira linha, sem [title].
  final String companyName;
  final String? logoUrl;

  /// A primeira linha, quando não é só o nome da empresa ("Bracell · 12 set",
  /// canvas "3c").
  final String? title;

  /// A segunda linha: o curso e, quando ajuda, a data ("… · 12 set").
  final String subtitle;
```

**Em `lib/ui/core/widgets/session_context_header.dart`, substituir:**

```dart
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: AppTypography.contextTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
```

**por:**

```dart
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? companyName,
                  style: AppTypography.contextTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
```

**Em `lib/ui/core/widgets/status_chip.dart`, substituir:**

```dart

/// Tom semântico de um chip de status.
enum StatusTone { neutral, info, warning, success, danger, mauve }

/// Chip de status: sempre ícone + texto, nunca só cor (daltonismo e leitura
/// rápida com atenção dividida).
```

**por:**

```dart

/// Tom semântico de um chip de status.
enum StatusTone { neutral, info, warning, success, danger, mauve }

/// Fundo, contorno e tinta de cada tom — os mesmos no [StatusChip] e na
/// [LabelPill].
extension on StatusTone {
  Color get background => switch (this) {
        StatusTone.neutral => AppColors.neutralBg,
        StatusTone.info => AppColors.primarySurface,
        StatusTone.warning => AppColors.warningBg,
        StatusTone.success => AppColors.successBg,
        StatusTone.danger => AppColors.dangerBg,
        StatusTone.mauve => AppColors.mauveSoft,
      };

  Color get border => switch (this) {
        StatusTone.neutral => AppColors.neutralBorder,
        StatusTone.info => AppColors.primary,
        StatusTone.warning => AppColors.warningBorder,
        StatusTone.success => AppColors.successBorder,
        StatusTone.danger => AppColors.dangerBorder,
        StatusTone.mauve => AppColors.mauveBorder,
      };

  Color get ink => switch (this) {
        StatusTone.neutral => AppColors.neutralInk,
        StatusTone.info => AppColors.primaryDark,
        StatusTone.warning => AppColors.warningInk,
        StatusTone.success => AppColors.successInk,
        StatusTone.danger => AppColors.dangerInk,
        StatusTone.mauve => AppColors.mauve,
      };
}

/// Chip de status: sempre ícone + texto, nunca só cor (daltonismo e leitura
/// rápida com atenção dividida).
```

**Em `lib/ui/core/widgets/status_chip.dart`, substituir:**

```dart
  /// avaliação com outra pessoa): mesma cor, contorno mais fraco.
  final bool dashedBorder;

  Color get _background => switch (tone) {
        StatusTone.neutral => AppColors.neutralBg,
        StatusTone.info => AppColors.primarySurface,
        StatusTone.warning => AppColors.warningBg,
        StatusTone.success => AppColors.successBg,
        StatusTone.danger => AppColors.dangerBg,
        StatusTone.mauve => AppColors.mauveSoft,
      };

  Color get _border => switch (tone) {
        StatusTone.neutral => AppColors.neutralBorder,
        StatusTone.info => AppColors.primary,
        StatusTone.warning => AppColors.warningBorder,
        StatusTone.success => AppColors.successBorder,
        StatusTone.danger => AppColors.dangerBorder,
        StatusTone.mauve => AppColors.mauveBorder,
      };

  Color get _ink => switch (tone) {
        StatusTone.neutral => AppColors.neutralInk,
        StatusTone.info => AppColors.primaryDark,
        StatusTone.warning => AppColors.warningInk,
        StatusTone.success => AppColors.successInk,
        StatusTone.danger => AppColors.dangerInk,
        StatusTone.mauve => AppColors.mauve,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: dashedBorder ? _border.withValues(alpha: 0.5) : _border,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _ink),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(label, style: AppTypography.chipLabel.copyWith(color: _ink)),
        ],
      ),
    );
  }
}
```

**por:**

```dart
  /// avaliação com outra pessoa): mesma cor, contorno mais fraco.
  final bool dashedBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: dashedBorder ? tone.border.withValues(alpha: 0.5) : tone.border,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone.ink),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(label, style: AppTypography.chipLabel.copyWith(color: tone.ink)),
        ],
      ),
    );
  }
}

/// Pastilha só de texto, nas cores de um [StatusTone]: um rótulo que não é a
/// situação de nada e por isso dispensa o ícone — o papel do consultor
/// ("Responsável", "Consultor") na tela "Consultores" (canvas "3c").
class LabelPill extends StatelessWidget {
  const LabelPill({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tone.border, width: 1.5),
      ),
      child: Text(label, style: AppTypography.chipLabel.copyWith(color: tone.ink)),
    );
  }
}
```

**Criar `lib/ui/session_consultants/consultant_row.dart`:**

```dart
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/inline_notice.dart';

/// Uma linha da tela 1.13 "Consultores" (canvas "3c"): o nome, uma linha de
/// apoio e, à direita, o papel de quem está na sessão ou o "Adicionar" de
/// quem está na equipe. Quem está na sessão ainda pode ter o aviso da
/// avaliação em andamento e o "Remover da sessão".
///
/// Arquivo próprio por tamanho, não por reuso, como o `participant_row.dart`.
class ConsultantRow extends StatelessWidget {
  const ConsultantRow({
    super.key,
    required this.name,
    required this.trailing,
    this.meta,
    this.metaWraps = false,
    this.note,
    this.action,
  });

  final String name;

  /// A pastilha do papel, ou o botão "Adicionar".
  final Widget trailing;

  /// "2 participantes · 1 em andamento" de quem está na sessão; o e-mail de
  /// quem está na equipe.
  final String? meta;

  /// A linha de apoio quebra em vez de encolher com reticências. O quadro só
  /// corta a de quem está na equipe (o e-mail); a de quem está na sessão é
  /// informação, e aparece inteira.
  final bool metaWraps;

  /// O que acontece com a avaliação em andamento se o consultor sair.
  final String? note;

  /// "Remover da sessão" — o responsável não tem.
  final Widget? action;

  // O vão entre o cabeçalho, o aviso e a ação (10 no canvas).
  static const double _gap = AppSpacing.md - AppSpacing.xxs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg - 1,
      ),
      // O quadro desenha o contorno em cima e embaixo de cada linha: entre
      // duas linhas seguidas, os dois se somam.
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.5),
          bottom: BorderSide(color: AppColors.border, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          if (note != null) ...[
            const SizedBox(height: _gap),
            InlineNotice(
              icon: AppIcons.info,
              tone: NoticeTone.warning,
              message: note!,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: _gap),
            action!,
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(child: _buildIdentity()),
        const SizedBox(width: AppSpacing.md),
        trailing,
      ],
    );
  }

  Widget _buildIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: AppTypography.consultantName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (meta != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            meta!,
            style: AppTypography.meta,
            maxLines: metaWraps ? null : 1,
            overflow: metaWraps ? null : TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
```

As cores de cada tom saíram de dentro do `StatusChip` para uma extensão do `StatusTone`, que o chip e a pastilha nova usam: o chip continua igual. No "Adicionar", o rótulo continua ocupando o lugar dele enquanto o indicador gira (`Visibility` com `maintainSize`), para a largura do botão não mudar.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/widgets test/ui/session_consultants/consultant_row_test.dart`
Esperado: `+66: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+743: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/ui/core/theme/app_icons.dart \
  apps/mobile/simtc/lib/ui/core/theme/app_typography.dart \
  apps/mobile/simtc/lib/ui/core/widgets/app_buttons.dart \
  apps/mobile/simtc/lib/ui/core/widgets/session_context_header.dart \
  apps/mobile/simtc/lib/ui/core/widgets/status_chip.dart \
  apps/mobile/simtc/lib/ui/session_consultants/consultant_row.dart \
  apps/mobile/simtc/test/ui/core/widgets/display_widgets_test.dart \
  apps/mobile/simtc/test/ui/core/widgets/form_widgets_test.dart \
  apps/mobile/simtc/test/ui/session_consultants/consultant_row_test.dart
git commit -m "feat(mobile): componentes do ds para a tela de consultores"
```

---

## Task 7: Os dados da tela de Consultores

A ViewModel da 1.13, sem tela. Três streams do cache — a sessão, os participantes e os consultores — e a equipe, que vem do servidor. Dos participantes saem a segunda linha e o aviso de cada consultor; por isso a tela abre baixando a sessão de novo. Entrar e sair valem na hora: um consultor por toque, um toque de cada vez. Depois de toda mudança aceita, e de toda recusa do servidor, a sessão é baixada de novo — e isso roda mesmo com a tela já fechada, porque o detalhe que fica embaixo lê do mesmo cache.

A chave que ordena nomes sem o acento mandar para o fim já existia no detalhe (`participant_filter.dart`); passa para `lib/ui/core/name_sort.dart`, e as duas listas a usam.

**Files:**
- Create: `lib/ui/core/name_sort.dart`
- Create: `lib/ui/session_consultants/session_consultants_viewmodel.dart`
- Create: `test/ui/core/name_sort_test.dart`
- Create: `test/ui/session_consultants/session_consultants_viewmodel_test.dart`
- Modify: `lib/ui/session_detail/participant_filter.dart`

**Interfaces:**
- Consumes: `SessionRepository.watchSession`; `ParticipantRepository.watchBySession`, `syncSession`; `SessionConsultantRepository` (Task 5); `ConnectivityService.onReconnected`; `AuthUser.isAdmin`, `consultantId`; `SessionStatus.acceptsChanges`; `SessionParticipant.status`, `assignedConsultantId`, `assessedByConsultantId`, `isAssessed`, `hasPreviousAssessment`; `dayMonthLabel`.
- Produces:
  - `String nameSortKey(String name)` (`lib/ui/core/name_sort.dart`).
  - `String consultantMetaLabel({required int total, required int inProgress})`.
  - `class SessionConsultantItem { String id; String name; String displayName; bool isResponsible; String meta; int inProgressCount; String? note; bool get removable; }`.
  - `SessionConsultantsViewModel({required String sessionId, required SessionRepository sessionRepository, required ParticipantRepository participantRepository, required SessionConsultantRepository consultantRepository, required ConnectivityService connectivity, required AuthUser? currentUser})`, com: `init()`; `isLoading`; `session`; `String contextTitle`, `String contextSubtitle`; `bool notDownloaded`; `List<SessionConsultantItem> inSession`; `List<SessionConsultant> available`; `bool isTeamLoading`; `String? teamNotice`; `String? lockedReason`; `bool canChange`; `String? busyConsultantId`; `String? errorMessage`; `String? message` e `clearMessage()`; `Future<void> refresh()`; `Future<void> add(String consultantId)`; `Future<void> remove(String consultantId)`.

- [ ] **Step 1: Escrever os testes que falham**

**Criar `test/ui/core/name_sort_test.dart`:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/name_sort.dart';

void main() {
  test('ignora caixa e acento, para "Ângela" ficar junto de "Ana"', () {
    expect(nameSortKey('Ângela Reis'), 'angela reis');
    expect(nameSortKey('JOSÉ'), 'jose');
    expect(nameSortKey('Conceição'), 'conceicao');

    final names = ['Zeca', 'Ângela', 'ana', 'Érica', 'Bruno']
      ..sort((a, b) => nameSortKey(a).compareTo(nameSortKey(b)));
    expect(names, ['ana', 'Ângela', 'Bruno', 'Érica', 'Zeca']);
  });
}
```

**Criar `test/ui/session_consultants/session_consultants_viewmodel_test.dart`:**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_consultant.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/session_consultants/session_consultants_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockConsultantRepository extends Mock
    implements SessionConsultantRepository {}

/// Conectividade de mentira: o serviço real conversa com o plugin de
/// plataforma, que não existe num teste de unidade.
class _FakeConnectivity extends ConnectivityService {
  final _reconnected = StreamController<void>.broadcast();

  @override
  Stream<void> get onReconnected => _reconnected.stream;

  void reconnect() => _reconnected.add(null);

  @override
  void dispose() {
    _reconnected.close();
    super.dispose();
  }
}

void main() {
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late _MockConsultantRepository consultants;
  late _FakeConnectivity connectivity;
  late StreamController<TrainingSession?> sessionStream;
  late StreamController<List<SessionParticipant>> participantsStream;
  late StreamController<List<SessionConsultant>> consultantsStream;

  const admin = AuthUser(
    id: 'u-admin',
    name: 'Carla Mendes',
    email: 'carla@sim.com',
    role: AppUserRole.admin,
    consultantId: 'c-carla',
  );
  const consultora = AuthUser(
    id: 'u1',
    name: 'Rafael Lima',
    email: 'rafael@sim.com',
    role: AppUserRole.consultant,
    consultantId: 'c-rafael',
  );

  const carla = SessionConsultant(id: 'c-carla', name: 'Carla Mendes');
  const rafael = SessionConsultant(id: 'c-rafael', name: 'Rafael Lima');
  const tatiane = SessionConsultant(id: 'c-tatiane', name: 'Tatiane Souza');
  const diego = SessionConsultant(
    id: 'c-diego',
    name: 'Diego Barbosa',
    email: 'diego@sim.com',
  );
  const patricia = SessionConsultant(id: 'c-patricia', name: 'Patrícia Vaz');

  const offlineError = ApiException(
    message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
    isNetworkError: true,
  );

  TrainingSession session({
    SessionStatus status = SessionStatus.emAndamento,
    String? responsible = 'c-carla',
    int total = 5,
    bool withoutDate = false,
  }) {
    return TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell',
      courseName: 'Direção Defensiva',
      city: 'Itabira',
      state: 'MG',
      date: withoutDate ? null : DateTime(2026, 9, 12),
      status: status,
      totalParticipants: total,
      assessableParticipants: total,
      assessedParticipants: 0,
      responsibleConsultantId: responsible,
      participantsSyncedAt: DateTime(2026, 9, 12, 8),
    );
  }

  SessionParticipant participant(
    String name, {
    ParticipantStatus status = ParticipantStatus.pendente,
    String? assignedTo,
    String? assessedBy,
    double? score,
    ParticipationType type = ParticipationType.teoricaEPratica,
  }) {
    return SessionParticipant(
      id: 'tp-$name',
      sessionId: 'sess-1',
      name: name,
      maskedCpf: '042.118.***-**',
      participationType: type,
      status: status,
      assignedConsultantId: assignedTo,
      assessedByConsultantId: assessedBy,
      score: score,
    );
  }

  SessionParticipant evaluating(String name, String consultantId, {double? score}) {
    return participant(
      name,
      status: ParticipantStatus.emAvaliacao,
      assignedTo: consultantId,
      score: score,
    );
  }

  SessionParticipant approved(String name, String consultantId) {
    return participant(
      name,
      status: ParticipantStatus.aprovado,
      assessedBy: consultantId,
      score: 90,
    );
  }

  setUp(() {
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    consultants = _MockConsultantRepository();
    connectivity = _FakeConnectivity();
    sessionStream = StreamController<TrainingSession?>.broadcast();
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();
    consultantsStream = StreamController<List<SessionConsultant>>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => consultants.watchBySession('sess-1'))
        .thenAnswer((_) => consultantsStream.stream);
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
    when(() => consultants.fetchTeam()).thenAnswer(
      (_) async => const Success([carla, diego, patricia, rafael, tatiane]),
    );
    when(() => consultants.add('sess-1', any()))
        .thenAnswer((_) async => const Success<void>(null));
    when(() => consultants.remove('sess-1', any()))
        .thenAnswer((_) async => const Success<void>(null));
  });

  tearDown(() {
    sessionStream.close();
    participantsStream.close();
    consultantsStream.close();
    connectivity.dispose();
  });

  SessionConsultantsViewModel build({AuthUser? user = admin}) {
    final vm = SessionConsultantsViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      consultantRepository: consultants,
      connectivity: connectivity,
      currentUser: user,
    )..init();
    addTearDown(vm.dispose);
    return vm;
  }

  /// A tela aberta, com o cache lido e a equipe já carregada.
  Future<SessionConsultantsViewModel> open({
    AuthUser? user = admin,
    TrainingSession? withSession,
    bool missing = false,
    List<SessionConsultant> inSession = const [carla, rafael, tatiane],
    List<SessionParticipant> people = const [],
  }) async {
    final vm = build(user: user);
    sessionStream.add(missing ? null : (withSession ?? session()));
    consultantsStream.add(inSession);
    participantsStream.add(people);
    await pumpEventQueue();
    return vm;
  }

  group('abertura', () {
    test('antes da primeira leitura do cache, está carregando', () {
      final vm = build();

      expect(vm.isLoading, isTrue);
      expect(vm.canChange, isFalse);
      // Carregando não é "ainda não baixados".
      expect(vm.notDownloaded, isFalse);
    });

    test('busca a equipe e baixa a sessão de novo', () async {
      final vm = await open();

      expect(vm.isLoading, isFalse);
      verify(() => consultants.fetchTeam()).called(1);
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('o contexto diz a empresa, a data e quanta gente tem', () async {
      final vm = await open();

      expect(vm.contextTitle, 'Bracell · 12 set');
      expect(vm.contextSubtitle, '5 participantes · 3 consultores');
    });

    test('o contexto no singular, e sem data', () async {
      final vm = await open(
        withSession: session(total: 1, withoutDate: true),
        inSession: const [carla],
      );

      expect(vm.contextTitle, 'Bracell');
      expect(vm.contextSubtitle, '1 participante · 1 consultor');
    });

    test('sem os consultores no aparelho, o contexto só conta os participantes, '
        'e a tela diz que ainda não foram baixados', () async {
      final vm = await open(inSession: const []);

      expect(vm.contextSubtitle, '5 participantes');
      expect(vm.inSession, isEmpty);
      expect(vm.notDownloaded, isTrue);
    });

    test('com os consultores no aparelho, não há o que baixar', () async {
      final vm = await open();

      expect(vm.notDownloaded, isFalse);
    });
  });

  group('na sessão', () {
    test('o responsável vem primeiro, e os outros por nome, sem o acento '
        'mandar para o fim', () async {
      const angela = SessionConsultant(id: 'c-angela', name: 'Ângela Reis');
      final vm = await open(
        withSession: session(responsible: 'c-rafael'),
        inSession: const [carla, rafael, tatiane, angela],
      );

      expect(
        vm.inSession.map((c) => c.name),
        ['Rafael Lima', 'Ângela Reis', 'Carla Mendes', 'Tatiane Souza'],
      );
      expect(vm.inSession.first.isResponsible, isTrue);
      expect(vm.inSession.skip(1).map((c) => c.isResponsible), everyElement(isFalse));
    });

    test('o consultor do usuário logado leva "(você)"; os outros, não',
        () async {
      final vm = await open();

      expect(
        vm.inSession.map((c) => c.displayName),
        ['Carla Mendes (você)', 'Rafael Lima', 'Tatiane Souza'],
      );
    });

    test('a linha de apoio conta os participantes de cada um neste aparelho',
        () async {
      final vm = await open(
        people: [
          evaluating('Ana Paula', 'c-carla'),
          approved('Bruno Dias', 'c-carla'),
          evaluating('Marcos Vinícius', 'c-rafael'),
          approved('Juliana Costa', 'c-tatiane'),
          approved('Rodrigo Tavares', 'c-tatiane'),
          // Ninguém pegou, e quem só faz a teórica: não são de consultor nenhum.
          participant('Sem Dono'),
          participant('Só Teórica', type: ParticipationType.somenteTeorica),
        ],
      );

      expect(vm.inSession.map((c) => c.meta), [
        '2 participantes · 1 em andamento',
        '1 participante · 1 em andamento',
        '2 participantes concluídos',
      ]);
      expect(vm.inSession.map((c) => c.inProgressCount), [1, 1, 0]);
    });

    test('um só concluído vai no singular, e quem não tem ninguém diz isso',
        () async {
      final vm = await open(people: [approved('Bruno Dias', 'c-rafael')]);

      expect(vm.inSession.map((c) => c.meta), [
        'Sem participantes',
        '1 participante concluído',
        'Sem participantes',
      ]);
    });

    test('o responsável não sai; os outros podem sair', () async {
      final vm = await open();

      expect(vm.inSession.map((c) => c.removable), [false, true, true]);
    });

    test('com uma avaliação em andamento, o aviso diz quem volta para Pendente',
        () async {
      final vm = await open(people: [evaluating('Marcos Vinícius', 'c-rafael')]);

      expect(
        vm.inSession[1].note,
        'Tem 1 avaliação em andamento. Remover devolve Marcos Vinícius para '
        'Pendente.',
      );
      expect(vm.inSession[2].note, isNull);
    });

    test('numa reavaliação, o participante volta para Não recomendado',
        () async {
      final vm = await open(
        people: [evaluating('Marcos Vinícius', 'c-rafael', score: 62)],
      );

      expect(
        vm.inSession[1].note,
        'Tem 1 avaliação em andamento. Remover devolve Marcos Vinícius para '
        'Não recomendado.',
      );
    });

    test('com duas ou mais, o aviso fala de todos', () async {
      final vm = await open(
        people: [
          evaluating('Marcos Vinícius', 'c-rafael'),
          evaluating('Ana Paula', 'c-rafael'),
        ],
      );

      expect(
        vm.inSession[1].note,
        'Tem 2 avaliações em andamento. Remover libera esses participantes '
        'para outro consultor.',
      );
    });

    test('o responsável não tem aviso, mesmo com avaliação em andamento',
        () async {
      final vm = await open(people: [evaluating('Ana Paula', 'c-carla')]);

      expect(vm.inSession.first.note, isNull);
      expect(vm.inSession.first.inProgressCount, 1);
    });
  });

  group('equipe', () {
    test('mostra quem é da equipe e ainda não está na sessão, por nome',
        () async {
      final vm = await open();

      expect(vm.available, const [diego, patricia]);
      expect(vm.teamNotice, isNull);
      expect(vm.isTeamLoading, isFalse);
    });

    test('a equipe fica por nome, sem depender da ordem do servidor nem do '
        'acento', () async {
      const angela = SessionConsultant(id: 'c-angela', name: 'Ângela Reis');
      when(() => consultants.fetchTeam())
          .thenAnswer((_) async => const Success([patricia, diego, angela]));
      final vm = await open();

      expect(vm.available, const [angela, diego, patricia]);
    });

    test('enquanto a equipe não chega, está carregando, sem aviso', () async {
      final answer = Completer<Result<List<SessionConsultant>>>();
      when(() => consultants.fetchTeam()).thenAnswer((_) => answer.future);
      final vm = await open();

      expect(vm.isTeamLoading, isTrue);
      expect(vm.available, isEmpty);
      expect(vm.teamNotice, isNull);

      answer.complete(const Success([diego]));
      await pumpEventQueue();

      expect(vm.isTeamLoading, isFalse);
      expect(vm.available, const [diego]);
    });

    test('quem entra na sessão sai da lista da equipe', () async {
      final vm = await open();

      consultantsStream.add(const [carla, rafael, tatiane, diego]);
      await pumpEventQueue();

      expect(vm.available, const [patricia]);
    });

    test('com todos já na sessão, a tela diz isso', () async {
      when(() => consultants.fetchTeam())
          .thenAnswer((_) async => const Success([carla, rafael]));
      final vm = await open();

      expect(vm.available, isEmpty);
      expect(
        vm.teamNotice,
        'Todos os consultores ativos da equipe já estão nesta sessão.',
      );
    });

    test('sem rede, a equipe fica para quando houver conexão — e carrega '
        'sozinha quando a rede volta', () async {
      when(() => consultants.fetchTeam())
          .thenAnswer((_) async => const Failure(offlineError, 'sem rede'));
      final vm = await open();

      expect(vm.available, isEmpty);
      expect(vm.teamNotice, 'A equipe aparece quando houver conexão.');

      when(() => consultants.fetchTeam())
          .thenAnswer((_) async => const Success([diego]));
      connectivity.reconnect();
      await pumpEventQueue();

      expect(vm.available, const [diego]);
      expect(vm.teamNotice, isNull);
      // A volta da rede também baixa a sessão de novo.
      verify(() => participants.syncSession('sess-1')).called(2);
    });

    test('outra falha pede para puxar, e atualizar carrega a equipe', () async {
      when(() => consultants.fetchTeam()).thenAnswer(
        (_) async => const Failure(
          ApiException(message: 'Internal server error', statusCode: 500),
          'Não foi possível carregar a equipe.',
        ),
      );
      final vm = await open();

      expect(
        vm.teamNotice,
        'Não foi possível carregar a equipe. Puxe para atualizar.',
      );

      when(() => consultants.fetchTeam())
          .thenAnswer((_) async => const Success([diego]));
      await vm.refresh();

      expect(vm.available, const [diego]);
      expect(vm.teamNotice, isNull);
    });

    test('uma exceção ao buscar a equipe não trava a tela', () async {
      when(() => consultants.fetchTeam()).thenThrow(StateError('quebrou'));
      final vm = await open();

      expect(vm.isTeamLoading, isFalse);
      expect(
        vm.teamNotice,
        'Não foi possível carregar a equipe. Puxe para atualizar.',
      );
    });

    test('uma falha ao atualizar não apaga a equipe que já estava na tela',
        () async {
      final vm = await open();

      when(() => consultants.fetchTeam())
          .thenAnswer((_) async => const Failure(offlineError, 'sem rede'));
      await vm.refresh();

      expect(vm.available, const [diego, patricia]);
      expect(vm.teamNotice, isNull);
    });

    test('ao atualizar com a equipe já na tela, a lista continua — não volta '
        'para o carregando', () async {
      final vm = await open();
      final answer = Completer<Result<List<SessionConsultant>>>();
      when(() => consultants.fetchTeam()).thenAnswer((_) => answer.future);

      final refreshing = vm.refresh();
      await pumpEventQueue();

      expect(vm.isTeamLoading, isFalse);
      expect(vm.available, const [diego, patricia]);

      answer.complete(const Success([diego]));
      await refreshing;
      expect(vm.available, const [diego]);
    });

    test('a volta da rede no meio de uma busca não dispara outra por cima',
        () async {
      final answer = Completer<Result<List<SessionConsultant>>>();
      when(() => consultants.fetchTeam()).thenAnswer((_) => answer.future);
      final vm = await open();

      connectivity.reconnect();
      await pumpEventQueue();

      verify(() => consultants.fetchTeam()).called(1);

      answer.complete(const Success([diego]));
      await pumpEventQueue();
      expect(vm.available, const [diego]);
    });

    test('uma falha ao baixar a sessão não trava nem avisa: a tela segue com '
        'o que tem', () async {
      when(() => participants.syncSession('sess-1'))
          .thenThrow(StateError('quebrou'));
      final vm = await open();

      await vm.refresh();

      expect(vm.errorMessage, isNull);
      expect(vm.message, isNull);
      expect(vm.available, const [diego, patricia]);
    });
  });

  group('quem pode mudar', () {
    test('o admin, numa sessão em andamento ou planejada', () async {
      final running = await open();
      expect(running.lockedReason, isNull);
      expect(running.canChange, isTrue);

      final planned = await open(
        withSession: session(status: SessionStatus.planejado),
      );
      expect(planned.canChange, isTrue);
    });

    test('consultor comum vê a lista travada, com o motivo', () async {
      final vm = await open(user: consultora);

      expect(vm.canChange, isFalse);
      expect(
        vm.lockedReason,
        'Só administradores podem mudar os consultores da sessão.',
      );

      await vm.add('c-diego');
      await vm.remove('c-tatiane');
      verifyNever(() => consultants.add(any(), any()));
      verifyNever(() => consultants.remove(any(), any()));
    });

    test('sessão concluída ou cancelada trava, com o motivo', () async {
      final done = await open(
        withSession: session(status: SessionStatus.concluido),
      );
      expect(done.canChange, isFalse);
      expect(
        done.lockedReason,
        'Sessão concluída: os consultores não podem mais ser alterados.',
      );

      final cancelled = await open(
        withSession: session(status: SessionStatus.cancelado),
      );
      expect(
        cancelled.lockedReason,
        'Sessão cancelada: os consultores não podem mais ser alterados.',
      );

      await done.add('c-diego');
      verifyNever(() => consultants.add(any(), any()));
    });

    test('sessão que não está no aparelho', () async {
      final vm = await open(missing: true);

      expect(vm.isLoading, isFalse);
      expect(vm.session, isNull);
      expect(vm.canChange, isFalse);
      expect(
        vm.lockedReason,
        'Esta sessão não está mais disponível neste aparelho.',
      );
    });

    test('a sessão ser concluída por outra pessoa trava a tela aberta',
        () async {
      final vm = await open();
      expect(vm.canChange, isTrue);

      sessionStream.add(session(status: SessionStatus.concluido));
      await pumpEventQueue();

      expect(vm.canChange, isFalse);
    });
  });

  group('adicionar', () {
    test('manda o consultor, avisa que entrou e baixa a sessão de novo',
        () async {
      final vm = await open();
      clearInteractions(participants);

      await vm.add('c-diego');

      verify(() => consultants.add('sess-1', 'c-diego')).called(1);
      expect(vm.message, 'Diego Barbosa entrou na sessão.');
      expect(vm.errorMessage, isNull);
      expect(vm.busyConsultantId, isNull);
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('durante o envio, só aquele consultor aparece ocupado, e outro toque '
        'não manda nada', () async {
      final answer = Completer<Result<void>>();
      when(() => consultants.add('sess-1', 'c-diego'))
          .thenAnswer((_) => answer.future);
      final vm = await open();

      final sending = vm.add('c-diego');
      await pumpEventQueue();

      expect(vm.busyConsultantId, 'c-diego');
      expect(vm.message, isNull);

      await vm.add('c-patricia');
      await vm.add('c-diego');
      await vm.remove('c-tatiane');
      verifyNever(() => consultants.add('sess-1', 'c-patricia'));
      verifyNever(() => consultants.remove(any(), any()));

      answer.complete(const Success<void>(null));
      await sending;

      verify(() => consultants.add('sess-1', 'c-diego')).called(1);
      expect(vm.busyConsultantId, isNull);
      expect(vm.message, 'Diego Barbosa entrou na sessão.');
    });

    test('quem não está na lista da equipe não é adicionado', () async {
      final vm = await open();

      await vm.add('c-nao-existe');
      // Já está na sessão: não aparece em "Disponíveis".
      await vm.add('c-rafael');

      verifyNever(() => consultants.add(any(), any()));
      expect(vm.message, isNull);
    });

    test('recusado pelo servidor: mostra o motivo, baixa a sessão e busca a '
        'equipe de novo', () async {
      when(() => consultants.add('sess-1', 'c-diego')).thenAnswer(
        (_) async => const Failure(
          ApiException(
            message: 'Consultor inativo não pode entrar em um treinamento',
            statusCode: 400,
          ),
          'Consultor inativo não pode entrar em um treinamento',
        ),
      );
      final vm = await open();
      clearInteractions(participants);
      clearInteractions(consultants);

      await vm.add('c-diego');
      await pumpEventQueue();

      expect(
        vm.errorMessage,
        'Consultor inativo não pode entrar em um treinamento',
      );
      expect(vm.message, isNull);
      expect(vm.busyConsultantId, isNull);
      verify(() => participants.syncSession('sess-1')).called(1);
      verify(() => consultants.fetchTeam()).called(1);
    });

    for (final status in const [403, 404, 409]) {
      test('recusa $status também baixa a sessão de novo', () async {
        when(() => consultants.add('sess-1', 'c-diego')).thenAnswer(
          (_) async => Failure(
            ApiException(message: 'recusado', statusCode: status),
            'recusado',
          ),
        );
        final vm = await open();
        clearInteractions(participants);

        await vm.add('c-diego');
        await pumpEventQueue();

        expect(vm.errorMessage, 'recusado');
        verify(() => participants.syncSession('sess-1')).called(1);
      });
    }

    test('sem rede: mostra o motivo e não baixa nada', () async {
      when(() => consultants.add('sess-1', 'c-diego')).thenAnswer(
        (_) async => const Failure(offlineError, 'Sem conexão com o servidor.'),
      );
      final vm = await open();
      clearInteractions(participants);
      clearInteractions(consultants);

      await vm.add('c-diego');
      await pumpEventQueue();

      expect(vm.errorMessage, 'Sem conexão com o servidor.');
      verifyNever(() => participants.syncSession(any()));
      verifyNever(() => consultants.fetchTeam());
    });

    test('erro do servidor (500): mostra o motivo e não baixa nada', () async {
      when(() => consultants.add('sess-1', 'c-diego')).thenAnswer(
        (_) async => const Failure(
          ApiException(message: 'Internal server error', statusCode: 500),
          'Não foi possível adicionar o consultor. Tente de novo.',
        ),
      );
      final vm = await open();
      clearInteractions(participants);

      await vm.add('c-diego');
      await pumpEventQueue();

      expect(
        vm.errorMessage,
        'Não foi possível adicionar o consultor. Tente de novo.',
      );
      verifyNever(() => participants.syncSession(any()));
    });

    test('uma exceção inesperada vira a mensagem genérica, sem travar a tela',
        () async {
      when(() => consultants.add('sess-1', 'c-diego'))
          .thenThrow(StateError('quebrou'));
      final vm = await open();

      await vm.add('c-diego');

      expect(
        vm.errorMessage,
        'Não foi possível adicionar o consultor. Tente de novo.',
      );
      expect(vm.busyConsultantId, isNull);
    });

    test('uma nova tentativa apaga o aviso da falha anterior', () async {
      when(() => consultants.add('sess-1', 'c-diego')).thenAnswer(
        (_) async => const Failure(offlineError, 'Sem conexão com o servidor.'),
      );
      final vm = await open();
      await vm.add('c-diego');
      expect(vm.errorMessage, isNotNull);

      final answer = Completer<Result<void>>();
      when(() => consultants.add('sess-1', 'c-diego'))
          .thenAnswer((_) => answer.future);
      final sending = vm.add('c-diego');
      await pumpEventQueue();

      expect(vm.errorMessage, isNull, reason: 'o aviso some já no toque');

      answer.complete(const Success<void>(null));
      await sending;
      expect(vm.errorMessage, isNull);
    });
  });

  group('remover', () {
    test('manda o consultor, avisa que saiu (sem o "(você)") e baixa a sessão '
        'de novo', () async {
      // O admin é consultor da sessão sem ser o responsável: pode se tirar.
      final vm = await open(withSession: session(responsible: 'c-rafael'));
      clearInteractions(participants);

      await vm.remove('c-carla');

      verify(() => consultants.remove('sess-1', 'c-carla')).called(1);
      expect(vm.message, 'Carla Mendes saiu da sessão.');
      expect(vm.errorMessage, isNull);
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('o responsável não é removido', () async {
      final vm = await open();

      await vm.remove('c-carla');

      verifyNever(() => consultants.remove(any(), any()));
    });

    test('quem não está na sessão não é removido', () async {
      final vm = await open();

      await vm.remove('c-diego');

      verifyNever(() => consultants.remove(any(), any()));
    });

    test('recusado pelo servidor: mostra o motivo e baixa a sessão de novo',
        () async {
      when(() => consultants.remove('sess-1', 'c-rafael')).thenAnswer(
        (_) async => const Failure(
          ApiException(
            message: 'Não é possível editar um treinamento concluído ou cancelado',
            statusCode: 403,
          ),
          'Não é possível editar um treinamento concluído ou cancelado',
        ),
      );
      final vm = await open();
      clearInteractions(participants);

      await vm.remove('c-rafael');
      await pumpEventQueue();

      expect(
        vm.errorMessage,
        'Não é possível editar um treinamento concluído ou cancelado',
      );
      expect(vm.message, isNull);
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('uma exceção inesperada vira a mensagem genérica', () async {
      when(() => consultants.remove('sess-1', 'c-rafael'))
          .thenThrow(StateError('quebrou'));
      final vm = await open();

      await vm.remove('c-rafael');

      expect(
        vm.errorMessage,
        'Não foi possível remover o consultor. Tente de novo.',
      );
    });

    test('dois toques rápidos removem uma vez só', () async {
      final answer = Completer<Result<void>>();
      when(() => consultants.remove('sess-1', 'c-rafael'))
          .thenAnswer((_) => answer.future);
      final vm = await open();

      final first = vm.remove('c-rafael');
      final second = vm.remove('c-rafael');
      await pumpEventQueue();
      expect(vm.busyConsultantId, 'c-rafael');

      answer.complete(const Success<void>(null));
      await Future.wait([first, second]);

      verify(() => consultants.remove('sess-1', 'c-rafael')).called(1);
    });
  });

  test('o aviso passageiro some quando a tela o consome', () async {
    final vm = await open();
    await vm.add('c-diego');
    expect(vm.message, isNotNull);

    vm.clearMessage();

    expect(vm.message, isNull);
  });

  test('fechar a tela com a resposta ainda viajando não derruba o app — e a '
      'sessão é baixada de novo mesmo assim', () async {
    final answer = Completer<Result<void>>();
    when(() => consultants.remove('sess-1', 'c-rafael'))
        .thenAnswer((_) => answer.future);
    final vm = SessionConsultantsViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      consultantRepository: consultants,
      connectivity: connectivity,
      currentUser: admin,
    )..init();
    sessionStream.add(session());
    consultantsStream.add(const [carla, rafael, tatiane]);
    participantsStream.add(const []);
    await pumpEventQueue();
    clearInteractions(participants);

    final sending = vm.remove('c-rafael');
    await pumpEventQueue();
    vm.dispose();

    answer.complete(const Success<void>(null));
    await sending;
    await pumpEventQueue();

    // Quem estava com o consultor foi liberado no servidor: o detalhe, que
    // ficou embaixo, lê do cache.
    verify(() => participants.syncSession('sess-1')).called(1);
  });

  group('rótulos', () {
    test('consultantMetaLabel', () {
      expect(consultantMetaLabel(total: 0, inProgress: 0), 'Sem participantes');
      expect(
        consultantMetaLabel(total: 1, inProgress: 0),
        '1 participante concluído',
      );
      expect(
        consultantMetaLabel(total: 3, inProgress: 0),
        '3 participantes concluídos',
      );
      expect(
        consultantMetaLabel(total: 1, inProgress: 1),
        '1 participante · 1 em andamento',
      );
      expect(
        consultantMetaLabel(total: 4, inProgress: 2),
        '4 participantes · 2 em andamento',
      );
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_consultants/session_consultants_viewmodel_test.dart test/ui/core/name_sort_test.dart test/ui/session_detail/participant_filter_test.dart`
Esperado: os dois arquivos novos não compilam — `Error when reading 'lib/ui/session_consultants/session_consultants_viewmodel.dart'` e `Error when reading 'lib/ui/core/name_sort.dart'`. O `participant_filter_test.dart` já passa, e tem de continuar passando depois do Step 3.

- [ ] **Step 3: Implementar**

**Criar `lib/ui/core/name_sort.dart`:**

```dart
const Map<String, String> _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c',
};

/// Chave de ordenação por nome que põe "Ângela" junto de "Ana", e não depois
/// de "Zeca" — o SQLite só ignora caixa em letras sem acento. Serve às listas
/// de participantes e de consultores.
String nameSortKey(String name) {
  final lower = name.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_semAcento[char] ?? char);
  }
  return buffer.toString();
}
```

**Criar `lib/ui/session_consultants/session_consultants_viewmodel.dart`:**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/models/session_consultant.dart';
import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_consultant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../data/services/connectivity_service.dart';
import '../../utils/result.dart';
import '../core/date_labels.dart';
import '../core/name_sort.dart';

/// A segunda linha de quem está na sessão, pelos participantes deste
/// aparelho: "2 participantes · 1 em andamento", "2 participantes concluídos"
/// ou "Sem participantes" (canvas "3c").
String consultantMetaLabel({required int total, required int inProgress}) {
  if (total == 0) return 'Sem participantes';
  if (inProgress == 0) {
    return total == 1
        ? '1 participante concluído'
        : '$total participantes concluídos';
  }
  final people = total == 1 ? '1 participante' : '$total participantes';
  return '$people · $inProgress em andamento';
}

/// Uma linha de "Na sessão".
class SessionConsultantItem {
  const SessionConsultantItem({
    required this.id,
    required this.name,
    required this.displayName,
    required this.isResponsible,
    required this.meta,
    required this.inProgressCount,
    this.note,
  });

  /// `Consultant.id`.
  final String id;

  /// O nome puro, para os avisos ("Rafael Lima saiu da sessão.").
  final String name;

  /// O nome como a linha mostra: o do usuário logado leva "(você)".
  final String displayName;

  /// O responsável pela sessão não sai por aqui: trocar o responsável é do
  /// painel web.
  final bool isResponsible;
  final String meta;

  /// Quantos participantes estão em avaliação com ele agora.
  final int inProgressCount;

  /// O que acontece com essas avaliações se ele sair. Só quem pode sair tem.
  final String? note;

  bool get removable => !isResponsible;
}

/// Por que a equipe não está na tela.
enum _TeamFailure { none, unreachable, failed }

/// Estado da tela 1.13 "Consultores" (Fase 6B, canvas "3c"), só para ADMIN.
///
/// Quem está na sessão e os participantes vêm do cache, pelos streams; a
/// equipe vem do servidor a cada abertura e não fica guardada. Entrar e sair
/// valem na hora: um consultor por toque, e um toque de cada vez.
class SessionConsultantsViewModel extends ChangeNotifier {
  SessionConsultantsViewModel({
    required this.sessionId,
    required SessionRepository sessionRepository,
    required ParticipantRepository participantRepository,
    required SessionConsultantRepository consultantRepository,
    required ConnectivityService connectivity,
    required AuthUser? currentUser,
  })  : _sessionRepository = sessionRepository,
        _participantRepository = participantRepository,
        _consultantRepository = consultantRepository,
        _connectivity = connectivity,
        _currentUser = currentUser;

  final String sessionId;
  final SessionRepository _sessionRepository;
  final ParticipantRepository _participantRepository;
  final SessionConsultantRepository _consultantRepository;
  final ConnectivityService _connectivity;
  final AuthUser? _currentUser;

  static const String _addFailed =
      'Não foi possível adicionar o consultor. Tente de novo.';
  static const String _removeFailed =
      'Não foi possível remover o consultor. Tente de novo.';

  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<List<SessionParticipant>>? _participantsSubscription;
  StreamSubscription<List<SessionConsultant>>? _consultantsSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  bool _disposed = false;
  bool _sessionLoaded = false;
  bool _participantsLoaded = false;
  bool _consultantsLoaded = false;
  TrainingSession? _session;
  List<SessionParticipant> _participants = const [];
  List<SessionConsultant> _consultants = const [];

  /// Os consultores ativos da equipe. Nulo enquanto não chegaram.
  List<SessionConsultant>? _team;
  bool _teamLoading = false;
  _TeamFailure _teamFailure = _TeamFailure.none;

  String? _busyConsultantId;
  String? _error;
  String? _message;

  /// Antes da primeira leitura do cache.
  bool get isLoading =>
      !_sessionLoaded || !_participantsLoaded || !_consultantsLoaded;

  /// Nula depois de carregada quer dizer que a sessão não está mais no
  /// aparelho.
  TrainingSession? get session => _session;

  /// "Bracell · 12 set", a primeira linha da faixa de contexto.
  String get contextTitle {
    final session = _session;
    if (session == null) return '';
    final date = session.date;
    return date == null
        ? session.companyName
        : '${session.companyName} · ${dayMonthLabel(date)}';
  }

  /// "5 participantes · 3 consultores". Sem os consultores no aparelho, só
  /// os participantes.
  String get contextSubtitle {
    final total = _session?.totalParticipants ?? 0;
    final people = total == 1 ? '1 participante' : '$total participantes';
    if (_consultants.isEmpty) return people;
    final count = _consultants.length;
    return '$people · ${count == 1 ? '1 consultor' : '$count consultores'}';
  }

  /// Os consultores desta sessão ainda não foram baixados neste aparelho —
  /// uma sessão que foi para o cache antes de o app guardar os consultores, e
  /// que ainda não foi aberta com conexão.
  bool get notDownloaded => !isLoading && _consultants.isEmpty;

  /// "Na sessão": o responsável primeiro, e os outros por nome.
  List<SessionConsultantItem> get inSession {
    final responsibleId = _session?.responsibleConsultantId;
    final sorted = [..._consultants]..sort((a, b) {
        final aFirst = a.id == responsibleId ? 0 : 1;
        final bFirst = b.id == responsibleId ? 0 : 1;
        if (aFirst != bFirst) return aFirst.compareTo(bFirst);
        return nameSortKey(a.name).compareTo(nameSortKey(b.name));
      });
    return [for (final consultant in sorted) _itemFor(consultant, responsibleId)];
  }

  SessionConsultantItem _itemFor(
    SessionConsultant consultant,
    String? responsibleId,
  ) {
    final inProgress = _participants
        .where((p) =>
            p.status == ParticipantStatus.emAvaliacao &&
            p.assignedConsultantId == consultant.id)
        .toList(growable: false);
    final concluded = _participants
        .where((p) => p.isAssessed && p.assessedByConsultantId == consultant.id)
        .length;
    final isResponsible = consultant.id == responsibleId;
    final isMe = consultant.id == _currentUser?.consultantId;

    return SessionConsultantItem(
      id: consultant.id,
      name: consultant.name,
      displayName: isMe ? '${consultant.name} (você)' : consultant.name,
      isResponsible: isResponsible,
      meta: consultantMetaLabel(
        total: inProgress.length + concluded,
        inProgress: inProgress.length,
      ),
      inProgressCount: inProgress.length,
      note: isResponsible ? null : _removalNote(inProgress),
    );
  }

  /// A mesma regra do backend ao liberar: quem nunca foi avaliado volta para
  /// "Pendente"; numa reavaliação, para o status da nota anterior ("Não
  /// recomendado" — aprovado não é reavaliado).
  String? _removalNote(List<SessionParticipant> inProgress) {
    if (inProgress.isEmpty) return null;
    if (inProgress.length > 1) {
      return 'Tem ${inProgress.length} avaliações em andamento. Remover '
          'libera esses participantes para outro consultor.';
    }
    final participant = inProgress.single;
    final status =
        participant.hasPreviousAssessment ? 'Não recomendado' : 'Pendente';
    return 'Tem 1 avaliação em andamento. Remover devolve '
        '${participant.name} para $status.';
  }

  /// "Disponíveis na equipe": os ativos que ainda não estão na sessão, por
  /// nome.
  List<SessionConsultant> get available {
    final team = _team;
    if (team == null) return const [];
    final inSession = {for (final consultant in _consultants) consultant.id};
    return team.where((c) => !inSession.contains(c.id)).toList(growable: false)
      ..sort((a, b) => nameSortKey(a.name).compareTo(nameSortKey(b.name)));
  }

  /// A primeira busca da equipe ainda não respondeu.
  bool get isTeamLoading => _teamLoading && _team == null;

  /// O que a tela escreve no lugar da equipe; nulo quando há lista (ou
  /// enquanto ela carrega).
  String? get teamNotice {
    if (_team != null) {
      return available.isEmpty
          ? 'Todos os consultores ativos da equipe já estão nesta sessão.'
          : null;
    }
    return switch (_teamFailure) {
      _TeamFailure.none => null,
      _TeamFailure.unreachable => 'A equipe aparece quando houver conexão.',
      _TeamFailure.failed =>
        'Não foi possível carregar a equipe. Puxe para atualizar.',
    };
  }

  /// Por que nada pode mudar; nulo quando pode. O motivo fica escrito na
  /// tela — os botões nunca somem, só apagam.
  String? get lockedReason {
    if (_currentUser?.isAdmin != true) {
      return 'Só administradores podem mudar os consultores da sessão.';
    }
    final session = _session;
    if (session == null) {
      return 'Esta sessão não está mais disponível neste aparelho.';
    }
    if (session.status.acceptsChanges) return null;
    return session.status == SessionStatus.cancelado
        ? 'Sessão cancelada: os consultores não podem mais ser alterados.'
        : 'Sessão concluída: os consultores não podem mais ser alterados.';
  }

  /// O backend só aceita mexer nos consultores de uma sessão planejada ou em
  /// andamento, e só de um ADMIN. A tela ainda exige conexão.
  bool get canChange => !isLoading && lockedReason == null;

  /// O consultor que está entrando ou saindo agora — um de cada vez.
  String? get busyConsultantId => _busyConsultantId;

  /// Falha do último adicionar ou remover, mostrada na própria tela; some no
  /// próximo toque.
  String? get errorMessage => _error;

  /// Aviso passageiro (SnackBar): quem entrou ou saiu.
  String? get message => _message;

  /// Assina o cache, busca a equipe e baixa a sessão de novo. Chamado uma
  /// vez pela tela.
  void init() {
    _sessionSubscription ??=
        _sessionRepository.watchSession(sessionId).listen((session) {
      _session = session;
      _sessionLoaded = true;
      notifyListeners();
    });

    _participantsSubscription ??= _participantRepository
        .watchBySession(sessionId)
        .listen((participants) {
      _participants = participants;
      _participantsLoaded = true;
      notifyListeners();
    });

    _consultantsSubscription ??= _consultantRepository
        .watchBySession(sessionId)
        .listen((consultants) {
      _consultants = consultants;
      _consultantsLoaded = true;
      notifyListeners();
    });

    _reconnectSubscription ??=
        _connectivity.onReconnected.listen((_) => refresh());

    unawaited(refresh());
  }

  /// Abertura da tela, puxar para atualizar e volta da conexão caem aqui: a
  /// equipe vem de novo do servidor, e a sessão é baixada de novo — é dos
  /// participantes dela que saem a linha de apoio e o aviso de cada consultor.
  Future<void> refresh() async {
    await Future.wait([_loadTeam(), _resyncSession()]);
  }

  Future<void> _loadTeam() async {
    if (_teamLoading || _disposed) return;

    _teamLoading = true;
    notifyListeners();
    try {
      final result = await _consultantRepository.fetchTeam();
      switch (result) {
        case Success(:final data):
          _team = data;
          _teamFailure = _TeamFailure.none;
        case Failure(:final exception):
          // A equipe que já estava na tela fica: `teamNotice` só olha a
          // falha enquanto não há lista.
          _teamFailure = exception is ApiException && exception.isNetworkError
              ? _TeamFailure.unreachable
              : _TeamFailure.failed;
      }
    } catch (_) {
      _teamFailure = _TeamFailure.failed;
    } finally {
      _teamLoading = false;
      notifyListeners();
    }
  }

  /// Sem aviso na falha: a tela segue com o que o cache tem, e sem conexão a
  /// faixa do topo já diz por quê. Não passa pelo estado desta ViewModel — é
  /// só o cache que muda —, e por isso roda mesmo depois de a tela fechar: o
  /// detalhe, que fica embaixo, lê do mesmo cache.
  Future<void> _resyncSession() async {
    try {
      await _participantRepository.syncSession(sessionId);
    } catch (_) {
      // `syncSession` já devolve `Result` para todo erro esperado.
    }
  }

  /// "Adicionar": põe na sessão um consultor da equipe.
  Future<void> add(String consultantId) async {
    final consultant =
        available.where((c) => c.id == consultantId).firstOrNull;
    if (consultant == null) return;

    await _change(
      consultantId,
      send: () => _consultantRepository.add(sessionId, consultantId),
      done: '${consultant.name} entrou na sessão.',
      fallback: _addFailed,
    );
  }

  /// "Remover da sessão". Quem estava em avaliação com o consultor é liberado
  /// pelo servidor na mesma operação; a tela pede confirmação antes, quando
  /// há alguém.
  Future<void> remove(String consultantId) async {
    final consultant = inSession
        .where((c) => c.id == consultantId && c.removable)
        .firstOrNull;
    if (consultant == null) return;

    await _change(
      consultantId,
      send: () => _consultantRepository.remove(sessionId, consultantId),
      done: '${consultant.name} saiu da sessão.',
      fallback: _removeFailed,
    );
  }

  Future<void> _change(
    String consultantId, {
    required Future<Result<void>> Function() send,
    required String done,
    required String fallback,
  }) async {
    if (!canChange || _busyConsultantId != null) return;

    _busyConsultantId = consultantId;
    _error = null;
    notifyListeners();

    var resync = false;
    var refused = false;
    try {
      final result = await send();
      switch (result) {
        case Success():
          _message = done;
          // O estado oficial: os consultores e, ao remover, quem foi liberado.
          resync = true;
        case Failure(:final exception, :final message):
          _error = message ?? fallback;
          refused = _isRefusal(exception);
          resync = refused;
      }
    } catch (_) {
      _error = fallback;
    } finally {
      _busyConsultantId = null;
      notifyListeners();
    }

    if (resync) unawaited(_resyncSession());
    // O consultor ficou inativo ou foi apagado: a equipe da tela está velha.
    if (refused) unawaited(_loadTeam());
  }

  /// O servidor respondeu que não: o que o aparelho tem está velho (a sessão
  /// foi concluída, o consultor ficou inativo, alguém já mexeu na lista).
  /// Sem rede e erro do servidor não dizem nada sobre o cache.
  bool _isRefusal(Exception exception) {
    if (exception is! ApiException) return false;
    return switch (exception.statusCode) {
      400 || 403 || 404 || 409 => true,
      _ => false,
    };
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  // Uma resposta pode chegar depois de a tela fechar; sem esta guarda, o
  // `finally` de adicionar/remover chamaria notifyListeners num ChangeNotifier
  // morto.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionSubscription?.cancel();
    _participantsSubscription?.cancel();
    _consultantsSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
```

**Em `lib/ui/session_detail/participant_filter.dart`, substituir:**

```dart
import '../../data/models/session_participant.dart';
import '../../data/services/local/app_database.dart';
import '../core/date_labels.dart';
import '../core/score_labels.dart';

/// Os quatro chips da tela 1.4. Aqui eles filtram de verdade (o canvas tem
```

**por:**

```dart
import '../../data/models/session_participant.dart';
import '../../data/services/local/app_database.dart';
import '../core/date_labels.dart';
import '../core/name_sort.dart';
import '../core/score_labels.dart';

/// Os quatro chips da tela 1.4. Aqui eles filtram de verdade (o canvas tem
```

**Em `lib/ui/session_detail/participant_filter.dart`, substituir:**

```dart
      ParticipantSituation.theoryOnly => 4,
    };

const Map<String, String> _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c',
};

/// Chave de ordenação por nome que põe "Ângela" junto de "Ana", e não depois
/// de "Zeca" — o SQLite só ignora caixa em letras sem acento.
String _nameKey(String name) {
  final lower = name.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_semAcento[char] ?? char);
  }
  return buffer.toString();
}

/// A lista na ordem do canvas: por grupo e, dentro do grupo, por nome.
/// Comparador completo (e não um `sort` estável sobre a ordem do banco),
/// porque o `List.sort` do Dart não garante estabilidade.
```

**por:**

```dart
      ParticipantSituation.theoryOnly => 4,
    };

/// A lista na ordem do canvas: por grupo e, dentro do grupo, por nome.
/// Comparador completo (e não um `sort` estável sobre a ordem do banco),
/// porque o `List.sort` do Dart não garante estabilidade.
```

**Em `lib/ui/session_detail/participant_filter.dart`, substituir:**

```dart
    final byGroup = _groupOf(situationOf(a, myConsultantId))
        .compareTo(_groupOf(situationOf(b, myConsultantId)));
    if (byGroup != 0) return byGroup;
    return _nameKey(a.name).compareTo(_nameKey(b.name));
  });
  return sorted;
}
```

**por:**

```dart
    final byGroup = _groupOf(situationOf(a, myConsultantId))
        .compareTo(_groupOf(situationOf(b, myConsultantId)));
    if (byGroup != 0) return byGroup;
    return nameSortKey(a.name).compareTo(nameSortKey(b.name));
  });
  return sorted;
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_consultants/session_consultants_viewmodel_test.dart test/ui/core/name_sort_test.dart test/ui/session_detail/participant_filter_test.dart`
Esperado: `+75: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+796: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/ui/core/name_sort.dart \
  apps/mobile/simtc/lib/ui/session_consultants/session_consultants_viewmodel.dart \
  apps/mobile/simtc/lib/ui/session_detail/participant_filter.dart \
  apps/mobile/simtc/test/ui/core/name_sort_test.dart \
  apps/mobile/simtc/test/ui/session_consultants/session_consultants_viewmodel_test.dart
git commit -m "feat(mobile): dados da tela de consultores da sessao"
```

---

## Task 8: A tela 1.13 "Consultores"

A tela (quadro `3c`), a rota e os dois ícones dos botões. Ela ainda não tem entrada pela interface — o ícone de pessoas do detalhe é da Task 9 —, então os testes a abrem pela rota, empilhada sobre uma tela de origem, com o Drift em memória, o `ApiClient` simulado e os três repositórios de verdade. O "servidor" dos testes guarda quem está na sessão e os participantes: tirar um consultor libera quem estava com ele, como o backend da Task 1.

De cima para baixo: a barra ("Consultores", sem ícone à direita), a faixa de offline, o aviso de falha (fora da rolagem) e a lista — a faixa de contexto, o aviso de "não baixados" ou de lista travada, "Na sessão", "Disponíveis na equipe" e a nota do fim.

**Files:**
- Create: `lib/ui/session_consultants/session_consultants_screen.dart`
- Create: `test/ui/session_consultants/session_consultants_screen_test.dart`
- Modify: `lib/ui/core/theme/app_icons.dart`
- Modify: `lib/router.dart`

**Interfaces:**
- Consumes: `SessionConsultantsViewModel`, `SessionConsultantItem` (Task 7); `ConsultantRow`, `LabelPill`, `AppCompactOutlineButton`, `AppDangerOutlineButton(compact:)`, `SessionContextHeader(title:)` (Task 6); `SessionConsultantRepository` pelo `Provider` (Task 5); `AppTopBar`, `ConnectivityBanner`, `InlineNotice`, `SkeletonListItem`; `AppLocalization` (nos testes).
- Produces:
  - `SessionConsultantsScreen({required String sessionId})`.
  - `AppRoutes.sessionConsultants(String sessionId)` → `/sessions/$sessionId/consultants`, com a rota `consultants` sob `/sessions/:sessionId`. A tela não devolve nada ao fechar: o que muda, muda no cache.
  - `AppIcons.addConsultant`, `AppIcons.removeConsultant`.
  - Chaves para os testes: `consultor-<id>` e `remover-<id>` em "Na sessão"; `equipe-<id>` e `adicionar-<id>` na equipe; `equipe-skeleton`; `session-consultants-skeleton`.

- [ ] **Step 1: Escrever os testes que falham**

**Criar `test/ui/session_consultants/session_consultants_screen_test.dart`:**

```dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/app_localization.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/inline_notice.dart';
import 'package:simtc/ui/core/widgets/session_context_header.dart';
import 'package:simtc/ui/core/widgets/status_chip.dart';
import 'package:simtc/ui/session_consultants/consultant_row.dart';
import 'package:simtc/ui/session_consultants/session_consultants_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

/// Os consultores ativos da equipe: nome e e-mail.
const Map<String, (String, String?)> _team = {
  'c-carla': ('Carla Mendes', 'carla.mendes@sim.com.br'),
  'c-diego': ('Diego Barbosa', 'diego.barbosa@sim.com.br'),
  'c-patricia': ('Patrícia Vasconcelos', null),
  'c-rafael': ('Rafael Lima', 'rafael.lima@sim.com.br'),
  'c-tatiane': ('Tatiane Souza', 'tatiane.souza@sim.com.br'),
};

const String _noteRafael =
    'Tem 1 avaliação em andamento. Remover devolve Marcos Vinícius para Pendente.';

void main() {
  late _MockApiClient api;
  late _MockAuthRepository auth;
  late AppDatabase db;
  late SessionRepository sessionRepository;
  late ParticipantRepository participantRepository;
  late SessionConsultantRepository consultantRepository;
  late ConnectivityService connectivity;
  late GoRouter router;

  // O "servidor" dos testes: quem está na sessão, os participantes e o status.
  late List<String> inSession;
  late List<Map<String, dynamic>> serverParticipants;
  late String serverStatus;

  const detailPath = '/training-sessions/sess-1';
  const teamPath = '/consultants';
  const addPath = '/training-sessions/sess-1/consultants';

  const offline = ApiException(
    message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
    isNetworkError: true,
  );

  const admin = AuthUser(
    id: 'u-admin',
    name: 'Carla Mendes',
    email: 'carla.mendes@sim.com.br',
    role: AppUserRole.admin,
    consultantId: 'c-carla',
  );
  const consultora = AuthUser(
    id: 'u1',
    name: 'Rafael Lima',
    email: 'rafael.lima@sim.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-rafael',
  );

  Map<String, dynamic> consultantJson(String id) {
    final (name, email) = _team[id]!;
    return {'id': id, 'name': name, 'email': email, 'active': true};
  }

  Map<String, dynamic> linkJson(String id) {
    return {
      'trainingSessionId': 'sess-1',
      'consultantId': id,
      'consultant': consultantJson(id),
    };
  }

  /// Um participante como vem em `participants[]` do detalhe.
  Map<String, dynamic> participantJson(
    String id,
    String name, {
    String status = 'PENDENTE',
    String? assignedTo,
    String? assessedBy,
    double? score,
  }) {
    return {
      'id': id,
      'participationType': 'TEORICA_E_PRATICA',
      'status': status,
      'assignedConsultantId': assignedTo,
      'assignedConsultant': assignedTo == null
          ? null
          : {'id': assignedTo, 'name': _team[assignedTo]!.$1},
      'participant': {'name': name, 'cpf': '04211833344'},
      'assessment': score == null
          ? null
          : {
              'score': score,
              'consultantId': assessedBy,
              'startTime': '2026-09-12T11:00:00.000Z',
              'endTime': '2026-09-12T11:30:00.000Z',
            },
    };
  }

  /// O corpo de `GET /training-sessions/sess-1`, pelo estado do "servidor".
  Map<String, dynamic> detailJson() {
    return {
      'id': 'sess-1',
      'company': {'name': 'Bracell', 'logoUrl': null},
      'course': {'name': 'Direção Defensiva — Veículo Pesado'},
      'city': 'Itabira',
      'state': 'MG',
      'date': '2026-09-12T00:00:00.000Z',
      'status': serverStatus,
      'notes': null,
      'responsibleConsultantId': 'c-carla',
      'responsibleConsultant': consultantJson('c-carla'),
      'consultants': [for (final id in inSession) linkJson(id)],
      'participants': serverParticipants,
    };
  }

  Response<Map<String, dynamic>> ok(String path, Map<String, dynamic> body) {
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: body,
    );
  }

  /// O que as rotas de consultor devolvem: a lista depois da mudança.
  Map<String, dynamic> changedJson() {
    return {
      'responsibleConsultantId': 'c-carla',
      'consultants': [for (final id in inSession) linkJson(id)],
    };
  }

  /// O servidor aceitando tudo: o detalhe, a equipe, entrar e sair (que
  /// libera quem estava em avaliação com o consultor, como o backend).
  void serverAnswers() {
    when(() => api.get<Map<String, dynamic>>(detailPath))
        .thenAnswer((_) async => ok(detailPath, detailJson()));
    when(() => api.get<List<dynamic>>(
          teamPath,
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: teamPath),
        statusCode: 200,
        data: [for (final id in _team.keys) consultantJson(id)],
      ),
    );
    when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .thenAnswer((invocation) async {
      final body = invocation.namedArguments[#data] as Map<String, dynamic>;
      final id = body['consultantId'] as String;
      if (!inSession.contains(id)) inSession.add(id);
      return ok(addPath, changedJson());
    });
    when(() => api.delete<Map<String, dynamic>>(any())).thenAnswer((invocation) async {
      final path = invocation.positionalArguments.single as String;
      final id = path.split('/').last;
      inSession.remove(id);
      for (final participant in serverParticipants) {
        if (participant['status'] == 'EM_AVALIACAO' &&
            participant['assignedConsultantId'] == id) {
          participant['status'] = 'PENDENTE';
          participant['assignedConsultantId'] = null;
          participant['assignedConsultant'] = null;
        }
      }
      return ok(path, changedJson());
    });
  }

  /// O servidor fora do ar para tudo.
  void serverUnreachable() {
    when(() => api.get<Map<String, dynamic>>(detailPath)).thenThrow(offline);
    when(() => api.get<List<dynamic>>(
          teamPath,
          queryParameters: any(named: 'queryParameters'),
        )).thenThrow(offline);
    when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .thenThrow(offline);
    when(() => api.delete<Map<String, dynamic>>(any())).thenThrow(offline);
  }

  setUp(() {
    api = _MockApiClient();
    auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(admin);
    when(() => auth.isAuthenticated).thenReturn(true);
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    sessionRepository = SessionRepository(apiClient: api, database: db);
    participantRepository = ParticipantRepository(apiClient: api, database: db);
    consultantRepository =
        SessionConsultantRepository(apiClient: api, database: db);
    connectivity = ConnectivityService();

    // O quadro "3c": a Carla responde pela sessão e avalia; o Rafael tem uma
    // avaliação em andamento; a Tatiane já concluiu as dela.
    inSession = ['c-carla', 'c-rafael', 'c-tatiane'];
    serverStatus = 'EM_ANDAMENTO';
    serverParticipants = [
      participantJson('tp-ana', 'Ana Paula Ribeiro',
          status: 'EM_AVALIACAO', assignedTo: 'c-carla'),
      participantJson('tp-bruno', 'Bruno Dias',
          status: 'APROVADO', assessedBy: 'c-carla', score: 90),
      participantJson('tp-marcos', 'Marcos Vinícius',
          status: 'EM_AVALIACAO', assignedTo: 'c-rafael'),
      participantJson('tp-juliana', 'Juliana Freitas Costa',
          status: 'APROVADO', assessedBy: 'c-tatiane', score: 86.7),
      participantJson('tp-rodrigo', 'Rodrigo Tavares',
          status: 'APROVADO', assessedBy: 'c-tatiane', score: 78),
    ];
    serverAnswers();
  });

  tearDown(() async {
    await db.close();
    connectivity.dispose();
  });

  /// O detalhe já baixado neste aparelho, como a tela de baixo deixa.
  Future<void> seedFromServer() async {
    final result = await participantRepository.syncSession('sess-1');
    expect(result.isSuccess, isTrue);
  }

  /// A sessão no cache como a Home a grava: sem participantes nem consultores.
  Future<void> seedSessionOnly() {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva — Veículo Pesado',
            city: 'Itabira',
            state: 'MG',
            status: 'EM_ANDAMENTO',
            cachedAt: DateTime(2026, 9, 12, 7),
          ),
        );
  }

  Future<void> goOffline() async {
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => const Stream.empty());
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  /// A tela empilhada sobre uma origem, pela rota real. Com [settle] falso,
  /// para quem deixa uma resposta presa: o esqueleto e o indicador não param
  /// de animar, e o `pumpAndSettle` não assentaria.
  Future<void> pumpScreen(
    WidgetTester tester, {
    Size screen = const Size(412, 1800),
    double textScale = 1,
    bool settle = true,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    router = GoRouter(
      initialLocation: '/origem',
      routes: [
        GoRoute(
          path: '/origem',
          builder: (context, state) => const Scaffold(body: Text('origem')),
        ),
        GoRoute(
          path: '/sessions/:sessionId/consultants',
          builder: (context, state) => SessionConsultantsScreen(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: sessionRepository),
          Provider<ParticipantRepository>.value(value: participantRepository),
          Provider<SessionConsultantRepository>.value(value: consultantRepository),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: AppLocalization.locale,
          supportedLocales: AppLocalization.supportedLocales,
          localizationsDelegates: AppLocalization.delegates,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    unawaited(router.push<void>(AppRoutes.sessionConsultants('sess-1')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await pumpTransitions(tester);
    }
  }

  AppDangerOutlineButton removeButton(WidgetTester tester, String id) =>
      tester.widget<AppDangerOutlineButton>(find.byKey(ValueKey('remover-$id')));

  AppCompactOutlineButton addButton(WidgetTester tester, String id) =>
      tester.widget<AppCompactOutlineButton>(find.byKey(ValueKey('adicionar-$id')));

  Finder rowOf(String key) => find.byKey(ValueKey(key));

  /// Rola a lista até o alvo ficar inteiro na tela: num celular baixo, o que
  /// está abaixo da dobra nem foi montado ainda, e o que foi montado pode
  /// estar só com a ponta à vista.
  Future<void> bringIntoView(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Finder inRow(String key, Finder matching) =>
      find.descendant(of: rowOf(key), matching: matching);

  int teamRequests() => verify(() => api.get<List<dynamic>>(
        teamPath,
        queryParameters: any(named: 'queryParameters'),
      )).callCount;

  testWidgets('antes da primeira leitura do cache, mostra o esqueleto',
      (tester) async {
    await seedFromServer();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: sessionRepository),
          Provider<ParticipantRepository>.value(value: participantRepository),
          Provider<SessionConsultantRepository>.value(value: consultantRepository),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SessionConsultantsScreen(sessionId: 'sess-1'),
        ),
      ),
    );

    expect(find.byKey(const Key('session-consultants-skeleton')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-consultants-skeleton')), findsNothing);
  });

  testWidgets(
      'mostra o contexto, quem está na sessão, a equipe e a nota do fim, como '
      'o quadro "3c"', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    expect(find.text('Consultores'), findsOneWidget);
    // Sem a lupa do quadro: a busca é da Fase 8.
    expect(find.byIcon(AppIcons.search), findsNothing);
    expect(find.text('Bracell · 12 set'), findsOneWidget);
    expect(find.text('5 participantes · 3 consultores'), findsOneWidget);
    // A faixa de contexto no fundo da tela, como no quadro.
    expect(
      tester.widget<SessionContextHeader>(find.byType(SessionContextHeader)).muted,
      isTrue,
    );

    expect(find.text('Na sessão'), findsOneWidget);
    expect(inRow('consultor-c-carla', find.text('Carla Mendes (você)')), findsOneWidget);
    expect(inRow('consultor-c-carla', find.text('Responsável')), findsOneWidget);
    expect(
      inRow('consultor-c-carla', find.text('2 participantes · 1 em andamento')),
      findsOneWidget,
    );
    // O responsável não sai por aqui, nem tem o aviso.
    expect(inRow('consultor-c-carla', find.byType(AppDangerOutlineButton)), findsNothing);
    expect(inRow('consultor-c-carla', find.byType(InlineNotice)), findsNothing);

    expect(inRow('consultor-c-rafael', find.text('Rafael Lima')), findsOneWidget);
    expect(inRow('consultor-c-rafael', find.text('Consultor')), findsOneWidget);
    expect(
      inRow('consultor-c-rafael', find.text('1 participante · 1 em andamento')),
      findsOneWidget,
    );
    expect(inRow('consultor-c-rafael', find.text(_noteRafael)), findsOneWidget);
    expect(removeButton(tester, 'c-rafael').onPressed, isNotNull);

    expect(
      inRow('consultor-c-tatiane', find.text('2 participantes concluídos')),
      findsOneWidget,
    );
    expect(inRow('consultor-c-tatiane', find.byType(InlineNotice)), findsNothing);
    expect(removeButton(tester, 'c-tatiane').onPressed, isNotNull);
    expect(find.text('Remover da sessão'), findsNWidgets(2));

    expect(find.text('Disponíveis na equipe'), findsOneWidget);
    expect(find.text('SIM Treinamentos'), findsOneWidget);
    expect(inRow('equipe-c-diego', find.text('Diego Barbosa')), findsOneWidget);
    expect(
      inRow('equipe-c-diego', find.text('diego.barbosa@sim.com.br')),
      findsOneWidget,
    );
    // Sem e-mail no cadastro, a linha fica só com o nome.
    expect(inRow('equipe-c-patricia', find.text('Patrícia Vasconcelos')), findsOneWidget);
    expect(addButton(tester, 'c-diego').onPressed, isNotNull);
    expect(addButton(tester, 'c-patricia').onPressed, isNotNull);
    // Quem já está na sessão não aparece na equipe.
    expect(find.text('Adicionar'), findsNWidgets(2));

    expect(
      find.text('Entrar e sair da sessão vale na hora e precisa de conexão. '
          'Offline, a lista fica só de leitura.'),
      findsOneWidget,
    );
    expect(find.textContaining('Sem conexão'), findsNothing);
  });

  testWidgets('a ordem é a do quadro: contexto, "Na sessão" com o responsável '
      'primeiro, a equipe e a nota', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    double top(Finder finder) => tester.getTopLeft(finder).dy;

    final order = [
      top(find.text('Bracell · 12 set')),
      top(find.text('Na sessão')),
      top(rowOf('consultor-c-carla')),
      top(rowOf('consultor-c-rafael')),
      top(rowOf('consultor-c-tatiane')),
      top(find.text('Disponíveis na equipe')),
      top(rowOf('equipe-c-diego')),
      top(rowOf('equipe-c-patricia')),
      top(find.textContaining('Entrar e sair da sessão')),
    ];
    expect(order, [...order]..sort());

    // As pastilhas do papel: a do responsável na cor de marca.
    final pills = tester.widgetList<LabelPill>(find.byType(LabelPill)).toList();
    expect(pills.map((p) => p.label), ['Responsável', 'Consultor', 'Consultor']);
    expect(pills.map((p) => p.tone),
        [StatusTone.info, StatusTone.neutral, StatusTone.neutral]);
  });

  testWidgets('os títulos de seção têm os recuos do quadro "3c"', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    // "Na sessão": 15 em cima e embaixo, 20 dos lados.
    final sessionTitle = tester.getRect(find.text('Na sessão'));
    final header = tester.getRect(find.byType(SessionContextHeader));
    final firstRow = tester.getRect(rowOf('consultor-c-carla'));
    expect(sessionTitle.left, 20);
    expect(sessionTitle.top - header.bottom, 15);
    expect(firstRow.top - sessionTitle.bottom, 15);

    // "Disponíveis na equipe": 22 em cima, 10 embaixo, e o nome da equipe na
    // margem direita.
    final teamTitle = tester.getRect(find.text('Disponíveis na equipe'));
    final lastRow = tester.getRect(rowOf('consultor-c-tatiane'));
    final teamRow = tester.getRect(rowOf('equipe-c-diego'));
    expect(teamTitle.left, 20);
    expect(teamTitle.top - lastRow.bottom, 22);
    expect(teamRow.top - teamTitle.bottom, closeTo(10, 0.5));
    expect(tester.getRect(find.text('SIM Treinamentos')).right, 412 - 20);

    // A nota do fim: 16 acima, 20 dos lados, 24 abaixo.
    final note = tester.getRect(
      find.ancestor(
        of: find.textContaining('Entrar e sair da sessão'),
        matching: find.byType(InlineNotice),
      ),
    );
    final lastTeamRow = tester.getRect(rowOf('equipe-c-patricia'));
    expect(note.top - lastTeamRow.bottom, 16);
    expect(note.left, 20);
    expect(note.right, 412 - 20);
  });

  testWidgets('"Adicionar" manda o consultor na hora, e ele passa para "Na '
      'sessão", com o aviso', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('adicionar-c-diego')));
    await tester.pumpAndSettle();

    final sent = verify(
      () => api.post<Map<String, dynamic>>(addPath, data: captureAny(named: 'data')),
    ).captured.single;
    expect(sent, {'consultantId': 'c-diego'});

    expect(find.text('Diego Barbosa entrou na sessão.'), findsOneWidget);
    expect(rowOf('consultor-c-diego'), findsOneWidget);
    expect(inRow('consultor-c-diego', find.text('Sem participantes')), findsOneWidget);
    expect(removeButton(tester, 'c-diego').onPressed, isNotNull);
    expect(rowOf('equipe-c-diego'), findsNothing);
    expect(find.text('5 participantes · 4 consultores'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
      'com a resposta demorando: o botão tocado gira, os outros travam, e '
      'tudo volta quando ela chega', (tester) async {
    await seedFromServer();
    final reply = Completer<Response<Map<String, dynamic>>>();
    when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .thenAnswer((_) => reply.future);
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('adicionar-c-diego')));
    await tester.pump();
    // Um quadro no meio do envio.
    await tester.pump(const Duration(milliseconds: 300));

    expect(addButton(tester, 'c-diego').isLoading, isTrue);
    expect(
      inRow('equipe-c-diego', find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
    expect(addButton(tester, 'c-patricia').onPressed, isNull);
    expect(addButton(tester, 'c-patricia').isLoading, isFalse);
    expect(removeButton(tester, 'c-rafael').onPressed, isNull);
    expect(removeButton(tester, 'c-tatiane').onPressed, isNull);
    expect(find.text('Diego Barbosa entrou na sessão.'), findsNothing);

    // Um segundo toque não manda nada.
    await tester.tap(find.byKey(const ValueKey('adicionar-c-patricia')));
    await tester.pump();

    inSession.add('c-diego');
    reply.complete(ok(addPath, changedJson()));
    await tester.pumpAndSettle();

    verify(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .called(1);
    expect(find.text('Diego Barbosa entrou na sessão.'), findsOneWidget);
    expect(addButton(tester, 'c-patricia').onPressed, isNotNull);
    expect(removeButton(tester, 'c-rafael').onPressed, isNotNull);
    expect(removeButton(tester, 'c-diego').onPressed, isNotNull);
  });

  testWidgets('remover quem não tem avaliação em andamento vale no toque, sem '
      'perguntar', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('remover-c-tatiane')));
    await tester.pumpAndSettle();

    verify(() => api.delete<Map<String, dynamic>>('$addPath/c-tatiane')).called(1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Tatiane Souza saiu da sessão.'), findsOneWidget);
    expect(rowOf('consultor-c-tatiane'), findsNothing);
    // Continua na equipe: dá para pôr de volta.
    expect(addButton(tester, 'c-tatiane').onPressed, isNotNull);
    expect(find.text('5 participantes · 2 consultores'), findsOneWidget);
  });

  testWidgets(
      'remover quem tem avaliação em andamento pergunta antes, com a '
      'consequência; "Voltar" não remove', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('remover-c-rafael')));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('Remover Rafael Lima da sessão?')),
      findsOneWidget,
    );
    expect(find.descendant(of: dialog, matching: find.text(_noteRafael)), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(() => api.delete<Map<String, dynamic>>(any()));
    expect(rowOf('consultor-c-rafael'), findsOneWidget);
  });

  testWidgets(
      'confirmando, o consultor sai e quem estava com ele volta para Pendente '
      'no aparelho', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('remover-c-rafael')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
    await tester.pumpAndSettle();

    verify(() => api.delete<Map<String, dynamic>>('$addPath/c-rafael')).called(1);
    expect(find.text('Rafael Lima saiu da sessão.'), findsOneWidget);
    expect(rowOf('consultor-c-rafael'), findsNothing);

    // A tela baixou a sessão de novo: o participante liberado está no cache.
    final marcos = await (db.select(db.participants)
          ..where((t) => t.id.equals('tp-marcos')))
        .getSingle();
    expect(marcos.status, 'PENDENTE');
    expect(marcos.assignedConsultantId, isNull);
  });

  testWidgets(
      'recusado pelo servidor: o motivo fica à vista, fora da rolagem, mesmo '
      'com a lista rolada até o fim', (tester) async {
    const reason = 'Consultor inativo não pode entrar em um treinamento';
    await seedFromServer();
    when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .thenThrow(const ApiException(message: reason, statusCode: 400));
    await pumpScreen(tester, screen: const Size(412, 640));

    final target = find.byKey(const ValueKey('adicionar-c-patricia'));
    await bringIntoView(tester, target);
    // O contexto, que abre a lista, já saiu da tela.
    expect(find.text('Bracell · 12 set').hitTestable(), findsNothing);
    clearInteractions(api);

    await tester.tap(target);
    await tester.pumpAndSettle();

    final notice = find.widgetWithText(InlineNotice, reason);
    expect(notice, findsOneWidget);
    expect(tester.widget<InlineNotice>(notice).tone, NoticeTone.danger);
    expect(find.ancestor(of: notice, matching: find.byType(ListView)), findsNothing);
    final rect = tester.getRect(notice);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(640));
    expect(find.text(reason).hitTestable(), findsOneWidget);

    // Sem aviso de sucesso, os botões voltam, e o que o aparelho tinha de
    // velho é baixado de novo: a sessão e a equipe.
    expect(find.textContaining('entrou na sessão'), findsNothing);
    expect(addButton(tester, 'c-patricia').onPressed, isNotNull);
    verify(() => api.get<Map<String, dynamic>>(detailPath)).called(1);
    expect(teamRequests(), 1);
  });

  testWidgets('o aviso da falha some na tentativa seguinte', (tester) async {
    await seedFromServer();
    when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .thenThrow(const ApiException(message: 'Internal server error', statusCode: 500));
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('adicionar-c-diego')));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível adicionar o consultor. Tente de novo.'),
      findsOneWidget,
    );

    serverAnswers();
    await tester.tap(find.byKey(const ValueKey('adicionar-c-diego')));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível adicionar o consultor. Tente de novo.'),
      findsNothing,
    );
    expect(find.text('Diego Barbosa entrou na sessão.'), findsOneWidget);
  });

  testWidgets(
      'sem conexão: a faixa diz por quê, quem está na sessão continua à vista '
      'com o remover apagado, e a equipe fica para depois', (tester) async {
    await seedFromServer();
    serverUnreachable();
    await goOffline();
    await pumpScreen(tester);

    expect(
      find.text('Sem conexão — mudar os consultores precisa de internet.'),
      findsOneWidget,
    );
    expect(inRow('consultor-c-rafael', find.text('Rafael Lima')), findsOneWidget);
    expect(inRow('consultor-c-rafael', find.text(_noteRafael)), findsOneWidget);
    expect(removeButton(tester, 'c-rafael').onPressed, isNull);
    expect(removeButton(tester, 'c-tatiane').onPressed, isNull);

    expect(find.text('Disponíveis na equipe'), findsOneWidget);
    expect(find.text('A equipe aparece quando houver conexão.'), findsOneWidget);
    expect(find.text('Adicionar'), findsNothing);
    // A nota do fim continua lá.
    expect(find.textContaining('Offline, a lista fica só de leitura.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remover-c-tatiane')));
    await tester.pumpAndSettle();
    verifyNever(() => api.delete<Map<String, dynamic>>(any()));
  });

  testWidgets(
      'a conexão cai com a tela aberta: a equipe continua à vista, com o '
      '"Adicionar" apagado; quando volta, tudo reabre e a equipe é buscada de '
      'novo', (tester) async {
    await seedFromServer();
    final changes = StreamController<List<ConnectivityResult>>();
    addTearDown(changes.close);
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => changes.stream);
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
    await pumpScreen(tester);
    expect(addButton(tester, 'c-diego').onPressed, isNotNull);
    clearInteractions(api);

    changes.add([ConnectivityResult.none]);
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão — mudar os consultores precisa de internet.'),
      findsOneWidget,
    );
    expect(inRow('equipe-c-diego', find.text('Diego Barbosa')), findsOneWidget);
    expect(addButton(tester, 'c-diego').onPressed, isNull);
    expect(removeButton(tester, 'c-rafael').onPressed, isNull);

    changes.add([ConnectivityResult.mobile]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Sem conexão'), findsNothing);
    expect(addButton(tester, 'c-diego').onPressed, isNotNull);
    expect(removeButton(tester, 'c-rafael').onPressed, isNotNull);
    expect(teamRequests(), 1);
  });

  testWidgets('enquanto a equipe não chega, mostra o esqueleto no lugar dela',
      (tester) async {
    await seedFromServer();
    final reply = Completer<Response<List<dynamic>>>();
    when(() => api.get<List<dynamic>>(
          teamPath,
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) => reply.future);
    await pumpScreen(tester, settle: false);

    expect(find.byKey(const Key('equipe-skeleton')), findsOneWidget);
    expect(find.text('Adicionar'), findsNothing);
    // Quem está na sessão vem do aparelho e não espera a equipe.
    expect(rowOf('consultor-c-rafael'), findsOneWidget);

    reply.complete(
      Response<List<dynamic>>(
        requestOptions: RequestOptions(path: teamPath),
        statusCode: 200,
        data: [consultantJson('c-diego')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('equipe-skeleton')), findsNothing);
    expect(addButton(tester, 'c-diego').onPressed, isNotNull);
  });

  testWidgets('com todos os ativos já na sessão, a equipe diz isso',
      (tester) async {
    inSession = _team.keys.toList();
    await seedFromServer();
    await pumpScreen(tester);

    expect(
      find.text('Todos os consultores ativos da equipe já estão nesta sessão.'),
      findsOneWidget,
    );
    expect(find.text('Adicionar'), findsNothing);
  });

  testWidgets('falha ao buscar a equipe: pede para puxar, e puxar traz a equipe',
      (tester) async {
    await seedFromServer();
    when(() => api.get<List<dynamic>>(
          teamPath,
          queryParameters: any(named: 'queryParameters'),
        )).thenThrow(const ApiException(message: 'Internal server error', statusCode: 500));
    await pumpScreen(tester, screen: const Size(412, 900));

    expect(
      find.text('Não foi possível carregar a equipe. Puxe para atualizar.'),
      findsOneWidget,
    );

    serverAnswers();
    await tester.fling(find.text('Na sessão'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar a equipe. Puxe para atualizar.'),
      findsNothing,
    );
    expect(addButton(tester, 'c-diego').onPressed, isNotNull);
  });

  testWidgets('sessão concluída: só leitura, com o motivo, e os botões à vista '
      'e apagados', (tester) async {
    serverStatus = 'CONCLUIDO';
    await seedFromServer();
    await pumpScreen(tester);

    expect(
      find.text('Sessão concluída: os consultores não podem mais ser alterados.'),
      findsOneWidget,
    );
    expect(removeButton(tester, 'c-rafael').onPressed, isNull);
    expect(addButton(tester, 'c-diego').onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('adicionar-c-diego')));
    await tester.pumpAndSettle();
    verifyNever(
      () => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')),
    );
  });

  testWidgets('sessão cancelada: o motivo próprio', (tester) async {
    serverStatus = 'CANCELADO';
    await seedFromServer();
    await pumpScreen(tester);

    expect(
      find.text('Sessão cancelada: os consultores não podem mais ser alterados.'),
      findsOneWidget,
    );
    expect(removeButton(tester, 'c-tatiane').onPressed, isNull);
  });

  testWidgets('quem não é ADMIN vê a lista travada, com o motivo', (tester) async {
    when(() => auth.currentUser).thenReturn(consultora);
    await seedFromServer();
    await pumpScreen(tester);

    expect(
      find.text('Só administradores podem mudar os consultores da sessão.'),
      findsOneWidget,
    );
    // O "(você)" acompanha quem está logado.
    expect(inRow('consultor-c-rafael', find.text('Rafael Lima (você)')), findsOneWidget);
    expect(removeButton(tester, 'c-tatiane').onPressed, isNull);
    expect(addButton(tester, 'c-diego').onPressed, isNull);
  });

  testWidgets('sessão que não está no aparelho: só o aviso', (tester) async {
    serverUnreachable();
    await pumpScreen(tester);

    expect(
      find.text('Esta sessão não está mais disponível neste aparelho.'),
      findsOneWidget,
    );
    expect(find.text('Na sessão'), findsNothing);
    expect(find.byType(ConsultantRow), findsNothing);
  });

  testWidgets(
      'sessão em cache sem os consultores, e sem conexão: avisa que ainda não '
      'foram baixados', (tester) async {
    await seedSessionOnly();
    serverUnreachable();
    await goOffline();
    await pumpScreen(tester);

    expect(
      find.text('Os consultores desta sessão ainda não foram baixados. Puxe '
          'para atualizar quando houver conexão.'),
      findsOneWidget,
    );
    expect(find.byType(ConsultantRow), findsNothing);
    expect(find.text('Na sessão'), findsOneWidget);
  });

  testWidgets(
      'num celular de 360x640 com a fonte ampliada, nada estoura, e dá para '
      'rolar até a nota do fim e adicionar', (tester) async {
    await seedFromServer();
    await pumpScreen(tester, screen: const Size(360, 640), textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.text('Consultores'), findsOneWidget);
    // A linha de apoio de quem está na sessão quebra, em vez de perder o
    // "em andamento" nas reticências.
    expect(
      tester
          .renderObject<RenderParagraph>(
            find.text('2 participantes · 1 em andamento'),
          )
          .didExceedMaxLines,
      isFalse,
    );

    final target = find.byKey(const ValueKey('adicionar-c-patricia'));
    await bringIntoView(tester, target);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(target).height, 48);

    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.text('Patrícia Vasconcelos entrou na sessão.'), findsOneWidget);

    await bringIntoView(tester, find.textContaining('Entrar e sair da sessão'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'num celular de 360x640 com a fonte ampliada, o aviso de falha comprido '
      'cabe acima da lista, que continua rolando', (tester) async {
    const reason = 'O consultor responsável não pode ser removido do '
        'treinamento. Troque o responsável antes.';
    await seedFromServer();
    when(() => api.delete<Map<String, dynamic>>(any()))
        .thenThrow(const ApiException(message: reason, statusCode: 400));
    await pumpScreen(tester, screen: const Size(360, 640), textScale: 1.3);

    final target = find.byKey(const ValueKey('remover-c-tatiane'));
    await bringIntoView(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.widgetWithText(InlineNotice, reason));
    expect(rect.bottom, lessThanOrEqualTo(640));
    // Sobra lista embaixo do aviso.
    expect(tester.getRect(find.byType(Scrollable).first).height, greaterThan(150));
  });

  testWidgets(
      'voltar com o envio ainda no ar: a tela fecha sem derrubar nada, e a '
      'sessão é baixada de novo quando a resposta chega', (tester) async {
    await seedFromServer();
    final reply = Completer<Response<Map<String, dynamic>>>();
    when(() => api.delete<Map<String, dynamic>>('$addPath/c-rafael'))
        .thenAnswer((_) => reply.future);
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('remover-c-rafael')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
    await pumpTransitions(tester);
    expect(removeButton(tester, 'c-rafael').isLoading, isTrue);
    clearInteractions(api);

    await tester.tap(find.byTooltip('Voltar'));
    await pumpTransitions(tester);

    expect(find.byType(SessionConsultantsScreen), findsNothing);
    expect(find.text('origem'), findsOneWidget);

    // O servidor conclui a remoção e libera o participante.
    inSession.remove('c-rafael');
    serverParticipants[2]
      ..['status'] = 'PENDENTE'
      ..['assignedConsultantId'] = null
      ..['assignedConsultant'] = null;
    reply.complete(ok('$addPath/c-rafael', changedJson()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    verify(() => api.get<Map<String, dynamic>>(detailPath)).called(1);
    final marcos = await (db.select(db.participants)
          ..where((t) => t.id.equals('tp-marcos')))
        .getSingle();
    expect(marcos.status, 'PENDENTE');
  });
}

/// Deixa as animações de rota e de diálogo correrem até o fim. Com um envio
/// no ar o botão gira sem parar e o `pumpAndSettle` não assenta; então, um
/// quadro para a animação começar e outro, de 1 s, para ela acabar.
Future<void> pumpTransitions(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_consultants/session_consultants_screen_test.dart`
Esperado: não compila — `Error when reading 'lib/ui/session_consultants/session_consultants_screen.dart'` e `Member not found: 'AppRoutes.sessionConsultants'`.

- [ ] **Step 3: Implementar**

**Em `lib/router.dart`, substituir:**

```dart
import 'ui/checklist/checklist_screen.dart';
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/result/result_screen.dart';
import 'ui/session_detail/session_detail_screen.dart';
import 'ui/session_edit/session_edit_screen.dart';
import 'ui/sessions/sessions_screen.dart';
```

**por:**

```dart
import 'ui/checklist/checklist_screen.dart';
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/result/result_screen.dart';
import 'ui/session_consultants/session_consultants_screen.dart';
import 'ui/session_detail/session_detail_screen.dart';
import 'ui/session_edit/session_edit_screen.dart';
import 'ui/sessions/sessions_screen.dart';
```

**Em `lib/router.dart`, substituir:**

```dart
  /// "Adicionar participante" (tela 1.11, Fase 6A), só para ADMIN.
  static String addParticipant(String sessionId) =>
      '/sessions/$sessionId/participants/new';

  /// Checklist do participante (Fase 4). [fromResult]: aberto pelo
  /// "Reavaliar" do Resultado, que continua embaixo — o voltar leva a ele.
```

**por:**

```dart
  /// "Adicionar participante" (tela 1.11, Fase 6A), só para ADMIN.
  static String addParticipant(String sessionId) =>
      '/sessions/$sessionId/participants/new';

  /// "Consultores" da sessão (tela 1.13, Fase 6B), só para ADMIN.
  static String sessionConsultants(String sessionId) =>
      '/sessions/$sessionId/consultants';

  /// Checklist do participante (Fase 4). [fromResult]: aberto pelo
  /// "Reavaliar" do Resultado, que continua embaixo — o voltar leva a ele.
```

**Em `lib/router.dart`, substituir:**

```dart
            ),
          ),
          GoRoute(
            path: 'participants/:participantId/checklist',
            builder: (context, state) => ChecklistScreen(
              sessionId: state.pathParameters['sessionId']!,
```

**por:**

```dart
            ),
          ),
          GoRoute(
            path: 'consultants',
            builder: (context, state) => SessionConsultantsScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
          GoRoute(
            path: 'participants/:participantId/checklist',
            builder: (context, state) => ChecklistScreen(
              sessionId: state.pathParameters['sessionId']!,
```

**Em `lib/ui/core/theme/app_icons.dart`, substituir:**

```dart
  static const IconData practice = Icons.directions_car_outlined;
  static const IconData addParticipant = Icons.person_add_outlined;

  /// O aviso de uma linha da tela "Consultores" (Fase 6B, canvas "3c").
  static const IconData info = Icons.info_outlined;
}
```

**por:**

```dart
  static const IconData practice = Icons.directions_car_outlined;
  static const IconData addParticipant = Icons.person_add_outlined;

  /// Tela "Consultores" (Fase 6B, canvas "3c"): o aviso de uma linha, e os
  /// botões de entrar e de sair da sessão.
  static const IconData info = Icons.info_outlined;
  static const IconData addConsultant = Icons.person_add_outlined;
  static const IconData removeConsultant = Icons.person_remove_outlined;
}
```

**Criar `lib/ui/session_consultants/session_consultants_screen.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/session_consultant.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_consultant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/session_context_header.dart';
import '../core/widgets/skeleton.dart';
import '../core/widgets/status_chip.dart';
import 'consultant_row.dart';
import 'session_consultants_viewmodel.dart';

/// Tela 1.13 — "Consultores" (quadro "3c" do canvas), só para ADMIN.
///
/// Diferenças do canvas, aprovadas em 09/10/2026: sem a lupa (a busca é da
/// Fase 8); o e-mail no lugar da agenda de quem está na equipe (o backend não
/// tem agenda de consultor); a confirmação antes de remover quem tem
/// avaliação em andamento; e os botões com 48dp (o quadro tem 44).
class SessionConsultantsScreen extends StatefulWidget {
  const SessionConsultantsScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionConsultantsScreen> createState() =>
      _SessionConsultantsScreenState();
}

class _SessionConsultantsScreenState extends State<SessionConsultantsScreen> {
  late final SessionConsultantsViewModel _viewModel =
      SessionConsultantsViewModel(
    sessionId: widget.sessionId,
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    consultantRepository: context.read<SessionConsultantRepository>(),
    connectivity: context.read<ConnectivityService>(),
    currentUser: context.read<AuthRepository>().currentUser,
  )..init();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_showMessageWhenItArrives);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_showMessageWhenItArrives);
    _viewModel.dispose();
    super.dispose();
  }

  /// Mesmo padrão do detalhe: o aviso de quem entrou ou saiu é passageiro. A
  /// mensagem é limpa assim que é agendada — limpar antes de agendar também
  /// evita reentrância, já que `clearMessage()` notifica de novo.
  void _showMessageWhenItArrives() {
    final message = _viewModel.message;
    if (message == null) return;
    _viewModel.clearMessage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;
    final error = _viewModel.errorMessage;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(title: 'Consultores'),
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
  }

  Widget _buildBody(bool isOffline) {
    if (_viewModel.isLoading) return _buildSkeleton();

    final session = _viewModel.session;
    if (session == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: InlineNotice(
          icon: AppIcons.sessions,
          message: _viewModel.lockedReason ?? '',
        ),
      );
    }

    // Entrar e sair precisam de conexão, de uma sessão que aceite mudanças e
    // de nenhum outro envio no ar. Fora disso os botões continuam à vista,
    // apagados — a faixa, o aviso ou o indicador dizem por quê.
    final enabled = _viewModel.canChange &&
        !isOffline &&
        _viewModel.busyConsultantId == null;
    final notice = _buildNotice();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _viewModel.refresh,
      child: ListView(
        // Explícito pelo mesmo motivo do detalhe: puxar para atualizar precisa
        // funcionar mesmo quando a lista é mais curta que a tela.
        physics: const AlwaysScrollableScrollPhysics(),
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
              child: notice,
            ),
          _buildSessionTitle(),
          for (final item in _viewModel.inSession)
            _buildSessionRow(item, enabled),
          _buildTeamTitle(),
          ..._buildTeam(enabled),
          _buildFooterNote(),
        ],
      ),
    );
  }

  /// Um aviso por vez: sem os consultores no aparelho, nada mais importa;
  /// depois, por que a lista está travada.
  Widget? _buildNotice() {
    if (_viewModel.notDownloaded) {
      return const InlineNotice(
        icon: AppIcons.noSignal,
        tone: NoticeTone.warning,
        message: 'Os consultores desta sessão ainda não foram baixados. '
            'Puxe para atualizar quando houver conexão.',
      );
    }
    final lockedReason = _viewModel.lockedReason;
    if (lockedReason == null) return null;
    return InlineNotice(icon: AppIcons.lockedByOther, message: lockedReason);
  }

  Widget _buildSessionTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg - 1,
      ),
      child: Text('Na sessão', style: AppTypography.sectionTitle),
    );
  }

  Widget _buildSessionRow(SessionConsultantItem item, bool enabled) {
    return ConsultantRow(
      key: ValueKey('consultor-${item.id}'),
      name: item.displayName,
      meta: item.meta,
      metaWraps: true,
      trailing: LabelPill(
        label: item.isResponsible ? 'Responsável' : 'Consultor',
        tone: item.isResponsible ? StatusTone.info : StatusTone.neutral,
      ),
      note: item.note,
      // O responsável não sai por aqui: trocar o responsável é do painel web.
      action: item.removable
          ? AppDangerOutlineButton(
              key: ValueKey('remover-${item.id}'),
              label: 'Remover da sessão',
              icon: AppIcons.removeConsultant,
              compact: true,
              isLoading: _viewModel.busyConsultantId == item.id,
              onPressed: enabled ? () => _remove(item) : null,
            )
          : null,
    );
  }

  /// "Disponíveis na equipe", com o nome da equipe à direita (canvas "3c").
  Widget _buildTeamTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl + AppSpacing.xxs,
        AppSpacing.xl,
        AppSpacing.md - AppSpacing.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              'Disponíveis na equipe',
              style: AppTypography.sectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'SIM Treinamentos',
            style: AppTypography.meta.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// A equipe vem do servidor: enquanto não chega, o esqueleto; se não der
  /// para trazer, o motivo no lugar dela.
  List<Widget> _buildTeam(bool enabled) {
    if (_viewModel.isTeamLoading) {
      return const [
        SkeletonListItem(key: Key('equipe-skeleton')),
        SkeletonListItem(),
      ];
    }

    final notice = _viewModel.teamNotice;
    if (notice != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: InlineNotice(icon: AppIcons.info, message: notice),
        ),
      ];
    }

    return [
      for (final consultant in _viewModel.available)
        _buildTeamRow(consultant, enabled),
    ];
  }

  Widget _buildTeamRow(SessionConsultant consultant, bool enabled) {
    return ConsultantRow(
      key: ValueKey('equipe-${consultant.id}'),
      name: consultant.name,
      // O e-mail, e não a agenda do quadro: o backend não tem agenda de
      // consultor (decisão de 09/10/2026).
      meta: consultant.email,
      trailing: AppCompactOutlineButton(
        key: ValueKey('adicionar-${consultant.id}'),
        label: 'Adicionar',
        icon: AppIcons.addConsultant,
        isLoading: _viewModel.busyConsultantId == consultant.id,
        onPressed: enabled ? () => _viewModel.add(consultant.id) : null,
      ),
    );
  }

  Widget _buildFooterNote() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: InlineNotice(
        icon: AppIcons.syncDone,
        message: 'Entrar e sair da sessão vale na hora e precisa de conexão. '
            'Offline, a lista fica só de leitura.',
      ),
    );
  }

  /// Quem tem avaliação em andamento perde os participantes ao sair: a
  /// consequência vem num diálogo, antes do toque que remove (não está no
  /// canvas — decisão de 09/10/2026). Sem avaliação em andamento, sai direto.
  Future<void> _remove(SessionConsultantItem item) async {
    final consequence = item.note;
    if (consequence != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Remover ${item.name} da sessão?'),
          content: Text(consequence),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remover'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await _viewModel.remove(item.id);
  }

  Widget _buildSkeleton() {
    return ListView(
      key: const Key('session-consultants-skeleton'),
      children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
    );
  }
}
```

O aviso de falha fica na coluna da tela, acima da lista, e não dentro dela: com a lista rolada até o fim, é lá que o admin toca. O "Adicionar" usa o mesmo desenho do "adicionar participante" do detalhe (`Icons.person_add_outlined`): os dois são o `person_add_alt` do canvas.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_consultants/session_consultants_screen_test.dart`
Esperado: `+24: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+820: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/router.dart \
  apps/mobile/simtc/lib/ui/core/theme/app_icons.dart \
  apps/mobile/simtc/lib/ui/session_consultants/session_consultants_screen.dart \
  apps/mobile/simtc/test/ui/session_consultants/session_consultants_screen_test.dart
git commit -m "feat(mobile): tela 1.13 de consultores da sessao"
```

---

## Task 9: Detalhe — o ícone de pessoas e o "N consultores"

A entrada da tela nova (quadro `1f`): na barra do ADMIN, o ícone de pessoas entra entre o lápis e o indicador de envio; no cabeçalho, "3 consultores" entra depois da data. O ícone fica sempre ligado — sem conexão, ou com a sessão encerrada, a tela de lá abre para leitura. A contagem vem do cache da Task 4 e só aparece quando há consultores no aparelho. Para o consultor comum, nada muda — a ViewModel nem assina a lista.

A `SessionDetailViewModel` ganha um parâmetro obrigatório (o repositório de consultores), e por isso os testes que montam o detalhe passam a fornecê-lo — inclusive o da Home que abre o detalhe pela rota de produção.

**Files:**
- Modify: `lib/ui/core/theme/app_icons.dart`
- Modify: `lib/ui/session_detail/session_detail_viewmodel.dart`
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Modify: `test/ui/session_detail/session_detail_viewmodel_test.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`
- Modify: `test/ui/sessions/sessions_screen_test.dart` (só o provider novo)

**Interfaces:**
- Consumes: `SessionConsultantRepository.watchBySession` (Task 5); `AppRoutes.sessionConsultants` e `SessionConsultantsScreen` (Task 8); `AppTopBar.actions`, `AppIconAction`; `_buildMetaItem` (o item de ícone e texto do cabeçalho).
- Produces:
  - `SessionDetailViewModel({..., required SessionConsultantRepository consultantRepository, ...})`.
  - `String? SessionDetailViewModel.consultantsLabel` — "3 consultores", "1 consultor", ou nulo (sem consultores no cache, ou para quem não é ADMIN).
  - `AppIcons.consultants`, `AppIcons.consultantCount`.
  - No detalhe do ADMIN: `AppIconAction` com a dica "Consultores da sessão".

- [ ] **Step 1: Escrever os testes que falham**

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
```

**por:**

```dart
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_consultant.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
import 'package:simtc/ui/core/date_labels.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/session_detail/participant_row.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
import 'package:simtc/ui/session_edit/session_edit_screen.dart';
```

**por:**

```dart
import 'package:simtc/ui/core/date_labels.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/sync_status_indicator.dart';
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/session_consultants/session_consultants_screen.dart';
import 'package:simtc/ui/session_detail/participant_row.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
import 'package:simtc/ui/session_edit/session_edit_screen.dart';
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
```

**por:**

```dart

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConsultantRepository extends Mock
    implements SessionConsultantRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
  late _MockAssessmentRepository assessments;
  late _MockAssessmentCatalogRepository catalog;
  late _MockAuthRepository auth;
  late ConnectivityService connectivity;
  late StreamController<TrainingSession?> sessionStream;
  late StreamController<List<SessionParticipant>> participantsStream;
  late StreamController<List<LocalAssessment>> localStream;

  const consultora = AuthUser(
    id: 'u1',
```

**por:**

```dart
  late _MockAssessmentRepository assessments;
  late _MockAssessmentCatalogRepository catalog;
  late _MockAuthRepository auth;
  late _MockConsultantRepository consultants;
  late ConnectivityService connectivity;
  late StreamController<TrainingSession?> sessionStream;
  late StreamController<List<SessionParticipant>> participantsStream;
  late StreamController<List<LocalAssessment>> localStream;
  late StreamController<List<SessionConsultant>> consultantsStream;

  const carla = SessionConsultant(id: 'c-resp', name: 'Carla Mendes');
  const rafael = SessionConsultant(id: 'c-outro', name: 'Rafael Lima');
  const tatiane = SessionConsultant(id: 'c-3', name: 'Tatiane Souza');

  const consultora = AuthUser(
    id: 'u1',
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
    assessments = _MockAssessmentRepository();
    catalog = _MockAssessmentCatalogRepository();
    auth = _MockAuthRepository();
    connectivity = ConnectivityService();
    sessionStream = StreamController<TrainingSession?>.broadcast();
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();
    localStream = StreamController<List<LocalAssessment>>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => assessments.watchSessionAssessments('sess-1', 'u1'))
```

**por:**

```dart
    assessments = _MockAssessmentRepository();
    catalog = _MockAssessmentCatalogRepository();
    auth = _MockAuthRepository();
    consultants = _MockConsultantRepository();
    connectivity = ConnectivityService();
    sessionStream = StreamController<TrainingSession?>.broadcast();
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();
    localStream = StreamController<List<LocalAssessment>>.broadcast();
    consultantsStream = StreamController<List<SessionConsultant>>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => consultants.watchBySession('sess-1'))
        .thenAnswer((_) => consultantsStream.stream);
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => assessments.watchSessionAssessments('sess-1', 'u1'))
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
    sessionStream.close();
    participantsStream.close();
    localStream.close();
    connectivity.dispose();
  });
```

**por:**

```dart
    sessionStream.close();
    participantsStream.close();
    localStream.close();
    consultantsStream.close();
    connectivity.dispose();
  });
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
      providers: [
        Provider<SessionRepository>.value(value: sessions),
        Provider<ParticipantRepository>.value(value: participants),
        Provider<AssessmentRepository>.value(value: assessments),
        Provider<AssessmentCatalogRepository>.value(value: catalog),
        ChangeNotifierProvider<AuthRepository>.value(value: auth),
```

**por:**

```dart
      providers: [
        Provider<SessionRepository>.value(value: sessions),
        Provider<ParticipantRepository>.value(value: participants),
        Provider<SessionConsultantRepository>.value(value: consultants),
        Provider<AssessmentRepository>.value(value: assessments),
        Provider<AssessmentCatalogRepository>.value(value: catalog),
        ChangeNotifierProvider<AuthRepository>.value(value: auth),
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
    });
  });

  group('navegação pelas rotas reais', () {
    /// O detalhe aberto pelo `createRouter` de produção; devolve o router,
    /// para o teste empilhar outra rota real por cima.
```

**por:**

```dart
    });
  });

  group('consultores da sessão (Fase 6B)', () {
    AppIconAction action(WidgetTester tester, IconData icon) =>
        tester.widget<AppIconAction>(find.widgetWithIcon(AppIconAction, icon));

    testWidgets('consultor comum não vê o ícone de pessoas nem a contagem',
        (tester) async {
      await show(tester);
      consultantsStream.add(const [carla, rafael, tatiane]);
      await tester.pump();

      expect(find.byTooltip('Consultores da sessão'), findsNothing);
      expect(find.byIcon(AppIcons.consultants), findsNothing);
      expect(find.textContaining('consultor'), findsNothing);
    });

    testWidgets(
        'ADMIN vê o ícone de pessoas entre o lápis e o indicador de envio, '
        'como no quadro "1f"', (tester) async {
      when(() => auth.currentUser).thenReturn(admin);

      await show(tester);

      expect(action(tester, AppIcons.consultants).onPressed, isNotNull);
      final edit = tester.getCenter(find.byTooltip('Editar dados do treinamento'));
      final people = tester.getCenter(find.byTooltip('Consultores da sessão'));
      final sync = tester.getCenter(find.byType(SyncStatusIndicator));
      expect(people.dx, greaterThan(edit.dx));
      expect(people.dx, lessThan(sync.dx));
      expect(people.dy, edit.dy);
      expect(
        tester.getSize(find.widgetWithIcon(AppIconAction, AppIcons.consultants)),
        const Size(48, 48),
      );
    });

    testWidgets(
        'o ícone de pessoas fica ligado sem conexão e em sessão concluída: a '
        'tela de lá abre para leitura', (tester) async {
      when(() => auth.currentUser).thenReturn(admin);
      await goOffline();

      await show(tester, withSession: session(status: SessionStatus.concluido));

      expect(action(tester, AppIcons.edit).onPressed, isNull);
      expect(action(tester, AppIcons.consultants).onPressed, isNotNull);
    });

    testWidgets(
        'o cabeçalho do ADMIN mostra "3 consultores" depois da data, com o '
        'ícone do quadro', (tester) async {
      when(() => auth.currentUser).thenReturn(admin);

      await show(tester);
      expect(find.textContaining('consultor'), findsNothing,
          reason: 'os consultores ainda não chegaram do cache');

      consultantsStream.add(const [carla, rafael, tatiane]);
      await tester.pump();

      final label = find.text('3 consultores');
      expect(label, findsOneWidget);
      final date = tester.getRect(find.text('12 set 2026'));
      final count = tester.getRect(label);
      final chip = tester.getRect(find.text('Em andamento'));
      // Na ordem de leitura: à direita na mesma linha, ou na linha de baixo
      // quando não cabe (a fonte de teste é mais larga que a do app).
      bool comesAfter(Rect later, Rect earlier) =>
          later.top >= earlier.bottom ||
          ((later.center.dy - earlier.center.dy).abs() < 2 &&
              later.left > earlier.right);
      expect(comesAfter(count, date), isTrue, reason: 'a contagem vem depois da data');
      expect(comesAfter(chip, count), isTrue, reason: 'o status vem por último');

      // O ícone fica à esquerda do texto, a 5 dele, como os outros dois.
      final icon = tester.getRect(find.byIcon(AppIcons.consultantCount));
      expect(count.left - icon.right, 5);
      expect(icon.width, 17);
    });

    testWidgets('com um consultor só, o singular; sem nenhum no aparelho, some',
        (tester) async {
      when(() => auth.currentUser).thenReturn(admin);

      await show(tester);
      consultantsStream.add(const [carla]);
      await tester.pump();
      expect(find.text('1 consultor'), findsOneWidget);

      consultantsStream.add(const []);
      await tester.pump();
      expect(find.textContaining('consultor'), findsNothing);
      expect(find.byIcon(AppIcons.consultantCount), findsNothing);
    });

    testWidgets(
        'num celular de 360 de largura, a barra do ADMIN com os três ícones e '
        'o cabeçalho com a contagem não estouram', (tester) async {
      when(() => auth.currentUser).thenReturn(admin);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        withProviders(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const SessionDetailScreen(sessionId: 'sess-1'),
          ),
        ),
      );
      sessionStream.add(session());
      participantsStream.add(const []);
      localStream.add(const []);
      consultantsStream.add(const [carla, rafael, tatiane]);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('3 consultores'), findsOneWidget);
      expect(find.byTooltip('Consultores da sessão'), findsOneWidget);
    });
  });

  group('navegação pelas rotas reais', () {
    /// O detalhe aberto pelo `createRouter` de produção; devolve o router,
    /// para o teste empilhar outra rota real por cima.
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
        verify(() => participants.syncSession('sess-1')).called(1);
      });

      testWidgets('fechar "Adicionar participante" sem adicionar não baixa nada',
          (tester) async {
        final router = await showAdmin(tester);
```

**por:**

```dart
        verify(() => participants.syncSession('sess-1')).called(1);
      });

      testWidgets('o ícone de pessoas abre "Consultores", e o voltar traz de '
          'volta ao detalhe', (tester) async {
        when(() => consultants.watchBySession('sess-1'))
            .thenAnswer((_) => Stream.value(const [carla, rafael]));
        when(() => consultants.fetchTeam())
            .thenAnswer((_) async => const Success([carla, rafael, tatiane]));
        final router = await showAdmin(tester);

        await tester.tap(find.byTooltip('Consultores da sessão'));
        await tester.pumpAndSettle();

        final screen = tester.widget<SessionConsultantsScreen>(
          find.byType(SessionConsultantsScreen),
        );
        expect(screen.sessionId, 'sess-1');

        router.pop();
        await tester.pumpAndSettle();

        expect(find.byType(SessionConsultantsScreen), findsNothing);
        expect(find.byType(SessionDetailScreen), findsOneWidget);
      });

      testWidgets('fechar "Adicionar participante" sem adicionar não baixa nada',
          (tester) async {
        final router = await showAdmin(tester);
```

**Em `test/ui/session_detail/session_detail_viewmodel_test.dart`, substituir:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
```

**por:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_consultant.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
```

**Em `test/ui/session_detail/session_detail_viewmodel_test.dart`, substituir:**

```dart
class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockAssessmentRepository extends Mock implements AssessmentRepository {}

/// Conectividade de mentira: o serviço real conversa com o plugin de
/// plataforma, que não existe num teste de unidade.
```

**por:**

```dart
class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockAssessmentRepository extends Mock implements AssessmentRepository {}

class _MockConsultantRepository extends Mock
    implements SessionConsultantRepository {}

/// Conectividade de mentira: o serviço real conversa com o plugin de
/// plataforma, que não existe num teste de unidade.
```

**Em `test/ui/session_detail/session_detail_viewmodel_test.dart`, substituir:**

```dart
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late _MockAssessmentRepository assessments;
  late _FakeConnectivity connectivity;
  late StreamController<TrainingSession?> sessionStream;
  late StreamController<List<SessionParticipant>> participantsStream;
  late StreamController<List<LocalAssessment>> localStream;

  const consultora = AuthUser(
    id: 'u1',
```

**por:**

```dart
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late _MockAssessmentRepository assessments;
  late _MockConsultantRepository consultants;
  late _FakeConnectivity connectivity;
  late StreamController<TrainingSession?> sessionStream;
  late StreamController<List<SessionParticipant>> participantsStream;
  late StreamController<List<LocalAssessment>> localStream;
  late StreamController<List<SessionConsultant>> consultantsStream;

  const consultora = AuthUser(
    id: 'u1',
```

**Em `test/ui/session_detail/session_detail_viewmodel_test.dart`, substituir:**

```dart
      sessionRepository: sessions,
      participantRepository: participants,
      assessmentRepository: assessments,
      connectivity: connectivity,
      currentUser: user,
      now: () => DateTime(2026, 9, 23, 14),
```

**por:**

```dart
      sessionRepository: sessions,
      participantRepository: participants,
      assessmentRepository: assessments,
      consultantRepository: consultants,
      connectivity: connectivity,
      currentUser: user,
      now: () => DateTime(2026, 9, 23, 14),
```

**Em `test/ui/session_detail/session_detail_viewmodel_test.dart`, substituir:**

```dart
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    assessments = _MockAssessmentRepository();
    connectivity = _FakeConnectivity();
    sessionStream = StreamController<TrainingSession?>.broadcast();
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();
    localStream = StreamController<List<LocalAssessment>>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => participants.syncSession('sess-1'))
```

**por:**

```dart
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    assessments = _MockAssessmentRepository();
    consultants = _MockConsultantRepository();
    connectivity = _FakeConnectivity();
    sessionStream = StreamController<TrainingSession?>.broadcast();
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();
    localStream = StreamController<List<LocalAssessment>>.broadcast();
    consultantsStream = StreamController<List<SessionConsultant>>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => consultants.watchBySession('sess-1'))
        .thenAnswer((_) => consultantsStream.stream);
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => participants.syncSession('sess-1'))
```

**Em `test/ui/session_detail/session_detail_viewmodel_test.dart`, substituir:**

```dart
    sessionStream.close();
    participantsStream.close();
    localStream.close();
    connectivity.dispose();
  });
```

**por:**

```dart
    sessionStream.close();
    participantsStream.close();
    localStream.close();
    consultantsStream.close();
    connectivity.dispose();
  });
```

**Em `test/ui/session_detail/session_detail_viewmodel_test.dart`, substituir:**

```dart

        expect(vm.isAdmin, isTrue);
        expect(vm.adminActionsAllowed, isFalse);
      });
    });
  });
```

**por:**

```dart

        expect(vm.isAdmin, isTrue);
        expect(vm.adminActionsAllowed, isFalse);
      });
    });

    group('"N consultores" do ADMIN (Fase 6B)', () {
      const admin = AuthUser(
        id: 'u2',
        name: 'Rita Alves',
        email: 'rita@simtc.com.br',
        role: AppUserRole.admin,
      );
      const carla = SessionConsultant(id: 'c-1', name: 'Carla Mendes');
      const rafael = SessionConsultant(id: 'c-2', name: 'Rafael Lima');
      const tatiane = SessionConsultant(id: 'c-3', name: 'Tatiane Souza');

      test('conta os consultores que o cache tem, e acompanha as mudanças',
          () async {
        final vm = await ready(user: admin);
        consultantsStream.add(const [carla, rafael, tatiane]);
        await pumpEventQueue();

        expect(vm.consultantsLabel, '3 consultores');

        consultantsStream.add(const [carla]);
        await pumpEventQueue();

        expect(vm.consultantsLabel, '1 consultor');
      });

      test('sem os consultores no aparelho, não há contagem para mostrar',
          () async {
        final vm = await ready(user: admin);
        expect(vm.consultantsLabel, isNull, reason: 'o cache ainda não respondeu');

        consultantsStream.add(const []);
        await pumpEventQueue();

        expect(vm.consultantsLabel, isNull);
      });

      test('o consultor comum não vê a contagem, nem assina a lista', () async {
        final vm = await ready();
        consultantsStream.add(const [carla, rafael]);
        await pumpEventQueue();

        expect(vm.consultantsLabel, isNull);
        verifyNever(() => consultants.watchBySession(any()));
      });

      test('fechar a tela larga a lista de consultores', () async {
        final vm = await ready(user: admin);
        expect(consultantsStream.hasListener, isTrue);

        vm.dispose();

        expect(consultantsStream.hasListener, isFalse);
        consultantsStream.add(const [carla]);
        await pumpEventQueue();
      });
    });
  });
```

**Em `test/ui/sessions/sessions_screen_test.dart`, substituir:**

```dart
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
```

**por:**

```dart
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
```

**Em `test/ui/sessions/sessions_screen_test.dart`, substituir:**

```dart
class _MockCatalogRepository extends Mock implements AssessmentCatalogRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockAssessmentRepository extends Mock implements AssessmentRepository {}
```

**por:**

```dart
class _MockCatalogRepository extends Mock implements AssessmentCatalogRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockConsultantRepository extends Mock
    implements SessionConsultantRepository {}

class _MockAssessmentRepository extends Mock implements AssessmentRepository {}
```

**Em `test/ui/sessions/sessions_screen_test.dart`, substituir:**

```dart
          Provider<SessionRepository>.value(value: repository),
          Provider<AssessmentCatalogRepository>.value(value: catalog),
          Provider<ParticipantRepository>.value(value: participants),
          Provider<AssessmentRepository>.value(value: assessments),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
```

**por:**

```dart
          Provider<SessionRepository>.value(value: repository),
          Provider<AssessmentCatalogRepository>.value(value: catalog),
          Provider<ParticipantRepository>.value(value: participants),
          // O detalhe só o usa para o ADMIN; aqui quem abre é a consultora.
          Provider<SessionConsultantRepository>.value(
            value: _MockConsultantRepository(),
          ),
          Provider<AssessmentRepository>.value(value: assessments),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_detail test/ui/sessions/sessions_screen_test.dart`
Esperado: os dois arquivos do detalhe não compilam — `Member not found: 'consultants'` e `Member not found: 'consultantCount'` (os dois ícones novos) no da tela; `No named parameter with the name 'consultantRepository'` e `The getter 'consultantsLabel' isn't defined for the type 'SessionDetailViewModel'` no da ViewModel. O da Home só ganhou o provider que o detalhe vai pedir, e não depende do Step 3.

- [ ] **Step 3: Implementar**

**Em `lib/ui/core/theme/app_icons.dart`, substituir:**

```dart
  /// O lápis do ADMIN na barra do detalhe da sessão (Fase 6A, canvas "1f").
  static const IconData edit = Icons.edit_outlined;

  /// "Adicionar participante" (Fase 6A, canvas "3a"): o campo do CPF, o
  /// cartão "Teórica + prática" e o botão que adiciona.
  static const IconData cpf = Icons.badge_outlined;
```

**por:**

```dart
  /// O lápis do ADMIN na barra do detalhe da sessão (Fase 6A, canvas "1f").
  static const IconData edit = Icons.edit_outlined;

  /// Os consultores da sessão no detalhe do ADMIN (Fase 6B, canvas "1f"): o
  /// atalho da barra e a contagem ao lado da data.
  static const IconData consultants = Icons.group_outlined;
  static const IconData consultantCount = Icons.badge_outlined;

  /// "Adicionar participante" (Fase 6A, canvas "3a"): o campo do CPF, o
  /// cartão "Teórica + prática" e o botão que adiciona.
  static const IconData cpf = Icons.badge_outlined;
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../router.dart';
```

**por:**

```dart
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_consultant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../router.dart';
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    assessmentRepository: context.read<AssessmentRepository>(),
    connectivity: context.read<ConnectivityService>(),
    currentUser: context.read<AuthRepository>().currentUser,
  )..init();
```

**por:**

```dart
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    assessmentRepository: context.read<AssessmentRepository>(),
    consultantRepository: context.read<SessionConsultantRepository>(),
    connectivity: context.read<ConnectivityService>(),
    currentUser: context.read<AuthRepository>().currentUser,
  )..init();
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
            AppTopBar(
              title: 'Detalhe da sessão',
              actions: [
                if (_viewModel.isAdmin)
                  AppIconAction(
                    icon: AppIcons.edit,
                    tooltip: 'Editar dados do treinamento',
                    onPressed: _adminActionsEnabled(isOffline) ? _openEdit : null,
                  ),
              ],
              trailing: SyncStatusIndicator(
                onTap: () => context.go(AppRoutes.sync),
```

**por:**

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
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
    final saved =
        await context.push<bool>(AppRoutes.sessionEdit(widget.sessionId));
    if (saved == true && mounted) unawaited(_viewModel.refresh());
  }

  /// Entrou gente lá: a linha nova já está no cache, e baixar de novo acerta
```

**por:**

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
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart

  Widget _buildMetaRow(TrainingSession session) {
    final date = session.date;

    return Wrap(
      spacing: AppSpacing.lg,
```

**por:**

```dart

  Widget _buildMetaRow(TrainingSession session) {
    final date = session.date;
    final consultants = _viewModel.consultantsLabel;

    return Wrap(
      spacing: AppSpacing.lg,
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
          AppIcons.event,
          date == null ? 'Sem data' : dayMonthYearLabel(date),
        ),
        StatusChip(
          label: session.status.label,
          icon: session.status.icon,
```

**por:**

```dart
          AppIcons.event,
          date == null ? 'Sem data' : dayMonthYearLabel(date),
        ),
        if (consultants != null)
          _buildMetaItem(AppIcons.consultantCount, consultants),
        StatusChip(
          label: session.status.label,
          icon: session.status.icon,
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart
import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../data/services/connectivity_service.dart';
```

**por:**

```dart
import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/models/session_consultant.dart';
import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_consultant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../data/services/connectivity_service.dart';
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart
    required SessionRepository sessionRepository,
    required ParticipantRepository participantRepository,
    required AssessmentRepository assessmentRepository,
    required ConnectivityService connectivity,
    required AuthUser? currentUser,
    DateTime Function()? now,
  })  : _sessionRepository = sessionRepository,
        _participantRepository = participantRepository,
        _assessmentRepository = assessmentRepository,
        _connectivity = connectivity,
        _currentUser = currentUser,
        _now = now ?? DateTime.now;
```

**por:**

```dart
    required SessionRepository sessionRepository,
    required ParticipantRepository participantRepository,
    required AssessmentRepository assessmentRepository,
    required SessionConsultantRepository consultantRepository,
    required ConnectivityService connectivity,
    required AuthUser? currentUser,
    DateTime Function()? now,
  })  : _sessionRepository = sessionRepository,
        _participantRepository = participantRepository,
        _assessmentRepository = assessmentRepository,
        _consultantRepository = consultantRepository,
        _connectivity = connectivity,
        _currentUser = currentUser,
        _now = now ?? DateTime.now;
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart
  final SessionRepository _sessionRepository;
  final ParticipantRepository _participantRepository;
  final AssessmentRepository _assessmentRepository;
  final ConnectivityService _connectivity;
  final AuthUser? _currentUser;
  final DateTime Function() _now;
```

**por:**

```dart
  final SessionRepository _sessionRepository;
  final ParticipantRepository _participantRepository;
  final AssessmentRepository _assessmentRepository;
  final SessionConsultantRepository _consultantRepository;
  final ConnectivityService _connectivity;
  final AuthUser? _currentUser;
  final DateTime Function() _now;
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart
  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<List<SessionParticipant>>? _participantsSubscription;
  StreamSubscription<List<LocalAssessment>>? _localSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  TrainingSession? _session;
  List<SessionParticipant> _participants = const [];
  Map<String, LocalAssessment> _local = const {};
  bool _sessionLoaded = false;
  bool _participantsLoaded = false;
  bool _isRefreshing = false;
```

**por:**

```dart
  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<List<SessionParticipant>>? _participantsSubscription;
  StreamSubscription<List<LocalAssessment>>? _localSubscription;
  StreamSubscription<List<SessionConsultant>>? _consultantsSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  TrainingSession? _session;
  List<SessionParticipant> _participants = const [];
  Map<String, LocalAssessment> _local = const {};
  int _consultantCount = 0;
  bool _sessionLoaded = false;
  bool _participantsLoaded = false;
  bool _isRefreshing = false;
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart
  /// planejada ou em andamento. A tela ainda exige conexão.
  bool get adminActionsAllowed =>
      isAdmin && (_session?.status.acceptsChanges ?? false);

  /// Há alguém que eu poderia atribuir agora — é quando o aviso de "atribuir
  /// precisa de internet" faz sentido.
```

**por:**

```dart
  /// planejada ou em andamento. A tela ainda exige conexão.
  bool get adminActionsAllowed =>
      isAdmin && (_session?.status.acceptsChanges ?? false);

  /// "3 consultores", ao lado da data — só o ADMIN vê (canvas "1f"): para o
  /// consultor, a lista nem é assinada. Nulo enquanto os consultores da
  /// sessão não foram baixados neste aparelho: a tela não afirma "0
  /// consultores".
  String? get consultantsLabel {
    if (_consultantCount == 0) return null;
    return _consultantCount == 1
        ? '1 consultor'
        : '$_consultantCount consultores';
  }

  /// Há alguém que eu poderia atribuir agora — é quando o aviso de "atribuir
  /// precisa de internet" faz sentido.
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart
          .watchSessionAssessments(sessionId, ownerUserId)
          .listen((rows) {
        _local = {for (final row in rows) row.trainingParticipantId: row};
        notifyListeners();
      });
    }
```

**por:**

```dart
          .watchSessionAssessments(sessionId, ownerUserId)
          .listen((rows) {
        _local = {for (final row in rows) row.trainingParticipantId: row};
        notifyListeners();
      });
    }

    // Só o ADMIN vê a contagem de consultores.
    if (isAdmin) {
      _consultantsSubscription ??= _consultantRepository
          .watchBySession(sessionId)
          .listen((consultants) {
        _consultantCount = consultants.length;
        notifyListeners();
      });
    }
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart
    _sessionSubscription?.cancel();
    _participantsSubscription?.cancel();
    _localSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
```

**por:**

```dart
    _sessionSubscription?.cancel();
    _participantsSubscription?.cancel();
    _localSubscription?.cancel();
    _consultantsSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
```

O detalhe não espera nada da tela de Consultores na volta: o que muda por lá muda o cache, e o detalhe lê do cache.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_detail test/ui/sessions/sessions_screen_test.dart`
Esperado: `+113: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+831: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/ui/core/theme/app_icons.dart \
  apps/mobile/simtc/lib/ui/session_detail/session_detail_screen.dart \
  apps/mobile/simtc/lib/ui/session_detail/session_detail_viewmodel.dart \
  apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart \
  apps/mobile/simtc/test/ui/session_detail/session_detail_viewmodel_test.dart \
  apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart
git commit -m "feat(mobile): icone de pessoas e contagem de consultores no detalhe"
```

---

## Task 10: Detalhe — o ⋮ do ADMIN para desatribuir

Para o ADMIN, a linha de quem está em avaliação com **outro** consultor ganha um ⋮ no lugar onde as outras têm a setinha, com "Desatribuir participante" (decisão 12). A confirmação diz com quem o participante está e para onde ele volta. O app já tinha a chamada (`ParticipantRepository.unassign`, a do ⋮ do checklist), que muda a linha na hora; a Task 2 fez o backend aceitar o ADMIN.

O ⋮ segue a regra das ações de ADMIN: sem conexão, ou com a sessão concluída ou cancelada, fica à vista e apagado. É um alvo de 48dp, e o recuo à direita da linha encolhe para o ícone — e não a área de toque — ficar na margem da lista; para isso o recuo lateral da `ParticipantRow` passa a ser de cada parte dela, sem mudar as linhas que não têm ⋮.

**Files:**
- Modify: `lib/ui/session_detail/participant_row.dart`
- Modify: `lib/ui/session_detail/session_detail_viewmodel.dart`
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Modify: `test/ui/session_detail/session_detail_viewmodel_test.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`

**Interfaces:**
- Consumes: `ParticipantRepository.unassign(String participantId)` → `Result<void>` (a mensagem do backend em 409 e a de falta de rede); `SessionDetailViewModel.isAdmin`, `adminActionsAllowed`, `situationFor`, `refresh()`; `ParticipantSituation.other`; `SessionParticipant.assignedConsultantName`, `hasPreviousAssessment`; `AppIcons.more`; o backend da Task 2.
- Produces:
  - `ParticipantRow({..., Widget? menu})` — no lugar da setinha.
  - `bool SessionDetailViewModel.showsAdminMenu(SessionParticipant participant)`; `String? unassigningParticipantId`; `Future<void> unassignAsAdmin(String participantId)` — no sucesso, `message` = "<nome> foi desatribuído." e o detalhe é baixado de novo; na recusa, o motivo e o detalhe baixado de novo; sem rede, só o motivo.
  - Chaves para os testes: `menu-<id>` (o ⋮) e `desatribuindo-<id>` (o indicador no lugar dele).

- [ ] **Step 1: Escrever os testes que falham**

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/add_participant/add_participant_screen.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/date_labels.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/sync_status_indicator.dart';
```

**por:**

```dart
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/add_participant/add_participant_screen.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/date_labels.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/sync_status_indicator.dart';
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
    });
  });

  group('navegação pelas rotas reais', () {
    /// O detalhe aberto pelo `createRouter` de produção; devolve o router,
    /// para o teste empilhar outra rota real por cima.
```

**por:**

```dart
    });
  });

  group('o ADMIN desatribui pelo ⋮ da linha (Fase 6B)', () {
    late SessionParticipant marcos;

    setUp(() {
      marcos = participant(
        '3',
        'Marcos Vinícius Alves',
        status: ParticipantStatus.emAvaliacao,
        assignedTo: 'c-outro',
        assignedName: 'Rafael Lima',
      );
      when(() => auth.currentUser).thenReturn(admin);
      when(() => participants.unassign(any()))
          .thenAnswer((_) async => const Success<void>(null));
    });

    Finder menuOf(String id) => find.byKey(ValueKey('menu-$id'));

    PopupMenuButton<Object?> menuButton(WidgetTester tester, String id) =>
        tester.widget<PopupMenuButton<Object?>>(
          find.descendant(
            of: find.byKey(ValueKey('participante-$id')),
            matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
          ),
        );

    /// Abre o ⋮ da linha e escolhe "Desatribuir participante".
    Future<void> chooseUnassign(WidgetTester tester, String id) async {
      await tester.tap(menuOf(id));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desatribuir participante'));
      await tester.pumpAndSettle();
    }

    testWidgets('consultor comum não tem o ⋮ na linha de quem está com outro',
        (tester) async {
      when(() => auth.currentUser).thenReturn(consultora);

      await show(tester, withParticipants: [marcos]);

      expect(find.text('Em avaliação com outro consultor.'), findsOneWidget);
      expect(find.byIcon(AppIcons.more), findsNothing);
    });

    testWidgets(
        'o ADMIN vê o ⋮ só na linha de quem está com outro consultor, num '
        'alvo de 48dp com o ícone na margem da lista', (tester) async {
      await show(tester, withParticipants: [
        participant('1', 'Ana Paula Ribeiro',
            status: ParticipantStatus.emAvaliacao, assignedTo: 'c-admin'),
        participant('2', 'Carlos Eduardo Nunes'),
        marcos,
        participant('4', 'Juliana Freitas Costa',
            status: ParticipantStatus.aprovado, score: 86.4),
      ]);

      expect(find.byIcon(AppIcons.more), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('participante-3')),
          matching: find.byIcon(AppIcons.more),
        ),
        findsOneWidget,
      );
      expect(menuButton(tester, '3').enabled, isTrue);
      expect(find.byTooltip('Mais opções'), findsOneWidget);

      final target = tester.getRect(
        find.ancestor(of: menuOf('3'), matching: find.byType(SizedBox)).first,
      );
      expect(target.size, const Size(48, 48));
      // A tela de teste tem 420 de largura; a margem da lista é de 20.
      expect(tester.getRect(find.byIcon(AppIcons.more)).right, 420 - 20);
      // A nota de baixo continua na margem de sempre.
      final row = tester.getRect(find.byKey(const ValueKey('participante-3')));
      final note = tester.getRect(find.text('Em avaliação com outro consultor.'));
      expect(note.left - row.left, 20);
      // A linha não abre nada: quem age é o menu.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('participante-3')),
          matching: find.byIcon(AppIcons.chevronRight),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'as linhas mantêm os recuos de sempre, com ou sem o ⋮: 20 dos lados e '
        '15 em cima e embaixo', (tester) async {
      await show(tester, withParticipants: [
        participant('2', 'Carlos Eduardo Nunes'),
        marcos,
      ]);

      // A linha pendente, com o "Atribuir a mim" embaixo.
      final pending = tester.getRect(find.byKey(const ValueKey('participante-2')));
      final pendingName = tester.getRect(find.text('Carlos Eduardo Nunes'));
      final assign = tester.getRect(find.byKey(const ValueKey('atribuir-2')));
      expect(pendingName.left - pending.left, 20);
      // 0,8 do traço de cima mais os 15 do recuo.
      expect(pendingName.top - pending.top, closeTo(15.8, 0.01));
      expect(assign.left - pending.left, 20);
      expect(pending.right - assign.right, 20);
      expect(pending.bottom - assign.bottom, 15);

      // A linha com o ⋮: o nome e a nota na mesma margem.
      final other = tester.getRect(find.byKey(const ValueKey('participante-3')));
      final otherName = tester.getRect(find.text('Marcos Vinícius Alves'));
      final note = tester.getRect(find.text('Em avaliação com outro consultor.'));
      expect(otherName.left - other.left, 20);
      expect(other.bottom - note.bottom, 15);
    });

    testWidgets(
        'o menu oferece "Desatribuir participante", e a confirmação diz com '
        'quem está e para onde volta', (tester) async {
      await show(tester, withParticipants: [marcos]);

      await tester.tap(menuOf('3'));
      await tester.pumpAndSettle();
      expect(find.text('Desatribuir participante'), findsOneWidget);

      await tester.tap(find.text('Desatribuir participante'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Desatribuir Marcos Vinícius Alves?'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(
            'Está em avaliação com Rafael Lima. Ao desatribuir, volta para '
            'Pendente e pode ser avaliado por outro consultor.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Voltar'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Desatribuir'), findsOneWidget);
      verifyNever(() => participants.unassign(any()));
    });

    testWidgets('numa reavaliação, a confirmação diz que volta para Não '
        'recomendado', (tester) async {
      await show(tester, withParticipants: [
        participant(
          '3',
          'Marcos Vinícius Alves',
          status: ParticipantStatus.emAvaliacao,
          assignedTo: 'c-outro',
          assignedName: 'Rafael Lima',
          score: 62,
        ),
      ]);

      await chooseUnassign(tester, '3');

      expect(
        find.text(
          'Está em avaliação com Rafael Lima. Ao desatribuir, volta para Não '
          'recomendado e pode ser avaliado por outro consultor.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('sem o nome do consultor no aparelho, a confirmação fala em '
        'outro consultor', (tester) async {
      await show(tester, withParticipants: [
        participant('3', 'Marcos Vinícius Alves',
            status: ParticipantStatus.emAvaliacao, assignedTo: 'c-outro'),
      ]);

      await chooseUnassign(tester, '3');

      expect(
        find.text(
          'Está em avaliação com outro consultor. Ao desatribuir, volta para '
          'Pendente e pode ser avaliado por outro consultor.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Voltar" fecha a confirmação sem desatribuir', (tester) async {
      await show(tester, withParticipants: [marcos]);
      await chooseUnassign(tester, '3');

      await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => participants.unassign(any()));
    });

    testWidgets('confirmando, desatribui e avisa com o nome do participante',
        (tester) async {
      await show(tester, withParticipants: [marcos]);
      await chooseUnassign(tester, '3');

      await tester.tap(find.widgetWithText(FilledButton, 'Desatribuir'));
      await tester.pumpAndSettle();

      verify(() => participants.unassign('3')).called(1);
      expect(find.text('Marcos Vinícius Alves foi desatribuído.'), findsOneWidget);
    });

    testWidgets(
        'com a resposta demorando: a linha gira no lugar do ⋮, e o ⋮ das '
        'outras linhas não abre', (tester) async {
      final reply = Completer<Result<void>>();
      when(() => participants.unassign('3')).thenAnswer((_) => reply.future);
      final bruno = participant(
        '7',
        'Bruno Lima',
        status: ParticipantStatus.emAvaliacao,
        assignedTo: 'c-outro',
        assignedName: 'Rafael Lima',
      );
      await show(tester, withParticipants: [marcos, bruno]);
      await chooseUnassign(tester, '3');

      await tester.tap(find.widgetWithText(FilledButton, 'Desatribuir'));
      await tester.pump();
      // Um quadro no meio do envio.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('desatribuindo-3')), findsOneWidget);
      expect(menuOf('3'), findsNothing);
      expect(menuButton(tester, '7').enabled, isFalse);
      expect(find.textContaining('foi desatribuído'), findsNothing);

      reply.complete(const Success<void>(null));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('desatribuindo-3')), findsNothing);
      expect(menuButton(tester, '7').enabled, isTrue);
      expect(find.text('Marcos Vinícius Alves foi desatribuído.'), findsOneWidget);
    });

    testWidgets('recusado pelo servidor: o motivo aparece', (tester) async {
      when(() => participants.unassign('3')).thenAnswer(
        (_) async => const Failure(
          ApiException(
            message: 'Um ou mais participantes não estão em avaliação',
            statusCode: 409,
          ),
          'Um ou mais participantes não estão em avaliação',
        ),
      );
      await show(tester, withParticipants: [marcos]);
      await chooseUnassign(tester, '3');

      await tester.tap(find.widgetWithText(FilledButton, 'Desatribuir'));
      await tester.pumpAndSettle();

      expect(
        find.text('Um ou mais participantes não estão em avaliação'),
        findsOneWidget,
      );
      expect(find.textContaining('foi desatribuído'), findsNothing);
    });

    testWidgets('sem conexão, o ⋮ continua à vista, apagado, e não abre',
        (tester) async {
      await goOffline();

      await show(tester, withParticipants: [marcos]);

      expect(find.byIcon(AppIcons.more), findsOneWidget);
      expect(menuButton(tester, '3').enabled, isFalse);
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.more)).color,
        AppColors.textMuted,
      );
      // O motivo é o aviso que a lista já mostra.
      expect(
        find.text('Ações administrativas precisam de conexão. A avaliação '
            'continua funcionando offline.'),
        findsOneWidget,
      );

      await tester.tap(menuOf('3'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Desatribuir participante'), findsNothing);
    });

    testWidgets('em sessão concluída, o ⋮ fica apagado', (tester) async {
      await show(
        tester,
        withSession: session(status: SessionStatus.concluido),
        withParticipants: [marcos],
      );

      expect(menuButton(tester, '3').enabled, isFalse);
    });

    testWidgets(
        'num celular de 360 de largura com a fonte ampliada, a linha com o '
        'chip e o ⋮ não estoura', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        withProviders(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const SessionDetailScreen(sessionId: 'sess-1'),
          ),
        ),
      );
      sessionStream.add(session());
      participantsStream.add([marcos]);
      localStream.add(const []);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(menuOf('3')).height, 48);
      expect(tester.getRect(find.byIcon(AppIcons.more)).right, 360 - 20);
    });
  });

  group('navegação pelas rotas reais', () {
    /// O detalhe aberto pelo `createRouter` de produção; devolve o router,
    /// para o teste empilhar outra rota real por cima.
```

**Em `test/ui/session_detail/session_detail_viewmodel_test.dart`, substituir:**

```dart
    });
  });

  group('linha "comigo" depois do envio aceito (revisão de 30/09/2026)', () {
    test(
        'sem download novo depois do envio, a linha mostra "Enviada" e não '
```

**por:**

```dart
    });
  });

  group('o ADMIN desatribui quem está com outro consultor (Fase 6B)', () {
    const admin = AuthUser(
      id: 'u2',
      name: 'Rita Alves',
      email: 'rita@simtc.com.br',
      role: AppUserRole.admin,
      consultantId: 'c-admin',
    );
    final comOutro = participant(
      'p1',
      status: ParticipantStatus.emAvaliacao,
      assignedTo: 'c-outro',
    );

    setUp(() {
      when(() => participants.unassign(any()))
          .thenAnswer((_) async => const Success<void>(null));
    });

    test('o menu é só do ADMIN, e só de quem está com outro consultor',
        () async {
      final comigo = participant(
        'p2',
        status: ParticipantStatus.emAvaliacao,
        assignedTo: 'c-admin',
      );
      final pendente = participant('p3');
      final aprovado = participant('p4', status: ParticipantStatus.aprovado);

      final vm = await ready(
        user: admin,
        withParticipants: [comOutro, comigo, pendente, aprovado],
      );
      expect(vm.showsAdminMenu(comOutro), isTrue);
      expect(vm.showsAdminMenu(comigo), isFalse);
      expect(vm.showsAdminMenu(pendente), isFalse);
      expect(vm.showsAdminMenu(aprovado), isFalse);

      final consultor = await ready(withParticipants: [comOutro]);
      expect(consultor.showsAdminMenu(comOutro), isFalse);
    });

    test('desatribui, avisa com o nome e baixa o detalhe de novo', () async {
      final vm = await ready(user: admin, withParticipants: [comOutro]);

      await vm.unassignAsAdmin('p1');
      await pumpEventQueue();

      verify(() => participants.unassign('p1')).called(1);
      expect(vm.message, 'Participante p1 foi desatribuído.');
      expect(vm.unassigningParticipantId, isNull);
      // O sync da abertura e o de depois de desatribuir.
      verify(() => participants.syncSession('sess-1')).called(2);
    });

    test('durante o envio só aquele participante aparece ocupado, e outro '
        'toque não manda nada', () async {
      final answer = Completer<Result<void>>();
      when(() => participants.unassign('p1')).thenAnswer((_) => answer.future);
      final outro = participant(
        'p5',
        status: ParticipantStatus.emAvaliacao,
        assignedTo: 'c-outro',
      );
      final vm = await ready(user: admin, withParticipants: [comOutro, outro]);

      final sending = vm.unassignAsAdmin('p1');
      await pumpEventQueue();

      expect(vm.unassigningParticipantId, 'p1');
      expect(vm.message, isNull);

      await vm.unassignAsAdmin('p5');
      await vm.unassignAsAdmin('p1');
      verifyNever(() => participants.unassign('p5'));

      answer.complete(const Success<void>(null));
      await sending;

      verify(() => participants.unassign('p1')).called(1);
      expect(vm.unassigningParticipantId, isNull);
    });

    test('recusado pelo servidor: mostra o motivo e baixa o detalhe, para a '
        'linha se acertar', () async {
      when(() => participants.unassign('p1')).thenAnswer(
        (_) async => const Failure(
          ApiException(
            message: 'Um ou mais participantes não estão em avaliação',
            statusCode: 409,
          ),
          'Um ou mais participantes não estão em avaliação',
        ),
      );
      final vm = await ready(user: admin, withParticipants: [comOutro]);

      await vm.unassignAsAdmin('p1');
      await pumpEventQueue();

      expect(vm.message, 'Um ou mais participantes não estão em avaliação');
      verify(() => participants.syncSession('sess-1')).called(2);
    });

    test('sem rede, avisa e não tenta baixar de novo', () async {
      when(() => participants.unassign('p1')).thenAnswer(
        (_) async => const Failure(
          ApiException(message: 'Sem conexão com o servidor.', isNetworkError: true),
          'Sem conexão com o servidor.',
        ),
      );
      final vm = await ready(user: admin, withParticipants: [comOutro]);

      await vm.unassignAsAdmin('p1');
      await pumpEventQueue();

      expect(vm.message, 'Sem conexão com o servidor.');
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('uma exceção inesperada vira a mensagem genérica, sem travar a linha',
        () async {
      when(() => participants.unassign('p1')).thenThrow(StateError('quebrou'));
      final vm = await ready(user: admin, withParticipants: [comOutro]);

      await vm.unassignAsAdmin('p1');

      expect(
        vm.message,
        'Não foi possível desatribuir o participante. Tente de novo.',
      );
      expect(vm.unassigningParticipantId, isNull);
    });

    test('quem não pode não manda nada: consultor comum, sessão encerrada, e '
        'participante que não está com outro consultor', () async {
      final consultor = await ready(withParticipants: [comOutro]);
      await consultor.unassignAsAdmin('p1');

      final encerrada = await ready(
        user: admin,
        withSession: session(status: SessionStatus.concluido),
        withParticipants: [comOutro],
      );
      await encerrada.unassignAsAdmin('p1');

      final pendente = participant('p3');
      final vm = await ready(user: admin, withParticipants: [pendente]);
      await vm.unassignAsAdmin('p3');
      await vm.unassignAsAdmin('nao-existe');

      verifyNever(() => participants.unassign(any()));
    });

    test('desatribuir que só responde depois do dispose não derruba o app nem '
        'baixa de novo', () async {
      final answer = Completer<Result<void>>();
      when(() => participants.unassign('p1')).thenAnswer((_) => answer.future);
      final vm = await ready(user: admin, withParticipants: [comOutro]);

      final sending = vm.unassignAsAdmin('p1');
      vm.dispose();
      answer.complete(const Success<void>(null));
      await sending;
      await pumpEventQueue();

      verify(() => participants.syncSession('sess-1')).called(1);
    });
  });

  group('linha "comigo" depois do envio aceito (revisão de 30/09/2026)', () {
    test(
        'sem download novo depois do envio, a linha mostra "Enviada" e não '
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_detail`
Esperado: o da ViewModel não compila — `The method 'showsAdminMenu' isn't defined for the type 'SessionDetailViewModel'`, `The method 'unassignAsAdmin' isn't defined…` e `The getter 'unassigningParticipantId' isn't defined…`; no da tela, os testes novos falham por não acharem o ⋮.

- [ ] **Step 3: Implementar**

**Em `lib/ui/session_detail/participant_row.dart`, substituir:**

```dart
    this.meta,
    this.blockedNote,
    this.action,
    this.onTap,
    this.accentColor = AppColors.border,
    this.muted = false,
```

**por:**

```dart
    this.meta,
    this.blockedNote,
    this.action,
    this.menu,
    this.onTap,
    this.accentColor = AppColors.border,
    this.muted = false,
```

**Em `lib/ui/session_detail/participant_row.dart`, substituir:**

```dart
  /// Botão sob a linha — hoje, só o "Atribuir a mim".
  final Widget? action;

  /// Nulo = a linha não abre nada, e o chevron some.
  final VoidCallback? onTap;
```

**por:**

```dart
  /// Botão sob a linha — hoje, só o "Atribuir a mim".
  final Widget? action;

  /// O ⋮ do ADMIN (Fase 6B), no lugar do chevron: um alvo de 48dp que a tela
  /// monta.
  final Widget? menu;

  /// Nulo = a linha não abre nada, e o chevron some.
  final VoidCallback? onTap;
```

**Em `lib/ui/session_detail/participant_row.dart`, substituir:**

```dart
  /// Fundo apagado para quem está com outro consultor.
  final bool muted;

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
          color: muted ? AppColors.background : AppColors.surface,
          border: Border(top: BorderSide(color: accentColor, width: 0.8)),
```

**por:**

```dart
  /// Fundo apagado para quem está com outro consultor.
  final bool muted;

  // O recuo lateral é de cada parte da linha, e não do contêiner: o cabeçalho
  // com o menu tem um recuo próprio à direita.
  static const EdgeInsets _sides =
      EdgeInsets.symmetric(horizontal: AppSpacing.xl);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg - 1),
        decoration: BoxDecoration(
          color: muted ? AppColors.background : AppColors.surface,
          border: Border(top: BorderSide(color: accentColor, width: 0.8)),
```

**Em `lib/ui/session_detail/participant_row.dart`, substituir:**

```dart
            _buildHeader(),
            if (blockedNote != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(blockedNote!, style: AppTypography.meta),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
```

**por:**

```dart
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

**Em `lib/ui/session_detail/participant_row.dart`, substituir:**

```dart
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(child: _buildIdentity()),
        const SizedBox(width: AppSpacing.md),
        chip,
        if (onTap != null) ...[
          const SizedBox(width: AppSpacing.xs),
          const Icon(AppIcons.chevronRight, size: 24, color: AppColors.text3),
        ],
      ],
    );
  }
```

**por:**

```dart
  }

  Widget _buildHeader() {
    return Padding(
      // Com o menu, o recuo da direita encolhe: é o ícone do ⋮, e não a área
      // de toque de 48dp, que fica na margem da lista — como o "adicionar" do
      // título "Participantes".
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: menu == null ? AppSpacing.xl : AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(child: _buildIdentity()),
          const SizedBox(width: AppSpacing.md),
          chip,
          if (menu != null)
            menu!
          else if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(AppIcons.chevronRight, size: 24, color: AppColors.text3),
          ],
        ],
      ),
    );
  }
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
      action: _viewModel.canAssign(participant)
          ? _buildAssignButton(participant, isOffline)
          : null,
    );
  }

  /// Para onde a linha leva: o checklist (Fase 4) ou o Resultado (Fase 5B) —
```

**por:**

```dart
      action: _viewModel.canAssign(participant)
          ? _buildAssignButton(participant, isOffline)
          : null,
      menu: _viewModel.showsAdminMenu(participant)
          ? _buildAdminMenu(participant, isOffline)
          : null,
    );
  }

  /// ⋮ do ADMIN na linha de quem está com outro consultor (decisão de
  /// 09/10/2026 — não está no canvas): "Desatribuir participante". Segue a
  /// regra das ações de ADMIN: sem conexão ou com a sessão encerrada, fica à
  /// vista, apagado, e o aviso da lista diz por quê. Com um desatribuir no ar,
  /// a linha dele gira e os outros menus não abrem.
  Widget _buildAdminMenu(SessionParticipant participant, bool isOffline) {
    final unassigning = _viewModel.unassigningParticipantId;
    if (unassigning == participant.id) {
      return SizedBox.square(
        key: ValueKey('desatribuindo-${participant.id}'),
        dimension: AppSpacing.touchTarget,
        child: const Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.text3),
            ),
          ),
        ),
      );
    }

    final enabled = _adminActionsEnabled(isOffline) && unassigning == null;
    return SizedBox.square(
      dimension: AppSpacing.touchTarget,
      child: PopupMenuButton<_RowAction>(
        key: ValueKey('menu-${participant.id}'),
        tooltip: 'Mais opções',
        enabled: enabled,
        icon: Icon(
          AppIcons.more,
          color: enabled ? AppColors.text : AppColors.textMuted,
        ),
        onSelected: (_) => _confirmUnassign(participant),
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _RowAction.unassign,
            child: Text('Desatribuir participante'),
          ),
        ],
      ),
    );
  }

  /// Volta para "Pendente" ou, numa reavaliação, para "Não recomendado" — a
  /// mesma regra do backend.
  Future<void> _confirmUnassign(SessionParticipant participant) async {
    final consultant = participant.assignedConsultantName?.trim() ?? '';
    final withWhom = consultant.isEmpty ? 'outro consultor' : consultant;
    final status =
        participant.hasPreviousAssessment ? 'Não recomendado' : 'Pendente';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Desatribuir ${participant.name}?'),
        content: Text(
          'Está em avaliação com $withWhom. Ao desatribuir, volta para '
          '$status e pode ser avaliado por outro consultor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desatribuir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _viewModel.unassignAsAdmin(participant.id);
    }
  }

  /// Para onde a linha leva: o checklist (Fase 4) ou o Resultado (Fase 5B) —
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
  }
}
```

**por:**

```dart
  }
}

/// O que o ⋮ de uma linha oferece ao ADMIN.
enum _RowAction { unassign }
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart
      'Não foi possível atribuir o participante. Tente de novo.';
  static const String _startFailed =
      'Não foi possível iniciar a sessão. Tente de novo.';

  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<List<SessionParticipant>>? _participantsSubscription;
```

**por:**

```dart
      'Não foi possível atribuir o participante. Tente de novo.';
  static const String _startFailed =
      'Não foi possível iniciar a sessão. Tente de novo.';
  static const String _unassignFailed =
      'Não foi possível desatribuir o participante. Tente de novo.';

  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<List<SessionParticipant>>? _participantsSubscription;
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart
  bool _isRefreshing = false;
  bool _isStarting = false;
  String? _assigningParticipantId;
  ParticipantFilter _filter = ParticipantFilter.todos;
  String? _message;
```

**por:**

```dart
  bool _isRefreshing = false;
  bool _isStarting = false;
  String? _assigningParticipantId;
  String? _unassigningParticipantId;
  ParticipantFilter _filter = ParticipantFilter.todos;
  String? _message;
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart

  /// Participante com atribuição em andamento — só um de cada vez.
  String? get assigningParticipantId => _assigningParticipantId;

  /// Aviso passageiro (SnackBar) — sucesso ou falha de uma ação.
  String? get message => _message;
```

**por:**

```dart

  /// Participante com atribuição em andamento — só um de cada vez.
  String? get assigningParticipantId => _assigningParticipantId;

  /// Participante que o ADMIN está desatribuindo — só um de cada vez.
  String? get unassigningParticipantId => _unassigningParticipantId;

  /// Aviso passageiro (SnackBar) — sucesso ou falha de uma ação.
  String? get message => _message;
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart
      evaluationOpen &&
      hasConsultantProfile &&
      situationFor(participant) == ParticipantSituation.pending;

  /// A avaliação deste aparelho para o participante — só as do consultor
  /// logado.
```

**por:**

```dart
      evaluationOpen &&
      hasConsultantProfile &&
      situationFor(participant) == ParticipantSituation.pending;

  /// O ⋮ do ADMIN (Fase 6B) aparece na linha de quem está em avaliação com
  /// outro consultor. Os participantes do próprio ADMIN continuam pelo ⋮ do
  /// checklist.
  bool showsAdminMenu(SessionParticipant participant) =>
      isAdmin && situationFor(participant) == ParticipantSituation.other;

  /// A avaliação deste aparelho para o participante — só as do consultor
  /// logado.
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart
    if (resync && !_disposed) unawaited(refresh());
  }

  /// "Iniciar sessão" — só o responsável ou um ADMIN chegam a ver o botão.
  Future<void> startSession() async {
    if (_isStarting || !canStartSession) return;
```

**por:**

```dart
    if (resync && !_disposed) unawaited(refresh());
  }

  /// "Desatribuir participante" pelo ⋮ do ADMIN: libera quem está em
  /// avaliação com outro consultor (o backend só aceita isso de um ADMIN). A
  /// linha muda na hora, e o detalhe é baixado de novo depois — no sucesso,
  /// para ficar com o estado oficial; na recusa, para mostrar o que mudou.
  Future<void> unassignAsAdmin(String participantId) async {
    final participant =
        _participants.where((p) => p.id == participantId).firstOrNull;
    if (participant == null ||
        !showsAdminMenu(participant) ||
        !adminActionsAllowed ||
        _unassigningParticipantId != null) {
      return;
    }

    _unassigningParticipantId = participantId;
    notifyListeners();

    var resync = false;
    try {
      final result = await _participantRepository.unassign(participantId);
      switch (result) {
        case Success():
          _message = '${participant.name} foi desatribuído.';
          resync = true;
        case Failure(:final exception, :final message):
          _message = message ?? _unassignFailed;
          // Sem rede, o re-sync falharia do mesmo jeito e só empilharia um
          // segundo aviso em cima deste.
          resync = exception is! ApiException || !exception.isNetworkError;
      }
    } catch (_) {
      _message = _unassignFailed;
    } finally {
      _unassigningParticipantId = null;
      notifyListeners();
    }

    // A tela pode ter sido fechada enquanto a resposta ainda viajava.
    if (resync && !_disposed) unawaited(refresh());
  }

  /// "Iniciar sessão" — só o responsável ou um ADMIN chegam a ver o botão.
  Future<void> startSession() async {
    if (_isStarting || !canStartSession) return;
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_detail`
Esperado: `+112: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+852: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/ui/session_detail/participant_row.dart \
  apps/mobile/simtc/lib/ui/session_detail/session_detail_screen.dart \
  apps/mobile/simtc/lib/ui/session_detail/session_detail_viewmodel.dart \
  apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart \
  apps/mobile/simtc/test/ui/session_detail/session_detail_viewmodel_test.dart
git commit -m "feat(mobile): admin desatribui participante pelo menu da linha"
```

---

## Task 11: A avaliação parada continua de onde parou

Com as Tasks 1 e 2, um participante pode sair das mãos do consultor com a avaliação pela metade. O rascunho fica no aparelho ("avaliação presa", da 6A). Faltava o que acontece quando o participante volta (decisão 8). Hoje, o checklist abre qualquer rascunho que encontrar — inclusive o de um participante que ainda não voltou para o consultor (o caminho do "Reavaliar"), o que deixaria avaliar sem reservar.

A regra: a avaliação que já existe só abre direto se o participante está com o consultor **e** nenhuma outra avaliação começou depois dela. Fora disso, ela espera: a tela é a de "não iniciada", dizendo quando a avaliação começou, com o botão "Continuar avaliação" — que reserva o participante, se preciso, e reabre a mesma avaliação, com as respostas e a hora de início de antes. Entre duas avaliações em andamento, vale a que começou por último.

E o outro lado: com o checklist aberto na hora em que o participante é liberado, o "Finalizar avaliação" desabilita, com o motivo — o servidor recusaria o envio (Task 3).

**Files:**
- Modify: `lib/ui/core/date_labels.dart`
- Modify: `lib/data/repositories/assessment_repository.dart`
- Modify: `lib/ui/checklist/checklist_viewmodel.dart`
- Modify: `lib/ui/checklist/checklist_screen.dart`
- Modify: `test/ui/core/date_labels_test.dart`
- Modify: `test/data/repositories/assessment_repository_test.dart`
- Modify: `test/ui/checklist/checklist_viewmodel_test.dart`
- Modify: `test/ui/checklist/checklist_screen_test.dart`

**Interfaces:**
- Consumes: `AssessmentRepository.findCurrent`, `findInProgressOther`, `openDraft`, `loadItems`, `discardDraft`; `ParticipantRepository.findParticipant`, `watchParticipant`, `assign`; `ChecklistViewModel._needsReservation`, `_reserve`, `_checkBlock`, `_attach`, `_detach`; `startedLabel`.
- Produces:
  - `String dayAndClockLabel(DateTime moment)` → "08/10 às 08:12"; o `offlineDataMessage` passa a usá-la.
  - `AssessmentRepository.findInProgressOther({..., DateTime? startedAfter})` — com ele, só conta o rascunho iniciado depois desse instante. `openDraft`, quando o rascunho do participante já existe, lança `EvaluationInProgressException` se outro, começado depois, ainda está em andamento.
  - `ChecklistViewModel`: `bool isResumable` (há uma avaliação parada, e a tela mostra o "Continuar avaliação"); `String? resumableStartedAt` ("08/10 às 08:12"); `bool isWithMe`; `bool isReleased` (o participante saiu das mãos do consultor com o checklist aberto); `canDiscard` passa a valer também para a avaliação parada; `startedText` também diz quando a avaliação parada começou; `start()` reabre a avaliação parada.

- [ ] **Step 1: Escrever os testes que falham**

**Em `test/data/repositories/assessment_repository_test.dart`, substituir:**

```dart
    String participantId, {
    String owner = 'user-1',
    String sessionId = 'sess-1',
  }) async {
    final id = 'draft-$participantId-$owner';
    await db.into(db.localAssessments).insert(
```

**por:**

```dart
    String participantId, {
    String owner = 'user-1',
    String sessionId = 'sess-1',
    DateTime? startTime,
  }) async {
    final id = 'draft-$participantId-$owner';
    await db.into(db.localAssessments).insert(
```

**Em `test/data/repositories/assessment_repository_test.dart`, substituir:**

```dart
            trainingParticipantId: participantId,
            sessionId: sessionId,
            date: DateTime(2026, 9, 29),
            startTime: DateTime(2026, 9, 29, 8),
            syncStatus: LocalSyncStatus.draft,
            createdAt: DateTime(2026, 9, 29, 8),
            updatedAt: DateTime(2026, 9, 29, 8),
```

**por:**

```dart
            trainingParticipantId: participantId,
            sessionId: sessionId,
            date: DateTime(2026, 9, 29),
            startTime: startTime ?? DateTime(2026, 9, 29, 8),
            syncStatus: LocalSyncStatus.draft,
            createdAt: DateTime(2026, 9, 29, 8),
            updatedAt: DateTime(2026, 9, 29, 8),
```

**Em `test/data/repositories/assessment_repository_test.dart`, substituir:**

```dart
        final rows = await db.select(db.localAssessments).get();
        expect(rows.map((r) => r.id), unorderedEquals([a.id, next.id]),
            reason: 'o preso continua guardado');
      });
    });
  });
```

**por:**

```dart
        final rows = await db.select(db.localAssessments).get();
        expect(rows.map((r) => r.id), unorderedEquals([a.id, next.id]),
            reason: 'o preso continua guardado');
      });
    });

    // O participante foi liberado com a avaliação pela metade, o consultor
    // começou outra, e o primeiro voltou para ele: são duas em andamento, e
    // vale a que começou por último (decisão de 09/10/2026).
    group('avaliação antiga que volta', () {
      late LocalAssessment old;
      late LocalAssessment recent;

      setUp(() async {
        await seedParticipant('tp-2');
        old = await insertDraft('tp-1', startTime: DateTime(2026, 9, 29, 8, 12));
        recent = await insertDraft('tp-2', startTime: DateTime(2026, 9, 29, 8, 30));
      });

      Future<LocalAssessment?> otherAfter(String except, DateTime startedAfter) {
        return repository.findInProgressOther(
          ownerUserId: 'user-1',
          consultantId: 'c-1',
          exceptTrainingParticipantId: except,
          startedAfter: startedAfter,
        );
      }

      test('só a avaliação que começou depois faz a outra esperar', () async {
        expect((await otherAfter('tp-1', old.startTime))?.id, recent.id);
        expect(await otherAfter('tp-2', recent.startTime), isNull);
      });

      test('sem o corte de horário, qualquer outra em andamento conta — é a '
          'regra de quem vai iniciar uma avaliação nova', () async {
        expect((await other('tp-1'))?.id, recent.id);
        expect((await other('tp-2'))?.id, old.id);
        // A que começou primeiro vem primeiro.
        expect((await other('tp-3'))?.id, old.id);
      });

      test('continuar a antiga é recusado enquanto a mais nova está em '
          'andamento, e nada muda', () async {
        await expectLater(
          open('tp-1'),
          throwsA(isA<EvaluationInProgressException>()
              .having((e) => e.trainingParticipantId, 'trainingParticipantId', 'tp-2')),
        );

        expect((await row(old.id)).startTime, old.startTime);
      });

      test('a mais nova continua abrindo, sem esperar pela antiga', () async {
        final again = await open('tp-2');

        expect(again.id, recent.id);
        expect(again.startTime, recent.startTime);
      });

      test('com a mais nova confirmada ou descartada, a antiga volta a abrir, '
          'com a mesma hora de início', () async {
        await repository.confirm(recent.id, participantName: 'B', score: 90);

        final again = await open('tp-1');

        expect(again.id, old.id);
        expect(again.startTime, old.startTime);
      });

      test('a mais nova que ficou presa não segura a antiga', () async {
        await (db.update(db.participants)..where((t) => t.id.equals('tp-2')))
            .write(const ParticipantsCompanion(
          status: Value('PENDENTE'),
          assignedConsultantId: Value(null),
        ));

        final again = await open('tp-1');

        expect(again.id, old.id);
      });

      test('avaliação na fila não espera ninguém: abre mesmo com outra mais '
          'nova em andamento', () async {
        await repository.confirm(old.id, participantName: 'A', score: 90);

        final again = await open('tp-1');

        expect(again.id, old.id);
        expect(again.syncStatus, LocalSyncStatus.pendingSync);
      });
    });
  });
```

**Em `test/ui/checklist/checklist_screen_test.dart`, substituir:**

```dart
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/summary/summary_screen.dart';
```

**por:**

```dart
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/inline_notice.dart';
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/summary/summary_screen.dart';
```

**Em `test/ui/checklist/checklist_screen_test.dart`, substituir:**

```dart
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  group('antes do "Iniciar avaliação"', () {
    testWidgets(
        'mostra o nome, "não iniciada" e o botão — sem a lista, sem "salvo" '
```

**por:**

```dart
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  // O participante saiu das mãos do consultor com a avaliação pela metade e
  // depois voltou: continua de onde parou (decisão de 09/10/2026).
  group('avaliação antiga que volta', () {
    const assignPath = '/practical-assessments/assign';
    const released =
        'Este participante não está mais com você. Atribua de novo para continuar.';

    /// A avaliação começada às 08:12 de 25/09, com a nota PM marcada.
    Future<void> seedOldDraft({String participantId = 'tp-1', int minute = 12}) async {
      final id = 'draft-$participantId';
      final at = DateTime(2026, 9, 25, 8, minute);
      await db.into(db.localAssessments).insert(
            LocalAssessmentsCompanion.insert(
              id: id,
              trainingParticipantId: participantId,
              sessionId: 'sess-1',
              date: DateTime(2026, 9, 25),
              startTime: at,
              syncStatus: LocalSyncStatus.draft,
              createdAt: at,
              updatedAt: at,
              ownerUserId: const Value('user-1'),
            ),
          );
      if (participantId == 'tp-1') {
        await assessmentRepository.mark(
          localAssessmentId: id,
          infractionId: 'inf-1',
          infractionNoteId: 'note-pm',
        );
      }
    }

    Future<void> setParticipant({required String status, String? consultant}) {
      return (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
          .write(
        ParticipantsCompanion(
          status: Value(status),
          assignedConsultantId: Value(consultant),
        ),
      );
    }

    AppCtaButton cta(WidgetTester tester, String label) =>
        tester.widget<AppCtaButton>(find.widgetWithText(AppCtaButton, label));

    testWidgets(
        'fora das mãos do consultor, a tela oferece continuar: diz quando '
        'começou e que as respostas voltam', (tester) async {
      await seedOldDraft();
      await setParticipant(status: 'NAO_RECOMENDADO');

      await pumpScreen(tester, started: false);

      expect(
        find.text('Você começou esta avaliação em 25/09 às 08:12.'),
        findsOneWidget,
      );
      expect(find.text('As respostas voltam ao continuar.'), findsOneWidget);
      expect(cta(tester, 'Continuar avaliação').onPressed, isNotNull);
      // No lugar do que a tela diz de quem nem começou.
      expect(find.text('A avaliação ainda não começou.'), findsNothing);
      expect(find.textContaining('A hora de início é registrada'), findsNothing);
      expect(find.text('Iniciar avaliação'), findsNothing);
      expect(find.text('não iniciada'), findsNothing);
      expect(find.textContaining('Iniciada em 25 set'), findsOneWidget);
      // Ainda é a tela de antes do checklist: sem as notas, sem "salvo".
      expect(find.byKey(const Key('checklist-not-started')), findsOneWidget);
      expect(find.text('O que será avaliado'), findsOneWidget);
      expect(find.text('PM'), findsNothing);
      expect(find.text('salvo'), findsNothing);
      expect(find.text('Finalizar avaliação'), findsNothing);
    });

    testWidgets(
        '"Continuar avaliação" reserva o participante e abre o checklist com '
        'as respostas de antes', (tester) async {
      await seedOldDraft();
      await setParticipant(status: 'NAO_RECOMENDADO');
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: assignPath),
          statusCode: 201,
          data: const {},
        ),
      );
      await pumpScreen(tester, started: false);

      await tester.tap(find.text('Continuar avaliação'));
      await tester.pumpAndSettle();

      verify(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .called(1);
      expect(find.text('Excesso de velocidade'), findsOneWidget);
      // A observação da nota PM só aparece com a nota marcada.
      expect(find.text(pmComment), findsOneWidget);
      expect(find.textContaining('Iniciada em 25 set'), findsOneWidget);
      expect(find.text('salvo'), findsOneWidget);
      expect(cta(tester, 'Finalizar avaliação').onPressed, isNotNull);
      expect(find.text(released), findsNothing);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });

    testWidgets('com a reserva demorando, o botão gira e o checklist ainda não '
        'abre', (tester) async {
      await seedOldDraft();
      await setParticipant(status: 'NAO_RECOMENDADO');
      final reply = Completer<Response<Map<String, dynamic>>>();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer((_) => reply.future);
      await pumpScreen(tester, started: false);

      await tester.tap(find.text('Continuar avaliação'));
      await tester.pump();
      // Um quadro no meio do envio.
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.widget<AppCtaButton>(find.byType(AppCtaButton)).isLoading, isTrue);
      expect(find.text('Excesso de velocidade'), findsNothing);
      expect(
        find.text('Você começou esta avaliação em 25/09 às 08:12.'),
        findsOneWidget,
      );

      reply.complete(
        Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: assignPath),
          statusCode: 201,
          data: const {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Excesso de velocidade'), findsOneWidget);
      expect(find.text(pmComment), findsOneWidget);
    });

    testWidgets(
        'com outra avaliação começada depois, o continuar fica travado, com o '
        'aviso de sempre', (tester) async {
      await seedOldDraft();
      await assignToMe();
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
      await seedOldDraft(participantId: 'tp-2', minute: 30);

      await pumpScreen(tester, started: false);

      expect(
        find.text('Você já está avaliando Marina Lopes. Finalize ou descarte '
            'essa avaliação para iniciar outra.'),
        findsOneWidget,
      );
      expect(cta(tester, 'Continuar avaliação').onPressed, isNull);
      expect(find.text('Excesso de velocidade'), findsNothing);
    });

    testWidgets(
        'o ⋮ oferece "Descartar avaliação" para começar limpo — sem dizer que '
        'o participante continua com você', (tester) async {
      await seedOldDraft();
      await setParticipant(status: 'PENDENTE');
      await pumpScreen(tester, started: false);

      await tester.tap(find.byKey(const Key('checklist-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar avaliação'));
      await tester.pumpAndSettle();

      expect(
        find.text('As marcações e a hora de início de Ana Paula Ribeiro serão '
            'apagadas.'),
        findsOneWidget,
      );
      expect(find.textContaining('continua com você'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('A avaliação ainda não começou.'), findsOneWidget);
      expect(find.text('não iniciada'), findsOneWidget);
      expect(cta(tester, 'Iniciar avaliação').onPressed, isNotNull);
      expect(find.text('Continuar avaliação'), findsNothing);
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    testWidgets(
        'participante liberado com o checklist aberto: o "Finalizar avaliação" '
        'desabilita, com o aviso — e volta quando ele é atribuído de novo',
        (tester) async {
      await assignToMe();
      await pumpScreen(tester);
      await tester.tap(find.text('PM'));
      await tester.pumpAndSettle();
      expect(cta(tester, 'Finalizar avaliação').onPressed, isNotNull);
      expect(find.text(released), findsNothing);

      // Um ADMIN desatribuiu, e o detalhe (embaixo) baixou a sessão de novo.
      await setParticipant(status: 'PENDENTE');
      await tester.pumpAndSettle();

      final notice = tester.widget<InlineNotice>(
        find.widgetWithText(InlineNotice, released),
      );
      expect(notice.tone, NoticeTone.warning);
      expect(cta(tester, 'Finalizar avaliação').onPressed, isNull);
      // As marcações continuam na tela.
      expect(find.text(pmComment), findsOneWidget);

      await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-eu');
      await tester.pumpAndSettle();

      expect(find.text(released), findsNothing);
      expect(cta(tester, 'Finalizar avaliação').onPressed, isNotNull);
    });

    testWidgets(
        'num celular de 360x640 com a fonte ampliada, a tela de continuar e o '
        'rodapé com o aviso de liberado não estouram', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await seedOldDraft();
      await setParticipant(status: 'PENDENTE');

      Future<void> pumpLarge() async {
        await tester.pumpWidget(withProviders(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const ChecklistScreen(sessionId: 'sess-1', participantId: 'tp-1'),
          ),
        ));
        await tester.pumpAndSettle();
      }

      await pumpLarge();
      expect(tester.takeException(), isNull);
      expect(find.text('Continuar avaliação'), findsOneWidget);
      expect(
        find.text('Você começou esta avaliação em 25/09 às 08:12.'),
        findsOneWidget,
      );

      // Agora com o checklist aberto e o participante liberado.
      await tester.pumpWidget(const SizedBox.shrink());
      await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-eu');
      await pumpLarge();
      await setParticipant(status: 'PENDENTE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(released), findsOneWidget);
      final footer = tester.getRect(find.widgetWithText(AppCtaButton, 'Finalizar avaliação'));
      expect(footer.bottom, lessThanOrEqualTo(640));
    });

    testWidgets(
        'desatribuir com a avaliação antiga à espera avisa que ela será '
        'descartada', (tester) async {
      await seedOldDraft();
      await assignToMe();
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
      await seedOldDraft(participantId: 'tp-2', minute: 30);
      await pumpScreen(tester, started: false);

      await tester.tap(find.byKey(const Key('checklist-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desatribuir participante'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('A avaliação iniciada será descartada.'),
        findsOneWidget,
      );
    });
  });

  group('antes do "Iniciar avaliação"', () {
    testWidgets(
        'mostra o nome, "não iniciada" e o botão — sem a lista, sem "salvo" '
```

**Em `test/ui/checklist/checklist_viewmodel_test.dart`, substituir:**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
```

**por:**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
```

**Em `test/ui/checklist/checklist_viewmodel_test.dart`, substituir:**

```dart
import 'package:simtc/ui/checklist/checklist_viewmodel.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;
```

**por:**

```dart
import 'package:simtc/ui/checklist/checklist_viewmodel.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// O participante só chega pelo stream quando o teste mandar: no aparelho, o
/// stream pode entregar depois de a tela já ter lido a avaliação do banco.
class _LateStreamParticipantRepository extends ParticipantRepository {
  _LateStreamParticipantRepository({
    required super.apiClient,
    required super.database,
  });

  final StreamController<SessionParticipant?> late =
      StreamController<SessionParticipant?>();

  @override
  Stream<SessionParticipant?> watchParticipant(String participantId) =>
      late.stream;
}

void main() {
  late _MockApiClient api;
```

**Em `test/ui/checklist/checklist_viewmodel_test.dart`, substituir:**

```dart
    });
  });

  group('descartar', () {
    test(
        'descartar apaga o rascunho e volta a "não iniciada" — e o "Iniciar" '
```

**por:**

```dart
    });
  });

  // O participante saiu das mãos do consultor com a avaliação pela metade
  // (um ADMIN o desatribuiu, ou o consultor foi tirado da sessão) e depois
  // voltou: continua de onde parou (decisão de 09/10/2026).
  group('avaliação antiga que volta', () {
    const assignPath = '/practical-assessments/assign';
    const detailPath = '/training-sessions/sess-1';

    Response<Map<String, dynamic>> ok(String path) {
      return Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: path),
        statusCode: 201,
        data: const {},
      );
    }

    /// A avaliação começada às 08:12 de 25/09, com a nota PM marcada.
    Future<LocalAssessment> seedOldDraft({String participantId = 'tp-1'}) async {
      final id = 'draft-$participantId';
      final at = DateTime(2026, 9, 25, 8, 12);
      await db.into(db.localAssessments).insert(
            LocalAssessmentsCompanion.insert(
              id: id,
              trainingParticipantId: participantId,
              sessionId: 'sess-1',
              date: DateTime(2026, 9, 25),
              startTime: at,
              syncStatus: LocalSyncStatus.draft,
              createdAt: at,
              updatedAt: at,
              ownerUserId: const Value('user-1'),
            ),
          );
      await assessmentRepository.mark(
        localAssessmentId: id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-pm',
      );
      return (db.select(db.localAssessments)..where((t) => t.id.equals(id)))
          .getSingle();
    }

    /// Outro participante do mesmo consultor, com a avaliação começada às
    /// 08:30 — depois da antiga.
    Future<void> seedNewerDraft() async {
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
      final at = DateTime(2026, 9, 25, 8, 30);
      await db.into(db.localAssessments).insert(
            LocalAssessmentsCompanion.insert(
              id: 'draft-tp-2',
              trainingParticipantId: 'tp-2',
              sessionId: 'sess-1',
              date: DateTime(2026, 9, 25),
              startTime: at,
              syncStatus: LocalSyncStatus.draft,
              createdAt: at,
              updatedAt: at,
              ownerUserId: const Value('user-1'),
            ),
          );
    }

    Future<void> setParticipant({required String status, String? consultant}) {
      return (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
          .write(
        ParticipantsCompanion(
          status: Value(status),
          assignedConsultantId: Value(consultant),
        ),
      );
    }

    Future<ChecklistViewModel> open() async {
      final vm = buildViewModel(now: () => DateTime(2026, 9, 26, 9));
      addTearDown(vm.dispose);
      await vm.init();
      return vm;
    }

    test('de volta com o consultor (pela linha): abre direto na avaliação '
        'antiga, com as respostas e a hora de início', () async {
      await seedParticipant(assignedConsultantId: 'c-eu');
      await seedCatalog();
      await seedOldDraft();

      final vm = await open();

      expect(vm.isStarted, isTrue);
      expect(vm.isResumable, isFalse);
      expect(vm.isReleased, isFalse);
      expect(vm.startedText, 'Iniciada em 25 set 08:12');
      expect(vm.sections.single.infractions.single.selectedNoteId, 'note-pm');
      expect(vm.expandedCategoryId, 'cat-1');
    });

    for (final (status, consultant, why) in const [
      ('NAO_RECOMENDADO', null, 'chegou pelo "Reavaliar"'),
      ('PENDENTE', null, 'foi liberado'),
      ('EM_AVALIACAO', 'c-outro', 'está com outro consultor'),
    ]) {
      test('ainda fora das mãos do consultor ($why): a tela oferece continuar, '
          'sem abrir as respostas', () async {
        await seedParticipant(status: status, assignedConsultantId: consultant);
        await seedCatalog();
        await seedOldDraft();

        final vm = await open();

        expect(vm.isLoading, isFalse);
        expect(vm.isStarted, isFalse);
        expect(vm.isResumable, isTrue);
        expect(vm.isBlocked, isFalse);
        expect(vm.resumableStartedAt, '25/09 às 08:12');
        expect(vm.startedText, 'Iniciada em 25 set 08:12');
        expect(vm.isWithMe, isFalse);
        // As respostas só voltam ao continuar.
        expect(vm.sections.single.infractions.single.selectedNoteId, isNull);
        expect(vm.expandedCategoryId, isNull);
        verifyNever(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')));
      });
    }

    test('a decisão de esperar não depende de o stream do participante já '
        'ter entregado', () async {
      await seedParticipant(status: 'PENDENTE');
      await seedCatalog();
      await seedOldDraft();
      final slow = _LateStreamParticipantRepository(apiClient: api, database: db);
      addTearDown(slow.late.close);
      final vm = ChecklistViewModel(
        sessionId: 'sess-1',
        participantId: 'tp-1',
        ownerUserId: 'user-1',
        consultantId: 'c-eu',
        consultantName: 'Carla Souza',
        assessmentRepository: assessmentRepository,
        participantRepository: slow,
        catalogRepository: catalogRepository,
      );
      addTearDown(vm.dispose);

      await vm.init();

      expect(vm.isResumable, isTrue);
      expect(vm.isStarted, isFalse);
      expect(vm.participant?.name, 'Carlos Eduardo Nunes');
    });

    test('depois de reservar, a tela já sabe que o participante está com o '
        'consultor, sem esperar o stream', () async {
      await seedParticipant(status: 'NAO_RECOMENDADO');
      await seedCatalog();
      await seedOldDraft();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer((_) async => ok(assignPath));
      final slow = _LateStreamParticipantRepository(apiClient: api, database: db);
      addTearDown(slow.late.close);
      final vm = ChecklistViewModel(
        sessionId: 'sess-1',
        participantId: 'tp-1',
        ownerUserId: 'user-1',
        consultantId: 'c-eu',
        consultantName: 'Carla Souza',
        assessmentRepository: assessmentRepository,
        participantRepository: slow,
        catalogRepository: catalogRepository,
      );
      addTearDown(vm.dispose);
      await vm.init();

      await vm.start();

      expect(vm.isStarted, isTrue);
      expect(vm.isReleased, isFalse);
      expect(vm.isWithMe, isTrue);
    });

    test('"Continuar avaliação" reserva o participante e reabre a antiga: a '
        'mesma hora de início, as mesmas respostas, nenhuma avaliação nova',
        () async {
      await seedParticipant(status: 'NAO_RECOMENDADO');
      await seedCatalog();
      final old = await seedOldDraft();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer((_) async => ok(assignPath));
      final vm = await open();

      await vm.start();

      final sent = verify(
        () => api.post<Map<String, dynamic>>(assignPath, data: captureAny(named: 'data')),
      ).captured.single;
      expect(sent, {
        'participantIds': ['tp-1'],
      });
      expect(vm.isStarted, isTrue);
      expect(vm.isResumable, isFalse);
      expect(vm.resumableStartedAt, isNull, reason: 'não está mais parada');
      // Já no fim do toque: a tela não acusa "não está mais com você".
      expect(vm.isReleased, isFalse);
      expect(vm.isWithMe, isTrue);
      expect(vm.message, isNull);
      expect(vm.expandedCategoryId, 'cat-1');
      expect(vm.sections.single.infractions.single.selectedNoteId, 'note-pm');
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.id), [old.id]);
      expect(rows.single.startTime, old.startTime);
    });

    test('sem rede, o continuar não reabre: avisa, e a avaliação antiga '
        'continua guardada', () async {
      await seedParticipant(status: 'NAO_RECOMENDADO');
      await seedCatalog();
      final old = await seedOldDraft();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        isNetworkError: true,
      ));
      final vm = await open();

      await vm.start();

      expect(vm.isStarted, isFalse);
      expect(vm.isResumable, isTrue);
      expect(
        vm.message,
        'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      );
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.id), [old.id]);
      expect(await assessmentRepository.loadItems(old.id), hasLength(1));
    });

    test('recusado (409, outro consultor ficou com ele): avisa, baixa a '
        'sessão, e a avaliação antiga continua guardada', () async {
      await seedParticipant(status: 'NAO_RECOMENDADO');
      await seedCatalog();
      final old = await seedOldDraft();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Um ou mais participantes já estão em avaliação com outro consultor',
        statusCode: 409,
      ));
      when(() => api.get<Map<String, dynamic>>(detailPath))
          .thenThrow(const ApiException(message: 'x', statusCode: 500));
      final vm = await open();

      await vm.start();
      await pumpEventQueue();

      expect(vm.isStarted, isFalse);
      expect(vm.isResumable, isTrue);
      expect(
        vm.message,
        'Um ou mais participantes já estão em avaliação com outro consultor',
      );
      verify(() => api.get<Map<String, dynamic>>(detailPath)).called(1);
      expect((await db.select(db.localAssessments).get()).map((r) => r.id), [old.id]);
    });

    group('uma por vez', () {
      test('com outra avaliação começada depois, a antiga espera — mesmo com '
          'o participante de volta', () async {
        await seedParticipant(assignedConsultantId: 'c-eu');
        await seedCatalog();
        await seedOldDraft();
        await seedNewerDraft();

        final vm = await open();

        expect(vm.isStarted, isFalse);
        expect(vm.isResumable, isTrue);
        expect(vm.isBlocked, isTrue);
        expect(vm.blockingParticipantName, 'Marina Lopes');
        expect(vm.isWithMe, isTrue);

        await vm.start();

        expect(vm.isStarted, isFalse);
        verifyNever(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')));
      });

      test('a avaliação mais nova abre sem esperar pela antiga', () async {
        await seedParticipant(assignedConsultantId: 'c-eu');
        await seedCatalog();
        await seedOldDraft();
        await seedNewerDraft();
        final vm = ChecklistViewModel(
          sessionId: 'sess-1',
          participantId: 'tp-2',
          ownerUserId: 'user-1',
          consultantId: 'c-eu',
          consultantName: 'Carla Souza',
          assessmentRepository: assessmentRepository,
          participantRepository: participantRepository,
          catalogRepository: catalogRepository,
        );
        addTearDown(vm.dispose);

        await vm.init();

        expect(vm.isStarted, isTrue);
        expect(vm.isResumable, isFalse);
        expect(vm.isBlocked, isFalse);
      });

      test('com a outra confirmada, a antiga volta a abrir direto', () async {
        await seedParticipant(assignedConsultantId: 'c-eu');
        await seedCatalog();
        await seedOldDraft();
        await seedNewerDraft();
        await assessmentRepository.confirm(
          'draft-tp-2',
          participantName: 'Marina Lopes',
          score: 90,
        );

        final vm = await open();

        expect(vm.isStarted, isTrue);
        expect(vm.isBlocked, isFalse);
        expect(vm.sections.single.infractions.single.selectedNoteId, 'note-pm');
      });

      test('fora das mãos do consultor e com outra em andamento: o continuar '
          'fica travado, sem reservar ninguém', () async {
        await seedParticipant(status: 'NAO_RECOMENDADO');
        await seedCatalog();
        await seedOldDraft();
        await seedNewerDraft();

        final vm = await open();
        expect(vm.isResumable, isTrue);
        expect(vm.isBlocked, isTrue);

        await vm.start();

        expect(vm.isStarted, isFalse);
        verifyNever(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')));
      });

      test('se a outra começou depois de a tela abrir, o continuar é recusado '
          'e a tela passa a avisar', () async {
        await seedParticipant(assignedConsultantId: 'c-eu');
        await seedCatalog();
        await seedOldDraft();
        // Na abertura, a antiga espera por estar fora das mãos do consultor.
        await setParticipant(status: 'PENDENTE');
        final vm = await open();
        expect(vm.isResumable, isTrue);
        expect(vm.isBlocked, isFalse);
        // O participante volta, e outra avaliação começa nesse meio-tempo.
        await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-eu');
        await seedNewerDraft();
        await pumpEventQueue();

        await vm.start();

        expect(vm.isStarted, isFalse);
        expect(vm.isBlocked, isTrue);
        expect(vm.blockingParticipantName, 'Marina Lopes');
      });
    });

    test('descartar a avaliação antiga começa limpo: some o continuar, e o '
        '"Iniciar avaliação" volta a valer', () async {
      await seedParticipant(status: 'PENDENTE');
      await seedCatalog();
      final old = await seedOldDraft();
      final vm = await open();
      expect(vm.canDiscard, isTrue);

      await vm.discard();

      expect(vm.isResumable, isFalse);
      expect(vm.canDiscard, isFalse);
      expect(vm.resumableStartedAt, isNull);
      expect(vm.startedText, isNull);
      expect(await db.select(db.localAssessments).get(), isEmpty);
      expect(await assessmentRepository.loadItems(old.id), isEmpty);
    });

    test('avaliação já confirmada não vira "continuar", mesmo com o '
        'participante fora das mãos do consultor', () async {
      await seedParticipant(status: 'PENDENTE');
      await seedCatalog();
      final old = await seedOldDraft();
      await assessmentRepository.confirm(old.id, participantName: 'Carlos', score: 80);

      final vm = await open();

      expect(vm.isStarted, isTrue);
      expect(vm.isConfirmed, isTrue);
      expect(vm.isResumable, isFalse);
      expect(vm.isReleased, isFalse);
    });

    test('participante liberado com o checklist aberto: não dá mais para '
        'finalizar — e volta a dar quando ele é atribuído de novo', () async {
      await seedParticipant(assignedConsultantId: 'c-eu');
      await seedCatalog();
      await seedOldDraft();
      final vm = await open();
      expect(vm.isReleased, isFalse);

      await setParticipant(status: 'PENDENTE');
      await pumpEventQueue();

      expect(vm.isStarted, isTrue, reason: 'as marcações continuam na tela');
      expect(vm.isReleased, isTrue);
      expect(vm.isWithMe, isFalse);

      await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-outro');
      await pumpEventQueue();
      expect(vm.isReleased, isTrue, reason: 'com outro consultor');

      await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-eu');
      await pumpEventQueue();
      expect(vm.isReleased, isFalse);
    });

    test('desatribuir com a avaliação antiga à espera também a apaga',
        () async {
      await seedParticipant(assignedConsultantId: 'c-eu');
      await seedCatalog();
      await seedOldDraft();
      await seedNewerDraft();
      when(() => api.post<Map<String, dynamic>>(
            '/practical-assessments/unassign',
            data: any(named: 'data'),
          )).thenAnswer((_) async => ok('/practical-assessments/unassign'));
      final vm = await open();
      expect(vm.isResumable, isTrue);
      expect(vm.canUnassign, isTrue);

      final released = await vm.unassign();

      expect(released, isTrue);
      expect(vm.isResumable, isFalse);
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.trainingParticipantId), ['tp-2']);
    });
  });

  group('descartar', () {
    test(
        'descartar apaga o rascunho e volta a "não iniciada" — e o "Iniciar" '
```

**Em `test/ui/core/date_labels_test.dart`, substituir:**

```dart
    expect(startedLabel(DateTime(2026, 9, 23, 8, 12), agora), 'Iniciada às 08:12');
    expect(startedLabel(DateTime(2026, 9, 22, 8, 12), agora), 'Iniciada em 22 set 08:12');
  });
}
```

**por:**

```dart
    expect(startedLabel(DateTime(2026, 9, 23, 8, 12), agora), 'Iniciada às 08:12');
    expect(startedLabel(DateTime(2026, 9, 22, 8, 12), agora), 'Iniciada em 22 set 08:12');
  });

  test('dayAndClockLabel diz o dia, o mês e a hora, com dois dígitos', () {
    expect(dayAndClockLabel(DateTime(2026, 10, 8, 8, 12)), '08/10 às 08:12');
    expect(dayAndClockLabel(DateTime(2026, 1, 25, 17, 5)), '25/01 às 17:05');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/date_labels_test.dart test/data/repositories/assessment_repository_test.dart test/ui/checklist`
Esperado: não compilam — `Method not found: 'dayAndClockLabel'`, `No named parameter with the name 'startedAfter'` e `The getter 'isResumable' isn't defined for the type 'ChecklistViewModel'` (e `isReleased`, `isWithMe`, `resumableStartedAt`); no teste da tela, os testes novos não acham "Continuar avaliação" nem o aviso de liberado.

- [ ] **Step 3: Implementar**

**Em `lib/data/repositories/assessment_repository.dart`, substituir:**

```dart
  /// [consultantId] é o `Consultant.id` de [ownerUserId]: é com ele que a
  /// atribuição do participante é conferida. Sem perfil de consultor (nulo),
  /// nenhum participante está com o usuário, e nada bloqueia.
  Future<LocalAssessment?> findInProgressOther({
    required String ownerUserId,
    required String? consultantId,
    required String exceptTrainingParticipantId,
  }) async {
    if (consultantId == null) return null;
```

**por:**

```dart
  /// [consultantId] é o `Consultant.id` de [ownerUserId]: é com ele que a
  /// atribuição do participante é conferida. Sem perfil de consultor (nulo),
  /// nenhum participante está com o usuário, e nada bloqueia.
  ///
  /// Com [startedAfter], só conta o rascunho iniciado depois desse instante.
  /// É a regra de quem volta a uma avaliação antiga (Fase 6B): o participante
  /// foi liberado com ela pela metade, o consultor começou outra, e o
  /// primeiro voltou para ele. Entre duas em andamento, vale a que começou
  /// por último — a antiga espera.
  Future<LocalAssessment?> findInProgressOther({
    required String ownerUserId,
    required String? consultantId,
    required String exceptTrainingParticipantId,
    DateTime? startedAfter,
  }) async {
    if (consultantId == null) return null;
```

**Em `lib/data/repositories/assessment_repository.dart`, substituir:**

```dart
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .get();
    for (final draft in drafts) {
      if (await _canStillOpen(draft, consultantId)) return draft;
    }
    return null;
```

**por:**

```dart
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .get();
    for (final draft in drafts) {
      if (startedAfter != null && !draft.startTime.isAfter(startedAfter)) {
        continue;
      }
      if (await _canStillOpen(draft, consultantId)) return draft;
    }
    return null;
```

**Em `lib/data/repositories/assessment_repository.dart`, substituir:**

```dart
  /// "Iniciar avaliação": cria o rascunho de [ownerUserId] com `startTime`
  /// agora — a hora de início mostrada e enviada vem daqui. Se a
  /// avaliação já está em andamento ([findCurrent]), devolve a mesma, sem
  /// recomeçar: um segundo toque não muda a hora de início.
  ///
  /// Só uma avaliação em andamento por consultor, em todas as sessões: se
  /// [ownerUserId] já tem um rascunho com outro participante — e ainda
  /// consegue abri-lo ([findInProgressOther], que confere a atribuição com
  /// [consultantId]) —, lança [EvaluationInProgressException] e não grava
  /// nada.
  ///
  /// `date` é a data de calendário da sessão (como `TrainingSession.date`,
  /// meia-noite local); sessão sem data, ou fora do cache, usa a de hoje.
```

**por:**

```dart
  /// "Iniciar avaliação": cria o rascunho de [ownerUserId] com `startTime`
  /// agora — a hora de início mostrada e enviada vem daqui. Se a
  /// avaliação já está em andamento ([findCurrent]), devolve a mesma, sem
  /// recomeçar: um segundo toque não muda a hora de início — e é assim que
  /// uma avaliação antiga continua de onde parou (Fase 6B).
  ///
  /// Só uma avaliação em andamento por consultor, em todas as sessões: se
  /// [ownerUserId] já tem um rascunho com outro participante — e ainda
  /// consegue abri-lo ([findInProgressOther], que confere a atribuição com
  /// [consultantId]) —, lança [EvaluationInProgressException] e não grava
  /// nada. Para o rascunho que já existia, só conta o outro que começou
  /// depois dele.
  ///
  /// `date` é a data de calendário da sessão (como `TrainingSession.date`,
  /// meia-noite local); sessão sem data, ou fora do cache, usa a de hoje.
```

**Em `lib/data/repositories/assessment_repository.dart`, substituir:**

```dart
      trainingParticipantId: trainingParticipantId,
      ownerUserId: ownerUserId,
    );
    if (current != null) return current;

    final existing = await findByParticipant(trainingParticipantId);
    final session = await (_db.select(_db.sessions)
```

**por:**

```dart
      trainingParticipantId: trainingParticipantId,
      ownerUserId: ownerUserId,
    );
    if (current != null) {
      // A avaliação confirmada não espera ninguém: é só leitura.
      if (current.syncStatus == LocalSyncStatus.draft) {
        final newer = await findInProgressOther(
          ownerUserId: ownerUserId,
          consultantId: consultantId,
          exceptTrainingParticipantId: trainingParticipantId,
          startedAfter: current.startTime,
        );
        if (newer != null) {
          throw EvaluationInProgressException(newer.trainingParticipantId);
        }
      }
      return current;
    }

    final existing = await findByParticipant(trainingParticipantId);
    final session = await (_db.select(_db.sessions)
```

**Em `lib/ui/checklist/checklist_screen.dart`, substituir:**

```dart
    final status = participant?.hasPreviousAssessment == true
        ? 'Não recomendado'
        : 'Pendente';
    final discardNote =
        _viewModel.isStarted ? ' A avaliação iniciada será descartada.' : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
```

**por:**

```dart
    final status = participant?.hasPreviousAssessment == true
        ? 'Não recomendado'
        : 'Pendente';
    final discardNote = _viewModel.isStarted || _viewModel.isResumable
        ? ' A avaliação iniciada será descartada.'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
```

**Em `lib/ui/checklist/checklist_screen.dart`, substituir:**

```dart
    final name = _viewModel.participant?.name;
    // "de Ana Paula Ribeiro" ou, sem o nome no aparelho, "deste participante".
    final whose = name == null ? 'deste participante' : 'de $name';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar a avaliação?'),
        content: Text(
          'As marcações e a hora de início $whose serão apagadas. O '
          'participante continua com você.',
        ),
        actions: [
          TextButton(
```

**por:**

```dart
    final name = _viewModel.participant?.name;
    // "de Ana Paula Ribeiro" ou, sem o nome no aparelho, "deste participante".
    final whose = name == null ? 'deste participante' : 'de $name';
    // A avaliação parada pode ser de quem já não está com o consultor.
    final stays =
        _viewModel.isWithMe ? ' O participante continua com você.' : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar a avaliação?'),
        content: Text(
          'As marcações e a hora de início $whose serão apagadas.$stays',
        ),
        actions: [
          TextButton(
```

**Em `lib/ui/checklist/checklist_screen.dart`, substituir:**

```dart
        children: [
          const Icon(AppIcons.timer, size: 14, color: AppColors.text3),
          const SizedBox(width: AppSpacing.xs),
          Text('não iniciada', style: AppTypography.meta),
        ],
      );
    }
```

**por:**

```dart
        children: [
          const Icon(AppIcons.timer, size: 14, color: AppColors.text3),
          const SizedBox(width: AppSpacing.xs),
          // A avaliação parada (Fase 6B) já tem hora de início.
          Flexible(
            child: Text(
              _viewModel.isResumable
                  ? _viewModel.startedText ?? ''
                  : 'não iniciada',
              style: AppTypography.meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
```

**Em `lib/ui/checklist/checklist_screen.dart`, substituir:**

```dart
            AppSpacing.sm + 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('O que será avaliado', style: AppTypography.sectionTitle),
              Text(_itemsLabel(items), style: AppTypography.categoryCount),
            ],
          ),
```

**por:**

```dart
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
```

**Em `lib/ui/checklist/checklist_screen.dart`, substituir:**

```dart
    );
  }

  Widget _buildNotStartedHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
```

**por:**

```dart
    );
  }

  /// Com uma avaliação parada (decisão de 09/10/2026), o bloco diz quando
  /// ela começou, e o botão do rodapé vira "Continuar avaliação".
  Widget _buildNotStartedHero() {
    final startedAt = _viewModel.resumableStartedAt;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
```

**Em `lib/ui/checklist/checklist_screen.dart`, substituir:**

```dart
          const Icon(AppIcons.timer, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm + 6),
          Text(
            'A avaliação ainda não começou.',
            style: AppTypography.notStartedTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A hora de início é registrada quando você tocar em "Iniciar avaliação".',
            style: AppTypography.notStartedBody,
            textAlign: TextAlign.center,
          ),
```

**por:**

```dart
          const Icon(AppIcons.timer, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm + 6),
          Text(
            startedAt == null
                ? 'A avaliação ainda não começou.'
                : 'Você começou esta avaliação em $startedAt.',
            style: AppTypography.notStartedTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            startedAt == null
                ? 'A hora de início é registrada quando você tocar em '
                    '"Iniciar avaliação".'
                : 'As respostas voltam ao continuar.',
            style: AppTypography.notStartedBody,
            textAlign: TextAlign.center,
          ),
```

**Em `lib/ui/checklist/checklist_screen.dart`, substituir:**

```dart
        AppSpacing.lg,
      ),
      child: _viewModel.isStarted
          ? AppCtaButton(
              label: 'Finalizar avaliação',
              icon: AppIcons.finish,
              size: AppCtaSize.large,
              onPressed: _isBusy ? null : _openSummary,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
```

**por:**

```dart
        AppSpacing.lg,
      ),
      child: _viewModel.isStarted
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // O participante saiu das mãos do consultor com o checklist
                // aberto: o servidor recusaria o envio (decisão de
                // 09/10/2026). As marcações ficam.
                if (_viewModel.isReleased) ...[
                  const InlineNotice(
                    icon: AppIcons.lockedByOther,
                    tone: NoticeTone.warning,
                    message: 'Este participante não está mais com você. '
                        'Atribua de novo para continuar.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppCtaButton(
                  label: 'Finalizar avaliação',
                  icon: AppIcons.finish,
                  size: AppCtaSize.large,
                  onPressed: _isBusy || _viewModel.isReleased
                      ? null
                      : _openSummary,
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
```

**Em `lib/ui/checklist/checklist_screen.dart`, substituir:**

```dart
                  const SizedBox(height: AppSpacing.md),
                ],
                AppCtaButton(
                  label: 'Iniciar avaliação',
                  icon: AppIcons.startEvaluation,
                  size: AppCtaSize.large,
                  isLoading: _viewModel.isStarting,
```

**por:**

```dart
                  const SizedBox(height: AppSpacing.md),
                ],
                AppCtaButton(
                  label: _viewModel.isResumable
                      ? 'Continuar avaliação'
                      : 'Iniciar avaliação',
                  icon: AppIcons.startEvaluation,
                  size: AppCtaSize.large,
                  isLoading: _viewModel.isStarting,
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
/// que reserva o participante, e no "Desatribuir participante" ([unassign]),
/// que libera a reserva. Se ele recusar um ou outro, a sessão é baixada de
/// novo.
class ChecklistViewModel extends ChangeNotifier {
  ChecklistViewModel({
    required this.sessionId,
```

**por:**

```dart
/// que reserva o participante, e no "Desatribuir participante" ([unassign]),
/// que libera a reserva. Se ele recusar um ou outro, a sessão é baixada de
/// novo.
///
/// Uma avaliação que ficou parada (Fase 6B) — o participante saiu das mãos do
/// consultor com ela pela metade — não abre sozinha: a tela oferece o
/// "Continuar avaliação" ([isResumable]), e é o [start] que a reabre, com as
/// respostas e a hora de início de antes.
class ChecklistViewModel extends ChangeNotifier {
  ChecklistViewModel({
    required this.sessionId,
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
  String? _assessmentId;
  DateTime? _startTime;
  LocalSyncStatus? _status;
  String? _message;
  SessionParticipant? _participant;
  List<CatalogCategory> _catalog = const [];
```

**por:**

```dart
  String? _assessmentId;
  DateTime? _startTime;
  LocalSyncStatus? _status;

  /// A avaliação deste participante que ficou parada e ainda não foi
  /// reaberta: ver [isResumable].
  LocalAssessment? _resumable;
  String? _message;
  SessionParticipant? _participant;
  List<CatalogCategory> _catalog = const [];
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
  /// outro caminho.
  bool get isConfirmed => _status != null && _status != LocalSyncStatus.draft;

  /// "Descartar avaliação" do menu ⋮: só com a avaliação iniciada e ainda em
  /// rascunho.
  bool get canDiscard => isStarted && !isConfirmed;

  /// O "Descartar avaliação" está apagando.
  bool get isDiscarding => _discarding;
```

**por:**

```dart
  /// outro caminho.
  bool get isConfirmed => _status != null && _status != LocalSyncStatus.draft;

  /// Há uma avaliação deste participante começada antes e que ficou parada
  /// (decisão de 09/10/2026): ele saiu das mãos do consultor com ela pela
  /// metade, ou outra avaliação começou depois dela. A tela mostra o
  /// "Continuar avaliação" no lugar do checklist; as respostas e a hora de
  /// início voltam quando o consultor continuar.
  bool get isResumable => !isStarted && _resumable != null;

  /// "08/10 às 08:12": quando a avaliação parada começou.
  String? get resumableStartedAt {
    final resumable = _resumable;
    return resumable == null ? null : dayAndClockLabel(resumable.startTime);
  }

  /// O participante está com o consultor logado — ou a linha não diz com
  /// quem, e vale o que o servidor disse por último.
  bool get isWithMe => !_needsReservation;

  /// O participante saiu das mãos do consultor com o checklist aberto (um
  /// ADMIN o desatribuiu, ou o consultor foi tirado da sessão): as marcações
  /// ficam, mas não dá para finalizar — o servidor recusaria o envio. Quando
  /// ele for atribuído de novo, a avaliação continua de onde parou.
  bool get isReleased => isStarted && !isConfirmed && _needsReservation;

  /// "Descartar avaliação" do menu ⋮: com a avaliação iniciada e ainda em
  /// rascunho — ou parada, para quem prefere começar limpo.
  bool get canDiscard => (isStarted && !isConfirmed) || isResumable;

  /// O "Descartar avaliação" está apagando.
  bool get isDiscarding => _discarding;
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
  bool get hasCatalog => sections.isNotEmpty;

  /// "Iniciada às 08:12" — a hora do "Iniciar avaliação"; nula antes dele.
  /// Não há cronômetro: o app só registra quando começou (30/09/2026).
  String? get startedText {
    final start = _startTime;
    return start == null ? null : startedLabel(start, _now());
  }
```

**por:**

```dart
  bool get hasCatalog => sections.isNotEmpty;

  /// "Iniciada às 08:12" — a hora do "Iniciar avaliação"; nula antes dele.
  /// Não há cronômetro: o app só registra quando começou (30/09/2026). A
  /// avaliação parada também diz quando começou.
  String? get startedText {
    final start = _startTime ?? _resumable?.startTime;
    return start == null ? null : startedLabel(start, _now());
  }
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
    if (_disposed) return;
    // As marcações primeiro: o stream as entrega enquanto o catálogo carrega,
    // e a tela já abre com elas.
    if (current != null) {
      _attach(current);
    } else {
      await _checkBlock();
      if (_disposed) return;
    }

    _catalog = await _catalogRepository.loadCatalog();
    if (_disposed) return;
    if (current != null) _openFirstCategory();

    _loading = false;
    notifyListeners();
  }

  /// O participante ainda não está reservado para este consultor: é o caso
```

**por:**

```dart
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
  }

  /// Uma avaliação que já existe só abre direto se nada mudou enquanto ela
  /// esteve fechada. Ela espera — e a tela mostra o "Continuar avaliação" —
  /// se o participante saiu das mãos do consultor, ou se outra avaliação
  /// começou depois dela: só uma por vez, e vale a mais nova. A avaliação já
  /// confirmada não espera nada: é só leitura.
  Future<bool> _waits(LocalAssessment current) async {
    if (current.syncStatus != LocalSyncStatus.draft) return false;
    // O stream do participante pode ainda não ter entregado nada.
    _participant = await _participantRepository.findParticipant(participantId);
    await _checkBlock(startedAfter: current.startTime);
    return _needsReservation || _blockingParticipantId != null;
  }

  /// O participante ainda não está reservado para este consultor: é o caso
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
    _starting = true;
    notifyListeners();
    try {
      if (_needsReservation && !await _reserve()) return;
      if (_disposed) return;
      final assessment = await _assessmentRepository.openDraft(
        trainingParticipantId: participantId,
        sessionId: sessionId,
```

**por:**

```dart
    _starting = true;
    notifyListeners();
    try {
      if (_needsReservation) {
        if (!await _reserve()) return;
        // A linha já mudou no banco, mas o stream só avisa no próximo turno:
        // até lá a tela acharia que o participante ainda não está com o
        // consultor.
        _participant =
            await _participantRepository.findParticipant(participantId) ??
                _participant;
      }
      if (_disposed) return;
      // Com uma avaliação parada, devolve a mesma: as respostas e a hora de
      // início de antes.
      final assessment = await _assessmentRepository.openDraft(
        trainingParticipantId: participantId,
        sessionId: sessionId,
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
        consultantId: consultantId,
      );
      if (_disposed) return;
      _attach(assessment);
      _openFirstCategory();
    } on EvaluationInProgressException catch (e) {
      // Outro participante começou depois de a tela abrir.
```

**por:**

```dart
        consultantId: consultantId,
      );
      if (_disposed) return;
      _resumable = null;
      _attach(assessment);
      // As respostas de uma avaliação parada voltam junto com a tela, sem
      // esperar o stream entregar.
      _items = await _assessmentRepository.loadItems(assessment.id);
      if (_disposed) return;
      _openFirstCategory();
    } on EvaluationInProgressException catch (e) {
      // Outro participante começou depois de a tela abrir.
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
  /// marcações, e a tela volta a "não iniciada" — o participante continua com
  /// o consultor. A tela pede confirmação antes.
  Future<void> discard() async {
    final assessmentId = _assessmentId;
    if (assessmentId == null || !canDiscard || _busy) return;

    _discarding = true;
```

**por:**

```dart
  /// marcações, e a tela volta a "não iniciada" — o participante continua com
  /// o consultor. A tela pede confirmação antes.
  Future<void> discard() async {
    final assessmentId = _assessmentId ?? _resumable?.id;
    if (assessmentId == null || !canDiscard || _busy) return;

    _discarding = true;
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
        _message = _discardFailed;
        return;
      }
      _detach();
      await _checkBlock();
    } catch (_) {
```

**por:**

```dart
        _message = _discardFailed;
        return;
      }
      _resumable = null;
      _detach();
      await _checkBlock();
    } catch (_) {
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
          }
          return false;
        case Success():
          final assessmentId = _assessmentId;
          if (assessmentId != null) {
            try {
              final discarded = await _assessmentRepository.discardDraft(assessmentId);
```

**por:**

```dart
          }
          return false;
        case Success():
          final assessmentId = _assessmentId ?? _resumable?.id;
          if (assessmentId != null) {
            try {
              final discarded = await _assessmentRepository.discardDraft(assessmentId);
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
              _message = _draftNotDiscarded;
            }
            // O participante foi liberado: a tela não segura mais a avaliação.
            _detach();
          }
          return true;
```

**por:**

```dart
              _message = _draftNotDiscarded;
            }
            // O participante foi liberado: a tela não segura mais a avaliação.
            _resumable = null;
            _detach();
          }
          return true;
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart

  /// Só uma avaliação por vez: confere se outro participante do consultor
  /// está em andamento, para o aviso e o "Iniciar" desabilitado. Só conta a
  /// avaliação que ele ainda consegue abrir — a "presa" não bloqueia.
  Future<void> _checkBlock() async {
    _blockingParticipantId = null;
    _blockingName = null;
    final inProgress = await _assessmentRepository.findInProgressOther(
      ownerUserId: ownerUserId,
      consultantId: consultantId,
      exceptTrainingParticipantId: participantId,
    );
    if (inProgress != null) await _block(inProgress.trainingParticipantId);
  }
```

**por:**

```dart

  /// Só uma avaliação por vez: confere se outro participante do consultor
  /// está em andamento, para o aviso e o "Iniciar" desabilitado. Só conta a
  /// avaliação que ele ainda consegue abrir — a "presa" não bloqueia. Para
  /// uma avaliação parada, [startedAfter] é o início dela: só a que começou
  /// depois a faz esperar.
  Future<void> _checkBlock({DateTime? startedAfter}) async {
    _blockingParticipantId = null;
    _blockingName = null;
    final inProgress = await _assessmentRepository.findInProgressOther(
      ownerUserId: ownerUserId,
      consultantId: consultantId,
      exceptTrainingParticipantId: participantId,
      startedAfter: startedAfter,
    );
    if (inProgress != null) await _block(inProgress.trainingParticipantId);
  }
```

**Em `lib/ui/core/date_labels.dart`, substituir:**

```dart
String startedLabel(DateTime start, DateTime now) =>
    'Iniciada ${atLabel(start, now)}';

/// Texto da faixa de offline: sem conexão, o consultor precisa saber a idade
/// do que está vendo — uma lista de ontem parece igualzinha a uma de agora.
/// Nulo quando nunca houve sync (aí a faixa usa a mensagem padrão dela).
String? offlineDataMessage(DateTime? syncedAt) {
  if (syncedAt == null) return null;
  final d = syncedAt.toLocal();
  return 'Sem conexão — dados de ${_dois(d.day)}/${_dois(d.month)} '
      'às ${_dois(d.hour)}:${_dois(d.minute)}.';
}
```

**por:**

```dart
String startedLabel(DateTime start, DateTime now) =>
    'Iniciada ${atLabel(start, now)}';

/// "08/10 às 08:12" — o dia e a hora de algo que pode não ter sido hoje: a
/// idade dos dados na faixa de offline, e o início de uma avaliação que ficou
/// parada.
String dayAndClockLabel(DateTime moment) {
  final d = moment.toLocal();
  return '${_dois(d.day)}/${_dois(d.month)} '
      'às ${_dois(d.hour)}:${_dois(d.minute)}';
}

/// Texto da faixa de offline: sem conexão, o consultor precisa saber a idade
/// do que está vendo — uma lista de ontem parece igualzinha a uma de agora.
/// Nulo quando nunca houve sync (aí a faixa usa a mensagem padrão dela).
String? offlineDataMessage(DateTime? syncedAt) {
  if (syncedAt == null) return null;
  return 'Sem conexão — dados de ${dayAndClockLabel(syncedAt)}.';
}
```

Depois de reservar, e ao reabrir a avaliação, a ViewModel lê o participante e as respostas direto do banco, sem esperar os streams: eles só avisam no turno seguinte, e até lá a tela mostraria o checklist sem as respostas, ou o aviso de "não está mais com você". O título "O que será avaliado" passa a encolher com reticências — o teste novo de 360dp com a fonte ampliada acusa um estouro que essa linha já tinha.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/date_labels_test.dart test/data/repositories/assessment_repository_test.dart test/ui/checklist`
Esperado: `+156: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+886: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/data/repositories/assessment_repository.dart \
  apps/mobile/simtc/lib/ui/checklist/checklist_screen.dart \
  apps/mobile/simtc/lib/ui/checklist/checklist_viewmodel.dart \
  apps/mobile/simtc/lib/ui/core/date_labels.dart \
  apps/mobile/simtc/test/data/repositories/assessment_repository_test.dart \
  apps/mobile/simtc/test/ui/checklist/checklist_screen_test.dart \
  apps/mobile/simtc/test/ui/checklist/checklist_viewmodel_test.dart \
  apps/mobile/simtc/test/ui/core/date_labels_test.dart
git commit -m "feat(mobile): avaliacao parada continua de onde parou"
```

---

## Task 12: Aba Sincronizar — o motivo próprio do envio recusado

Quem foi tirado da sessão, ou desatribuído, com a avaliação já confirmada no aparelho tem o envio recusado pelo servidor (Task 3). Na aba Sincronizar, o item passa a dizer por quê — "o participante não está mais com você" —, no lugar do genérico "recusada pelo servidor", e continua com o "Descartar". O app reconhece a recusa pelo código `NOT_ASSIGNED`; uma recusa sem código, ou com um código que ele não conhece, continua sendo a genérica.

**Files:**
- Modify: `lib/data/repositories/assessment_repository.dart`
- Modify: `lib/data/services/assessment_sync_service.dart`
- Modify: `lib/ui/sync/sync_screen.dart`
- Modify: `test/data/repositories/assessment_repository_test.dart`
- Modify: `test/data/services/assessment_sync_service_test.dart`
- Modify: `test/ui/sync/sync_screen_test.dart`

**Interfaces:**
- Consumes: o campo `code` do item rejeitado do `sync` (Task 3); `SendFailure.refused`; `AssessmentSyncService._outcomeByParticipant`, `discardRefused`.
- Produces:
  - `SendFailure.notAssigned` = "o participante não está mais com você"; `SendFailure.notAssignedCode` = "NOT_ASSIGNED"; `SendFailure.refusals` = `{refused, notAssigned}`.
  - `Future<bool> AssessmentRepository.discardFailed(String localAssessmentId, {required Set<String> reasons})` — troca o `reason` de antes: apaga a avaliação em erro cujo motivo é um dos pedidos.
  - `AssessmentSyncService.discardRefused` e a aba Sincronizar passam a valer para as duas recusas.

- [ ] **Step 1: Escrever os testes que falham**

**Em `test/data/repositories/assessment_repository_test.dart`, substituir:**

```dart
      await repository.confirm(queued.id, participantName: 'Bia', score: 90);

      expect(
        await repository.discardFailed(refused.id, reason: 'sem conexão'),
        isFalse,
        reason: 'outro motivo',
      );
      expect(
        await repository.discardFailed(queued.id, reason: 'recusada pelo servidor'),
        isFalse,
        reason: 'na fila, sem erro',
      );
      expect(
        await repository.discardFailed(refused.id, reason: 'recusada pelo servidor'),
        isTrue,
      );
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.id), [queued.id]);
    });

    test(
```

**por:**

```dart
      await repository.confirm(queued.id, participantName: 'Bia', score: 90);

      expect(
        await repository.discardFailed(refused.id, reasons: {'sem conexão'}),
        isFalse,
        reason: 'outro motivo',
      );
      expect(
        await repository.discardFailed(
          queued.id,
          reasons: {'recusada pelo servidor'},
        ),
        isFalse,
        reason: 'na fila, sem erro',
      );
      expect(
        await repository.discardFailed(
          refused.id,
          reasons: {'recusada pelo servidor'},
        ),
        isTrue,
      );
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.id), [queued.id]);
    });

    test('descartar uma falha aceita qualquer um dos motivos pedidos',
        () async {
      final released = await open('tp-1');
      await repository.confirm(released.id, participantName: 'Ana', score: 90);
      await repository.saveSendResults(
        {released.id: 'o participante não está mais com você'},
        at: DateTime(2026, 9, 30, 9),
      );

      expect(
        await repository.discardFailed(
          released.id,
          reasons: {'recusada pelo servidor', 'o participante não está mais com você'},
        ),
        isTrue,
      );
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    test('sem motivo nenhum pedido, nada é descartado', () async {
      final refused = await open('tp-1');
      await repository.confirm(refused.id, participantName: 'Ana', score: 90);
      await repository.saveSendResults(
        {refused.id: 'recusada pelo servidor'},
        at: DateTime(2026, 9, 30, 9),
      );

      expect(await repository.discardFailed(refused.id, reasons: const {}), isFalse);
    });

    test(
```

**Em `test/data/repositories/assessment_repository_test.dart`, substituir:**

```dart
      await repository.saveSendResults({resent.id: null}, at: DateTime(2026, 9, 30, 9, 5));

      expect(
        await repository.discardFailed(resent.id, reason: 'recusada pelo servidor'),
        isFalse,
      );
      expect((await row(resent.id)).syncStatus, LocalSyncStatus.synced);
```

**por:**

```dart
      await repository.saveSendResults({resent.id: null}, at: DateTime(2026, 9, 30, 9, 5));

      expect(
        await repository.discardFailed(
          resent.id,
          reasons: {'recusada pelo servidor'},
        ),
        isFalse,
      );
      expect((await row(resent.id)).syncStatus, LocalSyncStatus.synced);
```

**Em `test/data/services/assessment_sync_service_test.dart`, substituir:**

```dart
    expect(await db.select(db.localAssessments).get(), isEmpty);
  });

  test('"Descartar" não apaga a avaliação que falhou por rede', () async {
    failWith(semRede);
    final sync = startService();
```

**por:**

```dart
    expect(await db.select(db.localAssessments).get(), isEmpty);
  });

  group('recusa por o participante não estar mais com o consultor (Fase 6B)', () {
    /// O backend recusando com o código de "não está mais com você" para
    /// [released], e com uma recusa comum para os outros.
    void refuse({required String released}) {
      when(() => api.post<List<dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((invocation) async {
        final payload = payloadOf(invocation);
        sent.add(payload);
        return Response<List<dynamic>>(
          requestOptions: RequestOptions(path: AssessmentSyncService.syncPath),
          statusCode: 201,
          data: [
            for (final item in payload)
              if (item['trainingParticipantId'] == released)
                {
                  'trainingParticipantId': released,
                  'status': 'rejected',
                  'error': 'Este participante não está mais em avaliação com '
                      'você. A avaliação não foi registrada.',
                  'code': 'NOT_ASSIGNED',
                }
              else
                {
                  'trainingParticipantId': item['trainingParticipantId'],
                  'status': 'rejected',
                  'error': 'Participante não encontrado',
                  'code': null,
                },
          ],
        );
      });
    }

    test('ganha o motivo próprio; a recusa sem código continua "recusada pelo '
        'servidor"', () async {
      refuse(released: 'tp-1');
      final released = await confirmed('tp-1');
      final other = await confirmed('tp-2');

      startService();

      await until(() async =>
          await statusOf(released.id) == LocalSyncStatus.error &&
          await statusOf(other.id) == LocalSyncStatus.error);
      expect((await row(released.id)).lastError, SendFailure.notAssigned);
      expect((await row(released.id)).lastError,
          'o participante não está mais com você');
      expect((await row(other.id)).lastError, SendFailure.refused);
    });

    test('"Descartar" também apaga a avaliação recusada por esse motivo',
        () async {
      refuse(released: 'tp-1');
      final sync = startService();
      final released = await confirmed('tp-1');
      await until(() async => await statusOf(released.id) == LocalSyncStatus.error);
      expect((await row(released.id)).lastError, SendFailure.notAssigned);
      await until(() => !sync.isSending);

      expect(await sync.discardRefused(released.id), isTrue);

      await until(() => sync.queue.isEmpty);
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    test('um código que o app não conhece é uma recusa comum', () async {
      when(() => api.post<List<dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((invocation) async {
        final payload = payloadOf(invocation);
        sent.add(payload);
        return Response<List<dynamic>>(
          requestOptions: RequestOptions(path: AssessmentSyncService.syncPath),
          statusCode: 201,
          data: [
            for (final item in payload)
              {
                'trainingParticipantId': item['trainingParticipantId'],
                'status': 'rejected',
                'error': 'x',
                'code': 'OUTRO',
              },
          ],
        );
      });
      final refused = await confirmed('tp-1');

      startService();

      await until(() async => await statusOf(refused.id) == LocalSyncStatus.error);
      expect((await row(refused.id)).lastError, SendFailure.refused);
    });
  });

  test('"Descartar" não apaga a avaliação que falhou por rede', () async {
    failWith(semRede);
    final sync = startService();
```

**Em `test/ui/sync/sync_screen_test.dart`, substituir:**

```dart
    await tester.pumpAndSettle();

    expect(sync.discardCalls, [refused.id]);
    expect(find.text('Marcos Vinícius Alves'), findsNothing);
  });
```

**por:**

```dart
    await tester.pumpAndSettle();

    expect(sync.discardCalls, [refused.id]);
    expect(find.text('Marcos Vinícius Alves'), findsNothing);
  });

  testWidgets(
      'recusada por o participante não estar mais com o consultor: a linha diz '
      'o motivo e tem o "Descartar"', (tester) async {
    final released = queuedAssessment(
      '3',
      participantName: 'Marcos Vinícius Alves',
      status: LocalSyncStatus.error,
      lastAttemptAt: DateTime(2026, 9, 29, 8, 5),
      lastError: SendFailure.notAssigned,
    );
    await pump(tester, queue: [released]);

    expect(
      find.text('Falhou às 08:05 · o participante não está mais com você'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await tester.pumpAndSettle();

    expect(sync.discardCalls, [released.id]);
    expect(find.text('Marcos Vinícius Alves'), findsNothing);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/data/repositories/assessment_repository_test.dart test/data/services/assessment_sync_service_test.dart test/ui/sync`
Esperado: não compilam — `No named parameter with the name 'reasons'` e `Member not found: 'notAssigned'` (o `SendFailure.notAssigned`).

- [ ] **Step 3: Implementar**

**Em `lib/data/repositories/assessment_repository.dart`, substituir:**

```dart
  }

  /// "Descartar" da aba Sincronizar: apaga a avaliação que o envio deixou em
  /// erro com o motivo [reason] — na prática, "recusada pelo servidor". Se no
  /// meio do caminho ela foi reenviada e aceita, ou o motivo mudou, devolve
  /// `false` e não apaga.
  Future<bool> discardFailed(String localAssessmentId, {required String reason}) {
    return _discardWhere(
      localAssessmentId,
      (row) => row.syncStatus == LocalSyncStatus.error && row.lastError == reason,
    );
  }
```

**por:**

```dart
  }

  /// "Descartar" da aba Sincronizar: apaga a avaliação que o envio deixou em
  /// erro com um dos motivos de [reasons] — na prática, as recusas do
  /// servidor. Se no meio do caminho ela foi reenviada e aceita, ou o motivo
  /// mudou, devolve `false` e não apaga.
  Future<bool> discardFailed(
    String localAssessmentId, {
    required Set<String> reasons,
  }) {
    return _discardWhere(
      localAssessmentId,
      (row) =>
          row.syncStatus == LocalSyncStatus.error &&
          reasons.contains(row.lastError),
    );
  }
```

**Em `lib/data/services/assessment_sync_service.dart`, substituir:**

```dart
  static const String timeout = 'tempo esgotado';
  static const String serverDown = 'servidor indisponível';
  static const String refused = 'recusada pelo servidor';
}

/// Envia ao backend a fila de avaliações confirmadas (Fase 5A).
```

**por:**

```dart
  static const String timeout = 'tempo esgotado';
  static const String serverDown = 'servidor indisponível';
  static const String refused = 'recusada pelo servidor';

  /// O servidor recusou porque o participante não está mais em avaliação com
  /// quem enviou (Fase 6B): um ADMIN o desatribuiu, ou o consultor saiu da
  /// sessão, antes de o envio chegar.
  static const String notAssigned = 'o participante não está mais com você';

  /// O código que o backend manda junto com a recusa de [notAssigned].
  static const String notAssignedCode = 'NOT_ASSIGNED';

  /// As recusas do servidor: tentar de novo sozinho não resolve, e a aba
  /// Sincronizar oferece o "Descartar".
  static const Set<String> refusals = {refused, notAssigned};
}

/// Envia ao backend a fila de avaliações confirmadas (Fase 5A).
```

**Em `lib/data/services/assessment_sync_service.dart`, substituir:**

```dart
  /// A fila se atualiza pelo stream do banco.
  Future<bool> discardRefused(String localAssessmentId) async {
    if (isSending) return false;
    return _assessments.discardFailed(localAssessmentId, reason: SendFailure.refused);
  }

  /// Envia a fila agora, sem esperar a próxima tentativa. Sem rede, não tenta:
```

**por:**

```dart
  /// A fila se atualiza pelo stream do banco.
  Future<bool> discardRefused(String localAssessmentId) async {
    if (isSending) return false;
    return _assessments.discardFailed(
      localAssessmentId,
      reasons: SendFailure.refusals,
    );
  }

  /// Envia a fila agora, sem esperar a próxima tentativa. Sem rede, não tenta:
```

**Em `lib/data/services/assessment_sync_service.dart`, substituir:**

```dart

  /// `{trainingParticipantId: nulo se aceita, ou o motivo}`, da resposta do
  /// backend: `[{ trainingParticipantId, status: 'fulfilled' | 'rejected',
  /// error }]`. A mensagem crua da recusa vai só para o log.
  static Map<String, String?> _outcomeByParticipant(Object? body) {
    if (body is! List) return const {};
    final outcome = <String, String?>{};
```

**por:**

```dart

  /// `{trainingParticipantId: nulo se aceita, ou o motivo}`, da resposta do
  /// backend: `[{ trainingParticipantId, status: 'fulfilled' | 'rejected',
  /// error, code }]`. A mensagem crua da recusa vai só para o log; o `code`,
  /// quando o app o conhece, vira um motivo próprio.
  static Map<String, String?> _outcomeByParticipant(Object? body) {
    if (body is! List) return const {};
    final outcome = <String, String?>{};
```

**Em `lib/data/services/assessment_sync_service.dart`, substituir:**

```dart
        outcome[id] = null;
      } else {
        debugPrint('Avaliação de $id recusada: ${item['error']}');
        outcome[id] = SendFailure.refused;
      }
    }
    return outcome;
```

**por:**

```dart
        outcome[id] = null;
      } else {
        debugPrint('Avaliação de $id recusada: ${item['error']}');
        outcome[id] = item['code'] == SendFailure.notAssignedCode
            ? SendFailure.notAssigned
            : SendFailure.refused;
      }
    }
    return outcome;
```

**Em `lib/ui/sync/sync_screen.dart`, substituir:**

```dart
    final retry = _RetryButton(
      onPressed: isOffline || sync.isSending ? null : sync.syncNow,
    );
    if (item.lastError != SendFailure.refused) return retry;

    return Row(
      children: [
```

**por:**

```dart
    final retry = _RetryButton(
      onPressed: isOffline || sync.isSending ? null : sync.syncNow,
    );
    if (!SendFailure.refusals.contains(item.lastError)) return retry;

    return Row(
      children: [
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/data/repositories/assessment_repository_test.dart test/data/services/assessment_sync_service_test.dart test/ui/sync`
Esperado: `+93: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+892: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/data/repositories/assessment_repository.dart \
  apps/mobile/simtc/lib/data/services/assessment_sync_service.dart \
  apps/mobile/simtc/lib/ui/sync/sync_screen.dart \
  apps/mobile/simtc/test/data/repositories/assessment_repository_test.dart \
  apps/mobile/simtc/test/data/services/assessment_sync_service_test.dart \
  apps/mobile/simtc/test/ui/sync/sync_screen_test.dart
git commit -m "feat(mobile): motivo proprio para o envio recusado por participante liberado"
```

---

## Task 13: 1.11 — a consulta do CPF trava os campos, tem limite de tempo e respeita a conexão

Três acertos na "Adicionar participante", decididos depois da validação da 6A (decisões 5, 7 e 13):

- **Trava:** enquanto o CPF é consultado, nome e e-mail ficam travados. Com a rede lenta, o cadastro chegava com o admin no meio da digitação e trocava o texto sob o cursor.
- **Limite de tempo:** a consulta tem 8 segundos. Sem isso, os campos ficariam travados até o limite da API.
- **Conexão:** sem conexão, a consulta nem é feita e nenhum aviso de falha aparece sob o CPF — o aviso convidava a adicionar enquanto a faixa do topo dizia que não dá. Quando a rede volta, o CPF que está no campo é consultado sozinho; a consulta que falhou também é refeita.

**Files:**
- Modify: `lib/ui/add_participant/add_participant_viewmodel.dart`
- Modify: `lib/ui/add_participant/add_participant_screen.dart`
- Modify: `test/ui/add_participant/add_participant_viewmodel_test.dart`
- Modify: `test/ui/add_participant/add_participant_screen_test.dart`

**Interfaces:**
- Consumes: `ConnectivityService.isOffline`, `onReconnected`; `ParticipantRepository.lookupCpf`; `AddParticipantViewModel._lookup`, `setCpf`, `cpfHelper`.
- Produces:
  - `AddParticipantViewModel({..., required ConnectivityService connectivity, Duration lookupTimeout = defaultLookupTimeout})`; `static const Duration defaultLookupTimeout` = 8 segundos.
  - `CpfCheck.offline` — CPF válido digitado sem conexão: sem consulta, sem texto sob o campo, e sem poder adicionar.
  - `bool isCheckingCpf`.
  - Na tela, nome e e-mail desabilitados enquanto `isCheckingCpf`; o CPF, não.

- [ ] **Step 1: Escrever os testes que falham**

**Em `test/ui/add_participant/add_participant_screen_test.dart`, substituir:**

```dart
    verifyNever(
      () => api.post<Map<String, dynamic>>(lookupPath, data: any(named: 'data')),
    );
  });

  testWidgets('consulta que falha: avisa e segue como formulário simples',
```

**por:**

```dart
    verifyNever(
      () => api.post<Map<String, dynamic>>(lookupPath, data: any(named: 'data')),
    );
  });

  testWidgets(
      'enquanto o CPF é consultado, nome e e-mail ficam travados e o CPF '
      'continua editável; a resposta destrava e preenche', (tester) async {
    await seedSession();
    final reply = Completer<Response<Map<String, dynamic>>>();
    when(() => api.post<Map<String, dynamic>>(lookupPath, data: any(named: 'data')))
        .thenAnswer((_) => reply.future);
    await pumpAdd(tester);
    expect(tester.widget<TextField>(field('campo-nome')).enabled, isTrue);

    await tester.enterText(field('campo-cpf'), cpf);
    await tester.pump();
    // Um quadro no meio da consulta.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Consultando o CPF…'), findsOneWidget);
    expect(tester.widget<TextField>(field('campo-nome')).enabled, isFalse);
    expect(tester.widget<TextField>(field('campo-email')).enabled, isFalse);
    expect(tester.widget<TextField>(field('campo-cpf')).enabled, isTrue);

    reply.complete(
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: lookupPath),
        statusCode: 200,
        data: {
          'registered': true,
          'name': 'Fernanda Lopes Meireles',
          'email': 'fernanda@empresa.com.br',
          'enrolled': false,
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field('campo-nome')).enabled, isTrue);
    expect(tester.widget<TextField>(field('campo-email')).enabled, isTrue);
    expect(textOf(tester, 'campo-nome'), 'Fernanda Lopes Meireles');
    expect(textOf(tester, 'campo-email'), 'fernanda@empresa.com.br');
  });

  testWidgets(
      'sem conexão, o CPF completo não é consultado e não aparece o aviso de '
      'falha da consulta: ficam a faixa e a dica do botão', (tester) async {
    await seedSession();
    cpfIsFree();
    await goOffline();
    await pumpAdd(tester);

    await typeCpf(tester);

    verifyNever(
      () => api.post<Map<String, dynamic>>(lookupPath, data: any(named: 'data')),
    );
    expect(find.textContaining('Não foi possível consultar o CPF'), findsNothing);
    expect(find.text('Consultando o CPF…'), findsNothing);
    expect(
      find.text('Sem conexão — adicionar participante precisa de internet.'),
      findsOneWidget,
    );
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    // Dá para ir preenchendo o resto.
    expect(tester.widget<TextField>(field('campo-nome')).enabled, isTrue);
  });

  testWidgets(
      'quando a conexão volta, o CPF que estava no campo é consultado '
      'sozinho, e o cadastro preenche os campos', (tester) async {
    await seedSession();
    lookupAnswers({
      'registered': true,
      'name': 'Fernanda Lopes Meireles',
      'email': null,
      'enrolled': false,
    });
    final changes = StreamController<List<ConnectivityResult>>();
    addTearDown(changes.close);
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => changes.stream);
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
    await pumpAdd(tester);
    await typeCpf(tester);
    expect(textOf(tester, 'campo-nome'), '');

    changes.add([ConnectivityResult.wifi]);
    await tester.pumpAndSettle();

    verify(
      () => api.post<Map<String, dynamic>>(lookupPath, data: any(named: 'data')),
    ).called(1);
    expect(find.textContaining('Sem conexão'), findsNothing);
    expect(textOf(tester, 'campo-nome'), 'Fernanda Lopes Meireles');
    expect(find.textContaining('Já cadastrado em outro treinamento'), findsOneWidget);
  });

  testWidgets('consulta que falha: avisa e segue como formulário simples',
```

**Em `test/ui/add_participant/add_participant_viewmodel_test.dart`, substituir:**

```dart
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/ui/add_participant/add_participant_viewmodel.dart';
import 'package:simtc/utils/result.dart';
```

**por:**

```dart
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/add_participant/add_participant_viewmodel.dart';
import 'package:simtc/utils/result.dart';
```

**Em `test/ui/add_participant/add_participant_viewmodel_test.dart`, substituir:**

```dart

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

void main() {
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late StreamController<TrainingSession?> sessionStream;

  // Dois CPFs com os dígitos verificadores certos.
```

**por:**

```dart

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

/// Conectividade de mentira: o serviço real conversa com o plugin de
/// plataforma, que não existe num teste de unidade.
class _FakeConnectivity extends ConnectivityService {
  final _reconnected = StreamController<void>.broadcast();

  bool offline = false;

  @override
  bool get isOffline => offline;

  @override
  bool get isOnline => !offline;

  @override
  Stream<void> get onReconnected => _reconnected.stream;

  bool get hasReconnectListener => _reconnected.hasListener;

  /// A rede volta.
  void reconnect() {
    offline = false;
    _reconnected.add(null);
  }

  @override
  void dispose() {
    _reconnected.close();
    super.dispose();
  }
}

void main() {
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late _FakeConnectivity connectivity;
  late StreamController<TrainingSession?> sessionStream;

  // Dois CPFs com os dígitos verificadores certos.
```

**Em `test/ui/add_participant/add_participant_viewmodel_test.dart`, substituir:**

```dart
  setUp(() {
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    sessionStream = StreamController<TrainingSession?>.broadcast();

    when(() => sessions.watchSession('sess-1'))
```

**por:**

```dart
  setUp(() {
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    connectivity = _FakeConnectivity();
    sessionStream = StreamController<TrainingSession?>.broadcast();

    when(() => sessions.watchSession('sess-1'))
```

**Em `test/ui/add_participant/add_participant_viewmodel_test.dart`, substituir:**

```dart
    addAnswers(Success(added()));
  });

  tearDown(() => sessionStream.close());

  /// A tela aberta, com a sessão já lida do cache.
  Future<AddParticipantViewModel> open({
    AuthUser? user = admin,
    TrainingSession? withSession,
    bool missing = false,
  }) async {
    final vm = AddParticipantViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      currentUser: user,
    )..init();
    addTearDown(vm.dispose);
    sessionStream.add(missing ? null : (withSession ?? session()));
```

**por:**

```dart
    addAnswers(Success(added()));
  });

  tearDown(() {
    sessionStream.close();
    connectivity.dispose();
  });

  /// A tela aberta, com a sessão já lida do cache.
  Future<AddParticipantViewModel> open({
    AuthUser? user = admin,
    TrainingSession? withSession,
    bool missing = false,
    Duration lookupTimeout = AddParticipantViewModel.defaultLookupTimeout,
  }) async {
    final vm = AddParticipantViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      connectivity: connectivity,
      currentUser: user,
      lookupTimeout: lookupTimeout,
    )..init();
    addTearDown(vm.dispose);
    sessionStream.add(missing ? null : (withSession ?? session()));
```

**Em `test/ui/add_participant/add_participant_viewmodel_test.dart`, substituir:**

```dart
      answer.complete(const Success(free));
      await pumpEventQueue();
      expect(vm.canSubmit, isTrue);
    });
  });
```

**por:**

```dart
      answer.complete(const Success(free));
      await pumpEventQueue();
      expect(vm.canSubmit, isTrue);
    });
  });

  // Decisões de 09/10/2026: a consulta trava o nome e o e-mail, tem limite de
  // tempo próprio, não roda sem conexão e roda sozinha quando a rede volta.
  group('consulta: trava, limite de tempo e conexão', () {
    test('enquanto consulta, nome e e-mail ficam travados; a resposta '
        'destrava', () async {
      final answer = Completer<Result<CpfLookup>>();
      when(() => participants.lookupCpf('sess-1', cpf))
          .thenAnswer((_) => answer.future);
      final vm = await open();
      expect(vm.isCheckingCpf, isFalse);

      vm.setCpf(cpf);

      expect(vm.isCheckingCpf, isTrue);
      expect(vm.cpfHelper, 'Consultando o CPF…');

      answer.complete(const Success(registered));
      await pumpEventQueue();

      expect(vm.isCheckingCpf, isFalse);
      expect(vm.name, 'Fernanda Lopes Meireles');
    });

    test('o limite da consulta é de 8 segundos', () {
      expect(
        AddParticipantViewModel.defaultLookupTimeout,
        const Duration(seconds: 8),
      );
    });

    test('consulta que não responde no limite: destrava com o aviso, e a '
        'resposta que chegar depois é ignorada', () async {
      final answer = Completer<Result<CpfLookup>>();
      when(() => participants.lookupCpf('sess-1', cpf))
          .thenAnswer((_) => answer.future);
      final vm = await open(lookupTimeout: const Duration(milliseconds: 30));

      vm.setCpf(cpf);
      expect(vm.isCheckingCpf, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 90));

      expect(vm.isCheckingCpf, isFalse);
      expect(vm.cpfCheck, CpfCheck.unverified);
      expect(
        vm.cpfHelper,
        'Não foi possível consultar o CPF. Preencha os dados e adicione assim mesmo.',
      );
      vm.setName('Digitado À Mão');
      expect(vm.canSubmit, isTrue);

      answer.complete(const Success(registered));
      await pumpEventQueue();

      expect(vm.cpfCheck, CpfCheck.unverified);
      expect(vm.name, 'Digitado À Mão', reason: 'o cadastro chegou tarde demais');
      expect(vm.filledFromRegistry, isFalse);
    });

    test('sem conexão não consulta e não mostra aviso de falha', () async {
      connectivity.offline = true;
      final vm = await open();

      vm.setCpf(cpf);
      await pumpEventQueue();
      vm.setName('Fernanda Lopes Meireles');

      verifyNever(() => participants.lookupCpf(any(), any()));
      expect(vm.cpfCheck, CpfCheck.offline);
      expect(vm.isCheckingCpf, isFalse);
      expect(vm.cpfHelper, isNull);
      expect(vm.cpfError, isNull);
      // Adicionar precisa de conexão de qualquer jeito.
      expect(vm.canSubmit, isFalse);
    });

    test('sem conexão, o CPF com dígito errado continua sendo acusado',
        () async {
      connectivity.offline = true;
      final vm = await open();

      vm.setCpf('52998224726');

      expect(vm.cpfCheck, CpfCheck.invalid);
      expect(vm.cpfError, 'CPF inválido.');
    });

    test('quando a rede volta, o CPF do campo é consultado sozinho', () async {
      lookupAnswers(registered);
      connectivity.offline = true;
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();

      connectivity.reconnect();
      await pumpEventQueue();

      verify(() => participants.lookupCpf('sess-1', cpf)).called(1);
      expect(vm.cpfCheck, CpfCheck.available);
      expect(vm.name, 'Fernanda Lopes Meireles');
      expect(vm.email, 'fernanda@empresa.com.br');
    });

    test('a consulta de quando a rede volta também trava os campos', () async {
      final answer = Completer<Result<CpfLookup>>();
      when(() => participants.lookupCpf('sess-1', cpf))
          .thenAnswer((_) => answer.future);
      connectivity.offline = true;
      final vm = await open();
      vm.setCpf(cpf);

      connectivity.reconnect();
      await pumpEventQueue();

      expect(vm.isCheckingCpf, isTrue);

      answer.complete(const Success(free));
      await pumpEventQueue();
      expect(vm.isCheckingCpf, isFalse);
    });

    test('a consulta que falhou é refeita quando a rede volta', () async {
      when(() => participants.lookupCpf('sess-1', cpf)).thenAnswer(
        (_) async => Failure<CpfLookup>(Exception('sem rede'), 'x'),
      );
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();
      expect(vm.cpfCheck, CpfCheck.unverified);

      lookupAnswers(free);
      connectivity.reconnect();
      await pumpEventQueue();

      verify(() => participants.lookupCpf('sess-1', cpf)).called(2);
      expect(vm.cpfCheck, CpfCheck.available);
    });

    test('a rede voltar não refaz a consulta que já respondeu, nem consulta '
        'CPF incompleto, inválido ou já inscrito', () async {
      final vm = await open();

      connectivity.reconnect();
      await pumpEventQueue();
      verifyNever(() => participants.lookupCpf(any(), any()));

      vm.setCpf('5299822');
      connectivity.reconnect();
      vm.setCpf('52998224726');
      connectivity.reconnect();
      await pumpEventQueue();
      verifyNever(() => participants.lookupCpf(any(), any()));

      vm.setCpf(cpf);
      await pumpEventQueue();
      expect(vm.cpfCheck, CpfCheck.available);
      connectivity.reconnect();
      await pumpEventQueue();
      verify(() => participants.lookupCpf('sess-1', cpf)).called(1);

      lookupAnswers(
        const CpfLookup(registered: true, enrolled: true, name: 'Ana'),
        forCpf: otherCpf,
      );
      vm.setCpf(otherCpf);
      await pumpEventQueue();
      expect(vm.cpfCheck, CpfCheck.enrolled);
      connectivity.reconnect();
      await pumpEventQueue();
      verify(() => participants.lookupCpf('sess-1', otherCpf)).called(1);
    });

    test('a rede voltar no meio de uma consulta não dispara outra', () async {
      final answer = Completer<Result<CpfLookup>>();
      when(() => participants.lookupCpf('sess-1', cpf))
          .thenAnswer((_) => answer.future);
      final vm = await open();
      vm.setCpf(cpf);

      connectivity.reconnect();
      await pumpEventQueue();

      verify(() => participants.lookupCpf('sess-1', cpf)).called(1);
      answer.complete(const Success(free));
      await pumpEventQueue();
      expect(vm.cpfCheck, CpfCheck.available);
    });

    test('fechar a tela larga o aviso de volta da rede', () async {
      final vm = AddParticipantViewModel(
        sessionId: 'sess-1',
        sessionRepository: sessions,
        participantRepository: participants,
        connectivity: connectivity,
        currentUser: admin,
      )..init();
      expect(connectivity.hasReconnectListener, isTrue);

      vm.dispose();

      expect(connectivity.hasReconnectListener, isFalse);
    });
  });
```

**Em `test/ui/add_participant/add_participant_viewmodel_test.dart`, substituir:**

```dart
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      currentUser: admin,
    )..init();
    sessionStream.add(session());
```

**por:**

```dart
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      connectivity: connectivity,
      currentUser: admin,
    )..init();
    sessionStream.add(session());
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/add_participant`
Esperado: o da ViewModel não compila — `No named parameter with the name 'connectivity'`, `Member not found: 'defaultLookupTimeout'`, `Member not found: 'offline'` (o `CpfCheck.offline`) e `The getter 'isCheckingCpf' isn't defined for the type 'AddParticipantViewModel'`; no da tela, os três testes novos falham: os campos não travam durante a consulta, o CPF é consultado sem conexão e nada é consultado quando ela volta.

- [ ] **Step 3: Implementar**

**Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:**

```dart
    sessionId: widget.sessionId,
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    currentUser: context.read<AuthRepository>().currentUser,
  )..init();
```

**por:**

```dart
    sessionId: widget.sessionId,
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    connectivity: context.read<ConnectivityService>(),
    currentUser: context.read<AuthRepository>().currentUser,
  )..init();
```

**Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:**

```dart
  void _onEmailFocusChange() => setState(() {});

  bool get _fieldsEnabled => _viewModel.canAdd && !_viewModel.isSubmitting;

  bool get _showEmailError => !_emailFocus.hasFocus && !_viewModel.isEmailValid;
```

**por:**

```dart
  void _onEmailFocusChange() => setState(() {});

  bool get _fieldsEnabled => _viewModel.canAdd && !_viewModel.isSubmitting;

  /// Nome e e-mail ficam travados enquanto o CPF é consultado (decisão de
  /// 09/10/2026): o cadastro pode preenchê-los, e não troca o texto sob o
  /// cursor de quem está digitando. O CPF continua editável.
  bool get _registryFieldsEnabled =>
      _fieldsEnabled && !_viewModel.isCheckingCpf;

  bool get _showEmailError => !_emailFocus.hasFocus && !_viewModel.isEmailValid;
```

**Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:**

```dart
      icon: AppIcons.profile,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      enabled: _fieldsEnabled,
      onChanged: _viewModel.setName,
    );
  }
```

**por:**

```dart
      icon: AppIcons.profile,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      enabled: _registryFieldsEnabled,
      onChanged: _viewModel.setName,
    );
  }
```

**Em `lib/ui/add_participant/add_participant_screen.dart`, substituir:**

```dart
      hintText: 'para enviar o certificado',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      enabled: _fieldsEnabled,
      errorText: _showEmailError ? 'E-mail inválido.' : null,
      onChanged: _viewModel.setEmail,
    );
```

**por:**

```dart
      hintText: 'para enviar o certificado',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      enabled: _registryFieldsEnabled,
      errorText: _showEmailError ? 'E-mail inválido.' : null,
      onChanged: _viewModel.setEmail,
    );
```

**Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:**

```dart
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../utils/cpf.dart';
import '../../utils/result.dart';
```

**por:**

```dart
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../data/services/connectivity_service.dart';
import '../../utils/cpf.dart';
import '../../utils/result.dart';
```

**Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:**

```dart
  /// Válido, mas a consulta falhou: a tela segue como formulário simples, e
  /// o backend resolve o CPF repetido.
  unverified,
}

/// Estado da tela 1.11 "Adicionar participante" (Fase 6A), só para ADMIN.
```

**por:**

```dart
  /// Válido, mas a consulta falhou: a tela segue como formulário simples, e
  /// o backend resolve o CPF repetido.
  unverified,

  /// Válido, mas o aparelho está sem conexão: a consulta fica para quando a
  /// rede voltar, sem aviso de falha — a faixa do topo já diz o motivo.
  offline,
}

/// Estado da tela 1.11 "Adicionar participante" (Fase 6A), só para ADMIN.
```

**Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:**

```dart
/// Os campos continuam editáveis — o que estiver na tela ao adicionar é o que
/// o backend grava no cadastro, como já fazia.
///
/// O CPF inteiro só existe aqui, em memória, enquanto a tela está aberta.
class AddParticipantViewModel extends ChangeNotifier {
  AddParticipantViewModel({
    required this.sessionId,
    required SessionRepository sessionRepository,
    required ParticipantRepository participantRepository,
    required AuthUser? currentUser,
  })  : _sessionRepository = sessionRepository,
        _participantRepository = participantRepository,
        _currentUser = currentUser;

  final String sessionId;
  final SessionRepository _sessionRepository;
  final ParticipantRepository _participantRepository;
  final AuthUser? _currentUser;

  static const String _addFailed =
      'Não foi possível adicionar o participante. Tente de novo.';
```

**por:**

```dart
/// Os campos continuam editáveis — o que estiver na tela ao adicionar é o que
/// o backend grava no cadastro, como já fazia.
///
/// A consulta (decisões de 09/10/2026): enquanto está no ar, nome e e-mail
/// ficam travados — o cadastro não troca o texto sob o cursor de quem está
/// digitando; tem limite de tempo próprio ([lookupTimeout]); não roda sem
/// conexão; e roda sozinha quando a rede volta.
///
/// O CPF inteiro só existe aqui, em memória, enquanto a tela está aberta.
class AddParticipantViewModel extends ChangeNotifier {
  AddParticipantViewModel({
    required this.sessionId,
    required SessionRepository sessionRepository,
    required ParticipantRepository participantRepository,
    required ConnectivityService connectivity,
    required AuthUser? currentUser,
    this.lookupTimeout = defaultLookupTimeout,
  })  : _sessionRepository = sessionRepository,
        _participantRepository = participantRepository,
        _connectivity = connectivity,
        _currentUser = currentUser;

  /// Quanto a consulta do CPF pode demorar. O limite da API é bem maior (é o
  /// de qualquer chamada), e até lá os campos ficariam travados.
  static const Duration defaultLookupTimeout = Duration(seconds: 8);

  final String sessionId;
  final SessionRepository _sessionRepository;
  final ParticipantRepository _participantRepository;
  final ConnectivityService _connectivity;
  final AuthUser? _currentUser;

  /// Passou disso, a consulta conta como falha: os campos destravam, e a
  /// resposta que chegar depois é ignorada.
  final Duration lookupTimeout;

  static const String _addFailed =
      'Não foi possível adicionar o participante. Tente de novo.';
```

**Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:**

```dart
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  StreamSubscription<TrainingSession?>? _sessionSubscription;

  bool _disposed = false;
  bool _loaded = false;
```

**por:**

```dart
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  bool _disposed = false;
  bool _loaded = false;
```

**Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:**

```dart
  String get email => _email;
  ParticipationType get participationType => _type;
  CpfCheck get cpfCheck => _cpfCheck;

  /// Nome e/ou e-mail vieram do cadastro de outro treinamento.
  bool get filledFromRegistry => _filledFromRegistry;
```

**por:**

```dart
  String get email => _email;
  ParticipationType get participationType => _type;
  CpfCheck get cpfCheck => _cpfCheck;

  /// A consulta está no ar: nome e e-mail ficam travados até ela responder.
  bool get isCheckingCpf => _cpfCheck == CpfCheck.checking;

  /// Nome e/ou e-mail vieram do cadastro de outro treinamento.
  bool get filledFromRegistry => _filledFromRegistry;
```

**Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:**

```dart
      _name.trim().isNotEmpty &&
      isEmailValid;

  /// Assina o cache da sessão. Chamado uma vez pela tela.
  void init() {
    _sessionSubscription ??=
        _sessionRepository.watchSession(sessionId).listen((session) {
```

**por:**

```dart
      _name.trim().isNotEmpty &&
      isEmailValid;

  /// Assina o cache da sessão e a volta da conexão. Chamado uma vez pela
  /// tela.
  void init() {
    _sessionSubscription ??=
        _sessionRepository.watchSession(sessionId).listen((session) {
```

**Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:**

```dart
      _loaded = true;
      notifyListeners();
    });
  }

  /// Aceita o CPF com ou sem máscara. Completo e válido, dispara a consulta.
```

**por:**

```dart
      _loaded = true;
      notifyListeners();
    });

    _reconnectSubscription ??=
        _connectivity.onReconnected.listen((_) => _lookupAgain());
  }

  /// A rede voltou: o CPF que ficou sem consulta — digitado sem conexão, ou
  /// cuja consulta falhou — é consultado sozinho.
  void _lookupAgain() {
    if (_cpfCheck != CpfCheck.offline && _cpfCheck != CpfCheck.unverified) {
      return;
    }
    _cpfCheck = CpfCheck.checking;
    notifyListeners();
    unawaited(_lookup(_cpf));
  }

  /// Aceita o CPF com ou sem máscara. Completo e válido, dispara a consulta.
```

**Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:**

```dart
      _cpfCheck = CpfCheck.incomplete;
    } else if (!isValidCpf(cpf)) {
      _cpfCheck = CpfCheck.invalid;
    } else {
      _cpfCheck = CpfCheck.checking;
      unawaited(_lookup(cpf));
```

**por:**

```dart
      _cpfCheck = CpfCheck.incomplete;
    } else if (!isValidCpf(cpf)) {
      _cpfCheck = CpfCheck.invalid;
    } else if (_connectivity.isOffline) {
      // A consulta falharia, e o aviso de falha convidaria a adicionar o que
      // não dá para adicionar agora. Fica para a volta da rede.
      _cpfCheck = CpfCheck.offline;
    } else {
      _cpfCheck = CpfCheck.checking;
      unawaited(_lookup(cpf));
```

**Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:**

```dart
  Future<void> _lookup(String cpf) async {
    Result<CpfLookup> result;
    try {
      result = await _participantRepository.lookupCpf(sessionId, cpf);
    } catch (error) {
      result = Failure(Exception('$error'));
    }
    // Resposta atrasada: a tela fechou, ou o CPF já é outro.
```

**por:**

```dart
  Future<void> _lookup(String cpf) async {
    Result<CpfLookup> result;
    try {
      result = await _participantRepository
          .lookupCpf(sessionId, cpf)
          .timeout(lookupTimeout);
    } catch (error) {
      // O tempo esgotado também cai aqui.
      result = Failure(Exception('$error'));
    }
    // Resposta atrasada: a tela fechou, ou o CPF já é outro.
```

**Em `lib/ui/add_participant/add_participant_viewmodel.dart`, substituir:**

```dart
  void dispose() {
    _disposed = true;
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
```

**por:**

```dart
  void dispose() {
    _disposed = true;
    _sessionSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
```

O limite é um `Future.timeout`: ele só solta a tela — a chamada continua no ar, e a resposta que chegar depois cai no vazio.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/add_participant`
Esperado: `+80: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+906: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/ui/add_participant/add_participant_screen.dart \
  apps/mobile/simtc/lib/ui/add_participant/add_participant_viewmodel.dart \
  apps/mobile/simtc/test/ui/add_participant/add_participant_screen_test.dart \
  apps/mobile/simtc/test/ui/add_participant/add_participant_viewmodel_test.dart
git commit -m "fix(mobile): consulta de cpf trava os campos, tem limite de tempo e respeita a conexao"
```

---

## Task 14: 1.12 — a pergunta da data antiga, e a faixa de "salvar e cancelar"

Dois acertos em "Dados do treinamento" (decisões 6 e 13):

- **Data antiga:** a lista de sessões só baixa as dos últimos 90 dias, e o calendário da tela começa em 2020. Um toque errado no ano fazia a sessão — mesmo em andamento — sumir da lista de todos os aparelhos no próximo sync, sem aviso, e só o painel web consertava. Agora, salvar uma data que o admin **mudou** para antes dessa janela pede confirmação. A data antiga que já estava lá não pergunta nada.
- **Faixa:** sem conexão, a faixa dizia só "salvar precisa de internet", e o "Cancelar sessão" ficava apagado sem motivo escrito.

A janela é a mesma constante da lista (`SessionRepository.historyWindowDays`, que passa a ser pública). Como a pergunta depende de "hoje", a tela ganha um relógio que só os testes trocam — como a aba Sincronizar.

**Files:**
- Modify: `lib/data/repositories/session_repository.dart`
- Modify: `lib/ui/session_edit/session_edit_viewmodel.dart`
- Modify: `lib/ui/session_edit/session_edit_screen.dart`
- Modify: `test/ui/session_edit/session_edit_viewmodel_test.dart`
- Modify: `test/ui/session_edit/session_edit_screen_test.dart`

**Interfaces:**
- Consumes: `SessionRepository._historyWindowDays` e o cálculo do `from` no `syncAll`; `SessionEditViewModel._date`, `_dateChanged`, `save()`; `SessionEditScreen._save`.
- Produces:
  - `static const int SessionRepository.historyWindowDays` = 90 (pública).
  - `SessionEditViewModel({..., DateTime Function()? now})`; `bool dateLeavesTheList` — a data foi mudada, e a nova é anterior ao primeiro dia da janela.
  - `SessionEditScreen({required String sessionId, DateTime Function()? clock})`.
  - Diálogo: "Esta data é de mais de 90 dias atrás." / "A sessão vai sair da lista do app em todos os aparelhos; depois disso, só o painel web consegue alterá-la. Salvar assim mesmo?" / "Voltar" e "Salvar".
  - Faixa de offline: "Sem conexão — salvar e cancelar precisam de internet."

- [ ] **Step 1: Escrever os testes que falham**

**Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:**

```dart
    WidgetTester tester, {
    Size screen = const Size(412, 1400),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
```

**por:**

```dart
    WidgetTester tester, {
    Size screen = const Size(412, 1400),
    double textScale = 1,
    DateTime Function()? clock,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
```

**Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:**

```dart
          path: '/sessions/:sessionId/edit',
          builder: (context, state) => SessionEditScreen(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
      ],
```

**por:**

```dart
          path: '/sessions/:sessionId/edit',
          builder: (context, state) => SessionEditScreen(
            sessionId: state.pathParameters['sessionId']!,
            clock: clock,
          ),
        ),
      ],
```

**Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:**

```dart
    await tester.pumpAndSettle();

    expect(sentBody(), {'date': '2026-09-15'});
  });

  testWidgets(
```

**por:**

```dart
    await tester.pumpAndSettle();

    expect(sentBody(), {'date': '2026-09-15'});
  });

  // A lista de sessões só baixa as dos últimos 90 dias (decisão de
  // 09/10/2026). A sessão dos testes é de 12/09/2026.
  group('data com mais de 90 dias', () {
    const title = 'Esta data é de mais de 90 dias atrás.';
    const warning =
        'A sessão vai sair da lista do app em todos os aparelhos; depois '
        'disso, só o painel web consegue alterá-la. Salvar assim mesmo?';

    /// Troca a data para o dia 15 do mês da sessão e toca em "Salvar
    /// alterações".
    Future<void> pickDay15AndSave(WidgetTester tester) async {
      await tester.tapAt(tester.getCenter(find.text('12 set 2026')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
    }

    testWidgets('mudar a data para antes da janela pergunta antes de salvar; '
        '"Voltar" não salva e deixa a tela como estava', (tester) async {
      await seedSession();
      patchAnswers();
      // Em 20/01/2027, a janela começa em 22/10/2026.
      await pumpEdit(tester, clock: () => DateTime(2027, 1, 20, 9));

      await pickDay15AndSave(tester);

      final dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text(title)), findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text(warning)), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SessionEditScreen), findsOneWidget);
      expect(find.text('15 set 2026'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);
      verifyNever(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')));
    });

    testWidgets('confirmando, salva a data antiga e fecha a tela', (tester) async {
      await seedSession();
      patchAnswers();
      await pumpEdit(tester, clock: () => DateTime(2027, 1, 20, 9));

      await pickDay15AndSave(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(sentBody(), {'date': '2026-09-15'});
      expect(find.text('origem'), findsOneWidget);
      expect(find.text('Dados do treinamento atualizados.'), findsOneWidget);
    });

    testWidgets('data dentro da janela salva direto, sem perguntar',
        (tester) async {
      await seedSession();
      patchAnswers();
      // Em 20/09/2026, 15/09 é da semana passada.
      await pumpEdit(tester, clock: () => DateTime(2026, 9, 20, 9));

      await pickDay15AndSave(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(sentBody(), {'date': '2026-09-15'});
      expect(find.text('origem'), findsOneWidget);
    });

    testWidgets(
        'a data antiga já estava lá: mudar só a cidade salva direto, sem '
        'perguntar', (tester) async {
      await seedSession();
      patchAnswers();
      await pumpEdit(tester, clock: () => DateTime(2027, 1, 20, 9));

      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(sentBody(), {'city': 'Betim'});
    });

    testWidgets(
        'num celular de 360x640 com a fonte ampliada, a pergunta cabe na tela',
        (tester) async {
      await seedSession();
      patchAnswers();
      await pumpEdit(
        tester,
        screen: const Size(360, 640),
        textScale: 1.3,
        clock: () => DateTime(2027, 1, 20, 9),
      );

      await pickDay15AndSave(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(title), findsOneWidget);
      final save = tester.getRect(find.widgetWithText(FilledButton, 'Salvar'));
      expect(save.bottom, lessThanOrEqualTo(640));
    });
  });

  testWidgets(
```

**Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:**

```dart
    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();

    expect(find.text('Sem conexão — salvar precisa de internet.'), findsOneWidget);
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(cancelButton(tester).onPressed, isNull);
```

**por:**

```dart
    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();

    expect(
      find.text('Sem conexão — salvar e cancelar precisam de internet.'),
      findsOneWidget,
    );
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(cancelButton(tester).onPressed, isNull);
```

**Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:**

```dart
    expect(tester.takeException(), isNull);
    expect(find.text('Disponível quando houver conexão'), findsNothing);
    // O motivo segue escrito na faixa do topo, e os botões seguem apagados.
    expect(find.text('Sem conexão — salvar precisa de internet.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(find.widgetWithText(AppTextButton, 'Descartar'), findsOneWidget);
```

**por:**

```dart
    expect(tester.takeException(), isNull);
    expect(find.text('Disponível quando houver conexão'), findsNothing);
    // O motivo segue escrito na faixa do topo, e os botões seguem apagados.
    expect(
      find.text('Sem conexão — salvar e cancelar precisam de internet.'),
      findsOneWidget,
    );
    expect(saveButton(tester).onPressed, isNull);
    expect(find.widgetWithText(AppTextButton, 'Descartar'), findsOneWidget);
```

**Em `test/ui/session_edit/session_edit_screen_test.dart`, substituir:**

```dart
    changes.add([ConnectivityResult.mobile]);
    await tester.pumpAndSettle();

    expect(find.text('Sem conexão — salvar precisa de internet.'), findsNothing);
    expect(find.text('Betim'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    expect(cancelButton(tester).onPressed, isNotNull);
```

**por:**

```dart
    changes.add([ConnectivityResult.mobile]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Sem conexão'), findsNothing);
    expect(find.text('Betim'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    expect(cancelButton(tester).onPressed, isNotNull);
```

**Em `test/ui/session_edit/session_edit_viewmodel_test.dart`, substituir:**

```dart
    AuthUser? user = admin,
    TrainingSession? withSession,
    bool missing = false,
  }) async {
    final vm = SessionEditViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      currentUser: user,
    )..init();
    addTearDown(vm.dispose);
    sessionStream.add(missing ? null : (withSession ?? session()));
```

**por:**

```dart
    AuthUser? user = admin,
    TrainingSession? withSession,
    bool missing = false,
    DateTime Function()? now,
  }) async {
    final vm = SessionEditViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      currentUser: user,
      now: now,
    )..init();
    addTearDown(vm.dispose);
    sessionStream.add(missing ? null : (withSession ?? session()));
```

**Em `test/ui/session_edit/session_edit_viewmodel_test.dart`, substituir:**

```dart

      expect(vm.city, 'Betim');
      expect(vm.notes, 'Pátio 3 — portaria B.');
    });
  });
```

**por:**

```dart

      expect(vm.city, 'Betim');
      expect(vm.notes, 'Pátio 3 — portaria B.');
    });
  });

  // A lista de sessões só baixa as dos últimos 90 dias: uma data mais antiga
  // tira a sessão do app em todos os aparelhos (decisão de 09/10/2026).
  group('data antiga', () {
    // "Hoje" é 20/01/2027: a janela da lista começa em 22/10/2026.
    DateTime today() => DateTime(2027, 1, 20, 14, 30);

    test('a janela é a mesma da lista de sessões', () {
      expect(SessionRepository.historyWindowDays, 90);
    });

    test('data mudada para antes da janela pede confirmação', () async {
      final vm = await open(
        withSession: session(date: DateTime(2027, 1, 10)),
        now: today,
      );
      expect(vm.dateLeavesTheList, isFalse, reason: 'nada mudou ainda');

      vm.setDate(DateTime(2026, 10, 21));

      expect(vm.dateLeavesTheList, isTrue);
      expect(vm.canSave, isTrue, reason: 'a pergunta é da tela; salvar pode');
    });

    test('o primeiro dia da janela ainda está na lista; a véspera, não',
        () async {
      final vm = await open(
        withSession: session(date: DateTime(2027, 1, 10)),
        now: today,
      );

      vm.setDate(DateTime(2026, 10, 22));
      expect(vm.dateLeavesTheList, isFalse);

      vm.setDate(DateTime(2026, 10, 21));
      expect(vm.dateLeavesTheList, isTrue);
    });

    test('data recente ou futura não pergunta nada', () async {
      final vm = await open(
        withSession: session(date: DateTime(2027, 1, 10)),
        now: today,
      );

      vm.setDate(DateTime(2027, 1, 5));
      expect(vm.dateLeavesTheList, isFalse);

      vm.setDate(DateTime(2027, 6, 1));
      expect(vm.dateLeavesTheList, isFalse);
    });

    test('sessão que já tinha data antiga não pergunta ao mudar só outro campo',
        () async {
      final vm = await open(
        withSession: session(date: DateTime(2026, 5, 3)),
        now: today,
      );

      vm.setCity('Betim');

      expect(vm.isDirty, isTrue);
      expect(vm.dateLeavesTheList, isFalse);
    });

    test('escolher de novo o mesmo dia antigo não é mudança', () async {
      final vm = await open(
        withSession: session(date: DateTime(2026, 5, 3)),
        now: today,
      );

      vm.setDate(DateTime(2026, 5, 3, 9));

      expect(vm.dateLeavesTheList, isFalse);
    });

    test('trocar uma data antiga por outra data antiga pergunta', () async {
      final vm = await open(
        withSession: session(date: DateTime(2026, 5, 3)),
        now: today,
      );

      vm.setDate(DateTime(2026, 5, 4));

      expect(vm.dateLeavesTheList, isTrue);
    });

    test('sessão sem data, sem data escolhida: nada a perguntar', () async {
      final vm = await open(withSession: session(withoutDate: true), now: today);

      vm.setCity('Betim');

      expect(vm.dateLeavesTheList, isFalse);
    });

    test('sessão sem data que ganha uma data antiga pergunta', () async {
      final vm = await open(withSession: session(withoutDate: true), now: today);

      vm.setDate(DateTime(2026, 3, 1));

      expect(vm.dateLeavesTheList, isTrue);
    });
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_edit test/data/repositories/session_repository_test.dart`
Esperado: os dois arquivos da 1.12 não compilam — `No named parameter with the name 'now'`, `Member not found: 'historyWindowDays'` e `The getter 'dateLeavesTheList' isn't defined for the type 'SessionEditViewModel'` no da ViewModel; `No named parameter with the name 'clock'` no da tela. O `session_repository_test.dart` já passa, e tem de continuar passando depois do Step 3.

- [ ] **Step 3: Implementar**

**Em `lib/data/repositories/session_repository.dart`, substituir:**

```dart
  /// web — baixar o histórico inteiro faria o admin, que recebe todas as sessões
  /// do sistema, estourar o teto de páginas e ficar com uma lista parcial em
  /// silêncio. Decidido com o usuário em 20/09/2026.
  static const int _historyWindowDays = 90;

  static const String _offlineMessage =
      'Não foi possível atualizar. Mostrando os dados já baixados.';
```

**por:**

```dart
  /// web — baixar o histórico inteiro faria o admin, que recebe todas as sessões
  /// do sistema, estourar o teto de páginas e ficar com uma lista parcial em
  /// silêncio. Decidido com o usuário em 20/09/2026.
  ///
  /// Pública porque "Dados do treinamento" usa a mesma janela para avisar
  /// quando uma data nova tira a sessão desta lista (Fase 6B).
  static const int historyWindowDays = 90;

  static const String _offlineMessage =
      'Não foi possível atualizar. Mostrando os dados já baixados.';
```

**Em `lib/data/repositories/session_repository.dart`, substituir:**

```dart
    // Calculado uma vez antes do laço: uma virada de meia-noite no meio do
    // sync não pode mudar o filtro entre páginas.
    final from = DateTime.now().subtract(
      const Duration(days: _historyWindowDays),
    );

    try {
```

**por:**

```dart
    // Calculado uma vez antes do laço: uma virada de meia-noite no meio do
    // sync não pode mudar o filtro entre páginas.
    final from = DateTime.now().subtract(
      const Duration(days: historyWindowDays),
    );

    try {
```

**Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:**

```dart
/// tem horário), "Local" virou "Cidade" + "UF" (é como o backend guarda) e
/// sem o contador das observações (o backend não limita).
class SessionEditScreen extends StatefulWidget {
  const SessionEditScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionEditScreen> createState() => _SessionEditScreenState();
```

**por:**

```dart
/// tem horário), "Local" virou "Cidade" + "UF" (é como o backend guarda) e
/// sem o contador das observações (o backend não limita).
class SessionEditScreen extends StatefulWidget {
  const SessionEditScreen({super.key, required this.sessionId, this.clock});

  final String sessionId;

  /// O relógio da tela — só os testes passam outro. É dele que sai a pergunta
  /// da data com mais de 90 dias.
  final DateTime Function()? clock;

  @override
  State<SessionEditScreen> createState() => _SessionEditScreenState();
```

**Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:**

```dart
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    currentUser: context.read<AuthRepository>().currentUser,
  )..init();

  final TextEditingController _dateController = TextEditingController();
```

**por:**

```dart
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    currentUser: context.read<AuthRepository>().currentUser,
    now: widget.clock,
  )..init();

  final TextEditingController _dateController = TextEditingController();
```

**Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:**

```dart
              ),
              ConnectivityBanner(
                isOffline: isOffline,
                message: 'Sem conexão — salvar precisa de internet.',
              ),
              Expanded(child: _buildBody(isOffline)),
              if (_viewModel.session != null)
```

**por:**

```dart
              ),
              ConnectivityBanner(
                isOffline: isOffline,
                message: 'Sem conexão — salvar e cancelar precisam de internet.',
              ),
              Expanded(child: _buildBody(isOffline)),
              if (_viewModel.session != null)
```

**Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:**

```dart

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await _viewModel.save();
    if (!saved || !mounted) return;
```

**por:**

```dart

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_viewModel.dateLeavesTheList && !await _confirmOldDate()) return;
    if (!mounted) return;
    final saved = await _viewModel.save();
    if (!saved || !mounted) return;
```

**Em `lib/ui/session_edit/session_edit_screen.dart`, substituir:**

```dart
      const SnackBar(content: Text('Dados do treinamento atualizados.')),
    );
    Navigator.of(context).pop(true);
  }

  /// "Descartar" é um pedido explícito: sai sem perguntar.
```

**por:**

```dart
      const SnackBar(content: Text('Dados do treinamento atualizados.')),
    );
    Navigator.of(context).pop(true);
  }

  /// Um toque errado no ano tiraria a sessão — mesmo em andamento — da lista
  /// de todos os aparelhos, sem aviso (decisão de 09/10/2026 — não está no
  /// canvas). Só pergunta quando a data foi mudada para antes da janela.
  Future<bool> _confirmOldDate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Esta data é de mais de ${SessionRepository.historyWindowDays} dias '
          'atrás.',
        ),
        content: const Text(
          'A sessão vai sair da lista do app em todos os aparelhos; depois '
          'disso, só o painel web consegue alterá-la. Salvar assim mesmo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// "Descartar" é um pedido explícito: sai sem perguntar.
```

**Em `lib/ui/session_edit/session_edit_viewmodel.dart`, substituir:**

```dart
    required SessionRepository sessionRepository,
    required ParticipantRepository participantRepository,
    required AuthUser? currentUser,
  })  : _sessionRepository = sessionRepository,
        _participantRepository = participantRepository,
        _currentUser = currentUser;

  final String sessionId;
  final SessionRepository _sessionRepository;
  final ParticipantRepository _participantRepository;
  final AuthUser? _currentUser;

  static const String _saveFailed =
      'Não foi possível salvar as alterações. Tente de novo.';
```

**por:**

```dart
    required SessionRepository sessionRepository,
    required ParticipantRepository participantRepository,
    required AuthUser? currentUser,
    DateTime Function()? now,
  })  : _sessionRepository = sessionRepository,
        _participantRepository = participantRepository,
        _currentUser = currentUser,
        _now = now ?? DateTime.now;

  final String sessionId;
  final SessionRepository _sessionRepository;
  final ParticipantRepository _participantRepository;
  final AuthUser? _currentUser;
  final DateTime Function() _now;

  static const String _saveFailed =
      'Não foi possível salvar as alterações. Tente de novo.';
```

**Em `lib/ui/session_edit/session_edit_viewmodel.dart`, substituir:**

```dart

  bool get canSave =>
      canEdit && isDirty && cityError == null && stateError == null && !isBusy;

  /// Assina o cache. Chamado uma vez pela tela.
  void init() {
```

**por:**

```dart

  bool get canSave =>
      canEdit && isDirty && cityError == null && stateError == null && !isBusy;

  /// A data foi mudada para antes da janela da lista de sessões (decisão de
  /// 09/10/2026). A lista só baixa as dos últimos
  /// [SessionRepository.historyWindowDays] dias: com uma data mais antiga, a
  /// sessão some dela em todos os aparelhos no próximo sync, e só o painel web
  /// consegue alterá-la depois. A tela pede confirmação antes de salvar. Só
  /// conta a data que o admin mudou — a que já era antiga não pergunta nada.
  bool get dateLeavesTheList {
    final date = _date;
    if (date == null || !_dateChanged) return false;
    // O mesmo cálculo do `SessionRepository.syncAll`.
    final from = _now().subtract(
      const Duration(days: SessionRepository.historyWindowDays),
    );
    return date.isBefore(DateTime(from.year, from.month, from.day));
  }

  /// Assina o cache. Chamado uma vez pela tela.
  void init() {
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_edit test/data/repositories/session_repository_test.dart`
Esperado: `+102: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+920: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/data/repositories/session_repository.dart \
  apps/mobile/simtc/lib/ui/session_edit/session_edit_screen.dart \
  apps/mobile/simtc/lib/ui/session_edit/session_edit_viewmodel.dart \
  apps/mobile/simtc/test/ui/session_edit/session_edit_screen_test.dart \
  apps/mobile/simtc/test/ui/session_edit/session_edit_viewmodel_test.dart
git commit -m "fix(mobile): confirmacao de data antiga e faixa de salvar e cancelar na 1.12"
```

---

## Task 15: Validação no aparelho físico

Esta task é o portão da fase: sem ela, a Fase 7 não é planejada (decisão do usuário, registrada em 17/09/2026). É o roteiro que só o usuário pode rodar.

**Files:** nenhum arquivo de código.

**Interfaces:**
- Consumes: o app inteiro e o backend com as Tasks 1 a 3.
- Produces: o aval do usuário para planejar a Fase 7.

- [ ] **Step 1: Subir o backend com as mudanças e liberar a porta**

Run: `cd apps/backend && npm run start:dev`

Em outro terminal, com o aparelho conectado: `adb reverse tcp:3001 tcp:3001` (o id do aparelho sai de `adb devices`).

- [ ] **Step 2: Instalar no aparelho**

Run (em `apps/mobile/simtc`): `flutter pub get` e `flutter run -d <ID_DO_APARELHO>`

Sem `--dart-define`. **Instale por cima, sem desinstalar**: é o que exercita a migração do banco (v4 → v5).

- [ ] **Step 3: Percorrer o roteiro de aceite**

Preparação, com rede: um usuário **ADMIN que também é consultor** e um **consultor comum** (dá para alternar o login no mesmo aparelho); uma sessão "Em andamento" com pelo menos quatro participantes, dois consultores além do responsável e, na equipe, pelo menos um consultor ativo que não está nela; uma sessão **de teste**, que possa ter a data estragada; e o painel web à mão.

Logo depois de instalar por cima, **antes de abrir qualquer sessão com rede**:
- [ ] em modo avião, abra uma sessão que já estava no aparelho: o detalhe abre como antes, sem "0 consultores" no cabeçalho; o ícone de pessoas abre a tela de Consultores com o aviso "Os consultores desta sessão ainda não foram baixados…";
- [ ] volte a rede e puxe para atualizar: a contagem aparece no detalhe, e os consultores, na tela.

Detalhe da sessão, como ADMIN:
- [ ] a barra mostra o lápis, o ícone de pessoas e o indicador de envio, nessa ordem; o cabeçalho mostra "N consultores" depois da data;
- [ ] **offline** (modo avião + `adb -s <ID> reverse --remove tcp:3001`): o lápis apaga, e o ícone de pessoas continua ligado;
- [ ] como consultor comum: nem o ícone de pessoas nem a contagem aparecem.

Tela de Consultores, como ADMIN:
- [ ] a faixa de contexto mostra "Empresa · dia mês" e "N participantes · N consultores"; em "Na sessão", o responsável vem primeiro, com a pastilha "Responsável" e sem o "Remover da sessão"; o seu nome leva "(você)"; cada linha diz quantos participantes tem e quantos em andamento;
- [ ] "Disponíveis na equipe" mostra quem é da equipe e não está na sessão, com o e-mail e o "Adicionar"; no fim, a nota "Entrar e sair da sessão vale na hora…"; não há lupa na barra;
- [ ] "Adicionar": o botão gira, os outros travam, aparece "Fulano entrou na sessão.", e ele passa para "Na sessão" — no painel web, também;
- [ ] "Remover da sessão" de quem **não tem** avaliação em andamento: sai no toque, com "Fulano saiu da sessão.", e volta para a equipe;
- [ ] com o consultor comum avaliando alguém (atribua e inicie uma avaliação com o login dele): a linha dele mostra "Tem 1 avaliação em andamento. Remover devolve Fulano para Pendente."; "Remover da sessão" abre o diálogo "Remover Fulano da sessão?"; "Voltar" não remove; "Remover" tira o consultor, e no detalhe o participante volta para "Pendente" — no painel web, também;
- [ ] **offline** com a tela aberta: a faixa "Sem conexão — mudar os consultores precisa de internet.", os botões à vista e apagados; a equipe que já estava na tela continua; volte a rede: os botões voltam;
- [ ] abrindo a tela **já offline**: no lugar da equipe, "A equipe aparece quando houver conexão."; ao voltar a rede, ela carrega sozinha;
- [ ] numa sessão **concluída**: a tela abre só para leitura, com "Sessão concluída: os consultores não podem mais ser alterados." e os botões apagados;
- [ ] puxar a lista para baixo atualiza a tela.

Pelo painel web (a mesma regra vale lá):
- [ ] com um consultor avaliando alguém, edite a sessão no painel e tire esse consultor da lista: no app, depois de atualizar o detalhe, o participante está "Pendente" e sem consultor;
- [ ] avaliar um participante pelo painel (atribuir e salvar a avaliação) continua funcionando como antes.

Desatribuir pelo ⋮, como ADMIN:
- [ ] a linha de um participante em avaliação com **outro** consultor tem um ⋮ à direita do chip; as suas e as pendentes, não;
- [ ] ⋮ → "Desatribuir participante": o diálogo diz "Desatribuir Fulano?" e "Está em avaliação com Beltrano. Ao desatribuir, volta para Pendente…"; "Voltar" não faz nada; "Desatribuir" mostra "Fulano foi desatribuído.", e a linha vira "Pendente";
- [ ] **offline**: o ⋮ continua à vista, apagado, e não abre;
- [ ] como consultor comum: a linha de quem está com outro consultor não tem ⋮.

Avaliação que volta, como consultor comum:
- [ ] atribua um participante, inicie a avaliação e marque duas notas; saia do checklist. Como ADMIN (ou pelo painel), desatribua esse participante. De volta ao login do consultor: atualize o detalhe, toque em "Atribuir a mim" no mesmo participante e abra o checklist — as duas notas e a hora de início de antes estão lá;
- [ ] com um participante "Não recomendado": Resultado → "Reavaliar" → "Iniciar avaliação", marque uma nota e saia. O ADMIN desatribui. O consultor atualiza o detalhe e vai de novo por Resultado → "Reavaliar": a tela diz "Você começou esta avaliação em dd/mm às hh:mm." e "As respostas voltam ao continuar.", com o botão "Continuar avaliação"; o toque reabre o checklist com a nota marcada;
- [ ] na mesma tela de "continuar", o ⋮ oferece "Descartar avaliação"; depois de descartar, a tela volta a "A avaliação ainda não começou.";
- [ ] **uma por vez:** com uma avaliação parada (participante desatribuído), inicie a de outro participante; faça o primeiro voltar ("Atribuir a mim") e abra o checklist dele: aparece "Você já está avaliando Fulano…" e o "Continuar avaliação" fica apagado; finalize (ou descarte) a outra, e a primeira abre direto;
- [ ] **checklist aberto na hora da liberação:** com o checklist de um participante aberto, o ADMIN o desatribui pelo painel; no aparelho, ligue e desligue o modo avião (a volta da rede atualiza o detalhe que está embaixo): o rodapé mostra "Este participante não está mais com você. Atribua de novo para continuar.", e o "Finalizar avaliação" apaga.

Envio recusado, como consultor comum:
- [ ] inicie a avaliação de um participante; ponha o aparelho em modo avião; pelo painel, o ADMIN tira esse consultor da sessão (ou desatribui o participante). No aparelho, ainda offline, finalize e confirme a avaliação. Volte a rede: na aba Sincronizar, o item aparece com "Falhou às hh:mm · o participante não está mais com você", com "Tentar novamente" e "Descartar"; "Descartar" o tira da fila. No painel, o participante continua sem essa avaliação.

Adicionar participante (1.11):
- [ ] digite um CPF válido: enquanto aparece "Consultando o CPF…", os campos de nome e e-mail ficam apagados (com a rede boa, é um instante); o CPF continua editável;
- [ ] digite o CPF e toque logo no "próximo" do teclado: anote o que acontece com o teclado e com o foco enquanto a consulta dura (nome e e-mail estão travados nesse instante);
- [ ] **offline**: digite um CPF completo e válido — não aparece "Não foi possível consultar o CPF…"; ficam a faixa do topo e "Disponível quando houver conexão";
- [ ] ainda com esse CPF no campo (use o de alguém que já fez outro treinamento), volte a rede: a consulta roda sozinha, e nome e e-mail aparecem preenchidos.

Dados do treinamento (1.12), na sessão de teste:
- [ ] mude a data para mais de 90 dias atrás e toque em "Salvar alterações": o diálogo "Esta data é de mais de 90 dias atrás." aparece; "Voltar" não salva, e a data escolhida continua no campo; "Salvar" salva — e, ao atualizar a lista de sessões, a sessão some do app (o painel web a conserta);
- [ ] mudar só a cidade de uma sessão salva direto, sem pergunta;
- [ ] **offline**: a faixa diz "Sem conexão — salvar e cancelar precisam de internet."

Regressões:
- [ ] "Atribuir a mim", o checklist, a conferência, o Resultado e a aba "Sincronizar" continuam como na 6A, para o consultor comum;
- [ ] o ⋮ do checklist ("Descartar avaliação" e "Desatribuir participante") continua como antes para os participantes do próprio consultor;
- [ ] o lápis e o "adicionar participante" do detalhe continuam como na 6A.

Visual (ver "Ajustes feitos ao preparar o plano"):
- [ ] a tela de Consultores contra o quadro `3c`: as pastilhas, o aviso âmbar, os dois botões e a linha dupla entre as linhas;
- [ ] a linha com ⋮ no detalhe: o ícone alinhado com a margem da lista;
- [ ] a tela de Consultores e a de "continuar" numa tela estreita ou com a fonte do sistema ampliada.

**Não verificável neste aparelho, e por quê:** dois toques rápidos e o voltar com o envio no ar dependem de uma resposta lenta que a rede local não dá — ficam cobertos pelos testes das Tasks 7, 8 e 10; a recusa do servidor com a tela aberta (alguém conclui a sessão, ou desativa o consultor, entre abrir a tela e tocar no botão) depende de coordenar dois aparelhos no mesmo segundo — Task 7; o limite de 8 segundos da consulta de CPF só aparece com o servidor lento — Task 13; o reenvio de uma avaliação já aceita cuja resposta se perdeu não tem como ser provocado pela interface — Task 3; a tela de Consultores aberta por quem não é ADMIN não tem caminho pela interface — Tasks 7 e 8; e dois ADMINs mexendo nos consultores ao mesmo tempo — Task 1 (um consultor por chamada).

- [ ] **Step 4: Registrar o resultado**

Se tudo passar, avisar o usuário e pedir o aval para planejar a Fase 7. Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio ou de contrato do backend, parar e perguntar.

---

## Pendências levadas para as fases seguintes

Resolvidas nesta fase: as quatro pendências "6B" do plano da 6A (a tela de Consultores com a contagem e o ícone, liberar os participantes ao remover um consultor, o desatribuir do ADMIN e a avaliação presa que volta pelo "Reavaliar"); as "Decisões em aberto" 1 a 4 da 6A; a pendência "8" de lá sobre a consulta de CPF que não era refeita quando a rede voltava; e, na auditoria da Fase 0, a pendência "5" sobre o `sync` não validar a atribuição e as duas pendências "6" sobre os consultores da sessão.

| Fase | Pendência |
|---|---|
| Web | O painel trata o `POST /practical-assessments/sync` como salvo com qualquer resposta 2xx e não lê o resultado item a item (`assessment-drawer.tsx`, linha 182): com a regra nova, uma avaliação recusada aparece como salva. Só acontece se o participante for liberado com o checklist do painel já aberto. Ler `status`, `error` e `code` de cada item. |
| Web | O painel não avisa quando tirar um consultor da sessão vai liberar participantes em avaliação com ele (o app avisa). |
| 7 | A tela de Consultores no tablet (quadros `4n` e `4y`: diálogo ancorado e retrato). |
| 8 | A busca da tela de Consultores (a lupa do quadro `3c`), com as das outras telas. |
| 8 | As quatro decisões visuais em aberto da 6A (5 a 8 de lá) — e as medidas que a tela de Consultores herdou das mesmas peças: a faixa de contexto, os avisos, as cores dos tons e o contorno do "Remover da sessão" (ver "Ajustes"). |
| 8 | O "Atribuir a mim" tem canto 12, e o quadro o desenha com 10 — os botões compactos novos já saíram com 10. |
| 8 | Quando o consultor é tirado da sessão com o checklist aberto, o app não tem como saber (a sessão sai do aparelho, e o participante some do cache): o "Finalizar avaliação" continua valendo, e a recusa só aparece na aba Sincronizar. |
| 8 | Com o participante liberado e o checklist aberto, as notas continuam marcáveis; e o "Atribua de novo" exige voltar ao detalhe. |
| 8 | Na 1.11, com nome e e-mail travados durante a consulta do CPF, o "próximo" do teclado não tem para onde ir; avaliar levar o foco ao nome quando a consulta termina sem cadastro. |
| 8 | A tela de Consultores não mostra quais participantes estão com cada consultor, só a contagem. |
| 8 | Limpeza: o diálogo de confirmação e o aviso passageiro continuam repetidos em cada tela (pendência da 5B e da 6A); a tela de Consultores e o detalhe repetem o indicador de carregamento pequeno. |
| Backend | O `unassign` não confere o status da sessão: pela API, um ADMIN desatribui um participante de uma sessão concluída (o app apaga o ⋮ nesse caso). |
| Backend | Pela leitura do código, o `PATCH :id` que troca o `responsibleConsultantId` **sem** mandar `additionalConsultantsIds` não recria os vínculos da sessão: o responsável antigo continua como consultor dela (e ninguém é liberado), e o novo pode ficar sem vínculo. Com a lista, vale a lista nova. Não foi exercitado nesta fase. |
| Backend | `cancelSession` não mexe nos participantes: quem estava "em avaliação" continua assim numa sessão cancelada (pendência da 6A). |
| Backend | A agenda do consultor ("Sem sessão hoje", "Empilhadeira · Betim 13:00" no quadro `3c`) não existe no contrato. |
| — | Canvas: a 1.13 com o e-mail no lugar da agenda, sem a lupa, com o diálogo de remover e os estados sem conexão, carregando e sem equipe; o detalhe com o ⋮ e o diálogo de desatribuir; o checklist com a tela de "continuar" e o aviso de liberado; a 1.12 com a pergunta da data antiga. Atualizar no Claude Design. |

As pendências da Fase 8 que vieram da 5A, da 5B e da 6A e não estão acima continuam valendo como estão nos planos delas.
