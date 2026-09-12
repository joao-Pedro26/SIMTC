# Brainstorm — App Mobile SIMTC (Flutter)

**Data:** 11/09/2026
**Escopo:** App exclusivo para o fluxo de avaliação prática de participantes. Sem dashboards, sem gestão de empresas/consultores/cursos — só "encontrar meu treinamento → atribuir participante → preencher checklist → assinar → sincronizar".

---

## 0. Premissas assumidas (confirmadas com o usuário + inferidas do backend)

Confirmadas via perguntas diretas:

1. **Acesso à sessão:** ao logar, o consultor já vê a lista de treinamentos (`TrainingSession`) em que foi vinculado previamente no painel web/admin (relação `SessionConsultant`). Não há leitura de QR code no app.
2. **Atribuição:** é autoatribuição dentro do app. O consultor vê os participantes `PENDENTE` de uma sessão e toca em "Atribuir a mim", que chama `POST /practical-assessments/assign`. Isso reserva o participante (`assignedConsultantId` = ele, `status` → `EM_AVALIACAO`) e impede que outro consultor pegue o mesmo participante.
3. **Offline obrigatório:** o app precisa funcionar sem internet durante o preenchimento da avaliação (o local do treinamento pode não ter sinal). Tudo é salvo localmente (Drift/SQLite) e sincronizado depois via `POST /practical-assessments/sync`, quando houver conexão (`connectivity_plus`).
4. **Assinatura do participante:** será capturada no app ao final da avaliação, como confirmação de que ele foi avaliado. **Gap identificado:** hoje `PracticalAssessment` não tem campo de assinatura nem endpoint de upload — será necessário criar uma migration (`signatureUrl` ou similar em `PracticalAssessment`) e um endpoint/bucket de upload no backend antes de ativar essa funcionalidade em produção. O app já nasce preparado (captura + armazenamento local + fila de upload), mas o envio ao backend fica bloqueado até esse trabalho ser feito.
   Fotos de evidência ficam **fora de escopo** por enquanto.

Inferências necessárias para o fluxo (a validar com o usuário durante a implementação, mas assumidas para não travar o planejamento):

5. Só participantes com `participationType = TEORICA_E_PRATICA` entram no fluxo de avaliação prática. Participantes `SOMENTE_TEORICA` aparecem na lista da sessão apenas como informativo (badge "somente teórica"), sem ação de atribuir/avaliar.
6. `NECESSITA_REAVALIACAO` permite reavaliação: o consultor pode tocar em "Reavaliar", que reabre o checklist (a avaliação é 1:1 com o participante — `PracticalAssessment.trainingParticipantId` é único — então reavaliar é um update do mesmo registro, refazendo o `sync`).
7. O checklist é percorrido por categoria (`AssessmentCategory` → `Infraction`); cada infração tem 4 estados possíveis: sem marcação (nenhuma infração), B, PM ou M (`InfractionNote`). Categorias sem nenhuma infração marcada valem 100% automaticamente (já é assim no `scoring.ts`).
8. O catálogo de categorias/infrações/notas é praticamente estático (muda raramente, via admin web) — pode ser cacheado localmente e atualizado em background, não precisa ser buscado a cada avaliação.
9. `startTime`/`endTime` do `PracticalAssessment` são preenchidos automaticamente: `startTime` quando o consultor abre o checklist pela primeira vez para aquele participante, `endTime` quando ele finaliza/assina.
10. Login no app é exclusivo para `role = CONSULTANT` (o app não implementa o fluxo OTP de `CLIENT`, que é só usado no portal web do cliente). O app deve validar o `role` retornado por `/auth/me` e bloquear acesso de outros perfis.

Confirmadas na 2ª rodada de perguntas (diferenciação admin × consultor):

11. **Todo ADMIN também é um Consultant** (tem `consultantId` vinculado) — não existe admin "puro" que só administra e nunca avalia. Ou seja, no app, `role` decide o que aparece de *extra* na tela, mas o fluxo de avaliação em si é o mesmo para os dois perfis.
12. **O que o admin pode editar "na hora" (igual à web), direto na tela de Detalhe da Sessão:** adicionar participantes à sessão, alterar data, cidade, estado e observações da sessão, e alterar quais consultores estão vinculados a ela. Não inclui trocar curso/empresa da sessão nem editar dados individuais de participantes já cadastrados (isso continua exclusivo do painel web).
13. **Edições administrativas exigem conexão** — diferente do fluxo de avaliação (que é offline-first), as ações de admin (editar sessão, adicionar participante, gerenciar consultores) só ficam disponíveis quando o app está online, evitando conflito com edições feitas simultaneamente no painel web. Se estiver offline, os controles de edição ficam desabilitados/ocultos com uma mensagem explicativa.

