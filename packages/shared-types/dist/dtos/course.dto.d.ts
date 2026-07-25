import { VehicleType } from '../enums';
export interface CreateCourseDto {
    name: string;
    vehicleType: VehicleType;
    theoryHours: number;
    practiceHours?: number;
    description: string;
}
export interface UpdateCourseDto extends Partial<CreateCourseDto> {
}
//# sourceMappingURL=course.dto.d.ts.map