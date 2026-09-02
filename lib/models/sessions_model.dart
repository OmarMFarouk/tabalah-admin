import 'paginated_model.dart';

// ─────────────────────────────────────────────
//  MEMBERSHIP SESSION — الحصة الفعلية
//  Keys mirror MembershipSessionResource exactly.
//  The membership, sport and trainer names arrive
//  flattened, so there is nothing to walk into.
// ─────────────────────────────────────────────
class ClubSession {
  int? id;
  int? membershipId;
  int? scheduleId;
  String? sessionDate;
  String? startTime;
  String? endTime;
  String? status;
  String? qrRegeneratedAt;
  String? membershipName;
  String? sportName;
  String? trainerName;
  int? attendancesCount;

  ClubSession({
    this.id,
    this.membershipId,
    this.scheduleId,
    this.sessionDate,
    this.startTime,
    this.endTime,
    this.status,
    this.qrRegeneratedAt,
    this.membershipName,
    this.sportName,
    this.trainerName,
    this.attendancesCount,
  });

  factory ClubSession.fromJson(Map<String, dynamic> json) => ClubSession(
    id: asInt(json['id']),
    membershipId: asInt(json['membership_id']),
    scheduleId: asInt(json['schedule_id']),
    sessionDate: asDate(json['session_date']),
    startTime: asString(json['start_time']),
    endTime: asString(json['end_time']),
    status: asString(json['status']),
    qrRegeneratedAt: asDateTime(json['qr_regenerated_at']),
    membershipName: asString(json['membership_name']),
    sportName: asString(json['sport_name']),
    trainerName: asString(json['trainer_name']),
    attendancesCount: asInt(json['attendances_count']),
  );

  Map<String, dynamic> toJson() => {
    if (membershipId != null) 'membership_id': membershipId,
    if (scheduleId != null) 'schedule_id': scheduleId,
    if (sessionDate != null) 'session_date': sessionDate,
    if (startTime != null) 'start_time': startTime,
    if (endTime != null) 'end_time': endTime,
    if (status != null) 'status': status,
  };

  String get timeLabel => '${startTime ?? '--'} → ${endTime ?? '--'}';
  String get statusAr => statusLabel(status ?? '');

  // The reschedule endpoint accepts exactly these four.
  static const List<String> statuses = [
    'scheduled',
    'ongoing',
    'cancelled',
    'completed',
  ];

  static String statusLabel(String en) => switch (en) {
    'scheduled' => 'مجدولة',
    'ongoing' => 'جارية',
    'cancelled' => 'ملغاة',
    'completed' => 'مكتملة',
    _ => en.isEmpty ? '—' : en,
  };
}

// ─────────────────────────────────────────────
//  PLAYER ATTENDANCE — حضور الأعضاء
//  status: present | absent | late
// ─────────────────────────────────────────────
class Attendance {
  int? id;
  int? userId;
  int? membershipId;
  int? sessionId;
  String? status;
  String? date;
  String? note;
  String? userName;
  String? membershipName;

  Attendance({
    this.id,
    this.userId,
    this.membershipId,
    this.sessionId,
    this.status,
    this.date,
    this.note,
    this.userName,
    this.membershipName,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
    id: asInt(json['id']),
    userId: asInt(json['user_id']),
    membershipId: asInt(json['membership_id']),
    sessionId: asInt(json['session_id']),
    status: asString(json['status']),
    date: asDate(json['date']),
    note: asString(json['note']),
    userName: asString(json['user_name']),
    membershipName: asString(json['membership_name']),
  );

  Map<String, dynamic> toJson() => {
    if (userId != null) 'user_id': userId,
    if (membershipId != null) 'membership_id': membershipId,
    if (status != null) 'status': status,
    if (date != null) 'date': date,
    if (note != null) 'note': note,
  };

  String get memberName => userName ?? '—';
  String get statusAr => statusLabel(status ?? '');

  static const List<String> statuses = [
    'present',
    'late',
    'excused',
    'absent',
  ];

  static String statusLabel(String en) => switch (en) {
    'present' => 'حاضر',
    'late' => 'متأخر',
    // Absent with notice — the club treats this differently from a no-show.
    'excused' => 'بعذر',
    'absent' => 'غائب',
    _ => en.isEmpty ? '—' : en,
  };
}

// ─────────────────────────────────────────────
//  SESSION RATING — تقييم الحصة
//  A member (rater) scores the trainer (ratee)
//  out of five and leaves one line of text.
//
//  There is only ever ONE text field. Moderation
//  overwrites `note` rather than annotating it,
//  so the original wording is gone once edited.
// ─────────────────────────────────────────────
class SessionRating {
  int? id;
  int? sessionId;
  int? userId;
  int? raterId;
  String? rateeName;
  String? raterName;
  double? rating;
  String? note;
  String? createdAt;

