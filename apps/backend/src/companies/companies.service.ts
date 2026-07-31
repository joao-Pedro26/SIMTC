import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { CreateCompanyDto } from './dto/create-company.dto';
import { UpdateCompanyDto } from './dto/update-company.dto';
import { CreateContactUserDto } from './dto/create-contact-user.dto';

@Injectable()
export class CompaniesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  async createCompany(dto: CreateCompanyDto) {
    const existingCompany = await this.prisma.company.findUnique({
      where: { cnpj: dto.cnpj },
    });
    if (existingCompany) {
      throw new ConflictException('Empresa com este CNPJ já existe.');
    }

    return this.prisma.$transaction(async (tx) => {
      const company = await tx.company.create({
        data: {
          name: dto.name,
          cnpj: dto.cnpj,
          address: dto.address,
          city: dto.city,
          state: dto.state,
        },
      });

      for (const c of dto.contacts) {
        const contact = await tx.companyContact.create({
          data: {
            companyId: company.id,
            name: c.name,
            email: c.email,
            phone: c.phone,
          },
        });

        await tx.user.create({
          data: {
            email: c.email,
            role: 'CLIENT',
            contactId: contact.id,
          },
        });
      }

      return tx.company.findUnique({
        where: { id: company.id },
        include: { contacts: true },
      });
    });
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
      const contacts = await tx.companyContact.findMany({ where: { companyId: id } });
      for (const contact of contacts) {
        await tx.user.deleteMany({ where: { contactId: contact.id } });
      }
      await tx.companyContact.deleteMany({ where: { companyId: id } });
      return tx.company.delete({ where: { id } });
    });
  }

  async addContact(companyId: string, dto: CreateContactUserDto) {
    await this.findCompanyById(companyId);

    const existingUser = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (existingUser) {
      throw new ConflictException('Já existe um usuário com este e-mail.');
    }

    return this.prisma.$transaction(async (tx) => {
      const contact = await tx.companyContact.create({
        data: { companyId, name: dto.name, email: dto.email, phone: dto.phone },
      });
      await tx.user.create({
        data: { email: dto.email, role: 'CLIENT', contactId: contact.id },
      });
      return contact;
    });
  }

  async removeContact(companyId: string, contactId: string) {
    const contact = await this.prisma.companyContact.findFirst({
      where: { id: contactId, companyId },
    });
    if (!contact) throw new NotFoundException('Contato não encontrado');

    return this.prisma.$transaction(async (tx) => {
      await tx.user.deleteMany({ where: { contactId } });
      return tx.companyContact.delete({ where: { id: contactId } });
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

  async uploadCompanyLogo(id: string, buffer: Buffer, contentType: string) {
    await this.findCompanyById(id);
    const url = await this.storage.upload('logos', id, buffer, contentType);
    return this.prisma.company.update({
      where: { id },
      data: { logoUrl: url },
    });
  }
}
