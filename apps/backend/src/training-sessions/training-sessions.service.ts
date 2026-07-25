import { Injectable, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload } from '@simtc/shared-types';

@Injectable()
export class TrainingSessionsService {
  constructor(private readonly prisma: PrismaService) {}

  /** ADMIN vê todas as sessões; CONSULTANT vê apenas as suas */
  findAll(user: JwtPayload) {
    const where =
      user.role === 'CONSULTANT'
        ? {
            consultants: {
              some: { consultantId: user.consultantId },
            },
          }
        : {};

    return this.prisma.trainingSession.findMany({
      where,
      include: {
        company: { select: { id: true, name: true } },
        course: { select: { id: true, name: true } },
        responsibleConsultant: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  findOne(id: string) {
    return this.prisma.trainingSession.findUniqueOrThrow({
      where: { id },
      include: {
        company: true,
        course: true,
        responsibleConsultant: true,
        consultants: { include: { consultant: true } },
        participants: { include: { participant: true, assessment: true } },
      },
    });
  }

  async start(id: string) {
    return this.prisma.trainingSession.update({
      where: { id },
      data: { status: 'EM_ANDAMENTO' },
    });
  }

  async complete(id: string) {
    return this.prisma.trainingSession.update({
      where: { id },
      data: { status: 'CONCLUIDO' },
    });
  }

  findByQrToken(qrCodeToken: string) {
    return this.prisma.trainingSession.findUniqueOrThrow({
      where: { qrCodeToken },
      include: {
        course: { select: { name: true } },
        company: { select: { name: true } },
        responsibleConsultant: { select: { name: true } },
      },
    });
  }
}
