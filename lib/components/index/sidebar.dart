import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../src/app_colors.dart';
import '../../src/app_destinations.dart';

// ─────────────────────────────────────────────
//  SIDEBAR — القائمة الجانبية
//
//  Right-hand in RTL, grouped into sections that
//  fold, and collapsible to an icon rail. Both the
//  collapse and each section's fold are remembered
//  across launches: someone who works in HR all
//  day should not refold Finance every morning.
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
  static const _foldedKey = 'sidebar_folded_sections';

  static const double _expandedWidth = 246;
  static const double _collapsedWidth = 74;

  bool _collapsed = false;
  Set<String> _folded = {};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _collapsed = prefs.getBool(_collapsedKey) ?? false;
        _folded = (prefs.getStringList(_foldedKey) ?? const []).toSet();
      });
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_collapsedKey, _collapsed);
    await prefs.setStringList(_foldedKey, _folded.toList());
  }

  void _toggleCollapsed() {
    setState(() => _collapsed = !_collapsed);
    _persist();
  }

  void _toggleSection(String label) {
    setState(() {
      if (!_folded.remove(label)) _folded.add(label);
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final sections = AppDestinations.navSections();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: _collapsed ? _collapsedWidth : _expandedWidth,
      margin: const EdgeInsetsDirectional.fromSTEB(16, 16, 0, 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: GlobalColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GlobalColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // Labels follow the width actually available, not the flag: during the
      // expand animation the rail is still narrow for a few frames, and
      // drawing labels into it would overflow.
      child: LayoutBuilder(
        builder: (context, box) {
          final narrow = box.maxWidth < 160;

          return Column(
            children: [
              _Toggle(narrow: narrow, collapsed: _collapsed, onTap: _toggleCollapsed),
              Divider(height: 1, color: GlobalColors.border(context)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  children: [
                    for (var i = 0; i < sections.length; i++)
                      ..._section(context, sections[i], narrow, first: i == 0),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    NavSectionEntry section,
    bool narrow, {
    required bool first,
  }) {
    // A one-page section has nothing to fold: the page is the section.
    final foldable = section.items.length > 1;
    final open = narrow || !foldable || !_folded.contains(section.label);
    final active = section.items.any((i) => i.index == widget.currentPage);

    return [
      if (narrow)
        first
            ? const SizedBox(height: 4)
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Divider(height: 1, color: GlobalColors.border(context)),
              )
      else
        _SectionHeader(
          label: section.label,
          icon: section.icon,
          open: open,
          active: active,
          foldable: foldable,
          onTap: foldable ? () => _toggleSection(section.label) : null,
        ),
      AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: AlignmentDirectional.topStart,
        child: open
            ? Column(
                children: [
                  for (final item in section.items)
                    _NavTile(
                      item: item,
                      selected: item.index == widget.currentPage,
                      narrow: narrow,
                      onTap: () => widget.onChanged(item.index),
                    ),
                ],
              )
            : const SizedBox(width: double.infinity),
      ),
    ];
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
      height: 54,
      child: Row(
        mainAxisAlignment: narrow ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          if (!narrow) ...[
            const SizedBox(width: 18),
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
          IconButton(
            tooltip: collapsed ? 'توسيع القائمة' : 'طي القائمة',
            onPressed: onTap,
            icon: Icon(
              collapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
              color: GlobalColors.accentSoft,
            ),
          ),
          if (!narrow) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION HEADER
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.open,
    required this.active,
    required this.foldable,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool open;
  final bool active;
  final bool foldable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = active
        ? GlobalColors.accentSoft
        : GlobalColors.textSecondary(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 14, 6, 6),
        child: Row(
          children: [
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: ink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (foldable)
              AnimatedRotation(
                turns: open ? 0 : 0.25,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 16,
                  color: GlobalColors.textSecondary(context),
                ),
              ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
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
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 42,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: widget.narrow ? 0 : 12),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      GlobalColors.accent.withValues(alpha: 0.22),
                      GlobalColors.accentSoft.withValues(alpha: 0.05),
                    ],
                    begin: AlignmentDirectional.centerStart.resolve(TextDirection.rtl),
                    end: AlignmentDirectional.centerEnd.resolve(TextDirection.rtl),
                  )
                : null,
            color: selected
                ? null
                : _hovered
                ? GlobalColors.card(context).withValues(alpha: 0.85)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? GlobalColors.accent.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: widget.narrow
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(widget.item.icon, size: 19, color: ink),
              if (!widget.narrow) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: GlobalColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: GlobalColors.accent.withValues(alpha: 0.6),
                          blurRadius: 5,
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

    // Collapsed to icons, the name has to be one hover away.
    return widget.narrow
        ? Tooltip(message: widget.item.label, preferBelow: false, child: tile)
        : tile;
  }
}
