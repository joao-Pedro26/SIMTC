import { NoteType } from '../enums';

export interface CreateAssessmentCategoryDto {
  code: string;
  name: string;
  description?: string;
  order?: number;
}

export interface CreateInfractionDto {
  categoryId: string;
  description: string;
  order?: number;
  notes: {
    noteType: NoteType;
    comment?: string;
    deduction: number;
  }[];
}

export interface SyncPracticalAssessmentDto {
  trainingParticipantId: string;
  consultantId?: string;   // opcional — no web vem do JWT; no mobile pode ser enviado
  date: string;            // ISO date
  startTime: string;       // ISO datetime
  endTime?: string;
  items: {
    infractionNoteId: string;
  }[];
}
