import 'package:flutter/material.dart';

import '../../src/app_colors.dart';

// ─────────────────────────────────────────────
//  SNACKBAR — التنبيهات
// ─────────────────────────────────────────────
class MySnackBar {
  static void show(
    BuildContext context, {
    required String text,
    required bool isSuccess,
  }) {
    if (text.trim().isEmpty) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: isSuccess ? GlobalColors.green : GlobalColors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
