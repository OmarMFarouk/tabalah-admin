import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../src/app_secured.dart';

// ─────────────────────────────────────────────
//  API RESPONSE — الرد الموحّد
//  Every endpoint answers with the same
//  envelope: { success, message, <resource> }
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
//  API CLIENT — العميل المشترك
//  Holds the token, builds the query string and
//  unwraps the envelope so the resource APIs
//  stay one line per endpoint.
// ─────────────────────────────────────────────
class ApiClient {
  static const String tokenKey = 'admin_token';

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await AppSecured.readString(tokenKey) ?? '';
    return {
      'Accept': 'application/json',
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
    if (e is SocketException) {
      return ApiResponse.error('تعذّر الوصول للخادم — تحقّق من الاتصال.');
    }
    return ApiResponse.error('حدث خطأ: $e');
  }

  // ── Verbs ───────────────────────────────────
  static Future<ApiResponse> get(
    String url, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await http.get(_uri(url, query), headers: await _headers());
      return _parse(res);
    } catch (e) {
      return _onError(e);
    }
  }

  static Future<ApiResponse> post(
    String url, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await http.post(
        _uri(url, query),
        headers: await _headers(),
        body: jsonEncode(data ?? {}),
      );
      return _parse(res);
    } catch (e) {
      return _onError(e);
    }
  }

  static Future<ApiResponse> put(
    String url, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final res = await http.put(
        _uri(url),
        headers: await _headers(),
        body: jsonEncode(data ?? {}),
      );
      return _parse(res);
    } catch (e) {
      return _onError(e);
    }
  }

  static Future<ApiResponse> patch(
    String url, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final res = await http.patch(
        _uri(url),
        headers: await _headers(),
        body: jsonEncode(data ?? {}),
      );
      return _parse(res);
    } catch (e) {
      return _onError(e);
    }
  }

  static Future<ApiResponse> delete(
    String url, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await http.delete(
        _uri(url, query),
        headers: await _headers(),
      );
      return _parse(res);
    } catch (e) {
      return _onError(e);
    }
  }

  // Avatar upload — a file from disk, or an external URL.
  static Future<ApiResponse> upload(
    String url, {
    String? filePath,
    Map<String, String>? fields,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _uri(url));
      request.headers.addAll(await _headers(json: false));
      if (fields != null) request.fields.addAll(fields);
      if (filePath != null && filePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('avatar', filePath));
      }
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      return _parse(res);
    } catch (e) {
      return _onError(e);
    }
  }
}
