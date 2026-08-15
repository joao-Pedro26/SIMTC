import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PdfGeneratorService } from './pdf-generator.service';
import { StorageService } from '../storage/storage.service';
import { EmailService } from '../email/email.service';
import { JwtPayload } from '@simtc/shared-types';

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

    // Bucket 'signatures' é privado — resolve o path para uma signed URL
    // temporária (5 min é suficiente para o Puppeteer renderizar o PDF)
    const consultant = session.responsibleConsultant;
    let signatureUrl: string | null = null;
    if (consultant?.signatureUrl) {
      const sigPath = consultant.signatureUrl.startsWith('http')
        ? consultant.signatureUrl.replace(/.*\/signatures\//, '')
        : consultant.signatureUrl;
      signatureUrl = await this.storage.getSignedUrl('signatures', sigPath, 300).catch(() => null);
    }

    // Garante que contentItems é um array (campo Json? pode vir como null)
    const contentItems = Array.isArray(session.course.contentItems)
      ? session.course.contentItems
      : null;

    const pdf = await this.pdfGenerator.renderCertificate({
      participant: trainingParticipant.participant,
      session: { ...session, date: sessionDate },
      company: session.company,
      course: { ...session.course, contentItems },
      consultant: { ...consultant, signatureUrl },
      result,
      certificateId: cert.id,
      cargaHoraria,
    });

    // Deleta o arquivo anterior para evitar arquivos órfãos no bucket
    if (cert.pdfUrl) {
      const oldPath = cert.pdfUrl.split('/certificates/')[1];
      if (oldPath) await this.storage.delete('certificates', oldPath).catch(() => null);
    }

    // Timestamp no path para bustar o cache do CDN do Supabase
    const fileName = `${session.id}/${trainingParticipant.participantId}-${Date.now()}.pdf`;
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

  async generateAssessmentReports(trainingSessionId: string) {
    const session = await this.prisma.trainingSession.findUniqueOrThrow({
      where: { id: trainingSessionId },
      include: {
        company: true,
        course: true,
        responsibleConsultant: true,
        consultants: { include: { consultant: true } },
        participants: {
          include: {
            participant: true,
            assessment: {
              include: {
                items: {
                  include: {
                    infractionNote: {
                      include: { infraction: { include: { category: true } } },
                    },
                  },
                },
              },
            },
          },
        },
      },
    });

    const withAssessment = session.participants.filter((tp) => tp.assessment !== null);

    const results = await Promise.allSettled(
      withAssessment.map((tp) => this.generateOneAssessmentReport(tp, session)),
    );

    return results.map((r, i) => ({
      participantId: withAssessment[i].participantId,
      status: r.status,
      error: r.status === 'rejected' ? (r.reason as Error).message : undefined,
    }));
  }

  private async generateOneAssessmentReport(trainingParticipant: any, session: any) {
    const assessment = trainingParticipant.assessment;
    const participant = trainingParticipant.participant;
    const consultant = session.responsibleConsultant;

    let consultantSignatureUrl: string | null = null;
    if (consultant?.signatureUrl) {
      const sigPath = consultant.signatureUrl.startsWith('http')
        ? consultant.signatureUrl.replace(/.*\/signatures\//, '')
        : consultant.signatureUrl;
      consultantSignatureUrl = await this.storage.getSignedUrl('signatures', sigPath, 300).catch(() => null);
    }

    const sections = this.buildAssessmentSections(assessment.items);

    const assessmentDate = assessment.date
      ? new Date(assessment.date).toLocaleDateString('pt-BR')
      : null;
    const startTime = assessment.startTime
      ? new Date(assessment.startTime).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) + 'h'
      : null;
    const endTime = assessment.endTime
      ? new Date(assessment.endTime).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) + 'h'
      : null;
    const footerMonth = assessment.date
      ? new Date(assessment.date).toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })
      : null;
    const signatureDate = assessment.date
      ? this.formatDate(new Date(assessment.date))
      : null;
    const cnhExpiration = participant.cnhExpiration
      ? new Date(participant.cnhExpiration).toLocaleDateString('pt-BR')
      : null;

    const pdf = await this.pdfGenerator.renderAssessmentReport({
      participantName: participant.name,
      firstName: participant.name.split(' ')[0],
      cnhCategory: participant.cnhCategory ?? '—',
      cnhExpiration: cnhExpiration ?? '—',
      location: `${session.city}/${session.state}`,
      assessmentDate,
      startTime,
      endTime,
      footerMonth,
      signatureDate,
      sections,
      consultantName: consultant?.name ?? '',
      consultantCity: session.city,
      credentialDetran: consultant?.credentialDetran ?? null,
      consultantSignatureUrl,
    });

    // Deleta arquivo anterior do bucket para evitar órfãos
    if (assessment.reportPdfUrl) {
      const oldPath = assessment.reportPdfUrl.split('/reports/')[1];
      if (oldPath) await this.storage.delete('reports', oldPath).catch(() => null);
    }

    const fileName = `${session.id}/${trainingParticipant.participantId}-relatorio-${Date.now()}.pdf`;
    const url = await this.storage.upload('reports', fileName, pdf, 'application/pdf');

    return this.prisma.practicalAssessment.update({
      where: { id: assessment.id },
      data: { reportPdfUrl: url, reportGeneratedAt: new Date() },
    });
  }

  private buildAssessmentSections(items: any[]): any[] {
    const categoryMap = new Map<string, { code: string; name: string; items: any[] }>();

    for (const item of items) {
      const note = item.infractionNote;
      const infraction = note?.infraction;
      const category = infraction?.category;
      if (!category) continue;

      if (!categoryMap.has(category.id)) {
        categoryMap.set(category.id, { code: category.code, name: category.name, items: [] });
      }
      categoryMap.get(category.id)!.items.push({
        noteType: note.noteType,
        description: infraction.description,
        comment: note.comment ?? null,
      });
    }

    return Array.from(categoryMap.values());
  }

  async findAssessmentReportsByTrainingSession(trainingSessionId: string) {
    const participants = await this.prisma.trainingParticipant.findMany({
      where: { trainingSessionId },
      include: {
        participant: { select: { id: true, name: true } },
        assessment: {
          select: { id: true, reportPdfUrl: true, reportGeneratedAt: true },
        },
      },
      orderBy: { participant: { name: 'asc' } },
    });

    return participants.map((tp) => ({
      participantId: tp.participantId,
      participantName: tp.participant.name,
      status: tp.status,
      assessmentReport: tp.assessment?.reportPdfUrl
        ? {
            id: tp.assessment.id,
            pdfUrl: tp.assessment.reportPdfUrl,
            generatedAt: tp.assessment.reportGeneratedAt,
          }
        : null,
    }));
  }

  async getAssessmentReportDownloadUrl(assessmentId: string, user: JwtPayload): Promise<{ url: string }> {
    const assessment = await this.prisma.practicalAssessment.findUnique({
      where: { id: assessmentId },
      include: {
        trainingParticipant: {
          include: {
            training: {
              include: {
                consultants: true,
              },
            },
          },
        },
      },
    });

    if (!assessment || !assessment.reportPdfUrl) {
      throw new NotFoundException('Relatório não encontrado ou ainda não gerado');
    }

    const session = assessment.trainingParticipant.training;

    if (user.role === 'CLIENT') {
      if (session.companyId !== user.companyId) {
        throw new ForbiddenException('Acesso negado');
      }
    } else if (user.role === 'CONSULTANT') {
      const isAssigned =
        session.responsibleConsultantId === user.consultantId ||
        session.consultants.some((c: any) => c.consultantId === user.consultantId);
      if (!isAssigned) {
        throw new ForbiddenException('Você não tem acesso a este relatório');
      }
    }

    const pdfPath = assessment.reportPdfUrl.split('/reports/')[1];
    const url = await this.storage.getSignedUrl('reports', pdfPath, 300);
    return { url };
  }

  async findByTrainingSession(trainingSessionId: string, user: JwtPayload) {
    if (user.role === 'CLIENT') {
      const session = await this.prisma.trainingSession.findUnique({
        where: { id: trainingSessionId },
        select: { companyId: true },
      });
      if (!session) throw new NotFoundException('Sessão não encontrada');
      if (session.companyId !== user.companyId) throw new ForbiddenException('Acesso negado');
    }

    const participants = await this.prisma.trainingParticipant.findMany({
      where: { trainingSessionId },
      include: {
        participant: { select: { id: true, name: true } },
        certificate: true,
      },
      orderBy: { participant: { name: 'asc' } },
    });

    return participants.map((tp) => ({
      participantId: tp.participantId,
      participantName: tp.participant.name,
      status: tp.status,
      certificate: tp.certificate
        ? {
            id: tp.certificate.id,
            pdfUrl: tp.certificate.pdfUrl,
            generatedAt: tp.certificate.generatedAt,
            sentToParticipant: tp.certificate.sentToParticipant,
            sentToCompany: tp.certificate.sentToCompany,
          }
        : null,
    }));
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

  async getDownloadUrl(id: string, user: JwtPayload): Promise<{ url: string }> {
    const cert = await this.prisma.certificate.findUnique({
      where: { id },
      include: {
        trainingParticipant: {
          include: { training: { select: { companyId: true } } },
        },
      },
    });
    if (!cert || !cert.pdfUrl) throw new NotFoundException('Certificado não encontrado ou ainda não gerado');

    if (user.role === 'CLIENT') {
      if (cert.trainingParticipant.training.companyId !== user.companyId) {
        throw new ForbiddenException('Acesso negado');
      }
    }

    const pdfPath = cert.pdfUrl.split('/certificates/')[1];
    const url = await this.storage.getSignedUrl('certificates', pdfPath, 300);
    return { url };
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
