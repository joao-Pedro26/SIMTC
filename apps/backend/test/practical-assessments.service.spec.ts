import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from 'src/auth/decorators/roles.decorator';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { RolesGuard } from 'src/auth/guards/roles.guard';
import { PracticalAssessmentsController } from 'src/practical-assessments/practical-assessments.controller';
import { PracticalAssessmentsService } from 'src/practical-assessments/practical-assessments.service';
import { PrismaService } from 'src/prisma/prisma.service';
import {
  calculateCategoryScore,
  calculateOverallScore,
  getApprovalStatus,
  JwtPayload,
  UserRole,
} from '@simtc/shared-types';

const mockPrisma = {
  practicalAssessment: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn(), findUniqueOrThrow: jest.fn() },
  trainingParticipant: { findMany: jest.fn(), findUnique: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
  assessmentItem: { deleteMany: jest.fn() },
  assessmentCategory: { findMany: jest.fn() },
  $transaction: jest.fn(),
};

describe('PracticalAssessmentsService', () => {
  let service: PracticalAssessmentsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PracticalAssessmentsService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<PracticalAssessmentsService>(PracticalAssessmentsService);
    jest.clearAllMocks();
  });

  // ─── Funções de scoring (lógica pura) ────────────────────────────────────

  describe('calculateCategoryScore', () => {
    it('retorna 100 se não há infrações cadastradas na categoria', () => {
      expect(calculateCategoryScore([], 0)).toBe(100);
    });

    it('retorna 100 se há infrações cadastradas mas nenhuma foi marcada', () => {
      expect(calculateCategoryScore([], 5)).toBe(100);
    });

    it('desconta proporcionalmente ao número de infrações da categoria', () => {
      // 5 infrações no tópico → cada uma vale 20%. Uma nota M (peso máximo) desconta os 20% inteiros.
      expect(calculateCategoryScore([5], 5)).toBe(80);
    });

    it('nota B desconta apenas 1/5 do peso máximo dentro da fatia da infração', () => {
      // 5 infrações no tópico → fatia de 20%. Nota B (peso 1 de 5) desconta 1/5 de 20% = 4%.
      expect(calculateCategoryScore([1], 5)).toBe(96);
    });

    it('não vai abaixo de 0', () => {
      expect(calculateCategoryScore([5, 5, 5], 3)).toBe(0);
    });
  });

  describe('calculateOverallScore', () => {
    it('retorna 100 se não há categorias', () => {
      expect(calculateOverallScore([])).toBe(100);
    });

    it('retorna média das categorias', () => {
      expect(calculateOverallScore([80, 60])).toBe(70);
    });

    it('retorna valor único se só uma categoria', () => {
      expect(calculateOverallScore([85])).toBe(85);
    });
  });

  describe('getApprovalStatus', () => {
    it('retorna APROVADO se score >= 70', () => {
      expect(getApprovalStatus(70)).toBe('APROVADO');
      expect(getApprovalStatus(85)).toBe('APROVADO');
      expect(getApprovalStatus(100)).toBe('APROVADO');
    });

    it('retorna NAO_RECOMENDADO se score < 70', () => {
      expect(getApprovalStatus(69)).toBe('NAO_RECOMENDADO');
      expect(getApprovalStatus(0)).toBe('NAO_RECOMENDADO');
    });
  });

  // ─── assignParticipants ──────────────────────────────────────────────────

  describe('assignParticipants', () => {
    /** Um participante, na sessão em andamento e com parte prática, a menos
     * que o teste diga outra coisa. */
    const record = (overrides: Record<string, unknown> = {}) => ({
      id: 'tp-1',
      status: 'PENDENTE',
      assignedConsultantId: null,
      participationType: 'TEORICA_E_PRATICA',
      training: { status: 'EM_ANDAMENTO' },
      ...overrides,
    });

    /** O cliente da transação: a gravação condicional acontece nele. */
    const tx = { trainingParticipant: { updateMany: jest.fn() } };

    beforeEach(() => {
      tx.trainingParticipant.updateMany.mockReset();
      mockPrisma.$transaction.mockImplementation((fn: (t: unknown) => unknown) => fn(tx));
    });

    it('lança ConflictException se algum participante não existe', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([record()]);
      await expect(
        service.assignParticipants({ participantIds: ['tp-1', 'tp-2'] }, 'consultant-1'),
      ).rejects.toThrow(ConflictException);
    });

    it('lança ConflictException se participante já atribuído a outro consultor', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        record({ status: 'EM_AVALIACAO', assignedConsultantId: 'outro-consultor' }),
      ]);
      await expect(
        service.assignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor'),
      ).rejects.toThrow(ConflictException);
    });

    it('atribui participantes ao consultor corretamente, com a condição na própria gravação', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([record(), record({ id: 'tp-2' })]);
      tx.trainingParticipant.updateMany.mockResolvedValue({ count: 2 });

      const result = await service.assignParticipants(
        { participantIds: ['tp-1', 'tp-2'] },
        'consultant-1',
      );

      expect(result).toEqual({ assigned: 2 });
      expect(mockPrisma.trainingParticipant.findMany).toHaveBeenCalledWith({
        where: { id: { in: ['tp-1', 'tp-2'] } },
        include: { training: { select: { status: true } } },
      });
      expect(tx.trainingParticipant.updateMany).toHaveBeenCalledWith({
        where: {
          id: { in: ['tp-1', 'tp-2'] },
          status: { not: 'APROVADO' },
          OR: [{ status: { not: 'EM_AVALIACAO' } }, { assignedConsultantId: 'consultant-1' }],
        },
        data: { assignedConsultantId: 'consultant-1', status: 'EM_AVALIACAO' },
      });
    });

    it('permite reatribuir participante ao mesmo consultor', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        record({ status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor' }),
      ]);
      tx.trainingParticipant.updateMany.mockResolvedValue({ count: 1 });

      const result = await service.assignParticipants(
        { participantIds: ['tp-1'] },
        'meu-consultor',
      );
      expect(result).toEqual({ assigned: 1 });
    });

    describe('o servidor confere as regras das telas (Fase 8D-1)', () => {
      it.each([['PLANEJADO'], ['CONCLUIDO'], ['CANCELADO']])(
        'sessão %s: recusa, sem gravar nada',
        async (status) => {
          mockPrisma.trainingParticipant.findMany.mockResolvedValue([
            record({ training: { status } }),
          ]);

          await expect(
            service.assignParticipants({ participantIds: ['tp-1'] }, 'consultant-1'),
          ).rejects.toThrow('Só dá para atribuir participantes com o treinamento em andamento');
          expect(mockPrisma.$transaction).not.toHaveBeenCalled();
        },
      );

      it('"Somente teórica": recusa, sem gravar nada', async () => {
        mockPrisma.trainingParticipant.findMany.mockResolvedValue([
          record({ participationType: 'SOMENTE_TEORICA' }),
        ]);

        await expect(
          service.assignParticipants({ participantIds: ['tp-1'] }, 'consultant-1'),
        ).rejects.toThrow('Participantes somente da parte teórica não têm avaliação prática');
        expect(mockPrisma.$transaction).not.toHaveBeenCalled();
      });

      it('outro aparelho atribuiu no meio do caminho: a gravação não pega todos e recusa '
        + '(a transação desfaz o que pegou)', async () => {
        mockPrisma.trainingParticipant.findMany.mockResolvedValue([record(), record({ id: 'tp-2' })]);
        tx.trainingParticipant.updateMany.mockResolvedValue({ count: 1 });

        await expect(
          service.assignParticipants({ participantIds: ['tp-1', 'tp-2'] }, 'consultant-1'),
        ).rejects.toThrow('Um ou mais participantes já estão em avaliação com outro consultor');
      });

      it('ids repetidos no pedido contam uma vez só', async () => {
        mockPrisma.trainingParticipant.findMany.mockResolvedValue([record()]);
        tx.trainingParticipant.updateMany.mockResolvedValue({ count: 1 });

        const result = await service.assignParticipants(
          { participantIds: ['tp-1', 'tp-1'] },
          'consultant-1',
        );

        expect(result).toEqual({ assigned: 1 });
        expect(mockPrisma.trainingParticipant.findMany).toHaveBeenCalledWith(
          expect.objectContaining({ where: { id: { in: ['tp-1'] } } }),
        );
      });
    });
  });

  // ─── unassignParticipants ────────────────────────────────────────────────

  describe('unassignParticipants', () => {
    /** O cliente da transação: cada liberação é uma gravação condicional nele. */
    const tx = { trainingParticipant: { updateMany: jest.fn() } };

    beforeEach(() => {
      tx.trainingParticipant.updateMany.mockReset();
      tx.trainingParticipant.updateMany.mockResolvedValue({ count: 1 });
      mockPrisma.$transaction.mockImplementation((fn: (t: unknown) => unknown) => fn(tx));
    });

    it('lança ConflictException se algum participante não existe', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: null },
      ]);
      await expect(
        service.unassignParticipants({ participantIds: ['tp-1', 'tp-2'] }, 'meu-consultor'),
      ).rejects.toThrow(ConflictException);
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    it('lança ConflictException se o participante não está em avaliação com quem pediu', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'outro-consultor', assessment: null },
      ]);
      await expect(
        service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor'),
      ).rejects.toThrow('Um ou mais participantes não estão atribuídos a você');

      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'PENDENTE', assignedConsultantId: null, assessment: null },
      ]);
      await expect(
        service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor'),
      ).rejects.toThrow(ConflictException);
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    it('libera a atribuição e devolve o status anterior: Pendente sem avaliação, o da nota numa reavaliação', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: null },
        { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: { score: 62.5 } },
      ]);

      const result = await service.unassignParticipants(
        { participantIds: ['tp-1', 'tp-2'] },
        'meu-consultor',
      );

      expect(result).toEqual({ unassigned: 2 });
      expect(mockPrisma.trainingParticipant.findMany).toHaveBeenCalledWith({
        where: { id: { in: ['tp-1', 'tp-2'] } },
        include: { assessment: { select: { score: true } } },
      });
      expect(tx.trainingParticipant.updateMany.mock.calls).toEqual([
        [{
          where: { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor' },
          data: { assignedConsultantId: null, status: 'PENDENTE' },
        }],
        [{
          where: { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor' },
          data: { assignedConsultantId: null, status: 'NAO_RECOMENDADO' },
        }],
      ]);
    });

    it('nota zero é avaliação anterior: o participante volta a Não recomendado, não a Pendente', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: { score: 0 } },
      ]);

      const result = await service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor');

      expect(result).toEqual({ unassigned: 1 });
      expect(tx.trainingParticipant.updateMany).toHaveBeenCalledWith({
        where: { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor' },
        data: { assignedConsultantId: null, status: 'NAO_RECOMENDADO' },
      });
    });

    it('ADMIN libera participante que está com outro consultor, sem precisar de perfil de consultor', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'outro-consultor', assessment: null },
        { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'mais-um', assessment: { score: 90 } },
      ]);

      // Sem `consultantId` no token: só o papel. Se o serviço fosse procurar o
      // perfil de consultor do usuário, o mock (que não tem `user`) estouraria.
      const result = await service.unassignParticipants(
        { participantIds: ['tp-1', 'tp-2'] },
        undefined,
        'user-admin',
        'ADMIN',
      );

      expect(result).toEqual({ unassigned: 2 });
      expect(tx.trainingParticipant.updateMany.mock.calls).toEqual([
        [{
          where: { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'outro-consultor' },
          data: { assignedConsultantId: null, status: 'PENDENTE' },
        }],
        [{
          where: { id: 'tp-2', status: 'EM_AVALIACAO', assignedConsultantId: 'mais-um' },
          data: { assignedConsultantId: null, status: 'APROVADO' },
        }],
      ]);
    });

    it('ADMIN: quem não está em avaliação não tem o que liberar', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'PENDENTE', assignedConsultantId: null, assessment: null },
      ]);

      await expect(
        service.unassignParticipants({ participantIds: ['tp-1'] }, undefined, 'user-admin', 'ADMIN'),
      ).rejects.toThrow('Um ou mais participantes não estão em avaliação');
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    it('o papel de consultor não libera participante de outro consultor', async () => {
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([
        { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'outro-consultor', assessment: null },
      ]);

      await expect(
        service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor', 'user-1', 'CONSULTANT'),
      ).rejects.toThrow('Um ou mais participantes não estão atribuídos a você');
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    describe('corridas e pedidos repetidos (Fase 8D-1)', () => {
      it('o participante mudou ou sumiu no meio do caminho: 409, e não 500 '
        + '(a transação desfaz o que já liberou)', async () => {
        mockPrisma.trainingParticipant.findMany.mockResolvedValue([
          { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: null },
        ]);
        tx.trainingParticipant.updateMany.mockResolvedValue({ count: 0 });

        await expect(
          service.unassignParticipants({ participantIds: ['tp-1'] }, 'meu-consultor'),
        ).rejects.toThrow('Um ou mais participantes mudaram de situação. Atualize a lista e tente de novo.');
      });

      it('ids repetidos no pedido contam uma vez só, sem recusa enganosa', async () => {
        mockPrisma.trainingParticipant.findMany.mockResolvedValue([
          { id: 'tp-1', status: 'EM_AVALIACAO', assignedConsultantId: 'meu-consultor', assessment: null },
        ]);

        const result = await service.unassignParticipants(
          { participantIds: ['tp-1', 'tp-1'] },
          'meu-consultor',
        );

        expect(result).toEqual({ unassigned: 1 });
        expect(tx.trainingParticipant.updateMany).toHaveBeenCalledTimes(1);
      });
    });
  });

  // ─── syncFromMobile ──────────────────────────────────────────────────────

  describe('syncFromMobile', () => {
    const dto = {
      trainingParticipantId: 'tp-1',
      date: '2026-09-17',
      startTime: '2026-09-17T10:00:00.000Z',
      endTime: '2026-09-17T10:30:00.000Z',
      items: [],
    };

    beforeEach(() => {
      mockPrisma.assessmentCategory.findMany.mockResolvedValue([]);
      // A transação interativa roda com o próprio mock no papel do `tx`.
      mockPrisma.$transaction.mockImplementation((fn: (tx: unknown) => unknown) => fn(mockPrisma));
      // Quem envia está com o participante: é o caso de todo envio normal.
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
        status: 'EM_AVALIACAO',
        assignedConsultantId: 'consultant-1',
      });
    });

    it('sincroniza uma avaliação nova com sucesso', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);
      mockPrisma.practicalAssessment.create.mockResolvedValue({ id: 'assess-1', items: [] });

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result).toEqual([
        { trainingParticipantId: 'tp-1', status: 'fulfilled' },
      ]);
    });

    it('sincroniza também na reavaliação (registro existente)', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ id: 'assess-1' });
      mockPrisma.assessmentItem.deleteMany.mockResolvedValue({ count: 2 });
      mockPrisma.practicalAssessment.update.mockResolvedValue({ id: 'assess-1', items: [] });

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result[0]).toMatchObject({ status: 'fulfilled' });
    });

    describe('numa transação só (Fase 8D-1)', () => {
      /** O cliente da transação, separado do `mockPrisma`: o que for gravado
       * fora dela aparece no `mockPrisma`. */
      const tx = {
        practicalAssessment: { create: jest.fn(), update: jest.fn() },
        assessmentItem: { deleteMany: jest.fn() },
        assessmentCategory: { findMany: jest.fn() },
        trainingParticipant: { update: jest.fn() },
      };

      beforeEach(() => {
        Object.values(tx).forEach((model) =>
          Object.values(model).forEach((fn) => fn.mockReset()),
        );
        tx.assessmentCategory.findMany.mockResolvedValue([]);
        mockPrisma.$transaction.mockImplementation((fn: (t: unknown) => unknown) => fn(tx));
      });

      it('a reavaliação apaga os itens, regrava a avaliação e calcula a nota dentro dela', async () => {
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ id: 'assess-1' });
        tx.practicalAssessment.update.mockResolvedValue({ id: 'assess-1', items: [] });

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result[0]).toMatchObject({ status: 'fulfilled' });
        expect(tx.assessmentItem.deleteMany).toHaveBeenCalledWith({ where: { assessmentId: 'assess-1' } });
        expect(tx.practicalAssessment.update).toHaveBeenCalledWith(
          expect.objectContaining({ data: expect.objectContaining({ score: null }) }),
        );
        expect(tx.practicalAssessment.update).toHaveBeenCalledWith({
          where: { id: 'assess-1' },
          data: { score: 100 },
        });
        expect(tx.trainingParticipant.update).toHaveBeenCalledWith({
          where: { id: 'tp-1' },
          data: { status: 'APROVADO', assignedConsultantId: null },
        });
        expect(mockPrisma.assessmentItem.deleteMany).not.toHaveBeenCalled();
        expect(mockPrisma.practicalAssessment.update).not.toHaveBeenCalled();
        expect(mockPrisma.trainingParticipant.update).not.toHaveBeenCalled();
      });

      it('a primeira avaliação é criada e recebe a nota dentro dela', async () => {
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);
        tx.practicalAssessment.create.mockResolvedValue({ id: 'assess-1', items: [] });

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result[0]).toMatchObject({ status: 'fulfilled' });
        expect(tx.practicalAssessment.create).toHaveBeenCalled();
        expect(tx.trainingParticipant.update).toHaveBeenCalled();
        expect(mockPrisma.practicalAssessment.create).not.toHaveBeenCalled();
      });

      it('uma falha no meio recusa o item, e a nota não é gravada fora da transação', async () => {
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue({ id: 'assess-1' });
        tx.practicalAssessment.update.mockRejectedValue(new Error('falha no banco'));

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result).toEqual([
          { trainingParticipantId: 'tp-1', status: 'rejected', error: 'falha no banco' },
        ]);
        expect(tx.trainingParticipant.update).not.toHaveBeenCalled();
        expect(mockPrisma.trainingParticipant.update).not.toHaveBeenCalled();
      });
    });

    it('aceita o envio de quem está com o participante sem olhar o status da sessão: '
      + 'a avaliação de campo não se perde se a sessão foi concluída antes do envio (Fase 8D-1)', async () => {
      // O mock não tem `trainingSession`: se o envio lesse a sessão, quebraria.
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);
      mockPrisma.practicalAssessment.create.mockResolvedValue({ id: 'assess-1', items: [] });

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result).toEqual([{ trainingParticipantId: 'tp-1', status: 'fulfilled' }]);
    });

    it('devolve o erro para item rejeitado', async () => {
      mockPrisma.practicalAssessment.findUnique.mockRejectedValueOnce(new Error('falha no banco'));

      const result = await service.syncFromMobile([dto], 'consultant-1');

      expect(result).toEqual([
        { trainingParticipantId: 'tp-1', status: 'rejected', error: 'falha no banco' },
      ]);
    });

    // Só envia avaliação quem está com o participante (decisão 2 da Fase 6B do
    // app mobile): quem foi removido do treinamento, ou desatribuído pelo
    // ADMIN, não grava mais nada — nem por cima da avaliação de quem assumiu.
    describe('quem não está com o participante', () => {
      const refused = {
        trainingParticipantId: 'tp-1',
        status: 'rejected',
        error: 'Este participante não está mais em avaliação com você. A avaliação não foi registrada.',
        code: 'NOT_ASSIGNED',
      };

      it.each([
        ['foi liberado e voltou a Pendente', { status: 'PENDENTE', assignedConsultantId: null }],
        ['está em avaliação com outro consultor', { status: 'EM_AVALIACAO', assignedConsultantId: 'consultant-2' }],
        ['já foi avaliado por outro consultor', { status: 'APROVADO', assignedConsultantId: null }],
        ['está em avaliação sem consultor na linha', { status: 'EM_AVALIACAO', assignedConsultantId: null }],
        ['já tem nota, com o consultor ainda na linha', { status: 'APROVADO', assignedConsultantId: 'consultant-1' }],
      ])('%s: recusa com o código, sem gravar nada', async (_caso, participant) => {
        mockPrisma.trainingParticipant.findUnique.mockResolvedValue(participant);
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result).toEqual([refused]);
        expect(mockPrisma.practicalAssessment.create).not.toHaveBeenCalled();
        expect(mockPrisma.practicalAssessment.update).not.toHaveBeenCalled();
        expect(mockPrisma.assessmentItem.deleteMany).not.toHaveBeenCalled();
        expect(mockPrisma.$transaction).not.toHaveBeenCalled();
      });

      it('não sobrescreve a avaliação que outro consultor gravou depois', async () => {
        mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
          status: 'APROVADO',
          assignedConsultantId: null,
        });
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue({
          id: 'assess-1',
          consultantId: 'consultant-2',
          startTime: new Date('2026-09-17T10:00:00.000Z'),
        });

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result).toEqual([refused]);
        expect(mockPrisma.practicalAssessment.update).not.toHaveBeenCalled();
        expect(mockPrisma.assessmentItem.deleteMany).not.toHaveBeenCalled();
      });

      it('reenvio da mesma avaliação (a resposta do primeiro envio se perdeu): aceita sem regravar', async () => {
        // O primeiro envio foi aceito: o participante já tem a nota e ficou sem consultor.
        mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
          status: 'APROVADO',
          assignedConsultantId: null,
        });
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue({
          id: 'assess-1',
          consultantId: 'consultant-1',
          startTime: new Date('2026-09-17T10:00:00.000Z'),
        });

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result).toEqual([{ trainingParticipantId: 'tp-1', status: 'fulfilled' }]);
        expect(mockPrisma.practicalAssessment.update).not.toHaveBeenCalled();
        expect(mockPrisma.assessmentItem.deleteMany).not.toHaveBeenCalled();
        expect(mockPrisma.$transaction).not.toHaveBeenCalled();
      });

      it('avaliação antiga do mesmo consultor, com outra hora de início, não conta como reenvio', async () => {
        mockPrisma.trainingParticipant.findUnique.mockResolvedValue({
          status: 'NAO_RECOMENDADO',
          assignedConsultantId: null,
        });
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue({
          id: 'assess-1',
          consultantId: 'consultant-1',
          startTime: new Date('2026-09-10T08:00:00.000Z'),
        });

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result).toEqual([refused]);
        expect(mockPrisma.practicalAssessment.update).not.toHaveBeenCalled();
      });

      it('participante que não existe: recusa, sem o código', async () => {
        mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);
        mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);

        const result = await service.syncFromMobile([dto], 'consultant-1');

        expect(result).toEqual([
          { trainingParticipantId: 'tp-1', status: 'rejected', error: 'Participante não encontrado' },
        ]);
        expect(mockPrisma.practicalAssessment.create).not.toHaveBeenCalled();
      });
    });

    it('confere quem está com o participante pela linha dele', async () => {
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);
      mockPrisma.practicalAssessment.create.mockResolvedValue({ id: 'assess-1', items: [] });

      await service.syncFromMobile([dto], 'consultant-1');

      expect(mockPrisma.trainingParticipant.findUnique).toHaveBeenCalledWith({
        where: { id: 'tp-1' },
        select: { status: true, assignedConsultantId: true },
      });
    });

    it('num lote, recusa só a avaliação de quem não está com o participante', async () => {
      const outro = { ...dto, trainingParticipantId: 'tp-2' };
      mockPrisma.trainingParticipant.findUnique.mockImplementation(
        ({ where }: { where: { id: string } }) =>
          Promise.resolve(
            where.id === 'tp-1'
              ? { status: 'EM_AVALIACAO', assignedConsultantId: 'consultant-1' }
              : { status: 'PENDENTE', assignedConsultantId: null },
          ),
      );
      mockPrisma.practicalAssessment.findUnique.mockResolvedValue(null);
      mockPrisma.practicalAssessment.create.mockResolvedValue({ id: 'assess-1', items: [] });

      const result = await service.syncFromMobile([dto, outro], 'consultant-1');

      expect(result).toEqual([
        { trainingParticipantId: 'tp-1', status: 'fulfilled' },
        expect.objectContaining({
          trainingParticipantId: 'tp-2',
          status: 'rejected',
          code: 'NOT_ASSIGNED',
        }),
      ]);
      expect(mockPrisma.practicalAssessment.create).toHaveBeenCalledTimes(1);
    });
  });
});

