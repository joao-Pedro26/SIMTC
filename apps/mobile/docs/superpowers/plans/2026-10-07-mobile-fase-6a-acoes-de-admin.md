# App Mobile SIMTC — Fase 6A: Ações de ADMIN (dados do treinamento e adicionar participante) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Um ADMIN passa a editar os dados do treinamento (data, cidade, UF e observações), cancelar a sessão e adicionar participantes — com busca do cadastro pelo CPF — direto do detalhe da sessão, no celular. Junto, a regra de "uma avaliação por vez" deixa de ser travada por uma avaliação iniciada que o consultor não consegue mais abrir.

**Architecture:** Duas telas cheias novas, cada uma com rota e ViewModel próprios, abertas por dois ícones que só o ADMIN vê no detalhe da sessão. Os repositórios que já existem ganham as chamadas: `SessionRepository.update`/`cancel` (`PATCH /training-sessions/:id` e `/cancel`, que já existiam) e `ParticipantRepository.lookupCpf`/`add` (o endpoint novo `POST /training-sessions/:id/participants/lookup` e o `POST …/participants`, que já existia). Depois do sucesso, o repositório grava no cache e o detalhe baixa a sessão de novo — o mesmo padrão do "Atribuir a mim". A avaliação presa é resolvida num lugar só: a consulta do `AssessmentRepository` que o checklist já usa.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · drift 2.31.0 (**sem mudança de esquema**: continua v4) · dio · mocktail (testes) · backend NestJS + Prisma, testes com jest. **Uma mudança de dependência no app:** entra `flutter_localizations` (pacote do próprio SDK) e o `intl` sobe de `^0.19.0` para `^0.20.2`, a versão que o SDK exige — o app declara o `intl`, mas não o importa em lugar nenhum. No backend, um endpoint novo e nenhuma migração.

**Spec:** `brainstorm-implementacao-mobile.md` → "Fase 6 — Ações administrativas inline" (dividida em 6A e 6B em 06/10/2026; esta é a 6A) e `brainstorm-app-mobile.md` (telas 1.4.1 e 1.4.2; premissas 11 a 13); canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html`, quadros `1f` "1.4 Detalhe da Sessão · variante ADMIN" (linhas 951–1048), `3a` "1.11 Adicionar participante" (464–541) e `3b` "1.12 Dados do treinamento" (543–616); contratos no backend em `apps/backend/src/training-sessions/` e `apps/backend/src/participants/`; pendências marcadas "6" em `apps/mobile/docs/fase-0-auditoria.md` e a "decisão em aberto" nº 1 do plano da 5B (`2026-10-03-mobile-fase-5b-resultado.md`). O desenho aprovado em 06 e 07/10/2026 está em "Decisões tomadas com o usuário" — a trilha mobile não usa doc de spec separado, o plano é o documento.

**Validação prévia:** todo o código deste plano foi escrito e rodado numa cópia descartável do repositório (app e backend) antes de o plano ser fechado, uma task por commit, e depois as tasks foram **reencenadas em ordem** numa segunda cópia limpa: em cada task, os testes falharam antes da implementação pelo motivo descrito no passo "Esperado", e cada checkpoint bateu o número de testes — no app, **484 → 486 → 505 → 515 → 537 → 545 → 577 → 601 → 634 → 660 → 676**, com `flutter analyze` sem issues em todos; no backend, **74 → 82** (com as 12 falhas antigas de sempre). Os blocos de código foram gerados da primeira cópia por um script que confere cada "substituir / por" contra o estado deixado pela task anterior, e um segundo script aplicou o plano inteiro, como um executor faria — achando os blocos pelos títulos dos passos —, e conferiu que a árvore de arquivos de cada task ficou idêntica à do commit correspondente: o que está aqui é, byte a byte, o código que passou. (O passo da auditoria, na Task 1, é só documentação e ficou fora das cópias.)

## Decisões tomadas com o usuário

Em 06/10/2026, no brainstorm da fase (duas rodadas de perguntas):

1. **A Fase 6 foi dividida em 6A e 6B**, cada uma validada no aparelho. **6A (este plano):** a variante ADMIN do detalhe da sessão, "Dados do treinamento" (com "Cancelar sessão"), "Adicionar participante" e o ajuste da avaliação presa. **6B:** a tela de Consultores da sessão, o "N consultores" do cabeçalho, liberar os participantes ao remover um consultor e o desatribuir do ADMIN.
2. **"Cancelar sessão" entra, com confirmação.** Está no canvas (quadro `3b`) e não estava no roteiro da fase. O endpoint já existia (`PATCH /training-sessions/:id/cancel`, só ADMIN; recusa sessão concluída) e não há como desfazer. O diálogo diz a consequência antes do toque e quantos participantes estão em avaliação naquele momento; depois, o app vai para a lista de sessões — a sessão cancelada some da Home (decisão 7 da Fase 2).
3. **O campo "Consultor responsável" sai da 1.11.** O backend só atribui participante ao próprio usuário logado; atribuir a outro consultor não existe, nem no painel web. O participante entra "Pendente", e quem for avaliar toca em "Atribuir a mim".
4. **CPF de quem já tem cadastro: buscar pelo CPF** (a auditoria da Fase 0 deixou a escolha para esta fase). Endpoint novo, só ADMIN. O CPF passa a ser o primeiro campo; completo e válido, o app consulta o servidor. Se a pessoa já tem cadastro de outro treinamento, nome e e-mail aparecem preenchidos e continuam editáveis — o que estiver na tela ao adicionar é o que o backend grava no cadastro, como já fazia. Se o CPF já está nesta sessão, o aviso aparece antes do toque. Recusado: o formulário simples do canvas e do web, em que o admin redigita tudo e um nome digitado diferente troca o do cadastro.
5. **Avaliação presa: parar de bloquear, sem apagar** (fecha a "decisão em aberto" nº 1 da 5B). A regra de uma avaliação por vez só conta a avaliação iniciada que o consultor ainda consegue abrir: sessão em andamento no aparelho e participante ainda com ele. A que ficou presa — sessão concluída ou cancelada, consultor removido da sessão, participante liberado — continua guardada e volta a valer se o participante voltar para ele. Não muda nenhuma tela. Recusados: apagar a avaliação presa (uma remoção feita por engano no painel faria o consultor perder as marcações sem aviso) e deixar para a Fase 8.
6. **Já decidido para a 6B** (registrado aqui para não se perder): remover um consultor com avaliação em andamento devolve os participantes dele para "Pendente" — ou para o status da nota anterior, numa reavaliação —, com uma mudança no backend que vale também para o painel web; e o ADMIN desatribui um participante de outro consultor por um menu ⋮ na linha do participante.

Em 06 e 07/10/2026, o desenho, aprovado em três partes:

7. **Abordagem:** telas cheias, cada uma com rota e ViewModel próprios, estendendo os repositórios que já existem. Recusadas: folhas (bottom sheets) sobre o detalhe — o teclado briga com a folha, a `SessionDetailViewModel` engordaria com dois formulários, e o canvas do celular não desenha assim (popover é da Fase 7) — e um repositório só de ADMIN, que dividiria entre dois repositórios a escrita nas mesmas tabelas do cache.
8. **Detalhe da sessão para ADMIN (quadro `1f`):** um lápis na barra superior, antes do indicador de envio, abre "Dados do treinamento"; um ícone de adicionar, à direita do título "Participantes", abre "Adicionar participante". Só ADMIN vê os dois — para o consultor comum, a tela fica idêntica à de hoje. Funcionam com conexão e com a sessão planejada ou em andamento (o backend recusa edição e inscrição nos outros dois status); fora disso continuam visíveis, apagados. Offline, a lista mostra o aviso do canvas: "Ações administrativas precisam de conexão. A avaliação continua funcionando offline." Em sessão concluída ou cancelada, o aviso que já existe ganha, para o ADMIN, o complemento "e os dados não podem mais ser alterados".
9. **1.12 Dados do treinamento (quadro `3b`):**
   - **Estrutura:** barra com voltar e o indicador de envio (sem toque, para não sair do formulário); faixa de contexto com logo, empresa e curso; campos; rodapé com "Salvar alterações" e "Descartar".
   - **Campos:** Data (abre o calendário do Material, em português; não há "limpar data", porque o backend ignora data vazia); Cidade e UF na mesma linha (UF com 2 letras maiúsculas, conferida contra as 27 UFs); "Observações para os consultores", com várias linhas (apagar tudo limpa a observação no servidor); "Cancelar sessão", em contorno vermelho, no fim da rolagem.
   - **Só vai ao servidor o campo que mudou:** uma edição feita no painel web em outro campo não é desfeita, e um valor antigo fora do padrão não trava o salvar.
   - "Salvar alterações" habilita com mudança válida e conexão; no sucesso, volta ao detalhe com "Dados do treinamento atualizados."; na falha, a mensagem aparece na tela e as edições ficam.
   - Voltar com mudança não salva pede confirmação; "Descartar" sai direto.
   - Sem conexão com a tela aberta: os botões desabilitam com "Disponível quando houver conexão", e o que foi digitado fica.
   - **Cancelar sessão:** o diálogo diz que ninguém mais será avaliado, que a sessão sai da lista do app e que não dá para desfazer, e conta quem está em avaliação agora; botões "Voltar" e "Cancelar sessão". No sucesso, o app vai para a lista de sessões com "Sessão cancelada."
10. **1.11 Adicionar participante (quadro `3a`):**
    - **Estrutura:** barra com X e o indicador de envio; faixa de contexto com logo, empresa e "curso · data"; campos; rodapé com "Adicionar participante" e "Salvar e adicionar outro".
    - **Campos, nesta ordem:** CPF (teclado numérico, máscara `000.000.000-00`); Nome completo (obrigatório); E-mail (opcional; se preenchido, confere o formato básico); Tipo de participação (dois cartões, com "Teórica + prática" marcado).
    - **O que aparece sob o CPF:**

      | Situação | Texto | Efeito |
      |---|---|---|
      | Incompleto | nada | botões desabilitados |
      | Dígitos não conferem | "CPF inválido." | botões desabilitados |
      | Consultando | "Consultando o CPF…" | botões aguardam |
      | Sem cadastro | ✓ "CPF válido e sem cadastro nesta sessão." | segue |
      | Cadastro de outro treinamento | o mesmo, mais "Já cadastrado em outro treinamento: nome e e-mail preenchidos. Altere se precisar." | preenche nome e e-mail |
      | Já nesta sessão | "Fulano de Tal já está nesta sessão." | botões desabilitados |
      | Consulta falhou | "Não foi possível consultar o CPF. Preencha os dados e adicione assim mesmo." | segue como formulário simples |

    - Trocar o CPF depois de um preenchimento automático limpa o nome e o e-mail que vieram do cadastro, se o admin não mexeu neles — sem isso, a pessoa B poderia ser salva com o nome da A.
    - Apagar um e-mail preenchido não apaga o do cadastro: o backend só troca o e-mail quando ele vem preenchido.
    - "Adicionar participante" volta ao detalhe, com a pessoa já na lista e "Participante adicionado."; "Salvar e adicionar outro" limpa o formulário, volta o foco ao CPF e avisa quem entrou.
    - Fechar com algo preenchido pede confirmação.
11. **Por baixo:**
    - **Backend:** um endpoint novo, `POST /training-sessions/:id/participants/lookup`, só ADMIN, corpo `{ cpf }` → `{ registered, name, email, enrolled }`. É POST para o CPF ir no corpo, e não na URL (que acaba em log de servidor). Usa o mesmo conferidor de CPF do adicionar; 404 se a sessão não existe. Nada mais muda: sem migração e sem alterar endpoint existente.
    - **Dados no app:** sem mudança de esquema do Drift; formato do envio igual ao do web (data como `AAAA-MM-DD`, CPF só com dígitos); depois do sucesso o cache muda na hora (os campos editados, o status "Cancelado" ou a linha do participante novo) e o detalhe baixa a sessão de novo; o CPF inteiro não é guardado no aparelho — fica em memória enquanto o formulário está aberto, e a linha nova entra no cache já mascarada.
    - **Erros e bordas:** sessão concluída ou cancelada por outra pessoa com o formulário aberto → o servidor recusa, a tela mostra o motivo e a sessão é baixada de novo; CPF inscrito por outra pessoa entre a consulta e o toque → a recusa aparece sob o CPF; sem rede no envio → a mensagem de sempre, com o formulário intacto; dois toques rápidos → uma requisição só; resposta atrasada da consulta de um CPF que já foi trocado → ignorada; rota aberta por quem não é ADMIN, ou com a sessão fora de planejada/em andamento → os campos aparecem travados, com o motivo escrito.
12. **Divergências do canvas aprovadas:**
    - **Quadro `1f`:** alvo de toque de 48dp nos dois ícones (o canvas desenha 32dp); o chip de status e as observações continuam no cabeçalho (o `1f` não desenha nenhum dos dois, mas o quadro do consultor desenha, e o ADMIN precisa de ambos); "3 consultores" e o ícone de pessoas ficam para a 6B.
    - **Quadro `3b`:** sem "Início 07:30" (a sessão não tem horário no contrato; o web grava só a data); "Local" virou "Cidade" + "UF" (é como o backend guarda); sem o contador "62/240" (o backend não limita, e uma observação longa vinda do web precisa continuar editável); dois diálogos de confirmação que o canvas não desenha; o calendário é o do Material.
    - **Quadro `3a`:** CPF antes do nome, por causa da busca; sem "Consultor responsável" (decisão 3); os avisos da consulta, que o canvas não tem; e a conferência de formato do e-mail, que o backend não faz — é só para barrar erro de digitação no endereço que recebe o certificado.
13. **Fora da 6A**, como no roteiro: editar ou remover participante já inscrito, e trocar curso, empresa ou responsável. Continuam no painel web.

### Desvios na execução (07 a 09/10/2026)

A execução foi por subagentes, uma task por vez, cada uma conferida arquivo a arquivo contra o código validado e revisada antes da próxima. As Tasks 1, 2, 4, 5, 6, 9 e 11 saíram iguais ao plano. Os desvios foram:

**Task 3, posição dos grupos de teste e correção `bb3253e`.** Em `form_widgets_test.dart`, os três grupos novos (`AppDangerOutlineButton`, `AppTextButton`, `AppIconAction`) ficaram antes de `AppPrimaryButton`, e não antes de `AppCheckbox`, onde o plano os punha; os testes são os mesmos, e nenhuma task posterior edita esse arquivo. A revisão da task achou que o teste "nome e apoio compridos encolhem com reticências, sem estourar" passava mesmo sem a truncagem: ele ganhou a afirmação de que os dois textos foram cortados.

**Task 7, correção `9bd32c6`.** Nenhum teste travava a decisão 9 ("um valor antigo fora do padrão não trava o salvar"): sem a regra, os testes da ViewModel continuavam todos passando. Entrou o teste com UF "Minas Gerais" e cidade vazia antigas. 1 teste a mais.

**Task 8, correção `f3fb077`.** A revisão da task achou três defeitos que vinham do plano:
- **O voltar espera o envio.** Com o salvar ou o cancelar em andamento, o voltar abria "Descartar as alterações?" por cima; conforme a hora em que a resposta chegava, o detalhe não se atualizava ou a tela de baixo fechava junto. Agora, enquanto envia, o voltar da barra e o do Android não fazem nada, como o "Descartar" do rodapé.
- **A falha aparece no rodapé, acima do botão**, como na tela de Resumo, e não mais dentro da lista: em celular pequeno, com a fonte ampliada ou com uma observação longa, ela ficava abaixo da dobra. Vale para a falha do salvar e para a do cancelar. O canvas não desenha esse estado.
- **O rodapé segue o canvas** (12 em cima, 16 nos lados e embaixo, 8 entre os botões). O plano tinha 8 embaixo e 4 entre os botões, diferença que não estava entre as aprovadas na decisão 12.

4 testes a mais.

**Task 10, com os ajustes da Task 8 (`cf11ab7`) e a correção `86102b5`.** A tela 1.11 já nasceu com o rodapé do canvas e a falha no rodapé, mais o teste do voltar com o envio em andamento (o código do plano já protegia esse caso). A revisão da task achou ainda que, com a rede de verdade, o foco não voltava ao CPF depois do "Salvar e adicionar outro": o campo ainda estava travado quando o pedido de foco rodava, e o teste do plano não via isso porque o servidor simulado respondia na hora. O pedido de foco passou para depois do quadro. Entrou também o teste de tela da recusa do servidor com a sessão concluída por outra pessoa. 5 testes a mais que o plano.

**Revisão final.** Commits `a773d2a` e `5927d9d`, com 12 testes a mais no app e 2 no backend. A revisão do branch inteiro não achou nada crítico; entraram:
- **CPF já inscrito baixa a sessão de novo.** Quando o servidor diz que o CPF já está na sessão — na consulta ou na recusa do envio —, a lista do detalhe não mostrava a pessoa até o admin puxar para atualizar. Acontece com quem entra pelo QR code ou pelo painel, e quando o envio é aceito mas a resposta se perde. Nesse estado, o diálogo de descarte deixou de mostrar "Este participante ainda não foi adicionado.", que seria falso: fica só com o título e os botões.
- **A linha "Participantes" do ADMIN tem 62dp**, como o quadro `1f`. O plano tinha 48dp, e a decisão 12 só aprova o alvo de toque de 48dp.
- **Com o teclado aberto, o rodapé das duas telas mostra só os botões.** O aviso de falha e a dica "Disponível quando houver conexão" somem enquanto o teclado está aberto e voltam quando ele fecha: com a fonte do sistema ampliada num aparelho de até 700dp de altura, o rodapé estourava. Sem conexão, o motivo continua escrito na faixa do topo.
- **22dp antes do "Cancelar sessão"**, como o quadro `3b` (eram 24).
- **Testes que faltavam:** a consulta de CPF só para ADMIN, no backend; o e-mail corrigido à mão, que fica ao trocar o CPF; o aviso do cadastro, que some depois do "Salvar e adicionar outro"; e, na 1.12, a recusa do servidor que baixa a sessão e trava a tela.

**Fim da execução:** app com **698 testes passando** e `flutter analyze` sem issues; backend com as 12 falhas antigas e 72 testes passando (84 no total).

### Decisões em aberto (para o usuário)

A execução deixou estas escolhas para o usuário. Nenhuma foi decidida por conta própria:

1. **A consulta responde com o admin no meio da digitação do nome** (regra de tela). Nome e e-mail ficam editáveis durante o "Consultando o CPF…", e o cadastro substitui o que estiver nos campos. Com a rede lenta, o texto troca sob o cursor, e o que o admin continuar digitando emenda no fim do nome do cadastro — e vai para o cadastro compartilhado. O plano escolheu "o cadastro vence o que foi digitado" sem levar a escolha ao usuário. Opções: (a) travar nome e e-mail enquanto consulta; (b) o cadastro só preencher campo vazio; (c) deixar como está.
2. **Data com mais de 90 dias no passado tira a sessão do app** (encontro de duas regras). O calendário da 1.12 começa em 2020, e a lista de sessões só baixa as dos últimos 90 dias (ou sem data): um toque errado no ano faz a sessão — mesmo em andamento — sumir da lista de todos os aparelhos no próximo sync, sem aviso, e só o painel web conserta. Opções: (a) pedir confirmação quando a data escolhida for anterior à janela; (b) limitar o calendário; (c) deixar como está.
3. **Consulta de CPF sem conexão.** Com o CPF completo digitado sem conexão, a consulta falha e a tela mostra juntos "Sem conexão — adicionar participante precisa de internet.", "Não foi possível consultar o CPF. Preencha os dados e adicione assim mesmo." e "Disponível quando houver conexão": o texto do meio convida a adicionar enquanto os outros dizem que não dá. E, quando a conexão volta, o CPF não é consultado de novo, a não ser que o admin mexa nele. Opções: (a) não consultar sem conexão e consultar sozinho quando a rede voltar (recomendada pela revisão: preserva o objetivo da decisão 4 no caso mais comum em campo); (b) só trocar o texto; (c) deixar para a Fase 8, como a pendência já registrada.
4. **"Cancelar sessão" sem conexão não tem motivo próprio.** A faixa do topo diz "Sem conexão — salvar precisa de internet.", e "Disponível quando houver conexão" fica sob o "Salvar alterações"; o "Cancelar sessão" fica apagado no fim da rolagem. Trocar a faixa para dizer que salvar e cancelar precisam de internet, ou deixar?
5. **Cores do canvas que o app não tem.** O canvas desenha o "Somente teórica" (o ícone do cartão na 1.11 e o chip da lista) com a tinta #6B4A7A; o app usa o mauve #9B80A8 desde o Design System, inclusive no chip já validado. E a borda do "Cancelar sessão" é #E9A2A2 no quadro `3b`; o app usa o `dangerBorder` #FCA5A5. Aprovar as cores atuais, ou criar os tons do canvas?
6. **Contraste do "opcional"** ao lado do rótulo do e-mail: #94A3B8 em 11,5sp, cerca de 2,6:1 sobre o branco. É exatamente o que o canvas desenha, mas fica abaixo do recomendado para leitura. Manter, ou escurecer?
7. **Título "Participantes" apagado sem conexão.** No requadro "Mesma tela, admin offline" do quadro `1f`, o título também aparece apagado, junto com o ícone; no app, só o ícone apaga. É intenção do desenho, ou só o estilo do requadro?
8. **Medidas pequenas que ficaram diferentes do canvas**, por o campo de texto e o cabeçalho de contexto serem um widget só para as duas telas: o texto das observações em 16/1,3 (o quadro `3b` tem 15/1,45); o recuo vertical do cabeçalho de contexto em 12 (o `3b` tem 14), com o nome da empresa em 15 e vão de 3 na 1.11 (o `3a` tem 14 e 2); e o ícone de adicionar do detalhe com 22 (o `1f` tem 20). Aceitar, ou alinhar?

### Ajustes feitos ao preparar o plano (revisar junto com o plano)

A validação na cópia descartável levou a estes ajustes — **nenhum muda regra de negócio aprovada**, mas cada um é uma escolha que o usuário deve conferir:

- **A consulta de CPF confere o CPF dentro do controller**, chamando o `ValidateCpfPipe` à mão depois que a validação global do DTO já garantiu que `cpf` é texto — e usa o valor que o pipe devolve (só dígitos). O `POST …/participants` que já existe aplica o pipe pelo decorator e descarta o que ele devolve; ele não foi tocado.
- **Os testes do endpoint novo estão num arquivo novo**, `apps/backend/test/participants-lookup.spec.ts`: o `participants.service.spec.ts` é uma das duas suítes com as 12 falhas antigas (falta nele o mock do `EmailService`), e este plano não mexe nele.
- **`openDraft` e `findInProgressOther` ganharam o parâmetro obrigatório `consultantId`** (o `Consultant.id` de quem avalia): é com ele que a regra da avaliação presa confere se o participante ainda está com o consultor. Por ser obrigatório, 8 arquivos de teste que só abriam um rascunho passam a informar `consultantId: 'c-eu'` — troca mecânica, sem mudar o que cada teste confere. Sem perfil de consultor (nulo), nada bloqueia.
- **"Em avaliação, sem dono" não conta como "com o consultor"** na regra da avaliação presa: é a mesma condição com que o detalhe da sessão abre o checklist (`situationOf`).
- **`SessionStatus.acceptsChanges`** (planejada ou em andamento) entrou no modelo: é a regra que as duas telas novas e o detalhe compartilham.
- **A faixa de contexto das duas telas é um widget só** (`SessionContextHeader`), com o logo de 44 do card da Home, sem borda — o canvas usa 40 numa tela e 44 na outra, com borda; o logo do app perdeu a borda no export de 24/09.
- **O indicador de envio das telas novas não tem toque** (no detalhe, ele abre a aba Sincronizar): abrir a aba dali largaria o formulário.
- **Cada tela nova tem o texto próprio na faixa de offline:** "Sem conexão — salvar precisa de internet." e "Sem conexão — adicionar participante precisa de internet."
- **1.12, UF:** o campo só aceita letras e mostra em maiúsculas o que for digitado. Só o campo que mudou é conferido: uma UF antiga fora do padrão (o web aceita texto livre) continua como está se o admin não mexer nela.
- **1.12, calendário:** vai de 2020 até 31 de dezembro de cinco anos à frente — é o limite do seletor, não uma regra do backend. Uma sessão com data fora desse intervalo abre o calendário na borda mais próxima.
- **1.12, depois de salvar:** o detalhe baixa a sessão de novo só quando algo foi salvo (a tela devolve `true`); voltar sem salvar não gasta uma chamada.
- **1.11, aviso do cadastro:** diz o que foi preenchido — "nome e e-mail preenchidos" (o texto aprovado) ou, se o cadastro não tem e-mail, "nome preenchido".
- **1.11, erro do e-mail:** "E-mail inválido." só aparece depois que o admin sai do campo (no meio da digitação, todo e-mail está "errado"); os botões ficam desabilitados desde o primeiro caractere inválido.
- **1.11, "Salvar e adicionar outro":** o tipo de participação também volta a "Teórica + prática". Enquanto o envio está no ar, o indicador de carregamento aparece no botão principal, qualquer que tenha sido o botão tocado.
- **1.11, CPF já na sessão sem o nome** (a recusa 409 do toque não traz o nome): "Este CPF já está nesta sessão."
- **1.11, a tela devolve se alguém entrou** (`true`/`false`), inclusive depois de vários "Salvar e adicionar outro": é o que faz o detalhe baixar a sessão de novo.
- **Detalhe, aviso offline do ADMIN:** ocupa o lugar do "atribuir precisa de internet" (um aviso por vez; o "Atribuir a mim" continua desabilitado à vista).
- **Detalhe, alinhamento do ícone de adicionar:** o recuo à direita do título "Participantes" é menor para o ADMIN (8dp), para o ícone — e não a área de toque de 48dp — ficar perto da margem da lista.
- **Cursor do CPF:** a máscara leva o cursor sempre para o fim do campo. Editar um dígito no meio do CPF funciona, mas o cursor pula para o fim.
- **1.11, cartões do tipo de participação:** o escolhido se distingue pelo fundo, pela borda e pelo peso do rótulo, como no canvas — sem um ícone de "marcado" a mais.
- **Nada de elementos `?x` em listas** (null-aware elements do Dart 3.8): o `pubspec.yaml` aceita Dart a partir do 3.4, e o analyzer recusa essa sintaxe.

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app` (a mesma das fases anteriores). Sem git worktree. Não criar branch, não fazer merge, não fazer push.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada, com a mensagem exata dada. Vale também para o backend (o `apps/backend/CLAUDE.md` pede inglês, mas a prática do repositório é português).
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem arquivos soltos que não são desta fase — `apps/backend/test-render.js`, `apps/web/…`, `apps/mobile/simtc/devtools_options.yaml` e os arquivos da raiz (`brainstorm-*.md`, `prompt-*.md`, `test-*.js`, `IMPLEMENTATION-STATUS.md`, `.vscode/`) — **não tocar neles**.
- Não avançar com teste falhando, `flutter analyze` com issue ou build quebrado. No backend, `npx jest` já tem **12 falhas antigas** (`test/auth.service.spec.ts` e `test/participants.service.spec.ts`, desde 17/09/2026) — esse número não pode subir.
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-10-07-mobile-fase-6a-acoes-de-admin/`.

**Mobile (valem para todas as fases)**
- Flutter 3.41.6 / Dart 3.11.4 (o `pubspec.yaml` aceita a partir do 3.4: nada de sintaxe mais nova que isso). App **só Android**, APK sideload. Validação manual em **aparelho físico** (USB ou Wi-Fi, nunca emulador) — procedimento em `apps/mobile/simtc/README.md`.
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

Na Task 1 (backend), os caminhos são a partir da raiz do repositório. Nas Tasks 2 a 11 (app), todos os caminhos de código são relativos a `apps/mobile/simtc/`, e os comandos `flutter` rodam a partir dessa pasta. Os `git add`/`git commit` de todas as tasks rodam **da raiz do repositório**, com os caminhos completos dados.

## Review Focus

Os cinco casos que o desenho implica, que um ADMIN em campo vai encontrar, e onde cada um ficou preso num teste:

1. **Dois toques rápidos em "Salvar alterações" ou "Adicionar participante"** (sinal fraco, a resposta demora) → uma requisição só. Preso em: `dois toques rápidos salvam uma vez só` (Task 7) e `dois toques rápidos adicionam uma vez só` (Task 9).
2. **CPF trocado com a consulta ainda no ar, ou depois de um preenchimento automático** → a resposta atrasada é ignorada, e a pessoa nova não herda o nome da anterior. Preso em: `a resposta atrasada de um CPF que já foi trocado é ignorada` e `trocar o CPF limpa o que veio do cadastro — a pessoa é outra` (Task 9).
3. **Sessão concluída ou cancelada por outra pessoa com o formulário aberto** → os campos travam; se o toque chegar antes, o servidor recusa, o motivo aparece e a sessão é baixada de novo. Preso em: `a sessão ser concluída por outra pessoa trava a tela aberta` e `recusado pelo servidor (403): mostra o motivo e baixa a sessão de novo` (Task 7); `inscrições encerradas (400): mostra o motivo e baixa a sessão de novo` (Task 9).
4. **A conexão cai e volta com o formulário aberto** → nada do que foi digitado se perde, e os botões voltam. Preso em: `a conexão volta com a tela aberta: o salvar reabilita, e o que foi digitado continua` (Task 8).
5. **Celular estreito (360dp) com a fonte do sistema ampliada** → as duas telas novas não estouram, nem com os avisos e os erros à vista. Preso em: `celular estreito com a fonte do sistema ampliada…` (Tasks 8 e 10). Na Task 8 também fica presa a sessão com data antiga, fora do intervalo do calendário: `sessão com data fora do intervalo do calendário (cadastro antigo): o calendário abre mesmo assim`.

## Estado herdado (ponto de partida)

HEAD = o commit deste plano, sobre `91f0076`. App: `flutter analyze` limpo; **484 testes passando**. Backend: `npx jest` com **12 falhas antigas e 62 testes passando** (74 no total).

Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| Editar e cancelar no backend | `apps/backend/src/training-sessions/` | `PATCH /training-sessions/:id` (ADMIN; `UpdateTrainingSessionDto`: `date?` ISO, `city?`, `state?`, `notes?`; 403 em sessão concluída ou cancelada); `PATCH /training-sessions/:id/cancel` (ADMIN; 403 em concluída ou já cancelada) |
| Adicionar participante no backend | `apps/backend/src/participants/` | `POST /training-sessions/:id/participants` (ADMIN; `AddParticipantDto { cpf, name, email?, cnhCategory?, cnhExpiration?, participationType? }`; 409 "CPF já inscrito neste treinamento"; 400 "Inscrições encerradas para este treinamento"); `ValidateCpfPipe` (`src/common/pipes/`): `transform(value)` devolve só os dígitos ou lança 400 "CPF inválido" |
| Cliente HTTP | `lib/data/services/api/api_client.dart` | `get`, `post`, `patch`, `delete`; lança `ApiException` (`message` já com o texto do backend, `statusCode`, `isNetworkError`) |
| Sessões | `lib/data/repositories/session_repository.dart` | `watchSession(id)`; `start(id)` → `Result<void>` — o molde: chama a API e, no sucesso, grava no cache na hora |
| Participantes | `lib/data/repositories/participant_repository.dart` | `watchBySession(id)`; `syncSession(id)` → `Result<int>`; `assign(...)` — o molde das recusas com motivo próprio; `_now()` |
| Modelos | `lib/data/models/` | `TrainingSession` (`date` é data de calendário, meia-noite local), `SessionStatus`; `SessionParticipant.fromJson(json, sessionId:)`, `ParticipationType`, `ParticipantStatus`, `maskCpf` |
| Avaliação local | `lib/data/repositories/assessment_repository.dart` | `findCurrent`, `findInProgressOther`, `openDraft`, `EvaluationInProgressException` |
| Usuário | `lib/data/models/auth_user.dart` | `AuthUser.isAdmin`, `id`, `consultantId` |
| Detalhe | `lib/ui/session_detail/` | `SessionDetailViewModel` (`refresh()`, `canStartSession`, `neverDownloaded`); `_buildNotice`, `_buildListHeader`; `situationOf` (`participant_filter.dart`) |
| Checklist | `lib/ui/checklist/checklist_viewmodel.dart` | `start()` (chama `openDraft`), `_checkBlock()` (chama `findInProgressOther`), `consultantId` |
| Widgets do DS | `lib/ui/core/widgets/` | `AppTopBar` (`leadingIcon`, `trailing`), `AppTextField`, `AppCtaButton` (`AppCtaSize.large`), `InlineNotice` (`NoticeTone`), `ConnectivityBanner(isOffline, message)`, `SyncStatusIndicator(onTap)`, `CompanyLogo.card`, `SkeletonListItem` |
| Rótulos | `lib/ui/core/date_labels.dart` | `dayMonthYearLabel` |
| Padrões de tela | `lib/ui/checklist/checklist_screen.dart`, `lib/ui/result/result_screen.dart` | diálogo de confirmação com `FilledButton` em `AppColors.dangerInk`; rodapé com borda superior; SnackBar pelo `ScaffoldMessenger` do app (continua na tela de baixo) |
| Testes | `test/ui/result/result_screen_test.dart`, `test/ui/session_detail/session_detail_screen_test.dart` | tela com Drift em memória e `ApiClient` simulado, empilhada sobre uma rota "origem"; `goOffline()`; `showWithRouter` com o `createRouter` de produção |

## Mapa de Arquivos

### Novos

| Arquivo | Task | Responsabilidade |
|---|---|---|
| `apps/backend/src/participants/dto/lookup-participant.dto.ts` | 1 | corpo da consulta de CPF |
| `apps/backend/test/participants-lookup.spec.ts` | 1 | |
| `lib/ui/core/app_localization.dart` | 2 | idioma do app (pt-BR) e os delegates do Material |
| `lib/ui/core/widgets/session_context_header.dart` | 3 | faixa de contexto dos formulários de ADMIN |
| `lib/utils/cpf.dart` | 5 | `cpfDigits`, `isValidCpf`, `formatCpf` |
| `lib/data/models/cpf_lookup.dart` | 5 | resposta da consulta de CPF |
| `lib/ui/session_edit/session_edit_viewmodel.dart` | 7 | estado da 1.12; `brazilianStates` |
| `lib/ui/session_edit/session_edit_screen.dart` | 8 | tela 1.12 |
| `lib/ui/add_participant/add_participant_viewmodel.dart` | 9 | estado da 1.11; `CpfCheck` |
| `lib/ui/add_participant/add_participant_screen.dart` | 10 | tela 1.11 |
| `lib/ui/core/cpf_input_formatter.dart` | 10 | máscara do CPF enquanto se digita |
| `test/ui/core/app_localization_test.dart` | 2 | |
| `test/utils/cpf_test.dart`, `test/data/models/cpf_lookup_test.dart` | 5 | |
| `test/ui/session_edit/session_edit_viewmodel_test.dart` | 7 | |
| `test/ui/session_edit/session_edit_screen_test.dart` | 8 | |
| `test/ui/add_participant/add_participant_viewmodel_test.dart` | 9 | |
| `test/ui/add_participant/add_participant_screen_test.dart`, `test/ui/core/cpf_input_formatter_test.dart` | 10 | |

### Modificados

| Arquivo | Tasks | O que muda |
|---|---|---|
| `apps/backend/src/participants/participants.{controller,service}.ts` | 1 | `POST …/participants/lookup`, `lookupByCpf` |
| `apps/mobile/docs/fase-0-auditoria.md` | 1 | nota: a consulta por CPF passou a existir |
| `pubspec.yaml`, `pubspec.lock` | 2 | `flutter_localizations`; `intl` ^0.20.2 |
| `lib/app.dart` | 2 | `locale`, `supportedLocales`, `localizationsDelegates` |
| `lib/ui/core/theme/app_typography.dart` | 3, 10 | `fieldValueMono`, `fieldOptional`, `contextTitle`, `buttonDanger`, `textAction`; (10) `optionCard`, `optionCardSelected` |
| `lib/ui/core/widgets/app_text_field.dart` | 3 | texto de apoio, nota do rótulo, widget à direita, formatadores, só leitura com toque, várias linhas, fonte de números |
| `lib/ui/core/widgets/app_buttons.dart` | 3 | `AppDangerOutlineButton`, `AppTextButton`, `AppIconAction` |
| `lib/ui/core/widgets/app_top_bar.dart` | 3 | `actions` |
| `lib/data/repositories/session_repository.dart` | 4 | `update`, `cancel`; `_isoDate` |
| `lib/data/repositories/participant_repository.dart` | 5 | `lookupCpf`, `add` |
| `lib/data/repositories/assessment_repository.dart` | 6 | `consultantId` em `findInProgressOther` e `openDraft`; `_canStillOpen` |
| `lib/ui/checklist/checklist_viewmodel.dart` | 6 | passa o `consultantId` |
| `lib/data/models/training_session.dart` | 7 | `SessionStatus.acceptsChanges` |
| `lib/ui/core/theme/app_icons.dart` | 8, 10, 11 | `save`, `cancelSession`; (10) `cpf`, `practice`, `addParticipant`; (11) `edit` |
| `lib/router.dart` | 8, 10 | `AppRoutes.sessionEdit`; (10) `AppRoutes.addParticipant` |
| `lib/ui/core/date_labels.dart` | 10 | `dayMonthLabel` |
| `lib/ui/session_detail/session_detail_viewmodel.dart` | 11 | `isAdmin`, `adminActionsAllowed` |
| `lib/ui/session_detail/session_detail_screen.dart` | 11 | o lápis, o adicionar, os avisos do ADMIN, a volta das telas novas |
| testes existentes | 2–11 | ver cada task |

---

## Task 1: Backend — consulta de CPF (`POST /training-sessions/:id/participants/lookup`)

A tela "Adicionar participante" precisa saber, antes do toque, se um CPF já tem cadastro (para preencher nome e e-mail) e se já está nesta sessão. O backend não tinha essa consulta. Ela só lê: quem cria e altera o cadastro continua sendo o `addParticipant`. Os caminhos desta task são a partir da raiz do repositório.

**Files:**
- Create: `apps/backend/src/participants/dto/lookup-participant.dto.ts`
- Create: `apps/backend/test/participants-lookup.spec.ts`
- Modify: `apps/backend/src/participants/participants.controller.ts`
- Modify: `apps/backend/src/participants/participants.service.ts`
- Modify: `apps/mobile/docs/fase-0-auditoria.md`

**Interfaces:**
- Consumes: `ValidateCpfPipe.transform(value: string): string` (`src/common/pipes/validate-cpf.pipe.ts`) — devolve só os dígitos ou lança `BadRequestException('CPF inválido')`.
- Produces: `POST /api/training-sessions/:id/participants/lookup` (só ADMIN), corpo `{ "cpf": string }` → `200 { registered: boolean, name: string | null, email: string | null, enrolled: boolean }`; `400 "CPF inválido"`; `404 "Sessão de treinamento não encontrada"`. No service: `lookupByCpf(trainingSessionId: string, cpf: string)`. `registered`: existe um `Participant` com esse CPF; `enrolled`: ele já tem um `TrainingParticipant` nesta sessão.

- [ ] **Step 1: Escrever os testes que falham**

**Criar `apps/backend/test/participants-lookup.spec.ts`:**

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ParticipantsController } from 'src/participants/participants.controller';
import { ParticipantsService } from 'src/participants/participants.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { EmailService } from 'src/email/email.service';
import { StorageService } from 'src/storage/storage.service';

const mockPrisma = {
  trainingSession: { findUnique: jest.fn() },
  participant: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
  trainingParticipant: { findUnique: jest.fn(), create: jest.fn() },
};

// CPF válido (dígitos verificadores conferem).
const CPF = '52998224725';

describe('ParticipantsService.lookupByCpf', () => {
  let service: ParticipantsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ParticipantsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: EmailService, useValue: {} },
        { provide: StorageService, useValue: {} },
      ],
    }).compile();

    service = module.get(ParticipantsService);
    jest.clearAllMocks();
    mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: 'sess-1' });
  });

  it('lança 404 se a sessão não existe', async () => {
    mockPrisma.trainingSession.findUnique.mockResolvedValue(null);

    await expect(service.lookupByCpf('sess-x', CPF)).rejects.toThrow(NotFoundException);
    expect(mockPrisma.participant.findUnique).not.toHaveBeenCalled();
  });

  it('CPF sem cadastro: nada a preencher, e fora da sessão', async () => {
    mockPrisma.participant.findUnique.mockResolvedValue(null);

    await expect(service.lookupByCpf('sess-1', CPF)).resolves.toEqual({
      registered: false,
      name: null,
      email: null,
      enrolled: false,
    });
    expect(mockPrisma.participant.findUnique).toHaveBeenCalledWith({ where: { cpf: CPF } });
    expect(mockPrisma.trainingParticipant.findUnique).not.toHaveBeenCalled();
  });

  it('CPF com cadastro de outro treinamento: devolve nome e e-mail', async () => {
    mockPrisma.participant.findUnique.mockResolvedValue({
      id: 'part-1',
      name: 'Fernanda Lopes Meireles',
      email: 'fernanda@empresa.com.br',
    });
    mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);

    await expect(service.lookupByCpf('sess-1', CPF)).resolves.toEqual({
      registered: true,
      name: 'Fernanda Lopes Meireles',
      email: 'fernanda@empresa.com.br',
      enrolled: false,
    });
    expect(mockPrisma.trainingParticipant.findUnique).toHaveBeenCalledWith({
      where: {
        trainingSessionId_participantId: {
          trainingSessionId: 'sess-1',
          participantId: 'part-1',
        },
      },
      select: { id: true },
    });
  });

  it('cadastro sem e-mail devolve e-mail nulo', async () => {
    mockPrisma.participant.findUnique.mockResolvedValue({
      id: 'part-1',
      name: 'Fernanda Lopes Meireles',
      email: null,
    });
    mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);

    const result = await service.lookupByCpf('sess-1', CPF);

    expect(result.email).toBeNull();
  });

  it('CPF já inscrito nesta sessão: enrolled verdadeiro, com o nome', async () => {
    mockPrisma.participant.findUnique.mockResolvedValue({
      id: 'part-1',
      name: 'Fernanda Lopes Meireles',
      email: null,
    });
    mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });

    await expect(service.lookupByCpf('sess-1', CPF)).resolves.toEqual({
      registered: true,
      name: 'Fernanda Lopes Meireles',
      email: null,
      enrolled: true,
    });
  });

  it('só consulta: não cria nem altera cadastro ou inscrição', async () => {
    mockPrisma.participant.findUnique.mockResolvedValue({
      id: 'part-1',
      name: 'Fernanda Lopes Meireles',
      email: null,
    });
    mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);

    await service.lookupByCpf('sess-1', CPF);

    expect(mockPrisma.participant.create).not.toHaveBeenCalled();
    expect(mockPrisma.participant.update).not.toHaveBeenCalled();
    expect(mockPrisma.trainingParticipant.create).not.toHaveBeenCalled();
  });
});

describe('ParticipantsController.lookupParticipant', () => {
  const service = { lookupByCpf: jest.fn() };
  const controller = new ParticipantsController(service as unknown as ParticipantsService);

  beforeEach(() => {
    jest.clearAllMocks();
    service.lookupByCpf.mockResolvedValue({ registered: false, name: null, email: null, enrolled: false });
  });

  it('manda ao service o CPF só com dígitos', async () => {
    await controller.lookupParticipant('sess-1', { cpf: '529.982.247-25' });

    expect(service.lookupByCpf).toHaveBeenCalledWith('sess-1', CPF);
  });

  it('CPF com dígito verificador errado é 400, sem consultar', () => {
    expect(() => controller.lookupParticipant('sess-1', { cpf: '529.982.247-26' })).toThrow(
      BadRequestException,
    );
    expect(service.lookupByCpf).not.toHaveBeenCalled();
  });
});
```

