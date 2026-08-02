import { Injectable, ConflictException, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterParticipantPublicDto } from '@simtc/shared-types';
import { AddParticipantDto, ParticipationType } from './dto/add-participant.dto';
import { UpdateParticipantTypeDto } from './dto/update-participant-type.dto';

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

  async findByToken(qrToken: string): Promise<{ companyName: string; courseName: string; status: string }> {
    const session = await this.prisma.trainingSession.findUnique({
      where: { qrCodeToken: qrToken },
      include: {
        company: { select: { name: true } },
        course: { select: { name: true } },
      },
    });

    if (!session) {
      throw new NotFoundException('Sessão de treinamento não encontrada');
    }

    return {
      companyName: session.company.name,
      courseName: session.course.name,
      status: session.status,
    };
  }

  /** Rota pública — auto-cadastro via QR Code */
  async registerPublic(qrCodeToken: string, dto: RegisterParticipantPublicDto) {
    // 1. Encontra a sessão pelo token
    const session = await this.prisma.trainingSession.findUniqueOrThrow({
      where: { qrCodeToken },
    });

    if (session.status === 'CANCELADO' || session.status === 'CONCLUIDO') {
      throw new BadRequestException('Inscrições encerradas para este treinamento');
    }

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

  async addParticipant(trainingSessionId: string, dto: AddParticipantDto) {
    const session = await this.prisma.trainingSession.findUnique({
      where: { id: trainingSessionId },
    });

    if (!session) throw new NotFoundException('Sessão de treinamento não encontrada');
    if(session.status === 'CANCELADO' || session.status === 'CONCLUIDO') {
      throw new BadRequestException('Inscrições encerradas para este treinamento');
    }

    let participant = await this.prisma.participant.findUnique({
      where: { cpf: dto.cpf },
    });

    if(!participant) {
      participant = await this.prisma.participant.create({
        data: {
          name: dto.name,
          cpf: dto.cpf,
          email: dto.email,
          cnhCategory: dto.cnhCategory,
          cnhExpiration: dto.cnhExpiration ? new Date(dto.cnhExpiration) : undefined,
        }
      });
    }

    const existing = await this.prisma.trainingParticipant.findUnique({
      where: {
        trainingSessionId_participantId: {
          trainingSessionId,
          participantId: participant.id,
        },
      },  
    });

    if (existing) {
      throw new ConflictException('CPF já inscrito neste treinamento');
    }

    return this.prisma.trainingParticipant.create({
      data: {
        trainingSessionId,
        participantId: participant.id,
        participationType: dto.participationType,
      },
      include: { participant: true },
    });
  }

  updateParticipationType( participantId: string, dto: UpdateParticipantTypeDto) {
    const record = this.prisma.trainingParticipant.findUnique({
      where: { id: participantId },
    });
    if (!record) throw new NotFoundException('Participante não encontrado');

    return this.prisma.trainingParticipant.update({
      where: { id: participantId },
      data: { participationType: dto.participationType },
      include: { participant: true },
    });
  }

  async removeParticipant(participantId: string) {
    const record = await this.prisma.trainingParticipant.findUnique({
      where: { id: participantId },
    });
    if (!record) throw new NotFoundException('Participante não encontrado');
    if(record.status === 'EM_AVALIACAO') {
      throw new BadRequestException('Não é possível remover participante em avaliação');
    }

    return this.prisma.trainingParticipant.delete({
      where: { id: participantId },
    });
  }
}
