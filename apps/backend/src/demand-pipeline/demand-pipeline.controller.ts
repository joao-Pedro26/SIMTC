import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { DemandPipelineService } from './demand-pipeline.service';
import { CreateDemandDto } from './dto/create-demand.dto';
import { Roles } from 'src/auth/decorators/roles.decorator';
import { UserRole } from '@simtc/shared-types';
import { UpdateDemandDto } from './dto/update-demand.dto';
import { UpdateDemandStatusDto } from './dto/update-demand-status.dto';

@ApiTags('demand-pipeline')
@UseGuards(JwtAuthGuard)
@Controller('demand-pipeline')
export class DemandPipelineController {
  constructor(private readonly service: DemandPipelineService) {}

  @Post()
  @Roles(UserRole.ADMIN)
  createDemand(@Body() dto: CreateDemandDto) {
    return this.service.createDemand(dto);
  }

  @Get()
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  findAllDemands() {
    return this.service.findAllDemands();
  }

  @Get(':id')
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  findById(@Param('id') id: string) {
    return this.service.findDemandById(id);
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN)
  updateDemand(@Param('id') id: string, @Body() dto: UpdateDemandDto) {
    return this.service.updateDemand(id, dto);
  }

  @Patch(':id/status')
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  updateDemandStatus(@Param('id') id: string, @Body() dto: UpdateDemandStatusDto) {
    return this.service.updateDemandStatus(id, dto);
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  deleteDemand(@Param('id') id: string) {
    return this.service.deleteDemand(id);
  }
}
