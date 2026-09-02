import 'dart:developer';

import '../../src/app_endpoints.dart';
import '../../src/app_secured.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  AUTH API — الدخول والخروج
//  The panel only accepts staff roles; the
//  server rejects a player token on /admin/*.
// ─────────────────────────────────────────────
class AuthApi {
  Future<ApiResponse> login({
    required String email,
    required String password,
  }) async {
    final r = await ApiClient.post(
      AppEndPoints.login,
      data: {'email': email, 'password': password},
    );
    log(r.message, name: 'AuthApi.login');
    log(r.body.toString(), name: 'AuthApi.login.body');
    log(r.status.toString(), name: 'AuthApi.login.status');
    log(r.success.toString(), name: 'AuthApi.login.success');
    if (r.success && r['token'] != null) {
      await AppSecured.saveString(ApiClient.tokenKey, r['token'].toString());
    }
    return r;
  }

  Future<ApiResponse> logout() async {
    final r = await ApiClient.post(AppEndPoints.logout);
    await AppSecured.delete(ApiClient.tokenKey);
    return r;
  }

  // Who am I? The login payload doesn't reliably include `role`, so the
  // panel reads the shared profile endpoint to identify the account.
  Future<ApiResponse> profile() async {
    final r = await ApiClient.get(AppEndPoints.profile);
    if (r.success) return r;
    // Some builds expose this as /user/me instead.
    return ApiClient.get(AppEndPoints.me);
  }

  // Asks the server whether this token may use the panel at all.
  // /admin/* sits behind role:super-admin,admin,employee and answers 403
  // to everyone else — that verdict is authoritative, so the client
  // never has to guess from a role string it may have failed to parse.
  Future<ApiResponse> probePanelAccess() =>
      ApiClient.get(AppEndPoints.users, query: {'per_page': 1});

  Future<ApiResponse> forgotPassword({required String email}) =>
      ApiClient.post(AppEndPoints.forgotPassword, data: {'email': email});
}
