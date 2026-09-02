import 'catalog_model.dart';
import 'finance_model.dart';
import 'paginated_model.dart';
import 'performance_model.dart';
import 'sessions_model.dart';
import 'users_model.dart';

// ─────────────────────────────────────────────
//  USER PROFILE — الملف الشخصي
//  One aggregate for every kind of account.
//  `GET /admin/users/{id}/profile` always sends
//  every key; the ones that don't apply to the
//  role come back empty, so nothing here is
//  nullable except the user itself.
// ─────────────────────────────────────────────
class UserProfile {
  final User? user;
  final String role;
  final ProfileStats stats;

  final List<Enrollment> enrollments;
  final List<Payment> payments;
  final List<Attendance> attendances;
  final List<ClubSession> sessions;
  final List<SessionRating> ratings;
  final List<Salary> salaries;
  final List<KpiRecord> kpiRecords;

  const UserProfile({
    this.user,
    this.role = '',
    this.stats = const ProfileStats({}),
    this.enrollments = const [],
    this.payments = const [],
    this.attendances = const [],
    this.sessions = const [],
    this.ratings = const [],
    this.salaries = const [],
    this.kpiRecords = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) build) {
      final node = json[key];
      if (node is! List) return const [];
      return node
          .whereType<Map>()
          .map((e) => build(Map<String, dynamic>.from(e)))
          .toList();
    }

    final rawUser = json['user'];

    return UserProfile(
      // UserResource is the one resource that prefixes its keys (user_name,
      // user_role, ...). User.fromJson already runs them through unprefix
      // itself, so there is nothing to normalise here.
      user: rawUser is Map
          ? User.fromJson(Map<String, dynamic>.from(rawUser))
          : null,
      role: asString(json['role']) ?? '',
      stats: ProfileStats(
        json['stats'] is Map
            ? Map<String, dynamic>.from(json['stats'])
            : const {},
      ),
      enrollments: list('enrollments', Enrollment.fromJson),
      payments: list('payments', Payment.fromJson),
      attendances: list('attendances', Attendance.fromJson),
      sessions: list('sessions', ClubSession.fromJson),
      ratings: list('ratings', SessionRating.fromJson),
      salaries: list('salaries', Salary.fromJson),
      kpiRecords: list('kpi_records', KpiRecord.fromJson),
    );
  }

  bool get isPlayer => role == 'player';
  bool get isTrainer => role == 'trainer';
  bool get isStaff =>
      role == 'employee' || role == 'admin' || role == 'super-admin';
}

// ─────────────────────────────────────────────
//  PROFILE STATS — الإحصائيات
//  Deliberately a loose map. The server sends a
//  different set per role, and hard-coding one
//  class per role would mean three near-identical
//  parsers that all break the day a counter is
//  added. Typed getters below cover what the UI
//  actually reads.
// ─────────────────────────────────────────────
class ProfileStats {
  final Map<String, dynamic> raw;
  const ProfileStats(this.raw);

  int intOf(String key) => asInt(raw[key]) ?? 0;
  double doubleOf(String key) => asDouble(raw[key]) ?? 0;
  String? stringOf(String key) => asString(raw[key]);
  bool has(String key) => raw[key] != null;

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

  // ── Trainer ────────────────────────────────
  int get membershipsCount => intOf('memberships_count');
  int get sessionsCount => intOf('sessions_count');
  int get upcomingSessionsCount => intOf('upcoming_sessions_count');
  int get completedSessionsCount => intOf('completed_sessions_count');
  int get ratingsCount => intOf('ratings_count');
  double? get averageRating => asDouble(raw['average_rating']);

  // ── Staff ──────────────────────────────────
  int get kpiRecordsCount => intOf('kpi_records_count');
  double? get averageAchievement => asDouble(raw['average_achievement']);
  int get salariesCount => intOf('salaries_count');
  double get salariesTotal => doubleOf('salaries_total');
  String? get lastSalaryAt => asDate(raw['last_salary_at']);

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

  bool get needsAttention =>
      currentMembership == null ||
      (daysRemaining != null && daysRemaining! <= 7) ||
      pendingPaymentEnrollments > 0;
}
