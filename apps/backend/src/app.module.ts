import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { CompaniesModule } from './companies/companies.module';
import { ConsultantsModule } from './consultants/consultants.module';
import { CoursesModule } from './courses/courses.module';
import { AssessmentCategoriesModule } from './assessment-categories/assessment-categories.module';
import { DemandPipelineModule } from './demand-pipeline/demand-pipeline.module';
import { TrainingSessionsModule } from './training-sessions/training-sessions.module';
import { ParticipantsModule } from './participants/participants.module';
import { PracticalAssessmentsModule } from './practical-assessments/practical-assessments.module';
import { CertificatesModule } from './certificates/certificates.module';
import { ReportsModule } from './reports/reports.module';
import { StorageModule } from './storage/storage.module';
import { EmailModule } from './email/email.module';
import { UsersModule } from './users/users.module';
import { JobsModule } from './jobs/jobs.module';

@Module({
  imports: [
    // Configuração de variáveis de ambiente
    // envFilePath diz ao NestJS qual arquivo .env carregar.
    // Sem isso ele leria .env (padrão), mas nosso arquivo é .env.development.
    ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env.development' }),

    // Rate limiting — proteção para a rota pública de inscrição
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 10 }]),

    // Infraestrutura
    PrismaModule,
    StorageModule,
    EmailModule,
    JobsModule,

    // Domínio
    AuthModule,
    CompaniesModule,
    ConsultantsModule,
    CoursesModule,
    AssessmentCategoriesModule,
    DemandPipelineModule,
    TrainingSessionsModule,
    ParticipantsModule,
    PracticalAssessmentsModule,
    CertificatesModule,
    ReportsModule,
    UsersModule,
  ],
})
export class AppModule {}