---

## 1. Mapeamento de Telas

### 1.1 Splash / Bootstrap
Tela de abertura, sem interação do usuário. Mostra o logo SIM Treinamentos centralizado. Ao fundo, o app verifica se há token salvo (`flutter_secure_storage`) e, se houver, tenta validar/renovar via `/auth/refresh` ou `/auth/me`. Decide silenciosamente para onde navegar.

### 1.2 Login
Campos: e-mail e senha (sem etapa de OTP, já que o app é só para `CONSULTANT`). Botão "Entrar". Estado de erro inline (credenciais inválidas, consultor inativo — mensagem específica quando `Consultant.active = false`). Indicador de "sem conexão" caso o dispositivo esteja offline no primeiro login (login exige rede, diferente do uso posterior do app).

### 1.3 Minhas Sessões (Home)
Lista de `TrainingSession` vinculadas ao consultor logado (via `SessionConsultant`), ordenadas por data (mais próximas/recentes primeiro). Cada card mostra: **logo da empresa contratante** (`Company.logoUrl`, à esquerda ou no topo do card — com um placeholder/avatar de iniciais caso a empresa não tenha logo cadastrado), nome da empresa, curso, cidade/UF, data, status da sessão (`PLANEJADO/EM_ANDAMENTO/CONCLUIDO/CANCELADO`) e um contador "X de Y participantes avaliados". Barra superior com indicador de conectividade (online/offline) e ícone de sincronização pendente (badge com número de avaliações aguardando envio). Pull-to-refresh para atualizar a lista quando online.

*Nota técnica:* `Company.logoUrl` já existe no schema. Como o app é offline-first, a imagem do logo deve ser cacheada localmente (ex.: `cached_network_image`, que já está no `pubspec.yaml`) assim que a sessão for sincronizada pela primeira vez, para continuar aparecendo mesmo sem conexão.

### 1.4 Detalhe da Sessão (Lista de Participantes)
Mostra os dados da sessão no topo (logo da empresa, empresa, curso, local, data, observações) e a lista de `TrainingParticipant` daquela sessão. Cada item exibe: nome do participante, CPF, `participationType`, e um chip de status colorido:
- Cinza — `PENDENTE` (ninguém atribuído ainda) → botão "Atribuir a mim"
- Amarelo — `EM_AVALIACAO`, atribuído a mim → toque abre o Formulário de Avaliação
- Amarelo apagado/bloqueado — `EM_AVALIACAO`, atribuído a outro consultor → sem ação disponível, só informativo
- Verde — `APROVADO` → toque abre o Resultado (somente leitura)
- Vermelho/laranja — `NECESSITA_REAVALIACAO` → toque abre o Resultado com botão "Reavaliar"
- Badge neutro "Somente teórica" para `participationType = SOMENTE_TEORICA` (sem ação)

Filtro/segmento rápido no topo (Todos / Pendentes / Meus / Concluídos).

**Diferenciação ADMIN × CONSULTANT nesta tela:** quando o usuário logado tem `role = ADMIN` (além de `CONSULTANT`), aparece um botão "Editar sessão" (ícone de lápis) no cabeçalho e um botão "Adicionar participante" no fim da lista — ambos **visíveis apenas quando o app está online** (se offline, aparecem desabilitados com um tooltip/mensagem "disponível apenas com conexão"). Para o consultor comum (sem `ADMIN`), esses controles simplesmente não aparecem — a tela é idêntica à descrita acima.

- **"Editar sessão"** abre a tela/modal 1.4.1 (Editar Dados da Sessão), com data, cidade, estado e observações.
- **"Adicionar participante"** abre a tela/modal 1.4.2 (Adicionar Participante), permitindo buscar um participante existente (por CPF) ou cadastrar um novo, e vinculá-lo à sessão.
- Um terceiro atalho, "Gerenciar consultores" (ícone de pessoas no cabeçalho), abre a tela/modal 1.4.3, listando os consultores vinculados à sessão (`SessionConsultant`) com opção de adicionar/remover.

