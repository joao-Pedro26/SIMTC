import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCompanyDto } from './dto/create-company.dto';
import { UpdateCompanyDto } from './dto/update-company.dto';


@Injectable()
export class CompaniesService {
  constructor(private readonly prisma: PrismaService) {}

  async createCompany(dto: CreateCompanyDto) {
    
    const existingCompany = await this.prisma.company.findUnique({
      where: { cnpj: dto.cnpj },
    });

    if (existingCompany) {
      throw new ConflictException('Empresa com este CNPJ já existe.');
    }

    return this.prisma.$transaction(async(tx) => {
      const company = await tx.company.create({
        data: {
          name: dto.name,
          cnpj: dto.cnpj,
          address: dto.address,
          city: dto.city,
          state: dto.state
        },
      });

      await tx.companyContact.createMany({ 
        data: dto.contacts.map((c, index) => ({
          companyId: company.id,
          name: c.name,
          email: c.email,
          phone: c.phone,
        }))
      });

      return tx.company.findUnique({
        where: { id: company.id },
        include: { contacts: true },
      });
    })
  }

  async findAllCompanies() {
    return this.prisma.company.findMany({
      include: { contacts: true },
      orderBy: { name: 'asc' },
    });
   }

  async findCompanyById(id: string) {
    const company = await this.prisma.company.findUnique({
      where: { id },
      include: { contacts: true },
    });
    if (!company) throw new NotFoundException('Empresa não encontrada');
    return company;
  }

  async deleteCompany(id: string) {
    await this.findCompanyById(id);
    return this.prisma.$transaction(async (tx) => {
      await tx.companyContact.deleteMany({ where: { companyId: id } });
      return tx.company.delete({ where: { id } });
    });
  }

  async updateCompany(id: string, dto: UpdateCompanyDto) {
  await this.findCompanyById(id);

  return this.prisma.company.update({
    where: { id },
    data: {
      name: dto.name,
      cnpj: dto.cnpj,
      address: dto.address,
      city: dto.city,
      state: dto.state,
    },
    include: { contacts: true },
  });
  }
}


