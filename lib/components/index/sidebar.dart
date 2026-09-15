import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../src/app_colors.dart';
import '../../src/app_destinations.dart';

// ─────────────────────────────────────────────
//  SIDEBAR — القائمة الجانبية
//
//  Right-hand in RTL, grouped into sections that
//  fold, and collapsible to an icon rail. Sections
//  start folded except الأفراد, and whatever the
//  user opens is remembered across launches.
//
//  Opening a section, or expanding the rail,
//  scrolls the list so what just appeared is in
//  view — the list follows the user instead of
//  leaving them to hunt for it.
// ─────────────────────────────────────────────

class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    required this.currentPage,
    required this.onChanged,
  });

  final int currentPage;
  final ValueChanged<int> onChanged;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  static const _collapsedKey = 'sidebar_collapsed';
  static const _openKey = 'sidebar_open_sections';
  static const _defaultOpen = {'الأفراد'};

  static const double _expandedWidth = 252;
  static const double _collapsedWidth = 76;
  static const _motion = Duration(milliseconds: 280);
  static const _curve = Curves.easeOutCubic;

  final _scroll = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<int, GlobalKey> _itemKeys = {};

  bool _collapsed = false;
  Set<String> _open = {..._defaultOpen};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _collapsed = prefs.getBool(_collapsedKey) ?? false;
        final saved = prefs.getStringList(_openKey);
        if (saved != null) _open = saved.toSet();
      });
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_collapsedKey, _collapsed);
    await prefs.setStringList(_openKey, _open.toList());
  }

  /// Glide to [key] once the animation that revealed it has run.
  void _reveal(GlobalKey? key) {
    Future.delayed(_motion + const Duration(milliseconds: 20), () {
      final ctx = key?.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        alignment: 0.15,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  void _toggleCollapsed() {
    setState(() => _collapsed = !_collapsed);
    _persist();
    _reveal(_itemKeys[widget.currentPage]);
  }

  void _toggleSection(String label) {
    final opening = !_open.contains(label);
    setState(() => opening ? _open.add(label) : _open.remove(label));
    _persist();
    if (opening) _reveal(_sectionKeys[label]);
  }

  @override
  Widget build(BuildContext context) {
    final sections = AppDestinations.navSections();

    return AnimatedContainer(
      duration: _motion,
      curve: _curve,
      width: _collapsed ? _collapsedWidth : _expandedWidth,
      margin: const EdgeInsetsDirectional.fromSTEB(16, 16, 0, 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GlobalColors.surface(context),
            Color.lerp(GlobalColors.surface(context), GlobalColors.accent, 0.03)!,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GlobalColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      // Labels follow the width actually available, not the flag: during the
      // expand animation the rail is still narrow for a few frames.
      child: LayoutBuilder(
        builder: (context, box) {
          final narrow = box.maxWidth < 170;

          return Column(
            children: [
              _Toggle(narrow: narrow, collapsed: _collapsed, onTap: _toggleCollapsed),
              Divider(height: 1, color: GlobalColors.border(context)),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  child: Column(
                    children: [
                      for (var i = 0; i < sections.length; i++)
                        _section(context, sections[i], narrow, first: i == 0),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(
    BuildContext context,
    NavSectionEntry section,
    bool narrow, {
    required bool first,
  }) {
    // A one-page section has nothing to fold: the page is the section.
    final foldable = section.items.length > 1;
    final open = narrow || !foldable || _open.contains(section.label);
    final active = section.items.any((i) => i.index == widget.currentPage);
    final key = _sectionKeys.putIfAbsent(section.label, GlobalKey.new);

    return Column(
      key: key,
      children: [
        if (narrow)
          first
              ? const SizedBox(height: 4)
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                  child: Divider(height: 1, color: GlobalColors.border(context)),
                )
        else
          _SectionHeader(
            label: section.label,
            icon: section.icon,
            count: section.items.length,
            open: open,
            active: active,
            foldable: foldable,
            onTap: foldable ? () => _toggleSection(section.label) : null,
          ),
        // Height and opacity animate together, so a section unfolds rather
        // than popping in.
        ClipRect(
          child: AnimatedAlign(
            duration: _motion,
            curve: _curve,
            alignment: AlignmentDirectional.topStart,
            heightFactor: open ? 1 : 0,
            child: AnimatedOpacity(
              duration: _motion,
              curve: _curve,
              opacity: open ? 1 : 0,
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: narrow || !foldable ? 0 : 6),
                child: Column(
                  children: [
                    for (final item in section.items)
                      _NavTile(
                        key: _itemKeys.putIfAbsent(item.index, GlobalKey.new),
                        item: item,
                        selected: item.index == widget.currentPage,
                        narrow: narrow,
                        onTap: () => widget.onChanged(item.index),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  COLLAPSE TOGGLE
// ─────────────────────────────────────────────

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.narrow,
    required this.collapsed,
    required this.onTap,
  });

  final bool narrow;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: narrow ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          if (!narrow) ...[
            const SizedBox(width: 18),
            Icon(Icons.apps_rounded, size: 18, color: GlobalColors.accentSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'القائمة',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: GlobalColors.textPrimary(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          Tooltip(
            message: collapsed ? 'توسيع القائمة' : 'طي القائمة',
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: GlobalColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AnimatedRotation(
                  turns: collapsed ? 0.5 : 0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_double_arrow_right_rounded,
                    size: 20,
                    color: GlobalColors.accentSoft,
                  ),
                ),
              ),
            ),
          ),
          if (!narrow) const SizedBox(width: 10),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION HEADER
// ─────────────────────────────────────────────

class _SectionHeader extends StatefulWidget {
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.count,
    required this.open,
    required this.active,
    required this.foldable,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool open;
  final bool active;
  final bool foldable;
  final VoidCallback? onTap;

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ink = widget.active
        ? GlobalColors.accentSoft
        : _hovered
        ? GlobalColors.textPrimary(context)
        : GlobalColors.textSecondary(context);

    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(top: 8, bottom: 2),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 9, 8, 9),
          decoration: BoxDecoration(
            color: _hovered && widget.onTap != null
                ? GlobalColors.card(context).withValues(alpha: 0.7)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 15, color: ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // Folded with the current page inside: say so, or the user has
              // no idea where they are.
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: widget.active && !widget.open ? 1 : 0,
                child: Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsetsDirectional.only(end: 6),
                  decoration: BoxDecoration(color: GlobalColors.accent, shape: BoxShape.circle),
                ),
              ),
              if (widget.foldable) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: GlobalColors.border(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: widget.open ? 0 : 0.25,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: Icon(Icons.expand_more_rounded, size: 18, color: ink),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  NAV TILE
// ─────────────────────────────────────────────

class _NavTile extends StatefulWidget {
  const _NavTile({
    super.key,
    required this.item,
    required this.selected,
    required this.narrow,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final bool narrow;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final lit = selected || _hovered;
    final ink = selected
        ? GlobalColors.accentSoft
        : _hovered
        ? GlobalColors.textPrimary(context)
        : GlobalColors.textSecondary(context);

    final tile = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 44,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        GlobalColors.accent.withValues(alpha: 0.24),
                        GlobalColors.accentSoft.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    )
                  : null,
              color: selected
                  ? null
                  : _hovered
                  ? GlobalColors.card(context).withValues(alpha: 0.9)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? GlobalColors.accent.withValues(alpha: 0.35) : Colors.transparent,
              ),
            ),
            child: Stack(
              children: [
                // The accent bar on the leading edge grows in on selection.
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      width: 3.5,
                      height: selected ? 24 : 0,
                      decoration: BoxDecoration(
                        color: GlobalColors.accent,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: GlobalColors.accent.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  // Nudges inward on hover, so the row answers the pointer.
                  padding: EdgeInsetsDirectional.only(
                    start: widget.narrow ? 0 : (_hovered && !selected ? 16 : 12),
                    end: widget.narrow ? 0 : 10,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        widget.narrow ? MainAxisAlignment.center : MainAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: lit
                              ? GlobalColors.accent.withValues(alpha: selected ? 0.2 : 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(widget.item.icon, size: 18, color: ink),
                      ),
                      if (!widget.narrow) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              color: ink,
                              fontSize: 13.5,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                              fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                            ),
                            child: Text(
                              widget.item.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _hovered && !selected ? 1 : 0,
                          child: Icon(Icons.chevron_left_rounded, size: 18, color: ink),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Collapsed to icons, the name has to be one hover away.
    return widget.narrow
        ? Tooltip(message: widget.item.label, preferBelow: false, waitDuration: const Duration(milliseconds: 250), child: tile)
        : tile;
  }
}
