import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { CreateCompanyDto } from './dto/create-company.dto';
import { UpdateCompanyDto } from './dto/update-company.dto';
import { CreateContactUserDto } from './dto/create-contact-user.dto';
import { UpdateContactDto } from './dto/update-contact.dto';
import { deleteOrphanedParticipants } from '../participants/participant-cleanup.util';

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

    for (const c of dto.contacts) {
      const existingUser = await this.prisma.user.findUnique({ where: { email: c.email } });
      if (existingUser) {
        throw new ConflictException(`O e-mail "${c.email}" já está cadastrado no sistema.`);
      }
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
      include: {
        contacts: true,
        // Traz apenas o treinamento concluído mais recente para exibir "Último Treinamento"
        trainings: {
          where: { status: 'CONCLUIDO' },
          orderBy: { date: 'desc' },
          take: 1,
          select: { date: true },
        },
      },
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

    // Bloqueia apenas sessões ativas — canceladas podem ser limpas junto com a empresa
    const activeSessionCount = await this.prisma.trainingSession.count({
      where: { companyId: id, status: { in: ['PLANEJADO', 'EM_ANDAMENTO'] } },
    });

    if (activeSessionCount > 0) {
      throw new ConflictException(
        `Não é possível excluir esta empresa pois ela possui ${activeSessionCount} sessão(ões) ativa(s). Cancele ou conclua os treinamentos antes de excluir.`,
      );
    }

    return this.prisma.$transaction(async (tx) => {
      // Busca todas as sessões da empresa (canceladas/concluídas)
      const sessions = await tx.trainingSession.findMany({
        where: { companyId: id },
        select: { id: true },
      });
      const sessionIds = sessions.map((s) => s.id);

      if (sessionIds.length > 0) {
        // Jobs de ações em lote (excluir/enviar e-mail/baixar ZIP participantes)
        // têm FK obrigatória para a sessão — precisa limpar antes de apagar as
        // sessões, senão quebra com violação de FK (mesmo problema corrigido em
        // TrainingSessionsService.deleteSession, ver [[simtc-participant-training-delete]]).
        await tx.bulkOperationJob.deleteMany({
          where: { trainingSessionId: { in: sessionIds } },
        });

        // Busca participantes dessas sessões (participantId incluso para o
        // cleanup de cadastros órfãos logo abaixo, ver [[simtc-participant-training-delete]])
        const participants = await tx.trainingParticipant.findMany({
          where: { trainingSessionId: { in: sessionIds } },
          select: { id: true, participantId: true },
        });
        const participantIds = participants.map((p) => p.id);

        if (participantIds.length > 0) {
          // Deleta em cascata: itens de avaliação → avaliações → certificados → participantes
          const assessments = await tx.practicalAssessment.findMany({
            where: { trainingParticipantId: { in: participantIds } },
            select: { id: true },
          });
          await tx.assessmentItem.deleteMany({
            where: { assessmentId: { in: assessments.map((a) => a.id) } },
          });
          await tx.practicalAssessment.deleteMany({
            where: { trainingParticipantId: { in: participantIds } },
          });
          await tx.certificate.deleteMany({
            where: { trainingParticipantId: { in: participantIds } },
          });
          await tx.trainingParticipant.deleteMany({
            where: { trainingSessionId: { in: sessionIds } },
          });
          // Cadastro de Participant (CPF, compartilhado entre treinamentos)
          // só é apagado se não sobrar nenhuma outra inscrição dele
          await deleteOrphanedParticipants(tx, participants.map((p) => p.participantId));
        }

        // Deleta consultores vinculados às sessões e as sessões em si
        await tx.sessionConsultant.deleteMany({
          where: { trainingSessionId: { in: sessionIds } },
        });
        await tx.trainingSession.deleteMany({ where: { companyId: id } });
      }

      // Deleta demandas
      await tx.demandPipeline.deleteMany({ where: { companyId: id } });

      // Deleta contatos e usuários vinculados
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

  async updateContact(companyId: string, contactId: string, dto: UpdateContactDto) {
    const contact = await this.prisma.companyContact.findFirst({
      where: { id: contactId, companyId },
    });
    if (!contact) throw new NotFoundException('Contato não encontrado');

    // Se o e-mail está sendo alterado, verifica se já existe outro usuário com esse e-mail
    if (dto.email && dto.email !== contact.email) {
      const conflict = await this.prisma.user.findUnique({ where: { email: dto.email } });
      if (conflict) throw new ConflictException('Este e-mail já está em uso por outro usuário.');
    }

    return this.prisma.$transaction(async (tx) => {
      // Atualiza o contato
      const updated = await tx.companyContact.update({
        where: { id: contactId },
        data: {
          ...(dto.name  !== undefined && { name: dto.name }),
          ...(dto.email !== undefined && { email: dto.email }),
          ...(dto.phone !== undefined && { phone: dto.phone }),
        },
      });

      // Se o e-mail mudou, atualiza também o User vinculado (login)
      if (dto.email && dto.email !== contact.email) {
        await tx.user.updateMany({
          where: { contactId },
          data: { email: dto.email },
        });
      }

      return updated;
    });
  }

  async removeContact(companyId: string, contactId: string) {
    const contact = await this.prisma.companyContact.findFirst({
      where: { id: contactId, companyId },
    });
    if (!contact) throw new NotFoundException('Contato não encontrado');

    return this.prisma.$transaction(async (tx) => {
      // Mesmo motivo do bulkOperationJob.deleteMany em deleteCompany logo
      // acima: `requestedById` é FK obrigatória para User, então apagar o
      // usuário do contato sem limpar antes os jobs em lote que ele disparou
      // (bulk-download é liberado para CLIENT) quebra com violação de FK.
      const contactUsers = await tx.user.findMany({ where: { contactId }, select: { id: true } });
      await tx.bulkOperationJob.deleteMany({
        where: { requestedById: { in: contactUsers.map((u) => u.id) } },
      });

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
    const company = await this.findCompanyById(id);

    // Apaga o arquivo anterior para não acumular arquivos órfãos no bucket
    if (company.logoUrl) {
      const oldPath = new URL(company.logoUrl).pathname
        .replace(/^\/storage\/v1\/object\/public\/logos\//, '');
      await this.storage.delete('logos', oldPath).catch(() => null);
    }

    // Usa timestamp no caminho para garantir URL única e bustar o CDN automaticamente
    const ext = contentType === 'image/png' ? 'png' : contentType === 'image/svg+xml' ? 'svg' : 'jpg';
    const path = `${id}/${Date.now()}.${ext}`;
    const url = await this.storage.upload('logos', path, buffer, contentType);

    return this.prisma.company.update({
      where: { id },
      data: { logoUrl: url },
    });
  }
}
