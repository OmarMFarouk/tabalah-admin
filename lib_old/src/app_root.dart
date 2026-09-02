import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/app_bloc/cubit.dart';
import '../blocs/auth_bloc/auth_cubit.dart';
import '../blocs/base_states.dart';
import '../screens/auth.dart';
import '../screens/index.dart';
import 'app_colors.dart';
import 'app_globals.dart';
import 'app_presets.dart';

// ─────────────────────────────────────────────
//  APP ROOT — جذر التطبيق
//  Only the theme cubit and auth cubit live here;
//  each page owns its own cubit so its filters
//  reset with it.
// ─────────────────────────────────────────────
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppCubit()),
        BlocProvider(create: (_) => AuthCubit()),
      ],
      child: BlocBuilder<AppCubit, AppStates>(
        builder: (context, _) {
          final isDark = context.select((AppCubit c) => c.isDark);

          return MouseRegion(
            cursor: AppPresets.myCursor,
            child: MaterialApp(
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
  late Future<bool> _restore;

  @override
  void initState() {
    super.initState();
    _restore = AuthCubit.get(context).restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AppStates>(
      builder: (context, state) {
        // A completed login or logout flips this immediately.
        if (AppGlobals.isReady) return const MainDashboard();

        return FutureBuilder<bool>(
          future: _restore,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SplashScreen();
            }
            return snap.data == true
                ? const MainDashboard()
                : const AuthScreen();
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  SPLASH — شاشة البدء
// ─────────────────────────────────────────────
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlobalColors.bg(context),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => LinearGradient(
                colors: [GlobalColors.accentSoft, GlobalColors.accent],
              ).createShader(b),
              child: const Text(
                'Tabalah',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: GlobalColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
