import { IsEnum } from "class-validator";
import { ParticipationType } from "./add-participant.dto";

export class UpdateParticipantTypeDto {
    @IsEnum(ParticipationType)
    participationType!: ParticipationType;

}