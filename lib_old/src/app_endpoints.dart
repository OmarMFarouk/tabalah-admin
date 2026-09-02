// ─────────────────────────────────────────────
//  API ENDPOINTS — Tabalah Club · Admin Panel
//  كل مسارات لوحة التحكم
// ─────────────────────────────────────────────
class AppEndPoints {
  static const String endPoint = 'http://localhost:8000/api/v1';
  static const String admin = '$endPoint/admin';

  // ── Auth ────────────────────────────────────
  static const String login = '$endPoint/login';
  static const String logout = '$endPoint/logout';
  static const String forgotPassword = '$endPoint/forgot-password';
  static const String resetPassword = '$endPoint/reset-password';

  // The role-agnostic profile endpoint — returns the signed-in account
  // with whichever profile block matches its role. The login response
  // doesn't reliably carry `role`, so this is what identifies the user.
  static const String profile = '$endPoint/profile';
  static const String me = '$endPoint/user/me';

  // ── Dashboard ───────────────────────────────
  static const String dashboard = '$admin/dashboard';

  // ── Users ───────────────────────────────────
  static const String users = '$admin/users';
  static String user(dynamic id) => '$admin/users/$id';
  static String userAvatar(dynamic id) => '$admin/users/$id/avatar';

  // ── Employees (Staff) ───────────────────────
  static const String employees = '$admin/employees';
  static String employee(dynamic id) => '$admin/employees/$id';

  // ── Trainers ────────────────────────────────
  static const String trainers = '$admin/trainers';
  static String trainer(dynamic id) => '$admin/trainers/$id';

  // ── Players ─────────────────────────────────
  static const String players = '$admin/players';
  static String player(dynamic id) => '$admin/players/$id';

  // ── Sports ──────────────────────────────────
  static const String sports = '$admin/sports';
  static String sport(dynamic id) => '$admin/sports/$id';

  // ── Memberships ─────────────────────────────
  static const String memberships = '$admin/memberships';
  static String membership(dynamic id) => '$admin/memberships/$id';
  static String generateSessions(dynamic id) =>
      '$admin/memberships/$id/generate-sessions';

  // ── Membership Schedules ────────────────────
  static const String schedules = '$admin/membership-schedules';
  static String schedule(dynamic id) => '$admin/membership-schedules/$id';

  // ── Membership Sessions ─────────────────────
  static const String sessions = '$admin/membership-sessions';
  static const String sessionsBoard = '$admin/membership-sessions/board';
  static String session(dynamic id) => '$admin/membership-sessions/$id';
  static String rescheduleSession(dynamic id) =>
      '$admin/membership-sessions/$id/reschedule';

  // ── Payment Sources ─────────────────────────
  static const String paymentSources = '$admin/payment-sources';
  static String paymentSource(dynamic id) => '$admin/payment-sources/$id';

  // ── Payments ────────────────────────────────
  static const String payments = '$admin/payments';
  static String payment(dynamic id) => '$admin/payments/$id';
  static String paymentStatus(dynamic id) => '$admin/payments/$id/status';

  // ── Enrollments ─────────────────────────────
  static const String enrollments = '$admin/enrollments';
  static String enrollment(dynamic id) => '$admin/enrollments/$id';

  // ── Attendance ──────────────────────────────
  static const String attendances = '$admin/player-attendances';
  static String attendance(dynamic id) => '$admin/player-attendances/$id';

  // ── Session Ratings ─────────────────────────
  static const String ratings = '$admin/session-ratings';
  static String rating(dynamic id) => '$admin/session-ratings/$id';

  // ── KPIs / Records / Salaries ───────────────
  static const String kpis = '$admin/kpis';
  static String kpi(dynamic id) => '$admin/kpis/$id';
  static const String kpiRecords = '$admin/kpi-records';
  static String kpiRecord(dynamic id) => '$admin/kpi-records/$id';
  static const String salaries = '$admin/salaries';
  static String salary(dynamic id) => '$admin/salaries/$id';

  // ── Emails & Newsletters ────────────────────
  static const String emails = '$admin/emails';
  static const String customEmail = '$admin/emails/custom';
  static const String newsletter = '$admin/emails/newsletter';
  static const String newsletters = '$admin/newsletters';
}
