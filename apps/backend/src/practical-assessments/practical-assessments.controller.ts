import { Controller, Get, Post, Param, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PracticalAssessmentsService } from './practical-assessments.service';
import { SyncPracticalAssessmentDto } from '@simtc/shared-types';

@ApiTags('practical-assessments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('practical-assessments')
export class PracticalAssessmentsController {
  constructor(private readonly service: PracticalAssessmentsService) {}

  @Post('sync')
  @ApiOperation({ summary: 'Recebe avaliações em lote do app mobile (sync offline → servidor)' })
  sync(@Body() dtos: SyncPracticalAssessmentDto[]) {
    return this.service.syncFromMobile(dtos);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }
}
