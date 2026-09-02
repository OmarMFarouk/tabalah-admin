import 'package:flutter/material.dart';

import '../../src/app_colors.dart';

// ─────────────────────────────────────────────
//  STAT CARD — بطاقة إحصائية
//  The reference app rebuilt this inside every
//  screen; here it is once.
// ─────────────────────────────────────────────
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: GlobalColors.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GlobalColors.border(context)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: GlobalColors.textSecondary(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sub != null)
                      Text(
                        sub!,
                        style: TextStyle(
                          color: GlobalColors.textSecondary(context),
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  STAT ROW — صف البطاقات
// ─────────────────────────────────────────────
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.cards});
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            cards[i],
          ],
        ],
      ),
    );
  }
}
