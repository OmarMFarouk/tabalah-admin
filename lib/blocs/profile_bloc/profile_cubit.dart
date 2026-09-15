import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/catalog_model.dart';
import '../../models/finance_model.dart';
import '../../models/hr_model.dart';
import '../../models/paginated_model.dart';
import '../../models/performance_model.dart';
import '../../models/profile_model.dart';
import '../../models/sessions_model.dart';
import '../../services/apis/hr_api.dart';
import '../../services/apis/profile_api.dart';
import '../../src/app_globals.dart';
import '../../src/app_presets.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  PROFILE CUBIT — كيوبت الملف الشخصي
//  One account's profile over a chosen period:
//  the summary, and each tab's rows loaded the
//  first time that tab is opened.
// ─────────────────────────────────────────────

enum ProfileRange { month, quarter, year, all, custom }

extension ProfileRangeX on ProfileRange {
  String get label => switch (this) {
    ProfileRange.month => 'هذا الشهر',
    ProfileRange.quarter => 'آخر 3 أشهر',
    ProfileRange.year => 'هذه السنة',
    ProfileRange.all => 'كل الفترات',
    ProfileRange.custom => 'فترة مخصصة',
  };
}

class ProfileCubit extends Cubit<AppStates> {
  ProfileCubit(this.userId) : super(AppInitial()) {
    _setRange(ProfileRange.quarter);
  }

  final int userId;
  final ProfileApi _api = ProfileApi();

  UserProfile profile = const UserProfile();

  ProfileRange range = ProfileRange.quarter;
  String? from;
  String? to;

  /// Loaded pages by tab key. A tab missing here has not been opened yet
  /// for the current period.
  final Map<String, Paginated<dynamic>> sections = {};
  final Set<String> loadingSections = {};
  String? activeTab;

  // ── Enrolment form — نموذج الاشتراك ─────────
  int? formMembershipId;
  bool collectPayment = true;
  String formPaymentStatus = 'success';
  int? formSourceId;
  final TextEditingController amountCont = TextEditingController();
  final TextEditingController startCont = TextEditingController();
  final TextEditingController notesCont = TextEditingController();

  @override
  Future<void> close() {
    amountCont.dispose();
    startCont.dispose();
    notesCont.dispose();
    return super.close();
  }

  // ── Period ──────────────────────────────────

  void _setRange(ProfileRange r, {DateTimeRange? custom}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    range = r;
    final start = switch (r) {
      ProfileRange.month => DateTime(now.year, now.month, 1),
      ProfileRange.quarter => today.subtract(const Duration(days: 90)),
      ProfileRange.year => DateTime(now.year, 1, 1),
      ProfileRange.all => null,
      ProfileRange.custom => custom?.start,
    };
    final end = switch (r) {
      ProfileRange.all => null,
      ProfileRange.custom => custom?.end,
      _ => today,
    };

    from = start == null ? null : AppPresets.date(start);
    to = end == null ? null : AppPresets.date(end);
  }

  /// Everything on the screen describes the chosen period, so changing it
  /// refetches the summary and forgets every loaded tab.
  Future<void> applyRange(ProfileRange r, {DateTimeRange? custom}) {
    _setRange(r, custom: custom);
    return fetch();
  }

  // ── Loading ─────────────────────────────────

  Future<void> fetch() async {
    emit(AppLoading());
    final r = await _api.fetchProfile(userId, from: from, to: to);
    if (!r.success) return emit(AppFailure(msg: r.message));

    profile = UserProfile.fromJson(r.body);
    sections.clear();
    if (activeTab == null || !profile.tabs.contains(activeTab)) {
      activeTab = profile.tabs.firstOrNull;
    }
    emit(AppLoaded());

    if (activeTab != null) await loadSection(activeTab!);
  }

  Future<void> openTab(String key) async {
    activeTab = key;
    if (!sections.containsKey(key)) await loadSection(key);
  }

  Future<void> loadSection(String key, {int page = 1}) async {
    loadingSections.add(key);
    emit(AppLoaded());

    final r = await _api.fetchSection(userId, key, from: from, to: to, page: page);
    loadingSections.remove(key);
    if (!r.success) return emit(AppFailure(msg: r.message));

    sections[key] = Paginated.read<dynamic>(r.body, 'items', _parserFor(key));
    emit(AppLoaded());
  }

  static dynamic Function(Map<String, dynamic>) _parserFor(String key) =>
      switch (key) {
        'enrollments' => (m) => Enrollment.fromJson(m),
        'attendances' => (m) => Attendance.fromJson(m),
        'payments' => (m) => Payment.fromJson(m),
        'sessions' => (m) => ClubSession.fromJson(m),
        'ratings' || 'assessments_given' => (m) => SessionRating.fromJson(m),
        'overtime' => (m) => OvertimeRecord.fromJson(m),
        'kpi_records' => (m) => KpiRecord.fromJson(m),
        'salaries' => (m) => Salary.fromJson(m),
        'employee_attendances' => (m) => EmployeeClockIn.fromJson(m),
        _ => (m) => m,
      };

  // ── Employment letter — خطاب التعريف ───────

  /// Opens the printable letter in the browser, through a link the server
  /// signs for thirty minutes. The browser's own "Save as PDF" makes the file.
  Future<void> openEmploymentLetter() async {
    emit(AppBusy());
    final r = await HrApi().employmentLetter(userId);
    final url = r.success ? asString(r.body['url']) : null;
    if (url == null) return emit(AppFailure(msg: r.message));

    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    emit(
      opened
          ? AppSuccess(msg: 'فُتح الخطاب في المتصفح — اطبعه أو احفظه PDF.', shouldPop: false)
          : AppFailure(msg: 'تعذّر فتح المتصفح.'),
    );
  }

  // ── Enrolment ───────────────────────────────

  void resetEnrollForm() {
    formMembershipId = null;
    collectPayment = true;
    formPaymentStatus = 'success';
    formSourceId = AppGlobals.paymentSources
        .where((s) => s.isDefault)
        .map((s) => s.id)
        .firstOrNull;
    amountCont.clear();
    startCont.clear();
    notesCont.clear();
  }

  /// Pre-fills the amount from the membership price the moment one is
  /// picked, so the desk only types when the price is being overridden.
  void pickMembership(int? id) {
    formMembershipId = id;
    final m = AppGlobals.memberships.where((m) => m.id == id).firstOrNull;
    if (m?.price != null) amountCont.text = m!.price!.toStringAsFixed(2);
    emit(AppLoaded());
  }

  Future<void> submitEnrollment() async {
    if (formMembershipId == null) {
      emit(AppFailure(msg: 'يجب اختيار الباقة.'));
      return;
    }

    emit(AppBusy());
    final r = await _api.enroll(
      userId: userId,
      membershipId: formMembershipId!,
      collectPayment: collectPayment,
      startDate: startCont.text.trim(),
      amount: double.tryParse(amountCont.text.trim()),
      paymentSourceId: formSourceId,
      paymentStatus: formPaymentStatus,
      notes: notesCont.text.trim(),
    );

    if (!r.success) {
      emit(AppFailure(msg: r.message));
      return;
    }

    emit(AppSuccess(msg: r.message, shouldPop: true));
    await fetch();
  }

  Future<void> setEnrollmentStatus(dynamic id, String status) async {
    emit(AppBusy());
    final r = await _api.setEnrollmentStatus(id, status);
    if (!r.success) {
      emit(AppFailure(msg: r.message));
      return;
    }
    emit(AppSuccess(msg: r.message, shouldPop: false));
    await fetch();
  }
}
