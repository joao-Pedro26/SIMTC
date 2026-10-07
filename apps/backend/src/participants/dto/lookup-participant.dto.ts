import { IsString } from "class-validator";

export class LookupParticipantDto {

    @IsString()
    cpf!: string;
}
