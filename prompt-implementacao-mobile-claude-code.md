<papel>
Você é um agente de desenvolvimento Flutter sênior, atuando dentro deste monorepo (SIMTC — SIM Treinamentos). Você vai usar o plugin **superpowers** (SDD — Spec-Driven Development) já instalado e usado neste mesmo repositório (veja `.superpowers/sdd/` e o exemplo real de plano em `apps/web/docs/superpowers/plans/2026-08-02-frontend-backend-integration.md`, que implementou a integração frontend-backend do painel web). Siga o mesmo padrão de disciplina: Plano → Task → Brief → Report → Progress ledger → Review final, com commit por task.
</papel>

<objetivo>
Implementar o app mobile Flutter do SIMTC (`apps/mobile/simtc/`) do zero funcional até um app **completo, integrado de verdade com a API real** (não mockado), cobrindo todas as telas já mapeadas e desenhadas, seguindo arquitetura MVVM, um Design System (DS) próprio reaproveitável, e a convenção de composição de tela em "quebra-cabeça" (métodos `_buildX()` privados combinados em um `build()` único).

A implementação deve ser dividida em **fases sequenciais testáveis** — cada fase termina em um app que roda de verdade num **dispositivo Android físico** (USB ou depuração Wi-Fi — não emulador) e agrega valor tangível sobre a fase anterior. Não avance para a fase seguinte sem que a fase atual tenha sido validada manualmente no aparelho.
</objetivo>

<leia_primeiro>
Antes de gerar qualquer plano ou escrever qualquer código, leia estes arquivos por completo, nesta ordem — eles são a fonte de verdade e este prompt é só um resumo executivo:

1. `brainstorm-app-mobile.md` (raiz do repo) — mapeamento completo de todas as telas, fluxo de navegação, histórias de usuário, arquitetura MVVM/Repository, tabelas Drift, e as diretrizes de UI/UX (seção 6) que já foram usadas para gerar os mockups de alta fidelidade.
2. `prompt-claude-design-mobile.md` (raiz do repo) — o prompt de design já usado no Claude Design, com o Design System definitivo (cores em hex reais de produção, tipografia, componentes, navegação, adaptação para tablet). **As telas de alta fidelidade já foram geradas a partir deste prompt** — se houver um link/export do Claude Design disponível no projeto (ex: `SIMTC Mobile.dc.html`), use-o como referência visual pixel-a-pixel; se não estiver disponível no seu ambiente, implemente fielmente a partir das especificações escritas neste arquivo.
3. `brainstorm-implementacao-mobile.md` (raiz do repo) — o plano de fases já definido (0 a 8), com o que cada fase entrega, quais ViewModels/Repositories/tabelas Drift envolve, quais endpoints reais consome, e o critério de "pronto para testar". **Este é o roteiro que você deve seguir e detalhar em tasks.**
4. `apps/web/docs/superpowers/plans/2026-08-02-frontend-backend-integration.md` — use como **template estrutural** de como escrever um plano SDD neste repositório (cabeçalho com Goal/Architecture/Tech Stack, Global Constraints, Mapa de Arquivos, tasks com Files/Interfaces/Steps com código real/Testar/Commit). Adapte o mesmo rigor para Flutter/Dart em vez de Next.js/NestJS.
5. `apps/backend/prisma/schema.prisma` — schema real do banco (não invente campos). Modelos relevantes: `TrainingSession`, `SessionConsultant`, `TrainingParticipant`, `PracticalAssessment`, `AssessmentItem`, `AssessmentCategory`, `Infraction`, `InfractionNote`, `Consultant`, `Company`, `Participant`, e os enums `TrainingStatus`, `ParticipationType`, `ParticipantStatus`, `NoteType`, `UserRole`.
6. Os controllers/services reais do backend que o app vai consumir (não assuma contratos — leia o código): `apps/backend/src/auth/`, `apps/backend/src/training-sessions/`, `apps/backend/src/participants/`, `apps/backend/src/practical-assessments/`, `apps/backend/src/assessment-categories/`, `apps/backend/src/storage/storage.service.ts`, `apps/backend/src/consultants/` (referência do padrão de upload de assinatura), e `packages/shared-types/src/` (DTOs e `scoring.ts` — o algoritmo de pontuação, que precisa ser portado 1:1 para Dart).
</leia_primeiro>

