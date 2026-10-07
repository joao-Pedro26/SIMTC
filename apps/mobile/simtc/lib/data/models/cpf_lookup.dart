/// O que o backend sabe de um CPF, visto de uma sessão — a resposta de
/// `POST /training-sessions/:id/participants/lookup` (Fase 6A).
class CpfLookup {
  const CpfLookup({
    required this.registered,
    required this.enrolled,
    this.name,
    this.email,
  });

  /// O CPF já tem cadastro — de outro treinamento, ou deste.
  final bool registered;

  /// O CPF já está inscrito nesta sessão.
  final bool enrolled;

  /// Nome e e-mail do cadastro, para a tela preencher. Nulos sem cadastro —
  /// e o e-mail também quando o cadastro não tem um.
  final String? name;
  final String? email;

  /// Nulo quando a resposta não tem o formato esperado: quem chama trata
  /// como "não foi possível consultar", em vez de supor que o CPF está livre.
  static CpfLookup? tryParse(Object? body) {
    if (body is! Map) return null;
    final registered = body['registered'];
    final enrolled = body['enrolled'];
    if (registered is! bool || enrolled is! bool) return null;

    return CpfLookup(
      registered: registered,
      enrolled: enrolled,
      name: _text(body['name']),
      email: _text(body['email']),
    );
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;
}
