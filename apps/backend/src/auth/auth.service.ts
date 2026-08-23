import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomBytes, randomInt } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { AuthTokensDto, JwtPayload, MeResponseDto } from '@simtc/shared-types';
import { LoginDto } from './dto/login.dto';
import { EmailService } from '../email/email.service';

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
      include: { contact: { select: { companyId: true } }, consultant: { select: { active: true } } },
    });
    if (!user) throw new UnauthorizedException('Credenciais inválidas');

    if (!user.passwordHash) throw new UnauthorizedException('Credenciais inválidas');
    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Credenciais inválidas');

    // Consultor desativado manualmente (Consultant.active = false) perde o acesso de
    // login mesmo com a senha correta. Consultor excluído de fato (ver
    // ConsultantsService.deleteConsultant) já não tem mais User/Consultant no banco,
    // então nem chega a essa checagem.
    if (user.consultant && !user.consultant.active) {
      throw new UnauthorizedException('Credenciais inválidas');
    }

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
      // O JWT assinado já garante autenticidade — não precisamos de bcrypt adicional.
      // Verificar a assinatura + expiração é suficiente para um refresh token.
      const payload = this.jwt.verify(refreshToken, {
        secret: process.env.JWT_REFRESH_SECRET,
      }) as JwtPayload;

      // Confirma que o usuário ainda existe no sistema
      const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user) throw new UnauthorizedException('Usuário não encontrado');

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

  async forgotPassword(email: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { email },
      include: { consultant: true, contact: true },
    });

    // Retorna silenciosamente mesmo se o e-mail não existir ou for CLIENT (OTP-only)
    // para não vazar quais e-mails estão cadastrados.
    if (!user || !user.passwordHash) return;

    const token = randomBytes(32).toString('hex');
    const hash = await bcrypt.hash(token, 12);
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);

    await this.prisma.user.update({
      where: { id: user.id },
      data: { resetTokenHash: hash, resetTokenExpiresAt: expiresAt },
    });

    const resetLink = `${process.env.FRONTEND_URL}/reset-password?token=${token}`;
    const participantName = user.consultant?.name ?? user.contact?.name ?? user.email;
    await this.email.sendPasswordReset(email, resetLink, participantName);
  }

  async resetPassword(token: string, newPassword: string): Promise<void> {
    // Precisamos encontrar o usuário cujo hash bate com o token recebido.
    // Como não há índice direto no token em texto puro, buscamos todos os candidatos
    // com resetTokenHash não-nulo e expiração no futuro, depois comparamos com bcrypt.
    // Na prática haverá pouquíssimos registros simultaneamente nesse estado.
    const candidates = await this.prisma.user.findMany({
      where: {
        resetTokenHash: { not: null },
        resetTokenExpiresAt: { gt: new Date() },
      },
    });

    let matched: (typeof candidates)[0] | null = null;
    for (const candidate of candidates) {
      if (candidate.resetTokenHash && await bcrypt.compare(token, candidate.resetTokenHash)) {
        matched = candidate;
        break;
      }
    }

    if (!matched) throw new UnauthorizedException('Token inválido ou expirado');

    const passwordHash = await bcrypt.hash(newPassword, 12);
    await this.prisma.user.update({
      where: { id: matched.id },
      data: { passwordHash, resetTokenHash: null, resetTokenExpiresAt: null },
    });
  }

  private generateTokens(payload: JwtPayload): AuthTokensDto {
    // Remove campos de controle interno do JWT antes de assinar
    const { iat, exp, ...cleanPayload } = payload as JwtPayload & { iat?: number; exp?: number };

    const accessToken = this.jwt.sign(cleanPayload, {
      secret: process.env.JWT_SECRET,
      expiresIn: process.env.JWT_EXPIRES_IN ?? '8h',
    });
    const refreshToken = this.jwt.sign(cleanPayload, {
      secret: process.env.JWT_REFRESH_SECRET,
      expiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '30d',
    });

    return { accessToken, refreshToken };
  }

  async getMe(userId: string): Promise<MeResponseDto> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { consultant: true, contact: true },
    });
    if (!user) throw new UnauthorizedException('Usuário não encontrado');

    const name = user.consultant?.name ?? user.contact?.name ?? user.email;

    return {
      id: user.id,
      name,
      email: user.email,
      role: user.role,
    };
  }

  async checkEmail(email: string): Promise<{ authMethod: 'password' | 'otp' | 'not_found' }> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return { authMethod: 'not_found' };
    return { authMethod: user.role === 'CLIENT' ? 'otp' : 'password' };
  }

  async requestOtp(email: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { email },
      include: { consultant: true, contact: true },
    });
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

    const participantName = user.consultant?.name ?? user.contact?.name ?? " ";
    await this.email.sendOtpCode(email, code, participantName);
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
