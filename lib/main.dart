import 'dart:io';

import 'package:flutter/material.dart';

import 'services/overrides.dart';
import 'src/app_presets.dart';
import 'src/app_root.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPresets.init();
  HttpOverrides.global = MyHttpOverrides();
  runApp(const AppRoot());
}