O CPF `529.982.247-25` tem os dígitos verificadores certos; o `…-26` não.

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd apps/backend && npx jest test/participants-lookup.spec.ts`
Esperado: a suíte não compila — `TS2339: Property 'lookupByCpf' does not exist on type 'ParticipantsService'` e `Property 'lookupParticipant' does not exist on type 'ParticipantsController'`.

- [ ] **Step 3: Implementar**

**Criar `apps/backend/src/participants/dto/lookup-participant.dto.ts`:**

```typescript
import { IsString } from "class-validator";

export class LookupParticipantDto {

    @IsString()
    cpf!: string;
}
```

**Em `apps/backend/src/participants/participants.controller.ts`, substituir:**

```typescript
import { Controller, Get, Post, Param, Body, UseGuards, Patch, Delete } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ParticipantsService } from './participants.service';
import { UserRole } from '@simtc/shared-types';
import { ValidateCpfPipe } from '../common/pipes/validate-cpf.pipe';
import { AddParticipantDto } from './dto/add-participant.dto';
import { Roles } from 'src/auth/decorators/roles.decorator';
import { RolesGuard } from 'src/auth/guards/roles.guard';
```

**por:**

```typescript
import { Controller, Get, Post, Param, Body, UseGuards, Patch, Delete, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ParticipantsService } from './participants.service';
import { UserRole } from '@simtc/shared-types';
import { ValidateCpfPipe } from '../common/pipes/validate-cpf.pipe';
import { AddParticipantDto } from './dto/add-participant.dto';
import { LookupParticipantDto } from './dto/lookup-participant.dto';
import { Roles } from 'src/auth/decorators/roles.decorator';
import { RolesGuard } from 'src/auth/guards/roles.guard';
```

**Em `apps/backend/src/participants/participants.controller.ts`, substituir:**

```typescript
    return this.service.addParticipant(trainingSessionId, dto);
  }

  @Delete('participants/:participantId')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
```

**por:**

```typescript
    return this.service.addParticipant(trainingSessionId, dto);
  }

  /**
   * Consulta de CPF da tela "Adicionar participante" do app mobile. É POST
   * para o CPF viajar no corpo, e não na URL (que acaba em log de servidor).
   * O `ValidateCpfPipe` é chamado à mão, depois que o `ValidationPipe` global
   * já garantiu que `cpf` é texto: devolve o CPF só com dígitos, que é como
   * ele está gravado.
   */
  @Post('training-sessions/:id/participants/lookup')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Consulta um CPF antes de adicionar: já tem cadastro? já está nesta sessão?' })
  lookupParticipant(
    @Param('id') trainingSessionId: string,
    @Body() dto: LookupParticipantDto,
  ) {
    const cpf = new ValidateCpfPipe().transform(dto.cpf);
    return this.service.lookupByCpf(trainingSessionId, cpf);
  }

  @Delete('participants/:participantId')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
```

**Em `apps/backend/src/participants/participants.service.ts`, substituir:**

```typescript
    });
  }

  updateParticipationType( participantId: string, dto: UpdateParticipantTypeDto) {
    const record = this.prisma.trainingParticipant.findUnique({
      where: { id: participantId },
```

**por:**

```typescript
    });
  }

  /**
   * Consulta de CPF da tela "Adicionar participante" do app mobile: diz se o
   * CPF já tem cadastro (`Participant`, compartilhado entre treinamentos) —
   * devolvendo nome e e-mail para a tela preencher — e se já está inscrito
   * nesta sessão. Só lê: quem grava é o `addParticipant`.
   */
  async lookupByCpf(trainingSessionId: string, cpf: string) {
    const session = await this.prisma.trainingSession.findUnique({
      where: { id: trainingSessionId },
      select: { id: true },
    });
    if (!session) throw new NotFoundException('Sessão de treinamento não encontrada');

    const participant = await this.prisma.participant.findUnique({ where: { cpf } });
    if (!participant) {
      return { registered: false, name: null, email: null, enrolled: false };
    }

    const enrollment = await this.prisma.trainingParticipant.findUnique({
      where: {
        trainingSessionId_participantId: {
          trainingSessionId,
          participantId: participant.id,
        },
      },
      select: { id: true },
    });

    return {
      registered: true,
      name: participant.name,
      email: participant.email ?? null,
      enrolled: enrollment !== null,
    };
  }

  updateParticipationType( participantId: string, dto: UpdateParticipantTypeDto) {
    const record = this.prisma.trainingParticipant.findUnique({
      where: { id: participantId },
```

O DTO segue a indentação do `add-participant.dto.ts` vizinho. O `ValidationPipe` global roda com `forbidNonWhitelisted`: o corpo só pode ter `cpf`.

- [ ] **Step 4: Rodar e ver passar**

Run: `cd apps/backend && npx jest test/participants-lookup.spec.ts`
Esperado: `Tests: 8 passed, 8 total`.

- [ ] **Step 5: Suíte inteira e tipos**

Run: `cd apps/backend && npx jest` e `npx tsc --noEmit`
Esperado: `Tests: 12 failed, 70 passed, 82 total` — as 12 falhas antigas de `auth.service.spec.ts` e `participants.service.spec.ts` — e o `tsc` sem nenhuma saída.

- [ ] **Step 6: Registrar na auditoria da Fase 0**

A auditoria é leitura obrigatória antes de planejar cada fase, e diz que a busca por CPF não existe. Em `apps/mobile/docs/fase-0-auditoria.md`, no fim da seção 2.2, substituir:

```markdown
| 6 | `GET /consultants?active=true` (ADMIN e CONSULTANT) lista os consultores ativos | É a fonte da busca "Adicionar consultor" |

### 2.3 Testes do backend
```

por:

```markdown
| 6 | `GET /consultants?active=true` (ADMIN e CONSULTANT) lista os consultores ativos | É a fonte da busca "Adicionar consultor" |

**Nota de 07/10/2026:** a Fase 6A criou a consulta de participante por CPF que faltava: `POST /api/training-sessions/:id/participants/lookup` (só ADMIN; corpo `{ cpf }` → `{ registered, name, email, enrolled }`). O `POST /training-sessions/:id/participants` continua como descrito acima: deduplica por CPF e sobrescreve o `name` do cadastro.

### 2.3 Testes do backend
```

- [ ] **Step 7: Commit**

A partir da raiz do repositório:

```bash
git add apps/backend/src/participants/dto/lookup-participant.dto.ts \
  apps/backend/src/participants/participants.controller.ts \
  apps/backend/src/participants/participants.service.ts \
  apps/backend/test/participants-lookup.spec.ts \
  apps/mobile/docs/fase-0-auditoria.md
git commit -m "feat(participants): consulta de cpf antes de adicionar participante"
```

---

## Task 2: Calendário e textos do Material em português

O campo "Data" da 1.12 abre o calendário do Material, que sem os delegates de localização aparece em inglês ("September 2026", "CANCEL"). O pacote é do próprio SDK; ele exige o `intl` 0.20.2, e o app declara `^0.19.0` sem importar o `intl` em lugar nenhum — por isso a troca de versão não toca em código. Efeito colateral bom: o menu de copiar/colar dos campos e os rótulos de acessibilidade do Material também passam para português.

**Files:**
- Create: `lib/ui/core/app_localization.dart`
- Create: `test/ui/core/app_localization_test.dart`
- Modify: `pubspec.yaml` (e o `pubspec.lock`, pelo `flutter pub get`)
- Modify: `lib/app.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: —
- Produces: `AppLocalization.locale` (`Locale('pt', 'BR')`), `AppLocalization.supportedLocales`, `AppLocalization.delegates` — os testes de tela das Tasks 8 e 10 montam o `MaterialApp` com os três.

- [ ] **Step 1: Escrever os testes que falham**

**Criar `test/ui/core/app_localization_test.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/app_localization.dart';

void main() {
  testWidgets('o calendário do Material abre em português', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocalization.locale,
        supportedLocales: AppLocalization.supportedLocales,
        localizationsDelegates: AppLocalization.delegates,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDatePicker(
              context: context,
              initialDate: DateTime(2026, 9, 12),
              firstDate: DateTime(2026),
              lastDate: DateTime(2027),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('setembro de 2026'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('September 2026'), findsNothing);
  });
}
```

**Em `test/widget_test.dart`, substituir:**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/app.dart';
import 'package:simtc/data/services/local/app_database.dart';
```

**por:**

```dart
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/app.dart';
import 'package:simtc/data/services/local/app_database.dart';
```

**Em `test/widget_test.dart`, substituir:**

```dart

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
```

**por:**

```dart

    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('o app roda em português do Brasil', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(SimtcApp(database: database));
    await tester.pump();

    expect(
      Localizations.localeOf(tester.element(find.byType(SplashScreen))),
      const Locale('pt', 'BR'),
    );
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/app_localization_test.dart test/widget_test.dart`
Esperado: o `app_localization_test.dart` não compila — `Error when reading 'lib/ui/core/app_localization.dart'` e `Undefined name 'AppLocalization'`. O teste novo do `widget_test.dart` só passa depois do Step 3: até lá, o app não declara idioma nenhum.

- [ ] **Step 3: Implementar**

**Em `lib/app.dart`, substituir:**

```dart
import 'app_providers.dart';
import 'data/services/local/app_database.dart';
import 'router.dart';
import 'ui/core/theme/app_theme.dart';

class SimtcApp extends StatefulWidget {
```

**por:**

```dart
import 'app_providers.dart';
import 'data/services/local/app_database.dart';
import 'router.dart';
import 'ui/core/app_localization.dart';
import 'ui/core/theme/app_theme.dart';

class SimtcApp extends StatefulWidget {
```

**Em `lib/app.dart`, substituir:**

```dart
        title: 'SIMTC',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
```

**por:**

```dart
        title: 'SIMTC',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: AppLocalization.locale,
        supportedLocales: AppLocalization.supportedLocales,
        localizationsDelegates: AppLocalization.delegates,
        routerConfig: _router,
      ),
    );
```

**Criar `lib/ui/core/app_localization.dart`:**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Idioma do app: português do Brasil, fixo.
///
/// Os textos das telas são escritos direto em português; isto aqui cobre o que
/// o próprio Material desenha — o calendário de "Dados do treinamento", o menu
/// de copiar/colar dos campos e os rótulos de acessibilidade. Sem estes
/// delegates, o Flutter mostra tudo isso em inglês.
abstract final class AppLocalization {
  static const Locale locale = Locale('pt', 'BR');

  static const List<Locale> supportedLocales = [locale];

  static const List<LocalizationsDelegate<dynamic>> delegates =
      GlobalMaterialLocalizations.delegates;
}
```

**Em `pubspec.yaml`, substituir:**

```yaml

dependencies:
  flutter:
    sdk: flutter

  # Arquitetura oficial Flutter (MVVM)
```

**por:**

```yaml

dependencies:
  flutter:
    sdk: flutter

  # Textos do próprio Material em português (calendário, copiar/colar)
  flutter_localizations:
    sdk: flutter

  # Arquitetura oficial Flutter (MVVM)
```

**Em `pubspec.yaml`, substituir:**

```yaml
  flutter_cache_manager: ^3.4.1

  # Utilitários
  intl: ^0.19.0
  connectivity_plus: ^6.0.5
  uuid: ^4.4.2
```

**por:**

```yaml
  flutter_cache_manager: ^3.4.1

  # Utilitários
  intl: ^0.20.2
  connectivity_plus: ^6.0.5
  uuid: ^4.4.2
```

Depois de editar o `pubspec.yaml`:

Run: `flutter pub get`
Esperado: `+ flutter_localizations 0.0.0 from sdk flutter`, o `intl` passando de 0.19.0 para 0.20.2 e `Changed 2 dependencies!`. O `pubspec.lock` muda só nessas duas entradas.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/app_localization_test.dart test/widget_test.dart`
Esperado: `+3: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+486: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/app.dart \
  apps/mobile/simtc/lib/ui/core/app_localization.dart \
  apps/mobile/simtc/pubspec.lock \
  apps/mobile/simtc/pubspec.yaml \
  apps/mobile/simtc/test/ui/core/app_localization_test.dart \
  apps/mobile/simtc/test/widget_test.dart
git commit -m "feat(mobile): textos do material em portugues"
```

---

## Task 3: Design System — as peças dos formulários

As duas telas novas são formulários, e o DS só tinha o campo e os botões do login. Esta task traz o que falta, sem regra de negócio: o campo de texto ganha texto de apoio, nota ao lado do rótulo, widget à direita, formatadores, modo só leitura com toque (a data), várias linhas (as observações) e fonte de números (o CPF); entram o botão de contorno vermelho, a ação em texto do rodapé e o atalho de ícone; a barra superior passa a aceitar atalhos; e a faixa de contexto vira um widget.

**Files:**
- Create: `lib/ui/core/widgets/session_context_header.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/widgets/app_text_field.dart`
- Modify: `lib/ui/core/widgets/app_buttons.dart`
- Modify: `lib/ui/core/widgets/app_top_bar.dart`
- Modify: `test/ui/core/widgets/form_widgets_test.dart`
- Modify: `test/ui/core/widgets/display_widgets_test.dart`

**Interfaces:**
- Consumes: `CompanyLogo.card` (`company_logo.dart`); `AppColors`, `AppSpacing`, `AppRadius`.
- Produces:
  - `AppTextField` — parâmetros novos, todos opcionais: `String? helperText`, `String? labelTrailing`, `Widget? trailing`, `TextCapitalization textCapitalization`, `List<TextInputFormatter>? inputFormatters`, `bool readOnly`, `VoidCallback? onTap`, `int? minLines`, `int? maxLines` (padrão 1; `null` cresce sem limite), `bool mono`.
  - `AppDangerOutlineButton({required String label, VoidCallback? onPressed, bool isLoading, IconData? icon})`.
  - `AppTextButton({required String label, VoidCallback? onPressed, AppTextButtonTone tone})`; `enum AppTextButtonTone { primary, neutral }`.
  - `AppIconAction({required IconData icon, required String tooltip, VoidCallback? onPressed})` — 48×48; sem ação, apagado.
  - `AppTopBar({..., List<Widget> actions})` — antes do `trailing`.
  - `SessionContextHeader({required String companyName, required String subtitle, String? logoUrl, bool muted})`.
  - `AppTypography.fieldValueMono`, `fieldOptional`, `contextTitle`, `buttonDanger`, `textAction`.

- [ ] **Step 1: Escrever os testes que falham**

**Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_top_bar.dart';
import 'package:simtc/ui/core/widgets/company_logo.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/core/widgets/severity_badge.dart';
import 'package:simtc/ui/core/widgets/skeleton.dart';
import 'package:simtc/ui/core/widgets/status_chip.dart';
```

**por:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_top_bar.dart';
import 'package:simtc/ui/core/widgets/company_logo.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/core/widgets/session_context_header.dart';
import 'package:simtc/ui/core/widgets/severity_badge.dart';
import 'package:simtc/ui/core/widgets/skeleton.dart';
import 'package:simtc/ui/core/widgets/status_chip.dart';
```

**Em `test/ui/core/widgets/display_widgets_test.dart`, substituir:**

```dart
    expect(find.text('Detalhe da sessão'), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });
}
```

**por:**

```dart
    expect(find.text('Detalhe da sessão'), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('AppTopBar põe os atalhos entre o título e o indicador',
      (tester) async {
    var taps = 0;
    await _pump(
      tester,
      AppTopBar(
        title: 'Detalhe da sessão',
        actions: [
          AppIconAction(
            icon: AppIcons.search,
            tooltip: 'Editar dados do treinamento',
            onPressed: () => taps++,
          ),
        ],
        trailing: const SyncStatusIndicator(),
      ),
    );

    final title = tester.getCenter(find.text('Detalhe da sessão')).dx;
    final action = tester.getCenter(find.byType(AppIconAction)).dx;
    final indicator = tester.getCenter(find.byType(SyncStatusIndicator)).dx;
    expect(title, lessThan(action));
    expect(action, lessThan(indicator));

    await tester.tap(find.byTooltip('Editar dados do treinamento'));
    expect(taps, 1);
  });

  group('SessionContextHeader', () {
    testWidgets('mostra as iniciais (sem logo), a empresa e a linha de apoio',
        (tester) async {
      await _pump(
        tester,
        const SessionContextHeader(
          companyName: 'Bracell Celulose',
          subtitle: 'Direção Defensiva — Veículo Pesado',
        ),
      );

      expect(find.text('BC'), findsOneWidget);
      expect(find.text('Bracell Celulose'), findsOneWidget);
      expect(find.text('Direção Defensiva — Veículo Pesado'), findsOneWidget);
    });

    testWidgets('apagada usa o fundo da tela; a normal, o da superfície',
        (tester) async {
      Color? background() {
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(SessionContextHeader),
                matching: find.byType(Container),
              )
              .first,
        );
        return (container.decoration! as BoxDecoration).color;
      }

      await _pump(
        tester,
        const SessionContextHeader(companyName: 'Bracell', subtitle: 'Curso'),
      );
      expect(background(), AppColors.surface);

      await _pump(
        tester,
        const SessionContextHeader(
          companyName: 'Bracell',
          subtitle: 'Curso',
          muted: true,
        ),
      );
      expect(background(), AppColors.background);
    });

    testWidgets('nome e apoio compridos encolhem com reticências, sem estourar',
        (tester) async {
      await _pump(
        tester,
        const SizedBox(
          width: 320,
          child: SessionContextHeader(
            companyName: 'Transportes Vale Norte Sociedade Anônima do Brasil',
            subtitle: 'Direção Defensiva — Veículo Pesado · Reciclagem anual',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
```

**Em `test/ui/core/widgets/form_widgets_test.dart`, substituir:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_checkbox.dart';
import 'package:simtc/ui/core/widgets/app_text_field.dart';
```

**por:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/theme/app_typography.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_checkbox.dart';
import 'package:simtc/ui/core/widgets/app_text_field.dart';
```

**Em `test/ui/core/widgets/form_widgets_test.dart`, substituir:**

```dart
      );
      expect(toggleSize.width, greaterThanOrEqualTo(48));
      expect(toggleSize.height, greaterThanOrEqualTo(48));
    });
  });
```

**por:**

```dart
      );
      expect(toggleSize.width, greaterThanOrEqualTo(48));
      expect(toggleSize.height, greaterThanOrEqualTo(48));
    });

    testWidgets('mostra o texto de apoio, e o erro toma o lugar dele', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(label: 'CPF', controller: controller, helperText: 'CPF válido.'),
      );
      expect(find.text('CPF válido.'), findsOneWidget);

      await _pump(
        tester,
        AppTextField(
          label: 'CPF',
          controller: controller,
          helperText: 'CPF válido.',
          errorText: 'CPF inválido.',
        ),
      );
      expect(find.text('CPF inválido.'), findsOneWidget);
      expect(find.text('CPF válido.'), findsNothing);
    });

    testWidgets('mostra a nota ao lado do rótulo e o widget à direita do texto',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(
          label: 'E-mail',
          controller: controller,
          labelTrailing: 'opcional',
          trailing: const Icon(AppIcons.approved, key: Key('ok')),
        ),
      );

      expect(find.text('opcional'), findsOneWidget);
      expect(find.byKey(const Key('ok')), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const Key('ok'))).dx,
        greaterThan(tester.getCenter(find.byType(TextField)).dx),
      );
    });

    testWidgets('aplica os formatadores de entrada e a capitalização', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(
          label: 'UF',
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(2)],
        ),
      );

      await tester.enterText(find.byType(TextField), 'MGX');
      expect(controller.text, 'MG');
      expect(
        tester.widget<TextField>(find.byType(TextField)).textCapitalization,
        TextCapitalization.characters,
      );
    });

    testWidgets(
        'só leitura: o toque em qualquer ponto da caixa chama a ação e não '
        'abre o teclado', (tester) async {
      final controller = TextEditingController(text: '12 set 2026');
      addTearDown(controller.dispose);
      var taps = 0;

      await _pump(
        tester,
        AppTextField(
          label: 'Data',
          controller: controller,
          icon: AppIcons.event,
          readOnly: true,
          onTap: () => taps++,
        ),
      );

      // `tapAt`: o campo de dentro não recebe o ponteiro (é a caixa que
      // responde), e o `tap` num widget assim avisa que errou o alvo.
      await tester.tapAt(tester.getCenter(find.byIcon(AppIcons.event)));
      await tester.tapAt(tester.getCenter(find.text('12 set 2026')));
      await tester.pump();

      expect(taps, 2);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('só leitura e desabilitado: o toque não chama a ação', (tester) async {
      final controller = TextEditingController(text: '12 set 2026');
      addTearDown(controller.dispose);
      var taps = 0;

      await _pump(
        tester,
        AppTextField(
          label: 'Data',
          controller: controller,
          readOnly: true,
          enabled: false,
          onTap: () => taps++,
        ),
      );

      await tester.tapAt(tester.getCenter(find.text('12 set 2026')));
      expect(taps, 0);
    });

    testWidgets('várias linhas: cresce a partir do mínimo e fica mais alto que '
        'um campo comum', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(
          label: 'Observações',
          controller: controller,
          minLines: 3,
          maxLines: null,
          keyboardType: TextInputType.multiline,
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 3);
      expect(field.maxLines, isNull);
      expect(tester.getSize(find.byType(AppTextField)).height, greaterThan(96));
    });

    testWidgets('mono: o valor usa a fonte de números', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(tester, AppTextField(label: 'CPF', controller: controller, mono: true));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.fontFamily, AppTypography.monoFamily);
    });
  });
```

**Em `test/ui/core/widgets/form_widgets_test.dart`, substituir:**

```dart
    });
  });

  group('AppCheckbox', () {
    testWidgets('o toque devolve o valor invertido', (tester) async {
      bool? received;
```

**por:**

```dart
    });
  });

  group('AppDangerOutlineButton', () {
    testWidgets('dispara a ação, com 56dp de altura e a tinta de perigo',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AppDangerOutlineButton(
          label: 'Cancelar sessão',
          icon: AppIcons.needsReview,
          onPressed: () => taps++,
        ),
      );

      await tester.tap(find.text('Cancelar sessão'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(AppDangerOutlineButton)).height, 56);

      final context = tester.element(find.text('Cancelar sessão'));
      expect(DefaultTextStyle.of(context).style.color, AppColors.dangerInk);
      expect(find.byIcon(AppIcons.needsReview), findsOneWidget);
    });

    testWidgets('em carregamento mostra o indicador e não responde ao toque',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AppDangerOutlineButton(
          label: 'Cancelar sessão',
          isLoading: true,
          onPressed: () => taps++,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Cancelar sessão'), findsNothing);

      await tester.tap(find.byType(AppDangerOutlineButton));
      expect(taps, 0);
    });

    testWidgets('sem ação, fica desabilitado', (tester) async {
      await _pump(tester, const AppDangerOutlineButton(label: 'Cancelar sessão'));

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('AppTextButton', () {
    testWidgets('dispara a ação e tem o alvo mínimo de toque', (tester) async {
      var taps = 0;
      await _pump(tester, AppTextButton(label: 'Descartar', onPressed: () => taps++));

      await tester.tap(find.text('Descartar'));
      expect(taps, 1);
      expect(
        tester.getSize(find.byType(AppTextButton)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('o tom neutro usa a tinta de texto, não a de marca', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            AppTextButton(label: 'Salvar e adicionar outro', onPressed: () {}),
            AppTextButton(
              label: 'Descartar',
              tone: AppTextButtonTone.neutral,
              onPressed: () {},
            ),
          ],
        ),
      );

      Color? inkOf(String label) =>
          DefaultTextStyle.of(tester.element(find.text(label))).style.color;
      expect(inkOf('Salvar e adicionar outro'), AppColors.primaryDark);
      expect(inkOf('Descartar'), AppColors.text3);
    });

    testWidgets('sem ação, fica desabilitado', (tester) async {
      await _pump(tester, const AppTextButton(label: 'Descartar'));

      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(button.onPressed, isNull);
    });
  });

  group('AppIconAction', () {
    testWidgets('dispara a ação num alvo de 48dp, com a dica de acessibilidade',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        Row(
          children: [
            AppIconAction(
              icon: AppIcons.search,
              tooltip: 'Editar dados do treinamento',
              onPressed: () => taps++,
            ),
          ],
        ),
      );

      await tester.tap(find.byTooltip('Editar dados do treinamento'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(AppIconAction)), const Size(48, 48));
    });

    testWidgets('sem ação, continua visível, apagado, e não responde',
        (tester) async {
      await _pump(
        tester,
        const Row(
          children: [
            AppIconAction(icon: AppIcons.search, tooltip: 'Editar dados do treinamento'),
          ],
        ),
      );

      expect(find.byIcon(AppIcons.search), findsOneWidget);
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull);
      expect(button.disabledColor, AppColors.textMuted);
    });
  });

  group('AppCheckbox', () {
    testWidgets('o toque devolve o valor invertido', (tester) async {
      bool? received;
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/core/widgets`
Esperado: os dois arquivos não compilam — `No named parameter with the name 'helperText'` (e os demais parâmetros novos), `Method not found: 'AppDangerOutlineButton'`, `No named parameter with the name 'actions'` e `Error when reading 'lib/ui/core/widgets/session_context_header.dart'`.

- [ ] **Step 3: Implementar**

**Em `lib/ui/core/theme/app_typography.dart`, substituir:**

```dart
  static TextStyle get fieldValue =>
      _inter(size: 16, weight: FontWeight.w400, height: 1.3);

  /// Rótulo de chip (status, severidade, filtro)
  static TextStyle get chipLabel =>
      _inter(size: 12, weight: FontWeight.w600, height: 1.2);
```

**por:**

```dart
  static TextStyle get fieldValue =>
      _inter(size: 16, weight: FontWeight.w400, height: 1.3);

  /// Texto digitado em campo de número (o CPF de "Adicionar participante")
  static TextStyle get fieldValueMono =>
      _mono(size: 16, weight: FontWeight.w600, height: 1.3);

  /// Nota à direita do rótulo de um campo ("opcional")
  static TextStyle get fieldOptional =>
      _inter(size: 11.5, weight: FontWeight.w400, height: 1.2, color: AppColors.textMuted);

  /// Empresa na faixa de contexto dos formulários de ADMIN (canvas "3b")
  static TextStyle get contextTitle =>
      _inter(size: 15, weight: FontWeight.w600, height: 1.25);

  /// Rótulo de chip (status, severidade, filtro)
  static TextStyle get chipLabel =>
      _inter(size: 12, weight: FontWeight.w600, height: 1.2);
```

**Em `lib/ui/core/theme/app_typography.dart`, substituir:**

```dart
  /// Texto de botão compacto, dentro de uma linha de lista ("Atribuir a mim")
  static TextStyle get buttonCompact =>
      _inter(size: 14, weight: FontWeight.w700, height: 1.2, color: AppColors.ctaInk);

  /// Link discreto ("Esqueci a senha")
  static TextStyle get link =>
```

**por:**

```dart
  /// Texto de botão compacto, dentro de uma linha de lista ("Atribuir a mim")
  static TextStyle get buttonCompact =>
      _inter(size: 14, weight: FontWeight.w700, height: 1.2, color: AppColors.ctaInk);

  /// Texto do botão de contorno vermelho ("Cancelar sessão", canvas "3b")
  static TextStyle get buttonDanger =>
      _inter(size: 15, weight: FontWeight.w700, height: 1.2, color: AppColors.dangerInk);

  /// Ação em texto sob o botão principal de um rodapé ("Descartar")
  static TextStyle get textAction =>
      _inter(size: 14, weight: FontWeight.w600, height: 1.2, color: AppColors.primaryDark);

  /// Link discreto ("Esqueci a senha")
  static TextStyle get link =>
```

**Em `lib/ui/core/widgets/app_buttons.dart`, substituir:**

```dart
        ],
      ],
    );
  }
}
```

**por:**

```dart
        ],
      ],
    );
  }
}

/// Ação destrutiva em contorno vermelho, na caixa do botão principal —
/// "Cancelar sessão" (canvas "3b"): mora no fim da tela, longe do salvar.
class AppDangerOutlineButton extends StatelessWidget {
  const AppDangerOutlineButton({
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
      height: AppSpacing.controlHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.dangerInk,
          disabledForegroundColor:
              isLoading ? AppColors.dangerInk : AppColors.textMuted,
          side: BorderSide(
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
    );
  }

  Widget _buildSpinner() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.dangerInk),
      ),
    );
  }

  Widget _buildContent() {
    return Row(
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
}

/// Tinta do [AppTextButton].
enum AppTextButtonTone {
  /// Cor de marca — uma segunda forma de concluir ("Salvar e adicionar outro").
  primary,

  /// Cinza — desistir ("Descartar").
  neutral,
}

/// Ação secundária em texto, sob o botão principal de um rodapé (canvas "3a"
/// e "3b"). Ocupa a largura toda, com o alvo mínimo de toque.
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.tone = AppTextButtonTone.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppTextButtonTone tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: tone == AppTextButtonTone.primary
              ? AppColors.primaryDark
              : AppColors.text3,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.textAction,
        ),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Atalho de ícone: um alvo de toque inteiro (48dp) em volta de um ícone na
