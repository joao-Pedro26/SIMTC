# App Mobile SIMTC — Fase 8D-1: O servidor confere as regras — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O backend passa a conferir sozinho as regras que hoje só as telas do app e do web aplicam — envio de avaliação inteiro ou nada, atribuir e desatribuir só no estado certo e sem corrida, ciclo de vida da sessão, liberação de quem fica "em avaliação" sem dono, adicionar participante sem cadastro duplicado nem gravação na recusa, leitura de avaliação só para quem pode — e a suíte do backend volta a ficar toda verde; depois, com o OK do usuário, isso vai para a produção.

**Architecture:** Só o backend muda (NestJS + Prisma), sem migração e sem mudança de esquema. As gravações que dependem de uma leitura passam a ser condicionais: um `updateMany` com a condição no `where` e a contagem conferida, dentro de uma transação interativa (`$transaction(async (tx) => …)`) que desfaz tudo e responde 409 se alguma linha mudou no meio. A liberação de participantes ganha uma forma geral (`releaseHeldParticipants(tx, where)`), usada ao tirar um consultor da sessão, ao excluí-lo e ao cancelar a sessão. O app e o web não mudam: os dois já mostram a mensagem do servidor nas recusas 400, 403 e 409.

**Tech Stack:** NestJS 10 · Prisma 7 · class-validator 0.14 · Jest 29 com ts-jest. Nenhuma dependência nova.

**Spec:** `apps/mobile/docs/superpowers/specs/2026-10-24-mobile-fase-8-design.md`, seção "Desenho da 8D" (itens 1 a 11 da 8D-1 e "Respostas à leitura de quem planeja"), aprovado pelo usuário em 27/10/2026 ("ok, pode seguir com o plano da 8D-1").

**Validação prévia:** todo o código das Tasks 1 a 5 foi escrito e rodado numa cópia descartável do backend antes de o plano ser fechado, uma task por commit, e depois as tasks foram **reencenadas em ordem** numa segunda cópia limpa, a partir dos blocos deste plano: em cada task, os testes da task falharam antes da implementação e passaram depois (a Task 1 só tem testes: a falha é a das 12 antigas), e cada checkpoint bateu o número de testes — **120 (12 falhando) → 120 → 128 → 136 → 148 → 156**, com `npx tsc --noEmit` limpo em todos; a árvore de cada task ficou **idêntica** à do commit correspondente. **Cada regra foi conferida por mutação** (o trecho é trocado por uma versão errada, e algum teste tem de falhar): **38 mutações, todas acusadas**. Três sobreviveram na primeira rodada e levaram a testes mais firmes: o cancelar gravando fora da transação (o teste passou a dar à transação um `tx` próprio), a exclusão do consultor liberando depois de apagar a referência (o teste passou a conferir a ordem) e o formulário público conferindo a inscrição com o token, e não com o id da sessão. O backend não roda contra um banco nesta máquina: a prova de ponta a ponta é a validação contra a produção (Task 7).

## Decisões tomadas com o usuário

Do "Desenho da 8D" (27/10/2026), que o usuário aprovou depois de pedir a análise "pelo bom senso, como na 8C":

1. **Envio numa transação:** apagar os itens anteriores, gravar a avaliação, a nota e o status do participante — tudo ou nada.
2. **Atribuir** só com a sessão `EM_ANDAMENTO`, nunca um participante `SOMENTE_TEORICA`, e a gravação confere de novo o que foi lido.
3. **Iniciar** só `PLANEJADO`; **concluir** só `EM_ANDAMENTO`.
4. **Cancelar a sessão** libera quem estava "em avaliação".
5. **Excluir um consultor** libera quem estava "em avaliação" com ele.
6. **O envio continua aceito com a sessão concluída** (nada muda; fica dito no código).
7. **Adicionar participante:** CPF gravado só com dígitos; nome e e-mail do cadastro só mudam depois de passar pela recusa "CPF já inscrito"; e-mail conferido como e-mail.
8. **Ler uma avaliação** (`GET /practical-assessments/:id` e `…/by-participant/:id`) só ADMIN e CONSULTANT; id inexistente dá 404.
9. **Desatribuir:** a gravação confere de novo; o participante que sumiu no meio dá 409, e não 500; ids repetidos deixam de dar recusa enganosa.
10. **Os 12 testes antigos voltam a ficar verdes**, consertando os testes (sem mexer no código de produção).
11. **`apps/backend/CLAUDE.md`** ganha a rota de consulta de CPF.

E das respostas do desenho: os "em avaliação" que já existem presos na produção ficam como estão (o "Desatribuir" do ADMIN os libera); o status de volta sai da nota anterior (`statusAfterRelease`), sem mudança de esquema; a avaliação de campo enviada depois de cancelar a sessão ou excluir o consultor é recusada item a item (`NOT_ASSIGNED`), e a aba Sincronizar oferece o "Descartar". **Publicação:** só com o OK do usuário, e a validação roda contra a produção.

### Ajustes feitos ao preparar o plano (revisar junto com o plano)

Nenhum muda regra aprovada.

- **Os códigos das recusas novas** seguem os que o app já trata com a mensagem do servidor: **409** no atribuir e no desatribuir (o app e o web mostram o motivo), **403** no iniciar e no concluir fora do status (é o código que o iniciar já usa para o consultor que não é o responsável, e o app mostra a mensagem dele), **404** na avaliação que não existe e **400** "E-mail inválido".
- **Textos novos do servidor:** "Só dá para atribuir participantes com o treinamento em andamento"; "Participantes somente da parte teórica não têm avaliação prática"; "Um ou mais participantes mudaram de situação. Atualize a lista e tente de novo."; "Só dá para iniciar um treinamento planejado"; "Só dá para concluir um treinamento em andamento"; "Avaliação não encontrada"; "E-mail inválido".
- **A gravação condicional do atribuir** pega todos os participantes do pedido de uma vez (`updateMany` com `status` diferente de `APROVADO` e "fora de avaliação ou já comigo") e confere a contagem; a do **desatribuir** vai participante por participante (cada um volta a um status próprio, que depende da nota anterior). Nos dois, a transação desfaz tudo se a contagem não bater.
- **O formulário público do QR Code** (`POST /public/register/:qrToken`) usa a mesma função de cadastro do adicionar, então ganha a mesma ordem: uma inscrição recusada por "CPF já inscrito" não muda mais o cadastro. *(escolha minha: é o mesmo defeito, na mesma função.)* O formulário público continua sem a validação de CPF do pipe — isso é do web, que fica fora da 8D.
- **A sessão que não existe dá 404 também para o ADMIN** no iniciar e no concluir: antes, o ADMIN pulava a leitura da sessão e recebia um 500 do Prisma.
- **A regra de e-mail do app é um pouco mais frouxa que a do servidor:** alguns erros de digitação que o app aceita (`a@b.c`, `maria@empresa..com`, `m@x.com.`) passam a ser recusados pelo servidor com "E-mail inválido", que a tela 1.11 mostra. Endereços comuns passam nos dois. Alinhar a regra do app fica como observação para a 8D-2.
- **`apps/backend/CLAUDE.md` não é versionado** (está no `.gitignore`): a atualização dele é feita pelo controlador na Task 6, sem commit.

## Review Focus

- **Dois aparelhos atribuindo o mesmo participante ao mesmo tempo** (dois consultores, ou o app e o web): só um fica com ele; o outro recebe 409 com o motivo, e ninguém fica "em avaliação" pela metade — Task 3, teste da contagem que não bate.
- **O ADMIN desatribui enquanto o consultor envia a avaliação:** se o envio chegar primeiro, o desatribuir recebe 409 "mudaram de situação", e não 500 — Task 3.
- **O consultor avalia sem rede e o ADMIN conclui a sessão antes do envio:** o envio continua aceito — Task 2, teste da sessão concluída.
- **Uma falha no meio de uma reavaliação** (por exemplo, a conexão com o banco cai depois de apagar os itens): nada fica gravado pela metade — Task 2, teste da falha no meio.
- **Um pedido com o CPF com máscara** (o app e o web de hoje já mandam só dígitos, mas a API aceita os dois): reaproveita o cadastro, sem criar um segundo — Task 5, teste do controller.

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app`. Sem git worktree. Não criar branch. **Push e avanço da `feat/frontend-backend-integration` só na Task 6, cada um com o OK do usuário naquele momento.**
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final, sem acento e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada, com a mensagem exata dada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`. O working tree tem trabalho do usuário fora do git, que **não é desta fase e fica exatamente como está**: um arquivo rastreado **já modificado** (`brainstorm-app-mobile.md`) e os não rastreados `.vscode/`, `IMPLEMENTATION-STATUS.md`, `apps/backend/test-render.js`, `apps/mobile/simtc/devtools_options.yaml`, `apps/web/src/app/(client)/my-company/trainings/[id]/certificates/`, `brainstorm-implementacao-mobile.md`, `prompt-claude-design-mobile.md`, `prompt-implementacao-mobile-claude-code.md`, `test-pdf.js` e `test-render.js`.
- **Proibido `git restore`, `git checkout -- <arquivo>`, `git stash`, `git reset` e `git clean`**, e qualquer outro comando que desfaça mudança que não é da task. Se o `git status` mostrar algo que não é da task, ignorar e seguir.
- **Na execução por subagentes:** antes do primeiro despacho, guardar a linha de base — o `git status --porcelain` inteiro e o `git hash-object brainstorm-app-mobile.md` — e compará-la, sem filtrar nada, depois de **cada** subagente. Todo despacho repete as duas regras acima com todas as letras. Implementadores em **haiku**; revisões em **sonnet**; revisão final em **opus**.
- **Banco e produção:** nada de `prisma migrate`, `prisma db push`, `seed` ou script contra banco nenhum. Esta fase não tem migração.
- Não avançar com teste falhando ou `npx tsc --noEmit` com erro. **Não rodar `npm run lint`** (ele tem `--fix` e reescreveria arquivos fora da task).
- Ambiguidade de regra de negócio ou lacuna de contrato → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-10-27-mobile-fase-8d1-servidor-confere-regras/`.

**Backend**
- Os comandos `npx jest` e `npx tsc --noEmit` rodam a partir de `apps/backend/`. O `tsc` escreve `apps/backend/dist/tsconfig.tsbuildinfo`, que é ignorado pelo git: não adicionar.
- Todos os caminhos dos blocos são relativos a `apps/backend/`. Os `git add`/`git commit` rodam **da raiz do repositório**, com os caminhos completos dados.
- Os textos de recusa são exatamente os dos blocos (o app mostra a mensagem do servidor ao usuário).
- Nenhum formatador (`prettier`, `eslint --fix`): os blocos já vêm no formato certo.
- Posição dos testes novos: cada bloco de teste entra **no lugar que o plano dá** (o "substituir / por" diz onde), e não no fim do arquivo.
- No passo "Rodar e ver falhar", um arquivo de teste que não compila aparece como `Tests: 0 total` com o erro `TS…`: é a falha esperada quando o passo a cita.


## Task 1: Os testes antigos do backend voltam a ficar verdes

As 12 falhas de sempre vêm de testes desatualizados, e não de código errado: o `sendOtpCode` ganhou um terceiro argumento (o nome de quem recebe), e o `ParticipantsService` passou a receber `EmailService` e `StorageService` e a usar `participant.update`, `deleteMany`, `trainingParticipant.findMany` e uma transação interativa. Só os testes mudam; o código de produção fica como está (decisão do desenho). Esta task vem primeiro para que cada task seguinte possa exigir a suíte inteira verde.

**Files:**
- Modify: `test/auth.service.spec.ts`
- Modify: `test/participants.service.spec.ts`

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces:
  - a suíte do backend inteira verde: 120 testes
  - no `test/participants.service.spec.ts`, o `mockPrisma` com `participant.update`/`deleteMany`, `trainingParticipant.findMany` e `$transaction` que roda a função com o próprio mock no papel do `tx` — a Task 5 acrescenta testes nesse arquivo

- [ ] **Step 1: Rodar e ver as falhas antigas**

Run (em `apps/backend/`): `npx jest test/auth.service.spec.ts test/participants.service.spec.ts`
Esperado: `Tests: 12 failed, 12 passed, 24 total` — um em `AuthService › requestOtp` (o `sendOtpCode` sem o terceiro argumento) e onze em `ParticipantsService` (`Nest can't resolve dependencies` e mocks que faltam).

