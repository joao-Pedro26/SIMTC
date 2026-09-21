# App Mobile SIMTC — Fase 2: Minhas Sessões (Home) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar a `HomePlaceholderScreen` pela tela 1.3 "Minhas sessões" de verdade: a lista real de treinamentos do consultor, cacheada no Drift, com filtros por data, progresso de avaliação, pull-to-refresh e leitura offline do cache.

**Architecture:** O app nunca desenha a partir da resposta HTTP. `SessionRepository.syncAll()` baixa todas as páginas de `GET /training-sessions` e grava em `SessionsTable`; a tela assina `watchSessions()` (stream do Drift) e lê só do banco local. É isso que faz o modo offline sair de graça: sem rede, `syncAll()` falha, o banco continua servindo a lista, e a faixa de conectividade explica o estado. Filtro, agrupamento e contadores são calculados no `SessionsListViewModel` sobre o cache inteiro — não sobre uma página — porque o endpoint não tem filtro de data nem contagem. Para o card mostrar progresso, `GET /training-sessions` passa a devolver `participantStats` por sessão, calculado com **uma** query `groupBy` (não N+1).

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · dio 5.11.1 · drift 2.31.0 + drift_flutter 0.2.8 · connectivity_plus 6.1.5 · mocktail (testes) · backend NestJS 10 + Prisma 7.9 + Jest 29

**Spec:** `brainstorm-implementacao-mobile.md` → "Fase 2 — Minhas Sessões (Home)"; tela 1.3 do canvas `apps/mobile/docs/design/SIMTC-Mobile.dc.html` (linhas 767–855); pendências de backend em `apps/mobile/docs/fase-0-auditoria.md` (linhas 76–77). O desenho aprovado em 20/09/2026 está registrado na seção "Decisões tomadas com o usuário" abaixo — **não existe doc de spec separado nesta trilha**, o plano é o documento.

## Decisões tomadas com o usuário (20/09/2026)

1. **Progresso no card:** o backend é ampliado. `GET /training-sessions` passa a devolver `participantStats: { total, assessable, assessed }` por sessão, com uma query `groupBy` extra. Recusadas: buscar o detalhe de cada sessão (N+1 em 4G) e entregar a fase sem barra de progresso.
2. **`assessable` exclui `SOMENTE_TEORICA`:** quem só faz a teórica nunca recebe avaliação prática; se entrasse no denominador, a barra jamais chegaria a 100%. `assessed` conta `APROVADO` + `NECESSITA_REAVALIACAO` **dentro** de `TEORICA_E_PRATICA`.
3. **ADMIN vê tudo:** o endpoint já devolve todas as sessões para `role = ADMIN` e isso fica como está. O app só troca o título para "Sessões" (em vez de "Minhas sessões") quando o usuário é admin, para o rótulo não mentir. Coerente com a Fase 6, em que o admin administra qualquer sessão.
4. **Filtro e contadores são locais:** o app percorre a paginação até o fim, grava tudo no Drift e a tela lê só do banco. Contadores corretos, agrupamento por data correto e offline de graça. Recusado: adicionar filtros de data ao backend (os contadores ainda exigiriam chamadas extras, e o offline continuaria dependendo do cache).
5. **Regra dos três chips:** **Hoje** = `date` é hoje; **Próximos 7 dias** = `date` entre amanhã e +7 dias; **Concluídas** = `status = CONCLUIDO`, qualquer data. Sessões sem `date` e sessões atrasadas (data passada, status diferente de `CONCLUIDO`) aparecem num grupo **"Outras"** no fim do filtro **Hoje**, para nenhuma sessão sumir da tela.
6. **Navbar sim, busca não:** a `PillNavBar` já entra com a moldura definitiva, com "Sincronizar" e "Perfil" desabilitados até as Fases 5 e 7. O ícone de busca do canvas fica de fora porque não existe endpoint de busca — volta quando houver.

### Decidido depois da revisão final de branch (20/09/2026)

7. **Sessões `CANCELADO` não aparecem em lugar nenhum do app, e isso é intencional.** Elas ficam fora dos três chips e também fora do grupo "Outras". Isso parece contradizer a justificativa do "Outras" ("para nenhuma sessão sumir da tela"), e uma revisão futura vai reclamar — por isso está escrito aqui. O motivo: não há nada que o consultor possa fazer numa sessão cancelada (não dá para avaliar ninguém, e o backend recusa ações), então mostrá-la seria ruído numa tela que ele olha entre um cliente e outro. A regra do "Outras" vale para sessões que ainda podem receber trabalho.
8. **Janela de 90 dias no backend (Task 8).** O app pedia a base inteira, o que quebra para `ADMIN` a partir de 501 sessões. `GET /training-sessions` ganhou o parâmetro `from`, e o app pede os últimos 90 dias mais as sessões sem data. **Consequência aceita:** o chip "Concluídas" passa a mostrar os últimos 90 dias, não "qualquer data" — o que a decisão 5 acima dizia. Filtrar por "minhas sessões" foi recusado por contrariar a decisão 3.

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app` (a mesma das Fases 0 e 1). Sem git worktree.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`.
- Não avançar com teste novo falhando, `flutter analyze` com erro ou build quebrado. Baseline do backend permanece em 12 falhas pré-existentes — **não mexer nelas**; a Task 1 só pode adicionar testes que passam.
- Ambiguidade de regra de negócio → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-09-20-mobile-fase-2-minhas-sessoes/`.

**Mobile (valem para todas as fases)**
- Flutter 3.41.6 / Dart 3.11.4. App **só Android** (celular e tablet), APK sideload. Validação manual em **aparelho físico** (USB ou Wi-Fi, nunca emulador) — procedimento em `apps/mobile/simtc/README.md`.
- MVVM + Repository: um `ChangeNotifier` por tela/fluxo via `provider`; tela nunca chama `Dio`/Drift direto; Repository por domínio devolvendo o `Result<T>` de `lib/utils/result.dart` (reaproveitado, não recriado).
- `ConnectivityService` único, criado no `MultiProvider` do app, nunca dentro de uma tela.
- Composição "quebra-cabeça" obrigatória: cada tela decompõe a UI em métodos privados `Widget _buildX()` combinados num `build()` enxuto.
- Design System: nenhum `Color(0xFF…)`, nenhum número mágico de espaçamento e nenhum `TextStyle` literal fora de `lib/ui/core/theme/`. Cores por `AppColors`, espaçamento por `AppSpacing`/`AppRadius`, texto por `AppTypography`, ícones por `AppIcons`.
- Status e severidade nunca só por cor — sempre ícone + texto (o `StatusChip` já garante isso).
- Alvos de toque mínimos de 48dp (`AppSpacing.touchTarget`); skeleton no lugar de spinner em listas; estados de erro e vazio explícitos.
- Contratos reais apenas — nenhum campo ou endpoint não confirmado no código do backend.
- Arquivos gerados (`*.g.dart`) são versionados junto com a fonte.

## Estado herdado da Fase 1 (ponto de partida)

O commit `d9e660c` fecha a Fase 1 com `flutter analyze` limpo e 56 testes passando. Já existe e **deve ser reaproveitado, não recriado**:

| O que | Onde | Assinatura relevante |
|---|---|---|
| `Result<T>` | `lib/utils/result.dart` | `Success(data)` / `Failure(exception, [message])`, `isSuccess`, `isFailure`, `dataOrNull` |
| `ApiClient` | `lib/data/services/api/api_client.dart` | `Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters})`; lança `ApiException` |
| `ApiException` | `lib/data/services/api/api_exception.dart` | `const ApiException({required String message, int? statusCode, bool isNetworkError})` |
| `AppDatabase` | `lib/data/services/local/app_database.dart` | `schemaVersion => 1`, `MigrationStrategy` com `PRAGMA foreign_keys = ON` em `beforeOpen`, arquivo `simtc.sqlite` |
| `Sessions` (Drift) | `lib/data/services/local/tables.dart` | `id`, `companyName`, `companyLogoUrl?`, `courseName`, `city`, `state`, `date?`, `status`, `notes?`, `cachedAt`; PK `{id}` |
| `Participants` (Drift) | `lib/data/services/local/tables.dart` | tem FK `sessionId → Sessions.id` — apagar uma sessão sem apagar seus participantes viola a FK |
| `AuthRepository` | `lib/data/repositories/auth_repository.dart` | `ChangeNotifier`, `currentUser` → `AuthUser?` |
| `AuthUser` | `lib/data/models/auth_user.dart` | `name`, `email`, `role`, `isAdmin`, `consultantId?` |
| `ConnectivityService` | `lib/data/services/connectivity_service.dart` | `isOnline`, `isOffline`, `Stream<void> onReconnected` |
| `SessionCard` | `lib/ui/core/widgets/session_card.dart` | `companyName`, `courseName`, `meta`, `statusChip`, `accentColor`, `progressLabel?`, `progressValue?` (0..1, nulo esconde a barra), `onTap?` |
| `StatusChip` | `lib/ui/core/widgets/status_chip.dart` | `label`, `icon`, `tone` (`StatusTone.neutral/info/warning/success/danger/mauve`), `dashedBorder` |
| `FilterChipBar` | `lib/ui/core/widgets/filter_chip_bar.dart` | `items` (`FilterChipData(label, count?)`), `selectedIndex`, `onSelect` |
| `PillNavBar` | `lib/ui/core/widgets/pill_nav_bar.dart` | `items` (`PillNavItem(icon, label, badgeCount)`), `currentIndex`, `onSelect` |
| `SkeletonBox` | `lib/ui/core/widgets/skeleton.dart` | `SkeletonBox({double? width, double height = 14, double radius})` |
| `ConnectivityBanner` | `lib/ui/core/widgets/connectivity_banner.dart` | `isOffline`, `message?` — some sozinho quando online |
| `InlineNotice` | `lib/ui/core/widgets/inline_notice.dart` | `required IconData icon`, `required String message`, `tone` (`NoticeTone.neutral/warning/danger/success`) |
| `AppDependencies` | `lib/app_providers.dart` | fábrica única das dependências + `List<SingleChildWidget> get providers` |
| Rotas | `lib/router.dart` | `AppRoutes.splash/login/home/designSystem`, redirect por `auth.isAuthenticated` |
| Logo | `assets/images/logo-simtc.png` | já declarado em `pubspec.yaml` (`assets/images/`) |

**Contrato real do backend, conferido em 20/09/2026** (`apps/backend/src/training-sessions/training-sessions.service.ts`):

```jsonc
// GET /training-sessions?page=1&limit=20  → 200
{
  "data": [
    {
      "id": "clx...", "companyId": "...", "courseId": "...",
      "responsibleConsultantId": "...", "city": "Lençóis Paulista", "state": "SP",
      "date": "2026-09-20T00:00:00.000Z",   // nullable
      "participantCount": 12,                // nullable; é a previsão digitada no cadastro — NÃO é a contagem real
      "notes": null,
      "status": "PLANEJADO",                 // PLANEJADO | EM_ANDAMENTO | CONCLUIDO | CANCELADO
      "qrCodeToken": "...", "createdAt": "...", "updatedAt": "...",
      "company": { "id": "...", "name": "Bracell Celulose" },
      "course": { "id": "...", "name": "Direção Preventiva" },
      "responsibleConsultant": { "id": "...", "name": "Carla" }
      // "participantStats" é adicionado pela Task 1
    }
  ],
  "total": 37, "page": 1, "limit": 20, "totalPages": 2
}
```

Cuidados confirmados no código, não suposições:
- o status inicial é `PLANEJADO`, **não** `AGENDADO`;
- `participantCount` é a previsão do cadastro e pode estar desatualizada ou nula — o card **não** a usa; usa `participantStats.total`;
- `company` vem sem `logoUrl`, e a tela 1.3 não precisa dele (o logo do cabeçalho é o da SIM, não o da empresa);
- para `CONSULTANT` o `where` já filtra por `consultants.some.consultantId`; para `ADMIN` não há filtro.

## Mapa de Arquivos

### Novos

| Arquivo | Responsabilidade |
|---|---|
| `apps/backend/test/training-sessions.service.spec.ts` | Testes do `findAll` (filtro por perfil + agregação) |
| `apps/mobile/simtc/lib/data/models/training_session.dart` | Modelo de domínio + `SessionStatus` + `fromJson` + `fromRow` |
| `apps/mobile/simtc/lib/data/repositories/session_repository.dart` | Sync paginado, escrita no cache e streams de leitura |
| `apps/mobile/simtc/lib/ui/sessions/session_filter.dart` | `SessionFilter`, `SessionGroup` e as funções puras de filtro/agrupamento |
| `apps/mobile/simtc/lib/ui/sessions/sessions_list_viewmodel.dart` | Estado da tela 1.3 |
| `apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart` | Tela 1.3 |
| `apps/mobile/simtc/test/data/models/training_session_test.dart` | Parsing do JSON e do row |
| `apps/mobile/simtc/test/data/repositories/session_repository_test.dart` | Paginação, poda, falha de rede |
| `apps/mobile/simtc/test/ui/sessions/session_filter_test.dart` | Regra dos chips e dos grupos |
| `apps/mobile/simtc/test/ui/sessions/sessions_list_viewmodel_test.dart` | Contadores, troca de filtro, refresh |
| `apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart` | Estados carregando/lista/vazio/perfil |

### Modificados

| Arquivo | O que muda |
|---|---|
| `packages/shared-types/src/dtos/training.dto.ts` | Ganha `TrainingSessionParticipantStats` |
| `apps/backend/src/training-sessions/training-sessions.service.ts` | `findAll` agrega `participantStats` |
| `apps/mobile/simtc/lib/data/services/local/tables.dart` | `Sessions` ganha `totalParticipants`, `assessableParticipants`, `assessedParticipants` |
| `apps/mobile/simtc/lib/data/services/local/app_database.dart` | `schemaVersion` 2 + `onUpgrade` com `addColumn` |
| `apps/mobile/simtc/lib/data/services/local/app_database.g.dart` | Regerado por `build_runner` |
| `apps/mobile/simtc/lib/app_providers.dart` | Cria e provê o `SessionRepository` |
| `apps/mobile/simtc/lib/router.dart` | `/home` passa a construir a `SessionsScreen` |
| `apps/mobile/simtc/test/data/services/local/app_database_test.dart` | Teste da migração 1→2 |

### Apagados

| Arquivo | Por quê |
|---|---|
| `apps/mobile/simtc/lib/ui/home/home_placeholder_screen.dart` | Substituído pela `SessionsScreen`; o diretório `lib/ui/home/` deixa de existir |

---

## Task 1: Backend — `participantStats` em `GET /training-sessions`

**Files:**
- Modify: `packages/shared-types/src/dtos/training.dto.ts`
- Modify: `apps/backend/src/training-sessions/training-sessions.service.ts:21-50`
- Test: `apps/backend/test/training-sessions.service.spec.ts` (criar — este service ainda não tem spec)

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces: cada item de `GET /training-sessions` ganha `participantStats: { total: number; assessable: number; assessed: number }`. A Task 3 lê exatamente esses três nomes.

- [ ] **Step 1: Declarar o tipo compartilhado**

Em `packages/shared-types/src/dtos/training.dto.ts`, no fim do arquivo:

```ts
/** Contagem de participantes de uma sessão, devolvida na listagem. */
export interface TrainingSessionParticipantStats {
  /** Todos os participantes inscritos na sessão. */
  total: number;
  /**
   * Participantes que recebem avaliação prática (`TEORICA_E_PRATICA`).
   * É o denominador do progresso: quem é `SOMENTE_TEORICA` nunca é avaliado,
   * então incluí-lo faria a barra nunca chegar a 100%.
   */
  assessable: number;
  /** Avaliáveis já concluídos (`APROVADO` ou `NECESSITA_REAVALIACAO`). */
  assessed: number;
}
```

- [ ] **Step 2: Escrever o teste que falha**

Criar `apps/backend/test/training-sessions.service.spec.ts`:

```ts
import { Test, TestingModule } from '@nestjs/testing';
import { TrainingSessionsService } from 'src/training-sessions/training-sessions.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { EmailService } from 'src/email/email.service';
import { StorageService } from 'src/storage/storage.service';
import { JwtPayload } from '@simtc/shared-types';

