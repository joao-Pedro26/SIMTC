import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, BadRequestException } from '@nestjs/common';
import { BulkActionsService } from 'src/participants/bulk-actions.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { JobsService } from 'src/jobs/jobs.service';
import { ParticipantsService } from 'src/participants/participants.service';
import { CertificatesService } from 'src/certificates/certificates.service';
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

  describe('sanitizeFolderName', () => {
    it('remove acentos, caracteres inválidos e troca espaços por _', () => {
      expect((service as any).sanitizeFolderName('João da Conceição')).toBe('Joao_da_Conceicao');
    });

    it('usa um nome default quando o resultado fica vazio', () => {
      expect((service as any).sanitizeFolderName('%%%')).toBe('participante');
    });
  });
});