#### 1.4.1 Editar Dados da Sessão (admin, modal/tela)
Formulário simples com os campos editáveis da sessão: data, cidade, estado (UF) e observações. Botão "Salvar" (chama a API diretamente, exige conexão) e "Cancelar". Validação básica de campos obrigatórios. Ao salvar com sucesso, volta para o Detalhe da Sessão já atualizado.

#### 1.4.2 Adicionar Participante (admin, modal/tela)
Campo de busca por CPF (verifica se o participante já existe no sistema); se existir, mostra os dados encontrados para confirmação; se não existir, abre um miniformulário de cadastro (nome, CPF, e-mail opcional) e um seletor de `participationType` (Somente Teórica / Teórica e Prática). Botão "Adicionar à sessão" (exige conexão).

#### 1.4.3 Gerenciar Consultores da Sessão (admin, modal/tela)
Lista os consultores atualmente vinculados à sessão (via `SessionConsultant`), com opção de remover (exceto o responsável, que exige trocar antes de remover). Botão "Adicionar consultor" abre uma busca/lista de consultores ativos disponíveis para vincular. Exige conexão.

*Nota técnica:* como o backend só aceita replace total (`PATCH /training-sessions/:id` com `additionalConsultantsIds` completo), a tela deve carregar a lista atual, aplicar as alterações localmente (adições/remoções) e só então enviar a lista inteira de uma vez ao salvar — não há chamada incremental por consultor.

### 1.5 Formulário de Avaliação (Checklist)
Tela principal do app. Cabeçalho com nome do participante e cronômetro discreto (tempo decorrido desde `startTime`). Corpo em lista expansível por `AssessmentCategory` (accordion), cada categoria mostrando suas `Infraction`; cada infração tem um seletor de 4 opções (Sem infração / B / PM / M), com o texto de `InfractionNote.comment` visível ao selecionar B/PM/M. Barra de progresso mostrando quantas categorias já foram revisadas. Botão flutuante "Finalizar avaliação" (habilitado mesmo com categorias não abertas — assume-se sem infração se não revisada, mas exibe confirmação antes de finalizar se houver categorias não abertas). Autosave local a cada alteração (Drift), permitindo fechar o app e retomar depois.

### 1.6 Resumo da Avaliação
Ao finalizar o checklist: mostra o score calculado localmente (mesmo algoritmo de `scoring.ts`, portado para Dart), o resultado (`Aprovado` ✅ ou `Necessita Reavaliação` ⚠️, com o corte de 70%), e um resumo por categoria (percentual de cada uma). Botão "Confirmar e assinar".

### 1.7 Assinatura do Participante
Canvas de assinatura em tela cheia (dedo/caneta), com botões "Limpar" e "Confirmar". Texto curto acima explicando que a assinatura confirma a ciência do participante sobre o resultado. Ao confirmar, salva a imagem localmente e marca a avaliação como `finalizada` (pendente de sync).

### 1.8 Resultado (somente leitura)
Para participantes já avaliados (`APROVADO`/`NECESSITA_REAVALIACAO`). Mostra o mesmo resumo por categoria, score final, data/hora da avaliação, e a assinatura capturada (se houver). Se `NECESSITA_REAVALIACAO`, exibe botão "Reavaliar" que reabre o Formulário de Avaliação (novo ciclo, reaproveitando o registro).

### 1.9 Sincronização
Lista das avaliações pendentes de envio (com status: aguardando conexão / enviando / erro) e das últimas sincronizadas com sucesso. **A sincronização é 100% automática, sem botão manual:** assim que o app detecta que a conexão voltou (via `connectivity_plus`), a fila de avaliações pendentes é enviada sozinha em background, sem qualquer ação do consultor. Essa tela existe apenas como um painel de visibilidade (o que está pendente, o que já foi enviado, e detalhes de erro por item — ex: "participante já avaliado por outro consultor — conflito", replicando as validações do `assign`/`sync` do backend). Itens com erro ficam na fila e são reprocessados automaticamente na próxima janela de conectividade (com backoff), sem precisar de intervenção manual.

