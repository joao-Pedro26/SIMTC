import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Injectable,
  PayloadTooLargeException,
  BadRequestException,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { catchError, Observable, throwError } from 'rxjs';
import { ParticipantsService } from './participants.service';
import { RegisterParticipantPublicDto } from '@simtc/shared-types';
import { SIGNATURE_MAX_BYTES } from './signature.constants';

/** Arquivo acima do limite do multer vira 400 com mensagem clara (e não 413). */
@Injectable()
class SignatureTooLargeInterceptor implements NestInterceptor {
  intercept(_context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(
      catchError((err) =>
        err instanceof PayloadTooLargeException
          ? throwError(() => new BadRequestException(`Assinatura maior que ${SIGNATURE_MAX_BYTES / 1024} KB`))
          : throwError(() => err),
      ),
    );
  }
}

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
  @UseInterceptors(
    SignatureTooLargeInterceptor,
    FileInterceptor('signature', { limits: { fileSize: SIGNATURE_MAX_BYTES } }),
  )
  register(
    @Param('qrToken') qrToken: string,
    @Body() dto: RegisterParticipantPublicDto,
    @UploadedFile() signature?: Express.Multer.File,
  ) {
    return this.service.registerPublic(qrToken, dto, signature);
  }
}
