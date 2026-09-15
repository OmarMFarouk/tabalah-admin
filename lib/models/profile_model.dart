import 'paginated_model.dart';
import 'users_model.dart';

// ─────────────────────────────────────────────
//  USER PROFILE — الملف الشخصي
//  The summary half of the profile screen:
//  `GET /admin/users/{id}/profile?from=&to=`.
//  Each tab's rows are paged separately through
//  `/profile/{section}`, and `tabs` is exactly the
//  set this viewer is allowed to open.
// ─────────────────────────────────────────────

class UserProfile {
  final User? user;
  final String role;
  final ProfileStats stats;
  final List<String> tabs;

  const UserProfile({
    this.user,
    this.role = '',
    this.stats = const ProfileStats({}),
    this.tabs = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final rawTabs = json['tabs'];

    return UserProfile(
      // UserResource is the one resource that prefixes its keys (user_name,
      // user_role, ...). User.fromJson runs them through unprefix itself.
      user: rawUser is Map ? User.fromJson(Map<String, dynamic>.from(rawUser)) : null,
      role: asString(json['role']) ?? '',
      stats: ProfileStats(
        json['stats'] is Map ? Map<String, dynamic>.from(json['stats']) : const {},
      ),
      tabs: rawTabs is List ? rawTabs.map((e) => e.toString()).toList() : const [],
    );
  }

  bool get isPlayer => role == 'player';
  bool get isTrainer => role == 'trainer';
  bool get isEmployee => role == 'employee';
  bool get isAdminRole => role == 'admin' || role == 'super-admin';
  bool get isStaff => role == 'employee' || role == 'admin' || role == 'super-admin';
}

// ─────────────────────────────────────────────
//  PROFILE STATS — الإحصائيات
//  Deliberately a loose map: the server sends a
//  different set per role, and omits whatever the
//  viewer may not see (money, pay, HR). [has]
//  tells the screen whether to draw a card at all.
// ─────────────────────────────────────────────

class ProfileStats {
  final Map<String, dynamic> raw;
  const ProfileStats(this.raw);

  int intOf(String key) => asInt(raw[key]) ?? 0;
  double doubleOf(String key) => asDouble(raw[key]) ?? 0;
  String? stringOf(String key) => asString(raw[key]);
  bool has(String key) => raw.containsKey(key);

  // ── Player ─────────────────────────────────
  /// Null when the member has no attendance recorded yet — which is not the
  /// same as 0%, and the UI shows a dash rather than a damning zero.
  double? get attendanceRate => asDouble(raw['attendance_rate']);
  int get presentCount => intOf('present_count');
  int get lateCount => intOf('late_count');
  int get absentCount => intOf('absent_count');
  int get excusedCount => intOf('excused_count');
  int get sessionsRecorded => intOf('sessions_recorded');
  int get enrollmentsCount => intOf('enrollments_count');
  int get activeEnrollmentsCount => intOf('active_enrollments_count');
  int get pendingPaymentEnrollments => intOf('pending_payment_enrollments');
  String? get currentMembership => stringOf('current_membership');
  int? get currentEnrollmentId => asInt(raw['current_enrollment_id']);
  String? get currentEndsAt => asDate(raw['current_ends_at']);
  int? get daysRemaining => asInt(raw['days_remaining']);
  double get totalPaid => doubleOf('total_paid');
  double get pendingAmount => doubleOf('pending_amount');

  // ── Ratings (everyone) ─────────────────────
  int get ratingsCount => intOf('ratings_count');
  double? get averageRating => asDouble(raw['average_rating']);

  // ── Trainer ────────────────────────────────
  int get membershipsCount => intOf('memberships_count');
  int get playersCount => intOf('players_count');
  int get sessionsCount => intOf('sessions_count');
  int get upcomingSessionsCount => intOf('upcoming_sessions_count');
  int get completedSessionsCount => intOf('completed_sessions_count');
  int get assessmentsGivenCount => intOf('assessments_given_count');

  // ── Payroll (trainers and staff) ───────────
  int get attendanceDays => intOf('attendance_days');
  String? get lastCheckInAt => asDateTime(raw['last_check_in_at']);
  double get overtimeHours => doubleOf('overtime_hours');
  int get kpiRecordsCount => intOf('kpi_records_count');
  double? get averageAchievement => asDouble(raw['average_achievement']);
  int get salariesCount => intOf('salaries_count');
  double get salariesTotal => doubleOf('salaries_total');

  // ── Derived ────────────────────────────────
  /// Membership state as the front desk thinks of it, not as the DB stores
  /// it. 'expired' is not a stored status — an enrolment stays 'active' with
  /// a past end date — so it's worked out here from the remaining days.
  String get membershipStateAr {
    if (currentMembership == null) return 'لا يوجد اشتراك نشط';
    final d = daysRemaining;
    if (d == null) return 'نشط';
    if (d <= 0) return 'منتهٍ';
    if (d <= 7) return 'ينتهي خلال $d يوم';
    return 'نشط — $d يوم متبقٍ';
  }
}

/// One GPS clock-in, as the panel shows it on a profile.
class EmployeeClockIn {
  final String date;
  final String checkedInAt;
  final int distanceMeters;

  const EmployeeClockIn({
    required this.date,
    required this.checkedInAt,
    required this.distanceMeters,
  });

  factory EmployeeClockIn.fromJson(Map<String, dynamic> j) => EmployeeClockIn(
    date: (j['date'] ?? '').toString(),
    checkedInAt: (j['checked_in_at'] ?? '').toString(),
    distanceMeters: int.tryParse('${j['distance_meters']}') ?? 0,
  );

  /// Local wall-clock time of the clock-in. The API sends UTC ISO strings.
  String get timeLabel {
    final t = DateTime.tryParse(checkedInAt)?.toLocal();
    if (t == null) return checkedInAt;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String get dateLabel => asDate(date) ?? date;
}
