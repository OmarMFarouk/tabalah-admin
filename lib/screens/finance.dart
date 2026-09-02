import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/finance_bloc/finance_cubit.dart';
import '../components/general/app_dialog.dart';
import '../components/general/app_field.dart';
import '../components/general/app_table.dart';
import '../components/general/page_header.dart';
import '../components/general/snackbar.dart';
import '../components/general/stat_card.dart';
import '../models/catalog_model.dart';
import '../models/finance_model.dart';
import '../models/paginated_model.dart';
import '../models/users_model.dart';
import '../src/app_colors.dart';
import '../src/app_globals.dart';
import '../src/app_permissions.dart';
import '../src/app_presets.dart';

// ─────────────────────────────────────────────
//  FINANCE — المالية
//  Taking money, the ways of taking it, and the
//  sign-up it pays for. A desk payment carrying
//  an enrollment activates it in one call, so
//  all three belong on one page.
// ─────────────────────────────────────────────
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FinanceCubit()..fetch(),
      child: const _FinanceView(),
    );
  }
}

class _FinanceView extends StatelessWidget {
  const _FinanceView();

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
          body: BlocConsumer<FinanceCubit, AppStates>(
            listener: (ctx, state) {
              if (state is AppSuccess) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: true);
              }
              if (state is AppFailure) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: false);
              }
            },
            builder: (ctx, state) {
              final c = FinanceCubit.get(ctx);
              final loading = state is AppLoading;
              final me = AppGlobals.currentUser;
              final canWrite = Permissions.canWrite;

              return Column(
                children: [
                  PageHeader(
                    title: 'المالية',
                    icon: Icons.payments_rounded,
                    isLoading: loading,
                    onRefresh: c.fetch,
                    tabs: FinanceTab.values
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
                      if (c.tab == FinanceTab.payments && canWrite)
                        HeaderButton(
                          icon: Icons.add_card_rounded,
                          label: 'تسجيل دفعة',
                          color: GlobalColors.green,
                          filled: true,
                          onTap: () => _paymentForm(ctx, c),
                        ),
                      if (c.tab == FinanceTab.sources && canWrite)
                        HeaderButton(
                          icon: Icons.add_rounded,
                          label: 'وسيلة دفع',
                          color: GlobalColors.green,
                          filled: true,
                          onTap: () => _sourceForm(ctx, c),
                        ),
                      // Signing members up is everyday front-desk work.
                      if (c.tab == FinanceTab.enrollments)
                        HeaderButton(
                          icon: Icons.person_add_alt_1_rounded,
                          label: 'تسجيل عضو',
                          color: GlobalColors.green,
                          filled: true,
                          onTap: () => _enrollmentForm(ctx, c),
                        ),
                    ],
                  ),

                  _stats(c),
                  _toolbar(ctx, c),
                  Expanded(child: _table(ctx, c, loading, canWrite, me)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Stats ───────────────────────────────────
  // Totals cover the whole filtered set, so these
  // cards always agree with the filters above them.
  Widget _stats(FinanceCubit c) {
    final cur = AppGlobals.currency;
    return StatRow(
      cards: [
        StatCard(
          label: 'المحصّل',
          value: '${c.totals.collected.toStringAsFixed(0)} $cur',
          icon: Icons.check_circle_rounded,
          color: GlobalColors.green,
          sub: 'ضمن الفلتر الحالي',
        ),
        StatCard(
          label: 'المعلّق',
          value: '${c.totals.pending.toStringAsFixed(0)} $cur',
          icon: Icons.hourglass_bottom_rounded,
          color: GlobalColors.gold,
          sub: 'بانتظار التسوية',
        ),
        StatCard(
          label: 'المسترد',
          value: '${c.totals.refunded.toStringAsFixed(0)} $cur',
          icon: Icons.undo_rounded,
          color: GlobalColors.red,
          sub: 'مبالغ مردودة',
        ),
        StatCard(
          label: 'وسائل الدفع',
          value: '${c.activeSources.length}',
          icon: Icons.account_balance_wallet_rounded,
          color: GlobalColors.accent,
          sub: 'مفعّلة',
          onTap: () => c.switchTab(FinanceTab.sources),
        ),
      ],
    );
  }

  // ── Toolbar ─────────────────────────────────
  Widget _toolbar(BuildContext ctx, FinanceCubit c) {
    switch (c.tab) {
      case FinanceTab.payments:
        return Toolbar(
          children: [
            SizedBox(
              width: 220,
              child: SearchField(
                controller: c.referenceCont,
                hint: 'رقم المرجع... (Enter)',
                onChanged: (_) => c.search(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 200,
              child: AppDropdown<User>(
                value: pickWhere(
                  AppGlobals.members,
                  (u) => u.userId == c.memberFilter,
                ),
                items: AppGlobals.members,
                labelOf: (u) => u.name ?? '—',
                label: 'العضو',
                icon: Icons.person_rounded,
                emptyLabel: 'الكل',
                onChanged: (u) => c.setFilter(member: u?.userId ?? -1),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 190,
              child: AppDropdown<PaymentSource>(
                value: pickWhere(
                  AppGlobals.paymentSources,
                  (s) => s.id == c.sourceFilter,
                ),
                items: AppGlobals.paymentSources,
                labelOf: (s) => s.name ?? '—',
                label: 'الوسيلة',
                icon: Icons.wallet_rounded,
                emptyLabel: 'الكل',
                onChanged: (s) => c.setFilter(source: s?.id ?? -1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                children: ['', ...Payment.statuses]
                    .map(
                      (s) => AppFilterChip(
                        label: s.isEmpty ? 'الكل' : Payment.statusLabel(s),
                        isActive: c.statusFilter == (s.isEmpty ? null : s),
                        onTap: () => c.setFilter(status: s),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );

      case FinanceTab.sources:
        return Toolbar(
          children: [
            Expanded(
              flex: 2,
              child: SearchField(
                controller: c.searchCont,
                hint: 'ابحث بالاسم... (Enter)',
                onChanged: (_) => c.search(),
              ),
            ),
            const SizedBox(width: 12),
            ...['', ...PaymentSource.kinds].map(
              (k) => AppFilterChip(
                label: k.isEmpty ? 'الكل' : PaymentSource.kindLabel(k),
                isActive: c.kindFilter == (k.isEmpty ? null : k),
                onTap: () => c.setFilter(kind: k),
              ),
            ),
            const SizedBox(width: 8),
            AppFilterChip(
              label: 'المفعّلة فقط',
              isActive: c.activeFilter == true,
              onTap: () =>
                  c.setFilter(active: c.activeFilter == true ? null : true),
            ),
          ],
        );

      case FinanceTab.enrollments:
        return Toolbar(
          children: [
            SizedBox(
              width: 260,
              child: AppDropdown<User>(
                value: pickWhere(
                  AppGlobals.members,
                  (u) => u.userId == c.memberFilter,
                ),
                items: AppGlobals.members,
                labelOf: (u) => u.name ?? '—',
                label: 'العضو',
                icon: Icons.person_rounded,
                emptyLabel: 'كل الأعضاء',
                onChanged: (u) => c.setFilter(member: u?.userId ?? -1),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 260,
              child: AppDropdown<Membership>(
                value: pickWhere(
                  AppGlobals.memberships,
                  (m) => m.id == c.membershipFilter,
                ),
                items: AppGlobals.memberships,
                labelOf: (m) => m.name ?? '—',
                label: 'الاشتراك',
                icon: Icons.card_membership_rounded,
                emptyLabel: 'كل الاشتراكات',
                onChanged: (m) => c.setFilter(membership: m?.id ?? -1),
              ),
            ),
          ],
        );
    }
  }

  // ── Tables ──────────────────────────────────
  Widget _table(
    BuildContext ctx,
    FinanceCubit c,
    bool loading,
    bool canWrite,
    User? me,
  ) {
    switch (c.tab) {
      case FinanceTab.payments:
        return AppTable<Payment>(
          isLoading: loading,
          data: c.payments,
          onPage: c.setPage,
          unitLabel: 'دفعة',
          emptyTitle: 'لا توجد مدفوعات',
          emptyHint: 'اضغط "تسجيل دفعة" لتسجيل دفعة مكتب',
          emptyIcon: Icons.receipt_long_rounded,
          columns: const [
            AppColumn('الدافع', flex: 3),
            AppColumn('المبلغ', flex: 2),
            AppColumn('الوسيلة', flex: 2),
            AppColumn('النوع'),
            AppColumn('المرجع', flex: 2),
            AppColumn('التاريخ', flex: 2),
            AppColumn('الحالة'),
            AppColumn('إجراءات', flex: 2),
          ],
          rowBuilder: (rc, p, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, p.payerName, flex: 3, sub: p.notes),
              textCell(
                rc,
                p.amountLabel,
                flex: 2,
                color: GlobalColors.green,
                weight: FontWeight.w800,
                size: 13,
              ),
              textCell(
                rc,
                p.sourceName ?? AppGlobals.sourceName(p.paymentSourceId),
                flex: 2,
                sub: p.recordedByName,
              ),
              textCell(rc, p.typeAr, size: 11),
              textCell(rc, p.reference ?? '—', flex: 2, size: 10),
              textCell(rc, AppPresets.pretty(p.createdAt), flex: 2, size: 11),
              StatusBadge(label: p.statusAr, color: _payColor(p.status)),
              actionsCell([
                ActionBtn(
                  icon: Icons.edit_note_rounded,
                  color: GlobalColors.accentSoft,
                  // Amount and payer are immutable by design.
                  tooltip: 'تصحيح الوسيلة والملاحظات',
                  enabled: canWrite,
                  onTap: () => _correctForm(ctx, c, p),
                ),
                ActionBtn(
                  icon: Icons.undo_rounded,
                  color: GlobalColors.red,
                  tooltip: p.isRefunded
                      ? 'مستردة بالفعل'
                      : 'رد المبلغ وإلغاء التسجيل',
                  enabled: canWrite && !p.isRefunded,
                  onTap: () => _refundForm(ctx, c, p),
                ),
              ], flex: 2),
            ],
          ),
        );

      case FinanceTab.sources:
        return AppTable<PaymentSource>(
          isLoading: loading,
          data: c.sources,
          onPage: c.setPage,
          unitLabel: 'وسيلة',
          emptyTitle: 'لا توجد وسائل دفع',
          emptyHint: 'أضف نقداً أو نقاط بيع أو تحويلاً بنكياً',
          emptyIcon: Icons.account_balance_wallet_rounded,
          columns: const [
            AppColumn('الوسيلة', flex: 3),
            AppColumn('الكود', flex: 2),
            AppColumn('النوع'),
            AppColumn('الدفعات'),
            AppColumn('الترتيب'),
            AppColumn('الحالة'),
            AppColumn('إجراءات', flex: 2),
          ],
          rowBuilder: (rc, s, i) => AppRow(
            index: i,
            cells: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          (s.isOnline ? GlobalColors.blue : GlobalColors.gold)
                              .withValues(alpha: 0.15),
                      child: Icon(
                        s.isOnline
                            ? Icons.language_rounded
                            : Icons.store_rounded,
                        size: 15,
                        color: s.isOnline
                            ? GlobalColors.blue
                            : GlobalColors.gold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  s.name ?? '—',
                                  style: TextStyle(
                                    color: GlobalColors.textPrimary(rc),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (s.isDefault) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: GlobalColors.gold,
                                ),
                              ],
                            ],
                          ),
                          if (s.description != null)
                            Text(
                              s.description!,
                              style: TextStyle(
                                color: GlobalColors.textSecondary(rc),
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              textCell(rc, s.code ?? '—', flex: 2, size: 10),
              StatusBadge(
                label: s.kindAr,
                color: s.isOnline ? GlobalColors.blue : GlobalColors.gold,
              ),
              textCell(
                rc,
                '${s.paymentsCount ?? 0}',
                color: GlobalColors.accentSoft,
                weight: FontWeight.w700,
              ),
              textCell(rc, '${s.sortOrder ?? '—'}', size: 11),
              StatusBadge(
                label: s.statusAr,
                color: s.isActive ? GlobalColors.green : GlobalColors.red,
              ),
              actionsCell([
                ActionBtn(
                  icon: s.isActive
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  color: s.isActive ? GlobalColors.green : GlobalColors.red,
                  // Deactivating is the intended way to retire a method.
                  tooltip: s.isActive ? 'تعطيل' : 'تفعيل',
                  enabled: canWrite,
                  onTap: () => c.toggleSource(s),
                ),
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل',
                  enabled: canWrite,
                  onTap: () => _sourceForm(ctx, c, source: s),
                ),
                ActionBtn(
                  icon: Icons.delete_rounded,
                  color: GlobalColors.red,
                  // Greyed out rather than letting the 422 surprise you.
                  tooltip: s.canDelete
                      ? 'حذف'
                      : 'لا يمكن الحذف — استُخدمت في دفعات سابقة',
                  enabled: canWrite && s.canDelete,
                  onTap: () => showConfirm(
                    ctx,
                    title: 'حذف وسيلة الدفع',
                    message: 'سيتم حذف "${s.name}" نهائياً.',
                    onConfirm: () => c.deleteSource(s.id!),
                  ),
                ),
              ], flex: 2),
            ],
          ),
        );

      case FinanceTab.enrollments:
        return AppTable<Enrollment>(
          isLoading: loading,
          data: c.enrollments,
          onPage: c.setPage,
          unitLabel: 'تسجيل',
          emptyTitle: 'لا توجد تسجيلات',
          emptyHint: 'اضغط "تسجيل عضو" لإلحاق عضو باشتراك',
          emptyIcon: Icons.assignment_rounded,
          columns: const [
            AppColumn('العضو', flex: 3),
            AppColumn('الاشتراك', flex: 3),
            AppColumn('من', flex: 2),
            AppColumn('إلى', flex: 2),
            AppColumn('الحالة'),
            AppColumn('إجراءات', flex: 2),
          ],
          rowBuilder: (rc, e, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, e.memberName, flex: 3),
              textCell(
                rc,
                e.membershipName ?? AppGlobals.membershipName(e.membershipId),
                flex: 3,
              ),
              textCell(rc, AppPresets.pretty(e.startDate), flex: 2, size: 11),
              textCell(rc, AppPresets.pretty(e.endDate), flex: 2, size: 11),
              StatusBadge(label: e.statusAr, color: _enrollColor(e.status)),
              actionsCell([
                // The desk shortcut: take payment against this enrollment.
                ActionBtn(
                  icon: Icons.attach_money_rounded,
                  color: GlobalColors.green,
                  tooltip: 'تحصيل دفعة لهذا التسجيل',
                  enabled: canWrite,
                  onTap: () => _paymentForm(ctx, c, enrollment: e),
                ),
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل المدة',
                  onTap: () => _enrollmentForm(ctx, c, enrollment: e),
                ),
                ActionBtn(
                  icon: Icons.delete_rounded,
                  color: GlobalColors.red,
                  tooltip: 'حذف',
                  enabled: canWrite,
                  onTap: () => showConfirm(
                    ctx,
                    title: 'حذف التسجيل',
                    message: 'سيُلغى تسجيل ${e.memberName} في هذا الاشتراك.',
                    onConfirm: () => c.deleteEnrollment(e.id!),
                  ),
                ),
              ], flex: 2),
            ],
          ),
        );
    }
  }

  Color _payColor(String? s) => switch (s) {
    'success' => GlobalColors.green,
    'pending' => GlobalColors.gold,
    'refunded' => GlobalColors.red,
    'failed' => GlobalColors.red,
    _ => GlobalColors.accent,
  };

  Color _enrollColor(String? s) => switch (s) {
    'active' => GlobalColors.green,
    'pending_payment' => GlobalColors.gold,
    'cancelled' => GlobalColors.red,
    _ => GlobalColors.accent,
  };

  // ── Payment dialog ──────────────────────────
  // Payment sources live on this page, so the
  // dropdown here is never out of date.
  void _paymentForm(
    BuildContext ctx,
    FinanceCubit c, {
    Enrollment? enrollment,
  }) {
    c.clearForm();
    if (enrollment != null) {
      c.formUserId = enrollment.userId;
      c.formEnrollmentId = enrollment.id;
      c.formType = 'enrollment';
    }

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) => AppDialog<FinanceCubit>(
            title: 'تسجيل دفعة مكتب',
            icon: Icons.add_card_rounded,
            saveLabel: 'تسجيل',
            width: 580,
            onSave: c.recordPayment,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (enrollment != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GlobalColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.link_rounded,
                          size: 17,
                          color: GlobalColors.green,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'مرتبطة بتسجيل ${enrollment.memberName} — سيُفعَّل التسجيل فور نجاح الدفعة.',
                            style: TextStyle(
                              color: GlobalColors.textSecondary(sctx),
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                AppDropdown<User>(
                  value: pickWhere(
                    AppGlobals.members,
                    (u) => u.userId == c.formUserId,
                  ),
                  items: AppGlobals.members,
                  labelOf: (u) => '${u.name} · ${u.phone ?? ''}',
                  label: 'الدافع *',
                  icon: Icons.person_rounded,
                  onChanged: (u) => setLocal(() => c.formUserId = u?.userId),
                ),
                gap,
                dialogRow([
                  AppField(
                    controller: c.amountCont,
                    label: 'المبلغ *',
                    icon: Icons.attach_money_rounded,
                    isNumber: true,
                  ),
                  AppDropdown<PaymentSource>(
                    value: pickWhere(
                      c.activeSources,
                      (s) => s.id == c.formSourceId,
                    ),
                    items: c.activeSources,
                    labelOf: (s) => '${s.name} · ${s.kindAr}',
                    label: 'وسيلة الدفع *',
                    icon: Icons.wallet_rounded,
                    onChanged: (s) => setLocal(() => c.formSourceId = s?.id),
                  ),
                ]),
                gap,
                dialogRow([
                  AppDropdown<String>(
                    value: c.formType,
                    items: Payment.types,
                    labelOf: Payment.typeLabel,
                    label: 'النوع',
                    icon: Icons.category_rounded,
                    onChanged: (v) =>
                        setLocal(() => c.formType = v ?? 'enrollment'),
                  ),
                  AppDropdown<String>(
                    value: c.formStatus,
                    items: const ['success', 'pending'],
                    labelOf: Payment.statusLabel,
                    label: 'الحالة',
                    icon: Icons.flag_rounded,
                    onChanged: (v) =>
                        setLocal(() => c.formStatus = v ?? 'success'),
                  ),
                ]),
                gap,
                AppField(
                  controller: c.notesCont,
                  label: 'ملاحظات',
                  icon: Icons.note_rounded,
                  maxLines: 2,
                  hint: 'مثال: نقداً في الاستقبال',
                ),
                gap,

                // Shortcut so the desk never leaves this dialog to add a method.
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sctx);
                      c.switchTab(FinanceTab.sources);
                    },
                    icon: Icon(
                      Icons.settings_rounded,
                      size: 16,
                      color: GlobalColors.accentSoft,
                    ),
                    label: Text(
                      'إدارة وسائل الدفع',
                      style: TextStyle(
                        color: GlobalColors.accentSoft,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _correctForm(BuildContext ctx, FinanceCubit c, Payment p) {
    c.clearForm();
    c.formSourceId = p.paymentSourceId;
    c.notesCont.text = p.notes ?? '';

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) => AppDialog<FinanceCubit>(
            title: 'تصحيح الدفعة',
            icon: Icons.edit_note_rounded,
            saveLabel: 'حفظ',
            width: 500,
            onSave: () => c.correctPayment(p.id!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GlobalColors.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'المبلغ والدافع ثابتان عمداً. المبلغ الخاطئ يُرد ويُسجَّل من جديد حتى يبقى السجل صادقاً.',
                    style: TextStyle(
                      color: GlobalColors.textSecondary(sctx),
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ),
                gap,
                AppDropdown<PaymentSource>(
                  value: pickWhere(
                    c.activeSources,
                    (s) => s.id == c.formSourceId,
                  ),
                  items: c.activeSources,
                  labelOf: (s) => s.name ?? '—',
                  label: 'وسيلة الدفع',
                  icon: Icons.wallet_rounded,
                  onChanged: (s) => setLocal(() => c.formSourceId = s?.id),
                ),
                gap,
                AppField(
                  controller: c.notesCont,
                  label: 'ملاحظات',
                  icon: Icons.note_rounded,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _refundForm(BuildContext ctx, FinanceCubit c, Payment p) {
    c.clearForm();
    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: AppDialog<FinanceCubit>(
          title: 'رد الدفعة',
          icon: Icons.undo_rounded,
          saveLabel: 'رد المبلغ',
          saveColor: GlobalColors.red,
          width: 480,
          onSave: () => c.changeStatus(p.id!, 'refunded'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlobalColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'سيتم رد ${p.amountLabel} إلى ${p.payerName}، وإلغاء التسجيل المرتبط بها إن وُجد.',
                  style: TextStyle(
                    color: GlobalColors.textSecondary(ctx),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
              gap,
              AppField(
                controller: c.notesCont,
                label: 'سبب الرد',
                icon: Icons.note_rounded,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Source dialog ───────────────────────────
  void _sourceForm(BuildContext ctx, FinanceCubit c, {PaymentSource? source}) {
    c.clearForm();
    if (source != null) {
      c.nameCont.text = source.name ?? '';
      c.nameEnCont.text = source.nameEn ?? '';
      c.codeCont.text = source.code ?? '';
      c.descCont.text = source.description ?? '';
      c.descEnCont.text = source.descriptionEn ?? '';
      c.sortOrderCont.text = source.sortOrder?.toString() ?? '';
      c.formKind = source.kind ?? 'offline';
      c.formActive = source.isActive;
      c.formDefault = source.isDefault;
    }

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) => AppDialog<FinanceCubit>(
            title: source == null ? 'وسيلة دفع جديدة' : 'تعديل وسيلة الدفع',
            icon: Icons.account_balance_wallet_rounded,
            saveLabel: source == null ? 'إضافة' : 'حفظ',
            width: 540,
            onSave: () => c.saveSource(id: source?.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                dialogRow([
                  AppField(
                    controller: c.nameCont,
                    label: 'الاسم *',
                    icon: Icons.badge_rounded,
                    hint: 'نقدي، فيزا، تحويل بنكي...',
                  ),
                  AppField(
                    controller: c.codeCont,
                    label: 'الكود',
                    icon: Icons.tag_rounded,
                    // Slugged from the name when left blank.
                    hint: 'يُشتق من الاسم تلقائياً',
                    enabled: source == null,
                  ),
                ]),
                gap,
                // The English label members see at checkout when the app is
                // in English. Blank falls back to the Arabic name, which is
                // what leaves the checkout sheet mixed-language.
                AppField(
                  controller: c.nameEnCont,
                  label: 'Method name (English)',
                  icon: Icons.translate_rounded,
                  hint: 'يُعرض للأعضاء عند اختيار الإنجليزية',
                ),
                gap,
                dialogRow([
                  AppField(
                    controller: c.descCont,
                    label: 'الوصف (عربي)',
                    icon: Icons.description_rounded,
                    maxLines: 2,
                  ),
                  AppField(
                    controller: c.descEnCont,
                    label: 'Description (English)',
                    icon: Icons.translate_rounded,
                    maxLines: 2,
                  ),
                ]),
                gap,
                dialogRow([
                  AppDropdown<String>(
                    value: c.formKind,
                    items: PaymentSource.kinds,
                    labelOf: PaymentSource.kindLabel,
                    label: 'النوع',
                    icon: Icons.category_rounded,
                    onChanged: (k) =>
                        setLocal(() => c.formKind = k ?? 'offline'),
                  ),
                  AppField(
                    controller: c.sortOrderCont,
                    label: 'ترتيب العرض',
                    icon: Icons.sort_rounded,
                    isNumber: true,
                  ),
                ]),
                gap,
                AppSwitch(
                  value: c.formActive,
                  label: 'مفعّلة',
                  hint: 'تظهر في شاشة التحصيل',
                  onChanged: (v) => setLocal(() => c.formActive = v),
                ),
                gap,
                AppSwitch(
                  value: c.formDefault,
                  label: 'الوسيلة الافتراضية',
                  // Promoting one demotes whichever held the flag before.
                  hint: 'تُستخدم عند عدم تحديد وسيلة — واحدة فقط',
                  onChanged: (v) => setLocal(() => c.formDefault = v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Enrollment dialog ───────────────────────
  void _enrollmentForm(
    BuildContext ctx,
    FinanceCubit c, {
    Enrollment? enrollment,
  }) {
    c.clearForm();
    if (enrollment != null) {
      c.formUserId = enrollment.userId;
      c.formMembershipId = enrollment.membershipId;
      c.formStart = enrollment.startDate ?? AppPresets.today;
      c.formEnd = enrollment.endDate ?? AppPresets.nextMonth;
    }

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) => AppDialog<FinanceCubit>(
            title: enrollment == null ? 'تسجيل عضو' : 'تعديل التسجيل',
            icon: Icons.assignment_turned_in_rounded,
            saveLabel: enrollment == null ? 'تسجيل' : 'حفظ',
            width: 540,
            onSave: () => c.saveEnrollment(id: enrollment?.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (enrollment == null) ...[
                  AppDropdown<User>(
                    value: pickWhere(
                      AppGlobals.members,
                      (u) => u.userId == c.formUserId,
                    ),
                    items: AppGlobals.members,
                    labelOf: (u) => '${u.name} · ${u.phone ?? ''}',
                    label: 'العضو *',
                    icon: Icons.person_rounded,
                    onChanged: (u) => setLocal(() => c.formUserId = u?.userId),
                  ),
                  gap,
                  AppDropdown<Membership>(
                    value: pickWhere(
                      AppGlobals.memberships,
                      (m) => m.id == c.formMembershipId,
                    ),
                    items: AppGlobals.memberships
                        .where((m) => m.isActive)
                        .toList(),
                    labelOf: (m) =>
                        '${m.name} · ${(m.price ?? 0).toStringAsFixed(0)} ${AppGlobals.currency}${m.isFull ? ' (مكتمل)' : ''}',
                    label: 'الاشتراك *',
                    icon: Icons.card_membership_rounded,
                    onChanged: (m) =>
                        setLocal(() => c.formMembershipId = m?.id),
                  ),
                  gap,
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      '${enrollment.memberName} · ${enrollment.membershipName ?? ''}',
                      style: TextStyle(
                        color: GlobalColors.textPrimary(sctx),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                dialogRow([
                  DateField(
                    value: c.formStart,
                    label: 'تاريخ البداية *',
                    onPicked: (d) => setLocal(() => c.formStart = d),
                  ),
                  DateField(
                    value: c.formEnd,
                    label: 'تاريخ الانتهاء *',
                    onPicked: (d) => setLocal(() => c.formEnd = d),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
