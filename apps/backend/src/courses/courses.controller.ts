import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { UserRole } from '@simtc/shared-types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CoursesService } from './courses.service';
import { CreateCourseDto } from './dto/create-course.dto';
import { UpdateCourseDto } from './dto/update-couse.dto';

@ApiTags('courses')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('courses')
export class CoursesController {
  constructor(private readonly service: CoursesService) {}

  @Post()
  @Roles(UserRole.ADMIN)
  createCourse(@Body() dto: CreateCourseDto) {
    return this.service.createCourse(dto);
  }

  @Get()
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  findAllCourses() {
    return this.service.findAllCourses();
  }

  @Get(':id')
  @Roles(UserRole.ADMIN, UserRole.CONSULTANT)
  findCourseById(@Param('id') id: string) {
    return this.service.findCourseById(id);
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN)
  updateCourse(@Param('id') id: string, @Body() dto: UpdateCourseDto) {
    return this.service.updateCourse(id, dto);
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  deleteCourse(@Param('id') id: string) {
    return this.service.deleteCourse(id);
  }
}
