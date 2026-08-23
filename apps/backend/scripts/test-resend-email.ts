/**
 * Script de teste manual do Resend — roda fora do NestJS, só pra confirmar
 * que a RESEND_API_KEY e o remetente (EMAIL_FROM) configurados no
 * .env.development estão funcionando, antes do domínio simtc.com.br
 * ser verificado.
 *
 * Uso (de dentro de apps/backend):
 *   npm run test:email -- seuemail@exemplo.com
 *
 * Importante: enquanto o domínio não estiver verificado no Resend, só é
 * possível enviar para o e-mail com o qual você criou a conta no Resend.
 */
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env.development') });

import { Resend } from 'resend';

async function main() {
  const to = process.argv[2];
  if (!to) {
    console.error('Uso: npm run test:email -- seuemail@exemplo.com');
    process.exit(1);
  }

  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey || apiKey === 're_...') {
    console.error('RESEND_API_KEY não encontrada (ou é só o placeholder) no .env.development');
    process.exit(1);
  }

  const from = process.env.EMAIL_FROM ?? 'SIM Treinamentos <onboarding@resend.dev>';
  const resend = new Resend(apiKey);

  console.log(`Enviando e-mail de teste de "${from}" para "${to}"...`);

  const result = await resend.emails.send({
    from,
    to,
    subject: 'Teste de envio — Sistema SIMTC',
    html: '<p>Se você recebeu este e-mail, a configuração do Resend está funcionando corretamente.</p>',
  });

  console.log(JSON.stringify(result, null, 2));
}

main().catch((err) => {
  console.error('Erro ao enviar e-mail:', err);
  process.exit(1);
});
