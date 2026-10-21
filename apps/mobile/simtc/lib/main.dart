import 'package:flutter/material.dart';

import 'app.dart';
import 'data/services/local/app_database.dart';
import 'ui/core/form_factor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final display = WidgetsBinding.instance.platformDispatcher.displays.first;
  final formFactor = formFactorFor(display.size / display.devicePixelRatio);
  await applyOrientationPolicy(formFactor);
  runApp(SimtcApp(database: AppDatabase(), formFactor: formFactor));
}