*Nota técnica:* o disparo automático deve acontecer em qualquer tela do app (não só quando o usuário está na tela de Sincronização) — o `ConnectivityService` deve notificar o `SyncViewModel`/uma camada de serviço global assim que o status mudar de offline para online, iniciando o envio da fila imediatamente. O badge de "itens pendentes" na Home (1.3) deve atualizar em tempo real conforme os itens vão sendo sincronizados.

### 1.10 Perfil / Configurações
Dados do consultor logado (nome, e-mail, foto se houver). Botão "Sair" (logout, limpa token e — com confirmação — dados locais não sincronizados). Informação de versão do app. Futuro: alternar ambiente (prod/staging) só em build de debug.

---

## 2. Fluxo de Navegação

```
Splash
 ├─ (token inválido/ausente) → Login
 └─ (token válido, role=CONSULTANT) → Minhas Sessões

Login → (sucesso) → Minhas Sessões

Minhas Sessões
 ├─ [tap sessão] → Detalhe da Sessão
 ├─ [ícone sync] → Sincronização
 └─ [ícone perfil] → Perfil/Configurações

Detalhe da Sessão
 ├─ [Atribuir a mim em item PENDENTE] → (fica na mesma tela, item vira "meu, EM_AVALIACAO")
 ├─ [tap item meu, EM_AVALIACAO] → Formulário de Avaliação
 ├─ [tap item APROVADO/NECESSITA_REAVALIACAO] → Resultado (somente leitura)
 ├─ [Editar sessão] (só ADMIN, só online) → Editar Dados da Sessão → [Salvar] → volta atualizado
 ├─ [Adicionar participante] (só ADMIN, só online) → Adicionar Participante → [Confirmar] → volta com novo item na lista
 ├─ [Gerenciar consultores] (só ADMIN, só online) → Gerenciar Consultores da Sessão → [voltar] → Detalhe da Sessão
 └─ [voltar] → Minhas Sessões

Formulário de Avaliação → [Finalizar avaliação] → Resumo da Avaliação

Resumo da Avaliação → [Confirmar e assinar] → Assinatura do Participante

Assinatura do Participante → [Confirmar] → volta para Detalhe da Sessão
  (item agora aparece como APROVADO ou NECESSITA_REAVALIACAO, avaliação na fila de sync)

Resultado (somente leitura)
 └─ [Reavaliar] (só se NECESSITA_REAVALIACAO) → Formulário de Avaliação (mesmo registro)

Sincronização → [voltar] → Minhas Sessões

Perfil/Configurações → [Sair] → Login
```

---

## 3. Histórias de Usuário por Tela

**Splash:** O consultor abre o app e, sem precisar fazer nada, é levado diretamente para a lista de sessões se já tiver uma sessão válida salva — ou para o login, caso contrário.

**Login:** O consultor digita e-mail e senha e toca em "Entrar". Se as credenciais estiverem corretas, ele é autenticado e levado para a lista de sessões. Se estiver inativo ou errar a senha, vê uma mensagem clara do motivo.

**Minhas Sessões:** O consultor vê todos os treinamentos em que está escalado, com um resumo rápido de quantos participantes já avaliou em cada um. Ele toca em um treinamento para ver os participantes daquela sessão específica.

**Detalhe da Sessão:** O consultor vê todos os participantes daquele treinamento e o status de cada um. Ele toca em "Atribuir a mim" em um participante pendente para reservá-lo, e depois toca nele novamente para começar a avaliação. Participantes já avaliados por ele (ou por outro consultor) ficam visualmente diferenciados e não podem ser reatribuídos indevidamente. Quando o usuário logado também é admin e está com internet, ele ainda vê botões extras para corrigir a data/local/observações da sessão, adicionar um participante que faltou ser cadastrado, ou ajustar quais consultores estão escalados naquele treinamento — tudo direto do celular, sem precisar abrir o painel web.

**Formulário de Avaliação:** O consultor percorre cada categoria de avaliação e, para cada infração possível, marca se ela ocorreu e com qual gravidade (Básica, Média ou Grave). Ele pode fechar o app no meio da avaliação e retomar depois de onde parou, mesmo sem internet. Ao final, toca em "Finalizar avaliação".

