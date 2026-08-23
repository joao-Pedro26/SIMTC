export interface CreateConsultantDto {
  name: string;
  email: string;
  phone?: string;
  // Senha não é mais definida pelo admin: é gerada automaticamente no backend
  // e enviada por e-mail ao consultor (ver EmailService.sendConsultantCredentials).
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
