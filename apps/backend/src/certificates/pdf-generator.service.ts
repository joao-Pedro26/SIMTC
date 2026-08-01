import { Injectable } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as Handlebars from 'handlebars';

@Injectable()
export class PdfGeneratorService {
  private simLogoDataUrl: string | null = null;
  private certificateTemplate: HandlebarsTemplateDelegate | null = null;

  async renderCertificate(data: Record<string, any>): Promise<Buffer> {
    const { default: puppeteer } = await import('puppeteer');

    if (!this.certificateTemplate) {
      this.certificateTemplate = this.compileTemplate('certificate.html');
    }

    const html = this.certificateTemplate({
      ...data,
      simLogoUrl: this.getSimLogoDataUrl(),
    });

    const browser = await puppeteer.launch({
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: 'networkidle0' });
    const pdf = await page.pdf({
      format: 'A4',
      landscape: true,
      printBackground: true,
    });
    await browser.close();
    return Buffer.from(pdf);
  }

  private compileTemplate(filename: string): HandlebarsTemplateDelegate {
    const templatePath = path.join(__dirname, 'templates', filename);
    const source = fs.readFileSync(templatePath, 'utf-8');
    return Handlebars.compile(source);
  }

  /**
   * Lê o PNG do logo SIM Treinamentos e retorna como data URL base64.
   * Procura em `<raiz-do-monorepo>/assets/imagens/logo-sim-treinamentos.png`.
   * Retorna null silenciosamente se o arquivo não for encontrado.
   */
  private getSimLogoDataUrl(): string | null {
    if (this.simLogoDataUrl !== null) return this.simLogoDataUrl;

    try {
      const logoPath = path.resolve(
        process.cwd(),
        'assets',
        'imagens',
        'logo-sim-treinamentos.png',
      );
      const data = fs.readFileSync(logoPath);
      this.simLogoDataUrl = `data:image/png;base64,${data.toString('base64')}`;
    } catch {
      // Logo não encontrado — certificado será gerado sem ele
      this.simLogoDataUrl = '';
    }

    return this.simLogoDataUrl || null;
  }
}
