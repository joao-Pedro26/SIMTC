export interface CreateCourseDto {
    name: string;
    /** Id de um tipo de veículo cadastrado (/vehicle-types) */
    vehicleTypeId: string;
    theoryHours: number;
    practiceHours?: number;
    description: string;
    /** Tópicos (AssessmentCategory) que valem para o curso */
    categoryIds?: string[];
}
export interface UpdateCourseDto extends Partial<CreateCourseDto> {
}
//# sourceMappingURL=course.dto.d.ts.map