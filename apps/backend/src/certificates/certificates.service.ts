import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PdfGeneratorService } from './pdf-generator.service';
import { StorageService } from '../storage/storage.service';
import { EmailService } from '../email/email.service';
import {
  JwtPayload,
  calculateCategoryScore,
  calculateOverallScore,
  getApprovalLabel,
} from '@simtc/shared-types';

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

  /**
   * Wrapper público de `generateOne`, usado pelos jobs em lote (envio de
   * e-mail / download ZIP) para gerar sob demanda o certificado de UM
   * participante específico, quando ele ainda não tem um gerado. Busca os
   * mesmos dados que `generateBatch` busca para a sessão inteira, mas só para
   * este participante.
   */
  async generateCertificateForParticipant(trainingParticipantId: string) {
    const tp = await this.prisma.trainingParticipant.findUniqueOrThrow({
      where: { id: trainingParticipantId },
      include: {
        participant: true,
        assessment: { include: { items: { include: { infractionNote: true } } } },
      },
    });
    const session = await this.prisma.trainingSession.findUniqueOrThrow({
      where: { id: tp.trainingSessionId },
      include: { company: true, course: true, responsibleConsultant: true },
    });
    return this.generateOne(tp, session);
  }

  /**
   * Wrapper público de `generateOneAssessmentReport`, mesma ideia do método
   * acima mas para o relatório de avaliação técnica. Lança erro claro se o
   * participante ainda não tem avaliação prática lançada (não tem como gerar
   * relatório de algo que não existe).
   */
  async generateReportForParticipant(trainingParticipantId: string) {
    const tp = await this.prisma.trainingParticipant.findUniqueOrThrow({
      where: { id: trainingParticipantId },
      include: {
        participant: true,
        assessment: {
          include: {
            items: {
              include: { infractionNote: { include: { infraction: { include: { category: true } } } } },
            },
          },
        },
      },
    });
    if (!tp.assessment) {
      throw new Error('Participante não possui avaliação técnica lançada');
    }
    const session = await this.prisma.trainingSession.findUniqueOrThrow({
      where: { id: tp.trainingSessionId },
      include: {
        company: true,
        course: true,
        responsibleConsultant: true,
        consultants: { include: { consultant: true } },
      },
    });
    return this.generateOneAssessmentReport(tp, session);
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

  /** Formata "Julho/2024" para o rodapé do relatório de avaliação */
  private formatFooterMonth(date: Date): string {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    return `${months[date.getMonth()]}/${date.getFullYear()}`;
  }

  /** Cor da barra de progresso por tópico — mesmos limiares usados no preview do app web */
  private categoryBarColor(percent: number): string {
    if (percent > 75) return '#48bb78';
    if (percent > 50) return '#ecc94b';
    return '#fc8181';
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
    if (trainingParticipant.status === 'APROVADO') return 'Aprovado';
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

    // Busca TODAS as categorias (mesmo as não avaliadas nesta sessão, que contam 100%) —
    // necessário para o bloco "Resultado da Avaliação" (sempre mostra os 4 tópicos) e
    // para manter a ordem canônica (CV, RR, CS, TP) nas seções da página 1.
    const allCategories = await this.prisma.assessmentCategory.findMany({
      select: {
        id: true,
        code: true,
        name: true,
        description: true,
        order: true,
        _count: { select: { infractions: true } },
      },
      orderBy: { order: 'asc' },
    });

    const { topicSections, categoryScores, overallScorePercent, resultLabel, resultBadgeClass } =
      this.buildScoreData(assessment.items, allCategories);

    const conclusionParagraphs = await this.getConclusionParagraphs(overallScorePercent);

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
      ? this.formatFooterMonth(new Date(assessment.date))
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
      topicSections,
      categoryScores,
      overallScorePercent,
      resultLabel,
      resultBadgeClass,
      conclusionParagraphs,
      consultantName: consultant?.name ?? '',
      consultantCity: session.city,
      credentialDetran: consultant?.credentialDetran ?? null,
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

  /**
   * A partir dos itens marcados na avaliação e da lista completa de categorias, monta:
   *  - `topicSections`: só os tópicos com ao menos uma infração marcada (página 1), na
   *    ordem canônica das categorias, com o texto fixo do tópico (`category.description`,
   *    quando cadastrado — CV e TP ainda não têm) e as infrações ordenadas por `infraction.order`.
   *  - `categoryScores` / `overallScorePercent` / `resultLabel` / `resultBadgeClass`: o bloco
   *    "Resultado da Avaliação" da página 2, sempre com as 4 categorias — mesma fórmula usada
   *    em PracticalAssessmentsService.applyScore() e no preview do app web (score bruto para
   *    a média geral e para o limiar de cor da barra; arredondado só para exibição).
   */
  private buildScoreData(items: any[], allCategories: any[]) {
    const byCategoryDeductions = new Map<string, number[]>();
    const byCategoryInfractions = new Map<string, Array<{ order: number; title: string; body: string | null }>>();

    for (const item of items) {
      const note = item.infractionNote;
      const infraction = note?.infraction;
      const category = infraction?.category;
      if (!category) continue;

      if (!byCategoryDeductions.has(category.id)) byCategoryDeductions.set(category.id, []);
      byCategoryDeductions.get(category.id)!.push(note.deduction);

      if (!byCategoryInfractions.has(category.id)) byCategoryInfractions.set(category.id, []);
      byCategoryInfractions.get(category.id)!.push({
        order: infraction.order,
        title: infraction.description,
        body: note.comment ?? null,
      });
    }

    const rawScores = allCategories.map((cat) =>
      calculateCategoryScore(byCategoryDeductions.get(cat.id) ?? [], cat._count.infractions),
    );

    const categoryScores = allCategories.map((cat, i) => ({
      code: cat.code,
      name: cat.name,
      percent: Math.round(rawScores[i]),
      barColor: this.categoryBarColor(rawScores[i]),
    }));

    const overallScore = calculateOverallScore(rawScores);
    const overallScorePercent = Math.round(overallScore);
    const resultLabel = getApprovalLabel(overallScore);
    const resultBadgeClass = overallScore >= 70 ? '' : 'reprovado';

    const topicSections = allCategories
      .filter((cat) => byCategoryInfractions.has(cat.id))
      .map((cat) => ({
        code: cat.code,
        name: cat.name,
        description: cat.description ?? null,
        infractions: byCategoryInfractions
          .get(cat.id)!
          .sort((a, b) => a.order - b.order)
          .map(({ title, body }) => ({ title, body })),
      }));

    return { topicSections, categoryScores, overallScorePercent, resultLabel, resultBadgeClass };
  }

  /**
   * Texto de fechamento (carta) da página 2, que varia conforme a faixa de percentual geral
   * atingida (`overallScorePercent`) — não por tópico. Busca em `ReportConclusionText` a faixa
   * cujo [minPercent, maxPercent] contém o percentual e devolve o texto já separado em
   * parágrafos (o campo `text` guarda os parágrafos concatenados com '\n\n').
   *
   * Fallback: as 3 faixas cadastradas via seed cobrem 0–100 sem lacunas, então isso só deve
   * acontecer se o seed ainda não rodou no ambiente. Nesse caso, devolve um parágrafo de aviso
   * claramente identificável (em vez de silenciosamente usar o texto de outra faixa), para que
   * o problema seja percebido na revisão do PDF em vez de passar despercebido.
   */
  private async getConclusionParagraphs(overallScorePercent: number): Promise<string[]> {
    const match = await this.prisma.reportConclusionText.findFirst({
      where: {
        minPercent: { lte: overallScorePercent },
        maxPercent: { gte: overallScorePercent },
      },
    });

    if (!match) {
      return [
        'Texto de conclusão não configurado para esta faixa de pontuação (ReportConclusionText). ' +
          'Verifique se o seed foi executado neste ambiente.',
      ];
    }

    return match.text.split('\n\n');
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
            assessment: { select: { reportPdfUrl: true } },
            training: { include: { company: { include: { contacts: true } }, course: true } },
          },
        },
      },
    });

    const pdfPath = cert.pdfUrl!.split('/certificates/')[1];
    const pdfBuffer = await this.storage.download('certificates', pdfPath);
    const tp = cert.trainingParticipant;
    const companyLogoUrl = tp.training.company.logoUrl;
    const courseName = tp.training.course.name;

    // Se o participante já tem relatório de avaliação técnica gerado, anexa
    // junto no mesmo e-mail do certificado.
    let reportPdfBuffer: Buffer | null = null;
    if (tp.assessment?.reportPdfUrl) {
      const reportPath = tp.assessment.reportPdfUrl.split('/reports/')[1];
      if (reportPath) {
        reportPdfBuffer = await this.storage.download('reports', reportPath).catch(() => null);
      }
    }

    if ((to === 'participant' || to === 'both') && tp.participant.email) {
      await this.email.sendCertificateAndReport(
        tp.participant.email,
        tp.participant.name,
        courseName,
        pdfBuffer,
        companyLogoUrl,
        reportPdfBuffer,
      );
      await this.prisma.certificate.update({
        where: { id: certificateId },
        data: { sentToParticipant: true },
      });
    }

    if (to === 'company' || to === 'both') {
      const primary = tp.training.company.contacts.find((c: any) => c.isPrimary);
      if (primary) {
        await this.email.sendCertificateAndReport(
          primary.email,
          tp.participant.name,
          courseName,
          pdfBuffer,
          companyLogoUrl,
          reportPdfBuffer,
        );
        await this.prisma.certificate.update({
          where: { id: certificateId },
          data: { sentToCompany: true },
        });
      }
    }
  }
}
