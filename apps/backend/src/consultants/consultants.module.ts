import { Module } from '@nestjs/common';
import { ConsultantsController } from './consultants.controller';
import { ConsultantsService } from './consultants.service';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [StorageModule],
  controllers: [ConsultantsController],
  providers: [ConsultantsService],
  exports: [ConsultantsService],
})
export class ConsultantsModule {}
