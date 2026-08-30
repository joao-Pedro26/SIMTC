import { Injectable } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as Handlebars from 'handlebars';
// `p-limit` usa `export =` (estilo CommonJS puro) e este projeto não tem
// `esModuleInterop` no tsconfig — `import pLimit from 'p-limit'` compila
// para `p_limit_1.default(...)`, que não existe em runtime (só o
// `allowSyntheticDefaultImports` mascarava o erro de tipo). `import ... =
// require(...)` funciona independente de esModuleInterop.
import pLimit = require('p-limit');

@Injectable()
export class PdfGeneratorService {
  private footerDataUrl: string | null = null;
  private simLogoDataUrl: string | null = null;
  private simLogoIconDataUrl: string | null = null;
  private certificateTemplate: HandlebarsTemplateDelegate | null = null;
  private assessmentReportTemplate: HandlebarsTemplateDelegate | null = null;

  // Limita a no máximo 2 instâncias de Chromium (Puppeteer) rodando ao mesmo
  // tempo no processo inteiro, compartilhado entre certificados e relatórios.
  // O VPS de produção é 1 vCPU / 4GB — sem esse limite, um "gerar todos" ou um
  // job em lote (que também chama renderCertificate/renderAssessmentReport sob
  // demanda) poderia abrir dezenas de Chromiums em paralelo e estourar a RAM.
  private readonly limiter = pLimit(2);

  async renderCertificate(data: Record<string, any>): Promise<Buffer> {
    return this.limiter(() => this.renderCertificateInternal(data));
  }

  private async renderCertificateInternal(data: Record<string, any>): Promise<Buffer> {
    let puppeteer: any;
    try {
      const mod = await import('puppeteer');
      puppeteer = mod.default;
    } catch (e: any) {
      throw new Error(`Puppeteer não encontrado: ${e.message}`);
    }

    if (!this.certificateTemplate) {
      this.certificateTemplate = this.compileTemplate('certificate.html');
    }

    const html = this.certificateTemplate({
      ...data,
      footerDataUrl: this.getAssetDataUrl('footerDataUrl', 'cert-footer.png'),
      simLogoDataUrl: this.getAssetDataUrl('simLogoDataUrl', 'sim-logo.png'),
    });

    let browser: any;
    try {
      browser = await puppeteer.launch({
        args: ['--no-sandbox', '--disable-setuid-sandbox'],
      });
    } catch (e: any) {
      throw new Error(`Falha ao iniciar Chromium (Puppeteer): ${e.message}`);
    }

    try {
      const page = await browser.newPage();
      await page.setContent(html, { waitUntil: 'networkidle0' });
      const pdf = await page.pdf({
        format: 'A4',
        landscape: true,
        printBackground: true,
      });
      return Buffer.from(pdf);
    } finally {
      await browser.close().catch(() => {});
    }
  }

  async renderAssessmentReport(data: Record<string, any>): Promise<Buffer> {
    return this.limiter(() => this.renderAssessmentReportInternal(data));
  }

  private async renderAssessmentReportInternal(data: Record<string, any>): Promise<Buffer> {
    let puppeteer: any;
    try {
      const mod = await import('puppeteer');
      puppeteer = mod.default;
    } catch (e: any) {
      throw new Error(`Puppeteer não encontrado: ${e.message}`);
    }

    if (!this.assessmentReportTemplate) {
      this.assessmentReportTemplate = this.compileTemplate('assessment-report.html');
    }

    const html = this.assessmentReportTemplate({
      ...data,
      // Relatório de avaliação usa apenas o ícone (3 figuras), sem a wordmark
      // "SIM Treinamentos" por extenso — por isso um arquivo e uma cacheKey
      // próprios, distintos do simLogoDataUrl usado no certificado (que usa a
      // logo completa). Reaproveitar a mesma cacheKey aqui causaria colisão de
      // cache entre os dois templates (o getAssetDataUrl cacheia por cacheKey,
      // não por filename).
      simLogoIconDataUrl: this.getAssetDataUrl('simLogoIconDataUrl', 'sim-logo-icon.png'),
    });

    let browser: any;
    try {
      browser = await puppeteer.launch({
        args: ['--no-sandbox', '--disable-setuid-sandbox'],
      });
    } catch (e: any) {
      throw new Error(`Falha ao iniciar Chromium (Puppeteer): ${e.message}`);
    }

    try {
      const page = await browser.newPage();
      await page.setContent(html, { waitUntil: 'networkidle0' });
      const pdf = await page.pdf({
        format: 'A4',
        landscape: false,
        printBackground: true,
      });
      return Buffer.from(pdf);
    } finally {
      await browser.close().catch(() => {});
    }
  }

  private compileTemplate(filename: string): HandlebarsTemplateDelegate {
    // Tenta primeiro em __dirname (dist/), depois sobe para src/ (ts-node / teste)
    const candidates = [
      path.join(__dirname, 'templates', filename),
      path.join(__dirname, '..', '..', 'src', 'certificates', 'templates', filename),
      path.resolve(process.cwd(), 'src', 'certificates', 'templates', filename),
    ];

    for (const p of candidates) {
      if (fs.existsSync(p)) {
        return Handlebars.compile(fs.readFileSync(p, 'utf-8'));
      }
    }

    throw new Error(
      `Template "${filename}" não encontrado. Caminhos tentados:\n${candidates.join('\n')}`,
    );
  }

  private getAssetDataUrl(cacheKey: string, filename: string): string | null {
    if (this[cacheKey] !== null) return this[cacheKey] as string | null;

    // Mesma estratégia de caminhos candidatos do compileTemplate
    const candidates = [
      path.join(__dirname, 'templates', filename),
      path.join(__dirname, '..', '..', 'src', 'certificates', 'templates', filename),
      path.resolve(process.cwd(), 'src', 'certificates', 'templates', filename),
    ];

    for (const candidate of candidates) {
      try {
        if (fs.existsSync(candidate)) {
          const data = fs.readFileSync(candidate);
          (this as any)[cacheKey] = `data:image/png;base64,${data.toString('base64')}`;
          return (this as any)[cacheKey];
        }
      } catch {
        // tenta o próximo
      }
    }

    (this as any)[cacheKey] = '';
    return null;
  }
}
