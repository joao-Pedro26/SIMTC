import { IsEmail, IsString, Validate, ValidatorConstraint, ValidatorConstraintInterface } from 'class-validator';
import { ValidateCpfPipe } from '../../common/pipes/validate-cpf.pipe';

/** Mesma regra de CPF do `ValidateCpfPipe` (aceita com ou sem máscara). */
@ValidatorConstraint({ name: 'cpfValido' })
class CpfValidoConstraint implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    if (typeof value !== 'string') return false;
    try {
      new ValidateCpfPipe().transform(value);
      return true;
    } catch {
      return false;
    }
  }

  defaultMessage(): string {
    return 'CPF inválido';
  }
}

/** Corpo da prévia da assinatura: CPF e e-mail, que precisam bater com o cadastro. */
export class SignatureLookupDto {
  @IsString()
  @Validate(CpfValidoConstraint)
  cpf!: string;

  @IsEmail({}, { message: 'E-mail inválido' })
  email!: string;
}
