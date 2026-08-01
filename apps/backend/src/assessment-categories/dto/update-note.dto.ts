import { IsString, IsInt, IsOptional, Min } from 'class-validator';

export class UpdateNoteDto {
  @IsString()
  @IsOptional()
  comment?: string;

  @IsInt()
  @Min(1)
  @IsOptional()
  deduction?: number;
}
