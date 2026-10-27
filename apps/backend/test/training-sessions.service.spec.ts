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

  it('traz o logo da empresa, que o card de sessão do app mostra', async () => {
    mockPrisma.trainingSession.findMany.mockResolvedValue([]);

    await service.findAll(consultant, {});

    expect(mockPrisma.trainingSession.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        include: expect.objectContaining({
          company: { select: { id: true, name: true, logoUrl: true } },
        }),
      }),
    );
  });

  it('conta apenas TEORICA_E_PRATICA como avaliável e como avaliado', async () => {
    mockPrisma.trainingSession.findMany.mockResolvedValue([session('s1')]);
    mockPrisma.trainingParticipant.groupBy.mockResolvedValue([
      groupRow('s1', 'PENDENTE', 'TEORICA_E_PRATICA', 3),
      groupRow('s1', 'APROVADO', 'TEORICA_E_PRATICA', 4),
      groupRow('s1', 'NAO_RECOMENDADO', 'TEORICA_E_PRATICA', 1),
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
});

describe('TrainingSessionsService: ciclo de vida (Fase 8D-1)', () => {
  const prisma = {
    trainingSession: { findUnique: jest.fn(), update: jest.fn() },
    trainingParticipant: { findMany: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
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
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
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
    expect(tx.trainingParticipant.updateMany.mock.calls).toEqual([
      [{ where: { id: 'tp-1', status: 'EM_AVALIACAO' }, data: { assignedConsultantId: null, status: 'PENDENTE' } }],
      [{ where: { id: 'tp-2', status: 'EM_AVALIACAO' }, data: { assignedConsultantId: null, status: 'NAO_RECOMENDADO' } }],
    ]);
    expect(prisma.trainingSession.update).not.toHaveBeenCalled();
    expect(prisma.trainingParticipant.updateMany).not.toHaveBeenCalled();
  });
});
