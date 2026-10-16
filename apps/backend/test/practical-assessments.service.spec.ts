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
  practicalAssessment: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn(), findUniqueOrThrow: jest.fn() },
  trainingParticipant: { findMany: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
  assessmentItem: { deleteMany: jest.fn() },
  assessmentCategory: { findMany: jest.fn() },
  $transaction: jest.fn(),
};

describe('PracticalAssessmentsService', () => {
  let service: PracticalAssessmentsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PracticalAssessmentsService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<PracticalAssessmentsService>(PracticalAssessmentsService);
    jest.clearAllMocks();
  });

  // ─── Funções de scoring (lógica pura) ────────────────────────────────────

  describe('calculateCategoryScore', () => {
    it('retorna 100 se não há infrações cadastradas na categoria', () => {
      expect(calculateCategoryScore([], 0)).toBe(100);
    });

    it('retorna 100 se há infrações cadastradas mas nenhuma foi marcada', () => {
      expect(calculateCategoryScore([], 5)).toBe(100);
    });

    it('desconta proporcionalmente ao número de infrações da categoria', () => {
      // 5 infrações no tópico → cada uma vale 20%. Uma nota M (peso máximo) desconta os 20% inteiros.
      expect(calculateCategoryScore([5], 5)).toBe(80);
    });

    it('nota B desconta apenas 1/5 do peso máximo dentro da fatia da infração', () => {
      // 5 infrações no tópico → fatia de 20%. Nota B (peso 1 de 5) desconta 1/5 de 20% = 4%.
      expect(calculateCategoryScore([1], 5)).toBe(96);
    });

    it('não vai abaixo de 0', () => {
      expect(calculateCategoryScore([5, 5, 5], 3)).toBe(0);
    });
  });

  describe('calculateOverallScore', () => {
    it('retorna 100 se não há categorias', () => {
      expect(calculateOverallScore([])).toBe(100);
    });

    it('retorna média das categorias', () => {
      expect(calculateOverallScore([80, 60])).toBe(70);
    });

    it('retorna valor único se só uma categoria', () => {
      expect(calculateOverallScore([85])).toBe(85);
    });
  });

  describe('getApprovalStatus', () => {
    it('retorna APROVADO se score >= 70', () => {
      expect(getApprovalStatus(70)).toBe('APROVADO');
      expect(getApprovalStatus(85)).toBe('APROVADO');
      expect(getApprovalStatus(100)).toBe('APROVADO');
    });

    it('retorna NAO_RECOMENDADO se score < 70', () => {
      expect(getApprovalStatus(69)).toBe('NAO_RECOMENDADO');
      expect(getApprovalStatus(0)).toBe('NAO_RECOMENDADO');
    });
  });

  // ─── assignParticipants ──────────────────────────────────────────────────

  describe('assignParticipants', () => {
    it('lança ConflictException se algum participante não existe', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'PENDENTE', assignedConsultantId: null },
      ]);
      await expect(
        service.assignParticipants({ participantIds: ['tp-1', 'tp-2'] }, 'consultant-1'),
      ).rejects.toThrow(ConflictException);
    });

    it('lança ConflictException se participante já atribuído a outro consultor', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
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

      const result = await service.assignParticipants(
        { participantIds: ['tp-1', 'tp-2'] },
        'consultant-1',
      );

      expect(result).toEqual({ assigned: 2 });
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

      const result = await service.assignParticipants(
        { participantIds: ['tp-1'] },
        'meu-consultor',
      );
      expect(result).toEqual({ assigned: 1 });
    });
  });

  // ─── unassignParticipants ────────────────────────────────────────────────

  describe('unassignParticipants', () => {
    it('lança ConflictException se algum participante não existe', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: null },
      ]);
      await expect(
        service.unassignParticipants({ participantIds: ['tp-1', 'tp-2'] }, 'meu-consultor'),
      ).rejects.toThrow(ConflictException);
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    it('lança ConflictException se o participante não está em avaliação com quem pediu', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'outro-consultor', assessment: null },
      ]);
      await expect(
        service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor'),
      ).rejects.toThrow('Um ou mais participantes não estão atribuídos a você');

      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'PENDENTE', assignedConsultantId: null, assessment: null },
      ]);
      await expect(
        service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor'),
      ).rejects.toThrow(ConflictException);
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    it('libera a atribuição e devolve o status anterior: Pendente sem avaliação, o da nota numa reavaliação', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: null },
        { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: { score: 62.5 } },
      ]);
      mockPrisma.trainingParticipant.update.mockImplementation((args) => args);
      mockPrisma.$transaction.mockResolvedValue([]);

      const result = await service.unassignParticipants(
        { participantIds: ['tp-1', 'tp-2'] },
        'meu-consultor',
      );

      expect(result).toEqual({ unassigned: 2 });
      expect(mockPrisma.trainingParticipant.findMany).toHaveBeenCalledWith({
        where: { id: { in: ['tp-1', 'tp-2'] } },
        include: { assessment: { select: { score: true } } },
      });
      expect(mockPrisma.$transaction).toHaveBeenCalledWith([
        { where: { id: 'tp-1' }, data: { assignedConsultantId: null, status: 'PENDENTE' } },
        { where: { id: 'tp-2' }, data: { assignedConsultantId: null, status: 'NAO_RECOMENDADO' } },
      ]);
    });

    it('nota zero é avaliação anterior: o participante volta a Não recomendado, não a Pendente', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: { score: 0 } },
      ]);
      mockPrisma.trainingParticipant.update.mockImplementation((args) => args);
      mockPrisma.$transaction.mockResolvedValue([]);

      const result = await service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor');

      expect(result).toEqual({ unassigned: 1 });
      expect(mockPrisma.$transaction).toHaveBeenCalledWith([
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

  describe('syncFromMobile', () => {
    const dto = {
      trainingParticipantId: 'tp-1',
      date: '2026-09-17',
      startTime: '2026-09-17T10:00:00.000Z',
      endTime: '2026-09-17T10:30:00.000Z',
      items: [],
    };

    beforeEach(() => {
      mockPrisma.assessmentCategory.findMany.mockResolvedValue([]);
      mockPrisma.$transaction.mockResolvedValue([]);
    });

    it('sincroniza uma avaliação nova com sucesso', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);
      mockPrisma.practicalAssessment.create.mockResolvedValue({ id: 'assess-1', items: [] });

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result).toEqual([
        { trainingParticipantId: 'tp-1', status: 'fulfilled' },
      ]);
    });

    it('sincroniza também na reavaliação (registro existente)', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ id: 'assess-1' });
      mockPrisma.assessmentItem.deleteMany.mockResolvedValue({ count: 2 });
      mockPrisma.practicalAssessment.update.mockResolvedValue({ id: 'assess-1', items: [] });

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result[0]).toMatchObject({ status: 'fulfilled' });
    });

    it('devolve o erro para item rejeitado', async () => {
      mockPrisma.practicalAssessment.findUnique.mockRejectedValueOnce(new Error('falha no banco'));

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result).toEqual([
        { trainingParticipantId: 'tp-1', status: 'rejected', error: 'falha no banco' },
      ]);
    });
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
