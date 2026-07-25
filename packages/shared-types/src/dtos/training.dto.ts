import { ParticipationType, TrainingStatus } from '../enums';

export interface CreateTrainingSessionDto {
  companyId: string;
  courseId: string;
  responsibleConsultantId: string;
  city: string;
  state: string;
  date?: string;         // ISO date
  participantCount?: number;
  notes?: string;
  consultantIds?: string[];
}

export interface UpdateTrainingSessionDto extends Partial<CreateTrainingSessionDto> {
  status?: TrainingStatus;
}

export interface RegisterParticipantPublicDto {
  name: string;
  cpf: string;
  email?: string;
  cnhCategory?: string;
  cnhExpiration?: string; // ISO date
}

export interface UpdateParticipantTypeDto {
  participationType: ParticipationType;
}
