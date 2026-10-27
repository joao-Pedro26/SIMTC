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
  trainingParticipant: { findMany: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
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
    mockPrisma.trainingParticipant.updateMany.mockResolvedValue({ count: 1 });
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
      expect(mockPrisma.trainingParticipant.updateMany).not.toHaveBeenCalled();
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
        where: { id, status: 'EM_AVALIACAO' },
        data: { assignedConsultantId: null, status },
      });
      expect(mockPrisma.trainingParticipant.updateMany.mock.calls.map(([call]) => call)).toEqual([
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
      expect(mockPrisma.trainingParticipant.updateMany).not.toHaveBeenCalled();
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
      expect(mockPrisma.trainingParticipant.updateMany).toHaveBeenCalledWith({
        where: { id: 'tp-1', status: 'EM_AVALIACAO' },
        data: { assignedConsultantId: null, status: 'PENDENTE' },
      });
    });

    it('lista nova com os mesmos consultores: ninguém é liberado', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(sessionWith(['c1', 'c2']));

      await service.updateSession('s1', { additionalConsultantsIds: ['c2'] });

      expect(mockPrisma.sessionConsultant.createMany).toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.findMany).not.toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.updateMany).not.toHaveBeenCalled();
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
