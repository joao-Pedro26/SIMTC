import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { AuthTokensDto, JwtPayload } from '@simtc/shared-types';
import { LoginDto } from './dto/login.dto';
import { EmailService } from '../email/email.service';
import { randomInt } from 'crypto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly email: EmailService,
  ) {}

  async login(dto: LoginDto): Promise<AuthTokensDto> {
    // include: { contact } traz a relação junto com o usuário.
    // Sem isso, user.contact seria undefined em runtime e TypeScript
    // reclamaria no tipo porque a relação não é carregada por padrão.
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
      include: { contact: { select: { companyId: true } } },
    });
    if (!user) throw new UnauthorizedException('Credenciais inválidas');

    if (!user.passwordHash) throw new UnauthorizedException('Credenciais inválidas');
    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Credenciais inválidas');

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLogin: new Date() },
    });

    return this.generateTokens({
      sub: user.id,
      email: user.email,
      role: user.role,
      consultantId: user.consultantId ?? undefined,
      companyId: user.contact?.companyId ?? undefined,
    } as JwtPayload);
  }

  async refresh(refreshToken: string): Promise<AuthTokensDto> {
    try {
      const payload = this.jwt.verify(refreshToken, {
        secret: process.env.JWT_REFRESH_SECRET,
      }) as JwtPayload;

      const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user?.refreshTokenHash) throw new UnauthorizedException('Refresh token inválido');

      const valid = await bcrypt.compare(refreshToken, user.refreshTokenHash);
      if (!valid) throw new UnauthorizedException('Refresh token inválido');

      return this.generateTokens(payload);
    } catch {
      throw new UnauthorizedException('Refresh token inválido ou expirado');
    }
  }

  async logout(userId: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { refreshTokenHash: null },
    });
  }

  private async generateTokens(payload: JwtPayload): Promise<AuthTokensDto> {
    const accessToken = this.jwt.sign(payload, {
      secret: process.env.JWT_SECRET,
      expiresIn: process.env.JWT_EXPIRES_IN ?? '15m',
    });
    const refreshToken = this.jwt.sign(payload, {
      secret: process.env.JWT_REFRESH_SECRET,
      expiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '7d',
    });

    const hash = await bcrypt.hash(refreshToken, 10);
    await this.prisma.user.update({
      where: { id: payload.sub },
      data: { refreshTokenHash: hash },
    });

    return { accessToken, refreshToken };
  }

  async requestOtp(email: string): Promise<void> {
    const user = await this.prisma.user.findUnique({where: { email } });
    if (!user || user.role !== 'CLIENT') {
      return;
    }

    const code = randomInt(100000, 1000000).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

    await this.prisma.user.update({
      where: { email },
      data: {
        otpCode: code,
        otpExpiresAt: expiresAt
      },
    });

    await this.email.sendOtpCode(email, code);
  }

  async verifyOtp(email: string, code: string): Promise<AuthTokensDto> {
    const user = await this.prisma.user.findUnique({
      where: { email },
      include: { contact: {select: {companyId: true } } },
    });

    if (
      !user ||
      user.role !== 'CLIENT' ||
      user.otpCode !== code ||
      !user.otpExpiresAt ||
      user.otpExpiresAt < new Date()
    ) {
      throw new UnauthorizedException('Código inválido ou expirado');
    }

    await this.prisma.user.update({
      where: { email },
      data: {
        otpCode: null,
        otpExpiresAt: null,
        lastLogin: new Date()
      },
    });

    return this.generateTokens({
      sub: user.id,
      email: user.email,
      role: user.role,
      companyId: user.contact?.companyId ?? undefined,
    } as JwtPayload);
  }
}
