import { Injectable, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SyncPracticalAssessmentDto } from '@simtc/shared-types';
import { AssignParticipantsDto } from './dto/assign-participants.dto';
import { calculateCategoryScore, calculateOverallScore, getApprovalStatus } from '@simtc/shared-types';

@Injectable()
export class PracticalAssessmentsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Resolve o ID do Consultant a partir do consultantId do JWT ou,
   * como fallback, do userId (para admins com perfil de consultor vinculado).
   */
  async resolveConsultantId(consultantIdFromJwt?: string, userId?: string): Promise<string> {
    if (consultantIdFromJwt) return consultantIdFromJwt;
    if (!userId) throw new ConflictException('Consultor não identificado no token');

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { consultantId: true },
    });
    if (!user?.consultantId) {
      throw new ConflictException(
        'Este usuário não possui um perfil de consultor associado. Associe um perfil de consultor para poder avaliar participantes.',
      );
    }
    return user.consultantId;
  }

  /** Recebe sync em lote do app mobile / web */
  async syncFromMobile(dtos: SyncPracticalAssessmentDto[], consultantIdFromJwt?: string, userId?: string) {
    const resolvedConsultantId = await this.resolveConsultantId(consultantIdFromJwt, userId);
    const results = await Promise.allSettled(
      dtos.map((dto) => this.syncOne(dto, resolvedConsultantId)),
    );
    return results.map((r, i) => ({
      trainingParticipantId: dtos[i].trainingParticipantId,
      status: r.status,
      error: r.status === 'rejected' ? (r.reason as Error).message : undefined,
    }));
  }

  private async syncOne(dto: SyncPracticalAssessmentDto, consultantIdFromJwt?: string) {
    // consultantId do JWT tem prioridade (web) — fallback pro campo do DTO (mobile)
    const consultantId = consultantIdFromJwt ?? dto.consultantId;
    if (!consultantId) {
      throw new ConflictException('Consultor não identificado para esta avaliação');
    }

    const existing = await this.prisma.practicalAssessment.findUnique({
      where: { trainingParticipantId: dto.trainingParticipantId },
    });

    if (existing) {
      // Reavaliação: apaga os itens anteriores e atualiza o registro
      await this.prisma.assessmentItem.deleteMany({
        where: { assessmentId: existing.id },
      });

      const updated = await this.prisma.practicalAssessment.update({
        where: { id: existing.id },
        data: {
          consultantId,
          date: new Date(dto.date),
          startTime: new Date(dto.startTime),
          endTime: dto.endTime ? new Date(dto.endTime) : null,
          synced: true,
          score: null, // resetar até calcular abaixo
          items: {
            create: dto.items.map((item) => ({ infractionNoteId: item.infractionNoteId })),
          },
        },
        include: {
          items: {
            include: {
              infractionNote: {
                include: { infraction: { include: { category: true } } },
              },
            },
          },
        },
      });

      await this.applyScore(updated.id, updated.items, dto.trainingParticipantId);
      return updated;
    } else {
      // Primeira avaliação
      const assessment = await this.prisma.practicalAssessment.create({
        data: {
          trainingParticipantId: dto.trainingParticipantId,
          consultantId,
          date: new Date(dto.date),
          startTime: new Date(dto.startTime),
          endTime: dto.endTime ? new Date(dto.endTime) : undefined,
          synced: true,
          items: {
            create: dto.items.map((item) => ({ infractionNoteId: item.infractionNoteId })),
          },
        },
        include: {
          items: {
            include: {
              infractionNote: {
                include: { infraction: { include: { category: true } } },
              },
            },
          },
        },
      });

      await this.applyScore(assessment.id, assessment.items, dto.trainingParticipantId);
      return assessment;
    }
  }

  /** Calcula score e atualiza o assessment + status do participante */
  private async applyScore(
    assessmentId: string,
    items: Array<{
      infractionNote: {
        deduction: number;
        infraction: { category: { id: string } };
      };
    }>,
    trainingParticipantId: string,
  ) {
    const byCategory = new Map<string, number[]>();
    for (const item of items) {
      const categoryId = item.infractionNote.infraction.category.id;
      if (!byCategory.has(categoryId)) byCategory.set(categoryId, []);
      byCategory.get(categoryId)!.push(item.infractionNote.deduction);
    }

    const categoryScores = Array.from(byCategory.values()).map((deductions) =>
      calculateCategoryScore(deductions),
    );
    const overallScore = calculateOverallScore(categoryScores);
    const status = getApprovalStatus(overallScore);

    await this.prisma.$transaction([
      this.prisma.practicalAssessment.update({
        where: { id: assessmentId },
        data: { score: overallScore },
      }),
      this.prisma.trainingParticipant.update({
        where: { id: trainingParticipantId },
        data: { status, assignedConsultantId: null },
      }),
    ]);
  }

  findOne(id: string) {
    return this.prisma.practicalAssessment.findUniqueOrThrow({
      where: { id },
      include: {
        items: {
          include: {
            infractionNote: {
              include: { infraction: { include: { category: true } } },
            },
          },
        },
      },
    });
  }

  /** Retorna avaliação existente do participante, ou null se não houver */
  findByParticipant(trainingParticipantId: string) {
    return this.prisma.practicalAssessment.findUnique({
      where: { trainingParticipantId },
      include: {
        items: {
          include: {
            infractionNote: {
              include: { infraction: { include: { category: true } } },
            },
          },
        },
      },
    });
  }

  async assignParticipants(dto: AssignParticipantsDto, consultantIdFromJwt?: string, userId?: string) {
    const consultantId = await this.resolveConsultantId(consultantIdFromJwt, userId);
    const records = await this.prisma.trainingParticipant.findMany({
      where: { id: { in: dto.participantIds } },
    });

    if (records.length !== dto.participantIds.length) {
      throw new ConflictException('Um ou mais participantes não foram encontrados');
    }

    // Participantes aprovados não podem ser reatribuídos
    const alreadyApproved = records.filter((r) => r.status === 'APROVADO');
    if (alreadyApproved.length > 0) {
      throw new ConflictException('Participantes aprovados não podem ser reavaliados');
    }

    // Participantes em avaliação com outro consultor não podem ser roubados
    const alreadyAssignedToOther = records.filter(
      (r) => r.status === 'EM_AVALIACAO' && r.assignedConsultantId !== consultantId,
    );
    if (alreadyAssignedToOther.length > 0) {
      throw new ConflictException(
        'Um ou mais participantes já estão em avaliação com outro consultor',
      );
    }

    await this.prisma.trainingParticipant.updateMany({
      where: { id: { in: dto.participantIds } },
      data: { assignedConsultantId: consultantId, status: 'EM_AVALIACAO' },
    });

    return { assigned: dto.participantIds.length };
  }
}
