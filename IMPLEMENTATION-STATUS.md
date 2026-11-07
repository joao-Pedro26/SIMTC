# Status de Implementação — Sistema WEB SIMTC

> Referência: `brainstorm-implementacao-web.md`. Atualizar esta tabela ao iniciar e concluir cada fase.

| Fase | Descrição | Status | Data | Observações |
|------|-----------|--------|------|-------------|
| 0.5 | Login unificado (e-mail → senha ou OTP) + senha auto-gerada do consultor por e-mail | concluído (Resend testado; falta verificar domínio simtc.com.br) | 2026-08-14 | Fora da ordem original — feita antes por bloquear login de consultor/cliente. Cobre parte das fases 1.2, 2, 3, 5 e 8. Backend: `POST /auth/check-email`, `POST /consultants/:id/reset-password`, `EmailService.sendConsultantCredentials`. Frontend: login em 2 etapas (`(auth)/login/page.tsx`), form de consultor sem campo de senha, botão "Gerar nova senha e reenviar" na edição. `tsc --noEmit` ok no backend e no web. Resend testado com sucesso via `npm run test:email` (remetente sandbox `onboarding@resend.dev`, API key real já em `.env.development`). Falta: verificar domínio `simtc.com.br` no Resend (registros DNS) e então remover o `EMAIL_FROM` temporário do `.env.development`. |
| 1 | Segurança: logout real, role-guard no frontend, escopo de reports para CLIENT | pendente | — | — |
| 2 | Esqueci minha senha (Admin/Consultor) | pendente | — | — |
| 3 | Perfil do consultor + navegação básica | pendente | — | — |
| 4 | Relatórios (Admin) + cleanup de rotas mortas | pendente | — | Depende de 1.3 |
| 5 | Portal do Cliente — login via OTP | pendente | — | Depende de 1.2 |
| 6 | Portal do Cliente — fix ownership em `getSessionReport` + dashboard "Minha Empresa" (reaproveitando Sidebar/Header do admin) | pendente | — | Depende de 5 e 1.3. Revisado 15/08/2026: inclui fix de segurança em `ReportsService.getSessionReport` (sem checagem de papel/empresa hoje) |
| 6.5 | Portal do Cliente — detalhe do treinamento: abas Participantes + Relatório de Avaliação Técnica em PDF, por participante (geração nova no backend, reaproveitando `PdfGeneratorService`/`StorageService` dos certificados; modelo de layout em `assets/relatorios/` + `assets/ASSETS-CONTEXT.md`) | pendente | — | Nova fase (15/08/2026, corrigida no mesmo dia de per-sessão para per-participante após revisar `assets/relatorios/`). Depende de 6. Bucket Supabase `reports` já criado (15/08/2026) — pré-requisito manual resolvido, pode implementar assumindo que ele existe. Campos novos vão em `PracticalAssessment` (`reportPdfUrl`/`reportGeneratedAt`), não em `TrainingSession` |
| 7 | Portal do Cliente — aba Certificados (mesma tela da 6.5) + gestão de Responsáveis (admin) | pendente | — | Depende de 6.5 (revisado 15/08/2026 — antes dependia de 6, certificados agora é aba, não rota própria) |
| 8 | E-mails faltantes (boas-vindas, confirmação, notificações, lembrete agendado) | pendente | — | Depende de 3, 6, 7 |
| 9 | Revisão final (sem código novo — checklist manual por papel) | pendente | — | Depende de todas |
