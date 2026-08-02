import { Controller, Get, Post, Param, Body, UseGuards } from '@nestjs/common';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { ParticipantsService } from './participants.service';
import { RegisterParticipantPublicDto } from '@simtc/shared-types';

@ApiTags('public')
@Controller('public')
export class PublicRegisterController {
  constructor(private readonly service: ParticipantsService) {}

  @Get('training-sessions/by-token/:qrToken')
  @ApiOperation({ summary: 'Busca dados da sessão pelo QR token — sem autenticação' })
  getSessionByToken(@Param('qrToken') qrToken: string) {
    return this.service.findByToken(qrToken);
  }

  @Post('register/:qrToken')
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: 10, ttl: 3600_000 } })
  @ApiOperation({ summary: 'Formulário público de inscrição via QR Code — sem autenticação' })
  register(
    @Param('qrToken') qrToken: string,
    @Body() dto: RegisterParticipantPublicDto,
  ) {
    return this.service.registerPublic(qrToken, dto);
  }
}
