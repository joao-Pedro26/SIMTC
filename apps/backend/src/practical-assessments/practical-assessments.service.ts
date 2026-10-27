import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { SyncPracticalAssessmentDto } from '@simtc/shared-types';
import { AssignParticipantsDto } from './dto/assign-participants.dto';
import { calculateCategoryScore, calculateOverallScore, getApprovalStatus } from '@simtc/shared-types';
import { statusAfterRelease } from '../participants/participant-release.util';
import { SYNC_REFUSAL_NOT_ASSIGNED, SyncRefusedException } from './sync-refused.exception';

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
      // Só a recusa que o app mobile trata à parte leva código.
      code:
        r.status === 'rejected' && r.reason instanceof SyncRefusedException
          ? r.reason.code
          : undefined,
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

    // Só envia avaliação quem está com o participante (Fase 6B do app
    // mobile). Quem foi removido do treinamento, ou desatribuído pelo ADMIN,
    // com a avaliação em andamento não grava mais nada: o participante voltou
    // para a fila, e outro consultor pode já ter assumido — ou avaliado.
    const participant = await this.prisma.trainingParticipant.findUnique({
      where: { id: dto.trainingParticipantId },
      select: { status: true, assignedConsultantId: true },
    });
    if (!participant) {
      throw new ConflictException('Participante não encontrado');
    }
    // O status da sessão não conta (Fase 8D-1): o consultor avalia sem rede e
    // envia depois, e uma sessão concluída pelo ADMIN no fim do dia, antes do
    // envio, faria a avaliação de campo se perder. Basta o participante
    // continuar com quem envia.
    const isWithSender =
      participant.status === 'EM_AVALIACAO' && participant.assignedConsultantId === consultantId;
    if (!isWithSender) {
      // Reenvio: o primeiro envio desta mesma avaliação já foi aceito (por
      // isso o participante não está mais "em avaliação"), mas a resposta se
      // perdeu e o app tentou de novo. Não há o que regravar.
      const alreadySaved =
        existing != null &&
        existing.consultantId === consultantId &&
        existing.startTime.getTime() === new Date(dto.startTime).getTime();
      if (alreadySaved) return existing;

      throw new SyncRefusedException(
        SYNC_REFUSAL_NOT_ASSIGNED,
        'Este participante não está mais em avaliação com você. A avaliação não foi registrada.',
      );
    }

    // Tudo numa transação só (Fase 8D-1): uma falha no meio de uma
    // reavaliação deixava a avaliação aceita sem itens.
    return this.prisma.$transaction(async (tx) => {
      if (existing) {
        // Reavaliação: apaga os itens anteriores e atualiza o registro
        await tx.assessmentItem.deleteMany({
          where: { assessmentId: existing.id },
        });

        const updated = await tx.practicalAssessment.update({
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

        await this.applyScore(tx, updated.id, updated.items, dto.trainingParticipantId);
        return updated;
      }

      // Primeira avaliação
      const assessment = await tx.practicalAssessment.create({
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

      await this.applyScore(tx, assessment.id, assessment.items, dto.trainingParticipantId);
      return assessment;
    });
  }

  /** Calcula score e atualiza o assessment + status do participante, na
   * transação do envio. */
  private async applyScore(
    tx: Prisma.TransactionClient,
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

    // Busca TODAS as categorias (mesmo as não avaliadas nesta sessão, que contam 100%)
    const allCategories = await tx.assessmentCategory.findMany({
      select: { id: true, _count: { select: { infractions: true } } },
    });

    const categoryScores = allCategories.map((cat) =>
      calculateCategoryScore(byCategory.get(cat.id) ?? [], cat._count.infractions),
    );
    const overallScore = calculateOverallScore(categoryScores);
    const status = getApprovalStatus(overallScore);

    await tx.practicalAssessment.update({
      where: { id: assessmentId },
      data: { score: overallScore },
    });
    await tx.trainingParticipant.update({
      where: { id: trainingParticipantId },
      data: { status, assignedConsultantId: null },
    });
  }

  /** Um id que não existe é 404, e não o 500 do `findUniqueOrThrow` (Fase 8D-1). */
  async findOne(id: string) {
    const assessment = await this.prisma.practicalAssessment.findUnique({
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
    if (!assessment) throw new NotFoundException('Avaliação não encontrada');
    return assessment;
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
    // Ids repetidos no pedido contam uma vez só (Fase 8D-1).
    const ids = [...new Set(dto.participantIds)];
    const records = await this.prisma.trainingParticipant.findMany({
      where: { id: { in: ids } },
      include: { training: { select: { status: true } } },
    });

    if (records.length !== ids.length) {
      throw new ConflictException('Um ou mais participantes não foram encontrados');
    }

    // As regras que as telas do app e do web já aplicam (Fase 8D-1): só com
    // o treinamento em andamento, e só quem tem a parte prática.
    if (records.some((r) => r.training.status !== 'EM_ANDAMENTO')) {
      throw new ConflictException('Só dá para atribuir participantes com o treinamento em andamento');
    }
    if (records.some((r) => r.participationType === 'SOMENTE_TEORICA')) {
      throw new ConflictException('Participantes somente da parte teórica não têm avaliação prática');
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

    // A gravação confere as mesmas condições de novo: entre a leitura e aqui,
    // outro aparelho pode ter atribuído alguém. Se não pegar todos, a
    // transação desfaz o que pegou (Fase 8D-1).
    await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.trainingParticipant.updateMany({
        where: {
          id: { in: ids },
          status: { not: 'APROVADO' },
          OR: [{ status: { not: 'EM_AVALIACAO' } }, { assignedConsultantId: consultantId }],
        },
        data: { assignedConsultantId: consultantId, status: 'EM_AVALIACAO' },
      });
      if (count !== ids.length) {
        throw new ConflictException(
          'Um ou mais participantes já estão em avaliação com outro consultor',
        );
      }
    });

    return { assigned: ids.length };
  }

  /**
   * Libera participantes em avaliação (o "Desatribuir" do app mobile). O
   * consultor só libera os que estão com ele; o ADMIN libera os de qualquer
   * consultor (Fase 6B do app) e não precisa ter perfil de consultor. O
   * participante volta ao status de antes da atribuição: `PENDENTE` se nunca
   * foi avaliado, ou o status da nota da avaliação anterior numa reavaliação.
   */
  async unassignParticipants(
    dto: AssignParticipantsDto,
    consultantIdFromJwt?: string,
    userId?: string,
    role?: string,
  ) {
    const isAdmin = role === 'ADMIN';
    const consultantId = isAdmin
      ? undefined
      : await this.resolveConsultantId(consultantIdFromJwt, userId);
    // Ids repetidos no pedido contam uma vez só (Fase 8D-1).
    const ids = [...new Set(dto.participantIds)];
    const records = await this.prisma.trainingParticipant.findMany({
      where: { id: { in: ids } },
      include: { assessment: { select: { score: true } } },
    });

    if (records.length !== ids.length) {
      throw new ConflictException('Um ou mais participantes não foram encontrados');
    }

    if (isAdmin) {
      if (records.some((r) => r.status !== 'EM_AVALIACAO')) {
        throw new ConflictException('Um ou mais participantes não estão em avaliação');
      }
    } else {
      const notMine = records.filter(
        (r) => r.status !== 'EM_AVALIACAO' || r.assignedConsultantId !== consultantId,
      );
      if (notMine.length > 0) {
        throw new ConflictException('Um ou mais participantes não estão atribuídos a você');
      }
    }

    // Cada liberação confere de novo que o participante continua como foi
    // lido: no meio do caminho, outro pedido pode tê-lo liberado, avaliado ou
    // removido. Aí a transação desfaz tudo, com 409 em vez de 500 (Fase 8D-1).
    await this.prisma.$transaction(async (tx) => {
      for (const r of records) {
        const { count } = await tx.trainingParticipant.updateMany({
          where: { id: r.id, status: 'EM_AVALIACAO', assignedConsultantId: r.assignedConsultantId },
          data: {
            assignedConsultantId: null,
            status: statusAfterRelease(r.assessment?.score),
          },
        });
        if (count !== 1) {
          throw new ConflictException(
            'Um ou mais participantes mudaram de situação. Atualize a lista e tente de novo.',
          );
        }
      }
    });

    return { unassigned: records.length };
  }
}