/// cor de marca — o lápis da barra superior e o "adicionar participante" do
/// detalhe da sessão (canvas "1f", que os desenha com 32dp). Sem ação, fica
/// apagado: as ações de ADMIN nunca somem, só desabilitam.
class AppIconAction extends StatelessWidget {
  const AppIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.touchTarget,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 22),
        color: AppColors.primaryDark,
        disabledColor: AppColors.textMuted,
        onPressed: onPressed,
      ),
    );
  }
}
```

**Substituir o conteúdo inteiro de `lib/ui/core/widgets/app_text_field.dart` por:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Campo de texto do Design System: rótulo acima, ícone à esquerda, borda que
/// reage a foco e erro, e ação opcional à direita (ex.: mostrar/ocultar senha).
///
/// Componente sem regra de negócio — recebe estado e devolve eventos.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.hintText,
    this.errorText,
    this.helperText,
    this.labelTrailing,
    this.trailing,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.minLines,
    this.maxLines = 1,
    this.mono = false,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final String? hintText;
  final String? errorText;

  /// Texto de apoio sob o campo ("CPF válido e sem cadastro nesta sessão.").
  /// O [errorText], quando existe, toma o lugar dele.
  final String? helperText;

  /// Nota discreta à direita do rótulo ("opcional").
  final String? labelTrailing;

  /// Widget à direita do texto, dentro da caixa — o check do CPF válido, o
  /// indicador de consulta.
  final Widget? trailing;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  /// Campo que não se digita: o toque em qualquer ponto da caixa chama
  /// [onTap] (a data, que abre o calendário) e o teclado não abre.
  final bool readOnly;
  final VoidCallback? onTap;

  /// Mais de uma linha (as observações). `maxLines: null` cresce sem limite.
  final int? minLines;
  final int? maxLines;

  /// Valor na fonte de números (o CPF).
  final bool mono;
  final List<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _internalFocusNode;
  bool _isFocused = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  bool get _isMultiline => widget.maxLines != 1;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  Color get _borderColor {
    if (widget.errorText != null) return AppColors.dangerInk;
    if (_isFocused) return AppColors.primary;
    return AppColors.borderStrong;
  }

  Color get _iconColor {
    if (widget.errorText != null) return AppColors.dangerInk;
    if (_isFocused) return AppColors.primary;
    return AppColors.text3;
  }

  @override
  Widget build(BuildContext context) {
    final helperText = widget.helperText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: AppSpacing.sm - 1),
        _buildInput(),
        if (widget.errorText != null) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          _buildError(),
        ] else if (helperText != null) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          Text(helperText, style: AppTypography.meta),
        ],
      ],
    );
  }

  Widget _buildLabel() {
    final label = Text(widget.label, style: AppTypography.fieldLabel);
    final trailing = widget.labelTrailing;
    if (trailing == null) return label;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: label),
        Text(trailing, style: AppTypography.fieldOptional),
      ],
    );
  }

  Widget _buildInput() {
    final trailing = widget.trailing;
    final box = Container(
      constraints: BoxConstraints(
        minHeight:
            _isMultiline ? AppSpacing.huge * 2 : AppSpacing.controlHeight,
      ),
      decoration: BoxDecoration(
        color: widget.enabled ? AppColors.surface : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: _borderColor, width: 1),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 2,
        vertical: _isMultiline ? AppSpacing.md : 0,
      ),
      child: Row(
        crossAxisAlignment: _isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: _iconColor),
            const SizedBox(width: AppSpacing.sm + 2),
          ],
          Expanded(child: _buildTextField()),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing,
          ],
          if (widget.onToggleObscure != null) _buildObscureToggle(),
        ],
      ),
    );
    if (!widget.readOnly) return box;

    // Só leitura: a caixa inteira é o alvo do toque, e o campo de dentro não
    // recebe o ponteiro — assim o teclado nunca abre.
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: IgnorePointer(child: box),
      ),
    );
  }

  TextStyle get _valueStyle {
    if (widget.obscureText) return AppTypography.passwordDots;
    return widget.mono ? AppTypography.fieldValueMono : AppTypography.fieldValue;
  }

  Widget _buildTextField() {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: _valueStyle,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: widget.hintText,
        hintStyle: AppTypography.fieldValue.copyWith(color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildObscureToggle() {
    return Semantics(
      button: true,
      label: widget.obscureText ? 'Mostrar senha' : 'Ocultar senha',
      child: InkWell(
        onTap: widget.onToggleObscure,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // A área de toque é o tamanho do filho: um ícone de 22 com padding
        // pequeno daria ~38 dp, abaixo do mínimo de 48 dp exigido para uso com
        // o veículo em movimento.
        child: SizedBox(
          width: AppSpacing.touchTarget,
          height: AppSpacing.touchTarget,
          child: Center(
            child: Icon(
              widget.obscureText ? AppIcons.showPassword : AppIcons.hidePassword,
              size: 22,
              color: AppColors.text3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Text(
      widget.errorText!,
      style: AppTypography.meta.copyWith(color: AppColors.dangerInk),
    );
  }
}
```

**Em `lib/ui/core/widgets/app_top_bar.dart`, substituir:**

```dart
/// atalho à direita.
///
/// O lado direito sempre reserva o espaço de um alvo de toque, com ou sem
/// atalho — é o que mantém o título no centro da tela.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.trailing,
    this.leadingIcon = AppIcons.back,
    this.leadingIconSize = 30,
```

**por:**

```dart
/// atalho à direita.
///
/// O lado direito sempre reserva o espaço de um alvo de toque, com ou sem
/// atalho — é o que mantém o título no centro da tela. Com [actions], o
/// título fica centrado no espaço que sobra, como no canvas "1f".
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.trailing,
    this.leadingIcon = AppIcons.back,
    this.leadingIconSize = 30,
```

**Em `lib/ui/core/widgets/app_top_bar.dart`, substituir:**

```dart
  });

  final String title;
  final Widget? trailing;

  /// O botão da esquerda: o voltar, ou o fechar do Resultado (canvas "2g").
```

**por:**

```dart
  });

  final String title;

  /// Atalhos antes do [trailing] — o lápis do ADMIN no detalhe da sessão.
  /// Cada um traz o próprio alvo de toque (`AppIconAction`).
  final List<Widget> actions;
  final Widget? trailing;

  /// O botão da esquerda: o voltar, ou o fechar do Resultado (canvas "2g").
```

**Em `lib/ui/core/widgets/app_top_bar.dart`, substituir:**

```dart
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox.square(dimension: AppSpacing.touchTarget, child: trailing),
        ],
      ),
```

**por:**

```dart
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
          SizedBox.square(dimension: AppSpacing.touchTarget, child: trailing),
        ],
      ),
```

**Criar `lib/ui/core/widgets/session_context_header.dart`:**

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'company_logo.dart';

/// Faixa de contexto no topo dos formulários de ADMIN (canvas "3a" e "3b"):
/// o logo da empresa e duas linhas dizendo em que sessão o admin está
/// mexendo — ele cadastra em sequência e precisa saber onde está.
class SessionContextHeader extends StatelessWidget {
  const SessionContextHeader({
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

  /// Fundo da tela em vez do da superfície (canvas "3a").
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: muted ? AppColors.background : AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          CompanyLogo.card(companyName: companyName, url: logoUrl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: AppTypography.contextTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs + 1),
                Text(
                  subtitle,
                  style: AppTypography.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

No campo só leitura, o campo de dentro fica sob um `IgnorePointer`: é a caixa inteira que responde ao toque, e por isso o teclado nunca abre. Nos botões novos, a cor do texto vem do `foregroundColor` — o `textStyle` só dá tamanho e peso.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/core/widgets`
Esperado: `+52: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+505: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/ui/core/theme/app_typography.dart \
  apps/mobile/simtc/lib/ui/core/widgets/app_buttons.dart \
  apps/mobile/simtc/lib/ui/core/widgets/app_text_field.dart \
  apps/mobile/simtc/lib/ui/core/widgets/app_top_bar.dart \
  apps/mobile/simtc/lib/ui/core/widgets/session_context_header.dart \
  apps/mobile/simtc/test/ui/core/widgets/display_widgets_test.dart \
  apps/mobile/simtc/test/ui/core/widgets/form_widgets_test.dart
git commit -m "feat(mobile): componentes do ds para os formularios de admin"
```

---

## Task 4: Repositório — editar e cancelar a sessão

Os dois endpoints já existem no backend e são usados pelo painel web. O app os chama com o mesmo formato do web: a data como `AAAA-MM-DD` (o backend grava meia-noite UTC, e o app lê os três campos de calendário, sem conversão de fuso). `update` manda só o que mudou — nulo quer dizer "não mudou".

**Files:**
- Modify: `lib/data/repositories/session_repository.dart`
- Modify: `test/data/repositories/session_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient.patch<T>(String path, {Object? data})`; `ApiException`; `SessionStatus.cancelado.wireValue`.
- Produces:
  - `Future<Result<void>> SessionRepository.update(String sessionId, {DateTime? date, String? city, String? state, String? notes})` — `PATCH /training-sessions/:id` só com os campos não nulos; sem nenhum, devolve sucesso sem chamar o servidor. Com sucesso, grava os mesmos campos no cache.
  - `Future<Result<void>> SessionRepository.cancel(String sessionId)` — `PATCH /training-sessions/:id/cancel`. Com sucesso, o status local vira `CANCELADO`.
  - Nos dois, a mensagem do `Failure` é a do backend em 403 e 404 e a de falta de rede; no resto, "Não foi possível salvar as alterações. Tente de novo." / "Não foi possível cancelar a sessão. Tente de novo."

- [ ] **Step 1: Escrever os testes que falham**

**Em `test/data/repositories/session_repository_test.dart`, substituir:**

```dart
      expect(row.status, 'PLANEJADO');
    });
  });
}
```

**por:**

```dart
      expect(row.status, 'PLANEJADO');
    });
  });

  group('edição pelo ADMIN', () {
    const path = '/training-sessions/s1';

    Future<void> seedSession() {
      return db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: 's1',
              companyName: 'Bracell Celulose',
              courseName: 'Direção Preventiva',
              city: 'Itabira',
              state: 'MG',
              date: Value(DateTime(2026, 9, 12)),
              status: 'EM_ANDAMENTO',
              notes: const Value('Pátio 3 — portaria B.'),
              cachedAt: DateTime(2026, 9, 22, 8),
            ),
          );
    }

    Response<Map<String, dynamic>> ok(String requestPath) {
      return Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: requestPath),
        statusCode: 200,
        data: {'id': 's1'},
      );
    }

    void patchAnswers() {
      when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
          .thenAnswer((_) async => ok(path));
    }

    Object? sentBody() {
      return verify(
        () => api.patch<Map<String, dynamic>>(path, data: captureAny(named: 'data')),
      ).captured.single;
    }

    group('update', () {
      test(
          'manda só o que mudou, com a data como AAAA-MM-DD, e já grava no '
          'cache', () async {
        await seedSession();
        patchAnswers();

        final result = await repository.update(
          's1',
          date: DateTime(2026, 10, 3),
          notes: '',
        );

        expect(result.isSuccess, isTrue);
        expect(sentBody(), {'date': '2026-10-03', 'notes': ''});
        final row = await db.select(db.sessions).getSingle();
        expect(row.date, DateTime(2026, 10, 3));
        expect(row.notes, '');
        expect(row.city, 'Itabira', reason: 'o que não mudou fica como estava');
        expect(row.state, 'MG');
      });

      test('cidade e UF vão separadas, como o backend guarda', () async {
        await seedSession();
        patchAnswers();

        final result = await repository.update('s1', city: 'Betim', state: 'SP');

        expect(result.isSuccess, isTrue);
        expect(sentBody(), {'city': 'Betim', 'state': 'SP'});
        final row = await db.select(db.sessions).getSingle();
        expect(row.city, 'Betim');
        expect(row.state, 'SP');
        expect(row.date, DateTime(2026, 9, 12));
        expect(row.notes, 'Pátio 3 — portaria B.');
      });

      test('dia e mês de um dígito ganham o zero à esquerda', () async {
        await seedSession();
        patchAnswers();

        await repository.update('s1', date: DateTime(2027, 1, 5));

        expect(sentBody(), {'date': '2027-01-05'});
      });

      test('sem mudança nenhuma, não chama o servidor', () async {
        await seedSession();

        final result = await repository.update('s1');

        expect(result.isSuccess, isTrue);
        verifyNever(
          () => api.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
        );
      });

      test('403 devolve a mensagem do backend e não mexe no cache', () async {
        await seedSession();
        when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
            .thenThrow(const ApiException(
          message: 'Não é possível editar um treinamento concluído ou cancelado',
          statusCode: 403,
        ));

        final result = await repository.update('s1', city: 'Betim');

        expect(
          result,
          isA<Failure<void>>().having(
            (f) => f.message,
            'message',
            'Não é possível editar um treinamento concluído ou cancelado',
          ),
        );
        final row = await db.select(db.sessions).getSingle();
        expect(row.city, 'Itabira');
      });

      test('sem rede, a mensagem de falta de conexão', () async {
        await seedSession();
        when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
            .thenThrow(const ApiException(
          message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
          isNetworkError: true,
        ));

        final result = await repository.update('s1', city: 'Betim');

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
        await seedSession();
        when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
            .thenThrow(const ApiException(
          message: 'city must be a string',
          statusCode: 400,
        ));

        final result = await repository.update('s1', city: 'Betim');

        expect(
          result,
          isA<Failure<void>>().having(
            (f) => f.message,
            'message',
            'Não foi possível salvar as alterações. Tente de novo.',
          ),
        );
      });
    });

    group('cancel', () {
      const cancelPath = '/training-sessions/s1/cancel';

      test('chama o /cancel e já marca a sessão local como cancelada',
          () async {
        await seedSession();
        when(() => api.patch<Map<String, dynamic>>(cancelPath))
            .thenAnswer((_) async => ok(cancelPath));

        final result = await repository.cancel('s1');

        expect(result.isSuccess, isTrue);
        final row = await db.select(db.sessions).getSingle();
        expect(row.status, 'CANCELADO');
      });

      test('403 devolve a mensagem do backend e não mexe no status local',
          () async {
        await seedSession();
        when(() => api.patch<Map<String, dynamic>>(cancelPath))
            .thenThrow(const ApiException(
          message: 'Não é possível cancelar um treinamento já concluído',
          statusCode: 403,
        ));

        final result = await repository.cancel('s1');

        expect(
          result,
          isA<Failure<void>>().having(
            (f) => f.message,
            'message',
            'Não é possível cancelar um treinamento já concluído',
          ),
        );
        final row = await db.select(db.sessions).getSingle();
        expect(row.status, 'EM_ANDAMENTO');
      });

      test('erro inesperado do servidor vira uma mensagem genérica', () async {
        await seedSession();
        when(() => api.patch<Map<String, dynamic>>(cancelPath)).thenThrow(
          const ApiException(message: 'Internal server error', statusCode: 500),
        );

        final result = await repository.cancel('s1');

        expect(
          result,
          isA<Failure<void>>().having(
            (f) => f.message,
            'message',
            'Não foi possível cancelar a sessão. Tente de novo.',
          ),
        );
        final row = await db.select(db.sessions).getSingle();
        expect(row.status, 'EM_ANDAMENTO');
      });
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/data/repositories/session_repository_test.dart`
Esperado: não compila — `The method 'update' isn't defined for the type 'SessionRepository'` e `The method 'cancel' isn't defined for the type 'SessionRepository'`.

- [ ] **Step 3: Implementar**

**Em `lib/data/repositories/session_repository.dart`, substituir:**

```dart

  static const String _startFailed =
      'Não foi possível iniciar a sessão. Tente de novo.';

  /// Lista do cache, da data mais próxima para a mais distante; sem data por
  /// último, porque não dá para saber onde ela entra na agenda.
```

**por:**

```dart

  static const String _startFailed =
      'Não foi possível iniciar a sessão. Tente de novo.';

  static const String _updateFailed =
      'Não foi possível salvar as alterações. Tente de novo.';

  static const String _cancelFailed =
      'Não foi possível cancelar a sessão. Tente de novo.';

  /// `AAAA-MM-DD`: a data de calendário como o backend a recebe — o mesmo
  /// formato que o painel web manda de um `<input type="date">`.
  static String _isoDate(DateTime date) {
    String dois(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${dois(date.month)}-${dois(date.day)}';
  }

  /// Lista do cache, da data mais próxima para a mais distante; sem data por
  /// último, porque não dá para saber onde ela entra na agenda.
```

**Em `lib/data/repositories/session_repository.dart`, substituir:**

```dart
    return const Success<void>(null);
  }

  /// Quando o cache foi atualizado pela última vez — a tela mostra isso quando
  /// está offline, para o consultor saber a idade do que está vendo.
  Stream<DateTime?> watchLastSyncedAt() {
```

**por:**

```dart
    return const Success<void>(null);
  }

  /// "Dados do treinamento" (Fase 6A): edita data, cidade, UF e observações
  /// (`PATCH /training-sessions/:id`, só ADMIN). Nulo quer dizer "não mudou"
  /// e não é enviado — assim uma edição feita no painel web em outro campo
  /// não é desfeita por um valor velho do cache. Observações vazias limpam o
  /// campo no servidor; a data não tem como ser apagada (o backend ignora
  /// data vazia).
  ///
  /// O backend recusa (403) sessão concluída ou cancelada. Com sucesso, o
  /// cache muda na hora, sem esperar o re-sync do detalhe.
  Future<Result<void>> update(
    String sessionId, {
    DateTime? date,
    String? city,
    String? state,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      if (date != null) 'date': _isoDate(date),
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (notes != null) 'notes': notes,
    };
    if (body.isEmpty) return const Success<void>(null);

    try {
      await _api.patch<Map<String, dynamic>>('$_path/$sessionId', data: body);
    } on ApiException catch (error) {
      return Failure(error, _ownMessage(error) ? error.message : _updateFailed);
    } catch (error) {
      return Failure(Exception('$error'), _updateFailed);
    }

    try {
      await (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId)))
          .write(
        SessionsCompanion(
          date: date == null ? const Value.absent() : Value(date),
          city: city == null ? const Value.absent() : Value(city),
          state: state == null ? const Value.absent() : Value(state),
          notes: notes == null ? const Value.absent() : Value(notes),
        ),
      );
    } catch (_) {
      // O backend já gravou; o re-sync do detalhe corrige a linha local.
    }
    return const Success<void>(null);
  }

  /// "Cancelar sessão" (`PATCH /training-sessions/:id/cancel`, só ADMIN). O
  /// backend recusa (403) sessão já concluída ou já cancelada, e não há como
  /// desfazer. Com sucesso, o status local muda na hora — e a Home deixa de
  /// mostrar a sessão (decisão de 20/09/2026).
  Future<Result<void>> cancel(String sessionId) async {
    try {
      await _api.patch<Map<String, dynamic>>('$_path/$sessionId/cancel');
    } on ApiException catch (error) {
      return Failure(error, _ownMessage(error) ? error.message : _cancelFailed);
    } catch (error) {
      return Failure(Exception('$error'), _cancelFailed);
    }

    try {
      await (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId)))
          .write(
        SessionsCompanion(status: Value(SessionStatus.cancelado.wireValue)),
      );
    } catch (_) {
      // O backend já cancelou; o próximo sync corrige a linha local.
    }
    return const Success<void>(null);
  }

  /// Recusas do backend que explicam o que houve — 403 (sessão concluída ou
  /// cancelada) e 404 (sessão apagada) — e a falta de rede, cuja mensagem já
  /// diz o que fazer. O resto (400 de validação, 5xx) vira o texto genérico.
  static bool _ownMessage(ApiException error) =>
      error.statusCode == 403 || error.statusCode == 404 || error.isNetworkError;

  /// Quando o cache foi atualizado pela última vez — a tela mostra isso quando
  /// está offline, para o consultor saber a idade do que está vendo.
  Stream<DateTime?> watchLastSyncedAt() {
```

**Em `lib/data/repositories/session_repository.dart`, substituir:**

```dart
    final from = DateTime.now().subtract(
      const Duration(days: _historyWindowDays),
    );
    String dois(int value) => value.toString().padLeft(2, '0');

    try {
      for (var page = 1; page <= _maxPages; page++) {
```

**por:**

```dart
    final from = DateTime.now().subtract(
      const Duration(days: _historyWindowDays),
    );

    try {
      for (var page = 1; page <= _maxPages; page++) {
```

**Em `lib/data/repositories/session_repository.dart`, substituir:**

```dart
          queryParameters: {
            'page': page,
            'limit': _pageSize,
            'from': '${from.year}-${dois(from.month)}-${dois(from.day)}',
          },
        );
```

**por:**

```dart
          queryParameters: {
            'page': page,
            'limit': _pageSize,
            'from': _isoDate(from),
          },
        );
```

O `_isoDate` também passa a servir o `from` do `syncAll`, que formatava a data do mesmo jeito, à mão.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/data/repositories/session_repository_test.dart`
Esperado: `+24: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+515: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/data/repositories/session_repository.dart \
  apps/mobile/simtc/test/data/repositories/session_repository_test.dart
git commit -m "feat(mobile): editar e cancelar sessao no repositorio"
```

---

## Task 5: Repositório — consultar o CPF e adicionar participante

Três peças pequenas: as funções de CPF (a mesma conta de dígitos verificadores do `ValidateCpfPipe` do backend), o modelo da resposta da consulta e os dois métodos do `ParticipantRepository`. O CPF vai sempre só com dígitos, como o painel web manda — é assim que o backend o guarda e o compara.

**Files:**
- Create: `lib/utils/cpf.dart`
- Create: `lib/data/models/cpf_lookup.dart`
- Create: `test/utils/cpf_test.dart`
- Create: `test/data/models/cpf_lookup_test.dart`
- Modify: `lib/data/repositories/participant_repository.dart`
- Modify: `test/data/repositories/participant_repository_test.dart`

**Interfaces:**
- Consumes: o endpoint da Task 1; `POST /training-sessions/:id/participants` (devolve o `TrainingParticipant` com `participant` aninhado); `SessionParticipant.fromJson(json, sessionId:)`; `maskCpf`; `ParticipantRepository._now`.
- Produces:
  - `String cpfDigits(String value)`; `bool isValidCpf(String value)`; `String formatCpf(String value)` — `lib/utils/cpf.dart`.
  - `class CpfLookup { bool registered; bool enrolled; String? name; String? email; static CpfLookup? tryParse(Object? body) }`.
  - `Future<Result<CpfLookup>> ParticipantRepository.lookupCpf(String sessionId, String cpf)` — toda falha tem a mensagem "Não foi possível consultar o CPF."
  - `Future<Result<SessionParticipant>> ParticipantRepository.add(String sessionId, {required String cpf, required String name, String? email, required ParticipationType participationType})` — a mensagem do `Failure` é a do backend em 409, 400 e 404 e a de falta de rede; no resto, "Não foi possível adicionar o participante. Tente de novo." Com sucesso, a linha entra no cache com o CPF mascarado.

- [ ] **Step 1: Escrever os testes que falham**

**Criar `test/data/models/cpf_lookup_test.dart`:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/cpf_lookup.dart';

void main() {
  test('CPF sem cadastro', () {
    final lookup = CpfLookup.tryParse({
      'registered': false,
      'name': null,
      'email': null,
      'enrolled': false,
    });

    expect(lookup, isNotNull);
    expect(lookup!.registered, isFalse);
    expect(lookup.enrolled, isFalse);
    expect(lookup.name, isNull);
    expect(lookup.email, isNull);
  });

  test('CPF com cadastro traz nome e e-mail', () {
    final lookup = CpfLookup.tryParse({
      'registered': true,
      'name': 'Fernanda Lopes Meireles',
      'email': 'fernanda@empresa.com.br',
      'enrolled': true,
    });

    expect(lookup!.registered, isTrue);
    expect(lookup.enrolled, isTrue);
    expect(lookup.name, 'Fernanda Lopes Meireles');
    expect(lookup.email, 'fernanda@empresa.com.br');
  });

  test('nome ou e-mail em branco contam como ausentes', () {
    final lookup = CpfLookup.tryParse({
      'registered': true,
      'name': '   ',
      'email': '',
      'enrolled': false,
    });

    expect(lookup!.name, isNull);
    expect(lookup.email, isNull);
  });

  test('resposta fora do formato é nula, em vez de um palpite', () {
    expect(CpfLookup.tryParse(null), isNull);
    expect(CpfLookup.tryParse(''), isNull);
    expect(CpfLookup.tryParse(const <String, dynamic>{}), isNull);
    expect(
      CpfLookup.tryParse({'registered': 'sim', 'enrolled': false}),
      isNull,
      reason: 'registered precisa ser booleano',
    );
    expect(
      CpfLookup.tryParse({'registered': true, 'name': 'Fernanda'}),
      isNull,
      reason: 'sem enrolled não dá para dizer se já está na sessão',
    );
  });
}
```

**Em `test/data/repositories/participant_repository_test.dart`, substituir:**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/remote_assessment.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
```

**por:**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/cpf_lookup.dart';
import 'package:simtc/data/models/remote_assessment.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
```

**Em `test/data/repositories/participant_repository_test.dart`, substituir:**

```dart
      );
    });
  });
}
```

**por:**

```dart
      );
    });
  });

  group('lookupCpf', () {
    const lookupPath = '/training-sessions/sess-1/participants/lookup';

    void lookupAnswers(Map<String, dynamic>? body) {
      when(() => api.post<Map<String, dynamic>>(lookupPath,
          data: any(named: 'data'))).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: lookupPath),
          statusCode: 200,
          data: body,
        ),
      );
    }

    test('manda o CPF no corpo e devolve o cadastro que o backend achou',
        () async {
      lookupAnswers({
        'registered': true,
        'name': 'Fernanda Lopes Meireles',
        'email': 'fernanda@empresa.com.br',
        'enrolled': false,
      });

      final result = await repository.lookupCpf('sess-1', '52998224725');

      final sent = verify(() => api.post<Map<String, dynamic>>(lookupPath,
          data: captureAny(named: 'data'))).captured.single;
      expect(sent, {'cpf': '52998224725'});
      final lookup = (result as Success<CpfLookup>).data;
      expect(lookup.registered, isTrue);
      expect(lookup.enrolled, isFalse);
      expect(lookup.name, 'Fernanda Lopes Meireles');
      expect(lookup.email, 'fernanda@empresa.com.br');
    });

    test('CPF já inscrito nesta sessão', () async {
      lookupAnswers({
        'registered': true,
        'name': 'Fernanda Lopes Meireles',
        'email': null,
        'enrolled': true,
      });

      final result = await repository.lookupCpf('sess-1', '52998224725');

      expect((result as Success<CpfLookup>).data.enrolled, isTrue);
    });

    test('resposta fora do formato vira falha, não "sem cadastro"', () async {
      lookupAnswers(null);

      final result = await repository.lookupCpf('sess-1', '52998224725');

      expect(
        result,
        isA<Failure<CpfLookup>>().having(
            (f) => f.message, 'message', 'Não foi possível consultar o CPF.'),
      );
    });

    test('sem rede ou com erro do servidor, a mesma falha de consulta',
        () async {
      when(() => api.post<Map<String, dynamic>>(lookupPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(message: 'Sem conexão', isNetworkError: true),
      );

      final result = await repository.lookupCpf('sess-1', '52998224725');

      expect(
        result,
        isA<Failure<CpfLookup>>().having(
            (f) => f.message, 'message', 'Não foi possível consultar o CPF.'),
      );
    });
  });

  group('add', () {
    const addPath = '/training-sessions/sess-1/participants';

    Map<String, dynamic> addedJson({
      String participationType = 'TEORICA_E_PRATICA',
    }) {
      return {
        'id': 'tp-9',
        'trainingSessionId': 'sess-1',
        'participantId': 'p-9',
        'participationType': participationType,
        'status': 'PENDENTE',
        'assignedConsultantId': null,
        'registeredAt': '2026-10-07T12:00:00.000Z',
        'participant': {
          'id': 'p-9',
          'name': 'Fernanda Lopes Meireles',
          'cpf': '52998224725',
          'email': 'fernanda@empresa.com.br',
        },
      };
    }

    void addAnswers(Map<String, dynamic>? body) {
      when(() => api.post<Map<String, dynamic>>(addPath,
          data: any(named: 'data'))).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: addPath),
          statusCode: 201,
          data: body,
        ),
      );
    }

    Object? sentBody() {
      return verify(() => api.post<Map<String, dynamic>>(addPath,
          data: captureAny(named: 'data'))).captured.single;
    }

    test(
        'inscreve no backend e a linha já entra no cache, com o CPF '
        'mascarado', () async {
      await seedSession();
      addAnswers(addedJson());

      final result = await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        email: 'fernanda@empresa.com.br',
        participationType: ParticipationType.teoricaEPratica,
      );

      expect(sentBody(), {
        'cpf': '52998224725',
        'name': 'Fernanda Lopes Meireles',
        'email': 'fernanda@empresa.com.br',
        'participationType': 'TEORICA_E_PRATICA',
      });
      final added = (result as Success<SessionParticipant>).data;
      expect(added.id, 'tp-9');
      expect(added.name, 'Fernanda Lopes Meireles');

      final row = await db.select(db.participants).getSingle();
      expect(row.id, 'tp-9');
      expect(row.sessionId, 'sess-1');
      expect(row.name, 'Fernanda Lopes Meireles');
      expect(row.cpf, '529.982.***-**', reason: 'o CPF inteiro não é guardado');
      expect(row.status, 'PENDENTE');
      expect(row.participationType, 'TEORICA_E_PRATICA');
      expect(row.assignedConsultantId, isNull);
    });

    test('sem e-mail, o campo nem é enviado; somente teórica vai com o tipo',
        () async {
      await seedSession();
      addAnswers(addedJson(participationType: 'SOMENTE_TEORICA'));

      await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        email: '',
        participationType: ParticipationType.somenteTeorica,
      );

      expect(sentBody(), {
        'cpf': '52998224725',
        'name': 'Fernanda Lopes Meireles',
        'participationType': 'SOMENTE_TEORICA',
      });
      final row = await db.select(db.participants).getSingle();
      expect(row.participationType, 'SOMENTE_TEORICA');
    });

    test('409 devolve o motivo e não cria linha', () async {
      await seedSession();
      when(() => api.post<Map<String, dynamic>>(addPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(
          message: 'CPF já inscrito neste treinamento',
          statusCode: 409,
        ),
      );

      final result = await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        participationType: ParticipationType.teoricaEPratica,
      );

      expect(
        result,
        isA<Failure<SessionParticipant>>().having(
            (f) => f.message, 'message', 'CPF já inscrito neste treinamento'),
      );
      expect(await db.select(db.participants).get(), isEmpty);
    });

    test('400 (inscrições encerradas) devolve o motivo do backend', () async {
      await seedSession();
      when(() => api.post<Map<String, dynamic>>(addPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(
          message: 'Inscrições encerradas para este treinamento',
          statusCode: 400,
        ),
      );

      final result = await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        participationType: ParticipationType.teoricaEPratica,
      );

      expect(
        result,
        isA<Failure<SessionParticipant>>().having((f) => f.message, 'message',
            'Inscrições encerradas para este treinamento'),
      );
    });

    test('erro inesperado do servidor vira uma mensagem genérica', () async {
      await seedSession();
      when(() => api.post<Map<String, dynamic>>(addPath,
          data: any(named: 'data'))).thenThrow(
        const ApiException(message: 'Internal server error', statusCode: 500),
      );

      final result = await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        participationType: ParticipationType.teoricaEPratica,
      );

      expect(
        result,
        isA<Failure<SessionParticipant>>().having((f) => f.message, 'message',
            'Não foi possível adicionar o participante. Tente de novo.'),
      );
    });

    test(
        'aceito pelo backend com o corpo fora do formato: sucesso, sem linha '
        'no cache', () async {
      await seedSession();
      addAnswers(null);

      final result = await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        participationType: ParticipationType.teoricaEPratica,
      );

      // Falhar aqui faria o admin tentar de novo e receber "CPF já inscrito".
      final added = (result as Success<SessionParticipant>).data;
      expect(added.name, 'Fernanda Lopes Meireles');
      expect(added.maskedCpf, '529.982.***-**');
      expect(await db.select(db.participants).get(), isEmpty);
    });

    test('sessão fora do cache: o backend inscreveu, e isso basta', () async {
      // Sem `seedSession()`: a linha local violaria a chave estrangeira.
      addAnswers(addedJson());

      final result = await repository.add(
        'sess-1',
        cpf: '52998224725',
        name: 'Fernanda Lopes Meireles',
        participationType: ParticipationType.teoricaEPratica,
      );

      expect(result.isSuccess, isTrue);
      expect(await db.select(db.participants).get(), isEmpty);
    });
  });
}
```

**Criar `test/utils/cpf_test.dart`:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/utils/cpf.dart';

void main() {
  group('cpfDigits', () {
    test('tira a máscara e qualquer outro caractere', () {
      expect(cpfDigits('529.982.247-25'), '52998224725');
      expect(cpfDigits(' 529 982 247/25 '), '52998224725');
      expect(cpfDigits(''), '');
    });
  });

  group('isValidCpf', () {
    test('aceita CPF com os dois dígitos verificadores certos', () {
      expect(isValidCpf('52998224725'), isTrue);
      expect(isValidCpf('111.444.777-35'), isTrue, reason: 'com máscara');
    });

    test('recusa dígito verificador errado', () {
      expect(isValidCpf('52998224726'), isFalse, reason: 'segundo dígito');
      expect(isValidCpf('52998224735'), isFalse, reason: 'primeiro dígito');
      // O CPF de exemplo do canvas ("3a") não passa na conta.
      expect(isValidCpf('318.664.920-07'), isFalse);
    });

    test('recusa tamanho errado', () {
      expect(isValidCpf(''), isFalse);
      expect(isValidCpf('5299822472'), isFalse, reason: '10 dígitos');
      expect(isValidCpf('529982247250'), isFalse, reason: '12 dígitos');
    });

    test('recusa sequência de um dígito só, que passaria na conta', () {
      expect(isValidCpf('11111111111'), isFalse);
      expect(isValidCpf('000.000.000-00'), isFalse);
    });
  });

  group('formatCpf', () {
    test('mascara conforme os dígitos chegam', () {
      expect(formatCpf(''), '');
      expect(formatCpf('529'), '529');
      expect(formatCpf('5299'), '529.9');
      expect(formatCpf('529982'), '529.982');
      expect(formatCpf('5299822'), '529.982.2');
      expect(formatCpf('529982247'), '529.982.247');
      expect(formatCpf('5299822472'), '529.982.247-2');
      expect(formatCpf('52998224725'), '529.982.247-25');
    });

    test('ignora o que não é dígito e descarta o que passa do 11º', () {
      expect(formatCpf('529.982.247-25'), '529.982.247-25');
      expect(formatCpf('529982247259999'), '529.982.247-25');
      expect(formatCpf('abc'), '');
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/utils/cpf_test.dart test/data/models/cpf_lookup_test.dart test/data/repositories/participant_repository_test.dart`
Esperado: os três não compilam — `Error when reading 'lib/utils/cpf.dart'`, `Undefined name 'CpfLookup'` e `The method 'lookupCpf' isn't defined for the type 'ParticipantRepository'`.

- [ ] **Step 3: Implementar**

**Criar `lib/data/models/cpf_lookup.dart`:**

```dart
/// O que o backend sabe de um CPF, visto de uma sessão — a resposta de
/// `POST /training-sessions/:id/participants/lookup` (Fase 6A).
class CpfLookup {
  const CpfLookup({
    required this.registered,
    required this.enrolled,
    this.name,
    this.email,
  });

  /// O CPF já tem cadastro — de outro treinamento, ou deste.
  final bool registered;

  /// O CPF já está inscrito nesta sessão.
  final bool enrolled;

  /// Nome e e-mail do cadastro, para a tela preencher. Nulos sem cadastro —
  /// e o e-mail também quando o cadastro não tem um.
  final String? name;
  final String? email;

  /// Nulo quando a resposta não tem o formato esperado: quem chama trata
  /// como "não foi possível consultar", em vez de supor que o CPF está livre.
  static CpfLookup? tryParse(Object? body) {
    if (body is! Map) return null;
    final registered = body['registered'];
    final enrolled = body['enrolled'];
    if (registered is! bool || enrolled is! bool) return null;

    return CpfLookup(
      registered: registered,
      enrolled: enrolled,
      name: _text(body['name']),
      email: _text(body['email']),
    );
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;
}
```

**Em `lib/data/repositories/participant_repository.dart`, substituir:**

```dart

import '../../utils/result.dart';
import '../../utils/scoring.dart';
import '../models/remote_assessment.dart';
import '../models/session_participant.dart';
import '../models/training_session.dart';
```

**por:**

```dart

import '../../utils/result.dart';
import '../../utils/scoring.dart';
import '../models/cpf_lookup.dart';
import '../models/remote_assessment.dart';
import '../models/session_participant.dart';
import '../models/training_session.dart';
```

**Em `lib/data/repositories/participant_repository.dart`, substituir:**

```dart
  static const String _unassignFailed =
      'Não foi possível desatribuir o participante. Tente de novo.';
  static const String _resultFailed = 'Não foi possível carregar o resultado.';

  /// Participantes da sessão em ordem de nome. A ordem de exibição (meus
  /// primeiro, somente teórica por último) é regra de tela e fica na
```

**por:**

```dart
  static const String _unassignFailed =
      'Não foi possível desatribuir o participante. Tente de novo.';
  static const String _resultFailed = 'Não foi possível carregar o resultado.';
  static const String _lookupFailed = 'Não foi possível consultar o CPF.';
  static const String _addFailed =
      'Não foi possível adicionar o participante. Tente de novo.';

  /// Participantes da sessão em ordem de nome. A ordem de exibição (meus
  /// primeiro, somente teórica por último) é regra de tela e fica na
```

**Em `lib/data/repositories/participant_repository.dart`, substituir:**

```dart
    }
    return const Success<void>(null);
  }
}
```

**por:**

