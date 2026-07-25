import { Injectable } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as Handlebars from 'handlebars';

@Injectable()
export class PdfGeneratorService {
  private certificateTemplate: HandlebarsTemplateDelegate | null = null;

  async renderCertificate(data: Record<string, any>): Promise<Buffer> {
    // Importação dinâmica do Puppeteer (ESM)
    const { default: puppeteer } = await import('puppeteer');

    const html = this.getTemplate('certificate.html')(data);
    const browser = await puppeteer.launch({ args: ['--no-sandbox', '--disable-setuid-sandbox'] });
    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: 'networkidle0' });
    const pdf = await page.pdf({ format: 'A4', printBackground: true });
    await browser.close();
    return Buffer.from(pdf);
  }

  private getTemplate(filename: string): HandlebarsTemplateDelegate {
    const templatePath = path.join(__dirname, 'templates', filename);
    const source = fs.readFileSync(templatePath, 'utf-8');
    return Handlebars.compile(source);
  }
}
