import 'dart:convert';

/// Perfis aceitos pelo app. `CLIENT` existe no backend, mas usa o portal web.
enum AppUserRole { admin, consultant }

/// Usuário autenticado no app.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.consultantId,
  });

  final String id;
  final String name;
  final String email;
  final AppUserRole role;

  /// Id do `Consultant` vinculado, lido do JWT. Sem ele o usuário não consegue
  /// avaliar (o backend recusa a atribuição de participantes).
  final String? consultantId;

  bool get isAdmin => role == AppUserRole.admin;

  /// Monta o usuário a partir de `GET /auth/me`. Devolve null quando o perfil
  /// não é aceito no app.
  static AuthUser? fromMeJson(
    Map<String, dynamic> json, {
    String? consultantId,
  }) {
    final role = parseRole(json['role'] as String?);
    if (role == null) return null;

    return AuthUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: role,
      consultantId: consultantId,
    );
  }

  static AppUserRole? parseRole(String? value) => switch (value) {
        'ADMIN' => AppUserRole.admin,
        'CONSULTANT' => AppUserRole.consultant,
        _ => null,
      };

  /// Perfil guardado no aparelho para abrir o app sem rede (ver
  /// `AuthRepository.restoreSession`). Não é o formato do backend.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'consultantId': consultantId,
      };

  /// Lê o perfil guardado por [toJson]. Devolve null se ele estiver
  /// incompleto ou com um papel que o app não aceita.
  static AuthUser? fromJson(Map<String, dynamic> json) {
    final role = AppUserRole.values.asNameMap()[json['role']];
    final id = json['id'];
    if (role == null || id is! String || id.isEmpty) return null;

    return AuthUser(
      id: id,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: role,
      consultantId: json['consultantId'] as String?,
    );
  }
}

/// Lê o payload de um JWT sem validar a assinatura — a validação é do backend;
/// aqui só precisamos de um campo que o `/auth/me` não devolve.
Map<String, dynamic>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(decoded);
    return payload is Map<String, dynamic> ? payload : null;
  } on FormatException {
    return null;
  }
}
