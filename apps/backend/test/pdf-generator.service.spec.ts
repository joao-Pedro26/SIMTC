import { PdfGeneratorService, PDF_RENDER_CONCURRENCY } from 'src/certificates/pdf-generator.service';

const mockLaunch = jest.fn();
jest.mock('puppeteer', () => ({ default: { launch: (...args: any[]) => mockLaunch(...args) } }));

type FakeBrowser = {
  connected: boolean;
  newPage: jest.Mock;
  close: jest.Mock;
  on: jest.Mock;
  emitDisconnected: () => void;
};

function makePage(overrides: { pdf?: jest.Mock } = {}) {
  return {
    setContent: jest.fn().mockResolvedValue(undefined),
    pdf: overrides.pdf ?? jest.fn().mockResolvedValue(new Uint8Array([1, 2, 3])),
    close: jest.fn().mockResolvedValue(undefined),
  };
}

function makeBrowser(pageFactory: () => ReturnType<typeof makePage> = () => makePage()): FakeBrowser {
  const handlers: Array<() => void> = [];
  const browser: FakeBrowser = {
    connected: true,
    newPage: jest.fn().mockImplementation(async () => pageFactory()),
    close: jest.fn().mockImplementation(async () => {
      browser.connected = false;
      browser.emitDisconnected();
    }),
    on: jest.fn().mockImplementation((event: string, cb: () => void) => {
      if (event === 'disconnected') handlers.push(cb);
    }),
    emitDisconnected: () => handlers.forEach((cb) => cb()),
  };
  return browser;
}

