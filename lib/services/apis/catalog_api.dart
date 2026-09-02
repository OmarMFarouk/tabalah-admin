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

  // ── Artwork — الصور ─────────────────────────
  //  Artwork is set separately from the JSON create/update because it is
  //  multipart and optional: an admin swapping a picture shouldn't have to
  //  re-submit the whole form, and a sport with only an icon never posts
  //  here at all.
  Future<ApiResponse> setSportImage(
    dynamic id, {
    String? filePath,
    String? imageUrl,
  }) {
    if (filePath != null && filePath.isNotEmpty) {
      return ApiClient.upload(
        AppEndPoints.sportImage(id),
        filePath: filePath,
        field: 'image',
      );
    }
    return ApiClient.upload(
      AppEndPoints.sportImage(id),
      fields: {'image_url': imageUrl ?? ''},
      field: 'image',
    );
  }

  Future<ApiResponse> clearSportImage(dynamic id) =>
      ApiClient.delete(AppEndPoints.sportImage(id));

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

  // Card artwork — drawn behind the membership card at low opacity in
  // both the panel and the member app.
  Future<ApiResponse> setMembershipImage(
    dynamic id, {
    String? filePath,
    String? imageUrl,
  }) {
    if (filePath != null && filePath.isNotEmpty) {
      return ApiClient.upload(
        AppEndPoints.membershipImage(id),
        filePath: filePath,
        field: 'image',
      );
    }
    return ApiClient.upload(
      AppEndPoints.membershipImage(id),
      fields: {'image_url': imageUrl ?? ''},
      field: 'image',
    );
  }

  Future<ApiResponse> clearMembershipImage(dynamic id) =>
      ApiClient.delete(AppEndPoints.membershipImage(id));

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
