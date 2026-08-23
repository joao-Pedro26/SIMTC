import { BadRequestException, Body, Controller, Delete, Get, MaxFileSizeValidator, NotFoundException, Param, ParseFilePipe, Patch, Post, Query, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { UserRole } from '@simtc/shared-types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { ConsultantsService } from './consultants.service';
import { CreateConsultantDto } from './dto/create-consultant.dto';
import { UpdateConsultantDto } from './dto/update-consultant.dto';
import { FileInterceptor } from '@nestjs/platform-express';

@ApiTags('consultants')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('consultants')
export class ConsultantsController {
  constructor(private readonly service: ConsultantsService) {}

  @Post()
  @Roles(UserRole.ADMIN)
  createConsultant(@Body () dto: CreateConsultantDto) {
    return this.service.createConsultant(dto);
  }

  @Get()
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  @ApiOperation({ summary: 'Lista consultores. Use ?active=true para trazer só os ativos (ex: dropdowns de atribuição de novo trabalho).' })
  findAllConsultants(@Query('active') active?: string) {
    return this.service.findAllConsultants(active === 'true');
  }

  @Get(':id')
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  findConsultantById(@Param('id') id: string) {
    return this.service.findConsultantById(id);
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  deleteConsultant(@Param('id') id: string) {
    return this.service.deleteConsultant(id);
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN)
  updateConsultant(@Param('id') id: string, @Body() dto: UpdateConsultantDto) {
    return this.service.updateConsultant(id, dto);
  }

  @Post(':id/reset-password')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Gera uma nova senha aleatória para o consultor e reenvia por e-mail' })
  resetPassword(@Param('id') id: string) {
    return this.service.resetConsultantPassword(id);
  }

  @Get(':id/signature-url')
  @Roles(UserRole.ADMIN)
  async getSignatureUrl(@Param('id') id: string) {
    const result = await this.service.getSignatureSignedUrl(id);
    if (!result) throw new NotFoundException('Sem assinatura cadastrada');
    return result;
  }

  @Patch(':id/signature')
  @Roles(UserRole.ADMIN)
  @UseInterceptors(FileInterceptor('file'))
  uploadSignature(
    @Param('id') id: string,
    @UploadedFile(new ParseFilePipe({
      validators: [new MaxFileSizeValidator({ maxSize: 2 * 1024 * 1024 })],
    }))
    file: Express.Multer.File,
  ) {
    if (!/^image\/(png|jpeg|svg\+xml)$/.test(file.mimetype)) {
      throw new BadRequestException('Tipo de arquivo inválido. Aceito: PNG, JPEG, SVG.');
    }
    return this.service.uploadSignature(id, file.buffer, file.mimetype);
  }
}


