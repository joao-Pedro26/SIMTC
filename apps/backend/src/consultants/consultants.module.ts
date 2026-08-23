import { Module } from '@nestjs/common';
import { ConsultantsController } from './consultants.controller';
import { ConsultantsService } from './consultants.service';
import { StorageModule } from '../storage/storage.module';
import { EmailModule } from '../email/email.module';

@Module({
  imports: [StorageModule, EmailModule],
  controllers: [ConsultantsController],
  providers: [ConsultantsService],
  exports: [ConsultantsService],
})
export class ConsultantsModule {}
