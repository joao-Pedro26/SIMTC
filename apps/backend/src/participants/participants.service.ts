import { Injectable, ConflictException, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';
import { StorageService } from '../storage/storage.service';
import { RegisterParticipantPublicDto } from '@simtc/shared-types';
import { AddParticipantDto, ParticipationType } from './dto/add-participant.dto';
import { UpdateParticipantTypeDto } from './dto/update-participant-type.dto';
import { deleteOrphanedParticipants } from './participant-cleanup.util';

@Injectable()
export class ParticipantsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly email: EmailService,
    private readonly storage: StorageService,
  ) {}

  findBySession(trainingSessionId: string) {
    return this.prisma.trainingParticipant.findMany({
      where: { trainingSessionId },
      include: { participant: true, assessment: true },
      orderBy: { registeredAt: 'asc' },
    });
  }

  async findByToken(qrToken: string): Promise<{
    companyName: string;
    companyLogoUrl: string | null;
    courseName: string;
    status: string;
  }> {
    const session = await this.prisma.trainingSession.findUnique({
      where: { qrCodeToken: qrToken },
      include: {
        company: { select: { name: true, logoUrl: true } },
        course: { select: { name: true } },
      },
    });

    if (!session) {
      throw new NotFoundException('Sessão de treinamento não encontrada');
    }

    return {
      companyName: session.company.name,
      companyLogoUrl: session.company.logoUrl ?? null,
      courseName: session.course.name,
      status: session.status,
    };
  }

  /**
   * Encontra o `Participant` pelo CPF (cadastro compartilhado entre
   * treinamentos, dedup por CPF) e, se já existir, ATUALIZA os campos com os
   * valores desta nova inscrição em vez de manter os antigos — decisão do
   * cliente (30/08/2026): se a pessoa se inscreve de novo com um e-mail
   * diferente do que já estava salvo, por exemplo, o cadastro deve passar a
   * refletir o e-mail novo, não o antigo.
   *
   * Os campos opcionais (`email`, `cnhCategory`, `cnhExpiration`) só são
   * sobrescritos quando vêm preenchidos na nova inscrição: o formulário de
   * "adicionar participante" do admin permite deixá-los em branco (ver
   * `session-management-drawer.tsx` no frontend), e um valor `undefined` no
   * `data` do Prisma faz o campo ser IGNORADO no update (mantém o que já
   * estava no banco) em vez de apagar o valor existente. Já `name` é sempre
   * obrigatório nos dois formulários (público e admin), por isso sempre
   * sobrescreve.
   */
  private async findOrUpdateParticipantByCpf(dto: {
    cpf: string;
    name: string;
    email?: string;
    cnhCategory?: string;
    cnhExpiration?: string;
  }) {
    const existing = await this.prisma.participant.findUnique({ where: { cpf: dto.cpf } });

    if (!existing) {
      return this.prisma.participant.create({
        data: {
          name: dto.name,
          cpf: dto.cpf,
          email: dto.email,
          cnhCategory: dto.cnhCategory,
          cnhExpiration: dto.cnhExpiration ? new Date(dto.cnhExpiration) : undefined,
        },
      });
    }

    return this.prisma.participant.update({
      where: { id: existing.id },
      data: {
        name: dto.name,
        email: dto.email ? dto.email : undefined,
        cnhCategory: dto.cnhCategory ? dto.cnhCategory : undefined,
        cnhExpiration: dto.cnhExpiration ? new Date(dto.cnhExpiration) : undefined,
      },
    });
  }

  /** Rota pública — auto-cadastro via QR Code */
  async registerPublic(qrCodeToken: string, dto: RegisterParticipantPublicDto) {
    // 1. Encontra a sessão pelo token
    const session = await this.prisma.trainingSession.findUniqueOrThrow({
      where: { qrCodeToken },
      include: {
        company: { select: { name: true, logoUrl: true } },
        course: { select: { name: true } },
      },
    });

    if (session.status === 'CANCELADO' || session.status === 'CONCLUIDO') {
      throw new BadRequestException('Inscrições encerradas para este treinamento');
    }

    // 2. De-duplicação por CPF: reutiliza o participante, atualizando os
    // dados com o que veio nesta nova inscrição (ver findOrUpdateParticipantByCpf)
    const participant = await this.findOrUpdateParticipantByCpf(dto);

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

    const trainingParticipant = await this.prisma.trainingParticipant.create({
      data: {
        trainingSessionId: session.id,
        participantId: participant.id,
        participationType: dto.participationType,
      },
    });

    if (participant.email) {
      await this.email
        .sendRegistrationConfirmation(
          participant.email,
          participant.name,
          session.course.name,
          session.company.name,
          session.company.logoUrl,
        )
        .catch((err) => console.error('Falha ao enviar e-mail de confirmação de inscrição:', err));
    }

    return trainingParticipant;
  }

  async addParticipant(trainingSessionId: string, dto: AddParticipantDto) {
    const session = await this.prisma.trainingSession.findUnique({
      where: { id: trainingSessionId },
    });

    if (!session) throw new NotFoundException('Sessão de treinamento não encontrada');
    if(session.status === 'CANCELADO' || session.status === 'CONCLUIDO') {
      throw new BadRequestException('Inscrições encerradas para este treinamento');
    }

    // De-duplicação por CPF: reutiliza o participante, atualizando os dados
    // com o que veio nesta nova inscrição (ver findOrUpdateParticipantByCpf)
    const participant = await this.findOrUpdateParticipantByCpf(dto);

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

  /**
   * Remove um participante de um treinamento (linha `TrainingParticipant`).
   *
   * `PracticalAssessment`, `Certificate` e `AssessmentItem` têm FK `RESTRICT`
   * para `TrainingParticipant` (ver migration `20260723222838_init`), então
   * apagar a linha diretamente falhava com erro de FK sempre que o
   * participante já tinha avaliação/certificado gerado (ou seja, qualquer
   * status além de PENDENTE/EM_AVALIACAO sem relatório). Por isso apagamos
   * os registros filhos primeiro, na mesma transação — mesma ordem já usada
   * em `TrainingSessionsService.deleteSession()`.
   *
   * Além das linhas no banco, `PracticalAssessment.reportPdfUrl` e
   * `Certificate.pdfUrl` apontam para arquivos reais nos buckets `reports` e
   * `certificates` do Supabase Storage — sem removê-los, ficam órfãos lá para
   * sempre (o banco não sabe nada sobre esses arquivos). A exclusão do
   * storage é feita depois da transação, best-effort (`.catch(() => null)`,
   * mesmo padrão usado em certificates.service.ts): se falhar, não impede a
   * remoção do participante, só deixa o arquivo órfão em vez de travar a ação
   * do usuário.
   *
   * Além disso, ao remover a inscrição, o cadastro de `Participant` (CPF) só
   * é apagado se essa era a última — decisão do cliente 30/08/2026: ver
   * `deleteOrphanedParticipants` em `participant-cleanup.util.ts`.
   */
  async removeParticipant(participantId: string) {
    const record = await this.prisma.trainingParticipant.findUnique({
      where: { id: participantId },
      include: { assessment: true, certificate: true },
    });
    if (!record) throw new NotFoundException('Participante não encontrado');
    if (record.status === 'EM_AVALIACAO') {
      throw new BadRequestException('Não é possível remover participante em avaliação');
    }

    const deleted = await this.prisma.$transaction(async (tx) => {
      if (record.assessment) {
        await tx.assessmentItem.deleteMany({ where: { assessmentId: record.assessment.id } });
        await tx.practicalAssessment.delete({ where: { id: record.assessment.id } });
      }
      if (record.certificate) {
        await tx.certificate.delete({ where: { id: record.certificate.id } });
      }
      const result = await tx.trainingParticipant.delete({ where: { id: participantId } });
      await deleteOrphanedParticipants(tx, [record.participantId]);
      return result;
    });

    if (record.assessment?.reportPdfUrl) {
      const path = record.assessment.reportPdfUrl.split('/reports/')[1];
      if (path) await this.storage.delete('reports', path).catch(() => null);
    }
    if (record.certificate?.pdfUrl) {
      const path = record.certificate.pdfUrl.split('/certificates/')[1];
      if (path) await this.storage.delete('certificates', path).catch(() => null);
    }

    return deleted;
  }
}
