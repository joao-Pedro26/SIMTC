import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CompaniesService } from './companies.service';
import { CreateCompanyDto } from './dto/create-company.dto';
import { UpdateCompanyDto } from './dto/update-company.dto';

@ApiTags('companies')
@UseGuards(JwtAuthGuard)
@Controller('companies')
export class CompaniesController {
  constructor(private readonly service: CompaniesService) {}

  @Post()
  createCompany(@Body () dto: CreateCompanyDto) {
    return this.service.createCompany(dto);
  }

  @Get()
  findAllCompanies() {
    return this.service.findAllCompanies();
  }

  @Get(':id')
  findCompanyById(@Param('id') id: string) {
    return this.service.findCompanyById(id);
  }

  @Delete(':id')
  deleteCompany(@Param('id')  id: string) {
    return this.service.deleteCompany(id);
  }
  
  @Patch(':id')
  updateCompany(@Param('id') id: string, @Body() dto: UpdateCompanyDto) {
    return this.service.updateCompany(id, dto);
  }
}