```dart
    }
    return const Success<void>(null);
  }

  /// Consulta de CPF de "Adicionar participante" (Fase 6A,
  /// `POST /training-sessions/:id/participants/lookup`, só ADMIN): diz se o
  /// CPF já tem cadastro — com nome e e-mail, para a tela preencher — e se já
  /// está nesta sessão. [cpf] vai só com dígitos, no corpo (não na URL).
  ///
  /// Toda falha tem a mesma mensagem: a tela não bloqueia por causa dela —
  /// segue como formulário simples, e o backend resolve o CPF repetido.
  Future<Result<CpfLookup>> lookupCpf(String sessionId, String cpf) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/training-sessions/$sessionId/participants/lookup',
        data: {'cpf': cpf},
      );
      final lookup = CpfLookup.tryParse(response.data);
      if (lookup == null) {
        return Failure(
          Exception('resposta de participants/lookup fora do formato'),
          _lookupFailed,
        );
      }
      return Success(lookup);
    } on ApiException catch (error) {
      return Failure(error, _lookupFailed);
    } catch (error) {
      return Failure(Exception('$error'), _lookupFailed);
    }
  }

  /// "Adicionar participante" (Fase 6A): inscreve na sessão
  /// (`POST /training-sessions/:id/participants`, só ADMIN). [cpf] vai só com
  /// dígitos, como o painel web manda. Para um CPF que já tem cadastro, o
  /// backend reaproveita o cadastro e grava nele o [name] — e o [email], se
  /// vier preenchido (vazio não apaga o que já está lá).
  ///
  /// Recusas com motivo próprio: 409 (CPF já inscrito nesta sessão), 400
  /// (inscrições encerradas: sessão concluída ou cancelada) e 404.
  ///
  /// Com sucesso, a linha entra no cache na hora, já com o CPF mascarado — o
  /// CPF inteiro nunca é guardado no aparelho.
  Future<Result<SessionParticipant>> add(
    String sessionId, {
    required String cpf,
    required String name,
    String? email,
    required ParticipationType participationType,
  }) async {
    final SessionParticipant added;
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/training-sessions/$sessionId/participants',
        data: {
          'cpf': cpf,
          'name': name,
          if (email != null && email.isNotEmpty) 'email': email,
          'participationType': participationType.wireValue,
        },
      );
      added = SessionParticipant.fromJson(
        response.data ?? const <String, dynamic>{},
        sessionId: sessionId,
      );
    } on ApiException catch (error) {
      final ownMessage = error.statusCode == 409 ||
          error.statusCode == 400 ||
          error.statusCode == 404 ||
          error.isNetworkError;
      return Failure(error, ownMessage ? error.message : _addFailed);
    } catch (error) {
      return Failure(Exception('$error'), _addFailed);
    }

    // O backend já inscreveu. Um corpo fora do formato não vira falha — o
    // admin tentaria de novo e receberia "CPF já inscrito": só não há linha
    // para o cache, e o re-sync do detalhe a traz.
    if (added.id.isEmpty) {
      return Success(
        SessionParticipant(
          id: '',
          sessionId: sessionId,
          name: name,
          maskedCpf: maskCpf(cpf),
          participationType: participationType,
          status: ParticipantStatus.pendente,
        ),
      );
    }

    try {
      await _db.into(_db.participants).insertOnConflictUpdate(
            ParticipantsCompanion.insert(
              id: added.id,
              sessionId: sessionId,
              name: added.name,
              cpf: added.maskedCpf,
              participationType: added.participationType.wireValue,
              status: added.status.wireValue,
              cachedAt: _now(),
            ),
          );
    } catch (_) {
      // Sessão fora do cache, por exemplo (a linha violaria a chave
      // estrangeira): o re-sync do detalhe corrige.
    }
    return Success(added);
  }
}
```

**Criar `lib/utils/cpf.dart`:**

```dart
/// Só os dígitos de [value] — é assim que o backend guarda e recebe o CPF.
String cpfDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Confere os dois dígitos verificadores, com a mesma conta do
/// `ValidateCpfPipe` do backend — que também recusa as sequências de um
/// dígito só ("111.111.111-11" passa na conta, mas não é um CPF).
bool isValidCpf(String value) {
  final digits = cpfDigits(value);
  if (digits.length != 11 || RegExp(r'^(\d)\1+$').hasMatch(digits)) {
    return false;
  }

  for (var position = 9; position < 11; position++) {
    var sum = 0;
    for (var i = 0; i < position; i++) {
      sum += int.parse(digits[i]) * (position + 1 - i);
    }
    final check = (sum * 10) % 11 % 10;
    if (check != int.parse(digits[position])) return false;
  }
  return true;
}

/// "529.982.247-25". Aceita o CPF incompleto ("529.98"), para mascarar
/// enquanto ele é digitado; o que passa do 11º dígito é descartado.
String formatCpf(String value) {
  final digits = cpfDigits(value);
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length && i < 11; i++) {
    if (i == 3 || i == 6) buffer.write('.');
    if (i == 9) buffer.write('-');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
```

Um corpo fora do formato numa resposta 201 do `add` não vira falha: o backend já inscreveu, e uma falha faria o admin tentar de novo e receber "CPF já inscrito". Só não há linha para o cache — o re-sync do detalhe a traz.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/utils/cpf_test.dart test/data/models/cpf_lookup_test.dart test/data/repositories/participant_repository_test.dart`
Esperado: `+45: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+537: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/data/models/cpf_lookup.dart \
  apps/mobile/simtc/lib/data/repositories/participant_repository.dart \
  apps/mobile/simtc/lib/utils/cpf.dart \
  apps/mobile/simtc/test/data/models/cpf_lookup_test.dart \
  apps/mobile/simtc/test/data/repositories/participant_repository_test.dart \
  apps/mobile/simtc/test/utils/cpf_test.dart
git commit -m "feat(mobile): consultar cpf e adicionar participante no repositorio"
```

---

## Task 6: Avaliação presa não bloqueia o "Iniciar avaliação"

Hoje, qualquer avaliação iniciada e não confirmada do consultor bloqueia o "Iniciar avaliação" de todos os outros participantes — inclusive uma que ele não consegue mais abrir: a de uma sessão que foi concluída ou cancelada, a de uma sessão de que ele foi removido, ou a de um participante que foi liberado. Não há saída na interface. E o "Cancelar sessão" desta fase torna isso mais fácil de acontecer.

A regra nova (decisão 5): só conta a avaliação que ainda dá para abrir — a sessão dela está em andamento no cache e o participante continua em avaliação com o consultor. É a mesma condição com que o detalhe da sessão abre o checklist. Nada é apagado.

Para conferir "com o consultor", `findInProgressOther` e `openDraft` passam a receber o `consultantId` (o `Consultant.id`; o `ownerUserId` que já recebiam é o `AuthUser.id`). O parâmetro é obrigatório, e por isso todo teste que abre um rascunho passa a informá-lo.

**Files:**
- Modify: `lib/data/repositories/assessment_repository.dart`
- Modify: `lib/ui/checklist/checklist_viewmodel.dart`
- Modify: `test/data/repositories/assessment_repository_test.dart` (a regra)
- Modify: `test/ui/checklist/checklist_viewmodel_test.dart` (o aviso do checklist)
- Modify: `test/ui/checklist/checklist_screen_test.dart`, `test/ui/result/result_screen_test.dart` (o "outro participante" dos testes de uma por vez passa a estar com o consultor)
- Modify: `test/data/services/assessment_sync_service_test.dart`, `test/ui/result/result_viewmodel_test.dart`, `test/ui/summary/summary_screen_test.dart`, `test/ui/summary/summary_viewmodel_test.dart`, `test/ui/session_detail/session_detail_screen_test.dart` (só o parâmetro novo)

**Interfaces:**
- Consumes: as tabelas `Sessions` e `Participants` do cache; `ParticipantStatus.emAvaliacao.wireValue`; `SessionStatus.emAndamento.wireValue`; `ChecklistViewModel.consultantId`.
- Produces:
  - `Future<LocalAssessment?> AssessmentRepository.findInProgressOther({required String ownerUserId, required String? consultantId, required String exceptTrainingParticipantId})`.
  - `Future<LocalAssessment> AssessmentRepository.openDraft({required String trainingParticipantId, required String sessionId, required String ownerUserId, required String? consultantId})`.

- [ ] **Step 1: Escrever os testes que falham**

**Em `test/data/repositories/assessment_repository_test.dart`, substituir:**

```dart
  tearDown(() => db.close());

  /// Abre o rascunho de [participantId] para [owner] — o caminho do checklist.
  Future<LocalAssessment> open(String participantId, {String owner = 'user-1'}) {
    return repository.openDraft(
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      ownerUserId: owner,
    );
  }
```

**por:**

```dart
  tearDown(() => db.close());

  /// Abre o rascunho de [participantId] para [owner] — o caminho do checklist.
  /// [consultant] é o `Consultant.id` de [owner].
  Future<LocalAssessment> open(
    String participantId, {
    String owner = 'user-1',
    String? consultant = 'c-1',
  }) {
    return repository.openDraft(
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      ownerUserId: owner,
      consultantId: consultant,
    );
  }
```

**Em `test/data/repositories/assessment_repository_test.dart`, substituir:**

```dart
            state: 'MG',
            status: 'EM_ANDAMENTO',
            date: Value(date),
            cachedAt: DateTime(2026, 9, 12, 8),
          ),
        );
```

**por:**

```dart
            state: 'MG',
            status: 'EM_ANDAMENTO',
            date: Value(date),
            cachedAt: DateTime(2026, 9, 12, 8),
          ),
        );
  }

  /// O participante no cache, como o detalhe da sessão o grava: em avaliação
  /// com [consultant]. É o que faz a avaliação dele "ainda dar para abrir".
  Future<void> seedParticipant(
    String id, {
    String? consultant = 'c-1',
    String status = 'EM_AVALIACAO',
  }) {
    return db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: id,
            sessionId: 'sess-1',
            name: 'Participante $id',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: status,
            assignedConsultantId: Value(consultant),
            cachedAt: DateTime(2026, 9, 12, 8),
          ),
        );
```

**Em `test/data/repositories/assessment_repository_test.dart`, substituir:**

```dart
  });

  group('um por vez', () {
    Future<LocalAssessment?> other(String except, {String owner = 'user-1'}) {
      return repository.findInProgressOther(
        ownerUserId: owner,
        exceptTrainingParticipantId: except,
      );
    }
```

**por:**

```dart
  });

  group('um por vez', () {
    // A sessão em andamento e o tp-1 com o consultor: é o que faz o rascunho
    // dele contar — só bloqueia a avaliação que ainda dá para abrir (decisão
    // de 06/10/2026).
    setUp(() async {
      await seedSession();
      await seedParticipant('tp-1');
    });

    Future<LocalAssessment?> other(
      String except, {
      String owner = 'user-1',
      String? consultant = 'c-1',
    }) {
      return repository.findInProgressOther(
        ownerUserId: owner,
        consultantId: consultant,
        exceptTrainingParticipantId: except,
      );
    }
```

**Em `test/data/repositories/assessment_repository_test.dart`, substituir:**

```dart

      expect((await other('tp-2'))?.id, a.id);
      expect(await other('tp-1'), isNull, reason: 'o próprio não conta');
      expect(await other('tp-2', owner: 'user-2'), isNull,
          reason: 'o rascunho é de outro consultor');
    });
```

**por:**

```dart

      expect((await other('tp-2'))?.id, a.id);
      expect(await other('tp-1'), isNull, reason: 'o próprio não conta');
      expect(await other('tp-2', owner: 'user-2', consultant: 'c-2'), isNull,
          reason: 'o rascunho é de outro consultor');
    });
```

**Em `test/data/repositories/assessment_repository_test.dart`, substituir:**

```dart
    });

    test('o rascunho de outro consultor não bloqueia', () async {
      await open('tp-1', owner: 'user-2');

      final mine = await open('tp-2');

      expect(mine.ownerUserId, 'user-1');
    });
  });
```

**por:**

```dart
    });

    test('o rascunho de outro consultor não bloqueia', () async {
      await open('tp-1', owner: 'user-2', consultant: 'c-2');

      final mine = await open('tp-2');

      expect(mine.ownerUserId, 'user-1');
    });

    group('avaliação presa', () {
      Future<void> setSessionStatus(String status) {
        return (db.update(db.sessions)..where((t) => t.id.equals('sess-1')))
            .write(SessionsCompanion(status: Value(status)));
      }

      Future<void> setParticipant({
        required String status,
        required String? consultant,
      }) {
        return (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
            .write(
          ParticipantsCompanion(
            status: Value(status),
            assignedConsultantId: Value(consultant),
          ),
        );
      }

      test('sessão que não está mais em andamento: o rascunho deixa de bloquear',
          () async {
        final a = await open('tp-1');

        for (final status in ['CONCLUIDO', 'CANCELADO', 'PLANEJADO']) {
          await setSessionStatus(status);
          expect(await other('tp-2'), isNull, reason: status);
        }

        await setSessionStatus('EM_ANDAMENTO');
        expect((await other('tp-2'))?.id, a.id, reason: 'voltou a andamento');
      });

      test('sessão que saiu do aparelho (o consultor foi removido dela)',
          () async {
        await open('tp-1');
        await db.delete(db.participants).go();
        await db.delete(db.sessions).go();

        expect(await other('tp-2'), isNull);
      });

      test('participante liberado, com outro consultor ou sem dono', () async {
        await open('tp-1');

        await setParticipant(status: 'PENDENTE', consultant: null);
        expect(await other('tp-2'), isNull, reason: 'liberado: voltou a pendente');

        await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-outro');
        expect(await other('tp-2'), isNull, reason: 'com outro consultor');

        await setParticipant(status: 'EM_AVALIACAO', consultant: null);
        expect(await other('tp-2'), isNull, reason: 'em avaliação, sem dono');
      });

      test('nada é apagado: se o participante volta, o rascunho volta a bloquear',
          () async {
        final a = await open('tp-1');
        await setParticipant(status: 'PENDENTE', consultant: null);

        expect(await other('tp-2'), isNull);
        final rows = await db.select(db.localAssessments).get();
        expect(rows.map((r) => r.id), [a.id], reason: 'continua guardado');

        await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-1');
        expect((await other('tp-2'))?.id, a.id);
      });

      test('sem perfil de consultor, nenhum participante está com o usuário',
          () async {
        await open('tp-1');

        expect(await other('tp-2', consultant: null), isNull);
      });

      test('com um rascunho preso e outro que ainda abre, bloqueia o que abre',
          () async {
        // O tp-0 começou antes e ficou preso: não está mais com o consultor.
        await seedParticipant('tp-0', status: 'PENDENTE', consultant: null);
        await insertDraft('tp-0');
        final a = await open('tp-1');

        expect((await other('tp-2'))?.id, a.id);
      });

      test('iniciar outro participante passa quando o rascunho antigo ficou preso',
          () async {
        final a = await open('tp-1');
        await setParticipant(status: 'PENDENTE', consultant: null);

        final next = await open('tp-2');

        expect(next.trainingParticipantId, 'tp-2');
        final rows = await db.select(db.localAssessments).get();
        expect(rows.map((r) => r.id), unorderedEquals([a.id, next.id]),
            reason: 'o preso continua guardado');
      });
    });
  });
```

**Em `test/data/services/assessment_sync_service_test.dart`, substituir:**

```dart
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      ownerUserId: owner,
    );
    await assessments.confirm(draft.id, participantName: 'P $participantId', score: 90);
    return draft;
```

**por:**

```dart
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      ownerUserId: owner,
      consultantId: 'c-eu',
    );
    await assessments.confirm(draft.id, participantName: 'P $participantId', score: 90);
    return draft;
```

**Em `test/ui/checklist/checklist_screen_test.dart`, substituir:**

```dart
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
  }
```

**por:**

```dart
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
      consultantId: 'c-eu',
    );
  }
```

**Em `test/ui/checklist/checklist_screen_test.dart`, substituir:**

```dart
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    await assessmentRepository.mark(
      localAssessmentId: draft.id,
```

**por:**

```dart
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
      consultantId: 'c-eu',
    );
    await assessmentRepository.mark(
      localAssessmentId: draft.id,
```

**Em `test/ui/checklist/checklist_screen_test.dart`, substituir:**

```dart
              cpf: '111.222.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'EM_AVALIACAO',
              cachedAt: DateTime(2026, 9, 25, 8),
            ),
          );
```

**por:**

```dart
              cpf: '111.222.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'EM_AVALIACAO',
              assignedConsultantId: const Value('c-eu'),
              cachedAt: DateTime(2026, 9, 25, 8),
            ),
          );
```

**Em `test/ui/checklist/checklist_screen_test.dart`, substituir:**

```dart
        trainingParticipantId: 'tp-2',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
      );

      await pumpScreen(tester, started: false);
```

**por:**

```dart
        trainingParticipantId: 'tp-2',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
        consultantId: 'c-eu',
      );

      await pumpScreen(tester, started: false);
```

**Em `test/ui/checklist/checklist_viewmodel_test.dart`, substituir:**

```dart
              cpf: '111.222.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'EM_AVALIACAO',
              cachedAt: DateTime(2026, 9, 25, 8),
            ),
          );
```

**por:**

```dart
              cpf: '111.222.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'EM_AVALIACAO',
              assignedConsultantId: const Value('c-eu'),
              cachedAt: DateTime(2026, 9, 25, 8),
            ),
          );
```

**Em `test/ui/checklist/checklist_viewmodel_test.dart`, substituir:**

```dart
        trainingParticipantId: 'tp-2',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
      );
    }
```

**por:**

```dart
        trainingParticipantId: 'tp-2',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
        consultantId: 'c-eu',
      );
    }
```

**Em `test/ui/checklist/checklist_viewmodel_test.dart`, substituir:**

```dart
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.trainingParticipantId), ['tp-2']);
    });
  });

  group('descartar', () {
```

**por:**

```dart
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.trainingParticipantId), ['tp-2']);
    });

    test(
        'avaliação presa — a de um participante que não está mais com o '
        'consultor — não bloqueia, e continua guardada', () async {
      await seedParticipant();
      await seedCatalog();
      await startOtherParticipant();
      // O painel passou a Marina para outro consultor.
      await (db.update(db.participants)..where((t) => t.id.equals('tp-2')))
          .write(
        const ParticipantsCompanion(assignedConsultantId: Value('c-outro')),
      );
      final vm = buildViewModel();
      addTearDown(vm.dispose);

      await vm.init();
      expect(vm.isBlocked, isFalse);

      await vm.start();

      expect(vm.isStarted, isTrue);
      final rows = await db.select(db.localAssessments).get();
      expect(
        rows.map((r) => r.trainingParticipantId),
        unorderedEquals(['tp-1', 'tp-2']),
      );
    });
  });

  group('descartar', () {
```

**Em `test/ui/checklist/checklist_viewmodel_test.dart`, substituir:**

```dart
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
      );
      await assessmentRepository.mark(
        localAssessmentId: draft.id,
```

**por:**

```dart
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
        consultantId: 'c-eu',
      );
      await assessmentRepository.mark(
        localAssessmentId: draft.id,
```

**Em `test/ui/result/result_screen_test.dart`, substituir:**

```dart
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    for (final MapEntry(key: infraction, value: note) in marks.entries) {
      await assessmentRepository.mark(
```

**por:**

```dart
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
      consultantId: 'c-eu',
    );
    for (final MapEntry(key: infraction, value: note) in marks.entries) {
      await assessmentRepository.mark(
```

**Em `test/ui/result/result_screen_test.dart`, substituir:**

```dart
            cpf: '111.222.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'EM_AVALIACAO',
            cachedAt: DateTime(2026, 9, 30, 7),
          ),
        );
```

**por:**

```dart
            cpf: '111.222.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'EM_AVALIACAO',
            assignedConsultantId: const Value('c-eu'),
            cachedAt: DateTime(2026, 9, 30, 7),
          ),
        );
```

**Em `test/ui/result/result_screen_test.dart`, substituir:**

```dart
      trainingParticipantId: 'tp-2',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    serverAnswers(serverJson());
    await pumpResult(tester);
```

**por:**

```dart
      trainingParticipantId: 'tp-2',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
      consultantId: 'c-eu',
    );
    serverAnswers(serverJson());
    await pumpResult(tester);
```

**Em `test/ui/result/result_viewmodel_test.dart`, substituir:**

```dart
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    await assessmentRepository.mark(
      localAssessmentId: draft.id,
```

**por:**

```dart
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
      consultantId: 'c-eu',
    );
    await assessmentRepository.mark(
      localAssessmentId: draft.id,
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
        )).thenAnswer((_) async => null);
    when(() => assessments.findInProgressOther(
          ownerUserId: any(named: 'ownerUserId'),
          exceptTrainingParticipantId: any(named: 'exceptTrainingParticipantId'),
        )).thenAnswer((_) async => null);
  });
```

**por:**

```dart
        )).thenAnswer((_) async => null);
    when(() => assessments.findInProgressOther(
          ownerUserId: any(named: 'ownerUserId'),
          consultantId: any(named: 'consultantId'),
          exceptTrainingParticipantId: any(named: 'exceptTrainingParticipantId'),
        )).thenAnswer((_) async => null);
  });
