import { Controller, Get, Post, Param, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ParticipantsService } from './participants.service';
import { RegisterParticipantPublicDto } from '@simtc/shared-types';
import { ValidateCpfPipe } from '../common/pipes/validate-cpf.pipe';

@ApiTags('participants')
@Controller()
export class ParticipantsController {
  constructor(private readonly service: ParticipantsService) {}

  @Post('public/register/:qrToken')
  registerPublic(
    @Param('qrToken') qrToken: string,
    @Body('cpf', ValidateCpfPipe) _cpf: string,
    @Body() dto: RegisterParticipantPublicDto,
  ) {
    return this.service.registerPublic(qrToken, dto);
  }

  @Get('training-sessions/:id/participants')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  findBySession(@Param('id') trainingSessionId: string) {
    return this.service.findBySession(trainingSessionId);
  }
}
