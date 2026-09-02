import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/paginated_model.dart';
import '../../models/settings_model.dart';
import '../../models/users_model.dart';
import '../../services/apis/people_api.dart';
import '../../services/apis/settings_api.dart';
import '../../src/app_globals.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  PEOPLE TABS — تبويبات الأشخاص
//  Accounts, members, coaches and staff are one
//  page: they're the same object seen four ways.
// ─────────────────────────────────────────────
enum PeopleTab { accounts, members, trainers, staff }

extension PeopleTabX on PeopleTab {
  String get label => switch (this) {
    PeopleTab.accounts => 'الحسابات',
    PeopleTab.members => 'الأعضاء',
    PeopleTab.trainers => 'المدربون',
    PeopleTab.staff => 'الموظفون',
  };

  IconData get icon => switch (this) {
    PeopleTab.accounts => Icons.manage_accounts_rounded,
    PeopleTab.members => Icons.people_alt_rounded,
    PeopleTab.trainers => Icons.sports_rounded,
    PeopleTab.staff => Icons.badge_rounded,
  };
}

class PeopleCubit extends Cubit<AppStates> {
  PeopleCubit() : super(AppInitial());
  static PeopleCubit get(context) => BlocProvider.of(context);

  final PeopleApi _api = PeopleApi();

  // ── Tab & filters — التبويب والفلاتر ────────
  PeopleTab tab = PeopleTab.accounts;
  final TextEditingController searchCont = TextEditingController();
  String? roleFilter;
  String? statusFilter;
  int? sportFilter;
  int page = 1;

  // ── Data — البيانات ─────────────────────────
  Paginated<User> users = Paginated(items: []);
  Paginated<PlayerProfile> players = Paginated(items: []);
  Paginated<TrainerProfile> trainers = Paginated(items: []);
  Paginated<EmployeeProfile> employees = Paginated(items: []);

  // ── Form controllers — حقول النموذج ─────────
  final nameCont = TextEditingController();
  // Optional English rendering of the person's name. Blank falls back to
  // the Arabic one server-side, so a half-filled form degrades to today's
  // behaviour rather than to a blank name in the member app.
  final nameEnCont = TextEditingController();
  final emailCont = TextEditingController();
  final phoneCont = TextEditingController();
  final passwordCont = TextEditingController();
  final bioCont = TextEditingController();
  final positionCont = TextEditingController();
  final salaryCont = TextEditingController();
  final heightCont = TextEditingController();
  final weightCont = TextEditingController();
  final emergencyCont = TextEditingController();
  final avatarUrlCont = TextEditingController();

  /// A picture chosen from disk but not uploaded yet. Nothing goes up until
  /// the form is saved, so cancelling leaves the account untouched — and on
  /// a new account there is no user id to upload against until the account
  /// itself exists.
  String? pendingAvatarPath;

  /// New accounts start by asking what kind of account it is. Everything
  /// below that answer differs — a coach needs a sport, a member needs
  /// their measurements — so asking first is what lets the rest of the form
  /// be about one thing.
  bool roleTypeChosen = false;

  /// The named role being assigned to a member of staff — the thing that
  /// decides their permissions. Null means "leave them on the tier
  /// defaults", which is what an account with no role assigned runs on.
  int? formAccessRoleId;

  /// Picks a role and renames the job title to match.
  ///
  /// The title defaults to the role's name and stays free text afterwards,
  /// so choosing a different role rewrites it to the new name — otherwise an
  /// employee moved from "المحاسب" to "المدير" keeps a title describing the
  /// job they no longer hold. It is written into the same field the operator
  /// can then edit, rather than applied invisibly on save, so if they want
  /// something else they can see what they are changing and type over it.
  void pickAccessRole(AccessRole? role) {
    formAccessRoleId = role?.id;

    final name = role?.name ?? role?.key;
    if (name != null && name.isNotEmpty) positionCont.text = name;

    emit(AppLoaded());
  }
  String formRole = 'player';
  int? formSportId;
  String formStatus = 'active';

  /// Whether the add form is promoting an existing account rather than
  /// creating one. Defaults to false: creating is the common case, and
  /// leading with a searchable dropdown made it look like the only case.

  void clearForm() {
    for (final c in [
      nameCont,
      nameEnCont,
      emailCont,
      phoneCont,
      passwordCont,
      bioCont,
      positionCont,
      salaryCont,
      heightCont,
      weightCont,
      emergencyCont,
      avatarUrlCont,
    ]) {
      c.clear();
    }
    formRole = 'player';
    roleTypeChosen = false;
    formAccessRoleId = null;
    pendingAvatarPath = null;
    formSportId = null;
    formStatus = 'active';
  }

  void switchTab(PeopleTab t) {
    tab = t;
    page = 1;
    searchCont.clear();
    roleFilter = null;
    statusFilter = null;
    sportFilter = null;
    emit(AppInitial());
    fetch();
  }

