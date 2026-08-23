import { BadRequestException, Body, Controller, Delete, ForbiddenException, Get, MaxFileSizeValidator, Param, ParseFilePipe, Patch, Post, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { JwtPayload, UserRole } from '@simtc/shared-types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { CompaniesService } from './companies.service';
import { CreateCompanyDto } from './dto/create-company.dto';
import { UpdateCompanyDto } from './dto/update-company.dto';
import { CreateContactUserDto } from './dto/create-contact-user.dto';
import { UpdateContactDto } from './dto/update-contact.dto';
import { FileInterceptor } from '@nestjs/platform-express';

@ApiTags('companies')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('companies')
export class CompaniesController {
  constructor(private readonly service: CompaniesService) {}

  @Post()
  @Roles(UserRole.ADMIN)
  createCompany(@Body () dto: CreateCompanyDto) {
    return this.service.createCompany(dto);
  }

  @Get()
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  findAllCompanies() {
    return this.service.findAllCompanies();
  }

  @Get(':id')
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT, UserRole.CLIENT)
  findCompanyById(@Param('id') id: string, @CurrentUser() user: JwtPayload) {
    if (user.role === UserRole.CLIENT && user.companyId !== id) {
      throw new ForbiddenException('Você não tem acesso a esta empresa.');
    }
    return this.service.findCompanyById(id);
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  deleteCompany(@Param('id')  id: string) {
    return this.service.deleteCompany(id);
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN)
  updateCompany(@Param('id') id: string, @Body() dto: UpdateCompanyDto) {
    return this.service.updateCompany(id, dto);
  }

  @Post(':id/contacts')
  @Roles(UserRole.ADMIN)
  addContact(@Param('id') id: string, @Body() dto: CreateContactUserDto) {
    return this.service.addContact(id, dto);
  }

  @Patch(':id/contacts/:contactId')
  @Roles(UserRole.ADMIN)
  updateContact(
    @Param('id') id: string,
    @Param('contactId') contactId: string,
    @Body() dto: UpdateContactDto,
  ) {
    return this.service.updateContact(id, contactId, dto);
  }

  @Delete(':id/contacts/:contactId')
  @Roles(UserRole.ADMIN)
  removeContact(@Param('id') id: string, @Param('contactId') contactId: string) {
    return this.service.removeContact(id, contactId);
  }

  @Patch(':id/logo')
  @Roles(UserRole.ADMIN)
  @UseInterceptors(FileInterceptor('file'))
  uploadCompanyLogo(
    @Param('id') id: string,
    @UploadedFile(new ParseFilePipe({
      validators: [new MaxFileSizeValidator({ maxSize: 2 * 1024 * 1024 })],
    }))
    file: Express.Multer.File,
  ) {
    if (!/^image\/(png|jpeg|svg\+xml)$/.test(file.mimetype)) {
      throw new BadRequestException('Tipo de arquivo inválido. Aceito: PNG, JPEG, SVG.');
    }
    return this.service.uploadCompanyLogo(id, file.buffer, file.mimetype);
  }

}
