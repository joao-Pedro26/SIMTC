import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCourseDto } from './dto/create-course.dto';
import { UpdateCourseDto } from './dto/update-couse.dto';

@Injectable()
export class CoursesService {
  constructor(private readonly prisma: PrismaService) {}

  async createCourse(dto: CreateCourseDto) {
    return this.prisma.course.create({ data: dto });
  }

  async findAllCourses() {
    return this.prisma.course.findMany({orderBy: { name: 'asc' }});
  }

  async findCourseById(id: string) {
    const course = await this.prisma.course.findUnique({ where: { id } });
    if (!course) {
      throw new NotFoundException('Curso não encontrado');
    }
    return course;
  }

  async updateCourse(id: string, dto: UpdateCourseDto) {
    await this.findCourseById(id);
    return this.prisma.course.update({ where: { id }, data: dto });
  }

  async deleteCourse(id: string) {
    await this.findCourseById(id);
    return this.prisma.course.delete({ where: { id } });
  }
}


