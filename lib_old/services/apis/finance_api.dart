import '../../src/app_endpoints.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  FINANCE API — المدفوعات ووسائل الدفع والتسجيلات
//  Taking money at the desk, the catalogue of
//  ways to take it, and the sign-ups it pays for.
// ─────────────────────────────────────────────
class FinanceApi {
  // ── Payment sources — وسائل الدفع ───────────
  Future<ApiResponse> fetchSources({
    bool? isActive,
    String? kind,
    String? q,
    int page = 1,
    int perPage = 50,
  }) => ApiClient.get(
    AppEndPoints.paymentSources,
    query: {
      'is_active': isActive,
      'kind': kind,
      'q': q,
      'page': page,
      'per_page': perPage,
    },
  );

  Future<ApiResponse> showSource(dynamic id) =>
      ApiClient.get(AppEndPoints.paymentSource(id));

  // code is slugged from the name when omitted.
  Future<ApiResponse> createSource(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.paymentSources, data: data);

  // Renaming is safe — payments point at the id.
  Future<ApiResponse> updateSource(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.paymentSource(id), data: data);

  // Only a source that was never used can be removed.
  Future<ApiResponse> deleteSource(dynamic id) =>
      ApiClient.delete(AppEndPoints.paymentSource(id));

  // ── Payments — المدفوعات ────────────────────
  Future<ApiResponse> fetchPayments({
    String? status,
    dynamic userId,
    dynamic sourceId,
    String? type,
    String? from,
    String? to,
    String? reference,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.payments,
    query: {
      'status': status,
      'user_id': userId,
      'payment_source_id': sourceId,
      'type': type,
      'from': from,
      'to': to,
      'reference': reference,
      'page': page,
      'per_page': perPage,
    },
  );

  Future<ApiResponse> showPayment(dynamic id) =>
      ApiClient.get(AppEndPoints.payment(id));

  // Money taken outside the gateway. Pass enrollment_id and a
  // successful payment activates that enrollment in the same call.
  Future<ApiResponse> recordPayment(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.payments, data: data);

  // Bookkeeping fields only — amount and payer stay immutable.
  Future<ApiResponse> correctPayment(dynamic id, Map<String, dynamic> data) =>
      ApiClient.patch(AppEndPoints.payment(id), data: data);

  // Refunding cancels the linked enrollment.
  Future<ApiResponse> changeStatus(
    dynamic id, {
    required String status,
    String? notes,
  }) => ApiClient.patch(
    AppEndPoints.paymentStatus(id),
    data: {'status': status, if (notes != null) 'notes': notes},
  );

  Future<ApiResponse> deletePayment(dynamic id) =>
      ApiClient.delete(AppEndPoints.payment(id));

  // ── Enrollments — التسجيلات ─────────────────
  Future<ApiResponse> fetchEnrollments({
    dynamic userId,
    dynamic membershipId,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.enrollments,
    query: {
      'user_id': userId,
      'membership_id': membershipId,
      'page': page,
      'per_page': perPage,
    },
  );

  Future<ApiResponse> showEnrollment(dynamic id) =>
      ApiClient.get(AppEndPoints.enrollment(id));

  // Front-desk write — all staff can sign members up.
  Future<ApiResponse> createEnrollment(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.enrollments, data: data);

  Future<ApiResponse> updateEnrollment(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.enrollment(id), data: data);

  // Admin only.
  Future<ApiResponse> deleteEnrollment(dynamic id) =>
      ApiClient.delete(AppEndPoints.enrollment(id));
}
