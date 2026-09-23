import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'config/app_config.dart';
import 'data/repositories/assessment_catalog_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/session_repository.dart';
import 'data/services/api/api_client.dart';
import 'data/services/auth_session.dart';
import 'data/services/connectivity_service.dart';
import 'data/services/local/app_database.dart';
import 'data/services/local/token_storage.dart';

/// Dependências vivas do app, criadas uma única vez na abertura.
///
/// O `ApiClient` recebe do `AuthSession` as funções de leitura e gravação de
/// token; o `AuthRepository` recebe os dois. Assim o cliente HTTP não conhece o
/// repositório e não há ciclo entre eles.
class AppDependencies {
  AppDependencies._({
    required this.database,
    required this.tokenStorage,
    required this.session,
    required this.apiClient,
    required this.authRepository,
    required this.sessionRepository,
    required this.catalogRepository,
    required this.connectivityService,
  });

  factory AppDependencies.create({required AppDatabase database}) {
    final tokenStorage = TokenStorage();
    final session = AuthSession(tokenStorage);
    late final AuthRepository authRepository;

    final apiClient = ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      readAccessToken: session.readAccessToken,
      readRefreshToken: session.readRefreshToken,
      onTokensRenewed: session.updateTokens,
      onSessionExpired: () async {
        await session.expire();
        await authRepository.handleSessionExpired();
      },
    );

    authRepository = AuthRepository(
      apiClient: apiClient,
      session: session,
      clearLocalCache: database.clearSessionsCache,
    );
    final sessionRepository = SessionRepository(
      apiClient: apiClient,
      database: database,
    );
    final catalogRepository = AssessmentCatalogRepository(
      apiClient: apiClient,
      database: database,
    );

    return AppDependencies._(
      database: database,
      tokenStorage: tokenStorage,
      session: session,
      apiClient: apiClient,
      authRepository: authRepository,
      sessionRepository: sessionRepository,
      catalogRepository: catalogRepository,
      connectivityService: ConnectivityService()..initialize(),
    );
  }

  final AppDatabase database;
  final TokenStorage tokenStorage;
  final AuthSession session;
  final ApiClient apiClient;
  final AuthRepository authRepository;
  final SessionRepository sessionRepository;
  final AssessmentCatalogRepository catalogRepository;
  final ConnectivityService connectivityService;

  /// Providers na ordem de dependência, para o `MultiProvider` do app.
  ///
  /// Todos entram por `.value` porque quem cria é esta classe — e é ela quem
  /// libera os recursos em `dispose()`.
  List<SingleChildWidget> get providers => [
        Provider<AppDatabase>.value(value: database),
        Provider<TokenStorage>.value(value: tokenStorage),
        Provider<AuthSession>.value(value: session),
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<AuthRepository>.value(value: authRepository),
        Provider<SessionRepository>.value(value: sessionRepository),
        Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        ChangeNotifierProvider<ConnectivityService>.value(
          value: connectivityService,
        ),
      ];

  void dispose() {
    connectivityService.dispose();
    authRepository.dispose();
    session.dispose();
  }
}
