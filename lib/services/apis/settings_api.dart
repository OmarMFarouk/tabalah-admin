import '../../src/app_endpoints.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  SETTINGS API — الأدوار والصلاحيات وسجل النشاط
//  The panel's own administration: who may do
//  what, and a record of what they did.
// ─────────────────────────────────────────────
class SettingsApi {
  // ── Roles — الأدوار ─────────────────────────
  Future<ApiResponse> fetchRoles() => ApiClient.get(AppEndPoints.roles);

  Future<ApiResponse> showRole(dynamic id) =>
      ApiClient.get(AppEndPoints.role(id));

  /// The whole permission catalogue, grouped.
  ///
  /// Fetched rather than hard-coded so the editor can never offer a
  /// permission the server does not enforce — the two would drift the first
  /// time one shipped without the other.
  Future<ApiResponse> fetchPermissions() =>
      ApiClient.get(AppEndPoints.permissions);

  Future<ApiResponse> createRole(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.roles, data: data);

  Future<ApiResponse> updateRole(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.role(id), data: data);

  // Refused server-side for system roles, and for any role still assigned.
  Future<ApiResponse> deleteRole(dynamic id) =>
      ApiClient.delete(AppEndPoints.role(id));

  // ── Activity trail — سجل النشاط ─────────────
  Future<ApiResponse> fetchAuditLogs({
    dynamic userId,
    String? action,
    String? type,
    String? from,
    String? to,
    String? q,
    int page = 1,
    int perPage = 30,
  }) => ApiClient.get(
    AppEndPoints.auditLogs,
    query: {
      'user_id': userId,
      'action': action,
      'type': type,
      'from': from,
      'to': to,
      'q': q,
      'page': page,
      'per_page': perPage,
    },
  );

  /// Everything that has happened to one record, oldest first.
  Future<ApiResponse> fetchRecordHistory(String type, dynamic id) =>
      ApiClient.get(AppEndPoints.auditForRecord(type, id));
}
