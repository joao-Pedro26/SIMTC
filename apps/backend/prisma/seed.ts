import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';

dotenv.config({ path: '.env.development' });

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL! });
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🌱 Seeding database...');

  // Admin user (Sebastião)
  const passwordHash = await bcrypt.hash('Admin@2025', 12);
  const admin = await prisma.user.upsert({
    where: { email: 'admin@simtc.com.br' },
    update: {},
    create: {
      email: 'admin@simtc.com.br',
      passwordHash,
      role: 'ADMIN',
    },
  });
  console.log('  ✓ Admin user:', admin.email);

  // Categorias de avaliação padrão
  const categories = [
    { code: 'CV', name: 'Controle do Veículo', order: 1 },
    { code: 'RR', name: 'Respeito às Regras', order: 2 },
    { code: 'CS', name: 'Comportamento Seguro', order: 3 },
    { code: 'TP', name: 'Técnica de Pista', order: 4 },
  ];

  for (const cat of categories) {
    await prisma.assessmentCategory.upsert({
      where: { code: cat.code },
      update: {},
      create: cat,
    });
    console.log(`  ✓ Categoria: ${cat.code} — ${cat.name}`);
  }

  console.log('✅ Seed concluído!');
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
