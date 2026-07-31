import { IsEmail, IsOptional, IsString } from "class-validator";

export class CreateContactUserDto {
    
    @IsString()
    name!: string;

    @IsEmail()
    email!: string;

    @IsString()
    @IsOptional()
    phone?: string;
}