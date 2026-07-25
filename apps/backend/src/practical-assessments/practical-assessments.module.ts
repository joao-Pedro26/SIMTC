import { Module } from '@nestjs/common';
import { PracticalAssessmentsController } from './practical-assessments.controller';
import { PracticalAssessmentsService } from './practical-assessments.service';

@Module({
  controllers: [PracticalAssessmentsController],
  providers: [PracticalAssessmentsService],
  exports: [PracticalAssessmentsService],
})
export class PracticalAssessmentsModule {}
