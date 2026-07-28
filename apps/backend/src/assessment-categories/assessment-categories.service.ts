import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAssessmentCategoryDto } from './dto/create-assessment-category.dto';
import { UpdateAssessmentCategoryDto } from './dto/update-assessment-category.dto';

@Injectable()
export class AssessmentCategoriesService {
  constructor(private readonly prisma: PrismaService) { }

  async createAssementCategory(dto: CreateAssessmentCategoryDto) {
    const existing = await this.prisma.assessmentCategory.findUnique({
      where: { code: dto.code },
    });
    if (existing) throw new ConflictException(`Já existe uma categoria com o código '${dto.code}'`);

    return this.prisma.$transaction(async (tx) => {
      const category = await tx.assessmentCategory.create({
        data: {
          code: dto.code,
          name: dto.name,
          description: dto.description,
          order: dto.order
        },
      });

      for (const inf of dto.infractions) {
        const infraction = await tx.infraction.create({
          data: {
            categoryId: category.id,
            description: inf.description,
            order: inf.order,
          },
        });

        await tx.infractionNote.createMany({
          data: inf.notes.map((n) => ({
            infractionId: infraction.id,
            noteType: n.noteType,
            comment: n.comment,
            deduction: n.deduction,
          })),
        });
      }

      return tx.assessmentCategory.findUnique({
        where: { id: category.id },
        include: {
          infractions: {
            include: { notes: true },
            orderBy: { order: 'asc' },
          }
        }
      })
    })
  }

  findAll() {
    return this.prisma.assessmentCategory.findMany({
      orderBy: { order: 'asc' },
      include: {
        infractions: {
          orderBy: { order: 'asc' },
          include: { notes: true },
        },
      },
    });
  }

  findAssementCaretegoryById(id: string) {
    return this.prisma.assessmentCategory.findUniqueOrThrow({ where: { id } });
  }

  async updateAssessmentCategory (id: string, dto: UpdateAssessmentCategoryDto) {
    await this.findAssementCaretegoryById(id);
    return this.prisma.assessmentCategory.update({
      where: { id },
      data: {
        code: dto.code,
        name: dto.name,
        description: dto.description,
        order: dto.order,
      },
      include: {
        infractions: {
          include: { notes: true},
          orderBy: {order: 'asc'}
        }
      },
    });
  }

  async deleteAssessmentCotegory(id: string) {
    await this.findAssementCaretegoryById(id);
    return this.prisma.$transaction(async (tx) => {
      const infractions = await tx.infraction.findMany ({
        where: {categoryId: id },
      });

      for (const inf of infractions) {
        await tx.infractionNote.deleteMany({ where: {infractionId: inf.id } });
      }

      await tx.infraction.deleteMany({ where: { categoryId: id } });
      return tx.assessmentCategory.delete({ where: {id } });
    });
  }

  findInfractionsByCategory(categoryId: string) {
    return this.prisma.infraction.findMany({
      where: { categoryId },
      orderBy: { order: 'asc' },
      include: { notes: true },
    });
  }
}
