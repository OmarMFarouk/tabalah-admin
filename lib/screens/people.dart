import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/people_bloc/people_cubit.dart';
import '../components/general/app_dialog.dart';
import '../components/general/app_field.dart';
import '../components/general/app_media_fields.dart';
import '../components/general/app_table.dart';
import '../components/general/page_header.dart';
import '../components/general/snackbar.dart';
import '../components/general/stat_card.dart';
import '../models/catalog_model.dart';
import '../models/paginated_model.dart';
import '../models/settings_model.dart';
import '../models/users_model.dart';
import '../src/app_colors.dart';
import '../src/app_globals.dart';
import '../src/app_permissions.dart';
import 'guardian_share.dart';
import 'profile.dart';

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
      // SelectionArea sits here, per screen, rather than once in
      // MaterialApp.builder. `builder` wraps the Navigator, so a
      // SelectionArea there would be ABOVE the Overlay and its
      // copy/select context menu would have nowhere to mount - the same
      // trap Tooltip hits in that position. Inside a route the Overlay is
      // an ancestor, so right-click copy works.
      child: SelectionArea(
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
      ),
    );
  }

  // Staff roster is owner-only; the rest follow the admin policy.
  bool _canAdd(PeopleTab tab, User? me) {
    if (me == null) return false;
    return switch (tab) {
      PeopleTab.accounts => Permissions.canCreateUsers,
      PeopleTab.trainers => Permissions.canManageTrainers,
      PeopleTab.staff => Permissions.canManageStaff,
      // Members used to have no add button at all, which meant signing up a
      // walk-in started on a different tab.
      PeopleTab.members => Permissions.canManagePlayers,
    };
  }

  String _addLabel(PeopleTab tab) => switch (tab) {
    PeopleTab.accounts => 'حساب جديد',
    PeopleTab.trainers => 'مدرب جديد',
    PeopleTab.staff => 'موظف جديد',
    PeopleTab.members => 'عضو جديد',
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
            onChanged: (_) => c.search(),
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
              avatarCell(
                rc,
                avatar: u.avatar ?? '',
                u.name ?? '—',
                flex: 3,
                sub: u.presenceAr,
              ),
              textCell(rc, u.email ?? '—', flex: 3, size: 11),
              textCell(rc, u.phone ?? '—'),
              StatusBadge(label: u.roleAr, color: _roleColor(u.role)),
              actionsCell([
                ActionBtn(
                  icon: Icons.badge_rounded,
                  color: GlobalColors.blue,
                  tooltip: 'الملف الشخصي',
                  onTap: () =>
                      UserProfileScreen.open(ctx, u.userId!, name: u.name),
                ),
                ActionBtn(
                  icon: Icons.image_rounded,
                  color: GlobalColors.purple,
                  tooltip: 'الصورة الشخصية',
                  onTap: () => _avatarDialog(
                    ctx,
                    c,
                    userId: u.userId!,
                    name: u.name ?? '',
                    hasAvatar: u.hasAvatar,
                    currentUrl: u.avatar,
                  ),
                ),
                // Absent rather than greyed out for members and coaches:
                // a role only means something inside the panel, and they
                // never open it. A disabled button here read as "you lack
                // the permission", which was the wrong explanation.
                if (u.isStaff)
                  ActionBtn(
                    icon: Icons.admin_panel_settings_rounded,
                    color: GlobalColors.gold,
                    tooltip: Permissions.canChangeRoleOf(u)
                        ? 'الدور والصلاحيات'
                        : Permissions.roleDenialReason(u),
                    enabled: Permissions.canChangeRoleOf(u),
                    onTap: () => showRoleDialog(ctx, c, u),
                  ),
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل',
                  enabled: Permissions.canManageUsers,
                  onTap: () => _openForm(ctx, c, user: u),
                ),
                ActionBtn(
                  icon: Icons.delete_rounded,
                  color: GlobalColors.red,
                  tooltip: Permissions.canDeleteUser(u)
                      ? 'حذف'
                      : 'الحذف متاح للمالك فقط',
                  enabled: Permissions.canManageStaff,
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
            AppColumn('رقم العضوية', flex: 2),
            AppColumn('الطول'),
            AppColumn('الوزن'),
            AppColumn('كتلة الجسم'),
            AppColumn('كود ولي الأمر', flex: 2),
            AppColumn('اتصال الطوارئ', flex: 2),
            AppColumn('إجراءات', flex: 2),
          ],
          rowBuilder: (rc, p, i) => AppRow(
            index: i,
            cells: [
              avatarCell(
                rc,
                avatar: p.avatar ?? '',
                p.displayName,
                flex: 3,
                sub: p.email,
              ),
              // Their club id, not the database row id — this is the number
              // on the card and the one they give at the desk.
              textCell(
                rc,
                p.clubId ?? '—',
                flex: 2,
                size: 11,
                color: GlobalColors.accentSoft,
                weight: FontWeight.w700,
              ),
              textCell(rc, p.height == null ? '—' : '${p.height} سم'),
              textCell(rc, p.weight == null ? '—' : '${p.weight} كجم'),
              textCell(
                rc,
                p.bmi == null ? '—' : p.bmi!.toStringAsFixed(1),
                color: GlobalColors.accentSoft,
                weight: FontWeight.w700,
              ),
              // The code is meant to be read out or copied at the desk, so
              // it is shown in the row itself rather than hidden behind a
              // dialog. Greyed out when the portal is switched off, which
              // is the state staff most often need to spot.
              _guardianCodeCell(rc, p),
              textCell(rc, p.emergencyContact ?? '—', flex: 2, size: 11),
              actionsCell([
                ActionBtn(
                  icon: Icons.badge_rounded,
                  color: GlobalColors.blue,
                  tooltip: 'الملف الشخصي',
                  onTap: () => UserProfileScreen.open(ctx, p.userId!, name: p.name),
                ),
                ActionBtn(
                  icon: Icons.family_restroom_rounded,
                  color: p.guardianAccessEnabled
                      ? GlobalColors.purple
                      : GlobalColors.red,
                  tooltip: 'بوابة ولي الأمر',
                  enabled: Permissions.canManageUsers,
                  onTap: () => _openGuardianDialog(ctx, c, p),
                ),
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل البيانات البدنية',
                  enabled: Permissions.canManageUsers,
                  onTap: () => _openForm(ctx, c, player: p),
                ),
              ], flex: 2),
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
              avatarCell(
                rc,
                t.displayName,
                avatar: t.avatar ?? '',
                flex: 3,
                sub: t.bio,
              ),
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
                  icon: Icons.badge_rounded,
                  color: GlobalColors.blue,
                  tooltip: 'الملف الشخصي',
                  onTap: () => UserProfileScreen.open(ctx, t.userId!, name: t.name),
                ),
                ActionBtn(
                  icon: Icons.image_rounded,
                  color: GlobalColors.purple,
                  tooltip: 'الصورة الشخصية',
                  enabled: Permissions.canManageUsers && t.userId != null,
                  onTap: () => _avatarDialog(
                    ctx,
                    c,
                    userId: t.userId!,
                    name: t.displayName,
                    hasAvatar: (t.avatar ?? '').isNotEmpty,
                    currentUrl: t.avatar,
                  ),
                ),
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل',
                  enabled: Permissions.canManageUsers,
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
                      Permissions.canManageTrainers && (t.membershipsCount ?? 0) == 0,
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
            AppColumn('الدور', flex: 2),
            AppColumn('الراتب'),
            AppColumn('الحالة'),
            AppColumn('إجراءات'),
          ],
          rowBuilder: (rc, e, i) => AppRow(
            index: i,
            cells: [
              avatarCell(
                rc,
                avatar: e.avatar,
                e.displayName,
                flex: 3,
                sub: e.email,
              ),
              textCell(rc, e.position ?? '—', flex: 2),
              // The title and the role are different facts and are shown as
              // such — a "Head Coach" on default permissions and one on a
              // custom role look identical until this column says so.
              textCell(
                rc,
                e.accessRoleName ?? 'الصلاحيات الافتراضية',
                flex: 2,
                size: 11,
                color: e.accessRoleName == null
                    ? GlobalColors.textSecondary(rc)
                    : GlobalColors.accentSoft,
              ),
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
                  icon: Icons.badge_rounded,
                  color: GlobalColors.blue,
                  tooltip: 'الملف الشخصي',
                  onTap: () => UserProfileScreen.open(ctx, e.userId!, name: e.name),
                ),
                ActionBtn(
                  icon: Icons.edit_rounded,
                  color: GlobalColors.accentSoft,
                  tooltip: 'تعديل',
                  enabled: Permissions.canManageStaff,
                  onTap: () => _openForm(ctx, c, employee: e),
                ),
                ActionBtn(
                  icon: Icons.person_remove_rounded,
                  color: GlobalColors.red,
                  tooltip: 'إنهاء التعيين',
                  enabled: Permissions.canManageStaff,
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
      c.nameEnCont.text = user.nameEn ?? '';
      c.phoneCont.text = user.phone ?? '';
      c.formRole = user.role ?? 'player';
    }
    if (player != null) {
      c.heightCont.text = player.height?.toString() ?? '';
      c.weightCont.text = player.weight?.toString() ?? '';
      c.emergencyCont.text = player.emergencyContact ?? '';
    }
    if (trainer != null) {
      c.nameCont.text = trainer.name ?? '';
      c.nameEnCont.text = trainer.nameEn ?? '';
      c.emailCont.text = trainer.email ?? '';
      c.phoneCont.text = trainer.phone ?? '';
      c.bioCont.text = trainer.bio ?? '';
      c.formSportId = trainer.sportId;
      c.formStatus = trainer.status ?? 'active';
    }
    if (employee != null) {
      c.nameCont.text = employee.name!;
      c.nameEnCont.text = employee.nameEn ?? '';
      c.positionCont.text = employee.position ?? '';
      c.salaryCont.text = employee.salary?.toString() ?? '';
      c.formAccessRoleId = employee.accessRoleId;
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

  // ── Parent portal — بوابة ولي الأمر ─────────
  //  One short code per member, handed to a parent so they can watch
  //  their child's attendance, schedule and payments without an account
  //  of their own and without being able to change anything.
  Widget _guardianCodeCell(BuildContext rc, PlayerProfile p) {
    final code = p.guardianCode;
    final off = !p.guardianAccessEnabled;

    if (code == null || code.isEmpty) {
      return textCell(rc, '—', flex: 2, size: 11);
    }

    return Expanded(
      flex: 2,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (off ? GlobalColors.red : GlobalColors.purple).withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (off ? GlobalColors.red : GlobalColors.purple)
                    .withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              code,
              style: TextStyle(
                color: off ? GlobalColors.red : GlobalColors.purple,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                // A monospace face matters here: the code gets compared
                // character by character against something written down.
                fontFamily: 'monospace',
                letterSpacing: 1.2,
                decoration: off ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 14),
            tooltip: 'نسخ الكود',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            color: GlobalColors.textSecondary(rc),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              MySnackBar.show(rc, text: 'تم نسخ الكود.', isSuccess: true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 14),
            tooltip: 'مشاركة الكود',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            color: GlobalColors.textSecondary(rc),
            onPressed: () => shareGuardianCode(
              rc,
              code: code,
              memberName: p.displayName,
              phone: p.phone,
            ),
          ),
        ],
      ),
    );
  }

  void _openGuardianDialog(BuildContext ctx, PeopleCubit c, PlayerProfile p) {
    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: _GuardianDialog(player: p),
      ),
    );
  }

  void _avatarDialog(
    BuildContext ctx,
    PeopleCubit c, {
    required int userId,
    required String name,
    required bool hasAvatar,
    String? currentUrl,
  }) {
    c.avatarUrlCont.clear();
    c.pendingAvatarPath = null;

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) => AppDialog<PeopleCubit>(
            title: 'صورة $name',
            icon: Icons.image_rounded,
            width: 460,
            saveLabel: 'تعيين',
            // A file wins when both are set, though the picker clears the
            // URL field anyway — the server takes one or the other.
            onSave: () => c.setAvatar(
              userId,
              filePath: c.pendingAvatarPath,
              url: c.avatarUrlCont.text.trim(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Same control the catalogue uses for artwork: a file from
                // disk or a pasted link, rather than a link and nothing else.
                // Most photos an operator has are on the machine in front of
                // them, and "upload it somewhere first" was the wrong ask.
                ImageField(
                  urlController: c.avatarUrlCont,
                  label: 'الصورة الشخصية',
                  hint: 'ارفع صورة من الجهاز أو الصق رابطاً',
                  pickedPath: c.pendingAvatarPath,
                  currentUrl: currentUrl,
                  onPickFile: () async {
                    await c.pickAvatarFile();
                    setLocal(() {});
                  },
                  onDropPicked: () => setLocal(c.dropPickedAvatar),
                  onRemove: () {
                    Navigator.pop(sctx);
                    c.removeAvatar(userId);
                  },
                ),
                if (hasAvatar) ...[
                  gap,
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(sctx);
                        c.removeAvatar(userId);
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
              ],
            ),
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

    // Which shape is this dialog wearing?
    final isPlayerEdit = widget.player != null;
    final isPlayerAdd =
        widget.player == null && c.tab == PeopleTab.members;
    final isTrainer = c.tab == PeopleTab.trainers;
    // The accounts tab creating a brand new account — the one flow that
    // starts with the type picker.
    final isNewAccount =
        c.tab == PeopleTab.accounts && widget.user == null;
    final isStaff = c.tab == PeopleTab.staff;
    final isEdit =
        widget.user != null ||
        widget.player != null ||
        widget.trainer != null ||
        widget.employee != null;

    return AppDialog<PeopleCubit>(
      title: isNewAccount && !c.roleTypeChosen
          ? 'ما نوع الحساب؟'
          : _title(isEdit, isPlayerEdit, isTrainer, isStaff),
      showSave: !(isNewAccount && !c.roleTypeChosen),
      icon: isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
      saveLabel: isEdit ? 'حفظ التعديل' : 'إضافة',
      onSave: () async {
        if (isPlayerAdd) return c.createPlayer();
        if (isPlayerEdit) return c.savePlayer(widget.player!.id!);
        if (isTrainer) return c.saveTrainer(id: widget.trainer?.id);
        if (isStaff) return c.saveEmployee(id: widget.employee?.id);
        return c.saveUser(id: widget.user?.userId);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── A new account starts with "what kind?" ──
          //  Nothing below this point is shared between the three: a coach
          //  needs a sport, a member needs their measurements, a staff
          //  member needs a job title. Showing all of it at once and letting
          //  a dropdown hide two thirds made the form look like it changed
          //  its mind every time the role moved.
          if (isNewAccount && !c.roleTypeChosen)
            _RoleTypePicker(
              onPicked: (role) => setState(() {
                c.formRole = role;
                c.roleTypeChosen = true;
              }),
            )
          // ── Adding a member ──────────────────
          else if (isPlayerAdd) ...[
            dialogRow([
              AppField(
              controller: c.nameCont,
              label: 'الاسم (عربي) *',
              icon: Icons.badge_rounded,
              ),
              AppField(
              controller: c.nameEnCont,
              label: 'Name (English)',
              icon: Icons.translate_rounded,
              ),
            ]),
            gap,
            dialogRow([
              AppField(
              controller: c.emailCont,
              label: 'البريد الإلكتروني *',
              icon: Icons.email_rounded,
              ),
              AppField(
              controller: c.phoneCont,
              label: 'الهاتف',
              icon: Icons.phone_rounded,
              hint: '05XXXXXXXX',
              ),
            ]),
            gap,
            AppField(
              controller: c.passwordCont,
              label: 'كلمة المرور *',
              icon: Icons.lock_rounded,
              hint: '8 أحرف على الأقل',
            ),
            gap,
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
          // ── Members: physical details only ───
          else if (isPlayerEdit) ...[
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
            ...[
              dialogRow([
                AppField(
                  controller: c.nameCont,
                  label: 'الاسم (عربي)',
                  icon: Icons.badge_rounded,
                ),
                AppField(
                  controller: c.nameEnCont,
                  label: 'Name (English)',
                  icon: Icons.translate_rounded,
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
            // The role decides what this account may do; the job title is
            // only a label. They start out saying the same thing — a blank
            // title is filled in from the role — and diverge from there.
            AppDropdown<AccessRole>(
              value: pickWhere(
                AppGlobals.accessRoles,
                (r) => r.id == c.formAccessRoleId,
              ),
              items: AppGlobals.accessRoles,
              labelOf: (r) => r.name ?? r.key ?? '—',
              label: 'الدور والصلاحيات',
              icon: Icons.admin_panel_settings_rounded,
              emptyLabel: AppGlobals.accessRoles.isEmpty
                  ? 'لا توجد أدوار — أنشئها من شاشة الصلاحيات'
                  : 'الصلاحيات الافتراضية',
              onChanged: (r) => setState(() => c.pickAccessRole(r)),
            ),
            gap,
            dialogRow([
              AppField(
                controller: c.positionCont,
                label: 'المسمى الوظيفي',
                icon: Icons.work_rounded,
                hint: 'يتبع اسم الدور — عدّله إن أردت مسمّى مختلفاً',
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
            // The coach's account details are editable too, not just their
            // sport and bio: the form used to hide these once the trainer
            // existed, which left a typo'd name or a stale phone number with
            // nowhere to be fixed.
            dialogRow([
              AppField(
                controller: c.nameCont,
                label: 'الاسم (عربي)',
                icon: Icons.badge_rounded,
              ),
              AppField(
                controller: c.nameEnCont,
                label: 'Name (English)',
                icon: Icons.translate_rounded,
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
                // Blank on an edit means "leave the current one alone" —
                // the update payload drops the field entirely.
                hint: widget.trainer == null
                    ? '٨ أحرف على الأقل'
                    : 'اتركه فارغاً للإبقاء على كلمة المرور الحالية',
              ),
            ]),
            gap,
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
                label: 'الاسم (عربي) *',
                icon: Icons.badge_rounded,
              ),
              AppField(
                controller: c.nameEnCont,
                label: 'Name (English)',
                icon: Icons.translate_rounded,
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

              // The chosen kind, and a way back to the picker. Shown rather
              // than a dropdown because the choice has already been made by
              // this point and it decides everything below it — a control
              // that still looks unset invites changing it by accident.
              _ChosenRoleBar(
                role: c.formRole,
                onChange: () => setState(() => c.roleTypeChosen = false),
              ),
              gap,

              // Role-matching profile block
              if (c.formRole == 'trainer') ...[
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
                gap,
                AppField(
                  controller: c.bioCont,
                  label: 'نبذة',
                  icon: Icons.description_rounded,
                  maxLines: 2,
                ),
                gap,
              ],

              if (c.formRole == 'player') ...[
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
                gap,
              ],

              if (c.formRole == 'admin' || c.formRole == 'employee') ...[
                AppDropdown<AccessRole>(
                  value: pickWhere(
                    AppGlobals.accessRoles,
                    (r) => r.id == c.formAccessRoleId,
                  ),
                  items: AppGlobals.accessRoles,
                  labelOf: (r) => r.name ?? r.key ?? '—',
                  label: 'الدور والصلاحيات',
                  icon: Icons.admin_panel_settings_rounded,
                  emptyLabel: AppGlobals.accessRoles.isEmpty
                      ? 'لا توجد أدوار — أنشئها من شاشة الصلاحيات'
                      : 'الصلاحيات الافتراضية',
                  onChanged: (r) => setState(() => c.pickAccessRole(r)),
                ),
                gap,
                dialogRow([
                  AppField(
                    controller: c.positionCont,
                    label: 'المسمى الوظيفي',
                    icon: Icons.work_rounded,
                    hint: 'يتبع اسم الدور — عدّله إن أردت مسمّى مختلفاً',
                  ),
                  AppField(
                    controller: c.salaryCont,
                    label: 'الراتب',
                    icon: Icons.payments_rounded,
                    isNumber: true,
                  ),
                ]),
                gap,
              ],

              // Uploaded after the account is created — the avatar endpoint
              // is keyed on a user id, so there is nothing to attach a photo
              // to until the account exists.
              ImageField(
                urlController: c.avatarUrlCont,
                label: 'الصورة الشخصية',
                hint: 'اختياري — ارفع صورة من الجهاز أو الصق رابطاً',
                pickedPath: c.pendingAvatarPath,
                onPickFile: () async {
                  await c.pickAvatarFile();
                  if (mounted) setState(() {});
                },
                onDropPicked: () => setState(c.dropPickedAvatar),
                onRemove: () => setState(c.dropPickedAvatar),
              ),
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

// ─────────────────────────────────────────────
//  ROLE DIALOG — تغيير الدور
//  Separate from the edit form on purpose: this
//  changes what somebody is allowed to do, so it
//  gets its own confirmation and its own server
//  call.
//
//  What it offers is the roles built on the
//  permissions screen, not the account tier. The
//  tier decides which application you may open —
//  panel, coach app, member app — and that
//  follows from what the person is, so it isn't
//  something to reassign from a dropdown. The
//  role decides what you may do once inside the
//  panel, which is exactly the thing an operator
//  wants to change, and only staff are ever
//  inside it. Hence: staff accounts only, and
//  never a route from employee to member.
// ─────────────────────────────────────────────
void showRoleDialog(BuildContext ctx, PeopleCubit c, User target) {
  // Fetched lazily rather than assumed: the list is loaded at sign-in, but
  // an account that only just gained the permission would find it empty.
  c.ensureAccessRoles();

  int? picked = target.accessRoleId;

  showDialog(
    context: ctx,
    builder: (_) => BlocProvider.value(
      value: c,
      child: BlocBuilder<PeopleCubit, AppStates>(
        builder: (bctx, _) => StatefulBuilder(
          builder: (sctx, setLocal) {
            final options = AppGlobals.accessRoles;
            final allowed = Permissions.canChangeRoleOf(target);
            final current = target.accessRoleName;

            return AppDialog<PeopleCubit>(
              title: 'دور ${target.name ?? ''}',
              icon: Icons.admin_panel_settings_rounded,
              saveLabel: 'حفظ الدور',
              width: 480,
              onSave: () {
                if (!allowed || target.userId == null) return;
                c.assignRole(target.userId!, picked);
              },
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
                      'الدور الحالي: ${current ?? 'الصلاحيات الافتراضية'}. '
                      'الدور يحدّد ما يستطيع هذا الحساب فعله داخل لوحة التحكم، '
                      'ويسري مفعوله فوراً.',
                      style: TextStyle(
                        color: GlobalColors.textSecondary(sctx),
                        fontSize: 11.5,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppDropdown<AccessRole>(
                    value: pickWhere(options, (r) => r.id == picked),
                    items: options,
                    labelOf: (r) => r.name ?? r.key ?? '—',
                    label: 'الدور',
                    icon: Icons.badge_rounded,
                    emptyLabel: options.isEmpty
                        ? 'لا توجد أدوار — أنشئها من شاشة الصلاحيات'
                        : 'الصلاحيات الافتراضية',
                    onChanged: (r) => setLocal(() => picked = r?.id),
                  ),
                  const SizedBox(height: 10),
                  // Every role here was built on the permissions screen, so
                  // that is where its contents are read and changed — this
                  // dialog only decides who gets it.
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: GlobalColors.textSecondary(sctx),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'تُدار الأدوار وصلاحياتها من شاشة الإعدادات › '
                          'الأدوار والصلاحيات.',
                          style: TextStyle(
                            color: GlobalColors.textSecondary(sctx),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (picked != null &&
                      pickWhere(options, (r) => r.id == picked)
                              ?.permissions
                              .isNotEmpty ==
                          true) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${pickWhere(options, (r) => r.id == picked)!.permissions.length} صلاحية '
                        'ضمن هذا الدور.',
                        style: TextStyle(
                          color: GlobalColors.accentSoft,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (!allowed) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: GlobalColors.red,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            Permissions.roleDenialReason(target),
                            style: TextStyle(
                              color: GlobalColors.red,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  GUARDIAN DIALOG — إدارة بوابة ولي الأمر
//
//  Deliberately not part of the member edit form:
//  regenerating a code and switching the portal
//  off both take effect immediately and cut a
//  parent's access, so they sit behind their own
//  confirm rather than riding along with a height
//  and weight correction.
// ─────────────────────────────────────────────
class _GuardianDialog extends StatefulWidget {
  const _GuardianDialog({required this.player});

  final PlayerProfile player;

  @override
  State<_GuardianDialog> createState() => _GuardianDialogState();
}

class _GuardianDialogState extends State<_GuardianDialog> {
  late bool _enabled = widget.player.guardianAccessEnabled;

  @override
  Widget build(BuildContext context) {
    final c = PeopleCubit.get(context);
    final code = widget.player.guardianCode ?? '—';

    return AppDialog<PeopleCubit>(
      title: 'بوابة ولي الأمر — ${widget.player.displayName}',
      icon: Icons.family_restroom_rounded,
      width: 480,
      saveLabel: 'حفظ',
      onSave: () => c.setGuardianAccess(widget.player.id!, _enabled),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'يدخل ولي الأمر هذا الكود في التطبيق ليتابع حضور العضو ومواعيده '
            'واشتراكاته للاطّلاع فقط — دون أي صلاحية للتعديل أو الدفع.',
            style: TextStyle(
              color: GlobalColors.textSecondary(context),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          gap,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: GlobalColors.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GlobalColors.border(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SelectableText(
                  code,
                  style: TextStyle(
                    color: GlobalColors.accent,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'نسخ',
                  color: GlobalColors.textSecondary(context),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    MySnackBar.show(
                      context,
                      text: 'تم نسخ الكود.',
                      isSuccess: true,
                    );
                  },
                ),
                // Copying leaves the desk to retype the code — and the
                // sentence explaining it — into whatever they message the
                // parent from. This sends the whole message instead.
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  tooltip: 'مشاركة',
                  color: GlobalColors.textSecondary(context),
                  onPressed: code == '—'
                      ? null
                      : () => shareGuardianCode(
                          context,
                          code: code,
                          memberName: widget.player.displayName,
                          phone: widget.player.phone,
                        ),
                ),
              ],
            ),
          ),
          gap,
          AppSwitch(
            value: _enabled,
            label: 'تفعيل البوابة',
            onChanged: (v) => setState(() => _enabled = v),
          ),
          gap,
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              showConfirm(
                context,
                title: 'إنشاء كود جديد',
                message:
                    'سيتوقف الكود الحالي عن العمل فوراً، وسيُسجَّل خروج أي '
                    'ولي أمر يستخدمه. تأكد من تسليم الكود الجديد لصاحبه.',
                onConfirm: () => c.rotateGuardianCode(widget.player.id!),
              );
            },
            icon: const Icon(Icons.autorenew_rounded, size: 16),
            label: const Text('إنشاء كود جديد'),
            style: OutlinedButton.styleFrom(
              foregroundColor: GlobalColors.red,
              side: BorderSide(color: GlobalColors.border(context)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────
//  ROLE TYPE PICKER — نوع الحساب
//
//  The first thing a new account asks. Three
//  cards rather than a dropdown: the choice
//  decides what the rest of the form even is,
//  and a one-line select underplays that.
// ─────────────────────────────────────────────
class _RoleTypePicker extends StatelessWidget {
  const _RoleTypePicker({required this.onPicked});

  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'اختر نوع الحساب لعرض الحقول الخاصة به.',
          style: TextStyle(
            color: GlobalColors.textSecondary(context),
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 16),
        _card(
          context,
          role: 'player',
          label: 'عضو',
          hint: 'يستخدم تطبيق الأعضاء — القياسات والاشتراكات والحضور',
          icon: Icons.person_rounded,
          color: GlobalColors.accent,
        ),
        const SizedBox(height: 10),
        _card(
          context,
          role: 'trainer',
          label: 'مدرب',
          hint: 'يستخدم تطبيق المدربين — يرتبط برياضة واحدة',
          icon: Icons.sports_rounded,
          color: GlobalColors.green,
        ),
        const SizedBox(height: 10),
        _card(
          context,
          role: 'employee',
          label: 'موظف',
          hint: 'يدخل لوحة التحكم — المسمى الوظيفي والراتب',
          icon: Icons.badge_rounded,
          color: GlobalColors.blue,
        ),
        // Minting an admin stays with the owner, same as the server's rule.
        if (Permissions.isOwner) ...[
          const SizedBox(height: 10),
          _card(
            context,
            role: 'admin',
            label: 'مدير',
            hint: 'صلاحيات إدارية كاملة على النادي',
            icon: Icons.admin_panel_settings_rounded,
            color: GlobalColors.gold,
          ),
        ],
      ],
    );
  }

  Widget _card(
    BuildContext context, {
    required String role,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onPicked(role),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: GlobalColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GlobalColors.border(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: GlobalColors.textPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    style: TextStyle(
                      color: GlobalColors.textSecondary(context),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: GlobalColors.textSecondary(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CHOSEN ROLE BAR — النوع المختار
//  A reminder of the answer, and the way back.
// ─────────────────────────────────────────────
class _ChosenRoleBar extends StatelessWidget {
  const _ChosenRoleBar({required this.role, required this.onChange});

  final String role;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: GlobalColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlobalColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_rounded, size: 17, color: GlobalColors.accentSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'نوع الحساب: ${User(role: role).roleAr}',
              style: TextStyle(
                color: GlobalColors.textPrimary(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onChange,
            icon: Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: GlobalColors.accentSoft,
            ),
            label: Text(
              'تغيير',
              style: TextStyle(
                color: GlobalColors.accentSoft,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