<estado_atual_do_scaffold>
`apps/mobile/simtc/` já existe como projeto Flutter, mas é **inteiramente placeholder** e deve ser substituído tela por tela: login mock sem API real, tela de "avaliação" genérica com slider 0-10 (não reflete o domínio real de categorias/infrações/notas B-PM-M), paleta de cores errada (`#00569E`, não é a marca real da SIM Treinamentos), `api_constants.dart` apontando para endpoints que não existem (`/evaluations`, `/evaluations/sync`). Reaproveite apenas: a estrutura de pastas, o `pubspec.yaml` (dependências já corretas: `provider`, `go_router`, `dio`, `drift`/`drift_flutter`, `flutter_secure_storage`, `google_fonts`, `flutter_svg`, `cached_network_image`, `connectivity_plus`, `uuid`, `pdfx`, `json_annotation`/`json_serializable`), e o esqueleto do `app_database.dart` (Drift) como ponto de partida a ser expandido. Tudo o que é lógica de negócio, autenticação e telas deve ser reescrito.
</estado_atual_do_scaffold>

<restricoes_globais>
Aplique estas restrições em **todas as fases e todos os arquivos novos**, sem exceção:

**Arquitetura MVVM + Repository:**
- Um `ChangeNotifier` (ViewModel) por tela/fluxo, injetado via `provider`. Nenhuma tela chama `Dio`/Drift diretamente — sempre via Repository.
- Um Repository por domínio (Auth, Session, Participant, AssessmentCatalog, Assessment, Signature, SessionConsultants), retornando o tipo `Result<T>` já existente em `utils/result.dart` (reaproveitar, não recriar).
- `ConnectivityService` é um serviço transversal inicializado uma única vez no nível do app (em `main.dart`/`app.dart` via `MultiProvider`), nunca instanciado dentro de uma tela — ele deve notificar/disparar sincronização mesmo com o app em qualquer tela.

**Convenção de composição "quebra-cabeça" (obrigatória):**
- Toda `Screen`/`View`/`Widget` de tela deve decompor sua UI em métodos privados nomeados por responsabilidade — ex: `Widget _buildHeader()`, `Widget _buildSessionList()`, `Widget _buildEmptyState()`, `Widget _buildStatusChip(...)` — todos combinados dentro de um único `Widget build(BuildContext context)` enxuto e legível. Não são aceitas árvores de widgets profundas e não decompostas direto no `build()`.

**Design System (DS), criado na Fase 1 e nunca contornado depois:**
- Arquivo de cores com os tokens reais de produção (não os tokens desatualizados do CSS web): primária `#1D9AA4` (hover `#167F8A`, escuro `#0A6E80`, fundo suave `#EEF9FA`), CTA laranja `#F5A520` (hover `#E09510`, suave `#FEF8EE`), roxo/mauve `#9B80A8` (suave `#F5F0F8`), charcoal `#1E2A34`/`#2A3A46`, neutros `#F8FAFC`/`#FFFFFF`/`#E2E8F0`/`#0F172A`/`#475569`/`#94A3B8`.
- Paleta semântica **separada** da paleta de marca: severidade B/PM/M idêntica ao painel web em produção — B verde (`#DCFCE7`/`#16A34A`), PM âmbar (`#FEF9C3`/`#CA8A04`), M vermelho (`#FEE2E2`/`#DC2626`) — não inventar uma escala nova. Status de participante (PENDENTE cinza, EM_AVALIACAO amarelo, APROVADO verde, NECESSITA_REAVALIACAO vermelho/laranja escuro) nunca reutiliza o laranja de marca/CTA.
- Nenhum status/severidade comunicado só por cor — sempre ícone e/ou texto curto junto.
- Escala de espaçamento nomeada (constantes, não números soltos), escala tipográfica sobre `google_fonts` Inter com suporte a tipografia dinâmica (`MediaQuery.textScaler`), `ThemeData` Material 3 único mapeando os tokens para `ColorScheme`.
- **Granularidade de arquivo — siga o padrão já existente em `lib/ui/auth/login_screen.dart`:** não crie um arquivo por widget por padrão. Um widget só vira arquivo próprio em `lib/ui/core/widgets/` quando for genuinamente reutilizável em várias telas (ex: os já existentes `custom_button.dart`/`custom_text_field.dart`) ou grande/complexo o suficiente para prejudicar a leitura se ficasse embutido na tela. Widgets pequenos e específicos de uma única tela continuam como métodos privados `_buildX()` dentro do arquivo da própria tela — é exatamente assim que `login_screen.dart` já organiza `_buildHeader()`, `_buildFormFields()`, `_buildErrorMessage()`, `_buildSubmitButton()`, sem nenhum deles virar arquivo separado. Aplique esse mesmo critério ao decidir o que vira componente do DS versus o que fica local à tela.
- Componentes-base reutilizáveis e "burros" (sem lógica de negócio), que se qualificam para arquivo próprio por serem usados em múltiplas telas: chip de status, badge de severidade, card de sessão, navbar pill flutuante, botões primário/secundário, campo de texto, banner de conectividade, item de skeleton de carregamento. Nenhuma tela cria estilo inline duplicado depois que o componente existir.
- Rótulos de severidade permanecem literalmente **"B"**, **"PM"**, **"M"** na UI — nunca expandir para "Bom"/"Pode Melhorar"/"Melhorar" (isso só existe em comentário de código, nunca visível ao usuário), consistente com o padrão já em produção no web.

