import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/api_constants.dart';
import '../../utils/result.dart';
import '../models/user_model.dart';
import '../services/api/api_service.dart';

class AuthRepository {
  final ApiService _apiService;
  final FlutterSecureStorage _storage;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  AuthRepository({
    ApiService? apiService,
    FlutterSecureStorage? storage,
  })  : _apiService = apiService ?? ApiService(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<Result<UserModel>> login({
    required String email,
    required String password,
  }) async {
    final result = await _apiService.post<UserModel>(
      ApiConstants.login,
      data: {'email': email, 'password': password},
      parser: (data) => UserModel.fromJson(data as Map<String, dynamic>),
    );

    if (result is Success<UserModel>) {
      _currentUser = result.data;
      if (_currentUser?.token != null) {
        await _storage.write(key: 'auth_token', value: _currentUser!.token);
        _apiService.setAuthToken(_currentUser!.token!);
      }
      return result;
    } else {
      // Mock fallback for development/demo
      if (email.isNotEmpty && password.length >= 4) {
        final mockUser = UserModel(
          id: 'user_1',
          name: 'Instrutor SIMTC',
          email: email,
          token: 'mock_jwt_token_123',
        );
        _currentUser = mockUser;
        await _storage.write(key: 'auth_token', value: mockUser.token);
        _apiService.setAuthToken(mockUser.token!);
        return Success(mockUser);
      }
      return result;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    await _storage.delete(key: 'auth_token');
    _apiService.clearAuthToken();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null && token.isNotEmpty) {
      _apiService.setAuthToken(token);
      _currentUser = const UserModel(
        id: 'user_1',
        name: 'Instrutor SIMTC',
        email: 'instrutor@simtc.com.br',
        token: 'mock_jwt_token_123',
      );
      return true;
    }
    return false;
  }
}