```

**Em `test/ui/summary/summary_screen_test.dart`, substituir:**

```dart
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    for (final MapEntry(key: infraction, value: note) in marks.entries) {
      await assessmentRepository.mark(
```

**por:**

```dart
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
      consultantId: 'c-eu',
    );
    for (final MapEntry(key: infraction, value: note) in marks.entries) {
      await assessmentRepository.mark(
```

**Em `test/ui/summary/summary_viewmodel_test.dart`, substituir:**

```dart
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    for (final MapEntry(key: infraction, value: note) in marks.entries) {
      await assessmentRepository.mark(
```

**por:**

```dart
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
      consultantId: 'c-eu',
    );
    for (final MapEntry(key: infraction, value: note) in marks.entries) {
      await assessmentRepository.mark(
```

**Em `test/ui/summary/summary_viewmodel_test.dart`, substituir:**

```dart
      trainingParticipantId: 'tp-fora-do-cache',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    await assessmentRepository.mark(
      localAssessmentId: draft.id,
```

**por:**

```dart
      trainingParticipantId: 'tp-fora-do-cache',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
      consultantId: 'c-eu',
    );
    await assessmentRepository.mark(
      localAssessmentId: draft.id,
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/data/repositories/assessment_repository_test.dart test/ui/checklist/checklist_viewmodel_test.dart`
Esperado: os dois não compilam — `No named parameter with the name 'consultantId'`.

- [ ] **Step 3: Implementar**

**Em `lib/data/repositories/assessment_repository.dart`, substituir:**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../services/local/app_database.dart';

/// O consultor já tem outra avaliação em andamento (rascunho iniciado e ainda
```

**por:**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models/session_participant.dart';
import '../models/training_session.dart';
import '../services/local/app_database.dart';

/// O consultor já tem outra avaliação em andamento (rascunho iniciado e ainda
```

**Em `lib/data/repositories/assessment_repository.dart`, substituir:**

```dart
  }

  /// O rascunho que [ownerUserId] tem em andamento com outro participante que
  /// não [exceptTrainingParticipantId] — iniciado e ainda não confirmado. Nulo
  /// se não há. Avaliação confirmada (na fila ou enviada) não conta.
  Future<LocalAssessment?> findInProgressOther({
    required String ownerUserId,
    required String exceptTrainingParticipantId,
  }) {
    return (_db.select(_db.localAssessments)
          ..where((t) =>
              t.ownerUserId.equals(ownerUserId) &
              t.syncStatus.equalsValue(LocalSyncStatus.draft) &
              t.trainingParticipantId.equals(exceptTrainingParticipantId).not())
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// "Iniciar avaliação": cria o rascunho de [ownerUserId] com `startTime`
```

**por:**

```dart
  }

  /// O rascunho que [ownerUserId] tem em andamento com outro participante que
  /// não [exceptTrainingParticipantId] — iniciado, ainda não confirmado, e
  /// que ele ainda consegue abrir ([_canStillOpen]). Nulo se não há.
  /// Avaliação confirmada (na fila ou enviada) não conta.
  ///
  /// [consultantId] é o `Consultant.id` de [ownerUserId]: é com ele que a
  /// atribuição do participante é conferida. Sem perfil de consultor (nulo),
  /// nenhum participante está com o usuário, e nada bloqueia.
  Future<LocalAssessment?> findInProgressOther({
    required String ownerUserId,
    required String? consultantId,
    required String exceptTrainingParticipantId,
  }) async {
    if (consultantId == null) return null;

    final drafts = await (_db.select(_db.localAssessments)
          ..where((t) =>
              t.ownerUserId.equals(ownerUserId) &
              t.syncStatus.equalsValue(LocalSyncStatus.draft) &
              t.trainingParticipantId.equals(exceptTrainingParticipantId).not())
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .get();
    for (final draft in drafts) {
      if (await _canStillOpen(draft, consultantId)) return draft;
    }
    return null;
  }

  /// A avaliação iniciada ainda pode ser aberta pelo consultor: a sessão dela
  /// está em andamento no aparelho e o participante continua com ele — a
  /// mesma condição com que o detalhe da sessão abre o checklist.
  ///
  /// Fora disso, ela é uma "avaliação presa" (decisão de 06/10/2026): a
  /// sessão foi concluída ou cancelada, a sessão saiu do aparelho (o
  /// consultor foi removido dela) ou o participante foi liberado ou passado a
  /// outro consultor. O rascunho continua guardado, mas não segura mais a
  /// regra de uma avaliação por vez — antes, bloqueava o "Iniciar avaliação"
  /// de todos os outros participantes, sem saída na interface.
  Future<bool> _canStillOpen(LocalAssessment draft, String consultantId) async {
    final participant = await (_db.select(_db.participants)
          ..where((t) => t.id.equals(draft.trainingParticipantId)))
        .getSingleOrNull();
    if (participant == null ||
        participant.status != ParticipantStatus.emAvaliacao.wireValue ||
        participant.assignedConsultantId != consultantId) {
      return false;
    }

    final session = await (_db.select(_db.sessions)
          ..where((t) => t.id.equals(participant.sessionId)))
        .getSingleOrNull();
    return session?.status == SessionStatus.emAndamento.wireValue;
  }

  /// "Iniciar avaliação": cria o rascunho de [ownerUserId] com `startTime`
```

**Em `lib/data/repositories/assessment_repository.dart`, substituir:**

```dart
  /// recomeçar: um segundo toque não muda a hora de início.
  ///
  /// Só uma avaliação em andamento por consultor, em todas as sessões: se
  /// [ownerUserId] já tem um rascunho com outro participante, lança
  /// [EvaluationInProgressException] e não grava nada.
  ///
  /// `date` é a data de calendário da sessão (como `TrainingSession.date`,
  /// meia-noite local); sessão sem data, ou fora do cache, usa a de hoje.
```

**por:**

```dart
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

**Em `lib/data/repositories/assessment_repository.dart`, substituir:**

```dart
    required String trainingParticipantId,
    required String sessionId,
    required String ownerUserId,
  }) async {
    final current = await findCurrent(
      trainingParticipantId: trainingParticipantId,
```

**por:**

```dart
    required String trainingParticipantId,
    required String sessionId,
    required String ownerUserId,
    required String? consultantId,
  }) async {
    final current = await findCurrent(
      trainingParticipantId: trainingParticipantId,
```

**Em `lib/data/repositories/assessment_repository.dart`, substituir:**

```dart
    await _db.transaction(() async {
      final inProgress = await findInProgressOther(
        ownerUserId: ownerUserId,
        exceptTrainingParticipantId: trainingParticipantId,
      );
      if (inProgress != null) {
```

**por:**

```dart
    await _db.transaction(() async {
      final inProgress = await findInProgressOther(
        ownerUserId: ownerUserId,
        consultantId: consultantId,
        exceptTrainingParticipantId: trainingParticipantId,
      );
      if (inProgress != null) {
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
        trainingParticipantId: participantId,
        sessionId: sessionId,
        ownerUserId: ownerUserId,
      );
      if (_disposed) return;
      _attach(assessment);
```

**por:**

```dart
        trainingParticipantId: participantId,
        sessionId: sessionId,
        ownerUserId: ownerUserId,
        consultantId: consultantId,
      );
      if (_disposed) return;
      _attach(assessment);
```

**Em `lib/ui/checklist/checklist_viewmodel.dart`, substituir:**

```dart
  }

  /// Só uma avaliação por vez: confere se outro participante do consultor
  /// está em andamento, para o aviso e o "Iniciar" desabilitado.
  Future<void> _checkBlock() async {
    _blockingParticipantId = null;
    _blockingName = null;
    final inProgress = await _assessmentRepository.findInProgressOther(
      ownerUserId: ownerUserId,
      exceptTrainingParticipantId: participantId,
    );
    if (inProgress != null) await _block(inProgress.trainingParticipantId);
```

**por:**

```dart
  }

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
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/data/repositories/assessment_repository_test.dart test/ui/checklist/checklist_viewmodel_test.dart`
Esperado: `+72: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+545: All tests passed!` — os outros sete arquivos de teste tocados no Step 1 só compilam com o parâmetro novo.

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/data/repositories/assessment_repository.dart \
  apps/mobile/simtc/lib/ui/checklist/checklist_viewmodel.dart \
  apps/mobile/simtc/test/data/repositories/assessment_repository_test.dart \
  apps/mobile/simtc/test/data/services/assessment_sync_service_test.dart \
  apps/mobile/simtc/test/ui/checklist/checklist_screen_test.dart \
  apps/mobile/simtc/test/ui/checklist/checklist_viewmodel_test.dart \
  apps/mobile/simtc/test/ui/result/result_screen_test.dart \
  apps/mobile/simtc/test/ui/result/result_viewmodel_test.dart \
  apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart \
  apps/mobile/simtc/test/ui/summary/summary_screen_test.dart \
  apps/mobile/simtc/test/ui/summary/summary_viewmodel_test.dart
git commit -m "fix(mobile): avaliacao presa nao bloqueia o iniciar avaliacao"
```

---

## Task 7: Os dados da tela "Dados do treinamento"

A ViewModel da 1.12, sem tela. Os valores iniciais vêm do cache e são lidos uma vez: o que o admin digita não é desfeito por uma atualização do cache que chegue com a tela aberta. O status da sessão, esse sim, é acompanhado — se alguém a concluir ou cancelar no meio, os campos travam. Só o campo que mudou é conferido e enviado.

**Files:**
- Create: `lib/ui/session_edit/session_edit_viewmodel.dart`
- Create: `test/ui/session_edit/session_edit_viewmodel_test.dart`
- Modify: `lib/data/models/training_session.dart`
- Modify: `test/data/models/training_session_test.dart`

**Interfaces:**
- Consumes: `SessionRepository.watchSession`, `update`, `cancel` (Task 4); `ParticipantRepository.watchBySession`, `syncSession`; `AuthUser.isAdmin`.
- Produces:
  - `bool SessionStatus.acceptsChanges` — planejada ou em andamento.
  - `const Set<String> brazilianStates` — as 27 siglas.
  - `SessionEditViewModel({required String sessionId, required SessionRepository sessionRepository, required ParticipantRepository participantRepository, required AuthUser? currentUser})`, com: `init()`; `isLoading`; `session`; `date`, `city`, `state`, `notes`; `setDate(DateTime)`, `setCity(String)`, `setState(String)`, `setNotes(String)`; `canEdit`, `String? lockedReason`; `isDirty`; `String? cityError`, `String? stateError`; `canSave`; `isSaving`, `isCancelling`, `isBusy`; `String? errorMessage`; `int inEvaluationCount`; `Future<bool> save()`; `Future<bool> cancelSession()`.

- [ ] **Step 1: Escrever os testes que falham**

**Em `test/data/models/training_session_test.dart`, substituir:**

```dart
    expect(session.participantsSyncedAt, isNull,
        reason: 'a data de sync dos participantes só existe no cache');
  });
}
```

**por:**

```dart
    expect(session.participantsSyncedAt, isNull,
        reason: 'a data de sync dos participantes só existe no cache');
  });

  test('só a sessão planejada ou em andamento aceita mudanças', () {
    expect(SessionStatus.planejado.acceptsChanges, isTrue);
    expect(SessionStatus.emAndamento.acceptsChanges, isTrue);
    expect(SessionStatus.concluido.acceptsChanges, isFalse);
    expect(SessionStatus.cancelado.acceptsChanges, isFalse);
  });
}
```

**Criar `test/ui/session_edit/session_edit_viewmodel_test.dart`:**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/ui/session_edit/session_edit_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

void main() {
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late StreamController<TrainingSession?> sessionStream;
  late StreamController<List<SessionParticipant>> participantsStream;

  const admin = AuthUser(
    id: 'u-admin',
    name: 'Sebastião Souza',
    email: 'admin@simtc.com.br',
    role: AppUserRole.admin,
    consultantId: 'c-admin',
  );
  const consultora = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-eu',
  );

  TrainingSession session({
    SessionStatus status = SessionStatus.emAndamento,
    String city = 'Itabira',
    String state = 'MG',
    String? notes = 'Pátio 3 — portaria B.',
    DateTime? date,
    bool withoutDate = false,
  }) {
    return TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell',
      courseName: 'Direção Defensiva',
      city: city,
      state: state,
      date: withoutDate ? null : (date ?? DateTime(2026, 9, 12)),
      status: status,
      notes: notes,
      totalParticipants: 0,
      assessableParticipants: 0,
      assessedParticipants: 0,
    );
  }

  SessionParticipant participant(String id, ParticipantStatus status) {
    return SessionParticipant(
      id: id,
      sessionId: 'sess-1',
      name: 'Participante $id',
      maskedCpf: '042.118.***-**',
      participationType: ParticipationType.teoricaEPratica,
      status: status,
    );
  }

  setUp(() {
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    sessionStream = StreamController<TrainingSession?>.broadcast();
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
    when(() => sessions.update(
          'sess-1',
          date: any(named: 'date'),
          city: any(named: 'city'),
          state: any(named: 'state'),
          notes: any(named: 'notes'),
        )).thenAnswer((_) async => const Success<void>(null));
    when(() => sessions.cancel('sess-1'))
        .thenAnswer((_) async => const Success<void>(null));
  });

  tearDown(() {
    sessionStream.close();
    participantsStream.close();
  });

  /// A tela aberta, com a sessão já lida do cache.
  Future<SessionEditViewModel> open({
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
    participantsStream.add(const []);
    await pumpEventQueue();
    return vm;
  }

  group('abertura', () {
    test('antes da primeira leitura do cache, está carregando', () {
      final vm = SessionEditViewModel(
        sessionId: 'sess-1',
        sessionRepository: sessions,
        participantRepository: participants,
        currentUser: admin,
      )..init();
      addTearDown(vm.dispose);

      expect(vm.isLoading, isTrue);
      expect(vm.canEdit, isFalse);
    });

    test('traz os valores da sessão e não começa com mudança', () async {
      final vm = await open();

      expect(vm.isLoading, isFalse);
      expect(vm.date, DateTime(2026, 9, 12));
      expect(vm.city, 'Itabira');
      expect(vm.state, 'MG');
      expect(vm.notes, 'Pátio 3 — portaria B.');
      expect(vm.isDirty, isFalse);
      expect(vm.canSave, isFalse);
      expect(vm.canEdit, isTrue);
      expect(vm.lockedReason, isNull);
    });

    test('sessão sem data e sem observações abre com os campos vazios',
        () async {
      final vm = await open(withSession: session(withoutDate: true, notes: null));

      expect(vm.date, isNull);
      expect(vm.notes, '');
      expect(vm.isDirty, isFalse);
    });
  });

  group('quem pode editar', () {
    test('consultor comum vê os campos travados, com o motivo', () async {
      final vm = await open(user: consultora);

      expect(vm.canEdit, isFalse);
      expect(
        vm.lockedReason,
        'Só administradores podem alterar os dados do treinamento.',
      );
    });

    test('sessão concluída ou cancelada trava, com o motivo', () async {
      final concluded =
          await open(withSession: session(status: SessionStatus.concluido));
      expect(concluded.canEdit, isFalse);
      expect(
        concluded.lockedReason,
        'Sessão concluída: os dados não podem mais ser alterados.',
      );

      final cancelled =
          await open(withSession: session(status: SessionStatus.cancelado));
      expect(cancelled.canEdit, isFalse);
      expect(
        cancelled.lockedReason,
        'Sessão cancelada: os dados não podem mais ser alterados.',
      );
    });

    test('sessão planejada também pode ser editada', () async {
      final vm = await open(withSession: session(status: SessionStatus.planejado));

      expect(vm.canEdit, isTrue);
    });

    test('sessão que não está no aparelho', () async {
      final vm = await open(missing: true);

      expect(vm.isLoading, isFalse);
      expect(vm.session, isNull);
      expect(vm.canEdit, isFalse);
      expect(
        vm.lockedReason,
        'Esta sessão não está mais disponível neste aparelho.',
      );
    });

    test('a sessão ser concluída por outra pessoa trava a tela aberta', () async {
      final vm = await open();
      vm.setCity('Betim');
      expect(vm.canSave, isTrue);

      sessionStream.add(session(status: SessionStatus.concluido));
      await pumpEventQueue();

      expect(vm.canEdit, isFalse);
      expect(vm.canSave, isFalse);
      expect(vm.city, 'Betim', reason: 'o que foi digitado continua na tela');
    });
  });

  group('mudanças', () {
    test('mudar um campo marca a mudança; voltar ao valor original desmarca',
        () async {
      final vm = await open();

      vm.setCity('Betim');
      expect(vm.isDirty, isTrue);
      expect(vm.canSave, isTrue);

      vm.setCity('Itabira');
      expect(vm.isDirty, isFalse);
      expect(vm.canSave, isFalse);
    });

    test('espaço sobrando não conta como mudança', () async {
      final vm = await open();

      vm.setCity('  Itabira ');
      vm.setNotes('Pátio 3 — portaria B.  ');

      expect(vm.isDirty, isFalse);
    });

    test('escolher o mesmo dia não conta como mudança', () async {
      final vm = await open();

      vm.setDate(DateTime(2026, 9, 12, 15, 30));

      expect(vm.isDirty, isFalse);
    });

    test('um valor antigo fora do padrão não vira mudança só por abrir a tela',
        () async {
      // Cadastrado pelo painel web, que aceita texto livre na UF.
      final vm = await open(withSession: session(state: 'mg', city: 'Itabira '));

      expect(vm.isDirty, isFalse);
      expect(vm.stateError, isNull, reason: 'o que não mudou não é conferido');
    });

    test('um valor novo do cache não desfaz o que o admin digitou', () async {
      final vm = await open();
      vm.setCity('Betim');

      sessionStream.add(session(city: 'Contagem', notes: 'Outra observação.'));
      await pumpEventQueue();

      expect(vm.city, 'Betim');
      expect(vm.notes, 'Pátio 3 — portaria B.');
    });
  });

  group('conferência', () {
    test('cidade apagada impede o salvar, com o motivo', () async {
      final vm = await open();

      vm.setCity('   ');

      expect(vm.cityError, 'Informe a cidade.');
      expect(vm.canSave, isFalse);
    });

    test('UF que não existe impede o salvar, com o motivo', () async {
      final vm = await open();

      vm.setState('XX');
      expect(vm.stateError, 'UF inválida.');
      expect(vm.canSave, isFalse);

      vm.setState('M');
      expect(vm.stateError, 'UF inválida.');

      vm.setState('sp');
      expect(vm.stateError, isNull, reason: 'minúsculas valem');
      expect(vm.canSave, isTrue);
    });
  });

  group('salvar', () {
    test('manda só o que mudou e devolve verdadeiro', () async {
      final vm = await open();
      vm.setDate(DateTime(2026, 10, 3));
      vm.setNotes('Levar colete.');

      final saved = await vm.save();

      expect(saved, isTrue);
      verify(() => sessions.update(
            'sess-1',
            date: DateTime(2026, 10, 3),
            city: null,
            state: null,
            notes: 'Levar colete.',
          )).called(1);
      expect(vm.isSaving, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('cidade e UF vão aparadas, e a UF em maiúsculas', () async {
      final vm = await open();
      vm.setCity('  Betim ');
      vm.setState('sp');

      await vm.save();

      verify(() => sessions.update(
            'sess-1',
            date: null,
            city: 'Betim',
            state: 'SP',
            notes: null,
          )).called(1);
    });

    test('observação apagada vai como texto vazio, para limpar no servidor',
        () async {
      final vm = await open();
      vm.setNotes('');

      await vm.save();

      verify(() => sessions.update(
            'sess-1',
            date: null,
            city: null,
            state: null,
            notes: '',
          )).called(1);
    });

    test('a data escolhida vai só com o dia, sem hora', () async {
      final vm = await open();
      vm.setDate(DateTime(2026, 10, 3, 15, 30));

      await vm.save();

      verify(() => sessions.update(
            'sess-1',
            date: DateTime(2026, 10, 3),
            city: null,
            state: null,
            notes: null,
          )).called(1);
    });

    test('sem mudança, não chama o repositório', () async {
      final vm = await open();

      expect(await vm.save(), isFalse);

      verifyNever(() => sessions.update(
            any(),
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          ));
    });

    test('falha: mostra o motivo, e o que foi digitado continua', () async {
      when(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).thenAnswer(
        (_) async => const Failure<void>(
          ApiException(message: 'Sem conexão', isNetworkError: true),
          'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        ),
      );
      final vm = await open();
      vm.setCity('Betim');

      final saved = await vm.save();

      expect(saved, isFalse);
      expect(
        vm.errorMessage,
        'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      );
      expect(vm.city, 'Betim');
      expect(vm.isDirty, isTrue);
      verifyNever(() => participants.syncSession(any()));
    });

    test('recusado pelo servidor (403): mostra o motivo e baixa a sessão de novo',
        () async {
      when(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).thenAnswer(
        (_) async => const Failure<void>(
          ApiException(
            message: 'Não é possível editar um treinamento concluído ou cancelado',
            statusCode: 403,
          ),
          'Não é possível editar um treinamento concluído ou cancelado',
        ),
      );
      final vm = await open();
      vm.setCity('Betim');

      expect(await vm.save(), isFalse);

      expect(
        vm.errorMessage,
        'Não é possível editar um treinamento concluído ou cancelado',
      );
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('uma exceção inesperada vira a mensagem genérica, sem travar a tela',
        () async {
      when(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).thenThrow(StateError('banco fechado'));
      final vm = await open();
      vm.setCity('Betim');

      expect(await vm.save(), isFalse);

      expect(
        vm.errorMessage,
        'Não foi possível salvar as alterações. Tente de novo.',
      );
      expect(vm.isSaving, isFalse);
    });

    test('mexer num campo apaga a mensagem de erro', () async {
      when(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => Failure<void>(Exception('x'), 'Falhou.'));
      final vm = await open();
      vm.setCity('Betim');
      await vm.save();
      expect(vm.errorMessage, 'Falhou.');

      vm.setCity('Betim 2');

      expect(vm.errorMessage, isNull);
    });

    test('dois toques rápidos salvam uma vez só', () async {
      final answer = Completer<Result<void>>();
      when(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) => answer.future);
      final vm = await open();
      vm.setCity('Betim');

      final first = vm.save();
      final second = vm.save();
      expect(vm.isSaving, isTrue);
      expect(vm.canSave, isFalse);
      answer.complete(const Success<void>(null));

      expect(await first, isTrue);
      expect(await second, isFalse);
      verify(() => sessions.update(
            'sess-1',
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          )).called(1);
    });
  });

  group('cancelar sessão', () {
    test('conta quem está em avaliação agora, para o aviso', () async {
      final vm = await open();
      expect(vm.inEvaluationCount, 0);

      participantsStream.add([
        participant('tp-1', ParticipantStatus.emAvaliacao),
        participant('tp-2', ParticipantStatus.pendente),
        participant('tp-3', ParticipantStatus.emAvaliacao),
        participant('tp-4', ParticipantStatus.aprovado),
      ]);
      await pumpEventQueue();

      expect(vm.inEvaluationCount, 2);
    });

    test('cancela e devolve verdadeiro', () async {
      final vm = await open();

      expect(await vm.cancelSession(), isTrue);

      verify(() => sessions.cancel('sess-1')).called(1);
      expect(vm.isCancelling, isFalse);
    });

    test('recusado pelo servidor: mostra o motivo e baixa a sessão de novo',
        () async {
      when(() => sessions.cancel('sess-1')).thenAnswer(
        (_) async => const Failure<void>(
          ApiException(
            message: 'Não é possível cancelar um treinamento já concluído',
            statusCode: 403,
          ),
          'Não é possível cancelar um treinamento já concluído',
        ),
      );
      final vm = await open();

      expect(await vm.cancelSession(), isFalse);

      expect(
        vm.errorMessage,
        'Não é possível cancelar um treinamento já concluído',
      );
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('quem não pode editar não cancela', () async {
      final vm = await open(user: consultora);

      expect(await vm.cancelSession(), isFalse);

      verifyNever(() => sessions.cancel(any()));
    });

    test('salvar e cancelar não correm juntos', () async {
      final answer = Completer<Result<void>>();
      when(() => sessions.cancel('sess-1')).thenAnswer((_) => answer.future);
      final vm = await open();
      vm.setCity('Betim');

      final cancelling = vm.cancelSession();
      expect(vm.isCancelling, isTrue);
      expect(vm.canSave, isFalse);
      expect(await vm.save(), isFalse);
      answer.complete(const Success<void>(null));
      await cancelling;

      verifyNever(() => sessions.update(
            any(),
            date: any(named: 'date'),
            city: any(named: 'city'),
            state: any(named: 'state'),
            notes: any(named: 'notes'),
          ));
    });
  });

  test('fechar a tela com uma resposta ainda viajando não derruba o app',
      () async {
    final answer = Completer<Result<void>>();
    when(() => sessions.update(
          'sess-1',
          date: any(named: 'date'),
          city: any(named: 'city'),
          state: any(named: 'state'),
          notes: any(named: 'notes'),
        )).thenAnswer((_) => answer.future);
    final vm = SessionEditViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      currentUser: admin,
    )..init();
    sessionStream.add(session());
    await pumpEventQueue();
    vm.setCity('Betim');

    final saving = vm.save();
    vm.dispose();
    answer.complete(const Success<void>(null));

    expect(await saving, isTrue);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_edit/session_edit_viewmodel_test.dart test/data/models/training_session_test.dart`
Esperado: não compilam — `Error when reading 'lib/ui/session_edit/session_edit_viewmodel.dart'` e `The getter 'acceptsChanges' isn't defined for the type 'SessionStatus'`.

- [ ] **Step 3: Implementar**

**Em `lib/data/models/training_session.dart`, substituir:**

```dart
  const SessionStatus(this.label);

  final String label;

  /// Nome que o backend usa — também é o que vai para o cache.
  String get wireValue => switch (this) {
```

**por:**

```dart
  const SessionStatus(this.label);

  final String label;

  /// Planejada ou em andamento: o backend aceita editar os dados, cancelar e
  /// inscrever participantes. Concluída ou cancelada, recusa os três — é o
  /// que liga e desliga as ações de ADMIN do app (Fase 6A).
  bool get acceptsChanges =>
      this == SessionStatus.planejado || this == SessionStatus.emAndamento;

  /// Nome que o backend usa — também é o que vai para o cache.
  String get wireValue => switch (this) {
```

**Criar `lib/ui/session_edit/session_edit_viewmodel.dart`:**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../utils/result.dart';

/// Siglas das 27 unidades da federação. A UF digitada é conferida contra esta
/// lista — o backend aceita qualquer texto.
const Set<String> brazilianStates = {
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG',
  'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE',
  'TO',
};

/// Estado da tela 1.12 "Dados do treinamento" (Fase 6A), só para ADMIN.
///
/// Os valores iniciais vêm do cache e são lidos uma vez: o que o admin digita
/// não é desfeito por uma atualização do cache que chegue com a tela aberta.
/// O status da sessão, esse sim, é acompanhado — se alguém a concluir ou
/// cancelar no meio, os campos travam. Só o campo que mudou vai ao servidor
/// (decisão de 06/10/2026): uma edição feita no painel web em outro campo
/// não é desfeita, e um valor antigo fora do padrão não trava o salvar.
class SessionEditViewModel extends ChangeNotifier {
  SessionEditViewModel({
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

  static const String _saveFailed =
      'Não foi possível salvar as alterações. Tente de novo.';
  static const String _cancelFailed =
      'Não foi possível cancelar a sessão. Tente de novo.';

  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<List<SessionParticipant>>? _participantsSubscription;

  bool _disposed = false;
  bool _loaded = false;
  TrainingSession? _session;

  /// A sessão como estava quando a tela abriu: a base do "o que mudou".
  TrainingSession? _initial;
  DateTime? _date;
  String _city = '';
  String _state = '';
  String _notes = '';
  int _inEvaluation = 0;
  bool _saving = false;
  bool _cancelling = false;
  String? _error;

  /// Antes da primeira leitura do cache.
  bool get isLoading => !_loaded;

  /// A sessão no cache agora. Nula depois de carregada quer dizer que ela não
  /// está mais no aparelho.
  TrainingSession? get session => _session;

  DateTime? get date => _date;
  String get city => _city;
  String get state => _state;
  String get notes => _notes;

  bool get isSaving => _saving;
  bool get isCancelling => _cancelling;

  /// Salvar e cancelar não correm juntos, nem duas vezes.
  bool get isBusy => _saving || _cancelling;

  /// Falha do último salvar ou cancelar, mostrada na própria tela; some
  /// quando o admin mexe num campo.
  String? get errorMessage => _error;

  /// Quantos participantes estão em avaliação agora, pelo cache — o aviso do
  /// diálogo de "Cancelar sessão".
  int get inEvaluationCount => _inEvaluation;

  /// Por que os campos estão travados; nulo quando dá para editar. O motivo
  /// fica escrito na tela — os campos nunca somem (canvas "3b").
  String? get lockedReason {
    if (_currentUser?.isAdmin != true) {
      return 'Só administradores podem alterar os dados do treinamento.';
    }
    final session = _session;
    if (session == null) {
      return 'Esta sessão não está mais disponível neste aparelho.';
    }
    if (session.status.acceptsChanges) return null;
    return session.status == SessionStatus.cancelado
        ? 'Sessão cancelada: os dados não podem mais ser alterados.'
        : 'Sessão concluída: os dados não podem mais ser alterados.';
  }

  bool get canEdit => _loaded && lockedReason == null;

  bool get _dateChanged {
    final before = _initial?.date;
    final now = _date;
    if (before == null || now == null) return before != now;
    return before.year != now.year ||
        before.month != now.month ||
        before.day != now.day;
  }

  // Aparados dos dois lados: espaço sobrando não é mudança, nem um valor
  // antigo que já veio com espaço do painel web.
  bool get _cityChanged => _city.trim() != (_initial?.city ?? '').trim();
  bool get _stateChanged => _state.trim() != (_initial?.state ?? '').trim();
  bool get _notesChanged => _notes.trim() != (_initial?.notes ?? '').trim();

  bool get isDirty =>
      _initial != null &&
      (_dateChanged || _cityChanged || _stateChanged || _notesChanged);

  /// Só o campo que mudou é conferido — o que veio do servidor fica como
  /// está, mesmo fora do padrão.
  String? get cityError =>
      _cityChanged && _city.trim().isEmpty ? 'Informe a cidade.' : null;

  String? get stateError =>
      _stateChanged && !brazilianStates.contains(_state.trim().toUpperCase())
          ? 'UF inválida.'
          : null;

  bool get canSave =>
      canEdit && isDirty && cityError == null && stateError == null && !isBusy;

  /// Assina o cache. Chamado uma vez pela tela.
  void init() {
    _sessionSubscription ??=
        _sessionRepository.watchSession(sessionId).listen((session) {
      _session = session;
      _loaded = true;
      if (_initial == null && session != null) {
        _initial = session;
        _date = session.date;
        _city = session.city;
        _state = session.state;
        _notes = session.notes ?? '';
      }
      notifyListeners();
    });

    _participantsSubscription ??= _participantRepository
        .watchBySession(sessionId)
        .listen((participants) {
      _inEvaluation = participants
          .where((p) => p.status == ParticipantStatus.emAvaliacao)
          .length;
      notifyListeners();
    });
  }

  /// A data é de calendário: a hora que o seletor trouxer é descartada.
  void setDate(DateTime value) {
    _date = DateTime(value.year, value.month, value.day);
    _edited();
  }

  void setCity(String value) {
    _city = value;
    _edited();
  }

  void setState(String value) {
    _state = value;
    _edited();
  }

  void setNotes(String value) {
    _notes = value;
    _edited();
  }

  void _edited() {
    _error = null;
    notifyListeners();
  }

  /// "Salvar alterações". Devolve `true` quando o servidor aceitou: a tela
  /// fecha. Na falha, o motivo fica em [errorMessage] e nada do que foi
  /// digitado se perde.
  Future<bool> save() async {
    if (!canSave) return false;

    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _sessionRepository.update(
        sessionId,
        date: _dateChanged ? _date : null,
        city: _cityChanged ? _city.trim() : null,
        state: _stateChanged ? _state.trim().toUpperCase() : null,
        notes: _notesChanged ? _notes.trim() : null,
      );
      switch (result) {
        case Success():
          return true;
        case Failure(:final exception, :final message):
          _error = message ?? _saveFailed;
          _resyncIfRefused(exception);
          return false;
      }
    } catch (_) {
      _error = _saveFailed;
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// "Cancelar sessão" — a tela pede confirmação antes. Devolve `true`
  /// quando o servidor cancelou: a tela leva o admin de volta à lista.
  Future<bool> cancelSession() async {
    if (!canEdit || isBusy) return false;

    _cancelling = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _sessionRepository.cancel(sessionId);
      switch (result) {
        case Success():
          return true;
        case Failure(:final exception, :final message):
          _error = message ?? _cancelFailed;
          _resyncIfRefused(exception);
          return false;
      }
    } catch (_) {
      _error = _cancelFailed;
      return false;
    } finally {
      _cancelling = false;
      notifyListeners();
    }
  }

  /// O servidor recusou (403) ou não achou a sessão (404): alguém a concluiu,
  /// cancelou ou apagou. Baixar de novo põe o cache — e o status desta tela —
  /// em dia.
  void _resyncIfRefused(Exception exception) {
    if (exception is! ApiException) return;
    if (exception.statusCode == 403 || exception.statusCode == 404) {
      unawaited(_participantRepository.syncSession(sessionId));
    }
  }

  // Uma resposta pode chegar depois de a tela fechar; sem esta guarda, o
  // `finally` de salvar/cancelar chamaria notifyListeners num ChangeNotifier
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
    super.dispose();
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_edit/session_edit_viewmodel_test.dart test/data/models/training_session_test.dart`
Esperado: `+40: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+577: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/data/models/training_session.dart \
  apps/mobile/simtc/lib/ui/session_edit/session_edit_viewmodel.dart \
  apps/mobile/simtc/test/data/models/training_session_test.dart \
  apps/mobile/simtc/test/ui/session_edit/session_edit_viewmodel_test.dart
git commit -m "feat(mobile): dados da tela de dados do treinamento"
```

---

## Task 8: A tela 1.12 "Dados do treinamento"

A tela (quadro `3b`) e a rota. Ela ainda não tem entrada pela interface — o lápis do detalhe é da Task 11 —, então os testes a abrem pela rota, empilhada sobre uma tela de origem, com o Drift em memória e o `ApiClient` simulado.

**Files:**
- Create: `lib/ui/session_edit/session_edit_screen.dart`
- Create: `test/ui/session_edit/session_edit_screen_test.dart`
- Modify: `lib/ui/core/theme/app_icons.dart`
- Modify: `lib/router.dart`

**Interfaces:**
- Consumes: `SessionEditViewModel` (Task 7); `AppTextField` (só leitura, formatadores, várias linhas), `AppDangerOutlineButton`, `AppTextButton`, `SessionContextHeader` (Task 3); `AppLocalization` (Task 2, nos testes); `dayMonthYearLabel`; `AppRoutes.home`.
- Produces:
  - `SessionEditScreen({required String sessionId})`.
  - `AppRoutes.sessionEdit(String sessionId)` → `/sessions/$sessionId/edit`. A tela fecha devolvendo `true` quando salvou; nulo nos outros casos. Depois do "Cancelar sessão", vai para `AppRoutes.home`.
  - `AppIcons.save`, `AppIcons.cancelSession`.

- [ ] **Step 1: Escrever os testes que falham**

**Criar `test/ui/session_edit/session_edit_screen_test.dart`:**

```dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/app_localization.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_text_field.dart';
import 'package:simtc/ui/session_edit/session_edit_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockApiClient api;
  late _MockAuthRepository auth;
  late AppDatabase db;
  late SessionRepository sessionRepository;
  late ParticipantRepository participantRepository;
  late ConnectivityService connectivity;
  late GoRouter router;

  const path = '/training-sessions/sess-1';
  const cancelPath = '/training-sessions/sess-1/cancel';

  const admin = AuthUser(
    id: 'u-admin',
    name: 'Sebastião Souza',
    email: 'admin@simtc.com.br',
    role: AppUserRole.admin,
    consultantId: 'c-admin',
  );
  const consultora = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-eu',
  );

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
    connectivity = ConnectivityService();
  });

  tearDown(() async {
    await db.close();
    connectivity.dispose();
  });

  Future<void> seedSession({
    String status = 'EM_ANDAMENTO',
    bool withDate = true,
    DateTime? date,
    String? notes = 'Pátio 3 — portaria B.',
  }) {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva — Veículo Pesado',
            city: 'Itabira',
            state: 'MG',
            date: Value(withDate ? (date ?? DateTime(2026, 9, 12)) : null),
            status: status,
            notes: Value(notes),
            cachedAt: DateTime(2026, 9, 12, 7),
          ),
        );
  }

  Future<void> seedParticipant(String id, String status) {
    return db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: id,
            sessionId: 'sess-1',
            name: 'Participante $id',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: status,
            cachedAt: DateTime(2026, 9, 12, 7),
          ),
        );
  }

  Response<Map<String, dynamic>> ok(String requestPath) {
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: requestPath),
      statusCode: 200,
      data: {'id': 'sess-1'},
    );
  }

  void patchAnswers() {
    when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
        .thenAnswer((_) async => ok(path));
  }

  Object? sentBody() {
    return verify(
      () => api.patch<Map<String, dynamic>>(path, data: captureAny(named: 'data')),
    ).captured.single;
  }

  Future<void> goOffline() async {
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => const Stream.empty());
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  /// A tela empilhada sobre uma origem, pela rota real; a lista de sessões é
  /// para onde o "Cancelar sessão" leva.
  Future<void> pumpEdit(
    WidgetTester tester, {
    Size screen = const Size(412, 1400),
    double textScale = 1,
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
          path: AppRoutes.home,
          builder: (context, state) =>
              const Scaffold(body: Text('lista de sessões')),
        ),
        GoRoute(
          path: '/sessions/:sessionId/edit',
          builder: (context, state) => SessionEditScreen(
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
    router.push(AppRoutes.sessionEdit('sess-1'));
    await tester.pumpAndSettle();
  }

  Finder field(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );

  AppCtaButton saveButton(WidgetTester tester) =>
      tester.widget<AppCtaButton>(find.byType(AppCtaButton));

  AppDangerOutlineButton cancelButton(WidgetTester tester) =>
      tester.widget<AppDangerOutlineButton>(find.byType(AppDangerOutlineButton));

  testWidgets('mostra o contexto da sessão e os campos com os valores dela',
      (tester) async {
    await seedSession();
    await pumpEdit(tester);

    expect(find.text('Dados do treinamento'), findsOneWidget);
    expect(find.text('Bracell'), findsOneWidget);
    expect(find.text('Direção Defensiva — Veículo Pesado'), findsOneWidget);
    expect(find.text('12 set 2026'), findsOneWidget);
    expect(find.text('Itabira'), findsOneWidget);
    expect(find.text('MG'), findsOneWidget);
    expect(find.text('Pátio 3 — portaria B.'), findsOneWidget);
    expect(find.text('Observações para os consultores'), findsOneWidget);

    expect(saveButton(tester).onPressed, isNull, reason: 'nada mudou ainda');
    expect(cancelButton(tester).onPressed, isNotNull);
    expect(find.text('Descartar'), findsOneWidget);
    // Fora do contrato, e por isso fora da tela (decisões de 06/10/2026).
    expect(find.text('Início'), findsNothing);
    expect(find.text('Local'), findsNothing);
  });

  testWidgets('sessão sem data mostra "Sem data" no campo', (tester) async {
    await seedSession(withDate: false);
    await pumpEdit(tester);

    expect(find.text('Sem data'), findsOneWidget);
  });

  testWidgets(
      'editar a cidade e salvar: manda só o que mudou, volta à tela de baixo '
      'e avisa', (tester) async {
    await seedSession();
    patchAnswers();
    await pumpEdit(tester);

    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(sentBody(), {'city': 'Betim'});
    expect(find.text('origem'), findsOneWidget);
    expect(find.byType(SessionEditScreen), findsNothing);
    expect(find.text('Dados do treinamento atualizados.'), findsOneWidget);
    final row = await db.select(db.sessions).getSingle();
    expect(row.city, 'Betim');
  });

  testWidgets('a data é escolhida no calendário, em português', (tester) async {
    await seedSession();
    patchAnswers();
    await pumpEdit(tester);

    await tester.tapAt(tester.getCenter(find.text('12 set 2026')));
    await tester.pumpAndSettle();

    expect(find.text('Data do treinamento'), findsOneWidget);
    expect(find.text('setembro de 2026'), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('15 set 2026'), findsOneWidget);

    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(sentBody(), {'date': '2026-09-15'});
  });

  testWidgets(
      'sessão com data fora do intervalo do calendário (cadastro antigo): o '
      'calendário abre mesmo assim', (tester) async {
    await seedSession(date: DateTime(2019, 5, 10));
    await pumpEdit(tester);

    await tester.tapAt(tester.getCenter(find.text('10 mai 2019')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Data do treinamento'), findsOneWidget);
  });

  testWidgets('fechar o calendário sem escolher não muda nada', (tester) async {
    await seedSession();
    await pumpEdit(tester);

    await tester.tapAt(tester.getCenter(find.text('12 set 2026')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('12 set 2026'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets(
      'UF: fica em maiúsculas, com duas letras, e a sigla que não existe '
      'impede o salvar', (tester) async {
    await seedSession();
    patchAnswers();
    await pumpEdit(tester);

    await tester.enterText(field('campo-uf'), 'xx9');
    await tester.pump();

    expect(find.text('XX'), findsOneWidget);
    expect(find.text('UF inválida.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(field('campo-uf'), 'sp');
    await tester.pump();

    expect(find.text('UF inválida.'), findsNothing);
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(sentBody(), {'state': 'SP'});
  });

  testWidgets('cidade apagada mostra o motivo e impede o salvar', (tester) async {
    await seedSession();
    await pumpEdit(tester);

    await tester.enterText(field('campo-cidade'), '');
    await tester.pump();

    expect(find.text('Informe a cidade.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('apagar as observações limpa o campo no servidor', (tester) async {
    await seedSession();
    patchAnswers();
    await pumpEdit(tester);

    await tester.enterText(field('campo-observacoes'), '');
    await tester.pump();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(sentBody(), {'notes': ''});
  });

  testWidgets('falha ao salvar: o motivo aparece na tela e o que foi digitado fica',
      (tester) async {
    await seedSession();
    when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
        .thenThrow(const ApiException(
      message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      isNetworkError: true,
    ));
    await pumpEdit(tester);

    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionEditScreen), findsOneWidget);
    expect(
      find.text('Sem conexão com o servidor. Verifique a internet e tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Betim'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull, reason: 'dá para tentar de novo');
  });

  group('sair da tela', () {
    testWidgets('sem mudança, o voltar sai direto', (tester) async {
      await seedSession();
      await pumpEdit(tester);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
        'com mudança, o voltar pergunta: "Continuar editando" fica, '
        '"Descartar" sai sem salvar', (tester) async {
      await seedSession();
      await pumpEdit(tester);
      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('Descartar as alterações?'), findsOneWidget);

      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionEditScreen), findsOneWidget);
      expect(find.text('Betim'), findsOneWidget);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      verifyNever(
        () => api.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
      );
    });

    testWidgets('o voltar do Android, com mudança, também pergunta',
        (tester) async {
      await seedSession();
      await pumpEdit(tester);
      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Descartar as alterações?'), findsOneWidget);
      expect(find.byType(SessionEditScreen), findsOneWidget);
    });

    testWidgets('"Descartar" do rodapé sai sem perguntar e sem salvar',
        (tester) async {
      await seedSession();
      await pumpEdit(tester);
      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();

      await tester.tap(find.widgetWithText(AppTextButton, 'Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(
        () => api.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
      );
    });
  });

  testWidgets(
      'sem conexão: salvar e cancelar ficam desabilitados, com o aviso, e os '
      'campos continuam editáveis', (tester) async {
    await seedSession();
    await goOffline();
    await pumpEdit(tester);

    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();

    expect(find.text('Sem conexão — salvar precisa de internet.'), findsOneWidget);
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(cancelButton(tester).onPressed, isNull);
    expect(find.text('Betim'), findsOneWidget);
  });

  testWidgets(
      'a conexão volta com a tela aberta: o salvar reabilita, e o que foi '
      'digitado continua', (tester) async {
    await seedSession();
    final changes = StreamController<List<ConnectivityResult>>();
    addTearDown(changes.close);
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => changes.stream);
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
    await pumpEdit(tester);
    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);

    changes.add([ConnectivityResult.mobile]);
    await tester.pumpAndSettle();

    expect(find.text('Sem conexão — salvar precisa de internet.'), findsNothing);
    expect(find.text('Betim'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    expect(cancelButton(tester).onPressed, isNotNull);
  });

  testWidgets(
      'celular estreito com a fonte do sistema ampliada: a tela não estoura, '
      'nem com os dois erros à vista', (tester) async {
    await seedSession();
    await pumpEdit(tester, screen: const Size(360, 1600), textScale: 1.6);

    await tester.enterText(field('campo-cidade'), '');
    await tester.enterText(field('campo-uf'), 'XX');
    await tester.pump();

    expect(find.text('Informe a cidade.'), findsOneWidget);
    expect(find.text('UF inválida.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('cancelar sessão', () {
    testWidgets(
        'o diálogo diz a consequência e quem está em avaliação; confirmar '
        'cancela, avisa e leva à lista de sessões', (tester) async {
      await seedSession();
      await seedParticipant('tp-1', 'EM_AVALIACAO');
      await seedParticipant('tp-2', 'EM_AVALIACAO');
      await seedParticipant('tp-3', 'PENDENTE');
      when(() => api.patch<Map<String, dynamic>>(cancelPath))
          .thenAnswer((_) async => ok(cancelPath));
      await pumpEdit(tester);

      await tester.tap(find.text('Cancelar sessão'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar a sessão?'), findsOneWidget);
      expect(
        find.text(
          'Ninguém mais poderá ser avaliado nesta sessão, e ela sai da lista '
          'de sessões do app. Não dá para desfazer. Há 2 participantes em '
          'avaliação agora.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar sessão'));
      await tester.pumpAndSettle();

      verify(() => api.patch<Map<String, dynamic>>(cancelPath)).called(1);
      expect(find.text('lista de sessões'), findsOneWidget);
      expect(find.text('Sessão cancelada.'), findsOneWidget);
      final row = await db.select(db.sessions).getSingle();
      expect(row.status, 'CANCELADO');
    });

    testWidgets('com um só em avaliação, o aviso fica no singular; sem ninguém, some',
        (tester) async {
      await seedSession();
      await seedParticipant('tp-1', 'EM_AVALIACAO');
      await pumpEdit(tester);

      await tester.tap(find.text('Cancelar sessão'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Há 1 participante em avaliação agora.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      await (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
          .write(const ParticipantsCompanion(status: Value('APROVADO')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar sessão'));
      await tester.pumpAndSettle();

      expect(find.textContaining('em avaliação agora'), findsNothing);
      expect(find.textContaining('Não dá para desfazer.'), findsOneWidget);
    });

    testWidgets('"Voltar" fecha o diálogo sem cancelar', (tester) async {
      await seedSession();
      await pumpEdit(tester);

      await tester.tap(find.text('Cancelar sessão'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionEditScreen), findsOneWidget);
      verifyNever(() => api.patch<Map<String, dynamic>>(cancelPath));
    });

    testWidgets('recusado pelo servidor: o motivo aparece, e a tela fica',
        (tester) async {
      await seedSession();
      when(() => api.patch<Map<String, dynamic>>(cancelPath)).thenThrow(
        const ApiException(
          message: 'Não é possível cancelar um treinamento já concluído',
          statusCode: 403,
        ),
      );
      when(() => api.get<Map<String, dynamic>>(path)).thenThrow(
        const ApiException(message: 'Sem conexão', isNetworkError: true),
      );
      await pumpEdit(tester);

      await tester.tap(find.text('Cancelar sessão'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar sessão'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionEditScreen), findsOneWidget);
      expect(
        find.text('Não é possível cancelar um treinamento já concluído'),
        findsOneWidget,
      );
      expect(find.text('lista de sessões'), findsNothing);
    });
  });

  group('campos travados, com o motivo escrito', () {
    testWidgets('consultor comum', (tester) async {
      when(() => auth.currentUser).thenReturn(consultora);
      await seedSession();
      await pumpEdit(tester);

      expect(
        find.text('Só administradores podem alterar os dados do treinamento.'),
        findsOneWidget,
      );
      expect(find.text('Itabira'), findsOneWidget, reason: 'os campos não somem');
      for (final input in tester.widgetList<AppTextField>(find.byType(AppTextField))) {
        expect(input.enabled, isFalse, reason: input.label);
      }
      expect(saveButton(tester).onPressed, isNull);
      expect(cancelButton(tester).onPressed, isNull);
    });

    testWidgets('sessão concluída', (tester) async {
      await seedSession(status: 'CONCLUIDO');
      await pumpEdit(tester);

      expect(
        find.text('Sessão concluída: os dados não podem mais ser alterados.'),
        findsOneWidget,
      );
      expect(saveButton(tester).onPressed, isNull);
      expect(cancelButton(tester).onPressed, isNull);
    });
  });

  testWidgets('sessão que não está no aparelho: só o aviso', (tester) async {
    await pumpEdit(tester);

    expect(
      find.text('Esta sessão não está mais disponível neste aparelho.'),
      findsOneWidget,
    );
    expect(find.byType(AppCtaButton), findsNothing);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_edit/session_edit_screen_test.dart`
Esperado: não compila — `Error when reading 'lib/ui/session_edit/session_edit_screen.dart'` e `Member not found: 'AppRoutes.sessionEdit'`.

- [ ] **Step 3: Implementar**

**Em `lib/router.dart`, substituir:**

```dart
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/result/result_screen.dart';
import 'ui/session_detail/session_detail_screen.dart';
import 'ui/sessions/sessions_screen.dart';
import 'ui/splash/splash_screen.dart';
import 'ui/summary/summary_screen.dart';
```

**por:**

```dart
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/result/result_screen.dart';
import 'ui/session_detail/session_detail_screen.dart';
import 'ui/session_edit/session_edit_screen.dart';
import 'ui/sessions/sessions_screen.dart';
import 'ui/splash/splash_screen.dart';
import 'ui/summary/summary_screen.dart';
```

**Em `lib/router.dart`, substituir:**

```dart

  /// Detalhe da sessão (tela 1.4).
  static String sessionDetail(String sessionId) => '/sessions/$sessionId';

  /// Checklist do participante (Fase 4). [fromResult]: aberto pelo
  /// "Reavaliar" do Resultado, que continua embaixo — o voltar leva a ele.
```

**por:**

```dart

  /// Detalhe da sessão (tela 1.4).
  static String sessionDetail(String sessionId) => '/sessions/$sessionId';

  /// "Dados do treinamento" (tela 1.12, Fase 6A), só para ADMIN.
  static String sessionEdit(String sessionId) => '/sessions/$sessionId/edit';

  /// Checklist do participante (Fase 4). [fromResult]: aberto pelo
  /// "Reavaliar" do Resultado, que continua embaixo — o voltar leva a ele.
```

**Em `lib/router.dart`, substituir:**

```dart
        ),
        routes: [
          GoRoute(
            path: 'participants/:participantId/checklist',
            builder: (context, state) => ChecklistScreen(
              sessionId: state.pathParameters['sessionId']!,
```

**por:**

```dart
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => SessionEditScreen(
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
  /// "Descartar" do item que o servidor recusou, na aba Sincronizar (Fase
  /// 5B — não está no canvas).
  static const IconData discard = Icons.delete_outline;
}
```

**por:**

```dart
  /// "Descartar" do item que o servidor recusou, na aba Sincronizar (Fase
  /// 5B — não está no canvas).
  static const IconData discard = Icons.delete_outline;

  /// "Dados do treinamento" (Fase 6A, canvas "3b"): salvar e cancelar sessão.
  static const IconData save = Icons.save_outlined;
  static const IconData cancelSession = Icons.event_busy_outlined;
}
```

**Criar `lib/ui/session_edit/session_edit_screen.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../router.dart';
import '../core/date_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/session_context_header.dart';
import '../core/widgets/skeleton.dart';
import '../core/widgets/sync_status_indicator.dart';
import 'session_edit_viewmodel.dart';

/// Tela 1.12 — "Dados do treinamento" (quadro "3b" do canvas), só para ADMIN.
///
/// Diferenças do canvas, aprovadas em 06/10/2026: sem "Início" (a sessão não
/// tem horário), "Local" virou "Cidade" + "UF" (é como o backend guarda) e
/// sem o contador das observações (o backend não limita).
class SessionEditScreen extends StatefulWidget {
  const SessionEditScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionEditScreen> createState() => _SessionEditScreenState();
}

class _SessionEditScreenState extends State<SessionEditScreen> {
  late final SessionEditViewModel _viewModel = SessionEditViewModel(
    sessionId: widget.sessionId,
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    currentUser: context.read<AuthRepository>().currentUser,
  )..init();

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  /// Os campos já receberam os valores da sessão — acontece uma vez só, para
  /// uma atualização do cache não apagar o que o admin digitou.
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_fillWhenLoaded);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_fillWhenLoaded);
    _viewModel.dispose();
    _dateController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _fillWhenLoaded() {
    if (_filled || _viewModel.session == null) return;
    _filled = true;

    final date = _viewModel.date;
    _dateController.text = date == null ? '' : dayMonthYearLabel(date);
    _cityController.text = _viewModel.city;
    _stateController.text = _viewModel.state;
    _notesController.text = _viewModel.notes;
  }

  bool get _fieldsEnabled => _viewModel.canEdit && !_viewModel.isBusy;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    // Com mudança por salvar, o voltar (da barra ou do Android) pergunta
    // antes; o `pop` direto — do "Descartar" e do salvar — não passa por aqui.
    return PopScope<Object?>(
      canPop: !_viewModel.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
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
                message: 'Sem conexão — salvar precisa de internet.',
              ),
              Expanded(child: _buildBody(isOffline)),
              if (_viewModel.session != null) _buildFooter(isOffline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isOffline) {
    if (_viewModel.isLoading) return _buildSkeleton();

    final session = _viewModel.session;
    final lockedReason = _viewModel.lockedReason;
    if (session == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: InlineNotice(icon: AppIcons.sessions, message: lockedReason ?? ''),
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        SessionContextHeader(
          companyName: session.companyName,
          logoUrl: session.companyLogoUrl,
          subtitle: session.courseName,
        ),
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
              if (_viewModel.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.lg),
                InlineNotice(
                  icon: AppIcons.needsReview,
                  message: _viewModel.errorMessage!,
                  tone: NoticeTone.danger,
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              _buildCancelButton(isOffline),
            ],
          ),
        ),
      ],
    );
  }

  /// Não se digita: o toque abre o calendário. Não há "limpar data" — o
  /// backend ignora data vazia.
  Widget _buildDateField() {
    return AppTextField(
      key: const Key('campo-data'),
      label: 'Data',
      controller: _dateController,
      icon: AppIcons.event,
      hintText: 'Sem data',
      readOnly: true,
      enabled: _fieldsEnabled,
      onTap: _pickDate,
    );
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = DateTime(2020);
    final last = DateTime(today.year + 5, 12, 31);
    final current = _viewModel.date ?? today;

    final picked = await showDatePicker(
      context: context,
      // O calendário exige a data inicial dentro do intervalo.
      initialDate: current.isBefore(first)
          ? first
          : current.isAfter(last)
              ? last
              : current,
      firstDate: first,
      lastDate: last,
      helpText: 'Data do treinamento',
    );
    if (picked == null || !mounted) return;

    _viewModel.setDate(picked);
    _dateController.text = dayMonthYearLabel(picked);
  }

  /// Cidade e UF na mesma linha, separadas como o backend guarda (o canvas
  /// desenha um campo "Local" só).
  Widget _buildPlaceRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            key: const Key('campo-cidade'),
            label: 'Cidade',
            controller: _cityController,
            icon: AppIcons.place,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            enabled: _fieldsEnabled,
            errorText: _viewModel.cityError,
            onChanged: _viewModel.setCity,
          ),
        ),
        const SizedBox(width: AppSpacing.md - 2),
        SizedBox(
          width: AppSpacing.huge * 2,
          child: AppTextField(
            key: const Key('campo-uf'),
            label: 'UF',
            controller: _stateController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
              LengthLimitingTextInputFormatter(2),
              const _UpperCaseFormatter(),
            ],
            enabled: _fieldsEnabled,
            errorText: _viewModel.stateError,
            onChanged: _viewModel.setState,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return AppTextField(
      key: const Key('campo-observacoes'),
      label: 'Observações para os consultores',
      controller: _notesController,
      minLines: 4,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      enabled: _fieldsEnabled,
      onChanged: _viewModel.setNotes,
    );
  }

  /// Destrutivo e sem volta: mora no fim da tela, em contorno vermelho, longe
  /// do "Salvar alterações" (canvas "3b"). A consequência vem no diálogo,
  /// antes do toque que cancela.
  Widget _buildCancelButton(bool isOffline) {
    return AppDangerOutlineButton(
      label: 'Cancelar sessão',
      icon: AppIcons.cancelSession,
      isLoading: _viewModel.isCancelling,
      onPressed: _fieldsEnabled && !isOffline ? _confirmCancel : null,
    );
  }

  Widget _buildFooter(bool isOffline) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCtaButton(
            label: 'Salvar alterações',
            icon: AppIcons.save,
            size: AppCtaSize.large,
            isLoading: _viewModel.isSaving,
            onPressed: _viewModel.canSave && !isOffline ? _save : null,
          ),
          if (isOffline && _viewModel.canEdit) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Text(
              'Disponível quando houver conexão',
              style: AppTypography.meta,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          AppTextButton(
            label: 'Descartar',
            tone: AppTextButtonTone.neutral,
            onPressed: _viewModel.isBusy ? null : _discard,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await _viewModel.save();
    if (!saved || !mounted) return;

    // O SnackBar é do `ScaffoldMessenger` do app: continua na tela de baixo.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados do treinamento atualizados.')),
    );
    Navigator.of(context).pop(true);
  }

  /// "Descartar" é um pedido explícito: sai sem perguntar.
  void _discard() => Navigator.of(context).pop();

  Future<void> _confirmLeave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar as alterações?'),
        content: const Text(
          'O que você mudou nos dados do treinamento ainda não foi salvo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmCancel() async {
    final count = _viewModel.inEvaluationCount;
    final inEvaluation = switch (count) {
      0 => '',
      1 => ' Há 1 participante em avaliação agora.',
      _ => ' Há $count participantes em avaliação agora.',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar a sessão?'),
        content: Text(
          'Ninguém mais poderá ser avaliado nesta sessão, e ela sai da lista '
          'de sessões do app. Não dá para desfazer.$inEvaluation',
        ),
        actions: [
          // "Voltar", e não "Cancelar": aqui "cancelar" é a própria ação.
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancelar sessão'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final cancelled = await _viewModel.cancelSession();
    if (!cancelled || !mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sessão cancelada.')));
    // A sessão cancelada some da Home (decisão de 20/09/2026): o detalhe que
    // ficou embaixo não tem mais para onde voltar.
    context.go(AppRoutes.home);
  }

  Widget _buildSkeleton() {
    return ListView(
      key: const Key('session-edit-skeleton'),
      children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
    );
  }
}

/// Mostra em maiúsculas o que for digitado na UF, mesmo num teclado que não
/// respeita o `TextCapitalization.characters`.
class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
```

O `PopScope` só intercepta o voltar da barra e o do Android (`maybePop`); o `Navigator.pop` direto — do "Descartar" e do salvar — não passa por ele. No diálogo do "Cancelar sessão", o botão que desiste é "Voltar", e não "Cancelar": ali "cancelar" é a própria ação.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_edit/session_edit_screen_test.dart`
Esperado: `+24: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+601: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/router.dart \
  apps/mobile/simtc/lib/ui/core/theme/app_icons.dart \
  apps/mobile/simtc/lib/ui/session_edit/session_edit_screen.dart \
  apps/mobile/simtc/test/ui/session_edit/session_edit_screen_test.dart
git commit -m "feat(mobile): tela 1.12 de dados do treinamento"
```

---

## Task 9: Os dados da tela "Adicionar participante"

A ViewModel da 1.11, sem tela. O CPF é o centro: completo e válido, dispara a consulta, que decide o que aparece sob o campo e se nome e e-mail são preenchidos. O CPF inteiro só existe aqui, em memória, enquanto a tela está aberta.

**Files:**
- Create: `lib/ui/add_participant/add_participant_viewmodel.dart`
- Create: `test/ui/add_participant/add_participant_viewmodel_test.dart`

**Interfaces:**
- Consumes: `cpfDigits`, `isValidCpf` (Task 5); `ParticipantRepository.lookupCpf`, `add`, `syncSession` (Task 5); `SessionRepository.watchSession`; `SessionStatus.acceptsChanges` (Task 7); `CpfLookup`.
- Produces:
  - `enum CpfCheck { incomplete, invalid, checking, available, enrolled, unverified }`.
  - `AddParticipantViewModel({required String sessionId, required SessionRepository sessionRepository, required ParticipantRepository participantRepository, required AuthUser? currentUser})`, com: `init()`; `isLoading`; `session`; `canAdd`, `String? lockedReason`; `cpf` (só dígitos), `name`, `email`, `participationType`; `setCpf(String)`, `setName(String)`, `setEmail(String)`, `setParticipationType(ParticipationType)`; `CpfCheck cpfCheck`; `String? cpfError`, `String? cpfHelper`; `bool filledFromRegistry`, `String? registryNotice`; `bool isEmailValid`; `bool hasInput`; `bool canSubmit`; `bool isSubmitting`; `String? errorMessage`; `int addedCount`; `Future<SessionParticipant?> submit({bool addAnother = false})`.

- [ ] **Step 1: Escrever os testes que falham**

**Criar `test/ui/add_participant/add_participant_viewmodel_test.dart`:**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/cpf_lookup.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/ui/add_participant/add_participant_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

void main() {
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late StreamController<TrainingSession?> sessionStream;

  // Dois CPFs com os dígitos verificadores certos.
  const cpf = '52998224725';
  const otherCpf = '11144477735';

  const admin = AuthUser(
    id: 'u-admin',
    name: 'Sebastião Souza',
    email: 'admin@simtc.com.br',
    role: AppUserRole.admin,
    consultantId: 'c-admin',
  );
  const consultora = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-eu',
  );

  const free = CpfLookup(registered: false, enrolled: false);
  const registered = CpfLookup(
    registered: true,
    enrolled: false,
    name: 'Fernanda Lopes Meireles',
    email: 'fernanda@empresa.com.br',
  );

  TrainingSession session({SessionStatus status = SessionStatus.emAndamento}) {
    return TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell',
      courseName: 'Direção Defensiva',
      city: 'Itabira',
      state: 'MG',
      status: status,
      totalParticipants: 0,
      assessableParticipants: 0,
      assessedParticipants: 0,
    );
  }

  SessionParticipant added({String name = 'Fernanda Lopes Meireles'}) {
    return SessionParticipant(
      id: 'tp-9',
      sessionId: 'sess-1',
      name: name,
      maskedCpf: '529.982.***-**',
      participationType: ParticipationType.teoricaEPratica,
      status: ParticipantStatus.pendente,
    );
  }

  void lookupAnswers(CpfLookup lookup, {String forCpf = cpf}) {
    when(() => participants.lookupCpf('sess-1', forCpf))
        .thenAnswer((_) async => Success(lookup));
  }

  void addAnswers(Result<SessionParticipant> result) {
    when(() => participants.add(
          'sess-1',
          cpf: any(named: 'cpf'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          participationType: any(named: 'participationType'),
        )).thenAnswer((_) async => result);
  }

  setUpAll(() => registerFallbackValue(ParticipationType.teoricaEPratica));

  setUp(() {
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    sessionStream = StreamController<TrainingSession?>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
    lookupAnswers(free);
    lookupAnswers(free, forCpf: otherCpf);
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
    await pumpEventQueue();
    return vm;
  }

  /// CPF livre e nome preenchidos: pronto para adicionar.
  Future<AddParticipantViewModel> filled() async {
    final vm = await open();
    vm.setCpf(cpf);
    await pumpEventQueue();
    vm.setName('Fernanda Lopes Meireles');
    return vm;
  }

  group('abertura', () {
    test('começa vazia, com "Teórica + prática" marcado e sem poder adicionar',
        () async {
      final vm = await open();

      expect(vm.isLoading, isFalse);
      expect(vm.canAdd, isTrue);
      expect(vm.lockedReason, isNull);
      expect(vm.cpf, '');
      expect(vm.name, '');
      expect(vm.email, '');
      expect(vm.participationType, ParticipationType.teoricaEPratica);
      expect(vm.cpfCheck, CpfCheck.incomplete);
      expect(vm.canSubmit, isFalse);
      expect(vm.hasInput, isFalse);
      expect(vm.addedCount, 0);
    });

    test('sessão planejada também aceita participante', () async {
      final vm = await open(withSession: session(status: SessionStatus.planejado));

      expect(vm.canAdd, isTrue);
    });

    test('consultor comum, sessão concluída, cancelada ou fora do aparelho: '
        'travado, com o motivo', () async {
      final consultant = await open(user: consultora);
      expect(consultant.canAdd, isFalse);
      expect(
        consultant.lockedReason,
        'Só administradores podem adicionar participantes.',
      );

      final concluded =
          await open(withSession: session(status: SessionStatus.concluido));
      expect(
        concluded.lockedReason,
        'Sessão concluída: não dá mais para adicionar participantes.',
      );

      final cancelled =
          await open(withSession: session(status: SessionStatus.cancelado));
      expect(
        cancelled.lockedReason,
        'Sessão cancelada: não dá mais para adicionar participantes.',
      );

      final missing = await open(missing: true);
      expect(
        missing.lockedReason,
        'Esta sessão não está mais disponível neste aparelho.',
      );
    });
  });

  group('CPF', () {
    test('incompleto não consulta nem acusa erro', () async {
      final vm = await open();

      vm.setCpf('529.982.247');
      await pumpEventQueue();

      expect(vm.cpf, '529982247');
      expect(vm.cpfCheck, CpfCheck.incomplete);
      expect(vm.cpfError, isNull);
      expect(vm.cpfHelper, isNull);
      verifyNever(() => participants.lookupCpf(any(), any()));
    });

    test('dígitos verificadores errados: "CPF inválido.", sem consultar',
        () async {
      final vm = await open();

      vm.setCpf('529.982.247-26');
      await pumpEventQueue();

      expect(vm.cpfCheck, CpfCheck.invalid);
      expect(vm.cpfError, 'CPF inválido.');
      verifyNever(() => participants.lookupCpf(any(), any()));
    });

    test('válido: consulta com os dígitos e, livre, diz que pode seguir',
        () async {
      final vm = await open();

      vm.setCpf('529.982.247-25');
      expect(vm.cpfCheck, CpfCheck.checking);
      expect(vm.cpfHelper, 'Consultando o CPF…');
      await pumpEventQueue();

      verify(() => participants.lookupCpf('sess-1', cpf)).called(1);
      expect(vm.cpfCheck, CpfCheck.available);
      expect(vm.cpfHelper, 'CPF válido e sem cadastro nesta sessão.');
      expect(vm.cpfError, isNull);
      expect(vm.filledFromRegistry, isFalse);
      expect(vm.registryNotice, isNull);
    });

    test('o mesmo CPF de novo (só mudou a máscara) não consulta outra vez',
        () async {
      final vm = await open();
      vm.setCpf('529.982.247-25');
      await pumpEventQueue();

      vm.setCpf('52998224725');
      await pumpEventQueue();

      verify(() => participants.lookupCpf('sess-1', cpf)).called(1);
    });

    test('o que passa do 11º dígito é descartado', () async {
      final vm = await open();

      vm.setCpf('529982247259');

      expect(vm.cpf, cpf);
    });

    test('já inscrito nesta sessão: diz quem é e não deixa adicionar',
        () async {
      lookupAnswers(const CpfLookup(
        registered: true,
        enrolled: true,
        name: 'Fernanda Lopes Meireles',
      ));
      final vm = await open();

      vm.setCpf(cpf);
      await pumpEventQueue();
      vm.setName('Fernanda');

      expect(vm.cpfCheck, CpfCheck.enrolled);
      expect(vm.cpfError, 'Fernanda Lopes Meireles já está nesta sessão.');
      expect(vm.canSubmit, isFalse);
      expect(vm.name, 'Fernanda', reason: 'inscrito não preenche o formulário');
    });

    test('consulta que falha: avisa e segue como formulário simples', () async {
      when(() => participants.lookupCpf('sess-1', cpf)).thenAnswer(
        (_) async => Failure<CpfLookup>(
          Exception('sem rede'),
          'Não foi possível consultar o CPF.',
        ),
      );
      final vm = await open();

      vm.setCpf(cpf);
      await pumpEventQueue();
      vm.setName('Fernanda Lopes Meireles');

      expect(vm.cpfCheck, CpfCheck.unverified);
      expect(
        vm.cpfHelper,
        'Não foi possível consultar o CPF. Preencha os dados e adicione assim mesmo.',
      );
      expect(vm.canSubmit, isTrue);
    });

    test('a resposta atrasada de um CPF que já foi trocado é ignorada',
        () async {
      final late = Completer<Result<CpfLookup>>();
      when(() => participants.lookupCpf('sess-1', cpf))
          .thenAnswer((_) => late.future);
      final vm = await open();

      vm.setCpf(cpf);
      vm.setCpf(otherCpf);
      await pumpEventQueue();
      expect(vm.cpfCheck, CpfCheck.available);

      late.complete(const Success(registered));
      await pumpEventQueue();

      expect(vm.cpf, otherCpf);
      expect(vm.cpfCheck, CpfCheck.available);
      expect(vm.name, '', reason: 'o cadastro era do CPF anterior');
      expect(vm.filledFromRegistry, isFalse);
    });

    test('enquanto consulta, não dá para adicionar', () async {
      final answer = Completer<Result<CpfLookup>>();
      when(() => participants.lookupCpf('sess-1', cpf))
          .thenAnswer((_) => answer.future);
      final vm = await open();
      vm.setName('Fernanda Lopes Meireles');

      vm.setCpf(cpf);

      expect(vm.cpfCheck, CpfCheck.checking);
      expect(vm.canSubmit, isFalse);

      answer.complete(const Success(free));
      await pumpEventQueue();
      expect(vm.canSubmit, isTrue);
    });
  });

  group('cadastro de outro treinamento', () {
    test('preenche nome e e-mail, e avisa que vieram do cadastro', () async {
      lookupAnswers(registered);
      final vm = await open();

      vm.setCpf(cpf);
      await pumpEventQueue();

      expect(vm.cpfCheck, CpfCheck.available);
      expect(vm.name, 'Fernanda Lopes Meireles');
      expect(vm.email, 'fernanda@empresa.com.br');
      expect(vm.filledFromRegistry, isTrue);
      expect(
        vm.registryNotice,
        'Já cadastrado em outro treinamento: nome e e-mail preenchidos. '
        'Altere se precisar.',
      );
      expect(vm.canSubmit, isTrue);
    });

    test('o que o admin já tinha digitado dá lugar ao cadastro', () async {
      lookupAnswers(registered);
      final vm = await open();
      vm.setName('Fernanda');

      vm.setCpf(cpf);
      await pumpEventQueue();

      expect(vm.name, 'Fernanda Lopes Meireles');
    });

    test('cadastro sem e-mail preenche só o nome, sem apagar o e-mail digitado',
        () async {
      lookupAnswers(const CpfLookup(
        registered: true,
        enrolled: false,
        name: 'Fernanda Lopes Meireles',
      ));
      final vm = await open();
      vm.setEmail('novo@empresa.com.br');

      vm.setCpf(cpf);
      await pumpEventQueue();

      expect(vm.name, 'Fernanda Lopes Meireles');
      expect(vm.email, 'novo@empresa.com.br');
      expect(vm.filledFromRegistry, isTrue);
      expect(
        vm.registryNotice,
        'Já cadastrado em outro treinamento: nome preenchido. Altere se precisar.',
      );
    });

    test('trocar o CPF limpa o que veio do cadastro — a pessoa é outra',
        () async {
      lookupAnswers(registered);
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();

      vm.setCpf(otherCpf);
      await pumpEventQueue();

      expect(vm.name, '');
      expect(vm.email, '');
      expect(vm.filledFromRegistry, isFalse);
      expect(vm.canSubmit, isFalse, reason: 'falta o nome');
    });

    test('apagar um dígito do CPF já limpa o que veio do cadastro', () async {
      lookupAnswers(registered);
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();

      vm.setCpf('5299822472');

      expect(vm.cpfCheck, CpfCheck.incomplete);
      expect(vm.name, '');
      expect(vm.email, '');
      expect(vm.filledFromRegistry, isFalse);
    });

    test('trocar o CPF não apaga o que o admin corrigiu à mão', () async {
      lookupAnswers(registered);
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();
      vm.setName('Fernanda L. Meireles');

      vm.setCpf(otherCpf);
      await pumpEventQueue();

      expect(vm.name, 'Fernanda L. Meireles');
      expect(vm.email, '', reason: 'o e-mail ele não tinha mexido');
    });
  });

  group('demais campos', () {
    test('sem nome não adiciona', () async {
      final vm = await open();
      vm.setCpf(cpf);
      await pumpEventQueue();

      expect(vm.canSubmit, isFalse);
      vm.setName('   ');
      expect(vm.canSubmit, isFalse);
      vm.setName('Fernanda Lopes Meireles');
      expect(vm.canSubmit, isTrue);
    });

    test('e-mail é opcional; preenchido, precisa ter cara de e-mail', () async {
      final vm = await filled();
      expect(vm.isEmailValid, isTrue, reason: 'vazio vale');

      for (final wrong in ['fernanda', 'fernanda@', 'fernanda@empresa', 'a b@c.com']) {
        vm.setEmail(wrong);
        expect(vm.isEmailValid, isFalse, reason: wrong);
        expect(vm.canSubmit, isFalse, reason: wrong);
      }

      vm.setEmail(' fernanda@empresa.com.br ');
      expect(vm.isEmailValid, isTrue);
      expect(vm.canSubmit, isTrue);
    });

    test('qualquer campo preenchido conta como algo a perder ao fechar',
        () async {
      final vm = await open();

      vm.setName('F');
      expect(vm.hasInput, isTrue);
      vm.setName('');
      expect(vm.hasInput, isFalse);
      vm.setEmail('f');
      expect(vm.hasInput, isTrue);
      vm.setEmail('');
      vm.setCpf('5');
      expect(vm.hasInput, isTrue);
    });
  });

  group('adicionar', () {
    test('manda o CPF só com dígitos, o nome aparado e o tipo escolhido',
        () async {
      final vm = await open();
      vm.setCpf('529.982.247-25');
      await pumpEventQueue();
      vm.setName('  Fernanda Lopes Meireles ');
      vm.setEmail(' fernanda@empresa.com.br ');
      vm.setParticipationType(ParticipationType.somenteTeorica);

      final result = await vm.submit();

      expect(result?.id, 'tp-9');
      verify(() => participants.add(
            'sess-1',
            cpf: cpf,
            name: 'Fernanda Lopes Meireles',
            email: 'fernanda@empresa.com.br',
            participationType: ParticipationType.somenteTeorica,
          )).called(1);
      expect(vm.addedCount, 1);
      expect(vm.isSubmitting, isFalse);
      expect(vm.cpf, cpf,
          reason: 'sem "adicionar outro", o formulário fica como está: a tela fecha');
    });

    test('e-mail em branco vai nulo', () async {
      final vm = await filled();

      await vm.submit();

      verify(() => participants.add(
            'sess-1',
            cpf: cpf,
            name: 'Fernanda Lopes Meireles',
            email: null,
            participationType: ParticipationType.teoricaEPratica,
          )).called(1);
    });

    test('"Salvar e adicionar outro" limpa o formulário e conta quem entrou',
        () async {
      final vm = await filled();
      vm.setEmail('fernanda@empresa.com.br');
      vm.setParticipationType(ParticipationType.somenteTeorica);

      final result = await vm.submit(addAnother: true);

      expect(result?.name, 'Fernanda Lopes Meireles');
      expect(vm.cpf, '');
      expect(vm.name, '');
      expect(vm.email, '');
      expect(vm.participationType, ParticipationType.teoricaEPratica);
      expect(vm.cpfCheck, CpfCheck.incomplete);
      expect(vm.hasInput, isFalse);
      expect(vm.addedCount, 1);

      vm.setCpf(otherCpf);
      await pumpEventQueue();
      vm.setName('Diego Barbosa');
      await vm.submit(addAnother: true);
      expect(vm.addedCount, 2);
    });

    test('sem os dados mínimos, não chama o repositório', () async {
      final vm = await open();

      expect(await vm.submit(), isNull);

      verifyNever(() => participants.add(
            any(),
            cpf: any(named: 'cpf'),
            name: any(named: 'name'),
            email: any(named: 'email'),
            participationType: any(named: 'participationType'),
          ));
    });

    test(
        'CPF inscrito por outra pessoa entre a consulta e o toque (409): o '
        'aviso vai para o CPF', () async {
      addAnswers(const Failure<SessionParticipant>(
        ApiException(message: 'CPF já inscrito neste treinamento', statusCode: 409),
        'CPF já inscrito neste treinamento',
      ));
      final vm = await filled();

      expect(await vm.submit(), isNull);

      expect(vm.cpfCheck, CpfCheck.enrolled);
      expect(vm.cpfError, 'Este CPF já está nesta sessão.');
      expect(vm.errorMessage, isNull);
      expect(vm.canSubmit, isFalse);
      expect(vm.addedCount, 0);
    });

    test('inscrições encerradas (400): mostra o motivo e baixa a sessão de novo',
        () async {
      addAnswers(const Failure<SessionParticipant>(
        ApiException(
          message: 'Inscrições encerradas para este treinamento',
          statusCode: 400,
        ),
        'Inscrições encerradas para este treinamento',
      ));
      final vm = await filled();

      expect(await vm.submit(), isNull);

      expect(vm.errorMessage, 'Inscrições encerradas para este treinamento');
      verify(() => participants.syncSession('sess-1')).called(1);
    });

    test('sem rede: mostra o motivo, e o que foi digitado continua', () async {
      addAnswers(const Failure<SessionParticipant>(
        ApiException(message: 'Sem conexão', isNetworkError: true),
        'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      ));
      final vm = await filled();

      expect(await vm.submit(addAnother: true), isNull);

      expect(
        vm.errorMessage,
        'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      );
      expect(vm.cpf, cpf);
      expect(vm.name, 'Fernanda Lopes Meireles');
      expect(vm.canSubmit, isTrue, reason: 'dá para tentar de novo');
      verifyNever(() => participants.syncSession(any()));
    });

    test('uma exceção inesperada vira a mensagem genérica, sem travar a tela',
        () async {
      when(() => participants.add(
            'sess-1',
            cpf: any(named: 'cpf'),
            name: any(named: 'name'),
            email: any(named: 'email'),
            participationType: any(named: 'participationType'),
          )).thenThrow(StateError('banco fechado'));
      final vm = await filled();

      expect(await vm.submit(), isNull);

      expect(
        vm.errorMessage,
        'Não foi possível adicionar o participante. Tente de novo.',
      );
      expect(vm.isSubmitting, isFalse);
    });

    test('mexer num campo apaga a mensagem de erro', () async {
      addAnswers(Failure<SessionParticipant>(Exception('x'), 'Falhou.'));
      final vm = await filled();
      await vm.submit();
      expect(vm.errorMessage, 'Falhou.');

      vm.setName('Fernanda L. Meireles');

      expect(vm.errorMessage, isNull);
    });

    test('dois toques rápidos adicionam uma vez só', () async {
      final answer = Completer<Result<SessionParticipant>>();
      when(() => participants.add(
            'sess-1',
            cpf: any(named: 'cpf'),
            name: any(named: 'name'),
            email: any(named: 'email'),
            participationType: any(named: 'participationType'),
          )).thenAnswer((_) => answer.future);
      final vm = await filled();

      final first = vm.submit();
      final second = vm.submit(addAnother: true);
      expect(vm.isSubmitting, isTrue);
      expect(vm.canSubmit, isFalse);
      answer.complete(Success(added()));

      expect((await first)?.id, 'tp-9');
      expect(await second, isNull);
      expect(vm.addedCount, 1);
    });

    test('quem não pode adicionar não adiciona', () async {
      final vm = await open(user: consultora);
      vm.setCpf(cpf);
      await pumpEventQueue();
      vm.setName('Fernanda Lopes Meireles');

      expect(vm.canSubmit, isFalse);
      expect(await vm.submit(), isNull);
    });
  });

  test('fechar a tela com a consulta ainda viajando não derruba o app',
      () async {
    final answer = Completer<Result<CpfLookup>>();
    when(() => participants.lookupCpf('sess-1', cpf))
        .thenAnswer((_) => answer.future);
    final vm = AddParticipantViewModel(
      sessionId: 'sess-1',
      sessionRepository: sessions,
      participantRepository: participants,
      currentUser: admin,
    )..init();
    sessionStream.add(session());
    await pumpEventQueue();

    vm.setCpf(cpf);
    vm.dispose();
    answer.complete(const Success(registered));
    await pumpEventQueue();

    expect(vm.name, '');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/add_participant/add_participant_viewmodel_test.dart`
Esperado: não compila — `Error when reading 'lib/ui/add_participant/add_participant_viewmodel.dart'`.

- [ ] **Step 3: Implementar**

**Criar `lib/ui/add_participant/add_participant_viewmodel.dart`:**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/models/cpf_lookup.dart';
import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../utils/cpf.dart';
import '../../utils/result.dart';

/// Em que pé está o CPF digitado em "Adicionar participante".
enum CpfCheck {
  /// Menos de 11 dígitos.
  incomplete,

  /// 11 dígitos, mas os verificadores não conferem.
  invalid,

  /// Válido; a consulta ao servidor está no ar.
  checking,

  /// Válido e fora desta sessão — com ou sem cadastro de outro treinamento.
  available,

  /// Já inscrito nesta sessão.
  enrolled,

  /// Válido, mas a consulta falhou: a tela segue como formulário simples, e
  /// o backend resolve o CPF repetido.
  unverified,
}

/// Estado da tela 1.11 "Adicionar participante" (Fase 6A), só para ADMIN.
///
/// O CPF é o primeiro campo (decisão de 06/10/2026): completo e válido, é
/// consultado no servidor, que diz se já está nesta sessão e, se a pessoa
/// tem cadastro de outro treinamento, devolve nome e e-mail para preencher.
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

  /// Só para barrar erro de digitação no endereço que recebe o certificado:
  /// algo, arroba, algo, ponto, algo — sem espaços. O backend não confere.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  StreamSubscription<TrainingSession?>? _sessionSubscription;

  bool _disposed = false;
  bool _loaded = false;
  TrainingSession? _session;

  String _cpf = '';
  String _name = '';
  String _email = '';
  ParticipationType _type = ParticipationType.teoricaEPratica;
  CpfCheck _cpfCheck = CpfCheck.incomplete;

  /// Nome de quem já está na sessão com este CPF, quando a consulta o trouxe.
  String? _enrolledName;

  /// O que a consulta pôs nos campos. Enquanto o campo ainda tiver este
  /// valor, trocar o CPF o limpa — a pessoa passou a ser outra.
  String? _autoName;
  String? _autoEmail;
  bool _filledFromRegistry = false;

  bool _submitting = false;
  String? _error;
  int _addedCount = 0;

  /// Antes da primeira leitura do cache.
  bool get isLoading => !_loaded;

  /// A sessão no cache agora — o contexto do topo da tela.
  TrainingSession? get session => _session;

  /// Só os dígitos.
  String get cpf => _cpf;
  String get name => _name;
  String get email => _email;
  ParticipationType get participationType => _type;
  CpfCheck get cpfCheck => _cpfCheck;

  /// Nome e/ou e-mail vieram do cadastro de outro treinamento.
  bool get filledFromRegistry => _filledFromRegistry;

  /// O aviso de que os campos foram preenchidos pelo cadastro, dizendo quais;
  /// nulo quando nada veio de lá.
  String? get registryNotice {
    if (!_filledFromRegistry) return null;
    final filled = _autoName != null && _autoEmail != null
        ? 'nome e e-mail preenchidos'
        : _autoName != null
            ? 'nome preenchido'
            : 'e-mail preenchido';
    return 'Já cadastrado em outro treinamento: $filled. Altere se precisar.';
  }

  bool get isSubmitting => _submitting;

  /// Falha do último "adicionar", mostrada na própria tela; some quando o
  /// admin mexe num campo.
  String? get errorMessage => _error;

  /// Quantos participantes entraram desde que a tela abriu — com "Salvar e
  /// adicionar outro", pode ser mais de um. A tela de baixo se atualiza se
  /// for maior que zero.
  int get addedCount => _addedCount;

  /// Há algo digitado: fechar a tela pede confirmação.
  bool get hasInput =>
      _cpf.isNotEmpty || _name.trim().isNotEmpty || _email.trim().isNotEmpty;

  /// Por que o formulário está travado; nulo quando dá para adicionar.
  String? get lockedReason {
    if (_currentUser?.isAdmin != true) {
      return 'Só administradores podem adicionar participantes.';
    }
    final session = _session;
    if (session == null) {
      return 'Esta sessão não está mais disponível neste aparelho.';
    }
    if (session.status.acceptsChanges) return null;
    return session.status == SessionStatus.cancelado
        ? 'Sessão cancelada: não dá mais para adicionar participantes.'
        : 'Sessão concluída: não dá mais para adicionar participantes.';
  }

  bool get canAdd => _loaded && lockedReason == null;

  /// Erro sob o CPF: dígitos que não conferem, ou já inscrito nesta sessão.
  String? get cpfError => switch (_cpfCheck) {
        CpfCheck.invalid => 'CPF inválido.',
        CpfCheck.enrolled => _enrolledName == null
            ? 'Este CPF já está nesta sessão.'
            : '$_enrolledName já está nesta sessão.',
        _ => null,
      };

  /// Texto de apoio sob o CPF, quando não há erro.
  String? get cpfHelper => switch (_cpfCheck) {
        CpfCheck.checking => 'Consultando o CPF…',
        CpfCheck.available => 'CPF válido e sem cadastro nesta sessão.',
        CpfCheck.unverified =>
          'Não foi possível consultar o CPF. Preencha os dados e adicione '
              'assim mesmo.',
        _ => null,
      };

  /// Vazio vale: o e-mail é opcional.
  bool get isEmailValid {
    final email = _email.trim();
    return email.isEmpty || _emailPattern.hasMatch(email);
  }

  bool get canSubmit =>
      canAdd &&
      !_submitting &&
      (_cpfCheck == CpfCheck.available || _cpfCheck == CpfCheck.unverified) &&
      _name.trim().isNotEmpty &&
      isEmailValid;

  /// Assina o cache da sessão. Chamado uma vez pela tela.
  void init() {
    _sessionSubscription ??=
        _sessionRepository.watchSession(sessionId).listen((session) {
      _session = session;
      _loaded = true;
      notifyListeners();
    });
  }

  /// Aceita o CPF com ou sem máscara. Completo e válido, dispara a consulta.
  void setCpf(String value) {
    final digits = cpfDigits(value);
    final cpf = digits.length > 11 ? digits.substring(0, 11) : digits;
    if (cpf == _cpf) return;

    _cpf = cpf;
    _error = null;
    _enrolledName = null;
    _clearRegistryFill();

    if (cpf.length < 11) {
      _cpfCheck = CpfCheck.incomplete;
    } else if (!isValidCpf(cpf)) {
      _cpfCheck = CpfCheck.invalid;
    } else {
      _cpfCheck = CpfCheck.checking;
      unawaited(_lookup(cpf));
    }
    notifyListeners();
  }

  void setName(String value) {
    _name = value;
    _edited();
  }

  void setEmail(String value) {
    _email = value;
    _edited();
  }

  void setParticipationType(ParticipationType value) {
    _type = value;
    _edited();
  }

  void _edited() {
    _error = null;
    notifyListeners();
  }

  Future<void> _lookup(String cpf) async {
    Result<CpfLookup> result;
    try {
      result = await _participantRepository.lookupCpf(sessionId, cpf);
    } catch (error) {
      result = Failure(Exception('$error'));
    }
    // Resposta atrasada: a tela fechou, ou o CPF já é outro.
    if (_disposed || cpf != _cpf) return;

    switch (result) {
      case Success(:final data) when data.enrolled:
        _cpfCheck = CpfCheck.enrolled;
        _enrolledName = data.name;
      case Success(:final data):
        _cpfCheck = CpfCheck.available;
        if (data.registered) _fillFromRegistry(data);
      case Failure():
        _cpfCheck = CpfCheck.unverified;
    }
    notifyListeners();
  }

  /// O cadastro toma o lugar do que estiver nos campos — é o dado que a
  /// pessoa já tem no sistema. Sem e-mail no cadastro, o campo fica como está.
  void _fillFromRegistry(CpfLookup lookup) {
    final name = lookup.name;
    final email = lookup.email;
    if (name == null && email == null) return;

    if (name != null) {
      _name = name;
      _autoName = name;
    }
    if (email != null) {
      _email = email;
      _autoEmail = email;
    }
    _filledFromRegistry = true;
  }

  /// O CPF mudou: o que veio do cadastro anterior sai, a não ser que o admin
  /// tenha mexido no campo. Sem isso, a pessoa nova seria salva com o nome
  /// da anterior.
  void _clearRegistryFill() {
    if (_autoName != null && _name == _autoName) _name = '';
    if (_autoEmail != null && _email == _autoEmail) _email = '';
    _autoName = null;
    _autoEmail = null;
    _filledFromRegistry = false;
  }

  /// "Adicionar participante" e, com [addAnother], "Salvar e adicionar
  /// outro" — que limpa o formulário para o próximo. Devolve quem entrou, ou
  /// nulo se não entrou: o motivo fica em [errorMessage], ou sob o CPF quando
  /// ele já está na sessão.
  Future<SessionParticipant?> submit({bool addAnother = false}) async {
    if (!canSubmit) return null;

    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final email = _email.trim();
      final result = await _participantRepository.add(
        sessionId,
        cpf: _cpf,
        name: _name.trim(),
        email: email.isEmpty ? null : email,
        participationType: _type,
      );
      switch (result) {
        case Success(:final data):
          _addedCount++;
          if (addAnother) _reset();
          return data;
        case Failure(:final exception, :final message):
          _refused(exception, message);
          return null;
      }
    } catch (_) {
      _error = _addFailed;
      return null;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  void _refused(Exception exception, String? message) {
    final status = exception is ApiException ? exception.statusCode : null;
    if (status == 409) {
      // Outra pessoa inscreveu este CPF entre a consulta e o toque.
      _cpfCheck = CpfCheck.enrolled;
      _enrolledName = null;
      return;
    }

    _error = message ?? _addFailed;
    // 400: inscrições encerradas (a sessão foi concluída ou cancelada); 404:
    // a sessão foi apagada. Baixar de novo põe o cache — e esta tela — em dia.
    if (status == 400 || status == 404) {
      unawaited(_participantRepository.syncSession(sessionId));
    }
  }

  void _reset() {
    _cpf = '';
    _name = '';
    _email = '';
    _type = ParticipationType.teoricaEPratica;
    _cpfCheck = CpfCheck.incomplete;
    _enrolledName = null;
    _autoName = null;
    _autoEmail = null;
    _filledFromRegistry = false;
  }

  // A consulta e o "adicionar" podem responder depois de a tela fechar.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/add_participant/add_participant_viewmodel_test.dart`
Esperado: `+33: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+634: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/ui/add_participant/add_participant_viewmodel.dart \
  apps/mobile/simtc/test/ui/add_participant/add_participant_viewmodel_test.dart
git commit -m "feat(mobile): dados da tela de adicionar participante"
```

---

## Task 10: A tela 1.11 "Adicionar participante"

A tela (quadro `3a`), a rota e as duas peças que só ela usa: a máscara do CPF e a data sem o ano da faixa de contexto. Como a 1.12, ainda não tem entrada pela interface: os testes a abrem pela rota.

**Files:**
- Create: `lib/ui/add_participant/add_participant_screen.dart`
- Create: `lib/ui/core/cpf_input_formatter.dart`
- Create: `test/ui/add_participant/add_participant_screen_test.dart`
- Create: `test/ui/core/cpf_input_formatter_test.dart`
- Modify: `lib/ui/core/theme/app_icons.dart`
- Modify: `lib/ui/core/theme/app_typography.dart`
- Modify: `lib/ui/core/date_labels.dart`
- Modify: `lib/router.dart`
- Modify: `test/ui/core/date_labels_test.dart`

**Interfaces:**
- Consumes: `AddParticipantViewModel`, `CpfCheck` (Task 9); `formatCpf` (Task 5); `AppTextField` (`mono`, `trailing`, `helperText`, `labelTrailing`), `AppTextButton`, `SessionContextHeader` (Task 3); `AppLocalization` (Task 2, nos testes).
- Produces:
  - `AddParticipantScreen({required String sessionId})`.
  - `AppRoutes.addParticipant(String sessionId)` → `/sessions/$sessionId/participants/new`. A tela fecha devolvendo `true` se alguém entrou na sessão desde que ela abriu, `false` se não.
  - `CpfInputFormatter` (`lib/ui/core/cpf_input_formatter.dart`).
  - `String dayMonthLabel(DateTime date)` → "12 set".
  - `AppTypography.optionCard`, `optionCardSelected`; `AppIcons.cpf`, `practice`, `addParticipant`.

- [ ] **Step 1: Escrever os testes que falham**

**Criar `test/ui/add_participant/add_participant_screen_test.dart`:**

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/add_participant/add_participant_screen.dart';
import 'package:simtc/ui/core/app_localization.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_text_field.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockApiClient api;
  late _MockAuthRepository auth;
  late AppDatabase db;
  late SessionRepository sessionRepository;
  late ParticipantRepository participantRepository;
  late ConnectivityService connectivity;
  late GoRouter router;

  /// O que a tela devolveu ao fechar: `true` se alguém entrou na sessão.
  late Future<Object?> closed;

  const lookupPath = '/training-sessions/sess-1/participants/lookup';
  const addPath = '/training-sessions/sess-1/participants';

  // CPF com os dígitos verificadores certos.
  const cpf = '52998224725';

  const admin = AuthUser(
    id: 'u-admin',
    name: 'Sebastião Souza',
    email: 'admin@simtc.com.br',
    role: AppUserRole.admin,
    consultantId: 'c-admin',
  );
  const consultora = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-eu',
  );

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
    connectivity = ConnectivityService();
  });

  tearDown(() async {
    await db.close();
    connectivity.dispose();
  });

  Future<void> seedSession({String status = 'EM_ANDAMENTO', bool withDate = true}) {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva — Veículo Pesado',
            city: 'Itabira',
            state: 'MG',
            date: Value(withDate ? DateTime(2026, 9, 12) : null),
            status: status,
            cachedAt: DateTime(2026, 9, 12, 7),
          ),
        );
  }

  void lookupAnswers(Map<String, dynamic> body) {
    when(() => api.post<Map<String, dynamic>>(lookupPath, data: any(named: 'data')))
        .thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: lookupPath),
        statusCode: 200,
        data: body,
      ),
    );
  }

  void cpfIsFree() => lookupAnswers(
        {'registered': false, 'name': null, 'email': null, 'enrolled': false},
      );

  Map<String, dynamic> addedJson({
    String id = 'tp-9',
    String name = 'Fernanda Lopes Meireles',
    String participationType = 'TEORICA_E_PRATICA',
  }) {
    return {
      'id': id,
      'trainingSessionId': 'sess-1',
      'participationType': participationType,
      'status': 'PENDENTE',
      'assignedConsultantId': null,
      'participant': {'id': 'p-$id', 'name': name, 'cpf': cpf, 'email': null},
    };
  }

  void addAnswers(Map<String, dynamic> body) {
    when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: addPath),
        statusCode: 201,
        data: body,
      ),
    );
  }

  List<Object?> sentBodies() {
    return verify(
      () => api.post<Map<String, dynamic>>(addPath, data: captureAny(named: 'data')),
    ).captured;
  }

  Future<void> goOffline() async {
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => const Stream.empty());
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  /// A tela empilhada sobre uma origem, pela rota real.
  Future<void> pumpAdd(
    WidgetTester tester, {
    Size screen = const Size(412, 1400),
    double textScale = 1,
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
          path: '/sessions/:sessionId/participants/new',
          builder: (context, state) => AddParticipantScreen(
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
    closed = router.push<Object?>(AppRoutes.addParticipant('sess-1'));
    await tester.pumpAndSettle();
  }

  Finder field(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );

  String textOf(WidgetTester tester, String key) =>
      tester.widget<TextField>(field(key)).controller!.text;

  AppCtaButton addButton(WidgetTester tester) =>
      tester.widget<AppCtaButton>(find.byType(AppCtaButton));

  AppTextButton addAnotherButton(WidgetTester tester) =>
      tester.widget<AppTextButton>(find.byType(AppTextButton));

  /// Digita o CPF e espera a consulta responder.
  Future<void> typeCpf(WidgetTester tester, [String digits = cpf]) async {
    await tester.enterText(field('campo-cpf'), digits);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'mostra o contexto da sessão e os campos, com o CPF primeiro e '
      '"Teórica + prática" marcado', (tester) async {
    await seedSession();
    await pumpAdd(tester);

    expect(find.text('Adicionar participante'), findsNWidgets(2),
        reason: 'o título e o botão');
    expect(find.text('Bracell'), findsOneWidget);
    expect(find.text('Direção Defensiva — Veículo Pesado · 12 set'), findsOneWidget);
    expect(find.text('opcional'), findsOneWidget);
    expect(find.text('para enviar o certificado'), findsOneWidget);
    expect(find.text('Tipo de participação'), findsOneWidget);
    expect(find.text('Salvar e adicionar outro'), findsOneWidget);

    final cpfY = tester.getTopLeft(find.byKey(const Key('campo-cpf'))).dy;
    final nameY = tester.getTopLeft(find.byKey(const Key('campo-nome'))).dy;
    final emailY = tester.getTopLeft(find.byKey(const Key('campo-email'))).dy;
    expect(cpfY, lessThan(nameY));
    expect(nameY, lessThan(emailY));

    Color? borderOf(String key) {
      final box = tester.widget<Container>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(Container)),
      );
      return ((box.decoration! as BoxDecoration).border! as Border).top.color;
    }

    expect(borderOf('tipo-teoricaEPratica'), AppColors.primary);
    expect(borderOf('tipo-somenteTeorica'), AppColors.borderStrong);

    expect(addButton(tester).onPressed, isNull, reason: 'nada preenchido');
    expect(addAnotherButton(tester).onPressed, isNull);
    // Atribuir a outro consultor não existe no backend (decisão de 06/10/2026).
    expect(find.text('Consultor responsável'), findsNothing);
  });

  testWidgets('sessão sem data: a faixa de contexto mostra só o curso',
      (tester) async {
    await seedSession(withDate: false);
    await pumpAdd(tester);

    expect(find.text('Direção Defensiva — Veículo Pesado'), findsOneWidget);
  });

  testWidgets(
      'CPF livre: máscara, check e o texto do canvas; adicionar manda os '
      'dados, volta à tela de baixo e avisa', (tester) async {
    await seedSession();
    cpfIsFree();
    addAnswers(addedJson());
    await pumpAdd(tester);

    await typeCpf(tester);

    expect(textOf(tester, 'campo-cpf'), '529.982.247-25');
    expect(find.text('CPF válido e sem cadastro nesta sessão.'), findsOneWidget);
    expect(find.byIcon(AppIcons.approved), findsOneWidget);
    final sentLookup = verify(
      () => api.post<Map<String, dynamic>>(lookupPath, data: captureAny(named: 'data')),
    ).captured.single;
    expect(sentLookup, {'cpf': cpf});
    expect(addButton(tester).onPressed, isNull, reason: 'falta o nome');

    await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');
    await tester.pump();
    await tester.tap(find.widgetWithText(AppCtaButton, 'Adicionar participante'));
    await tester.pumpAndSettle();

    expect(sentBodies().single, {
      'cpf': cpf,
      'name': 'Fernanda Lopes Meireles',
      'participationType': 'TEORICA_E_PRATICA',
    });
    expect(find.text('origem'), findsOneWidget);
    expect(find.byType(AddParticipantScreen), findsNothing);
    expect(find.text('Participante adicionado.'), findsOneWidget);
    expect(await closed, isTrue);
    final row = await db.select(db.participants).getSingle();
    expect(row.name, 'Fernanda Lopes Meireles');
    expect(row.cpf, '529.982.***-**');
  });

  testWidgets(
      'CPF com cadastro de outro treinamento: preenche nome e e-mail e avisa '
      'de onde vieram', (tester) async {
    await seedSession();
    lookupAnswers({
      'registered': true,
      'name': 'Fernanda Lopes Meireles',
      'email': 'fernanda@empresa.com.br',
      'enrolled': false,
    });
    addAnswers(addedJson());
    await pumpAdd(tester);

    await typeCpf(tester);

    expect(textOf(tester, 'campo-nome'), 'Fernanda Lopes Meireles');
    expect(textOf(tester, 'campo-email'), 'fernanda@empresa.com.br');
    expect(
      find.text('Já cadastrado em outro treinamento: nome e e-mail '
          'preenchidos. Altere se precisar.'),
      findsOneWidget,
    );
    expect(addButton(tester).onPressed, isNotNull);

    // Os campos continuam editáveis: o que está na tela é o que vai.
    await tester.enterText(field('campo-nome'), 'Fernanda L. Meireles');
    await tester.pump();
    await tester.tap(find.widgetWithText(AppCtaButton, 'Adicionar participante'));
    await tester.pumpAndSettle();

    expect(sentBodies().single, {
      'cpf': cpf,
      'name': 'Fernanda L. Meireles',
      'email': 'fernanda@empresa.com.br',
      'participationType': 'TEORICA_E_PRATICA',
    });
  });

  testWidgets('trocar o CPF depois do preenchimento limpa o que veio do cadastro',
      (tester) async {
    await seedSession();
    lookupAnswers({
      'registered': true,
      'name': 'Fernanda Lopes Meireles',
      'email': 'fernanda@empresa.com.br',
      'enrolled': false,
    });
    await pumpAdd(tester);
    await typeCpf(tester);

    await tester.enterText(field('campo-cpf'), '5299822472');
    await tester.pumpAndSettle();

    expect(textOf(tester, 'campo-nome'), '');
    expect(textOf(tester, 'campo-email'), '');
    expect(find.textContaining('Já cadastrado em outro treinamento'), findsNothing);
  });

  testWidgets('CPF já nesta sessão: diz quem é e não deixa adicionar',
      (tester) async {
    await seedSession();
    lookupAnswers({
      'registered': true,
      'name': 'Fernanda Lopes Meireles',
      'email': null,
      'enrolled': true,
    });
    await pumpAdd(tester);

    await typeCpf(tester);
    await tester.enterText(field('campo-nome'), 'Fernanda');
    await tester.pump();

    expect(find.text('Fernanda Lopes Meireles já está nesta sessão.'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);
    expect(addAnotherButton(tester).onPressed, isNull);
  });

  testWidgets('CPF com dígito verificador errado: "CPF inválido.", sem consultar',
      (tester) async {
    await seedSession();
    await pumpAdd(tester);

    await typeCpf(tester, '52998224726');

    expect(find.text('CPF inválido.'), findsOneWidget);
    verifyNever(
      () => api.post<Map<String, dynamic>>(lookupPath, data: any(named: 'data')),
    );
  });

  testWidgets('consulta que falha: avisa e segue como formulário simples',
      (tester) async {
    await seedSession();
    when(() => api.post<Map<String, dynamic>>(lookupPath, data: any(named: 'data')))
        .thenThrow(const ApiException(message: 'Sem conexão', isNetworkError: true));
    addAnswers(addedJson());
    await pumpAdd(tester);

    await typeCpf(tester);
    await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');
    await tester.pump();

    expect(
      find.text('Não foi possível consultar o CPF. Preencha os dados e '
          'adicione assim mesmo.'),
      findsOneWidget,
    );
    expect(addButton(tester).onPressed, isNotNull);
  });

  testWidgets(
      '"Salvar e adicionar outro": limpa o formulário, avisa quem entrou e '
      'fica na tela; ao fechar, a tela de baixo sabe que entrou gente',
      (tester) async {
    await seedSession();
    cpfIsFree();
    addAnswers(addedJson());
    await pumpAdd(tester);
    await typeCpf(tester);
    await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');
    await tester.pump();
    await tester.tap(find.byKey(const Key('tipo-somenteTeorica')));
    await tester.pump();

    await tester.tap(find.text('Salvar e adicionar outro'));
    await tester.pumpAndSettle();

    expect(find.byType(AddParticipantScreen), findsOneWidget);
    expect(find.text('Fernanda Lopes Meireles entrou na sessão.'), findsOneWidget);
    expect(textOf(tester, 'campo-cpf'), '');
    expect(textOf(tester, 'campo-nome'), '');
    expect(textOf(tester, 'campo-email'), '');
    expect(addButton(tester).onPressed, isNull);
    expect(sentBodies().single, {
      'cpf': cpf,
      'name': 'Fernanda Lopes Meireles',
      'participationType': 'SOMENTE_TEORICA',
    });

    // Formulário vazio: o X fecha sem perguntar.
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    expect(find.text('origem'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await closed, isTrue);
  });

  testWidgets('e-mail com erro de digitação: o aviso aparece ao sair do campo',
      (tester) async {
    await seedSession();
    cpfIsFree();
    await pumpAdd(tester);
    await typeCpf(tester);
    await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');

    await tester.tap(field('campo-email'));
    await tester.enterText(field('campo-email'), 'fernanda@empresa');
    await tester.pump();

    expect(find.text('E-mail inválido.'), findsNothing, reason: 'ainda digitando');
    expect(addButton(tester).onPressed, isNull);

    await tester.tap(field('campo-nome'));
    await tester.pump();

    expect(find.text('E-mail inválido.'), findsOneWidget);

    await tester.enterText(field('campo-email'), 'fernanda@empresa.com.br');
    await tester.pump();

    expect(find.text('E-mail inválido.'), findsNothing);
    expect(addButton(tester).onPressed, isNotNull);
  });

  group('fechar a tela', () {
    testWidgets('vazia, fecha direto e avisa a tela de baixo que nada mudou',
        (tester) async {
      await seedSession();
      await pumpAdd(tester);

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      expect(await closed, isFalse);
    });

    testWidgets(
        'com algo preenchido, pergunta: "Continuar preenchendo" fica, '
        '"Descartar" fecha sem adicionar', (tester) async {
      await seedSession();
      await pumpAdd(tester);
      await tester.enterText(field('campo-nome'), 'Fernanda');
      await tester.pump();

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text('Descartar o que foi preenchido?'), findsOneWidget);

      await tester.tap(find.text('Continuar preenchendo'));
      await tester.pumpAndSettle();
      expect(find.byType(AddParticipantScreen), findsOneWidget);
      expect(textOf(tester, 'campo-nome'), 'Fernanda');

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      expect(await closed, isFalse);
      verifyNever(
        () => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')),
      );
    });

    testWidgets('o voltar do Android, com algo preenchido, também pergunta',
        (tester) async {
      await seedSession();
      await pumpAdd(tester);
      await tester.enterText(field('campo-nome'), 'Fernanda');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Descartar o que foi preenchido?'), findsOneWidget);
      expect(find.byType(AddParticipantScreen), findsOneWidget);
    });
  });

  testWidgets(
      'sem conexão: os dois botões ficam desabilitados, com o aviso, e o que '
      'foi digitado fica', (tester) async {
    await seedSession();
    cpfIsFree();
    await goOffline();
    await pumpAdd(tester);
    await typeCpf(tester);
    await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');
    await tester.pump();

    expect(
      find.text('Sem conexão — adicionar participante precisa de internet.'),
      findsOneWidget,
    );
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);
    expect(addAnotherButton(tester).onPressed, isNull);
    expect(textOf(tester, 'campo-nome'), 'Fernanda Lopes Meireles');
  });

  testWidgets(
      'celular estreito com a fonte do sistema ampliada: a tela não estoura, '
      'nem com o aviso do cadastro e os cartões em duas linhas', (tester) async {
    await seedSession();
    lookupAnswers({
      'registered': true,
      'name': 'Fernanda Lopes Meireles de Albuquerque Vasconcelos',
      'email': 'fernanda.lopes.meireles@empresa-de-transportes.com.br',
      'enrolled': false,
    });
    await pumpAdd(tester, screen: const Size(360, 1800), textScale: 1.6);

    await typeCpf(tester);

    expect(find.textContaining('Já cadastrado em outro treinamento'), findsOneWidget);
    expect(find.text('Teórica + prática'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('o servidor recusa', () {
    Future<void> fillAndAdd(WidgetTester tester) async {
      await typeCpf(tester);
      await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppCtaButton, 'Adicionar participante'));
      await tester.pumpAndSettle();
    }

    testWidgets('falha de rede: o motivo aparece na tela e os campos ficam',
        (tester) async {
      await seedSession();
      cpfIsFree();
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        isNetworkError: true,
      ));
      await pumpAdd(tester);

      await fillAndAdd(tester);

      expect(find.byType(AddParticipantScreen), findsOneWidget);
      expect(
        find.text('Sem conexão com o servidor. Verifique a internet e tente de novo.'),
        findsOneWidget,
      );
      expect(textOf(tester, 'campo-nome'), 'Fernanda Lopes Meireles');
      expect(addButton(tester).onPressed, isNotNull, reason: 'dá para tentar de novo');
    });

    testWidgets(
        'CPF inscrito por outra pessoa entre a consulta e o toque: o aviso '
        'vai para o CPF', (tester) async {
      await seedSession();
      cpfIsFree();
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'CPF já inscrito neste treinamento',
        statusCode: 409,
      ));
      await pumpAdd(tester);

      await fillAndAdd(tester);

      expect(find.text('Este CPF já está nesta sessão.'), findsOneWidget);
      expect(addButton(tester).onPressed, isNull);
    });
  });

  group('formulário travado, com o motivo escrito', () {
    testWidgets('consultor comum', (tester) async {
      when(() => auth.currentUser).thenReturn(consultora);
      await seedSession();
      await pumpAdd(tester);

      expect(
        find.text('Só administradores podem adicionar participantes.'),
        findsOneWidget,
      );
      for (final input in tester.widgetList<AppTextField>(find.byType(AppTextField))) {
        expect(input.enabled, isFalse, reason: input.label);
      }
      expect(addButton(tester).onPressed, isNull);
    });

    testWidgets('sessão concluída', (tester) async {
      await seedSession(status: 'CONCLUIDO');
      await pumpAdd(tester);

      expect(
        find.text('Sessão concluída: não dá mais para adicionar participantes.'),
        findsOneWidget,
      );
      expect(addButton(tester).onPressed, isNull);
    });
  });

  testWidgets('sessão que não está no aparelho: só o aviso', (tester) async {
    await pumpAdd(tester);

    expect(
      find.text('Esta sessão não está mais disponível neste aparelho.'),
      findsOneWidget,
    );
    expect(find.byType(AppCtaButton), findsNothing);
  });
}
```

**Criar `test/ui/core/cpf_input_formatter_test.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/cpf_input_formatter.dart';

void main() {
  const formatter = CpfInputFormatter();

  TextEditingValue typed(String text) {
    return formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
  }

  test('põe os pontos e o traço conforme os dígitos chegam', () {
    expect(typed('5299').text, '529.9');
    expect(typed('5299822').text, '529.982.2');
    expect(typed('52998224725').text, '529.982.247-25');
  });

  test('o cursor fica no fim do texto mascarado', () {
    final value = typed('5299822');

    expect(value.selection, const TextSelection.collapsed(offset: 9));
  });

  test('descarta letras e o que passa do 11º dígito', () {
    expect(typed('529a982b247c25999').text, '529.982.247-25');
  });

  test('apagar o dígito depois do traço leva o traço junto', () {
    // "529.982.247-2" com o backspace vira "529.982.247-".
    expect(typed('529.982.247-').text, '529.982.247');
    expect(typed('529.').text, '529');
  });

  testWidgets('num campo de verdade, mascara enquanto se digita', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            inputFormatters: const [CpfInputFormatter()],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '52998224725');

    expect(controller.text, '529.982.247-25');
  });
}
```

**Em `test/ui/core/date_labels_test.dart`, substituir:**

```dart

  test('dayMonthYearLabel escreve a data da sessão por extenso curto', () {
    expect(dayMonthYearLabel(DateTime(2026, 9, 12)), '12 set 2026');
  });

  test('momentLabel diz "hoje" no mesmo dia', () {
```

**por:**

```dart

  test('dayMonthYearLabel escreve a data da sessão por extenso curto', () {
    expect(dayMonthYearLabel(DateTime(2026, 9, 12)), '12 set 2026');
  });

  test('dayMonthLabel é a mesma data, sem o ano', () {
    expect(dayMonthLabel(DateTime(2026, 9, 12)), '12 set');
    expect(dayMonthLabel(DateTime(2027, 1, 5)), '5 jan');
  });

  test('momentLabel diz "hoje" no mesmo dia', () {
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/add_participant/add_participant_screen_test.dart test/ui/core/cpf_input_formatter_test.dart test/ui/core/date_labels_test.dart`
Esperado: não compilam — `Error when reading 'lib/ui/add_participant/add_participant_screen.dart'` e `Member not found: 'AppRoutes.addParticipant'` no teste da tela; `Error when reading 'lib/ui/core/cpf_input_formatter.dart'` no da máscara; `Method not found: 'dayMonthLabel'` no dos rótulos de data.

- [ ] **Step 3: Implementar**

**Em `lib/router.dart`, substituir:**

```dart
import 'package:go_router/go_router.dart';

import 'data/repositories/auth_repository.dart';
import 'ui/auth/login_screen.dart';
import 'ui/checklist/checklist_screen.dart';
import 'ui/debug/ds_gallery_screen.dart';
```

**por:**

```dart
import 'package:go_router/go_router.dart';

import 'data/repositories/auth_repository.dart';
import 'ui/add_participant/add_participant_screen.dart';
import 'ui/auth/login_screen.dart';
import 'ui/checklist/checklist_screen.dart';
import 'ui/debug/ds_gallery_screen.dart';
```

**Em `lib/router.dart`, substituir:**

```dart

  /// "Dados do treinamento" (tela 1.12, Fase 6A), só para ADMIN.
  static String sessionEdit(String sessionId) => '/sessions/$sessionId/edit';

  /// Checklist do participante (Fase 4). [fromResult]: aberto pelo
  /// "Reavaliar" do Resultado, que continua embaixo — o voltar leva a ele.
```

**por:**

```dart

  /// "Dados do treinamento" (tela 1.12, Fase 6A), só para ADMIN.
  static String sessionEdit(String sessionId) => '/sessions/$sessionId/edit';

  /// "Adicionar participante" (tela 1.11, Fase 6A), só para ADMIN.
  static String addParticipant(String sessionId) =>
      '/sessions/$sessionId/participants/new';

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
            path: 'participants/new',
            builder: (context, state) => AddParticipantScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
          GoRoute(
            path: 'participants/:participantId/checklist',
            builder: (context, state) => ChecklistScreen(
              sessionId: state.pathParameters['sessionId']!,
```

**Criar `lib/ui/add_participant/add_participant_screen.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../core/cpf_input_formatter.dart';
import '../core/date_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/session_context_header.dart';
import '../core/widgets/skeleton.dart';
import '../core/widgets/sync_status_indicator.dart';
import 'add_participant_viewmodel.dart';

/// Tela 1.11 — "Adicionar participante" (quadro "3a" do canvas), só para
/// ADMIN.
///
/// Diferenças do canvas, aprovadas em 06/10/2026: o CPF vem antes do nome
/// (ele é consultado no servidor, que preenche o resto para quem já tem
/// cadastro), não há "Consultor responsável" (o participante entra pendente;
/// atribuir a outro consultor não existe no backend) e os avisos da consulta
/// são novos.
class AddParticipantScreen extends StatefulWidget {
  const AddParticipantScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<AddParticipantScreen> createState() => _AddParticipantScreenState();
}

class _AddParticipantScreenState extends State<AddParticipantScreen> {
  late final AddParticipantViewModel _viewModel = AddParticipantViewModel(
    sessionId: widget.sessionId,
    sessionRepository: context.read<SessionRepository>(),
    participantRepository: context.read<ParticipantRepository>(),
    currentUser: context.read<AuthRepository>().currentUser,
  )..init();

  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _cpfFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_syncFields);
    _emailFocus.addListener(_onEmailFocusChange);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_syncFields);
    _emailFocus.removeListener(_onEmailFocusChange);
    _viewModel.dispose();
    _cpfController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _cpfFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  /// Leva para os campos o que a ViewModel mudou sozinha: o preenchimento
  /// pelo cadastro, a limpeza ao trocar o CPF e o formulário zerado do
  /// "Salvar e adicionar outro". O que o admin digita já chega igual, e aí
  /// nada é reescrito (o cursor fica onde está).
  void _syncFields() {
    if (_nameController.text != _viewModel.name) {
      _nameController.text = _viewModel.name;
    }
    if (_emailController.text != _viewModel.email) {
      _emailController.text = _viewModel.email;
    }
    if (_viewModel.cpf.isEmpty && _cpfController.text.isNotEmpty) {
      _cpfController.clear();
    }
  }

  /// O erro do e-mail só aparece depois que o admin sai do campo — no meio
  /// da digitação, todo e-mail está "errado".
  void _onEmailFocusChange() => setState(() {});

  bool get _fieldsEnabled => _viewModel.canAdd && !_viewModel.isSubmitting;

  bool get _showEmailError => !_emailFocus.hasFocus && !_viewModel.isEmailValid;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    // Todo fechar passa por `_close`: ele confirma o descarte e devolve à
    // tela de baixo se alguém foi adicionado.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
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
              if (_viewModel.session != null) _buildFooter(isOffline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) return _buildSkeleton();

    final session = _viewModel.session;
    final lockedReason = _viewModel.lockedReason;
    if (session == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: InlineNotice(icon: AppIcons.sessions, message: lockedReason ?? ''),
      );
    }

    final registryNotice = _viewModel.registryNotice;
    final errorMessage = _viewModel.errorMessage;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        SessionContextHeader(
          companyName: session.companyName,
          logoUrl: session.companyLogoUrl,
          subtitle: _contextLine(session),
          muted: true,
        ),
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
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.lg),
                InlineNotice(
                  icon: AppIcons.needsReview,
                  message: errorMessage,
                  tone: NoticeTone.danger,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "Direção Defensiva — Veículo Pesado · 12 set": o admin cadastra em
  /// sequência e precisa saber em que sessão está.
  String _contextLine(TrainingSession session) {
    final date = session.date;
    return date == null
        ? session.courseName
        : '${session.courseName} · ${dayMonthLabel(date)}';
  }

  /// Primeiro campo, e sem máscara de privacidade: é o admin digitando, não
  /// a tela que passa pela mão do participante (canvas "3a").
  Widget _buildCpfField() {
    return AppTextField(
      key: const Key('campo-cpf'),
      label: 'CPF',
      controller: _cpfController,
      focusNode: _cpfFocus,
      icon: AppIcons.cpf,
      hintText: '000.000.000-00',
      mono: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: const [CpfInputFormatter()],
      enabled: _fieldsEnabled,
      errorText: _viewModel.cpfError,
      helperText: _viewModel.cpfHelper,
      trailing: _buildCpfTrailing(),
      onChanged: _viewModel.setCpf,
    );
  }

  Widget? _buildCpfTrailing() {
    return switch (_viewModel.cpfCheck) {
      CpfCheck.checking => const SizedBox.square(
          dimension: AppSpacing.lg + 2,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      CpfCheck.available =>
        const Icon(AppIcons.approved, size: 20, color: AppColors.savedInk),
      _ => null,
    };
  }

  Widget _buildNameField() {
    return AppTextField(
      key: const Key('campo-nome'),
      label: 'Nome completo',
      controller: _nameController,
      icon: AppIcons.profile,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      enabled: _fieldsEnabled,
      onChanged: _viewModel.setName,
    );
  }

  Widget _buildEmailField() {
    return AppTextField(
      key: const Key('campo-email'),
      label: 'E-mail',
      labelTrailing: 'opcional',
      controller: _emailController,
      focusNode: _emailFocus,
      icon: AppIcons.email,
      hintText: 'para enviar o certificado',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      enabled: _fieldsEnabled,
      errorText: _showEmailError ? 'E-mail inválido.' : null,
      onChanged: _viewModel.setEmail,
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo de participação', style: AppTypography.fieldLabel),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildTypeOption(
                type: ParticipationType.teoricaEPratica,
                label: 'Teórica + prática',
                icon: AppIcons.practice,
                iconColor: AppColors.text3,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildTypeOption(
                type: ParticipationType.somenteTeorica,
                label: 'Somente teórica',
                icon: AppIcons.theoryOnly,
                iconColor: AppColors.mauve,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required ParticipationType type,
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    final selected = _viewModel.participationType == type;

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
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isOffline) {
    final canSubmit = _viewModel.canSubmit && !isOffline;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCtaButton(
            label: 'Adicionar participante',
            icon: AppIcons.addParticipant,
            size: AppCtaSize.large,
            isLoading: _viewModel.isSubmitting,
            onPressed: canSubmit ? () => _submit(addAnother: false) : null,
          ),
          if (isOffline && _viewModel.canAdd) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Text(
              'Disponível quando houver conexão',
              style: AppTypography.meta,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          AppTextButton(
            label: 'Salvar e adicionar outro',
            onPressed: canSubmit ? () => _submit(addAnother: true) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _submit({required bool addAnother}) async {
    FocusScope.of(context).unfocus();
    final added = await _viewModel.submit(addAnother: addAnother);
    if (added == null || !mounted) return;

    // O SnackBar é do `ScaffoldMessenger` do app: continua na tela de baixo.
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (!addAnother) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Participante adicionado.')),
      );
      Navigator.of(context).pop(true);
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('${added.name} entrou na sessão.')),
    );
    _cpfFocus.requestFocus();
  }

  /// O X, o voltar do Android e o gesto de voltar caem aqui. Com algo
  /// preenchido, pergunta antes; e devolve `true` se alguém entrou na sessão
  /// desde que a tela abriu, para o detalhe se atualizar.
  Future<void> _close() async {
    if (_viewModel.isSubmitting) return;
    if (_viewModel.hasInput && !await _confirmDiscard()) return;
    if (mounted) Navigator.of(context).pop(_viewModel.addedCount > 0);
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar o que foi preenchido?'),
        content: const Text('Este participante ainda não foi adicionado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar preenchendo'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerInk),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Widget _buildSkeleton() {
    return ListView(
      key: const Key('add-participant-skeleton'),
      children: const [SkeletonListItem(), SkeletonListItem(), SkeletonListItem()],
    );
  }
}
```

**Criar `lib/ui/core/cpf_input_formatter.dart`:**

```dart
import 'package:flutter/services.dart';

import '../../utils/cpf.dart';

/// Mascara o CPF enquanto ele é digitado ("529.982.247-25") e descarta o que
/// passa do 11º dígito.
///
/// O cursor vai sempre para o fim: o campo é curto e digitado de uma vez, e
/// reposicionar o cursor no meio da máscara custaria mais do que vale.
class CpfInputFormatter extends TextInputFormatter {
  const CpfInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = formatCpf(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
```

**Em `lib/ui/core/date_labels.dart`, substituir:**

```dart

String _dois(int value) => value.toString().padLeft(2, '0');

/// "12 set 2026" — a data de uma sessão, no cabeçalho do detalhe.
String dayMonthYearLabel(DateTime date) =>
    '${date.day} ${_meses[date.month - 1]} ${date.year}';

/// Quando algo aconteceu, do jeito que se fala em campo: "hoje 08:12",
/// "12 set 08:12" ou, em outro ano, "12 set 2025 08:12". Converte para a hora
```

**por:**

```dart

String _dois(int value) => value.toString().padLeft(2, '0');

/// "12 set" — a data de uma sessão onde o ano não precisa aparecer (a faixa
/// de contexto de "Adicionar participante").
String dayMonthLabel(DateTime date) => '${date.day} ${_meses[date.month - 1]}';

/// "12 set 2026" — a data de uma sessão, no cabeçalho do detalhe.
String dayMonthYearLabel(DateTime date) =>
    '${dayMonthLabel(date)} ${date.year}';

/// Quando algo aconteceu, do jeito que se fala em campo: "hoje 08:12",
/// "12 set 08:12" ou, em outro ano, "12 set 2025 08:12". Converte para a hora
```

**Em `lib/ui/core/theme/app_icons.dart`, substituir:**

```dart
  /// "Dados do treinamento" (Fase 6A, canvas "3b"): salvar e cancelar sessão.
  static const IconData save = Icons.save_outlined;
  static const IconData cancelSession = Icons.event_busy_outlined;
}
```

**por:**

```dart
  /// "Dados do treinamento" (Fase 6A, canvas "3b"): salvar e cancelar sessão.
  static const IconData save = Icons.save_outlined;
  static const IconData cancelSession = Icons.event_busy_outlined;

  /// "Adicionar participante" (Fase 6A, canvas "3a"): o campo do CPF, o
  /// cartão "Teórica + prática" e o botão que adiciona.
  static const IconData cpf = Icons.badge_outlined;
  static const IconData practice = Icons.directions_car_outlined;
  static const IconData addParticipant = Icons.person_add_outlined;
}
```

**Em `lib/ui/core/theme/app_typography.dart`, substituir:**

```dart
  /// Empresa na faixa de contexto dos formulários de ADMIN (canvas "3b")
  static TextStyle get contextTitle =>
      _inter(size: 15, weight: FontWeight.w600, height: 1.25);

  /// Rótulo de chip (status, severidade, filtro)
  static TextStyle get chipLabel =>
```

**por:**

```dart
  /// Empresa na faixa de contexto dos formulários de ADMIN (canvas "3b")
  static TextStyle get contextTitle =>
      _inter(size: 15, weight: FontWeight.w600, height: 1.25);

  /// Rótulo de um cartão de opção ("Somente teórica", canvas "3a"). São dois
  /// estilos, e não um `copyWith(fontWeight:)`: o `copyWith` não mexe no
  /// `fontVariations`, e é do eixo `wght` que vem o peso da fonte variável.
  static TextStyle get optionCard =>
      _inter(size: 13, weight: FontWeight.w600, height: 1.2, color: AppColors.text2);

  /// O cartão de opção escolhido ("Teórica + prática")
  static TextStyle get optionCardSelected =>
      _inter(size: 13, weight: FontWeight.w700, height: 1.2, color: AppColors.primaryDark);

  /// Rótulo de chip (status, severidade, filtro)
  static TextStyle get chipLabel =>
```

Os campos de nome e e-mail só são reescritos pela tela quando a ViewModel os mudou sozinha (o preenchimento pelo cadastro, a limpeza ao trocar o CPF, o formulário zerado): o que o admin digita já chega igual, e o cursor fica onde está. Os dois estilos do cartão de opção são tokens separados, e não um `copyWith(fontWeight:)`: o `copyWith` não mexe no `fontVariations` do estilo, e é do eixo `wght` que vem o peso da fonte variável.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/add_participant/add_participant_screen_test.dart test/ui/core/cpf_input_formatter_test.dart test/ui/core/date_labels_test.dart`
Esperado: `+35: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+660: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/router.dart \
  apps/mobile/simtc/lib/ui/add_participant/add_participant_screen.dart \
  apps/mobile/simtc/lib/ui/core/cpf_input_formatter.dart \
  apps/mobile/simtc/lib/ui/core/date_labels.dart \
  apps/mobile/simtc/lib/ui/core/theme/app_icons.dart \
  apps/mobile/simtc/lib/ui/core/theme/app_typography.dart \
  apps/mobile/simtc/test/ui/add_participant/add_participant_screen_test.dart \
  apps/mobile/simtc/test/ui/core/cpf_input_formatter_test.dart \
  apps/mobile/simtc/test/ui/core/date_labels_test.dart
git commit -m "feat(mobile): tela 1.11 de adicionar participante"
```

---

## Task 11: As ações de ADMIN no detalhe da sessão

A entrada das duas telas (quadro `1f`): o lápis na barra superior e o ícone de adicionar à direita do título "Participantes". Só ADMIN vê; fora de hora — sem conexão, ou com a sessão concluída ou cancelada — ficam à vista, apagados, e o aviso da lista diz o motivo. Para o consultor comum, a tela não muda.

**Files:**
- Modify: `lib/ui/core/theme/app_icons.dart`
- Modify: `lib/ui/session_detail/session_detail_viewmodel.dart`
- Modify: `lib/ui/session_detail/session_detail_screen.dart`
- Modify: `test/ui/session_detail/session_detail_viewmodel_test.dart`
- Modify: `test/ui/session_detail/session_detail_screen_test.dart`

**Interfaces:**
- Consumes: `AppTopBar.actions`, `AppIconAction` (Task 3); `SessionStatus.acceptsChanges` (Task 7); `AppRoutes.sessionEdit` (Task 8) e `AppRoutes.addParticipant` (Task 10), com o que cada tela devolve ao fechar; `SessionDetailViewModel.refresh()`; `AppIcons.addParticipant` (Task 10).
- Produces: `bool SessionDetailViewModel.isAdmin`; `bool SessionDetailViewModel.adminActionsAllowed`; `AppIcons.edit`.

- [ ] **Step 1: Escrever os testes que falham**

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/date_labels.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/session_detail/participant_row.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}
```

**por:**

```dart
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/add_participant/add_participant_screen.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/date_labels.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/session_detail/participant_row.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
import 'package:simtc/ui/session_edit/session_edit_screen.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-eu',
  );

  TrainingSession session({
```

**por:**

```dart
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-eu',
  );
  const admin = AuthUser(
    id: 'u-admin',
    name: 'Sebastião Souza',
    email: 'admin@simtc.com.br',
    role: AppUserRole.admin,
    consultantId: 'c-admin',
  );

  TrainingSession session({
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => assessments.watchSessionAssessments('sess-1', 'u1'))
        .thenAnswer((_) => localStream.stream);
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
```

**por:**

```dart
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => assessments.watchSessionAssessments('sess-1', 'u1'))
        .thenAnswer((_) => localStream.stream);
    // O ADMIN dos testes da Fase 6A é outro usuário, com a própria fila.
    when(() => assessments.watchSessionAssessments('sess-1', 'u-admin'))
        .thenAnswer((_) => localStream.stream);
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
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

  group('ações de ADMIN (Fase 6A)', () {
    AppIconAction action(WidgetTester tester, IconData icon) =>
        tester.widget<AppIconAction>(find.widgetWithIcon(AppIconAction, icon));

    testWidgets('consultor comum não vê o lápis nem o adicionar participante',
        (tester) async {
      await show(tester, withParticipants: [
        participant('2', 'Carlos Eduardo Nunes'),
      ]);

      expect(find.byType(AppIconAction), findsNothing);
      expect(find.byTooltip('Editar dados do treinamento'), findsNothing);
      expect(find.byTooltip('Adicionar participante'), findsNothing);
    });

    testWidgets(
        'ADMIN vê os dois, habilitados, e o cabeçalho continua com o status e '
        'as observações', (tester) async {
      when(() => auth.currentUser).thenReturn(admin);

      await show(tester);

      expect(action(tester, AppIcons.edit).onPressed, isNotNull);
      expect(action(tester, AppIcons.addParticipant).onPressed, isNotNull);
      expect(find.byTooltip('Editar dados do treinamento'), findsOneWidget);
      expect(find.byTooltip('Adicionar participante'), findsOneWidget);
      // O quadro "1f" não desenha os dois, mas o ADMIN precisa de ambos.
      expect(find.text('Em andamento'), findsOneWidget);
      expect(find.text('Pátio 3 — apresentar-se na portaria B às 07h30.'),
          findsOneWidget);
    });

    testWidgets('o adicionar fica na linha do título "Participantes", à direita',
        (tester) async {
      when(() => auth.currentUser).thenReturn(admin);

      await show(tester);

      final title = tester.getCenter(find.text('Participantes'));
      final add = tester.getCenter(find.byTooltip('Adicionar participante'));
      expect(add.dy, closeTo(title.dy, 1));
      expect(add.dx, greaterThan(title.dx));
      expect(tester.getSize(find.widgetWithIcon(AppIconAction, AppIcons.addParticipant)),
          const Size(48, 48));
    });

    testWidgets('sessão planejada também aceita as ações de ADMIN',
        (tester) async {
      when(() => auth.currentUser).thenReturn(admin);

      await show(tester, withSession: session(status: SessionStatus.planejado));

      expect(action(tester, AppIcons.edit).onPressed, isNotNull);
      expect(action(tester, AppIcons.addParticipant).onPressed, isNotNull);
    });

    testWidgets(
        'ADMIN sem conexão: os dois continuam à vista, apagados, com o aviso '
        'do canvas', (tester) async {
      when(() => auth.currentUser).thenReturn(admin);
      await goOffline();

      await show(tester, withParticipants: [
        participant('2', 'Carlos Eduardo Nunes'),
      ]);

      expect(action(tester, AppIcons.edit).onPressed, isNull);
      expect(action(tester, AppIcons.addParticipant).onPressed, isNull);
      expect(
        find.text('Ações administrativas precisam de conexão. A avaliação '
            'continua funcionando offline.'),
        findsOneWidget,
      );
      expect(find.textContaining('atribuir precisa de internet'), findsNothing,
          reason: 'um aviso por vez');
    });

    testWidgets(
        'ADMIN em sessão concluída ou cancelada: apagados, e o aviso diz que '
        'os dados não mudam mais', (tester) async {
      when(() => auth.currentUser).thenReturn(admin);

      await show(tester, withSession: session(status: SessionStatus.concluido));

      expect(action(tester, AppIcons.edit).onPressed, isNull);
      expect(action(tester, AppIcons.addParticipant).onPressed, isNull);
      expect(
        find.text('Sessão concluída: os participantes ficam só para consulta, '
            'e os dados não podem mais ser alterados.'),
        findsOneWidget,
      );

      sessionStream.add(session(status: SessionStatus.cancelado));
      await tester.pump();

      expect(action(tester, AppIcons.edit).onPressed, isNull);
      expect(
        find.text('Sessão cancelada: os participantes ficam só para consulta, '
            'e os dados não podem mais ser alterados.'),
        findsOneWidget,
      );
    });

    testWidgets('consultor comum em sessão concluída vê o aviso de sempre',
        (tester) async {
      await show(tester, withSession: session(status: SessionStatus.concluido));

      expect(
        find.text('Sessão concluída: os participantes ficam só para consulta.'),
        findsOneWidget,
      );
    });

    testWidgets('antes de a sessão carregar, o lápis do ADMIN já está lá, apagado',
        (tester) async {
      when(() => auth.currentUser).thenReturn(admin);
      await tester.pumpWidget(
        withProviders(
          const MaterialApp(home: SessionDetailScreen(sessionId: 'sess-1')),
        ),
      );
      await tester.pump();

      expect(action(tester, AppIcons.edit).onPressed, isNull);
    });
  });

  group('navegação pelas rotas reais', () {
    /// O detalhe aberto pelo `createRouter` de produção; devolve o router,
    /// para o teste empilhar outra rota real por cima.
```

**Em `test/ui/session_detail/session_detail_screen_test.dart`, substituir:**

```dart
      expect(find.byType(ResultScreen), findsNothing);
      expect(find.byType(ChecklistScreen), findsNothing);
    });
  });
}
```

**por:**

```dart
      expect(find.byType(ResultScreen), findsNothing);
      expect(find.byType(ChecklistScreen), findsNothing);
    });

    group('ADMIN', () {
      /// O detalhe do ADMIN pelas rotas reais. As telas de ADMIN assinam o
      /// mesmo cache depois: cada assinatura recebe a sessão de novo, como o
      /// banco de verdade faz (o stream de transmissão dos outros testes só
      /// entrega a quem já estava ouvindo).
      Future<GoRouter> showAdmin(WidgetTester tester) async {
        when(() => auth.currentUser).thenReturn(admin);
        when(() => sessions.watchSession('sess-1'))
            .thenAnswer((_) => Stream.value(session()));
        when(() => participants.watchBySession('sess-1'))
            .thenAnswer((_) => Stream.value(const []));
        final router = await showWithRouter(tester, const []);
        await tester.pumpAndSettle();
        // Só as chamadas daqui para a frente interessam (a abertura já baixou
        // a sessão uma vez).
        clearInteractions(participants);
        return router;
      }

      testWidgets(
          'o lápis abre "Dados do treinamento"; voltar de lá depois de salvar '
          'baixa a sessão de novo', (tester) async {
        final router = await showAdmin(tester);

        await tester.tap(find.byTooltip('Editar dados do treinamento'));
        await tester.pumpAndSettle();

        expect(find.byType(SessionEditScreen), findsOneWidget);

        router.pop(true);
        await tester.pumpAndSettle();

        expect(find.byType(SessionEditScreen), findsNothing);
        expect(find.byType(SessionDetailScreen), findsOneWidget);
        verify(() => participants.syncSession('sess-1')).called(1);
      });

      testWidgets('voltar de "Dados do treinamento" sem salvar não baixa nada',
          (tester) async {
        final router = await showAdmin(tester);
        await tester.tap(find.byTooltip('Editar dados do treinamento'));
        await tester.pumpAndSettle();

        router.pop();
        await tester.pumpAndSettle();

        expect(find.byType(SessionDetailScreen), findsOneWidget);
        verifyNever(() => participants.syncSession(any()));
      });

      testWidgets(
          'o adicionar abre "Adicionar participante"; fechar com alguém '
          'adicionado baixa a sessão de novo', (tester) async {
        final router = await showAdmin(tester);

        await tester.tap(find.byTooltip('Adicionar participante'));
        await tester.pumpAndSettle();

        expect(find.byType(AddParticipantScreen), findsOneWidget);

        router.pop(true);
        await tester.pumpAndSettle();

        expect(find.byType(AddParticipantScreen), findsNothing);
        verify(() => participants.syncSession('sess-1')).called(1);
      });

      testWidgets('fechar "Adicionar participante" sem adicionar não baixa nada',
          (tester) async {
        final router = await showAdmin(tester);
        await tester.tap(find.byTooltip('Adicionar participante'));
        await tester.pumpAndSettle();

        router.pop(false);
        await tester.pumpAndSettle();

        expect(find.byType(SessionDetailScreen), findsOneWidget);
        verifyNever(() => participants.syncSession(any()));
      });
    });
  });
}
```

**Em `test/ui/session_detail/session_detail_viewmodel_test.dart`, substituir:**

```dart
      );
      expect(jaIniciada.canStartSession, isFalse);
    });
  });

  group('linha "comigo" depois do envio aceito (revisão de 30/09/2026)', () {
```

**por:**

```dart
      );
      expect(jaIniciada.canStartSession, isFalse);
    });

    group('ações de ADMIN (Fase 6A)', () {
      const admin = AuthUser(
        id: 'u2',
        name: 'Rita Alves',
        email: 'rita@simtc.com.br',
        role: AppUserRole.admin,
      );

      test('o consultor comum não as tem', () async {
        final vm = await ready();

        expect(vm.isAdmin, isFalse);
        expect(vm.adminActionsAllowed, isFalse);
      });

      test('valem com a sessão planejada ou em andamento', () async {
        for (final status in [SessionStatus.planejado, SessionStatus.emAndamento]) {
          final vm = await ready(withSession: session(status: status), user: admin);

          expect(vm.isAdmin, isTrue);
          expect(vm.adminActionsAllowed, isTrue, reason: status.name);
        }
      });

      test('sessão concluída ou cancelada: o ADMIN continua ADMIN, mas as '
          'ações não valem', () async {
        for (final status in [SessionStatus.concluido, SessionStatus.cancelado]) {
          final vm = await ready(withSession: session(status: status), user: admin);

          expect(vm.isAdmin, isTrue);
          expect(vm.adminActionsAllowed, isFalse, reason: status.name);
        }
      });

      test('antes de a sessão chegar do cache, ficam desligadas', () {
        final vm = build(user: admin)..init();

        expect(vm.isAdmin, isTrue);
        expect(vm.adminActionsAllowed, isFalse);
      });
    });
  });

  group('linha "comigo" depois do envio aceito (revisão de 30/09/2026)', () {
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/ui/session_detail`
Esperado: não compilam — `Member not found: 'edit'` (o `AppIcons.edit`) e `The getter 'adminActionsAllowed' isn't defined for the type 'SessionDetailViewModel'`.

- [ ] **Step 3: Implementar**

**Em `lib/ui/core/theme/app_icons.dart`, substituir:**

```dart
  static const IconData save = Icons.save_outlined;
  static const IconData cancelSession = Icons.event_busy_outlined;

  /// "Adicionar participante" (Fase 6A, canvas "3a"): o campo do CPF, o
  /// cartão "Teórica + prática" e o botão que adiciona.
  static const IconData cpf = Icons.badge_outlined;
```

**por:**

```dart
  static const IconData save = Icons.save_outlined;
  static const IconData cancelSession = Icons.event_busy_outlined;

  /// O lápis do ADMIN na barra do detalhe da sessão (Fase 6A, canvas "1f").
  static const IconData edit = Icons.edit_outlined;

  /// "Adicionar participante" (Fase 6A, canvas "3a"): o campo do CPF, o
  /// cartão "Teórica + prática" e o botão que adiciona.
  static const IconData cpf = Icons.badge_outlined;
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
```

**por:**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
          children: [
            AppTopBar(
              title: 'Detalhe da sessão',
              trailing: SyncStatusIndicator(
                onTap: () => context.go(AppRoutes.sync),
              ),
```

**por:**

```dart
          children: [
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
              ),
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
        ),
      ),
    );
  }

  Widget _buildBody(bool isOffline) {
```

**por:**

```dart
        ),
      ),
    );
  }

  /// As ações de ADMIN (canvas "1f") precisam de conexão e de uma sessão
  /// que ainda aceite mudanças. Sem isso, continuam à vista, apagadas — e o
  /// aviso da lista diz o motivo.
  bool _adminActionsEnabled(bool isOffline) =>
      _viewModel.adminActionsAllowed && !isOffline;

  /// Salvou lá: baixa a sessão de novo, para ficar com o estado oficial do
  /// servidor. (Se a sessão foi cancelada, a tela de lá já levou o ADMIN para
  /// a lista, e este detalhe nem existe mais.)
  Future<void> _openEdit() async {
    final saved =
        await context.push<bool>(AppRoutes.sessionEdit(widget.sessionId));
    if (saved == true && mounted) unawaited(_viewModel.refresh());
  }

  /// Entrou gente lá: a linha nova já está no cache, e baixar de novo acerta
  /// os contadores.
  Future<void> _openAddParticipant() async {
    final added =
        await context.push<bool>(AppRoutes.addParticipant(widget.sessionId));
    if (added == true && mounted) unawaited(_viewModel.refresh());
  }

  Widget _buildBody(bool isOffline) {
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
              ),
              child: notice,
            ),
          _buildListHeader(),
          if (visible.isEmpty)
            _buildEmpty()
          else