**Resumo da Avaliação:** O consultor revê o resultado calculado (aprovado ou não, e o desempenho por categoria) antes de confirmar, podendo voltar ao checklist se perceber um erro.

**Assinatura do Participante:** O consultor entrega o celular ao participante (ou assina em nome dele conforme processo da empresa) para capturar a assinatura confirmando o resultado, finalizando a avaliação daquele participante.

**Resultado (somente leitura):** O consultor (ou outro consultor da mesma sessão) pode conferir o resultado de uma avaliação já concluída sem risco de alterá-la. Se o participante precisar de reavaliação, há um botão dedicado para reabrir o processo.

**Sincronização:** Assim que o celular do consultor pega sinal de internet novamente, o app já envia sozinho as avaliações pendentes em segundo plano, sem o consultor precisar fazer nada — nem existe um botão para isso. Essa tela serve só para ele conferir o que já foi enviado, o que ainda está pendente, e entender o motivo caso algum item tenha dado erro (ex.: conflito porque outro consultor já avaliou o mesmo participante).

**Perfil/Configurações:** O consultor confirma qual conta está usando e consegue sair do app com segurança.

---

## 4. Visão Arquitetural Inicial (MVVM + Repository Pattern)

### ViewModels (`ChangeNotifier`, um por tela/fluxo)

- `SplashViewModel` — decide a rota inicial (checa token + tenta refresh silencioso).
- `AuthViewModel` — login, tratamento de erro, estado de loading.
- `SessionsListViewModel` — lista de sessões do consultor, pull-to-refresh, contadores de progresso.
- `SessionDetailViewModel` — lista de participantes de uma sessão, ação de autoatribuição, filtros de status, e (se `role = ADMIN` e online) exposição das ações administrativas (abrir edição de sessão, adicionar participante, gerenciar consultores).
- `AdminSessionEditViewModel` — formulário de edição de data/cidade/estado/observações da sessão (só ADMIN, só online).
- `AdminAddParticipantViewModel` — busca de participante por CPF, cadastro de novo participante e vínculo à sessão (só ADMIN, só online).
- `AdminSessionConsultantsViewModel` — lista/adiciona/remove consultores vinculados à sessão (só ADMIN, só online).
- `EvaluationFormViewModel` — estado do checklist (categorias/infrações/notas selecionadas), autosave local, cronômetro, validações antes de finalizar.
- `EvaluationSummaryViewModel` — cálculo do score local (mirror do `scoring.ts` em Dart), montagem do resumo por categoria.
- `SignatureViewModel` — captura/validação da assinatura, persistência local da imagem.
- `EvaluationResultViewModel` — exibição somente leitura de uma avaliação já concluída, ação de reavaliar.
- `SyncViewModel` — expõe só leitura da fila de sincronização e status por item (sem ação de disparo manual); o disparo em si é automático, feito pelo `ConnectivityService`/`AssessmentRepository` assim que detecta conexão, e trata conflitos retornados pelo backend com retry automático (backoff) para itens com erro.
- `ProfileViewModel` — dados do usuário logado, logout.

### Repositories