const mockPrisma = {
  trainingSession: { findMany: jest.fn(), count: jest.fn() },
  trainingParticipant: { groupBy: jest.fn() },
};

const consultant = { sub: 'u1', role: 'CONSULTANT', consultantId: 'c1' } as unknown as JwtPayload;
const admin = { sub: 'u2', role: 'ADMIN' } as unknown as JwtPayload;

function session(id: string) {
  return { id, city: 'Lençóis Paulista', state: 'SP', status: 'PLANEJADO' };
}

function groupRow(
  trainingSessionId: string,
  status: string,
  participationType: string,
  count: number,
) {
  return { trainingSessionId, status, participationType, _count: { _all: count } };
}

describe('TrainingSessionsService.findAll', () => {
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
    jest.clearAllMocks();
    mockPrisma.trainingSession.count.mockResolvedValue(0);
    mockPrisma.trainingParticipant.groupBy.mockResolvedValue([]);
  });

  it('filtra por consultor quando o perfil é CONSULTANT', async () => {
    mockPrisma.trainingSession.findMany.mockResolvedValue([]);

    await service.findAll(consultant, {});

    expect(mockPrisma.trainingSession.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { consultants: { some: { consultantId: 'c1' } } },
      }),
    );
  });

  it('não filtra por consultor quando o perfil é ADMIN', async () => {
    mockPrisma.trainingSession.findMany.mockResolvedValue([]);

    await service.findAll(admin, {});

    expect(mockPrisma.trainingSession.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: {} }),
    );
  });

  it('conta apenas TEORICA_E_PRATICA como avaliável e como avaliado', async () => {
    mockPrisma.trainingSession.findMany.mockResolvedValue([session('s1')]);
    mockPrisma.trainingParticipant.groupBy.mockResolvedValue([
      groupRow('s1', 'PENDENTE', 'TEORICA_E_PRATICA', 3),
      groupRow('s1', 'APROVADO', 'TEORICA_E_PRATICA', 4),
      groupRow('s1', 'NECESSITA_REAVALIACAO', 'TEORICA_E_PRATICA', 1),
      groupRow('s1', 'APROVADO', 'SOMENTE_TEORICA', 2),
    ]);

    const result = await service.findAll(consultant, {});

    expect(result.data[0].participantStats).toEqual({
      total: 10,
      assessable: 8,
      assessed: 5,
    });
  });

  it('devolve zeros para sessão sem participantes', async () => {
    mockPrisma.trainingSession.findMany.mockResolvedValue([session('s1')]);

    const result = await service.findAll(consultant, {});

    expect(result.data[0].participantStats).toEqual({ total: 0, assessable: 0, assessed: 0 });
  });

  it('não consulta participantes quando a página vem vazia', async () => {
    mockPrisma.trainingSession.findMany.mockResolvedValue([]);

    await service.findAll(consultant, {});

    expect(mockPrisma.trainingParticipant.groupBy).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 3: Rodar o teste e confirmar que falha**

Run: `cd apps/backend && npx jest test/training-sessions.service.spec.ts`
Esperado: FAIL — os três testes de agregação quebram com `participantStats` `undefined`.

- [ ] **Step 4: Implementar a agregação**

Em `apps/backend/src/training-sessions/training-sessions.service.ts`, importar o tipo junto de `JwtPayload`:

```ts
import { JwtPayload, TrainingSessionParticipantStats } from '@simtc/shared-types';
```

Substituir o `return` de `findAll` e acrescentar o método privado logo abaixo dele:

```ts
    const stats = await this.participantStatsBySession(data.map((s) => s.id));

    return {
      data: data.map((session) => ({
        ...session,
        participantStats:
          stats.get(session.id) ?? { total: 0, assessable: 0, assessed: 0 },
      })),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * Conta os participantes das sessões da página numa única query.
   *
   * O app mobile precisa de "X de Y avaliados" no card da Home; buscar o
   * detalhe de cada sessão seria N+1 numa tela que abre em 4G.
   */
  private async participantStatsBySession(sessionIds: string[]) {
    const stats = new Map<string, TrainingSessionParticipantStats>();
    if (sessionIds.length === 0) return stats;

    const rows = await this.prisma.trainingParticipant.groupBy({
      by: ['trainingSessionId', 'status', 'participationType'],
      where: { trainingSessionId: { in: sessionIds } },
      _count: { _all: true },
    });

    for (const row of rows) {
      const current =
        stats.get(row.trainingSessionId) ?? { total: 0, assessable: 0, assessed: 0 };
      const count = row._count._all;

      current.total += count;
      if (row.participationType === 'TEORICA_E_PRATICA') {
        current.assessable += count;
        if (row.status === 'APROVADO' || row.status === 'NECESSITA_REAVALIACAO') {
          current.assessed += count;
        }
      }

      stats.set(row.trainingSessionId, current);
    }

    return stats;
  }
```

- [ ] **Step 5: Reconstruir o pacote de tipos compartilhados**

Run: `cd packages/shared-types && npm run build`

`@simtc/shared-types` aponta `main`/`types` para `./dist`, não para `./src`. Sem este build, o `ts-jest` e o `tsc --noEmit` leem o `dist` velho e o import de `TrainingSessionParticipantStats` no teste não resolve. Só inclua artefatos de `dist/` no commit se o repositório já os rastrear (confira com `git status`) — se forem ignorados, deixe fora.

- [ ] **Step 6: Rodar o teste e confirmar que passa**

Run: `cd apps/backend && npx jest test/training-sessions.service.spec.ts`
Esperado: PASS, 5 testes.

- [ ] **Step 7: Confirmar que a baseline do backend não piorou**

Run: `cd apps/backend && npx jest 2>&1 | tail -5` e depois `npx tsc --noEmit`
Esperado: as mesmas 12 falhas pré-existentes (nenhuma nova) e `tsc` sem erro. Se aparecer uma 13ª falha, ela é sua — corrija antes de commitar.

- [ ] **Step 8: Commit**

```bash
git add packages/shared-types/src/dtos/training.dto.ts apps/backend/src/training-sessions/training-sessions.service.ts apps/backend/test/training-sessions.service.spec.ts
git commit -m "feat(backend): devolve contagem de participantes na listagem de sessoes"
```

---

## Task 2: Drift — colunas de contagem e migração 1→2

**Files:**
- Modify: `apps/mobile/simtc/lib/data/services/local/tables.dart:19-35`
- Modify: `apps/mobile/simtc/lib/data/services/local/app_database.dart:29-40`
- Modify (gerado): `apps/mobile/simtc/lib/data/services/local/app_database.g.dart`
- Test: `apps/mobile/simtc/test/data/services/local/app_database_test.dart`

**Interfaces:**
- Consumes: `participantStats` da Task 1 (os três números vêm daí).
- Produces: `Sessions` ganha `totalParticipants`, `assessableParticipants`, `assessedParticipants` (`IntColumn`, default 0). `SessionsCompanion.insert` passa a aceitar esses três nomes como `Value<int>` opcionais. As Tasks 3 e 4 usam esses nomes.

- [ ] **Step 1: Escrever o teste de migração que falha**

Acrescentar `import 'dart:io';` no topo de `test/data/services/local/app_database_test.dart` e o teste abaixo no fim do `main()` existente.

O banco antigo é montado no `setup` do `NativeDatabase`, e **não** abrindo um `AppDatabase` antes: um `AppDatabase` sobre arquivo vazio dispara `createAll()` já na versão 2, e aí a migração nunca rodaria — e, quando rodasse, o `addColumn` quebraria com "duplicate column name". O `setup` roda no banco cru, antes de o drift comparar as versões, então a abertura enxerga um v1 de verdade.

```dart
  test('migra do esquema 1 para o 2 mantendo as sessões já cacheadas', () async {
    final directory = Directory.systemTemp.createTempSync('simtc_migracao');
    final file = File('${directory.path}/simtc.sqlite');

    final migrated = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          // A tabela `sessions` exatamente como a Fase 1 a criou.
          raw.execute('''
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
              cached_at INTEGER NOT NULL,
              PRIMARY KEY (id)
            )
          ''');
          raw.execute('''
            INSERT INTO sessions (id, company_name, course_name, city, state, status, cached_at)
            VALUES ('sess-antiga', 'Bracell Celulose', 'Direção Preventiva',
                    'Lençóis Paulista', 'SP', 'PLANEJADO', 0)
          ''');
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );

    addTearDown(() async {
      await migrated.close();
      directory.deleteSync(recursive: true);
    });

    final row = await migrated.select(migrated.sessions).getSingle();

    expect(row.id, 'sess-antiga');
    expect(row.companyName, 'Bracell Celulose');
    expect(row.totalParticipants, 0);
    expect(row.assessableParticipants, 0);
    expect(row.assessedParticipants, 0);
  });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `cd apps/mobile/simtc && flutter test test/data/services/local/app_database_test.dart`
Esperado: FAIL na compilação — `totalParticipants` não existe em `Session`.

- [ ] **Step 3: Acrescentar as colunas**

Em `lib/data/services/local/tables.dart`, dentro de `class Sessions`, logo antes de `cachedAt`:

```dart
  /// Total de participantes inscritos — mostrado na linha de meta do card.
  IntColumn get totalParticipants => integer().withDefault(const Constant(0))();

  /// Participantes que recebem avaliação prática: denominador do progresso.
  IntColumn get assessableParticipants =>
      integer().withDefault(const Constant(0))();

  /// Avaliáveis já concluídos: numerador do progresso.
  IntColumn get assessedParticipants =>
      integer().withDefault(const Constant(0))();
```

- [ ] **Step 4: Subir a versão do esquema e escrever a migração**

Em `lib/data/services/local/app_database.dart`, trocar `schemaVersion` e o `MigrationStrategy`:

```dart
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Fase 2: contagens de participantes no card da Home. São cache —
            // entram com 0 e o primeiro sync preenche. Migrar por `addColumn`
            // (e não recriando a tabela) preserva a lista que o consultor já
            // tem no aparelho, que é o que ele vê ao abrir o app offline.
            await m.addColumn(sessions, sessions.totalParticipants);
            await m.addColumn(sessions, sessions.assessableParticipants);
            await m.addColumn(sessions, sessions.assessedParticipants);
          }
        },
        beforeOpen: (details) async {
          // O esquema usa chaves estrangeiras (participante → sessão, infração →
          // categoria); no SQLite elas só são aplicadas com este pragma ligado.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
```

- [ ] **Step 5: Regerar o código do Drift**

Run: `cd apps/mobile/simtc && dart run build_runner build --delete-conflicting-outputs`
Esperado: `app_database.g.dart` regravado, sem erro.

- [ ] **Step 6: Rodar os testes e confirmar que passam**

Run: `cd apps/mobile/simtc && flutter test test/data/services/local/app_database_test.dart && flutter analyze`
Esperado: PASS em todos os testes do arquivo e `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/simtc/lib/data/services/local/tables.dart apps/mobile/simtc/lib/data/services/local/app_database.dart apps/mobile/simtc/lib/data/services/local/app_database.g.dart apps/mobile/simtc/test/data/services/local/app_database_test.dart
git commit -m "feat(mobile): guarda a contagem de participantes no cache de sessoes"
```

---

## Task 3: Modelo de domínio `TrainingSession`

**Files:**
- Create: `apps/mobile/simtc/lib/data/models/training_session.dart`
- Test: `apps/mobile/simtc/test/data/models/training_session_test.dart`

**Interfaces:**
- Consumes: `participantStats` (Task 1); a classe `Session` gerada pelo Drift (Task 2).
- Produces:
  - `enum SessionStatus { planejado, emAndamento, concluido, cancelado }` com `label`, `wireValue` e `SessionStatus.parse(String?)`;
  - `class TrainingSession` com `id, companyName, companyLogoUrl?, courseName, city, state, date?, status, notes?, totalParticipants, assessableParticipants, assessedParticipants`;
  - `TrainingSession.fromJson(Map<String, dynamic>)` e `TrainingSession.fromRow(Session)`;
  - `double? get progress`, `String? get progressLabel`, `String get meta`.
  As Tasks 4, 5 e 6 usam exatamente esses nomes.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/data/models/training_session_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/training_session.dart';

void main() {
  Map<String, dynamic> json({
    String status = 'PLANEJADO',
    String? date = '2026-09-20T12:00:00.000Z',
    Map<String, dynamic>? stats,
  }) {
    return {
      'id': 'sess-1',
      'city': 'Lençóis Paulista',
      'state': 'SP',
      'date': date,
      'notes': null,
      'status': status,
      'company': {'id': 'emp-1', 'name': 'Bracell Celulose'},
      'course': {'id': 'cur-1', 'name': 'Direção Preventiva'},
      'participantStats': stats ?? {'total': 10, 'assessable': 8, 'assessed': 2},
    };
  }

  test('lê os campos aninhados de empresa, curso e contagem', () {
    final session = TrainingSession.fromJson(json());

    expect(session.id, 'sess-1');
    expect(session.companyName, 'Bracell Celulose');
    expect(session.courseName, 'Direção Preventiva');
    expect(session.totalParticipants, 10);
    expect(session.assessableParticipants, 8);
    expect(session.assessedParticipants, 2);
    expect(session.status, SessionStatus.planejado);
  });

  test('aceita sessão sem data e sem contagem', () {
    final semStats = json(date: null)..remove('participantStats');
    final session = TrainingSession.fromJson(semStats);

    expect(session.date, isNull);
    expect(session.totalParticipants, 0);
    expect(session.progress, isNull);
    expect(session.progressLabel, isNull);
  });

  test('status desconhecido não quebra o parsing', () {
    expect(TrainingSession.fromJson(json(status: 'ALGO_NOVO')).status,
        SessionStatus.planejado);
  });

  test('progresso é a fração de avaliáveis concluídos', () {
    final session = TrainingSession.fromJson(json());

    expect(session.progress, 0.25);
    expect(session.progressLabel, '2 de 8 avaliados');
  });

  test('meta junta cidade, UF e total de participantes', () {
    expect(TrainingSession.fromJson(json()).meta,
        'Lençóis Paulista/SP · 10 participantes');
  });

  test('meta no singular quando há um participante só', () {
    final session = TrainingSession.fromJson(
      json(stats: {'total': 1, 'assessable': 1, 'assessed': 0}),
    );

    expect(session.meta, 'Lençóis Paulista/SP · 1 participante');
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `cd apps/mobile/simtc && flutter test test/data/models/training_session_test.dart`
Esperado: FAIL — `training_session.dart` não existe.

- [ ] **Step 3: Escrever o modelo**

Criar `lib/data/models/training_session.dart`:

```dart
import '../services/local/app_database.dart';

/// Situação de uma sessão de treinamento. Espelha `TrainingStatus` do backend —
/// o valor inicial lá é `PLANEJADO`, não `AGENDADO`.
enum SessionStatus {
  planejado('Planejado'),
  emAndamento('Em andamento'),
  concluido('Concluído'),
  cancelado('Cancelado');

  const SessionStatus(this.label);

  final String label;

  /// Nome que o backend usa — também é o que vai para o cache.
  String get wireValue => switch (this) {
        SessionStatus.planejado => 'PLANEJADO',
        SessionStatus.emAndamento => 'EM_ANDAMENTO',
        SessionStatus.concluido => 'CONCLUIDO',
        SessionStatus.cancelado => 'CANCELADO',
      };

  /// Um status novo no backend não pode derrubar a lista inteira do consultor
  /// em campo, então o desconhecido cai no valor inicial.
  static SessionStatus parse(String? value) => switch (value) {
        'EM_ANDAMENTO' => SessionStatus.emAndamento,
        'CONCLUIDO' => SessionStatus.concluido,
        'CANCELADO' => SessionStatus.cancelado,
        _ => SessionStatus.planejado,
      };
}

/// Uma sessão de treinamento como o app a usa — já achatada, sem os objetos
/// aninhados do backend.
class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.companyName,
    required this.courseName,
    required this.city,
    required this.state,
    required this.status,
    required this.totalParticipants,
    required this.assessableParticipants,
    required this.assessedParticipants,
    this.companyLogoUrl,
    this.date,
    this.notes,
  });

  final String id;
  final String companyName;
  final String? companyLogoUrl;
  final String courseName;
  final String city;
  final String state;
  final DateTime? date;
  final SessionStatus status;
  final String? notes;

  /// Todos os inscritos. Vem de `participantStats.total`, não do campo
  /// `participantCount` do cadastro, que é só uma previsão e envelhece.
  final int totalParticipants;

  /// Denominador do progresso: só quem faz a prática.
  final int assessableParticipants;

  /// Numerador do progresso: avaliáveis já concluídos.
  final int assessedParticipants;

  static int _asInt(Object? value) => value is num ? value.toInt() : 0;

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    final company = json['company'] as Map<String, dynamic>? ?? const {};
    final course = json['course'] as Map<String, dynamic>? ?? const {};
    final stats = json['participantStats'] as Map<String, dynamic>? ?? const {};
    final date = json['date'] as String?;

    return TrainingSession(
      id: json['id'] as String? ?? '',
      companyName: company['name'] as String? ?? '',
      companyLogoUrl: company['logoUrl'] as String?,
      courseName: course['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      date: date == null ? null : DateTime.tryParse(date)?.toLocal(),
      status: SessionStatus.parse(json['status'] as String?),
      notes: json['notes'] as String?,
      totalParticipants: _asInt(stats['total']),
      assessableParticipants: _asInt(stats['assessable']),
      assessedParticipants: _asInt(stats['assessed']),
    );
  }

  /// Reconstrói a partir da linha do cache local.
  factory TrainingSession.fromRow(Session row) {
    return TrainingSession(
      id: row.id,
      companyName: row.companyName,
      companyLogoUrl: row.companyLogoUrl,
      courseName: row.courseName,
      city: row.city,
      state: row.state,
      date: row.date,
      status: SessionStatus.parse(row.status),
      notes: row.notes,
      totalParticipants: row.totalParticipants,
      assessableParticipants: row.assessableParticipants,
      assessedParticipants: row.assessedParticipants,
    );
  }

  /// Fração de 0 a 1 para a barra do card; nula quando ninguém é avaliável
  /// (aí o card não mostra barra nenhuma, em vez de uma barra vazia mentirosa).
  double? get progress {
    if (assessableParticipants <= 0) return null;
    return assessedParticipants / assessableParticipants;
  }

  String? get progressLabel {
    if (assessableParticipants <= 0) return null;
    return '$assessedParticipants de $assessableParticipants avaliados';
  }

  /// Linha de metadados do card: onde é e quanta gente tem.
  String get meta {
    final plural = totalParticipants == 1 ? 'participante' : 'participantes';
    return '$city/$state · $totalParticipants $plural';
  }
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `cd apps/mobile/simtc && flutter test test/data/models/training_session_test.dart && flutter analyze`
Esperado: PASS, 6 testes, `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/simtc/lib/data/models/training_session.dart apps/mobile/simtc/test/data/models/training_session_test.dart
git commit -m "feat(mobile): modelo de sessao de treinamento com progresso de avaliacao"
```

