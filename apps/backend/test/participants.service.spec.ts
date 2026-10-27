import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { ParticipantsService } from 'src/participants/participants.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { EmailService } from 'src/email/email.service';
import { StorageService } from 'src/storage/storage.service';
import { ParticipantsController } from 'src/participants/participants.controller';
import { AddParticipantDto } from 'src/participants/dto/add-participant.dto';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

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
