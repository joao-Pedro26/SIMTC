import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  constructor() {
    // Prisma v7 removeu o driver nativo de PostgreSQL — agora você precisa
    // fornecer um driver explicitamente via "adapter". Usamos o PrismaPg,
    // que usa a biblioteca `pg` por baixo dos panos.
    // O DATABASE_URL (pooler) já está no process.env graças ao ConfigModule.
    const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL! });
    super({ adapter });
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
