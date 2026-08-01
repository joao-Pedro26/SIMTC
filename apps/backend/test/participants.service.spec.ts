import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { ParticipantsService } from 'src/participants/participants.service';
import { PrismaService } from 'src/prisma/prisma.service';

const mockPrisma = {
  trainingSession: { findUniqueOrThrow: jest.fn(), findUnique: jest.fn() },
  participant: { findUnique: jest.fn(), create: jest.fn() },
  trainingParticipant: { findUnique: jest.fn(), create: jest.fn(), findMany: jest.fn(), update: jest.fn(), delete: jest.fn() },
};

describe('ParticipantsService', () => {
  let service: ParticipantsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ParticipantsService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<ParticipantsService>(ParticipantsService);
    jest.clearAllMocks();
  });

  // ─── registerPublic ──────────────────────────────────────────────────────

  describe('registerPublic', () => {
    const dto = { name: 'João', cpf: '12345678901', email: 'j@j.com', cnhCategory: 'B', cnhExpiration: null };

    it('lança 400 se sessão está CANCELADO', async () => {
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue({ id: '1', status: 'CANCELADO' });
      await expect(service.registerPublic('token', dto as any)).rejects.toThrow(BadRequestException);
    });

    it('lança 400 se sessão está CONCLUIDO', async () => {
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue({ id: '1', status: 'CONCLUIDO' });
      await expect(service.registerPublic('token', dto as any)).rejects.toThrow(BadRequestException);
    });

    it('lança 409 se CPF já está inscrito na sessão', async () => {
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-1' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });
      await expect(service.registerPublic('token', dto as any)).rejects.toThrow(ConflictException);
    });

    it('reutiliza participante existente pelo CPF', async () => {
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-existente' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);
      mockPrisma.trainingParticipant.create.mockResolvedValue({ id: 'tp-1' });

      await service.registerPublic('token', dto as any);

      expect(mockPrisma.participant.create).not.toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ participantId: 'part-existente' }) }),
      );
    });

    it('cria participante novo se CPF não existe', async () => {
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue(null);
      mockPrisma.participant.create.mockResolvedValue({ id: 'part-novo' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);
      mockPrisma.trainingParticipant.create.mockResolvedValue({ id: 'tp-1' });

      await service.registerPublic('token', dto as any);

      expect(mockPrisma.participant.create).toHaveBeenCalled();
    });
  });

  // ─── addParticipant ──────────────────────────────────────────────────────

  describe('addParticipant', () => {
    const dto = { cpf: '12345678901', name: 'Maria', email: null, cnhCategory: null, cnhExpiration: null };

    it('lança 404 se sessão não existe', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(null);
      await expect(service.addParticipant('sess-id', dto as any)).rejects.toThrow();
    });

    it('lança 400 se sessão está CANCELADO', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: '1', status: 'CANCELADO' });
      await expect(service.addParticipant('sess-id', dto as any)).rejects.toThrow(BadRequestException);
    });

    it('lança 409 se CPF já inscrito', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-1' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });
      await expect(service.addParticipant('sess-1', dto as any)).rejects.toThrow(ConflictException);
    });
  });

  // ─── removeParticipant ───────────────────────────────────────────────────

  describe('removeParticipant', () => {
    it('lança 404 se participante não encontrado', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);
      await expect(service.removeParticipant('tp-id')).rejects.toThrow();
    });

    it('lança 400 se participante está EM_AVALIACAO', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1', status: 'EM_AVALIACAO' });
      await expect(service.removeParticipant('tp-1')).rejects.toThrow(BadRequestException);
    });

    it('deleta participante com status PENDENTE', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1', status: 'PENDENTE' });
      mockPrisma.trainingParticipant.delete.mockResolvedValue({ id: 'tp-1' });
      await service.removeParticipant('tp-1');
      expect(mockPrisma.trainingParticipant.delete).toHaveBeenCalledWith({ where: { id: 'tp-1' } });
    });
  });
});