- [ ] **Step 2: Consertar os testes**

Em `test/auth.service.spec.ts`, substituir:

```ts
      expect(mockEmail.sendOtpCode).toHaveBeenCalledWith('c@c.com', expect.any(String));
```

por:

```ts
      // O terceiro argumento é o nome de quem recebe (um espaço, sem nome).
      expect(mockEmail.sendOtpCode).toHaveBeenCalledWith('c@c.com', expect.any(String), expect.any(String));
```

Em `test/participants.service.spec.ts`, substituir:

```ts
import { PrismaService } from 'src/prisma/prisma.service';

const mockPrisma = {
  trainingSession: { findUniqueOrThrow: jest.fn(), findUnique: jest.fn() },
  participant: { findUnique: jest.fn(), create: jest.fn() },
  trainingParticipant: { findUnique: jest.fn(), create: jest.fn(), findMany: jest.fn(), update: jest.fn(), delete: jest.fn() },
};
```

por:

```ts
import { PrismaService } from 'src/prisma/prisma.service';
import { EmailService } from 'src/email/email.service';
import { StorageService } from 'src/storage/storage.service';

const mockPrisma = {
  trainingSession: { findUniqueOrThrow: jest.fn(), findUnique: jest.fn() },
  participant: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn(), deleteMany: jest.fn() },
  trainingParticipant: { findUnique: jest.fn(), create: jest.fn(), findMany: jest.fn(), update: jest.fn(), delete: jest.fn() },
  // A transação interativa roda com o próprio mock no papel do `tx`.
  $transaction: jest.fn((fn: (tx: unknown) => unknown) => fn(mockPrisma)),
};
```

Em `test/participants.service.spec.ts`, substituir:

```ts
      ],
    }).compile();

    service = module.get<ParticipantsService>(ParticipantsService);
    jest.clearAllMocks();
```

por:

```ts
        // O serviço passou a mandar e-mail e guardar arquivos: nos testes,
        // os dois só precisam existir.
        { provide: EmailService, useValue: {} },
        { provide: StorageService, useValue: {} },
      ],
    }).compile();

    service = module.get<ParticipantsService>(ParticipantsService);
    jest.clearAllMocks();
    mockPrisma.trainingParticipant.findMany.mockResolvedValue([]);
```

Em `test/participants.service.spec.ts`, substituir:

```ts
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-1' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });
      await expect(service.registerPublic('token', dto as any)).rejects.toThrow(ConflictException);
```

por:

```ts
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-1' });
      mockPrisma.participant.update.mockResolvedValue({ id: 'part-1' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });
      await expect(service.registerPublic('token', dto as any)).rejects.toThrow(ConflictException);
```

Em `test/participants.service.spec.ts`, substituir:

```ts
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-existente' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);
```

por:

```ts
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-existente' });
      mockPrisma.participant.update.mockResolvedValue({ id: 'part-existente' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);
```

Em `test/participants.service.spec.ts`, substituir:

```ts
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-1' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });
```

por:

```ts
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-1' });
      mockPrisma.participant.update.mockResolvedValue({ id: 'part-1' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });
```

- [ ] **Step 3: Rodar e ver passar**

Run (em `apps/backend/`): `npx jest test/auth.service.spec.ts test/participants.service.spec.ts`
Esperado: `Tests: 24 passed, 24 total`

- [ ] **Step 4: Conferir o backend inteiro**

Run (em `apps/backend/`): `npx tsc --noEmit` e depois `npx jest`
Esperado: nenhuma saída do `tsc`, e `Tests: 120 passed, 120 total`

- [ ] **Step 5: Commit**

```bash
git add apps/backend/test/auth.service.spec.ts apps/backend/test/participants.service.spec.ts
git commit -m "test(backend): testes antigos do backend voltam a ficar verdes"
```

---

## Task 2: Envio de avaliação numa transação e leitura só para ADMIN e CONSULTANT

Itens 1, 6 e 8 do desenho. O `syncOne` grava tudo numa transação só: apagar os itens anteriores, criar ou atualizar a avaliação, a nota e o status do participante (`applyScore` passa a receber o `tx`). Uma falha no meio de uma reavaliação deixava a avaliação aceita sem itens. O envio continua aceito com a sessão já concluída, e isso fica dito num comentário. As duas leituras (`GET /practical-assessments/:id` e `…/by-participant/:id`) passam a exigir ADMIN ou CONSULTANT, e um id que não existe devolve 404 "Avaliação não encontrada", e não 500.

**Files:**
- Modify: `src/practical-assessments/practical-assessments.controller.ts`
- Modify: `src/practical-assessments/practical-assessments.service.ts`
- Modify: `test/practical-assessments.service.spec.ts`

**Interfaces:**
- Consumes: a suíte verde da Task 1.
- Produces:
  - `PracticalAssessmentsService.applyScore(tx: Prisma.TransactionClient, assessmentId, items, trainingParticipantId)` (privado)
  - `findOne(id)` assíncrono, com `NotFoundException('Avaliação não encontrada')`
  - no `test/practical-assessments.service.spec.ts`, o `mockPrisma.$transaction` que roda a função com um `tx` — a Task 3 acrescenta testes nesse arquivo

- [ ] **Step 1: Escrever os testes que falham**

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
import { ConflictException } from '@nestjs/common';
```

por:

```ts
import { ConflictException, NotFoundException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from 'src/auth/decorators/roles.decorator';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { RolesGuard } from 'src/auth/guards/roles.guard';
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
  JwtPayload,
} from '@simtc/shared-types';
```

por:

```ts
  JwtPayload,
  UserRole,
} from '@simtc/shared-types';
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
      mockPrisma.assessmentCategory.findMany.mockResolvedValue([]);
      mockPrisma.$transaction.mockResolvedValue([]);
      // Quem envia está com o participante: é o caso de todo envio normal.
```

por:

```ts
      mockPrisma.assessmentCategory.findMany.mockResolvedValue([]);
      // A transação interativa roda com o próprio mock no papel do `tx`.
      mockPrisma.$transaction.mockImplementation((fn: (tx: unknown) => unknown) => fn(mockPrisma));
      // Quem envia está com o participante: é o caso de todo envio normal.
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
      expect(result[0]).toMatchObject({ status: 'fulfilled' });
    });
```

por:

```ts
      expect(result[0]).toMatchObject({ status: 'fulfilled' });
    });

    describe('numa transação só (Fase 8D-1)', () => {
      /** O cliente da transação, separado do `mockPrisma`: o que for gravado
       * fora dela aparece no `mockPrisma`. */
      const tx = {
        practicalAssessment: { create: jest.fn(), update: jest.fn() },
        assessmentItem: { deleteMany: jest.fn() },
        assessmentCategory: { findMany: jest.fn() },
        trainingParticipant: { update: jest.fn() },
      };

      beforeEach(() => {
        Object.values(tx).forEach((model) =>
          Object.values(model).forEach((fn) => fn.mockReset()),
        );
        tx.assessmentCategory.findMany.mockResolvedValue([]);
        mockPrisma.$transaction.mockImplementation((fn: (t: unknown) => unknown) => fn(tx));
      });

      it('a reavaliação apaga os itens, regrava a avaliação e calcula a nota dentro dela', async () => {
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ id: 'assess-1' });
        tx.practicalAssessment.update.mockResolvedValue({ id: 'assess-1', items: [] });

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result[0]).toMatchObject({ status: 'fulfilled' });
        expect(tx.assessmentItem.deleteMany).toHaveBeenCalledWith({ where: { assessmentId: 'assess-1' } });
        expect(tx.practicalAssessment.update).toHaveBeenCalledWith(
          expect.objectContaining({ data: expect.objectContaining({ score: null }) }),
        );
        expect(tx.practicalAssessment.update).toHaveBeenCalledWith({
          where: { id: 'assess-1' },
          data: { score: 100 },
        });
        expect(tx.trainingParticipant.update).toHaveBeenCalledWith({
          where: { id: 'tp-1' },
          data: { status: 'APROVADO', assignedConsultantId: null },
        });
        expect(mockPrisma.assessmentItem.deleteMany).not.toHaveBeenCalled();
        expect(mockPrisma.practicalAssessment.update).not.toHaveBeenCalled();
        expect(mockPrisma.trainingParticipant.update).not.toHaveBeenCalled();
      });

      it('a primeira avaliação é criada e recebe a nota dentro dela', async () => {
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);
        tx.practicalAssessment.create.mockResolvedValue({ id: 'assess-1', items: [] });

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result[0]).toMatchObject({ status: 'fulfilled' });
        expect(tx.practicalAssessment.create).toHaveBeenCalled();
        expect(tx.trainingParticipant.update).toHaveBeenCalled();
        expect(mockPrisma.practicalAssessment.create).not.toHaveBeenCalled();
      });

      it('uma falha no meio recusa o item, e a nota não é gravada fora da transação', async () => {
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ id: 'assess-1' });
        tx.practicalAssessment.update.mockRejectedValue(new Error('falha no banco'));

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result).toEqual([
          { trainingParticipantId: 'tp-1', status: 'rejected', error: 'falha no banco' },
        ]);
        expect(tx.trainingParticipant.update).not.toHaveBeenCalled();
        expect(mockPrisma.trainingParticipant.update).not.toHaveBeenCalled();
      });
    });

    it('aceita o envio de quem está com o participante sem olhar o status da sessão: '
      + 'a avaliação de campo não se perde se a sessão foi concluída antes do envio (Fase 8D-1)', async () => {
      // O mock não tem `trainingSession`: se o envio lesse a sessão, quebraria.
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);
      mockPrisma.practicalAssessment.create.mockResolvedValue({ id: 'assess-1', items: [] });

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result).toEqual([{ trainingParticipantId: 'tp-1', status: 'fulfilled' }]);
    });
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
});

