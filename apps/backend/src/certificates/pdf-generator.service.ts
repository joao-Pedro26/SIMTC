import { Injectable, OnModuleDestroy } from '@nestjs/common';
import type { Browser, PDFOptions } from 'puppeteer';
import * as fs from 'fs';
import * as path from 'path';
import * as Handlebars from 'handlebars';
// `p-limit` usa `export =` (estilo CommonJS puro) e este projeto não tem
// `esModuleInterop` no tsconfig — `import pLimit from 'p-limit'` compila
// para `p_limit_1.default(...)`, que não existe em runtime (só o
// `allowSyntheticDefaultImports` mascarava o erro de tipo). `import ... =
// require(...)` funciona independente de esModuleInterop.
import pLimit = require('p-limit');

// Sem geração de PDF por este tempo, o Chromium compartilhado é fechado para
// devolver a RAM; a próxima geração abre um novo.
const BROWSER_IDLE_CLOSE_MS = 60_000;

const BROWSER_ARGS = ['--no-sandbox', '--disable-setuid-sandbox'];

/**
 * Quantas renderizações (páginas do Chromium) rodam ao mesmo tempo no processo
 * inteiro, compartilhado entre certificados e relatórios. O job em lote de
 * documentos usa o mesmo número como quantidade de participantes em andamento,
 * para que sempre haja trabalho esperando uma vaga livre.
 *
 * O VPS de produção é 1 vCPU / 4GB. Medições de 24/11/2026: 2 foi bem mais
 * rápido que abrir um Chromium por PDF, e 1 (com participantes também um por
 * vez) ficou mais lento que 2, porque a CPU fica parada nas esperas de rede,
 * upload e banco. Teste de estresse em 10 para descobrir até onde melhora;
 * se a CPU saturar, a RAM encostar no limite ou aparecer timeout, volte para
 * 2 ou 3. É o único lugar a mudar.
 */
export const PDF_RENDER_CONCURRENCY = 3;

@Injectable()
export class PdfGeneratorService implements OnModuleDestroy {
  // Um único Chromium para o processo inteiro. Abrir o navegador é a parte
  // mais cara em CPU (o VPS de produção tem 1 vCPU), então ele é aberto na
  // primeira geração e reaproveitado; cada PDF usa só uma página nova.
  private browserPromise: Promise<Browser> | null = null;
  private browser: Browser | null = null;
  private activeRenders = 0;
  private idleTimer: NodeJS.Timeout | null = null;

  private footerDataUrl: string | null = null;
  private simLogoDataUrl: string | null = null;
  private simLogoIconDataUrl: string | null = null;
  private certificateTemplate: HandlebarsTemplateDelegate | null = null;
  private assessmentReportTemplate: HandlebarsTemplateDelegate | null = null;

  // Sem esse limite, um "gerar todos" ou um job em lote (que também chama
  // renderCertificate/renderAssessmentReport sob demanda) abriria dezenas de
  // páginas em paralelo e estouraria CPU e RAM. Valor e histórico de
  // medições em PDF_RENDER_CONCURRENCY.
  private readonly limiter = pLimit(PDF_RENDER_CONCURRENCY);

  async renderCertificate(data: Record<string, any>): Promise<Buffer> {
    return this.limiter(() => this.renderCertificateInternal(data));
  }

  private async renderCertificateInternal(data: Record<string, any>): Promise<Buffer> {
    if (!this.certificateTemplate) {
      this.certificateTemplate = this.compileTemplate('certificate.html');
    }

    const html = this.certificateTemplate({
      ...data,
      footerDataUrl: this.getAssetDataUrl('footerDataUrl', 'cert-footer.png'),
      simLogoDataUrl: this.getAssetDataUrl('simLogoDataUrl', 'sim-logo.png'),
    });

    return this.renderPdf(html, { format: 'A4', landscape: true, printBackground: true });
  }

  async renderAssessmentReport(data: Record<string, any>): Promise<Buffer> {
    return this.limiter(() => this.renderAssessmentReportInternal(data));
  }

