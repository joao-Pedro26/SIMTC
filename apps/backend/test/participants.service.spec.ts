import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { Reflector } from '@nestjs/core';
import { UserRole } from '@simtc/shared-types';
import { ROLES_KEY } from 'src/auth/decorators/roles.decorator';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { RolesGuard } from 'src/auth/guards/roles.guard';
import { ParticipantsService } from 'src/participants/participants.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { EmailService } from 'src/email/email.service';
import { StorageService } from 'src/storage/storage.service';
import { ParticipantsController } from 'src/participants/participants.controller';
import { AddParticipantDto } from 'src/participants/dto/add-participant.dto';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

const mockStorage = { upload: jest.fn(), delete: jest.fn(), getSignedUrl: jest.fn() };

const mockPrisma = {
  trainingSession: { findUniqueOrThrow: jest.fn(), findUnique: jest.fn() },
  participant: { findUnique: jest.fn(), findMany: jest.fn(), create: jest.fn(), update: jest.fn(), updateMany: jest.fn(), deleteMany: jest.fn() },
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
        { provide: StorageService, useValue: mockStorage },
      ],
    }).compile();

    service = module.get<ParticipantsService>(ParticipantsService);
    jest.clearAllMocks();
    mockPrisma.trainingParticipant.findMany.mockResolvedValue([]);
    mockPrisma.participant.updateMany.mockResolvedValue({ count: 1 });
    mockPrisma.participant.findMany.mockResolvedValue([]);
    mockStorage.upload.mockResolvedValue('https://storage/x.png');
    mockStorage.delete.mockResolvedValue(undefined);
    mockStorage.getSignedUrl.mockResolvedValue('https://storage/signed.png?token=abc');
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

  // ─── registerPublic — assinatura ─────────────────────────────────────────

  describe('registerPublic — assinatura', () => {
    const baseDto = {
      name: 'João',
      cpf: '12345678901',
      email: 'joao@mail.com',
      cnhCategory: 'B',
      participationType: 'TEORICA_E_PRATICA',
    };
    const pngBuffer = () => {
      const buf = Buffer.alloc(33);
      Buffer.from('89504E470D0A1A0A', 'hex').copy(buf, 0);
      buf.writeUInt32BE(13, 8);
      buf.write('IHDR', 12, 'ascii');
      buf.writeUInt32BE(100, 16);
      buf.writeUInt32BE(50, 20);
      return buf;
    };
    const pngFile = (buffer: Buffer = pngBuffer()) =>
      ({ buffer, mimetype: 'image/png', size: buffer.length, originalname: 'assinatura.png' }) as Express.Multer.File;
    const existing = (over: Record<string, unknown> = {}) => ({
      id: 'part-1',
      email: 'joao@mail.com',
      signaturePath: null,
      ...over,
    });
    const NEW_PATH = /^participants\/part-1\/\d+\.png$/;

    beforeEach(() => {
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue({
        id: 'sess-1',
        status: 'PLANEJADO',
        course: { name: 'NR-11' },
        company: { name: 'Acme', logoUrl: null },
      });
      mockPrisma.participant.findUnique.mockResolvedValue(null);
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);
      mockPrisma.participant.update.mockResolvedValue({ id: 'part-1' });
      mockPrisma.participant.create.mockResolvedValue({ id: 'part-novo' });
      mockPrisma.trainingParticipant.create.mockResolvedValue({ id: 'tp-1', participantId: 'part-1' });
    });

    it('salva assinatura nova: sobe o PNG antes da transação e grava o caminho', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(existing());

      const result = await service.registerPublic('token', { ...baseDto, signatureAction: 'replace' } as any, pngFile());

      expect(mockStorage.upload).toHaveBeenCalledWith('signatures', expect.stringMatching(NEW_PATH), expect.any(Buffer), 'image/png');
      expect(mockStorage.upload.mock.invocationCallOrder[0]).toBeLessThan(mockPrisma.$transaction.mock.invocationCallOrder[0]);
      expect(mockPrisma.participant.updateMany).toHaveBeenCalledWith({
        where: { id: 'part-1', signaturePath: null },
        data: { signaturePath: expect.stringMatching(NEW_PATH), signatureUpdatedAt: expect.any(Date) },
      });
      expect(result).toEqual(expect.objectContaining({ signatureSaved: true }));
      expect(result).not.toHaveProperty('signatureIgnored');
      expect(mockStorage.delete).not.toHaveBeenCalled();
    });

    it('participante novo: cria o cadastro com id gerado e grava a assinatura nele', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(null);

      const result = await service.registerPublic('token', { ...baseDto, signatureAction: 'replace' } as any, pngFile());

      const id = mockPrisma.participant.create.mock.calls[0][0].data.id;
      expect(typeof id).toBe('string');
      expect(mockStorage.upload).toHaveBeenCalledWith(
        'signatures',
        expect.stringMatching(new RegExp(`^participants/${id}/\\d+\\.png$`)),
        expect.any(Buffer),
        'image/png',
      );
      expect(mockPrisma.participant.updateMany).toHaveBeenCalledWith({
        where: { id, signaturePath: null },
        data: expect.objectContaining({ signaturePath: expect.any(String) }),
      });
      expect(result).toEqual(expect.objectContaining({ signatureSaved: true }));
    });

    it.each([['keep'], ['none']])('signatureAction %s: não sobe nada e não marca como salva', async (action) => {
      mockPrisma.participant.findUnique.mockResolvedValue(existing({ signaturePath: 'participants/part-1/1.png' }));

      const result = await service.registerPublic('token', { ...baseDto, signatureAction: action } as any, pngFile());

      expect(mockStorage.upload).not.toHaveBeenCalled();
      expect(mockPrisma.participant.updateMany).not.toHaveBeenCalled();
      expect(result).toEqual(expect.objectContaining({ signatureSaved: false }));
      expect(result).not.toHaveProperty('signatureIgnored');
    });

    it('sem signatureAction (ausente = none): não sobe nada', async () => {
      const result = await service.registerPublic('token', { ...baseDto } as any);

      expect(mockStorage.upload).not.toHaveBeenCalled();
      expect(result).toEqual(expect.objectContaining({ signatureSaved: false }));
      expect(result).not.toHaveProperty('signatureIgnored');
    });

    it('replace com assinatura já salva e e-mail diferente: mantém a antiga e marca signatureIgnored', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(
        existing({ email: 'outro@mail.com', signaturePath: 'participants/part-1/old.png' }),
      );

      const result = await service.registerPublic('token', { ...baseDto, signatureAction: 'replace' } as any, pngFile());

      expect(mockStorage.upload).not.toHaveBeenCalled();
      expect(mockStorage.delete).not.toHaveBeenCalled();
      expect(mockPrisma.participant.updateMany).not.toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.create).toHaveBeenCalled();
      expect(result).toEqual(expect.objectContaining({ signatureSaved: false, signatureIgnored: true }));
    });

    it('replace com assinatura já salva e e-mail igual (caixa e espaços): sobe a nova e apaga a antiga após o commit', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(
        existing({ email: 'joao@mail.com', signaturePath: 'participants/part-1/old.png' }),
      );

      const result = await service.registerPublic(
        'token',
        { ...baseDto, email: '  JOAO@Mail.com ', signatureAction: 'replace' } as any,
        pngFile(),
      );

      expect(mockStorage.upload).toHaveBeenCalledWith('signatures', expect.stringMatching(NEW_PATH), expect.any(Buffer), 'image/png');
      expect(mockPrisma.participant.updateMany).toHaveBeenCalledWith({
        where: { id: 'part-1', signaturePath: 'participants/part-1/old.png' },
        data: { signaturePath: expect.stringMatching(NEW_PATH), signatureUpdatedAt: expect.any(Date) },
      });
      expect(mockStorage.delete).toHaveBeenCalledTimes(1);
      expect(mockStorage.delete).toHaveBeenCalledWith('signatures', 'participants/part-1/old.png');
      expect(mockStorage.delete.mock.invocationCallOrder[0]).toBeGreaterThan(
        mockPrisma.$transaction.mock.invocationCallOrder[0],
      );
      expect(result).toEqual(expect.objectContaining({ signatureSaved: true }));
      expect(result).not.toHaveProperty('signatureIgnored');
    });

    it('falha no upload: inscrição criada, signatureSaved false', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(existing());
      mockStorage.upload.mockRejectedValue(new Error('bucket fora do ar'));

      const result = await service.registerPublic('token', { ...baseDto, signatureAction: 'replace' } as any, pngFile());

      expect(mockPrisma.trainingParticipant.create).toHaveBeenCalled();
      expect(mockPrisma.participant.updateMany).not.toHaveBeenCalled();
      expect(result).toEqual(expect.objectContaining({ signatureSaved: false }));
      expect(result).not.toHaveProperty('signatureIgnored');
    });

    it('falha na transação: apaga o arquivo recém-enviado e propaga o erro', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(existing());
      mockPrisma.trainingParticipant.create.mockRejectedValue(new Error('falha no banco'));

      await expect(
        service.registerPublic('token', { ...baseDto, signatureAction: 'replace' } as any, pngFile()),
      ).rejects.toThrow('falha no banco');
      expect(mockStorage.delete).toHaveBeenCalledWith('signatures', expect.stringMatching(NEW_PATH));
    });

    it('updateMany sem linhas (outra gravação ganhou a corrida): apaga o novo arquivo e marca signatureIgnored', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(existing());
      mockPrisma.participant.updateMany.mockResolvedValue({ count: 0 });

      const result = await service.registerPublic('token', { ...baseDto, signatureAction: 'replace' } as any, pngFile());

      expect(mockStorage.delete).toHaveBeenCalledTimes(1);
      expect(mockStorage.delete).toHaveBeenCalledWith('signatures', expect.stringMatching(NEW_PATH));
      expect(result).toEqual(expect.objectContaining({ signatureSaved: false, signatureIgnored: true }));
    });

    it('replace sem arquivo: BadRequestException', async () => {
      await expect(
        service.registerPublic('token', { ...baseDto, signatureAction: 'replace' } as any),
      ).rejects.toThrow(BadRequestException);
      expect(mockStorage.upload).not.toHaveBeenCalled();
    });

    it('arquivo que não é PNG: BadRequestException', async () => {
      await expect(
        service.registerPublic('token', { ...baseDto, signatureAction: 'replace' } as any, pngFile(Buffer.alloc(40))),
      ).rejects.toThrow(BadRequestException);
      expect(mockStorage.upload).not.toHaveBeenCalled();
    });

    it('signatureAction desconhecido: BadRequestException', async () => {
      await expect(
        service.registerPublic('token', { ...baseDto, signatureAction: 'apagar' } as any),
      ).rejects.toThrow(BadRequestException);
    });

    it('participationType fora do enum: BadRequestException', async () => {
      await expect(
        service.registerPublic('token', { ...baseDto, participationType: 'OUTRO', signatureAction: 'none' } as any),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // ─── addParticipant──────────────────────────────────────────────────────

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
      mockPrisma.trainingParticipant.create.mockResolvedValue({ id: 'tp-1', participant: { id: 'part-1' } });

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
      mockPrisma.trainingParticipant.create.mockResolvedValue({ id: 'tp-1', participant: { id: 'part-1' } });

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

  // ─── signaturePreview ────────────────────────────────────────────────────

  describe('signaturePreview', () => {
    const CPF = '52998224725';
    const UPDATED = new Date('2026-10-01T12:00:00.000Z');
    const withSignature = (over: Record<string, unknown> = {}) => ({
      id: 'part-1',
      name: 'João Segredo',
      cpf: CPF,
      cnhCategory: 'B',
      email: 'joao@mail.com',
      signaturePath: 'participants/part-1/123.png',
      signatureUpdatedAt: UPDATED,
      ...over,
    });

    beforeEach(() => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue(null);
    });

    it('lança 404 se o token não corresponde a nenhuma sessão', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(null);
      await expect(
        service.signaturePreview('token-inexistente', { cpf: CPF, email: 'joao@mail.com' }),
      ).rejects.toThrow(NotFoundException);
    });

    it.each([['CANCELADO'], ['CONCLUIDO']])('sessão %s: BadRequestException', async (status) => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: 'sess-1', status });
      await expect(
        service.signaturePreview('token', { cpf: CPF, email: 'joao@mail.com' }),
      ).rejects.toThrow(BadRequestException);
      expect(mockPrisma.participant.findUnique).not.toHaveBeenCalled();
    });

    it('none se o CPF não está cadastrado', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(null);
      const result = await service.signaturePreview('token', { cpf: CPF, email: 'joao@mail.com' });
      expect(result).toEqual({ status: 'none' });
      expect(mockStorage.getSignedUrl).not.toHaveBeenCalled();
    });

    it('none se o CPF existe mas não tem assinatura', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(withSignature({ signaturePath: null, signatureUpdatedAt: null }));
      const result = await service.signaturePreview('token', { cpf: CPF, email: 'joao@mail.com' });
      expect(result).toEqual({ status: 'none' });
      expect(mockStorage.getSignedUrl).not.toHaveBeenCalled();
    });

    it('normaliza o CPF com máscara antes de buscar', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(null);
      await service.signaturePreview('token', { cpf: '529.982.247-25', email: 'joao@mail.com' });
      expect(mockPrisma.participant.findUnique).toHaveBeenCalledWith({ where: { cpf: CPF } });
    });

    it('found: CPF e e-mail conferem (caixa e espaços), signed URL de 120 s', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(withSignature());
      const result = await service.signaturePreview('token', { cpf: CPF, email: '  JOAO@mail.com ' });
      expect(mockStorage.getSignedUrl).toHaveBeenCalledWith('signatures', 'participants/part-1/123.png', 120);
      expect(result).toEqual({
        status: 'found',
        previewUrl: 'https://storage/signed.png?token=abc',
        updatedAt: UPDATED.toISOString(),
      });
    });

    it('locked: e-mail diferente, sem previewUrl e sem gerar signed URL', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(withSignature());
      const result = await service.signaturePreview('token', { cpf: CPF, email: 'outro@mail.com' });
      expect(result).toEqual({ status: 'locked' });
      expect(mockStorage.getSignedUrl).not.toHaveBeenCalled();
    });

    it('locked: cadastro sem e-mail nunca confere', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(withSignature({ email: null }));
      const result = await service.signaturePreview('token', { cpf: CPF, email: 'joao@mail.com' });
      expect(result).toEqual({ status: 'locked' });
    });

    it('falha ao gerar signed URL: none', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(withSignature());
      mockStorage.getSignedUrl.mockRejectedValue(new Error('storage fora do ar'));
      const result = await service.signaturePreview('token', { cpf: CPF, email: 'joao@mail.com' });
      expect(result).toEqual({ status: 'none' });
    });
  });

  // ─── removeOwnSignature ──────────────────────────────────────────────────

  describe('removeOwnSignature', () => {
    const CPF = '52998224725';
    const SIG_PATH = 'participants/part-1/123.png';
    const withSignature = (over: Record<string, unknown> = {}) => ({
      id: 'part-1',
      name: 'João Segredo',
      cpf: CPF,
      cnhCategory: 'B',
      email: 'joao@mail.com',
      signaturePath: SIG_PATH,
      signatureUpdatedAt: new Date('2026-10-01T12:00:00.000Z'),
      ...over,
    });

    beforeEach(() => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: 'sess-1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue(null);
    });

    it('remove quando CPF e e-mail conferem: zera o banco antes e apaga o arquivo depois', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(withSignature());
      const result = await service.removeOwnSignature('token', { cpf: CPF, email: '  JOAO@mail.com ' });

      expect(result).toEqual({ removed: true });
      expect(mockPrisma.participant.updateMany).toHaveBeenCalledWith({
        where: { id: 'part-1', signaturePath: SIG_PATH },
        data: { signaturePath: null, signatureUpdatedAt: null },
      });
      expect(mockStorage.delete).toHaveBeenCalledWith('signatures', SIG_PATH);
      const dbOrder = mockPrisma.participant.updateMany.mock.invocationCallOrder[0];
      const storageOrder = mockStorage.delete.mock.invocationCallOrder[0];
      expect(dbOrder).toBeLessThan(storageOrder);
    });

    it('403 quando o e-mail não confere, sem tocar em banco nem storage', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(withSignature());
      await expect(
        service.removeOwnSignature('token', { cpf: CPF, email: 'outro@mail.com' }),
      ).rejects.toThrow(ForbiddenException);
      expect(mockPrisma.participant.updateMany).not.toHaveBeenCalled();
      expect(mockStorage.delete).not.toHaveBeenCalled();
    });

    it('{ removed: false } quando o CPF não está cadastrado', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(null);
      const result = await service.removeOwnSignature('token', { cpf: CPF, email: 'joao@mail.com' });
      expect(result).toEqual({ removed: false });
      expect(mockPrisma.participant.updateMany).not.toHaveBeenCalled();
      expect(mockStorage.delete).not.toHaveBeenCalled();
    });

    it('{ removed: false } quando o participante não tem assinatura', async () => {
      mockPrisma.participant.findUnique.mockResolvedValue(withSignature({ signaturePath: null, signatureUpdatedAt: null }));
      const result = await service.removeOwnSignature('token', { cpf: CPF, email: 'joao@mail.com' });
      expect(result).toEqual({ removed: false });
      expect(mockPrisma.participant.updateMany).not.toHaveBeenCalled();
      expect(mockStorage.delete).not.toHaveBeenCalled();
    });

    it('falha do storage não desfaz a remoção no banco', async () => {
      const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
      mockPrisma.participant.findUnique.mockResolvedValue(withSignature());
      mockStorage.delete.mockRejectedValue(new Error('storage fora do ar'));

      const result = await service.removeOwnSignature('token', { cpf: CPF, email: 'joao@mail.com' });

      expect(result).toEqual({ removed: true });
      expect(mockPrisma.participant.updateMany).toHaveBeenCalledTimes(1);
      errorSpy.mockRestore();
    });

    it('sessão encerrada: BadRequestException, sem tocar em banco', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: 'sess-1', status: 'CONCLUIDO' });
      await expect(
        service.removeOwnSignature('token', { cpf: CPF, email: 'joao@mail.com' }),
      ).rejects.toThrow(BadRequestException);
      expect(mockPrisma.participant.findUnique).not.toHaveBeenCalled();
      expect(mockPrisma.participant.updateMany).not.toHaveBeenCalled();
    });
  });

  // ─── removeSignature (admin) ─────────────────────────────────────────────

  describe('removeSignature', () => {
    const SIG_PATH = 'participants/part-1/123.png';
    const inscricao = (signaturePath: string | null = SIG_PATH) => ({
      id: 'tp-1',
      participant: { id: 'part-1', signaturePath },
    });

    it('zera o banco e só depois apaga do storage', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(inscricao());

      const result = await service.removeSignature('tp-1');

      expect(result).toEqual({ removed: true });
      expect(mockPrisma.participant.updateMany).toHaveBeenCalledWith({
        where: { id: 'part-1', signaturePath: SIG_PATH },
        data: { signaturePath: null, signatureUpdatedAt: null },
      });
      expect(mockStorage.delete).toHaveBeenCalledWith('signatures', SIG_PATH);
      const dbOrder = mockPrisma.participant.updateMany.mock.invocationCallOrder[0];
      const storageOrder = mockStorage.delete.mock.invocationCallOrder[0];
      expect(dbOrder).toBeLessThan(storageOrder);
    });

    it('404 se a inscrição não existe, sem tocar em banco de participante nem storage', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);

      await expect(service.removeSignature('tp-x')).rejects.toThrow(NotFoundException);
      await expect(service.removeSignature('tp-x')).rejects.toThrow('Participante não encontrado');
      expect(mockPrisma.participant.updateMany).not.toHaveBeenCalled();
      expect(mockStorage.delete).not.toHaveBeenCalled();
    });

    it('{ removed: false } sem assinatura, sem tocar em banco nem storage', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(inscricao(null));

      const result = await service.removeSignature('tp-1');

      expect(result).toEqual({ removed: false });
      expect(mockPrisma.participant.updateMany).not.toHaveBeenCalled();
      expect(mockStorage.delete).not.toHaveBeenCalled();
    });

    it('falha do storage não desfaz a remoção no banco e não propaga o erro', async () => {
      const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(inscricao());
      mockStorage.delete.mockRejectedValue(new Error('storage fora do ar'));

      const result = await service.removeSignature('tp-1');

      expect(result).toEqual({ removed: true });
      expect(mockPrisma.participant.updateMany).toHaveBeenCalledTimes(1);
      errorSpy.mockRestore();
    });

    it('count === 0 (assinatura trocada no meio do caminho): { removed: false } sem tocar o storage', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(inscricao());
      mockPrisma.participant.updateMany.mockResolvedValue({ count: 0 });

      const result = await service.removeSignature('tp-1');

      expect(result).toEqual({ removed: false });
      expect(mockStorage.delete).not.toHaveBeenCalled();
    });
  });

  // ─── removeSignature: quem pode chamar ───────────────────────────────────

  describe('ParticipantsController.removeSignature: quem pode remover', () => {
    // A remoção pelo admin apaga a assinatura de vez: só ADMIN. Mesmo padrão
    // de metadado de guard dos outros endpoints admin (ver participants-lookup.spec.ts).
    const handler = ParticipantsController.prototype.removeSignature;
    const reflector = new Reflector();

    it('exige o papel ADMIN', () => {
      expect(reflector.get<UserRole[]>(ROLES_KEY, handler)).toEqual([UserRole.ADMIN]);
    });

    it('passa pelo JwtAuthGuard e, depois dele, pelo RolesGuard', () => {
      expect(reflector.get(GUARDS_METADATA, handler)).toEqual([JwtAuthGuard, RolesGuard]);
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

    it('removeParticipant apaga a assinatura do último vínculo', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
        id: 'tp-1', status: 'PENDENTE', participantId: 'p1', assessment: null, certificate: null,
      });
      mockPrisma.trainingParticipant.delete.mockResolvedValue({ id: 'tp-1' });
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([]);
      mockPrisma.participant.findMany.mockResolvedValue([
        { id: 'p1', signaturePath: 'participants/p1/123.png' },
      ]);

      await service.removeParticipant('tp-1');

      expect(mockStorage.delete).toHaveBeenCalledWith('signatures', 'participants/p1/123.png');
      expect(mockStorage.delete.mock.invocationCallOrder[0]).toBeGreaterThan(
        mockPrisma.$transaction.mock.invocationCallOrder[0],
      );
    });

    it('removeParticipant não apaga a assinatura se o participante continua em outro treinamento', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
        id: 'tp-1', status: 'PENDENTE', participantId: 'p1', assessment: null, certificate: null,
      });
      mockPrisma.trainingParticipant.delete.mockResolvedValue({ id: 'tp-1' });
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([{ participantId: 'p1' }]);

      await service.removeParticipant('tp-1');

      expect(mockPrisma.participant.deleteMany).not.toHaveBeenCalled();
      expect(mockStorage.delete).not.toHaveBeenCalledWith('signatures', expect.anything());
    });
  });

  // --- hasSignature sem vazar o path ---------------------------------------

  describe('participante nas respostas: hasSignature sem signaturePath', () => {
    const withSig = {
      id: 'p1', name: 'Maria', cpf: '1', signaturePath: 'participants/p1/1.png', signatureUpdatedAt: new Date(),
    };
    const noSig = { id: 'p2', name: 'Joao', cpf: '2', signaturePath: null, signatureUpdatedAt: null };

    function expectPublic(participant: Record<string, unknown>, has: boolean) {
      expect(participant.hasSignature).toBe(has);
      expect(participant).not.toHaveProperty('signaturePath');
      expect(participant).not.toHaveProperty('signatureUpdatedAt');
    }

    it('findBySession não expõe signaturePath/signatureUpdatedAt e devolve hasSignature true/false', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp1', participant: withSig, assessment: null },
        { id: 'tp2', participant: noSig, assessment: { id: 'a1' } },
      ]);
      const result = (await service.findBySession('s1')) as any[];
      expectPublic(result[0].participant, true);
      expectPublic(result[1].participant, false);
      expect(result[1].assessment).toEqual({ id: 'a1' });
      expect(result[0].id).toBe('tp1');
    });

    it('addParticipant devolve o participante sem o caminho da assinatura', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: 's1', status: 'PLANEJADO' });
      mockPrisma.participant.findUnique.mockResolvedValue(null);
      mockPrisma.participant.create.mockResolvedValue({ id: 'p1' });
      mockPrisma.trainingParticipant.create.mockResolvedValue({ id: 'tp1', participant: withSig });
      const result = (await service.addParticipant('s1', {
        cpf: '1', name: 'Maria', email: null, cnhCategory: null, cnhExpiration: null, participationType: 'TEORICA_E_PRATICA',
      } as any)) as any;
      expectPublic(result.participant, true);
    });

    it('updateParticipationType devolve o participante sem o caminho da assinatura', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp1' });
      mockPrisma.trainingParticipant.update.mockResolvedValue({ id: 'tp1', participant: noSig });
      const result = (await service.updateParticipationType('tp1', { participationType: 'SOMENTE_TEORICA' } as any)) as any;
      expectPublic(result.participant, false);
    });
  });
});
