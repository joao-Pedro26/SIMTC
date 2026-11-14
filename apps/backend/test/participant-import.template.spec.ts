import * as ExcelJS from 'exceljs';
import { CNH_CATEGORIES } from 'src/participants/cnh.constants';
import { buildParticipantImportTemplate } from 'src/participants/import/participant-import.template';
import { parseParticipantSheet } from 'src/participants/import/participant-import.parser';

async function open(buffer: Buffer): Promise<ExcelJS.Workbook> {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.load(buffer as unknown as ExcelJS.Buffer);
  return wb;
}

describe('buildParticipantImportTemplate', () => {
  let template: Buffer;

  beforeAll(async () => {
    template = await buildParticipantImportTemplate();
  });

  it('gera um .xlsx (começa com PK\\x03\\x04)', () => {
    expect(template.subarray(0, 4)).toEqual(Buffer.from([0x50, 0x4b, 0x03, 0x04]));
  });

  it('tem as abas Participantes e Instruções, nessa ordem', async () => {
    const wb = await open(template);
    expect(wb.worksheets.map((w) => w.name)).toEqual(['Participantes', 'Instruções']);
  });

  it('cabeçalhos em negrito na linha 1, congelada, e sem linha de exemplo', async () => {
    const ws = (await open(template)).getWorksheet('Participantes')!;
    const header = ws.getRow(1);
    expect(header.values).toEqual([
      undefined,
      'Nome*',
      'CPF*',
      'E-mail',
      'Categoria CNH*',
      'Validade CNH',
      'Tipo de participação',
    ]);
    for (let c = 1; c <= 6; c++) expect(header.getCell(c).font?.bold).toBe(true);
    expect(ws.views[0]).toMatchObject({ state: 'frozen', ySplit: 1 });
    expect(ws.getRow(2).hasValues).toBe(false);
  });

  it('coluna CPF é Texto e Validade CNH é dd/mm/yyyy', async () => {
    const ws = (await open(template)).getWorksheet('Participantes')!;
    expect(ws.getColumn(2).numFmt).toBe('@');
    expect(ws.getColumn(5).numFmt).toBe('dd/mm/yyyy');
  });

  it('listas suspensas nas linhas 2 a 501 (CNH e Tipo)', async () => {
    const ws = (await open(template)).getWorksheet('Participantes')!;
    for (const row of [2, 250, 501]) {
      const cnh = ws.getCell(`D${row}`).dataValidation;
      expect(cnh.type).toBe('list');
      expect(cnh.formulae).toEqual([`"${CNH_CATEGORIES.join(',')}"`]);
      const tipo = ws.getCell(`F${row}`).dataValidation;
      expect(tipo.type).toBe('list');
      expect(tipo.formulae).toEqual(['"Somente teórica,Teórica e prática"']);
    }
    expect(ws.getCell('D502').dataValidation).toBeFalsy();
    expect(ws.getCell('F502').dataValidation).toBeFalsy();
  });

  it('a aba Instruções traz as regras e o exemplo', async () => {
    const ws = (await open(template)).getWorksheet('Instruções')!;
    const text: string[] = [];
    ws.eachRow((row) => row.eachCell((cell) => text.push(cell.text)));
    const all = text.join('\n');
    for (const piece of [
      'Nome',
      'CPF',
      'Categoria CNH',
      CNH_CATEGORIES.join(', '),
      'dd/mm/aaaa',
      'Somente teórica',
      'Teórica e prática',
      '500',
      '2 MB',
      'Participantes',
    ]) {
      expect(all).toContain(piece);
    }
  });

  it('o parser lê o modelo vazio: aba Participantes, cabeçalho na linha 1, nada ignorado', async () => {
    const sheet = await parseParticipantSheet(template, 'modelo.xlsx');
    expect(sheet).toMatchObject({
      sheetName: 'Participantes',
      headerRow: 1,
      ignoredColumns: [],
      rows: [],
    });
  });

  it('modelo preenchido (tipos da lista, CPF com zero à esquerda como texto) → 3 linhas limpas', async () => {
    const wb = await open(template);
    const ws = wb.getWorksheet('Participantes')!;
    ws.getRow(2).values = ['Ana Souza', '01234567890', 'ana@x.com', 'B', '31/12/2030', 'Somente teórica'];
    ws.getRow(3).values = ['Bruno Lima', '52998224725', '', 'AB', '', 'Teórica e prática'];
    ws.getRow(4).values = ['Carla Dias', '11144477735', 'carla@x.com', 'E'];
    const filled = Buffer.from(await wb.xlsx.writeBuffer());

    const sheet = await parseParticipantSheet(filled, 'modelo.xlsx');
    expect(sheet.rows).toHaveLength(3);
    for (const row of sheet.rows) {
      expect(row.errors).toEqual([]);
      expect(row.warnings).toEqual([]);
    }
    expect(sheet.rows[0]).toMatchObject({
      cpf: '01234567890',
      participationType: 'SOMENTE_TEORICA',
      cnhExpiration: '2030-12-31',
    });
    expect(sheet.rows[1].participationType).toBe('TEORICA_E_PRATICA');
  });
});