describe('PracticalAssessmentsController.unassign', () => {
  it('passa o papel de quem pediu: é ele que deixa o ADMIN liberar participante de outro consultor', () => {
```

por:

```ts
});

describe('PracticalAssessmentsService.findOne (Fase 8D-1)', () => {
  it('uma avaliação que não existe é 404, e não 500', async () => {
    const prisma = { practicalAssessment: { findUnique: jest.fn().mockResolvedValue(null) } };
    const service = new PracticalAssessmentsService(prisma as unknown as PrismaService);

    await expect(service.findOne('nao-existe')).rejects.toThrow(NotFoundException);
  });
});

describe('PracticalAssessmentsController: quem lê uma avaliação (Fase 8D-1)', () => {
  // As duas leituras devolvem notas e infrações: só ADMIN e CONSULTANT. O
  // `JwtAuthGuard` está na classe; o `RolesGuard`, que lê o papel, nos métodos.
  const reflector = new Reflector();

  it.each([
    ['findByParticipant', PracticalAssessmentsController.prototype.findByParticipant],
    ['findOne', PracticalAssessmentsController.prototype.findOne],
  ])('%s exige ADMIN ou CONSULTANT, pelo RolesGuard', (_name, handler) => {
    expect(reflector.get<UserRole[]>(ROLES_KEY, handler)).toEqual([
      UserRole.ADMIN,
      UserRole.CONSULTANT,
    ]);
    expect(reflector.get(GUARDS_METADATA, handler)).toEqual([RolesGuard]);
  });

  it('a classe continua exigindo o login', () => {
    expect(reflector.get(GUARDS_METADATA, PracticalAssessmentsController)).toEqual([JwtAuthGuard]);
  });
});

describe('PracticalAssessmentsController.unassign', () => {
  it('passa o papel de quem pediu: é ele que deixa o ADMIN liberar participante de outro consultor', () => {
```

- [ ] **Step 2: Rodar e ver falhar**

Run (em `apps/backend/`): `npx jest test/practical-assessments.service.spec.ts`
Esperado: `Tests: 10 failed, 34 passed, 44 total` — os testes novos do envio (as gravações não passam pelo `tx`), o 404 e os papéis das duas rotas de leitura.

- [ ] **Step 3: Implementar**

Em `src/practical-assessments/practical-assessments.controller.ts`, substituir:

```ts
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtPayload, SyncPracticalAssessmentDto } from '@simtc/shared-types';
```

por:

```ts
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtPayload, SyncPracticalAssessmentDto, UserRole } from '@simtc/shared-types';
```

Em `src/practical-assessments/practical-assessments.controller.ts`, substituir:

```ts
  @Get('by-participant/:trainingParticipantId')
  @ApiOperation({ summary: 'Retorna avaliação existente do participante, ou null' })
  findByParticipant(@Param('trainingParticipantId') trainingParticipantId: string) {
    return this.service.findByParticipant(trainingParticipantId);
  }

  @Get(':id')
```

por:

```ts
  // As leituras devolvem notas e infrações: só ADMIN e CONSULTANT, e não um
  // CLIENT de outra empresa (Fase 8D-1 do app mobile).
  @Get('by-participant/:trainingParticipantId')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  @ApiOperation({ summary: 'Retorna avaliação existente do participante, ou null' })
  findByParticipant(@Param('trainingParticipantId') trainingParticipantId: string) {
    return this.service.findByParticipant(trainingParticipantId);
  }

  @Get(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
```

Em `src/practical-assessments/practical-assessments.service.ts`, substituir:

```ts
import { Injectable, ConflictException } from '@nestjs/common';
```

por:

```ts
import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
```

Em `src/practical-assessments/practical-assessments.service.ts`, substituir:

```ts
    }
    const isWithSender =
```

por:

```ts
    }
    // O status da sessão não conta (Fase 8D-1): o consultor avalia sem rede e
    // envia depois, e uma sessão concluída pelo ADMIN no fim do dia, antes do
    // envio, faria a avaliação de campo se perder. Basta o participante
    // continuar com quem envia.
    const isWithSender =
```

Em `src/practical-assessments/practical-assessments.service.ts`, substituir:

```ts
    if (existing) {
      // Reavaliação: apaga os itens anteriores e atualiza o registro
      await this.prisma.assessmentItem.deleteMany({
        where: { assessmentId: existing.id },
      });

      const updated = await this.prisma.practicalAssessment.update({
        where: { id: existing.id },
        data: {
          consultantId,
          date: new Date(dto.date),
          startTime: new Date(dto.startTime),
          endTime: dto.endTime ? new Date(dto.endTime) : null,
          synced: true,
          score: null, // resetar até calcular abaixo
          items: {
            create: dto.items.map((item) => ({ infractionNoteId: item.infractionNoteId })),
          },
        },
        include: {
          items: {
            include: {
              infractionNote: {
                include: { infraction: { include: { category: true } } },
              },
            },
          },
        },
      });

      await this.applyScore(updated.id, updated.items, dto.trainingParticipantId);
      return updated;
    } else {
      // Primeira avaliação
      const assessment = await this.prisma.practicalAssessment.create({
```

por:

```ts
    // Tudo numa transação só (Fase 8D-1): uma falha no meio de uma
    // reavaliação deixava a avaliação aceita sem itens.
    return this.prisma.$transaction(async (tx) => {
      if (existing) {
        // Reavaliação: apaga os itens anteriores e atualiza o registro
        await tx.assessmentItem.deleteMany({
          where: { assessmentId: existing.id },
        });

        const updated = await tx.practicalAssessment.update({
          where: { id: existing.id },
          data: {
            consultantId,
            date: new Date(dto.date),
            startTime: new Date(dto.startTime),
            endTime: dto.endTime ? new Date(dto.endTime) : null,
            synced: true,
            score: null, // resetar até calcular abaixo
            items: {
              create: dto.items.map((item) => ({ infractionNoteId: item.infractionNoteId })),
            },
          },
          include: {
            items: {
              include: {
                infractionNote: {
                  include: { infraction: { include: { category: true } } },
                },
              },
            },
          },
        });

        await this.applyScore(tx, updated.id, updated.items, dto.trainingParticipantId);
        return updated;
      }

      // Primeira avaliação
      const assessment = await tx.practicalAssessment.create({
```

Em `src/practical-assessments/practical-assessments.service.ts`, substituir:

```ts
      await this.applyScore(assessment.id, assessment.items, dto.trainingParticipantId);
      return assessment;
    }
  }

  /** Calcula score e atualiza o assessment + status do participante */
  private async applyScore(
```

por:

```ts
      await this.applyScore(tx, assessment.id, assessment.items, dto.trainingParticipantId);
      return assessment;
    });
  }

  /** Calcula score e atualiza o assessment + status do participante, na
   * transação do envio. */
  private async applyScore(
    tx: Prisma.TransactionClient,
```

Em `src/practical-assessments/practical-assessments.service.ts`, substituir:

```ts
    const allCategories = await this.prisma.assessmentCategory.findMany({
```

por:

```ts
    const allCategories = await tx.assessmentCategory.findMany({
```

Em `src/practical-assessments/practical-assessments.service.ts`, substituir:

```ts
    await this.prisma.$transaction([
      this.prisma.practicalAssessment.update({
        where: { id: assessmentId },
        data: { score: overallScore },
      }),
      this.prisma.trainingParticipant.update({
        where: { id: trainingParticipantId },
        data: { status, assignedConsultantId: null },
      }),
    ]);
  }

  findOne(id: string) {
    return this.prisma.practicalAssessment.findUniqueOrThrow({
```

por:

```ts
    await tx.practicalAssessment.update({
      where: { id: assessmentId },
      data: { score: overallScore },
    });
    await tx.trainingParticipant.update({
      where: { id: trainingParticipantId },
      data: { status, assignedConsultantId: null },
    });
  }

  /** Um id que não existe é 404, e não o 500 do `findUniqueOrThrow` (Fase 8D-1). */
  async findOne(id: string) {
    const assessment = await this.prisma.practicalAssessment.findUnique({
```

Em `src/practical-assessments/practical-assessments.service.ts`, substituir:

```ts
        },
      },
    });
  }

  /** Retorna avaliação existente do participante, ou null se não houver */
```

por:

```ts
        },
      },
    });
    if (!assessment) throw new NotFoundException('Avaliação não encontrada');
    return assessment;
  }

  /** Retorna avaliação existente do participante, ou null se não houver */
```

- [ ] **Step 4: Rodar e ver passar**

Run (em `apps/backend/`): `npx jest test/practical-assessments.service.spec.ts`
Esperado: `Tests: 44 passed, 44 total`

- [ ] **Step 5: Conferir o backend inteiro**

Run (em `apps/backend/`): `npx tsc --noEmit` e depois `npx jest`
Esperado: nenhuma saída do `tsc`, e `Tests: 128 passed, 128 total`

- [ ] **Step 6: Commit**

```bash
git add apps/backend/src/practical-assessments/practical-assessments.controller.ts apps/backend/src/practical-assessments/practical-assessments.service.ts apps/backend/test/practical-assessments.service.spec.ts
git commit -m "fix(practical-assessments): envio numa transacao e leitura so para admin e consultor"
```

---

## Task 3: Atribuir e desatribuir conferem as regras na gravação

Itens 2 e 9 do desenho. **Atribuir:** ids repetidos contam uma vez só; só com o treinamento em andamento ("Só dá para atribuir participantes com o treinamento em andamento"); nunca quem é somente da parte teórica ("Participantes somente da parte teórica não têm avaliação prática"); e a gravação é um `updateMany` condicional numa transação, que confere de novo que o participante não foi aprovado nem pego por outro consultor entre a leitura e a gravação — se não pegar todos, a transação desfaz e responde 409. **Desatribuir:** ids repetidos contam uma vez só; cada liberação é um `updateMany` que confere de novo que o participante continua em avaliação com o mesmo consultor lido; se algum mudou, a transação desfaz tudo e responde 409 "Um ou mais participantes mudaram de situação. Atualize a lista e tente de novo.", e não 500.

**Files:**
- Modify: `src/practical-assessments/practical-assessments.service.ts`
- Modify: `test/practical-assessments.service.spec.ts`

**Interfaces:**
- Consumes: `test/practical-assessments.service.spec.ts` da Task 2.
- Produces:
  - recusas novas (409): 'Só dá para atribuir participantes com o treinamento em andamento', 'Participantes somente da parte teórica não têm avaliação prática' e 'Um ou mais participantes mudaram de situação. Atualize a lista e tente de novo.'
  - o `assign` lê os participantes com `include: { training: { select: { status: true } } }`

- [ ] **Step 1: Escrever os testes que falham**

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
    it('lança ConflictException se algum participante não existe', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'PENDENTE', assignedConsultantId: null },
      ]);
```

por:

```ts
    /** Um participante, na sessão em andamento e com parte prática, a menos
     * que o teste diga outra coisa. */
    const record = (overrides: Record<string, unknown> = {}) => ({
      id: 'tp-1',
      status: 'PENDENTE',
      assignedConsultantId: null,
      participationType: 'TEORICA_E_PRATICA',
      training: { status: 'EM_ANDAMENTO' },
      ...overrides,
    });

    /** O cliente da transação: a gravação condicional acontece nele. */
    const tx = { trainingParticipant: { updateMany: jest.fn() } };

    beforeEach(() => {
      tx.trainingParticipant.updateMany.mockReset();
      mockPrisma.$transaction.mockImplementation((fn: (t: unknown) => unknown) => fn(tx));
    });

    it('lança ConflictException se algum participante não existe', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([record()]);
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'outro-consultor' },
      ]);
      await expect(
        service.assignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor'),
      ).rejects.toThrow(ConflictException);
    });

    it('atribui participantes ao consultor corretamente', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'PENDENTE', assignedConsultantId: null },
        { id: 'tp-2', status: 'PENDENTE', assignedConsultantId: null },
      ]);
      mockPrisma.trainingParticipant.updateMany.mockResolvedValue({ count: 2 });
```

por:

```ts
        record({ status: 'EM_AVALIACAO', assignedConsultantId: 'outro-consultor' }),
      ]);
      await expect(
        service.assignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor'),
      ).rejects.toThrow(ConflictException);
    });

    it('atribui participantes ao consultor corretamente, com a condição na própria gravação', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([record(), record({ id: 'tp-2' })]);
      tx.trainingParticipant.updateMany.mockResolvedValue({ count: 2 });
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
      expect(mockPrisma.trainingParticipant.updateMany).toHaveBeenCalledWith({
        where: { id: { in: ['tp-1', 'tp-2'] } },
        data: { assignedConsultantId: 'consultant-1', status: 'EM_AVALIACAO' },
      });
    });

    it('permite reatribuir participante ao mesmo consultor', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor' },
      ]);
      mockPrisma.trainingParticipant.updateMany.mockResolvedValue({ count: 1 });
```

por:

```ts
      expect(mockPrisma.trainingParticipant.findMany).toHaveBeenCalledWith({
        where: { id: { in: ['tp-1', 'tp-2'] } },
        include: { training: { select: { status: true } } },
      });
      expect(tx.trainingParticipant.updateMany).toHaveBeenCalledWith({
        where: {
          id: { in: ['tp-1', 'tp-2'] },
          status: { not: 'APROVADO' },
          OR: [{ status: { not: 'EM_AVALIACAO' } }, { assignedConsultantId: 'consultant-1' }],
        },
        data: { assignedConsultantId: 'consultant-1', status: 'EM_AVALIACAO' },
      });
    });

    it('permite reatribuir participante ao mesmo consultor', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        record({ status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor' }),
      ]);
      tx.trainingParticipant.updateMany.mockResolvedValue({ count: 1 });
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
    });
  });

  // ─── unassignParticipants ────────────────────────────────────────────────

  describe('unassignParticipants', () => {
    it('lança ConflictException se algum participante não existe', async () => {
```

por:

```ts
    });

    describe('o servidor confere as regras das telas (Fase 8D-1)', () => {
      it.each([['PLANEJADO'], ['CONCLUIDO'], ['CANCELADO']])(
        'sessão %s: recusa, sem gravar nada',
        async (status) => {
          mockPrisma.trainingParticipant.findMany.mockResolvedValue([
            record({ training: { status } }),
          ]);

          await expect(
            service.assignParticipants({ participantIds: ['tp-1'] }, 'consultant-1'),
          ).rejects.toThrow('Só dá para atribuir participantes com o treinamento em andamento');
          expect(mockPrisma.$transaction).not.toHaveBeenCalled();
        },
      );

      it('"Somente teórica": recusa, sem gravar nada', async () => {
        mockPrisma.trainingParticipant.findMany.mockResolvedValue([
          record({ participationType: 'SOMENTE_TEORICA' }),
        ]);

        await expect(
          service.assignParticipants({ participantIds: ['tp-1'] }, 'consultant-1'),
        ).rejects.toThrow('Participantes somente da parte teórica não têm avaliação prática');
        expect(mockPrisma.$transaction).not.toHaveBeenCalled();
      });

      it('outro aparelho atribuiu no meio do caminho: a gravação não pega todos e recusa '
        + '(a transação desfaz o que pegou)', async () => {
        mockPrisma.trainingParticipant.findMany.mockResolvedValue([record(), record({ id: 'tp-2' })]);
        tx.trainingParticipant.updateMany.mockResolvedValue({ count: 1 });

        await expect(
          service.assignParticipants({ participantIds: ['tp-1', 'tp-2'] }, 'consultant-1'),
        ).rejects.toThrow('Um ou mais participantes já estão em avaliação com outro consultor');
      });

      it('ids repetidos no pedido contam uma vez só', async () => {
        mockPrisma.trainingParticipant.findMany.mockResolvedValue([record()]);
        tx.trainingParticipant.updateMany.mockResolvedValue({ count: 1 });

        const result = await service.assignParticipants(
          { participantIds: ['tp-1', 'tp-1'] },
          'consultant-1',
        );

        expect(result).toEqual({ assigned: 1 });
        expect(mockPrisma.trainingParticipant.findMany).toHaveBeenCalledWith(
          expect.objectContaining({ where: { id: { in: ['tp-1'] } } }),
        );
      });
    });
  });

  // ─── unassignParticipants ────────────────────────────────────────────────

  describe('unassignParticipants', () => {
    /** O cliente da transação: cada liberação é uma gravação condicional nele. */
    const tx = { trainingParticipant: { updateMany: jest.fn() } };

    beforeEach(() => {
      tx.trainingParticipant.updateMany.mockReset();
      tx.trainingParticipant.updateMany.mockResolvedValue({ count: 1 });
      mockPrisma.$transaction.mockImplementation((fn: (t: unknown) => unknown) => fn(tx));
    });

    it('lança ConflictException se algum participante não existe', async () => {
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
        { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: { score: 62.5 } },
      ]);
      mockPrisma.trainingParticipant.update.mockImplementation((args) => args);
      mockPrisma.$transaction.mockResolvedValue([]);

      const result = await service.unassignParticipants(
```

por:

```ts
        { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: { score: 62.5 } },
      ]);

      const result = await service.unassignParticipants(
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
      expect(mockPrisma.$transaction).toHaveBeenCalledWith([
        { where: { id: 'tp-1' }, data: { assignedConsultantId: null, status: 'PENDENTE' } },
        { where: { id: 'tp-2' }, data: { assignedConsultantId: null, status: 'NAO_RECOMENDADO' } },
```

por:

```ts
      expect(tx.trainingParticipant.updateMany.mock.calls).toEqual([
        [{
          where: { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor' },
          data: { assignedConsultantId: null, status: 'PENDENTE' },
        }],
        [{
          where: { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor' },
          data: { assignedConsultantId: null, status: 'NAO_RECOMENDADO' },
        }],
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
      ]);
      mockPrisma.trainingParticipant.update.mockImplementation((args) => args);
      mockPrisma.$transaction.mockResolvedValue([]);

      const result = await service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor');

      expect(result).toEqual({ unassigned: 1 });
      expect(mockPrisma.$transaction).toHaveBeenCalledWith([
        { where: { id: 'tp-1' }, data: { assignedConsultantId: null, status: 'NAO_RECOMENDADO' } },
      ]);
    });
```

por:

```ts
      ]);

      const result = await service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor');

      expect(result).toEqual({ unassigned: 1 });
      expect(tx.trainingParticipant.updateMany).toHaveBeenCalledWith({
        where: { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor' },
        data: { assignedConsultantId: null, status: 'NAO_RECOMENDADO' },
      });
    });
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
        { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'mais-um', assessment: { score: 90 } },
      ]);
      mockPrisma.trainingParticipant.update.mockImplementation((args) => args);
      mockPrisma.$transaction.mockResolvedValue([]);

      // Sem `consultantId` no token: só o papel. Se o serviço fosse procurar o
```

por:

```ts
        { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'mais-um', assessment: { score: 90 } },
      ]);

      // Sem `consultantId` no token: só o papel. Se o serviço fosse procurar o
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
      expect(mockPrisma.$transaction).toHaveBeenCalledWith([
        { where: { id: 'tp-1' }, data: { assignedConsultantId: null, status: 'PENDENTE' } },
        { where: { id: 'tp-2' }, data: { assignedConsultantId: null, status: 'APROVADO' } },
```

por:

```ts
      expect(tx.trainingParticipant.updateMany.mock.calls).toEqual([
        [{
          where: { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'outro-consultor' },
          data: { assignedConsultantId: null, status: 'PENDENTE' },
        }],
        [{
          where: { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'mais-um' },
          data: { assignedConsultantId: null, status: 'APROVADO' },
        }],
```

Em `test/practical-assessments.service.spec.ts`, substituir:

```ts
      ).rejects.toThrow('Um ou mais participantes não estão atribuídos a você');
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });
  });
```

por:

```ts
      ).rejects.toThrow('Um ou mais participantes não estão atribuídos a você');
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    describe('corridas e pedidos repetidos (Fase 8D-1)', () => {
      it('o participante mudou ou sumiu no meio do caminho: 409, e não 500 '
        + '(a transação desfaz o que já liberou)', async () => {
        mockPrisma.trainingParticipant.findMany.mockResolvedValue([
          { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: null },
        ]);
        tx.trainingParticipant.updateMany.mockResolvedValue({ count: 0 });

        await expect(
          service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor'),
        ).rejects.toThrow('Um ou mais participantes mudaram de situação. Atualize a lista e tente de novo.');
      });

      it('ids repetidos no pedido contam uma vez só, sem recusa enganosa', async () => {
        mockPrisma.trainingParticipant.findMany.mockResolvedValue([
          { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: null },
        ]);

        const result = await service.unassignParticipants(
          { participantIds: ['tp-1', 'tp-1'] },
          'meu-consultor',
        );

        expect(result).toEqual({ unassigned: 1 });
        expect(tx.trainingParticipant.updateMany).toHaveBeenCalledTimes(1);
      });
    });
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run (em `apps/backend/`): `npx jest test/practical-assessments.service.spec.ts`
Esperado: `Tests: 12 failed, 40 passed, 52 total` — os testes reescritos do `assign` e do `unassign` (dedup, status da sessão, somente teórica, gravação condicional e o 409).

- [ ] **Step 3: Implementar**

Em `src/practical-assessments/practical-assessments.service.ts`, substituir:

```ts
    const records = await this.prisma.trainingParticipant.findMany({
      where: { id: { in: dto.participantIds } },
    });

    if (records.length !== dto.participantIds.length) {
      throw new ConflictException('Um ou mais participantes não foram encontrados');
```

por:

```ts
    // Ids repetidos no pedido contam uma vez só (Fase 8D-1).
    const ids = [...new Set(dto.participantIds)];
    const records = await this.prisma.trainingParticipant.findMany({
      where: { id: { in: ids } },
      include: { training: { select: { status: true } } },
    });

    if (records.length !== ids.length) {
      throw new ConflictException('Um ou mais participantes não foram encontrados');
    }

    // As regras que as telas do app e do web já aplicam (Fase 8D-1): só com
    // o treinamento em andamento, e só quem tem a parte prática.
    if (records.some((r) => r.training.status !== 'EM_ANDAMENTO')) {
      throw new ConflictException('Só dá para atribuir participantes com o treinamento em andamento');
    }
    if (records.some((r) => r.participationType === 'SOMENTE_TEORICA')) {
      throw new ConflictException('Participantes somente da parte teórica não têm avaliação prática');
```

Em `src/practical-assessments/practical-assessments.service.ts`, substituir:

```ts
    await this.prisma.trainingParticipant.updateMany({
      where: { id: { in: dto.participantIds } },
      data: { assignedConsultantId: consultantId, status: 'EM_AVALIACAO' },
    });

    return { assigned: dto.participantIds.length };
```

por:

```ts
    // A gravação confere as mesmas condições de novo: entre a leitura e aqui,
    // outro aparelho pode ter atribuído alguém. Se não pegar todos, a
    // transação desfaz o que pegou (Fase 8D-1).
    await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.trainingParticipant.updateMany({
        where: {
          id: { in: ids },
          status: { not: 'APROVADO' },
          OR: [{ status: { not: 'EM_AVALIACAO' } }, { assignedConsultantId: consultantId }],
        },
        data: { assignedConsultantId: consultantId, status: 'EM_AVALIACAO' },
      });
      if (count !== ids.length) {
        throw new ConflictException(
          'Um ou mais participantes já estão em avaliação com outro consultor',
        );
      }
    });

    return { assigned: ids.length };
```

Em `src/practical-assessments/practical-assessments.service.ts`, substituir:

```ts
    const records = await this.prisma.trainingParticipant.findMany({
      where: { id: { in: dto.participantIds } },
      include: { assessment: { select: { score: true } } },
    });

    if (records.length !== dto.participantIds.length) {
```

por:

```ts
    // Ids repetidos no pedido contam uma vez só (Fase 8D-1).
    const ids = [...new Set(dto.participantIds)];
    const records = await this.prisma.trainingParticipant.findMany({
      where: { id: { in: ids } },
      include: { assessment: { select: { score: true } } },
    });

    if (records.length !== ids.length) {
```

Em `src/practical-assessments/practical-assessments.service.ts`, substituir:

```ts
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
```

por:

```ts
    // Cada liberação confere de novo que o participante continua como foi
    // lido: no meio do caminho, outro pedido pode tê-lo liberado, avaliado ou
    // removido. Aí a transação desfaz tudo, com 409 em vez de 500 (Fase 8D-1).
    await this.prisma.$transaction(async (tx) => {
      for (const r of records) {
        const { count } = await tx.trainingParticipant.updateMany({
          where: { id: r.id, status: 'EM_AVALIACAO', assignedConsultantId: r.assignedConsultantId },
          data: {
            assignedConsultantId: null,
            status: statusAfterRelease(r.assessment?.score),
          },
        });
        if (count !== 1) {
          throw new ConflictException(
            'Um ou mais participantes mudaram de situação. Atualize a lista e tente de novo.',
          );
        }
      }
    });
```

- [ ] **Step 4: Rodar e ver passar**

Run (em `apps/backend/`): `npx jest test/practical-assessments.service.spec.ts`
Esperado: `Tests: 52 passed, 52 total`

- [ ] **Step 5: Conferir o backend inteiro**

Run (em `apps/backend/`): `npx tsc --noEmit` e depois `npx jest`
Esperado: nenhuma saída do `tsc`, e `Tests: 136 passed, 136 total`

- [ ] **Step 6: Commit**

```bash
git add apps/backend/src/practical-assessments/practical-assessments.service.ts apps/backend/test/practical-assessments.service.spec.ts
git commit -m "fix(practical-assessments): atribuir e desatribuir conferem as regras na gravacao"
```

---

## Task 4: Ciclo de vida da sessão e liberação de quem estava em avaliação

Itens 3, 4 e 5 do desenho. Iniciar só um treinamento planejado ("Só dá para iniciar um treinamento planejado") e concluir só um em andamento ("Só dá para concluir um treinamento em andamento"), com 403 como a recusa do consultor que não é o responsável; a sessão que não existe dá 404 também para o ADMIN. Cancelar a sessão, e excluir um consultor, liberam quem estava em avaliação, na mesma transação, de volta ao status de antes da atribuição (`statusAfterRelease`, sem mudança de esquema). A função de liberação ganha uma forma geral, `releaseHeldParticipants(tx, where)`, e a que já existia (`releaseParticipantsOfConsultants`) passa a usá-la. Na exclusão do consultor, a liberação vem **antes** de apagar a referência: depois, ela não acharia mais ninguém com ele.

**Files:**
- Create: `test/consultants.service.spec.ts`
- Modify: `src/consultants/consultants.service.ts`
- Modify: `src/participants/participant-release.util.ts`
- Modify: `src/training-sessions/training-sessions.service.ts`
- Modify: `test/training-sessions.service.spec.ts`

**Interfaces:**
- Consumes: a suíte verde da Task 3.
- Produces:
  - `releaseHeldParticipants(tx: Prisma.TransactionClient, where: Prisma.TrainingParticipantWhereInput): Promise<void>` em `src/participants/participant-release.util.ts`
  - `assertCanManageLifecycle(id, user?)` devolve o status da sessão
  - `test/consultants.service.spec.ts` novo

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/consultants.service.spec.ts`:

```ts
import { ConsultantsService } from 'src/consultants/consultants.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { StorageService } from 'src/storage/storage.service';
import { EmailService } from 'src/email/email.service';

describe('ConsultantsService.deleteConsultant (Fase 8D-1)', () => {
  const prisma = {
    consultant: { findUnique: jest.fn(), delete: jest.fn() },
    sessionConsultant: { deleteMany: jest.fn() },
    trainingSession: { updateMany: jest.fn() },
    practicalAssessment: { updateMany: jest.fn() },
    demandPipeline: { updateMany: jest.fn() },
    trainingParticipant: { findMany: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
    user: { findMany: jest.fn(), deleteMany: jest.fn() },
    bulkOperationJob: { deleteMany: jest.fn() },
    // A transação interativa roda com o próprio mock no papel do `tx`.
    $transaction: jest.fn((fn: (tx: unknown) => unknown) => fn(prisma)),
  };
  const service = new ConsultantsService(
    prisma as unknown as PrismaService,
    {} as StorageService,
    {} as EmailService,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.consultant.findUnique.mockResolvedValue({ id: 'c1' });
    prisma.user.findMany.mockResolvedValue([]);
  });

  it('libera quem estava em avaliação com ele, de qualquer treinamento, antes de apagar a referência', async () => {
    prisma.trainingParticipant.findMany.mockResolvedValue([
      { id: 'tp-1', assessment: null },
      { id: 'tp-2', assessment: { score: 90 } },
    ]);

    await service.deleteConsultant('c1');

    expect(prisma.trainingParticipant.findMany).toHaveBeenCalledWith({
      where: { assignedConsultantId: 'c1', status: 'EM_AVALIACAO' },
      include: { assessment: { select: { score: true } } },
    });
    expect(prisma.trainingParticipant.update.mock.calls).toEqual([
      [{ where: { id: 'tp-1' }, data: { assignedConsultantId: null, status: 'PENDENTE' } }],
      [{ where: { id: 'tp-2' }, data: { assignedConsultantId: null, status: 'APROVADO' } }],
    ]);
    // O resto (já avaliado com ele) só perde a referência, depois: antes,
    // a liberação não acharia mais ninguém com ele.
    expect(prisma.trainingParticipant.updateMany).toHaveBeenCalledWith({
      where: { assignedConsultantId: 'c1' },
      data: { assignedConsultantId: null },
    });
    const [releasedAt] = prisma.trainingParticipant.findMany.mock.invocationCallOrder;
    const [droppedAt] = prisma.trainingParticipant.updateMany.mock.invocationCallOrder;
    expect(releasedAt).toBeLessThan(droppedAt);
    expect(prisma.consultant.delete).toHaveBeenCalledWith({ where: { id: 'c1' } });
  });
});
```

Em `test/training-sessions.service.spec.ts`, substituir:

```ts
  });
});
```

por:

```ts
  });
});

describe('TrainingSessionsService: ciclo de vida (Fase 8D-1)', () => {
  const prisma = {
    trainingSession: { findUnique: jest.fn(), update: jest.fn() },
    trainingParticipant: { findMany: jest.fn(), update: jest.fn() },
    // A transação interativa roda com o próprio mock no papel do `tx`.
    $transaction: jest.fn((fn: (tx: unknown) => unknown) => fn(prisma)),
  };
  const service = new TrainingSessionsService(
    prisma as unknown as PrismaService,
    {} as EmailService,
    {} as StorageService,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.trainingParticipant.findMany.mockResolvedValue([]);
  });

  function sessionIs(status: string) {
    prisma.trainingSession.findUnique.mockResolvedValue({
      id: 's1',
      status,
      responsibleConsultantId: 'c1',
      consultants: [],
    });
  }

  it('inicia um treinamento planejado', async () => {
    sessionIs('PLANEJADO');
    await service.start('s1', admin);
    expect(prisma.trainingSession.update).toHaveBeenCalledWith({
      where: { id: 's1' },
      data: { status: 'EM_ANDAMENTO' },
    });
  });

  it.each([['EM_ANDAMENTO'], ['CONCLUIDO'], ['CANCELADO']])(
    'não inicia um treinamento %s (iniciar um concluído o reabriria)',
    async (status) => {
      sessionIs(status);
      await expect(service.start('s1', admin)).rejects.toThrow(
        'Só dá para iniciar um treinamento planejado',
      );
      expect(prisma.trainingSession.update).not.toHaveBeenCalled();
    },
  );

  it('conclui um treinamento em andamento', async () => {
    sessionIs('EM_ANDAMENTO');
    await service.complete('s1', consultant);
    expect(prisma.trainingSession.update).toHaveBeenCalledWith({
      where: { id: 's1' },
      data: { status: 'CONCLUIDO' },
    });
  });

  it.each([['PLANEJADO'], ['CONCLUIDO'], ['CANCELADO']])(
    'não conclui um treinamento %s',
    async (status) => {
      sessionIs(status);
      await expect(service.complete('s1', admin)).rejects.toThrow(
        'Só dá para concluir um treinamento em andamento',
      );
      expect(prisma.trainingSession.update).not.toHaveBeenCalled();
    },
  );

  it('o consultor que não é o responsável continua sem poder iniciar', async () => {
    sessionIs('PLANEJADO');
    const other = { sub: 'u3', role: 'CONSULTANT', consultantId: 'c9' } as unknown as JwtPayload;
    await expect(service.start('s1', other)).rejects.toThrow(
      'Somente o consultor responsável por este treinamento pode iniciá-lo ou concluí-lo',
    );
  });

  it('um treinamento que não existe é 404, também para o ADMIN', async () => {
    prisma.trainingSession.findUnique.mockResolvedValue(null);
    await expect(service.start('nao-existe', admin)).rejects.toThrow(
      'Sessão de treinamento não encontrada',
    );
  });

  it('cancelar libera quem estava em avaliação, na mesma transação, e volta ao status de antes', async () => {
    sessionIs('EM_ANDAMENTO');
    // A transação recebe um `tx` próprio: o que for gravado fora dele não conta.
    const tx = {
      trainingSession: { update: jest.fn() },
      trainingParticipant: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'tp-1', assessment: null },
          { id: 'tp-2', assessment: { score: 62.5 } },
        ]),
        update: jest.fn(),
      },
    };
    prisma.$transaction.mockImplementationOnce((fn: (t: unknown) => unknown) => fn(tx));

    await service.cancelSession('s1');

    expect(tx.trainingSession.update).toHaveBeenCalledWith({
      where: { id: 's1' },
      data: { status: 'CANCELADO' },
    });
    expect(tx.trainingParticipant.findMany).toHaveBeenCalledWith({
      where: { trainingSessionId: 's1', status: 'EM_AVALIACAO' },
      include: { assessment: { select: { score: true } } },
    });
    expect(tx.trainingParticipant.update.mock.calls).toEqual([
      [{ where: { id: 'tp-1' }, data: { assignedConsultantId: null, status: 'PENDENTE' } }],
      [{ where: { id: 'tp-2' }, data: { assignedConsultantId: null, status: 'NAO_RECOMENDADO' } }],
    ]);
    expect(prisma.trainingSession.update).not.toHaveBeenCalled();
    expect(prisma.trainingParticipant.update).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run (em `apps/backend/`): `npx jest test/consultants.service.spec.ts test/training-sessions.service.spec.ts`
Esperado: `Tests: 9 failed, 12 passed, 21 total` — iniciar e concluir em qualquer status, o 404 do ADMIN, o cancelar que não libera e a exclusão do consultor que não libera.

- [ ] **Step 3: Implementar**

Em `src/consultants/consultants.service.ts`, substituir:

```ts
import { UpdateConsultantDto } from './dto/update-consultant.dto';
import * as bcrypt from 'bcrypt';
```

por:

```ts
import { UpdateConsultantDto } from './dto/update-consultant.dto';
import { releaseHeldParticipants } from '../participants/participant-release.util';
import * as bcrypt from 'bcrypt';
```

Em `src/consultants/consultants.service.ts`, substituir:

```ts
      });

      await tx.trainingParticipant.updateMany({
        where: { assignedConsultantId: id },
```

por:

```ts
      });

      // Quem estava em avaliação com ele é liberado: sem dono, ficaria "em
      // avaliação" para sempre (Fase 8D-1). O resto só perde a referência.
      await releaseHeldParticipants(tx, { assignedConsultantId: id });
      await tx.trainingParticipant.updateMany({
        where: { assignedConsultantId: id },
```

Em `src/participants/participant-release.util.ts`, substituir:

```ts
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
```

por:

```ts
 * Libera quem está em avaliação entre os participantes de `where`: ficam sem
 * consultor e voltam ao status de antes da atribuição (ver
 * `statusAfterRelease`). Chamar na MESMA transação que faz o que os libera —
 * tirar o consultor do treinamento, excluí-lo ou cancelar o treinamento.
 */
export async function releaseHeldParticipants(
  tx: Prisma.TransactionClient,
  where: Prisma.TrainingParticipantWhereInput,
): Promise<void> {
  const held = await tx.trainingParticipant.findMany({
    where: { ...where, status: 'EM_AVALIACAO' },
```

Em `src/participants/participant-release.util.ts`, substituir:

```ts
  }
}
```

por:

```ts
  }
}

/**
 * Libera os participantes do treinamento que estavam em avaliação com algum
 * dos consultores de `consultantIds`.
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
  await releaseHeldParticipants(tx, {
    trainingSessionId,
    assignedConsultantId: { in: consultantIds },
  });
}
```

Em `src/training-sessions/training-sessions.service.ts`, substituir:

```ts
import { releaseParticipantsOfConsultants } from '../participants/participant-release.util';
```

por:

```ts
import {
  releaseHeldParticipants,
  releaseParticipantsOfConsultants,
} from '../participants/participant-release.util';
```

Em `src/training-sessions/training-sessions.service.ts`, substituir:

```ts
  /** Só ADMIN ou o consultor responsável pela sessão podem iniciar/concluir (regras de negócio). */
  private async assertCanManageLifecycle(id: string, user?: JwtPayload) {
    if (!user || user.role === 'ADMIN') return;
    const session = await this.prisma.trainingSession.findUnique({
      where: { id },
      select: { responsibleConsultantId: true },
    });
    if (!session) {
      throw new NotFoundException('Sessão de treinamento não encontrada');
    }
    if (session.responsibleConsultantId !== user.consultantId) {
      throw new ForbiddenException(
        'Somente o consultor responsável por este treinamento pode iniciá-lo ou concluí-lo',
      );
    }
  }

  async start(id: string, user?: JwtPayload) {
    await this.assertCanManageLifecycle(id, user);
    return this.prisma.trainingSession.update({
      where: { id },
      data: { status: 'EM_ANDAMENTO' },
    });
  }

  async complete(id: string, user?: JwtPayload) {
    await this.assertCanManageLifecycle(id, user);
```

por:

```ts
  /**
   * Só ADMIN ou o consultor responsável pela sessão podem iniciar/concluir
   * (regras de negócio). Devolve o status, que decide se a passagem vale.
   */
  private async assertCanManageLifecycle(id: string, user?: JwtPayload) {
    const session = await this.prisma.trainingSession.findUnique({
      where: { id },
      select: { responsibleConsultantId: true, status: true },
    });
    if (!session) {
      throw new NotFoundException('Sessão de treinamento não encontrada');
    }
    if (user && user.role !== 'ADMIN' && session.responsibleConsultantId !== user.consultantId) {
      throw new ForbiddenException(
        'Somente o consultor responsável por este treinamento pode iniciá-lo ou concluí-lo',
      );
    }
    return session.status;
  }

  /** Só um treinamento planejado é iniciado: iniciar um concluído o reabriria (Fase 8D-1). */
  async start(id: string, user?: JwtPayload) {
    const status = await this.assertCanManageLifecycle(id, user);
    if (status !== 'PLANEJADO') {
      throw new ForbiddenException('Só dá para iniciar um treinamento planejado');
    }
    return this.prisma.trainingSession.update({
      where: { id },
      data: { status: 'EM_ANDAMENTO' },
    });
  }

  /** Só um treinamento em andamento é concluído (Fase 8D-1). */
  async complete(id: string, user?: JwtPayload) {
    const status = await this.assertCanManageLifecycle(id, user);
    if (status !== 'EM_ANDAMENTO') {
      throw new ForbiddenException('Só dá para concluir um treinamento em andamento');
    }
```

Em `src/training-sessions/training-sessions.service.ts`, substituir:

```ts
    return this.prisma.trainingSession.update({
      where: { id },
      data: { status: 'CANCELADO' },
```

por:

```ts
    // Quem estava em avaliação é liberado junto: numa sessão cancelada, ficaria
    // "em avaliação" para sempre (Fase 8D-1).
    return this.prisma.$transaction(async (tx) => {
      const cancelled = await tx.trainingSession.update({
        where: { id },
        data: { status: 'CANCELADO' },
      });
      await releaseHeldParticipants(tx, { trainingSessionId: id });
      return cancelled;
```

- [ ] **Step 4: Rodar e ver passar**

Run (em `apps/backend/`): `npx jest test/consultants.service.spec.ts test/training-sessions.service.spec.ts`
Esperado: `Tests: 21 passed, 21 total`

- [ ] **Step 5: Conferir o backend inteiro**

Run (em `apps/backend/`): `npx tsc --noEmit` e depois `npx jest`
Esperado: nenhuma saída do `tsc`, e `Tests: 148 passed, 148 total`

- [ ] **Step 6: Commit**

```bash
git add apps/backend/test/consultants.service.spec.ts apps/backend/src/consultants/consultants.service.ts apps/backend/src/participants/participant-release.util.ts apps/backend/src/training-sessions/training-sessions.service.ts apps/backend/test/training-sessions.service.spec.ts
git commit -m "fix(training-sessions): ciclo de vida da sessao e liberacao de quem estava em avaliacao"
```

---

## Task 5: Adicionar participante: CPF só com dígitos, recusa antes de atualizar, e-mail conferido

Item 7 do desenho. O controller passa a mandar ao service o CPF devolvido pelo `ValidateCpfPipe` (só dígitos) — antes, o pipe validava e o retorno era jogado fora, e um CPF com máscara criava um segundo cadastro. A busca do cadastro pelo CPF confere a inscrição na sessão **antes** de atualizar nome e e-mail: uma recusa "CPF já inscrito neste treinamento" não muda mais o cadastro. A mesma função serve ao formulário público do QR Code, que ganha a mesma ordem (*escolha minha*: é o mesmo defeito, na mesma função). O `email` do `AddParticipantDto` é conferido como e-mail (`@IsEmail`, "E-mail inválido"); continua opcional.

**Files:**
- Modify: `src/participants/dto/add-participant.dto.ts`
- Modify: `src/participants/participants.controller.ts`
- Modify: `src/participants/participants.service.ts`
- Modify: `test/participants.service.spec.ts`

**Interfaces:**
- Consumes: o `test/participants.service.spec.ts` da Task 1.
- Produces:
  - `ParticipantsController.addParticipant(trainingSessionId, dto)` (dois parâmetros; o `@Body('cpf', ValidateCpfPipe)` sai)
  - `ParticipantsService.findOrUpdateParticipantForSession(trainingSessionId, dto)` (privado; substitui `findOrUpdateParticipantByCpf`)

- [ ] **Step 1: Escrever os testes que falham**

Em `test/participants.service.spec.ts`, substituir:

```ts
import { EmailService } from 'src/email/email.service';
import { StorageService } from 'src/storage/storage.service';

const mockPrisma = {
```

por:

```ts
import { EmailService } from 'src/email/email.service';
import { StorageService } from 'src/storage/storage.service';
import { ParticipantsController } from 'src/participants/participants.controller';
import { AddParticipantDto } from 'src/participants/dto/add-participant.dto';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

const mockPrisma = {
```

Em `test/participants.service.spec.ts`, substituir:

```ts
      mockPrisma.trainingParticipant.create.mockResolvedValue({ id: 'tp-1' });

      await service.registerPublic('token', dto as any);

      expect(mockPrisma.participant.create).toHaveBeenCalled();
    });
  });

  // ─── addParticipant ──────────────────────────────────────────────────────

  describe('addParticipant', () => {
    const dto = { cpf: '12345678901', name: 'Maria', email: null, cnhCategory: null, cnhExpiration: null };
```

por:

```ts
      mockPrisma.trainingParticipant.create.mockResolvedValue({ id: 'tp-1' });

      await service.registerPublic('token', dto as any);

      expect(mockPrisma.participant.create).toHaveBeenCalled();
    });

    it('CPF já inscrito: recusa sem mudar o cadastro', async () => {
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-1' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });

      await expect(service.registerPublic('token', dto as any)).rejects.toThrow('CPF já inscrito neste treinamento');
      expect(mockPrisma.trainingParticipant.findUnique).toHaveBeenCalledWith({
        where: { trainingSessionId_participantId: { trainingSessionId: 'sess-1', participantId: 'part-1' } },
      });
      expect(mockPrisma.participant.update).not.toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.create).not.toHaveBeenCalled();
    });
  });

  // ─── addParticipant ──────────────────────────────────────────────────────

  describe('addParticipant', () => {
    const dto = { cpf: '12345678901', name: 'Maria', email: null, cnhCategory: null, cnhExpiration: null };
```

Em `test/participants.service.spec.ts`, substituir:

```ts
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });
      await expect(service.addParticipant('sess-1', dto as any)).rejects.toThrow(ConflictException);
    });
  });

  // ─── removeParticipant ───────────────────────────────────────────────────
```

por:

```ts
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });
      await expect(service.addParticipant('sess-1', dto as any)).rejects.toThrow(ConflictException);
    });

    it('CPF já inscrito: recusa sem mudar o cadastro', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-1' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });

      await expect(service.addParticipant('sess-1', dto as any)).rejects.toThrow('CPF já inscrito neste treinamento');
      expect(mockPrisma.trainingParticipant.findUnique).toHaveBeenCalledWith({
        where: { trainingSessionId_participantId: { trainingSessionId: 'sess-1', participantId: 'part-1' } },
      });
      expect(mockPrisma.participant.update).not.toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.create).not.toHaveBeenCalled();
    });

    it('cadastro existente fora da sessão: atualiza nome e e-mail e inscreve', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-1' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);
      mockPrisma.participant.update.mockResolvedValue({ id: 'part-1' });
      mockPrisma.trainingParticipant.create.mockResolvedValue({ id: 'tp-1' });

      await service.addParticipant('sess-1', { cpf: '12345678901', name: 'Maria Nova', email: 'maria@nova.com' } as any);

      expect(mockPrisma.participant.update).toHaveBeenCalledWith({
        where: { id: 'part-1' },
        data: expect.objectContaining({ name: 'Maria Nova', email: 'maria@nova.com' }),
      });
      expect(mockPrisma.trainingParticipant.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ trainingSessionId: 'sess-1', participantId: 'part-1' }) }),
      );
    });

    it('cadastro novo: cria sem procurar inscrição', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue(null);
      mockPrisma.participant.create.mockResolvedValue({ id: 'part-novo' });
      mockPrisma.trainingParticipant.create.mockResolvedValue({ id: 'tp-1' });

      await service.addParticipant('sess-1', dto as any);

      expect(mockPrisma.participant.create).toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.findUnique).not.toHaveBeenCalled();
    });
  });

  // ─── addParticipant: controller e DTO ────────────────────────────────────

  describe('ParticipantsController.addParticipant', () => {
    const svc = { addParticipant: jest.fn() };
    const controller = new ParticipantsController(svc as unknown as ParticipantsService);

    it('manda ao service o CPF só com dígitos', () => {
      controller.addParticipant('sess-1', { cpf: '529.982.247-25', name: 'Maria' } as AddParticipantDto);

      expect(svc.addParticipant).toHaveBeenCalledWith('sess-1', { cpf: '52998224725', name: 'Maria' });
    });

    it('CPF com dígito verificador errado é 400, sem chamar o service', () => {
      expect(() =>
        controller.addParticipant('sess-1', { cpf: '529.982.247-26', name: 'Maria' } as AddParticipantDto),
      ).toThrow(BadRequestException);
      expect(svc.addParticipant).not.toHaveBeenCalled();
    });
  });

  describe('AddParticipantDto', () => {
    const errorsOf = (body: object) => validate(plainToInstance(AddParticipantDto, body));

    it('recusa um e-mail que não é e-mail', async () => {
      const errors = await errorsOf({ cpf: '52998224725', name: 'Maria', email: 'maria-sem-arroba' });

      expect(errors).toHaveLength(1);
      expect(errors[0].property).toBe('email');
      expect(Object.values(errors[0].constraints ?? {})).toEqual(['E-mail inválido']);
    });

    it('aceita e-mail válido ou ausente', async () => {
      await expect(errorsOf({ cpf: '52998224725', name: 'Maria', email: 'maria@empresa.com.br' })).resolves.toEqual([]);
      await expect(errorsOf({ cpf: '52998224725', name: 'Maria' })).resolves.toEqual([]);
    });
  });

  // ─── removeParticipant ───────────────────────────────────────────────────
