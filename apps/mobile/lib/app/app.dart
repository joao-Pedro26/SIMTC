import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../design_system/ds.dart';
import 'router.dart';

class SimtcApp extends ConsumerWidget {
  const SimtcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SIMTC',
      theme: SimtcTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
