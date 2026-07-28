import { IsArray, IsDateString, IsInt, IsOptional, IsString, Min } from "class-validator";

export class CreateTrainingSessionDto {

    @IsString()
    companyId!: string;

    @IsString()
    courseId!: string;

    @IsString()
    responsibleConsultantId!: string;

    @IsString()
    city!: string;

    @IsString()
    state!: string;
    
    @IsOptional()
    @IsDateString()
    date?: string;

    @IsOptional()
    @IsInt()
    @Min(1)
    participantCount?: number;

    @IsOptional()
    @IsString()
    notes?: string;

    @IsOptional()
    @IsArray()
    @IsString(({ each: true }))
    additionalConsultantsIds?: string[];
}