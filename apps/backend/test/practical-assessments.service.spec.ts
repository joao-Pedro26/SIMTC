import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException } from '@nestjs/common';
import { PracticalAssessmentsService } from 'src/practical-assessments/practical-assessments.service';
import { PrismaService } from 'src/prisma/prisma.service';
import {
  calculateCategoryScore,
  calculateOverallScore,
  getApprovalStatus,
} from '@simtc/shared-types';

const mockPrisma = {
  practicalAssessment: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn(), findUniqueOrThrow: jest.fn() },
  trainingParticipant: { findMany: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
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

    it('retorna NECESSITA_REAVALIACAO se score < 70', () => {
      expect(getApprovalStatus(69)).toBe('NECESSITA_REAVALIACAO');
      expect(getApprovalStatus(0)).toBe('NECESSITA_REAVALIACAO');
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
});
