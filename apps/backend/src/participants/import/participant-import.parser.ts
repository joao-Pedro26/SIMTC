import { BadRequestException } from '@nestjs/common';
import { isEmail } from 'class-validator';
import * as ExcelJS from 'exceljs';
import * as Papa from 'papaparse';
import {
  ParticipantImportRowDto,
  ParticipationType,
  PARTICIPANT_IMPORT_MAX_ROWS,
} from '@simtc/shared-types';
import { ValidateCpfPipe } from '../../common/pipes/validate-cpf.pipe';
import { CNH_CATEGORIES, isValidCnhCategory } from '../cnh.constants';

export interface RawImportRow {
  rowNumber: number;
  name?: unknown;
  cpf?: unknown;
  email?: unknown;
  cnhCategory?: unknown;
  cnhExpiration?: unknown;
  participationType?: unknown;
}

export interface ParsedRow extends ParticipantImportRowDto {
  errors: string[];
  warnings: string[];
}

export interface ParsedSheet {
  sheetName: string | null;
  headerRow: number;
  ignoredColumns: string[];
  rows: ParsedRow[];
}

type FieldKey = 'name' | 'cpf' | 'email' | 'cnhCategory' | 'cnhExpiration' | 'participationType';

/** Cada célula já lida: `Date`/número ficam crus (datas e CPF numérico), o resto vira texto. */
type Grid = unknown[][];

const HEADER_SCAN_ROWS = 10;
/** Colunas além desta são ignoradas na leitura do .xlsx. */
const XLSX_MAX_COLUMNS = 50;
/** Seriais do Excel abaixo disto (antes de ~1954) são tratados como número solto, não data. */
const MIN_PLAUSIBLE_EXCEL_SERIAL = 20000;
const XLSX_SIGNATURE = Buffer.from([0x50, 0x4b, 0x03, 0x04]);