```

**por:**

```dart
              ),
              child: notice,
            ),
          _buildListHeader(isOffline),
          if (visible.isEmpty)
            _buildEmpty()
          else
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
      );
    }

    switch (session.status) {
      case SessionStatus.planejado:
        // Quem pode iniciar já tem o botão e a explicação no cabeçalho.
```

**por:**

```dart
      );
    }

    // ADMIN sem conexão, numa sessão que ainda aceita mudanças: o aviso do
    // canvas "1f". Cobre também o "Atribuir a mim", que fica desabilitado.
    if (isOffline && _viewModel.adminActionsAllowed) {
      return const InlineNotice(
        icon: AppIcons.offline,
        tone: NoticeTone.warning,
        message: 'Ações administrativas precisam de conexão. A avaliação '
            'continua funcionando offline.',
      );
    }

    // O ADMIN vê o lápis e o adicionar apagados: o aviso diz por quê.
    final lockedForAdmin = _viewModel.isAdmin
        ? ', e os dados não podem mais ser alterados.'
        : '.';

    switch (session.status) {
      case SessionStatus.planejado:
        // Quem pode iniciar já tem o botão e a explicação no cabeçalho.
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
              'e avaliar participantes.',
        );
      case SessionStatus.concluido:
        return const InlineNotice(
          icon: AppIcons.approved,
          message: 'Sessão concluída: os participantes ficam só para consulta.',
        );
      case SessionStatus.cancelado:
        return const InlineNotice(
          icon: AppIcons.needsReview,
          message: 'Sessão cancelada: os participantes ficam só para consulta.',
        );
      case SessionStatus.emAndamento:
        if (!_viewModel.hasConsultantProfile) {
```

**por:**

```dart
              'e avaliar participantes.',
        );
      case SessionStatus.concluido:
        return InlineNotice(
          icon: AppIcons.approved,
          message: 'Sessão concluída: os participantes ficam só para consulta'
              '$lockedForAdmin',
        );
      case SessionStatus.cancelado:
        return InlineNotice(
          icon: AppIcons.needsReview,
          message: 'Sessão cancelada: os participantes ficam só para consulta'
              '$lockedForAdmin',
        );
      case SessionStatus.emAndamento:
        if (!_viewModel.hasConsultantProfile) {
```

**Em `lib/ui/session_detail/session_detail_screen.dart`, substituir:**

```dart
    }
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg - 1,
      ),
      child: Text('Participantes', style: AppTypography.sectionTitle),
    );
  }
