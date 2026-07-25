import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CoursesService } from './courses.service';
import { CreateCourseDto } from './dto/create-course.dto';
import { UpdateCourseDto } from './dto/update-couse.dto';

@ApiTags('courses')
@UseGuards(JwtAuthGuard)
@Controller('courses')
export class CoursesController {
  constructor(private readonly service: CoursesService) {}

  @Post()
  createCourse(@Body() dto: CreateCourseDto) {
    return this.service.createCourse(dto);
  }

  @Get()
   findAllCourses() {
    return this.service.findAllCourses();
  }

  @Get(':id')
  findCourseById(@Param('id') id: string) {
    return this.service.findCourseById(id);
  }

  @Patch(':id')
  updateCourse(@Param('id') id: string, @Body() dto: UpdateCourseDto) {
    return this.service.updateCourse(id, dto);
  }

  @Delete(':id')
  deleteCourse(@Param('id') id: string) {
    return this.service.deleteCourse(id);
  }
}
