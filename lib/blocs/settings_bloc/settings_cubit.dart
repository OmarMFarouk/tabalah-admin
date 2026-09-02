import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/paginated_model.dart';
import '../../models/settings_model.dart';
import '../../services/apis/api_client.dart';
import '../../services/apis/settings_api.dart';
import '../../src/app_globals.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  SETTINGS TABS — الأدوار وسجل النشاط
//  Who may do what, and a record of what they did.
// ─────────────────────────────────────────────
enum SettingsTab { roles, audit }

extension SettingsTabX on SettingsTab {
  String get label => switch (this) {
    SettingsTab.roles => 'الأدوار والصلاحيات',
    SettingsTab.audit => 'سجل النشاط',
  };

  IconData get icon => switch (this) {
    SettingsTab.roles => Icons.admin_panel_settings_rounded,
    SettingsTab.audit => Icons.history_rounded,
  };
}

class SettingsCubit extends Cubit<AppStates> {
  SettingsCubit() : super(AppInitial());
  static SettingsCubit get(context) => BlocProvider.of(context);

  final SettingsApi _api = SettingsApi();

  SettingsTab tab = SettingsTab.roles;

  // ── Roles ───────────────────────────────────
  List<AccessRole> roles = [];

  /// The catalogue, grouped for the editor. Fetched once per screen visit.
  List<AppPermission> allPermissions = [];
  List<({String key, String label})> permissionGroups = [];

  // ── Audit ───────────────────────────────────
  Paginated<AuditEntry> logs = Paginated(items: []);
  int page = 1;
  String? actionFilter;
  String? typeFilter;
  String? fromFilter;
  String? toFilter;
  final searchCont = TextEditingController();

  /// Filter options come from what is actually in the log, so the dropdowns
  /// never offer an action with no rows behind it.
  List<String> availableActions = [];
  List<String> availableTypes = [];

  // ── Role form ───────────────────────────────
  final nameCont = TextEditingController();
  final nameEnCont = TextEditingController();
  final descCont = TextEditingController();

  /// The permission keys ticked in the editor.
  Set<String> formPermissions = {};

  void clearForm() {
    nameCont.clear();
    nameEnCont.clear();
    descCont.clear();
    formPermissions = {};
  }

  void loadForm(AccessRole role) {
    nameCont.text = role.name ?? '';
    nameEnCont.text = role.nameEn ?? '';
    descCont.text = role.description ?? '';
    formPermissions = role.permissions.toSet();
  }

  void togglePermission(String key, bool on) {
    if (on) {
      formPermissions.add(key);
    } else {
      formPermissions.remove(key);
    }
    emit(AppLoaded());
  }

  /// Tick or clear a whole group at once — building a role one checkbox at a
  /// time across ten sections is the kind of thing people give up on.
  void toggleGroup(String group, bool on) {
    final keys = allPermissions
        .where((p) => p.group == group)
        .map((p) => p.key!)
        .toList();

    if (on) {
      formPermissions.addAll(keys);
    } else {
      formPermissions.removeAll(keys);
    }
    emit(AppLoaded());
  }

  bool groupFullySelected(String group) {
    final keys = allPermissions.where((p) => p.group == group).map((p) => p.key);
    return keys.isNotEmpty && keys.every(formPermissions.contains);
  }

  List<AppPermission> permissionsIn(String group) =>
      allPermissions.where((p) => p.group == group).toList();

  void switchTab(SettingsTab t) {
    tab = t;
    page = 1;
    emit(AppInitial());
    fetch();
  }

  void setPage(int p) {
    page = p;
    fetch();
  }

  void setFilter({String? action, String? type, String? from, String? to}) {
    if (action != null) actionFilter = action.isEmpty ? null : action;
    if (type != null) typeFilter = type.isEmpty ? null : type;
    if (from != null) fromFilter = from.isEmpty ? null : from;
    if (to != null) toFilter = to.isEmpty ? null : to;
    page = 1;
    fetch();
  }

  void clearFilters() {
    actionFilter = null;
    typeFilter = null;
    fromFilter = null;
    toFilter = null;
    searchCont.clear();
    page = 1;
    fetch();
  }

  void search() {
    page = 1;
    fetch();
  }

  Future<void> fetch() async {
    emit(AppLoading());

    switch (tab) {
      case SettingsTab.roles:
        // Both in parallel: the editor is useless without the catalogue, and
        // the list is useless without the roles.
        final results = await Future.wait([
          _api.fetchRoles(),
          _api.fetchPermissions(),
        ]);

        if (!results[0].success) return emit(AppFailure(msg: results[0].message));

        roles = Paginated.parse<AccessRole>(
          results[0]['roles'],
          AccessRole.fromJson,
        ).items;

        // Publish to the shared lookup the rest of the panel reads from.
        //
        // Without this the list was only loaded at sign-in, so a role
        // created here did not appear in the employee form — or the account
        // role dialog — until the app was restarted. This screen is the one
        // place roles change, so it is the right place to keep the copy
        // everyone else uses honest.
        AppGlobals.accessRoles = roles;

        if (results[1].success) {
          allPermissions = Paginated.parse<AppPermission>(
            results[1]['permissions'],
            AppPermission.fromJson,
          ).items;

          final groups = results[1]['groups'];
          if (groups is List) {
            permissionGroups = groups
                .whereType<Map>()
                .map(
                  (g) => (
                    key: g['key'].toString(),
                    label: g['label'].toString(),
                  ),
                )
                .toList();
          }
        }
        break;

      case SettingsTab.audit:
        final r = await _api.fetchAuditLogs(
          action: actionFilter,
          type: typeFilter,
          from: fromFilter,
          to: toFilter,
          q: searchCont.text.trim(),
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));

        logs = Paginated.read<AuditEntry>(r.body, 'logs', AuditEntry.fromJson);

        final filters = r['filters'];
        if (filters is Map) {
          availableActions =
              (filters['actions'] as List?)?.map((e) => e.toString()).toList() ??
              const [];
          availableTypes =
              (filters['types'] as List?)?.map((e) => e.toString()).toList() ??
              const [];
        }

        // The page fell off the end — a tighter filter, or entries aged out.
        if (logs.isOrphanedPage) {
          page = 1;
          return fetch();
        }
        break;
    }

    emit(AppLoaded());
  }

  // ── Writes ──────────────────────────────────
  Future<void> saveRole({int? id}) {
    final data = AccessRole(
      name: nameCont.text.trim(),
      nameEn: nameEnCont.text.trim(),
      description: descCont.text.trim(),
      permissions: formPermissions.toList()..sort(),
    ).toJson();

    return _write(
      () => id == null ? _api.createRole(data) : _api.updateRole(id, data),
      id == null ? 'تم إنشاء الدور.' : 'تم حفظ الدور.',
    );
  }

  Future<void> deleteRole(int id) =>
      _write(() => _api.deleteRole(id), 'تم حذف الدور.');

  Future<void> _write(Future<ApiResponse> Function() call, String okMsg) async {
    emit(AppBusy());
    final r = await call();
    if (r.success) {
      emit(AppSuccess(msg: okMsg));
      await fetch();
    } else {
      emit(AppFailure(msg: r.message));
    }
  }
}
