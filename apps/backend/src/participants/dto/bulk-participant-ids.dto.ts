import { ArrayNotEmpty, IsArray, IsString } from 'class-validator';

export class BulkParticipantIdsDto {
  @IsArray()
  @ArrayNotEmpty()
  @IsString({ each: true })
  participantIds: string[];
}
