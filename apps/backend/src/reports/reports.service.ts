import { Injectable, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload } from '@simtc/shared-types';

@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async getTrainingSessions(user: JwtPayload) {
    const where =
      user.role === 'CONSULTANT'
        ? { consultants: { some: { consultantId: user.consultantId } } }
        : user.role === 'CLIENT'
          ? { companyId: user.companyId }
          : {};

    return this.prisma.trainingSession.findMany({
      where,
      include: {
        company: true,
        course: true,
        responsibleConsultant: true,
        _count: {
          select: { participants: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getSessionReport(id: string, user: JwtPayload) {
    const session = await this.prisma.trainingSession.findUniqueOrThrow({
      where: { id },
      include: {
        company: true,
        course: true,
        responsibleConsultant: true,
        consultants: { include: { consultant: true } },
        participants: {
          include: {
            participant: true,
            assessment: {
              include: {
                items: {
                  include: {
                    infractionNote: {
                      include: { infraction: { include: { category: true } } },
                    },
                  },
                },
              },
            },
            certificate: true,
          },
        },
      },
    });

    if (user.role === 'CLIENT') {
      if (session.companyId !== user.companyId) {
        throw new ForbiddenException('Acesso negado');
      }
    } else if (user.role === 'CONSULTANT') {
      const isAssigned = session.consultants.some(
        (c) => c.consultantId === user.consultantId,
      );
      if (!isAssigned) {
        throw new ForbiddenException('Você não tem acesso a este treinamento');
      }
    }

    return session;
  }

  async getCompanyHistory(companyId: string, user: JwtPayload) {
    if (user.role === 'CLIENT' && user.companyId !== companyId) {
      throw new ForbiddenException('Acesso negado');
    }

    return this.prisma.trainingSession.findMany({
      where: { companyId },
      include: {
        course: true,
        _count: { select: { participants: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }
}
