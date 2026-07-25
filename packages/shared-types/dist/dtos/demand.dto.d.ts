import { DemandStatus } from '../enums';
export interface CreateDemandDto {
    companyId: string;
    consultantId: string;
    courseId: string;
    participantCount?: number;
    notes?: string;
}
export interface UpdateDemandStatusDto {
    status: DemandStatus;
}
//# sourceMappingURL=demand.dto.d.ts.map