  SessionRating({
    this.id,
    this.sessionId,
    this.userId,
    this.raterId,
    this.rateeName,
    this.raterName,
    this.rating,
    this.note,
    this.createdAt,
  });

  factory SessionRating.fromJson(Map<String, dynamic> json) => SessionRating(
    id: asInt(json['id']),
    sessionId: asInt(json['session_id']),
    userId: asInt(json['user_id']),
    raterId: asInt(json['rater_id']),
    rateeName: asString(json['ratee_name']),
    raterName: asString(json['rater_name']),
    // Half-stars are allowed — the API validates 0–5 as a decimal.
    rating: asDouble(json['rating']),
    note: asString(json['note']),
    createdAt: asDateTime(json['created_at']),
  );

  Map<String, dynamic> toJson() => {if (note != null) 'note': note};

  String get memberName => raterName ?? '—';
  String get trainerName => rateeName ?? '—';
  double get stars => (rating ?? 0).clamp(0, 5).toDouble();
  String get scoreLabel => (rating ?? 0).toStringAsFixed(1);
}

// ─────────────────────────────────────────────
//  DASHBOARD — لوحة المؤشرات
//  The dashboard controller assembles its own
//  block rather than going through a resource,
//  so counts are read leniently by key.
// ─────────────────────────────────────────────
class DashboardStats {
  final Map<String, dynamic> raw;
  DashboardStats(this.raw);

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    // Counts may sit at the root or under a "stats"/"counts" block.
    final node = json['stats'] ?? json['counts'] ?? json;
    return DashboardStats(Map<String, dynamic>.from(node is Map ? node : json));
  }

  int count(List<String> keys) {
    for (final k in keys) {
      final v = raw[k];
      if (v != null) return asInt(v) ?? 0;
    }
    return 0;
  }

  double money(List<String> keys) {
    for (final k in keys) {
      final v = raw[k];
      if (v != null) return asDouble(v) ?? 0;
    }
    return 0;
  }

  // The server's own spelling comes first in each list — the rest are
  // tolerated fallbacks. `today_sessions_count` and
  // `active_enrollments_count` are what DashboardController actually sends;
  // reading the unqualified names alone made both cards read zero.
  int get players => count(['players_count', 'players', 'total_players']);
  int get trainers => count(['trainers_count', 'trainers', 'total_trainers']);
  int get employees =>
      count(['employees_count', 'employees', 'total_employees']);
  int get memberships =>
      count(['memberships_count', 'memberships', 'total_memberships']);
  int get sessions => count([
    'today_sessions_count',
    'sessions_count',
    'sessions',
    'total_sessions',
  ]);
  int get enrollments => count([
    'active_enrollments_count',
    'enrollments_count',
    'enrollments',
    'total_enrollments',
  ]);
  int get sports => count(['sports_count', 'sports', 'total_sports']);

  // The two actionable counters. Unlike the rest, these exist to be clicked:
  // the dashboard turns each into a quick action rather than a stat card.
  int get pendingPayments => count(['pending_payment_count']);
  int get expiringSoon => count(['expiring_soon_count']);
  double get revenue =>
      money(['revenue', 'total_revenue', 'collected', 'payments_total']);

  // ── Business health ──────────────────────────
  //  The two numbers that say whether the club is growing and whether the
  //  people who joined are actually turning up. Both replaced revenue cards
  //  on the home screen; the money moved to the reports page.
  int get newMembersThisMonth => count(['new_members_this_month']);

  /// Null when nothing has been recorded yet — distinct from 0%, which
  /// would claim nobody turned up.
  double? get attendanceRateMonth {
    final v = raw['attendance_rate_month'];
    return v == null ? null : asDouble(v);
  }
}
