import { Module } from '@nestjs/common';
import { PracticalAssessmentsController } from './practical-assessments.controller';
import { PracticalAssessmentsService } from './practical-assessments.service';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [StorageModule],
  controllers: [PracticalAssessmentsController],
  providers: [PracticalAssessmentsService],
  exports: [PracticalAssessmentsService],
})
export class PracticalAssessmentsModule {}
