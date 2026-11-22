final RegExp _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

/// Uma versão publicada do app, como descrita no `latest.json` do bucket
/// `app-releases` (gerado por `tool/publicar-release.ps1`).
class AppRelease {
  const AppRelease({
    required this.versionName,
    required this.versionCode,
    required this.minSupportedVersionCode,
    required this.apkUrl,
    required this.sha256,
    this.sizeBytes,
    this.releaseNotes = const [],
  });

  /// Lê o `latest.json`. Qualquer campo obrigatório ausente ou malformado vira
  /// `FormatException`: um manifesto torto nunca deve levar a um download.
  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final versionName = json['versionName'];
    if (versionName is! String || versionName.trim().isEmpty) {
      throw const FormatException('versionName ausente');
    }

    final versionCode = json['versionCode'];
    if (versionCode is! int || versionCode < 1) {
      throw const FormatException('versionCode ausente ou inválido');
    }

    final apkUrl = json['apkUrl'];
    if (apkUrl is! String || !apkUrl.startsWith('https://')) {
      throw const FormatException('apkUrl ausente ou sem https');
    }

    final sha256 = json['sha256'];
    if (sha256 is! String || !_sha256Pattern.hasMatch(sha256)) {
      throw const FormatException('sha256 ausente ou inválido');
    }

    final minSupported = json['minSupportedVersionCode'];
    if (minSupported != null && (minSupported is! int || minSupported < 0)) {
      throw const FormatException('minSupportedVersionCode inválido');
    }

    final size = json['sizeBytes'];
    final notes = json['releaseNotes'];

    return AppRelease(
      versionName: versionName.trim(),
      versionCode: versionCode,
      minSupportedVersionCode: (minSupported as int?) ?? 0,
      apkUrl: apkUrl,
      sha256: sha256.toLowerCase(),
      sizeBytes: size is int && size > 0 ? size : null,
      releaseNotes: notes is List
          ? notes.whereType<String>().where((n) => n.trim().isNotEmpty).toList()
          : const [],
    );
  }

  /// "1.1.0", o que o usuário vê.
  final String versionName;

  /// O número depois do `+` no `pubspec.yaml`; só ele decide qual é mais novo.
  final int versionCode;

  /// Quem estiver abaixo deste código é obrigado a atualizar.
  final int minSupportedVersionCode;

  final String apkUrl;

  /// Em minúsculas, 64 caracteres hexadecimais.
  final String sha256;

  final int? sizeBytes;
  final List<String> releaseNotes;

  /// Esta versão é mais nova que a instalada?
  bool isNewerThan(int installedVersionCode) =>
      versionCode > installedVersionCode;

  /// A instalada é antiga demais para continuar sendo usada?
  bool isMandatoryFor(int installedVersionCode) =>
      installedVersionCode < minSupportedVersionCode;

  /// Nome do arquivo no aparelho; o mesmo padrão do script de publicação.
  String get fileName => 'simtc-$versionName-$versionCode.apk';
}
