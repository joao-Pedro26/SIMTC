export interface CreateCompanyDto {
    name: string;
    cnpj: string;
    address?: string;
    city?: string;
    state?: string;
    logoUrl?: string;
}
export interface UpdateCompanyDto extends Partial<CreateCompanyDto> {
}
export interface CreateCompanyContactDto {
    name: string;
    email: string;
    phone?: string;
    isPrimary?: boolean;
}
//# sourceMappingURL=company.dto.d.ts.map