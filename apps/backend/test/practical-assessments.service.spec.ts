import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { PracticalAssessmentsService } from 'src/practical-assessments/practical-assessments.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { StorageService } from 'src/storage/storage.service';
import {
  calculateCategoryScore,
  calculateOverallScore,
  getApprovalStatus,
} from '@simtc/shared-types';

const mockPrisma = {
  practicalAssessment: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn(), findUniqueOrThrow: jest.fn() },
  trainingParticipant: { findMany: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
  assessmentItem: { deleteMany: jest.fn() },
  assessmentCategory: { findMany: jest.fn() },
  $transaction: jest.fn(),
};

const mockStorage = {
  upload: jest.fn(),
  delete: jest.fn(),
  getSignedUrl: jest.fn(),
};

describe('PracticalAssessmentsService', () => {
  let service: PracticalAssessmentsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PracticalAssessmentsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: StorageService, useValue: mockStorage },
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

  // ─── Assinatura do participante ──────────────────────────────────────────

  describe('uploadParticipantSignature', () => {
    const png = Buffer.from('fake-png');
    let nowSpy: jest.SpyInstance;

    beforeEach(() => {
      nowSpy = jest.spyOn(Date, 'now').mockReturnValue(1_700_000_000_000);
      mockStorage.upload.mockResolvedValue('https://ignorada.example/publica.png');
      mockStorage.delete.mockResolvedValue(undefined);
      mockStorage.getSignedUrl.mockResolvedValue('https://signed.example/assinatura.png');
      mockPrisma.practicalAssessment.update.mockResolvedValue({});
    });

    afterEach(() => nowSpy.mockRestore());

    it('lança NotFoundException se a avaliação não existe', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);

      await expect(
        service.uploadParticipantSignature('assess-x', png, 'image/png'),
      ).rejects.toThrow(NotFoundException);
      expect(mockStorage.upload).not.toHaveBeenCalled();
    });

    it('sobe no bucket signatures, salva só o path e devolve signed URL', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ participantSignatureUrl: null });

      const result = await service.uploadParticipantSignature('assess-1', png, 'image/png');

      expect(mockStorage.delete).not.toHaveBeenCalled();
      expect(mockStorage.upload).toHaveBeenCalledWith(
        'signatures',
        'participants/assess-1/1700000000000.png',
        png,
        'image/png',
      );
      expect(mockPrisma.practicalAssessment.update).toHaveBeenCalledWith({
        where: { id: 'assess-1' },
        data: { participantSignatureUrl: 'participants/assess-1/1700000000000.png' },
      });
      expect(mockStorage.getSignedUrl).toHaveBeenCalledWith(
        'signatures',
        'participants/assess-1/1700000000000.png',
        3600,
      );
      expect(result).toEqual({ signedUrl: 'https://signed.example/assinatura.png' });
    });

    it('apaga o arquivo anterior antes de subir o novo', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({
        participantSignatureUrl: 'participants/assess-1/1600000000000.png',
      });

      await service.uploadParticipantSignature('assess-1', png, 'image/png');

      expect(mockStorage.delete).toHaveBeenCalledWith(
        'signatures',
        'participants/assess-1/1600000000000.png',
      );
      expect(mockStorage.delete.mock.invocationCallOrder[0]).toBeLessThan(
        mockStorage.upload.mock.invocationCallOrder[0],
      );
    });

    it('segue com o upload mesmo se apagar o arquivo anterior falhar', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({
        participantSignatureUrl: 'participants/assess-1/1600000000000.png',
      });
      mockStorage.delete.mockRejectedValueOnce(new Error('Object not found'));

      await expect(
        service.uploadParticipantSignature('assess-1', png, 'image/png'),
      ).resolves.toEqual({ signedUrl: 'https://signed.example/assinatura.png' });
      expect(mockStorage.upload).toHaveBeenCalled();
    });

    it('usa extensão .jpg para image/jpeg', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ participantSignatureUrl: null });

      await service.uploadParticipantSignature('assess-1', png, 'image/jpeg');

      expect(mockStorage.upload).toHaveBeenCalledWith(
        'signatures',
        'participants/assess-1/1700000000000.jpg',
        png,
        'image/jpeg',
      );
    });
  });

  describe('getParticipantSignatureSignedUrl', () => {
    it('lança NotFoundException se a avaliação não existe', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);

      await expect(service.getParticipantSignatureSignedUrl('assess-x')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('retorna null se a avaliação não tem assinatura', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ participantSignatureUrl: null });

      await expect(service.getParticipantSignatureSignedUrl('assess-1')).resolves.toBeNull();
      expect(mockStorage.getSignedUrl).not.toHaveBeenCalled();
    });

    it('gera signed URL de 1h a partir do path salvo', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({
        participantSignatureUrl: 'participants/assess-1/1700000000000.png',
      });
      mockStorage.getSignedUrl.mockResolvedValue('https://signed.example/assinatura.png');

      await expect(service.getParticipantSignatureSignedUrl('assess-1')).resolves.toEqual({
        signedUrl: 'https://signed.example/assinatura.png',
      });
      expect(mockStorage.getSignedUrl).toHaveBeenCalledWith(
        'signatures',
        'participants/assess-1/1700000000000.png',
        3600,
      );
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

    it('devolve o assessmentId de cada avaliação sincronizada', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);
      mockPrisma.practicalAssessment.create.mockResolvedValue({ id: 'assess-1', items: [] });

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result).toEqual([
        { trainingParticipantId: 'tp-1', status: 'fulfilled', assessmentId: 'assess-1' },
      ]);
    });

    it('devolve o assessmentId também na reavaliação (registro existente)', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ id: 'assess-1' });
      mockPrisma.assessmentItem.deleteMany.mockResolvedValue({ count: 2 });
      mockPrisma.practicalAssessment.update.mockResolvedValue({ id: 'assess-1', items: [] });

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result[0]).toMatchObject({ status: 'fulfilled', assessmentId: 'assess-1' });
    });

    it('não devolve assessmentId para item rejeitado', async () => {
      mockPrisma.practicalAssessment.findUnique.mockRejectedValueOnce(new Error('falha no banco'));

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result).toEqual([
        { trainingParticipantId: 'tp-1', status: 'rejected', error: 'falha no banco' },
      ]);
      expect(result[0].assessmentId).toBeUndefined();
    });
  });
});
