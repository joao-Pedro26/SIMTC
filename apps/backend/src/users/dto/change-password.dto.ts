import { IsString, Min, MinLength } from "class-validator";

export class ChangePasswordDto {

    @IsString()
    currentPassword!: string;

    @IsString()
    @MinLength(8)
    newPassword!: string;
}