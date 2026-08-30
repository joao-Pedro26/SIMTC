import { ArrayMinSize, IsArray, IsString } from "class-validator";

export class AssignParticipantsDto {

    @IsArray()
    @IsString({ each: true})
    @ArrayMinSize(1)
    participantIds!: string[];
}