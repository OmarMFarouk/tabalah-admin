import '../../src/app_endpoints.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  PEOPLE API — الحسابات والأشخاص
//  Accounts, staff, coaches and members. Every
//  role is readable by all staff; writes are
//  gated server-side by policy.
// ─────────────────────────────────────────────
class PeopleApi {
  // ── Users — الحسابات ────────────────────────
  Future<ApiResponse> fetchUsers({
    String? role,
    String? q,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.users,
    query: {'role': role, 'q': q, 'page': page, 'per_page': perPage},
  );

  Future<ApiResponse> showUser(dynamic id) =>
      ApiClient.get(AppEndPoints.user(id));

  // Creates the account and its role-matching profile row in one call.
  Future<ApiResponse> createUser(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.users, data: data);

  // Partial — send only what changes.
  Future<ApiResponse> updateUser(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.user(id), data: data);

  // Owner only — revokes the account's tokens first.
  Future<ApiResponse> deleteUser(dynamic id) =>
      ApiClient.delete(AppEndPoints.user(id));

  // Accepts a file from disk or an external URL.
  Future<ApiResponse> setAvatar(
    dynamic id, {
    String? filePath,
    String? avatarUrl,
  }) {
    if (filePath != null && filePath.isNotEmpty) {
      return ApiClient.upload(AppEndPoints.userAvatar(id), filePath: filePath);
    }
    return ApiClient.post(
      AppEndPoints.userAvatar(id),
      data: {'avatar_url': avatarUrl},
    );
  }

  Future<ApiResponse> removeAvatar(dynamic id) =>
      ApiClient.delete(AppEndPoints.userAvatar(id));

  // ── Employees — الموظفون ────────────────────
  Future<ApiResponse> fetchEmployees({
    String? status,
    String? role,
    String? q,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.employees,
    query: {
      'status': status,
      'role': role,
      'q': q,
      'page': page,
      'per_page': perPage,
    },
  );

  Future<ApiResponse> showEmployee(dynamic id) =>
      ApiClient.get(AppEndPoints.employee(id));

  // Two accepted shapes: name+email+password hires inline,
  // or user_id promotes an existing account.
  Future<ApiResponse> createEmployee(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.employees, data: data);

  Future<ApiResponse> updateEmployee(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.employee(id), data: data);

  // Demotes by default and keeps the login.
  Future<ApiResponse> deleteEmployee(dynamic id, {bool deleteUser = false}) =>
      ApiClient.delete(
        AppEndPoints.employee(id),
        query: deleteUser ? {'delete_user': 'true'} : null,
      );

  // ── Trainers — المدربون ─────────────────────
  Future<ApiResponse> fetchTrainers({
    dynamic sportId,
    String? status,
    String? q,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.trainers,
    query: {
      'sport_id': sportId,
      'status': status,
      'q': q,
      'page': page,
      'per_page': perPage,
    },
  );

  Future<ApiResponse> showTrainer(dynamic id) =>
      ApiClient.get(AppEndPoints.trainer(id));

  Future<ApiResponse> createTrainer(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.trainers, data: data);

  Future<ApiResponse> updateTrainer(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.trainer(id), data: data);

  // Refused while the coach still has memberships.
  Future<ApiResponse> deleteTrainer(dynamic id) =>
      ApiClient.delete(AppEndPoints.trainer(id));

  // ── Players — الأعضاء ───────────────────────
  Future<ApiResponse> fetchPlayers({
    String? q,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.players,
    query: {'q': q, 'page': page, 'per_page': perPage},
  );

  Future<ApiResponse> showPlayer(dynamic id) =>
      ApiClient.get(AppEndPoints.player(id));

  Future<ApiResponse> updatePlayer(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.player(id), data: data);
}