  void setPage(int p) {
    page = p;
    fetch();
  }

  void setFilter({String? role, String? status, int? sport, bool clear = false}) {
    if (clear) {
      roleFilter = null;
      statusFilter = null;
      sportFilter = null;
    } else {
      if (role != null) roleFilter = role == '' ? null : role;
      if (status != null) statusFilter = status == '' ? null : status;
      if (sport != null) sportFilter = sport == -1 ? null : sport;
    }
    page = 1;
    fetch();
  }

  // ── Read — القراءة ──────────────────────────

  Paginated get _active => switch (tab) {
    PeopleTab.accounts => users,
    PeopleTab.members => players,
    PeopleTab.trainers => trainers,
    PeopleTab.staff => employees,
  };

  // ── SEARCH — البحث ──────────────────────────
  //  A new query is a NEW result set. Page 3 of the old one is meaningless
  //  against it and the server rightly answers with nothing, which reads on
  //  screen as "no results" when there may be plenty on page 1. So every
  //  search starts from the first page; the pager takes over from there.
  void search() {
    page = 1;
    fetch();
  }

  Future<void> fetch() async {
    emit(AppLoading());
    final q = searchCont.text.trim();

    switch (tab) {
      case PeopleTab.accounts:
        final r = await _api.fetchUsers(role: roleFilter, q: q, page: page);
        if (!r.success) return emit(AppFailure(msg: r.message));
        users = Paginated.read<User>(r.body, 'users', User.fromJson);
        break;

      case PeopleTab.members:
        final r = await _api.fetchPlayers(q: q, page: page);
        if (!r.success) return emit(AppFailure(msg: r.message));
        players = Paginated.read<PlayerProfile>(
          r.body,
          'players',
          PlayerProfile.fromJson,
        );
        break;

      case PeopleTab.trainers:
        final r = await _api.fetchTrainers(
          sportId: sportFilter,
          status: statusFilter,
          q: q,
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        trainers = Paginated.read<TrainerProfile>(
          r.body,
          'trainers',
          TrainerProfile.fromJson,
        );
        AppGlobals.trainers = trainers.items;
        break;

      case PeopleTab.staff:
        final r = await _api.fetchEmployees(
          status: statusFilter,
          q: q,
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        employees = Paginated.read<EmployeeProfile>(
          r.body,
          'employees',
          EmployeeProfile.fromJson,
        );
        break;
    }
    // The page we asked for fell off the end of the result set — a narrower
    // search, a tighter filter, or a deletion. Land on page 1 rather than
    // showing an empty table over a non-zero total.
    if (_active.isOrphanedPage) {
      page = 1;
      return fetch();
    }
    emit(AppLoaded());
  }

  // ── Accounts — الحسابات ─────────────────────
  // ── Role assignment — إسناد الأدوار ─────────
  //  Deliberately its own call rather than a field on the edit form.
  //  Re-roling somebody is a different act from correcting their phone
  //  number: it changes what they can do, the server gates it through
  //  UserPolicy::assignRole, and it deserves its own confirmation. Sending
  //  only `role` also means a role change can't quietly carry along an
  //  edited field the operator didn't mean to save.
  Future<void> assignRole(int userId, int? roleId) async {
    emit(AppLoading());
    final r = await _api.updateUser(userId, {'role_id': roleId});
    if (!r.success) {
      emit(AppFailure(msg: r.message));
      return;
    }
    emit(AppSuccess(msg: r.message, shouldPop: true));
    await fetch();
  }

  Future<void> saveUser({int? id}) async {
    final data = <String, dynamic>{
      'name': nameCont.text.trim(),
      'name_en': nameEnCont.text.trim().isEmpty
          ? null
          : nameEnCont.text.trim(),
      if (phoneCont.text.trim().isNotEmpty) 'phone': phoneCont.text.trim(),
    };

    if (id == null) {
      data['email'] = emailCont.text.trim();
      data['password'] = passwordCont.text;
      data['role'] = formRole;
      // A trainer can't exist without a sport.
      if (formRole == 'trainer') data['sport_id'] = formSportId;
      if (formRole == 'trainer' && bioCont.text.isNotEmpty) {
        data['bio'] = bioCont.text.trim();
      }
      if (formRole == 'player') {
        if (heightCont.text.isNotEmpty) {
          data['height'] = double.tryParse(heightCont.text);
        }
        if (weightCont.text.isNotEmpty) {
          data['weight'] = double.tryParse(weightCont.text);
        }
        if (emergencyCont.text.isNotEmpty) {
          data['emergency_contact'] = emergencyCont.text.trim();
        }
      }
      if (formRole == 'admin' || formRole == 'employee') {
        // Left out when blank rather than sent empty: the server fills it
        // with the assigned role's name, which is the sensible day-one
        // title and saves the operator typing it twice.
        if (positionCont.text.isNotEmpty) {
          data['position'] = positionCont.text.trim();
        }
        if (salaryCont.text.isNotEmpty) {
          data['salary'] = double.tryParse(salaryCont.text);
        }
        if (formAccessRoleId != null) data['role_id'] = formAccessRoleId;
      }
    } else {
      if (weightCont.text.isNotEmpty) {
        data['weight'] = double.tryParse(weightCont.text);
      }
      if (heightCont.text.isNotEmpty) {
        data['height'] = double.tryParse(heightCont.text);
      }
    }

    await _write(
      () async => id == null
          ? _syncNewAvatar(await _api.createUser(data))
          : _api.updateUser(id, data),
      id == null ? 'تم إنشاء الحساب.' : 'تم حفظ التعديل.',
    );
  }

  /// Pulls the role list if login missed it — the roles endpoint is
  /// permission-gated, so an account that gained the permission mid-session
  /// would otherwise be stuck with an empty dropdown until it signed in again.
  Future<void> ensureAccessRoles() async {
    if (AppGlobals.accessRoles.isNotEmpty) return;

    final r = await SettingsApi().fetchRoles();
    if (!r.success) return;

    AppGlobals.accessRoles = Paginated.parse<AccessRole>(
      r['roles'],
      AccessRole.fromJson,
    ).items;
    emit(AppLoaded());
  }

  Future<void> deleteUser(int id) =>
      _write(() => _api.deleteUser(id), 'تم حذف الحساب.');

  /// Opens the OS file dialog and remembers the picture. Same contract as
  /// the catalogue's artwork picker: a file and a URL are two ways of saying
  /// the same thing and the server takes one, so choosing a file clears the
  /// URL field.
  Future<void> pickAvatarFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: false,
    );

    final path = result?.files.single.path;
    if (path == null) return;

    pendingAvatarPath = path;
    avatarUrlCont.clear();
    emit(AppLoaded());
  }

