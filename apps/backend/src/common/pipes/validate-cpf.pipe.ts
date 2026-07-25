import { PipeTransform, Injectable, BadRequestException } from '@nestjs/common';

@Injectable()
export class ValidateCpfPipe implements PipeTransform {
  transform(value: string): string {
    const cpf = value.replace(/\D/g, '');
    if (cpf.length !== 11 || /^(\d)\1+$/.test(cpf)) {
      throw new BadRequestException('CPF inválido');
    }
    // Validação do dígito verificador
    for (let t = 9; t < 11; t++) {
      let sum = 0;
      for (let d = 0; d < t; d++) {
        sum += parseInt(cpf[d]) * (t + 1 - d);
      }
      const check = (sum * 10) % 11 % 10;
      if (check !== parseInt(cpf[t])) {
        throw new BadRequestException('CPF inválido');
      }
    }
    return cpf;
  }
}
