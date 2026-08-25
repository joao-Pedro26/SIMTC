import { Injectable, Logger } from '@nestjs/common';
import { Resend } from 'resend';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private readonly resend = new Resend(process.env.RESEND_API_KEY);
  private readonly from = process.env.EMAIL_FROM ?? 'SIM Treinamentos <noreply@simtc.com.br>';
  private readonly simLogoUrl =
    process.env.SIM_LOGO_URL ?? `${process.env.SUPABASE_URL}/storage/v1/object/public/logos/logo-sim-treinamentos.png`;
  
  private readonly brandBarUrl =
    process.env.EMAIL_BRAND_BAR_URL ??
    `${process.env.SUPABASE_URL}/storage/v1/object/public/logos/email-brand-bar.png`; 

  /**
   * Envia o certificado de participação e, se fornecido, o relatório de avaliação
   * técnica em anexo no mesmo e-mail. Usa o template "certificado-relatorio" criado
   * no dashboard do Resend (ver assets/email-templates/certificado-relatorio.html) —
   * as variáveis {{{simLogoUrl}}}, {{{companyLogoUrl}}}, {{{brandBarUrl}}},
   * {{{participantName}}} e {{{anoAtual}}} são resolvidas pelo próprio Resend a
   * partir de `template.variables` (chaves triplas — é a sintaxe de interpolação
   * do Resend, chaves duplas não renderizam).
   */
  async sendCertificateAndReport(
    to: string,
    participantName: string,
    courseName: string,
    certificatePdfBuffer: Buffer,
    companyLogoUrl?: string | null,
    reportPdfBuffer?: Buffer | null,
  ) {
    const fileSlug = participantName.toLowerCase().replace(/ /g, '-');

    const attachments = [
      {
        filename: `certificado-${fileSlug}.pdf`,
        content: certificatePdfBuffer.toString('base64'),
      },
    ];

    if (reportPdfBuffer) {
      attachments.push({
        filename: `relatorio-${fileSlug}.pdf`,
        content: reportPdfBuffer.toString('base64'),
      });
    }

    const { data, error } = await this.resend.emails.send({
      from: this.from,
      to,
      subject: reportPdfBuffer
        ? 'Seu certificado e relatório — SIM Treinamentos'
        : 'Seu certificado — SIM Treinamentos',
      template: {
        id: 'certificado-relatorio',
        variables: {
          simLogoUrl: this.simLogoUrl,
          companyLogoUrl: companyLogoUrl ?? this.simLogoUrl,
          brandBarUrl: this.brandBarUrl,
          participantName,
          courseName,
          anoAtual: String(new Date().getFullYear()),
        },
      },
      attachments,
    } as any);

    if (error) {
      this.logger.error(`Falha ao enviar certificado/relatório para ${to}: ${JSON.stringify(error)}`);
      throw new Error(`Falha ao enviar e-mail via Resend: ${error.message ?? JSON.stringify(error)}`);
    }

    return data;
  }

  async sendOtpCode(
    to: string, 
    code: string,
    participantName: string,
  ) {
    const { data, error } = await this.resend.emails.send({
      from: this.from,
      to,
      subject: 'Seu código de acesso — SIM Treinamentos',
      template: {
        id: 'otp-code',
        variables : {
          simLogoUrl: this.simLogoUrl,
          brandBarUrl: this.brandBarUrl,
          participantName,
          code,
          anoAtual: String(new Date().getFullYear()),
        },
      },
    } as any);

    if (error) {
      this.logger.error(`Falha ao enviar p código otp para ${to}: ${JSON.stringify(error)}`);
      throw new Error(`Falha ao enviar código otp via Resend: ${error.message ?? JSON.stringify(error)}`);
    }

    return data;
  }

  async sendPasswordReset(to: string, resetLink: string, participantName: string) {
    const { data, error } = await this.resend.emails.send({
      from: this.from,
      to,
      subject: 'Redefinição de senha — SIM Treinamentos',
      template: {
        id: 'password-reset',
        variables: {
          simLogoUrl: this.simLogoUrl,
          brandBarUrl: this.brandBarUrl,
          participantName,
          resetLink,
          anoAtual: String(new Date().getFullYear()),
        },
      },
    } as any);

    if (error) {
      this.logger.error(`Falha ao enviar e-mail de redefinição de senha para ${to}: ${JSON.stringify(error)}`);
      throw new Error(`Falha ao enviar e-mail via Resend: ${error.message ?? JSON.stringify(error)}`);
    }

    return data;
  }

  async sendRegistrationConfirmation(
     to: string,
     participantName: string,
     courseName: string,
     companyName: string, 
     companyLogoUrl: string | null
    ) {
    await this.resend.emails.send({
      from: this.from,
      to,
      subject: `Inscrição confirmada — ${courseName}`,
      template: {
        id: 'registration-confirmation',
        variables: {
          simLogoUrl: this.simLogoUrl,
          brandBarUrl: this.brandBarUrl,
          companyLogoUrl: companyLogoUrl,
          companyName,
          courseName,
          participantName,
          anoAtual: String(new Date().getFullYear()),
        },
      },
    } as any);
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
    const subject =
      mode === 'created'
        ? 'Seu acesso ao Sistema SIM Treinamentos foi criado'
        : 'Sua senha de acesso foi redefinida — SIM Treinamentos';
    const { data, error } = await this.resend.emails.send({
      from: this.from,
      to,
      subject,
      template: {
        id: mode === 'created' ? 'consultant-credentials-created' : 'consultant-credentials-reset',
        variables: {
          simLogoUrl: this.simLogoUrl,
          brandBarUrl: this.brandBarUrl,
          consultantName: name,
          email: to,
          password,
          accessUrl: process.env.FRONTEND_URL ?? 'https://app.simtc.com.br',
          anoAtual: String(new Date().getFullYear()),
        },
      },
    } as any);

    if (error) {
      this.logger.error(`Falha ao enviar credenciais para ${to}: ${JSON.stringify(error)}`);
      throw new Error(`Falha ao enviar e-mail via Resend: ${error.message ?? JSON.stringify(error)}`);
    }

    return data;
  }
}
