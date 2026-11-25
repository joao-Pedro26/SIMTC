import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
// `archiver` também usa `export =` (mesmo caso do `p-limit` em
// pdf-generator.service.ts) — sem `esModuleInterop` no tsconfig, o import
// default padrão compilaria para `.default`, que não existe em runtime.
import archiver = require('archiver');
import { PrismaService } from '../prisma/prisma.service';
import { ParticipantsService } from './participants.service';
import { CertificatesService } from '../certificates/certificates.service';
import { PDF_RENDER_CONCURRENCY } from '../certificates/pdf-generator.service';
import { StorageService } from '../storage/storage.service';
import { EmailService, EmailRateLimitError } from '../email/email.service';
import { JobsService, BulkItemResult } from '../jobs/jobs.service';
import { JwtPayload } from '@simtc/shared-types';

/**
 * Orquestra as 3 ações em lote da listagem de participantes (excluir, enviar
 * certificados/relatórios por e-mail, baixar ZIP). Cada `start*` cria o job e
 * dispara o processamento "solto" no event loop (`void this.process...()`),
 * respondendo imediatamente com `{ jobId }` — o cliente acompanha o progresso
 * via polling em GET /jobs/:jobId (ver JobsService).
 *
 * Ver brainstorm-acoes-lote-participantes.md para o racional completo.
 */
