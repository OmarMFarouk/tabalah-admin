import '../../src/app_endpoints.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  SESSIONS API — الحصص والحضور والتقييمات
//  Individual class occurrences, who turned up,
//  and what they thought of it.
// ─────────────────────────────────────────────
class SessionsApi {
  // ── Sessions — الحصص ────────────────────────
  Future<ApiResponse> fetchSessions({
    dynamic membershipId,
    String? status,
    String? date,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.sessions,
    query: {
      'membership_id': membershipId,
      'status': status,
      'date': date,
      'page': page,
      'per_page': perPage,
    },
  );

  // Sessions grouped by status for the board view.
  Future<ApiResponse> fetchBoard({String? from, String? to}) =>
      ApiClient.get(AppEndPoints.sessionsBoard, query: {'from': from, 'to': to});

  Future<ApiResponse> showSession(dynamic id) =>
      ApiClient.get(AppEndPoints.session(id));

  // Add a session by hand — needs an existing schedule to hang off.
  Future<ApiResponse> createSession(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.sessions, data: data);

  // Expands schedules into concrete sessions. Safe to re-run.
  Future<ApiResponse> generateSessions(
    dynamic membershipId, {
    required String from,
    required String to,
  }) => ApiClient.post(
    AppEndPoints.generateSessions(membershipId),
    data: {'from': from, 'to': to},
  );

  // What the board's drag-and-drop calls.
  Future<ApiResponse> rescheduleSession(
    dynamic id, {
    String? sessionDate,
    String? startTime,
    String? endTime,
    String? status,
  }) => ApiClient.patch(
    AppEndPoints.rescheduleSession(id),
    data: {
      if (sessionDate != null) 'session_date': sessionDate,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (status != null) 'status': status,
    },
  );

  // ── Attendance — الحضور ─────────────────────
  Future<ApiResponse> fetchAttendances({
    dynamic userId,
    dynamic membershipId,
    String? status,
    String? date,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.attendances,
    query: {
      'user_id': userId,
      'membership_id': membershipId,
      'status': status,
      'date': date,
      'page': page,
      'per_page': perPage,
    },
  );

  // Front-desk write — employees can create and update here.
  Future<ApiResponse> recordAttendance(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.attendances, data: data);

  Future<ApiResponse> updateAttendance(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.attendance(id), data: data);

  // Admin only.
  Future<ApiResponse> deleteAttendance(dynamic id) =>
      ApiClient.delete(AppEndPoints.attendance(id));

  // ── Ratings — التقييمات ─────────────────────
  // Two different people sit on a rating row: `user_id` is the ratee (the
  // trainer being scored) and `rater_id` is the member who scored them.
  // The panel filters by member, so it must send `rater_id` — sending the
  // member's id as `user_id` matches trainers and returns nothing.
  Future<ApiResponse> fetchRatings({
    dynamic raterId,
    dynamic rateeId,
    dynamic sessionId,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.ratings,
    query: {
      'rater_id': raterId,
      'user_id': rateeId,
      'session_id': sessionId,
      'page': page,
      'per_page': perPage,
    },
  );

  Future<ApiResponse> showRating(dynamic id) =>
      ApiClient.get(AppEndPoints.rating(id));

  // Feedback is moderated rather than deleted.
  Future<ApiResponse> updateRating(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.rating(id), data: data);
}
