import { Injectable, ConflictException, NotFoundException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAdminDto } from './dto/create-admin.dto';
import { ChangePasswordDto } from './dto/change-password.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async createAdmin(dto: CreateAdminDto) {
    const existing = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (existing) throw new ConflictException('Já existe um usuário com este e-mail');

    const passwordHash = await bcrypt.hash(dto.password, 12);

    // Cria Consultant + User em transação — todo admin tem perfil de consultor vinculado
    const user = await this.prisma.$transaction(async (tx) => {
      const consultant = await tx.consultant.create({
        data: { name: dto.name, email: dto.email },
      });

      return tx.user.create({
        data: {
          email: dto.email,
          passwordHash,
          role: 'ADMIN',
          consultantId: consultant.id,
        },
      });
    });

    const { passwordHash: _, ...result } = user;
    return result;
  }

  async findAll() {
    const users = await this.prisma.user.findMany({
      select: {
        id: true,
        email: true,
        role: true,
        createdAt: true,
        lastLogin: true,
        consultantId: true,
        contactId: true,
      },
      orderBy: { createdAt: 'desc' },
    });
    return users;
  }

  async changePassword(userId: string, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('Usuário não encontrado');
    if (!user.passwordHash) {
      throw new UnauthorizedException('Este usuário não usa senha — acesso via código OTP');
    }

    const valid = await bcrypt.compare(dto.currentPassword, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Senha atual incorreta');

    const newHash = await bcrypt.hash(dto.newPassword, 12);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newHash },
    });

    return { message: 'Senha alterada com sucesso' };
  }
}