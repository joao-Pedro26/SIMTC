import { Injectable } from '@nestjs/common';
import * as QRCode from 'qrcode';

@Injectable()
export class QrCodeService {
  async generatePng(token: string, baseUrl: string): Promise<Buffer> {
    const url = `${baseUrl}/register/${token}`;
    return QRCode.toBuffer(url, {
      type: 'png',
      width: 400,
      margin: 2,
      errorCorrectionLevel: 'M',
    });
  }
}
