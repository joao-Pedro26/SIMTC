import { BadRequestException } from '@nestjs/common';
import * as ExcelJS from 'exceljs';
import {
  parseParticipantSheet,
  validateImportRow,
} from 'src/participants/import/participant-import.parser';

const HEADER = ['Nome', 'CPF', 'E-mail', 'Categoria CNH', 'Validade CNH', 'Tipo'];
const VALID_CPF = '01234567890';

type Cell = ExcelJS.CellValue;

async function xlsx(sheets: { name?: string; rows: Cell[][] }[]): Promise<Buffer> {
  const wb = new ExcelJS.Workbook();
  sheets.forEach((s, i) => {
    const ws = wb.addWorksheet(s.name ?? `Aba${i + 1}`);
    s.rows.forEach((r) => ws.addRow(r));
  });
  return Buffer.from(await wb.xlsx.writeBuffer());
}

const oneSheet = (rows: Cell[][]) => xlsx([{ rows }]);

async function expectFileError(promise: Promise<unknown>, message: string) {
  await expect(promise).rejects.toBeInstanceOf(BadRequestException);
  await expect(promise).rejects.toThrow(message);
}

describe('parseParticipantSheet', () => {
  it('encontra o cabeçalho na linha 3 e preserva o rowNumber', async () => {
    const buf = await oneSheet([
      ['Lista da turma'],
      [],
      HEADER,
      ['Maria', VALID_CPF, '', 'B'],
    ]);
    const sheet = await parseParticipantSheet(buf, 'a.xlsx');
    expect(sheet.headerRow).toBe(3);
    expect(sheet.rows[0].rowNumber).toBe(4);
    expect(sheet.rows[0].errors).toEqual([]);
  });

  it('reconhece aliases com acento e lista colunas ignoradas', async () => {
    const buf = await oneSheet([
      ['Colaborador', 'CPF', 'Setor', 'E-mail', 'Cat CNH', 'Vencimento CNH', 'Participação'],
      ['Ana', VALID_CPF, 'Frota', 'ana@x.com', 'B', '31/12/2027', 'teorica'],
    ]);
    const sheet = await parseParticipantSheet(buf, 'a.xlsx');
    expect(sheet.ignoredColumns).toEqual(['Setor']);
    expect(sheet.rows[0]).toMatchObject({
      name: 'Ana',
      email: 'ana@x.com',
      cnhCategory: 'B',
      cnhExpiration: '2027-12-31',
      participationType: 'SOMENTE_TEORICA',
    });
  });

  it('aceita "Nome Completo" e cabeçalho com asterisco do modelo', async () => {
    const buf = await oneSheet([
      ['Nome Completo*', 'CPF*', 'Categoria CNH*'],
      ['Ana', VALID_CPF, 'B'],
    ]);
    const sheet = await parseParticipantSheet(buf, 'a.xlsx');
    expect(sheet.rows[0].name).toBe('Ana');
    expect(sheet.ignoredColumns).toEqual([]);
  });

  it('usa a segunda aba quando só ela tem o cabeçalho', async () => {
    const buf = await xlsx([
      { name: 'Instruções', rows: [['Leia isto']] },
      { name: 'Participantes', rows: [HEADER, ['Maria', VALID_CPF, '', 'B']] },
    ]);
    const sheet = await parseParticipantSheet(buf, 'a.xlsx');
    expect(sheet.sheetName).toBe('Participantes');
    expect(sheet.rows).toHaveLength(1);
  });

  it('CPF numérico sem o zero à esquerda volta a ter 11 dígitos', async () => {
    const buf = await oneSheet([HEADER, ['Maria', 1234567890, '', 'B']]);
    const sheet = await parseParticipantSheet(buf, 'a.xlsx');
    expect(sheet.rows[0].cpf).toBe(VALID_CPF);
    expect(sheet.rows[0].errors).toEqual([]);
  });

  it('CPF com máscara fica só com dígitos', async () => {
    const buf = await oneSheet([HEADER, ['Maria', '012.345.678-90', '', 'B']]);
    const sheet = await parseParticipantSheet(buf, 'a.xlsx');
    expect(sheet.rows[0].cpf).toBe(VALID_CPF);
  });

  it('e-mail hiperlink em maiúsculas vira texto limpo em minúsculas', async () => {
    const buf = await oneSheet([
      HEADER,
      [
        'Maria',
        VALID_CPF,
        { text: 'Maria@Empresa.COM', hyperlink: 'mailto:Maria@Empresa.COM' },
        'B',
      ],
    ]);
    const sheet = await parseParticipantSheet(buf, 'a.xlsx');
    expect(sheet.rows[0].email).toBe('maria@empresa.com');
    expect(sheet.rows[0].errors).toEqual([]);
  });

  it.each<[string, Cell]>([
    ['Date', new Date(Date.UTC(2027, 11, 31))],
    ['serial numérico', 46752],
    ['texto dd/mm/aaaa', '31/12/2027'],
    ['texto dd-mm-aaaa', '31-12-2027'],
    ['texto aaaa-mm-dd', '2027-12-31'],
  ])('validade como %s vira 2027-12-31', async (_label, value) => {
    const buf = await oneSheet([HEADER, ['Maria', VALID_CPF, '', 'B', value]]);
    const sheet = await parseParticipantSheet(buf, 'a.xlsx');
    expect(sheet.rows[0].cnhExpiration).toBe('2027-12-31');
    expect(sheet.rows[0].warnings).toEqual([]);
  });

  it('05/04/2027 é dia/mês', async () => {
    const buf = await oneSheet([HEADER, ['Maria', VALID_CPF, '', 'B', '05/04/2027']]);
    const sheet = await parseParticipantSheet(buf, 'a.xlsx');
    expect(sheet.rows[0].cnhExpiration).toBe('2027-04-05');
  });

  it('validade ilegível gera aviso e fica sem data', async () => {
    const buf = await oneSheet([HEADER, ['Maria', VALID_CPF, '', 'B', 'amanha']]);
    const sheet = await parseParticipantSheet(buf, 'a.xlsx');
    expect(sheet.rows[0].cnhExpiration).toBeUndefined();
    expect(sheet.rows[0].warnings).toEqual(['Validade da CNH ilegível']);
    expect(sheet.rows[0].errors).toEqual([]);
  });

  it('CSV com ; em latin1 mantém João e Conceição', async () => {
    const csv = 'Nome;CPF;Categoria CNH\nJoão;012.345.678-90;B\nConceição;01234567890;A\n';
    const sheet = await parseParticipantSheet(Buffer.from(csv, 'latin1'), 'a.csv');
    expect(sheet.sheetName).toBeNull();
    expect(sheet.rows.map((r) => r.name)).toEqual(['João', 'Conceição']);
  });

  it('CSV com , em UTF-8 com BOM reconhece a primeira coluna', async () => {
    const csv = '﻿Nome,CPF,Categoria CNH\nMaria,01234567890,B\n';
    const sheet = await parseParticipantSheet(Buffer.from(csv, 'utf8'), 'a.csv');
    expect(sheet.rows[0]).toMatchObject({ name: 'Maria', cpf: VALID_CPF, rowNumber: 2 });
  });

  it('ignora linhas vazias no meio e no fim e preserva o rowNumber', async () => {
    const buf = await oneSheet([
      HEADER,
      ['Ana', VALID_CPF, '', 'B'],
      [],
      ['Bia', VALID_CPF, '', 'B'],
      [],
      [],
    ]);
    const sheet = await parseParticipantSheet(buf, 'a.xlsx');
    expect(sheet.rows.map((r) => r.rowNumber)).toEqual([2, 4]);
  });

  it('recusa .xls', async () => {
    await expectFileError(
      parseParticipantSheet(Buffer.from('x'), 'a.xls'),
      'Arquivos .xls não são suportados. Abra no Excel e use "Salvar como" .xlsx',
    );
  });

  it('recusa extensão desconhecida', async () => {
    await expectFileError(
      parseParticipantSheet(Buffer.from('x'), 'a.txt'),
      'Envie um arquivo .xlsx ou .csv',
    );
  });

  it('recusa .xlsx cujo conteúdo não é ZIP', async () => {
    await expectFileError(
      parseParticipantSheet(Buffer.from('isto não é um zip'), 'a.xlsx'),
      'Não foi possível ler o arquivo .xlsx',
    );
  });

  it('recusa .xlsx com assinatura ZIP mas conteúdo corrompido', async () => {
    const corrupt = Buffer.concat([Buffer.from([0x50, 0x4b, 0x03, 0x04]), Buffer.from('lixo')]);
    await expectFileError(
      parseParticipantSheet(corrupt, 'a.xlsx'),
      'Não foi possível ler o arquivo .xlsx',
    );
  });

  it('sem coluna CPF é erro do arquivo', async () => {
    const buf = await oneSheet([['Nome', 'Categoria CNH'], ['Maria', 'B']]);
    await expectFileError(
      parseParticipantSheet(buf, 'a.xlsx'),
      'Não encontramos as colunas Nome e CPF. Baixe o modelo para ver o formato esperado',
    );
  });

  it('sem coluna Categoria CNH é erro do arquivo', async () => {
    const buf = await oneSheet([['Nome', 'CPF'], ['Maria', VALID_CPF]]);
    await expectFileError(parseParticipantSheet(buf, 'a.xlsx'), 'Coluna Categoria CNH não encontrada');
  });

  it('cabeçalho depois da linha 10 não é encontrado', async () => {
    const rows: Cell[][] = Array.from({ length: 10 }, () => ['x']);
    rows.push(HEADER);
    const buf = await oneSheet(rows);
    await expectFileError(parseParticipantSheet(buf, 'a.xlsx'), 'Não encontramos as colunas Nome e CPF');
  });

  it('501 linhas de dados é erro do arquivo; 500 passa', async () => {
    const people = (n: number): Cell[][] =>
      Array.from({ length: n }, (_, i) => [`Pessoa ${i}`, VALID_CPF, '', 'B']);
    const over = await oneSheet([HEADER, ...people(501)]);
    await expectFileError(
      parseParticipantSheet(over, 'a.xlsx'),
      'A planilha tem 501 linhas; o limite é 500 por arquivo',
    );
    const ok = await oneSheet([HEADER, ...people(500)]);
    expect((await parseParticipantSheet(ok, 'a.xlsx')).rows).toHaveLength(500);
  });
});

