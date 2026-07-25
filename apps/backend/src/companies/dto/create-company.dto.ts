import { IsString, IsEmail, IsOptional, Length, IsNotEmpty, Validate, IsBoolean } from 'class-validator';
import { ValidateNested, IsArray, ArrayMinSize, ArrayMaxSize } from 'class-validator';
import { Type } from 'class-transformer';

class CreateCompanyContactDto {

    @IsString()
    @IsNotEmpty()
    name!: string;

    @IsEmail()
    @IsNotEmpty()
    email!: string;

    @IsOptional()
    @IsString()
    phone?: string;
}

export class CreateCompanyDto {

    @IsString()
    @IsNotEmpty()
    @Length(1, 100)
    name!: string;

    @IsString()
    @IsNotEmpty()
    @Length(14, 14)
    cnpj!: string;

    @IsString()
    @IsNotEmpty()
    address!: string;

    @IsString()
    @IsNotEmpty()
    city!: string;

    @IsString()
    @IsNotEmpty()
    state!: string;

    @IsArray()
    @ValidateNested({ each: true })
    @ArrayMinSize(1, { message: 'Informe ao menos 1 contato' })
    @ArrayMaxSize(3, { message: 'Máximo de 3 contatos por empresa' })
    @Type(() => CreateCompanyContactDto)
    contacts!: CreateCompanyContactDto[];

}