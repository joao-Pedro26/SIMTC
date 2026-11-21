import { Test, TestingModule } from '@nestjs/testing';
import { CertificatesService } from 'src/certificates/certificates.service';
import { PdfGeneratorService } from 'src/certificates/pdf-generator.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { StorageService } from 'src/storage/storage.service';
import { EmailService } from 'src/email/email.service';
import * as fs from 'fs';
import * as path from 'path';
import Handlebars from 'handlebars';

const mockStorage = { upload: jest.fn(), delete: jest.fn(), getSignedUrl: jest.fn(), download: jest.fn() };
const mockPdfGenerator = { renderCertificate: jest.fn(), renderAssessmentReport: jest.fn() };

const mockPrisma = {
  trainingParticipant: { findUniqueOrThrow: jest.fn() },
  trainingSession: { findUniqueOrThrow: jest.fn() },
  certificate: { upsert: jest.fn(), update: jest.fn(), findUnique: jest.fn() },
};

const PARTICIPANT_SIGNATURE_PATH = 'participants/p1/1730000000000.png';
const CONSULTANT_SIGNATURE_PATH = 'consultants/c1/1729000000000.png';

function buildTrainingParticipant(overrides: Record<string, unknown> = {}) {
  return {
    id: 'tp1',
    participantId: 'p1',
    trainingSessionId: 's1',
    status: 'APROVADO',
    participationType: 'PRESENCIAL',
    assessment: null,
    participant: {
      id: 'p1',
      name: 'Maria da Silva',
      signaturePath: PARTICIPANT_SIGNATURE_PATH,
    },
    ...overrides,
  };
}

function buildSession(consultantSignatureUrl: string | null = null) {
  return {
    id: 's1',
    date: new Date('2026-10-01T12:00:00Z'),
    company: { id: 'c1', name: 'Empresa' },
    course: { name: 'Curso', theoryHours: 4, practiceHours: 2, contentItems: [] },
    responsibleConsultant: {
      id: 'cons1',
      name: 'Consultor',
      signatureUrl: consultantSignatureUrl,
      credentialDetran: null,
      regMte: null,
    },
  };
}

