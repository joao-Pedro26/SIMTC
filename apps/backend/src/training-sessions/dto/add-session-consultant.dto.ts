import { IsNotEmpty, IsString } from 'class-validator';

/** Corpo do `POST /training-sessions/:id/consultants`: quem entra na sessão. */
export class AddSessionConsultantDto {
  @IsString()
  @IsNotEmpty()
  consultantId!: string;
}
