import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';
import { JwtPayload } from '@simtc/shared-types';
import { CreateTrainingSessionDto } from './dto/create-training-session.dto';
import { UpdateTrainingSessionDto } from './dto/update-training-session.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

@Injectable()
export class TrainingSessionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly email: EmailService,
  ) {}

  /** ADMIN vê todas as sessões; CONSULTANT vê apenas as suas */
  async findAll(user: JwtPayload, pagination: PaginationDto) {
    const where: Record<string, unknown> =
      user.role === 'CONSULTANT'
        ? { consultants: { some: { consultantId: user.consultantId } } }
        : {};

    if (pagination.companyId) {
      where.companyId = pagination.companyId;
    }

    const page = pagination.page ?? 1;
    const limit = pagination.limit ?? 20;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.prisma.trainingSession.findMany({
        where,
        include: {
          company: { select: { id: true, name: true } },
          course: { select: { id: true, name: true } },
          responsibleConsultant: { select: { id: true, name: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.trainingSession.count({ where }),
    ]);

    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async findTrainingSessionById(id: string, user?: JwtPayload) {
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
            assessment: true,
            certificate: true,
            assignedConsultant: { select: { id: true, name: true } },
          },
        },
      },
    });

    // CONSULTANT só pode ver o detalhe de uma sessão à qual está atribuído.
    // (chamadas internas — cancelSession/updateSession/deleteSession — não passam
    // `user`, então continuam sem essa checagem, pois já são restritas a ADMIN.)
    if (user?.role === 'CONSULTANT') {
      const isAssigned = session.consultants.some(
        (c) => c.consultantId === user.consultantId,
      );
      if (!isAssigned) {
        throw new ForbiddenException('Você não tem acesso a este treinamento');
      }
    }

    return session;
  }

  /** Só ADMIN ou o consultor responsável pela sessão podem iniciar/concluir (regras de negócio). */
  private async assertCanManageLifecycle(id: string, user?: JwtPayload) {
    if (!user || user.role === 'ADMIN') return;
    const session = await this.prisma.trainingSession.findUniqueOrThrow({
      where: { id },
      select: { responsibleConsultantId: true },
    });
    if (session.responsibleConsultantId !== user.consultantId) {
      throw new ForbiddenException(
        'Somente o consultor responsável por este treinamento pode iniciá-lo ou concluí-lo',
      );
    }
  }

  async start(id: string, user?: JwtPayload) {
    await this.assertCanManageLifecycle(id, user);
    return this.prisma.trainingSession.update({
      where: { id },
      data: { status: 'EM_ANDAMENTO' },
    });
  }

  async complete(id: string, user?: JwtPayload) {
    await this.assertCanManageLifecycle(id, user);
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

    const session = await this.prisma.$transaction(async (tx) => {
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
          company: { select: { id: true, name: true, contacts: { select: { name: true, email: true } } } },
          course: { select: { id: true, name: true } },
          responsibleConsultant: { select: { id: true, name: true } },
          consultants: { include: { consultant: { select: { id: true, name: true } } } },
        },
      });
    });

    if (session) {
      const company = session.company as { id: string; name: string; contacts: { name: string; email: string }[] };
      const promises = company.contacts.map((contact) =>
        this.email
          .sendTrainingScheduled(
            contact.email,
            contact.name,
            session.course!.name,
            company.name,
            session.city,
            session.state,
            session.date,
          )
          .catch((err) => console.error(`Falha ao notificar contato ${contact.email} sobre treinamento agendado:`, err)),
      );
      await Promise.allSettled(promises);
    }

    return session;
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

  async cancelSession(id: string) {
    const session = await this.findTrainingSessionById(id);
    if (session.status === 'CONCLUIDO') {
      throw new ForbiddenException('Não é possível cancelar um treinamento já concluído');
    }
    if (session.status === 'CANCELADO') {
      throw new ForbiddenException('Treinamento já está cancelado');
    }
    return this.prisma.trainingSession.update({
      where: { id },
      data: { status: 'CANCELADO' },
    });
  }

  async updateSession (id: string, dto: UpdateTrainingSessionDto) {
    const session = await this.findTrainingSessionById(id);

    if (session.status === 'CONCLUIDO' || session.status === 'CANCELADO') {
      throw new ForbiddenException('Não é possível editar um treinamento concluído ou cancelado');
    }

    return this.prisma.$transaction(async (tx) => {
      if(dto.additionalConsultantsIds !== undefined) {
        await tx.sessionConsultant.deleteMany({ where: { trainingSessionId: id} });

        const allConsultantIds = [
          dto.responsibleConsultantId ?? session.responsibleConsultantId,
          ...dto.additionalConsultantsIds,
        ].filter((cid, index, self): cid is string => Boolean(cid) && self.indexOf(cid) === index);

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

