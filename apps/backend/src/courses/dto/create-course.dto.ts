import { IsArray, IsNotEmpty, IsNumber, IsOptional, IsString, MaxLength, Min, MinLength } from "class-validator";

export class CreateCourseDto {

    @IsString()
    name!: string;

    /** Id de um VehicleType cadastrado (GET /vehicle-types). */
    @IsString()
    @IsNotEmpty()
    vehicleTypeId!: string;

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

    /** Tópicos (AssessmentCategory) que valem para este curso. */
    @IsOptional()
    @IsArray()
    @IsString({ each: true })
    categoryIds?: string[];
}
