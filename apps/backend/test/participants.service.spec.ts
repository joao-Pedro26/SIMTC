import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { ParticipantsService } from 'src/participants/participants.service';
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

describe('ParticipantsService', () => {
  let service: ParticipantsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ParticipantsService,
        { provide: PrismaService, useValue: mockPrisma },
        // O serviço passou a mandar e-mail e guardar arquivos: nos testes,
        // os dois só precisam existir.
        { provide: EmailService, useValue: {} },
        { provide: StorageService, useValue: {} },
      ],
    }).compile();

    service = module.get<ParticipantsService>(ParticipantsService);
    jest.clearAllMocks();
    mockPrisma.trainingParticipant.findMany.mockResolvedValue([]);
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
      mockPrisma.participant.update.mockResolvedValue({ id: 'part-1' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });
      await expect(service.registerPublic('token', dto as any)).rejects.toThrow(ConflictException);
    });

    it('reutiliza participante existente pelo CPF', async () => {
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'part-existente' });
      mockPrisma.participant.update.mockResolvedValue({ id: 'part-existente' });
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
      mockPrisma.participant.update.mockResolvedValue({ id: 'part-1' });
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
