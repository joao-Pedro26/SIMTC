import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { Reflector } from '@nestjs/core';
import { UserRole } from '@simtc/shared-types';
import { ROLES_KEY } from 'src/auth/decorators/roles.decorator';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { RolesGuard } from 'src/auth/guards/roles.guard';
import { ParticipantsController } from 'src/participants/participants.controller';
import { ParticipantsService } from 'src/participants/participants.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { EmailService } from 'src/email/email.service';
import { StorageService } from 'src/storage/storage.service';

const mockPrisma = {
  trainingSession: { findUnique: jest.fn() },
  participant: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
  trainingParticipant: { findUnique: jest.fn(), create: jest.fn() },
};

// CPF válido (dígitos verificadores conferem).
const CPF = '52998224725';

describe('ParticipantsService.lookupByCpf', () => {
  let service: ParticipantsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ParticipantsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: EmailService, useValue: {} },
        { provide: StorageService, useValue: {} },
      ],
    }).compile();

    service = module.get(ParticipantsService);
    jest.clearAllMocks();
    mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: 'sess-1' });
  });

  it('lança 404 se a sessão não existe', async () => {
    mockPrisma.trainingSession.findUnique.mockResolvedValue(null);

    await expect(service.lookupByCpf('sess-x', CPF)).rejects.toThrow(NotFoundException);
    expect(mockPrisma.participant.findUnique).not.toHaveBeenCalled();
  });

  it('CPF sem cadastro: nada a preencher, e fora da sessão', async () => {
    mockPrisma.participant.findUnique.mockResolvedValue(null);

    await expect(service.lookupByCpf('sess-1', CPF)).resolves.toEqual({
      registered: false,
      name: null,
      email: null,
      enrolled: false,
    });
    expect(mockPrisma.participant.findUnique).toHaveBeenCalledWith({ where: { cpf: CPF } });
    expect(mockPrisma.trainingParticipant.findUnique).not.toHaveBeenCalled();
  });

  it('CPF com cadastro de outro treinamento: devolve nome e e-mail', async () => {
    mockPrisma.participant.findUnique.mockResolvedValue({
      id: 'part-1',
      name: 'Fernanda Lopes Meireles',
      email: 'fernanda@empresa.com.br',
    });
    mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);

    await expect(service.lookupByCpf('sess-1', CPF)).resolves.toEqual({
      registered: true,
      name: 'Fernanda Lopes Meireles',
      email: 'fernanda@empresa.com.br',
      enrolled: false,
    });
    expect(mockPrisma.trainingParticipant.findUnique).toHaveBeenCalledWith({
      where: {
        trainingSessionId_participantId: {
          trainingSessionId: 'sess-1',
          participantId: 'part-1',
        },
      },
      select: { id: true },
    });
  });

  it('cadastro sem e-mail devolve e-mail nulo', async () => {
    mockPrisma.participant.findUnique.mockResolvedValue({
      id: 'part-1',
      name: 'Fernanda Lopes Meireles',
      email: null,
    });
    mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);

    const result = await service.lookupByCpf('sess-1', CPF);

    expect(result.email).toBeNull();
  });

  it('CPF já inscrito nesta sessão: enrolled verdadeiro, com o nome', async () => {
    mockPrisma.participant.findUnique.mockResolvedValue({
      id: 'part-1',
      name: 'Fernanda Lopes Meireles',
      email: null,
    });
    mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });

    await expect(service.lookupByCpf('sess-1', CPF)).resolves.toEqual({
      registered: true,
      name: 'Fernanda Lopes Meireles',
      email: null,
      enrolled: true,
    });
  });

  it('só consulta: não cria nem altera cadastro ou inscrição', async () => {
    mockPrisma.participant.findUnique.mockResolvedValue({
      id: 'part-1',
      name: 'Fernanda Lopes Meireles',
      email: null,
    });
    mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);

    await service.lookupByCpf('sess-1', CPF);

    expect(mockPrisma.participant.create).not.toHaveBeenCalled();
    expect(mockPrisma.participant.update).not.toHaveBeenCalled();
    expect(mockPrisma.trainingParticipant.create).not.toHaveBeenCalled();
  });
});

describe('ParticipantsController.lookupParticipant', () => {
  const service = { lookupByCpf: jest.fn() };
  const controller = new ParticipantsController(service as unknown as ParticipantsService);

  beforeEach(() => {
    jest.clearAllMocks();
    service.lookupByCpf.mockResolvedValue({ registered: false, name: null, email: null, enrolled: false });
  });

  it('manda ao service o CPF só com dígitos', async () => {
    await controller.lookupParticipant('sess-1', { cpf: '529.982.247-25' });

    expect(service.lookupByCpf).toHaveBeenCalledWith('sess-1', CPF);
  });

  it('CPF com dígito verificador errado é 400, sem consultar', () => {
    expect(() => controller.lookupParticipant('sess-1', { cpf: '529.982.247-26' })).toThrow(
      BadRequestException,
    );
    expect(service.lookupByCpf).not.toHaveBeenCalled();
  });
});

describe('ParticipantsController.lookupParticipant: quem pode consultar', () => {
  // A consulta devolve nome e e-mail de quem já tem cadastro: é só para ADMIN
  // (decisões 4 e 11 da Fase 6A). Os testes acima chamam o método direto e
  // passam por cima dos guards; quem tranca a rota é o metadado que o Nest lê.
  // O papel e os guards estão no método, e não na classe: o `findBySession`
  // da mesma classe é aberto a qualquer usuário logado.
  const handler = ParticipantsController.prototype.lookupParticipant;
  const reflector = new Reflector();

  it('exige o papel ADMIN', () => {
    expect(reflector.get<UserRole[]>(ROLES_KEY, handler)).toEqual([UserRole.ADMIN]);
  });

  it('passa pelo JwtAuthGuard e, depois dele, pelo RolesGuard, que é quem lê o papel', () => {
    expect(reflector.get(GUARDS_METADATA, handler)).toEqual([JwtAuthGuard, RolesGuard]);
  });
});
