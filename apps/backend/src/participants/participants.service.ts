import { Injectable, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterParticipantPublicDto } from '@simtc/shared-types';

@Injectable()
export class ParticipantsService {
  constructor(private readonly prisma: PrismaService) {}

  findBySession(trainingSessionId: string) {
    return this.prisma.trainingParticipant.findMany({
      where: { trainingSessionId },
      include: { participant: true, assessment: true },
      orderBy: { registeredAt: 'asc' },
    });
  }

  /** Rota pública — auto-cadastro via QR Code */
  async registerPublic(qrCodeToken: string, dto: RegisterParticipantPublicDto) {
    // 1. Encontra a sessão pelo token
    const session = await this.prisma.trainingSession.findUniqueOrThrow({
      where: { qrCodeToken },
    });

    // 2. De-duplicação: se CPF já existe, reutiliza o participante
    let participant = await this.prisma.participant.findUnique({
      where: { cpf: dto.cpf },
    });

    if (!participant) {
      participant = await this.prisma.participant.create({
        data: {
          name: dto.name,
          cpf: dto.cpf,
          email: dto.email,
          cnhCategory: dto.cnhCategory,
          cnhExpiration: dto.cnhExpiration ? new Date(dto.cnhExpiration) : undefined,
        },
      });
    }

    // 3. Vincula participante à sessão (verifica se já está inscrito)
    const existing = await this.prisma.trainingParticipant.findUnique({
      where: {
        trainingSessionId_participantId: {
          trainingSessionId: session.id,
          participantId: participant.id,
        },
      },
    });

    if (existing) {
      throw new ConflictException('CPF já inscrito neste treinamento');
    }

    return this.prisma.trainingParticipant.create({
      data: { trainingSessionId: session.id, participantId: participant.id },
    });
  }
}
