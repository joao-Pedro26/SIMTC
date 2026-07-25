import { IsEmail, IsString, IsOptional, Matches } from "class-validator";

export class CreateConsultantDto {

    @IsString()
    name!: string;

    @IsEmail()
    @Matches(/^[^@]+@simtc\.com\.br$/, { message: 'O e-mail deve ser do domínio @simtc.com.br' })
    email!: string;

    @IsString()
    @IsOptional()
    phone?: string;
}