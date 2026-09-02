import 'package:custom_mouse_cursor/custom_mouse_cursor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import 'app_assets.dart';
import 'app_shared.dart';

class AppPresets {
  static late WindowManager instance;
  static late CustomMouseCursor myCursor;

  static Future<void> init() async {
    await windowManager.ensureInitialized();
    instance = WindowManager.instance;
    await instance.setAsFrameless();
    await instance.setMinimumSize(const Size(1100, 700));
    await instance.setAlignment(const Alignment(0, 0));

    myCursor = await CustomMouseCursor.asset(
      AppAssets.cursor,
      hotX: 2,
      hotY: 2,
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    await AppShared.init();
    // Generic Arabic rather than a country locale: intl ships month
    // names for 'ar' with certainty (يناير، فبراير…), which is what
    // Saudi usage expects, and a missing country locale would throw at
    // the first DateFormat call.
    await initializeDateFormatting('ar', '');
    Intl.defaultLocale = 'ar';
  }

  // ── Date helpers — مساعدات التاريخ ──────────
  static String get today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static String get thisMonth => DateFormat('yyyy-MM').format(DateTime.now());

  static String get nextMonth {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, now.day));
  }

  static String date(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String pretty(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      return DateFormat('d MMM yyyy', 'ar').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  static String time(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
