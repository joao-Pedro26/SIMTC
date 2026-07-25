import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/api_client.dart';
import 'user.dart';

part 'auth_repository.g.dart';

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository(ref.watch(apiClientProvider));
}

class AuthRepository {
  final _dio;
  AuthRepository(this._dio);

  Future<AuthUser> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return AuthUser.fromJson(response.data as Map<String, dynamic>);
  }
}
