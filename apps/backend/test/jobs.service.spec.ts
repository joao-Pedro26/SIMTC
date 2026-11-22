import { Test, TestingModule } from '@nestjs/testing';
import {
  JobsService,
  ORPHANED_GENERATE_DOCUMENTS_MESSAGE,
  ORPHANED_JOB_MESSAGE,
} from 'src/jobs/jobs.service';
import { PrismaService } from 'src/prisma/prisma.service';

const mockPrisma = {
  bulkOperationJob: { findFirst: jest.fn(), updateMany: jest.fn() },
};

describe('JobsService', () => {
  let service: JobsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [JobsService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();

    service = module.get<JobsService>(JobsService);
    jest.clearAllMocks();
    mockPrisma.bulkOperationJob.updateMany.mockResolvedValue({ count: 0 });
  });

  describe('findActiveJob', () => {
    it('busca só PENDING/RUNNING do tipo na sessão, o mais recente', async () => {
      mockPrisma.bulkOperationJob.findFirst.mockResolvedValue({ id: 'job-1' });

      const job = await service.findActiveJob('s1', 'GENERATE_DOCUMENTS');

      expect(job).toEqual({ id: 'job-1' });
      expect(mockPrisma.bulkOperationJob.findFirst).toHaveBeenCalledWith({
        where: { trainingSessionId: 's1', type: 'GENERATE_DOCUMENTS', status: { in: ['PENDING', 'RUNNING'] } },
        orderBy: { createdAt: 'desc' },
      });
    });
  });

  describe('failOrphanedJobs', () => {
    it('marca geração órfã com a mensagem dos documentos', async () => {
      await service.failOrphanedJobs();

      expect(mockPrisma.bulkOperationJob.updateMany).toHaveBeenCalledWith({
        where: { status: { in: ['PENDING', 'RUNNING'] }, type: 'GENERATE_DOCUMENTS' },
        data: { status: 'FAILED', errorMessage: ORPHANED_GENERATE_DOCUMENTS_MESSAGE },
      });
    });

    it('marca os outros tipos com a mensagem genérica', async () => {
      await service.failOrphanedJobs();

      expect(mockPrisma.bulkOperationJob.updateMany).toHaveBeenCalledWith({
        where: { status: { in: ['PENDING', 'RUNNING'] }, type: { not: 'GENERATE_DOCUMENTS' } },
        data: { status: 'FAILED', errorMessage: ORPHANED_JOB_MESSAGE },
      });
    });

    it('devolve o total de jobs marcados', async () => {
      mockPrisma.bulkOperationJob.updateMany
        .mockResolvedValueOnce({ count: 2 })
        .mockResolvedValueOnce({ count: 1 });

      await expect(service.failOrphanedJobs()).resolves.toBe(3);
    });

    it('as mensagens são as do spec', () => {
      expect(ORPHANED_GENERATE_DOCUMENTS_MESSAGE).toBe(
        'Interrompido porque o servidor reiniciou. Os documentos já gerados foram salvos; gere novamente os pendentes.',
      );
      expect(ORPHANED_JOB_MESSAGE).toBe(
        'Interrompido porque o servidor reiniciou. O que já foi processado foi mantido; rode a ação de novo para os itens que faltaram.',
      );
    });
  });

  describe('onApplicationBootstrap', () => {
    it('limpa os jobs órfãos ao subir', async () => {
      const spy = jest.spyOn(service, 'failOrphanedJobs').mockResolvedValue(0);

      await service.onApplicationBootstrap();

      expect(spy).toHaveBeenCalledTimes(1);
    });
  });
});
