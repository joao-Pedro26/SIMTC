import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { UserRole } from '@simtc/shared-types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { AssessmentCategoriesService } from './assessment-categories.service';
import { CreateAssessmentCategoryDto, CreateInfractionDto } from './dto/create-assessment-category.dto';
import { UpdateAssessmentCategoryDto } from './dto/update-assessment-category.dto';
import { UpdateInfractionDto } from './dto/update-infraction.dto';
import { UpdateNoteDto } from './dto/update-note.dto';

@ApiTags('assessment-categories')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('assessment-categories')
export class AssessmentCategoriesController {
  constructor(private readonly service: AssessmentCategoriesService) {}

  @Get()
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  @ApiOperation({ summary: 'Lista todas as categorias com infrações e notas (usada pelo app mobile)' })
  findAll() {
    return this.service.findAll();
  }

  @Get(':id/infractions')
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  @ApiOperation({ summary: 'Lista infrações de uma categoria específica' })
  findInfractions(@Param('id') id: string) {
    return this.service.findInfractionsByCategory(id);
  }

  @Get(':id')
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  findAssessmentCategoryById (@Param('id') id: string){
    return this.service.findAssementCaretegoryById(id);
  }

  @Post()
  @Roles(UserRole.ADMIN)
  createAssessmentCategory(@Body() dto: CreateAssessmentCategoryDto){
    return this.service.createAssementCategory(dto);
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN)
  updateAssessmentCategory(@Param('id') id: string, @Body() dto: UpdateAssessmentCategoryDto) {
    return this.service.updateAssessmentCategory(id, dto)
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  deleteAssessmentCotegory(@Param('id') id: string){
    return this.service.deleteAssessmentCotegory(id)
  }

  @Post(':id/infractions')
@Roles(UserRole.ADMIN)
addInfraction(@Param('id') id: string, @Body() dto: CreateInfractionDto) {
  return this.service.addInfraction(id, dto);
}

@Patch(':id/infractions/:infractionId')
@Roles(UserRole.ADMIN)
updateInfraction(
  @Param('id') id: string,
  @Param('infractionId') infractionId: string,
  @Body() dto: UpdateInfractionDto,
) {
  return this.service.updateInfraction(id, infractionId, dto);
}

@Delete(':id/infractions/:infractionId')
@Roles(UserRole.ADMIN)
removeInfraction(
  @Param('id') id: string,
  @Param('infractionId') infractionId: string,
) {
  return this.service.removeInfraction(id, infractionId);
}

@Patch(':id/infractions/:infractionId/notes/:noteType')
@Roles(UserRole.ADMIN)
updateNote(
  @Param('infractionId') infractionId: string,
  @Param('noteType') noteType: string,
  @Body() dto: UpdateNoteDto,
) {
  return this.service.updateNote(infractionId, noteType, dto);
}
}
