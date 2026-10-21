# Fase 0 — Auditoria do scaffold e dos contratos do backend

**Data:** 17/09/2026 · **Plano:** `apps/mobile/docs/superpowers/plans/2026-09-17-mobile-fase-0-preparacao.md`

Leitura obrigatória antes de planejar as Fases 1 a 8. Tudo aqui foi conferido no código, não em documentação.

## 1. Scaffold `apps/mobile/simtc`

Estado registrado na Fase 0: Flutter 3.41.6 / Dart 3.11.4, `flutter analyze` sem issues e `flutter test` com 1 smoke test. O app abre um login **mock** e telas genéricas de "dashboard" e "avaliação"; nada disso reflete o domínio real.

### 1.1 O que a Fase 1 descarta ou reescreve

| Arquivo | Problema encontrado | Destino |
|---|---|---|
| `lib/utils/app_colors.dart` | Paleta errada (`#00569E`, `#00A859`…) | Substituído pelos tokens do Design System |
| `lib/utils/api_constants.dart` | `baseUrl` é `https://api.simtc.com.br/v1`, mas a API real usa o prefixo `/api`; os endpoints `/evaluations` e `/evaluations/sync` não existem | Reescrito com os endpoints reais e `baseUrl` por ambiente |
| `lib/data/services/api/api_service.dart` | Só tem GET e POST; guarda o token num header mutável; não faz refresh em `401` | Reescrito como cliente `dio` com interceptors (auth + refresh) |
| `lib/data/repositories/auth_repository.dart` | Tem fallback mock: qualquer e-mail com senha de 4+ caracteres "loga". `isLoggedIn()` inventa um usuário se houver qualquer token salvo, e o login espera um campo `token` que a API não devolve | Reescrito sem mock |
| `lib/data/models/user_model.dart` | Espera `{ id, name, email, token }`, mas o login real devolve `{ accessToken, refreshToken }` e `/auth/me` devolve `{ id, name, email, role }` | Reescrito |
| `lib/data/repositories/evaluation_repository.dart` | Lista mock em memória; `saveEvaluation` devolve sucesso mesmo quando a API falha | Removido |
| `lib/data/models/evaluation_model.dart` | Domínio genérico (título e nota de 0 a 10) que não existe no backend | Removido |
| `lib/data/services/local/app_database.dart` (+ `.g.dart`) | Só a tabela placeholder `EvaluationTable`, com `schemaVersion` 1 e banco `simtc_app_db` | Esquema reescrito (ver 1.3) |
| `lib/ui/auth/login_screen.dart`, `login_viewmodel.dart` | Login mock, mensagem de erro genérica, e o ViewModel aplica `trim()` na **senha** | Reescritos com o DS, sem `trim()` na senha |
| `lib/ui/dashboard/*` | Lista de avaliações mock | Removidos (substituídos por "Minhas Sessões" na Fase 2) |
| `lib/ui/evaluation/*` | Formulário genérico com slider de 0 a 10 | Removidos (o checklist real entra na Fase 4) |
| `lib/ui/core/widgets/custom_button.dart`, `custom_text_field.dart` | Estilos próprios sobre a paleta errada | Substituídos pelos componentes do DS |
| `lib/router.dart` | Rotas `/login`, `/dashboard` e `/evaluation`, sem redirecionamento por autenticação | Reescrito |
| `lib/app.dart` | Providers dos placeholders e `ColorScheme.fromSeed` com a paleta errada | Reescrito (`MultiProvider` com serviços globais + tema do DS) |
| `test/widget_test.dart` | Smoke test do app placeholder | Reescrito |

### 1.2 O que se reaproveita

| Item | Observação |
|---|---|
| `pubspec.yaml` | As dependências estão certas: `provider` 6.1.5, `go_router` 14.8.1, `dio` 5.11.1, `drift`/`drift_dev` 2.31.0, `drift_flutter` 0.2.8, `flutter_secure_storage` 9.2.4, `google_fonts` 6.3.3, `flutter_svg` 2.3.0, `cached_network_image` 3.4.1, `connectivity_plus` 6.1.5, `uuid` 4.6.0, `intl` 0.19.0, `json_annotation`/`json_serializable` e `build_runner` (versões resolvidas no `pubspec.lock`) |
| `lib/utils/result.dart` | `Result<T>` selado (`Success`/`Failure`), usado por todos os repositories novos |
| `lib/main.dart` | Hoje só chama `runApp`; será estendido para inicializar o banco e os serviços |
| Estrutura `lib/data/{models,repositories,services}` + `lib/ui/<feature>/` + `lib/ui/core/` | Mantida (é o padrão da arquitetura recomendada pelo Flutter); o DS entra em `lib/ui/core/` |
| `assets/images/logo-simtc.png` | Logo real (37 KB) |
| `android/` | Template do Flutter 3.41 (AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14) |

Pacotes a decidir em cada fase:
- mocks para os testes (Fase 1);
- ~~captura de assinatura, por pacote ou `CustomPainter` (Fase 5)~~ — não se aplica mais: mudou em 20/09/2026, a assinatura passou a ser capturada no formulário web de inscrição, não no app (ver `brainstorm-app-mobile.md` seção 0 item 4);
- `flutter_adaptive_scaffold`: conferir se continua mantido antes de adotar (Fase 7);
- versão do app na tela de Perfil (Fase 8).

