import { VehicleType } from '../enums';

export interface CreateCourseDto {
  name: string;
  vehicleType: VehicleType;
  theoryHours: number;
  practiceHours?: number;
  description: string;
  /** Tópicos (AssessmentCategory) que valem para o curso */
  categoryIds?: string[];
}

export interface UpdateCourseDto extends Partial<CreateCourseDto> {}
