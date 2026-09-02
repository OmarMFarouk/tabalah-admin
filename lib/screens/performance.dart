import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/performance_bloc/performance_cubit.dart';
import '../components/general/app_dialog.dart';
import '../components/general/app_field.dart';
import '../components/general/app_table.dart';
import '../components/general/page_header.dart';
import '../components/general/snackbar.dart';
import '../components/general/stat_card.dart';
import '../models/paginated_model.dart';
import '../models/performance_model.dart';
import '../models/users_model.dart';
import '../src/app_colors.dart';
import '../src/app_globals.dart';
import '../src/app_permissions.dart';

// ─────────────────────────────────────────────
//  PERFORMANCE — الأداء والرواتب
//  A metric is defined once, recorded monthly
//  per staff member, and read beside their pay.
// ─────────────────────────────────────────────
class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PerformanceCubit()..fetch(),
      child: const _PerformanceView(),
    );
  }
}

class _PerformanceView extends StatelessWidget {
  const _PerformanceView();

  // Staff and coaches are the people who get measured and paid.
  // Carry the account id across — the KPI and salary endpoints key on
  // `user_id`, so a name-only User would post a null and be rejected.
  List<User> get _staffPool => [
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      // SelectionArea sits here, per screen, rather than once in
      // MaterialApp.builder. `builder` wraps the Navigator, so a
      // SelectionArea there would be ABOVE the Overlay and its
      // copy/select context menu would have nowhere to mount - the same
      // trap Tooltip hits in that position. Inside a route the Overlay is
      // an ancestor, so right-click copy works.
      child: SelectionArea(
        child: Scaffold(
          backgroundColor: GlobalColors.bg(context),
          body: BlocConsumer<PerformanceCubit, AppStates>(
            listener: (ctx, state) {
              if (state is AppSuccess) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: true);
              }
              if (state is AppFailure) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: false);
              }
            },
            builder: (ctx, state) {
              final c = PerformanceCubit.get(ctx);
              final loading = state is AppLoading;
              final canWrite = Permissions.canWrite;

              return Column(
                children: [
                  PageHeader(
                    title: 'الأداء والرواتب',
                    icon: Icons.insights_rounded,
                    isLoading: loading,
                    onRefresh: c.fetch,
                    tabs: PerformanceTab.values
                        .map(
                          (t) => TabPill(
                            label: t.label,
                            icon: t.icon,
                            isActive: c.tab == t,
                            onTap: () => c.switchTab(t),
                          ),
                        )
                        .toList(),
                    actions: [
                      if (canWrite)
                        HeaderButton(
                          icon: Icons.add_rounded,
                          label: switch (c.tab) {
                            PerformanceTab.records => 'تسجيل أداء',
                            PerformanceTab.kpis => 'مؤشر جديد',
                            PerformanceTab.salaries => 'تسجيل راتب',
                          },
                          color: GlobalColors.green,
                          filled: true,
                          onTap: () => _openForm(ctx, c),
                        ),
                    ],
                  ),

                  StatRow(
                    cards: [
                      StatCard(
                        label: 'المؤشرات',
                        value: '${c.kpis.total}',
                        icon: Icons.speed_rounded,
                        color: GlobalColors.purple,
                        sub: 'مقياس معرّف',
                      ),
                      StatCard(
                        label: 'التسجيلات',
                        value: '${c.records.total}',
                        icon: Icons.insights_rounded,
                        color: GlobalColors.accent,
                        sub: 'قياس شهري',
                      ),
                      StatCard(
                        label: 'حقّقوا الهدف',
                        value:
                            '${c.records.items.where((r) => r.metTarget).length}',
                        icon: Icons.emoji_events_rounded,
                        color: GlobalColors.green,
                        sub: 'ضمن الصفحة الحالية',
                      ),
                      StatCard(
                        label: 'إجمالي الرواتب',
                        value:
                            '${c.salaries.items.fold<double>(0, (s, e) => s + (e.amount ?? 0)).toStringAsFixed(0)} ${AppGlobals.currency}',
                        icon: Icons.account_balance_rounded,
                        color: GlobalColors.gold,
                        sub: 'ضمن الصفحة الحالية',
                      ),
                    ],
                  ),

                  _toolbar(ctx, c),
                  Expanded(child: _table(ctx, c, loading, canWrite)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext ctx, PerformanceCubit c) {
    if (c.tab == PerformanceTab.kpis) {
      return const SizedBox(height: 14);
    }

    return Toolbar(
      children: [
        SizedBox(
          width: 250,
          child: AppDropdown<User>(
            value: pickWhere(_staffPool, (u) => u.userId == c.staffFilter),
            items: _staffPool,
            labelOf: (u) => u.name ?? '—',
            label: 'الموظف',
            icon: Icons.badge_rounded,
            emptyLabel: 'كل الفريق',
            onChanged: (u) => c.setFilter(staff: u?.userId ?? -1),
          ),
        ),
        const SizedBox(width: 12),
        if (c.tab == PerformanceTab.records)
          SizedBox(
            width: 250,
            child: AppDropdown<Kpi>(
              value: pickWhere(c.kpis.items, (k) => k.id == c.kpiFilter),
              items: c.kpis.items,
              labelOf: (k) => k.metric ?? '—',
              label: 'المؤشر',
              icon: Icons.speed_rounded,
              emptyLabel: 'كل المؤشرات',
              onChanged: (k) => c.setFilter(kpi: k?.id ?? -1),
            ),
          ),
        const SizedBox(width: 12),
        SizedBox(
          width: 180,
          child: _PeriodField(
            value: c.periodFilter,
            label: 'الشهر',
            onPicked: (p) => c.setFilter(period: p),
          ),
        ),
      ],
    );
  }

  Widget _table(
    BuildContext ctx,
    PerformanceCubit c,
    bool loading,
    bool canWrite,
  ) {
    switch (c.tab) {
      case PerformanceTab.records:
        return AppTable<KpiRecord>(
          isLoading: loading,
          data: c.records,
          onPage: c.setPage,
          unitLabel: 'تسجيل',
          emptyTitle: 'لا توجد تسجيلات أداء',
          emptyHint: 'سجّل الهدف والنتيجة الفعلية لكل موظف شهرياً',
          emptyIcon: Icons.insights_rounded,
          columns: const [
            AppColumn('الموظف', flex: 3),
            AppColumn('المؤشر', flex: 3),
            AppColumn('الشهر'),
            AppColumn('الهدف'),
            AppColumn('الفعلي'),
            AppColumn('الإنجاز', flex: 3),
            AppColumn('إجراءات'),
          ],
          rowBuilder: (rc, r, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, r.staffName, flex: 3),
              textCell(rc, r.metric ?? '—', flex: 3),
              textCell(rc, r.period ?? '—', size: 11),
              textCell(rc, r.target?.toStringAsFixed(1) ?? '—'),
              textCell(
                rc,
                r.actual?.toStringAsFixed(1) ?? '—',
                color: r.metTarget ? GlobalColors.green : GlobalColors.gold,
                weight: FontWeight.w800,
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: r.progress.clamp(0, 1),
                          minHeight: 7,
                          backgroundColor: GlobalColors.border(rc),
                          color: r.metTarget
                              ? GlobalColors.green
                              : GlobalColors.gold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${(r.progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: GlobalColors.textSecondary(rc),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsCell([
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تحديث النتيجة',
                  enabled: canWrite,
                  onTap: () => _openForm(ctx, c, record: r),
                ),
              ]),
            ],
          ),
        );

      case PerformanceTab.kpis:
        return AppTable<Kpi>(
          isLoading: loading,
          data: c.kpis,
          onPage: c.setPage,
          unitLabel: 'مؤشر',
          emptyTitle: 'لا توجد مؤشرات',
          emptyHint: 'عرّف مقياساً لتبدأ قياس الأداء',
          emptyIcon: Icons.speed_rounded,
          columns: const [
            AppColumn('المؤشر', flex: 5),
            AppColumn('عدد التسجيلات', flex: 2),
            AppColumn('إجراءات', flex: 2),
          ],
          rowBuilder: (rc, k, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, k.metric ?? '—', flex: 5),
              textCell(
                rc,
                '${k.recordsCount ?? 0}',
                flex: 2,
                color: GlobalColors.accentSoft,
                weight: FontWeight.w700,
              ),
              actionsCell([
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل',
                  enabled: canWrite,
                  onTap: () => _openForm(ctx, c, kpi: k),
                ),
                ActionBtn(
                  icon: Icons.delete_rounded,
                  color: GlobalColors.red,
                  tooltip: 'حذف',
                  enabled: canWrite,
                  onTap: () => showConfirm(
                    ctx,
                    title: 'حذف المؤشر',
                    message: 'سيُحذف "${k.metric}" مع تسجيلاته.',
                    onConfirm: () => c.deleteKpi(k.id!),
                  ),
                ),
              ], flex: 2),
            ],
          ),
        );

      case PerformanceTab.salaries:
        return AppTable<Salary>(
          isLoading: loading,
          data: c.salaries,
          onPage: c.setPage,
          unitLabel: 'راتب',
          emptyTitle: 'لا توجد رواتب مسجّلة',
          emptyHint: 'سجّل راتب كل موظف عن شهر محدد',
          emptyIcon: Icons.account_balance_rounded,
          columns: const [
            AppColumn('الموظف', flex: 4),
            AppColumn('الشهر', flex: 2),
            AppColumn('المبلغ', flex: 2),
            AppColumn('إجراءات', flex: 2),
          ],
          rowBuilder: (rc, s, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, s.staffName, flex: 4),
              textCell(rc, s.period ?? '—', flex: 2),
              textCell(
                rc,
                s.amountLabel,
                flex: 2,
                color: GlobalColors.green,
                weight: FontWeight.w800,
                size: 13,
              ),
              actionsCell([
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل المبلغ',
                  enabled: canWrite,
                  onTap: () => _openForm(ctx, c, salary: s),
                ),
                ActionBtn(
                  icon: Icons.delete_rounded,
                  color: GlobalColors.red,
                  tooltip: 'حذف',
                  enabled: canWrite,
                  onTap: () => showConfirm(
                    ctx,
                    title: 'حذف الراتب',
                    message: 'سيُحذف سجل راتب ${s.staffName} عن ${s.period}.',
                    onConfirm: () => c.deleteSalary(s.id!),
                  ),
                ),
              ], flex: 2),
            ],
          ),
        );
    }
  }

  void _openForm(
    BuildContext ctx,
    PerformanceCubit c, {
    Kpi? kpi,
    KpiRecord? record,
    Salary? salary,
  }) {
    c.clearForm();
    if (kpi != null) c.metricCont.text = kpi.metric ?? '';
    if (record != null) {
      c.formKpiId = record.kpiId;
      c.formUserId = record.userId;
      c.targetCont.text = record.target?.toStringAsFixed(1) ?? '';
      c.actualCont.text = record.actual?.toStringAsFixed(1) ?? '';
      c.formPeriod = record.period ?? c.formPeriod;
    }
    if (salary != null) {
      c.formUserId = salary.userId;
      c.amountCont.text = salary.amount?.toStringAsFixed(0) ?? '';
      c.formPeriod = salary.period ?? c.formPeriod;
    }

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) {
            switch (c.tab) {
              case PerformanceTab.kpis:
                return AppDialog<PerformanceCubit>(
                  title: kpi == null ? 'مؤشر جديد' : 'تعديل المؤشر',
                  icon: Icons.speed_rounded,
                  saveLabel: kpi == null ? 'إضافة' : 'حفظ',
                  width: 460,
                  onSave: () => c.saveKpi(id: kpi?.id),
                  child: AppField(
                    controller: c.metricCont,
                    label: 'اسم المقياس *',
                    icon: Icons.speed_rounded,
                    hint: 'الاسم فريد — مثال: نسبة التجديد',
                  ),
                );

              case PerformanceTab.records:
                return AppDialog<PerformanceCubit>(
                  title: record == null ? 'تسجيل أداء' : 'تحديث النتيجة',
                  icon: Icons.insights_rounded,
                  saveLabel: record == null ? 'تسجيل' : 'حفظ',
                  width: 540,
                  onSave: () => c.saveRecord(id: record?.id),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (record == null) ...[
                        AppDropdown<Kpi>(
                          value: pickWhere(
                            c.kpis.items,
                            (k) => k.id == c.formKpiId,
                          ),
                          items: c.kpis.items,
                          labelOf: (k) => k.metric ?? '—',
                          label: 'المؤشر *',
                          icon: Icons.speed_rounded,
                          onChanged: (k) => setLocal(() => c.formKpiId = k?.id),
                        ),
                        gap,
                        AppDropdown<User>(
                          value: pickWhere(
                            _staffPool,
                            (u) => u.userId == c.formUserId,
                          ),
                          items: _staffPool,
                          labelOf: (u) => u.name ?? '—',
                          label: 'الموظف *',
                          icon: Icons.badge_rounded,
                          onChanged: (u) =>
                              setLocal(() => c.formUserId = u?.userId),
                        ),
                        gap,
                        _PeriodField(
                          value: c.formPeriod,
                          label: 'الشهر * (YYYY-MM)',
                          onPicked: (p) => setLocal(() => c.formPeriod = p),
                        ),
                        gap,
                      ],
                      dialogRow([
                        AppField(
                          controller: c.targetCont,
                          label: 'الهدف',
                          icon: Icons.flag_rounded,
                          isNumber: true,
                          enabled: record == null,
                        ),
                        AppField(
                          controller: c.actualCont,
                          label: 'الفعلي',
                          icon: Icons.trending_up_rounded,
                          isNumber: true,
                        ),
                      ]),
                    ],
                  ),
                );

              case PerformanceTab.salaries:
                return AppDialog<PerformanceCubit>(
                  title: salary == null ? 'تسجيل راتب' : 'تعديل الراتب',
                  icon: Icons.account_balance_rounded,
                  saveLabel: salary == null ? 'تسجيل' : 'حفظ',
                  width: 500,
                  onSave: () => c.saveSalary(id: salary?.id),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (salary == null) ...[
                        AppDropdown<User>(
                          value: pickWhere(
                            _staffPool,
                            (u) => u.userId == c.formUserId,
                          ),
                          items: _staffPool,
                          labelOf: (u) => u.name ?? '—',
                          label: 'الموظف *',
                          icon: Icons.badge_rounded,
                          onChanged: (u) =>
                              setLocal(() => c.formUserId = u?.userId),
                        ),
                        gap,
                        _PeriodField(
                          value: c.formPeriod,
                          label: 'الشهر * (YYYY-MM)',
                          onPicked: (p) => setLocal(() => c.formPeriod = p),
                        ),
                        gap,
                      ],
                      AppField(
                        controller: c.amountCont,
                        label: 'المبلغ *',
                        icon: Icons.payments_rounded,
                        isNumber: true,
                      ),
                    ],
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PERIOD FIELD — اختيار الشهر
//  The API wants YYYY-MM, so this picks a month
//  rather than a date.
// ─────────────────────────────────────────────
class _PeriodField extends StatelessWidget {
  const _PeriodField({
    required this.value,
    required this.label,
    required this.onPicked,
  });

  final String? value;
  final String label;
  final void Function(String) onPicked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse('${value ?? ''}-01') ?? now,
          firstDate: DateTime(now.year - 3),
          lastDate: DateTime(now.year + 1),
          initialDatePickerMode: DatePickerMode.year,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.dark(
                primary: GlobalColors.accent,
                surface: GlobalColors.card(context),
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          onPicked('${picked.year}-${picked.month.toString().padLeft(2, '0')}');
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: GlobalColors.surface(context),
          labelStyle: TextStyle(
            color: GlobalColors.textSecondary(context),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.date_range_rounded,
            color: GlobalColors.accentSoft,
            size: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: GlobalColors.border(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: GlobalColors.border(context)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        child: Text(
          value ?? 'كل الشهور',
          style: TextStyle(
            color: value == null
                ? GlobalColors.textSecondary(context)
                : GlobalColors.textPrimary(context),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
