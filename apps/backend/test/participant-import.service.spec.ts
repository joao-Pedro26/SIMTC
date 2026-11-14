import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { ImportParticipantsDto, ParticipantImportRowDto, ParticipationType } from '@simtc/shared-types';
import { ParticipantImportService } from 'src/participants/import/participant-import.service';
import { buildParticipantUpdateData } from 'src/participants/participant-data.util';
import { PrismaService } from 'src/prisma/prisma.service';

const tx = {
  participant: { create: jest.fn(), update: jest.fn() },
  trainingParticipant: { create: jest.fn() },
};

const mockPrisma = {
  trainingSession: { findUnique: jest.fn() },
  participant: { findMany: jest.fn(), findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
  trainingParticipant: { findMany: jest.fn(), findUnique: jest.fn(), create: jest.fn() },
  $transaction: jest.fn(),
};

// CPFs válidos (dígitos verificadores conferem).
const CPF_ANA = '52998224725';
const CPF_BRUNO = '11144477735';
const CPF_CARLA = '12345678909';
const CPF_DIEGO = '98765432100';
const CPF_ELISA = '39053344705';

const SESSION_ID = 'sess-1';
const HEADER = 'Nome,CPF,E-mail,Categoria CNH,Validade CNH,Tipo';

function csv(...lines: string[]): Buffer {
  return Buffer.from([HEADER, ...lines].join('\n'), 'utf-8');
}

function stored(overrides: Record<string, unknown>) {
  return { email: null, cnhCategory: null, cnhExpiration: null, ...overrides };
}

function row(rowNumber: number, overrides: Partial<ParticipantImportRowDto> = {}): ParticipantImportRowDto {
  return { rowNumber, name: 'Ana Nova', cpf: CPF_ANA, cnhCategory: 'B', cnhExpiration: '2027-12-31', ...overrides };
}

function body(...rows: ParticipantImportRowDto[]): ImportParticipantsDto {
  return { defaultParticipationType: ParticipationType.TEORICA_E_PRATICA, rows };
}

function uniqueViolation(target: string[]): Prisma.PrismaClientKnownRequestError {
  return new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
    code: 'P2002',
    clientVersion: 'test',
    meta: { target },
  });
}

function expectNoWrites() {
  expect(mockPrisma.$transaction).not.toHaveBeenCalled();
  for (const client of [mockPrisma, tx]) {
    expect(client.participant.create).not.toHaveBeenCalled();
    expect(client.participant.update).not.toHaveBeenCalled();
    expect(client.trainingParticipant.create).not.toHaveBeenCalled();
  }
}

