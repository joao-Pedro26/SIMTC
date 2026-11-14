import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import {
  ImportParticipantsDto,
  ParticipantImportRowDto,
  ParticipationType as SharedParticipationType,
  PARTICIPANT_IMPORT_MAX_ROWS,
} from '@simtc/shared-types';
import { ParticipationType } from './add-participant.dto';

/**
 * Aqui só se confere o formato do corpo. O conteúdo (CPF, CNH, e-mail, data,
 * tipo) é revalidado no `ParticipantImportService` de propósito: linha ruim
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

  @IsOptional()
  @IsString()
  participationType?: SharedParticipationType;
}

export class ImportParticipantsBodyDto implements ImportParticipantsDto {
  @IsEnum(ParticipationType)
  defaultParticipationType!: SharedParticipationType;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(PARTICIPANT_IMPORT_MAX_ROWS)
  @ValidateNested({ each: true })
  @Type(() => ImportParticipantRowBodyDto)
  rows!: ImportParticipantRowBodyDto[];
}