**Offline-first (obrigatório no fluxo de avaliação, não no admin):**
- O fluxo de avaliação (atribuição já feita → checklist → resumo → assinatura) deve funcionar 100% sem conexão, com autosave local via Drift a cada alteração.
- Sincronização é **automática**, nunca por botão manual: o `ConnectivityService` dispara o envio da fila assim que detecta a transição offline→online, de qualquer tela.
- Ações administrativas (editar sessão, adicionar participante, gerenciar consultores) **exigem conexão** — ficam visíveis porém desabilitadas com mensagem explicativa quando offline, nunca escondidas sem aviso.

**Scoring:**
- Portar `calculateCategoryScore`, `calculateOverallScore`, `getApprovalStatus` de `packages/shared-types/src/scoring.ts` para Dart **byte a byte na lógica** (B=1, PM=3, M=5, normalizado pelo peso máximo 5; categoria sem infração marcada = 100%; aprovação com corte ≥70%). Escrever testes unitários Dart comparando contra casos conhecidos da implementação TypeScript.

**Contratos de API reais (não invente campos nem endpoints):**
- `POST /auth/login` → `{ email, password }`, `GET /auth/me` → `{ id, name, email, role }` (validar `role` ∈ {`CONSULTANT`,`ADMIN`}, bloquear qualquer outro), `POST /auth/refresh`, `POST /auth/logout`.
- `GET /training-sessions?page=&limit=` — já filtra automaticamente por consultor logado via JWT (backend, `training-sessions.service.ts`, método `findAll`) — não enviar `consultantId` como parâmetro. `GET /training-sessions/:id` já bloqueia acesso de consultor não vinculado.
- `GET training-sessions/:id/participants`, `POST training-sessions/:id/participants` (ADMIN, `AddParticipantDto`: `{ cpf, name, email?, cnhCategory?, cnhExpiration?, participationType? }`), `DELETE participants/:participantId` (ADMIN).
- `PATCH /training-sessions/:id` (ADMIN) — cobre edição de data/cidade/estado/observações **e** o replace total de `additionalConsultantsIds` (a tela de gerenciar consultores deve sempre carregar a lista atual, aplicar adições/remoções localmente, e enviar a lista completa de uma vez — não existe endpoint granular por consultor).
- `POST /practical-assessments/assign` — `AssignParticipantsDto { participantIds: string[] }`. **Atenção:** o backend bloqueia reatribuir participantes `APROVADO`, e bloqueia "roubar" um participante `EM_AVALIACAO` de outro consultor — trate esses erros com mensagem clara, sem quebrar a tela.
- `POST /practical-assessments/sync` — recebe **array** de `SyncPracticalAssessmentDto { trainingParticipantId, consultantId?, date, startTime, endTime?, items: [{ infractionNoteId }] }` (não enviar `consultantId` no mobile — o backend usa o do JWT). **Atenção crítica:** ao processar o sync com sucesso, o backend sempre reseta `assignedConsultantId: null` no participante (`applyScore()` em `practical-assessments.service.ts`) — ou seja, depois de sincronizado, o participante deixa de estar "atribuído" a quem o avaliou. Por isso, o botão "Reavaliar" (tela de Resultado, só visível se `NECESSITA_REAVALIACAO`) deve **chamar `POST /practical-assessments/assign` novamente antes de reabrir o checklist**, senão o próximo `sync` pode falhar por conflito de atribuição.
- `GET /practical-assessments/by-participant/:trainingParticipantId` (retorna avaliação existente ou null), `GET /practical-assessments/:id`.
- `GET /assessment-categories` — catálogo completo (categorias + infrações + notas), praticamente estático, cachear localmente com refresh periódico/manual, não a cada avaliação.
- **Novos endpoints da Fase 0** (a serem criados por você, seguindo exatamente o padrão de `consultants.controller.ts`/`consultants.service.ts` + `StorageService`): `PATCH /practical-assessments/:id/participant-signature` (upload multipart, bucket Supabase `participant-signatures`, delete-then-upload com path novo por envio) e `GET /practical-assessments/:id/participant-signature-url` (signed URL). Antes disso, adicionar migration Prisma em `PracticalAssessment` para o campo `participantSignatureUrl String?`.

