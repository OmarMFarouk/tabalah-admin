import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/catalog_model.dart';
import '../../models/paginated_model.dart';
import '../../services/apis/catalog_api.dart';
import '../../src/app_globals.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  CATALOG TABS — تبويبات العروض
//  A sport holds memberships; a membership holds
//  schedules. One page, three depths.
// ─────────────────────────────────────────────
enum CatalogTab { memberships, sports, schedules }

extension CatalogTabX on CatalogTab {
  String get label => switch (this) {
    CatalogTab.memberships => 'الاشتراكات',
    CatalogTab.sports => 'الرياضات',
    CatalogTab.schedules => 'المواعيد',
  };

  IconData get icon => switch (this) {
    CatalogTab.memberships => Icons.card_membership_rounded,
    CatalogTab.sports => Icons.sports_soccer_rounded,
    CatalogTab.schedules => Icons.event_repeat_rounded,
  };
}

class CatalogCubit extends Cubit<AppStates> {
  CatalogCubit() : super(AppInitial());
  static CatalogCubit get(context) => BlocProvider.of(context);

  final CatalogApi _api = CatalogApi();

  CatalogTab tab = CatalogTab.memberships;
  final TextEditingController searchCont = TextEditingController();
  int? sportFilter;
  int? trainerFilter;
  String? statusFilter;
  int? scheduleMembershipFilter;
  int page = 1;

  Paginated<Membership> memberships = Paginated(items: []);
  Paginated<Sport> sports = Paginated(items: []);
  Paginated<MembershipSchedule> schedules = Paginated(items: []);

  // ── Form controllers — حقول النموذج ─────────
  final nameCont = TextEditingController();
  final descCont = TextEditingController();
  final imageCont = TextEditingController();
  final priceCont = TextEditingController();
  final durationCont = TextEditingController();
  final maxAttendeesCont = TextEditingController();
  int? formSportId;
  int? formTrainerId;
  String formType = 'scheduled';
  String formStatus = 'active';

  // Schedule form — نموذج الموعد
  int? schedMembershipId;
  String schedType = 'weekly';
  String schedDay = 'saturday';
  String? schedDate;
  TimeOfDay schedStart = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay schedEnd = const TimeOfDay(hour: 18, minute: 30);

  void clearForm() {
    for (final c in [
      nameCont,
      descCont,
      imageCont,
      priceCont,
      durationCont,
      maxAttendeesCont,
    ]) {
      c.clear();
    }
    formSportId = null;
    formTrainerId = null;
    formType = 'scheduled';
    formStatus = 'active';
  }

  void switchTab(CatalogTab t) {
    tab = t;
    page = 1;
    searchCont.clear();
    emit(AppInitial());
    fetch();
  }

  void setPage(int p) {
    page = p;
    fetch();
  }

  void setFilter({int? sport, int? trainer, String? status, int? membership}) {
    if (sport != null) sportFilter = sport == -1 ? null : sport;
    if (trainer != null) trainerFilter = trainer == -1 ? null : trainer;
    if (status != null) statusFilter = status == '' ? null : status;
    if (membership != null) {
      scheduleMembershipFilter = membership == -1 ? null : membership;
    }
    page = 1;
    fetch();
  }

  Future<void> fetch() async {
    emit(AppLoading());
    final q = searchCont.text.trim();

    switch (tab) {
      case CatalogTab.memberships:
        final r = await _api.fetchMemberships(
          sportId: sportFilter,
          trainerId: trainerFilter,
          status: statusFilter,
          q: q,
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        memberships = Paginated.parse<Membership>(
          r['memberships'],
          Membership.fromJson,
        );
        AppGlobals.memberships = memberships.items;
        break;

      case CatalogTab.sports:
        final r = await _api.fetchSports(q: q, page: page);
        if (!r.success) return emit(AppFailure(msg: r.message));
        sports = Paginated.parse<Sport>(r['sports'], Sport.fromJson);
        AppGlobals.sports = sports.items;
        break;

      case CatalogTab.schedules:
        final r = await _api.fetchSchedules(
          membershipId: scheduleMembershipFilter,
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        schedules = Paginated.parse<MembershipSchedule>(
          r['membership_schedules'],
          MembershipSchedule.fromJson,
        );
        break;
    }
    emit(AppLoaded());
  }

  // ── Sports — الرياضات ───────────────────────
  Future<void> saveSport({int? id}) {
    final data = Sport(
      name: nameCont.text.trim(),
      description: descCont.text.trim(),
      image: imageCont.text.trim().isEmpty ? null : imageCont.text.trim(),
    ).toJson();
    return _write(
      () => id == null ? _api.createSport(data) : _api.updateSport(id, data),
      id == null ? 'تمت إضافة الرياضة.' : 'تم حفظ التعديل.',
    );
  }

  // Deleting a sport cascades to its trainers and memberships.
  Future<void> deleteSport(int id) =>
      _write(() => _api.deleteSport(id), 'تم حذف الرياضة.');

  // ── Memberships — الاشتراكات ────────────────
  Future<void> saveMembership({int? id}) {
    final data = Membership(
      name: nameCont.text.trim(),
      description: descCont.text.trim(),
      trainerId: formTrainerId,
      sportId: formSportId,
      price: double.tryParse(priceCont.text) ?? 0,
      // Blank means open-ended / uncapped.
      durationDays: durationCont.text.trim().isEmpty
          ? null
          : int.tryParse(durationCont.text),
      maxAttendees: maxAttendeesCont.text.trim().isEmpty
          ? null
          : int.tryParse(maxAttendeesCont.text),
      type: formType,
      status: formStatus,
    ).toJson();

    return _write(
      () => id == null
          ? _api.createMembership(data)
          : _api.updateMembership(id, data),
      id == null ? 'تمت إضافة الاشتراك.' : 'تم حفظ التعديل.',
    );
  }

  // Cascades to schedules, sessions and enrollments.
  Future<void> deleteMembership(int id) =>
      _write(() => _api.deleteMembership(id), 'تم حذف الاشتراك.');

  // ── Schedules — المواعيد ────────────────────
  Future<void> saveSchedule({int? id}) {
    final data = MembershipSchedule(
      membershipId: schedMembershipId,
      scheduleType: schedType,
      dayOfWeek: schedDay,
      specificDate: schedDate,
      startTime: _fmt(schedStart),
      endTime: _fmt(schedEnd),
    ).toJson();

    return _write(
      () => id == null
          ? _api.createSchedule(data)
          : _api.updateSchedule(id, {
              'start_time': _fmt(schedStart),
              'end_time': _fmt(schedEnd),
            }),
      id == null ? 'تمت إضافة الموعد.' : 'تم حفظ الموعد.',
    );
  }

  Future<void> deleteSchedule(int id) =>
      _write(() => _api.deleteSchedule(id), 'تم حذف الموعد.');

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
