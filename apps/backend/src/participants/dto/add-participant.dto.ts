import { IsEmail, IsEnum, IsIn, IsOptional, IsString } from "class-validator";
import { CNH_CATEGORIES } from "../cnh.constants";

export enum ParticipationType {
    SOMENTE_TEORICA = 'SOMENTE_TEORICA',
    TEORICA_E_PRATICA = 'TEORICA_E_PRATICA',
}

export class AddParticipantDto {
    
    @IsString()
    cpf!: string;

    @IsString()
    name!: string;

    @IsEmail({}, { message: 'E-mail inválido' })
    @IsOptional()
    email?: string;

    @IsIn(CNH_CATEGORIES, { message: `Categoria de CNH inválida (use: ${CNH_CATEGORIES.join(', ')})` })
    @IsOptional()
    cnhCategory?: string;

    @IsString()
    @IsOptional()
    cnhExpiration?: string;

    @IsEnum(ParticipationType)
    @IsOptional()
    participationType?: ParticipationType;
}