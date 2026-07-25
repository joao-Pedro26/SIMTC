import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AssessmentCategoriesService } from './assessment-categories.service';

@ApiTags('assessment-categories')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('assessment-categories')
export class AssessmentCategoriesController {
  constructor(private readonly service: AssessmentCategoriesService) {}

  @Get()
  @ApiOperation({ summary: 'Lista todas as categorias com infrações e notas (usada pelo app mobile)' })
  findAll() {
    return this.service.findAll();
  }

  @Get(':id/infractions')
  @ApiOperation({ summary: 'Lista infrações de uma categoria específica' })
  findInfractions(@Param('id') id: string) {
    return this.service.findInfractionsByCategory(id);
  }
}
