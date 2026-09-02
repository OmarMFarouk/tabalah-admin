import '../../src/app_endpoints.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  PROFILE API — واجهة الملف الشخصي
//  One aggregate read per account, plus the two
//  writes the profile screen owns: enrolling a
//  member, and changing an enrolment's state.
// ─────────────────────────────────────────────
class ProfileApi {
  /// Everything the profile screen renders, in one call. The server shapes
  /// the payload by role, so there is no per-role variant to pick here.
  Future<ApiResponse> fetchProfile(dynamic userId) =>
      ApiClient.get(AppEndPoints.userProfile(userId));

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
      ApiClient.put(
        '${AppEndPoints.enrollments}/$id',
        data: {'status': status},
      );
}
