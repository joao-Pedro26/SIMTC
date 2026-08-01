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

  async getSessionReport(id: string) {
    return this.prisma.trainingSession.findUniqueOrThrow({
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
