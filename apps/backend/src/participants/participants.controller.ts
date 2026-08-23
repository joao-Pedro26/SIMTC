import { Controller, Get, Post, Param, Body, UseGuards, Patch, Delete } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ParticipantsService } from './participants.service';
import { UserRole } from '@simtc/shared-types';
import { ValidateCpfPipe } from '../common/pipes/validate-cpf.pipe';
import { AddParticipantDto } from './dto/add-participant.dto';
import { Roles } from 'src/auth/decorators/roles.decorator';
import { RolesGuard } from 'src/auth/guards/roles.guard';

@ApiTags('participants')
@Controller()
export class ParticipantsController {
  constructor(private readonly service: ParticipantsService) {}

  @Get('training-sessions/:id/participants')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  findBySession(@Param('id') trainingSessionId: string) {
    return this.service.findBySession(trainingSessionId);
  }

  @Post('training-sessions/:id/participants')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  addParticipant(
    @Param('id') trainingSessionId: string,
    @Body('cpf', ValidateCpfPipe) _cpf: string,
    @Body() dto: AddParticipantDto,
  ) {
    return this.service.addParticipant(trainingSessionId, dto);
  }

  @Delete('participants/:participantId')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  removeParticipant(@Param('participantId') participantId: string) {
    return this.service.removeParticipant(participantId);
  }
  
}