- `AuthRepository` — login, refresh, logout, leitura de `/auth/me` (validando `role = CONSULTANT`), gestão do token em `flutter_secure_storage`. *(Precisa ser reescrito: hoje tem fallback mock que deve ser removido.)*
- `SessionRepository` — busca sessões vinculadas ao consultor via `GET /training-sessions` (já filtra automaticamente por `consultantId` do JWT — validado, não precisa de endpoint novo), com cache local em Drift para uso offline. Também expõe `updateSession()` (PATCH `/training-sessions/:id`, só ADMIN e só online) para os campos data/cidade/estado/observações.
- `ParticipantRepository` — busca `TrainingParticipant` de uma sessão, aplica autoatribuição (`POST /practical-assessments/assign`), atualiza cache local e trata conflitos (participante já atribuído a outro consultor). Também expõe, para ADMIN online, a busca de participante por CPF e o vínculo de um participante (novo ou existente) à sessão.
- `SessionConsultantsRepository` — para ADMIN online: lista consultores vinculados a uma sessão e salva a lista completa (adições/remoções aplicadas localmente) via `PATCH /training-sessions/:id` (`additionalConsultantsIds`), reaproveitando o replace total já existente no backend — sem endpoints granulares.
- `AssessmentCatalogRepository` — busca e cacheia localmente `AssessmentCategory` + `Infraction` + `InfractionNote` (catálogo estático, refresh periódico ou manual).
- `AssessmentRepository` — CRUD local do rascunho de `PracticalAssessment` + `AssessmentItem[]` (Drift), cálculo do score local, leitura de avaliação existente (`GET /practical-assessments/by-participant/:id`), envio via `POST /practical-assessments/sync`, e gestão da fila de sincronização (itens pendentes/erro/enviados).
- `SignatureRepository` — armazenamento local da imagem de assinatura e (futuramente, após criação do endpoint no backend) upload junto ao `sync`.
- `ConnectivityService` (não é bem um repository, mas um serviço transversal, deve ser inicializado no nível do app, não só dentro de uma tela) — expõe estado online/offline (`connectivity_plus`) e **dispara automaticamente** a sincronização da fila (`AssessmentRepository.syncPending()`) assim que detecta a transição offline → online, independente da tela em que o consultor esteja.

### Persistência local (Drift/SQLite)

Tabelas novas a substituir o placeholder atual (`EvaluationTable`):
- `SessionsTable`, `ParticipantsTable` (cache de leitura, refletindo o que veio da API)
- `AssessmentCategoriesTable`, `InfractionsTable`, `InfractionNotesTable` (catálogo)
- `LocalAssessmentTable` (rascunho da avaliação em andamento/concluída localmente, com campo `syncStatus`: `draft` / `pendingSync` / `synced` / `error`)
- `LocalAssessmentItemTable` (infrações marcadas em cada avaliação local)
- `LocalSignatureTable` ou apenas caminho de arquivo de imagem referenciado em `LocalAssessmentTable`

---

## 5. Gaps e Pendências Técnicas Identificadas (para tratar antes/durante a implementação)

1. **Assinatura do participante:** não existe campo/endpoint no backend hoje. Precisa de migration em `PracticalAssessment` (ex.: `participantSignatureUrl`) + endpoint de upload (Supabase Storage, seguindo o mesmo padrão de bucket usado para `signatureUrl` do consultor). **Único gap real pendente** (ver item 2 abaixo, já validado).
2. ~~Endpoint "minhas sessões" para consultor~~ — **validado em 11/09/2026: já existe.** `GET /training-sessions` (`training-sessions.controller.ts` + `.service.ts`) já filtra automaticamente por consultor logado via JWT, sem precisar de query param: `where: user.role === 'CONSULTANT' ? { consultants: { some: { consultantId: user.consultantId } } } : {}`. O app mobile só precisa chamar `GET /training-sessions?page=1&limit=20` com o token do consultor. `GET /training-sessions/:id` também já bloqueia acesso (`ForbiddenException`) se o consultor não estiver vinculado à sessão. Nenhum código novo é necessário aqui.
3. **Scaffold atual do mobile é só um placeholder:** login e "avaliação" genérica (slider 0-10) não refletem o domínio real e devem ser substituídos — não há reaproveitamento de lógica, só de estrutura de pastas/dependências já instaladas (Drift, Provider, go_router, dio, flutter_secure_storage já estão no `pubspec.yaml`).
4. **Mock/fallback no `AuthRepository` e `EvaluationRepository` atuais** precisam ser removidos para não mascarar erros reais de API em produção.
5. **Endpoints administrativos — validado em 11/09/2026:**
   - Editar sessão (1.4.1): `PATCH /training-sessions/:id` (`@Roles('ADMIN')`) já existe e cobre data/cidade/estado/observações — reaproveita o mesmo endpoint da web. **Nada a criar.**
   - Adicionar participante (1.4.2): `POST /training-sessions/:id/participants` (`apps/backend/src/participants/participants.controller.ts`, `@Roles(UserRole.ADMIN)`) já existe — recebe `cpf`, `name`, `email?`, `cnhCategory?`, `cnhExpiration?`, `participationType?`, cria o `Participant` se for novo e já vincula o `TrainingParticipant`. Também já existem `GET training-sessions/:id/participants` e `DELETE participants/:participantId`. **Nada a criar.**
   - Gerenciar consultores (1.4.3): **decidido: manter o replace total, sem criar endpoints novos.** O app mobile reaproveita `PATCH /training-sessions/:id` passando a lista completa de `additionalConsultantsIds` (`training-sessions.service.ts`, método `updateSession`, que faz `deleteMany` + `createMany` de todos os `SessionConsultant`). A tela 1.4.3 deve, portanto, sempre carregar a lista atual de consultores da sessão antes de editar, montar a lista completa (adicionando/removendo localmente) e enviar tudo de uma vez no `PATCH` — não há endpoint granular por consultor. **Nada a criar no backend.** Risco aceito: se dois admins editarem a lista de consultores da mesma sessão ao mesmo tempo (um pelo mobile, outro pela web), a última gravação sobrescreve a anterior.

