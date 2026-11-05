import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Atrás do proxy do EasyPanel: sem trust proxy, req.ip é sempre o IP do proxy
  // e o throttle vira um limite global em vez de por cliente.
  app.set('trust proxy', 1);

  // Prefixo global da API
  app.setGlobalPrefix('api');

  // Validação automática dos DTOs
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  // CORS — permite requisições do frontend
  app.enableCors({
    origin: process.env.FRONTEND_URL ?? 'http://localhost:3000',
    credentials: true,
  });

  // Swagger (apenas em desenvolvimento)
  if (process.env.NODE_ENV !== 'production') {
    const config = new DocumentBuilder()
      .setTitle('SIMTC API')
      .setDescription('API do sistema de treinamentos SIM Treinamentos')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('docs', app, document);
  }

  const port = process.env.PORT ?? 3001;
  await app.listen(port);
  console.log(`🚀 SIMTC API rodando em: http://localhost:${port}/api`);
}

bootstrap();
