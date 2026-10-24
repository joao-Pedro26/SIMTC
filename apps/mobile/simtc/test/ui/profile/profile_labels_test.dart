import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/ui/profile/profile_labels.dart';

void main() {
  test('perfil de acesso', () {
    expect(roleLabel(AppUserRole.consultant), 'Consultor');
    expect(roleLabel(AppUserRole.admin), 'Administrador');
  });

  test('última sincronização: só o momento, ou "Nenhum envio"', () {
    final now = DateTime(2026, 10, 24, 9);
    expect(lastSyncValue(DateTime(2026, 10, 24, 7, 12), now), 'hoje 07:12');
    expect(lastSyncValue(DateTime(2026, 10, 20, 7, 12), now), '20 out 07:12');
    expect(lastSyncValue(null, now), 'Nenhum envio');
  });

  test('tamanho em KB abaixo de 1 MB, com uma casa e vírgula acima', () {
    expect(sizeLabel(0), '0 KB');
    expect(sizeLabel(1), '1 KB');
    expect(sizeLabel(36 * 1024), '36 KB');
    expect(sizeLabel(1024 * 1024 - 1), '1024 KB');
    expect(sizeLabel(1024 * 1024), '1,0 MB');
    expect(sizeLabel((18.4 * 1024 * 1024).round()), '18,4 MB');
    expect(sizeLabel((1.25 * 1024 * 1024 * 1024).round()), '1,3 GB');
  });

  group('confirmação do "Sair"', () {
    test('sem fila nem rascunho, com rede: só as sessões', () {
      expect(
        logoutMessage(queued: 0, drafts: 0, offline: false),
        'As sessões baixadas neste aparelho serão apagadas.',
      );
    });

    test('com fila e rascunho, sem rede: um parágrafo por assunto', () {
      expect(
        logoutMessage(queued: 3, drafts: 1, offline: true),
        'As sessões baixadas neste aparelho serão apagadas.\n\n'
        '3 avaliações na fila ficam guardadas neste aparelho e são enviadas '
        'quando você entrar de novo.\n\n'
        'A avaliação iniciada fica guardada para você continuar quando entrar '
        'de novo.\n\n'
        'Sem conexão, você só consegue entrar de novo quando houver rede.',
      );
    });

    test('singular e plural', () {
      expect(
        logoutMessage(queued: 1, drafts: 2, offline: false),
        'As sessões baixadas neste aparelho serão apagadas.\n\n'
        'A avaliação na fila fica guardada neste aparelho e é enviada quando '
        'você entrar de novo.\n\n'
        '2 avaliações iniciadas ficam guardadas para você continuar quando '
        'entrar de novo.',
      );
    });
  });
}