**Convenções de commit e organização:**
- Commits em português ou inglês (siga o padrão predominante já usado no histórico do repo — verifique com `git log` antes de decidir), formato `tipo(escopo): mensagem`, um commit por task concluída e verificada.
- Nunca avance para a próxima task/fase com testes falhando ou build quebrado.
</restricoes_globais>

<processo_de_trabalho>
1. Leia todos os arquivos listados em `<leia_primeiro>`.
2. Use a sub-skill do superpowers apropriada (`superpowers:executing-plans` ou `superpowers:subagent-driven-development`, conforme sua disponibilidade neste ambiente) para transformar **cada fase** de `brainstorm-implementacao-mobile.md` (Fase 0 a Fase 8) em um documento de plano SDD próprio, salvo em `apps/mobile/docs/superpowers/plans/`, no mesmo formato estrutural de `apps/web/docs/superpowers/plans/2026-08-02-frontend-backend-integration.md`: cabeçalho com Goal/Architecture/Tech Stack, seção "Global Constraints" (reaproveitando as restrições listadas acima), "Mapa de Arquivos" (novos/modificados/deletados), e tasks numeradas com **Files**, **Interfaces** (Produces/Consumes), passos `- [ ]` com código real completo (não pseudocódigo), passo de "Testar" com instruções manuais precisas para validar no dispositivo físico, e passo de "Commit" com o comando git exato.
3. Gere o plano de uma fase por vez, começando pela Fase 0 — não gere1os de uma vez sem antes confirmar que o formato e o nível de detalhe estão corretos na primeira fase.
4. Depois de gerado e aprovado o plano da fase, execute-o task por task, seguindo rigorosamente o fluxo Task→Brief→Report→Progress ledger já estabelecido neste repositório (veja `.superpowers/sdd/2026-08-02-frontend-backend-integration/` como referência de formato de brief/report/progress).
5. Ao final de cada fase, pare e aguarde validação manual no dispositivo físico (USB ou Wi-Fi debug) antes de iniciar o plano da fase seguinte — o critério de "pronto para testar" de cada fase está descrito em `brainstorm-implementacao-mobile.md`.
6. Se encontrar qualquer ambiguidade de regra de negócio não coberta pelos documentos lidos (ex: um comportamento de edge case não antecipado), **pare e pergunte** em vez de assumir — este projeto tem histórico de decisões tomadas via pergunta direta ao usuário, não por suposição.
</processo_de_trabalho>

<fora_de_escopo>
- iOS (o app é Android-only, distribuído via APK sideload — sem Play Store).
- Dashboards, relatórios gerenciais, telas de gestão de empresas/cursos/consultores fora das 3 ações administrativas inline já mapeadas (isso permanece exclusivo do painel web).
- Fluxo OTP de login (exclusivo do portal do cliente/web, não existe no mobile).
- Captura de fotos/evidências na avaliação (só assinatura do participante).
- Qualquer campo ou endpoint que você não tenha confirmado existir lendo o código real do backend — se precisar de algo que não existe, sinalize como pendência em vez de inventar.
</fora_de_escopo>
