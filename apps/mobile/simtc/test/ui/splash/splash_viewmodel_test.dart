import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/config/app_config.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/services/device_data_service.dart';
import 'package:simtc/ui/splash/splash_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockDeviceData extends Mock implements DeviceDataService {}

void main() {
  late _MockAuthRepository auth;
  late _MockDeviceData deviceData;

  setUp(() {
    auth = _MockAuthRepository();
    deviceData = _MockDeviceData();
    when(() => deviceData.resetIfServerChanged(any()))
        .thenAnswer((_) async => true);
  });

  test('confere o servidor antes de retomar a sessão salva', () async {
    when(auth.restoreSession).thenAnswer(
      (_) async => const Success(AuthUser(
        id: 'user-1',
        name: 'Carla Mendes',
        email: 'carla@simtc.com.br',
        role: AppUserRole.consultant,
      )),
    );
    final viewModel = SplashViewModel(
      authRepository: auth,
      deviceData: deviceData,
      apiBaseUrl: 'http://localhost:3001/api',
    );
    addTearDown(viewModel.dispose);

    expect(await viewModel.decideInitialRoute(), isTrue);

    verifyInOrder([
      () => deviceData.resetIfServerChanged('http://localhost:3001/api'),
      () => auth.restoreSession(),
    ]);
  });

  test('sem sessão salva, vai para o login', () async {
    when(auth.restoreSession)
        .thenAnswer((_) async => Failure(Exception('sem sessão'), 'Entre.'));
    final viewModel = SplashViewModel(authRepository: auth, deviceData: deviceData);
    addTearDown(viewModel.dispose);

    expect(await viewModel.decideInitialRoute(), isFalse);
  });

  test('o endereço conferido é, por padrão, o deste build', () {
    final viewModel = SplashViewModel(authRepository: auth, deviceData: deviceData);
    addTearDown(viewModel.dispose);

    expect(viewModel.apiBaseUrl, AppConfig.apiBaseUrl);
  });
}
