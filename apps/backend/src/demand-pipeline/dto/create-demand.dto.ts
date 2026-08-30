import { IsInt, IsOptional, IsString, Min } from "class-validator";

export class CreateDemandDto {

    @IsString()
    companyId!: string;

    @IsString()
    consultantId!: string;

    @IsString()
    courseId!: string;

    @IsInt()
    @Min(1)
    @IsOptional()
    participantCount?: number;

    @IsString()
    @IsOptional()
    notes?: string;
}