describe('ParticipantImportService', () => {
  let service: ParticipantImportService;
  let consoleError: jest.SpyInstance;

  beforeEach(() => {
    jest.resetAllMocks();
    service = new ParticipantImportService(mockPrisma as unknown as PrismaService);

    mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: SESSION_ID, status: 'PLANEJADO' });
    mockPrisma.participant.findMany.mockResolvedValue([]);
    mockPrisma.trainingParticipant.findMany.mockResolvedValue([]);
    mockPrisma.$transaction.mockImplementation((fn: (t: typeof tx) => unknown) => fn(tx));
    let created = 0;
    tx.participant.create.mockImplementation(async () => ({ id: `new-${++created}` }));
    tx.participant.update.mockResolvedValue({});
    tx.trainingParticipant.create.mockResolvedValue({});
    consoleError = jest.spyOn(console, 'error').mockImplementation(() => undefined);
  });

  afterEach(() => {
    consoleError.mockRestore();
  });

  describe('preview', () => {
    it('sessão inexistente → 404', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(null);

      await expect(service.preview('sess-x', csv(), 'lista.csv')).rejects.toThrow(NotFoundException);
      expect(mockPrisma.participant.findMany).not.toHaveBeenCalled();
    });

    it.each(['CANCELADO', 'CONCLUIDO'])('sessão %s → 400 de inscrições encerradas', async (status) => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: SESSION_ID, status });

      await expect(service.preview(SESSION_ID, csv(), 'lista.csv')).rejects.toThrow(
        new BadRequestException('Inscrições encerradas para este treinamento'),
      );
      expect(mockPrisma.participant.findMany).not.toHaveBeenCalled();
    });

    it('classifica os 5 status com duas queries, sem gravar nada', async () => {
      mockPrisma.participant.findMany.mockResolvedValue([
        stored({ id: 'p-bruno', cpf: CPF_BRUNO, name: 'Bruno Antigo' }),
        stored({ id: 'p-carla', cpf: CPF_CARLA, name: 'Carla Inscrita' }),
      ]);
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([{ participantId: 'p-carla' }]);

      const file = csv(
        'Ana Nova,529.982.247-25,ana@empresa.com,B,31/12/2027,teorica',
        `Bruno Cadastrado,${CPF_BRUNO},,AB,31/12/2027,`,
        `Carla Inscrita,${CPF_CARLA},,B,31/12/2027,`,
        `Ana Repetida,${CPF_ANA},,B,31/12/2027,`,
        `Elisa Sem Cnh,${CPF_ELISA},,,31/12/2027,`,
        `Diego Novo,${CPF_DIEGO},,C,31/12/2027,`,
      );

      const result = await service.preview(SESSION_ID, file, 'lista.csv');

      expect(result.sheetName).toBeNull();
      expect(result.headerRow).toBe(1);
      expect(result.rows.map((r) => [r.rowNumber, r.status])).toEqual([
        [2, 'NOVO'],
        [3, 'ATUALIZA_E_INSCREVE'],
        [4, 'JA_INSCRITO'],
        [5, 'DUPLICADO_NA_PLANILHA'],
        [6, 'ERRO'],
        [7, 'NOVO'],
      ]);
      expect(result.rows[0]).toEqual({
        rowNumber: 2,
        name: 'Ana Nova',
        cpf: CPF_ANA,
        email: 'ana@empresa.com',
        cnhCategory: 'B',
        cnhExpiration: '2027-12-31',
        participationType: ParticipationType.SOMENTE_TEORICA,
        status: 'NOVO',
        errors: [],
        warnings: [],
      });
      expect(result.rows[4].errors).toEqual(['Categoria CNH obrigatória']);
      expect(result.totals).toEqual({
        total: 6,
        novo: 2,
        atualizaEInscreve: 1,
        jaInscrito: 1,
        duplicado: 1,
        erro: 1,
      });

      // Sem N+1: uma busca de cadastros e uma de inscrições para o arquivo todo.
      expect(mockPrisma.participant.findMany).toHaveBeenCalledTimes(1);
      expect(mockPrisma.participant.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { cpf: { in: [CPF_ANA, CPF_BRUNO, CPF_CARLA, CPF_DIEGO] } } }),
      );
      expect(mockPrisma.trainingParticipant.findMany).toHaveBeenCalledTimes(1);
      expect(mockPrisma.trainingParticipant.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { trainingSessionId: SESSION_ID, participantId: { in: ['p-bruno', 'p-carla'] } },
        }),
      );
      expect(mockPrisma.participant.findUnique).not.toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.findUnique).not.toHaveBeenCalled();
      expectNoWrites();
    });

    it('duplicado: vale a primeira ocorrência, mesmo com máscara diferente', async () => {
      const result = await service.preview(
        SESSION_ID,
        csv(`Ana Nova,${CPF_ANA},,B,31/12/2027,`, 'Ana De Novo,529.982.247-25,,B,31/12/2027,'),
        'lista.csv',
      );

      expect(result.rows.map((r) => r.status)).toEqual(['NOVO', 'DUPLICADO_NA_PLANILHA']);
    });

    it('linha com ERRO não reserva o CPF para as seguintes', async () => {
      const result = await service.preview(
        SESSION_ID,
        csv(
          `Ana Sem Cnh,${CPF_ANA},,,31/12/2027,`,
          `Ana Nova,${CPF_ANA},,B,31/12/2027,`,
          `Ana De Novo,${CPF_ANA},,B,31/12/2027,`,
        ),
        'lista.csv',
      );

      expect(result.rows.map((r) => r.status)).toEqual(['ERRO', 'NOVO', 'DUPLICADO_NA_PLANILHA']);
    });

    it('ERRO vem antes de JA_INSCRITO: CPF inscrito em linha inválida é erro', async () => {
      mockPrisma.participant.findMany.mockResolvedValue([stored({ id: 'p-carla', cpf: CPF_CARLA, name: 'Carla' })]);
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([{ participantId: 'p-carla' }]);

      const result = await service.preview(
        SESSION_ID,
        csv(`Carla,${CPF_CARLA},x@,B,31/12/2027,`, `Carla,${CPF_CARLA},,B,31/12/2027,`),
        'lista.csv',
      );

      expect(result.rows.map((r) => r.status)).toEqual(['ERRO', 'JA_INSCRITO']);
      expect(result.rows[0].errors).toEqual(['E-mail inválido']);
    });

    it('linha sem validade da CNH é ERRO', async () => {
      const result = await service.preview(SESSION_ID, csv(`Ana Nova,${CPF_ANA},,B,,`), 'lista.csv');

      expect(result.rows[0].status).toBe('ERRO');
      expect(result.rows[0].errors).toEqual(['Validade da CNH obrigatória']);
    });

    it('arquivo só com linhas inválidas não consulta cadastros', async () => {
      const result = await service.preview(SESSION_ID, csv('Sem Cpf,,,B,31/12/2027,'), 'lista.csv');

      expect(result.rows.map((r) => r.status)).toEqual(['ERRO']);
      expect(mockPrisma.participant.findMany).not.toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.findMany).not.toHaveBeenCalled();
    });

    describe('changes em ATUALIZA_E_INSCREVE', () => {
      const existing = stored({
        id: 'p-bruno',
        cpf: CPF_BRUNO,
        name: 'Bruno Antigo',
        email: 'bruno@antigo.com',
        cnhCategory: 'B',
        cnhExpiration: new Date('2026-01-31'),
      });

      beforeEach(() => {
        mockPrisma.participant.findMany.mockResolvedValue([existing]);
      });

      it('nome e CNH diferentes viram change; e-mail vazio na planilha não', async () => {
        const result = await service.preview(
          SESSION_ID,
          csv(`Bruno Novo,${CPF_BRUNO},,AB,31/01/2026,`),
          'lista.csv',
        );

        expect(result.rows[0].status).toBe('ATUALIZA_E_INSCREVE');
        expect(result.rows[0].changes).toEqual([
          { field: 'name', from: 'Bruno Antigo', to: 'Bruno Novo' },
          { field: 'cnhCategory', from: 'B', to: 'AB' },
        ]);
      });

      it('e-mail e validade preenchidos e diferentes viram change', async () => {
        const result = await service.preview(
          SESSION_ID,
          csv(`Bruno Antigo,${CPF_BRUNO},bruno@novo.com,B,31/12/2027,`),
          'lista.csv',
        );

        expect(result.rows[0].changes).toEqual([
          { field: 'email', from: 'bruno@antigo.com', to: 'bruno@novo.com' },
          { field: 'cnhExpiration', from: '2026-01-31', to: '2027-12-31' },
        ]);
      });

      it('campo vazio no cadastro aparece como from: null', async () => {
        mockPrisma.participant.findMany.mockResolvedValue([
          stored({ id: 'p-bruno', cpf: CPF_BRUNO, name: 'Bruno Antigo' }),
        ]);

        const result = await service.preview(
          SESSION_ID,
          csv(`Bruno Antigo,${CPF_BRUNO},bruno@novo.com,B,31/12/2027,`),
          'lista.csv',
        );

        expect(result.rows[0].changes).toEqual([
          { field: 'email', from: null, to: 'bruno@novo.com' },
          { field: 'cnhCategory', from: null, to: 'B' },
          { field: 'cnhExpiration', from: null, to: '2027-12-31' },
        ]);
      });

      it('valores iguais → changes vazio', async () => {
        const result = await service.preview(
          SESSION_ID,
          csv(`Bruno Antigo,${CPF_BRUNO},bruno@antigo.com,B,31/01/2026,`),
          'lista.csv',
        );

        expect(result.rows[0].status).toBe('ATUALIZA_E_INSCREVE');
        expect(result.rows[0].changes).toEqual([]);
      });

      it('validade igual à do cadastro não gera change; diferente gera', async () => {
        const same = await service.preview(
          SESSION_ID,
          csv(`Bruno Antigo,${CPF_BRUNO},,B,31/01/2026,`),
          'lista.csv',
        );
        expect(same.rows[0].changes).toEqual([]);

        const other = await service.preview(
          SESSION_ID,
          csv(`Bruno Antigo,${CPF_BRUNO},,B,28/02/2026,`),
          'lista.csv',
        );
        expect(other.rows[0].changes).toEqual([
          { field: 'cnhExpiration', from: '2026-01-31', to: '2026-02-28' },
        ]);
      });

      it('só ATUALIZA_E_INSCREVE tem changes', async () => {
        const result = await service.preview(SESSION_ID, csv(`Ana Nova,${CPF_ANA},,B,31/12/2027,`), 'lista.csv');

        expect(result.rows[0].status).toBe('NOVO');
        expect(result.rows[0]).not.toHaveProperty('changes');
      });
    });
  });

  describe('commit', () => {
    it('sessão inexistente → 404', async () => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue(null);

      await expect(service.commit('sess-x', body(row(2)))).rejects.toThrow(NotFoundException);
      expectNoWrites();
    });

    it.each(['CANCELADO', 'CONCLUIDO'])('sessão %s → 400 de inscrições encerradas', async (status) => {
      mockPrisma.trainingSession.findUnique.mockResolvedValue({ id: SESSION_ID, status });

      await expect(service.commit(SESSION_ID, body(row(2)))).rejects.toThrow(
        new BadRequestException('Inscrições encerradas para este treinamento'),
      );
      expectNoWrites();
    });

    it.each([
      ['CPF inválido', { cpf: '11111111111' }, 'CPF inválido'],
      ['CNH fora da lista', { cnhCategory: 'F' }, 'Categoria CNH inválida (use: A, B, C, D, E, AB, AC, AD, AE)'],
      ['CNH ausente', { cnhCategory: undefined }, 'Categoria CNH obrigatória'],
      ['e-mail inválido', { email: 'x@' }, 'E-mail inválido'],
      ['validade ausente', { cnhExpiration: undefined }, 'Validade da CNH obrigatória'],
      ['validade ilegível', { cnhExpiration: 'amanha' }, 'Validade da CNH ilegível (use dd/mm/aaaa)'],
    ])('revalida a linha do JSON: %s vai para skipped, sem gravar', async (_label, overrides, reason) => {
      const result = await service.commit(SESSION_ID, body(row(2, overrides)));

      expect(result).toEqual({
        created: 0,
        updatedAndEnrolled: 0,
        skipped: [{ rowNumber: 2, cpf: expect.any(String), reason }],
        failed: [],
      });
      expectNoWrites();
    });

    it('linha com vários erros lista todos no motivo', async () => {
      const result = await service.commit(
        SESSION_ID,
        body(row(2, { name: ' ', cnhCategory: 'F', cnhExpiration: undefined })),
      );

      expect(result.skipped[0].reason).toBe(
        'Nome obrigatório · Categoria CNH inválida (use: A, B, C, D, E, AB, AC, AD, AE) · Validade da CNH obrigatória',
      );
    });

    it('reclassifica: CPF tratado como novo no JSON mas já inscrito no banco → skipped', async () => {
      mockPrisma.participant.findMany.mockResolvedValue([stored({ id: 'p-ana', cpf: CPF_ANA, name: 'Ana' })]);
      mockPrisma.trainingParticipant.findMany.mockResolvedValue([{ participantId: 'p-ana' }]);

      const result = await service.commit(SESSION_ID, body(row(2)));

      expect(result).toEqual({
        created: 0,
        updatedAndEnrolled: 0,
        skipped: [{ rowNumber: 2, cpf: CPF_ANA, reason: 'CPF já inscrito neste treinamento' }],
        failed: [],
      });
      expectNoWrites();
    });

    it('CPF repetido no JSON: a segunda vai para skipped', async () => {
      const result = await service.commit(
        SESSION_ID,
        body(row(2), row(3, { name: 'Ana De Novo', cpf: '529.982.247-25' })),
      );

      expect(result.created).toBe(1);
      expect(result.skipped).toEqual([{ rowNumber: 3, cpf: CPF_ANA, reason: 'CPF repetido na planilha' }]);
      expect(tx.participant.create).toHaveBeenCalledTimes(1);
    });

    it('classifica o lote com duas queries, sem consulta por linha', async () => {
      mockPrisma.participant.findMany.mockResolvedValue([stored({ id: 'p-bruno', cpf: CPF_BRUNO, name: 'Bruno' })]);

      await service.commit(
        SESSION_ID,
        body(row(2), row(3, { cpf: CPF_BRUNO }), row(4, { cpf: CPF_DIEGO })),
      );

      expect(mockPrisma.participant.findMany).toHaveBeenCalledTimes(1);
      expect(mockPrisma.trainingParticipant.findMany).toHaveBeenCalledTimes(1);
      expect(mockPrisma.participant.findUnique).not.toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.findUnique).not.toHaveBeenCalled();
    });

    it('NOVO: cria cadastro e inscrição na mesma transação', async () => {
      const result = await service.commit(
        SESSION_ID,
        body(
          row(2, {
            email: 'ana@empresa.com',
            cnhExpiration: '2027-12-31',
            participationType: ParticipationType.SOMENTE_TEORICA,
          }),
        ),
      );

      expect(result).toEqual({ created: 1, updatedAndEnrolled: 0, skipped: [], failed: [] });
      expect(mockPrisma.$transaction).toHaveBeenCalledTimes(1);
      expect(tx.participant.create).toHaveBeenCalledWith({
        data: {
          name: 'Ana Nova',
          cpf: CPF_ANA,
          email: 'ana@empresa.com',
          cnhCategory: 'B',
          cnhExpiration: new Date('2027-12-31'),
        },
      });
      expect(tx.trainingParticipant.create).toHaveBeenCalledWith({
        data: {
          trainingSessionId: SESSION_ID,
          participantId: 'new-1',
          participationType: ParticipationType.SOMENTE_TEORICA,
        },
      });
      // As gravações passam pelo `tx`, nunca pelo cliente fora da transação.
      expect(mockPrisma.participant.create).not.toHaveBeenCalled();
      expect(mockPrisma.trainingParticipant.create).not.toHaveBeenCalled();
    });

    it('ATUALIZA_E_INSCREVE: update com exatamente a regra compartilhada', async () => {
      mockPrisma.participant.findMany.mockResolvedValue([
        stored({ id: 'p-bruno', cpf: CPF_BRUNO, name: 'Bruno Antigo', email: 'bruno@antigo.com' }),
      ]);

      const result = await service.commit(
        SESSION_ID,
        body(row(2, { name: 'Bruno Novo', cpf: CPF_BRUNO, cnhCategory: 'AB' })),
      );

      expect(result).toEqual({ created: 0, updatedAndEnrolled: 1, skipped: [], failed: [] });
      expect(mockPrisma.$transaction).toHaveBeenCalledTimes(1);
      const expectedData = buildParticipantUpdateData({
        name: 'Bruno Novo',
        cnhCategory: 'AB',
        cnhExpiration: '2027-12-31',
      });
      expect(expectedData.email).toBeUndefined();
      expect(tx.participant.update).toHaveBeenCalledWith({ where: { id: 'p-bruno' }, data: expectedData });
      expect(tx.participant.create).not.toHaveBeenCalled();
      expect(tx.trainingParticipant.create).toHaveBeenCalledWith({
        data: {
          trainingSessionId: SESSION_ID,
          participantId: 'p-bruno',
          participationType: ParticipationType.TEORICA_E_PRATICA,
        },
      });
    });

    it('participationType ausente na linha → usa o tipo padrão do lote', async () => {
      await service.commit(SESSION_ID, {
        defaultParticipationType: ParticipationType.SOMENTE_TEORICA,
        rows: [row(2)],
      });

      expect(tx.trainingParticipant.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ participationType: ParticipationType.SOMENTE_TEORICA }),
      });
    });

    it('cada linha tem a própria transação: erro na 2ª não derruba a 1ª nem a 3ª', async () => {
      const boom = new Error('conexão caiu');
      tx.trainingParticipant.create
        .mockResolvedValueOnce({})
        .mockRejectedValueOnce(boom)
        .mockResolvedValueOnce({});

      const result = await service.commit(
        SESSION_ID,
        body(row(2), row(3, { cpf: CPF_BRUNO }), row(4, { cpf: CPF_DIEGO })),
      );

      expect(result).toEqual({
        created: 2,
        updatedAndEnrolled: 0,
        skipped: [],
        failed: [{ rowNumber: 3, cpf: CPF_BRUNO, reason: 'Erro ao gravar a linha' }],
      });
      expect(mockPrisma.$transaction).toHaveBeenCalledTimes(3);
      expect(consoleError).toHaveBeenCalledWith(expect.any(String), boom);
    });

    it('P2002 na inscrição (corrida com o QR Code) → skipped como já inscrito, não failed', async () => {
      mockPrisma.participant.findMany.mockResolvedValue([stored({ id: 'p-bruno', cpf: CPF_BRUNO, name: 'Bruno' })]);
      tx.trainingParticipant.create.mockRejectedValue(uniqueViolation(['trainingSessionId', 'participantId']));
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'p-bruno' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue({ id: 'tp-1' });

      const result = await service.commit(SESSION_ID, body(row(2, { cpf: CPF_BRUNO })));

      expect(result).toEqual({
        created: 0,
        updatedAndEnrolled: 0,
        skipped: [{ rowNumber: 2, cpf: CPF_BRUNO, reason: 'CPF já inscrito neste treinamento' }],
        failed: [],
      });
      expect(mockPrisma.participant.findUnique).toHaveBeenCalledWith(
        expect.objectContaining({ where: { cpf: CPF_BRUNO } }),
      );
      expect(mockPrisma.$transaction).toHaveBeenCalledTimes(1);
    });

    it('P2002 no CPF do cadastro (criado no meio do caminho) → repete uma vez pelo update', async () => {
      tx.participant.create.mockRejectedValue(uniqueViolation(['cpf']));
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'p-ana' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);

      const result = await service.commit(SESSION_ID, body(row(2, { name: 'Ana Atual' })));

      expect(result).toEqual({ created: 0, updatedAndEnrolled: 1, skipped: [], failed: [] });
      expect(mockPrisma.$transaction).toHaveBeenCalledTimes(2);
      expect(tx.participant.update).toHaveBeenCalledWith({
        where: { id: 'p-ana' },
        data: buildParticipantUpdateData({
          name: 'Ana Atual',
          cnhCategory: 'B',
          cnhExpiration: '2027-12-31',
        }),
      });
      expect(tx.trainingParticipant.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ participantId: 'p-ana' }),
      });
    });

    it('nova falha na repetição → failed, sem terceira tentativa', async () => {
      tx.participant.create.mockRejectedValue(uniqueViolation(['cpf']));
      mockPrisma.participant.findUnique.mockResolvedValue({ id: 'p-ana' });
      mockPrisma.trainingParticipant.findUnique.mockResolvedValue(null);
      tx.trainingParticipant.create.mockRejectedValue(uniqueViolation(['trainingSessionId', 'participantId']));

      const result = await service.commit(SESSION_ID, body(row(2)));

      expect(result).toEqual({
        created: 0,
        updatedAndEnrolled: 0,
        skipped: [],
        failed: [{ rowNumber: 2, cpf: CPF_ANA, reason: 'Erro ao gravar a linha' }],
      });
      expect(mockPrisma.$transaction).toHaveBeenCalledTimes(2);
    });

    it('P2002 sem inscrição nem cadastro para explicar → failed', async () => {
      tx.participant.create.mockRejectedValue(uniqueViolation(['cpf']));
      mockPrisma.participant.findUnique.mockResolvedValue(null);

      const result = await service.commit(SESSION_ID, body(row(2)));

      expect(result.failed).toEqual([{ rowNumber: 2, cpf: CPF_ANA, reason: 'Erro ao gravar a linha' }]);
      expect(mockPrisma.$transaction).toHaveBeenCalledTimes(1);
    });
  });
});
