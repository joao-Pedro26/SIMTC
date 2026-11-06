import { ReportsService } from 'src/reports/reports.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { JwtPayload } from '@simtc/shared-types';

describe('ReportsService.getSessionReport: assinatura do participante', () => {
  const prisma = { trainingSession: { findUniqueOrThrow: jest.fn() } };
  const service = new ReportsService(prisma as unknown as PrismaService);
  const admin = { sub: 'u1', role: 'ADMIN' } as unknown as JwtPayload;

  it('não expõe signaturePath/signatureUpdatedAt e devolve hasSignature', async () => {
    prisma.trainingSession.findUniqueOrThrow.mockResolvedValue({
      id: 's1',
      companyId: 'co1',
      consultants: [],
      participants: [
        {
          id: 'tp1',
          assessment: { id: 'a1', items: [] },
          certificate: null,
          participant: { id: 'p1', name: 'Maria', signaturePath: 'participants/p1/1.png', signatureUpdatedAt: new Date() },
        },
        {
          id: 'tp2',
          assessment: null,
          certificate: null,
          participant: { id: 'p2', name: 'Joao', signaturePath: null, signatureUpdatedAt: null },
        },
      ],
    });
    const result = await service.getSessionReport('s1', admin);
    const [a, b] = result.participants as any[];
    expect(a.participant.hasSignature).toBe(true);
    expect(b.participant.hasSignature).toBe(false);
    for (const p of [a.participant, b.participant]) {
      expect(p).not.toHaveProperty('signaturePath');
      expect(p).not.toHaveProperty('signatureUpdatedAt');
    }
    expect(a.assessment).toEqual({ id: 'a1', items: [] });
  });
});
