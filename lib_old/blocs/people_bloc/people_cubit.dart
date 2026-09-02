import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/paginated_model.dart';
import '../../models/users_model.dart';
import '../../services/apis/people_api.dart';
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
  String formRole = 'player';
  int? formSportId;
  String formStatus = 'active';
  int? promoteUserId;

  void clearForm() {
    for (final c in [
      nameCont,
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
    formSportId = null;
    formStatus = 'active';
    promoteUserId = null;
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
  Future<void> fetch() async {
    emit(AppLoading());
    final q = searchCont.text.trim();

    switch (tab) {
      case PeopleTab.accounts:
        final r = await _api.fetchUsers(role: roleFilter, q: q, page: page);
        if (!r.success) return emit(AppFailure(msg: r.message));
        users = Paginated.parse<User>(r['users'], User.fromJson);
        break;

      case PeopleTab.members:
        final r = await _api.fetchPlayers(q: q, page: page);
        if (!r.success) return emit(AppFailure(msg: r.message));
        players = Paginated.parse<PlayerProfile>(
          r['players'],
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
        trainers = Paginated.parse<TrainerProfile>(
          r['trainers'],
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
        employees = Paginated.parse<EmployeeProfile>(
          r['employees'],
          EmployeeProfile.fromJson,
        );
        break;
    }
    emit(AppLoaded());
  }

  // ── Accounts — الحسابات ─────────────────────
  Future<void> saveUser({int? id}) async {
    final data = <String, dynamic>{
      'name': nameCont.text.trim(),
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
        if (positionCont.text.isNotEmpty) {
          data['position'] = positionCont.text.trim();
        }
        if (salaryCont.text.isNotEmpty) {
          data['salary'] = double.tryParse(salaryCont.text);
        }
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
      () => id == null ? _api.createUser(data) : _api.updateUser(id, data),
      id == null ? 'تم إنشاء الحساب.' : 'تم حفظ التعديل.',
    );
  }

  Future<void> deleteUser(int id) =>
      _write(() => _api.deleteUser(id), 'تم حذف الحساب.');

  Future<void> setAvatar(int id, {String? filePath, String? url}) => _write(
    () => _api.setAvatar(id, filePath: filePath, avatarUrl: url),
    'تم تحديث الصورة.',
  );

  Future<void> removeAvatar(int id) =>
      _write(() => _api.removeAvatar(id), 'تم حذف الصورة.');

  // ── Members — الأعضاء ───────────────────────
  Future<void> savePlayer(int id) => _write(
    () => _api.updatePlayer(id, {
      if (heightCont.text.isNotEmpty) 'height': double.tryParse(heightCont.text),
      if (weightCont.text.isNotEmpty) 'weight': double.tryParse(weightCont.text),
      if (emergencyCont.text.isNotEmpty)
        'emergency_contact': emergencyCont.text.trim(),
    }),
    'تم تحديث بيانات العضو.',
  );

  // ── Trainers — المدربون ─────────────────────
  Future<void> saveTrainer({int? id}) async {
    if (id == null) {
      final data = {
        'name': nameCont.text.trim(),
        'email': emailCont.text.trim(),
        'password': passwordCont.text,
        'sport_id': formSportId,
        if (phoneCont.text.trim().isNotEmpty) 'phone': phoneCont.text.trim(),
        if (bioCont.text.trim().isNotEmpty) 'bio': bioCont.text.trim(),
        'status': formStatus,
      };
      await _write(() => _api.createTrainer(data), 'تم إضافة المدرب.');
    } else {
      final data = {
        if (formSportId != null) 'sport_id': formSportId,
        if (bioCont.text.trim().isNotEmpty) 'bio': bioCont.text.trim(),
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
      // Either promote an existing account, or hire inline.
      final data = promoteUserId != null
          ? {
              'user_id': promoteUserId,
              'position': positionCont.text.trim(),
              if (salaryCont.text.isNotEmpty)
                'salary': double.tryParse(salaryCont.text),
            }
          : {
              'name': nameCont.text.trim(),
              'email': emailCont.text.trim(),
              'password': passwordCont.text,
              if (phoneCont.text.trim().isNotEmpty)
                'phone': phoneCont.text.trim(),
              'role': 'employee',
              'position': positionCont.text.trim(),
              if (salaryCont.text.isNotEmpty)
                'salary': double.tryParse(salaryCont.text),
              'status': formStatus,
            };
      await _write(() => _api.createEmployee(data), 'تم تعيين الموظف.');
    } else {
      final data = {
        'position': positionCont.text.trim(),
        if (salaryCont.text.isNotEmpty)
          'salary': double.tryParse(salaryCont.text),
        if (nameCont.text.trim().isNotEmpty) 'name': nameCont.text.trim(),
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
