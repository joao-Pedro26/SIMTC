import { Controller, Get, Post, Param, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { CertificatesService } from './certificates.service';
import { JwtPayload } from '@simtc/shared-types';

@ApiTags('certificates')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller()
export class CertificatesController {
  constructor(private readonly service: CertificatesService) {}

  @Post('training-sessions/:id/generate-certificates')
  @Roles('ADMIN' as any)
  @ApiOperation({ summary: 'Gera PDFs em lote para todos os aprovados da sessão' })
  generateBatch(@Param('id') trainingSessionId: string) {
    return this.service.generateBatch(trainingSessionId);
  }

  @Post('training-sessions/:id/generate-assessment-reports')
  @Roles('ADMIN' as any)
  @ApiOperation({ summary: 'Gera relatórios de avaliação técnica em lote para a sessão' })
  generateAssessmentReports(@Param('id') trainingSessionId: string) {
    return this.service.generateAssessmentReports(trainingSessionId);
  }

  @Get('training-sessions/:id/certificates')
  @Roles('ADMIN' as any, 'CONSULTANT' as any, 'CLIENT' as any)
  @ApiOperation({ summary: 'Lista todos os certificados de uma sessão de treinamento' })
  findByTrainingSession(@Param('id') trainingSessionId: string) {
    return this.service.findByTrainingSession(trainingSessionId);
  }

  @Get('training-sessions/:id/assessment-reports')
  @Roles('ADMIN' as any, 'CONSULTANT' as any, 'CLIENT' as any)
  @ApiOperation({ summary: 'Lista relatórios de avaliação técnica de uma sessão' })
  findAssessmentReportsByTrainingSession(@Param('id') trainingSessionId: string) {
    return this.service.findAssessmentReportsByTrainingSession(trainingSessionId);
  }

  @Get('certificates/:id')
  @Roles('ADMIN' as any, 'CONSULTANT' as any, 'CLIENT' as any)
  @ApiOperation({ summary: 'Busca certificado por ID com URL do PDF' })
  findById(@Param('id') id: string) {
    return this.service.findById(id);
  }

  @Get('certificates/:id/download-url')
  @Roles('ADMIN' as any, 'CONSULTANT' as any, 'CLIENT' as any)
  @ApiOperation({ summary: 'Retorna URL assinada de 5 minutos para download do PDF (bucket privado)' })
  getDownloadUrl(@Param('id') id: string) {
    return this.service.getDownloadUrl(id);
  }

  @Get('assessment-reports/:id/download-url')
  @Roles('ADMIN' as any, 'CONSULTANT' as any, 'CLIENT' as any)
  @ApiOperation({ summary: 'Retorna URL assinada de 5 minutos para download do relatório de avaliação' })
  getAssessmentReportDownloadUrl(
    @Param('id') assessmentId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.getAssessmentReportDownloadUrl(assessmentId, user);
  }

  @Post('certificates/:id/send')
  @Roles('ADMIN' as any)
  @ApiOperation({ summary: 'Envia certificado por e-mail (participant | company | both)' })
  send(
    @Param('id') id: string,
    @Body('to') to: 'participant' | 'company' | 'both',
  ) {
    return this.service.sendByEmail(id, to);
  }
}
