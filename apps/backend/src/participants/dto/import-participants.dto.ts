import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import {
  ImportParticipantsDto,
  ParticipantImportRowDto,
  PARTICIPANT_IMPORT_MAX_ROWS,
} from '@simtc/shared-types';

/**
 * Aqui só se confere o formato do corpo. O conteúdo (CPF, CNH, e-mail, data) é revalidado no `ParticipantImportService` de propósito: linha ruim
 * vira `skipped` no resultado, em vez de um 400 que derrubaria o lote todo.
 */
export class ImportParticipantRowBodyDto implements ParticipantImportRowDto {
  @IsInt()
  rowNumber!: number;

  @IsString()
  name!: string;

  @IsString()
  cpf!: string;

  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @IsString()
  cnhCategory?: string;

  @IsOptional()
  @IsString()
  cnhExpiration?: string;
}

export class ImportParticipantsBodyDto implements ImportParticipantsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(PARTICIPANT_IMPORT_MAX_ROWS)
  @ValidateNested({ each: true })
  @Type(() => ImportParticipantRowBodyDto)
  rows!: ImportParticipantRowBodyDto[];
}
