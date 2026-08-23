import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { UsersService } from 'src/users/users.service';
import { PrismaService } from 'src/prisma/prisma.service';

const mockTx = {
  consultant: { create: jest.fn() },
  user: { create: jest.fn() },
};

const mockPrisma = {
  user: {
    findUnique: jest.fn(),
    create: jest.fn(),
    findMany: jest.fn(),
    update: jest.fn(),
  },
  // $transaction executa o callback passando mockTx como "tx"
  $transaction: jest.fn((cb: (tx: typeof mockTx) => Promise<unknown>) => cb(mockTx)),
};

describe('UsersService', () => {
  let service: UsersService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    jest.clearAllMocks();
    // Reseta também os mocks do tx
    mockTx.consultant.create.mockReset();
    mockTx.user.create.mockReset();
  });

  // ─── createAdmin ─────────────────────────────────────────────────────────

  describe('createAdmin', () => {
    it('lança 409 se e-mail já existe', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: '1' });
      await expect(service.createAdmin({ name: 'Admin', email: 'a@a.com', password: '12345678' }))
        .rejects.toThrow(ConflictException);
    });

    it('cria admin sem retornar o passwordHash e com consultantId vinculado', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      mockTx.consultant.create.mockResolvedValue({ id: 'c1', name: 'Admin', email: 'a@a.com' });
      mockTx.user.create.mockResolvedValue({
        id: '1', email: 'a@a.com', role: 'ADMIN', consultantId: 'c1', passwordHash: 'hash', createdAt: new Date(),
      });

      const result = await service.createAdmin({ name: 'Admin', email: 'a@a.com', password: '12345678' });

      expect(result).not.toHaveProperty('passwordHash');
      expect(mockTx.consultant.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ name: 'Admin', email: 'a@a.com' }) }),
      );
      expect(mockTx.user.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ role: 'ADMIN', consultantId: 'c1' }) }),
      );
    });
  });

  // ─── changePassword ──────────────────────────────────────────────────────

  describe('changePassword', () => {
    it('lança 401 se usuário não tem senha (CLIENT com OTP)', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: '1', passwordHash: null });
      await expect(service.changePassword('1', { currentPassword: 'abc', newPassword: 'nova' }))
        .rejects.toThrow(UnauthorizedException);
    });

    it('lança 401 se senha atual incorreta', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: '1',
        passwordHash: await bcrypt.hash('correta', 10),
      });
      await expect(service.changePassword('1', { currentPassword: 'errada', newPassword: 'nova12345' }))
        .rejects.toThrow(UnauthorizedException);
    });

    it('atualiza senha com hash correto', async () => {
      const hash = await bcrypt.hash('correta', 10);
      mockPrisma.user.findUnique.mockResolvedValue({ id: '1', passwordHash: hash });
      mockPrisma.user.update.mockResolvedValue({});

      const result = await service.changePassword('1', { currentPassword: 'correta', newPassword: 'nova12345' });

      expect(result).toEqual({ message: 'Senha alterada com sucesso' });
      expect(mockPrisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: '1' } }),
      );
    });
  });
});