  private async renderAssessmentReportInternal(data: Record<string, any>): Promise<Buffer> {
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

    return this.renderPdf(html, { format: 'A4', landscape: false, printBackground: true });
  }

  async onModuleDestroy(): Promise<void> {
    this.cancelIdleClose();
    await this.closeBrowser();
  }

  private async renderPdf(html: string, options: PDFOptions): Promise<Buffer> {
    this.activeRenders++;
    this.cancelIdleClose();
    try {
      const browser = await this.getBrowser();
      try {
        return await this.renderInPage(browser, html, options);
      } catch (err) {
        // Se o navegador caiu no meio (falta de memória, processo morto), a
        // falha não é do documento: tenta uma vez com um Chromium novo.
        if (browser.connected) throw err;
        return await this.renderInPage(await this.getBrowser(), html, options);
      }
    } finally {
      this.activeRenders--;
      if (this.activeRenders === 0) this.scheduleIdleClose();
    }
  }

  private async renderInPage(browser: Browser, html: string, options: PDFOptions): Promise<Buffer> {
    const page = await browser.newPage();
    try {
      await page.setContent(html, { waitUntil: 'networkidle0' });
      return Buffer.from(await page.pdf(options));
    } finally {
      await page.close().catch(() => {});
    }
  }

  private getBrowser(): Promise<Browser> {
    if (!this.browserPromise) {
      const promise = this.launchBrowser();
      this.browserPromise = promise;
      // Falha ao abrir não fica em cache: a próxima geração tenta de novo.
      promise.catch(() => {
        if (this.browserPromise === promise) this.browserPromise = null;
      });
    }
    return this.browserPromise;
  }

  private async launchBrowser(): Promise<Browser> {
    let puppeteer: any;
    try {
      const mod = await import('puppeteer');
      puppeteer = mod.default;
    } catch (e: any) {
      throw new Error(`Puppeteer não encontrado: ${e.message}`);
    }

    let browser: Browser;
    try {
      browser = await puppeteer.launch({ args: BROWSER_ARGS });
    } catch (e: any) {
      throw new Error(`Falha ao iniciar Chromium (Puppeteer): ${e.message}`);
    }

    this.browser = browser;
    // Chromium morto ou desconectado: esquece a instância para a próxima
    // geração abrir outra. Só vale se ainda for o navegador corrente (um
    // fechamento deliberado já zerou os campos antes).
    browser.on('disconnected', () => {
      if (this.browser === browser) {
        this.browser = null;
        this.browserPromise = null;
      }
    });
    return browser;
  }

  private scheduleIdleClose(): void {
    this.cancelIdleClose();
    this.idleTimer = setTimeout(() => {
      this.idleTimer = null;
      void this.closeBrowser();
    }, BROWSER_IDLE_CLOSE_MS);
    // Não segura o processo vivo só por causa deste timer.
    this.idleTimer.unref();
  }

  private cancelIdleClose(): void {
    if (this.idleTimer) {
      clearTimeout(this.idleTimer);
      this.idleTimer = null;
    }
  }

  private async closeBrowser(): Promise<void> {
    const promise = this.browserPromise;
    this.browserPromise = null;
    this.browser = null;
    if (!promise) return;
    const browser = await promise.catch(() => null);
    await browser?.close().catch(() => {});
  }

  private compileTemplate(filename: string): HandlebarsTemplateDelegate {
    // Tenta primeiro em __dirname (dist/), depois sobe para src/ (ts-node / teste)
    const candidates = [
      path.join(__dirname, 'templates', filename),
      // build do Nest: os assets (html/png) vão para dist/certificates/templates,
      // fora de dist/src/ onde roda o código compilado
      path.join(__dirname, '..', '..', 'certificates', 'templates', filename),
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
      // build do Nest: os assets (html/png) vão para dist/certificates/templates,
      // fora de dist/src/ onde roda o código compilado
      path.join(__dirname, '..', '..', 'certificates', 'templates', filename),
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
