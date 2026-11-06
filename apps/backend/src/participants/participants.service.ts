import { Injectable, ConflictException, BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';
import { StorageService } from '../storage/storage.service';
import { randomUUID } from 'crypto';
import { RegisterParticipantPublicDto, SignatureAction, SignaturePreviewResponse, SignatureRemoveResponse } from '@simtc/shared-types';
import { AddParticipantDto, ParticipationType } from './dto/add-participant.dto';
import { SignatureLookupDto } from './dto/signature-lookup.dto';
import { UpdateParticipantTypeDto } from './dto/update-participant-type.dto';
import { deleteOrphanedParticipants } from './participant-cleanup.util';
import { assertValidSignaturePng } from './png-signature.util';
import { SIGNATURE_BUCKET } from './signature.constants';
import { withPublicParticipant } from './participant-view.util';

const SIGNATURE_ACTIONS: SignatureAction[] = ['keep', 'replace', 'none'];
/** Validade da signed URL da prévia: basta para o `<img>` carregar, não serve para compartilhar. */
const SIGNATURE_PREVIEW_TTL_SECONDS = 120;

@Injectable()
export class ParticipantsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly email: EmailService,
    private readonly storage: StorageService,
  ) {}

  async findBySession(trainingSessionId: string) {
    const records = await this.prisma.trainingParticipant.findMany({
      where: { trainingSessionId },
      include: { participant: true, assessment: true },
      orderBy: { registeredAt: 'asc' },
    });
    return records.map(withPublicParticipant);
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
   *
   * A recusa de "CPF já inscrito" vem ANTES da atualização: uma inscrição
   * recusada não muda o cadastro. Cadastro novo não tem inscrição nenhuma.
   */
  private async findOrUpdateParticipantForSession(
    trainingSessionId: string,
    dto: {
      cpf: string;
      name: string;
      email?: string;
      cnhCategory?: string;
      cnhExpiration?: string;
    },
  ) {
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

    const enrolled = await this.prisma.trainingParticipant.findUnique({
      where: {
        trainingSessionId_participantId: {
          trainingSessionId,
          participantId: existing.id,
        },
      },
    });
    if (enrolled) {
      throw new ConflictException('CPF já inscrito neste treinamento');
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

  /**
   * Rota pública — auto-cadastro via QR Code, com assinatura opcional.
   *
   * Ordem: validações → sessão → dedupe por CPF → conferência de e-mail (só
   * quando já há assinatura) → upload → transação (cadastro, vínculo e caminho
   * da assinatura) → apaga a assinatura antiga após o commit. Falha no upload
   * não cancela a inscrição (`signatureSaved: false`); falha na transação
   * apaga o arquivo recém-enviado e propaga o erro.
   */
  async registerPublic(
    qrCodeToken: string,
    dto: RegisterParticipantPublicDto,
    signature?: Express.Multer.File,
  ) {
    // 0. Validação manual: o DTO é uma interface e o ValidationPipe não valida o corpo
    const signatureAction: SignatureAction = dto.signatureAction ?? 'none';
    if (!SIGNATURE_ACTIONS.includes(signatureAction)) {
      throw new BadRequestException('Ação de assinatura inválida');
    }
    if (
      dto.participationType !== undefined &&
      !(Object.values(ParticipationType) as string[]).includes(dto.participationType)
    ) {
      throw new BadRequestException('Tipo de participação inválido');
    }
    if (signatureAction === 'replace') {
      if (!signature) throw new BadRequestException('Envie a assinatura em PNG para substituir a atual');
      assertValidSignaturePng(signature.buffer);
    }

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

    // 2. De-duplicação por CPF; recusa quem já está inscrito nesta sessão
    // (mesma regra de findOrUpdateParticipantForSession, que segue usada pelo admin)
    const existing = await this.prisma.participant.findUnique({ where: { cpf: dto.cpf } });
    if (existing) {
      const enrolled = await this.prisma.trainingParticipant.findUnique({
        where: {
          trainingSessionId_participantId: { trainingSessionId: session.id, participantId: existing.id },
        },
      });
      if (enrolled) throw new ConflictException('CPF já inscrito neste treinamento');
    }
    // Cadastro novo recebe o id já aqui, porque o caminho da assinatura depende dele
    const participantId = existing?.id ?? randomUUID();
    const previousSignaturePath = existing?.signaturePath ?? null;

    // 3. Assinatura: conferência de e-mail e upload (antes da transação)
    let uploadedPath: string | null = null;
    let signatureIgnored = false;
    if (signatureAction === 'replace' && signature) {
      if (previousSignaturePath && !this.emailMatches(existing?.email ?? null, dto.email)) {
        // Já há assinatura e o e-mail não confere: quem troca precisa ser o titular
        signatureIgnored = true;
      } else {
        const path = `participants/${participantId}/${Date.now()}.png`;
        try {
          await this.storage.upload(SIGNATURE_BUCKET, path, signature.buffer, 'image/png');
          uploadedPath = path;
        } catch (err) {
          console.error('Falha ao enviar assinatura do participante:', err);
        }
      }
    }

    // 4. Transação: cadastro + vínculo + caminho da assinatura
    const txResult = await this.prisma
      .$transaction(async (tx) => {
        const participant = existing
          ? await tx.participant.update({
              where: { id: existing.id },
              data: {
                name: dto.name,
                email: dto.email ? dto.email : undefined,
                cnhCategory: dto.cnhCategory ? dto.cnhCategory : undefined,
                cnhExpiration: dto.cnhExpiration ? new Date(dto.cnhExpiration) : undefined,
              },
            })
          : await tx.participant.create({
              data: {
                id: participantId,
                name: dto.name,
                cpf: dto.cpf,
                email: dto.email,
                cnhCategory: dto.cnhCategory,
                cnhExpiration: dto.cnhExpiration ? new Date(dto.cnhExpiration) : undefined,
              },
            });

        const trainingParticipant = await tx.trainingParticipant.create({
          data: {
            trainingSessionId: session.id,
            participantId,
            participationType: dto.participationType,
          },
        });

        let replaced = false;
        if (uploadedPath) {
          // Condicional ao caminho lido antes: se outra gravação trocou a assinatura
          // no meio do caminho, nada é gravado e o arquivo recém-enviado é descartado
          const { count } = await tx.participant.updateMany({
            where: { id: participantId, signaturePath: previousSignaturePath },
            data: { signaturePath: uploadedPath, signatureUpdatedAt: new Date() },
          });
          replaced = count > 0;
        }

        return { participant, trainingParticipant, replaced };
      })
      .catch(async (err: unknown) => {
        if (uploadedPath) await this.removeSignatureFile(uploadedPath);
        throw err;
      });

    const { participant, trainingParticipant, replaced } = txResult;

    // 5. Depois do commit: apaga a assinatura antiga, ou descarta a nova se não foi gravada
    if (uploadedPath) {
      if (replaced) {
        if (previousSignaturePath) await this.removeSignatureFile(previousSignaturePath);
      } else {
        await this.removeSignatureFile(uploadedPath);
        signatureIgnored = true;
      }
    }

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

    return {
      ...trainingParticipant,
      signatureSaved: replaced,
      ...(signatureIgnored ? { signatureIgnored: true } : {}),
    };
  }

  /** Compara e-mails ignorando caixa e espaços; falso se algum dos lados estiver vazio. */
  private emailMatches(stored: string | null, given?: string): boolean {
    const a = stored?.trim().toLowerCase() ?? '';
    const b = given?.trim().toLowerCase() ?? '';
    return a !== '' && b !== '' && a === b;
  }

  /** Apaga um arquivo de assinatura. Falha só é registrada: o arquivo fica órfão, mas a ação não trava. */
  private async removeSignatureFile(path: string): Promise<void> {
    try {
      await this.storage.delete(SIGNATURE_BUCKET, path);
    } catch (err) {
      console.error('Falha ao apagar arquivo de assinatura:', err);
    }
  }

  /**
   * Prévia da assinatura na inscrição pública. A assinatura só aparece quando
   * CPF e e-mail conferem com o cadastro (ver brainstorm §4). Não devolve nome
   * nem CNH. Falha ao gerar a signed URL vira `none`, sem travar o formulário.
   */
  async signaturePreview(qrToken: string, dto: SignatureLookupDto): Promise<SignaturePreviewResponse> {
    const access = await this.checkSignatureAccess(qrToken, dto);
    if (access.status !== 'found') return access;

    try {
      const previewUrl = await this.storage.getSignedUrl(SIGNATURE_BUCKET, access.signaturePath, SIGNATURE_PREVIEW_TTL_SECONDS);
      // Toda assinatura gravada tem data (ver registerPublic); o fallback só cobre dado antigo
      const updatedAt = (access.signatureUpdatedAt ?? new Date(0)).toISOString();
      return { status: 'found', previewUrl, updatedAt };
    } catch (err) {
      console.error('Falha ao gerar prévia da assinatura:', err);
      return { status: 'none' };
    }
  }

  /**
   * Remoção da assinatura pelo próprio aluno, com a mesma conferência de CPF + e-mail
   * da prévia. Sem assinatura → `removed: false`; e-mail não confere → 403. Primeiro
   * zera o banco (condicionado ao caminho lido, para não apagar assinatura trocada
   * no meio); depois apaga o arquivo. Falha no storage só é registrada.
   */
  async removeOwnSignature(qrToken: string, dto: SignatureLookupDto): Promise<SignatureRemoveResponse> {
    const access = await this.checkSignatureAccess(qrToken, dto);
    if (access.status === 'locked') throw new ForbiddenException('E-mail não confere com o cadastro');
    if (access.status !== 'found') return { removed: false };

    const { count } = await this.prisma.participant.updateMany({
      where: { id: access.participantId, signaturePath: access.signaturePath },
      data: { signaturePath: null, signatureUpdatedAt: null },
    });
    if (count === 0) return { removed: false };

    await this.removeSignatureFile(access.signaturePath);
    return { removed: true };
  }

  /**
   * Remoção da assinatura pelo admin, pela inscrição (`TrainingParticipant.id`), sem
   * conferência de CPF/e-mail. Mesma ordem do `removeOwnSignature`: zera o banco
   * (condicionado ao caminho lido) e só depois apaga o arquivo, best-effort.
   */
  async removeSignature(trainingParticipantId: string): Promise<SignatureRemoveResponse> {
    const record = await this.prisma.trainingParticipant.findUnique({
      where: { id: trainingParticipantId },
      select: { id: true, participant: { select: { id: true, signaturePath: true } } },
    });
    if (!record) throw new NotFoundException('Participante não encontrado');

    const { id: participantId, signaturePath } = record.participant;
    if (!signaturePath) return { removed: false };

    const { count } = await this.prisma.participant.updateMany({
      where: { id: participantId, signaturePath },
      data: { signaturePath: null, signatureUpdatedAt: null },
    });
    if (count === 0) return { removed: false };

    await this.storage.delete(SIGNATURE_BUCKET, signaturePath).catch(() => null);
    return { removed: true };
  }

  /**
   * Conferência de acesso à assinatura pelo formulário público: sessão do token
   * (404 se não existe, 400 se encerrada) → CPF normalizado só com dígitos →
   * participante → `none` (sem cadastro ou sem assinatura), `locked` (e-mail não
   * confere) ou `found` (com o caminho da assinatura).
   */
  private async checkSignatureAccess(
    qrToken: string,
    dto: { cpf: string; email: string },
  ): Promise<
    | { status: 'none' }
    | { status: 'locked' }
    | { status: 'found'; participantId: string; signaturePath: string; signatureUpdatedAt: Date | null }
  > {
    const session = await this.prisma.trainingSession.findUnique({
      where: { qrCodeToken: qrToken },
      select: { status: true },
    });
    if (!session) throw new NotFoundException('Sessão de treinamento não encontrada');
    if (session.status === 'CANCELADO' || session.status === 'CONCLUIDO') {
      throw new BadRequestException('Inscrições encerradas para este treinamento');
    }

    const cpf = dto.cpf.replace(/\D/g, '');
    const participant = await this.prisma.participant.findUnique({ where: { cpf } });
    if (!participant || !participant.signaturePath) return { status: 'none' };
    if (!this.emailMatches(participant.email, dto.email)) return { status: 'locked' };

    return {
      status: 'found',
      participantId: participant.id,
      signaturePath: participant.signaturePath,
      signatureUpdatedAt: participant.signatureUpdatedAt,
    };
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
    // com o que veio nesta nova inscrição; recusa quem já está inscrito
    // (ver findOrUpdateParticipantForSession)
    const participant = await this.findOrUpdateParticipantForSession(trainingSessionId, dto);

    const created = await this.prisma.trainingParticipant.create({
      data: {
        trainingSessionId,
        participantId: participant.id,
        participationType: dto.participationType,
      },
      include: { participant: true },
    });
    return withPublicParticipant(created);
  }

  /**
   * Consulta de CPF da tela "Adicionar participante" do app mobile: diz se o
   * CPF já tem cadastro (`Participant`, compartilhado entre treinamentos) —
   * devolvendo nome e e-mail para a tela preencher — e se já está inscrito
   * nesta sessão. Só lê: quem grava é o `addParticipant`.
   */
  async lookupByCpf(trainingSessionId: string, cpf: string) {
    const session = await this.prisma.trainingSession.findUnique({
      where: { id: trainingSessionId },
      select: { id: true },
    });
    if (!session) throw new NotFoundException('Sessão de treinamento não encontrada');

    const participant = await this.prisma.participant.findUnique({ where: { cpf } });
    if (!participant) {
      return { registered: false, name: null, email: null, enrolled: false };
    }

    const enrollment = await this.prisma.trainingParticipant.findUnique({
      where: {
        trainingSessionId_participantId: {
          trainingSessionId,
          participantId: participant.id,
        },
      },
      select: { id: true },
    });

    return {
      registered: true,
      name: participant.name,
      email: participant.email ?? null,
      enrolled: enrollment !== null,
    };
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
    }).then(withPublicParticipant);
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

    let signaturePaths: string[] = [];
    const deleted = await this.prisma.$transaction(async (tx) => {
      if (record.assessment) {
        await tx.assessmentItem.deleteMany({ where: { assessmentId: record.assessment.id } });
        await tx.practicalAssessment.delete({ where: { id: record.assessment.id } });
      }
      if (record.certificate) {
        await tx.certificate.delete({ where: { id: record.certificate.id } });
      }
      const result = await tx.trainingParticipant.delete({ where: { id: participantId } });
      signaturePaths = await deleteOrphanedParticipants(tx, [record.participantId]);
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
    for (const path of signaturePaths) {
      await this.storage.delete(SIGNATURE_BUCKET, path).catch(() => null);
    }

    return deleted;
  }
}
