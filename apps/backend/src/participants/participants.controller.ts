import { Controller, Get, Post, Param, Body, UseGuards, Patch, Delete, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ParticipantsService } from './participants.service';
import { UserRole } from '@simtc/shared-types';
import { ValidateCpfPipe } from '../common/pipes/validate-cpf.pipe';
import { AddParticipantDto } from './dto/add-participant.dto';
import { LookupParticipantDto } from './dto/lookup-participant.dto';
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

  /**
   * Consulta de CPF da tela "Adicionar participante" do app mobile. É POST
   * para o CPF viajar no corpo, e não na URL (que acaba em log de servidor).
   * O `ValidateCpfPipe` é chamado à mão, depois que o `ValidationPipe` global
   * já garantiu que `cpf` é texto: devolve o CPF só com dígitos, que é como
   * ele está gravado.
   */
  @Post('training-sessions/:id/participants/lookup')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Consulta um CPF antes de adicionar: já tem cadastro? já está nesta sessão?' })
  lookupParticipant(
    @Param('id') trainingSessionId: string,
    @Body() dto: LookupParticipantDto,
  ) {
    const cpf = new ValidateCpfPipe().transform(dto.cpf);
    return this.service.lookupByCpf(trainingSessionId, cpf);
  }

  @Delete('participants/:participantId')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  removeParticipant(@Param('participantId') participantId: string) {
    return this.service.removeParticipant(participantId);
  }
  
}
