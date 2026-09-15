import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/app_bloc/cubit.dart';
import '../../blocs/auth_bloc/auth_cubit.dart';
import '../../blocs/base_states.dart';
import '../../src/app_assets.dart';
import '../../src/app_colors.dart';
import '../../src/app_globals.dart';
import '../../src/app_presets.dart';
import '../general/app_dialog.dart';

// Navigation lives in the sidebar (components/index/sidebar.dart). This bar
// is the window's title bar: controls, brand, theme and the signed-in account.
class MyAppBar extends StatelessWidget {
  const MyAppBar({super.key});

  void _minimize() => AppPresets.instance.minimize();
  void _close() => AppPresets.instance.close();
  void _maximize() => AppPresets.instance.maximize();
  void _restore() => AppPresets.instance.restore();
  void _toggle() async =>
      await AppPresets.instance.isMaximized() ? _restore() : _maximize();
  void _drag(details) => AppPresets.instance.startDragging();

  @override
  Widget build(BuildContext context) {
    final user = AppGlobals.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onPanStart: _drag,
        onDoubleTap: _toggle,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: GlobalColors.surface(context),
            border: Border(
              bottom: BorderSide(
                color: GlobalColors.accent.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Window controls ──────────────
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 8),
                child: Row(
                  spacing: 8,
                  children: [
                    WindowControl(
                      color: const Color(0xFFFF5F57),
                      icon: Icons.close,
                      onTap: _close,
                    ),
                    WindowControl(
                      color: const Color(0xFF28C840),
                      icon: Icons.fullscreen,
                      onTap: _toggle,
                    ),
                    WindowControl(
                      color: const Color(0xFFFFBD2E),
                      icon: Icons.remove,
                      onTap: _minimize,
                    ),
                  ],
                ),
              ),

              Container(
                width: 1,
                height: 28,
                color: GlobalColors.border(context),
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // ── Logo + title ─────────────────
              SizedBox(width: 30, height: 30, child: Image.asset(AppAssets.logo)),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [GlobalColors.accentSoft, GlobalColors.accent],
                ).createShader(bounds),
                child: const Text(
                  'أكاديمية تبالة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),

              const Spacer(),

              // ── Theme switch ─────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BlocBuilder<AppCubit, AppStates>(
                  builder: (ctx, _) {
                    final isDark = ctx.read<AppCubit>().isDark;
                    return GestureDetector(
                      onTap: () => ctx.read<AppCubit>().switchTheme(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 52,
                        height: 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: isDark
                              ? GlobalColors.accent.withValues(alpha: 0.2)
                              : GlobalColors.gold.withValues(alpha: 0.2),
                          border: Border.all(
                            color: isDark
                                ? GlobalColors.accent.withValues(alpha: 0.5)
                                : GlobalColors.gold.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              right: 6,
                              child: Icon(
                                Icons.dark_mode_rounded,
                                size: 13,
                                color: isDark
                                    ? GlobalColors.accentSoft
                                    : GlobalColors.textSecondary(context).withValues(alpha: 0.4),
                              ),
                            ),
                            Positioned(
                              left: 6,
                              child: Icon(
                                Icons.light_mode_rounded,
                                size: 13,
                                color: !isDark
                                    ? GlobalColors.gold
                                    : GlobalColors.textSecondary(context).withValues(alpha: 0.4),
                              ),
                            ),
                            AnimatedAlign(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              alignment: isDark
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? GlobalColors.accent : GlobalColors.gold,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isDark ? GlobalColors.accent : GlobalColors.gold)
                                          .withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── User chip ────────────────────
              if (user != null) _UserChip(name: user.name ?? '', role: user.roleAr),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  USER CHIP — الحساب الحالي
// ─────────────────────────────────────────────

class _UserChip extends StatelessWidget {
  const _UserChip({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'الحساب',
      color: GlobalColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 46),
      onSelected: (v) {
        if (v == 'logout') {
          showConfirm(
            context,
            title: 'تسجيل الخروج',
            message: 'سيتم إنهاء الجلسة الحالية على هذا الجهاز.',
            confirmLabel: 'خروج',
            onConfirm: () => AuthCubit.get(context).logout(),
          );
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 17, color: GlobalColors.red),
              const SizedBox(width: 10),
              Text(
                'تسجيل الخروج',
                style: TextStyle(color: GlobalColors.textPrimary(context), fontSize: 13),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: GlobalColors.card(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: GlobalColors.border(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: GlobalColors.accent.withValues(alpha: 0.2),
              child: Text(
                name.isNotEmpty ? name.substring(0, 1) : '؟',
                style: TextStyle(
                  color: GlobalColors.accentSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  role,
                  style: TextStyle(color: GlobalColors.textSecondary(context), fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WINDOW CONTROL DOT
// ─────────────────────────────────────────────

class WindowControl extends StatefulWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const WindowControl({
    super.key,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<WindowControl> createState() => _WindowControlState();
}

class _WindowControlState extends State<WindowControl> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: _isHovered
              ? Icon(widget.icon, size: 8, color: Colors.black.withValues(alpha: 0.6))
              : null,
        ),
      ),
    );
  }
}
