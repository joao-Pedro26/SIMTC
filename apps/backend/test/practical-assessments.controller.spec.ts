import { BadRequestException, NotFoundException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { Reflector } from '@nestjs/core';
import { PracticalAssessmentsController } from 'src/practical-assessments/practical-assessments.controller';
import { PracticalAssessmentsService } from 'src/practical-assessments/practical-assessments.service';
import { RolesGuard } from 'src/auth/guards/roles.guard';
import { ROLES_KEY } from 'src/auth/decorators/roles.decorator';

const mockService = {
  uploadParticipantSignature: jest.fn(),
  getParticipantSignatureSignedUrl: jest.fn(),
};

function fakeFile(mimetype: string): Express.Multer.File {
  return { mimetype, buffer: Buffer.from('x'), size: 1 } as Express.Multer.File;
}

describe('PracticalAssessmentsController — assinatura do participante', () => {
  const controller = new PracticalAssessmentsController(
    mockService as unknown as PracticalAssessmentsService,
  );
  const reflector = new Reflector();

  beforeEach(() => jest.clearAllMocks());

  it('upload exige RolesGuard com ADMIN ou CONSULTANT (CLIENT bloqueado)', () => {
    const handler = PracticalAssessmentsController.prototype.uploadParticipantSignature;
    expect(reflector.get(GUARDS_METADATA, handler)).toContain(RolesGuard);
    expect(reflector.get(ROLES_KEY, handler)).toEqual(['ADMIN', 'CONSULTANT']);
  });

  it('leitura da signed URL exige RolesGuard com ADMIN ou CONSULTANT (CLIENT bloqueado)', () => {
    const handler = PracticalAssessmentsController.prototype.getParticipantSignatureUrl;
    expect(reflector.get(GUARDS_METADATA, handler)).toContain(RolesGuard);
    expect(reflector.get(ROLES_KEY, handler)).toEqual(['ADMIN', 'CONSULTANT']);
  });

  it('recusa arquivo que não é PNG/JPEG', () => {
    expect(() =>
      controller.uploadParticipantSignature('assess-1', fakeFile('application/pdf')),
    ).toThrow(BadRequestException);
    expect(mockService.uploadParticipantSignature).not.toHaveBeenCalled();
  });

  it('repassa o PNG para o service', async () => {
    mockService.uploadParticipantSignature.mockResolvedValue({ signedUrl: 'https://s' });
    const file = fakeFile('image/png');

    await expect(controller.uploadParticipantSignature('assess-1', file)).resolves.toEqual({
      signedUrl: 'https://s',
    });
    expect(mockService.uploadParticipantSignature).toHaveBeenCalledWith(
      'assess-1',
      file.buffer,
      'image/png',
    );
  });

  it('responde 404 quando não há assinatura', async () => {
    mockService.getParticipantSignatureSignedUrl.mockResolvedValue(null);

    await expect(controller.getParticipantSignatureUrl('assess-1')).rejects.toThrow(
      NotFoundException,
    );
  });

  it('devolve a signed URL quando há assinatura', async () => {
    mockService.getParticipantSignatureSignedUrl.mockResolvedValue({ signedUrl: 'https://s' });

    await expect(controller.getParticipantSignatureUrl('assess-1')).resolves.toEqual({
      signedUrl: 'https://s',
    });
  });
});