```

**por:**

```dart
    }
  }

  Widget _buildListHeader(bool isOffline) {
    final title = Text('Participantes', style: AppTypography.sectionTitle);
    if (!_viewModel.isAdmin) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg - 1,
        ),
        child: title,
      );
    }

    // ADMIN (canvas "1f"): o "adicionar participante" à direita do título. O
    // alvo de 48dp já dá a altura da linha; o recuo menor à direita alinha o
    // ícone, e não a área de toque, com a margem da lista.
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(child: title),
          AppIconAction(
            icon: AppIcons.addParticipant,
            tooltip: 'Adicionar participante',
            onPressed:
                _adminActionsEnabled(isOffline) ? _openAddParticipant : null,
          ),
        ],
      ),
    );
  }
```

**Em `lib/ui/session_detail/session_detail_viewmodel.dart`, substituir:**

```dart
    return myConsultantId != null &&
        session.responsibleConsultantId == myConsultantId;
  }

  /// Há alguém que eu poderia atribuir agora — é quando o aviso de "atribuir
  /// precisa de internet" faz sentido.
```

**por:**

```dart
    return myConsultantId != null &&
        session.responsibleConsultantId == myConsultantId;
  }

  /// O lápis e o "adicionar participante" (Fase 6A) são só do ADMIN. Para
  /// ele, nunca somem: fora de hora, ficam apagados.
  bool get isAdmin => _currentUser?.isAdmin == true;

  /// O backend só aceita editar a sessão e inscrever participante com ela
  /// planejada ou em andamento. A tela ainda exige conexão.
  bool get adminActionsAllowed =>
      isAdmin && (_session?.status.acceptsChanges ?? false);

  /// Há alguém que eu poderia atribuir agora — é quando o aviso de "atribuir
  /// precisa de internet" faz sentido.
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/ui/session_detail`
Esperado: `+79: All tests passed!`

- [ ] **Step 5: Suíte inteira e análise**

Run: `flutter analyze` e `flutter test`
Esperado: `No issues found!` e `+676: All tests passed!`

- [ ] **Step 6: Commit**

A partir da raiz do repositório:

```bash
git add apps/mobile/simtc/lib/ui/core/theme/app_icons.dart \
  apps/mobile/simtc/lib/ui/session_detail/session_detail_screen.dart \
  apps/mobile/simtc/lib/ui/session_detail/session_detail_viewmodel.dart \
  apps/mobile/simtc/test/ui/session_detail/session_detail_screen_test.dart \
  apps/mobile/simtc/test/ui/session_detail/session_detail_viewmodel_test.dart