---

*Próximo passo sugerido: decidir o formato exato da migration/endpoint de assinatura do participante (gap #1, o único que resta) antes de iniciar a implementação das telas.*

---

## 6. Diretrizes de UI/UX (Design Brief) — brainstorm de 12/09/2026

Definido antes de gerar o prompt para o Claude Design (Claude.ai) desenhar as telas de alta fidelidade.

### 6.1 Paleta de marca
O mobile reaproveita os design tokens já definidos para o web (`apps/web/src/app/globals.css`), extraídos do próprio logo SIM Treinamentos:
- `--teal` `#38BEC8` (primária) / `--teal-dark` `#2AA8B4` / `--teal-soft` `#EEF9FA`
- `--orange` `#F5A520` (CTA) / `--orange-dark` `#E09510` / `--orange-soft` `#FEF8EE`
- `--mauve` `#9B80A8` / `--mauve-soft` `#F5F0F8`
- `--charcoal` `#1E2A34` / `--charcoal-2` `#2A3A46`
- Neutros: `--bg` `#F8FAFC`, `--surface` `#FFFFFF`, `--border` `#E2E8F0`, `--text` `#0F172A`, `--text-2` `#475569`, `--text-muted` `#94A3B8`
- Tipografia: Inter (já é dependência via `google_fonts` no `pubspec.yaml`)

**Why:** mesma empresa, muitos admins usam web e mobile — identidade visual única entre as duas plataformas, sem fragmentar a marca.
**How to apply:** mapear esses tokens para os "color roles" do Material Design 3 (primary/secondary/tertiary/surface) na base do app mobile.

### 6.2 Paleta semântica de status/severidade (separada da marca)
Cor de marca (chrome do app, botões primários) e cor semântica de status/severidade são **paletas conceitualmente distintas**, mesmo que os tons se aproximem. Isso evita ambiguidade no checklist (ex: botão de ação laranja vs. indicador de infração grave também laranja).

Precisam de escala semântica própria:
- Status de `TrainingParticipant`: `PENDENTE` (cinza), `EM_AVALIACAO` (amarelo), `APROVADO` (verde), `NECESSITA_REAVALIACAO` (vermelho/laranja)
- Severidade de `InfractionNote`: `B` (leve), `PM` (média), `M` (grave) — precisa de 3 tons numa escala de severidade crescente
- Acessibilidade: nunca comunicar status/severidade só por cor — sempre acompanhar de ícone e/ou texto curto (daltonismo, legibilidade sob sol forte)

**Why:** decisão tomada para evitar que a cor de CTA/marca colida visualmente com a cor de aviso/erro no fluxo mais crítico do app (checklist de infrações).

### 6.3 Navegação: modelo híbrido (celular)
- **Nível superior (3 abas fixas):** Minhas Sessões / Sincronização / Perfil — sempre acessíveis, navegação livre entre elas a qualquer momento.
- **Fluxo de avaliação (imersivo, sem abas):** ao entrar em uma sessão específica (Detalhe da Sessão → Formulário de Avaliação → Resumo → Assinatura), a barra de navegação desaparece e vira uma pilha simples (stack) com botão voltar — o consultor está "dentro" de uma tarefa focada, não navegando entre seções.

**Why:** dá liberdade de navegação entre as áreas paralelas do app, sem comprometer o espaço de tela e o foco durante o preenchimento do checklist (a tela mais densa do app).

### 6.4 Estilo visual da navbar
Barra de navegação em formato **pill/flutuante arredondado** (tendência atual, ex: Netflix, WhatsApp iOS) em vez da `NavigationBar` padrão engessada do Material 3.
**Decisão de opacidade/blur deixada a critério do Claude Design:** avaliar entre fundo sólido/opaco (mais contraste, melhor para uso em campo sob sol forte) vs. efeito glassmorphism/blur (mais alinhado à tendência visual, risco de contraste reduzido) — o prompt final pede para ele decidir e justificar com base no contexto de uso outdoor.

### 6.5 Fidelidade
Alta fidelidade completa: cores, tipografia e componentes reais (chips de status, checklist, assinatura, navbar flutuante) prontos para servir de referência direta na implementação Flutter — não wireframes.

### 6.6 Considerações gerais de UX já incorporadas ao brief
- Plataforma-base: Material Design 3 (Android nativo, ver [[simtc-mobile-app-strategy]])
- Contexto de uso: campo, sol forte, uma mão ocupada — contraste alto, alvos de toque grandes (mín. 48dp), sem depender só de cor para status crítico
- Diferenciação ADMIN × CONSULTANT: mesmas telas, affordances extras aparecem só para admin (progressive disclosure), sem tela/tema separado — indicador discreto de "modo admin" no perfil
- Skeleton screens no lugar de spinners genéricos ao carregar listas/dados (melhora performance percebida)
- Tipografia dinâmica: layout não pode quebrar se o usuário aumentar a fonte do sistema (acessibilidade, baixa visão)

### 6.7 Suporte a tablet (decidido em 12/09/2026)

O app também será usado em tablet, não só celular — isso muda a arquitetura de layout, não é só "esticar" o design do celular. Decisões:

- **Estratégia geral:** adaptação real por breakpoint, seguindo o sistema oficial de "adaptive layouts" do Material Design 3 (compact <600dp = celular, medium 600–839dp, expanded ≥840dp = tablet). Uma única base de design/código que se reorganiza sozinha conforme a largura da tela — não duas versões separadas de app. Em Flutter, isso mapeia diretamente para o pacote `flutter_adaptive_scaffold` (mantido pelo próprio time do Flutter/Material).
- **Master-detail (split view):** aplicado apenas à dupla **Minhas Sessões + Detalhe da Sessão** — no tablet, a lista de treinamentos fica numa coluna à esquerda e os participantes daquele treinamento aparecem à direita, sem trocar de tela (padrão Gmail/Configurações). O fluxo de avaliação em si (Formulário de Avaliação, Resumo, Assinatura) **permanece em tela cheia mesmo no tablet** — não vira master-detail, para preservar o foco durante o preenchimento do checklist.
- **Navegação no tablet:** a mesma pill flutuante arredondada decidida para o celular (seção 6.4), só que **reposicionada verticalmente na lateral** da tela — mantém a identidade visual entre celular e tablet, e ao mesmo tempo respeita a ergonomia de "toque lateral" (o usuário segura o tablet pelas bordas, diferente do polegar central do celular).
- **Orientação:** o celular permanece fixo em retrato; o **tablet suporta retrato e paisagem**, com os layouts (inclusive o master-detail) se adaptando a cada orientação — reflete o uso real de tablet (na mão vs. apoiado numa mesa/suporte durante o treinamento).
- **Telas administrativas em tablet (1.4.1, 1.4.2, 1.4.3):** no tablet, abrem como diálogo/popover flutuante ancorado (mantendo o contexto da tela de fundo visível), em vez de ocupar a tela inteira como acontece no celular.
- **Fora de escopo por ora:** hover states de mouse/trackpad e otimização para leitura em colunas longas — não se aplicam ao contexto de uso (tablets Android de campo, textos curtos no domínio).

**Why:** tratar tablet como "celular gigante" (só esticando o layout) desperdiça o espaço extra e ignora a ergonomia real de uso em duas mãos/apoiado numa mesa — o padrão adaptive do Material 3 já resolve isso de forma testada e com suporte nativo no Flutter.
**How to apply:** o prompt para o Claude Design deve pedir explicitamente as três larguras (compact/medium/expanded) para as telas afetadas (Minhas Sessões, Detalhe da Sessão, e a navbar), com a navegação e o split view se adaptando conforme descrito acima.
