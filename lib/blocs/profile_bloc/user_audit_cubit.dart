import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/paginated_model.dart';
import '../../models/settings_model.dart';
import '../../services/apis/settings_api.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  USER AUDIT — سجل نشاط الحساب
//
//  The same trail the settings screen shows,
//  pinned to one account. Its own cubit rather
//  than a flag on SettingsCubit: that one owns a
//  whole screen — roles, the permission
//  catalogue, its own tab state — and a modal
//  opened over a profile has no business
//  carrying any of it.
//
//  `user_id` is fixed for the lifetime of the
//  cubit. Everything else — the search box, the
//  action and type dropdowns, the date range —
//  narrows within that one account rather than
//  across the club.
// ─────────────────────────────────────────────
class UserAuditCubit extends Cubit<AppStates> {
  UserAuditCubit(this.userId) : super(AppInitial());

  static UserAuditCubit get(BuildContext context) => BlocProvider.of(context);

  final int userId;
  final SettingsApi _api = SettingsApi();

  Paginated<AuditEntry> logs = Paginated(items: []);
  int page = 1;

  String? actionFilter;
  String? typeFilter;
  String? fromFilter;
  String? toFilter;
  final searchCont = TextEditingController();

  /// Offered by the server from what is actually in this account's trail, so
  /// the dropdowns never list an action with no rows behind it.
  List<String> availableActions = [];
  List<String> availableTypes = [];

  bool get hasFilters =>
      actionFilter != null ||
      typeFilter != null ||
      fromFilter != null ||
      toFilter != null ||
      searchCont.text.trim().isNotEmpty;

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

    final r = await _api.fetchAuditLogs(
      userId: userId,
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

    emit(AppLoaded());
  }

  @override
  Future<void> close() {
    searchCont.dispose();
    return super.close();
  }
}
