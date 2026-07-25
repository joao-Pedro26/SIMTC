import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_client.g.dart';

const _baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3001/api');

@riverpod
Dio apiClient(ApiClientRef ref) {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // Interceptor: injeta Bearer token em todas as requisições
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // TODO: ler token do secure storage e injetar no header
        // final token = ref.read(authTokenProvider);
        // if (token != null) options.headers['Authorization'] = 'Bearer $token';
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // TODO: tentar refresh token; se falhar, fazer logout
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
}
