import { Injectable, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SyncPracticalAssessmentDto } from '@simtc/shared-types';
import { calculateCategoryScore, calculateOverallScore } from '@simtc/shared-types';

@Injectable()
export class PracticalAssessmentsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Recebe sync em lote do app mobile */
  async syncFromMobile(dtos: SyncPracticalAssessmentDto[]) {
    const results = await Promise.allSettled(dtos.map((dto) => this.syncOne(dto)));
    return results.map((r, i) => ({
      trainingParticipantId: dtos[i].trainingParticipantId,
      status: r.status,
      error: r.status === 'rejected' ? (r.reason as Error).message : undefined,
    }));
  }

  private async syncOne(dto: SyncPracticalAssessmentDto) {
    // Verifica se já existe (evita duplicata)
    const existing = await this.prisma.practicalAssessment.findUnique({
      where: { trainingParticipantId: dto.trainingParticipantId },
    });
    if (existing) {
      throw new ConflictException(
        `Participante ${dto.trainingParticipantId} já possui avaliação registrada`,
      );
    }

    const assessment = await this.prisma.practicalAssessment.create({
      data: {
        trainingParticipantId: dto.trainingParticipantId,
        consultantId: dto.consultantId,
        date: new Date(dto.date),
        startTime: new Date(dto.startTime),
        endTime: dto.endTime ? new Date(dto.endTime) : undefined,
        synced: true,
        items: {
          create: dto.items.map((item) => ({ infractionNoteId: item.infractionNoteId })),
        },
      },
      include: { items: { include: { infractionNote: true } } },
    });

    // Calcula score e atualiza status do participante
    const deductions = assessment.items.map((i) => i.infractionNote.deduction);
    const score = calculateCategoryScore(deductions); // simplificado — ver scoring.ts para lógica completa
    const status = score >= 70 ? 'APROVADO' : 'NECESSITA_REAVALIACAO';

    await this.prisma.trainingParticipant.update({
      where: { id: dto.trainingParticipantId },
      data: { status },
    });

    return assessment;
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
}
