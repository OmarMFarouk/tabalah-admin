import '../../src/app_endpoints.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  PROFILE API — واجهة الملف الشخصي
//  A summary per account and period, one paged
//  call per tab, plus the two writes the profile
//  screen owns: enrolling a member, and changing
//  an enrolment's state.
// ─────────────────────────────────────────────

class ProfileApi {
  /// The header, stats and tab list for one account over [from]–[to]. Both
  /// ends are optional; neither means all time.
  Future<ApiResponse> fetchProfile(dynamic userId, {String? from, String? to}) =>
      ApiClient.get(
        AppEndPoints.userProfile(userId),
        query: {'from': from, 'to': to},
      );

  /// One page of one tab, over the same period as the summary.
  Future<ApiResponse> fetchSection(
    dynamic userId,
    String section, {
    String? from,
    String? to,
    int page = 1,
  }) => ApiClient.get(
    AppEndPoints.userProfileSection(userId, section),
    query: {'from': from, 'to': to, 'page': page, 'per_page': 10},
  );

  /// Enrol a member and optionally take the payment in the same
  /// transaction. Two separate calls could leave an enrolment stranded
  /// without its receipt if the second one failed.
  Future<ApiResponse> enroll({
    required int userId,
    required int membershipId,
    required bool collectPayment,
    String? startDate,
    String? endDate,
    double? amount,
    int? paymentSourceId,
    String? paymentStatus,
    String? notes,
  }) => ApiClient.post(
    AppEndPoints.enroll,
    data: {
      'user_id': userId,
      'membership_id': membershipId,
      'collect_payment': collectPayment,
      if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
      if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      if (collectPayment && amount != null) 'amount': amount,
      if (collectPayment && paymentSourceId != null)
        'payment_source_id': paymentSourceId,
      if (collectPayment && paymentStatus != null)
        'payment_status': paymentStatus,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    },
  );

  /// Cancel an enrolment, or activate one left pending after an offline
  /// payment.
  Future<ApiResponse> setEnrollmentStatus(dynamic id, String status) =>
      ApiClient.put('${AppEndPoints.enrollments}/$id', data: {'status': status});
}
