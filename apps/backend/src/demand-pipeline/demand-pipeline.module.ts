import { Module } from '@nestjs/common';
import { DemandPipelineController } from './demand-pipeline.controller';
import { DemandPipelineService } from './demand-pipeline.service';

@Module({
  controllers: [DemandPipelineController],
  providers: [DemandPipelineService],
  exports: [DemandPipelineService],
})
export class DemandPipelineModule {}
