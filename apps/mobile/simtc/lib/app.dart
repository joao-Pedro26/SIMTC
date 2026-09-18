import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_providers.dart';
import 'data/services/local/app_database.dart';
import 'router.dart';
import 'ui/core/theme/app_theme.dart';

class SimtcApp extends StatefulWidget {
  const SimtcApp({super.key, required this.database});

  final AppDatabase database;

  @override
  State<SimtcApp> createState() => _SimtcAppState();
}

class _SimtcAppState extends State<SimtcApp> {
  // Criados uma vez: recriar o GoRouter a cada build perderia a pilha de navegação.
  late final AppDependencies _dependencies =
      AppDependencies.create(database: widget.database);
  late final GoRouter _router = createRouter(_dependencies.authRepository);

  @override
  void dispose() {
    _dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: _dependencies.providers,
      child: MaterialApp.router(
        title: 'SIMTC',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
