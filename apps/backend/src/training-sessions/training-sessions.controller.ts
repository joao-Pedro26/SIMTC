import { Controller, Get, Post, Put, Param, Body, UseGuards, Request, Res, Delete, Patch, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Response } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { TrainingSessionsService } from './training-sessions.service';
import { QrCodeService } from './qr-code.service';
import { JwtPayload } from '@simtc/shared-types';
import { CreateTrainingSessionDto } from './dto/create-training-session.dto';
import { UpdateTrainingSessionDto } from './dto/update-training-session.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

@ApiTags('training-sessions')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('training-sessions')
export class TrainingSessionsController {
  constructor(
    private readonly service: TrainingSessionsService,
    private readonly qrCode: QrCodeService,
  ) {}

  @Get()
  @Roles('ADMIN' as any, 'CONSULTANT' as any)
  @ApiOperation({ summary: 'Lista sessões — ADMIN vê tudo, CONSULTANT vê só as suas' })
  findAll(@CurrentUser() user: JwtPayload, @Query() pagination: PaginationDto) {
    return this.service.findAll(user, pagination);
  }

  @Get(':id')
  @Roles('ADMIN' as any, 'CONSULTANT' as any)
  @ApiOperation({ summary: 'Detalhe da sessão — CONSULTANT só acessa se estiver atribuído a ela' })
  findTrainingSessionById(@Param('id') id: string, @CurrentUser() user: JwtPayload) {
    return this.service.findTrainingSessionById(id, user);
  }

  @Post(':id/start')
  @Roles('ADMIN' as any, 'CONSULTANT' as any)
  @ApiOperation({ summary: 'Inicia a sessão — ADMIN ou o consultor responsável por ela' })
  start(@Param('id') id: string, @CurrentUser() user: JwtPayload) {
    return this.service.start(id, user);
  }

  @Post(':id/complete')
  @Roles('ADMIN' as any, 'CONSULTANT' as any)
  @ApiOperation({ summary: 'Conclui a sessão — ADMIN ou o consultor responsável por ela' })
  complete(@Param('id') id: string, @CurrentUser() user: JwtPayload) {
    return this.service.complete(id, user);
  }

  @Post()
  @Roles('ADMIN' as any)
  @ApiOperation({ summary: 'Cria uma nova sessão de treinamento' })
  createTrainingSession(@Body() dto: CreateTrainingSessionDto) {
    return this.service.createTrainingSession(dto);
  }

  @Get(':id/qr-code')
  @Public()
  @ApiOperation({ summary: 'Retorna imagem PNG do QR Code da sessão — público (usado como <img src>)' })
  async getQrCode(@Param('id') id: string, @Res() res: Response) {
    const session = await this.service.findTrainingSessionById(id);
    const png = await this.qrCode.generatePng(
      session.qrCodeToken,
      process.env.FRONTEND_URL ?? 'http://localhost:3000',
    );
    res.setHeader('Content-Type', 'image/png');
    res.send(png);
  }

  @Delete(':id')
  @Roles('ADMIN' as any)
  deleteTrainingSession(@Param('id') id:string){
    return this.service.deleteSession(id);
  }

  @Patch(':id/cancel')
  @Roles('ADMIN' as any)
  cancelTrainingSession(@Param('id') id: string) {
    return this.service.cancelSession(id);
  }

  @Patch(':id')
  @Roles('ADMIN' as any)
  updateTrainingSession(@Param('id') id: string, @Body() dto: UpdateTrainingSessionDto) {
    return this.service.updateSession(id, dto);
  }
}