describe('PdfGeneratorService', () => {
  let service: PdfGeneratorService;

  beforeEach(() => {
    mockLaunch.mockReset();
    service = new PdfGeneratorService();
  });

  afterEach(async () => {
    await service.onModuleDestroy();
    jest.useRealTimers();
  });

  it('reaproveita o mesmo Chromium entre certificados e relatórios', async () => {
    const pages: ReturnType<typeof makePage>[] = [];
    const browser = makeBrowser(() => {
      const page = makePage();
      pages.push(page);
      return page;
    });
    mockLaunch.mockResolvedValue(browser);

    const cert = await service.renderCertificate({});
    const report = await service.renderAssessmentReport({});
    await service.renderCertificate({});

    expect(Buffer.isBuffer(cert)).toBe(true);
    expect(Buffer.isBuffer(report)).toBe(true);
    expect(mockLaunch).toHaveBeenCalledTimes(1);
    expect(browser.newPage).toHaveBeenCalledTimes(3);
    pages.forEach((page) => expect(page.close).toHaveBeenCalledTimes(1));
    expect(browser.close).not.toHaveBeenCalled();
  });

  it('mantém a orientação de cada documento (certificado paisagem, relatório retrato)', async () => {
    const pages: ReturnType<typeof makePage>[] = [];
    mockLaunch.mockResolvedValue(
      makeBrowser(() => {
        const page = makePage();
        pages.push(page);
        return page;
      }),
    );

    await service.renderCertificate({});
    await service.renderAssessmentReport({});

    expect(pages[0].pdf).toHaveBeenCalledWith({ format: 'A4', landscape: true, printBackground: true });
    expect(pages[1].pdf).toHaveBeenCalledWith(
      expect.objectContaining({ format: 'A4', landscape: false, printBackground: true }),
    );
  });

  it('põe o mês do relatório no rodapé nativo do PDF, que se repete em todas as folhas', async () => {
    const page = makePage();
    mockLaunch.mockResolvedValue(makeBrowser(() => page));

    await service.renderAssessmentReport({ footerMonth: 'Novembro/2026' });

    const options = page.pdf.mock.calls[0][0];
    expect(options.displayHeaderFooter).toBe(true);
    expect(options.footerTemplate).toContain('Novembro/2026');
    // Sem cabeçalho: o padrão do Chromium imprimiria data e título da página.
    expect(options.headerTemplate).not.toMatch(/class="(date|title)"/);
  });

  it('repete ícone, título e topo da faixa cinza no cabeçalho de todas as folhas do relatório', async () => {
    const page = makePage();
    mockLaunch.mockResolvedValue(makeBrowser(() => page));

    await service.renderAssessmentReport({});

    const { headerTemplate } = page.pdf.mock.calls[0][0];
    expect(headerTemplate).toMatch(/<img src="data:image\/png;base64,/);
    expect(headerTemplate).toContain('Avaliação Técnica de Direção Veicular');
    expect(headerTemplate).toMatch(/<path d="M 60\.646 68\.206/);
    expect(headerTemplate).toContain('fill="#EAE8E8"');
  });

  it('escapa o mês no rodapé do relatório (o template do rodapé é HTML)', async () => {
    const page = makePage();
    mockLaunch.mockResolvedValue(makeBrowser(() => page));

    await service.renderAssessmentReport({ footerMonth: '<b>x</b>' });

    const { footerTemplate } = page.pdf.mock.calls[0][0];
    expect(footerTemplate).toContain('&lt;b&gt;x&lt;/b&gt;');
    expect(footerTemplate).not.toContain('<b>');
  });

  it('fecha a página mesmo quando a geração do PDF falha, e segue usando o mesmo navegador', async () => {
    const failing = makePage({ pdf: jest.fn().mockRejectedValue(new Error('pdf quebrou')) });
    const pages = [failing];
    const browser = makeBrowser(() => pages.shift() ?? makePage());
    mockLaunch.mockResolvedValue(browser);

    await expect(service.renderCertificate({})).rejects.toThrow('pdf quebrou');
    expect(failing.close).toHaveBeenCalledTimes(1);

    await expect(service.renderCertificate({})).resolves.toBeInstanceOf(Buffer);
    expect(mockLaunch).toHaveBeenCalledTimes(1);
  });

  it('renderiza no máximo PDF_RENDER_CONCURRENCY páginas ao mesmo tempo', async () => {
    let running = 0;
    let peak = 0;
    const slowPdf = jest.fn().mockImplementation(async () => {
      running++;
      peak = Math.max(peak, running);
      await new Promise((resolve) => setTimeout(resolve, 10));
      running--;
      return new Uint8Array([1]);
    });
    mockLaunch.mockResolvedValue(makeBrowser(() => makePage({ pdf: slowPdf })));

    const total = PDF_RENDER_CONCURRENCY * 2 + 1;
    await Promise.all(Array.from({ length: total }, () => service.renderCertificate({})));

    expect(slowPdf).toHaveBeenCalledTimes(total);
    expect(peak).toBe(PDF_RENDER_CONCURRENCY);
    expect(mockLaunch).toHaveBeenCalledTimes(1);
  });

  it('abre um navegador novo depois que o anterior desconecta', async () => {
    const first = makeBrowser();
    const second = makeBrowser();
    mockLaunch.mockResolvedValueOnce(first).mockResolvedValueOnce(second);

    await service.renderCertificate({});
    first.connected = false;
    first.emitDisconnected();
    await service.renderCertificate({});

    expect(mockLaunch).toHaveBeenCalledTimes(2);
    expect(first.newPage).toHaveBeenCalledTimes(1);
    expect(second.newPage).toHaveBeenCalledTimes(1);
  });

  it('tenta uma vez de novo com navegador novo se o Chromium cai no meio da geração', async () => {
    const dying = makeBrowser();
    dying.newPage.mockImplementation(async () => {
      dying.connected = false;
      dying.emitDisconnected();
      throw new Error('Connection closed');
    });
    const healthy = makeBrowser();
    mockLaunch.mockResolvedValueOnce(dying).mockResolvedValueOnce(healthy);

    await expect(service.renderCertificate({})).resolves.toBeInstanceOf(Buffer);

    expect(mockLaunch).toHaveBeenCalledTimes(2);
    expect(healthy.newPage).toHaveBeenCalledTimes(1);
  });

  it('não repete a geração quando o erro não é de navegador caído', async () => {
    const page = makePage({ pdf: jest.fn().mockRejectedValue(new Error('template inválido')) });
    const browser = makeBrowser(() => page);
    mockLaunch.mockResolvedValue(browser);

    await expect(service.renderAssessmentReport({})).rejects.toThrow('template inválido');
    expect(browser.newPage).toHaveBeenCalledTimes(1);
  });

  it('não guarda em cache uma falha ao abrir o Chromium', async () => {
    mockLaunch.mockRejectedValueOnce(new Error('sem memória')).mockResolvedValueOnce(makeBrowser());

    await expect(service.renderCertificate({})).rejects.toThrow('Falha ao iniciar Chromium (Puppeteer): sem memória');
    await expect(service.renderCertificate({})).resolves.toBeInstanceOf(Buffer);
    expect(mockLaunch).toHaveBeenCalledTimes(2);
  });

  it('fecha o Chromium depois de 60 s sem gerar PDF e abre outro na próxima geração', async () => {
    jest.useFakeTimers();
    const first = makeBrowser();
    const second = makeBrowser();
    mockLaunch.mockResolvedValueOnce(first).mockResolvedValueOnce(second);

    await service.renderCertificate({});
    await jest.advanceTimersByTimeAsync(59_000);
    expect(first.close).not.toHaveBeenCalled();

    await jest.advanceTimersByTimeAsync(1_000);
    expect(first.close).toHaveBeenCalledTimes(1);

    await service.renderCertificate({});
    expect(mockLaunch).toHaveBeenCalledTimes(2);
    expect(second.newPage).toHaveBeenCalledTimes(1);
  });

  it('uma nova geração dentro dos 60 s adia o fechamento', async () => {
    jest.useFakeTimers();
    const browser = makeBrowser();
    mockLaunch.mockResolvedValue(browser);

    await service.renderCertificate({});
    await jest.advanceTimersByTimeAsync(50_000);
    await service.renderCertificate({});
    await jest.advanceTimersByTimeAsync(50_000);

    expect(browser.close).not.toHaveBeenCalled();
    expect(mockLaunch).toHaveBeenCalledTimes(1);
  });

  it('fecha o Chromium ao desligar o módulo', async () => {
    const browser = makeBrowser();
    mockLaunch.mockResolvedValue(browser);

    await service.renderCertificate({});
    await service.onModuleDestroy();

    expect(browser.close).toHaveBeenCalledTimes(1);
  });
});