describe('validateImportRow', () => {
  const base = { rowNumber: 2, name: 'Maria', cpf: VALID_CPF, cnhCategory: 'B' };

  it.each([
    ['vazia', ''],
    ['F', 'F'],
    ['ABC', 'ABC'],
  ])('categoria CNH %s é erro', (_label, cnhCategory) => {
    const row = validateImportRow({ ...base, cnhCategory });
    expect(row.errors).toHaveLength(1);
    expect(row.cnhCategory).toBeUndefined();
  });

  it('mensagens exatas de categoria CNH', () => {
    expect(validateImportRow({ ...base, cnhCategory: '' }).errors).toEqual([
      'Categoria CNH obrigatória',
    ]);
    expect(validateImportRow({ ...base, cnhCategory: 'F' }).errors).toEqual([
      'Categoria CNH inválida (use: A, B, C, D, E, AB, AC, AD, AE)',
    ]);
  });

  it.each(['A/B', 'a b', ' ab '])('categoria "%s" vira AB', (cnhCategory) => {
    const row = validateImportRow({ ...base, cnhCategory });
    expect(row.cnhCategory).toBe('AB');
    expect(row.errors).toEqual([]);
  });

  it('e-mail vazio não é erro e fica undefined', () => {
    const row = validateImportRow({ ...base, email: '  ' });
    expect(row.email).toBeUndefined();
    expect(row.errors).toEqual([]);
  });

  it('e-mail "fulano@" é inválido', () => {
    expect(validateImportRow({ ...base, email: 'fulano@' }).errors).toEqual(['E-mail inválido']);
  });

  it('acumula nome vazio, CPF inválido e CNH vazia', () => {
    const row = validateImportRow({ rowNumber: 7, name: '', cpf: '123', cnhCategory: '' });
    expect(row.errors).toEqual(['Nome obrigatório', 'CPF inválido', 'Categoria CNH obrigatória']);
    expect(row.rowNumber).toBe(7);
    expect(row.cpf).toBe('123');
  });

  it('CPF ausente é "CPF obrigatório"', () => {
    expect(validateImportRow({ ...base, cpf: undefined }).errors).toEqual(['CPF obrigatório']);
  });

  it.each([
    ['teorica', 'SOMENTE_TEORICA'],
    ['Somente Teórica', 'SOMENTE_TEORICA'],
    ['completa', 'TEORICA_E_PRATICA'],
    ['Teórica e Prática', 'TEORICA_E_PRATICA'],
  ])('tipo "%s" vira %s', (participationType, expected) => {
    const row = validateImportRow({ ...base, participationType });
    expect(row.participationType).toBe(expected);
    expect(row.warnings).toEqual([]);
  });

  it('tipo vazio fica undefined sem aviso', () => {
    const row = validateImportRow({ ...base, participationType: '' });
    expect(row.participationType).toBeUndefined();
    expect(row.warnings).toEqual([]);
  });

  it('tipo "xyz" fica undefined com aviso', () => {
    const row = validateImportRow({ ...base, participationType: 'xyz' });
    expect(row.participationType).toBeUndefined();
    expect(row.warnings).toEqual(['Tipo de participação não reconhecido']);
  });

  it('normaliza o nome', () => {
    expect(validateImportRow({ ...base, name: '  Maria   da  SILVA ' }).name).toBe('Maria da SILVA');
  });

  it('aceita entrada já normalizada sem aviso', () => {
    const row = validateImportRow({
      ...base,
      cnhExpiration: '2027-12-31',
      participationType: 'SOMENTE_TEORICA',
    });
    expect(row.cnhExpiration).toBe('2027-12-31');
    expect(row.participationType).toBe('SOMENTE_TEORICA');
    expect(row.warnings).toEqual([]);
    expect(row.errors).toEqual([]);
  });
});
