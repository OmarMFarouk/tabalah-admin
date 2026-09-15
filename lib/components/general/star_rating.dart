import 'package:flutter/material.dart';

import '../../src/app_colors.dart';

/// Five stars with halves, and the number beside them.
///
/// Laid out left-to-right even inside the RTL panel: a half star's filled
/// half is drawn on the left, so mirroring the row would put it on the wrong
/// side of the empty ones.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.size = 15,
    this.showValue = true,
  });

  final double value;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              value >= i + 1
                  ? Icons.star_rounded
                  : value > i
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
              size: size,
              color: GlobalColors.gold,
            ),
          if (showValue) ...[
            const SizedBox(width: 6),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                color: GlobalColors.textPrimary(context),
                fontWeight: FontWeight.w800,
                fontSize: size * 0.85,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