  void dropPickedAvatar() {
    pendingAvatarPath = null;
    emit(AppLoaded());
  }

  Future<void> setAvatar(int id, {String? filePath, String? url}) => _write(
    () => _api.setAvatar(id, filePath: filePath, avatarUrl: url),
    'تم تحديث الصورة.',
  );

  /// Uploads whatever the avatar field is holding onto a freshly created
  /// account, then reports the original result.
  ///
  /// The account has to exist before its picture can be attached — the
  /// avatar endpoint is keyed on a user id — so this runs as a second call
  /// rather than as a field on the create payload. A failure here is
  /// surfaced rather than swallowed: the account was still created, and an
  /// operator who picked a photo should be told it didn't stick.
  Future<dynamic> _syncNewAvatar(dynamic created) async {
    if (!created.success) return created;

    final path = pendingAvatarPath;
    final url = avatarUrlCont.text.trim();
    if (path == null && url.isEmpty) return created;

    final userId = asInt(created['user']?['user_id'] ?? created['user']?['id']);
    if (userId == null) return created;

    final r = await _api.setAvatar(
      userId,
      filePath: path,
      avatarUrl: url.isEmpty ? null : url,
    );

    return r.success ? created : r;
  }

  Future<void> removeAvatar(int id) =>
      _write(() => _api.removeAvatar(id), 'تم حذف الصورة.');

  // ── Parent portal — بوابة ولي الأمر ─────────
  //  `id` here is the players-table id, not the user id: both endpoints
  //  hang off /admin/players/{player}.
  Future<void> rotateGuardianCode(int playerId) => _write(
    () => _api.rotateGuardianCode(playerId),
    'تم إنشاء كود جديد لولي الأمر.',
  );

  Future<void> setGuardianAccess(int playerId, bool enabled) => _write(
    () => _api.setGuardianAccess(playerId, enabled),
    enabled ? 'تم تفعيل بوابة ولي الأمر.' : 'تم إيقاف بوابة ولي الأمر.',
  );

  // ── Members — الأعضاء ───────────────────────
  /// Physical details only — the account behind the member is edited from
  /// the accounts tab.
  Future<void> savePlayer(int id) => _write(
    () => _api.updatePlayer(id, {
      if (heightCont.text.isNotEmpty) 'height': double.tryParse(heightCont.text),
      if (weightCont.text.isNotEmpty) 'weight': double.tryParse(weightCont.text),
      if (emergencyCont.text.isNotEmpty)
        'emergency_contact': emergencyCont.text.trim(),
    }),
    'تم تحديث بيانات العضو.',
  );

