import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';

dotenv.config({ path: '.env.development' });

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL! });
const prisma = new PrismaClient({ adapter });

// ── Infrações por categoria ────────────────────────────────────────────────────
// Cada item: { description, notes: Array<{ noteType, deduction, comment? }> }
// Deduções padrão: B=1, PM=3, M=5

const INFRACTIONS_BY_CATEGORY: Record<string, Array<{
  description: string;
  notes: Array<{ noteType: 'B' | 'PM' | 'M'; deduction: number; comment?: string }>;
}>> = {
  CV: [
    {
      description: 'Não ajustou o banco, cinto ou espelhos antes de partir',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Ajuste parcial' },
        { noteType: 'PM', deduction: 3, comment: 'Ajuste feito somente após solicitação' },
        { noteType: 'M',  deduction: 5, comment: 'Não realizou nenhum ajuste' },
      ],
    },
    {
      description: 'Posição incorreta das mãos no volante',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Leve desvio de posição' },
        { noteType: 'PM', deduction: 3, comment: 'Uma mão no volante com frequência' },
        { noteType: 'M',  deduction: 5, comment: 'Condução com postura totalmente inadequada' },
      ],
    },
    {
      description: 'Troca de marchas inadequada para a velocidade ou situação',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Pequeno atraso ou adiantamento na troca' },
        { noteType: 'PM', deduction: 3, comment: 'Marcha errada em situação de risco' },
        { noteType: 'M',  deduction: 5, comment: 'Condução prolongada em marcha errada' },
      ],
    },
    {
      description: 'Uso excessivo ou tardio do freio',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Frenagem um pouco brusca' },
        { noteType: 'PM', deduction: 3, comment: 'Frenagens frequentemente inadequadas' },
        { noteType: 'M',  deduction: 5, comment: 'Frenagem de emergência por falta de antecipação' },
      ],
    },
    {
      description: 'Aceleração brusca ou desnecessária',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Aceleração um pouco acentuada' },
        { noteType: 'PM', deduction: 3, comment: 'Acelerações abruptas recorrentes' },
        { noteType: 'M',  deduction: 5, comment: 'Arrancadas violentas ou perigosas' },
      ],
    },
    {
      description: 'Direção com uma só mão sem necessidade operacional',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Ocorrência pontual' },
        { noteType: 'PM', deduction: 3, comment: 'Hábito frequente' },
        { noteType: 'M',  deduction: 5, comment: 'Condução predominantemente com uma mão' },
      ],
    },
  ],

  RR: [
    {
      description: 'Desrespeitou sinalização de trânsito (semáforo, placa de parada)',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Desacelerou tarde, mas parou' },
        { noteType: 'PM', deduction: 3, comment: 'Ultrapassou sinalização com veículo em movimento lento' },
        { noteType: 'M',  deduction: 5, comment: 'Ignorou completamente a sinalização' },
      ],
    },
    {
      description: 'Não manteve distância de segurança do veículo à frente',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Distância ligeiramente abaixo do recomendado' },
        { noteType: 'PM', deduction: 3, comment: 'Distância insuficiente de forma recorrente' },
        { noteType: 'M',  deduction: 5, comment: 'Seguimento muito próximo com risco de colisão' },
      ],
    },
    {
      description: 'Ultrapassagem em local proibido ou sem condições de segurança',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Ultrapassagem em local duvidoso' },
        { noteType: 'PM', deduction: 3, comment: 'Ultrapassagem em local com faixa contínua' },
        { noteType: 'M',  deduction: 5, comment: 'Ultrapassagem gerando risco iminente' },
      ],
    },
    {
      description: 'Não sinalizou manobra com o pisca-alerta',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Acionou com atraso' },
        { noteType: 'PM', deduction: 3, comment: 'Esqueceu em manobra de risco' },
        { noteType: 'M',  deduction: 5, comment: 'Não sinaliza nenhuma manobra' },
      ],
    },
    {
      description: 'Velocidade acima da permitida na via',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Até 10 km/h acima do limite' },
        { noteType: 'PM', deduction: 3, comment: 'Entre 10 e 20 km/h acima do limite' },
        { noteType: 'M',  deduction: 5, comment: 'Acima de 20 km/h do limite' },
      ],
    },
    {
      description: 'Não cedeu passagem a pedestre na faixa',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Parou tarde, mas cedeu passagem' },
        { noteType: 'PM', deduction: 3, comment: 'Forçou o pedestre a interromper a travessia' },
        { noteType: 'M',  deduction: 5, comment: 'Não parou para o pedestre' },
      ],
    },
  ],

  CS: [
    {
      description: 'Realizou manobra sem verificar o ponto cego',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Verificou superficialmente' },
        { noteType: 'PM', deduction: 3, comment: 'Não verificou em manobra de risco moderado' },
        { noteType: 'M',  deduction: 5, comment: 'Executou manobra sem qualquer verificação' },
      ],
    },
    {
      description: 'Conduta impaciente ou agressiva com outros condutores',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Demonstrou impaciência leve' },
        { noteType: 'PM', deduction: 3, comment: 'Buzinou ou gesticulou de forma inadequada' },
        { noteType: 'M',  deduction: 5, comment: 'Comportamento agressivo com risco para terceiros' },
      ],
    },
    {
      description: 'Não reduziu velocidade em área de risco (escola, hospital, obras)',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Reduziu pouco abaixo do recomendado' },
        { noteType: 'PM', deduction: 3, comment: 'Manteve velocidade sem reduzir' },
        { noteType: 'M',  deduction: 5, comment: 'Acelerou em área de risco' },
      ],
    },
    {
      description: 'Distração durante a condução (celular, conversa, objetos)',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Distração breve em local seguro' },
        { noteType: 'PM', deduction: 3, comment: 'Distração em trânsito moderado' },
        { noteType: 'M',  deduction: 5, comment: 'Uso de celular ou distração prolongada em movimento' },
      ],
    },
    {
      description: 'Não realizou verificação de segurança antes de iniciar o veículo',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Verificação incompleta' },
        { noteType: 'PM', deduction: 3, comment: 'Ignorou itens relevantes' },
        { noteType: 'M',  deduction: 5, comment: 'Não realizou nenhuma verificação' },
      ],
    },
    {
      description: 'Condução sob influência de fadiga ou sinais de desatenção',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Sinais leves de cansaço' },
        { noteType: 'PM', deduction: 3, comment: 'Reações lentas em situações simples' },
        { noteType: 'M',  deduction: 5, comment: 'Desatenção grave comprometendo a segurança' },
      ],
    },
  ],

  TP: [
    {
      description: 'Velocidade excessiva na entrada de curvas',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Velocidade ligeiramente elevada' },
        { noteType: 'PM', deduction: 3, comment: 'Precisou corrigir a trajetória na curva' },
        { noteType: 'M',  deduction: 5, comment: 'Risco de saída de pista na curva' },
      ],
    },
    {
      description: 'Trajetória inadequada nas curvas',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Pequeno desvio da linha ideal' },
        { noteType: 'PM', deduction: 3, comment: 'Trajetória comprometeu a segurança' },
        { noteType: 'M',  deduction: 5, comment: 'Saiu da faixa ou invadiu a contramão' },
      ],
    },
    {
      description: 'Aceleração brusca na saída de curvas',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Aceleração um pouco acentuada' },
        { noteType: 'PM', deduction: 3, comment: 'Desequilíbrio do veículo na saída' },
        { noteType: 'M',  deduction: 5, comment: 'Perda de aderência ou derrapagem' },
      ],
    },
    {
      description: 'Frenagem tardia antes de curvas ou interseções',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Frenagem iniciada um pouco tarde' },
        { noteType: 'PM', deduction: 3, comment: 'Entrou na curva mais rápido que o seguro' },
        { noteType: 'M',  deduction: 5, comment: 'Necessitou de correção de emergência' },
      ],
    },
    {
      description: 'Troca de faixa sem sinalização e verificação prévia',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Sinalizou mas não verificou o ponto cego' },
        { noteType: 'PM', deduction: 3, comment: 'Não sinalizou em troca de baixo risco' },
        { noteType: 'M',  deduction: 5, comment: 'Troca brusca sem sinalização gerando risco' },
      ],
    },
    {
      description: 'Posicionamento incorreto na faixa (muito à esquerda ou direita)',
      notes: [
        { noteType: 'B',  deduction: 1, comment: 'Leve desvio de posicionamento' },
        { noteType: 'PM', deduction: 3, comment: 'Posicionamento frequentemente fora do centro' },
        { noteType: 'M',  deduction: 5, comment: 'Invasão de faixa adjacente ou acostamento' },
      ],
    },
  ],
};

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log('🌱 Seeding database...');

  // ── Admin user (Sebastião) ─────────────────────────────────────────────────
  const passwordHash = await bcrypt.hash('Admin@2025', 12);

  const adminConsultant = await prisma.consultant.upsert({
    where: { email: 'admin@simtc.com.br' },
    update: {},
    create: { name: 'Sebastião', email: 'admin@simtc.com.br' },
  });

  const admin = await prisma.user.upsert({
    where: { email: 'admin@simtc.com.br' },
    update: { consultantId: adminConsultant.id },
    create: {
      email: 'admin@simtc.com.br',
      passwordHash,
      role: 'ADMIN',
      consultantId: adminConsultant.id,
    },
  });
  console.log('  ✓ Admin:', admin.email, '(consultantId:', admin.consultantId, ')');

  // ── Categorias de avaliação ────────────────────────────────────────────────
  const categories = [
    { code: 'CV', name: 'Controle do Veículo',  order: 1, description: null },
    {
      code: 'RR', name: 'Respeito às Regras',   order: 2,
      description: 'O trânsito é um “jogo” e as apostas são altíssimas: ou ganha-se muito, ou perde-se muito! No trânsito, há regras que devem ser seguidas. Na parte prática o objetivo foi verificar sua aptidão de perceber e obedecer às regras e sinalizações (disciplina). A indisciplina, por distração ou descuido, nos expõe a dois riscos indesejados: às multas e aos sinistros de trânsito. Portanto, tenha atenção e cuidado!',
    },
    {
      code: 'CS', name: 'Comportamento Seguro', order: 3,
      description: 'Posicionar-se com segurança na via é, sem dúvidas, uma das principais vantagens de um condutor prudente. Lembre-se: um correto posicionamento nos faz evitar diversos riscos indesejados, pois teremos mais espaços para executar as decisões tomadas, teremos mais visibilidade e melhor controle da situação.',
    },
    { code: 'TP', name: 'Técnica de Pista',     order: 4, description: null },
  ];

  for (const cat of categories) {
    const saved = await prisma.assessmentCategory.upsert({
      where: { code: cat.code },
      update: { name: cat.name, order: cat.order, description: cat.description },
      create: cat,
    });
    console.log(`  ✓ Categoria: ${cat.code} — ${cat.name}`);

    // ── Infrações da categoria ─────────────────────────────────────────────
    const infractions = INFRACTIONS_BY_CATEGORY[cat.code] ?? [];
    if (infractions.length === 0) continue;

    // Só cria se a categoria ainda não tem nenhuma infração
    const existing = await prisma.infraction.count({ where: { categoryId: saved.id } });
    if (existing > 0) {
      console.log(`    ↳ ${existing} infrações já existentes — pulando`);
      continue;
    }

    for (let i = 0; i < infractions.length; i++) {
      const inf = infractions[i];
      const created = await prisma.infraction.create({
        data: {
          categoryId: saved.id,
          description: inf.description,
          order: i + 1,
        },
      });

      for (const note of inf.notes) {
        await prisma.infractionNote.create({
          data: {
            infractionId: created.id,
            noteType: note.noteType,
            deduction: note.deduction,
            comment: note.comment,
          },
        });
      }

      console.log(`    ↳ [${i + 1}] ${inf.description}`);
    }
  }

  // ── Textos de fechamento do relatório (por faixa de percentual geral) ──────
  // ATENÇÃO: apenas a faixa 76–100 abaixo é texto REAL, extraído do PDF de
  // referência (assets/relatorios/20240708 - Erica dos Santos Gomes.pdf).
  // As faixas 0–50 e 51–75 são RASCUNHO/PLACEHOLDER escrito para preencher o
  // mecanismo enquanto Sebastião não fecha a redação final — não enviar ao
  // aluno sem revisão dele. Cortes das faixas (0–50/51–75/76–100) também são
  // ilustrativos, dados por ele em 26/08/2026, não confirmados como finais.
  const conclusionTexts = [
    {
      minPercent: 0,
      maxPercent: 50,
      text: [
        'O objetivo da observação, era verificar sua técnica, a forma como você se posiciona na via e, também, ver como você gerencia os riscos ao seu redor enquanto dirige. Durante o percurso avaliado, identificamos diversos pontos que precisam de atenção imediata, descritos acima, e recomendamos fortemente que sejam revistos antes de uma nova avaliação.',
        'Durante um percurso com um veículo, é possível dirigir com economia, conforto e segurança. Neste momento, a prioridade deve ser corrigir os procedimentos indicados nesta avaliação, de forma a reduzir os riscos identificados e aumentar sua segurança e a de terceiros no trânsito.',
        'Recomendamos a reavaliação após a revisão dos pontos apontados, para que possamos confirmar sua evolução e segurança na condução.',
        'Agradecemos sua participação e ficamos à disposição para auxiliar no que for necessário!',
      ].join('\n\n'),
    },
    {
      minPercent: 51,
      maxPercent: 75,
      text: [
        'O objetivo da observação, era verificar sua técnica, a forma como você se posiciona na via e, também, ver como você gerencia os riscos ao seu redor enquanto dirige. Durante o percurso avaliado, identificamos alguns pontos de atenção, descritos acima, que merecem ser revistos para elevar o seu nível de segurança na condução.',
        'Durante um percurso com um veículo, é possível dirigir com economia, conforto e segurança. Recomendamos que você dedique atenção especial aos pontos observados nesta avaliação, buscando corrigir os procedimentos indicados para tornar sua condução mais segura no dia a dia.',
        'Desejamos que esta avaliação atenda às suas expectativas e que os resultados dela possam contribuir para aprimorar sua performance no trânsito.',
        'Agradecemos sua participação e até uma próxima oportunidade!',
      ].join('\n\n'),
    },
    {
      // Texto real, verbatim do PDF de referência (score 80%, "Aprovado").
      minPercent: 76,
      maxPercent: 100,
      text: [
        'O objetivo da observação, era verificar sua técnica, a forma como você se posiciona na via e, também, ver como você gerencia os riscos ao seu redor enquanto dirige. Após observação durante o trajeto percorrido na prática veicular, propomos que você reveja os procedimentos comentados acima, essas recomendações, irão aumentar sua segurança!',
        'Durante um percurso com um veículo, é possível dirigir com economia, conforto e segurança. Propomos que segurança seja a opção predominante. A segurança é a opção que irá proporcionar as maiores chances de preservar a sua integridade física e também do veículo. As técnicas indicadas, tornarão suas viagens mais seguras.',
        'Desejamos que esta avaliação atenda às suas expectativas e que os resultados dela possam contribuir para aprimorar sua performance no trânsito.',
        'Agradecemos sua participação e até uma próxima oportunidade!',
      ].join('\n\n'),
    },
  ];

  for (const ct of conclusionTexts) {
    await prisma.reportConclusionText.upsert({
      where: { minPercent_maxPercent: { minPercent: ct.minPercent, maxPercent: ct.maxPercent } },
      update: { text: ct.text },
      create: ct,
    });
    console.log(`  ✓ Texto de fechamento: ${ct.minPercent}–${ct.maxPercent}%`);
  }

  console.log('✅ Seed concluído!');
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