describe('CertificatesService', () => {
  let service: CertificatesService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CertificatesService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: PdfGeneratorService, useValue: mockPdfGenerator },
        { provide: StorageService, useValue: mockStorage },
        { provide: EmailService, useValue: {} },
      ],
    }).compile();

    service = module.get<CertificatesService>(CertificatesService);
    jest.clearAllMocks();
    mockPrisma.certificate.upsert.mockResolvedValue({ id: 'cert1', pdfUrl: '' });
    mockPrisma.certificate.update.mockResolvedValue({ id: 'cert1', pdfUrl: 'https://storage/certificates/x.pdf' });
    mockPdfGenerator.renderCertificate.mockResolvedValue(Buffer.from('pdf'));
    mockStorage.upload.mockResolvedValue('https://storage/certificates/s1/p1-1.pdf');
    mockStorage.getSignedUrl.mockImplementation(async (_bucket: string, path: string) => `https://signed/${path}`);
  });

  describe('generateCertificateForParticipant (assinatura do participante)', () => {
    it('resolve a signed URL (300s, bucket signatures) da assinatura do participante e passa ao renderer', async () => {
      mockPrisma.trainingParticipant.findUniqueOrThrow.mockResolvedValue(buildTrainingParticipant());
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue(buildSession());

      await service.generateCertificateForParticipant('tp1');

      expect(mockStorage.getSignedUrl).toHaveBeenCalledTimes(1);
      expect(mockStorage.getSignedUrl).toHaveBeenCalledWith('signatures', PARTICIPANT_SIGNATURE_PATH, 300);
      expect(mockPdfGenerator.renderCertificate).toHaveBeenCalledTimes(1);
      const data = mockPdfGenerator.renderCertificate.mock.calls[0][0];
      expect(data.participant.signatureUrl).toBe(`https://signed/${PARTICIPANT_SIGNATURE_PATH}`);
      expect(data.participant.name).toBe('Maria da Silva');
    });

    it('segue com signatureUrl null se getSignedUrl do participante falhar, e o PDF ainda sai', async () => {
      mockPrisma.trainingParticipant.findUniqueOrThrow.mockResolvedValue(buildTrainingParticipant());
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue(buildSession());
      mockStorage.getSignedUrl.mockRejectedValue(new Error('storage offline'));

      await expect(service.generateCertificateForParticipant('tp1')).resolves.toBeDefined();

      expect(mockPdfGenerator.renderCertificate).toHaveBeenCalledTimes(1);
      const data = mockPdfGenerator.renderCertificate.mock.calls[0][0];
      expect(data.participant.signatureUrl).toBeNull();
      expect(mockStorage.upload).toHaveBeenCalledTimes(1);
    });

    it('sem signaturePath não chama o storage para o aluno e signatureUrl é null', async () => {
      mockPrisma.trainingParticipant.findUniqueOrThrow.mockResolvedValue(
        buildTrainingParticipant({
          participant: { id: 'p1', name: 'Maria da Silva', signaturePath: null },
        }),
      );
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue(buildSession());

      await service.generateCertificateForParticipant('tp1');

      expect(mockStorage.getSignedUrl).not.toHaveBeenCalled();
      const data = mockPdfGenerator.renderCertificate.mock.calls[0][0];
      expect(data.participant.signatureUrl).toBeNull();
    });

    it('sem signaturePath, a assinatura do consultor continua sendo resolvida separadamente', async () => {
      mockPrisma.trainingParticipant.findUniqueOrThrow.mockResolvedValue(
        buildTrainingParticipant({
          participant: { id: 'p1', name: 'Maria da Silva', signaturePath: null },
        }),
      );
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue(
        buildSession(`https://x.supabase.co/storage/v1/object/signatures/${CONSULTANT_SIGNATURE_PATH}`),
      );

      await service.generateCertificateForParticipant('tp1');

      expect(mockStorage.getSignedUrl).toHaveBeenCalledTimes(1);
      expect(mockStorage.getSignedUrl).toHaveBeenCalledWith('signatures', CONSULTANT_SIGNATURE_PATH, 300);
      const data = mockPdfGenerator.renderCertificate.mock.calls[0][0];
      expect(data.participant.signatureUrl).toBeNull();
      expect(data.consultant.signatureUrl).toBe(`https://signed/${CONSULTANT_SIGNATURE_PATH}`);
    });

    it('não repassa signaturePath ao renderer (só signatureUrl)', async () => {
      mockPrisma.trainingParticipant.findUniqueOrThrow.mockResolvedValue(buildTrainingParticipant());
      mockPrisma.trainingSession.findUniqueOrThrow.mockResolvedValue(buildSession());

      await service.generateCertificateForParticipant('tp1');

      const data = mockPdfGenerator.renderCertificate.mock.calls[0][0];
      expect(data.participant).not.toHaveProperty('signaturePath');
      expect(JSON.stringify(data)).not.toContain('"signaturePath"');
    });
  });

  describe('findById: assinatura do participante', () => {
    it('não expõe signaturePath/signatureUpdatedAt e devolve hasSignature', async () => {
      mockPrisma.certificate.findUnique.mockResolvedValue({
        id: 'cert1',
        trainingParticipant: {
          id: 'tp1',
          training: { id: 's1' },
          participant: { id: 'p1', name: 'Maria', signaturePath: PARTICIPANT_SIGNATURE_PATH, signatureUpdatedAt: new Date() },
        },
      });
      const result = (await service.findById('cert1')) as any;
      const p = result.trainingParticipant.participant;
      expect(p.hasSignature).toBe(true);
      expect(p).not.toHaveProperty('signaturePath');
      expect(p).not.toHaveProperty('signatureUpdatedAt');
      expect(result.trainingParticipant.training).toEqual({ id: 's1' });
    });
  });

  describe('buildScoreData: observacao do instrutor', () => {
    const cat = { id: 'cat1', code: 'CV', name: 'Cat', description: null, _count: { infractions: 5 } };
    const item = (order: number, desc: string, observation?: string | null) => ({
      ...(observation !== undefined ? { observation } : {}),
      infractionNote: {
        deduction: 1,
        comment: 'c',
        infraction: { order, description: desc, category: { id: 'cat1' } },
      },
    });
    const build = (items: any[]) => (service as any).buildScoreData(items, [cat]);

    it('repassa a observacao da infracao', () => {
      const data = build([item(1, 'A', 'texto')]);
      expect(data.topicSections[0].infractions[0].observation).toBe('texto');
    });

    it('sem observacao fica null', () => {
      const data = build([item(1, 'A'), item(2, 'B', null)]);
      expect(data.topicSections[0].infractions.map((i: any) => i.observation)).toEqual([null, null]);
    });

    it('continua ordenando por order', () => {
      const data = build([item(2, 'B', 'y'), item(1, 'A', 'x')]);
      expect(data.topicSections[0].infractions.map((i: any) => i.title)).toEqual(['A', 'B']);
    });
  });

  describe('template assessment-report: observacao do instrutor', () => {
    const tpl = Handlebars.compile(
      fs.readFileSync(path.join(__dirname, '..', 'src', 'certificates', 'templates', 'assessment-report.html'), 'utf-8'),
    );
    const render = (observation: string | null) =>
      tpl({
        topicSections: [
          { code: 'CV', name: 'Cat', description: null, infractions: [{ title: 'A', body: 'b', observation }] },
        ],
        categoryScores: [],
        conclusionParagraphs: [],
      });

    it('escapa HTML da observacao', () => {
      const html = render('a <b>x</b> & "q"' + String.fromCharCode(10) + 'linha2');
      expect(html).toContain('instructor-note');
      expect(html).toContain('&lt;b&gt;');
      expect(html).toContain('&amp;');
      expect(html).toContain('&quot;');
      expect(html).not.toContain('<b>x</b>');
    });

    it('nao renderiza o bloco sem observacao', () => {
      expect(render(null)).not.toContain('<div class="instructor-note">');
    });
  });
});