  /// Add a member in one step.
  ///
  /// Signing somebody up at the desk used to take two screens: create the
  /// account somewhere else, then come back and find it in a dropdown.
  /// Always creates the account alongside the member. Attaching a member
  /// profile to an existing login was a second path through this form that
  /// nobody used, and it has been removed.
  Future<void> createPlayer() {
    final data = <String, dynamic>{
      if (heightCont.text.isNotEmpty) 'height': double.tryParse(heightCont.text),
      if (weightCont.text.isNotEmpty) 'weight': double.tryParse(weightCont.text),
      if (emergencyCont.text.trim().isNotEmpty)
        'emergency_contact': emergencyCont.text.trim(),
    };

    {
      data['name'] = nameCont.text.trim();
      data['name_en'] = nameEnCont.text.trim().isEmpty
          ? null
          : nameEnCont.text.trim();
      data['email'] = emailCont.text.trim();
      data['password'] = passwordCont.text;
      if (phoneCont.text.trim().isNotEmpty) {
        data['phone'] = phoneCont.text.trim();
      }
    }

    return _write(() => _api.createPlayer(data), 'تمت إضافة العضو.');
  }

  // ── Trainers — المدربون ─────────────────────
  Future<void> saveTrainer({int? id}) async {
    if (id == null) {
      final data = {
        'name': nameCont.text.trim(),
        'name_en': nameEnCont.text.trim().isEmpty
            ? null
            : nameEnCont.text.trim(),
        'email': emailCont.text.trim(),
        'password': passwordCont.text,
        'sport_id': formSportId,
        if (phoneCont.text.trim().isNotEmpty) 'phone': phoneCont.text.trim(),
        if (bioCont.text.trim().isNotEmpty) 'bio': bioCont.text.trim(),
        'status': formStatus,
      };
      await _write(() => _api.createTrainer(data), 'تم إضافة المدرب.');
    } else {
      // Everything the trainer endpoint accepts, so the edit dialog can
      // reach all of it. `bio` and `phone` go out even when blank — that is
      // how the form clears them — while `email` and `password` are only
      // sent when filled, since the server treats them as required-if-present.
      final data = {
        if (formSportId != null) 'sport_id': formSportId,
        'bio': bioCont.text.trim(),
        if (nameCont.text.trim().isNotEmpty) 'name': nameCont.text.trim(),
        'name_en': nameEnCont.text.trim().isEmpty
            ? null
            : nameEnCont.text.trim(),
        if (emailCont.text.trim().isNotEmpty) 'email': emailCont.text.trim(),
        'phone': phoneCont.text.trim(),
        if (passwordCont.text.isNotEmpty) 'password': passwordCont.text,
        'status': formStatus,
      };
      await _write(() => _api.updateTrainer(id, data), 'تم حفظ التعديل.');
    }
  }

  Future<void> deleteTrainer(int id) =>
      _write(() => _api.deleteTrainer(id), 'تم حذف المدرب.');

  // ── Staff — الموظفون ────────────────────────
  Future<void> saveEmployee({int? id}) async {
    if (id == null) {
      final data = {
        'name': nameCont.text.trim(),
        'name_en': nameEnCont.text.trim().isEmpty
            ? null
            : nameEnCont.text.trim(),
        'email': emailCont.text.trim(),
        'password': passwordCont.text,
        if (phoneCont.text.trim().isNotEmpty) 'phone': phoneCont.text.trim(),
        'role': 'employee',
        // Blank means "name it after the role" — the server does that.
        if (positionCont.text.trim().isNotEmpty)
          'position': positionCont.text.trim(),
        if (salaryCont.text.isNotEmpty)
          'salary': double.tryParse(salaryCont.text),
        if (formAccessRoleId != null) 'role_id': formAccessRoleId,
        'status': formStatus,
      };
      await _write(() => _api.createEmployee(data), 'تم تعيين الموظف.');
    } else {
      final data = {
        'position': positionCont.text.trim(),
        if (salaryCont.text.isNotEmpty)
          'salary': double.tryParse(salaryCont.text),
        if (nameCont.text.trim().isNotEmpty) 'name': nameCont.text.trim(),
        'name_en': nameEnCont.text.trim().isEmpty
            ? null
            : nameEnCont.text.trim(),
        if (formAccessRoleId != null) 'role_id': formAccessRoleId,
        'status': formStatus,
      };
      await _write(() => _api.updateEmployee(id, data), 'تم حفظ التعديل.');
    }
  }

  // Demote keeps the login; deleteUser removes the account entirely.
  Future<void> deleteEmployee(int id, {bool deleteUser = false}) => _write(
    () => _api.deleteEmployee(id, deleteUser: deleteUser),
    deleteUser ? 'تم حذف الحساب.' : 'تم إنهاء التعيين مع الإبقاء على الحساب.',
  );

  // ── Shared write path — مسار الكتابة ────────
  Future<void> _write(Future Function() call, String okMsg) async {
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
