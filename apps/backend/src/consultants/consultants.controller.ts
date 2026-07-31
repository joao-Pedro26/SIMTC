import { Body, Controller, Delete, FileTypeValidator, Get, MaxFileSizeValidator, Param, ParseFilePipe, Patch, Post, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
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
  findAllConsultants() {
    return this.service.findAllConsultants();
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

  @Patch(':id/signature')
  @Roles(UserRole.ADMIN)
  @UseInterceptors(FileInterceptor('file'))
  uploadSignature(@Param('id') id: string,
    @UploadedFile(new ParseFilePipe({
      validators: [
        new MaxFileSizeValidator({ maxSize: 2 * 1024 * 1024 }), // 5MB
        new FileTypeValidator({ fileType: /image\/(png|jpeg)/ }),
      ],
    }),
  )
  file: Express.Multer.File,
)  {
    return this.service.uploadSignature(id, file.buffer, file.mimetype);
  }
}


