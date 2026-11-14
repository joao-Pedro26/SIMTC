import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  ImportParticipantsDto,
  ParticipantImportChange,
  ParticipantImportPreviewResponse,
  ParticipantImportPreviewRow,
  ParticipantImportResult,
  ParticipantImportRowStatus,
  ParticipantImportTotals,
  ParticipationType,
} from '@simtc/shared-types';
import { PrismaService } from '../../prisma/prisma.service';
import { buildParticipantUpdateData } from '../participant-data.util';
import { ParsedRow, parseParticipantSheet, validateImportRow } from './participant-import.parser';

const ALREADY_ENROLLED = 'CPF já inscrito neste treinamento';
const DUPLICATED_IN_SHEET = 'CPF repetido na planilha';
const WRITE_FAILED = 'Erro ao gravar a linha';

/** Campos do cadastro usados para classificar a linha e mostrar o que muda. */
const EXISTING_PARTICIPANT_SELECT = {
  id: true,
  cpf: true,
  name: true,
  email: true,
  cnhCategory: true,
  cnhExpiration: true,
} satisfies Prisma.ParticipantSelect;

type ExistingParticipant = Prisma.ParticipantGetPayload<{ select: typeof EXISTING_PARTICIPANT_SELECT }>;

interface ClassifiedRow {
  row: ParsedRow;
  status: ParticipantImportRowStatus;
  /** Cadastro já existente; só em `ATUALIZA_E_INSCREVE`. */
  existing?: ExistingParticipant;
}

type WriteOutcome = 'created' | 'updated' | 'alreadyEnrolled' | 'failed';

/** Curso com horas práticas → teoria + prática; só teórico → somente teórica. */
function participationTypeForCourse(practiceHours: number): ParticipationType {
  return practiceHours > 0 ? ParticipationType.TEORICA_E_PRATICA : ParticipationType.SOMENTE_TEORICA;
}

function isUniqueViolation(err: unknown): boolean {
  return err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';
}

/**
 * Importação de participantes por planilha: `preview` lê e classifica sem
 * gravar; `commit` revalida e reclassifica o que o cliente devolveu (a prévia
 * não é confiável) e grava cada linha numa transação própria.
 */
@Injectable()
export class ParticipantImportService {
  constructor(private readonly prisma: PrismaService) {}

  async preview(
    sessionId: string,
    buffer: Buffer,
    filename: string,
  ): Promise<ParticipantImportPreviewResponse> {
    const participationType = await this.assertSessionOpen(sessionId);

    const sheet = await parseParticipantSheet(buffer, filename);
    const classified = await this.classifyRows(sessionId, sheet.rows);

    const rows = classified.map(({ row, status, existing }): ParticipantImportPreviewRow =>
      existing ? { ...row, status, changes: this.listChanges(existing, row) } : { ...row, status },
    );
    const count = (status: ParticipantImportRowStatus) => rows.filter((r) => r.status === status).length;
    const totals: ParticipantImportTotals = {
      total: rows.length,
      novo: count('NOVO'),
      atualizaEInscreve: count('ATUALIZA_E_INSCREVE'),
      jaInscrito: count('JA_INSCRITO'),
      duplicado: count('DUPLICADO_NA_PLANILHA'),
      erro: count('ERRO'),
    };

    return {
      participationType,
      sheetName: sheet.sheetName,
      headerRow: sheet.headerRow,
      ignoredColumns: sheet.ignoredColumns,
      rows,
      totals,
    };
  }

  async commit(sessionId: string, dto: ImportParticipantsDto): Promise<ParticipantImportResult> {
    const participationType = await this.assertSessionOpen(sessionId);

    const classified = await this.classifyRows(sessionId, dto.rows.map(validateImportRow));

    const result: ParticipantImportResult = { created: 0, updatedAndEnrolled: 0, skipped: [], failed: [] };
    for (const { row, status, existing } of classified) {
      const entry = (reason: string) => ({ rowNumber: row.rowNumber, cpf: row.cpf, reason });

      if (status === 'ERRO') {
        result.skipped.push(entry(row.errors.join(' · ')));
      } else if (status === 'DUPLICADO_NA_PLANILHA') {
        result.skipped.push(entry(DUPLICATED_IN_SHEET));
      } else if (status === 'JA_INSCRITO') {
        result.skipped.push(entry(ALREADY_ENROLLED));
      } else {
        const outcome = await this.writeRow(sessionId, row, existing?.id ?? null, participationType);
        if (outcome === 'created') result.created++;
        else if (outcome === 'updated') result.updatedAndEnrolled++;
        else if (outcome === 'alreadyEnrolled') result.skipped.push(entry(ALREADY_ENROLLED));
        else result.failed.push(entry(WRITE_FAILED));
      }
    }
    return result;
  }

  /**
   * Mesma recusa do `addParticipant`: sessão inexistente, cancelada ou concluída.
   * Devolve o tipo de participação de todas as linhas, derivado do curso (mesma query).
   */
  private async assertSessionOpen(sessionId: string): Promise<ParticipationType> {
    const session = await this.prisma.trainingSession.findUnique({
      where: { id: sessionId },
      select: { status: true, course: { select: { practiceHours: true } } },
    });
    if (!session) throw new NotFoundException('Sessão de treinamento não encontrada');
    if (session.status === 'CANCELADO' || session.status === 'CONCLUIDO') {
      throw new BadRequestException('Inscrições encerradas para este treinamento');
    }
    return participationTypeForCourse(session.course.practiceHours);
  }

