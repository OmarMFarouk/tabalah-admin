import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../src/app_endpoints.dart';

/// A release the panel is behind.
class AppUpdate {
  final String version;
  final String? notes;
  final bool isForced;
  final String downloadUrl;

  const AppUpdate({
    required this.version,
    required this.notes,
    required this.isForced,
    required this.downloadUrl,
  });
}

/// Checks for a newer desktop build and installs it.
///
/// The server decides whether we are out of date - it already knows the
/// published version and how to compare two of them, and having one
/// implementation of that comparison rather than one per client is the
/// difference between "1.10.0 is newer than 1.9.0" being right everywhere
/// or nowhere.
class UpdateService {
  UpdateService._();

  /// Null when current, unreachable, or no installer has been published.
  ///
  /// Never throws: a failed update check must not stop someone signing in
  /// and doing their job.
  static Future<AppUpdate?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();

      final res = await http
          .get(Uri.parse(
              '${AppEndPoints.appRelease}?current=${Uri.encodeComponent(info.version)}'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body);
      final data = body is Map ? (body['data'] ?? body) : null;
      if (data is! Map) return null;

      if (data['update_available'] != true) return null;

      final url = data['download_url'];
      // A published version with no installer behind it would leave the
      // dialog offering a button that cannot work - especially bad when
      // forced, since there would be no way out of it.
      if (url is! String || url.isEmpty) return null;

      return AppUpdate(
        version: '${data['version']}',
        notes: data['notes'] as String?,
        isForced: data['is_forced'] == true,
        downloadUrl: url,
      );
    } catch (_) {
      return null;
    }
  }

  /// Download the installer and hand over to it.
  ///
  /// Returns an error message, or never returns because the app exited.
  /// The installer is launched detached and then this process quits: Inno
  /// cannot replace an executable that is still running.
  static Future<String?> downloadAndRun(
    AppUpdate update, {
    void Function(double)? onProgress,
  }) async {
    try {
      final res = await http.Client().send(
        http.Request('GET', Uri.parse(update.downloadUrl)),
      );

      if (res.statusCode != 200) {
        return 'تعذّر تنزيل التحديث (${res.statusCode}).';
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}\\TabalahAdmin-Setup-${update.version}.exe');
      final sink = file.openWrite();

      final total = res.contentLength ?? 0;
      var received = 0;

      await for (final chunk in res.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.close();

      if (await file.length() < 1024) {
        return 'ملف التحديث غير صالح.';
      }

      // /SILENT so staff are not asked to click through a wizard they did
      // not start. Detached so it outlives us - we are about to exit, and
      // Inno needs this executable released before it can overwrite it.
      await Process.start(
        file.path,
        ['/SILENT', '/NOCANCEL', '/RESTARTAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );

      await Future<void>.delayed(const Duration(milliseconds: 400));
      exit(0);
    } catch (e) {
      return 'تعذّر تثبيت التحديث: $e';
    }
  }
}
