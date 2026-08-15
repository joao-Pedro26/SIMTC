import { Injectable } from '@nestjs/common';
import { Resend } from 'resend';

@Injectable()
export class EmailService {
  private readonly resend = new Resend(process.env.RESEND_API_KEY);
  // Configurável via EMAIL_FROM — útil para testar com o remetente sandbox do
  // Resend (onboarding@resend.dev) antes do domínio simtc.com.br ser verificado.
  private readonly from = process.env.EMAIL_FROM ?? 'SIM Treinamentos <noreply@simtc.com.br>';

  async sendCertificate(to: string, participantName: string, pdfBuffer: Buffer) {
    await this.resend.emails.send({
      from: this.from,
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

  async sendOtpCode(to: string, code: string) {
    await this.resend.emails.send({
      from: this.from,
      to,
      subject: 'Seu código de acesso — SIM Treinamentos',
      html: `<p>Seu código de acesso ao Portal do Cliente é:</p>
             <h2 style="letter-spacing: 4px">${code}</h2>
             <p>Válido por 10 minutos. Não compartilhe este código.</p>`,
    });
  }

  async sendClientPortalAccess(to: string, name: string, tempPassword: string) {
    await this.resend.emails.send({
      from: this.from,
      to,
      subject: 'Acesso ao Portal do Cliente — SIM Treinamentos',
      html: `<p>Olá, ${name}!</p>
             <p>Seu acesso ao Portal do Cliente foi criado.</p>
             <p><strong>E-mail:</strong> ${to}<br>
             <strong>Senha temporária:</strong> ${tempPassword}</p>
             <p>Acesse em: <a href="${process.env.FRONTEND_URL}">${process.env.FRONTEND_URL}</a></p>`,
    });
  }

  async sendPasswordReset(to: string, resetLink: string) {
    await this.resend.emails.send({
      from: this.from,
      to,
      subject: 'Redefinição de senha — SIM Treinamentos',
      html: `<p>Recebemos uma solicitação para redefinir a senha da sua conta.</p>
             <p>Clique no link abaixo para criar uma nova senha. O link é válido por 1 hora.</p>
             <p><a href="${resetLink}">Redefinir minha senha</a></p>
             <p style="color:#6b7280; font-size: 0.9em;">Se você não solicitou isso, ignore este e-mail — sua senha permanece a mesma.</p>
             <p>Em caso de dúvidas: <a href="mailto:contato@simtc.com.br">contato@simtc.com.br</a></p>`,
    });
  }

  async sendRegistrationConfirmation(to: string, participantName: string, courseName: string, companyName: string) {
    await this.resend.emails.send({
      from: this.from,
      to,
      subject: `Inscrição confirmada — ${courseName}`,
      html: `<p>Olá, ${participantName}!</p>
             <p>Sua inscrição no treinamento <strong>${courseName}</strong> promovido pela empresa <strong>${companyName}</strong> foi confirmada com sucesso.</p>
             <p>Em caso de dúvidas, entre em contato: <a href="mailto:contato@simtc.com.br">contato@simtc.com.br</a></p>`,
    });
  }

  async sendTrainingScheduled(
    to: string,
    contactName: string,
    courseName: string,
    companyName: string,
    city: string | null,
    state: string | null,
    date: Date | null,
  ) {
    const location = [city, state].filter(Boolean).join(' - ') || 'a definir';
    const dateFormatted = date
      ? date.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' })
      : 'a definir';

    await this.resend.emails.send({
      from: this.from,
      to,
      subject: `Treinamento agendado: ${courseName} — SIM Treinamentos`,
      html: `<p>Olá, ${contactName}!</p>
             <p>Um novo treinamento foi agendado para a empresa <strong>${companyName}</strong>:</p>
             <p><strong>Curso:</strong> ${courseName}<br>
             <strong>Data:</strong> ${dateFormatted}<br>
             <strong>Local:</strong> ${location}</p>
             <p>Em caso de dúvidas, entre em contato: <a href="mailto:contato@simtc.com.br">contato@simtc.com.br</a></p>`,
    });
  }

  async sendConsultantCredentials(
    to: string,
    name: string,
    password: string,
    mode: 'created' | 'reset',
  ) {
    const accessUrl = process.env.FRONTEND_URL ?? 'https://app.simtc.com.br';

    const subject =
      mode === 'created'
        ? 'Seu acesso ao Sistema SIM Treinamentos foi criado'
        : 'Sua senha de acesso foi redefinida — SIM Treinamentos';

    const intro =
      mode === 'created'
        ? `<p>Olá, ${name}!</p>
           <p>Seu acesso ao Sistema de Automação de Treinamentos da SIM Treinamentos foi criado. Use os dados abaixo para fazer o primeiro acesso:</p>`
        : `<p>Olá, ${name}!</p>
           <p>Um administrador redefiniu sua senha de acesso ao Sistema de Automação de Treinamentos. Use os dados abaixo para entrar novamente:</p>`;

    const securityNote =
      mode === 'reset'
        ? `<p style="color:#b91c1c; font-size: 0.9em;">Se você não esperava essa redefinição, entre em contato imediatamente com um administrador.</p>`
        : '';

    await this.resend.emails.send({
      from: this.from,
      to,
      subject,
      html: `${intro}
             <p><strong>E-mail:</strong> ${to}<br>
             <strong>Senha temporária:</strong> ${password}</p>
             <p>Recomendamos alterar essa senha em "Meu Perfil" assim que possível.</p>
             <p>Acesse em: <a href="${accessUrl}">${accessUrl}</a></p>
             ${securityNote}
             <p>Em caso de dúvidas, entre em contato: <a href="mailto:contato@simtc.com.br">contato@simtc.com.br</a></p>`,
    });
  }
}
