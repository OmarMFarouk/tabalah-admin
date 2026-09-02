import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../src/app_globals.dart';
import '../../src/app_secured.dart';

class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic> body;
  final int status;

  ApiResponse({
    required this.success,
    required this.message,
    this.body = const {},
    this.status = 0,
  });

  factory ApiResponse.error(String message, [int status = 0]) =>
      ApiResponse(success: false, message: message, status: status);

  dynamic operator [](String key) => body[key];

  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
}

class ApiClient {
  static const String tokenKey = 'admin_token';

  /// How long any single request may take before it is abandoned.
  ///
  /// `package:http` has **no default timeout**, and that was the whole of the
  /// "login spins forever and never says why" bug: a connection that stalls
  /// rather than being refused - a WAF dropping packets, a flaky link, a
  /// server that accepts and never answers - leaves the Future pending for
  /// ever. `AuthCubit.login()` awaits `Future.wait` over six of these, so one
  /// stalled socket parks the cubit on AppBusy permanently. There is no error
  /// to report because nothing ever failed; it simply never finished.
  ///
  /// The member app has had these limits since it was written (Dio's
  /// connect/receive timeouts); this client just never got them.
  static const Duration timeout = Duration(seconds: 25);

  /// Uploads move real files, so they get a longer leash than a JSON call.
  static const Duration uploadTimeout = Duration(seconds: 90);

  /// Called whenever the server rejects the stored token, so the app can
  /// drop back to the login card.
  ///
  /// Wired once from AppRoot to the AuthCubit. A callback rather than a
  /// direct Navigator call because this class is static and has no route
  /// stack to reason about — see the note in [_parse].
  static void Function()? onUnauthorized;

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await AppSecured.readString(tokenKey) ?? '';
    return {
      'Accept': 'application/json',
      // The panel is Arabic end to end, so it asks for Arabic explicitly
      // rather than relying on the API's default. Catalogue rows come back
      // with `name`/`description` resolved to Arabic and the raw `name_ar`
      // / `name_en` columns alongside, which is what the edit forms write.
      'X-App-Locale': 'ar',
      if (json) 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Drops null/empty params so blank filters aren't sent.
  static Uri _uri(String url, [Map<String, dynamic>? query]) {
    final uri = Uri.parse(url);
    if (query == null || query.isEmpty) return uri;
    final clean = <String, String>{};
    query.forEach((k, v) {
      if (v == null) return;
      final s = v.toString();
      if (s.isEmpty || s == 'null') return;
      clean[k] = s;
    });
    if (clean.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...clean});
  }

