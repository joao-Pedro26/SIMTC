import * as ExcelJS from 'exceljs';
import {
  PARTICIPANT_IMPORT_MAX_BYTES,
  PARTICIPANT_IMPORT_MAX_ROWS,
} from '@simtc/shared-types';
import { CNH_CATEGORIES } from '../cnh.constants';

const PARTICIPANTS_SHEET = 'Participantes';
const INSTRUCTIONS_SHEET = 'Instruções';

const FIRST_DATA_ROW = 2;
const LAST_VALIDATED_ROW = PARTICIPANT_IMPORT_MAX_ROWS + 1;

const COLUMNS: { header: string; width: number; numFmt?: string }[] = [
  { header: 'Nome*', width: 32 },
  { header: 'CPF*', width: 18, numFmt: '@' },
  { header: 'E-mail', width: 30 },
  { header: 'Categoria CNH*', width: 18 },
  { header: 'Validade CNH*', width: 16, numFmt: 'dd/mm/yyyy' },
];

const maxMb = Math.round(PARTICIPANT_IMPORT_MAX_BYTES / (1024 * 1024));

const INSTRUCTIONS: string[] = [
  'Como preencher a planilha de participantes',
  '',
  'Preencha a aba "Participantes", uma pessoa por linha, a partir da linha 2.',
  '',
  'Campos obrigatórios: Nome, CPF, Categoria CNH e Validade CNH.',
  `Categorias de CNH aceitas: ${CNH_CATEGORIES.join(', ')}.`,
  'E-mail: opcional, mas, se preenchido, precisa ser um e-mail válido.',
  'Validade CNH: obrigatória, no formato dd/mm/aaaa (por exemplo, 31/12/2030).',
  'O tipo de participação é definido pelo curso do treinamento e pode ser ajustado depois, na lista de participantes.',
  'CPF: a coluna já está formatada como Texto para o Excel não apagar o zero à esquerda.',
  '',
  `Limites: até ${PARTICIPANT_IMPORT_MAX_ROWS} linhas e ${maxMb} MB por arquivo.`,
  'Somente a aba "Participantes" é lida; esta aba de instruções é ignorada.',
  '',
  'Exemplo de linha preenchida:',
  'Nome: Maria da Silva | CPF: 012.345.678-90 | E-mail: maria@empresa.com.br | Categoria CNH: B | Validade CNH: 31/12/2030',
];

function listFormula(options: readonly string[]): string {
  return `"${options.join(',')}"`;
}

export async function buildParticipantImportTemplate(): Promise<Buffer> {
  const workbook = new ExcelJS.Workbook();

  const sheet = workbook.addWorksheet(PARTICIPANTS_SHEET, {
    views: [{ state: 'frozen', ySplit: 1 }],
  });
  sheet.columns = COLUMNS.map(({ header, width }) => ({ header, width }));
  COLUMNS.forEach(({ numFmt }, index) => {
    if (numFmt) sheet.getColumn(index + 1).numFmt = numFmt;
  });
  sheet.getRow(1).font = { bold: true };

  const cnhList = { type: 'list' as const, allowBlank: true, formulae: [listFormula(CNH_CATEGORIES)] };
  for (let row = FIRST_DATA_ROW; row <= LAST_VALIDATED_ROW; row++) {
    sheet.getCell(row, 4).dataValidation = cnhList;
  }

  const instructions = workbook.addWorksheet(INSTRUCTIONS_SHEET);
  instructions.getColumn(1).width = 120;
  INSTRUCTIONS.forEach((line, index) => {
    const cell = instructions.getCell(index + 1, 1);
    cell.value = line;
    cell.alignment = { wrapText: true, vertical: 'top' };
  });
  instructions.getCell(1, 1).font = { bold: true, size: 14 };

  return Buffer.from(await workbook.xlsx.writeBuffer());
}
