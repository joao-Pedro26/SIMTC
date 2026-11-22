import { Controller, Get, Post, Param, Body, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { BulkActionsService } from './bulk-actions.service';
import { BulkParticipantIdsDto } from './dto/bulk-participant-ids.dto';
import { UserRole, JwtPayload } from '@simtc/shared-types';

/**
 * Ações em lote sobre a listagem de participantes de uma sessão (excluir,
 * enviar certificados/relatórios por e-mail, baixar ZIP). Cada rota cria um
 * job em background e responde 202 com `{ jobId }` — o progresso é consultado
 * via GET /jobs/:jobId (JobsController). Ver brainstorm-acoes-lote-participantes.md.
 */
@ApiTags('bulk-actions')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('training-sessions/:sessionId/participants')
export class BulkActionsController {
  constructor(private readonly service: BulkActionsService) {}

  @Post('bulk-delete')
  @HttpCode(HttpStatus.ACCEPTED)
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Exclui vários participantes em lote (job em background)' })
  bulkDelete(
    @Param('sessionId') sessionId: string,
    @Body() dto: BulkParticipantIdsDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.startBulkDelete(sessionId, dto.participantIds, user);
  }

  @Post('bulk-send-certificates')
  @HttpCode(HttpStatus.ACCEPTED)
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Envia certificado + relatório por e-mail em lote (job em background)' })
  bulkSendCertificates(
    @Param('sessionId') sessionId: string,
    @Body() dto: BulkParticipantIdsDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.startBulkSendCertificates(sessionId, dto.participantIds, user);
  }

  @Post('bulk-generate-documents')
  @HttpCode(HttpStatus.ACCEPTED)
  @Roles(UserRole.ADMIN)
  @ApiOperation({
    summary: 'Gera certificado + relatório dos participantes (job em background); devolve o job ativo se já houver um',
  })
  bulkGenerateDocuments(
    @Param('sessionId') sessionId: string,
    @Body() dto: BulkParticipantIdsDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.startBulkGenerateDocuments(sessionId, dto.participantIds, user);
  }

  @Get('bulk-generate-documents/active')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Id da geração de documentos em andamento na sessão, ou null' })
  activeGenerateDocuments(@Param('sessionId') sessionId: string) {
    return this.service.getActiveGenerateDocumentsJob(sessionId);
  }

  @Post('bulk-download')
  @HttpCode(HttpStatus.ACCEPTED)
  @Roles(UserRole.ADMIN, UserRole.CLIENT, UserRole.CONSULTANT)
  @ApiOperation({ summary: 'Gera um ZIP com certificados/relatórios de vários participantes (job em background)' })
  bulkDownload(
    @Param('sessionId') sessionId: string,
    @Body() dto: BulkParticipantIdsDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.startBulkDownload(sessionId, dto.participantIds, user);
  }
}
