import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/people_bloc/people_cubit.dart';
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
//  PEOPLE — الأشخاص
//  Accounts, members, coaches and staff. Four
//  API folders, one page: the same person seen
//  from four angles.
// ─────────────────────────────────────────────
class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PeopleCubit()..fetch(),
      child: const _PeopleView(),
    );
  }
}

class _PeopleView extends StatelessWidget {
  const _PeopleView();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: GlobalColors.bg(context),
        body: BlocConsumer<PeopleCubit, AppStates>(
          listener: (ctx, state) {
            if (state is AppSuccess) {
              MySnackBar.show(ctx, text: state.msg, isSuccess: true);
            }
            if (state is AppFailure) {
              MySnackBar.show(ctx, text: state.msg, isSuccess: false);
            }
          },
          builder: (ctx, state) {
            final cubit = PeopleCubit.get(ctx);
            final loading = state is AppLoading;
            final me = AppGlobals.currentUser;

            return Column(
              children: [
                PageHeader(
                  title: 'الأشخاص',
                  icon: Icons.people_alt_rounded,
                  isLoading: loading,
                  onRefresh: cubit.fetch,
                  tabs: PeopleTab.values
                      .map(
                        (t) => TabPill(
                          label: t.label,
                          icon: t.icon,
                          isActive: cubit.tab == t,
                          onTap: () => cubit.switchTab(t),
                        ),
                      )
                      .toList(),
                  actions: [
                    if (_canAdd(cubit.tab, me))
                      HeaderButton(
                        icon: Icons.person_add_rounded,
                        label: _addLabel(cubit.tab),
                        color: GlobalColors.green,
                        filled: true,
                        onTap: () => _openForm(ctx, cubit),
                      ),
                  ],
                ),

                _stats(cubit),
                _toolbar(ctx, cubit),

                Expanded(child: _table(ctx, cubit, loading, me)),
              ],
            );
          },
        ),
      ),
    );
  }

  // Staff roster is owner-only; the rest follow the admin policy.
  bool _canAdd(PeopleTab tab, User? me) {
    if (me == null) return false;
    return switch (tab) {
      PeopleTab.accounts => me.isAdmin,
      PeopleTab.trainers => me.isAdmin,
      PeopleTab.staff => me.isOwner,
      PeopleTab.members => false,
    };
  }

  String _addLabel(PeopleTab tab) => switch (tab) {
    PeopleTab.accounts => 'حساب جديد',
    PeopleTab.trainers => 'مدرب جديد',
    PeopleTab.staff => 'تعيين موظف',
    PeopleTab.members => '',
  };

  // ── Stats ───────────────────────────────────
  Widget _stats(PeopleCubit c) {
    return StatRow(
      cards: [
        StatCard(
          label: 'الحسابات',
          value: '${c.users.total}',
          icon: Icons.manage_accounts_rounded,
          color: GlobalColors.accent,
          sub: 'إجمالي',
        ),
        StatCard(
          label: 'الأعضاء',
          value: '${c.players.total}',
          icon: Icons.people_alt_rounded,
          color: GlobalColors.green,
          sub: 'مسجّل',
        ),
        StatCard(
          label: 'المدربون',
          value: '${c.trainers.total}',
          icon: Icons.sports_rounded,
          color: GlobalColors.blue,
          sub: 'طاقم التدريب',
        ),
        StatCard(
          label: 'الموظفون',
          value: '${c.employees.total}',
          icon: Icons.badge_rounded,
          color: GlobalColors.gold,
          sub: 'فريق العمل',
        ),
      ],
    );
  }

  // ── Toolbar ─────────────────────────────────
  Widget _toolbar(BuildContext ctx, PeopleCubit c) {
    return Toolbar(
      children: [
        Expanded(
          flex: 3,
          child: SearchField(
            controller: c.searchCont,
            hint: 'ابحث بالاسم أو البريد... (اضغط Enter)',
            onChanged: (_) => c.fetch(),
          ),
        ),
        const SizedBox(width: 12),

        // Chips wrap to a second line rather than overflowing the row.
        Expanded(
          flex: 4,
          child: Wrap(
            alignment: WrapAlignment.end,
            runSpacing: 6,
            children: [
              if (c.tab == PeopleTab.accounts)
                ...['', 'player', 'trainer', 'employee', 'admin'].map(
                  (r) => AppFilterChip(
                    label: r.isEmpty ? 'الكل' : User(role: r).roleAr,
                    isActive: c.roleFilter == (r.isEmpty ? null : r),
                    onTap: () => c.setFilter(role: r),
                  ),
                ),
              if (c.tab == PeopleTab.trainers || c.tab == PeopleTab.staff)
                ...['', 'active', 'inactive'].map(
                  (s) => AppFilterChip(
                    label: s.isEmpty
                        ? 'الكل'
                        : s == 'active'
                        ? 'نشط'
                        : 'موقوف',
                    isActive: c.statusFilter == (s.isEmpty ? null : s),
                    onTap: () => c.setFilter(status: s),
                  ),
                ),
            ],
          ),
        ),

        if (c.tab == PeopleTab.trainers) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 200,
            child: AppDropdown<Sport>(
              value: pickWhere(AppGlobals.sports, (s) => s.id == c.sportFilter),
              items: AppGlobals.sports,
              labelOf: (s) => s.name ?? '—',
              label: 'الرياضة',
              icon: Icons.sports_soccer_rounded,
              emptyLabel: 'كل الرياضات',
              onChanged: (s) => c.setFilter(sport: s?.id ?? -1),
            ),
          ),
        ],
      ],
    );
  }

  // ── Tables ──────────────────────────────────
  Widget _table(BuildContext ctx, PeopleCubit c, bool loading, User? me) {
    switch (c.tab) {
      case PeopleTab.accounts:
        return AppTable<User>(
          isLoading: loading,
          data: c.users,
          onPage: c.setPage,
          unitLabel: 'حساب',
          emptyTitle: 'لا توجد حسابات',
          emptyHint: 'اضغط "حساب جديد" للبدء',
          emptyIcon: Icons.person_off_rounded,
          columns: const [
            AppColumn('الاسم', flex: 3),
            AppColumn('البريد', flex: 3),
            AppColumn('الهاتف'),
            AppColumn('الدور'),
            AppColumn('إجراءات'),
          ],
          rowBuilder: (rc, u, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, u.name ?? '—', flex: 3, sub: u.presenceAr),
              textCell(rc, u.email ?? '—', flex: 3, size: 11),
              textCell(rc, u.phone ?? '—'),
              StatusBadge(label: u.roleAr, color: _roleColor(u.role)),
              actionsCell([
                ActionBtn(
                  icon: Icons.image_rounded,
                  color: GlobalColors.purple,
                  tooltip: 'الصورة الشخصية',
                  onTap: () => _avatarDialog(ctx, c, u),
                ),
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل',
                  enabled: me?.isAdmin ?? false,
                  onTap: () => _openForm(ctx, c, user: u),
                ),
                ActionBtn(
                  icon: Icons.delete_rounded,
                  color: GlobalColors.red,
                  tooltip: me?.isOwner ?? false
                      ? 'حذف'
                      : 'الحذف متاح للمالك فقط',
                  enabled: me?.isOwner ?? false,
                  onTap: () => showConfirm(
                    ctx,
                    title: 'حذف الحساب',
                    message:
                        'سيتم حذف حساب ${u.name} وإلغاء جلساته المفتوحة. لا يمكن التراجع.',
                    onConfirm: () => c.deleteUser(u.userId!),
                  ),
                ),
              ]),
            ],
          ),
        );

      case PeopleTab.members:
        return AppTable<PlayerProfile>(
          isLoading: loading,
          data: c.players,
          onPage: c.setPage,
          unitLabel: 'عضو',
          emptyTitle: 'لا يوجد أعضاء',
          emptyHint: 'يُضاف الأعضاء من تبويب الحسابات',
          emptyIcon: Icons.person_off_rounded,
          columns: const [
            AppColumn('العضو', flex: 3),
            AppColumn('الطول'),
            AppColumn('الوزن'),
            AppColumn('كتلة الجسم'),
            AppColumn('اتصال الطوارئ', flex: 2),
            AppColumn('إجراءات'),
          ],
          rowBuilder: (rc, p, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, p.displayName, flex: 3, sub: p.email),
              textCell(rc, p.height == null ? '—' : '${p.height} سم'),
              textCell(rc, p.weight == null ? '—' : '${p.weight} كجم'),
              textCell(
                rc,
                p.bmi == null ? '—' : p.bmi!.toStringAsFixed(1),
                color: GlobalColors.accentSoft,
                weight: FontWeight.w700,
              ),
              textCell(rc, p.emergencyContact ?? '—', flex: 2, size: 11),
              actionsCell([
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل البيانات البدنية',
                  enabled: me?.isAdmin ?? false,
                  onTap: () => _openForm(ctx, c, player: p),
                ),
              ]),
            ],
          ),
        );

      case PeopleTab.trainers:
        return AppTable<TrainerProfile>(
          isLoading: loading,
          data: c.trainers,
          onPage: c.setPage,
          unitLabel: 'مدرب',
          emptyTitle: 'لا يوجد مدربون',
          emptyHint: 'اضغط "مدرب جديد" للبدء',
          emptyIcon: Icons.sports_rounded,
          columns: const [
            AppColumn('المدرب', flex: 3),
            AppColumn('الرياضة'),
            AppColumn('الاشتراكات'),
            AppColumn('التقييم'),
            AppColumn('الحالة'),
            AppColumn('إجراءات'),
          ],
          rowBuilder: (rc, t, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, t.displayName, flex: 3, sub: t.bio),
              textCell(rc, t.sportName ?? AppGlobals.sportName(t.sportId)),
              textCell(
                rc,
                '${t.membershipsCount ?? 0}',
                color: GlobalColors.accentSoft,
                weight: FontWeight.w700,
              ),
              textCell(
                rc,
                t.ratingAvg == null
                    ? '—'
                    : '★ ${t.ratingAvg!.toStringAsFixed(1)}',
                color: GlobalColors.gold,
              ),
              StatusBadge(
                label: t.statusAr,
                color: t.isActive ? GlobalColors.green : GlobalColors.red,
              ),
              actionsCell([
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل',
                  enabled: me?.isAdmin ?? false,
                  onTap: () => _openForm(ctx, c, trainer: t),
                ),
                ActionBtn(
                  icon: Icons.delete_rounded,
                  color: GlobalColors.red,
                  // The server refuses while the coach still has classes.
                  tooltip: (t.membershipsCount ?? 0) > 0
                      ? 'لا يمكن الحذف — لديه اشتراكات قائمة'
                      : 'حذف',
                  enabled:
                      (me?.isAdmin ?? false) && (t.membershipsCount ?? 0) == 0,
                  onTap: () => showConfirm(
                    ctx,
                    title: 'حذف المدرب',
                    message: 'سيتم حذف ملف المدرب ${t.displayName}.',
                    onConfirm: () => c.deleteTrainer(t.id!),
                  ),
                ),
              ]),
            ],
          ),
        );

      case PeopleTab.staff:
        return AppTable<EmployeeProfile>(
          isLoading: loading,
          data: c.employees,
          onPage: c.setPage,
          unitLabel: 'موظف',
          emptyTitle: 'لا يوجد موظفون',
          emptyHint: 'التعيين متاح للمالك',
          emptyIcon: Icons.badge_rounded,
          columns: const [
            AppColumn('الموظف', flex: 3),
            AppColumn('الوظيفة', flex: 2),
            AppColumn('الراتب'),
            AppColumn('الحالة'),
            AppColumn('إجراءات'),
          ],
          rowBuilder: (rc, e, i) => AppRow(
            index: i,
            cells: [
              avatarCell(rc, e.displayName, flex: 3, sub: e.email),
              textCell(rc, e.position ?? '—', flex: 2),
              textCell(
                rc,
                e.salary == null
                    ? '—'
                    : '${e.salary!.toStringAsFixed(0)} ${AppGlobals.currency}',
                color: GlobalColors.green,
                weight: FontWeight.w700,
              ),
              StatusBadge(
                label: e.statusAr,
                color: e.isActive ? GlobalColors.green : GlobalColors.red,
              ),
              actionsCell([
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل',
                  enabled: me?.isOwner ?? false,
                  onTap: () => _openForm(ctx, c, employee: e),
                ),
                ActionBtn(
                  icon: Icons.person_remove_rounded,
                  color: GlobalColors.red,
                  tooltip: 'إنهاء التعيين',
                  enabled: me?.isOwner ?? false,
                  onTap: () => showConfirm(
                    ctx,
                    title: 'إنهاء التعيين',
                    message:
                        'سيحتفظ ${e.displayName} بحسابه ويعود عضواً عادياً. لن يُحذف الحساب.',
                    confirmLabel: 'إنهاء التعيين',
                    onConfirm: () => c.deleteEmployee(e.id!),
                  ),
                ),
              ]),
            ],
          ),
        );
    }
  }

  Color _roleColor(String? role) => switch (role) {
    'super-admin' => GlobalColors.gold,
    'admin' => GlobalColors.purple,
    'employee' => GlobalColors.blue,
    'trainer' => GlobalColors.accent,
    _ => GlobalColors.green,
  };

  // ── Dialogs ─────────────────────────────────
  void _openForm(
    BuildContext ctx,
    PeopleCubit c, {
    User? user,
    PlayerProfile? player,
    TrainerProfile? trainer,
    EmployeeProfile? employee,
  }) {
    c.clearForm();

    if (user != null) {
      c.nameCont.text = user.name ?? '';
      c.phoneCont.text = user.phone ?? '';
      c.formRole = user.role ?? 'player';
    }
    if (player != null) {
      c.heightCont.text = player.height?.toString() ?? '';
      c.weightCont.text = player.weight?.toString() ?? '';
      c.emergencyCont.text = player.emergencyContact ?? '';
    }
    if (trainer != null) {
      c.bioCont.text = trainer.bio ?? '';
      c.formSportId = trainer.sportId;
      c.formStatus = trainer.status ?? 'active';
    }
    if (employee != null) {
      c.nameCont.text = employee.name!;
      c.positionCont.text = employee.position ?? '';
      c.salaryCont.text = employee.salary?.toString() ?? '';
      c.formStatus = employee.status ?? 'active';
    }

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: _PeopleForm(
          user: user,
          player: player,
          trainer: trainer,
          employee: employee,
        ),
      ),
    );
  }

  void _avatarDialog(BuildContext ctx, PeopleCubit c, User u) {
    c.avatarUrlCont.clear();
    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: AppDialog<PeopleCubit>(
          title: 'صورة ${u.name ?? ''}',
          icon: Icons.image_rounded,
          width: 420,
          saveLabel: 'تعيين',
          onSave: () =>
              c.setAvatar(u.userId!, url: c.avatarUrlCont.text.trim()),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppField(
                controller: c.avatarUrlCont,
                label: 'رابط الصورة',
                icon: Icons.link_rounded,
                hint: 'https://...',
              ),
              gap,
              if (u.hasAvatar)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      c.removeAvatar(u.userId!);
                    },
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: GlobalColors.red,
                    ),
                    label: Text(
                      'إزالة الصورة الحالية',
                      style: TextStyle(color: GlobalColors.red),
                    ),
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
//  PEOPLE FORM — نموذج الأشخاص
//  One dialog serving four tabs; the fields
//  shown follow the role being edited.
// ─────────────────────────────────────────────
class _PeopleForm extends StatefulWidget {
  const _PeopleForm({this.user, this.player, this.trainer, this.employee});

