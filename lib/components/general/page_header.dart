import 'package:flutter/material.dart';

import '../../src/app_colors.dart';

// ─────────────────────────────────────────────
//  PAGE HEADER — رأس الصفحة
//  Icon, title, the page's tabs, and its actions
//  on one 64px bar.
// ─────────────────────────────────────────────
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.icon,
    this.tabs = const [],
    this.actions = const [],
    this.isLoading = false,
    this.onRefresh,
  });

  final String title;
  final IconData icon;
  final List<Widget> tabs;
  final List<Widget> actions;
  final bool isLoading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: GlobalColors.surface(context),
        border: Border(
          bottom: BorderSide(color: GlobalColors.border(context), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: GlobalColors.accent.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [GlobalColors.accent, GlobalColors.accentSoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: GlobalColors.textPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),

          if (tabs.isNotEmpty) ...[
            const SizedBox(width: 28),
            // High flex so the tab strip claims the space it needs before
            // the Spacer below takes the remainder for the action buttons.
            Flexible(
              flex: 8,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: GlobalColors.card(context),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: GlobalColors.border(context)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: tabs),
                ),
              ),
            ),
          ],

          const Spacer(),

          if (isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: GlobalColors.accentSoft,
              ),
            )
          else if (onRefresh != null)
            HeaderButton(
              icon: Icons.refresh_rounded,
              label: 'تحديث',
              color: GlobalColors.accentSoft,
              onTap: onRefresh!,
            ),

          for (final a in actions) ...[const SizedBox(width: 10), a],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TAB PILL — زر التبويب
// ─────────────────────────────────────────────
class TabPill extends StatelessWidget {
  const TabPill({
    super.key,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? GlobalColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive
                    ? Colors.white
                    : GlobalColors.textSecondary(context),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : GlobalColors.textSecondary(context),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HEADER BUTTON — زر الإجراء
// ─────────────────────────────────────────────
class HeaderButton extends StatelessWidget {
  const HeaderButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: filled ? color : color.withValues(alpha: 0.12),
        foregroundColor: filled ? Colors.white : color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
