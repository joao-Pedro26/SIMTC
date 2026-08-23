import { defineConfig } from 'prisma/config';
import { config } from 'dotenv';

// Carrega o .env.development para que o Prisma CLI encontre as variáveis
// (o Prisma leria .env por padrão, mas nosso arquivo de dev tem outro nome)
config({ path: '.env.development' });

export default defineConfig({
  migrations: {
    seed: 'ts-node ./prisma/seed.ts',
  },
  datasource: {
    // DIRECT_URL: conexão direta ao banco, necessária para migrations.
    // DATABASE_URL (pooler) não funciona para migrations pois o PgBouncer
    // bloqueia alguns comandos DDL que o Prisma precisa executar.
    url: process.env.DIRECT_URL,
  },
});
