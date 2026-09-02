import '../../src/app_endpoints.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  COMMS API — البريد والنشرات
//  Split by blast radius: one-off mail is open
//  to all staff, mass newsletters are admin-only.
// ─────────────────────────────────────────────
class CommsApi {
  // The audit trail of every email sent, automatic ones included.
  Future<ApiResponse> fetchEmails({
    String? type,
    String? q,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.emails,
    query: {'type': type, 'q': q, 'page': page, 'per_page': perPage},
  );

  // A single message to one member — allowed for all staff.
  Future<ApiResponse> sendCustom({
    required dynamic userId,
    required String subject,
    required String body,
  }) => ApiClient.post(
    AppEndPoints.customEmail,
    data: {'user_id': userId, 'subject': subject, 'body': body},
  );

  Future<ApiResponse> fetchNewsletters({int page = 1, int perPage = 15}) =>
      ApiClient.get(
        AppEndPoints.newsletters,
        query: {'page': page, 'per_page': perPage},
      );

  // Mass mail to all, players, trainers, staff, or a custom id list.
  Future<ApiResponse> sendNewsletter({
    required String audience,
    required String subject,
    required String body,
    List<int>? userIds,
  }) => ApiClient.post(
    AppEndPoints.newsletter,
    data: {
      'audience': audience,
      'subject': subject,
      'body': body,
      if (audience == 'custom') 'user_ids': userIds ?? [],
    },
  );
}
