import { Controller, Post, Param, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CertificatesService } from './certificates.service';

@ApiTags('certificates')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN' as any)
@Controller()
export class CertificatesController {
  constructor(private readonly service: CertificatesService) {}

  @Post('training-sessions/:id/generate-certificates')
  @ApiOperation({ summary: 'Gera PDFs em lote para todos os aprovados da sessão' })
  generateBatch(@Param('id') trainingSessionId: string) {
    return this.service.generateBatch(trainingSessionId);
  }

  @Post('certificates/:id/send')
  @ApiOperation({ summary: 'Envia certificado por e-mail (participant | company | both)' })
  send(
    @Param('id') id: string,
    @Body('to') to: 'participant' | 'company' | 'both',
  ) {
    return this.service.sendByEmail(id, to);
  }
}
