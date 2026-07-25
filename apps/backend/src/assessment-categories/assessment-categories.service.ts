import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AssessmentCategoriesService {
  constructor(private readonly prisma: PrismaService) {}

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

  findOne(id: string) {
    return this.prisma.assessmentCategory.findUniqueOrThrow({ where: { id } });
  }

  findInfractionsByCategory(categoryId: string) {
    return this.prisma.infraction.findMany({
      where: { categoryId },
      orderBy: { order: 'asc' },
      include: { notes: true },
    });
  }
}