  /**
   * Classifica o lote inteiro com duas queries (cadastros pelos CPFs e, deles,
   * quem já está nesta sessão). Precedência por linha: `ERRO` →
   * `DUPLICADO_NA_PLANILHA` → `JA_INSCRITO` → `ATUALIZA_E_INSCREVE` → `NOVO`.
   * Linha com erro não reserva o CPF: a primeira ocorrência válida é a que vale.
   */
  private async classifyRows(sessionId: string, rows: ParsedRow[]): Promise<ClassifiedRow[]> {
    const cpfs = [...new Set(rows.filter((row) => row.errors.length === 0).map((row) => row.cpf))];

    const participants = cpfs.length
      ? await this.prisma.participant.findMany({
          where: { cpf: { in: cpfs } },
          select: EXISTING_PARTICIPANT_SELECT,
        })
      : [];
    const enrollments = participants.length
      ? await this.prisma.trainingParticipant.findMany({
          where: { trainingSessionId: sessionId, participantId: { in: participants.map((p) => p.id) } },
          select: { participantId: true },
        })
      : [];

    const byCpf = new Map(participants.map((p) => [p.cpf, p]));
    const enrolledIds = new Set(enrollments.map((e) => e.participantId));
    const seenCpfs = new Set<string>();

    return rows.map((row): ClassifiedRow => {
      if (row.errors.length > 0) return { row, status: 'ERRO' };
      if (seenCpfs.has(row.cpf)) return { row, status: 'DUPLICADO_NA_PLANILHA' };
      seenCpfs.add(row.cpf);

      const existing = byCpf.get(row.cpf);
      if (!existing) return { row, status: 'NOVO' };
      if (enrolledIds.has(existing.id)) return { row, status: 'JA_INSCRITO' };
      return { row, status: 'ATUALIZA_E_INSCREVE', existing };
    });
  }

  /** O que o update vai mudar no cadastro: só campos que a regra compartilhada sobrescreve. */
  private listChanges(existing: ExistingParticipant, row: ParsedRow): ParticipantImportChange[] {
    const next = buildParticipantUpdateData(row);
    const candidates: ParticipantImportChange[] = [
      { field: 'name', from: existing.name, to: next.name },
    ];
    if (next.email) candidates.push({ field: 'email', from: existing.email, to: next.email });
    if (next.cnhCategory) {
      candidates.push({ field: 'cnhCategory', from: existing.cnhCategory, to: next.cnhCategory });
    }
    if (next.cnhExpiration) {
      candidates.push({
        field: 'cnhExpiration',
        from: existing.cnhExpiration?.toISOString().slice(0, 10) ?? null,
        to: next.cnhExpiration.toISOString().slice(0, 10),
      });
    }
    return candidates.filter((change) => change.from !== change.to);
  }

  /**
   * Grava uma linha na sua própria transação; nunca lança, para uma linha ruim
   * não derrubar as outras. Em `P2002` (corrida com outra inscrição, como a do
   * QR Code) relê o banco: já inscrito → `alreadyEnrolled`; cadastro criado no
   * meio do caminho → repete uma única vez pelo caminho de update.
   */
  private async writeRow(
    sessionId: string,
    row: ParsedRow,
    existingId: string | null,
    participationType: ParticipationType,
  ): Promise<WriteOutcome> {
    try {
      await this.enrollInTransaction(sessionId, row, existingId, participationType);
      return existingId ? 'updated' : 'created';
    } catch (err) {
      if (!isUniqueViolation(err)) return this.logFailure(row, err);

      try {
        const current = await this.prisma.participant.findUnique({
          where: { cpf: row.cpf },
          select: { id: true },
        });
        if (!current) return this.logFailure(row, err);

        const enrolled = await this.prisma.trainingParticipant.findUnique({
          where: {
            trainingSessionId_participantId: { trainingSessionId: sessionId, participantId: current.id },
          },
          select: { id: true },
        });
        if (enrolled) return 'alreadyEnrolled';
        if (existingId) return this.logFailure(row, err);

        await this.enrollInTransaction(sessionId, row, current.id, participationType);
        return 'updated';
      } catch (retryErr) {
        return this.logFailure(row, retryErr);
      }
    }
  }

  /** Cadastro (create ou update pela regra compartilhada) + inscrição, juntos ou nada. */
  private async enrollInTransaction(
    sessionId: string,
    row: ParsedRow,
    existingId: string | null,
    participationType: ParticipationType,
  ): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      let participantId = existingId;
      if (participantId) {
        await tx.participant.update({
          where: { id: participantId },
          data: buildParticipantUpdateData(row),
        });
      } else {
        const created = await tx.participant.create({
          data: {
            name: row.name,
            cpf: row.cpf,
            email: row.email,
            cnhCategory: row.cnhCategory,
            cnhExpiration: row.cnhExpiration ? new Date(row.cnhExpiration) : undefined,
          },
        });
        participantId = created.id;
      }

      await tx.trainingParticipant.create({
        data: { trainingSessionId: sessionId, participantId, participationType },
      });
    });
  }

  private logFailure(row: ParsedRow, err: unknown): WriteOutcome {
    console.error(`Falha ao importar a linha ${row.rowNumber} da planilha:`, err);
    return 'failed';
  }
}
