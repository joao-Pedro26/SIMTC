export interface CreateConsultantDto {
  name: string;
  email: string;
  phone?: string;
  password: string; // criado pelo admin — hash no backend
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
