import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/hr_bloc/overtime_cubit.dart';
import '../components/general/app_dialog.dart';
import '../components/general/app_field.dart';
import '../components/general/app_table.dart';
import '../components/general/page_header.dart';
import '../components/general/snackbar.dart';
import '../components/general/stat_card.dart';
import '../models/hr_model.dart';
import '../models/paginated_model.dart';
import '../models/users_model.dart';
import '../src/app_colors.dart';
import '../src/app_globals.dart';
import '../src/app_permissions.dart';
import 'profile.dart';

// ─────────────────────────────────────────────
//  OVERTIME — الساعات الإضافية
//  Hours beyond the normal day, for anyone on the
//  payroll. Totals are over the whole filter, so
//  "how much overtime did Salem do this month" is
//  one filter away.
// ─────────────────────────────────────────────

class OvertimeScreen extends StatelessWidget {
  const OvertimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OvertimeCubit()..fetch(),
      child: const _OvertimeView(),
    );
  }
}

/// Everyone who can accrue overtime: staff and trainers, keyed on user id.
List<User> get payrollPool => [
  ...AppGlobals.staff,
  ...AppGlobals.trainers.map(
    (t) => User(
      userId: t.userId,
      name: t.name,
      email: t.email,
      phone: t.phone,
      role: 'trainer',
    ),
  ),
];

