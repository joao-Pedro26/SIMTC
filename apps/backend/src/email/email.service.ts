import { Injectable } from '@nestjs/common';
import { Resend } from 'resend';

@Injectable()
export class EmailService {
  private readonly resend = new Resend(process.env.RESEND_API_KEY);

  async sendCertificate(to: string, participantName: string, pdfBuffer: Buffer) {
    await this.resend.emails.send({
      from: 'SIM Treinamentos <noreply@simtc.com.br>',
      to,
      subject: `Seu certificado — SIM Treinamentos`,
      html: `<p>Olá, ${participantName}!</p>
             <p>Segue em anexo seu certificado de participação no treinamento de segurança no trânsito.</p>
             <p>Em caso de dúvidas, entre em contato: <a href="mailto:contato@simtc.com.br">contato@simtc.com.br</a></p>`,
      attachments: [
        {
          filename: `certificado-${participantName.toLowerCase().replace(/ /g, '-')}.pdf`,
          content: pdfBuffer.toString('base64'),
        },
      ],
    });
  }

  async sendClientPortalAccess(to: string, name: string, tempPassword: string) {
    await this.resend.emails.send({
      from: 'SIM Treinamentos <noreply@simtc.com.br>',
      to,
      subject: 'Acesso ao Portal do Cliente — SIM Treinamentos',
      html: `<p>Olá, ${name}!</p>
             <p>Seu acesso ao Portal do Cliente foi criado.</p>
             <p><strong>E-mail:</strong> ${to}<br>
             <strong>Senha temporária:</strong> ${tempPassword}</p>
             <p>Acesse em: <a href="${process.env.FRONTEND_URL}">${process.env.FRONTEND_URL}</a></p>`,
    });
  }
}
