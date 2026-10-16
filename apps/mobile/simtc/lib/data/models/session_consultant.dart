import 'package:drift/drift.dart' show Value;

import '../services/local/app_database.dart';

/// Um consultor de uma sessão: a linha da tela "Consultores" e a contagem
/// "N consultores" do detalhe (Fase 6B).
class SessionConsultant {
  const SessionConsultant({required this.id, required this.name, this.email});

  /// `Consultant.id`.
  final String id;
  final String name;
  final String? email;

  /// Um consultor a partir de `{ id, name, email }`, o formato de `Consultant`
  /// no backend. Nulo se faltar o id ou o nome; e-mail em branco vira nulo.
  static SessionConsultant? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    final email = json['email'];
    return SessionConsultant(
      id: id,
      name: name.trim(),
      email: email is String && email.trim().isNotEmpty ? email.trim() : null,
    );
  }

  /// Os consultores de uma sessão, do corpo de `GET /training-sessions/:id` ou
  /// da resposta das rotas `…/consultants`: os dois trazem
  /// `consultants[].consultant`, com `id`, `name` e `email`.
  ///
  /// O responsável entra mesmo que o vínculo dele falte na lista: o detalhe
  /// traz `responsibleConsultant` inteiro, e a tela precisa mostrar quem
  /// responde pela sessão. Devolve nulo se `consultants` não vier como lista —
  /// uma resposta fora do formato não pode virar "sessão sem consultor" no
  /// cache.
  static List<SessionConsultant>? listFromJson(Map<String, dynamic> body) {
    final links = body['consultants'];
    if (links is! List) return null;

    final byId = <String, SessionConsultant>{};
    void add(SessionConsultant? consultant) {
      if (consultant != null) byId.putIfAbsent(consultant.id, () => consultant);
    }

    for (final link in links) {
      if (link is Map<String, dynamic>) add(tryParse(link['consultant']));
    }
    add(tryParse(body['responsibleConsultant']));
    return byId.values.toList(growable: false);
  }

  factory SessionConsultant.fromRow(SessionConsultantRow row) {
    return SessionConsultant(
      id: row.consultantId,
      name: row.name,
      email: row.email,
    );
  }

  /// A linha deste consultor no cache da sessão [sessionId].
  SessionConsultantsCompanion toCompanion(String sessionId) {
    return SessionConsultantsCompanion.insert(
      sessionId: sessionId,
      consultantId: id,
      name: name,
      email: Value(email),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SessionConsultant &&
      other.id == id &&
      other.name == name &&
      other.email == email;

  @override
  int get hashCode => Object.hash(id, name, email);

  @override
  String toString() => 'SessionConsultant($id, $name, $email)';
}