  static ApiResponse _parse(http.Response res) {
    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return ApiResponse.error('تعذّر قراءة رد الخادم.', res.statusCode);
    }
    // Sanctum answers an expired or missing token with 401 "Unauthenticated."
    // The old guard matched 'unauthenticated  ' — two trailing spaces — which
    // no message ever starts with, so the session-expiry redirect never fired
    // and the user just saw an empty screen. Trust the status code first.
    final message = (body['message'] ?? '').toString().toLowerCase();
    if (res.statusCode == 401 || message.startsWith('unauthenticated')) {
      // Clear the dead session and *report* it. Deliberately no navigation
      // from here.
      //
      // This used to call Navigator.pushReplacement on the root navigator,
      // and that was the "login succeeds but nothing happens" bug: the gate
      // widget IS the root route, so replacing it destroyed the one thing
      // that knew how to show the dashboard. AuthScreen became the root with
      // no navigation logic of its own, and from then on a perfectly good
      // login set `AppGlobals.currentUser`, emitted its states, and moved
      // nothing. A stale token on launch was enough to trigger it.
      //
      // Routing decisions belong to the widget that owns the route stack,
      // not to a static HTTP helper that cannot see it. This now mirrors the
      // member app, where `ApiClient.onUnauthorized` hands the fact to the
      // auth cubit and the gate reacts.
      AppSecured.delete(tokenKey);
      AppGlobals.clear();
      onUnauthorized?.call();
      return ApiResponse.error('انتهت صلاحية الجلسة', res.statusCode);
    }
    final ok = body['success'] == true && res.statusCode < 300;
    return ApiResponse(
      success: ok,
      message: (body['message'] ?? (ok ? '' : 'حدث خطأ غير متوقع.')).toString(),
      body: body,
      status: res.statusCode,
    );
  }

  static ApiResponse _onError(Object e) {
    log('ApiClient error: $e');
    if (e is TimeoutException) {
      // Worth its own message: a timeout is not "no connection", it is a
      // server that took the request and never answered. Telling the two
      // apart is the difference between "check your wifi" and "the server
      // is struggling", and the user can act on each differently.
      return ApiResponse.error(
        'انتهت مهلة الاتصال بالخادم — حاول مرة أخرى.',
      );
    }
    if (e is SocketException) {
      return ApiResponse.error('تعذّر الوصول للخادم — تحقّق من الاتصال.');
    }
    if (e is HandshakeException) {
      return ApiResponse.error('تعذّر التحقّق من شهادة الأمان للخادم.');
    }
    return ApiResponse.error('حدث خطأ: $e');
  }

  /// Every verb goes through here, so the timeout can never be forgotten on
  /// one of them - which is exactly how this class ended up with none at all.
  ///
  /// Building the headers is *inside* the guard, and that matters: reading
  /// the token goes through the secure-storage plugin, which can fail on its
  /// own (a locked keychain, a missing platform implementation). Fetching
  /// them before the try - as this first did - put that failure back outside
  /// any handler, which is the same shape as the bug the guard exists for.
  static Future<ApiResponse> _send(
    Future<http.Response> Function(Map<String, String> headers) call, {
    Duration? limit,
    bool json = true,
  }) async {
    try {
      final headers = await _headers(json: json);
      return _parse(await call(headers).timeout(limit ?? timeout));
    } catch (e) {
      return _onError(e);
    }
  }

  // ── Verbs ───────────────────────────────────
  static Future<ApiResponse> get(String url, {Map<String, dynamic>? query}) =>
      _send((h) => http.get(_uri(url, query), headers: h));

  static Future<ApiResponse> post(
    String url, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) => _send(
    (h) => http.post(_uri(url, query), headers: h, body: jsonEncode(data ?? {})),
  );

  static Future<ApiResponse> put(String url, {Map<String, dynamic>? data}) =>
      _send(
        (h) => http.put(_uri(url), headers: h, body: jsonEncode(data ?? {})),
      );

  static Future<ApiResponse> patch(String url, {Map<String, dynamic>? data}) =>
      _send(
        (h) => http.patch(_uri(url), headers: h, body: jsonEncode(data ?? {})),
      );

  static Future<ApiResponse> delete(
    String url, {
    Map<String, dynamic>? query,
  }) => _send((h) => http.delete(_uri(url, query), headers: h));

  // Multipart upload — a file from disk, or an external URL in `fields`.
  //
  // `field` is the multipart part name the endpoint expects: 'avatar' for
  // the profile endpoints, 'image' for sport and membership artwork. It
  // used to be hardcoded to 'avatar', which is why catalogue uploads had
  // to be added here rather than bolted on as a second method.
  static Future<ApiResponse> upload(
    String url, {
    String? filePath,
    Map<String, String>? fields,
    String field = 'avatar',
  }) async {
    try {
      final request = http.MultipartRequest('POST', _uri(url));
      request.headers.addAll(await _headers(json: false));
      if (fields != null) request.fields.addAll(fields);
      if (filePath != null && filePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(field, filePath));
      }
      final streamed = await request.send().timeout(uploadTimeout);
      final res = await http.Response.fromStream(
        streamed,
      ).timeout(uploadTimeout);
      return _parse(res);
    } catch (e) {
      return _onError(e);
    }
  }
}
