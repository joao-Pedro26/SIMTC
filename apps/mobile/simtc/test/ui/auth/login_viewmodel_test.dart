import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/ui/auth/login_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository auth;
  late LoginViewModel viewModel;

  const user = AuthUser(
    id: 'u1',
    name: 'Carla',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
  );

  setUp(() {
    auth = _MockAuthRepository();
    viewModel = LoginViewModel(authRepository: auth);
  });

  test('só habilita o envio com e-mail e senha preenchidos', () {
    expect(viewModel.canSubmit, isFalse);

    viewModel.setEmail('carla@simtc.com.br');
    expect(viewModel.canSubmit, isFalse);

    viewModel.setPassword('123456');
    expect(viewModel.canSubmit, isTrue);
  });

  test('login bem-sucedido repassa a preferência de manter conectado', () async {
    when(() => auth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          keepSignedIn: any(named: 'keepSignedIn'),
        )).thenAnswer((_) async => const Success(user));

    viewModel
      ..setEmail('carla@simtc.com.br')
      ..setPassword('123456')
      ..setKeepSignedIn(false);

    expect(await viewModel.submit(), isTrue);
    verify(() => auth.login(
          email: 'carla@simtc.com.br',
          password: '123456',
          keepSignedIn: false,
        )).called(1);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isSubmitting, isFalse);
  });

  test('falha mostra a mensagem do repositório e não navega', () async {
    when(() => auth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          keepSignedIn: any(named: 'keepSignedIn'),
        )).thenAnswer((_) async =>
            Failure<AuthUser>(Exception('401'), 'E-mail ou senha incorretos.'));

    viewModel
      ..setEmail('carla@simtc.com.br')
      ..setPassword('errada');

    expect(await viewModel.submit(), isFalse);
    expect(viewModel.errorMessage, 'E-mail ou senha incorretos.');
  });

  test('digitar de novo limpa a mensagem de erro', () async {
    when(() => auth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          keepSignedIn: any(named: 'keepSignedIn'),
        )).thenAnswer((_) async =>
            Failure<AuthUser>(Exception('401'), 'E-mail ou senha incorretos.'));

    viewModel
      ..setEmail('carla@simtc.com.br')
      ..setPassword('errada');
    await viewModel.submit();

    viewModel.setPassword('outra');
    expect(viewModel.errorMessage, isNull);
  });

  test('esqueci a senha sem e-mail avisa antes de chamar a API', () async {
    await viewModel.requestPasswordReset();

    expect(viewModel.errorMessage, contains('Informe o e-mail'));
    verifyNever(() => auth.requestPasswordReset(any()));
  });

  test('esqueci a senha mostra a mesma confirmação sempre', () async {
    when(() => auth.requestPasswordReset(any()))
        .thenAnswer((_) async => const Success(null));

    viewModel.setEmail('carla@simtc.com.br');
    await viewModel.requestPasswordReset();

    expect(viewModel.infoMessage, contains('enviamos um link'));
    expect(viewModel.errorMessage, isNull);
  });
}
