import { IsString, MaxLength, MinLength } from 'class-validator';

export class CreateVehicleTypeDto {
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  name!: string;
}
