import { Controller, Get, Post, Param, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtPayload, SyncPracticalAssessmentDto } from '@simtc/shared-types';
import { PracticalAssessmentsService } from './practical-assessments.service';
import { AssignParticipantsDto } from './dto/assign-participants.dto';

@ApiTags('practical-assessments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('practical-assessments')
export class PracticalAssessmentsController {
  constructor(private readonly service: PracticalAssessmentsService) {}

  @Post('assign')
  @ApiOperation({ summary: 'Atribui participantes ao consultor/admin logado para avaliação' })
  assign(@Body() dto: AssignParticipantsDto, @CurrentUser() user: JwtPayload) {
    // Passa consultantId do JWT (se existir) + userId como fallback para admins
    return this.service.assignParticipants(dto, user.consultantId, user.sub);
  }

  @Post('sync')
  @ApiOperation({ summary: 'Salva avaliações (web ou sync offline do mobile)' })
  sync(@Body() dtos: SyncPracticalAssessmentDto[], @CurrentUser() user: JwtPayload) {
    // No web, o consultantId sempre vem do JWT para evitar impersonação
    return this.service.syncFromMobile(dtos, user.consultantId, user.sub);
  }

  @Get('by-participant/:trainingParticipantId')
  @ApiOperation({ summary: 'Retorna avaliação existente do participante, ou null' })
  findByParticipant(@Param('trainingParticipantId') trainingParticipantId: string) {
    return this.service.findByParticipant(trainingParticipantId);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }
}
