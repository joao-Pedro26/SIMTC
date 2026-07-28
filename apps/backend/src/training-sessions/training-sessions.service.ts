import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload } from '@simtc/shared-types';
import { CreateTrainingSessionDto } from './dto/create-training-session.dto';
import { UpdateTrainingSessionDto } from './dto/update-training-session.dto';

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

  async findTrainingSessionById(id: string) {
    const session = await this.prisma.trainingSession.findUniqueOrThrow({
      where: { id },
      include: {
        company: true,
        course: true,
        responsibleConsultant: true,
        consultants: { include: { consultant: true } },
        participants: { include: { participant: true, assessment: true } },
      },
    });
    return session;
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

  async createTrainingSession(dto: CreateTrainingSessionDto) {
    const consultantsIds = [
      dto.responsibleConsultantId,
      ...(dto.additionalConsultantsIds ?? []),
    ].filter((id, index, self) => self.indexOf(id) === index);

    return this.prisma.$transaction(async (tx) => {
      const trainingSession = await tx.trainingSession.create({
        data: {
          companyId: dto.companyId,
          courseId: dto.courseId,
          responsibleConsultantId: dto.responsibleConsultantId,
          city: dto.city,
          state: dto.state,
          date: dto.date ? new Date(dto.date) : undefined,
          participantCount: dto.participantCount,
          notes: dto.notes,
        },
      });

      await tx.sessionConsultant.createMany({
        data: consultantsIds.map((consultantId) => ({
          trainingSessionId: trainingSession.id,
          consultantId,
        })),
      });

      return tx.trainingSession.findUnique({
        where: { id: trainingSession.id },
        include: {
          company: { select: { id: true, name: true } },
          course: { select: { id: true, name: true } },
          responsibleConsultant: { select: { id: true, name: true } },
          consultants: { include: { consultant: { select: { id: true, name: true } } } },
        }        
      })
    });
  }

 async deleteSession(id: string) {
  await this.findTrainingSessionById(id);
  return this.prisma.$transaction(async (tx) => {
    const participants = await tx.trainingParticipant.findMany({
      where: { trainingSessionId: id },
      include: { assessment: true },
    });

    const assessmentIds = participants
      .filter((p) => p.assessment)
      .map((p) => p.assessment!.id);

    if (assessmentIds.length > 0) {
      await tx.assessmentItem.deleteMany({ where: { assessmentId: { in: assessmentIds } } });
      await tx.practicalAssessment.deleteMany({ where: { id: { in: assessmentIds } } });
    }

    const participantIds = participants.map((p) => p.id);
    await tx.certificate.deleteMany({ where: { trainingParticipantId: { in: participantIds } } });
    await tx.trainingParticipant.deleteMany({ where: { trainingSessionId: id } });
    await tx.sessionConsultant.deleteMany({ where: { trainingSessionId: id } });

    return tx.trainingSession.delete({ where: { id } });
  });
}

  async updateSession (id: string, dto: UpdateTrainingSessionDto) {
    const session = await this.findTrainingSessionById(id);

    if(session.status === 'CONCLUIDO') {
      throw new ForbiddenException('Não é possível editar um treinamento concluído');
    }

    return this.prisma.$transaction(async (tx) => {
      if(dto.additionalConsultantsIds !== undefined) {
        await tx.sessionConsultant.deleteMany({ where: { trainingSessionId: id} });

        const allConsultantIds = [
          dto.responsibleConsultantId ?? session.responsibleConsultantId,
          ...dto.additionalConsultantsIds,
        ].filter((cid, index, self) => self.indexOf (cid) === index);

        await tx.sessionConsultant.createMany({
          data: allConsultantIds.map((consultantId) => ({
            trainingSessionId: id,
            consultantId,
          })),
        });
      }

      return tx.trainingSession.update({
      where: { id },
      data: {
        companyId: dto.companyId,
        courseId: dto.courseId,
        responsibleConsultantId: dto.responsibleConsultantId,
        city: dto.city,
        state: dto.state,
        date: dto.date ? new Date(dto.date) : undefined,
        participantCount: dto.participantCount,
        notes: dto.notes,
      },
      include: {
        company: { select: { id: true, name: true } },
        course: { select: { id: true, name: true } },
        responsibleConsultant: { select: { id: true, name: true } },
        consultants: { include: { consultant: { select: { id: true, name: true } } } },
      },
    });
    })
  }
}

