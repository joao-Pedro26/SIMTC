import { IsBoolean, IsOptional, IsString } from 'class-validator';

// DTO separado para update — NÃO estende CreateConsultantDto pois:
// - password não existe no modelo Consultant (fica em User)
// - email requer atualização coordenada em User (não suportada aqui)
export class UpdateConsultantDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  phone?: string;

  @IsString()
  @IsOptional()
  credentialDetran?: string;

  // Permite reativar um consultor arquivado (ver ConsultantsService.deleteConsultant).
  // Não é exposto como campo editável para desativar diretamente — desativação
  // só acontece via DELETE quando há histórico vinculado.
  @IsBoolean()
  @IsOptional()
  active?: boolean;
}