```

- [ ] **Step 2: Rodar e ver falhar**

Run (em `apps/backend/`): `npx jest test/participants.service.spec.ts`
Esperado: `Tests: 0 total` — o arquivo não compila: `TS2554: Expected 3 arguments, but got 2` (o `addParticipant` do controller ainda tem três parâmetros).

- [ ] **Step 3: Implementar**

Em `src/participants/dto/add-participant.dto.ts`, substituir:

```ts
import { IsEnum, IsOptional, IsString } from "class-validator";
```

por:

```ts
import { IsEmail, IsEnum, IsOptional, IsString } from "class-validator";
```

Em `src/participants/dto/add-participant.dto.ts`, substituir:

```ts
    name!: string;

    @IsString()
    @IsOptional()
    email?: string;
```

por:

```ts
    name!: string;

    @IsEmail({}, { message: 'E-mail inválido' })
    @IsOptional()
    email?: string;
```

Em `src/participants/participants.controller.ts`, substituir:

```ts
  @Post('training-sessions/:id/participants')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  addParticipant(
    @Param('id') trainingSessionId: string,
    @Body('cpf', ValidateCpfPipe) _cpf: string,
    @Body() dto: AddParticipantDto,
  ) {
    return this.service.addParticipant(trainingSessionId, dto);
```

por:

```ts
  /**
   * O CPF segue para o service só com dígitos, que é como ele está gravado:
   * um CPF com máscara não pode criar um segundo cadastro. Como na consulta
   * abaixo, o `ValidateCpfPipe` é chamado à mão, depois do `ValidationPipe`.
   */
  @Post('training-sessions/:id/participants')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  addParticipant(
    @Param('id') trainingSessionId: string,
    @Body() dto: AddParticipantDto,
  ) {
    const cpf = new ValidateCpfPipe().transform(dto.cpf);
    return this.service.addParticipant(trainingSessionId, { ...dto, cpf });
```

Em `src/participants/participants.service.ts`, substituir:

```ts
   */
  private async findOrUpdateParticipantByCpf(dto: {
    cpf: string;
    name: string;
    email?: string;
    cnhCategory?: string;
    cnhExpiration?: string;
  }) {
```

por:

```ts
   *
   * A recusa de "CPF já inscrito" vem ANTES da atualização: uma inscrição
   * recusada não muda o cadastro. Cadastro novo não tem inscrição nenhuma.
   */
  private async findOrUpdateParticipantForSession(
    trainingSessionId: string,
    dto: {
      cpf: string;
      name: string;
      email?: string;
      cnhCategory?: string;
      cnhExpiration?: string;
    },
  ) {
```

Em `src/participants/participants.service.ts`, substituir:

```ts
      });
    }
```

por:

```ts
      });
    }

    const enrolled = await this.prisma.trainingParticipant.findUnique({
      where: {
        trainingSessionId_participantId: {
          trainingSessionId,
          participantId: existing.id,
        },
      },
    });
    if (enrolled) {
      throw new ConflictException('CPF já inscrito neste treinamento');
    }
