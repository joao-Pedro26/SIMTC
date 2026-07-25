import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { CreateConsultantDto } from './dto/create-consultant.dto';
import { UpdateConsultantDto } from './dto/update-consultant.dto';

@Injectable()
export class ConsultantsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  async createConsultant(dto: CreateConsultantDto) {
    const existingConsultant = await this.prisma.consultant.findUnique({
      where: { email: dto.email },
    });

    if (existingConsultant) {
      throw new ConflictException('Já existe um consultor com este e-mail.');
    }

    return this.prisma.consultant.create({data: dto});
  }

  async findAllConsultants() {
    return this.prisma.consultant.findMany({orderBy: { name: 'asc' }});
  }

  async findConsultantById(id: string) {
    const consultant = await this.prisma.consultant.findUnique({ where: { id } });
    if (!consultant) throw new NotFoundException('Consultor não encontrado');
    return consultant;
  }

  async deleteConsultant(id: string) {
    await this.findConsultantById(id);
    return this.prisma.consultant.delete({ where: { id } });
  }

  async updateConsultant(id: string, dto: UpdateConsultantDto) {
    await this.findConsultantById(id);
    return this.prisma.consultant.update({
      where: { id },
      data: dto,
    });
  } 

  async uploadSignature(id: string, buffer: Buffer, contentType: string) {
    await this.findConsultantById(id);
    const path = `${id}`;
    await this.storage.upload('signatures', path, buffer, contentType);
    return this.prisma.consultant.update({
      where: { id },
      data: { signatureUrl: path },
    });
  }
}
