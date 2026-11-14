import { Controller, Get, Post, Param, Body, UseGuards, Patch, Delete, HttpCode, HttpStatus, Inject, MaxFileSizeValidator, ParseFilePipe, StreamableFile, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ParticipantsService } from './participants.service';
import { PARTICIPANT_IMPORT_MAX_BYTES, UserRole } from '@simtc/shared-types';
import { ValidateCpfPipe } from '../common/pipes/validate-cpf.pipe';
import { AddParticipantDto } from './dto/add-participant.dto';
import { ImportParticipantsBodyDto } from './dto/import-participants.dto';
import { LookupParticipantDto } from './dto/lookup-participant.dto';
import { UpdateParticipantTypeDto } from './dto/update-participant-type.dto';
import { ParticipantImportService } from './import/participant-import.service';
import { buildParticipantImportTemplate } from './import/participant-import.template';
import { Roles } from 'src/auth/decorators/roles.decorator';
import { RolesGuard } from 'src/auth/guards/roles.guard';

@ApiTags('participants')
@Controller()
export class ParticipantsController {
  constructor(private readonly service: ParticipantsService) {}

  // Injeção por propriedade: o construtor continua com um argumento só, que é
  // como os specs existentes instanciam o controller.
  @Inject(ParticipantImportService)
  private readonly importService!: ParticipantImportService;

  @Get('training-sessions/:id/participants')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  findBySession(@Param('id') trainingSessionId: string) {
    return this.service.findBySession(trainingSessionId);
  }

  /**
   * O CPF segue para o service só com dígitos, que é como ele está gravado:
   * um CPF com máscara não pode criar um segundo cadastro. Como na consulta
   * abaixo, o `ValidateCpfPipe` é chamado à mão, depois do `ValidationPipe`.
   */
  @Post('training-sessions/:id/participants')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  addParticipant(
    @Param('id') trainingSessionId: string,
    @Body() dto: AddParticipantDto,
  ) {
    const cpf = new ValidateCpfPipe().transform(dto.cpf);
    return this.service.addParticipant(trainingSessionId, { ...dto, cpf });
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

  /**
   * Prévia da importação por planilha (.xlsx/.csv, campo `file`): lê, valida e
   * classifica cada linha contra o banco. Não grava nada.
   */
  @Post('training-sessions/:id/participants/import/preview')
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Prévia da importação de participantes por planilha (não grava)' })
  @UseInterceptors(FileInterceptor('file'))
  previewImport(
    @Param('id') trainingSessionId: string,
    @UploadedFile(new ParseFilePipe({
      validators: [new MaxFileSizeValidator({ maxSize: PARTICIPANT_IMPORT_MAX_BYTES })],
    }))
    file: Express.Multer.File,
  ) {
    return this.importService.preview(trainingSessionId, file.buffer, file.originalname);
  }

  /**
   * Grava a importação. O corpo traz as linhas da prévia, mas o servidor
   * revalida e reclassifica cada uma: linha ruim volta em `skipped`.
   */
  @Post('training-sessions/:id/participants/import')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Importa participantes por planilha: cria/atualiza cadastros e inscreve' })
  importParticipants(
    @Param('id') trainingSessionId: string,
    @Body() dto: ImportParticipantsBodyDto,
  ) {
    return this.importService.commit(trainingSessionId, dto);
  }

  /** Modelo .xlsx da importação, gerado na hora para a lista de CNH nunca ficar defasada. */
  @Get('participants/import/template')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Baixa o modelo .xlsx para a importação de participantes' })
  async downloadImportTemplate() {
    const buffer = await buildParticipantImportTemplate();
    return new StreamableFile(buffer, {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      disposition: 'attachment; filename="modelo-importacao-participantes.xlsx"',
    });
  }

  @Patch('participants/:participantId/type')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Admin define se o participante faz só teoria ou teoria + prática' })
  updateParticipationType(
    @Param('participantId') participantId: string,
    @Body() dto: UpdateParticipantTypeDto,
  ) {
    return this.service.updateParticipationType(participantId, dto);
  }

  @Delete('participants/:participantId/signature')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Admin remove a assinatura do participante (pela inscrição)' })
  removeSignature(@Param('participantId') participantId: string) {
    return this.service.removeSignature(participantId);
  }

  @Delete('participants/:participantId')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  removeParticipant(@Param('participantId') participantId: string) {
    return this.service.removeParticipant(participantId);
  }
  
}
