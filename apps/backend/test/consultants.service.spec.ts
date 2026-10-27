import { ConsultantsService } from 'src/consultants/consultants.service';
import { PrismaService } from 'src/prisma/prisma.service';
import { StorageService } from 'src/storage/storage.service';
import { EmailService } from 'src/email/email.service';

describe('ConsultantsService.deleteConsultant (Fase 8D-1)', () => {
  const prisma = {
    consultant: { findUnique: jest.fn(), delete: jest.fn() },
    sessionConsultant: { deleteMany: jest.fn() },
    trainingSession: { updateMany: jest.fn() },
    practicalAssessment: { updateMany: jest.fn() },
    demandPipeline: { updateMany: jest.fn() },
    trainingParticipant: { findMany: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
    user: { findMany: jest.fn(), deleteMany: jest.fn() },
    bulkOperationJob: { deleteMany: jest.fn() },
    // A transação interativa roda com o próprio mock no papel do `tx`.
    $transaction: jest.fn((fn: (tx: unknown) => unknown) => fn(prisma)),
  };
  const service = new ConsultantsService(
    prisma as unknown as PrismaService,
    {} as StorageService,
    {} as EmailService,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.consultant.findUnique.mockResolvedValue({ id: 'c1' });
    prisma.user.findMany.mockResolvedValue([]);
    prisma.trainingParticipant.updateMany.mockResolvedValue({ count: 1 });
  });

  it('libera quem estava em avaliação com ele, de qualquer treinamento, antes de apagar a referência', async () => {
    prisma.trainingParticipant.findMany.mockResolvedValue([
      { id: 'tp-1', assessment: null },
      { id: 'tp-2', assessment: { score: 90 } },
    ]);

    await service.deleteConsultant('c1');

    expect(prisma.trainingParticipant.findMany).toHaveBeenCalledWith({
      where: { assignedConsultantId: 'c1', status: 'EM_AVALIACAO' },
      include: { assessment: { select: { score: true } } },
    });
    // As duas primeiras chamadas são a liberação; a terceira, logo abaixo, só tira a referência.
    expect(prisma.trainingParticipant.updateMany.mock.calls.slice(0, 2)).toEqual([
      [{ where: { id: 'tp-1', status: 'EM_AVALIACAO' }, data: { assignedConsultantId: null, status: 'PENDENTE' } }],
      [{ where: { id: 'tp-2', status: 'EM_AVALIACAO' }, data: { assignedConsultantId: null, status: 'APROVADO' } }],
    ]);
    // O resto (já avaliado com ele) só perde a referência, depois: antes,
    // a liberação não acharia mais ninguém com ele.
    expect(prisma.trainingParticipant.updateMany).toHaveBeenCalledWith({
      where: { assignedConsultantId: 'c1' },
      data: { assignedConsultantId: null },
    });
    const [releasedAt] = prisma.trainingParticipant.findMany.mock.invocationCallOrder;
    const droppedAt = prisma.trainingParticipant.updateMany.mock.invocationCallOrder[2];
    expect(releasedAt).toBeLessThan(droppedAt);
    expect(prisma.consultant.delete).toHaveBeenCalledWith({ where: { id: 'c1' } });
  });
});
