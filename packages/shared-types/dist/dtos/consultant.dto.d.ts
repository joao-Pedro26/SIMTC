export interface CreateConsultantDto {
    name: string;
    email: string;
    phone?: string;
    password: string;
}
export interface UpdateConsultantDto {
    name?: string;
    phone?: string;
    signatureUrl?: string;
}
export interface UpdateConsultantPasswordDto {
    currentPassword: string;
    newPassword: string;
}
//# sourceMappingURL=consultant.dto.d.ts.map