---

## Task 4: `SessionRepository` — sync paginado e leitura do cache

**Files:**
- Create: `apps/mobile/simtc/lib/data/repositories/session_repository.dart`
- Test: `apps/mobile/simtc/test/data/repositories/session_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient.get`, `AppDatabase`, `TrainingSession.fromJson`/`fromRow` (Task 3), colunas da Task 2.
- Produces:
  - `SessionRepository({required ApiClient apiClient, required AppDatabase database})`;
  - `Stream<List<TrainingSession>> watchSessions()` — data mais próxima primeiro, sem data por último;
  - `Stream<DateTime?> watchLastSyncedAt()`;
  - `Future<Result<int>> syncAll()` — devolve quantas sessões ficaram no cache.
  A Task 5 usa exatamente esses três métodos.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/data/repositories/session_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late SessionRepository repository;

  Map<String, dynamic> sessionJson(String id) {
    return {
      'id': id,
      'city': 'Lençóis Paulista',
      'state': 'SP',
      'date': '2026-09-20T12:00:00.000Z',
      'status': 'PLANEJADO',
      'notes': null,
      'company': {'id': 'emp-1', 'name': 'Bracell Celulose'},
      'course': {'id': 'cur-1', 'name': 'Direção Preventiva'},
      'participantStats': {'total': 4, 'assessable': 4, 'assessed': 1},
    };
  }

  Response<Map<String, dynamic>> page(
    List<Map<String, dynamic>> data, {
    required int pageNumber,
    required int totalPages,
  }) {
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/training-sessions'),
      statusCode: 200,
      data: {
        'data': data,
        'total': data.length,
        'page': pageNumber,
        'limit': 50,
        'totalPages': totalPages,
      },
    );
  }

  setUp(() {
    api = _MockApiClient();
    db = AppDatabase(NativeDatabase.memory());
    repository = SessionRepository(apiClient: api, database: db);
  });

  tearDown(() => db.close());

  test('percorre todas as páginas e grava tudo no cache', () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: {'page': 1, 'limit': 50}))
        .thenAnswer((_) async => page([sessionJson('s1')], pageNumber: 1, totalPages: 2));
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: {'page': 2, 'limit': 50}))
        .thenAnswer((_) async => page([sessionJson('s2')], pageNumber: 2, totalPages: 2));

    final result = await repository.syncAll();

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull, 2);
    final ids = (await db.select(db.sessions).get()).map((r) => r.id).toList();
    expect(ids, containsAll(['s1', 's2']));
  });

  test('apaga do cache a sessão que sumiu do servidor', () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('s1')], pageNumber: 1, totalPages: 1));
    await repository.syncAll();

    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('s2')], pageNumber: 1, totalPages: 1));
    await repository.syncAll();

    final ids = (await db.select(db.sessions).get()).map((r) => r.id).toList();
    expect(ids, ['s2']);
  });

  test('falha de rede preserva o que já estava no cache', () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([sessionJson('s1')], pageNumber: 1, totalPages: 1));
    await repository.syncAll();

    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenThrow(const ApiException(message: 'sem rede', isNetworkError: true));

    final result = await repository.syncAll();

    expect(result.isFailure, isTrue);
    expect(await db.select(db.sessions).get(), hasLength(1));
  });

  test('watchSessions ordena pela data mais próxima e deixa sem data por último',
      () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
        queryParameters: any(named: 'queryParameters'))).thenAnswer(
      (_) async => page([
        {...sessionJson('tarde'), 'date': '2026-09-25T12:00:00.000Z'},
        {...sessionJson('sem-data'), 'date': null},
        {...sessionJson('cedo'), 'date': '2026-09-21T12:00:00.000Z'},
      ], pageNumber: 1, totalPages: 1),
    );
    await repository.syncAll();

    final sessions = await repository.watchSessions().first;

    expect(sessions.map((s) => s.id).toList(), ['cedo', 'tarde', 'sem-data']);
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `cd apps/mobile/simtc && flutter test test/data/repositories/session_repository_test.dart`
Esperado: FAIL — `session_repository.dart` não existe.

