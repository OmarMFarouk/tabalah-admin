import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/catalog_model.dart';
import '../../models/paginated_model.dart';
import '../../services/apis/api_client.dart';
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

  // The English rendering members see when they run the app in English.
  // Optional: left blank, the backend falls back to the Arabic copy, so a
  // half-filled form degrades to today's behaviour rather than to a blank
  // card in the member app.
  final nameEnCont = TextEditingController();
  final descEnCont = TextEditingController();

  final imageCont = TextEditingController();
  final priceCont = TextEditingController();
  final durationCont = TextEditingController();
  final maxAttendeesCont = TextEditingController();
  int? formSportId;
  int? formTrainerId;
  String formType = 'scheduled';
  String formStatus = 'active';

  /// The icon key picked in the sport form. Null means "no icon" — the
  /// clients then draw their neutral fallback glyph.
  String? formIcon;

  /// A file chosen from disk, waiting to be uploaded once the row exists.
  /// Artwork is a second request (multipart), so on a *create* it can only
  /// be sent after the create returns an id.
  String? pendingImagePath;

  /// Set when the admin hits "remove image" so the save can clear it.
  bool clearImage = false;

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
      nameEnCont,
      descEnCont,
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
    formIcon = null;
    pendingImagePath = null;
    clearImage = false;
  }

  /// Opens the OS file dialog and remembers the chosen picture. Nothing is
  /// uploaded here — the file goes up when the form is saved, so cancelling
  /// the dialog leaves the row untouched.
  Future<void> pickImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: false,
    );

    final path = result?.files.single.path;
    if (path == null) return;

    pendingImagePath = path;
    // A file and a URL are two ways to say the same thing, and the backend
    // rejects both at once — picking a file therefore drops any URL typed
    // into the field, and vice versa.
    imageCont.clear();
    clearImage = false;
    emit(AppLoaded());
  }

  void dropPickedImage() {
    pendingImagePath = null;
    emit(AppLoaded());
  }

  /// Marks the existing artwork for removal on save.
  void markImageForRemoval() {
    clearImage = true;
    pendingImagePath = null;
    imageCont.clear();
    emit(AppLoaded());
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


  // The list the current tab is showing, for the orphaned-page check.
  Paginated get _active => switch (tab) {
    CatalogTab.memberships => memberships,
    CatalogTab.sports => sports,
    CatalogTab.schedules => schedules,
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
      case CatalogTab.memberships:
        final r = await _api.fetchMemberships(
          sportId: sportFilter,
          trainerId: trainerFilter,
          status: statusFilter,
          q: q,
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        memberships = Paginated.read<Membership>(
          r.body,
          'memberships',
          Membership.fromJson,
        );
        AppGlobals.memberships = memberships.items;
        break;

      case CatalogTab.sports:
        final r = await _api.fetchSports(q: q, page: page);
        if (!r.success) return emit(AppFailure(msg: r.message));
        sports = Paginated.read<Sport>(r.body, 'sports', Sport.fromJson);
        AppGlobals.sports = sports.items;
        break;

      case CatalogTab.schedules:
        final r = await _api.fetchSchedules(
          membershipId: scheduleMembershipFilter,
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        // MembershipScheduleController answers with `schedules`, not
        // `membership_schedules` — reading the wrong key is why this tab came
        // back empty however many rows the server actually sent.
        schedules = Paginated.read<MembershipSchedule>(
          r.body,
          'schedules',
          MembershipSchedule.fromJson,
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

  // ── Sports — الرياضات ───────────────────────
  Future<void> saveSport({int? id}) {
    final data = Sport(
      name: nameCont.text.trim(),
      nameEn: nameEnCont.text.trim(),
      description: descCont.text.trim(),
      descriptionEn: descEnCont.text.trim(),
      icon: formIcon,
    ).toJson();

    return _write(
      () async {
        final res = id == null
            ? await _api.createSport(data)
            : await _api.updateSport(id, data);
        if (!res.success) return res;

        // A create has no id until now, which is why artwork is a second
        // request rather than a field on the form payload.
        final sportId = id ?? asInt(res['sport']?['id']);
        return _syncImage(
          sportId,
          set: (target, {filePath, imageUrl}) => _api.setSportImage(
            target,
            filePath: filePath,
            imageUrl: imageUrl,
          ),
          clear: _api.clearSportImage,
          fallback: res,
        );
      },
      id == null ? 'تمت إضافة الرياضة.' : 'تم حفظ التعديل.',
    );
  }

  /// Applies whatever the form said about artwork — a picked file, a typed
  /// URL, an explicit removal, or nothing at all.
  ///
  /// A failure here is reported, but the row itself has already been saved:
  /// telling the admin "the sport saved, the picture didn't" beats implying
  /// the whole thing failed and having them re-type the form.
  Future<ApiResponse> _syncImage(
    int? id, {
    required Future<ApiResponse> Function(
      dynamic id, {
      String? filePath,
      String? imageUrl,
    })
    set,
    required Future<ApiResponse> Function(dynamic id) clear,
    required ApiResponse fallback,
  }) async {
    if (id == null) return fallback;

    final url = imageCont.text.trim();

    if (pendingImagePath != null) {
      return set(id, filePath: pendingImagePath);
    }
    if (url.isNotEmpty) {
      return set(id, imageUrl: url);
    }
    if (clearImage) {
      return clear(id);
    }
    return fallback;
  }

  // Deleting a sport cascades to its trainers and memberships.
  Future<void> deleteSport(int id) =>
      _write(() => _api.deleteSport(id), 'تم حذف الرياضة.');

  // ── Memberships — الاشتراكات ────────────────
  Future<void> saveMembership({int? id}) {
    final data = Membership(
      name: nameCont.text.trim(),
      nameEn: nameEnCont.text.trim(),
      description: descCont.text.trim(),
      descriptionEn: descEnCont.text.trim(),
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
      () async {
        final res = id == null
            ? await _api.createMembership(data)
            : await _api.updateMembership(id, data);
        if (!res.success) return res;

        final membershipId = id ?? asInt(res['membership']?['id']);
        return _syncImage(
          membershipId,
          set: (target, {filePath, imageUrl}) => _api.setMembershipImage(
            target,
            filePath: filePath,
            imageUrl: imageUrl,
          ),
          clear: _api.clearMembershipImage,
          fallback: res,
        );
      },
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
