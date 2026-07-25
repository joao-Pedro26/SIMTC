import { Controller, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { DemandPipelineService } from './demand-pipeline.service';

@ApiTags('demand-pipeline')
@UseGuards(JwtAuthGuard)
@Controller('demand-pipeline')
export class DemandPipelineController {
  constructor(private readonly service: DemandPipelineService) {}
}
