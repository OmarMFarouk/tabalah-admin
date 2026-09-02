import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/paginated_model.dart';
import '../../src/app_colors.dart';
import 'empty_widget.dart';

// ─────────────────────────────────────────────
//  COLUMN — تعريف العمود
// ─────────────────────────────────────────────
class AppColumn {
  final String label;
  final int flex;
  const AppColumn(this.label, {this.flex = 2});
}

// ─────────────────────────────────────────────
//  APP TABLE — الجدول
//  Header, striped rows, and a footer that
//  reports the count and pages through it.
// ─────────────────────────────────────────────
class AppTable<T> extends StatelessWidget {
  const AppTable({
    super.key,
    required this.columns,
    required this.data,
    required this.rowBuilder,
    required this.emptyTitle,
    this.emptyHint,
    this.emptyIcon = Icons.inbox_rounded,
    this.isLoading = false,
    this.onPage,
    this.unitLabel = 'سجل',
  });

  final List<AppColumn> columns;
  final Paginated<T> data;
  final Widget Function(BuildContext, T, int) rowBuilder;
  final String emptyTitle;
  final String? emptyHint;
  final IconData emptyIcon;
  final bool isLoading;
  final void Function(int page)? onPage;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        color: GlobalColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlobalColors.border(context)),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: GlobalColors.card(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: columns
                  .map(
                    (c) => Expanded(
                      flex: c.flex,
                      child: Text(
                        c.label,
                        style: TextStyle(
                          color: GlobalColors.textSecondary(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          // ── Rows ────────────────────────────
          Expanded(
            child: isLoading && data.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      color: GlobalColors.accent,
                    ),
                  )
                : data.isEmpty
                ? EmptyState(
                    title: emptyTitle,
                    hint: emptyHint,
                    icon: emptyIcon,
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: data.items.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: GlobalColors.border(
                        context,
                      ).withValues(alpha: 0.5),
                    ),
                    itemBuilder: (ctx, i) => rowBuilder(ctx, data.items[i], i),
                  ),
          ),

          // ── Footer ──────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: GlobalColors.card(context),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(color: GlobalColors.border(context)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'إجمالي: ${data.total} $unitLabel',
                  style: TextStyle(
                    color: GlobalColors.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
                // Which slice of that total is on screen right now.
                if (!data.isEmpty) ...[
                  const SizedBox(width: 10),
                  Text(
                    '(${data.firstIndex}–${data.lastIndex})',
                    style: TextStyle(
                      color: GlobalColors.textSecondary(
                        context,
                      ).withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
                const Spacer(),
                // Shown whenever there is anything to page through — the
                // arrows disable themselves at the ends, so a single-page
                // result still reads as "صفحة ١ من ١" rather than vanishing.
                if (onPage != null && !data.isEmpty)
                  Paginator(data: data, onPage: onPage!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TABLE ROW — صف الجدول
// ─────────────────────────────────────────────
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.index,
    required this.cells,
    this.onTap,
  });

  final int index;
  final List<Widget> cells;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: index.isOdd
          ? GlobalColors.card(context).withValues(alpha: 0.5)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: GlobalColors.accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: cells),
        ),
      ),
    );
  }
}

