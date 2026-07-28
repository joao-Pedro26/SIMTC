import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AssessmentCategoriesService } from './assessment-categories.service';
import { CreateAssessmentCategoryDto } from './dto/create-assessment-category.dto';
import { UpdateAssessmentCategoryDto } from './dto/update-assessment-category.dto';

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

  @Get(':id')
  findAssessmentCategoryById (@Param('id') id: string){
    return this.service.findAssementCaretegoryById(id);
  }

  @Post()
  createAssessmentCategory(@Body() dto: CreateAssessmentCategoryDto){
    return this.service.createAssementCategory(dto);
  }

  @Patch(':id')
  updateAssessmentCategory(@Param('id') id: string, @Body() dto: UpdateAssessmentCategoryDto) {
    return this.service.updateAssessmentCategory(id, dto)
  }

  @Delete(':id')
  deleteAssessmentCotegory(@Param('id') id: string){
    return this.service.deleteAssessmentCotegory(id)
  }
}
