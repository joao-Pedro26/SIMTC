import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ParticipantsService } from './participants.service';

@ApiTags('participants')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class ParticipantsController {
  constructor(private readonly service: ParticipantsService) {}

  @Get('training-sessions/:id/participants')
  findBySession(@Param('id') trainingSessionId: string) {
    return this.service.findBySession(trainingSessionId);
  }
}
