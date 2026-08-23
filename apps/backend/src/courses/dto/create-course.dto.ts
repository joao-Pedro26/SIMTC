import { IsArray, IsEnum, IsNumber, IsOptional, IsString, Max, MaxLength, Min, MinLength } from "class-validator";

enum VehicleType {
  LEVE = 'LEVE',
  PESADO = 'PESADO',
  MOTO = 'MOTO'
}

export class CreateCourseDto { 

    @IsString()
    name!: string;

    @IsEnum(VehicleType)
    vehicleType!: VehicleType;

    @IsNumber()
    @Min(0) 
    theoryHours!: number;

    @IsNumber()
    @Min(0)
    @IsOptional()
    practiceHours!: number;

    @IsString()
    @MinLength(2)
    @MaxLength(1000)
    description!: string;

    @IsOptional()
    @IsArray()
    contentItems?: any[];
}
