import 'package:flutter/material.dart';

import 'src/app_presets.dart';
import 'src/app_root.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPresets.init();

  runApp(const AppRoot());
}
