import { IsEmail, IsString, IsOptional, Matches, MinLength } from "class-validator";

export class CreateConsultantDto {

    @IsString()
    name!: string;

    @IsEmail()
    @Matches(/^[^@]+@simtc\.com\.br$/, { message: 'O e-mail deve ser do domínio @simtc.com.br' })
    email!: string;

    @IsString()
    @IsOptional()
    phone?: string;

    @IsString()
    @MinLength(8, { message: 'A senha de ter no mínimo 8 caracteres.' })
    password!: string;
}