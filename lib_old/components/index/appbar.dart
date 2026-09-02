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

// ─────────────────────────────────────────────
//  NAV DESTINATIONS — صفحات اللوحة
//  Sixteen API folders, seven pages.
// ─────────────────────────────────────────────
const List<(IconData, String)> navItems = [
  (Icons.dashboard_rounded, 'الرئيسية'),
  (Icons.people_alt_rounded, 'الأشخاص'),
  (Icons.card_membership_rounded, 'الاشتراكات'),
  (Icons.event_note_rounded, 'الحصص'),
  (Icons.payments_rounded, 'المالية'),
  (Icons.insights_rounded, 'الأداء'),
  (Icons.campaign_rounded, 'المراسلات'),
];

class MyAppBar extends StatelessWidget {
  const MyAppBar({
    super.key,
    required this.currentPage,
    required this.onChanged,
  });

  final int currentPage;
  final Function(int) onChanged;

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
          height: 62,
          decoration: BoxDecoration(
            color: GlobalColors.surface(context),
            border: Border(
              bottom: BorderSide(
                color: GlobalColors.accent.withOpacity(0.2),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
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
              SizedBox(
                width: 30,
                height: 30,
                child: Image.asset(AppAssets.logo),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [GlobalColors.accentSoft, GlobalColors.accent],
                ).createShader(bounds),
                child: const Text(
                  'Tabalah',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

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
                              ? GlobalColors.accent.withOpacity(0.2)
                              : GlobalColors.gold.withOpacity(0.2),
                          border: Border.all(
                            color: isDark
                                ? GlobalColors.accent.withOpacity(0.5)
                                : GlobalColors.gold.withOpacity(0.5),
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
                                    : GlobalColors.textSecondary(
                                        context,
                                      ).withOpacity(0.4),
                              ),
                            ),
                            Positioned(
                              left: 6,
                              child: Icon(
                                Icons.light_mode_rounded,
                                size: 13,
                                color: !isDark
                                    ? GlobalColors.gold
                                    : GlobalColors.textSecondary(
                                        context,
                                      ).withOpacity(0.4),
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
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? GlobalColors.accent
                                      : GlobalColors.gold,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (isDark
                                                  ? GlobalColors.accent
                                                  : GlobalColors.gold)
                                              .withOpacity(0.5),
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

              // ── Navigation ───────────────────
              // One Expanded rather than Spacer + Flexible: two flex
              // children would split the free space and squash the nav.
              // `reverse` parks the items at the far end on an RTL row.
              Expanded(
                child: user == null
                    ? const SizedBox()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < navItems.length; i++)
                              AppBarNavItem(
                                icon: navItems[i].$1,
                                label: navItems[i].$2,
                                isActive: currentPage == i,
                                onTap: () => onChanged(i),
                              ),
                          ],
                        ),
                      ),
              ),

              // ── User chip ────────────────────
              if (user != null) ...[
                const SizedBox(width: 12),
                _UserChip(name: user.name ?? '', role: user.roleAr),
              ],
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
                style: TextStyle(
                  color: GlobalColors.textPrimary(context),
                  fontSize: 13,
                ),
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
              backgroundColor: GlobalColors.accent.withOpacity(0.2),
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
                  style: TextStyle(
                    color: GlobalColors.textSecondary(context),
                    fontSize: 9,
                  ),
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
                      color: widget.color.withOpacity(0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: _isHovered
              ? Icon(widget.icon, size: 8, color: Colors.black.withOpacity(0.6))
              : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  NAV ITEM
// ─────────────────────────────────────────────
class AppBarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const AppBarNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<AppBarNavItem> createState() => _AppBarNavItemState();
}

class _AppBarNavItemState extends State<AppBarNavItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        _ctrl.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _ctrl.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
            decoration: BoxDecoration(
              gradient: widget.isActive
                  ? LinearGradient(
                      colors: [
                        GlobalColors.accent.withOpacity(0.18),
                        GlobalColors.accentSoft.withOpacity(0.08),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    )
                  : null,
              color: !widget.isActive
                  ? _isHovered
                        ? GlobalColors.card(context).withOpacity(0.6)
                        : Colors.transparent
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: widget.isActive
                  ? Border.all(
                      color: GlobalColors.accent.withOpacity(0.35),
                      width: 1,
                    )
                  : _isHovered
                  ? Border.all(
                      color: GlobalColors.border(context).withOpacity(0.6),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: widget.isActive
                      ? GlobalColors.accentSoft
                      : _isHovered
                      ? GlobalColors.textPrimary(context)
                      : GlobalColors.textSecondary(context),
                  size: 17,
                ),
                const SizedBox(width: 7),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: widget.isActive
                        ? GlobalColors.accentSoft
                        : _isHovered
                        ? GlobalColors.textPrimary(context)
                        : GlobalColors.textSecondary(context),
                    fontSize: 13,
                    fontWeight: widget.isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  child: Text(widget.label),
                ),
                if (widget.isActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: GlobalColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: GlobalColors.accent.withOpacity(0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
