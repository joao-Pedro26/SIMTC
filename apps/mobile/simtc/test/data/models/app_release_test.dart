import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/models/app_release.dart';

/// Manifesto válido, como o `latest.json` que o script de publicação gera.
Map<String, dynamic> _manifesto({
  String? versionName = '1.1.0',
  Object? versionCode = 2,
  Object? minSupportedVersionCode = 1,
  Object? apkUrl =
      'https://x.supabase.co/storage/v1/object/public/app-releases/simtc-1.1.0-2.apk',
  Object? sha256 = _hashValido,
  Object? sizeBytes = 31457280,
  Object? releaseNotes = const ['Corrige X', '  ', 'Melhora Y'],
}) {
  return {
    'versionName': versionName,
    'versionCode': versionCode,
    'minSupportedVersionCode': minSupportedVersionCode,
    'apkUrl': apkUrl,
    'sha256': sha256,
    'sizeBytes': sizeBytes,
    'releaseNotes': releaseNotes,
  };
}

const String _hashValido =
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

void main() {
  group('AppRelease.fromJson', () {
    test('manifesto válido preenche todos os campos', () {
      final release = AppRelease.fromJson(_manifesto());

      expect(release.versionName, '1.1.0');
      expect(release.versionCode, 2);
      expect(release.minSupportedVersionCode, 1);
      expect(release.apkUrl,
          'https://x.supabase.co/storage/v1/object/public/app-releases/simtc-1.1.0-2.apk');
      expect(release.sizeBytes, 31457280);
      expect(release.releaseNotes, ['Corrige X', 'Melhora Y']);
    });

    test('sha256 vira minúsculo', () {
      final release = AppRelease.fromJson(_manifesto());

      expect(release.sha256, 'a' * 64);
    });

    test('nota em branco é descartada e espaços das notas são preservados', () {
      final release = AppRelease.fromJson(_manifesto(
        releaseNotes: ['  Primeira  ', '', '   ', 'Segunda'],
      ));

      expect(release.releaseNotes, ['  Primeira  ', 'Segunda']);
    });

    test('versionName é aparado de espaços', () {
      final release = AppRelease.fromJson(_manifesto(versionName: ' 1.1.0 '));

      expect(release.versionName, '1.1.0');
    });

    test('fileName segue o padrão do script de publicação', () {
      final release = AppRelease.fromJson(_manifesto());

      expect(release.fileName, 'simtc-1.1.0-2.apk');
    });

    test('sem minSupportedVersionCode, o mínimo é 0', () {
      final release = AppRelease.fromJson(_manifesto(
        minSupportedVersionCode: null,
      ));

      expect(release.minSupportedVersionCode, 0);
    });

    test('sem sizeBytes, o tamanho é null', () {
      final release = AppRelease.fromJson(_manifesto(sizeBytes: null));

      expect(release.sizeBytes, isNull);
    });

    test('sizeBytes zero ou negativo vira null', () {
      expect(
        AppRelease.fromJson(_manifesto(sizeBytes: 0)).sizeBytes,
        isNull,
      );
      expect(
        AppRelease.fromJson(_manifesto(sizeBytes: -5)).sizeBytes,
        isNull,
      );
    });

    test('sem releaseNotes, a lista é vazia', () {
      final release = AppRelease.fromJson(_manifesto(releaseNotes: null));

      expect(release.releaseNotes, isEmpty);
    });

    test('releaseNotes que não é lista vira lista vazia', () {
      final release = AppRelease.fromJson(_manifesto(releaseNotes: 'texto'));

      expect(release.releaseNotes, isEmpty);
    });

    test('releaseNotes ignora itens que não são texto', () {
      final release = AppRelease.fromJson(_manifesto(
        releaseNotes: ['Válida', 42, null],
      ));

      expect(release.releaseNotes, ['Válida']);
    });

    test('versionName ausente lança FormatException', () {
      expect(
        () => AppRelease.fromJson(_manifesto(versionName: null)),
        throwsFormatException,
      );
    });

    test('versionName vazio lança FormatException', () {
      expect(
        () => AppRelease.fromJson(_manifesto(versionName: '   ')),
        throwsFormatException,
      );
    });

    test('versionCode como String lança FormatException', () {
      expect(
        () => AppRelease.fromJson(_manifesto(versionCode: '2')),
        throwsFormatException,
      );
    });

    test('versionCode zero lança FormatException', () {
      expect(
        () => AppRelease.fromJson(_manifesto(versionCode: 0)),
        throwsFormatException,
      );
    });

    test('apkUrl em http lança FormatException', () {
      expect(
        () => AppRelease.fromJson(_manifesto(
          apkUrl: 'http://x.supabase.co/simtc-1.1.0-2.apk',
        )),
        throwsFormatException,
      );
    });

    test('sha256 com 63 caracteres lança FormatException', () {
      expect(
        () => AppRelease.fromJson(_manifesto(sha256: 'a' * 63)),
        throwsFormatException,
      );
    });

    test('sha256 com caractere não hexadecimal lança FormatException', () {
      expect(
        () => AppRelease.fromJson(_manifesto(sha256: 'g' * 64)),
        throwsFormatException,
      );
    });

    test('minSupportedVersionCode negativo lança FormatException', () {
      expect(
        () => AppRelease.fromJson(_manifesto(minSupportedVersionCode: -1)),
        throwsFormatException,
      );
    });
  });

  group('AppRelease.isNewerThan', () {
    final release = AppRelease.fromJson(_manifesto());

    test('é mais nova que a instalada de código menor', () {
      expect(release.isNewerThan(1), isTrue);
    });

    test('não é mais nova que a instalada de mesmo código', () {
      expect(release.isNewerThan(2), isFalse);
    });

    test('não é mais nova que a instalada de código maior', () {
      expect(release.isNewerThan(3), isFalse);
    });
  });

  group('AppRelease.isMandatoryFor', () {
    test('é obrigatória quando a instalada está abaixo do mínimo', () {
      final release = AppRelease.fromJson(_manifesto(
        minSupportedVersionCode: 3,
      ));

      expect(release.isMandatoryFor(2), isTrue);
    });

    test('não é obrigatória quando a instalada já está no mínimo', () {
      final release = AppRelease.fromJson(_manifesto(
        minSupportedVersionCode: 2,
      ));

      expect(release.isMandatoryFor(2), isFalse);
    });
  });
}
