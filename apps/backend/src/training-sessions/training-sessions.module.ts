import { Module } from '@nestjs/common';
import { TrainingSessionsController } from './training-sessions.controller';
import { TrainingSessionsService } from './training-sessions.service';
import { QrCodeService } from './qr-code.service';
import { EmailModule } from '../email/email.module';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [EmailModule, StorageModule],
  controllers: [TrainingSessionsController],
  providers: [TrainingSessionsService, QrCodeService],
  exports: [TrainingSessionsService],
})
export class TrainingSessionsModule {}