// ── Cell helpers — خلايا جاهزة ────────────────
Widget textCell(
  BuildContext context,
  String text, {
  int flex = 2,
  Color? color,
  FontWeight weight = FontWeight.w500,
  double size = 12,
  String? sub,
}) {
  return Expanded(
    flex: flex,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            color: color ?? GlobalColors.textPrimary(context),
            fontSize: size,
            fontWeight: weight,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        if (sub != null && sub.isNotEmpty)
          Text(
            sub,
            style: TextStyle(
              color: GlobalColors.textSecondary(context),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    ),
  );
}

// Name cell with the member's initial in an avatar.
Widget avatarCell(
  BuildContext context,
  String name, {
  String? avatar,
  int flex = 3,
  String? sub,
}) {
  return Expanded(
    flex: flex,
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: GlobalColors.accent.withValues(alpha: 0.15),
          foregroundImage: avatar == null || avatar.isEmpty
              ? null
              : CachedNetworkImageProvider(avatar),
          child: Text(
            name.isNotEmpty ? name.substring(0, 1) : '؟',
            style: TextStyle(
              color: GlobalColors.accentSoft,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: GlobalColors.textPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (sub != null && sub.isNotEmpty)
                Text(
                  sub,
                  style: TextStyle(
                    color: GlobalColors.textSecondary(context),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
//  MEDIA CELL — خلية باسم وصورة/أيقونة مخصصة
//
//  avatarCell always draws a circle with an
//  initial in it, which is right for people and
//  wrong for a sport: a sport has a glyph or a
//  photo, and a square tile reads as an object
//  rather than as a face. Same layout otherwise,
//  so rows stay aligned across tabs.
// ─────────────────────────────────────────────
Widget mediaCell(
  BuildContext context,
  String name, {
  required Widget leading,
  int flex = 3,
  String? sub,
}) {
  return Expanded(
    flex: flex,
    child: Row(
      children: [
        leading,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: GlobalColors.textPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (sub != null && sub.isNotEmpty)
                Text(
                  sub,
                  style: TextStyle(
                    color: GlobalColors.textSecondary(context),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
//  STATUS BADGE — شارة الحالة
// ─────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.flex = 2,
    this.wrap = true,
  });

  final String label;
  final Color color;
  final int flex;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );

    if (!wrap) return badge;
    return Expanded(
      flex: flex,
      child: Center(child: badge),
    );
  }
}

// ─────────────────────────────────────────────
//  ACTION BUTTON — زر إجراء بالصف
// ─────────────────────────────────────────────
class ActionBtn extends StatelessWidget {
  const ActionBtn({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : GlobalColors.textSecondary(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: c.withValues(alpha: enabled ? 0.1 : 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: c.withValues(alpha: enabled ? 1 : 0.4),
            size: 16,
          ),
        ),
      ),
    );
  }
}

Widget actionsCell(List<Widget> actions, {int flex = 2}) {
  return Expanded(
    flex: flex,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          actions[i],
        ],
      ],
    ),
  );
}

// ─────────────────────────────────────────────
//  PAGINATOR — تنقّل الصفحات
// ─────────────────────────────────────────────
class Paginator extends StatelessWidget {
  const Paginator({super.key, required this.data, required this.onPage});

  final Paginated data;
  final void Function(int) onPage;

  @override
  Widget build(BuildContext context) {
    // RTL: "previous" points right, "next" points left.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _navBtn(
          context,
          Icons.first_page_rounded,
          data.hasPrev ? () => onPage(1) : null,
          'الأولى',
        ),
        const SizedBox(width: 4),
        _navBtn(
          context,
          Icons.chevron_right_rounded,
          data.hasPrev ? () => onPage(data.currentPage - 1) : null,
          'السابق',
        ),

        const SizedBox(width: 8),
        for (final p in data.pageWindow) ...[
          const SizedBox(width: 3),
          if (p == -1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '…',
                style: TextStyle(
                  color: GlobalColors.textSecondary(context),
                  fontSize: 12,
                ),
              ),
            )
          else
            _pageBtn(context, p),
        ],
        const SizedBox(width: 11),

        _navBtn(
          context,
          Icons.chevron_left_rounded,
          data.hasNext ? () => onPage(data.currentPage + 1) : null,
          'التالي',
        ),
        const SizedBox(width: 4),
        _navBtn(
          context,
          Icons.last_page_rounded,
          data.hasNext ? () => onPage(data.lastPage) : null,
          'الأخيرة',
        ),

        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            'صفحة ${data.currentPage} من ${data.lastPage}',
            style: TextStyle(
              color: GlobalColors.textSecondary(context),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pageBtn(BuildContext context, int page) {
    final isCurrent = page == data.currentPage;
    return InkWell(
      onTap: isCurrent ? null : () => onPage(page),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 26),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: isCurrent
              ? GlobalColors.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent
                ? GlobalColors.accent.withValues(alpha: 0.45)
                : GlobalColors.border(context),
          ),
        ),
        child: Text(
          '$page',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isCurrent
                ? GlobalColors.accentSoft
                : GlobalColors.textSecondary(context),
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _navBtn(
    BuildContext context,
    IconData icon,
    VoidCallback? onTap,
    String tooltip,
  ) {
    final enabled = onTap != null;
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: enabled
              ? GlobalColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? GlobalColors.accentSoft
              : GlobalColors.textSecondary(context).withValues(alpha: 0.4),
        ),
      ),
    );

    // A tooltip on a dead button is just noise.
    return enabled ? Tooltip(message: tooltip, child: btn) : btn;
  }
}
