import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/sessions_bloc/sessions_cubit.dart';
import '../components/general/app_dialog.dart';
import '../components/general/app_field.dart';
import '../components/general/app_table.dart';
import '../components/general/empty_widget.dart';
import '../components/general/page_header.dart';
import '../components/general/snackbar.dart';
import '../models/catalog_model.dart';
import '../models/paginated_model.dart';
import '../models/sessions_model.dart';
import '../models/users_model.dart';
import '../src/app_colors.dart';
import '../src/app_globals.dart';
import '../src/app_permissions.dart';
import '../src/app_presets.dart';

// ─────────────────────────────────────────────
//  SESSIONS — الحصص
//  A session is scheduled, attended, then rated.
//  The board is the default view because that's
//  what the desk looks at all day.
// ─────────────────────────────────────────────
class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionsCubit()..fetch(),
      child: const _SessionsView(),
    );
  }
}

class _SessionsView extends StatelessWidget {
  const _SessionsView();

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
          body: BlocConsumer<SessionsCubit, AppStates>(
            listener: (ctx, state) {
              if (state is AppSuccess) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: true);
              }
              if (state is AppFailure) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: false);
              }
            },
            builder: (ctx, state) {
              final c = SessionsCubit.get(ctx);
              final loading = state is AppLoading;
              final me = AppGlobals.currentUser;

              return Column(
                children: [
                  PageHeader(
                    title: 'الحصص والحضور',
                    icon: Icons.event_note_rounded,
                    isLoading: loading,
                    onRefresh: c.fetch,
                    tabs: SessionsTab.values
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
                      if (c.tab == SessionsTab.sessions ||
                          c.tab == SessionsTab.board) ...[
                        if (Permissions.canWrite)
                          HeaderButton(
                            icon: Icons.auto_awesome_rounded,
                            label: 'توليد الحصص',
                            color: GlobalColors.purple,
                            onTap: () => _generateDialog(ctx, c),
                          ),
                        if (Permissions.canWrite)
                          HeaderButton(
                            icon: Icons.add_rounded,
                            label: 'حصة يدوية',
                            color: GlobalColors.green,
                            filled: true,
                            onTap: () => _sessionForm(ctx, c),
                          ),
                      ],
                      if (c.tab == SessionsTab.attendance)
                        HeaderButton(
                          icon: Icons.how_to_reg_rounded,
                          label: 'تسجيل حضور',
                          color: GlobalColors.green,
                          filled: true,
                          onTap: () => _attendanceForm(ctx, c),
                        ),
                    ],
                  ),

                  _toolbar(ctx, c),
                  Expanded(child: _body(ctx, c, loading, me)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Toolbar ─────────────────────────────────
  Widget _toolbar(BuildContext ctx, SessionsCubit c) {
    if (c.tab == SessionsTab.board) {
      return Toolbar(
        children: [
          SizedBox(
            width: 220,
            child: DateField(
              value: c.boardFrom,
              label: 'من تاريخ',
              onPicked: (d) => c.setBoardRange(d, c.boardTo),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: DateField(
              value: c.boardTo,
              label: 'إلى تاريخ',
              onPicked: (d) => c.setBoardRange(c.boardFrom, d),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'اسحب البطاقة بين الأعمدة لتغيير حالة الحصة.',
              style: TextStyle(
                color: GlobalColors.textSecondary(ctx),
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    return Toolbar(
      children: [
        if (c.tab != SessionsTab.ratings)
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
        if (c.tab != SessionsTab.sessions) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
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
        ],
        const SizedBox(width: 12),

        if (c.tab == SessionsTab.sessions || c.tab == SessionsTab.attendance)
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              runSpacing: 6,
              children:
                  [
                        '',
                        ...(c.tab == SessionsTab.sessions
                            ? ClubSession.statuses
                            : Attendance.statuses),
                      ]
                      .map(
                        (s) => AppFilterChip(
                          label: s.isEmpty
                              ? 'الكل'
                              : c.tab == SessionsTab.sessions
                              ? ClubSession.statusLabel(s)
                              : Attendance.statusLabel(s),
                          isActive: c.statusFilter == (s.isEmpty ? null : s),
                          onTap: () => c.setFilter(status: s),
                        ),
                      )
                      .toList(),
            ),
          ),

        if (c.tab == SessionsTab.sessions ||
            c.tab == SessionsTab.attendance) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 190,
            child: DateField(
              value: c.dateFilter,
              label: 'التاريخ',
              onPicked: (d) => c.setFilter(date: d),
            ),
          ),
          if (c.dateFilter != null)
            IconButton(
              tooltip: 'إلغاء فلتر التاريخ',
              onPressed: () => c.setFilter(clearDate: true),
              icon: Icon(
                Icons.event_busy_rounded,
                size: 18,
                color: GlobalColors.red,
              ),
            ),
        ],
      ],
    );
  }

  // ── Body ────────────────────────────────────
  Widget _body(BuildContext ctx, SessionsCubit c, bool loading, User? me) {
    switch (c.tab) {
      case SessionsTab.board:
        return _board(ctx, c, loading);

      case SessionsTab.sessions:
        return AppTable<ClubSession>(
          isLoading: loading,
          data: c.sessions,
          onPage: c.setPage,
          unitLabel: 'حصة',
          emptyTitle: 'لا توجد حصص',
          emptyHint: 'ولّد الحصص من مواعيد الاشتراك',
          emptyIcon: Icons.event_busy_rounded,
          columns: const [
            AppColumn('الاشتراك', flex: 3),
            AppColumn('المدرب', flex: 2),
            AppColumn('التاريخ', flex: 2),
            AppColumn('التوقيت', flex: 2),
            AppColumn('الحالة'),
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
              textCell(rc, s.trainerName ?? '—', flex: 2),
              textCell(rc, AppPresets.pretty(s.sessionDate), flex: 2),
              textCell(rc, s.timeLabel, flex: 2, color: GlobalColors.blue),
              StatusBadge(label: s.statusAr, color: _sessionColor(s.status)),
              actionsCell([
                ActionBtn(
                  icon: Icons.edit_calendar_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'إعادة جدولة',
                  enabled: Permissions.canWrite,
                  onTap: () => _rescheduleForm(ctx, c, s),
                ),
              ]),
            ],
          ),
        );

      case SessionsTab.attendance:
        return AppTable<Attendance>(
          isLoading: loading,
          data: c.attendances,
          onPage: c.setPage,
          unitLabel: 'سجل',
          emptyTitle: 'لا توجد سجلات حضور',
          emptyHint: 'اضغط "تسجيل حضور" للبدء',
          emptyIcon: Icons.how_to_reg_rounded,
          columns: const [
            AppColumn('العضو', flex: 3),
            AppColumn('الاشتراك', flex: 2),
            AppColumn('التاريخ', flex: 2),
            AppColumn('الحالة'),
            AppColumn('ملاحظة', flex: 2),
            AppColumn('إجراءات'),
          ],
          rowBuilder: (rc, a, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, a.memberName, flex: 3),
              textCell(
                rc,
                a.membershipName ?? AppGlobals.membershipName(a.membershipId),
                flex: 2,
              ),
              textCell(rc, AppPresets.pretty(a.date), flex: 2),
              StatusBadge(label: a.statusAr, color: _attColor(a.status)),
              textCell(rc, a.note ?? '—', flex: 2, size: 11),
              actionsCell([
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تصحيح',
                  onTap: () => _attendanceForm(ctx, c, record: a),
                ),
                ActionBtn(
                  icon: Icons.delete_rounded,
                  color: GlobalColors.red,
                  tooltip: 'حذف',
                  enabled: Permissions.canWrite,
                  onTap: () => showConfirm(
                    ctx,
                    title: 'حذف السجل',
                    message: 'سيُحذف سجل حضور ${a.memberName}.',
                    onConfirm: () => c.deleteAttendance(a.id!),
                  ),
                ),
              ]),
            ],
          ),
        );

      case SessionsTab.ratings:
        return AppTable<SessionRating>(
          isLoading: loading,
          data: c.ratings,
          onPage: c.setPage,
          unitLabel: 'تقييم',
          emptyTitle: 'لا توجد تقييمات',
          emptyHint: 'يقيّم الأعضاء الحصص المكتملة فقط',
          emptyIcon: Icons.star_border_rounded,
          columns: const [
            AppColumn('العضو', flex: 3),
            AppColumn('المدرب', flex: 2),
            AppColumn('التقييم', flex: 2),
            AppColumn('الملاحظة', flex: 3),
            AppColumn('إجراءات'),
          ],
          rowBuilder: (rc, r, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, r.memberName, flex: 3),
              textCell(rc, r.trainerName, flex: 2),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Scores are decimal — 4.5 draws four full and one half.
                    ...List.generate(5, (k) {
                      final filled = r.stars - k;
                      return Icon(
                        filled >= 1
                            ? Icons.star_rounded
                            : filled >= 0.5
                            ? Icons.star_half_rounded
                            : Icons.star_border_rounded,
                        size: 15,
                        color: GlobalColors.gold,
                      );
                    }),
                    const SizedBox(width: 6),
                    Text(
                      r.scoreLabel,
                      style: TextStyle(
                        color: GlobalColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              textCell(rc, r.note ?? '—', flex: 3, size: 11),
              actionsCell([
                ActionBtn(
                  icon: Icons.shield_rounded,
                  color: GlobalColors.purple,
                  // Admins moderate feedback rather than deleting it.
                  tooltip: 'إشراف على الملاحظة',
                  enabled: Permissions.canWrite,
                  onTap: () => _moderateForm(ctx, c, r),
                ),
              ]),
            ],
          ),
        );
    }
  }

  // ── Kanban board ────────────────────────────
  Widget _board(BuildContext ctx, SessionsCubit c, bool loading) {
    if (loading && c.board.values.every((l) => l.isEmpty)) {
      return Center(
        child: CircularProgressIndicator(color: GlobalColors.accent),
      );
    }

    final total = c.board.values.fold(0, (s, l) => s + l.length);
    if (total == 0) {
      return const EmptyState(
        title: 'لا توجد حصص في هذه الفترة',
        hint: 'وسّع نطاق التاريخ أو ولّد الحصص من المواعيد',
        icon: Icons.view_kanban_rounded,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ClubSession.statuses.map((status) {
          final items = c.board[status] ?? [];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: DragTarget<ClubSession>(
                onWillAcceptWithDetails: (d) => d.data.status != status,
                onAcceptWithDetails: (d) => c.moveSession(d.data, status),
                builder: (dctx, candidate, __) {
                  final hot = candidate.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      color: hot
                          ? _sessionColor(status).withValues(alpha: 0.08)
                          : GlobalColors.surface(ctx),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hot
                            ? _sessionColor(status)
                            : GlobalColors.border(ctx),
                        width: hot ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Column header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: GlobalColors.card(ctx),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _sessionColor(status),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                ClubSession.statusLabel(status),
                                style: TextStyle(
                                  color: GlobalColors.textPrimary(ctx),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _sessionColor(
                                    status,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${items.length}',
                                  style: TextStyle(
                                    color: _sessionColor(status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: items.isEmpty
                              ? Center(
                                  child: Text(
                                    'أفلت حصة هنا',
                                    style: TextStyle(
                                      color: GlobalColors.textSecondary(
                                        ctx,
                                      ).withValues(alpha: 0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: items.length,
                                  itemBuilder: (_, i) => _BoardCard(
                                    session: items[i],
                                    color: _sessionColor(status),
                                    onTap: () =>
                                        _rescheduleForm(ctx, c, items[i]),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _sessionColor(String? s) => switch (s) {
    'ongoing' => GlobalColors.gold,
    'completed' => GlobalColors.green,
    'cancelled' => GlobalColors.red,
    _ => GlobalColors.accent,
  };

  Color _attColor(String? s) => switch (s) {
    'present' => GlobalColors.green,
    'late' => GlobalColors.gold,
    // Excused sits between late and absent: missed, but not a no-show.
    'excused' => GlobalColors.blue,
    'absent' => GlobalColors.red,
    _ => GlobalColors.accent,
  };

  // ── Dialogs ─────────────────────────────────
  void _generateDialog(BuildContext ctx, SessionsCubit c) {
    int? membershipId = c.membershipFilter;
    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) => AppDialog<SessionsCubit>(
            title: 'توليد الحصص من المواعيد',
            icon: Icons.auto_awesome_rounded,
            saveLabel: 'توليد',
            width: 480,
            onSave: () {
              if (membershipId == null) return;
              c.generateSessions(membershipId!);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GlobalColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: GlobalColors.accentSoft,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'يوسّع المواعيد إلى حصص فعلية. يمكن تكرار العملية بأمان لتغطية فترة أطول.',
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
                gap,
                AppDropdown<Membership>(
                  value: pickWhere(
                    AppGlobals.memberships,
                    (m) => m.id == membershipId,
                  ),
                  items: AppGlobals.memberships,
                  labelOf: (m) => m.name ?? '—',
                  label: 'الاشتراك *',
                  icon: Icons.card_membership_rounded,
                  onChanged: (m) => setLocal(() => membershipId = m?.id),
                ),
                gap,
                dialogRow([
                  DateField(
                    value: c.genFrom,
                    label: 'من',
                    onPicked: (d) => setLocal(() => c.genFrom = d),
                  ),
                  DateField(
                    value: c.genTo,
                    label: 'إلى',
                    onPicked: (d) => setLocal(() => c.genTo = d),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _sessionForm(BuildContext ctx, SessionsCubit c) {
    c.clearForm();
    c.formMembershipId = c.membershipFilter;
    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) => AppDialog<SessionsCubit>(
            title: 'حصة يدوية',
            icon: Icons.add_rounded,
            saveLabel: 'إضافة',
            width: 520,
            onSave: c.createSession,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDropdown<Membership>(
                  value: pickWhere(
                    AppGlobals.memberships,
                    (m) => m.id == c.formMembershipId,
                  ),
                  items: AppGlobals.memberships,
                  labelOf: (m) => m.name ?? '—',
                  label: 'الاشتراك *',
                  icon: Icons.card_membership_rounded,
                  onChanged: (m) => setLocal(() => c.formMembershipId = m?.id),
                ),
                gap,
                // The API hangs a manual session off an existing schedule.
                AppDropdown<MembershipSchedule>(
                  value: pickWhere(
                    _schedulesFor(c.formMembershipId),
                    (s) => s.id == c.formScheduleId,
                  ),
                  items: _schedulesFor(c.formMembershipId),
                  labelOf: (s) => '${s.whenAr} · ${s.timeLabel}',
                  label: 'الموعد المرتبط',
                  icon: Icons.event_repeat_rounded,
                  emptyLabel: 'اختر موعداً من مواعيد الاشتراك',
                  onChanged: (s) => setLocal(() => c.formScheduleId = s?.id),
                ),
                gap,
                DateField(
                  value: c.formDate,
                  label: 'تاريخ الحصة *',
                  onPicked: (d) => setLocal(() => c.formDate = d),
                ),
                gap,
                dialogRow([
                  TimeField(
                    value: c.formStart,
                    label: 'من',
                    onPicked: (t) => setLocal(() => c.formStart = t),
                  ),
                  TimeField(
                    value: c.formEnd,
                    label: 'إلى',
                    onPicked: (t) => setLocal(() => c.formEnd = t),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<MembershipSchedule> _schedulesFor(int? membershipId) {
    if (membershipId == null) return [];
    final m = pickWhere(AppGlobals.memberships, (e) => e.id == membershipId);
    return m?.schedules ?? [];
  }

  void _rescheduleForm(BuildContext ctx, SessionsCubit c, ClubSession s) {
    c.clearForm();
    c.formDate = s.sessionDate ?? AppPresets.today;
    c.formStatus = s.status ?? 'scheduled';
    c.formStart = _parse(s.startTime) ?? c.formStart;
    c.formEnd = _parse(s.endTime) ?? c.formEnd;

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) => AppDialog<SessionsCubit>(
            title: 'إعادة جدولة الحصة',
            icon: Icons.edit_calendar_rounded,
            saveLabel: 'حفظ',
            width: 500,
            onSave: () => c.rescheduleSession(
              s.id!,
              date: c.formDate,
              start: c.formStart,
              end: c.formEnd,
              status: c.formStatus,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.membershipName ?? '—',
                  style: TextStyle(
                    color: GlobalColors.textPrimary(sctx),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                gap,
                DateField(
                  value: c.formDate,
                  label: 'التاريخ',
                  onPicked: (d) => setLocal(() => c.formDate = d),
                ),
                gap,
                dialogRow([
                  TimeField(
                    value: c.formStart,
                    label: 'من',
                    onPicked: (t) => setLocal(() => c.formStart = t),
                  ),
                  TimeField(
                    value: c.formEnd,
                    label: 'إلى',
                    onPicked: (t) => setLocal(() => c.formEnd = t),
                  ),
                ]),
                gap,
                AppDropdown<String>(
                  value: c.formStatus,
                  items: ClubSession.statuses,
                  labelOf: ClubSession.statusLabel,
                  label: 'الحالة',
                  icon: Icons.flag_rounded,
                  onChanged: (v) =>
                      setLocal(() => c.formStatus = v ?? 'scheduled'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _attendanceForm(
    BuildContext ctx,
    SessionsCubit c, {
    Attendance? record,
  }) {
    c.clearForm();
    if (record != null) {
      c.formStatus = record.status ?? 'present';
      c.noteCont.text = record.note ?? '';
    } else {
      c.formStatus = 'present';
      c.formMembershipId = c.membershipFilter;
    }

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) => AppDialog<SessionsCubit>(
            title: record == null ? 'تسجيل حضور' : 'تصحيح الحضور',
            icon: Icons.how_to_reg_rounded,
            saveLabel: record == null ? 'تسجيل' : 'حفظ',
            width: 500,
            onSave: () => record == null
                ? c.recordAttendance()
                : c.updateAttendance(record.id!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (record == null) ...[
                  AppDropdown<User>(
                    value: pickWhere(
                      AppGlobals.members,
                      (u) => u.userId == c.formUserId,
                    ),
                    items: AppGlobals.members,
                    labelOf: (u) => u.name ?? '—',
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
                    items: AppGlobals.memberships,
                    labelOf: (m) => m.name ?? '—',
                    label: 'الاشتراك *',
                    icon: Icons.card_membership_rounded,
                    onChanged: (m) =>
                        setLocal(() => c.formMembershipId = m?.id),
                  ),
                  gap,
                  DateField(
                    value: c.formDate,
                    label: 'التاريخ',
                    onPicked: (d) => setLocal(() => c.formDate = d),
                  ),
                  gap,
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      '${record.memberName} · ${AppPresets.pretty(record.date)}',
                      style: TextStyle(
                        color: GlobalColors.textPrimary(sctx),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                AppDropdown<String>(
                  value: c.formStatus,
                  items: Attendance.statuses,
                  labelOf: Attendance.statusLabel,
                  label: 'الحالة',
                  icon: Icons.flag_rounded,
                  onChanged: (v) =>
                      setLocal(() => c.formStatus = v ?? 'present'),
                ),
                gap,
                AppField(
                  controller: c.noteCont,
                  label: 'ملاحظة',
                  icon: Icons.note_rounded,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _moderateForm(BuildContext ctx, SessionsCubit c, SessionRating r) {
    c.clearForm();
    c.noteCont.text = r.note ?? '';
    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: AppDialog<SessionsCubit>(
          title: 'إشراف على التقييم',
          icon: Icons.shield_rounded,
          saveLabel: 'حفظ',
          width: 480,
          onSave: () => c.moderateRating(r.id!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r.memberName} ← ${r.trainerName} · ${r.scoreLabel} من 5',
                style: TextStyle(
                  color: GlobalColors.textPrimary(ctx),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              // There is only one text field on a rating. Editing it
              // replaces what the member wrote — the original is not
              // kept anywhere, so say so plainly before they save.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlobalColors.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'التعديل هنا يستبدل نص العضو نهائياً — لا تُحفظ نسخة من الأصل. '
                  'انسخ ما تحتاجه قبل الحفظ.',
                  style: TextStyle(
                    color: GlobalColors.textSecondary(ctx),
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ),
              gap,
              AppField(
                controller: c.noteCont,
                label: 'نص الملاحظة',
                icon: Icons.rate_review_rounded,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  TimeOfDay? _parse(String? hhmm) {
    if (hhmm == null) return null;
    final p = hhmm.split(':');
    if (p.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(p[0]) ?? 0,
      minute: int.tryParse(p[1]) ?? 0,
    );
  }
}

// ─────────────────────────────────────────────
//  BOARD CARD — بطاقة الحصة
// ─────────────────────────────────────────────
class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.session,
    required this.color,
    required this.onTap,
  });

  final ClubSession session;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GlobalColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlobalColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.membershipName ?? 'حصة',
            style: TextStyle(
              color: GlobalColors.textPrimary(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 12,
                color: GlobalColors.textSecondary(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  session.timeLabel,
                  style: TextStyle(
                    color: GlobalColors.textSecondary(context),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 11,
                color: GlobalColors.textSecondary(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  AppPresets.pretty(session.sessionDate),
                  style: TextStyle(
                    color: GlobalColors.textSecondary(context),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (session.trainerName != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                session.trainerName!,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        onTap: onTap,
        child: Draggable<ClubSession>(
          data: session,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.9,
              child: SizedBox(width: 220, child: card),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: card),
          child: card,
        ),
      ),
    );
  }
}