describe('PracticalAssessmentsService.findOne (Fase 8D-1)', () => {
  it('uma avaliação que não existe é 404, e não 500', async () => {
    const prisma = { practicalAssessment: { findUnique: jest.fn().mockResolvedValue(null) } };
    const service = new PracticalAssessmentsService(prisma as unknown as PrismaService);

    await expect(service.findOne('nao-existe')).rejects.toThrow(NotFoundException);
  });
});

describe('PracticalAssessmentsController: quem lê uma avaliação (Fase 8D-1)', () => {
  // As duas leituras devolvem notas e infrações: só ADMIN e CONSULTANT. O
  // `JwtAuthGuard` está na classe; o `RolesGuard`, que lê o papel, nos métodos.
  const reflector = new Reflector();

  it.each([
    ['findByParticipant', PracticalAssessmentsController.prototype.findByParticipant],
    ['findOne', PracticalAssessmentsController.prototype.findOne],
  ])('%s exige ADMIN ou CONSULTANT, pelo RolesGuard', (_name, handler) => {
    expect(reflector.get<UserRole[]>(ROLES_KEY, handler)).toEqual([
      UserRole.ADMIN,
      UserRole.CONSULTANT,
    ]);
    expect(reflector.get(GUARDS_METADATA, handler)).toEqual([RolesGuard]);
  });

  it('a classe continua exigindo o login', () => {
    expect(reflector.get(GUARDS_METADATA, PracticalAssessmentsController)).toEqual([JwtAuthGuard]);
  });
});

describe('PracticalAssessmentsController.unassign', () => {
  it('passa o papel de quem pediu: é ele que deixa o ADMIN liberar participante de outro consultor', () => {
    const service = { unassignParticipants: jest.fn().mockReturnValue('ok') };
    const controller = new PracticalAssessmentsController(
      service as unknown as PracticalAssessmentsService,
    );
    const dto = { participantIds: ['tp-1'] };
    const admin = { sub: 'user-admin', email: 'admin@sim.com', role: 'ADMIN' } as JwtPayload;

    expect(controller.unassign(dto, admin)).toBe('ok');
    expect(service.unassignParticipants).toHaveBeenCalledWith(dto, undefined, 'user-admin', 'ADMIN');
  });
});