- [ ] **Step 3: Escrever o repository**

Criar `lib/data/repositories/session_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../../utils/result.dart';
import '../models/training_session.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/local/app_database.dart';

/// Sessões de treinamento do consultor.
///
/// A regra desta camada é simples: **a tela lê do banco, nunca da resposta
/// HTTP**. `syncAll()` baixa e grava; `watchSessions()` serve a lista. Sem rede,
/// `syncAll()` falha e a lista continua vindo do cache — é assim que a Home
/// funciona offline sem nenhum código de offline na tela.
class SessionRepository {
  SessionRepository({required ApiClient apiClient, required AppDatabase database})
      : _api = apiClient,
        _db = database;

  final ApiClient _api;
  final AppDatabase _db;

  static const String _path = '/training-sessions';

  /// Páginas maiores que o padrão do backend: a Home quer a lista inteira e
  /// cada viagem extra custa caro no 4G do cliente.
  static const int _pageSize = 50;

  /// Teto de segurança para não girar para sempre se o backend devolver um
  /// `totalPages` incoerente.
  static const int _maxPages = 10;

  static const String _offlineMessage =
      'Não foi possível atualizar. Mostrando os dados já baixados.';

  /// Lista do cache, da data mais próxima para a mais distante; sem data por
  /// último, porque não dá para saber onde ela entra na agenda.
  Stream<List<TrainingSession>> watchSessions() {
    final query = _db.select(_db.sessions)
      ..orderBy([
        (t) => OrderingTerm(expression: t.date.isNull()),
        (t) => OrderingTerm(expression: t.date),
        (t) => OrderingTerm(expression: t.companyName),
      ]);

    return query.watch().map(
          (rows) => rows.map(TrainingSession.fromRow).toList(growable: false),
        );
  }

  /// Quando o cache foi atualizado pela última vez — a tela mostra isso quando
  /// está offline, para o consultor saber a idade do que está vendo.
  Stream<DateTime?> watchLastSyncedAt() {
    final cachedAt = _db.sessions.cachedAt.max();
    final query = _db.selectOnly(_db.sessions)..addColumns([cachedAt]);
    return query.watchSingleOrNull().map((row) => row?.read(cachedAt));
  }

  /// Baixa todas as páginas e regrava o cache. Devolve quantas sessões ficaram.
  ///
  /// Nada é escrito antes de todas as páginas chegarem: uma queda no meio do
  /// caminho deixaria o cache com metade da agenda, que é pior do que a agenda
  /// velha inteira.
  Future<Result<int>> syncAll() async {
    final sessions = <TrainingSession>[];
    var reachedEnd = false;

    try {
      for (var page = 1; page <= _maxPages; page++) {
        final response = await _api.get<Map<String, dynamic>>(
          _path,
          queryParameters: {'page': page, 'limit': _pageSize},
        );

        final body = response.data ?? const <String, dynamic>{};
        final data = body['data'] as List<dynamic>? ?? const [];
        sessions.addAll(
          data.whereType<Map<String, dynamic>>().map(TrainingSession.fromJson),
        );

        final totalPages = (body['totalPages'] as num?)?.toInt() ?? page;
        if (page >= totalPages) {
          reachedEnd = true;
          break;
        }
      }
    } on ApiException catch (error) {
      return Failure(error, _offlineMessage);
    }

    // Só poda quando a lista veio inteira: se o teto de páginas interrompeu o
    // download, apagar "o que não veio" jogaria fora sessões válidas.
    await _write(sessions, prune: reachedEnd);
    return Success(sessions.length);
  }

  Future<void> _write(List<TrainingSession> sessions, {required bool prune}) {
    final now = DateTime.now();

    return _db.transaction(() async {
      if (prune) {
        final ids = sessions.map((s) => s.id).toList(growable: false);
        // Participantes têm chave estrangeira para a sessão: apagar a sessão
        // antes deles violaria a FK e derrubaria a transação inteira.
        await (_db.delete(_db.participants)
              ..where((t) => t.sessionId.isNotIn(ids)))
            .go();
        await (_db.delete(_db.sessions)..where((t) => t.id.isNotIn(ids))).go();
      }

      for (final session in sessions) {
        await _db.into(_db.sessions).insertOnConflictUpdate(
              SessionsCompanion.insert(
                id: session.id,
                companyName: session.companyName,
                companyLogoUrl: Value(session.companyLogoUrl),
                courseName: session.courseName,
                city: session.city,
                state: session.state,
                date: Value(session.date),
                status: session.status.wireValue,
                notes: Value(session.notes),
                totalParticipants: Value(session.totalParticipants),
                assessableParticipants: Value(session.assessableParticipants),
                assessedParticipants: Value(session.assessedParticipants),
                cachedAt: now,
              ),
            );
      }
    });
  }
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `cd apps/mobile/simtc && flutter test test/data/repositories/session_repository_test.dart && flutter analyze`
Esperado: PASS, 4 testes, `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/simtc/lib/data/repositories/session_repository.dart apps/mobile/simtc/test/data/repositories/session_repository_test.dart
git commit -m "feat(mobile): sincroniza e cacheia as sessoes do consultor"
```

---

## Task 5: Filtros, grupos e `SessionsListViewModel`

**Files:**
- Create: `apps/mobile/simtc/lib/ui/sessions/session_filter.dart`
- Create: `apps/mobile/simtc/lib/ui/sessions/sessions_list_viewmodel.dart`
- Test: `apps/mobile/simtc/test/ui/sessions/session_filter_test.dart`
- Test: `apps/mobile/simtc/test/ui/sessions/sessions_list_viewmodel_test.dart`

**Interfaces:**
- Consumes: `SessionRepository.watchSessions/watchLastSyncedAt/syncAll` (Task 4), `TrainingSession` (Task 3), `ConnectivityService`.
- Produces:
  - `enum SessionFilter { hoje, proximos7, concluidas }` com `label`;
  - `class SessionGroup { final String title; final List<TrainingSession> sessions; }`;
  - `List<SessionGroup> groupSessions(List<TrainingSession> sessions, SessionFilter filter, DateTime now)`;
  - `int countFor(List<TrainingSession> sessions, SessionFilter filter, DateTime now)`;
  - `SessionsListViewModel({required SessionRepository repository, required ConnectivityService connectivity, DateTime Function()? now})` com `init()`, `groups`, `counts`, `filter`, `setFilter`, `refresh()`, `isLoading`, `isRefreshing`, `errorMessage`, `clearError()`, `lastSyncedAt`.
  A Task 6 usa exatamente esses nomes.

  **O ViewModel não expõe `isOffline`.** A tela observa o `ConnectivityService` direto, porque é ele que notifica quando a conexão muda; um getter no ViewModel devolveria o valor certo mas nunca dispararia rebuild, e seria uma armadilha silenciosa. O ViewModel usa a conectividade só para ouvir `onReconnected`.

- [ ] **Step 1: Escrever o teste das regras de filtro**

Criar `test/ui/sessions/session_filter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/ui/sessions/session_filter.dart';