  final User? user;
  final PlayerProfile? player;
  final TrainerProfile? trainer;
  final EmployeeProfile? employee;

  @override
  State<_PeopleForm> createState() => _PeopleFormState();
}

class _PeopleFormState extends State<_PeopleForm> {
  @override
  Widget build(BuildContext context) {
    final c = PeopleCubit.get(context);
    final me = AppGlobals.currentUser;

    // Which shape is this dialog wearing?
    final isPlayerEdit = widget.player != null;
    final isTrainer = c.tab == PeopleTab.trainers;
    final isStaff = c.tab == PeopleTab.staff;
    final isEdit =
        widget.user != null ||
        widget.player != null ||
        widget.trainer != null ||
        widget.employee != null;

    return AppDialog<PeopleCubit>(
      title: _title(isEdit, isPlayerEdit, isTrainer, isStaff),
      icon: isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
      saveLabel: isEdit ? 'حفظ التعديل' : 'إضافة',
      onSave: () async {
        if (isPlayerEdit) return c.savePlayer(widget.player!.id!);
        if (isTrainer) return c.saveTrainer(id: widget.trainer?.id);
        if (isStaff) return c.saveEmployee(id: widget.employee?.id);
        return c.saveUser(id: widget.user?.userId);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Members: physical details only ───
          if (isPlayerEdit) ...[
            dialogRow([
              AppField(
                controller: c.heightCont,
                label: 'الطول (سم)',
                icon: Icons.height_rounded,
                isNumber: true,
              ),
              AppField(
                controller: c.weightCont,
                label: 'الوزن (كجم)',
                icon: Icons.monitor_weight_rounded,
                isNumber: true,
              ),
            ]),
            gap,
            AppField(
              controller: c.emergencyCont,
              label: 'رقم الطوارئ',
              icon: Icons.emergency_rounded,
              hint: '05XXXXXXXX',
            ),
          ]
          // ── Staff hiring / editing ───────────
          else if (isStaff) ...[
            if (widget.employee == null) ...[
              // Promote an existing member, or hire from scratch.
              AppDropdown<User>(
                value: pickWhere(
                  AppGlobals.members,
                  (u) => u.userId == c.promoteUserId,
                ),
                items: AppGlobals.members,
                labelOf: (u) => '${u.name} · ${u.email ?? ''}',
                label: 'ترقية حساب قائم (اختياري)',
                icon: Icons.upgrade_rounded,
                emptyLabel: 'أو أنشئ حساباً جديداً بالأسفل',
                onChanged: (u) => setState(() => c.promoteUserId = u?.userId),
              ),
              gap,
            ],
            if (c.promoteUserId == null) ...[
              dialogRow([
                AppField(
                  controller: c.nameCont,
                  label: 'الاسم',
                  icon: Icons.badge_rounded,
                ),
                AppField(
                  controller: c.phoneCont,
                  label: 'الهاتف',
                  icon: Icons.phone_rounded,
                  hint: '05XXXXXXXX',
                ),
              ]),
              gap,
              if (widget.employee == null)
                dialogRow([
                  AppField(
                    controller: c.emailCont,
                    label: 'البريد الإلكتروني',
                    icon: Icons.alternate_email_rounded,
                  ),
                  AppField(
                    controller: c.passwordCont,
                    label: 'كلمة المرور',
                    icon: Icons.lock_rounded,
                    isObscure: true,
                  ),
                ]),
              if (widget.employee == null) gap,
            ],
            dialogRow([
              AppField(
                controller: c.positionCont,
                label: 'المسمى الوظيفي',
                icon: Icons.work_rounded,
              ),
              AppField(
                controller: c.salaryCont,
                label: 'الراتب',
                icon: Icons.payments_rounded,
                isNumber: true,
              ),
            ]),
            gap,
            _statusPicker(c, setState),
          ]
          // ── Trainers ─────────────────────────
          else if (isTrainer) ...[
            if (widget.trainer == null) ...[
              dialogRow([
                AppField(
                  controller: c.nameCont,
                  label: 'الاسم',
                  icon: Icons.badge_rounded,
                ),
                AppField(
                  controller: c.phoneCont,
                  label: 'الهاتف',
                  icon: Icons.phone_rounded,
                  hint: '05XXXXXXXX',
                ),
              ]),
              gap,
              dialogRow([
                AppField(
                  controller: c.emailCont,
                  label: 'البريد الإلكتروني',
                  icon: Icons.alternate_email_rounded,
                ),
                AppField(
                  controller: c.passwordCont,
                  label: 'كلمة المرور',
                  icon: Icons.lock_rounded,
                  isObscure: true,
                ),
              ]),
              gap,
            ],
            // A trainer can't exist without a sport.
            AppDropdown<Sport>(
              value: pickWhere(AppGlobals.sports, (s) => s.id == c.formSportId),
              items: AppGlobals.sports,
              labelOf: (s) => s.name ?? '—',
              label: 'الرياضة *',
              icon: Icons.sports_soccer_rounded,
              onChanged: (s) => setState(() => c.formSportId = s?.id),
            ),
            gap,
            AppField(
              controller: c.bioCont,
              label: 'نبذة',
              icon: Icons.description_rounded,
              maxLines: 3,
            ),
            gap,
            _statusPicker(c, setState),
          ]
          // ── Accounts ─────────────────────────
          else ...[
            dialogRow([
              AppField(
                controller: c.nameCont,
                label: 'الاسم *',
                icon: Icons.badge_rounded,
              ),
              AppField(
                controller: c.phoneCont,
                label: 'الهاتف',
                icon: Icons.phone_rounded,
                hint: '05XXXXXXXX',
              ),
            ]),
            gap,
            if (widget.user == null) ...[
              dialogRow([
                AppField(
                  controller: c.emailCont,
                  label: 'البريد الإلكتروني *',
                  icon: Icons.alternate_email_rounded,
                ),
                AppField(
                  controller: c.passwordCont,
                  label: 'كلمة المرور *',
                  icon: Icons.lock_rounded,
                  isObscure: true,
                ),
              ]),
              gap,
              AppDropdown<String>(
                value: c.formRole,
                // Only the owner can mint admins.
                items: [
                  'player',
                  'trainer',
                  'employee',
                  if (me?.isOwner ?? false) 'admin',
                ],
                labelOf: (r) => User(role: r).roleAr,
                label: 'الدور *',
                icon: Icons.shield_rounded,
                onChanged: (r) => setState(() => c.formRole = r ?? 'player'),
              ),
              gap,

              // Role-matching profile block
              if (c.formRole == 'trainer')
                AppDropdown<Sport>(
                  value: pickWhere(
                    AppGlobals.sports,
                    (s) => s.id == c.formSportId,
                  ),
                  items: AppGlobals.sports,
                  labelOf: (s) => s.name ?? '—',
                  label: 'الرياضة * (مطلوبة للمدرب)',
                  icon: Icons.sports_soccer_rounded,
                  onChanged: (s) => setState(() => c.formSportId = s?.id),
                ),

              if (c.formRole == 'player')
                dialogRow([
                  AppField(
                    controller: c.heightCont,
                    label: 'الطول (سم)',
                    icon: Icons.height_rounded,
                    isNumber: true,
                  ),
                  AppField(
                    controller: c.weightCont,
                    label: 'الوزن (كجم)',
                    icon: Icons.monitor_weight_rounded,
                    isNumber: true,
                  ),
                ]),

              if (c.formRole == 'admin' || c.formRole == 'employee')
                dialogRow([
                  AppField(
                    controller: c.positionCont,
                    label: 'المسمى الوظيفي',
                    icon: Icons.work_rounded,
                  ),
                  AppField(
                    controller: c.salaryCont,
                    label: 'الراتب',
                    icon: Icons.payments_rounded,
                    isNumber: true,
                  ),
                ]),
            ],
          ],
        ],
      ),
    );
  }

  String _title(bool isEdit, bool isPlayer, bool isTrainer, bool isStaff) {
    if (isPlayer) return 'تعديل بيانات العضو';
    if (isTrainer) return isEdit ? 'تعديل المدرب' : 'مدرب جديد';
    if (isStaff) return isEdit ? 'تعديل الموظف' : 'تعيين موظف';
    return isEdit ? 'تعديل الحساب' : 'حساب جديد';
  }

  Widget _statusPicker(PeopleCubit c, void Function(VoidCallback) setter) {
    return AppDropdown<String>(
      value: c.formStatus,
      items: const ['active', 'inactive'],
      labelOf: (s) => s == 'active' ? 'نشط' : 'موقوف',
      label: 'الحالة',
      icon: Icons.toggle_on_rounded,
      onChanged: (s) => setter(() => c.formStatus = s ?? 'active'),
    );
  }
}
