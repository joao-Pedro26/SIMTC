import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { SignatureLookupDto } from 'src/participants/dto/signature-lookup.dto';
import { PublicRegisterController } from 'src/participants/public-register.controller';
import { ParticipantsService } from 'src/participants/participants.service';

describe('SignatureLookupDto', () => {
  const errorsOf = (body: object) => validate(plainToInstance(SignatureLookupDto, body));

  it('aceita CPF válido (com ou sem máscara) e e-mail válido', async () => {
    await expect(errorsOf({ cpf: '52998224725', email: 'joao@mail.com' })).resolves.toEqual([]);
    await expect(errorsOf({ cpf: '529.982.247-25', email: 'joao@mail.com' })).resolves.toEqual([]);
  });

  it('recusa CPF com dígito verificador errado', async () => {
    const errors = await errorsOf({ cpf: '529.982.247-26', email: 'joao@mail.com' });
    expect(errors.map((e) => e.property)).toEqual(['cpf']);
  });

  it('recusa CPF com todos os dígitos iguais', async () => {
    const errors = await errorsOf({ cpf: '11111111111', email: 'joao@mail.com' });
    expect(errors.map((e) => e.property)).toEqual(['cpf']);
  });

  it('recusa CPF que não é texto', async () => {
    const errors = await errorsOf({ cpf: 52998224725, email: 'joao@mail.com' });
    expect(errors.map((e) => e.property)).toEqual(['cpf']);
  });

  it('recusa e-mail que não é e-mail, ou ausente', async () => {
    const invalido = await errorsOf({ cpf: '52998224725', email: 'joao-sem-arroba' });
    expect(invalido.map((e) => e.property)).toEqual(['email']);

    const ausente = await errorsOf({ cpf: '52998224725' });
    expect(ausente.map((e) => e.property)).toEqual(['email']);
  });
});

describe('PublicRegisterController.signaturePreview', () => {
  it('repassa token e corpo ao service', async () => {
    const svc = { signaturePreview: jest.fn().mockResolvedValue({ status: 'none' }) };
    const controller = new PublicRegisterController(svc as unknown as ParticipantsService);
    const dto = { cpf: '52998224725', email: 'joao@mail.com' };

    const result = await controller.signaturePreview('token-1', dto);

    expect(svc.signaturePreview).toHaveBeenCalledWith('token-1', dto);
    expect(result).toEqual({ status: 'none' });
  });
});
