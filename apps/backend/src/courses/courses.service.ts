import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCourseDto } from './dto/create-course.dto';
import { UpdateCourseDto } from './dto/update-couse.dto';

const COURSE_INCLUDE = {
  categories: { select: { categoryId: true } },
} satisfies Prisma.CourseInclude;

type CourseWithCategories = Prisma.CourseGetPayload<{ include: typeof COURSE_INCLUDE }>;

/** Achata a tabela de vínculo em `categoryIds: string[]` na resposta. */
function toResponse(course: CourseWithCategories) {
  const { categories, ...rest } = course;
  return { ...rest, categoryIds: categories.map((c) => c.categoryId) };
}

@Injectable()
export class CoursesService {
  constructor(private readonly prisma: PrismaService) {}

  async createCourse(dto: CreateCourseDto) {
    const { categoryIds, ...data } = dto;
    const ids = await this.validateCategoryIds(categoryIds ?? [], data.practiceHours ?? 0);

    const course = await this.prisma.course.create({
      data: {
        ...data,
        categories: { create: ids.map((categoryId) => ({ categoryId })) },
      },
      include: COURSE_INCLUDE,
    });
    return toResponse(course);
  }

  async findAllCourses() {
    const courses = await this.prisma.course.findMany({
      orderBy: { name: 'asc' },
      include: COURSE_INCLUDE,
    });
    return courses.map(toResponse);
  }

  async findCourseById(id: string) {
    const course = await this.prisma.course.findUnique({ where: { id }, include: COURSE_INCLUDE });
    if (!course) {
      throw new NotFoundException('Curso não encontrado');
    }
    return toResponse(course);
  }

  async updateCourse(id: string, dto: UpdateCourseDto) {
    const current = await this.findCourseById(id);
    const { categoryIds, ...data } = dto;

    // A regra de "mínimo 1 tópico" olha o estado final do curso: as horas
    // práticas e os tópicos que vão ficar depois deste PATCH.
    const practiceHours = data.practiceHours ?? current.practiceHours;
    const ids = await this.validateCategoryIds(categoryIds ?? current.categoryIds, practiceHours);

    const course = await this.prisma.$transaction(async (tx) => {
      if (categoryIds !== undefined) {
        await tx.courseAssessmentCategory.deleteMany({ where: { courseId: id } });
        await tx.courseAssessmentCategory.createMany({
          data: ids.map((categoryId) => ({ courseId: id, categoryId })),
        });
      }
      return tx.course.update({ where: { id }, data, include: COURSE_INCLUDE });
    });
    return toResponse(course);
  }

  async deleteCourse(id: string) {
    await this.findCourseById(id);
    return this.prisma.course.delete({ where: { id } });
  }

  /**
   * Remove repetidos, confere que todos os tópicos existem e exige pelo menos
   * 1 tópico quando o curso tem parte prática (sem tópico não há checklist).
   */
  private async validateCategoryIds(categoryIds: string[], practiceHours: number) {
    const ids = [...new Set(categoryIds)];

    if (practiceHours > 0 && ids.length === 0) {
      throw new BadRequestException(
        'Cursos com horas práticas precisam de pelo menos 1 tópico de avaliação.',
      );
    }
    if (ids.length === 0) return ids;

    const found = await this.prisma.assessmentCategory.count({ where: { id: { in: ids } } });
    if (found !== ids.length) {
      throw new BadRequestException('Um ou mais tópicos de avaliação não foram encontrados.');
    }
    return ids;
  }
}
