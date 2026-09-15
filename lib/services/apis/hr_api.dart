import '../../src/app_endpoints.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  HR & EVALUATIONS API — الموارد البشرية والتقييمات
// ─────────────────────────────────────────────

class HrApi {
  // ── Overtime — الساعات الإضافية ─────────────
  Future<ApiResponse> fetchOvertime({
    int? userId,
    String? from,
    String? to,
    int page = 1,
  }) => ApiClient.get(
    AppEndPoints.overtime,
    query: {
      'user_id': userId,
      'from': from,
      'to': to,
      'page': page,
      'per_page': 15,
    },
  );

  Future<ApiResponse> createOvertime(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.overtime, data: data);

  Future<ApiResponse> updateOvertime(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.overtimeRecord(id), data: data);

  Future<ApiResponse> deleteOvertime(dynamic id) =>
      ApiClient.delete(AppEndPoints.overtimeRecord(id));

  // ── Employment letter — خطاب التعريف ───────
  /// A link signed for thirty minutes to the printable letter.
  Future<ApiResponse> employmentLetter(dynamic userId) =>
      ApiClient.get(AppEndPoints.employmentLetter(userId));

  // ── Evaluations — التقييمات ─────────────────
  Future<ApiResponse> fetchEvaluations({
    String? role,
    String? q,
    String? from,
    String? to,
    int page = 1,
  }) => ApiClient.get(
    AppEndPoints.ratings,
    query: {
      'role': role,
      'q': (q ?? '').isEmpty ? null : q,
      'from': from,
      'to': to,
      'page': page,
      'per_page': 15,
    },
  );

  Future<ApiResponse> createEvaluation(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.ratings, data: data);

  Future<ApiResponse> updateEvaluation(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.rating(id), data: data);

  Future<ApiResponse> deleteEvaluation(dynamic id) =>
      ApiClient.delete(AppEndPoints.rating(id));
}
