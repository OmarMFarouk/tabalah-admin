import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/catalog_bloc/catalog_cubit.dart';
import '../components/general/app_dialog.dart';
import '../components/general/app_field.dart';
import '../components/general/app_table.dart';
import '../components/general/page_header.dart';
import '../components/general/snackbar.dart';
import '../components/general/stat_card.dart';
import '../models/catalog_model.dart';
import '../models/paginated_model.dart';
import '../models/users_model.dart';
import '../src/app_colors.dart';
import '../src/app_globals.dart';

// ─────────────────────────────────────────────
//  CATALOG — الاشتراكات
//  A sport holds memberships; a membership holds
//  the weekly slots it meets on. One page.
// ─────────────────────────────────────────────
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CatalogCubit()..fetch(),
      child: const _CatalogView(),
    );
  }
}

class _CatalogView extends StatelessWidget {
  const _CatalogView();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: GlobalColors.bg(context),
        body: BlocConsumer<CatalogCubit, AppStates>(
          listener: (ctx, state) {
            if (state is AppSuccess) {
              MySnackBar.show(ctx, text: state.msg, isSuccess: true);
            }
            if (state is AppFailure) {
              MySnackBar.show(ctx, text: state.msg, isSuccess: false);
            }
          },
          builder: (ctx, state) {
            final c = CatalogCubit.get(ctx);
            final loading = state is AppLoading;
            final canWrite = AppGlobals.currentUser?.isAdmin ?? false;

            return Column(
              children: [
                PageHeader(
                  title: 'الاشتراكات والعروض',
                  icon: Icons.card_membership_rounded,
                  isLoading: loading,
                  onRefresh: c.fetch,
                  tabs: CatalogTab.values
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
                          CatalogTab.memberships => 'اشتراك جديد',
                          CatalogTab.sports => 'رياضة جديدة',
                          CatalogTab.schedules => 'موعد جديد',
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
                      label: 'الاشتراكات',
                      value: '${c.memberships.total}',
                      icon: Icons.card_membership_rounded,
                      color: GlobalColors.accent,
                      sub: 'حصة وباقة',
                    ),
                    StatCard(
                      label: 'الرياضات',
                      value: '${c.sports.total}',
                      icon: Icons.sports_soccer_rounded,
                      color: GlobalColors.purple,
                      sub: 'في الكتالوج',
                    ),
                    StatCard(
                      label: 'المواعيد',
                      value: '${c.schedules.total}',
                      icon: Icons.event_repeat_rounded,
                      color: GlobalColors.blue,
                      sub: 'أسبوعي ومحدد',
                    ),
                    StatCard(
                      label: 'مكتملة العدد',
                      value:
                          '${c.memberships.items.where((m) => m.isFull).length}',
                      icon: Icons.group_off_rounded,
                      color: GlobalColors.red,
                      sub: 'بلغت الحد الأقصى',
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
    );
  }

  Widget _toolbar(BuildContext ctx, CatalogCubit c) {
    if (c.tab == CatalogTab.schedules) {
      return Toolbar(
        children: [
          SizedBox(
            width: 320,
            child: AppDropdown<Membership>(
              value: pickWhere(AppGlobals.memberships, (m) => m.id == c.scheduleMembershipFilter),
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

    return Toolbar(
      children: [
        Expanded(
          flex: 3,
          child: SearchField(
            controller: c.searchCont,
            hint: 'ابحث بالاسم... (اضغط Enter)',
            onChanged: (_) => c.fetch(),
          ),
        ),
        const SizedBox(width: 12),

        if (c.tab == CatalogTab.memberships) ...[
          Expanded(
            flex: 2,
            child: Wrap(
              alignment: WrapAlignment.end,
              runSpacing: 6,
              children: ['', 'active', 'inactive']
                  .map(
                    (s) => AppFilterChip(
                      label: s.isEmpty
                          ? 'الكل'
                          : s == 'active'
                          ? 'نشط'
                          : 'متوقف',
                      isActive: c.statusFilter == (s.isEmpty ? null : s),
                      onTap: () => c.setFilter(status: s),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 180,
            child: AppDropdown<Sport>(
              value: pickWhere(AppGlobals.sports, (s) => s.id == c.sportFilter),
              items: AppGlobals.sports,
              labelOf: (s) => s.name ?? '—',
              label: 'الرياضة',
              icon: Icons.sports_soccer_rounded,
              emptyLabel: 'الكل',
              onChanged: (s) => c.setFilter(sport: s?.id ?? -1),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 180,
            child: AppDropdown<TrainerProfile>(
              value: pickWhere(AppGlobals.trainers, (t) => t.id == c.trainerFilter),
              items: AppGlobals.trainers,
              labelOf: (t) => t.displayName,
              label: 'المدرب',
              icon: Icons.sports_rounded,
              emptyLabel: 'الكل',
              onChanged: (t) => c.setFilter(trainer: t?.id ?? -1),
            ),
          ),
        ],
      ],
    );
  }

  Widget _table(
    BuildContext ctx,
    CatalogCubit c,
    bool loading,
    bool canWrite,
  ) {
    switch (c.tab) {
      case CatalogTab.memberships:
        return AppTable<Membership>(
          isLoading: loading,
          data: c.memberships,
          onPage: c.setPage,
          unitLabel: 'اشتراك',
          emptyTitle: 'لا توجد اشتراكات',
          emptyHint: 'اضغط "اشتراك جديد" للبدء',
          emptyIcon: Icons.card_membership_rounded,
          columns: const [
            AppColumn('الاشتراك', flex: 3),
            AppColumn('الرياضة'),
            AppColumn('المدرب', flex: 2),
            AppColumn('السعر'),
            AppColumn('المدة'),
            AppColumn('السعة'),
            AppColumn('النوع'),
            AppColumn('الحالة'),
            AppColumn('إجراءات', flex: 2),
          ],
          rowBuilder: (rc, m, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, m.name ?? '—', flex: 3, sub: m.description),
              textCell(rc, m.sportName ?? AppGlobals.sportName(m.sportId)),
              textCell(rc, m.trainerName ?? '—', flex: 2),
              textCell(
                rc,
                '${(m.price ?? 0).toStringAsFixed(0)} ${AppGlobals.currency}',
                color: GlobalColors.green,
                weight: FontWeight.w700,
              ),
              textCell(rc, m.durationLabel),
              textCell(
                rc,
                m.capacityLabel,
                color: m.isFull ? GlobalColors.red : null,
                weight: FontWeight.w700,
              ),
              textCell(rc, m.typeAr, size: 11),
              StatusBadge(
                label: m.statusAr,
                color: m.isActive ? GlobalColors.green : GlobalColors.red,
              ),
              actionsCell([
                ActionBtn(
                  icon: Icons.event_repeat_rounded,
                  color: GlobalColors.blue,
                  tooltip: 'مواعيد هذا الاشتراك',
                  onTap: () {
                    c.tab = CatalogTab.schedules;
                    c.setFilter(membership: m.id ?? -1);
                  },
                ),
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل',
                  enabled: canWrite,
                  onTap: () => _openForm(ctx, c, membership: m),
                ),
                ActionBtn(
                  icon: Icons.delete_rounded,
                  color: GlobalColors.red,
                  tooltip: 'حذف',
                  enabled: canWrite,
                  onTap: () => showConfirm(
                    ctx,
                    title: 'حذف الاشتراك',
                    message:
                        'سيؤدي حذف "${m.name}" إلى حذف مواعيده وحصصه وتسجيلات أعضائه.',
                    onConfirm: () => c.deleteMembership(m.id!),
                  ),
                ),
              ], flex: 2),
            ],
          ),
        );

      case CatalogTab.sports:
        return AppTable<Sport>(
          isLoading: loading,
          data: c.sports,
          onPage: c.setPage,
          unitLabel: 'رياضة',
          emptyTitle: 'لا توجد رياضات',
          emptyHint: 'اضغط "رياضة جديدة" للبدء',
          emptyIcon: Icons.sports_soccer_rounded,
          columns: const [
            AppColumn('الرياضة', flex: 3),
            AppColumn('الوصف', flex: 4),
            AppColumn('المدربون'),
            AppColumn('الاشتراكات'),
            AppColumn('إجراءات'),
          ],
          rowBuilder: (rc, s, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, s.name ?? '—', flex: 3),
              textCell(rc, s.description ?? '—', flex: 4, size: 11),
              textCell(
                rc,
                '${s.trainersCount ?? 0}',
                color: GlobalColors.blue,
                weight: FontWeight.w700,
              ),
              textCell(
                rc,
                '${s.membershipsCount ?? 0}',
                color: GlobalColors.accentSoft,
                weight: FontWeight.w700,
              ),
              actionsCell([
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل',
                  enabled: canWrite,
                  onTap: () => _openForm(ctx, c, sport: s),
                ),
                ActionBtn(
                  icon: Icons.delete_rounded,
                  color: GlobalColors.red,
                  tooltip: 'حذف',
                  enabled: canWrite,
                  onTap: () => showConfirm(
                    ctx,
                    title: 'حذف الرياضة',
                    message:
                        'حذف "${s.name}" يحذف معها مدربيها واشتراكاتها. لا يمكن التراجع.',
                    onConfirm: () => c.deleteSport(s.id!),
                  ),
                ),
              ]),
            ],
          ),
        );

      case CatalogTab.schedules:
        return AppTable<MembershipSchedule>(
          isLoading: loading,
          data: c.schedules,
          onPage: c.setPage,
          unitLabel: 'موعد',
          emptyTitle: 'لا توجد مواعيد',
          emptyHint: 'أضف موعداً أسبوعياً أو تاريخاً محدداً',
          emptyIcon: Icons.event_repeat_rounded,
          columns: const [
            AppColumn('الاشتراك', flex: 3),
            AppColumn('النوع'),
            AppColumn('اليوم / التاريخ', flex: 2),
            AppColumn('التوقيت', flex: 2),
            AppColumn('إجراءات'),
          ],
          rowBuilder: (rc, s, i) => AppRow(
            index: i,
            cells: [
              avatarCell(
                rc,
                s.membershipName ?? AppGlobals.membershipName(s.membershipId),
                flex: 3,
              ),
              StatusBadge(
                label: s.isWeekly ? 'أسبوعي' : 'تاريخ محدد',
                color: s.isWeekly ? GlobalColors.accent : GlobalColors.gold,
              ),
              textCell(rc, s.whenAr, flex: 2, weight: FontWeight.w600),
              textCell(rc, s.timeLabel, flex: 2, color: GlobalColors.blue),
              actionsCell([
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل التوقيت',
                  enabled: canWrite,
                  onTap: () => _openForm(ctx, c, schedule: s),
                ),
                ActionBtn(
                  icon: Icons.delete_rounded,
                  color: GlobalColors.red,
                  tooltip: 'حذف',
                  enabled: canWrite,
                  onTap: () => showConfirm(
                    ctx,
                    title: 'حذف الموعد',
                    message: 'سيُحذف هذا الموعد من جدول الاشتراك.',
                    onConfirm: () => c.deleteSchedule(s.id!),
                  ),
                ),
              ]),
            ],
          ),
        );
    }
  }

  void _openForm(
    BuildContext ctx,
    CatalogCubit c, {
    Membership? membership,
    Sport? sport,
    MembershipSchedule? schedule,
  }) {
    c.clearForm();

    if (membership != null) {
      c.nameCont.text = membership.name ?? '';
      c.descCont.text = membership.description ?? '';
      c.priceCont.text = membership.price?.toStringAsFixed(0) ?? '';
      c.durationCont.text = membership.durationDays?.toString() ?? '';
      c.maxAttendeesCont.text = membership.maxAttendees?.toString() ?? '';
      c.formSportId = membership.sportId;
      c.formTrainerId = membership.trainerId;
      c.formType = membership.type ?? 'scheduled';
      c.formStatus = membership.status ?? 'active';
    }
    if (sport != null) {
      c.nameCont.text = sport.name ?? '';
      c.descCont.text = sport.description ?? '';
      c.imageCont.text = sport.image ?? '';
    }
    if (schedule != null) {
      c.schedMembershipId = schedule.membershipId;
      c.schedType = schedule.scheduleType ?? 'weekly';
      c.schedDay = schedule.dayOfWeek ?? 'saturday';
      c.schedDate = schedule.specificDate;
      c.schedStart = _parse(schedule.startTime) ?? c.schedStart;
      c.schedEnd = _parse(schedule.endTime) ?? c.schedEnd;
    } else {
      c.schedMembershipId = c.scheduleMembershipFilter;
    }

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: _CatalogForm(
          membership: membership,
          sport: sport,
          schedule: schedule,
        ),
      ),
    );
  }

  TimeOfDay? _parse(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }
}

// ─────────────────────────────────────────────
//  CATALOG FORM — نموذج العروض
// ─────────────────────────────────────────────
class _CatalogForm extends StatefulWidget {
  const _CatalogForm({this.membership, this.sport, this.schedule});

  final Membership? membership;
  final Sport? sport;
  final MembershipSchedule? schedule;

  @override
  State<_CatalogForm> createState() => _CatalogFormState();
}

class _CatalogFormState extends State<_CatalogForm> {
  @override
  Widget build(BuildContext context) {
    final c = CatalogCubit.get(context);

    return switch (c.tab) {
      CatalogTab.sports => _sportForm(c),
      CatalogTab.schedules => _scheduleForm(c),
      CatalogTab.memberships => _membershipForm(c),
    };
  }

  // ── Sport ───────────────────────────────────
  Widget _sportForm(CatalogCubit c) {
    final isEdit = widget.sport != null;
    return AppDialog<CatalogCubit>(
      title: isEdit ? 'تعديل الرياضة' : 'رياضة جديدة',
      icon: Icons.sports_soccer_rounded,
      saveLabel: isEdit ? 'حفظ' : 'إضافة',
      width: 460,
      onSave: () => c.saveSport(id: widget.sport?.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppField(
            controller: c.nameCont,
            label: 'اسم الرياضة *',
            icon: Icons.sports_soccer_rounded,
            hint: 'الاسم فريد ولا يتكرر',
          ),
          gap,
          AppField(
            controller: c.descCont,
            label: 'الوصف',
            icon: Icons.description_rounded,
            maxLines: 3,
          ),
          gap,
          AppField(
            controller: c.imageCont,
            label: 'رابط الصورة',
            icon: Icons.link_rounded,
            hint: 'https://...',
          ),
        ],
      ),
    );
  }

  // ── Membership ──────────────────────────────
  Widget _membershipForm(CatalogCubit c) {
    final isEdit = widget.membership != null;
    return AppDialog<CatalogCubit>(
      title: isEdit ? 'تعديل الاشتراك' : 'اشتراك جديد',
      icon: Icons.card_membership_rounded,
      saveLabel: isEdit ? 'حفظ' : 'إضافة',
      width: 600,
      onSave: () => c.saveMembership(id: widget.membership?.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppField(
            controller: c.nameCont,
            label: 'اسم الاشتراك *',
            icon: Icons.card_membership_rounded,
          ),
          gap,
          AppField(
            controller: c.descCont,
            label: 'الوصف',
            icon: Icons.description_rounded,
            maxLines: 2,
          ),
          gap,
          dialogRow([
            AppDropdown<Sport>(
              value: pickWhere(AppGlobals.sports, (s) => s.id == c.formSportId),
              items: AppGlobals.sports,
              labelOf: (s) => s.name ?? '—',
              label: 'الرياضة *',
              icon: Icons.sports_soccer_rounded,
              onChanged: (s) => setState(() => c.formSportId = s?.id),
            ),
            AppDropdown<TrainerProfile>(
              value: pickWhere(AppGlobals.trainers, (t) => t.id == c.formTrainerId),
              items: AppGlobals.trainers,
              labelOf: (t) => t.displayName,
              label: 'المدرب *',
              icon: Icons.sports_rounded,
              onChanged: (t) => setState(() => c.formTrainerId = t?.id),
            ),
          ]),
          gap,
          dialogRow([
            AppField(
              controller: c.priceCont,
              label: 'السعر *',
              icon: Icons.payments_rounded,
              isNumber: true,
            ),
            AppField(
              controller: c.durationCont,
              label: 'المدة بالأيام',
              icon: Icons.timelapse_rounded,
              isNumber: true,
              hint: 'اتركه فارغاً لمدة مفتوحة',
            ),
            AppField(
              controller: c.maxAttendeesCont,
              label: 'الحد الأقصى',
              icon: Icons.groups_rounded,
              isNumber: true,
              hint: 'فارغ = بلا حد',
            ),
          ]),
          gap,
          dialogRow([
            AppDropdown<String>(
              value: c.formType,
              items: const ['scheduled', 'fixed'],
              labelOf: (t) => t == 'fixed' ? 'مرة واحدة' : 'متكرر بمواعيد',
              label: 'النوع',
              icon: Icons.repeat_rounded,
              onChanged: (t) => setState(() => c.formType = t ?? 'scheduled'),
            ),
            AppDropdown<String>(
              value: c.formStatus,
              items: const ['active', 'inactive'],
              labelOf: (s) => s == 'active' ? 'نشط' : 'متوقف',
              label: 'الحالة',
              icon: Icons.toggle_on_rounded,
              onChanged: (s) => setState(() => c.formStatus = s ?? 'active'),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Schedule ────────────────────────────────
  Widget _scheduleForm(CatalogCubit c) {
    final isEdit = widget.schedule != null;
    return AppDialog<CatalogCubit>(
      title: isEdit ? 'تعديل الموعد' : 'موعد جديد',
      icon: Icons.event_repeat_rounded,
      saveLabel: isEdit ? 'حفظ' : 'إضافة',
      width: 520,
      onSave: () => c.saveSchedule(id: widget.schedule?.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isEdit) ...[
            AppDropdown<Membership>(
              value: pickWhere(AppGlobals.memberships, (m) => m.id == c.schedMembershipId),
              items: AppGlobals.memberships,
              labelOf: (m) => m.name ?? '—',
              label: 'الاشتراك *',
              icon: Icons.card_membership_rounded,
              onChanged: (m) => setState(() => c.schedMembershipId = m?.id),
            ),
            gap,
            AppDropdown<String>(
              value: c.schedType,
              items: const ['weekly', 'date'],
              labelOf: (t) => t == 'weekly' ? 'أسبوعي متكرر' : 'تاريخ محدد',
              label: 'نوع الموعد',
              icon: Icons.repeat_rounded,
              onChanged: (t) => setState(() => c.schedType = t ?? 'weekly'),
            ),
            gap,
            if (c.schedType == 'weekly')
              AppDropdown<String>(
                value: c.schedDay,
                items: MembershipSchedule.weekDays,
                labelOf: MembershipSchedule.dayLabel,
                label: 'اليوم *',
                icon: Icons.today_rounded,
                onChanged: (d) => setState(() => c.schedDay = d ?? 'saturday'),
              )
            else
              DateField(
                value: c.schedDate,
                label: 'التاريخ * (اليوم أو بعده)',
                firstDate: DateTime.now(),
                onPicked: (d) => setState(() => c.schedDate = d),
              ),
            gap,
          ],
          dialogRow([
            TimeField(
              value: c.schedStart,
              label: 'من',
              onPicked: (t) => setState(() => c.schedStart = t),
            ),
            TimeField(
              value: c.schedEnd,
              label: 'إلى',
              onPicked: (t) => setState(() => c.schedEnd = t),
            ),
          ]),
        ],
      ),
    );
  }
}