/** Minúsculas, sem acento, sem pontuação, espaços colapsados. */
function normalizeText(value: unknown): string {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

const HEADER_ALIASES: Record<FieldKey, string[]> = {
  name: ['nome', 'nome completo', 'participante', 'colaborador', 'funcionario', 'aluno'],
  cpf: ['cpf', 'cpf do participante', 'n cpf', 'numero do cpf'],
  email: ['email', 'e-mail', 'email corporativo', 'correio eletronico'].map(normalizeText),
  cnhCategory: ['categoria cnh', 'cnh categoria', 'categoria', 'cat cnh', 'cnh'],
  cnhExpiration: ['validade cnh', 'vencimento cnh', 'validade', 'vencimento', 'data de validade'],
  participationType: ['tipo', 'tipo de participacao', 'participacao', 'modalidade'],
};

const PARTICIPATION_ALIASES: Record<string, ParticipationType> = {
  teorica: ParticipationType.SOMENTE_TEORICA,
  'somente teorica': ParticipationType.SOMENTE_TEORICA,
  teoria: ParticipationType.SOMENTE_TEORICA,
  'teorica e pratica': ParticipationType.TEORICA_E_PRATICA,
  pratica: ParticipationType.TEORICA_E_PRATICA,
  completa: ParticipationType.TEORICA_E_PRATICA,
  ambas: ParticipationType.TEORICA_E_PRATICA,
};

const cpfPipe = new ValidateCpfPipe();

function isBlank(value: unknown): boolean {
  return value === null || value === undefined || (typeof value === 'string' && value.trim() === '');
}

function toIsoDate(year: number, month: number, day: number): string | undefined {
  const d = new Date(Date.UTC(year, month - 1, day));
  if (d.getUTCFullYear() !== year || d.getUTCMonth() !== month - 1 || d.getUTCDate() !== day) {
    return undefined;
  }
  return d.toISOString().slice(0, 10);
}

function parseDate(value: unknown): string | undefined {
  if (value instanceof Date) {
    return isNaN(value.getTime()) ? undefined : value.toISOString().slice(0, 10);
  }
  if (typeof value === 'number') {
    // Número serial do Excel (dias desde 30/12/1899).
    if (!isFinite(value) || value < MIN_PLAUSIBLE_EXCEL_SERIAL || value > 2958465) return undefined;
    return new Date(Date.UTC(1899, 11, 30) + Math.floor(value) * 86400000)
      .toISOString()
      .slice(0, 10);
  }
  const text = String(value).trim();
  let m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
  if (m) return toIsoDate(+m[1], +m[2], +m[3]);
  m = /^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$/.exec(text);
  if (m) return toIsoDate(+m[3], +m[2], +m[1]);
  return undefined;
}

function normalizeCpfInput(value: unknown): string {
  let digits =
    typeof value === 'number' ? String(Math.round(value)) : String(value ?? '').replace(/\D/g, '');
  // Excel/CSV perdem o zero à esquerda do CPF digitado como número.
  if (digits.length === 9 || digits.length === 10) digits = digits.padStart(11, '0');
  return digits;
}

/** Normaliza e valida uma linha. Aceita valores crus (Date, serial, texto BR) e já normalizados. */
export function validateImportRow(raw: RawImportRow): ParsedRow {
  const errors: string[] = [];
  const warnings: string[] = [];

  const name = String(raw.name ?? '').trim().replace(/\s+/g, ' ');
  if (!name) errors.push('Nome obrigatório');

  let cpf = '';
  if (isBlank(raw.cpf)) {
    errors.push('CPF obrigatório');
  } else {
    cpf = normalizeCpfInput(raw.cpf);
    try {
      cpf = cpfPipe.transform(cpf);
    } catch {
      errors.push('CPF inválido');
    }
  }

  let email: string | undefined;
  if (!isBlank(raw.email)) {
    const text = String(raw.email).trim().replace(/^mailto:/i, '').trim().toLowerCase();
    if (isEmail(text)) email = text;
    else errors.push('E-mail inválido');
  }

  let cnhCategory: string | undefined;
  const categoryText = String(raw.cnhCategory ?? '').toUpperCase().replace(/[\s/]+/g, '');
  if (!categoryText) {
    errors.push('Categoria CNH obrigatória');
  } else if (isValidCnhCategory(categoryText)) {
    cnhCategory = categoryText;
  } else {
    errors.push(`Categoria CNH inválida (use: ${CNH_CATEGORIES.join(', ')})`);
  }

  let cnhExpiration: string | undefined;
  if (isBlank(raw.cnhExpiration)) {
    errors.push('Validade da CNH obrigatória');
  } else {
    cnhExpiration = parseDate(raw.cnhExpiration);
    if (!cnhExpiration) errors.push('Validade da CNH ilegível (use dd/mm/aaaa)');
  }

  let participationType: ParticipationType | undefined;
  if (!isBlank(raw.participationType)) {
    const key = normalizeText(raw.participationType);
    participationType = Object.prototype.hasOwnProperty.call(PARTICIPATION_ALIASES, key)
      ? PARTICIPATION_ALIASES[key]
      : undefined;
    if (!participationType) warnings.push('Tipo de participação não reconhecido');
  }

  return {
    rowNumber: raw.rowNumber,
    name,
    cpf,
    email,
    cnhCategory,
    cnhExpiration,
    participationType,
    errors,
    warnings,
  };
}

/** Mapeia cada campo para o índice da 1ª coluna que o reconhece. */
function mapHeader(cells: unknown[]): Map<FieldKey, number> {
  const map = new Map<FieldKey, number>();
  cells.forEach((cell, index) => {
    const header = normalizeText(cell);
    if (!header) return;
    for (const field of Object.keys(HEADER_ALIASES) as FieldKey[]) {
      if (!map.has(field) && HEADER_ALIASES[field].includes(header)) {
        map.set(field, index);
        return;
      }
    }
  });
  return map;
}

function findHeader(grid: Grid): { headerRow: number; columns: Map<FieldKey, number> } | null {
  const limit = Math.min(grid.length, HEADER_SCAN_ROWS);
  for (let i = 0; i < limit; i++) {
    const columns = mapHeader(grid[i] ?? []);
    if (columns.has('name') && columns.has('cpf')) return { headerRow: i + 1, columns };
  }
  return null;
}

function buildSheet(
  grid: Grid,
  sheetName: string | null,
  header: { headerRow: number; columns: Map<FieldKey, number> },
): ParsedSheet {
  const { headerRow, columns } = header;
  if (!columns.has('cnhCategory')) {
    throw new BadRequestException('Coluna Categoria CNH não encontrada');
  }
  if (!columns.has('cnhExpiration')) {
    throw new BadRequestException('Coluna Validade CNH não encontrada');
  }

  const used = new Set(columns.values());
  const ignoredColumns = (grid[headerRow - 1] ?? [])
    .map((cell, index) => ({ text: String(cell ?? '').trim(), index }))
    .filter(({ text, index }) => text !== '' && !used.has(index))
    .map(({ text }) => text);

  // `forEach` pula os buracos do grid esparso do .xlsx; o custo não depende da linha mais distante.
  const dataRows: { rowNumber: number; cells: unknown[] }[] = [];
  grid.forEach((cells, i) => {
    if (i < headerRow || !cells || cells.every(isBlank)) return;
    dataRows.push({ rowNumber: i + 1, cells });
  });
  if (dataRows.length > PARTICIPANT_IMPORT_MAX_ROWS) {
    throw new BadRequestException(
      `A planilha tem ${dataRows.length} linhas; o limite é ${PARTICIPANT_IMPORT_MAX_ROWS} por arquivo`,
    );
  }

  const at = (cells: unknown[], field: FieldKey): unknown => {
    const index = columns.get(field);
    return index === undefined ? undefined : cells[index];
  };
  const rows = dataRows.map(({ rowNumber, cells }) =>
    validateImportRow({
      rowNumber,
      name: at(cells, 'name'),
      cpf: at(cells, 'cpf'),
      email: at(cells, 'email'),
      cnhCategory: at(cells, 'cnhCategory'),
      cnhExpiration: at(cells, 'cnhExpiration'),
      participationType: at(cells, 'participationType'),
    }),
  );

  return { sheetName, headerRow, ignoredColumns, rows };
}

const HEADER_NOT_FOUND =
  'Não encontramos as colunas Nome e CPF. Baixe o modelo para ver o formato esperado';

/** Datas e números ficam crus; todo o resto passa por `cell.text` (hiperlink, rich text, fórmula). */
function readCell(cell: ExcelJS.Cell): unknown {
  const value = cell.value;
  if (value instanceof Date || typeof value === 'number') return value;
  if (value && typeof value === 'object' && 'result' in value) {
    const result = (value as ExcelJS.CellFormulaValue).result;
    if (result instanceof Date || typeof result === 'number') return result;
  }
  return cell.text;
}

async function parseXlsx(buffer: Buffer): Promise<ParsedSheet> {
  const unreadable = new BadRequestException('Não foi possível ler o arquivo .xlsx');
  if (buffer.length < 4 || !buffer.subarray(0, 4).equals(XLSX_SIGNATURE)) throw unreadable;

  const workbook = new ExcelJS.Workbook();
  try {
    await workbook.xlsx.load(buffer as unknown as ExcelJS.Buffer);
  } catch {
    throw unreadable;
  }

  for (const sheet of workbook.worksheets) {
    // Grid esparso: só linhas/células que existem, sem varrer rowCount × columnCount.
    const grid: Grid = [];
    sheet.eachRow({ includeEmpty: false }, (row, rowNumber) => {
      const cells: unknown[] = [];
      row.eachCell({ includeEmpty: false }, (cell, colNumber) => {
        if (colNumber <= XLSX_MAX_COLUMNS) cells[colNumber - 1] = readCell(cell);
      });
      grid[rowNumber - 1] = cells;
    });
    const header = findHeader(grid);
    if (header) return buildSheet(grid, sheet.name, header);
  }
  throw new BadRequestException(HEADER_NOT_FOUND);
}

/** Pontos de código de 0x80-0x9F no Windows-1252 (latin1 puro os deixaria como controles C1). */
const WINDOWS_1252_C1 = [
  0x20ac, 0x81, 0x201a, 0x192, 0x201e, 0x2026, 0x2020, 0x2021, 0x2c6, 0x2030, 0x160, 0x2039, 0x152,
  0x8d, 0x17d, 0x8f, 0x90, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x2dc, 0x2122,
  0x161, 0x203a, 0x153, 0x9d, 0x17e, 0x178,
];

/**
 * `TextDecoder('windows-1252')` no Node 24 decodifica como latin1 (0x93 vira controle C1),
 * então a tabela fica explícita aqui.
 */
function decodeWindows1252(buffer: Buffer): string {
  return buffer
    .toString('latin1')
    .replace(/[-]/g, (ch) => String.fromCharCode(WINDOWS_1252_C1[ch.charCodeAt(0) - 0x80]));
}

function decodeCsv(buffer: Buffer): string {
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(buffer).replace(/^﻿/, '');
  } catch {
    return decodeWindows1252(buffer);
  }
}

function parseCsv(buffer: Buffer): ParsedSheet {
  const result = Papa.parse<string[]>(decodeCsv(buffer), { skipEmptyLines: false });
  const grid: Grid = result.data;
  const header = findHeader(grid);
  if (!header) throw new BadRequestException(HEADER_NOT_FOUND);
  return buildSheet(grid, null, header);
}

export async function parseParticipantSheet(
  buffer: Buffer,
  filename: string,
): Promise<ParsedSheet> {
  const lower = filename.toLowerCase();
  if (lower.endsWith('.xls')) {
    throw new BadRequestException(
      'Arquivos .xls não são suportados. Abra no Excel e use "Salvar como" .xlsx',
    );
  }
  if (lower.endsWith('.xlsx')) return parseXlsx(buffer);
  if (lower.endsWith('.csv')) return parseCsv(buffer);
  throw new BadRequestException('Envie um arquivo .xlsx ou .csv');
}
