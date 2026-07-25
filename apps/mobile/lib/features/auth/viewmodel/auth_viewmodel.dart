import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../model/auth_repository.dart';
import 'auth_state.dart';

part 'auth_viewmodel.g.dart';

@riverpod
class AuthViewModel extends _$AuthViewModel {
  @override
  AuthState build() => const AuthState.initial();

  Future<void> login(String email, String password) async {
    state = const AuthState.loading();
    try {
      final user = await ref.read(authRepositoryProvider).login(email, password);
      state = AuthState.authenticated(user);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  void logout() {
    state = const AuthState.initial();
  }
}
