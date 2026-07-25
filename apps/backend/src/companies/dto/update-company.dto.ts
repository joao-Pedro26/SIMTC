import { PartialType } from '@nestjs/mapped-types';
import { CreateCompanyDto } from './create-company.dto';
import { IsEmail, IsOptional, Matches } from 'class-validator';

export class UpdateCompanyDto extends PartialType(CreateCompanyDto) {

    @IsEmail()
        @IsOptional()
        @Matches(/^[^@]+@simtc\.com\.br$/, { message: 'O e-mail deve ser do domínio @simtc.com.br' })
        email!: string;
}