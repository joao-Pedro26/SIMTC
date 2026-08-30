import {
  Controller,
  Get,
  Param,
  UseGuards,
  Res,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import type { Response } from 'express';
import * as fs from 'fs';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JobsService } from './jobs.service';
import { JwtPayload } from '@simtc/shared-types';

@ApiTags('jobs')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('jobs')
export class JobsController {
  constructor(private readonly service: JobsService) {}

  @Get(':jobId')
  getJob(@Param('jobId') jobId: string, @CurrentUser() user: JwtPayload) {
    return this.service.getJobForUser(jobId, user);
  }

  @Get(':jobId/download')
  async download(
    @Param('jobId') jobId: string,
    @CurrentUser() user: JwtPayload,
    @Res() res: Response,
  ) {
    const job = await this.service.getJobForUser(jobId, user);

    if (job.type !== 'DOWNLOAD_ZIP' || job.status !== 'COMPLETED' || !job.resultFilePath) {
      throw new BadRequestException('Este job não tem um arquivo pronto para download');
    }
    if (!fs.existsSync(job.resultFilePath)) {
      throw new NotFoundException(
        'Arquivo temporário não encontrado — pode já ter sido baixado antes. Gere o download novamente.',
      );
    }

    const fileName = `documentos-${jobId}.zip`;
    res.download(job.resultFilePath, fileName, (err) => {
      // Apaga o temporário depois do download (sucesso ou erro no meio do
      // streaming) — é um artefato descartável, não deve acumular em disco.
      fs.unlink(job.resultFilePath as string, () => {});
      if (err && !res.headersSent) {
        res.status(500).json({ message: 'Falha ao enviar o arquivo' });
      }
    });
  }
}
