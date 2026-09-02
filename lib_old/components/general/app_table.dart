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
                      color: GlobalColors.border(context).withOpacity(0.5),
                    ),
                    itemBuilder: (ctx, i) =>
                        rowBuilder(ctx, data.items[i], i),
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
                const Spacer(),
                if (onPage != null && data.lastPage > 1)
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
          ? GlobalColors.card(context).withOpacity(0.5)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: GlobalColors.accent.withOpacity(0.04),
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
  int flex = 3,
  String? sub,
}) {
  return Expanded(
    flex: flex,
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: GlobalColors.accent.withOpacity(0.15),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
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
    return Expanded(flex: flex, child: Center(child: badge));
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
            color: c.withOpacity(enabled ? 0.1 : 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: c.withOpacity(enabled ? 1 : 0.4), size: 16),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _navBtn(
          context,
          Icons.chevron_right_rounded,
          data.hasPrev ? () => onPage(data.currentPage - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'صفحة ${data.currentPage} من ${data.lastPage}',
            style: TextStyle(
              color: GlobalColors.textSecondary(context),
              fontSize: 12,
            ),
          ),
        ),
        _navBtn(
          context,
          Icons.chevron_left_rounded,
          data.hasNext ? () => onPage(data.currentPage + 1) : null,
        ),
      ],
    );
  }

  Widget _navBtn(BuildContext context, IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: enabled
              ? GlobalColors.accent.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? GlobalColors.accentSoft
              : GlobalColors.textSecondary(context).withOpacity(0.4),
        ),
      ),
    );
  }
}
