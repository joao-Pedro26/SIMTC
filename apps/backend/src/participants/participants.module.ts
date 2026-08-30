import { Module } from '@nestjs/common';
import { ParticipantsController } from './participants.controller';
import { ParticipantsService } from './participants.service';
import { PublicRegisterController } from './public-register.controller';
import { BulkActionsController } from './bulk-actions.controller';
import { BulkActionsService } from './bulk-actions.service';
import { EmailModule } from '../email/email.module';
import { StorageModule } from '../storage/storage.module';
import { CertificatesModule } from '../certificates/certificates.module';
import { JobsModule } from '../jobs/jobs.module';

@Module({
  imports: [EmailModule, StorageModule, CertificatesModule, JobsModule],
  controllers: [ParticipantsController, PublicRegisterController, BulkActionsController],
  providers: [ParticipantsService, BulkActionsService],
  exports: [ParticipantsService],
})
export class ParticipantsModule {}