O `pdfx` está no `pubspec.yaml`, mas nenhuma tela prevista o usa; avaliar a remoção na Fase 1.

### 1.3 Ajustes de plataforma e ambiente

- **Plataformas:** `ios/`, `linux/`, `macos/`, `web/` e `windows/` foram removidas na Fase 0 (o app é só Android). Para recriar alguma: `flutter create --platforms=<plataforma> .`
- **Permissão `INTERNET` no manifest principal:** `android/app/src/main/AndroidManifest.xml` não declara `android.permission.INTERNET`; só os manifests de debug e de profile declaram. Como o release usa o manifest principal, um APK release não acessaria a API. Corrigir na Fase 1.
- **Identidade do app:** `applicationId`/`namespace` são `com.example.simtc` e `android:label` é `"simtc"`. Definir o id definitivo antes de distribuir o primeiro APK, porque trocar depois instala um segundo app no aparelho.
- **Assinatura do release:** `build.gradle.kts` assina o release com a chave de debug. Criar uma keystore própria antes da distribuição (Fase 8).
- **Fonte offline:** o `google_fonts` baixa a Inter em tempo de execução. Para o app abrir com a fonte certa sem internet, embutir os arquivos da Inter como asset e desligar o download (`GoogleFonts.config.allowRuntimeFetching = false`). Fase 1.
- **Banco local antigo nos aparelhos de teste:** o placeholder cria o banco `simtc_app_db` com `schemaVersion` 1. Se a Fase 1 mantiver o mesmo nome e a mesma versão, o Drift abre o arquivo antigo e não cria as tabelas novas. Desinstalar o app placeholder dos aparelhos antes de testar a Fase 1, ou usar outro nome de banco.
- **HTTP em desenvolvimento:** o app de dev fala com o backend local em `http://localhost:3001/api` via `adb reverse` (ver `apps/mobile/simtc/README.md`). Se o Android recusar a chamada HTTP por política de cleartext, liberar cleartext **só** em `android/app/src/debug/AndroidManifest.xml` (Fase 1).
- **URL de produção da API:** não está no repositório (o CI da `main` faz deploy no Railway, e os commits recentes citam uma VPS com Docker). Confirmar com o usuário a URL HTTPS de produção na Fase 1.

## 2. Contratos do backend — achados

### 2.1 Resolvidos na Fase 0

- `PracticalAssessment.participantSignatureUrl`, com o path do arquivo no bucket privado `signatures`, sob o prefixo `participants/`.
- `PATCH /api/practical-assessments/:id/participant-signature` (multipart, campo `file`, PNG/JPEG com menos de 2 MB) e `GET /api/practical-assessments/:id/participant-signature-url` → `{ signedUrl }`, válida por 1 h. Só ADMIN e CONSULTANT têm acesso.
- `POST /api/practical-assessments/sync` passa a devolver `assessmentId` em cada item com `status: 'fulfilled'`.

**Nota de 03/10/2026:** os três itens acima deixaram de existir — a coluna `participantSignatureUrl`, as rotas `participant-signature*` e o `assessmentId` da resposta do `POST /practical-assessments/sync` foram removidos junto com a assinatura do participante, commitados na Fase 5B (`3b4a98f`).

### 2.2 Pendências por fase (não resolvidas na Fase 0)

