import { Module } from '@nestjs/common';
import { CertificatesController } from './certificates.controller';
import { CertificatesService } from './certificates.service';
import { PdfGeneratorService } from './pdf-generator.service';
import { StorageModule } from '../storage/storage.module';
import { EmailModule } from '../email/email.module';

@Module({
  imports: [StorageModule, EmailModule],
  controllers: [CertificatesController],
  providers: [CertificatesService, PdfGeneratorService],
  exports: [CertificatesService],
})
export class CertificatesModule {}
