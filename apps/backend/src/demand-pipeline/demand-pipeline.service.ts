import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDemandDto } from './dto/create-demand.dto';
import { UpdateDemandDto } from './dto/update-demand.dto';
import { UpdateDemandStatusDto } from './dto/update-demand-status.dto';


const INCLUDE = {
  company: { select: { id: true, name: true, logoUrl: true } },
  consultant: { select: { id: true, name: true } },
  course: { select: { id: true, name: true } }, 
};

@Injectable()
export class DemandPipelineService {
  constructor(private readonly prisma: PrismaService) {}

  async createDemand(dto: CreateDemandDto) {
  return this.prisma.demandPipeline.create({
    data: {
      companyId: dto.companyId,
      consultantId: dto.consultantId,
      courseId: dto.courseId,
      participantCount: dto.participantCount,
      notes: dto.notes,
    },
    include: INCLUDE
  });
}

  async findAllDemands() {
    return this.prisma.demandPipeline.findMany({
      include: INCLUDE,
      orderBy: { createdAt: 'desc' },
    });
  }

  async findDemandById(id: string) {
    const demand = await this.prisma.demandPipeline.findUnique({
      where: { id },
      include: INCLUDE,
    });

    if (!demand) {
      throw new NotFoundException('Demanda não encontrada');
    }
    return demand;
  }

  async updateDemand(id: string, dto: UpdateDemandDto) {
    await this.findDemandById(id);
    return this.prisma.demandPipeline.update({
      where: { id },
      data: {
        companyId: dto.companyId,
        consultantId: dto.consultantId,
        courseId: dto.courseId,
        participantCount: dto.participantCount,
        notes: dto.notes,
      },
      include: INCLUDE
    });
  }

  async updateDemandStatus(id: string, dto: UpdateDemandStatusDto) {
    await this.findDemandById(id);
    return this.prisma.demandPipeline.update({
      where: { id },
      data: {
        status: dto.status },
        include: INCLUDE,
    });
  }

  async deleteDemand(id: string) {
    await this.findDemandById(id);
    return this.prisma.demandPipeline.delete({
      where: { id },
    });
  }
}
