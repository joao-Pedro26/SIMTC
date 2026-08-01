import { Test, TestingModule } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { AuthService } from 'src/auth/auth.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { EmailService } from 'src/email/email.service';

const mockPrisma = {
  user: {
    findUnique: jest.fn(),
    update: jest.fn(),
  },
};

const mockJwt = {
  sign: jest.fn().mockReturnValue('token-mock'),
  verify: jest.fn(),
};

const mockEmail = {
  sendOtpCode: jest.fn(),
};

describe('AuthService', () => {
  let service: AuthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JwtService, useValue: mockJwt },
        { provide: EmailService, useValue: mockEmail },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    jest.clearAllMocks();
  });

  // ─── login ───────────────────────────────────────────────────────────────

  describe('login', () => {
    it('lança 401 se usuário não existe', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      await expect(service.login({ email: 'x@x.com', password: '123' }))
        .rejects.toThrow(UnauthorizedException);
    });

    it('lança 401 se usuário não tem senha (CLIENT com OTP)', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ passwordHash: null });
      await expect(service.login({ email: 'x@x.com', password: '123' }))
        .rejects.toThrow(UnauthorizedException);
    });

    it('lança 401 se senha incorreta', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: '1',
        email: 'a@a.com',
        passwordHash: await bcrypt.hash('correta', 10),
        role: 'ADMIN',
        consultantId: null,
        contact: null,
      });
      mockPrisma.user.update.mockResolvedValue({});
      await expect(service.login({ email: 'a@a.com', password: 'errada' }))
        .rejects.toThrow(UnauthorizedException);
    });

    it('retorna tokens se credenciais corretas', async () => {
      const hash = await bcrypt.hash('correta', 10);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: '1',
        email: 'a@a.com',
        passwordHash: hash,
        role: 'ADMIN',
        consultantId: null,
        contact: null,
      });
      mockPrisma.user.update.mockResolvedValue({});

      const result = await service.login({ email: 'a@a.com', password: 'correta' });
      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
    });
  });

  // ─── logout ──────────────────────────────────────────────────────────────

  describe('logout', () => {
    it('limpa o refreshTokenHash do usuário', async () => {
      mockPrisma.user.update.mockResolvedValue({});
      await service.logout('user-id');
      expect(mockPrisma.user.update).toHaveBeenCalledWith({
        where: { id: 'user-id' },
        data: { refreshTokenHash: null },
      });
    });
  });

  // ─── requestOtp ──────────────────────────────────────────────────────────

  describe('requestOtp', () => {
    it('não faz nada se usuário não existe', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      await service.requestOtp('x@x.com');
      expect(mockPrisma.user.update).not.toHaveBeenCalled();
      expect(mockEmail.sendOtpCode).not.toHaveBeenCalled();
    });

    it('não faz nada se usuário não é CLIENT', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ role: 'ADMIN' });
      await service.requestOtp('x@x.com');
      expect(mockEmail.sendOtpCode).not.toHaveBeenCalled();
    });

    it('gera OTP e envia e-mail para CLIENT', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: '1', email: 'c@c.com', role: 'CLIENT' });
      mockPrisma.user.update.mockResolvedValue({});
      await service.requestOtp('c@c.com');
      expect(mockPrisma.user.update).toHaveBeenCalled();
      expect(mockEmail.sendOtpCode).toHaveBeenCalledWith('c@c.com', expect.any(String));
    });
  });

  // ─── verifyOtp ───────────────────────────────────────────────────────────

  describe('verifyOtp', () => {
    it('lança 401 se usuário não existe', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      await expect(service.verifyOtp('x@x.com', '123456'))
        .rejects.toThrow(UnauthorizedException);
    });

    it('lança 401 se usuário não é CLIENT', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        role: 'ADMIN', otpCode: '123456', otpExpiresAt: new Date(Date.now() + 60000),
      });
      await expect(service.verifyOtp('x@x.com', '123456'))
        .rejects.toThrow(UnauthorizedException);
    });

    it('lança 401 se código incorreto', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        role: 'CLIENT', otpCode: '111111', otpExpiresAt: new Date(Date.now() + 60000),
      });
      await expect(service.verifyOtp('x@x.com', '999999'))
        .rejects.toThrow(UnauthorizedException);
    });

    it('lança 401 se OTP expirado', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        role: 'CLIENT', otpCode: '123456', otpExpiresAt: new Date(Date.now() - 1000),
      });
      await expect(service.verifyOtp('x@x.com', '123456'))
        .rejects.toThrow(UnauthorizedException);
    });

    it('retorna tokens se OTP válido', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: '1', email: 'c@c.com', role: 'CLIENT',
        otpCode: '123456', otpExpiresAt: new Date(Date.now() + 60000),
        contact: null,
      });
      mockPrisma.user.update.mockResolvedValue({});

      const result = await service.verifyOtp('c@c.com', '123456');
      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
      expect(mockPrisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ otpCode: null }) }),
      );
    });
  });
});