@Injectable()
export class BulkActionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jobs: JobsService,
    private readonly participants: ParticipantsService,
    private readonly certificates: CertificatesService,
    private readonly email: EmailService,
    private readonly storage: StorageService,
  ) {}

  // ─── EXCLUSÃO EM LOTE ───────────────────────────────────────────────────

  async startBulkDelete(trainingSessionId: string, participantIds: string[], user: JwtPayload) {
    const job = await this.jobs.createJob({
      type: 'DELETE_PARTICIPANTS',
      requestedById: user.sub,
      requestedByRole: user.role,
      trainingSessionId,
      totalItems: participantIds.length,
    });
    void this.processBulkDelete(job.id, participantIds);
    return { jobId: job.id };
  }

  private async processBulkDelete(jobId: string, participantIds: string[]) {
    await this.jobs.markRunning(jobId);

    // Grupos de 10 em paralelo — cada exclusão já é leve (1 transação Prisma +
    // 2 deletes best-effort no Storage), não precisa ser sequencial.
    const chunkSize = 10;
    for (let i = 0; i < participantIds.length; i += chunkSize) {
      const chunk = participantIds.slice(i, i + chunkSize);
      const results = await Promise.all(chunk.map((id) => this.deleteOne(id)));
      for (const r of results) {
        await this.jobs.recordItemResult(jobId, r);
      }
    }

    await this.jobs.completeJob(jobId);
  }

  private async deleteOne(trainingParticipantId: string): Promise<BulkItemResult> {
    const tp = await this.prisma.trainingParticipant.findUnique({
      where: { id: trainingParticipantId },
      include: { participant: true },
    });
    const name = tp?.participant?.name ?? trainingParticipantId;
    if (!tp) {
      return { participantId: trainingParticipantId, name, status: 'failed', reason: 'Participante não encontrado' };
    }
    try {
      await this.participants.removeParticipant(trainingParticipantId);
      return { participantId: trainingParticipantId, name, status: 'success' };
    } catch (err: any) {
      return { participantId: trainingParticipantId, name, status: 'failed', reason: err.message ?? 'Erro desconhecido' };
    }
  }

  // ─── ENVIO DE CERTIFICADOS/RELATÓRIOS EM LOTE ──────────────────────────

  async startBulkSendCertificates(trainingSessionId: string, participantIds: string[], user: JwtPayload) {
    const job = await this.jobs.createJob({
      type: 'SEND_CERTIFICATES',
      requestedById: user.sub,
      requestedByRole: user.role,
      trainingSessionId,
      totalItems: participantIds.length,
    });
    void this.processBulkSendCertificates(job.id, participantIds);
    return { jobId: job.id };
  }

  private async processBulkSendCertificates(jobId: string, participantIds: string[]) {
    await this.jobs.markRunning(jobId);

    // Sequencial, um por vez — é a única ação com rate limit externo real
    // (Resend). Delay de ~600ms entre envios mantém margem segura abaixo do
    // limite de 2 req/s que o Resend aplica por padrão.
    for (const participantId of participantIds) {
      const result = await this.sendCertificateForOne(participantId);
      await this.jobs.recordItemResult(jobId, result);
      await this.sleep(600);
    }

    await this.jobs.completeJob(jobId);
  }

  private async sendCertificateForOne(trainingParticipantId: string): Promise<BulkItemResult> {
    const tp = await this.prisma.trainingParticipant.findUnique({
      where: { id: trainingParticipantId },
      include: { participant: true, certificate: true, assessment: true },
    });
    if (!tp) {
      return { participantId: trainingParticipantId, name: trainingParticipantId, status: 'failed', reason: 'Participante não encontrado' };
    }
    const name = tp.participant.name;

    if (!tp.participant.email) {
      return { participantId: trainingParticipantId, name, status: 'skipped', reason: 'Participante sem e-mail cadastrado' };
    }

    // Gera o certificado na hora se ainda não existir
    if (!tp.certificate?.pdfUrl) {
      try {
        await this.certificates.generateCertificateForParticipant(trainingParticipantId);
      } catch (err: any) {
        return { participantId: trainingParticipantId, name, status: 'skipped', reason: `Não foi possível gerar o certificado: ${err.message}` };
      }
    }

    // Gera o relatório também, se o participante já tem avaliação lançada mas
    // o relatório ainda não foi gerado — best-effort, não bloqueia o envio do
    // certificado se essa geração falhar.
    if (tp.assessment && !tp.assessment.reportPdfUrl) {
      await this.certificates.generateReportForParticipant(trainingParticipantId).catch(() => null);
    }

    const freshCert = await this.prisma.certificate.findUnique({ where: { trainingParticipantId } });
    if (!freshCert?.pdfUrl) {
      return { participantId: trainingParticipantId, name, status: 'skipped', reason: 'Certificado indisponível' };
    }

    // Tenta enviar; em caso de rate limit do Resend, espera um pouco e tenta
    // mais 1 vez antes de desistir deste participante (nunca aborta o lote
    // inteiro por causa de 1 e-mail problemático).
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        await this.certificates.sendByEmail(freshCert.id, 'participant');
        return { participantId: trainingParticipantId, name, status: 'success' };
      } catch (err: any) {
        if (err instanceof EmailRateLimitError && attempt === 0) {
          await this.sleep(2000);
          continue;
        }
        return { participantId: trainingParticipantId, name, status: 'failed', reason: err.message ?? 'Falha ao enviar e-mail' };
      }
    }

    return { participantId: trainingParticipantId, name, status: 'failed', reason: 'Falha ao enviar e-mail' };
  }

  // ─── DOWNLOAD EM LOTE (ZIP) ─────────────────────────────────────────────

  async startBulkDownload(trainingSessionId: string, participantIds: string[], user: JwtPayload) {
    if (user.role === 'CLIENT') {
      const session = await this.prisma.trainingSession.findUnique({
        where: { id: trainingSessionId },
        select: { companyId: true },
      });
      if (!session) throw new NotFoundException('Sessão não encontrada');
      if (session.companyId !== user.companyId) throw new ForbiddenException('Acesso negado');
    }

    const job = await this.jobs.createJob({
      type: 'DOWNLOAD_ZIP',
      requestedById: user.sub,
      requestedByRole: user.role,
      trainingSessionId,
      totalItems: participantIds.length,
    });
    void this.processBulkDownload(job.id, participantIds);
    return { jobId: job.id };
  }

  private async processBulkDownload(jobId: string, participantIds: string[]) {
    await this.jobs.markRunning(jobId);

    const tmpPath = path.join(os.tmpdir(), `simtc-bulk-download-${jobId}.zip`);
    const output = fs.createWriteStream(tmpPath);
    const archive = archiver('zip', { zlib: { level: 9 } });

    const archiveFinished = new Promise<void>((resolve, reject) => {
      output.on('close', () => resolve());
      archive.on('error', (err) => reject(err));
    });
    archive.pipe(output);

    try {
      const usedFolderNames = new Set<string>();

      // Grupos de 5 em paralelo — busca no Storage é I/O-bound, mas cada PDF
      // pesa alguns KB/MB e o VPS tem só 4GB de RAM, então não vale a pena
      // baixar tudo de uma vez.
      const chunkSize = 5;
      for (let i = 0; i < participantIds.length; i += chunkSize) {
        const chunk = participantIds.slice(i, i + chunkSize);
        const chunkResults = await Promise.all(chunk.map((id) => this.collectParticipantFiles(id)));

        for (const r of chunkResults) {
          let folderName = r.folderName;
          if (usedFolderNames.has(folderName)) {
            folderName = `${folderName}_${r.result.participantId.slice(-6)}`;
          }
          usedFolderNames.add(folderName);

          if (r.certificateBuffer) archive.append(r.certificateBuffer, { name: `${folderName}/certificado.pdf` });
          if (r.reportBuffer) archive.append(r.reportBuffer, { name: `${folderName}/relatorio.pdf` });

          await this.jobs.recordItemResult(jobId, r.result);
        }
      }

      await archive.finalize();
      await archiveFinished;

      await this.jobs.completeJob(jobId, tmpPath);
    } catch (err: any) {
      await this.jobs.failJob(jobId, err.message ?? 'Falha ao gerar arquivo ZIP');
    }
  }

  private async collectParticipantFiles(trainingParticipantId: string): Promise<{
    certificateBuffer: Buffer | null;
    reportBuffer: Buffer | null;
    folderName: string;
    result: BulkItemResult;
  }> {
    const tp = await this.prisma.trainingParticipant.findUnique({
      where: { id: trainingParticipantId },
      include: { participant: true, certificate: true, assessment: true },
    });

    if (!tp) {
      return {
        certificateBuffer: null,
        reportBuffer: null,
        folderName: trainingParticipantId,
        result: { participantId: trainingParticipantId, name: trainingParticipantId, status: 'failed', reason: 'Participante não encontrado' },
      };
    }

    const name = tp.participant.name;
    const folderName = this.sanitizeFolderName(name);
    const problems: string[] = [];
    let certificateBuffer: Buffer | null = null;
    let reportBuffer: Buffer | null = null;

    // Certificado — gera na hora se ainda não existir
    let certUrl = tp.certificate?.pdfUrl ?? null;
    if (!certUrl) {
      try {
        const cert = await this.certificates.generateCertificateForParticipant(trainingParticipantId);
        certUrl = cert.pdfUrl;
      } catch (err: any) {
        problems.push(`certificado indisponível (${err.message})`);
      }
    }
    if (certUrl) {
      const certPath = certUrl.split('/certificates/')[1];
      if (certPath) certificateBuffer = await this.storage.download('certificates', certPath).catch(() => null);
    }

    // Relatório — só se o participante tiver avaliação prática lançada
    if (tp.assessment) {
      let reportUrl = tp.assessment.reportPdfUrl ?? null;
      if (!reportUrl) {
        try {
          const updated = await this.certificates.generateReportForParticipant(trainingParticipantId);
          reportUrl = updated.reportPdfUrl;
        } catch (err: any) {
          problems.push(`relatório indisponível (${err.message})`);
        }
      }
      if (reportUrl) {
        const reportPath = reportUrl.split('/reports/')[1];
        if (reportPath) reportBuffer = await this.storage.download('reports', reportPath).catch(() => null);
      }
    }

    if (!certificateBuffer && !reportBuffer) {
      return {
        certificateBuffer: null,
        reportBuffer: null,
        folderName,
        result: {
          participantId: trainingParticipantId,
          name,
          status: 'skipped',
          reason: problems.length ? problems.join('; ') : 'Nenhum documento disponível',
        },
      };
    }

    return {
      certificateBuffer,
      reportBuffer,
      folderName,
      result: {
        participantId: trainingParticipantId,
        name,
        status: 'success',
        reason: problems.length ? problems.join('; ') : undefined,
      },
    };
  }

  // ─── GERAÇÃO DE CERTIFICADOS/RELATÓRIOS EM LOTE ────────────────────────

  /**
   * Gera (ou gera de novo) certificado e relatório dos participantes pedidos.
   * Uma geração ativa por sessão: se já há uma rodando, devolve o id dela com
   * `alreadyRunning` em vez de criar outra (a tela abre o progresso existente).
   */
  async startBulkGenerateDocuments(
    trainingSessionId: string,
    participantIds: string[],
    user: JwtPayload,
  ): Promise<{ jobId: string; alreadyRunning: boolean }> {
    const session = await this.prisma.trainingSession.findUnique({
      where: { id: trainingSessionId },
      select: { status: true },
    });
    if (!session) throw new NotFoundException('Sessão não encontrada');
    if (session.status !== 'CONCLUIDO') {
      throw new BadRequestException('Conclua o treinamento antes de gerar os documentos');
    }

    const active = await this.jobs.findActiveJob(trainingSessionId, 'GENERATE_DOCUMENTS');
    if (active) return { jobId: active.id, alreadyRunning: true };

    const job = await this.jobs.createJob({
      type: 'GENERATE_DOCUMENTS',
      requestedById: user.sub,
      requestedByRole: user.role,
      trainingSessionId,
      totalItems: participantIds.length,
    });
    void this.processBulkGenerateDocuments(job.id, trainingSessionId, participantIds);
    return { jobId: job.id, alreadyRunning: false };
  }

  async getActiveGenerateDocumentsJob(trainingSessionId: string): Promise<{ jobId: string | null }> {
    const active = await this.jobs.findActiveJob(trainingSessionId, 'GENERATE_DOCUMENTS');
    return { jobId: active?.id ?? null };
  }

  private async processBulkGenerateDocuments(jobId: string, trainingSessionId: string, participantIds: string[]) {
    try {
      await this.jobs.markRunning(jobId);

      // Pool: PDF_RENDER_CONCURRENCY participantes em andamento ao mesmo
      // tempo. Quando um termina, o resultado dele é gravado na hora e o
      // trabalhador já pega o próximo da fila, sem esperar os outros (em
      // grupos, quem terminava antes ficava parado e o progresso subia aos
      // saltos). Cada documento é gravado assim que fica pronto, então uma
      // interrupção mantém o que já foi gerado.
      let next = 0;
      let stopped = false;
      // `recordItemResult` lê o array de resultados, acrescenta e salva de
      // volta: duas chamadas ao mesmo tempo perderiam resultados. Os
      // trabalhadores gravam em fila, uma de cada vez.
      let recording: Promise<unknown> = Promise.resolve();
      const record = (result: BulkItemResult) => {
        const run = recording.then(() => this.jobs.recordItemResult(jobId, result));
        recording = run;
        return run;
      };

      const worker = async () => {
        while (!stopped && next < participantIds.length) {
          const id = participantIds[next++];
          try {
            const result = await this.generateDocumentsForOne(id, trainingSessionId);
            await record(result);
          } catch (err) {
            // Falha ao gravar o progresso: ninguém começa participante novo.
            stopped = true;
            throw err;
          }
        }
      };

      const workers = Math.min(PDF_RENDER_CONCURRENCY, participantIds.length);
      await Promise.all(Array.from({ length: workers }, worker));

      await this.jobs.completeJob(jobId);
    } catch (err: any) {
      // Roda solto no event loop: nada pode escapar como rejeição não tratada.
      try {
        await this.jobs.failJob(jobId, err?.message ?? 'Falha ao gerar documentos');
      } catch {
        // banco fora do ar: o job vira órfão e é limpo no próximo boot
      }
    }
  }

  /** Nunca lança: um erro de um participante (ex.: soluço do banco) vira falha só dele. */
  private async generateDocumentsForOne(trainingParticipantId: string, trainingSessionId: string): Promise<BulkItemResult> {
    try {
      return await this.generateDocumentsForOneUnsafe(trainingParticipantId, trainingSessionId);
    } catch (err: any) {
      return {
        participantId: trainingParticipantId,
        name: trainingParticipantId,
        status: 'failed',
        reason: err?.message ?? 'Erro desconhecido',
      };
    }
  }

  private async generateDocumentsForOneUnsafe(
    trainingParticipantId: string,
    trainingSessionId: string,
  ): Promise<BulkItemResult> {
    const tp = await this.prisma.trainingParticipant.findUnique({
      where: { id: trainingParticipantId },
      include: { participant: true, assessment: { select: { id: true } } },
    });
    if (!tp || tp.trainingSessionId !== trainingSessionId) {
      return {
        participantId: trainingParticipantId,
        name: tp?.participant?.name ?? trainingParticipantId,
        status: 'failed',
        reason: 'Participante não encontrado nesta sessão',
      };
    }
    const name = tp.participant.name;

    // Mesmas regras de elegibilidade de generateBatch / generateAssessmentReports.
    const wantsCertificate = tp.status === 'APROVADO' || tp.participationType === 'SOMENTE_TEORICA';
    const wantsReport = !!tp.assessment;
    if (!wantsCertificate && !wantsReport) {
      return {
        participantId: trainingParticipantId,
        name,
        status: 'skipped',
        reason: 'Sem documento a gerar: não aprovado e sem avaliação prática',
      };
    }

    const problems: string[] = [];
    if (wantsCertificate) {
      await this.certificates
        .generateCertificateForParticipant(trainingParticipantId)
        .catch((err: any) => problems.push(`certificado: ${err?.message ?? 'erro desconhecido'}`));
    }
    if (wantsReport) {
      await this.certificates
        .generateReportForParticipant(trainingParticipantId)
        .catch((err: any) => problems.push(`relatório: ${err?.message ?? 'erro desconhecido'}`));
    }

    return problems.length
      ? { participantId: trainingParticipantId, name, status: 'failed', reason: problems.join('; ') }
      : { participantId: trainingParticipantId, name, status: 'success' };
  }

  /** Remove acentos e caracteres inválidos para nome de pasta dentro do ZIP. */
  private sanitizeFolderName(name: string): string {
    return (
      name
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/[^a-zA-Z0-9 ]/g, '')
        .trim()
        .replace(/\s+/g, '_') || 'participante'
    );
  }

  private sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
