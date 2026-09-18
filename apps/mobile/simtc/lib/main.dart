import 'package:flutter/material.dart';

import 'app.dart';
import 'data/services/local/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SimtcApp(database: AppDatabase()));
}
