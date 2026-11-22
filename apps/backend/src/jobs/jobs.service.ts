import {
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
  OnApplicationBootstrap,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload } from '@simtc/shared-types';

export type BulkJobType = 'DELETE_PARTICIPANTS' | 'SEND_CERTIFICATES' | 'DOWNLOAD_ZIP' | 'GENERATE_DOCUMENTS';

export const ORPHANED_GENERATE_DOCUMENTS_MESSAGE =
  'Interrompido porque o servidor reiniciou. Os documentos já gerados foram salvos; gere novamente os pendentes.';
export const ORPHANED_JOB_MESSAGE =
  'Interrompido porque o servidor reiniciou. O que já foi processado foi mantido; rode a ação de novo para os itens que faltaram.';

const ACTIVE_STATUSES = ['PENDING', 'RUNNING'] as const;

export interface BulkItemResult {
  participantId: string;
  name: string;
  status: 'success' | 'skipped' | 'failed';
  reason?: string;
}

/**
 * Infra genérica de "job em background" para ações em lote (excluir, enviar
 * e-mail, baixar ZIP). Não usa fila externa (Redis/BullMQ) — o job roda solto
 * no event loop do próprio processo Node (`void processJob(...)` sem await na
 * resposta HTTP) e o progresso fica no Postgres, lido via polling pelo
 * frontend em GET /jobs/:jobId. Ver brainstorm-acoes-lote-participantes.md.
 */
@Injectable()
export class JobsService implements OnApplicationBootstrap {
  private readonly logger = new Logger(JobsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * O job roda solto no event loop: se o processo reinicia (deploy, queda),
   * ele morre no meio e ficaria PENDING/RUNNING para sempre, travando a tela e
   * a regra de "uma geração por sessão". Ao subir, nenhum job pode estar vivo
   * (produção roda um único container), então todos os ativos viram FAILED.
   */
  async onApplicationBootstrap() {
    const count = await this.failOrphanedJobs();
    if (count > 0) this.logger.warn(`${count} job(s) interrompido(s) pelo reinício marcado(s) como FAILED`);
  }

  async failOrphanedJobs(): Promise<number> {
    const status = { in: [...ACTIVE_STATUSES] };
    const generate = await this.prisma.bulkOperationJob.updateMany({
      where: { status, type: 'GENERATE_DOCUMENTS' },
      data: { status: 'FAILED', errorMessage: ORPHANED_GENERATE_DOCUMENTS_MESSAGE },
    });
    const others = await this.prisma.bulkOperationJob.updateMany({
      where: { status, type: { not: 'GENERATE_DOCUMENTS' } },
      data: { status: 'FAILED', errorMessage: ORPHANED_JOB_MESSAGE },
    });
    return generate.count + others.count;
  }

  /** Job ainda em andamento (PENDING/RUNNING) de um tipo numa sessão, o mais recente. */
  async findActiveJob(trainingSessionId: string, type: BulkJobType) {
    return this.prisma.bulkOperationJob.findFirst({
      where: { trainingSessionId, type, status: { in: [...ACTIVE_STATUSES] } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createJob(params: {
    type: BulkJobType;
    requestedById: string;
    requestedByRole: string;
    trainingSessionId: string;
    totalItems: number;
  }) {
    return this.prisma.bulkOperationJob.create({
      data: {
        type: params.type as any,
        requestedById: params.requestedById,
        requestedByRole: params.requestedByRole as any,
        trainingSessionId: params.trainingSessionId,
        totalItems: params.totalItems,
        status: 'PENDING',
      },
    });
  }

  async markRunning(jobId: string) {
    return this.prisma.bulkOperationJob.update({
      where: { id: jobId },
      data: { status: 'RUNNING' },
    });
  }

  /**
   * Registra o resultado de 1 item processado (sucesso/pulado/falha) e
   * incrementa os contadores. Não há concorrência real entre chamadas desta
   * função dentro de um mesmo job (cada job processa sequencialmente ou em
   * pequenos grupos, sempre agregando os resultados de um grupo antes de
   * seguir para o próximo), então o padrão "lê job → concatena → salva" não
   * precisa de lock otimista.
   */
  async recordItemResult(jobId: string, result: BulkItemResult) {
    const job = await this.prisma.bulkOperationJob.findUniqueOrThrow({ where: { id: jobId } });
    const details = Array.isArray(job.resultDetails) ? (job.resultDetails as any[]) : [];
    details.push(result);

    return this.prisma.bulkOperationJob.update({
      where: { id: jobId },
      data: {
        resultDetails: details,
        processedItems: { increment: 1 },
        ...(result.status === 'success' ? { succeededItems: { increment: 1 } } : {}),
        ...(result.status === 'skipped' ? { skippedItems: { increment: 1 } } : {}),
        ...(result.status === 'failed' ? { failedItems: { increment: 1 } } : {}),
      },
    });
  }

  async completeJob(jobId: string, resultFilePath?: string) {
    return this.prisma.bulkOperationJob.update({
      where: { id: jobId },
      data: { status: 'COMPLETED', resultFilePath },
    });
  }

  async failJob(jobId: string, errorMessage: string) {
    return this.prisma.bulkOperationJob.update({
      where: { id: jobId },
      data: { status: 'FAILED', errorMessage },
    });
  }

  /** Só quem pediu o job (ou ADMIN) pode ver/baixar o resultado. */
  async getJobForUser(jobId: string, user: JwtPayload) {
    const job = await this.prisma.bulkOperationJob.findUnique({ where: { id: jobId } });
    if (!job) throw new NotFoundException('Job não encontrado');
    if (job.requestedById !== user.sub && user.role !== 'ADMIN') {
      throw new ForbiddenException('Acesso negado');
    }
    return job;
  }
}
