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
    consultantId: string;
    date: string;
    startTime: string;
    endTime?: string;
    items: {
        infractionNoteId: string;
    }[];
}
//# sourceMappingURL=assessment.dto.d.ts.map