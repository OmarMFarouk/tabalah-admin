import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/settings_bloc/settings_cubit.dart';
import '../components/general/app_dialog.dart';
import '../components/general/app_field.dart';
import '../components/general/app_table.dart';
import '../components/general/page_header.dart';
import '../components/general/snackbar.dart';
import '../components/general/stat_card.dart';
import '../models/paginated_model.dart';
import '../models/settings_model.dart';
import '../src/app_colors.dart';
import 'user_audit.dart';
import '../src/app_permissions.dart';

// ─────────────────────────────────────────────
//  SETTINGS — الأدوار وسجل النشاط
//  Two halves of the same question: who is
//  allowed to do what, and what did they do.
// ─────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsCubit()..fetch(),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SelectionArea(
        child: Scaffold(
          backgroundColor: GlobalColors.bg(context),
          body: BlocConsumer<SettingsCubit, AppStates>(
            listener: (ctx, state) {
              if (state is AppSuccess) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: true);
              }
              if (state is AppFailure) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: false);
              }
            },
            builder: (ctx, state) {
              final c = SettingsCubit.get(ctx);
              final loading = state is AppLoading;

              // Only the tabs this account may actually open. A tab that
              // 403s on load is worse than one that isn't there.
              final tabs = SettingsTab.values.where((t) {
                return switch (t) {
                  SettingsTab.roles => Permissions.canSeeRoles,
                  SettingsTab.audit => Permissions.canSeeAudit,
                };
              }).toList();

              return Column(
                children: [
                  PageHeader(
                    title: 'الإعدادات والصلاحيات',
                    icon: Icons.shield_rounded,
                    isLoading: loading,
                    onRefresh: c.fetch,
                    tabs: tabs
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
                      if (c.tab == SettingsTab.roles &&
                          Permissions.canManageRoles)
                        HeaderButton(
                          icon: Icons.add_rounded,
                          label: 'دور جديد',
                          color: GlobalColors.green,
                          filled: true,
                          onTap: () => _openRoleForm(ctx, c),
                        ),
                    ],
                  ),

                  if (c.tab == SettingsTab.roles)
                    StatRow(
                      cards: [
                        StatCard(
                          label: 'الأدوار',
                          value: '${c.roles.length}',
                          icon: Icons.admin_panel_settings_rounded,
                          color: GlobalColors.accent,
                          sub: 'مجموعات صلاحيات',
                        ),
                        StatCard(
                          label: 'الصلاحيات',
                          value: '${c.allPermissions.length}',
                          icon: Icons.key_rounded,
                          color: GlobalColors.purple,
                          sub: 'إجراء يمكن ضبطه',
                        ),
                        StatCard(
                          label: 'حسابات مُسندة',
                          value:
                              '${c.roles.fold<int>(0, (a, r) => a + r.usersCount)}',
                          icon: Icons.people_alt_rounded,
                          color: GlobalColors.blue,
                          sub: 'موظف لديه دور',
                        ),
                      ],
                    ),

                  if (c.tab == SettingsTab.audit) _auditToolbar(ctx, c),

                  Expanded(child: _body(ctx, c, loading)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Toolbar ─────────────────────────────────
  Widget _auditToolbar(BuildContext ctx, SettingsCubit c) {
    return Toolbar(
      children: [
        Expanded(
          flex: 3,
          child: SearchField(
            controller: c.searchCont,
            hint: 'ابحث في الوصف أو باسم الموظف... (اضغط Enter)',
            onChanged: (_) => c.search(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 170,
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
          width: 170,
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
          width: 150,
          child: DateField(
            value: c.fromFilter,
            label: 'من تاريخ',
            onPicked: (d) => c.setFilter(from: d),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: DateField(
            value: c.toFilter,
            label: 'إلى تاريخ',
            onPicked: (d) => c.setFilter(to: d),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: c.clearFilters,
          tooltip: 'مسح الفلاتر',
          icon: Icon(Icons.filter_alt_off_rounded, color: GlobalColors.red),
        ),
      ],
    );
  }

  // ── Body ────────────────────────────────────
  Widget _body(BuildContext ctx, SettingsCubit c, bool loading) {
    if (c.tab == SettingsTab.roles) return _rolesTable(ctx, c, loading);
    return _auditTable(ctx, c, loading);
  }

  Widget _rolesTable(BuildContext ctx, SettingsCubit c, bool loading) {
    return AppTable<AccessRole>(
      isLoading: loading,
      data: Paginated(items: c.roles, total: c.roles.length),
      unitLabel: 'دور',
      emptyTitle: 'لا توجد أدوار',
      emptyHint: 'اضغط "دور جديد" لإنشاء أول دور',
      emptyIcon: Icons.admin_panel_settings_rounded,
      columns: const [
        AppColumn('الدور', flex: 3),
        AppColumn('الوصف', flex: 3),
        AppColumn('الصلاحيات'),
        AppColumn('الحسابات'),
        AppColumn('النوع'),
        AppColumn('إجراءات'),
      ],
      rowBuilder: (rc, role, i) => AppRow(
        index: i,
        cells: [
          mediaCell(
            rc,
            role.displayName,
            flex: 3,
            sub: role.nameEn,
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: GlobalColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                role.isSystem
                    ? Icons.verified_user_rounded
                    : Icons.admin_panel_settings_rounded,
                size: 18,
                color: GlobalColors.accentSoft,
              ),
            ),
          ),
          textCell(rc, role.description ?? '—', flex: 3, size: 11),
          textCell(
            rc,
            '${role.permissions.length}',
            color: GlobalColors.accentSoft,
            weight: FontWeight.w700,
          ),
          textCell(
            rc,
            '${role.usersCount}',
            color: GlobalColors.blue,
            weight: FontWeight.w700,
          ),
          StatusBadge(
            label: role.isSystem ? 'أساسي' : 'مخصّص',
            color: role.isSystem ? GlobalColors.gold : GlobalColors.green,
          ),
          actionsCell([
            ActionBtn(
              icon: Icons.tune_rounded,
              color: GlobalColors.accentSoft,
              tooltip: 'تعديل الصلاحيات',
              enabled: Permissions.canManageRoles,
              onTap: () => _openRoleForm(ctx, c, role: role),
            ),
            ActionBtn(
              icon: Icons.delete_rounded,
              color: GlobalColors.red,
              tooltip: role.isSystem
                  ? 'لا يمكن حذف دور أساسي'
                  : role.usersCount > 0
                  ? 'الدور مُسند إلى حسابات'
                  : 'حذف',
              enabled: Permissions.canManageRoles && role.isDeletable,
              onTap: () => showConfirm(
                ctx,
                title: 'حذف الدور',
                message:
                    'سيُحذف دور «${role.displayName}» نهائياً. لا يمكن التراجع.',
                onConfirm: () => c.deleteRole(role.id!),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _auditTable(BuildContext ctx, SettingsCubit c, bool loading) {
    return AppTable<AuditEntry>(
      isLoading: loading,
      data: c.logs,
      onPage: c.setPage,
      unitLabel: 'حدث',
      emptyTitle: 'لا يوجد نشاط',
      emptyHint: 'كل إجراء داخل اللوحة يُسجَّل هنا تلقائياً',
      emptyIcon: Icons.history_rounded,
      columns: const [
        AppColumn('الوقت', flex: 2),
        AppColumn('الموظف', flex: 2),
        AppColumn('الإجراء'),
        AppColumn('التفاصيل', flex: 4),
        AppColumn('IP'),
        AppColumn(''),
      ],
      rowBuilder: (rc, log, i) => AppRow(
        index: i,
        cells: [
          textCell(rc, log.createdAt ?? '—', flex: 2, size: 11),
          mediaCell(
            rc,
            log.actor,
            flex: 2,
            sub: log.userRole,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: GlobalColors.accent.withValues(alpha: 0.15),
              child: Text(
                log.actor.isNotEmpty ? log.actor.substring(0, 1) : '؟',
                style: TextStyle(
                  color: GlobalColors.accentSoft,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StatusBadge(
            label: log.actionLabel ?? log.action ?? '—',
            color: actionColor(log),
          ),
          textCell(rc, log.description ?? '—', flex: 4, size: 11),
          textCell(rc, log.ipAddress ?? '—', size: 10),
          actionsCell([
            ActionBtn(
              icon: Icons.unfold_more_rounded,
              color: GlobalColors.blue,
              tooltip: 'ما الذي تغيّر',
              enabled: log.diff.isNotEmpty ||
                  log.granted.isNotEmpty ||
                  log.revoked.isNotEmpty,
              onTap: () => showAuditDiff(ctx, log),
            ),
          ], flex: 1),
        ],
      ),
    );
  }

  // ── Role editor ─────────────────────────────
  void _openRoleForm(BuildContext ctx, SettingsCubit c, {AccessRole? role}) {
    c.clearForm();
    if (role != null) c.loadForm(role);

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: _RoleForm(role: role),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ROLE FORM — نموذج الدور
// ─────────────────────────────────────────────
class _RoleForm extends StatefulWidget {
  const _RoleForm({this.role});

  final AccessRole? role;

  @override
  State<_RoleForm> createState() => _RoleFormState();
}

class _RoleFormState extends State<_RoleForm> {
  @override
  Widget build(BuildContext context) {
    final c = SettingsCubit.get(context);
    final isEdit = widget.role != null;

    return AppDialog<SettingsCubit>(
      title: isEdit ? 'تعديل «${widget.role!.displayName}»' : 'دور جديد',
      icon: Icons.admin_panel_settings_rounded,
      saveLabel: isEdit ? 'حفظ' : 'إنشاء',
      width: 760,
      onSave: () => c.saveRole(id: widget.role?.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dialogRow([
            AppField(
              controller: c.nameCont,
              label: 'اسم الدور *',
              icon: Icons.badge_rounded,
              hint: 'مثال: مشرف الحصص',
            ),
            AppField(
              controller: c.nameEnCont,
              label: 'Role name (English)',
              icon: Icons.translate_rounded,
            ),
          ]),
          gap,
          AppField(
            controller: c.descCont,
            label: 'الوصف',
            icon: Icons.description_rounded,
            hint: 'ما الذي يفعله صاحب هذا الدور؟',
          ),
          gap,

          if (widget.role?.isSystem ?? false)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: GlobalColors.gold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذا دور أساسي — يمكنك تعديل صلاحياته، لكن لا يمكن حذفه.',
                      style: TextStyle(
                        color: GlobalColors.textSecondary(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Text(
                'الصلاحيات',
                style: TextStyle(
                  color: GlobalColors.textPrimary(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${c.formPermissions.length} من ${c.allPermissions.length} مُفعّلة',
                style: TextStyle(
                  color: GlobalColors.textSecondary(context),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Capped and scrollable: ten sections of checkboxes would push the
          // save button off the bottom of the screen otherwise.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: SingleChildScrollView(
              child: Column(
                children: c.permissionGroups
                    .map((g) => _group(context, c, g.key, g.label))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(
    BuildContext context,
    SettingsCubit c,
    String key,
    String label,
  ) {
    final perms = c.permissionsIn(key);
    if (perms.isEmpty) return const SizedBox.shrink();

    final allOn = c.groupFullySelected(key);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: GlobalColors.bg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlobalColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ticking a whole section at once — building a role one
              // checkbox at a time across ten sections is the kind of thing
              // people give up halfway through.
              Checkbox(
                value: allOn,
                activeColor: GlobalColors.accent,
                onChanged: (v) => setState(() => c.toggleGroup(key, v ?? false)),
              ),
              Text(
                label,
                style: TextStyle(
                  color: GlobalColors.textPrimary(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: perms.map((p) {
              final on = c.formPermissions.contains(p.key);

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    setState(() => c.togglePermission(p.key!, !on)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: on
                        ? GlobalColors.accent.withValues(alpha: 0.16)
                        : GlobalColors.surface(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: on
                          ? GlobalColors.accent
                          : GlobalColors.border(context),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        on
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 14,
                        color: on
                            ? GlobalColors.accent
                            : GlobalColors.textSecondary(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        p.label ?? p.key ?? '',
                        style: TextStyle(
                          color: on
                              ? GlobalColors.textPrimary(context)
                              : GlobalColors.textSecondary(context),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
