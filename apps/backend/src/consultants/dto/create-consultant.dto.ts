import { IsEmail, IsString, IsOptional } from "class-validator";

export class CreateConsultantDto {

    @IsString()
    name!: string;

    @IsEmail()
    email!: string;

    @IsString()
    @IsOptional()
    phone?: string;
}
