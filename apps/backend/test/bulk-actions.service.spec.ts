import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, BadRequestException, NotFoundException } from '@nestjs/common';
import { BulkActionsService } from 'src/participants/bulk-actions.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { JobsService } from 'src/jobs/jobs.service';
import { ParticipantsService } from 'src/participants/participants.service';
import { CertificatesService } from 'src/certificates/certificates.service';
import { PDF_RENDER_CONCURRENCY } from 'src/certificates/pdf-generator.service';
import { EmailService, EmailRateLimitError } from 'src/email/email.service';
import { StorageService } from 'src/storage/storage.service';

const mockPrisma = {
  trainingParticipant: { findUnique: jest.fn() },
  trainingSession: { findUnique: jest.fn() },
  certificate: { findUnique: jest.fn() },
};
const mockJobs = {
  createJob: jest.fn(),
  markRunning: jest.fn(),
  recordItemResult: jest.fn(),
  completeJob: jest.fn(),
  failJob: jest.fn(),
  getJobForUser: jest.fn(),
  findActiveJob: jest.fn(),
};
const mockParticipants = { removeParticipant: jest.fn() };
const mockCertificates = {
  generateCertificateForParticipant: jest.fn(),
  generateReportForParticipant: jest.fn(),
  sendByEmail: jest.fn(),
};
const mockEmail = {};
const mockStorage = { download: jest.fn() };