| Fase | Achado no código | Impacto no app |
|---|---|---|
| 1 | Login de consultor inativo devolve o mesmo `401 "Credenciais inválidas"` da senha errada (`auth.service.ts`) | A mensagem específica de "consultor inativo" prevista na tela 1.2 depende de mudança no backend. Decidir na Fase 1 |
| 1 | `GET /auth/me` devolve só `{ id, name, email, role }`, sem `consultantId` | O app lê o `consultantId` do payload do access token (o campo está no JWT) para saber quem é "eu" nas atribuições |
| 1 | `POST /auth/refresh` (body `{ refreshToken }`) devolve um par novo `{ accessToken, refreshToken }` | O interceptor precisa salvar os dois tokens |
| 2 | `GET /training-sessions` inclui só `company { id, name }`, `course { id, name }` e `responsibleConsultant { id, name }`, sem `company.logoUrl` nem contagem de participantes por status, e ordena por `createdAt desc` | Só com a listagem não dá para montar o card da Home (logo + "X de Y avaliados"). Opções: ampliar o `include`/`_count` no backend ou buscar o detalhe de cada sessão. Decidir na Fase 2 |
| 2 | Para `role = ADMIN`, `GET /training-sessions` devolve **todas** as sessões | "Minhas Sessões" de um admin listaria tudo. Decidir o comportamento na Fase 2 |
| 2 | `Company.logoUrl` guarda uma URL pública (o bucket `logos` é público) | O `cached_network_image` carrega direto, sem token |
| 3 | `GET /training-sessions/:id` traz `participants[]` com `participant`, `assessment`, `certificate` e `assignedConsultant { id, name }`, e bloqueia consultor não vinculado. Já `GET /training-sessions/:id/participants` traz só `participant` + `assessment` e não confere o vínculo | Usar o detalhe da sessão na tela 1.4 |
| 3 | O web trata `EM_AVALIACAO` com avaliação anterior como "reavaliação em andamento" (`getDisplayStatus`, commit `bd4d1a5`) | Espelhar no app para não esconder o fluxo |
| 3 | `POST /practical-assessments/assign` responde `409` com "Participantes aprovados não podem ser reavaliados" ou "Um ou mais participantes já estão em avaliação com outro consultor" | Mostrar a mensagem sem quebrar a lista |
| 3 | O seed (`prisma/seed.ts`) já cria infrações e notas por categoria (`INFRACTIONS_BY_CATEGORY`); a observação contrária no `apps/backend/CLAUDE.md` estava desatualizada | O catálogo está disponível para testar as Fases 3 e 4 |
| 4 | O score usa o `deduction` de cada `InfractionNote` vindo do banco, normalizado por `MAX_NOTE_WEIGHT = 5`, e a média geral considera **todas** as categorias do catálogo (categoria sem infração marcada = 100%); ver `applyScore()` | O port Dart recebe o `deduction` e o total de infrações por categoria a partir do cache local |
| 5 | O `sync` **não valida** o `assignedConsultantId` (bug já listado no `apps/backend/CLAUDE.md`; corrigido na 6B, ver a nota de 10/10/2026 abaixo) e sempre zera esse campo depois do sucesso | "Reavaliar" continua chamando `assign` antes, para reservar o participante, mas o `sync` não falha por conflito de atribuição. Reenviar o mesmo item atualiza o mesmo registro |
| 5 | O `sync` responde `201` mesmo com itens rejeitados; cada item traz `status` (`fulfilled`/`rejected`) e `error` | A fila do app trata o resultado item a item, não pelo status HTTP |
| 5 | `GET /practical-assessments/:id` usa `findUniqueOrThrow`, então um id inexistente vira `500` | Tratar como erro genérico |
| 5 | O upload valida `file.mimetype`, e o `dio` manda `application/octet-stream` por padrão | Enviar o `MultipartFile` com `contentType` `image/png` |
| 6 | Não existe busca de participante por CPF. `POST /training-sessions/:id/participants` deduplica por CPF e **sobrescreve** o `name` do cadastro existente (e também `email`/`cnh*`, quando enviados) | A tela 1.4.2 ("buscar por CPF → confirmar dados") não sai só com os endpoints atuais. Decidir na Fase 6 |
| 6 | `PATCH /training-sessions/:id` e `POST /training-sessions/:id/participants` recusam sessões `CONCLUIDO`/`CANCELADO` | Desabilitar as ações admin nesses status |
| 6 | Quando recebe `additionalConsultantsIds`, o `updateSession` recria os vínculos e sempre inclui de novo o consultor responsável | A tela 1.4.3 não precisa enviar o responsável na lista |
| 6 | `GET /consultants?active=true` (ADMIN e CONSULTANT) lista os consultores ativos | É a fonte da busca "Adicionar consultor" |

**Nota de 07/10/2026:** a Fase 6A criou a consulta de participante por CPF que faltava: `POST /api/training-sessions/:id/participants/lookup` (só ADMIN; corpo `{ cpf }` → `{ registered, name, email, enrolled }`). O `POST /training-sessions/:id/participants` continua como descrito acima: deduplica por CPF e sobrescreve o `name` do cadastro.

**Nota de 10/10/2026:** a Fase 6B mudou três pontos do backend. (1) Entraram `POST /api/training-sessions/:id/consultants` (corpo `{ consultantId }`) e `DELETE /api/training-sessions/:id/consultants/:consultantId`, só ADMIN: um consultor por chamada, e as duas devolvem `{ responsibleConsultantId, consultants }`. O `PATCH /training-sessions/:id` com `additionalConsultantsIds` continua como descrito acima. Tirar um consultor da sessão — pela rota nova ou pelo `PATCH` — libera quem estava em avaliação com ele: o participante fica sem consultor e volta para `PENDENTE`, ou para o status da nota anterior, numa reavaliação. (2) O `POST /practical-assessments/unassign` aceita que um ADMIN libere o participante de qualquer consultor. (3) O `sync` passou a conferir a atribuição — a primeira linha "5" acima deixou de valer: a avaliação de um participante que não está em avaliação com quem envia é recusada, e o item rejeitado ganha `code: 'NOT_ASSIGNED'`; reenviar a mesma avaliação (mesmo consultor e mesma hora de início) continua sendo aceito, sem regravar. O painel web ainda não lê o resultado item a item (pendência "Web" do plano da 6B).

### 2.3 Testes do backend

Em 17/09/2026, `npx jest` em `apps/backend` já tinha 12 falhas pré-existentes: `test/auth.service.spec.ts` espera `sendOtpCode` com 2 argumentos, e `test/participants.service.spec.ts` não tem o mock de `EmailService`. Qualquer fase que mexa no backend deve manter esse número, sem criar falhas novas.
