abstract class ApiConstants {
  static const String baseUrl = 'https://api.simtc.com.br/v1';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Endpoints
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  static const String evaluations = '/evaluations';
  static const String syncEvaluations = '/evaluations/sync';
}
