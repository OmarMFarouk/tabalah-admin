import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  STATIC PALETTE
//  الألوان الثابتة
// ─────────────────────────────────────────────
class AppColors {
  // Backgrounds
  static const backGround = Color(0xFF0A0A0A);
  static const secondary = Color(0xFF1A1A1A);

  static const primary = Color(0xFF6C63FF);
  static const primaryGradient = [
    Color(0xFF8B85FF),
    Color(0xFF6C63FF),
    Color(0xFF4B44D6),
  ];

  static const secondaryGradient = [Color(0xFF2A2A2A), Color(0xFF3A3A3A)];

  // Accent Colors
  static const primaryFont = Colors.white;
  static const grey = Colors.grey;
  static const red = Color(0xFFFF5C6A);
  static const yellow = Color(0xFFFFBF47);
  static const purple = Color(0xFFA78BFA);
  static const green = Color(0xFF27D27A);
  static const blue = Color(0xFF4FA3E0);
  static const orange = Color(0xFFFF8A65);

  // Base
  static const Color scaffold = Color(0xFF0D1117);
  static const Color surface = Color(0xFF1A1F3A);
  static const Color card = Color(0xFF0B0E1D);

  // Borders & dividers
  static const Color border = Color(0x14FFFFFF);
  static const Color divider = Color(0x0DFFFFFF);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF4B5563);

  static const Color white5 = Color(0x0DFFFFFF);
  static const Color white8 = Color(0x14FFFFFF);
  static const Color white10 = Color(0x1AFFFFFF);
  static const Color white20 = Color(0x33FFFFFF);
}

// ─────────────────────────────────────────────
//  GLOBAL COLORS — ألوان التطبيق
//  Usage: GlobalColors.bg(context) / GlobalColors.accent
// ─────────────────────────────────────────────
class GlobalColors {
  GlobalColors._();

  // Read the brightness off the theme, not off AppCubit.
  //
  // These helpers get called from event handlers and from dialog
  // builders holding a caller's context, and `context.watch` is only
  // legal while that exact context is building — anywhere else it
  // throws. AppRoot already feeds `isDark` into the MaterialApp theme,
  // so the theme carries the same answer and is safe to read from
  // anywhere, while still rebuilding when the toggle flips.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ── Backgrounds ──────────────────────────────
  static Color bg(BuildContext context) =>
      isDark(context) ? const Color(0xFF0F1117) : const Color(0xFFF4F5FA);

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A1D27) : const Color(0xFFFFFFFF);

  static Color card(BuildContext context) =>
      isDark(context) ? const Color(0xFF21253A) : const Color(0xFFEEF0FA);

  // ── Borders ──────────────────────────────────
  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF2C3050) : const Color(0xFFD8DAEA);

  // ── Brand / Accent ───────────────────────────
  static Color get accent => const Color(0xFF6C63FF);
  static Color get accentSoft => const Color(0xFF8B85FF);

  // ── Semantic ─────────────────────────────────
  static Color get green => const Color(0xFF27D27A);
  static Color get red => const Color(0xFFFF5C6A);
  static Color get gold => const Color(0xFFFFBF47);
  static Color get blue => const Color(0xFF4FA3E0);
  static Color get purple => const Color(0xFFA78BFA);

  // ── Text ─────────────────────────────────────
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFEEEEF4) : const Color(0xFF12141E);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF8A8FAB) : const Color(0xFF5A607A);
}
