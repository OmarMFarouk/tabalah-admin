import 'package:flutter/material.dart';

import '../../services/update_service.dart';
import '../../src/app_colors.dart';

/// Offers the update, or insists on it.
///
/// A forced update is unskippable in all three ways a dialog can be
/// dismissed: no Later button, `barrierDismissible: false`, and a PopScope
/// that blocks Escape and Alt+F4. Blocking only the button would leave the
/// other two as a way around a release that shipped precisely because the
/// old client no longer works.
class UpdateDialog extends StatefulWidget {
  final AppUpdate update;

  const UpdateDialog({super.key, required this.update});

  static Future<void> show(BuildContext context, AppUpdate update) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !update.isForced,
      builder: (_) => UpdateDialog(update: update),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _busy = false;
  double _progress = 0;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });

    // Returns only on failure - on success the process is replaced by the
    // installer and this never comes back.
    final error = await UpdateService.downloadAndRun(
      widget.update,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final forced = widget.update.isForced;

    return PopScope(
      canPop: !forced && !_busy,
      child: AlertDialog(
        icon: Icon(
          forced ? Icons.system_security_update_warning_rounded
                 : Icons.system_update_alt_rounded,
          size: 40,
          color: AppColors.primary,
        ),
        title: Text(forced ? 'تحديث مطلوب' : 'يتوفّر تحديث جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              forced
                  ? 'الإصدار ${widget.update.version} مطلوب لمتابعة استخدام اللوحة.'
                  : 'الإصدار ${widget.update.version} متاح الآن.',
              textAlign: TextAlign.center,
            ),
            if ((widget.update.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(widget.update.notes!,
                    style: const TextStyle(fontSize: 12.5)),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 8),
              Text(
                _progress == 0
                    ? 'جارٍ التنزيل…'
                    : 'جارٍ التنزيل… ${(_progress * 100).round()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
            ],
          ],
        ),
        actions: [
          if (!forced)
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('لاحقاً'),
            ),
          FilledButton.icon(
            onPressed: _busy ? null : _install,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(_busy ? 'جارٍ التحديث…' : 'تحديث الآن'),
          ),
        ],
      ),
    );
  }
}
