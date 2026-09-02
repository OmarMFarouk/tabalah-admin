import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/profile_bloc/user_audit_cubit.dart';
import '../components/general/app_field.dart';
import '../components/general/app_table.dart';
import '../components/general/modal_page.dart';
import '../components/general/snackbar.dart';
import '../models/settings_model.dart';
import '../src/app_colors.dart';

// ─────────────────────────────────────────────
//  USER AUDIT — سجل نشاط الحساب
//
//  Everything this account did, opened from its
//  profile. The settings screen answers "what
//  happened in the club"; this answers "what did
//  this person do", which is the question you
//  actually have while looking at someone.
//
//  Same filters as the club-wide trail — search,
//  action, record type, date range — because the
//  narrowing you want is the same once the
//  account is already fixed.
// ─────────────────────────────────────────────
void showUserAuditDialog(BuildContext context, int userId, {String? name}) {
  ModalPage.show(
    context,
    BlocProvider(
      create: (_) => UserAuditCubit(userId)..fetch(),
      child: _UserAuditView(name: name),
    ),
    // Narrower than a profile: six columns of log, not a whole record.
  );
}

class _UserAuditView extends StatelessWidget {
  const _UserAuditView({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return ModalPage(
      maxWidth: 1100,
      child: SelectionArea(
        child: Material(
          color: Colors.transparent,
          child: BlocConsumer<UserAuditCubit, AppStates>(
            listener: (ctx, state) {
              if (state is AppFailure) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: false);
              }
            },
            builder: (ctx, state) {
              final c = UserAuditCubit.get(ctx);
              final loading = state is AppLoading;

              return Column(
                children: [
                  _header(ctx, c, loading),
                  _toolbar(ctx, c),
                  Expanded(child: _table(ctx, c, loading)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────
  Widget _header(BuildContext ctx, UserAuditCubit c, bool loading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      decoration: BoxDecoration(
        color: GlobalColors.surface(ctx).withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: GlobalColors.border(ctx))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: GlobalColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.history_rounded,
              color: GlobalColors.accentSoft,
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'سجل النشاط',
                  style: TextStyle(
                    color: GlobalColors.textPrimary(ctx),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name == null
                      ? 'كل ما قام به هذا الحساب'
                      : 'كل ما قام به $name',
                  style: TextStyle(
                    color: GlobalColors.textSecondary(ctx),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            onPressed: c.fetch,
            icon: const Icon(Icons.refresh_rounded),
            color: GlobalColors.textSecondary(ctx),
            tooltip: 'تحديث',
          ),
          const SizedBox(width: 4),
          ModalCloseButton(onTap: () => Navigator.of(ctx).maybePop()),
        ],
      ),
    );
  }

  // ── Filters ─────────────────────────────────
  Widget _toolbar(BuildContext ctx, UserAuditCubit c) {
    return Toolbar(
      children: [
        Expanded(
          flex: 3,
          child: SearchField(
            controller: c.searchCont,
            hint: 'ابحث في الوصف... (اضغط Enter)',
            onChanged: (_) => c.search(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 160,
          child: AppDropdown<String>(
            value: c.actionFilter,
            items: c.availableActions,
            labelOf: actionLabel,
            label: 'الإجراء',
            icon: Icons.bolt_rounded,
            emptyLabel: 'كل الإجراءات',
            onChanged: (v) => c.setFilter(action: v ?? ''),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 160,
          child: AppDropdown<String>(
            value: c.typeFilter,
            items: c.availableTypes,
            labelOf: (t) => t,
            label: 'النوع',
            icon: Icons.category_rounded,
            emptyLabel: 'كل الأنواع',
            onChanged: (v) => c.setFilter(type: v ?? ''),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: DateField(
            value: c.fromFilter,
            label: 'من تاريخ',
            onPicked: (d) => c.setFilter(from: d),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: DateField(
            value: c.toFilter,
            label: 'إلى تاريخ',
            onPicked: (d) => c.setFilter(to: d),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: c.hasFilters ? c.clearFilters : null,
          tooltip: 'مسح الفلاتر',
          icon: Icon(
            Icons.filter_alt_off_rounded,
            color: c.hasFilters
                ? GlobalColors.red
                : GlobalColors.textSecondary(ctx).withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  // ── Trail ───────────────────────────────────
  Widget _table(BuildContext ctx, UserAuditCubit c, bool loading) {
    return AppTable<AuditEntry>(
      isLoading: loading,
      data: c.logs,
      onPage: c.setPage,
      unitLabel: 'حدث',
      emptyTitle: 'لا يوجد نشاط',
      // Two different empty states: nothing recorded at all reads very
      // differently from "your filters excluded everything".
      emptyHint: c.hasFilters
          ? 'لا نتائج ضمن الفلاتر الحالية — جرّب توسيعها'
          : 'لم يُسجَّل أي إجراء لهذا الحساب بعد',
      emptyIcon: Icons.history_rounded,
      columns: const [
        AppColumn('الوقت', flex: 2),
        AppColumn('الإجراء'),
        AppColumn('السجل', flex: 2),
        AppColumn('التفاصيل', flex: 4),
        AppColumn('IP'),
        AppColumn(''),
      ],
      rowBuilder: (rc, log, i) => AppRow(
        index: i,
        cells: [
          textCell(rc, log.createdAt ?? '—', flex: 2, size: 11),
          StatusBadge(
            label: log.actionLabel ?? log.action ?? '—',
            color: actionColor(log),
          ),
          textCell(
            rc,
            log.recordLabel ?? log.recordType ?? '—',
            flex: 2,
            size: 11,
          ),
          textCell(rc, log.description ?? '—', flex: 4, size: 11),
          textCell(rc, log.ipAddress ?? '—', size: 10),
          actionsCell([
            ActionBtn(
              icon: Icons.unfold_more_rounded,
              color: GlobalColors.blue,
              tooltip: 'ما الذي تغيّر',
              enabled:
                  log.diff.isNotEmpty ||
                  log.granted.isNotEmpty ||
                  log.revoked.isNotEmpty,
              onTap: () => showAuditDiff(ctx, log),
            ),
          ], flex: 1),
        ],
      ),
    );
  }
}

// ── Shared with the settings trail ────────────
Color actionColor(AuditEntry log) {
  if (log.isDestructive) return GlobalColors.red;
  if (log.action == 'created') return GlobalColors.green;
  if (log.action == 'login_failed') return GlobalColors.red;
  if (log.isAuthEvent) return GlobalColors.blue;
  return GlobalColors.accent;
}

String actionLabel(String action) => switch (action) {
  'created' => 'إنشاء',
  'updated' => 'تعديل',
  'deleted' => 'حذف',
  'login' => 'تسجيل دخول',
  'logout' => 'تسجيل خروج',
  'login_failed' => 'محاولة فاشلة',
  'guardian_login' => 'دخول ولي أمر',
  _ => action,
};

/// What moved on one entry, as `field: before → after`, plus the
/// granted/revoked lists that role edits produce.
///
/// Shared with the settings trail rather than written twice: the two views
/// differ in what they list, not in what one entry means.
void showAuditDiff(BuildContext ctx, AuditEntry log) {
  showDialog(
    context: ctx,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: GlobalColors.surface(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.unfold_more_rounded, color: GlobalColors.accentSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                log.description ?? 'تفاصيل التغيير',
                style: TextStyle(
                  color: GlobalColors.textPrimary(ctx),
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${log.actor} — ${log.createdAt ?? ''}',
                  style: TextStyle(
                    color: GlobalColors.textSecondary(ctx),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),

                // Role edits: the granted/revoked lists are the whole
                // story, and far more legible than a raw before/after.
                if (log.granted.isNotEmpty)
                  _permList(ctx, 'صلاحيات مُنحت', log.granted,
                      GlobalColors.green),
                if (log.revoked.isNotEmpty)
                  _permList(ctx, 'صلاحيات سُحبت', log.revoked,
                      GlobalColors.red),

                ...log.diff.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            d.field,
                            style: TextStyle(
                              color: GlobalColors.textSecondary(ctx),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              if (d.before != null)
                                Text(
                                  d.before!,
                                  style: TextStyle(
                                    color: GlobalColors.red,
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              if (d.before != null && d.after != null)
                                Icon(
                                  Icons.arrow_back_rounded,
                                  size: 13,
                                  color: GlobalColors.textSecondary(ctx),
                                ),
                              if (d.after != null)
                                Text(
                                  d.after!,
                                  style: TextStyle(
                                    color: GlobalColors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    ),
  );
}

Widget _permList(
  BuildContext ctx,
  String title,
  List<String> keys,
  Color color,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: keys
              .map(
                (k) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    k,
                    style: TextStyle(color: color, fontSize: 10.5),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

