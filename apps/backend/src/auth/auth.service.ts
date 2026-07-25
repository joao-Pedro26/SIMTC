import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto, AuthTokensDto, JwtPayload } from '@simtc/shared-types';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
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
    });
  }

  async refresh(refreshToken: string): Promise<AuthTokensDto> {
    try {
      const payload = this.jwt.verify(refreshToken, {
        secret: process.env.JWT_REFRESH_SECRET,
      }) as JwtPayload;
      return this.generateTokens(payload);
    } catch {
      throw new UnauthorizedException('Refresh token inválido ou expirado');
    }
  }

  private generateTokens(payload: JwtPayload): AuthTokensDto {
    const accessToken = this.jwt.sign(payload, {
      secret: process.env.JWT_SECRET,
      expiresIn: process.env.JWT_EXPIRES_IN ?? '15m',
    });
    const refreshToken = this.jwt.sign(payload, {
      secret: process.env.JWT_REFRESH_SECRET,
      expiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '7d',
    });
    return { accessToken, refreshToken };
  }
}
