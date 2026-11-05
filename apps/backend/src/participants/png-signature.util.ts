import { BadRequestException } from '@nestjs/common';

const PNG_SIGNATURE = Buffer.from('89504E470D0A1A0A', 'hex');
const PNG_MIN_LENGTH = 24;
const PNG_MAX_DIMENSION = 2000;

export function assertValidSignaturePng(buffer: Buffer): void {
  if (buffer.length < PNG_MIN_LENGTH) {
    throw new BadRequestException('Assinatura inválida: arquivo muito pequeno para ser um PNG.');
  }

  if (!buffer.subarray(0, PNG_SIGNATURE.length).equals(PNG_SIGNATURE)) {
    throw new BadRequestException('Assinatura inválida: o arquivo não é um PNG.');
  }

  const width = buffer.readUInt32BE(16);
  const height = buffer.readUInt32BE(20);

  if (width > PNG_MAX_DIMENSION || height > PNG_MAX_DIMENSION) {
    throw new BadRequestException(
      `Assinatura inválida: dimensões máximas de ${PNG_MAX_DIMENSION}x${PNG_MAX_DIMENSION} pixels.`,
    );
  }
}
