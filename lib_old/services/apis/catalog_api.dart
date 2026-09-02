import '../../src/app_endpoints.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  CATALOG API — الرياضات والاشتراكات والمواعيد
//  What the club offers and when it meets.
// ─────────────────────────────────────────────
class CatalogApi {
  // ── Sports — الرياضات ───────────────────────
  Future<ApiResponse> fetchSports({
    String? q,
    int page = 1,
    int perPage = 50,
  }) => ApiClient.get(
    AppEndPoints.sports,
    query: {'q': q, 'page': page, 'per_page': perPage},
  );

  Future<ApiResponse> showSport(dynamic id) =>
      ApiClient.get(AppEndPoints.sport(id));

  // Names are unique.
  Future<ApiResponse> createSport(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.sports, data: data);

  Future<ApiResponse> updateSport(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.sport(id), data: data);

  // Cascades to trainers and memberships.
  Future<ApiResponse> deleteSport(dynamic id) =>
      ApiClient.delete(AppEndPoints.sport(id));

  // ── Memberships — الاشتراكات ────────────────
  Future<ApiResponse> fetchMemberships({
    dynamic sportId,
    dynamic trainerId,
    String? status,
    String? q,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.memberships,
    query: {
      'sport_id': sportId,
      'trainer_id': trainerId,
      'status': status,
      'q': q,
      'page': page,
      'per_page': perPage,
    },
  );

  Future<ApiResponse> showMembership(dynamic id) =>
      ApiClient.get(AppEndPoints.membership(id));

  Future<ApiResponse> createMembership(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.memberships, data: data);

  Future<ApiResponse> updateMembership(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.membership(id), data: data);

  // Cascades to schedules, sessions and enrollments.
  Future<ApiResponse> deleteMembership(dynamic id) =>
      ApiClient.delete(AppEndPoints.membership(id));

  // ── Schedules — المواعيد ────────────────────
  Future<ApiResponse> fetchSchedules({
    dynamic membershipId,
    int page = 1,
    int perPage = 100,
  }) => ApiClient.get(
    AppEndPoints.schedules,
    query: {
      'membership_id': membershipId,
      'page': page,
      'per_page': perPage,
    },
  );

  // Weekly slot, or a single dated occurrence.
  Future<ApiResponse> createSchedule(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.schedules, data: data);

  Future<ApiResponse> updateSchedule(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.schedule(id), data: data);

  Future<ApiResponse> deleteSchedule(dynamic id) =>
      ApiClient.delete(AppEndPoints.schedule(id));
}
