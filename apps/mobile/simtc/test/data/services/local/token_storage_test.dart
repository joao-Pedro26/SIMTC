import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/services/local/token_storage.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  test(
      'clear apaga os tokens e o perfil salvo — sair do app não deixa o perfil '
      'para a próxima abertura sem rede', () async {
    final secure = _MockSecureStorage();
    when(() => secure.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    final storage = TokenStorage(storage: secure);

    await storage.clear();

    verify(() => secure.delete(key: 'auth.accessToken')).called(1);
    verify(() => secure.delete(key: 'auth.refreshToken')).called(1);
    verify(() => secure.delete(key: 'auth.user')).called(1);
  });
}
