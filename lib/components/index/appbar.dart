import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/app_bloc/cubit.dart';
import '../../blocs/auth_bloc/auth_cubit.dart';
import '../../blocs/base_states.dart';
import '../../src/app_assets.dart';
import '../../src/app_colors.dart';
import '../../src/app_destinations.dart';
import '../../src/app_globals.dart';
import '../../src/app_presets.dart';
import '../general/app_dialog.dart';

// The destination list now lives in src/app_destinations.dart, because it
// has to be filtered by the signed-in account's permissions and kept
// index-aligned with the PageView. This bar just renders what it is given.

class MyAppBar extends StatelessWidget {
  const MyAppBar({
    super.key,
    required this.currentPage,
    required this.onChanged,
    required this.items,
  });

  final int currentPage;
  final Function(int) onChanged;

  /// The bar's entries after permission filtering — each is either a page
  /// or a menu of pages. See AppDestinations.navEntries().
  final List<NavEntry> items;

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
                  'تبالة',
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
                                    : GlobalColors.textSecondary(
                                        context,
                                      ).withValues(alpha: 0.4),
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
                                      ).withValues(alpha: 0.4),
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
                            for (final entry in items)
                              if (entry.isMenu)
                                AppBarNavMenu(
                                  entry: entry,
                                  currentPage: currentPage,
                                  onChanged: onChanged,
                                )
                              else
                                AppBarNavItem(
                                  icon: entry.icon,
                                  label: entry.label,
                                  isActive: currentPage == entry.index,
                                  onTap: () => onChanged(entry.index),
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
                      color: widget.color.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: _isHovered
              ? Icon(
                  widget.icon,
                  size: 8,
                  color: Colors.black.withValues(alpha: 0.6),
                )
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
                        GlobalColors.accent.withValues(alpha: 0.18),
                        GlobalColors.accentSoft.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    )
                  : null,
              color: !widget.isActive
                  ? _isHovered
                        ? GlobalColors.card(context).withValues(alpha: 0.6)
                        : Colors.transparent
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: widget.isActive
                  ? Border.all(
                      color: GlobalColors.accent.withValues(alpha: 0.35),
                      width: 1,
                    )
                  : _isHovered
                  ? Border.all(
                      color: GlobalColors.border(
                        context,
                      ).withValues(alpha: 0.6),
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
                          color: GlobalColors.accent.withValues(alpha: 0.6),
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

// ─────────────────────────────────────────────
//  NAV MENU — مجموعة صفحات في القائمة العلوية
//
//  Opens on hover and sits flush under its item.
//
//  Built on a plain OverlayEntry positioned from
//  the button's own screen rect. Two earlier
//  attempts are worth recording so they are not
//  repeated:
//
//  * PopupMenuButton — opens on tap only, no hover
//    hook at all, and its `position: under` plus
//    an offset were what put the menu miles below
//    the bar.
//  * OverlayPortal + CompositedTransformFollower —
//    the portal showed (the chevron flipped) but
//    the menu never appeared. Anchor-based
//    following is hard to verify by reading; a
//    measured `Positioned` is not.
//
//  Styled to match AppBarNavItem exactly: a group
//  and a page sit next to each other in the same
//  bar and should read as the same kind of thing.
//
//  A group counts as active when *any* of its
//  pages is the current one; otherwise landing on
//  الحصص would leave the bar showing nothing
//  selected.
// ─────────────────────────────────────────────
class AppBarNavMenu extends StatefulWidget {
  final NavEntry entry;
  final int currentPage;
  final Function(int) onChanged;

  const AppBarNavMenu({
    super.key,
    required this.entry,
    required this.currentPage,
    required this.onChanged,
  });

  @override
  State<AppBarNavMenu> createState() => _AppBarNavMenuState();
}

class _AppBarNavMenuState extends State<AppBarNavMenu> {
  /// The menu currently on screen, across every group in the bar.
  ///
  /// Without this, sliding the pointer from one group to the next opened the
  /// second before the first's close timer had fired, and both stayed up.
  /// One menu at a time is the whole contract of a menu bar.
  static _AppBarNavMenuState? _openMenu;

  OverlayEntry? _entry;
  bool _overButton = false;
  bool _overMenu = false;
  Timer? _closeTimer;

  /// How long the menu survives the pointer being over neither the button
  /// nor the menu.
  ///
  /// Not cosmetic. The menu sits a couple of pixels below the button so its
  /// border does not overlap, and crossing that gap leaves the pointer over
  /// neither for a frame or two — closing immediately would make the menu
  /// impossible to reach. This also forgives clipping a corner on the way in.
  static const _closeDelay = Duration(milliseconds: 140);

  bool get _isOpen => _entry != null;

  @override
  void dispose() {
    _closeTimer?.cancel();
    _remove();
    super.dispose();
  }

  void _remove() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    if (_openMenu == this) _openMenu = null;
  }

  void _open() {
    _closeTimer?.cancel();
    if (_isOpen) return;

    // Close whichever group was open before this one.
    if (_openMenu != null && _openMenu != this) _openMenu!._closeNow();

    // Measured, not anchored: the button's rect in global coordinates is
    // something we can compute and check, which the follower's anchor maths
    // was not.
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final topLeft = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.of(context).size;

    // RTL: hang the menu from the button's right edge, so `right` is the
    // distance from the screen's right edge to that same edge.
    final right = screen.width - (topLeft.dx + box.size.width);
    final top = topLeft.dy + box.size.height + 2;

    _entry = OverlayEntry(
      builder: (overlayContext) =>
          Positioned(top: top, right: right, child: _menu(overlayContext)),
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _openMenu = this;
    setState(() {});
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(_closeDelay, () {
      if (!mounted || _overButton || _overMenu) return;
      _remove();
      setState(() {});
    });
  }

  void _closeNow() {
    _closeTimer?.cancel();
    _overButton = false;
    _overMenu = false;
    _remove();
    if (mounted) setState(() {});
  }

  bool get _isActive =>
      widget.entry.children.any((c) => c.index == widget.currentPage);

  /// The label shown on the bar.
  ///
  /// When one of the group's pages is open, the bar shows *that* page's name
  /// rather than the group's. The group name tells you which menu you are in;
  /// the page name tells you where you are, which is the more useful of the
  /// two once you have arrived.
  String get _label {
    if (!_isActive) return widget.entry.label;
    return widget.entry.children
        .firstWhere((c) => c.index == widget.currentPage)
        .label;
  }

  @override
  Widget build(BuildContext context) {
    final active = _isActive;
    final lit = _overButton || _isOpen;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        _overButton = true;
        _open();
      },
      onExit: (_) {
        _overButton = false;
        _scheduleClose();
      },
      child: GestureDetector(
        // Tapping the group opens its first page, so the entry still does
        // something on a click rather than only on hover.
        onTap: () {
          _closeNow();
          widget.onChanged(widget.entry.children.first.index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    colors: [
                      GlobalColors.accent.withValues(alpha: 0.18),
                      GlobalColors.accentSoft.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  )
                : null,
            color: !active
                ? lit
                      ? GlobalColors.card(context).withValues(alpha: 0.6)
                      : Colors.transparent
                : null,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(color: GlobalColors.accent.withValues(alpha: 0.35))
                : lit
                ? Border.all(
                    color: GlobalColors.border(context).withValues(alpha: 0.6),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.entry.icon,
                size: 17,
                color: active
                    ? GlobalColors.accentSoft
                    : lit
                    ? GlobalColors.textPrimary(context)
                    : GlobalColors.textSecondary(context),
              ),
              const SizedBox(width: 7),
              Text(
                _label,
                style: TextStyle(
                  color: active
                      ? GlobalColors.accentSoft
                      : lit
                      ? GlobalColors.textPrimary(context)
                      : GlobalColors.textSecondary(context),
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: active
                      ? GlobalColors.accentSoft
                      : GlobalColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext overlayContext) {
    return MouseRegion(
      onEnter: (_) {
        _overMenu = true;
        _closeTimer?.cancel();
      },
      onExit: (_) {
        _overMenu = false;
        _scheduleClose();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(minWidth: 155, maxWidth: 155),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: GlobalColors.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GlobalColors.border(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.entry.children
                  .map(
                    (child) => _MenuRow(
                      icon: child.icon,
                      label: child.label,
                      selected: child.index == widget.currentPage,
                      onTap: () {
                        _closeNow();
                        widget.onChanged(child.index);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row inside a nav menu. Its own widget so it can carry hover state
/// without rebuilding the whole menu on every pointer move.
class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final lit = widget.selected || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? GlobalColors.accent.withValues(alpha: 0.16)
                : _hovered
                ? GlobalColors.card(context).withValues(alpha: 0.7)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 17,
                color: lit
                    ? GlobalColors.accentSoft
                    : GlobalColors.textSecondary(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.selected
                        ? GlobalColors.accentSoft
                        : GlobalColors.textPrimary(context),
                    fontSize: 13,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.selected) ...[
                const SizedBox(width: 10),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: GlobalColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: GlobalColors.accent.withValues(alpha: 0.6),
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
    );
  }
}
