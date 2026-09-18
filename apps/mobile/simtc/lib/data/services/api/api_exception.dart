import 'package:dio/dio.dart';

/// Erro de API já traduzido para algo exibível ao usuário.
///
/// O backend responde `{ "message": ..., "error": ..., "statusCode": ... }`,
/// onde `message` é um texto ou, nos erros de validação do NestJS, uma lista.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.isNetworkError = false,
  });

  final String message;
  final int? statusCode;
  final bool isNetworkError;

  static const String _networkMessage =
      'Sem conexão com o servidor. Verifique a internet e tente de novo.';
  static const String _unexpectedMessage =
      'Não foi possível completar a operação. Tente de novo.';

  factory ApiException.fromDio(DioException error) {
    final isNetwork = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      DioExceptionType.unknown => error.response == null,
      _ => false,
    };

    if (isNetwork) {
      return const ApiException(message: _networkMessage, isNetworkError: true);
    }

    final response = error.response;
    return ApiException(
      statusCode: response?.statusCode,
      message: _messageFrom(response?.data) ?? _unexpectedMessage,
    );
  }

  static String? _messageFrom(Object? data) {
    if (data is! Map) return null;
    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;
    if (message is List && message.isNotEmpty) {
      return message.map((item) => '$item').join('\n');
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
