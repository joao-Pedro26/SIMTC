import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { UsersService } from 'src/users/users.service';
import { PrismaService } from 'src/prisma/prisma.service';

const mockPrisma = {
  user: {
    findUnique: jest.fn(),
    create: jest.fn(),
    findMany: jest.fn(),
    update: jest.fn(),
  },
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
  });

  // ─── createAdmin ─────────────────────────────────────────────────────────

  describe('createAdmin', () => {
    it('lança 409 se e-mail já existe', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: '1' });
      await expect(service.createAdmin({ email: 'a@a.com', password: '12345678' }))
        .rejects.toThrow(ConflictException);
    });

    it('cria admin sem retornar o passwordHash', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      mockPrisma.user.create.mockResolvedValue({
        id: '1', email: 'a@a.com', role: 'ADMIN', passwordHash: 'hash', createdAt: new Date(),
      });

      const result = await service.createAdmin({ email: 'a@a.com', password: '12345678' });

      expect(result).not.toHaveProperty('passwordHash');
      expect(mockPrisma.user.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ role: 'ADMIN' }) }),
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