git commit -m "feat(mobile): acoes de admin no detalhe da sessao"
```

---

## Task 12: Validação no aparelho físico

Esta task é o portão da fase: sem ela, a 6B não é planejada (decisão do usuário, registrada em 17/09/2026). É o roteiro que só o usuário pode rodar.

**Files:** nenhum arquivo de código.

**Interfaces:**
- Consumes: o app inteiro e o backend com a consulta de CPF.
- Produces: o aval do usuário para planejar a 6B.

- [ ] **Step 1: Subir o backend com o endpoint novo e liberar a porta**

Run: `cd apps/backend && npm run start:dev`

Em outro terminal, com o aparelho conectado: `adb reverse tcp:3001 tcp:3001` (o id do aparelho sai de `adb devices`).

- [ ] **Step 2: Instalar no aparelho**

Run (em `apps/mobile/simtc`): `flutter pub get` e `flutter run -d <ID_DO_APARELHO>`

Sem `--dart-define`. Instale por cima, sem desinstalar.

- [ ] **Step 3: Percorrer o roteiro de aceite**

Preparação, com rede: um usuário **ADMIN** e um **consultor comum**; na Home, uma sessão "Em andamento" com alguns participantes e outra sessão **de teste**, que possa ser cancelada; tenha à mão o painel web.

Detalhe da sessão, como ADMIN:
- [ ] a barra mostra o lápis antes do indicador de envio, e o título "Participantes" tem o ícone de adicionar à direita; o cabeçalho continua com o status e as observações;
- [ ] **offline** (modo avião + `adb -s <ID> reverse --remove tcp:3001`): os dois ícones continuam à vista, apagados, e a lista mostra "Ações administrativas precisam de conexão. A avaliação continua funcionando offline.";
- [ ] numa sessão **concluída**, os dois ícones ficam apagados e o aviso termina com "e os dados não podem mais ser alterados."

Detalhe da sessão, como consultor comum:
- [ ] nenhum dos dois ícones aparece; a tela está como antes.

Dados do treinamento:
- [ ] o lápis abre a tela com a faixa de contexto (logo, empresa e curso) e os campos com os valores da sessão; "Salvar alterações" começa desabilitado;
- [ ] o campo "Data" abre o calendário **em português**; escolha outro dia e confira o campo;
- [ ] mude a cidade, a UF e as observações e toque em "Salvar alterações": volta ao detalhe com "Dados do treinamento atualizados." e os dados novos no cabeçalho — no painel web, também;
- [ ] UF "XX": aparece "UF inválida." e o salvar desabilita; cidade vazia: "Informe a cidade.";
- [ ] apague as observações e salve: o bloco de observações some do detalhe;
- [ ] mude algo e toque no voltar: o diálogo pergunta se descarta; "Continuar editando" fica, "Descartar" sai sem salvar; o "Descartar" do rodapé sai direto;
- [ ] com a tela aberta, tire a rede: "Salvar alterações" e "Cancelar sessão" desabilitam, com "Disponível quando houver conexão"; volte a rede: os botões voltam e o que foi digitado continua lá;
- [ ] com o backend parado (e o aparelho com rede), mude a cidade e toque em "Salvar alterações": o motivo aparece no rodapé, acima do botão, e o que foi digitado fica; toque num campo: com o teclado aberto, o aviso some e o rodapé fica só com os dois botões; feche o teclado sem digitar: o aviso volta (suba o backend de novo antes de seguir);
- [ ] na sessão de teste, "Cancelar sessão": o diálogo diz a consequência e quantos estão em avaliação; "Voltar" não cancela; "Cancelar sessão" leva à lista de sessões com "Sessão cancelada.", a sessão some da lista e o painel web a mostra como cancelada.

Adicionar participante:
- [ ] o ícone abre a tela com a faixa "curso · data", o CPF como primeiro campo e "Teórica + prática" marcado;
- [ ] o CPF é mascarado enquanto se digita; um CPF com dígito errado mostra "CPF inválido.";
- [ ] um CPF válido e novo: aparece "Consultando o CPF…" e depois o check com "CPF válido e sem cadastro nesta sessão."; preencha o nome e toque em "Adicionar participante": volta ao detalhe com "Participante adicionado." e a pessoa na lista, como "Pendente" — no painel web, também;
- [ ] o CPF de alguém que já fez **outro** treinamento: nome e e-mail aparecem preenchidos, com o aviso "Já cadastrado em outro treinamento…"; apague um dígito do CPF: os dois campos se limpam;
- [ ] o CPF de alguém que **já está nesta sessão**: "Fulano já está nesta sessão." e os dois botões desabilitados; o X pergunta se descarta, sem a frase "Este participante ainda não foi adicionado.";
- [ ] com o detalhe da sessão aberto no app, inscreva alguém pelo painel web; sem puxar para atualizar, abra "Adicionar participante" e digite o CPF dessa pessoa: a tela diz que ela já está na sessão e, ao fechar, ela aparece na lista;
- [ ] um e-mail com erro ("nome@empresa"): ao sair do campo, aparece "E-mail inválido.";
- [ ] "Somente teórica" e "Salvar e adicionar outro": o formulário se limpa, o aviso diz quem entrou e o foco volta ao CPF; feche pelo X: o detalhe já mostra a pessoa, com o chip "Somente teórica";
- [ ] com algo preenchido, o X pergunta se descarta.

Avaliação presa:
- [ ] como consultor, inicie a avaliação de um participante de uma sessão de teste; pelo painel web, conclua (ou cancele) essa sessão; no app, puxe para atualizar a lista de sessões; em outra sessão em andamento, o "Iniciar avaliação" de outro participante funciona, sem o aviso de "Você já está avaliando…".

Regressões:
- [ ] "Atribuir a mim", o checklist, a conferência, o Resultado e a aba "Sincronizar" continuam como na 5B;
- [ ] com uma avaliação iniciada e ainda aberta numa sessão em andamento, o aviso de uma por vez continua aparecendo em outro participante;
- [ ] um toque longo num campo de texto mostra o menu de copiar/colar em português.

Visual (ver "Ajustes feitos ao preparar o plano"):
- [ ] as duas telas novas com o teclado aberto: o rodapé (só os dois botões, enquanto o teclado está aberto) e o campo em edição continuam alcançáveis;
- [ ] a linha "Cidade | UF" e os dois cartões de tipo numa tela estreita ou com a fonte do sistema ampliada;
- [ ] o alinhamento do ícone de adicionar com a margem da lista, e a altura da linha "Participantes" do ADMIN;
- [ ] o rodapé das duas telas novas: o espaço entre os dois botões e o recuo embaixo.

Em modo debug (`flutter run`), um estouro de layout aparece como uma faixa listrada amarela e preta. Ainda é esperado num caso só: a 1.11 sem conexão, num aparelho de até 640dp de altura, com o teclado aberto e a fonte do sistema em 1,6x ou mais (pendência da Fase 8).

**Não verificável neste aparelho, e por quê:** a recusa do servidor com o formulário aberto (alguém conclui a sessão, ou inscreve o mesmo CPF, entre abrir a tela e tocar no botão) depende de coordenar dois aparelhos no mesmo segundo — fica coberta pelos testes das Tasks 7 e 9 e pelos testes de tela das Tasks 8 e 10; a resposta atrasada da consulta de um CPF que já foi trocado só aparece com a rede lenta — Task 9; a consulta de CPF que falha depende de o servidor cair entre abrir a tela e digitar — Tasks 9 e 10; a rota aberta por quem não é ADMIN não tem caminho pela interface — Tasks 8 e 10; a avaliação presa por consultor removido ou por participante liberado só passa a acontecer pelo app na 6B — fica coberta pelos testes da Task 6.

- [x] **Step 4: Registrar o resultado**

**Validado em 09/10/2026, no aparelho físico, pelo usuário: o roteiro passou inteiro. As oito "Decisões em aberto" seguem em aberto. Aval dado para planejar a Fase 6B.**

Se tudo passar, avisar o usuário e pedir o aval para planejar a 6B. Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio ou de contrato do backend, parar e perguntar.

---

## Pendências levadas para as fases seguintes

Resolvidas nesta fase: as pendências "6" da auditoria da Fase 0 sobre adicionar participante (a busca por CPF) e sobre desabilitar as ações de ADMIN em sessão concluída ou cancelada; e a "decisão em aberto" nº 1 da 5B (a avaliação iniciada numa sessão que foi concluída ou cancelada).

| Fase | Pendência |
|---|---|
| 6B | A tela 1.13 Consultores da sessão, o "N consultores" do cabeçalho e o ícone de pessoas da barra (decisão 1). |
| 6B | Remover um consultor com avaliação em andamento devolve os participantes dele para "Pendente" (ou o status da nota anterior) — mudança no backend, que vale também para o painel web (decisão 6). |
| 6B | ADMIN desatribuir um participante de outro consultor, por um menu ⋮ na linha (decisão 6). O `unassign` só libera os do próprio consultor. |
| 6B | A avaliação presa de um participante liberado que volta pelo "Reavaliar": hoje o checklist abre já iniciado, com a avaliação antiga, sem reservar o participante. Só passa a acontecer quando a 6B trouxer a liberação; a correção é o checklist tratar como "não iniciada" a avaliação de quem não está com o consultor. |
| 6B | A avaliação presa que volta a valer (o participante é reatribuído ao mesmo consultor) depois de outra ter sido iniciada: ficam duas abertas ao mesmo tempo, porque nada é apagado (decisão 5). Só passa a acontecer pelo app com a liberação; decidir no plano da 6B. |
| 8 | A consulta de CPF que falhou não é refeita sozinha quando a rede volta: o admin precisa mexer no CPF, ou seguir sem ela (ver a decisão em aberto 3). |
| 8 | O formulário de "Dados do treinamento" não atualiza os campos que o admin não tocou quando o cache muda com a tela aberta (eles não são enviados, então nada se perde). |
| 8 | A máscara do CPF leva o cursor sempre para o fim do campo. |
| 8 | As buscas (a lupa do detalhe, da Home e, na 6B, da tela de Consultores). |
| 8 | As "decisões em aberto" 2 a 6 da 5B (indicador de progresso do desatribuir, "Tentar novamente" ao lado do "Descartar", a pílula que não encolhe, a setinha das linhas da fila e o texto do descarte que não apagou) continuam em aberto. |
| 8 | Limpeza: as duas telas novas repetem o rodapé com borda e o diálogo de confirmação que já se repetiam nas outras (pendência da 5B). |
| 8 | A tela travada ainda pergunta se descarta: depois que a sessão é concluída por outra pessoa com mudança por salvar, o voltar da 1.12 e o X da 1.11 abrem a confirmação, sem haver mais o que salvar. |
| 8 | Rodapé das duas telas novas com o teclado aberto: sobraram duas combinações com estouro (a 1.11 sem conexão, em aparelho de 640dp de altura, com teclado alto e fonte em 1,6x ou mais). E, na 1.12, o "Cancelar sessão" não tira o foco do campo antes do diálogo: com um campo em edição, o teclado volta sozinho quando o diálogo fecha e, se o cancelar falhar nesse intervalo, o aviso fica escondido até o teclado fechar (uma linha no `_confirmCancel`). |
| 8 | Consulta de CPF: a resposta atrasada é reconhecida pelo CPF, e não pela consulta (digitar, apagar um dígito e redigitar antes da resposta dispara duas, e a segunda pode repor o nome do cadastro sobre uma correção do admin); e ela não tem tempo limite próprio (com sinal ruim, "Consultando o CPF…" segura os botões por até 35 segundos). |
| 8 | Sessão apagada no servidor (404) com a 1.11 ou a 1.12 aberta: a tela mostra o texto do servidor e continua aberta para edição (baixar de novo só resolve a recusa por status); sem teste. E `lockedReason`, nas duas ViewModels novas, devolve "Esta sessão não está mais disponível neste aparelho." enquanto a tela carrega (sem efeito hoje: as telas olham o carregamento antes). |
| 8 | Corridas do "grava no cache e baixa de novo": a resposta atrasada de uma baixa da sessão pode regravar o cache por cima do que acabou de ser salvo, cancelado ou adicionado, até a próxima baixa (janela estreita; cura-se sozinho). |
| 8 | O aviso "Você já está avaliando…" do checklist só é recalculado ao abrir a tela e ao descartar: com a regra nova da avaliação presa, ele pode ficar desatualizado até a tela ser reaberta. E os rascunhos presos de sessão concluída ou cancelada ficam no aparelho para sempre (decisão 5): falta uma limpeza. |
| 8 | Leitor de tela (TalkBack) nas telas novas: o campo só leitura da data gera três nós soltos, e os cartões de tipo não dizem "desativado" nem mostram a ondulação do toque. Conferir também o gesto de voltar preditivo do Android 14 em diante, e o formulário depois de o Android encerrar o app em segundo plano (o que foi digitado se perde, como em todas as telas). |
| 8 | Limpeza de código anotada pelas revisões: o esqueleto repetido de `start`, `update` e `cancel` no `SessionRepository`, com duas versões de "mantém a mensagem do backend", e o `update` gravando no cache a data como veio (quem chama já normaliza); o `add` do `ParticipantRepository` mandando CPF e e-mail como chegam (quem chama já normaliza) e devolvendo um participante sem `id`, sem dizer isso no comentário, quando a resposta vem fora do formato; a terceira cópia do spinner dos botões e da regra "está comigo" (`SessionParticipant.isWith`); os textos de falha duplicados entre repositório e ViewModel; `_openEdit` e `_openAddParticipant`; o exemplo do campo do CPF em Inter, com os dígitos em fonte mono; comentários imprecisos (a data vazia no `SessionRepository`, o rodapé da 1.12); a faixa do `intl` no `pubspec.yaml`, presa à versão do SDK; e, no backend, a consulta de inscrição repetida três vezes no `participants.service.ts`. |
| 8 | Lacunas de teste anotadas pelas revisões, em que o código faz a coisa certa hoje — fundação e repositórios: no `widget_test.dart`, nada afirma que o `SimtcApp` repassa os delegates de idioma, e o banco em memória não usa `closeStreamsSynchronously`; nos widgets do Design System, a posição da nota "opcional", a borda e a cor do ícone do botão de perigo, a cor desenhada do `AppIconAction`, o repasse do `logoUrl` e as reticências do cabeçalho de contexto (o teste trava o corte, não o "…"); no `SessionRepository`, o 404, o `Failure.exception` com o `statusCode` e a exceção que não é `ApiException`; no CPF, o ramo "resto 10 vira dígito 0" (`123.456.789-09`); no `ParticipantRepository`, o 404 e a falta de rede no `add` e o erro do servidor no `lookupCpf`; na avaliação presa, a cláusula de status isolada (participante "Pendente" ainda com o consultor); e, no backend, o `where`, o `select` e a mensagem do 404 da consulta de CPF. |
| 8 | Lacunas de teste — ViewModels e telas: na `SessionEditViewModel`, o 404, cancelar duas vezes e cancelar durante o salvar, a UF aparada no envio e as 27 siglas; na `AddParticipantViewModel`, o 404, a consulta que lança exceção, o envio que termina depois de a tela fechar e o erro que some ao mexer no CPF; na 1.12, o indicador de carregamento do salvar e do cancelar, a sessão planejada (editável) e a cancelada (travada), e a recusa do cancelar com o repositório de verdade; na 1.11, os campos e os cartões travados durante o envio, o primeiro quadro (carregando), o estado "consultando" e o CPF que continua no campo depois da recusa; no detalhe, o ADMIN sem conexão em sessão concluída, cancelada ou planejada, o "Atribuir a mim" do ADMIN sem conexão e uma âncora positiva no teste do consultor. E o ruído antigo na saída da suíte (avisos do drift em `app_database_test.dart` e o `debugPrint` do envio). |
| 8 | A data copiada para a avaliação ao iniciar não acompanha uma mudança de data da sessão feita depois (pelo app ou pelo painel): conferir o que vai para o servidor. |
| 8 | Conferir no aparelho os `copyWith(fontWeight: …)` que já existem nas telas (por exemplo, a linha do progresso no detalhe da sessão): o `copyWith` não mexe no `fontVariations` do estilo, de onde vem o peso da fonte variável, então o peso pedido pode não aparecer. Não foi conferido nesta fase. |
| Backend | No `POST …/participants`, o `ValidateCpfPipe` é aplicado pelo decorator e o que ele devolve é descartado: o CPF é gravado como veio. O web e o app mandam só dígitos, mas um cliente que mande o CPF com máscara cria um cadastro duplicado. Pela leitura do código, um corpo sem `cpf` também chega ao pipe antes da validação do DTO e vira erro 500, em vez de 400. |
| Backend | `PATCH /training-sessions/:id` não tem como apagar a data (data vazia é ignorada), e o `email` do `AddParticipantDto` não é conferido como e-mail. |
| Backend | `cancelSession` não mexe nos participantes: quem estava "em avaliação" continua assim numa sessão cancelada. |
| Backend | No `POST …/participants`, o nome e o e-mail do cadastro são atualizados **antes** da recusa por CPF já inscrito (409): numa recusa, o que o admin digitou ainda é gravado no cadastro compartilhado. |
| Backend | `assign` e `sync` não conferem o status da sessão (a regra está só no app); a consulta de CPF não tem limite de frequência; e `updateParticipationType` existe no service sem rota — se ganhar uma, a regra da avaliação presa (`_canStillOpen`) precisa olhar o tipo de participação. |
| Backend | O inventário de endpoints de `apps/backend/CLAUDE.md` não lista o `POST …/participants/lookup`. |
| Web | O painel não usa a consulta de CPF nova (continua trocando o nome do cadastro sem avisar) e não consegue apagar as observações de uma sessão (o formulário não manda o campo quando ele fica vazio). |
| — | Canvas: a 1.12 sem "Início", com "Cidade" + "UF" e sem o contador; a 1.11 com o CPF primeiro, sem "Consultor responsável" e com os avisos da consulta; os diálogos de confirmação. Atualizar no Claude Design. |

As pendências da Fase 8 que vieram da 5A e da 5B e não estão acima continuam valendo como estão nos planos delas.
