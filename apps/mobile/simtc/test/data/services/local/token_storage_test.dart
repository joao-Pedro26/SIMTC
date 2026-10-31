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

  test(
      'o endereço da API tem chave própria, que o clear não apaga — sair da '
      'conta não muda de servidor', () async {
    final secure = _MockSecureStorage();
    when(() => secure.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(() => secure.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    when(() => secure.read(key: 'app.apiBaseUrl'))
        .thenAnswer((_) async => 'https://api.simtc.com.br/api');
    final storage = TokenStorage(storage: secure);

    await storage.saveApiBaseUrl('https://api.simtc.com.br/api');
    expect(await storage.readApiBaseUrl(), 'https://api.simtc.com.br/api');
    await storage.clear();

    verify(() => secure.write(
          key: 'app.apiBaseUrl',
          value: 'https://api.simtc.com.br/api',
        )).called(1);
    verifyNever(() => secure.delete(key: 'app.apiBaseUrl'));
  });

  test(
      'uma chave que não apaga não impede as outras; o "manter conectado" é '
      'desligado e a falha sobe no fim (Fase 8D)', () async {
    final secure = _MockSecureStorage();
    when(() => secure.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(() => secure.delete(key: 'auth.accessToken'))
        .thenThrow(Exception('keystore'));
    when(() => secure.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    final storage = TokenStorage(storage: secure);

    await expectLater(storage.clear(), throwsException);

    verify(() => secure.delete(key: 'auth.refreshToken')).called(1);
    verify(() => secure.delete(key: 'auth.user')).called(1);
    verify(() => secure.write(key: 'auth.keepSignedIn', value: 'false')).called(1);
  });

  test('deleteUser apaga só o perfil salvo, sem mexer nos tokens', () async {
    final secure = _MockSecureStorage();
    when(() => secure.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    final storage = TokenStorage(storage: secure);

    await storage.deleteUser();

    verify(() => secure.delete(key: 'auth.user')).called(1);
    verifyNever(() => secure.delete(key: 'auth.accessToken'));
    verifyNever(() => secure.delete(key: 'auth.refreshToken'));
  });
}