class _OvertimeView extends StatelessWidget {
  const _OvertimeView();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SelectionArea(
        child: Scaffold(
          backgroundColor: GlobalColors.bg(context),
          body: BlocConsumer<OvertimeCubit, AppStates>(
            listener: (ctx, state) {
              if (state is AppSuccess) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: true);
              }
              if (state is AppFailure) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: false);
              }
            },
            builder: (ctx, state) {
              final c = OvertimeCubit.get(ctx);
              final loading = state is AppLoading;
              final canWrite = Permissions.canManageOvertime;
              final pool = payrollPool;

              return Column(
                children: [
                  PageHeader(
                    title: 'الساعات الإضافية',
                    icon: Icons.more_time_rounded,
                    isLoading: loading,
                    onRefresh: c.fetch,
                    actions: [
                      if (canWrite)
                        HeaderButton(
                          icon: Icons.add_rounded,
                          label: 'تسجيل ساعات',
                          color: GlobalColors.green,
                          filled: true,
                          onTap: () => _openForm(ctx, c),
                        ),
                    ],
                  ),
                  StatRow(
                    cards: [
                      StatCard(
                        label: 'إجمالي الساعات',
                        value: formatHours(c.totalHours),
                        icon: Icons.timelapse_rounded,
                        color: GlobalColors.gold,
                        sub: c.from == null && c.to == null
                            ? 'كل الفترات'
                            : '${c.from ?? '…'} ← ${c.to ?? '…'}',
                      ),
                      StatCard(
                        label: 'السجلات',
                        value: '${c.rows.total}',
                        icon: Icons.receipt_long_rounded,
                        color: GlobalColors.accent,
                        sub: 'ضمن الفلتر الحالي',
                      ),
                      StatCard(
                        label: 'متوسط السجل',
                        value: c.rows.total == 0
                            ? '—'
                            : formatHours(c.totalHours / c.rows.total),
                        icon: Icons.av_timer_rounded,
                        color: GlobalColors.blue,
                        sub: 'لكل يوم مسجّل',
                      ),
                    ],
                  ),
                  Toolbar(
                    children: [
                      SizedBox(
                        width: 260,
                        child: AppDropdown<User>(
                          value: pickWhere(pool, (u) => u.userId == c.userFilter),
                          items: pool,
                          labelOf: (u) => u.name ?? '—',
                          label: 'الموظف / المدرب',
                          icon: Icons.badge_rounded,
                          emptyLabel: 'الجميع',
                          onChanged: (u) => c.setFilter(user: u?.userId ?? -1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 170,
                        child: DateField(
                          value: c.from,
                          label: 'من تاريخ',
                          onPicked: (v) => c.setFilter(from: v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 170,
                        child: DateField(
                          value: c.to,
                          label: 'إلى تاريخ',
                          onPicked: (v) => c.setFilter(to: v),
                        ),
                      ),
                      if (c.from != null || c.to != null) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: c.clearDates,
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          label: const Text('مسح التاريخ'),
                        ),
                      ],
                    ],
                  ),
                  Expanded(
                    child: AppTable<OvertimeRecord>(
                      isLoading: loading,
                      data: c.rows,
                      onPage: c.setPage,
                      unitLabel: 'سجل',
                      emptyTitle: 'لا توجد ساعات إضافية',
                      emptyHint: 'سجّل الساعات الإضافية للمدربين والموظفين',
                      emptyIcon: Icons.more_time_rounded,
                      columns: const [
                        AppColumn('الاسم', flex: 3),
                        AppColumn('التاريخ'),
                        AppColumn('الساعات'),
                        AppColumn('ملاحظة', flex: 3),
                        AppColumn('سجّلها', flex: 2),
                        AppColumn('إجراءات'),
                      ],
                      rowBuilder: (rc, r, i) => AppRow(
                        index: i,
                        onTap: r.userId == null
                            ? null
                            : () => UserProfileScreen.open(rc, r.userId!, name: r.userName),
                        cells: [
                          avatarCell(
                            rc,
                            r.userName ?? '—',
                            flex: 3,
                            sub: User(role: r.userRole).roleAr,
                          ),
                          textCell(rc, r.date ?? '—'),
                          textCell(
                            rc,
                            formatHours(r.hours),
                            color: GlobalColors.gold,
                            weight: FontWeight.w800,
                            size: 13,
                          ),
                          textCell(rc, r.note ?? '—', flex: 3, size: 11),
                          textCell(rc, r.recorderName ?? '—', flex: 2, size: 11),
                          actionsCell([
                            ActionBtn(
                              icon: Icons.edit_rounded,
                              color: GlobalColors.accentSoft,
                              tooltip: 'تعديل',
                              enabled: canWrite,
                              onTap: () => _openForm(ctx, c, record: r),
                            ),
                            ActionBtn(
                              icon: Icons.delete_rounded,
                              color: GlobalColors.red,
                              tooltip: 'حذف',
                              enabled: canWrite,
                              onTap: () => showConfirm(
                                ctx,
                                title: 'حذف السجل',
                                message:
                                    'سيُحذف سجل ${formatHours(r.hours)} لـ ${r.userName ?? ''} بتاريخ ${r.date ?? ''}.',
                                onConfirm: () => c.delete(r.id!),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext ctx, OvertimeCubit c, {OvertimeRecord? record}) {
    c.fillForm(record);
    final pool = payrollPool;

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) => AppDialog<OvertimeCubit>(
            title: record == null ? 'تسجيل ساعات إضافية' : 'تعديل الساعات الإضافية',
            icon: Icons.more_time_rounded,
            saveLabel: record == null ? 'تسجيل' : 'حفظ',
            width: 500,
            onSave: () => c.save(id: record?.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (record == null) ...[
                  AppDropdown<User>(
                    value: pickWhere(pool, (u) => u.userId == c.formUserId),
                    items: pool,
                    labelOf: (u) => '${u.name ?? '—'} · ${u.roleAr}',
                    label: 'الموظف / المدرب *',
                    icon: Icons.badge_rounded,
                    onChanged: (u) => setLocal(() => c.formUserId = u?.userId),
                  ),
                  gap,
                ] else ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      record.userName ?? '—',
                      style: TextStyle(
                        color: GlobalColors.textPrimary(sctx),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  gap,
                ],
                dialogRow([
                  DateField(
                    value: c.formDate,
                    label: 'التاريخ *',
                    onPicked: (v) => setLocal(() => c.formDate = v),
                  ),
                  AppField(
                    controller: c.hoursCont,
                    label: 'عدد الساعات *',
                    icon: Icons.timelapse_rounded,
                    isNumber: true,
                    hint: 'مثال: 2.5',
                  ),
                ]),
                gap,
                AppField(
                  controller: c.noteCont,
                  label: 'ملاحظة',
                  icon: Icons.notes_rounded,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
