import {
  BadRequestException,
  Body,
  Controller,
  Get,
  MaxFileSizeValidator,
  NotFoundException,
  Param,
  ParseFilePipe,
  Patch,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody, ApiConsumes } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtPayload, SyncPracticalAssessmentDto, UserRole } from '@simtc/shared-types';
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

  // CLIENT recebe o id da avaliação em GET /reports/training-sessions/:id, por isso
  // as rotas de assinatura exigem ADMIN ou CONSULTANT (decisão de 17/09/2026).
  @Patch(':id/participant-signature')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @ApiOperation({ summary: 'Envia a assinatura do participante (PNG/JPEG, até 2 MB) capturada no app mobile' })
  uploadParticipantSignature(
    @Param('id') id: string,
    @UploadedFile(new ParseFilePipe({
      validators: [new MaxFileSizeValidator({ maxSize: 2 * 1024 * 1024 })],
    }))
    file: Express.Multer.File,
  ) {
    if (!/^image\/(png|jpeg)$/.test(file.mimetype)) {
      throw new BadRequestException('Tipo de arquivo inválido. Aceito: PNG, JPEG.');
    }
    return this.service.uploadParticipantSignature(id, file.buffer, file.mimetype);
  }

  @Get(':id/participant-signature-url')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  @ApiOperation({ summary: 'Signed URL (1h) da assinatura do participante' })
  async getParticipantSignatureUrl(@Param('id') id: string) {
    const result = await this.service.getParticipantSignatureSignedUrl(id);
    if (!result) throw new NotFoundException('Sem assinatura do participante cadastrada');
    return result;
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }
}
