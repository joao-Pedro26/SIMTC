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
