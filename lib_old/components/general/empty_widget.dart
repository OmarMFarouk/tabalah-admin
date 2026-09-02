import 'package:flutter/material.dart';

import '../../src/app_colors.dart';

// ─────────────────────────────────────────────
//  EMPTY STATE — لا توجد بيانات
//  An empty screen is an invitation to act.
// ─────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.hint,
    this.icon = Icons.inbox_rounded,
  });

  final String title;
  final String? hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: GlobalColors.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: GlobalColors.accent, size: 44),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              color: GlobalColors.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: TextStyle(
                color: GlobalColors.textSecondary(context),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
