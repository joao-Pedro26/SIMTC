import { Type } from "class-transformer";
import { ArrayMaxSize, ArrayMinSize, IsArray, IsEnum, IsInt, IsOptional, IsString, Min, ValidateNested } from "class-validator";
// ArrayMinSize mantido pois ainda é usado em CreateInfractionDto (notes)

enum NoteType {
    B = 'B',
    PM = 'PM',
    M = 'M'
}

class CreateInfractionNoteDto {
    
    @IsEnum(NoteType)
    noteType!: NoteType;

    @IsString()
    @IsOptional()
    comment?: string;

    @IsInt()
    @Min(1)
    deduction!: number;
}

export class CreateInfractionDto {
    
    @IsString()
    description!: string;

    @IsInt()
    @IsOptional()
    order?: number;

    @IsArray()
    @ValidateNested({each: true})
    @ArrayMinSize(3, { message: 'Informe exatamente 3 notas (B, PM, M)' })
    @ArrayMaxSize(3, { message: 'Informe exatamente 3 notas (B, PM, M)' })
    @Type(() => CreateInfractionNoteDto)
    notes!: CreateInfractionNoteDto[];
}

export class CreateAssessmentCategoryDto {

    @IsString()
    code!: string;

    @IsString()
    name!: string;

    @IsString()
    @IsOptional()
    description?: string;

    @IsInt()
    @IsOptional()   
    order?: number;

    @IsArray()
    @ValidateNested({each: true})
    @Type(() => CreateInfractionDto)
    infractions!: CreateInfractionDto[]
}