void main() {
  final agora = DateTime(2026, 9, 20, 9);

  TrainingSession session(
    String id, {
    DateTime? date,
    SessionStatus status = SessionStatus.planejado,
  }) {
    return TrainingSession(
      id: id,
      companyName: 'Bracell Celulose',
      courseName: 'Direção Preventiva',
      city: 'Lençóis Paulista',
      state: 'SP',
      date: date,
      status: status,
      totalParticipants: 4,
      assessableParticipants: 4,
      assessedParticipants: 1,
    );
  }

  final hoje = session('hoje', date: DateTime(2026, 9, 20, 8));
  final amanha = session('amanha', date: DateTime(2026, 9, 21, 8));
  final emSete = session('em-sete', date: DateTime(2026, 9, 27, 8));
  final emOito = session('em-oito', date: DateTime(2026, 9, 28, 8));
  final semData = session('sem-data');
  final atrasada = session('atrasada', date: DateTime(2026, 9, 10, 8));
  final concluida = session('concluida',
      date: DateTime(2026, 8, 30, 8), status: SessionStatus.concluido);

  // Na ordem que o repository entrega: data mais próxima primeiro, sem data no fim.
  final todas = [concluida, atrasada, hoje, amanha, emSete, emOito, semData];

  List<String> idsOf(List<SessionGroup> groups) =>
      groups.expand((g) => g.sessions).map((s) => s.id).toList();

  test('Hoje traz as de hoje e junta sem data e atrasadas em "Outras"', () {
    final groups = groupSessions(todas, SessionFilter.hoje, agora);

    expect(groups.first.title, 'Hoje · 20 set');
    expect(groups.first.sessions.map((s) => s.id).toList(), ['hoje']);
    expect(groups.last.title, 'Outras · 2');
    expect(groups.last.sessions.map((s) => s.id).toList(),
        ['atrasada', 'sem-data']);
  });

  test('Próximos 7 dias vai de amanhã até o sétimo dia, um grupo por dia', () {
    final groups = groupSessions(todas, SessionFilter.proximos7, agora);

    expect(idsOf(groups), ['amanha', 'em-sete']);
    expect(groups.first.title, 'Seg, 21 set');
  });

  test('Concluídas ignora a data e pega só o status', () {
    final groups = groupSessions(todas, SessionFilter.concluidas, agora);

    expect(groups.single.title, 'Concluídas');
    expect(idsOf(groups), ['concluida']);
  });

  test('sessão de hoje já concluída não aparece em Hoje, e sim em Concluídas', () {
    final hojeConcluida = session('hoje-ok',
        date: DateTime(2026, 9, 20, 7), status: SessionStatus.concluido);

    expect(idsOf(groupSessions([hojeConcluida], SessionFilter.hoje, agora)),
        isEmpty);
    expect(idsOf(groupSessions([hojeConcluida], SessionFilter.concluidas, agora)),
        ['hoje-ok']);
  });

  test('o contador do chip conta só o grupo principal do filtro', () {
    expect(countFor(todas, SessionFilter.hoje, agora), 1);
    expect(countFor(todas, SessionFilter.proximos7, agora), 2);
    expect(countFor(todas, SessionFilter.concluidas, agora), 1);
  });

  test('sessão cancelada não entra em nenhum filtro de agenda', () {
    final cancelada = session('cancelada',
        date: DateTime(2026, 9, 20, 8), status: SessionStatus.cancelado);

    expect(idsOf(groupSessions([cancelada], SessionFilter.hoje, agora)), isEmpty);
    expect(idsOf(groupSessions([cancelada], SessionFilter.proximos7, agora)),
        isEmpty);
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/session_filter_test.dart`
Esperado: FAIL — `session_filter.dart` não existe.

- [ ] **Step 3: Escrever as regras de filtro**

Criar `lib/ui/sessions/session_filter.dart`:

```dart
import '../../data/models/training_session.dart';

/// Os três chips da tela 1.3.
enum SessionFilter {
  hoje('Hoje'),
  proximos7('Próximos 7 dias'),
  concluidas('Concluídas');

  const SessionFilter(this.label);

  final String label;
}

/// Um bloco da lista, com o cabeçalho que aparece acima dele.
class SessionGroup {
  SessionGroup({required this.title, required this.sessions});

  final String title;
  final List<TrainingSession> sessions;
}

const List<String> _meses = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

const List<String> _diasDaSemana = [
  'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom',
];

String _diaEMes(DateTime date) => '${date.day} ${_meses[date.month - 1]}';

String _diaDaSemana(DateTime date) => _diasDaSemana[date.weekday - 1];

DateTime _dia(DateTime value) => DateTime(value.year, value.month, value.day);

/// Uma sessão está "aberta" enquanto ainda pode receber avaliação.
bool _estaAberta(TrainingSession session) =>
    session.status == SessionStatus.planejado ||
    session.status == SessionStatus.emAndamento;

bool _ehHoje(TrainingSession session, DateTime hoje) =>
    _estaAberta(session) && session.date != null && _dia(session.date!) == hoje;

bool _ehProximos7(TrainingSession session, DateTime hoje) {
  if (!_estaAberta(session) || session.date == null) return false;
  final dia = _dia(session.date!);
  return dia.isAfter(hoje) && !dia.isAfter(hoje.add(const Duration(days: 7)));
}

bool _ehConcluida(TrainingSession session) =>
    session.status == SessionStatus.concluido;

/// Sem data, ou com data passada e ainda aberta: não cabe em nenhum chip, mas
/// não pode sumir da tela — o consultor precisa conseguir chegar nela.
bool _ehOutra(TrainingSession session, DateTime hoje) {
  if (!_estaAberta(session)) return false;
  if (session.date == null) return true;
  return _dia(session.date!).isBefore(hoje);
}

/// Quantas sessões o chip anuncia. Conta só o grupo principal do filtro — o
/// grupo "Outras" carrega o próprio número no cabeçalho, para o chip não
/// prometer um número diferente do que a lista mostra.
int countFor(
  List<TrainingSession> sessions,
  SessionFilter filter,
  DateTime now,
) {
  final hoje = _dia(now);
  return switch (filter) {
    SessionFilter.hoje => sessions.where((s) => _ehHoje(s, hoje)).length,
    SessionFilter.proximos7 =>
      sessions.where((s) => _ehProximos7(s, hoje)).length,
    SessionFilter.concluidas => sessions.where(_ehConcluida).length,
  };
}

/// Monta os blocos da lista para o filtro escolhido.
///
/// A entrada já vem ordenada pelo repository (data mais próxima primeiro, sem
/// data por último), então aqui só é preciso particionar.
List<SessionGroup> groupSessions(
  List<TrainingSession> sessions,
  SessionFilter filter,
  DateTime now,
) {
  final hoje = _dia(now);

  switch (filter) {
    case SessionFilter.hoje:
      final doDia = sessions.where((s) => _ehHoje(s, hoje)).toList();
      final outras = sessions.where((s) => _ehOutra(s, hoje)).toList();

      return [
        if (doDia.isNotEmpty)
          SessionGroup(title: 'Hoje · ${_diaEMes(hoje)}', sessions: doDia),
        if (outras.isNotEmpty)
          SessionGroup(title: 'Outras · ${outras.length}', sessions: outras),
      ];

    case SessionFilter.proximos7:
      final groups = <SessionGroup>[];
      DateTime? diaAtual;

      for (final session in sessions.where((s) => _ehProximos7(s, hoje))) {
        final dia = _dia(session.date!);
        if (dia != diaAtual) {
          diaAtual = dia;
          groups.add(SessionGroup(
            title: '${_diaDaSemana(dia)}, ${_diaEMes(dia)}',
            sessions: [],
          ));
        }
        groups.last.sessions.add(session);
      }

      return groups;

    case SessionFilter.concluidas:
      final concluidas = sessions.where(_ehConcluida).toList();
      return [
        if (concluidas.isNotEmpty)
          SessionGroup(title: 'Concluídas', sessions: concluidas),
      ];
  }
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/session_filter_test.dart`
Esperado: PASS, 6 testes.

- [ ] **Step 5: Escrever o teste do ViewModel**

Criar `test/ui/sessions/sessions_list_viewmodel_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/sessions/session_filter.dart';
import 'package:simtc/ui/sessions/sessions_list_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

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
  late _MockSessionRepository repository;
  late _FakeConnectivity connectivity;
  late StreamController<List<TrainingSession>> sessions;

  final agora = DateTime(2026, 9, 20, 9);

  TrainingSession session(String id, {DateTime? date, SessionStatus? status}) {
    return TrainingSession(
      id: id,
      companyName: 'Bracell Celulose',
      courseName: 'Direção Preventiva',
      city: 'Lençóis Paulista',
      state: 'SP',
      date: date,
      status: status ?? SessionStatus.planejado,
      totalParticipants: 4,
      assessableParticipants: 4,
      assessedParticipants: 1,
    );
  }

  SessionsListViewModel build() => SessionsListViewModel(
        repository: repository,
        connectivity: connectivity,
        now: () => agora,
      );

  setUp(() {
    repository = _MockSessionRepository();
    connectivity = _FakeConnectivity();
    sessions = StreamController<List<TrainingSession>>.broadcast();

    when(repository.watchSessions).thenAnswer((_) => sessions.stream);
    when(repository.watchLastSyncedAt)
        .thenAnswer((_) => Stream.value(DateTime(2026, 9, 20, 8)));
    when(repository.syncAll).thenAnswer((_) async => const Success(1));
  });

  tearDown(() {
    sessions.close();
    connectivity.dispose();
  });

  test('começa carregando e sai do carregamento na primeira emissão', () async {
    final viewModel = build()..init();
    expect(viewModel.isLoading, isTrue);

    sessions.add([session('hoje', date: DateTime(2026, 9, 20, 8))]);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.groups.single.sessions.single.id, 'hoje');
  });

  test('sincroniza sozinho ao abrir', () async {
    build().init();
    await Future<void>.delayed(Duration.zero);

    verify(repository.syncAll).called(1);
  });

  test('sincroniza de novo quando a conexão volta', () async {
    build().init();
    await Future<void>.delayed(Duration.zero);

    connectivity.reconnect();
    await Future<void>.delayed(Duration.zero);

    verify(repository.syncAll).called(2);
  });

  test('os contadores dos chips não dependem do filtro escolhido', () async {
    final viewModel = build()..init();
    sessions.add([
      session('hoje', date: DateTime(2026, 9, 20, 8)),
      session('amanha', date: DateTime(2026, 9, 21, 8)),
      session('ok', status: SessionStatus.concluido),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.counts[SessionFilter.hoje], 1);
    expect(viewModel.counts[SessionFilter.proximos7], 1);
    expect(viewModel.counts[SessionFilter.concluidas], 1);
  });

  test('trocar o filtro remonta os grupos sem nova chamada de rede', () async {
    final viewModel = build()..init();
    sessions.add([session('amanha', date: DateTime(2026, 9, 21, 8))]);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.groups, isEmpty);

    viewModel.setFilter(SessionFilter.proximos7);

    expect(viewModel.groups.single.sessions.single.id, 'amanha');
    verify(repository.syncAll).called(1);
  });

  test('falha no refresh vira mensagem, sem apagar a lista', () async {
    final viewModel = build()..init();
    sessions.add([session('hoje', date: DateTime(2026, 9, 20, 8))]);
    await Future<void>.delayed(Duration.zero);

    when(repository.syncAll)
        .thenAnswer((_) async => Failure(Exception('sem rede'), 'Sem conexão.'));

    await viewModel.refresh();

    expect(viewModel.errorMessage, 'Sem conexão.');
    expect(viewModel.groups.single.sessions, hasLength(1));
  });
}
```

- [ ] **Step 6: Rodar o teste e confirmar que falha**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/sessions_list_viewmodel_test.dart`
Esperado: FAIL — `sessions_list_viewmodel.dart` não existe.

- [ ] **Step 7: Escrever o ViewModel**

Criar `lib/ui/sessions/sessions_list_viewmodel.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/training_session.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../utils/result.dart';
import 'session_filter.dart';

/// Estado da tela 1.3 "Minhas sessões".
///
/// A lista nunca vem da resposta HTTP: chega pelo stream do cache. O sync é um
/// efeito colateral que atualiza o cache — se falhar, a tela continua com o que
/// tem e só ganha uma mensagem.
class SessionsListViewModel extends ChangeNotifier {
  SessionsListViewModel({
    required SessionRepository repository,
    required ConnectivityService connectivity,
    DateTime Function()? now,
  })  : _repository = repository,
        _connectivity = connectivity,
        _now = now ?? DateTime.now;

  final SessionRepository _repository;
  final ConnectivityService _connectivity;
  final DateTime Function() _now;

  StreamSubscription<List<TrainingSession>>? _sessionsSubscription;
  StreamSubscription<DateTime?>? _syncedAtSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  List<TrainingSession> _sessions = const [];
  SessionFilter _filter = SessionFilter.hoje;
  bool _hasLoadedOnce = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  DateTime? _lastSyncedAt;

  SessionFilter get filter => _filter;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  /// Quando o cache foi atualizado pela última vez — a faixa de offline usa
  /// isso para dizer a idade do que está na tela.
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Só é carregamento antes da primeira leitura do cache. Depois disso, mesmo
  /// vazia, a tela já sabe o que mostrar — e skeleton por cima de dados velhos
  /// esconderia justamente o que o consultor precisa ver quando está offline.
  bool get isLoading => !_hasLoadedOnce;

  List<SessionGroup> get groups => groupSessions(_sessions, _filter, _now());

  Map<SessionFilter, int> get counts => {
        for (final filter in SessionFilter.values)
          filter: countFor(_sessions, filter, _now()),
      };

  /// Assina o cache e dispara o primeiro sync. Chamado uma vez pela tela.
  void init() {
    _sessionsSubscription ??= _repository.watchSessions().listen((sessions) {
      _sessions = sessions;
      _hasLoadedOnce = true;
      notifyListeners();
    });

    _syncedAtSubscription ??= _repository.watchLastSyncedAt().listen((value) {
      _lastSyncedAt = value;
      notifyListeners();
    });

    // A volta da conexão atualiza a agenda sem o consultor pedir: ele costuma
    // sair da área sem sinal já dentro do pátio, com o celular no bolso.
    _reconnectSubscription ??=
        _connectivity.onReconnected.listen((_) => refresh());

    unawaited(refresh());
  }

  void setFilter(SessionFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  /// Puxar para atualizar, abertura da tela e volta da conexão caem todos aqui.
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.syncAll();

    _isRefreshing = false;
    if (result case Failure(message: final message)) {
      _errorMessage = message ?? 'Não foi possível atualizar as sessões.';
    }
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    _syncedAtSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 8: Rodar os testes e confirmar que passam**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/ && flutter analyze`
Esperado: PASS, 12 testes nos dois arquivos, `No issues found!`.

- [ ] **Step 9: Commit**

```bash
git add apps/mobile/simtc/lib/ui/sessions/session_filter.dart apps/mobile/simtc/lib/ui/sessions/sessions_list_viewmodel.dart apps/mobile/simtc/test/ui/sessions/session_filter_test.dart apps/mobile/simtc/test/ui/sessions/sessions_list_viewmodel_test.dart
git commit -m "feat(mobile): filtros, agrupamento e estado da lista de sessoes"
```

---

## Task 6: Tela 1.3 `SessionsScreen`, rota e providers

**Files:**
- Create: `apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart`
- Modify: `apps/mobile/simtc/lib/app_providers.dart`
- Modify: `apps/mobile/simtc/lib/router.dart:5-35`
- Delete: `apps/mobile/simtc/lib/ui/home/home_placeholder_screen.dart`
- Test: `apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart`

**Interfaces:**
- Consumes: tudo das tasks anteriores, mais os widgets da Fase 1 (`SessionCard`, `StatusChip`, `FilterChipBar`, `PillNavBar`, `SkeletonBox`, `ConnectivityBanner`, `InlineNotice`).
- Produces: `SessionsScreen` (StatefulWidget sem parâmetros) e `SessionRepository` disponível no `MultiProvider`.
- A tela é o único consumidor da superfície de erro do ViewModel: ela mostra `errorMessage` num `SnackBar` e chama `clearError()`, e passa `lastSyncedAt` formatado para a `ConnectivityBanner`. Sem isso, o critério de aceite da Task 7 ("puxar para atualizar offline mostra a mensagem de falha sem apagar a lista") não teria UI que o cumprisse.

- [ ] **Step 1: Escrever o teste de widget que falha**

Criar `test/ui/sessions/sessions_screen_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/sessions/sessions_screen.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockSessionRepository repository;
  late _MockAuthRepository auth;
  late StreamController<List<TrainingSession>> sessions;
  late ConnectivityService connectivity;

  const consultor = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c1',
  );

  TrainingSession hoje() {
    return TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell Celulose',
      courseName: 'Direção Preventiva',
      city: 'Lençóis Paulista',
      state: 'SP',
      date: DateTime.now(),
      status: SessionStatus.emAndamento,
      totalParticipants: 8,
      assessableParticipants: 8,
      assessedParticipants: 2,
    );
  }

  setUp(() {
    repository = _MockSessionRepository();
    auth = _MockAuthRepository();
    sessions = StreamController<List<TrainingSession>>.broadcast();
    connectivity = ConnectivityService();

    when(repository.watchSessions).thenAnswer((_) => sessions.stream);
    when(repository.watchLastSyncedAt).thenAnswer((_) => Stream.value(null));
    when(repository.syncAll).thenAnswer((_) async => const Success(0));
    when(() => auth.currentUser).thenReturn(consultor);
  });

  tearDown(() {
    sessions.close();
    connectivity.dispose();
  });

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: repository),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: const MaterialApp(home: SessionsScreen()),
      ),
    );
  }

  /// O título é lido pelo key: o rótulo 'Sessões' da navbar tem o mesmo texto
  /// do título quando o usuário é ADMIN, e `find.text` acharia os dois.
  String titleText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('sessions-title'))).data!;

  testWidgets('mostra skeleton antes da primeira leitura do cache',
      (tester) async {
    await pump(tester);
    await tester.pump();

    expect(find.byKey(const Key('sessions-skeleton')), findsOneWidget);
    expect(find.byType(SessionCard), findsNothing);
  });

  testWidgets('mostra a sessão de hoje com o progresso', (tester) async {
    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    expect(find.byType(SessionCard), findsOneWidget);
    expect(find.text('Bracell Celulose'), findsOneWidget);
    expect(find.text('2 de 8 avaliados'), findsOneWidget);
  });

  testWidgets('saúda o consultor pelo primeiro nome e usa o título dele',
      (tester) async {
    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    expect(find.textContaining('Carla'), findsOneWidget);
    expect(titleText(tester), 'Minhas sessões');
  });

  testWidgets('para ADMIN o título é "Sessões"', (tester) async {
    when(() => auth.currentUser).thenReturn(const AuthUser(
      id: 'u2',
      name: 'Rita Alves',
      email: 'rita@simtc.com.br',
      role: AppUserRole.admin,
    ));

    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    expect(titleText(tester), 'Sessões');
  });

  testWidgets('falha ao atualizar aparece num SnackBar, sem apagar a lista',
      (tester) async {
    when(repository.syncAll)
        .thenAnswer((_) async => Failure(Exception('sem rede'), 'Sem conexão.'));

    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump(); // entrega do stream e disparo do listener
    await tester.pump(); // post-frame callback que mostra o SnackBar
    await tester.pump(const Duration(milliseconds: 750)); // animação de entrada

    expect(find.text('Sem conexão.'), findsOneWidget);
    expect(find.byType(SessionCard), findsOneWidget);
  });

  testWidgets('cache vazio mostra o estado vazio, não o skeleton',
      (tester) async {
    await pump(tester);
    sessions.add(const []);
    await tester.pump();

    expect(find.byKey(const Key('sessions-empty')), findsOneWidget);
    expect(find.byKey(const Key('sessions-skeleton')), findsNothing);
  });

  testWidgets('trocar de chip mostra a sessão do outro período', (tester) async {
    final amanha = TrainingSession(
      id: 'sess-2',
      companyName: 'Suzano Papel',
      courseName: 'Operação de Empilhadeira',
      city: 'Bauru',
      state: 'SP',
      date: DateTime.now().add(const Duration(days: 1)),
      status: SessionStatus.planejado,
      totalParticipants: 3,
      assessableParticipants: 3,
      assessedParticipants: 0,
    );

    await pump(tester);
    sessions.add([hoje(), amanha]);
    await tester.pump();

    expect(find.text('Suzano Papel'), findsNothing);

    await tester.tap(find.text('Próximos 7 dias'));
    await tester.pump();

    expect(find.text('Suzano Papel'), findsOneWidget);
    expect(find.text('Bracell Celulose'), findsNothing);
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `cd apps/mobile/simtc && flutter test test/ui/sessions/sessions_screen_test.dart`
Esperado: FAIL — `sessions_screen.dart` não existe.

- [ ] **Step 3: Escrever a tela**

Criar `lib/ui/sessions/sessions_screen.dart`. Medidas e cores saem do quadro 1.3 do canvas (linhas 767–855); nada de literal fora do Design System.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/training_session.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/filter_chip_bar.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/pill_nav_bar.dart';
import '../core/widgets/session_card.dart';
import '../core/widgets/skeleton.dart';
import '../core/widgets/status_chip.dart';
import 'session_filter.dart';
import 'sessions_list_viewmodel.dart';

/// Tela 1.3 — a Home do app.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late final SessionsListViewModel _viewModel = SessionsListViewModel(
    repository: context.read<SessionRepository>(),
    connectivity: context.read<ConnectivityService>(),
  )..init();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_showErrorWhenItArrives);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_showErrorWhenItArrives);
    _viewModel.dispose();
    super.dispose();
  }

  /// A falha de atualização é um aviso passageiro, não um estado da tela: a
  /// lista cacheada continua válida e visível. Por isso SnackBar, e por isso a
  /// mensagem é limpa assim que é agendada — limpar antes de agendar também
  /// evita reentrância, já que `clearError()` notifica de novo.
  void _showErrorWhenItArrives() {
    final message = _viewModel.errorMessage;
    if (message == null) return;
    _viewModel.clearError();

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
      builder: (context, _) => _buildScaffold(context, _viewModel),
    );
  }

  Widget _buildScaffold(BuildContext context, SessionsListViewModel viewModel) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            ConnectivityBanner(
              isOffline: isOffline,
              message: _offlineMessage(viewModel.lastSyncedAt),
            ),
            _buildFilters(viewModel),
            Expanded(child: _buildBody(viewModel)),
          ],
        ),
      ),
      bottomNavigationBar: _buildNavBar(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;
    final title = user?.isAdmin == true ? 'Sessões' : 'Minhas sessões';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm + 2,
        AppSpacing.md,
        AppSpacing.sm + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/logo-simtc.png',
                height: AppSpacing.huge + AppSpacing.md,
                semanticLabel: 'SIM Treinamentos',
              ),
              const Spacer(),
              _buildSyncIndicator(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(_greeting(user?.name), style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.xxs),
          // O key desambigua o título do rótulo 'Sessões' da navbar, que tem o
          // mesmo texto quando o usuário é ADMIN.
          Text(
            title,
            key: const Key('sessions-title'),
            style: AppTypography.screenTitle,
          ),
        ],
      ),
    );
  }

  /// Sem conexão, o consultor precisa saber a idade do que está vendo — uma
  /// lista de ontem parece igualzinha a uma de agora. Devolve nulo quando o
  /// cache nunca foi preenchido, e aí a faixa usa a mensagem padrão dela.
  String? _offlineMessage(DateTime? lastSyncedAt) {
    if (lastSyncedAt == null) return null;

    String two(int value) => value.toString().padLeft(2, '0');
    final d = lastSyncedAt;
    return 'Sem conexão — dados de ${two(d.day)}/${two(d.month)} '
        'às ${two(d.hour)}:${two(d.minute)}.';
  }

  /// Indicador de avaliações esperando envio. Fica sem badge até a Fase 4 criar
  /// a fila local; já existe para o consultor aprender onde olhar.
  Widget _buildSyncIndicator() {
    return const SizedBox(
      width: AppSpacing.touchTarget,
      height: AppSpacing.touchTarget,
      child: Icon(AppIcons.syncDone, color: AppColors.text3),
    );
  }

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final periodo = hour < 12
        ? 'Bom dia'
        : hour < 18
            ? 'Boa tarde'
            : 'Boa noite';
    final firstName = (name ?? '').trim().split(' ').first;
    return firstName.isEmpty ? periodo : '$periodo, $firstName';
  }

  Widget _buildFilters(SessionsListViewModel viewModel) {
    final counts = viewModel.counts;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: FilterChipBar(
        items: [
          for (final filter in SessionFilter.values)
            FilterChipData(label: filter.label, count: counts[filter]),
        ],
        selectedIndex: SessionFilter.values.indexOf(viewModel.filter),
        onSelect: (index) => viewModel.setFilter(SessionFilter.values[index]),
      ),
    );
  }

  Widget _buildBody(SessionsListViewModel viewModel) {
    if (viewModel.isLoading) return _buildSkeleton();

    final groups = viewModel.groups;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: viewModel.refresh,
      child: groups.isEmpty
          ? _buildEmptyState(viewModel)
          : ListView(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.huge * 2,
              ),
              children: [
                for (final group in groups) ..._buildGroup(group),
              ],
            ),
    );
  }

  List<Widget> _buildGroup(SessionGroup group) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.sm + 2,
        ),
        child: Text(
          group.title,
          style: AppTypography.meta.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      for (final session in group.sessions) _buildCard(session),
    ];
  }

  Widget _buildCard(TrainingSession session) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SessionCard(
        companyName: session.companyName,
        courseName: session.courseName,
        meta: session.meta,
        accentColor: _accentFor(session.status),
        statusChip: StatusChip(
          label: session.status.label,
          icon: _iconFor(session.status),
          tone: _toneFor(session.status),
        ),
        progressValue: session.progress,
        progressLabel: session.progressLabel,
        // O detalhe da sessão é a Fase 3; até lá o card não navega.
        onTap: null,
      ),
    );
  }

  Color _accentFor(SessionStatus status) => switch (status) {
        SessionStatus.planejado => AppColors.border,
        SessionStatus.emAndamento => AppColors.primary,
        SessionStatus.concluido => AppColors.successBorder,
        SessionStatus.cancelado => AppColors.dangerBorder,
      };

  StatusTone _toneFor(SessionStatus status) => switch (status) {
        SessionStatus.planejado => StatusTone.neutral,
        SessionStatus.emAndamento => StatusTone.info,
        SessionStatus.concluido => StatusTone.success,
        SessionStatus.cancelado => StatusTone.danger,
      };

  IconData _iconFor(SessionStatus status) => switch (status) {
        SessionStatus.planejado => AppIcons.pending,
        SessionStatus.emAndamento => AppIcons.inProgress,
        SessionStatus.concluido => AppIcons.approved,
        SessionStatus.cancelado => AppIcons.needsReview,
      };

  Widget _buildSkeleton() {
    return ListView.builder(
      key: const Key('sessions-skeleton'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 180, height: 18),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(width: 220),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(width: 140, height: 12),
          ],
        ),
      ),
    );
  }

  /// A lista precisa rolar mesmo vazia, senão o pull-to-refresh não tem o que
  /// arrastar — e é justamente quando está vazia que o consultor puxa.
  Widget _buildEmptyState(SessionsListViewModel viewModel) {
    final message = switch (viewModel.filter) {
      SessionFilter.hoje => 'Nenhuma sessão para hoje.',
      SessionFilter.proximos7 => 'Nada agendado para os próximos 7 dias.',
      SessionFilter.concluidas => 'Nenhuma sessão concluída ainda.',
    };

    return ListView(
      key: const Key('sessions-empty'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.huge),
        InlineNotice(
          icon: AppIcons.sessions,
          message: '$message Puxe para atualizar.',
        ),
      ],
    );
  }

  Widget _buildNavBar(BuildContext context) {
    return PillNavBar(
      currentIndex: 0,
      items: const [
        PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
        PillNavItem(icon: AppIcons.sync, label: 'Sincronizar'),
        PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
      ],
      onSelect: (index) {
        if (index == 0) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disponível em breve.')),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Prover o `SessionRepository`**

Em `lib/app_providers.dart`:

1. importar `import 'data/repositories/session_repository.dart';`;
2. acrescentar `required this.sessionRepository,` no construtor privado e o campo `final SessionRepository sessionRepository;`;
3. dentro de `factory AppDependencies.create`, depois da criação do `authRepository`:

```dart
    final sessionRepository = SessionRepository(
      apiClient: apiClient,
      database: database,
    );
```

4. passar `sessionRepository: sessionRepository,` no `AppDependencies._(...)`;
5. em `providers`, depois do `ChangeNotifierProvider<AuthRepository>`:

```dart
        Provider<SessionRepository>.value(value: sessionRepository),
```

`SessionRepository` entra como `Provider`, não `ChangeNotifierProvider`: quem notifica mudança é o stream do Drift, não o repository.

- [ ] **Step 5: Apontar a rota `/home` para a tela nova**

Em `lib/router.dart`, trocar o import de `ui/home/home_placeholder_screen.dart` por `ui/sessions/sessions_screen.dart` e o builder da rota:

```dart
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const SessionsScreen(),
      ),
```

Depois apagar o arquivo antigo:

```bash
rm "apps/mobile/simtc/lib/ui/home/home_placeholder_screen.dart"
```

- [ ] **Step 6: Rodar a suíte inteira e o analyze**

Run: `cd apps/mobile/simtc && flutter analyze && flutter test`
Esperado: `No issues found!` e todos os testes passando (os 56 da Fase 1 mais os novos). Se `widget_test.dart` quebrar por causa do provider novo, acrescente o `SessionRepository` ao setup dele — não remova o teste.

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/simtc/lib/ui/sessions/sessions_screen.dart apps/mobile/simtc/lib/app_providers.dart apps/mobile/simtc/lib/router.dart apps/mobile/simtc/test/ui/sessions/sessions_screen_test.dart
git add -u apps/mobile/simtc/lib/ui/home
git commit -m "feat(mobile): tela de minhas sessoes substitui a home provisoria"
```

---

## Task 8: Janela de 90 dias no backend + teste de migração que morde

Acrescentada em 20/09/2026, depois da revisão final de branch. Duas frentes, na mesma área (o que o app baixa e o banco local), num commit cada.

**Files:**
- Modify: `apps/backend/src/common/dto/pagination.dto.ts`
- Modify: `apps/backend/src/training-sessions/training-sessions.service.ts` (`findAll`)
- Modify: `apps/backend/test/training-sessions.service.spec.ts`
- Modify: `apps/mobile/simtc/lib/data/repositories/session_repository.dart`
- Modify: `apps/mobile/simtc/test/data/repositories/session_repository_test.dart`
- Modify: `apps/mobile/simtc/test/data/services/local/app_database_test.dart`

**Interfaces:**
- Consumes: `findAll` e `syncAll()` como estão hoje.
- Produces: `GET /training-sessions` aceita `from` (data ISO `YYYY-MM-DD`); `SessionRepository` passa a enviá-lo.

### Frente A — o app para de baixar a base inteira

**O problema.** `_pageSize = 50` e `_maxPages = 10` limitam o download a 500 sessões. Para `role = ADMIN`, o endpoint devolve **todas** as sessões do sistema, então a partir de 501 o admin vê uma lista permanentemente parcial, `reachedEnd` nunca fica verdadeiro, a poda nunca roda e sessões apagadas no servidor ficam no cache para sempre — tudo em silêncio. Hoje são 37 sessões; isso chega em um ou dois anos.

**A decisão do usuário (20/09/2026):** resolver de verdade agora, com filtro de data no backend, janela de **90 dias**. Filtrar por "minhas sessões" foi recusado porque contraria a decisão já tomada de que ADMIN vê tudo.

**Consequência aceita, e que precisa estar visível:** o chip "Concluídas" passa a mostrar os últimos 90 dias, não mais "qualquer data". Para um app de campo isso é mais útil que o histórico inteiro, e é o que limita o download.

- [ ] **Step 1: Escrever os testes de backend que falham**

Em `apps/backend/test/training-sessions.service.spec.ts`, acrescentar ao `describe` existente:

```ts
  it('sem `from`, não filtra por data', async () => {
    mockPrisma.trainingSession.findMany.mockResolvedValue([]);

    await service.findAll(consultant, {});

    const [[args]] = mockPrisma.trainingSession.findMany.mock.calls;
    expect(args.where.OR).toBeUndefined();
  });

  it('com `from`, traz o que é a partir da data E o que não tem data', async () => {
    mockPrisma.trainingSession.findMany.mockResolvedValue([]);

    await service.findAll(consultant, { from: '2026-06-22' });

    const [[args]] = mockPrisma.trainingSession.findMany.mock.calls;
    expect(args.where.OR).toEqual([
      { date: { gte: new Date('2026-06-22') } },
      { date: null },
    ]);
  });

  it('`from` convive com o filtro de consultor', async () => {
    mockPrisma.trainingSession.findMany.mockResolvedValue([]);

    await service.findAll(consultant, { from: '2026-06-22' });

    const [[args]] = mockPrisma.trainingSession.findMany.mock.calls;
    expect(args.where.consultants).toEqual({ some: { consultantId: 'c1' } });
    expect(args.where.OR).toHaveLength(2);
  });
```

A sessão **sem data** tem de continuar chegando: ela alimenta o grupo "Outras", que existe justamente para nenhuma sessão sumir da tela. Um filtro `date: { gte: from }` sozinho a excluiria.

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `cd apps/backend && npx jest test/training-sessions.service.spec.ts`
Esperado: FAIL nos dois últimos — `where.OR` é `undefined` porque `from` ainda não existe.

- [ ] **Step 3: Implementar o filtro**

Em `apps/backend/src/common/dto/pagination.dto.ts`, acrescentar ao `PaginationDto`:

```ts
  /** Data ISO (`YYYY-MM-DD`). Traz sessões a partir dela, mais as sem data. */
  @IsDateString()
  @IsOptional()
  from?: string;
```

e `IsDateString` ao import de `class-validator`.

Em `findAll`, logo depois do bloco `if (pagination.companyId) { ... }`:

```ts
    if (pagination.from) {
      // Sessão sem data também entra: ela alimenta o grupo "Outras" do app, que
      // existe para nenhuma sessão sumir da tela do consultor.
      where.OR = [
        { date: { gte: new Date(pagination.from) } },
        { date: null },
      ];
    }
```

- [ ] **Step 4: Rodar e confirmar que passa, e que a baseline não piorou**

Run: `cd apps/backend && npx jest test/training-sessions.service.spec.ts` → PASS, 8 testes.
Depois: `npx jest 2>&1 | tail -5` e `npx tsc --noEmit` → as mesmas **12 falhas pré-existentes**, nenhuma nova, `tsc` sem erro.

- [ ] **Step 5: Reconstruir os tipos compartilhados se você tiver mexido neles**

Run: `cd packages/shared-types && npm run build`

Só é necessário se você tiver alterado algo em `packages/shared-types/src`. O `PaginationDto` vive no backend, então provavelmente não. Confira com `git status` e não commite `dist/` sem mudança real.

- [ ] **Step 6: Commit do backend**

```bash
git add apps/backend/src/common/dto/pagination.dto.ts apps/backend/src/training-sessions/training-sessions.service.ts apps/backend/test/training-sessions.service.spec.ts
git commit -m "feat(backend): filtra sessoes por data inicial na listagem"
```

- [ ] **Step 7: Escrever o teste do app que falha**

Em `apps/mobile/simtc/test/data/repositories/session_repository_test.dart`, acrescentar:

```dart
  test('pede só a janela de 90 dias, contando a partir de hoje', () async {
    when(() => api.get<Map<String, dynamic>>('/training-sessions',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => page([], pageNumber: 1, totalPages: 1));

    await repository.syncAll();

    final captured = verify(() => api.get<Map<String, dynamic>>(
          '/training-sessions',
          queryParameters: captureAny(named: 'queryParameters'),
        )).captured.single as Map<String, dynamic>;

    final esperado = DateTime.now().subtract(const Duration(days: 90));
    final dois = (int v) => v.toString().padLeft(2, '0');
    expect(
      captured['from'],
      '${esperado.year}-${dois(esperado.month)}-${dois(esperado.day)}',
    );
  });
```

- [ ] **Step 8: Rodar e confirmar que falha**

Run: `cd apps/mobile/simtc && flutter test test/data/repositories/session_repository_test.dart`
Esperado: FAIL — `captured['from']` é nulo.

- [ ] **Step 9: Enviar a janela**

Em `lib/data/repositories/session_repository.dart`, acrescentar a constante junto das outras:

```dart
  /// Quanto passado o app carrega. Fora disso, o consultor consulta pelo painel
  /// web — baixar o histórico inteiro faria o admin, que recebe todas as sessões
  /// do sistema, estourar o teto de páginas e ficar com uma lista parcial em
  /// silêncio. Decidido com o usuário em 20/09/2026.
  static const int _historyWindowDays = 90;
```

e incluir `from` nos `queryParameters` do `syncAll()`:

```dart
        final from = DateTime.now().subtract(
          const Duration(days: _historyWindowDays),
        );
        String dois(int value) => value.toString().padLeft(2, '0');

        final response = await _api.get<Map<String, dynamic>>(
          _path,
          queryParameters: {
            'page': page,
            'limit': _pageSize,
            'from': '${from.year}-${dois(from.month)}-${dois(from.day)}',
          },
        );
```

Calcule o `from` **uma vez antes do laço**, não a cada página — uma virada de meia-noite no meio do sync mudaria o filtro entre páginas.

- [ ] **Step 10: Rodar e confirmar que passa**

Run: `cd apps/mobile/simtc && flutter test && flutter analyze`
Esperado: tudo passando e `No issues found!`. Os testes que já existiam e casavam `queryParameters` exatos vão precisar do `from` — ajuste-os, sem afrouxar as asserções.

- [ ] **Step 11: Commit do app**

```bash
git add apps/mobile/simtc/lib/data/repositories/session_repository.dart apps/mobile/simtc/test/data/repositories/session_repository_test.dart
git commit -m "feat(mobile): baixa so a janela de 90 dias de sessoes"
```

### Frente B — o teste de migração precisa morder o código de produção

**O problema.** O teste de atomicidade acrescentado na onda de correção define `_FlakyMigrationDatabase extends AppDatabase` e **sobrescreve o getter `migration` inteiro**, com uma reimplementação própria que já traz o `transaction()`. Ele prova que `transaction()` + `addColumn` do drift é atômico — verificação de premissa válida — mas não pina a mudança feita no arquivo de produção: **reverter o `transaction()` real em `app_database.dart` deixa o teste verde**.

Isso é o mesmo padrão que esta fase já rejeitou duas vezes: um teste que não falha quando a correção é revertida não protege nada.

- [ ] **Step 12: Fazer o teste exercitar o `AppDatabase` real**

Em `apps/mobile/simtc/test/data/services/local/app_database_test.dart`, reescrever o teste de atomicidade para que a migração sob teste seja a de `AppDatabase`, não uma cópia. A falha no meio da migração precisa ser injetada **de fora** do getter `migration` — por exemplo por um `QueryExecutor` que envolva o real e lance na enésima instrução `ALTER TABLE`, deixando o `migration` de produção intacto.

O critério de aceitação é comportamental, não estrutural: **tire o `transaction(...)` de `app_database.dart` e o teste tem de falhar; devolva e ele tem de passar.** Registre as duas saídas no relatório. Se você não conseguir construir uma injeção que satisfaça esse critério sem duplicar o `migration`, **não force** — reporte DONE_WITH_CONCERNS explicando o que tentou e por que não fecha, e deixe no teste um comentário dizendo exatamente o que ele cobre e o que não cobre. Um teste honesto sobre seu alcance vale mais que um que finge.

- [ ] **Step 13: Rodar a suíte e o analyze**

Run: `cd apps/mobile/simtc && flutter test && flutter analyze`

- [ ] **Step 14: Commit**

```bash
git add apps/mobile/simtc/test/data/services/local/app_database_test.dart
git commit -m "test(mobile): faz o teste de migracao cobrir o codigo de producao"
```

---

## Task 7: Validação no aparelho físico

Esta task é o portão da fase: sem ela, a Fase 3 não começa (decisão do usuário, registrada em 17/09/2026).

**Files:** nenhum arquivo de código.

**Interfaces:**
- Consumes: o app inteiro, montado pelas tasks 1–6.
- Produces: o aval do usuário para planejar a Fase 3.

- [ ] **Step 1: Subir o backend e liberar a porta para o aparelho**

Run: `cd apps/backend && npm run start:dev`

Em outro terminal, com o motorola conectado: `adb reverse tcp:3001 tcp:3001`

- [ ] **Step 2: Instalar no aparelho**

Run: `cd apps/mobile/simtc && flutter run --dart-define=API_BASE_URL=http://localhost:3001/api`

O app já tem o banco da Fase 1 instalado; a migração 1→2 da Task 2 roda sozinha na primeira abertura. **Não desinstale o app antes de testar** — a migração precisa ser exercitada com dados reais, e é exatamente isso que este passo verifica.

- [ ] **Step 3: Percorrer o roteiro de aceite**

- [ ] logar com o consultor de teste mostra as sessões reais dele, sem nenhuma sessão de outro consultor;
- [ ] o card mostra empresa, curso, `Cidade/UF · N participantes` e a barra "X de Y avaliados", com números batendo com o painel web;
- [ ] os três chips mostram contadores coerentes, e trocar de chip troca a lista sem recarregar da rede;
- [ ] uma sessão sem data ou atrasada aparece no grupo "Outras" do chip Hoje;
- [ ] puxar para atualizar busca dados novos (mudar algo no painel web e confirmar que aparece);
- [ ] ativar o modo avião e reabrir o app ainda mostra a última lista cacheada, com a faixa de "sem conexão";
- [ ] ainda offline, puxar para atualizar mostra a mensagem de falha **sem** apagar a lista;
- [ ] desativar o modo avião com o app aberto atualiza a lista sozinho;
- [ ] tocar em "Sincronizar" ou "Perfil" mostra "Disponível em breve" sem quebrar nada;
- [ ] logar com um usuário ADMIN mostra o título "Sessões".

- [ ] **Step 4: Registrar o resultado**

Se tudo passar, avisar o usuário e pedir o aval para planejar a Fase 3. Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio ou de contrato do backend, parar e perguntar.

---

## Pendências levadas para as fases seguintes

| Fase | Pendência |
|---|---|
| 3 | O card ainda não navega (`onTap: null`). A Fase 3 liga o toque à tela 1.4 de detalhe da sessão. |
| 4 | O indicador de sincronização do cabeçalho não tem badge — ganha a contagem real quando a fila local existir. |
| 5 | A aba "Sincronizar" da navbar está desabilitada. |
| 7 | A aba "Perfil" está desabilitada, e o botão "Sair" saiu junto com a `HomePlaceholderScreen`. **Até a tela de Perfil existir não há como deslogar pela interface** — para trocar de usuário no teste, limpe os dados do app nas configurações do Android. |
| 8 | Busca no cabeçalho (o canvas tem a lupa; não existe endpoint). Contraste do item ativo da navbar (2,3:1, herdado da Fase 1). |
