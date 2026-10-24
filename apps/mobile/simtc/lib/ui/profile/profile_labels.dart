import '../../data/models/auth_user.dart';
import '../core/date_labels.dart';

/// Os textos da tela 1.10 Perfil (Fase 8A), separados da tela para os testes.

/// "Consultor" ou "Administrador" — a linha "Perfil de acesso", que faz as
/// vezes do selo "Admin" do brainstorm.
String roleLabel(AppUserRole role) => switch (role) {
      AppUserRole.consultant => 'Consultor',
      AppUserRole.admin => 'Administrador',
    };

/// A linha "Última sincronização": só o momento ("hoje 07:12"), porque o
/// rótulo da linha já diz o que é. O mesmo instante da aba Sincronizar.
String lastSyncValue(DateTime? at, DateTime now) =>
    at == null ? 'Nenhum envio' : momentLabel(at, now);

/// "36 KB", "18,4 MB", "1,2 GB" — o espaço do "Limpar cache local".
String sizeLabel(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  String oneDecimal(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');

  if (bytes >= gb) return '${oneDecimal(bytes / gb)} GB';
  if (bytes >= mb) return '${oneDecimal(bytes / mb)} MB';
  return '${(bytes / kb).ceil()} KB';
}

/// O corpo da confirmação do "Sair da conta" (decisão de 24/10/2026: avisa e
/// deixa sair). Um parágrafo por assunto, separados por linha em branco.
String logoutMessage({
  required int queued,
  required int drafts,
  required bool offline,
}) {
  return [
    'As sessões baixadas neste aparelho serão apagadas.',
    if (queued == 1)
      'A avaliação na fila fica guardada neste aparelho e é enviada quando '
          'você entrar de novo.',
    if (queued > 1)
      '$queued avaliações na fila ficam guardadas neste aparelho e são '
          'enviadas quando você entrar de novo.',
    if (drafts == 1)
      'A avaliação iniciada fica guardada para você continuar quando entrar '
          'de novo.',
    if (drafts > 1)
      '$drafts avaliações iniciadas ficam guardadas para você continuar '
          'quando entrar de novo.',
    if (offline) 'Sem conexão, você só consegue entrar de novo quando houver rede.',
  ].join('\n\n');
}
