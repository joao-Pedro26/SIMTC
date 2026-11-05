import { BadRequestException } from '@nestjs/common';
import { assertValidSignaturePng } from 'src/participants/png-signature.util';

const PNG_SIGNATURE = Buffer.from('89504E470D0A1A0A', 'hex');

function makePng(width: number, height: number): Buffer {
  const buf = Buffer.alloc(24);
  PNG_SIGNATURE.copy(buf, 0);
  buf.writeUInt32BE(13, 8); // comprimento do chunk IHDR
  buf.write('IHDR', 12, 'ascii');
  buf.writeUInt32BE(width, 16);
  buf.writeUInt32BE(height, 20);
  return buf;
}

describe('assertValidSignaturePng', () => {
  it('aceita PNG 600x200', () => {
    expect(() => assertValidSignaturePng(makePng(600, 200))).not.toThrow();
  });

  it('recusa buffer que não é PNG', () => {
    const notPng = Buffer.alloc(24, 0x41);
    expect(() => assertValidSignaturePng(notPng)).toThrow(BadRequestException);
  });

  it('recusa buffer com menos de 24 bytes', () => {
    expect(() => assertValidSignaturePng(PNG_SIGNATURE)).toThrow(BadRequestException);
  });

  it('recusa 2001x100', () => {
    expect(() => assertValidSignaturePng(makePng(2001, 100))).toThrow(BadRequestException);
  });

  it('recusa 100x2001', () => {
    expect(() => assertValidSignaturePng(makePng(100, 2001))).toThrow(BadRequestException);
  });
});