describe('BulkActionsService', () => {
  let service: BulkActionsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BulkActionsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JobsService, useValue: mockJobs },
        { provide: ParticipantsService, useValue: mockParticipants },
        { provide: CertificatesService, useValue: mockCertificates },
        { provide: EmailService, useValue: mockEmail },
        { provide: StorageService, useValue: mockStorage },
      ],
    }).compile();

    service = module.get<BulkActionsService>(BulkActionsService);
    jest.clearAllMocks();
    mockJobs.createJob.mockResolvedValue({ id: 'job-1' });
    // evita delays reais de verdade nos testes de rate-limit do Resend
    jest.spyOn(service as any, 'sleep').mockResolvedValue(undefined);
  });

  // ─── exclusão em lote ────────────────────────────────────────────────────

  describe('deleteOne', () => {
    it('marca sucesso quando a exclusão funciona', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1', participant: { name: 'Ana' } });
      mockParticipants.removeParticipant.mockResolvedValue({ id: 'tp-1' });

      const result = await (service as any).deleteOne('tp-1');

      expect(result).toEqual({ participantId: 'tp-1', name: 'Ana', status: 'success' });
    });

    it('marca falha (sem lançar) quando o participante está EM_AVALIACAO', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-2', participant: { name: 'Bruno' } });
      mockParticipants.removeParticipant.mockRejectedValue(
        new BadRequestException('Não é possível remover participante em avaliação'),
      );

      const result = await (service as any).deleteOne('tp-2');

      expect(result).toEqual({
        participantId: 'tp-2',
        name: 'Bruno',
        status: 'failed',
        reason: 'Não é possível remover participante em avaliação',
      });
    });

    it('marca falha quando o participante não existe, sem chamar removeParticipant', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);

      const result = await (service as any).deleteOne('tp-inexistente');

      expect(result).toEqual({
        participantId: 'tp-inexistente',
        name: 'tp-inexistente',
        status: 'failed',
        reason: 'Participante não encontrado',
      });
      expect(mockParticipants.removeParticipant).not.toHaveBeenCalled();
    });
  });

  describe('processBulkDelete', () => {
    it('processa o lote inteiro mesmo quando 1 item falha (EM_AVALIACAO)', async () => {
      mockPrisma.trainingParticipant.findUnique.mockImplementation(({ where }: any) =>
        Promise.resolve({ id: where.id, participant: { name: where.id } }),
      );
      mockParticipants.removeParticipant.mockImplementation((id: string) =>
        id === 'tp-em-avaliacao'
          ? Promise.reject(new BadRequestException('Não é possível remover participante em avaliação'))
          : Promise.resolve({ id }),
      );

      await (service as any).processBulkDelete('job-1', ['tp-ok', 'tp-em-avaliacao']);

      expect(mockJobs.markRunning).toHaveBeenCalledWith('job-1');
      expect(mockJobs.recordItemResult).toHaveBeenCalledTimes(2);
      expect(mockJobs.recordItemResult).toHaveBeenCalledWith(
        'job-1',
        expect.objectContaining({ participantId: 'tp-ok', status: 'success' }),
      );
      expect(mockJobs.recordItemResult).toHaveBeenCalledWith(
        'job-1',
        expect.objectContaining({ participantId: 'tp-em-avaliacao', status: 'failed' }),
      );
      expect(mockJobs.completeJob).toHaveBeenCalledWith('job-1');
    });
  });

  // ─── envio de certificados/relatórios em lote ──────────────────────────

  describe('sendCertificateForOne', () => {
    it('pula quando o participante não tem e-mail cadastrado', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
        participant: { name: 'Carla', email: null },
        certificate: null,
        assessment: null,
      });

      const result = await (service as any).sendCertificateForOne('tp-1');

      expect(result).toEqual({
        participantId: 'tp-1',
        name: 'Carla',
        status: 'skipped',
        reason: 'Participante sem e-mail cadastrado',
      });
      expect(mockCertificates.generateCertificateForParticipant).not.toHaveBeenCalled();
    });

    it('pula quando a geração automática do certificado falha', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
        participant: { name: 'Diego', email: 'diego@x.com' },
        certificate: null,
        assessment: null,
      });
      mockCertificates.generateCertificateForParticipant.mockRejectedValue(new Error('template ausente'));

      const result = await (service as any).sendCertificateForOne('tp-1');

      expect(result.status).toBe('skipped');
      expect(result.reason).toContain('template ausente');
    });

    it('envia com sucesso quando o certificado já existe (não gera de novo)', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
        participant: { name: 'Elis', email: 'elis@x.com' },
        certificate: { pdfUrl: 'https://x/certificates/foo.pdf' },
        assessment: null,
      });
      mockPrisma.certificate.findUnique.mockResolvedValue({ id: 'cert-1', pdfUrl: 'https://x/certificates/foo.pdf' });
      mockCertificates.sendByEmail.mockResolvedValue(undefined);

      const result = await (service as any).sendCertificateForOne('tp-1');

      expect(mockCertificates.generateCertificateForParticipant).not.toHaveBeenCalled();
      expect(mockCertificates.sendByEmail).toHaveBeenCalledWith('cert-1', 'participant');
      expect(result).toEqual({ participantId: 'tp-1', name: 'Elis', status: 'success' });
    });

    it('tenta de novo 1x em rate limit do Resend e consegue na segunda tentativa', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
        participant: { name: 'Fabio', email: 'fabio@x.com' },
        certificate: { pdfUrl: 'https://x/certificates/foo.pdf' },
        assessment: null,
      });
      mockPrisma.certificate.findUnique.mockResolvedValue({ id: 'cert-2', pdfUrl: 'https://x/certificates/foo.pdf' });
      mockCertificates.sendByEmail
        .mockRejectedValueOnce(new EmailRateLimitError('rate limited'))
        .mockResolvedValueOnce(undefined);

      const result = await (service as any).sendCertificateForOne('tp-1');

      expect(mockCertificates.sendByEmail).toHaveBeenCalledTimes(2);
      expect(result).toEqual({ participantId: 'tp-1', name: 'Fabio', status: 'success' });
    });

    it('desiste e marca falha se o rate limit persistir na 2ª tentativa', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
        participant: { name: 'Gustavo', email: 'gustavo@x.com' },
        certificate: { pdfUrl: 'https://x/certificates/foo.pdf' },
        assessment: null,
      });
      mockPrisma.certificate.findUnique.mockResolvedValue({ id: 'cert-3', pdfUrl: 'https://x/certificates/foo.pdf' });
      mockCertificates.sendByEmail.mockRejectedValue(new EmailRateLimitError('rate limited'));

      const result = await (service as any).sendCertificateForOne('tp-1');

      expect(mockCertificates.sendByEmail).toHaveBeenCalledTimes(2);
      expect(result.status).toBe('failed');
    });
  });

  // ─── download em lote (ZIP) ─────────────────────────────────────────────

  describe('startBulkDownload — controle de acesso do CLIENT', () => {
    it('nega acesso (403) se o CLIENT tentar baixar ZIP de sessão de outra empresa', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ companyId: 'empresa-A' });

      await expect(
        service.startBulkDownload('sess-1', ['tp-1'], { sub: 'user-1', role: 'CLIENT', companyId: 'empresa-B' } as any),
      ).rejects.toThrow(ForbiddenException);

      expect(mockJobs.createJob).not.toHaveBeenCalled();
    });

    it('permite quando a empresa do CLIENT bate com a da sessão', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ companyId: 'empresa-A' });
      // não deixa o processamento real (archiver/fs) rodar solto neste teste
      jest.spyOn(service as any, 'processBulkDownload').mockResolvedValue(undefined);

      const { jobId } = await service.startBulkDownload('sess-1', ['tp-1'], {
        sub: 'user-1',
        role: 'CLIENT',
        companyId: 'empresa-A',
      } as any);

      expect(jobId).toBe('job-1');
      expect(mockJobs.createJob).toHaveBeenCalled();
    });
  });

  describe('collectParticipantFiles', () => {
    it('baixa certificado e relatório quando ambos já existem', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
        participant: { name: 'Helena' },
        certificate: { pdfUrl: 'https://x/certificates/abc.pdf' },
        assessment: { reportPdfUrl: 'https://x/reports/def.pdf' },
      });
      mockStorage.download.mockImplementation((bucket: string) => Promise.resolve(Buffer.from(bucket)));

      const result = await (service as any).collectParticipantFiles('tp-1');

      expect(result.result.status).toBe('success');
      expect(result.certificateBuffer).toEqual(Buffer.from('certificates'));
      expect(result.reportBuffer).toEqual(Buffer.from('reports'));
      expect(result.folderName).toBe('Helena');
    });

    it('marca "skipped" quando não há certificado nem relatório disponíveis', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
        participant: { name: 'Igor' },
        certificate: null,
        assessment: null,
      });
      mockCertificates.generateCertificateForParticipant.mockRejectedValue(new Error('sem template'));

      const result = await (service as any).collectParticipantFiles('tp-1');

      expect(result.result.status).toBe('skipped');
      expect(result.result.reason).toContain('sem template');
      expect(result.certificateBuffer).toBeNull();
      expect(result.reportBuffer).toBeNull();
    });
  });

  // ─── geração de documentos em lote ─────────────────────────────────────

  describe('startBulkGenerateDocuments', () => {
    const admin = { sub: 'admin-1', role: 'ADMIN' } as any;

    it('recusa sessão que não está CONCLUIDO', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ status: 'EM_ANDAMENTO' });

      await expect(service.startBulkGenerateDocuments('s1', ['tp-1'], admin)).rejects.toThrow(BadRequestException);
      expect(mockJobs.createJob).not.toHaveBeenCalled();
    });

    it('recusa sessão inexistente', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(null);

      await expect(service.startBulkGenerateDocuments('s1', ['tp-1'], admin)).rejects.toThrow(NotFoundException);
    });

    it('devolve o job em andamento em vez de criar outro', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ status: 'CONCLUIDO' });
      mockJobs.findActiveJob.mockResolvedValue({ id: 'job-ativo' });

      const result = await service.startBulkGenerateDocuments('s1', ['tp-1'], admin);

      expect(result).toEqual({ jobId: 'job-ativo', alreadyRunning: true });
      expect(mockJobs.findActiveJob).toHaveBeenCalledWith('s1', 'GENERATE_DOCUMENTS');
      expect(mockJobs.createJob).not.toHaveBeenCalled();
    });

    it('cria o job com o total de ids', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ status: 'CONCLUIDO' });
      mockJobs.findActiveJob.mockResolvedValue(null);
      const process = jest.spyOn(service as any, 'processBulkGenerateDocuments').mockResolvedValue(undefined);

      const result = await service.startBulkGenerateDocuments('s1', ['tp-1', 'tp-2'], admin);

      expect(result).toEqual({ jobId: 'job-1', alreadyRunning: false });
      expect(mockJobs.createJob).toHaveBeenCalledWith(
        expect.objectContaining({ type: 'GENERATE_DOCUMENTS', totalItems: 2, trainingSessionId: 's1' }),
      );
      expect(process).toHaveBeenCalledWith('job-1', 's1', ['tp-1', 'tp-2']);
    });
  });

  describe('getActiveGenerateDocumentsJob', () => {
    it('devolve o id do job ativo ou null', async () => {
      mockJobs.findActiveJob.mockResolvedValueOnce({ id: 'job-ativo' }).mockResolvedValueOnce(null);

      await expect(service.getActiveGenerateDocumentsJob('s1')).resolves.toEqual({ jobId: 'job-ativo' });
      await expect(service.getActiveGenerateDocumentsJob('s1')).resolves.toEqual({ jobId: null });
    });
  });

  describe('generateDocumentsForOne', () => {
    const tp = (overrides: Record<string, unknown> = {}) => ({
      id: 'tp-1',
      trainingSessionId: 's1',
      status: 'APROVADO',
      participationType: 'TEORICA_E_PRATICA',
      participant: { name: 'Ana' },
      assessment: { id: 'a1' },
      ...overrides,
    });

    beforeEach(() => {
      mockCertificates.generateCertificateForParticipant.mockResolvedValue({});
      mockCertificates.generateReportForParticipant.mockResolvedValue({});
    });

    it('gera os dois para aprovado com avaliação', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(tp());

      const result = await (service as any).generateDocumentsForOne('tp-1', 's1');

      expect(mockCertificates.generateCertificateForParticipant).toHaveBeenCalledWith('tp-1');
      expect(mockCertificates.generateReportForParticipant).toHaveBeenCalledWith('tp-1');
      expect(result).toEqual({ participantId: 'tp-1', name: 'Ana', status: 'success' });
    });

    it('só certificado para SOMENTE_TEORICA sem avaliação', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(
        tp({ status: 'PENDENTE', participationType: 'SOMENTE_TEORICA', assessment: null }),
      );

      const result = await (service as any).generateDocumentsForOne('tp-1', 's1');

      expect(mockCertificates.generateCertificateForParticipant).toHaveBeenCalledWith('tp-1');
      expect(mockCertificates.generateReportForParticipant).not.toHaveBeenCalled();
      expect(result.status).toBe('success');
    });

    it('só relatório para NAO_RECOMENDADO', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(tp({ status: 'NAO_RECOMENDADO' }));

      const result = await (service as any).generateDocumentsForOne('tp-1', 's1');

      expect(mockCertificates.generateCertificateForParticipant).not.toHaveBeenCalled();
      expect(mockCertificates.generateReportForParticipant).toHaveBeenCalledWith('tp-1');
      expect(result.status).toBe('success');
    });

    it('pula quem não tem documento a gerar', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(tp({ status: 'PENDENTE', assessment: null }));

      const result = await (service as any).generateDocumentsForOne('tp-1', 's1');

      expect(result).toEqual({
        participantId: 'tp-1',
        name: 'Ana',
        status: 'skipped',
        reason: 'Sem documento a gerar: não aprovado e sem avaliação prática',
      });
      expect(mockCertificates.generateCertificateForParticipant).not.toHaveBeenCalled();
    });

    it('falha parcial mantém o que gerou', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(tp());
      mockCertificates.generateReportForParticipant.mockRejectedValue(new Error('sem textos'));

      const result = await (service as any).generateDocumentsForOne('tp-1', 's1');

      expect(mockCertificates.generateCertificateForParticipant).toHaveBeenCalledWith('tp-1');
      expect(result).toEqual({ participantId: 'tp-1', name: 'Ana', status: 'failed', reason: 'relatório: sem textos' });
    });

    it('junta os dois motivos quando os dois falham', async () => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(tp());
      mockCertificates.generateCertificateForParticipant.mockRejectedValue(new Error('a'));
      mockCertificates.generateReportForParticipant.mockRejectedValue(new Error('b'));

      const result = await (service as any).generateDocumentsForOne('tp-1', 's1');

      expect(result.reason).toBe('certificado: a; relatório: b');
    });

    it('erro inesperado ao ler o participante vira falha dele, sem derrubar o lote', async () => {
      mockPrisma.trainingParticipant.findUnique.mockRejectedValue(new Error('pooler caiu'));

      const result = await (service as any).generateDocumentsForOne('tp-1', 's1');

      expect(result).toEqual({ participantId: 'tp-1', name: 'tp-1', status: 'failed', reason: 'pooler caiu' });
    });

    it.each([
      ['de outra sessão', { trainingSessionId: 's2' }],
      ['removido', null],
    ])('participante %s falha sem gerar nada', async (_label, value) => {
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(value === null ? null : tp(value as any));

      const result = await (service as any).generateDocumentsForOne('tp-1', 's1');

      expect(result).toEqual(
        expect.objectContaining({ participantId: 'tp-1', status: 'failed', reason: 'Participante não encontrado nesta sessão' }),
      );
      expect(mockCertificates.generateCertificateForParticipant).not.toHaveBeenCalled();
      expect(mockCertificates.generateReportForParticipant).not.toHaveBeenCalled();
    });
  });

  describe('processBulkGenerateDocuments', () => {
    it('processa todos e conclui', async () => {
      jest
        .spyOn(service as any, 'generateDocumentsForOne')
        .mockImplementation(async (id: any) => ({ participantId: id, name: id, status: 'success' }));

      await (service as any).processBulkGenerateDocuments('job-1', 's1', ['tp-1', 'tp-2', 'tp-3']);

      expect(mockJobs.markRunning).toHaveBeenCalledWith('job-1');
      expect(mockJobs.recordItemResult).toHaveBeenCalledTimes(3);
      expect(mockJobs.completeJob).toHaveBeenCalledWith('job-1');
      expect(mockJobs.failJob).not.toHaveBeenCalled();
    });

    it('marca o job como falho se algo inesperado estourar', async () => {
      jest
        .spyOn(service as any, 'generateDocumentsForOne')
        .mockImplementation(async (id: any) => ({ participantId: id, name: id, status: 'success' }));
      mockJobs.recordItemResult.mockRejectedValueOnce(new Error('db caiu'));

      await expect((service as any).processBulkGenerateDocuments('job-1', 's1', ['tp-1'])).resolves.toBeUndefined();

      expect(mockJobs.failJob).toHaveBeenCalledWith('job-1', 'db caiu');
      expect(mockJobs.completeJob).not.toHaveBeenCalled();
    });

    describe('pool de participantes', () => {
      const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

      // `clearAllMocks` não zera implementações; estes testes trocam a de
      // `recordItemResult`, então ela é restaurada ao redor de cada um.
      beforeEach(() => mockJobs.recordItemResult.mockReset());
      afterEach(() => mockJobs.recordItemResult.mockReset());

      it('mantém no máximo PDF_RENDER_CONCURRENCY participantes em andamento', async () => {
        let running = 0;
        let peak = 0;
        jest.spyOn(service as any, 'generateDocumentsForOne').mockImplementation(async (id: any) => {
          running++;
          peak = Math.max(peak, running);
          await sleep(5);
          running--;
          return { participantId: id, name: id, status: 'success' };
        });
        const ids = Array.from({ length: PDF_RENDER_CONCURRENCY * 3 }, (_, i) => `tp-${i}`);

        await (service as any).processBulkGenerateDocuments('job-1', 's1', ids);

        expect(peak).toBe(PDF_RENDER_CONCURRENCY);
        expect(mockJobs.recordItemResult).toHaveBeenCalledTimes(ids.length);
        expect(mockJobs.completeJob).toHaveBeenCalledWith('job-1');
      });

      it('grava cada resultado assim que o participante termina, sem esperar os outros', async () => {
        const delays: Record<string, number> = { 'tp-slow': 30, 'tp-fast': 1 };
        jest.spyOn(service as any, 'generateDocumentsForOne').mockImplementation(async (id: any) => {
          await sleep(delays[id]);
          return { participantId: id, name: id, status: 'success' };
        });

        await (service as any).processBulkGenerateDocuments('job-1', 's1', ['tp-slow', 'tp-fast']);

        const order = mockJobs.recordItemResult.mock.calls.map((call: any[]) => call[1].participantId);
        expect(order).toEqual(['tp-fast', 'tp-slow']);
      });

      it('um trabalhador que termina cedo já pega o próximo da fila', async () => {
        const started: string[] = [];
        const finished: string[] = [];
        jest.spyOn(service as any, 'generateDocumentsForOne').mockImplementation(async (id: any) => {
          started.push(id);
          await sleep(id === 'tp-0' ? 40 : 2);
          finished.push(id);
          return { participantId: id, name: id, status: 'success' };
        });
        const ids = Array.from({ length: PDF_RENDER_CONCURRENCY + 3 }, (_, i) => `tp-${i}`);

        await (service as any).processBulkGenerateDocuments('job-1', 's1', ids);

        // O tp-0 é lento e segura um trabalhador; os demais seguem andando e
        // começam todos os participantes da fila antes de o tp-0 terminar.
        expect(started).toHaveLength(ids.length);
        expect(finished[finished.length - 1]).toBe('tp-0');
      });

      it('nunca grava dois resultados ao mesmo tempo', async () => {
        let recording = 0;
        let peak = 0;
        mockJobs.recordItemResult.mockImplementation(async () => {
          recording++;
          peak = Math.max(peak, recording);
          await sleep(3);
          recording--;
        });
        jest
          .spyOn(service as any, 'generateDocumentsForOne')
          .mockImplementation(async (id: any) => ({ participantId: id, name: id, status: 'success' }));
        const ids = Array.from({ length: PDF_RENDER_CONCURRENCY * 2 }, (_, i) => `tp-${i}`);

        await (service as any).processBulkGenerateDocuments('job-1', 's1', ids);

        expect(peak).toBe(1);
        expect(mockJobs.recordItemResult).toHaveBeenCalledTimes(ids.length);
      });

      it('falha ao gravar o progresso para de pegar participantes novos e marca o job como falho', async () => {
        const generate = jest
          .spyOn(service as any, 'generateDocumentsForOne')
          .mockImplementation(async (id: any) => ({ participantId: id, name: id, status: 'success' }));
        mockJobs.recordItemResult.mockRejectedValue(new Error('db caiu'));
        const ids = Array.from({ length: 20 }, (_, i) => `tp-${i}`);

        await expect((service as any).processBulkGenerateDocuments('job-1', 's1', ids)).resolves.toBeUndefined();

        expect(mockJobs.failJob).toHaveBeenCalledWith('job-1', 'db caiu');
        expect(mockJobs.completeJob).not.toHaveBeenCalled();
        expect(generate.mock.calls.length).toBeLessThan(ids.length);
      });

      it('lista vazia conclui o job sem gravar nada', async () => {
        await (service as any).processBulkGenerateDocuments('job-1', 's1', []);

        expect(mockJobs.recordItemResult).not.toHaveBeenCalled();
        expect(mockJobs.completeJob).toHaveBeenCalledWith('job-1');
      });
    });
  });

  describe('sanitizeFolderName', () => {
    it('remove acentos, caracteres inválidos e troca espaços por _', () => {
      expect((service as any).sanitizeFolderName('João da Conceição')).toBe('Joao_da_Conceicao');
    });

    it('usa um nome default quando o resultado fica vazio', () => {
      expect((service as any).sanitizeFolderName('%%%')).toBe('participante');
    });
  });
});
