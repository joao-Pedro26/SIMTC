import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateVehicleTypeDto } from './dto/create-vehicle-type.dto';

@Injectable()
export class VehicleTypesService {
  constructor(private readonly prisma: PrismaService) {}

  findAll() {
    return this.prisma.vehicleType.findMany({ orderBy: { name: 'asc' } });
  }

  async create(dto: CreateVehicleTypeDto) {
    const name = dto.name.trim();
    const existing = await this.prisma.vehicleType.findFirst({
      where: { name: { equals: name, mode: 'insensitive' } },
    });
    if (existing) {
      throw new ConflictException('Já existe um tipo de veículo com esse nome.');
    }
    return this.prisma.vehicleType.create({ data: { name } });
  }

  async remove(id: string) {
    const type = await this.prisma.vehicleType.findUnique({
      where: { id },
      include: { _count: { select: { courses: true } } },
    });
    if (!type) {
      throw new NotFoundException('Tipo de veículo não encontrado');
    }
    if (type._count.courses > 0) {
      throw new ConflictException(
        `Este tipo está em uso por ${type._count.courses} curso(s). Troque o tipo desses cursos antes de excluir.`,
      );
    }
    return this.prisma.vehicleType.delete({ where: { id } });
  }
}
