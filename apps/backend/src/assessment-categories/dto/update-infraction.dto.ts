import { IsString, IsInt, IsOptional } from 'class-validator';

export class UpdateInfractionDto {
  @IsString()
  @IsOptional()
  description?: string;

  @IsInt()
  @IsOptional()
  order?: number;
}