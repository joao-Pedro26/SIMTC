import { IsEnum, IsOptional, IsString } from "class-validator";

export enum ParticipationType {
    SOMENTE_TEORICA = 'SOMENTE_TEORICA',
    TEORICA_E_PRATICA = 'TEORICA_E_PRATICA',
}

export class AddParticipantDto {
    
    @IsString()
    cpf!: string;

    @IsString()
    name!: string;

    @IsString()
    @IsOptional()
    email?: string;

    @IsString()
    @IsOptional()
    cnhCategory?: string;

    @IsString()
    @IsOptional()
    cnhExpiration?: string;

    @IsEnum(ParticipationType)
    @IsOptional()
    participationType?: ParticipationType;
}