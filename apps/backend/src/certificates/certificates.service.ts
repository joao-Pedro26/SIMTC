import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PdfGeneratorService } from './pdf-generator.service';
import { StorageService } from '../storage/storage.service';
import { EmailService } from '../email/email.service';

@Injectable()
export class CertificatesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pdfGenerator: PdfGeneratorService,
    private readonly storage: StorageService,
    private readonly email: EmailService,
  ) {}

  /**
   * Gera certificados PDF em lote para todos os participantes APROVADOS da sessão.
   * Fluxo: dados → template HTML → Puppeteer → Supabase Storage → Certificate record
   */
  async generateBatch(trainingSessionId: string) {
    const session = await this.prisma.trainingSession.findUniqueOrThrow({
      where: { id: trainingSessionId },
      include: {
        company: true,
        course: true,
        responsibleConsultant: true,
        participants: {
          where: {
            OR: [
              { status: 'APROVADO' },
              { participationType: 'SOMENTE_TEORICA' },
            ],
          },
          include: {
            participant: true,
            assessment: { include: { items: { include: { infractionNote: true } } } },
          },
        },
      },
    });

    const results = await Promise.allSettled(
      session.participants.map((tp) => this.generateOne(tp, session)),
    );

    return results.map((r, i) => ({
      participantId: session.participants[i].participantId,
      status: r.status,
      error: r.status === 'rejected' ? (r.reason as Error).message : undefined,
    }));
  }

  private async generateOne(trainingParticipant: any, session: any) {
    const cert = await this.prisma.certificate.upsert({
      where: { trainingParticipantId: trainingParticipant.id },
      create: { trainingParticipantId: trainingParticipant.id, pdfUrl: '' },
      update: { generatedAt: new Date() },
    });

    const result = this.resolveResult(trainingParticipant);
    const sessionDate = session.date ? this.formatDate(new Date(session.date)) : null;
    const cargaHoraria = this.formatCargaHoraria(
      session.course.theoryHours,
      session.course.practiceHours,
    );

    const pdf = await this.pdfGenerator.renderCertificate({
      participant: trainingParticipant.participant,
      session: { ...session, date: sessionDate },
      company: session.company,
      course: session.course,
      consultant: session.responsibleConsultant,
      result,
      certificateId: cert.id,
      cargaHoraria,
    });

    const fileName = `${session.id}/${trainingParticipant.participantId}.pdf`;
    const url = await this.storage.upload('certificates', fileName, pdf, 'application/pdf');

    return this.prisma.certificate.update({
      where: { id: cert.id },
      data: { pdfUrl: url },
    });
  }

  private formatDate(date: Date): string {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    return `${String(date.getDate()).padStart(2, '0')} de ${months[date.getMonth()]} de ${date.getFullYear()}`;
  }

  private formatCargaHoraria(theoryHours: number, practiceHours: number): string {
    const total = theoryHours + practiceHours;
    if (practiceHours > 0) {
      const practiceStr = Number.isInteger(practiceHours)
        ? `${practiceHours}h00`
        : `${practiceHours}h`;
      return `${total} horas (${theoryHours} horas teóricas e ${practiceStr} horas prática)`;
    }
    return `${total} horas teóricas`;
  }

  private resolveResult(trainingParticipant: any): string | null {
    if (trainingParticipant.participationType === 'SOMENTE_TEORICA') return null;
    if (trainingParticipant.status === 'APROVADO') {
      const score = trainingParticipant.assessment?.score;
      if (score != null && score >= 85) return 'Aprovado com Excelência';
      return 'Aprovado';
    }
    return null;
  }

  async findById(id: string) {
    const cert = await this.prisma.certificate.findUnique({
      where: { id },
      include: {
        trainingParticipant: {
          include: { participant: true, training: { include: { company: true, course: true } } },
        },
      },
    });
    if (!cert) throw new NotFoundException('Certificado não encontrado');
    return cert;
  }

  async sendByEmail(certificateId: string, to: 'participant' | 'company' | 'both') {
    const cert = await this.prisma.certificate.findUniqueOrThrow({
      where: { id: certificateId },
      include: {
        trainingParticipant: {
          include: {
            participant: true,
            training: { include: { company: { include: { contacts: true } } } },
          },
        },
      },
    });

    const pdfPath = cert.pdfUrl!.split('/certificates/')[1];
    const pdfBuffer = await this.storage.download('certificates', pdfPath);
    const tp = cert.trainingParticipant;

    if ((to === 'participant' || to === 'both') && tp.participant.email) {
      await this.email.sendCertificate(tp.participant.email, tp.participant.name, pdfBuffer);
      await this.prisma.certificate.update({
        where: { id: certificateId },
        data: { sentToParticipant: true },
      });
    }

    if (to === 'company' || to === 'both') {
      const primary = tp.training.company.contacts.find((c: any) => c.isPrimary);
      if (primary) {
        await this.email.sendCertificate(primary.email, tp.participant.name, pdfBuffer);
        await this.prisma.certificate.update({
          where: { id: certificateId },
          data: { sentToCompany: true },
        });
      }
    }
  }
}
