import { IsEnum } from "class-validator";

export enum DemandStatus {
    QUALIFICACAO = 'QUALIFICACAO',
    ANALISE = 'ANALISE',
    AGENDAMENTO = 'AGENDAMENTO',
}

export class UpdateDemandStatusDto {

    @IsEnum(DemandStatus)
    status! : DemandStatus;
}