```

Em `src/participants/participants.service.ts`, substituir:

```ts
    // 2. De-duplicação por CPF: reutiliza o participante, atualizando os
    // dados com o que veio nesta nova inscrição (ver findOrUpdateParticipantByCpf)
    const participant = await this.findOrUpdateParticipantByCpf(dto);

    // 3. Vincula participante à sessão (verifica se já está inscrito)
    const existing = await this.prisma.trainingParticipant.findUnique({
      where: {
        trainingSessionId_participantId: {
          trainingSessionId: session.id,
          participantId: participant.id,
        },
      },
    });

    if (existing) {
      throw new ConflictException('CPF já inscrito neste treinamento');
    }

    const trainingParticipant = await this.prisma.trainingParticipant.create({
```

por:

```ts
    // 2. De-duplicação por CPF: reutiliza o participante, atualizando os
    // dados com o que veio nesta nova inscrição; recusa quem já está inscrito
    // (ver findOrUpdateParticipantForSession)
    const participant = await this.findOrUpdateParticipantForSession(session.id, dto);

    // 3. Vincula participante à sessão
    const trainingParticipant = await this.prisma.trainingParticipant.create({
```

Em `src/participants/participants.service.ts`, substituir:

```ts
    // com o que veio nesta nova inscrição (ver findOrUpdateParticipantByCpf)
    const participant = await this.findOrUpdateParticipantByCpf(dto);

    const existing = await this.prisma.trainingParticipant.findUnique({
      where: {
        trainingSessionId_participantId: {
          trainingSessionId,
          participantId: participant.id,
        },
      },
    });

    if (existing) {
      throw new ConflictException('CPF já inscrito neste treinamento');
    }
```

por:

```ts
    // com o que veio nesta nova inscrição; recusa quem já está inscrito
    // (ver findOrUpdateParticipantForSession)
    const participant = await this.findOrUpdateParticipantForSession(trainingSessionId, dto);
```

- [ ] **Step 4: Rodar e ver passar**

Run (em `apps/backend/`): `npx jest test/participants.service.spec.ts`
Esperado: `Tests: 19 passed, 19 total`

- [ ] **Step 5: Conferir o backend inteiro**

Run (em `apps/backend/`): `npx tsc --noEmit` e depois `npx jest`
Esperado: nenhuma saída do `tsc`, e `Tests: 156 passed, 156 total`

- [ ] **Step 6: Commit**

```bash
git add apps/backend/src/participants/dto/add-participant.dto.ts apps/backend/src/participants/participants.controller.ts apps/backend/src/participants/participants.service.ts apps/backend/test/participants.service.spec.ts
git commit -m "fix(participants): adicionar participante grava cpf so com digitos e recusa antes de atualizar"
```

---
## Task 6: Inventário do backend e publicação na produção

Feita pelo **controlador**, sem subagente, depois da revisão final. Cada passo marcado com ⚠ só acontece depois de o usuário dizer "pode" naquele momento.

**Interfaces:**
- Consumes: as Tasks 1 a 5 commitadas e a revisão final aprovada.
- Produces: a produção (`https://api.simtc.com.br/api`) rodando o backend da 8D-1; o `apps/backend/CLAUDE.md` em dia.

- [ ] **Step 1: Atualizar o `apps/backend/CLAUDE.md` (não versionado, sem commit)**

Na seção "Estado Atual do Projeto — Progresso por Módulo":

- Em **Participants**, trocar a linha da "Adição manual de participante" por:
  `✅ **Adição manual de participante** — \`POST /training-sessions/:id/participants\` (ADMIN), com dedup por CPF e validação de status da sessão. Desde 27/10/2026 (Fase 8D-1 do app): o CPF é gravado só com dígitos (o retorno do \`ValidateCpfPipe\`), a recusa 409 "CPF já inscrito neste treinamento" vem antes de atualizar o cadastro (vale também para o formulário público) e o e-mail é conferido (\`@IsEmail\`, "E-mail inválido").`
  e logo abaixo dela acrescentar:
  `✅ **Consulta de CPF** — \`POST /training-sessions/:id/participants/lookup\` (ADMIN), corpo \`{ cpf }\` (no corpo, e não na URL, para não ir a log); devolve \`{ registered, name, email, enrolled }\` e só lê. Usada pela tela "Adicionar participante" do app mobile (Fase 6A).`
- Em **TrainingSessions**, trocar a linha do `start`/`complete` por:
  `✅ \`POST /training-sessions/:id/start\` e \`/complete\` — controle de status: iniciar só \`PLANEJADO\`, concluir só \`EM_ANDAMENTO\` (403 fora disso); sessão inexistente é 404 (Fase 8D-1).`
  e a do `cancel` por:
  `✅ **\`PATCH /training-sessions/:id/cancel\`** — cancela sessão; bloqueia se já \`CONCLUIDO\` ou \`CANCELADO\`. Libera, na mesma transação, quem estava \`EM_AVALIACAO\` (Fase 8D-1).`
- Em **Consultants**, acrescentar ao fim da lista:
  `✅ **\`deleteConsultant\` libera quem estava em avaliação com ele** (de volta ao status de antes da atribuição), antes de apagar a referência (Fase 8D-1).`
- Em **PracticalAssessments**, acrescentar ao fim da lista:
  `✅ **Fase 8D-1 (27/10/2026):** o sync grava cada avaliação numa transação (itens, nota e status do participante) e continua aceito com a sessão concluída; \`GET /practical-assessments/:id\` e \`by-participant/:id\` só ADMIN e CONSULTANT, com 404 para id inexistente; \`assign\` só com a sessão \`EM_ANDAMENTO\`, nunca \`SOMENTE_TEORICA\`, com gravação condicional (409 se outro pegou no meio); \`unassign\` condicional, 409 em vez de 500, ids repetidos contam uma vez.`

Esperado: `git status --porcelain` igual à linha de base (o arquivo é ignorado).

- [ ] **Step 2: Conferir o que vai subir**

Run (da raiz): `git log --oneline origin/feat/frontend-backend-integration..feat/mobile-app | wc -l`, `git log --oneline feat/mobile-app..origin/feat/frontend-backend-integration | wc -l` e `git ls-files | grep -iE "(^|/)\.env|\.pem$|\.jks$|\.keystore$|key\.properties"`
Esperado: os commits só locais (32 em 27/10/2026, de antes deste plano, mais os deste plano); **zero** commits da `feat/frontend-backend-integration` que a `feat/mobile-app` não tenha (o avanço é direto, sem merge); e nenhum arquivo de segredo além da migração `add_consultant_credentials`, que não é segredo. Se aparecer um `.env` ou chave, parar e avisar o usuário. Mostrar ao usuário o resumo: as Fases 8B, 8C e 8D-1 sobem juntas; só a 8D-1 muda o backend, e nenhuma muda o web ou o banco.

- [ ] **Step 3: ⚠ Enviar a branch de trabalho**

Run: `git push origin feat/mobile-app`
Esperado: o GitHub recebe os commits.

- [ ] **Step 4: ⚠ Avançar a branch da produção**

Run: `git push origin feat/mobile-app:feat/frontend-backend-integration`
Esperado: avanço direto (fast-forward), como na 8A. Se o git recusar por não ser avanço direto, **parar e avisar o usuário** (alguém subiu algo na branch da produção). Depois: `git fetch origin` (não trocar de branch).

- [ ] **Step 5: Conferir a produção**

Pedir ao usuário que acompanhe o deploy do **backend** no EasyPanel até ele subir (o `prisma migrate deploy` não tem migração nova a aplicar). Se o backend não subir, mostrar o log ao usuário antes de qualquer coisa.

Run: `curl -s -o /dev/null -w "%{http_code}" https://api.simtc.com.br/api/practical-assessments/x`
Esperado: `401` (o servidor no ar; a rota pede login).

Não há commit nesta task.

---

## Task 7: Validação contra a produção

O portão da 8D-1, que só o usuário pode rodar, no **app** (celular físico) e no **painel web**, contra a produção, numa sessão de teste. O app não muda nesta fase: a versão instalada da 8C serve.

**Interfaces:**
- Consumes: a produção publicada (Task 6).
- Produces: o aval do usuário para planejar a 8D-2.

- [ ] **Step 1: Roteiro**

1. **Adicionar participante (painel web, ADMIN):** numa sessão planejada ou em andamento, adicionar de novo alguém que já está nela, com outro nome: a recusa "CPF já inscrito neste treinamento" aparece, e o nome continua o antigo (antes, a recusa gravava o nome novo). No app, a consulta de CPF já barra esse caso antes de enviar; ali, só conferir que adicionar alguém novo continua funcionando, com e sem e-mail.
2. **Atribuir e desatribuir (app, dois aparelhos ou app e web):** numa sessão em andamento, o consultor A pega um participante; o consultor B, com a lista desatualizada, tenta pegar o mesmo: recusa com o motivo. O ADMIN desatribui pelo ⋮: o participante volta para a fila.
3. **Cancelar libera:** o consultor pega um participante numa sessão de teste; o ADMIN cancela a sessão (app ou web): no web, o participante deixa de aparecer "em avaliação" e volta a "Pendente" (ou à nota anterior, numa reavaliação).
4. **Iniciar fora do status (app, dois aparelhos):** abrir o detalhe de uma sessão planejada nos dois; iniciar num deles; no outro, sem atualizar, tocar em "Iniciar": a recusa "Só dá para iniciar um treinamento planejado" aparece.
5. **Reavaliar continua funcionando (app, CONSULTANT):** "Reavaliar" um participante já avaliado abre a avaliação anterior (é a leitura `by-participant`, agora só para ADMIN e CONSULTANT).

O envio com a sessão já concluída não tem roteiro: o painel só conclui com todos avaliados, então o caso só acontece por fora das telas, e fica coberto pelo teste da Task 2.

- [ ] **Step 2: Registrar o resultado**

Se tudo passar, acrescentar ao fim desta task a linha "**Validado em <data>: roteiro inteiro passou contra a produção. Aval dado para planejar a 8D-2.**" e commitar:

```bash
git add apps/mobile/docs/superpowers/plans/2026-10-27-mobile-fase-8d1-servidor-confere-regras.md
git commit -m "docs(mobile): registra a validacao da fase 8d-1"
```

Se algo falhar, **não corrigir no improviso**: usar `superpowers:systematic-debugging`, e se a falha for de regra de negócio, parar e perguntar.

---

## Observações levadas para a 8D-2

- **A regra de e-mail do app** aceita alguns erros de digitação que o servidor recusa (`a@b.c`, `maria@empresa..com`); a tela mostra o "E-mail inválido" do servidor. Alinhar a regra do app, se valer a pena.
- **O formulário público do QR Code** continua sem a validação de CPF do pipe e grava o CPF como vier: é do web, fora da 8D.
- **Uma inscrição simultânea do mesmo CPF na mesma sessão** (dois envios no mesmo instante) ainda pode responder 500 pela chave única do banco, em vez de 409. É raro e não perde dado; fica registrado.
