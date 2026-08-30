import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { EmailService } from '../email/email.service';
import { CreateConsultantDto } from './dto/create-consultant.dto';
import { UpdateConsultantDto } from './dto/update-consultant.dto';
import * as bcrypt from 'bcrypt';

// Sem caracteres ambíguos (0/O, 1/l/I) para facilitar a digitação manual pelo consultor
const PASSWORD_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';

function generateRandomPassword(length = 12): string {
  const bytes = randomBytes(length);
  let password = '';
  for (let i = 0; i < length; i++) {
    password += PASSWORD_CHARS[bytes[i] % PASSWORD_CHARS.length];
  }
  return password;
}

@Injectable()
export class ConsultantsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly email: EmailService,
  ) {}

  async createConsultant(dto: CreateConsultantDto) {
    const existingConsultant = await this.prisma.consultant.findUnique({
      where: { email: dto.email },
    });

    if (existingConsultant) {
      throw new ConflictException('Já existe um consultor com este e-mail.');
    }

    const generatedPassword = generateRandomPassword();
    const passwordHash = await bcrypt.hash(generatedPassword, 12);

    const consultant = await this.prisma.$transaction(async (tx) => {
      const consultant = await tx.consultant.create({
        data: {
          name: dto.name,
          email: dto.email,
          phone: dto.phone
        },
      });

      await tx.user.create({
        data: {
          email: dto.email,
          passwordHash,
          role: 'CONSULTANT',
          consultantId: consultant.id,
        },
      });
       return consultant;
    });

    // Envia e-mail de boas-vindas com a senha gerada. Se o envio falhar, o consultor
    // já foi criado no banco — não derruba a criação por causa disso, apenas loga.
    await this.email
      .sendConsultantCredentials(dto.email, dto.name, generatedPassword, 'created')
      .catch((err) => console.error('Falha ao enviar e-mail de boas-vindas ao consultor:', err));

    return consultant;
  }

  async resetConsultantPassword(id: string) {
    const consultant = await this.findConsultantById(id);

    const generatedPassword = generateRandomPassword();
    const passwordHash = await bcrypt.hash(generatedPassword, 12);

    await this.prisma.user.update({
      where: { email: consultant.email },
      data: { passwordHash },
    });

    await this.email.sendConsultantCredentials(consultant.email, consultant.name, generatedPassword, 'reset');

    return { success: true };
  }

  async findAllConsultants(activeOnly?: boolean) {
    return this.prisma.consultant.findMany({
      where: activeOnly ? { active: true } : undefined,
      orderBy: { name: 'asc' },
    });
  }

  async findConsultantById(id: string) {
    const consultant = await this.prisma.consultant.findUnique({ where: { id } });
    if (!consultant) throw new NotFoundException('Consultor não encontrado');
    return consultant;
  }

  async deleteConsultant(id: string) {
    await this.findConsultantById(id);

    // Exclusão de fato: o consultor é removido do sistema. Registros
    // históricos (treinamentos, avaliações, demandas) não são apagados —
    // apenas perdem a referência ao consultor (fica em branco / NULL), já
    // que essas colunas são opcionais no schema. O vínculo de consultor
    // secundário na sessão (SessionConsultant) usa chave composta e não tem
    // como ficar "em branco", então a linha do vínculo é removida.
    await this.prisma.$transaction(async (tx) => {
      await tx.sessionConsultant.deleteMany({ where: { consultantId: id } });

      await tx.trainingSession.updateMany({
        where: { responsibleConsultantId: id },
        data: { responsibleConsultantId: null },
      });

      await tx.practicalAssessment.updateMany({
        where: { consultantId: id },
        data: { consultantId: null },
      });

      await tx.demandPipeline.updateMany({
        where: { consultantId: id },
        data: { consultantId: null },
      });

      await tx.trainingParticipant.updateMany({
        where: { assignedConsultantId: id },
        data: { assignedConsultantId: null },
      });

      // Jobs de ações em lote registram quem os disparou (`requestedById`,
      // FK obrigatória para User) — se este consultor já baixou um ZIP em
      // lote (bulk-download libera CONSULTANT), apagar o usuário sem antes
      // limpar esses jobs quebra com violação de FK (mesmo problema
      // corrigido em TrainingSessionsService.deleteSession, ver
      // [[simtc-participant-training-delete]]). Diferente das outras FKs
      // acima, aqui não dá pra deixar em branco — `requestedById` é
      // obrigatório, então a linha do job é removida (mesmo raciocínio já
      // usado para `SessionConsultant`).
      const consultantUsers = await tx.user.findMany({ where: { consultantId: id }, select: { id: true } });
      await tx.bulkOperationJob.deleteMany({
        where: { requestedById: { in: consultantUsers.map((u) => u.id) } },
      });

      await tx.user.deleteMany({ where: { consultantId: id } });
      await tx.consultant.delete({ where: { id } });
    });

    return { mode: 'deleted' as const };
  }

  async updateConsultant(id: string, dto: UpdateConsultantDto) {
    await this.findConsultantById(id);
    return this.prisma.consultant.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.phone !== undefined && { phone: dto.phone }),
        ...(dto.credentialDetran !== undefined && { credentialDetran: dto.credentialDetran }),
        ...(dto.active !== undefined && { active: dto.active }),
      },
    });
  }

  async uploadSignature(id: string, buffer: Buffer, contentType: string) {
    const consultant = await this.findConsultantById(id);

    // Remove arquivo anterior se existir (suporta path antigo no formato URL completa)
    if (consultant.signatureUrl) {
      const oldPath = consultant.signatureUrl.startsWith('http')
        ? consultant.signatureUrl.replace(/.*\/signatures\//, '')
        : consultant.signatureUrl;
      await this.storage.delete('signatures', oldPath).catch(() => null);
    }

    const ext = contentType === 'image/png' ? 'png' : contentType === 'image/svg+xml' ? 'svg' : 'jpg';
    const storagePath = `${id}/${Date.now()}.${ext}`;

    // Faz upload mas ignora a publicUrl — bucket é privado
    await this.storage.upload('signatures', storagePath, buffer, contentType);

    // Salva apenas o path no banco (não a URL pública)
    await this.prisma.consultant.update({
      where: { id },
      data: { signatureUrl: storagePath },
    });

    // Retorna uma signed URL temporária (1h) para exibição imediata
    const signedUrl = await this.storage.getSignedUrl('signatures', storagePath, 3600);
    return { signedUrl };
  }

  async getSignatureSignedUrl(id: string) {
    const consultant = await this.findConsultantById(id);
    if (!consultant.signatureUrl) return null;

    // Suporta path antigo no formato URL completa (migração)
    const storagePath = consultant.signatureUrl.startsWith('http')
      ? consultant.signatureUrl.replace(/.*\/signatures\//, '')
      : consultant.signatureUrl;

    const signedUrl = await this.storage.getSignedUrl('signatures', storagePath, 3600);
    return { signedUrl };
  }
}
