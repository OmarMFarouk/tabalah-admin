import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  STATIC PALETTE
//  الألوان الثابتة
// ─────────────────────────────────────────────
class AppColors {
  // Backgrounds
  static const backGround = Color(0xFF08140D);
  static const secondary = Color(0xFF0F2217);

  static const primary = Color(0xFFD4AF37); // Classic Gold
  static const primaryGradient = [
    Color(0xFFF3D573), // Bright Gold
    Color(0xFFD4AF37), // Core Gold
    Color(0xFFA8841B), // Deep Gold
  ];

  static const secondaryGradient = [Color(0xFF142B1C), Color(0xFF1C3A27)];

  // Accent Colors
  static const primaryFont = Colors.white;
  static const grey = Colors.grey;
  static const red = Color(0xFFFF5C6A);
  static const yellow = Color(0xFFFFC847);
  static const purple = Color(0xFFA78BFA);
  static const green = Color(0xFF2EAD68); // Academy Green
  static const blue = Color(0xFF4FA3E0);
  static const orange = Color(0xFFFF8A65);

  // Base
  static const Color scaffold = Color(0xFF06100A);
  static const Color surface = Color(0xFF0D1E14);
  static const Color card = Color(0xFF12271A);

  // Borders & dividers
  static const Color border = Color(0x14FFFFFF);
  static const Color divider = Color(0x0DFFFFFF);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8FA897);
  static const Color textMuted = Color(0xFF4C6353);

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
      isDark(context) ? const Color(0xFF08140D) : const Color(0xFFF3F5F3);

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF0E2217) : const Color(0xFFFFFFFF);

  static Color card(BuildContext context) =>
      isDark(context) ? const Color(0xFF152D1F) : const Color(0xFFE5EBE6);

  // ── Borders ──────────────────────────────────
  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF1F402B) : const Color(0xFFCBD6CD);

  // ── Brand / Accent ───────────────────────────
  static Color get accent => const Color(0xFFD4AF37); // Brand Metallic Gold
  static Color get accentSoft => const Color(0xFFE8C860); // Soft Light Gold

  // ── Semantic ─────────────────────────────────
  static Color get green => const Color(0xFF2EAD68);
  static Color get red => const Color(0xFFFF5C6A);
  static Color get gold => const Color(0xFFD4AF37);
  static Color get blue => const Color(0xFF4FA3E0);
  static Color get purple => const Color(0xFFA78BFA);

  // ── Text ─────────────────────────────────────
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFF1F5F2) : const Color(0xFF0A180F);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF8BA292) : const Color(0xFF4A6150);
}
