import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabalah_admin/src/app_navigator.dart';

import '../blocs/app_bloc/cubit.dart';
import '../blocs/auth_bloc/auth_cubit.dart';
import '../blocs/base_states.dart';
import '../screens/auth.dart';
import '../screens/index.dart';
import '../screens/splash.dart';
import '../services/apis/api_client.dart';
import 'app_assets.dart';
import 'app_colors.dart';
import 'app_globals.dart';
import 'app_presets.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppCubit()),
        BlocProvider(
          create: (_) {
            final cubit = AuthCubit();
            // A 401 anywhere in the panel - an expired token, or the account
            // signing in elsewhere, since the backend keeps one session per
            // user - drops back to the login card. The cubit emits, the gate
            // rebuilds; nothing touches the route stack.
            ApiClient.onUnauthorized = cubit.sessionExpired;
            return cubit;
          },
        ),
      ],
      child: BlocBuilder<AppCubit, AppStates>(
        builder: (context, _) {
          final isDark = context.select((AppCubit c) => c.isDark);

          return MouseRegion(
            cursor: AppPresets.myCursor,
            child: MaterialApp(
              // Still here because screens push their own routes through
              // AppNavigator. The 401 handler no longer touches the stack at
              // all, so this key is only ever mounted once and the old
              // "Duplicate GlobalKey" trap is gone for good.
              navigatorKey: AppNavigator.navigatorKey,
              title: 'Tabalah Club Admin',
              debugShowCheckedModeBanner: false,
              theme: _buildTheme(isDark),
              home: const _Gate(),
            ),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(bool isDark) {
    return ThemeData(
      // GlobalColors reads this back, so state it outright rather than
      // relying on it being inferred from the colour scheme.
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF),
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0F1117)
          : const Color(0xFFF4F5FA),
      datePickerTheme: _datePickerTheme(isDark),
      timePickerTheme: _timePickerTheme(isDark),
    );
  }

  // ── Pickers — منتقي التاريخ والوقت ───────────
  //  Left to Material 3's defaults these came out barely legible in light
  //  mode: the scheme is seeded from a colour that isn't the brand gold, and
  //  M3 then paints an elevation tint over the dialog surface. Gold text on a
  //  tinted near-white background is what made the dates look washed out.
  //  Killing the tint and stating the foreground colours outright fixes it,
  //  and keeps dark mode unchanged.
  DatePickerThemeData _datePickerTheme(bool isDark) {
    final surface = isDark ? const Color(0xFF12271A) : Colors.white;
    final onSurface = isDark ? Colors.white : const Color(0xFF1A1F2B);
    final muted = isDark ? const Color(0xFF8FA897) : const Color(0xFF6B7280);
    const accent = Color(0xFFD4AF37);
    // Gold is a light colour: white text on it is unreadable, so selected
    // days get near-black regardless of mode.
    const onAccent = Color(0xFF1A1200);

    return DatePickerThemeData(
      backgroundColor: surface,
      // The M3 elevation overlay is the thing that greys everything out.
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      headerBackgroundColor: isDark ? const Color(0xFF0D1E14) : accent,
      headerForegroundColor: isDark ? Colors.white : onAccent,
      weekdayStyle: TextStyle(
        color: muted,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      dayStyle: const TextStyle(fontSize: 13),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return onAccent;
        if (states.contains(WidgetState.disabled)) {
          return muted.withValues(alpha: 0.4);
        }
        return onSurface;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : null,
      ),
      todayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? onAccent : accent,
      ),
      todayBorder: const BorderSide(color: accent, width: 1.4),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return onAccent;
        return onSurface;
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : null,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: isDark ? accent : const Color(0xFF7A6412),
      ),
      cancelButtonStyle: TextButton.styleFrom(foregroundColor: muted),
    );
  }

  // TimePickerThemeData is NOT shaped like DatePickerThemeData, despite the
  // matching names:
  //   - it has no surfaceTintColor at all
  //   - its colour fields are plain `Color?`, not WidgetStateProperty
  // They still vary by state, because WidgetStateColor *is* a Color — so the
  // resolver goes through WidgetStateColor.resolveWith, which returns a
  // Color, rather than WidgetStateProperty.resolveWith, which does not.
  TimePickerThemeData _timePickerTheme(bool isDark) {
    final surface = isDark ? const Color(0xFF12271A) : Colors.white;
    final onSurface = isDark ? Colors.white : const Color(0xFF1A1F2B);
    final idle = isDark ? const Color(0xFF0D1E14) : const Color(0xFFF1F2F6);
    const accent = Color(0xFFD4AF37);
    const onAccent = Color(0xFF1A1200);
    // Gold on white is unreadable, so light mode uses a darkened gold for
    // text that sits on the surface rather than on the accent.
    final accentText = isDark ? accent : const Color(0xFF7A6412);

    return TimePickerThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      dialBackgroundColor: idle,
      dialHandColor: accent,
      hourMinuteColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accent.withValues(alpha: 0.22)
            : idle,
      ),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accentText : onSurface,
      ),
      dialTextColor: WidgetStateColor.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? onAccent : onSurface,
      ),
      dayPeriodColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accent.withValues(alpha: 0.22)
            : Colors.transparent,
      ),
      dayPeriodTextColor: WidgetStateColor.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accentText : onSurface,
      ),
      entryModeIconColor: accentText,
      helpTextStyle: TextStyle(
        color: onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      confirmButtonStyle: TextButton.styleFrom(foregroundColor: accentText),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: isDark
            ? const Color(0xFF8FA897)
            : const Color(0xFF6B7280),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  GATE — البوابة
//  Restores a saved session, then shows either
//  the panel or the login card.
// ─────────────────────────────────────────────
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  /// True only until the stored session has been checked once, on launch.
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreOnce();
  }

  Future<void> _restoreOnce() async {
    await AuthCubit.get(context).restoreSession();
    if (mounted) setState(() => _restoring = false);
  }

  /// Which screen the app shows is a pure function of "is there a session",
  /// re-evaluated on every auth state change — and this widget is the only
  /// thing that decides it.
  ///
  /// It used to keep the restore Future and read `snapshot.data`, which was
  /// wrong in two directions. That answer is a snapshot of launch time, so
  /// after a logout the gate still saw `true` and put the dashboard straight
  /// back up; and because the whole decision hung off a widget sitting at
  /// the root route, anything that replaced that route (the API client's old
  /// 401 redirect) deleted the app's only route to the dashboard, which is
  /// why a successful login could leave you staring at the login card.
  ///
  /// Reading `AppGlobals.isReady` on every build has neither problem: login,
  /// logout and an expired token all just change that flag and rebuild.
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AppStates>(
      builder: (context, state) {
        if (_restoring) return const SplashScreen();
        return AppGlobals.isReady ? const MainDashboard() : const AuthScreen();
      },
    );
  }
}
