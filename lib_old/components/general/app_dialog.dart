import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/base_states.dart';
import '../../src/app_colors.dart';

// ─────────────────────────────────────────────
//  APP DIALOG — الحوار الموحّد
//  Header icon, title, body, and a save button
//  that disables itself while the write is in
//  flight. Closes on AppSuccess.
// ─────────────────────────────────────────────
class AppDialog<C extends Cubit<AppStates>> extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    required this.onSave,
    this.saveLabel = 'حفظ',
    this.width = 520,
    this.saveColor,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback onSave;
  final String saveLabel;
  final double width;
  final Color? saveColor;

  @override
  Widget build(BuildContext context) {
    return BlocListener<C, AppStates>(
      listener: (ctx, state) {
        if (state is AppSuccess && state.shouldPop) Navigator.pop(ctx);
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: GlobalColors.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: GlobalColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: GlobalColors.accentSoft, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: width,
            child: SingleChildScrollView(child: child),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  color: GlobalColors.textSecondary(context),
                ),
              ),
            ),
            BlocBuilder<C, AppStates>(
              builder: (ctx, state) {
                final busy = state is AppBusy;
                return ElevatedButton(
                  onPressed: busy ? null : onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: saveColor ?? GlobalColors.accent,
                    disabledBackgroundColor: (saveColor ?? GlobalColors.accent)
                        .withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          saveLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Layout helpers for dialog bodies ──────────
Widget dialogRow(List<Widget> children) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (int i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 14),
        Expanded(child: children[i]),
      ],
    ],
  );
}

const Widget gap = SizedBox(height: 14);

// ─────────────────────────────────────────────
//  CONFIRM DIALOG — تأكيد الإجراء
//  States plainly what will happen, because
//  several of these cascade.
// ─────────────────────────────────────────────
Future<void> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required VoidCallback onConfirm,
  String confirmLabel = 'حذف',
  bool isDanger = true,
}) {
  final color = isDanger ? GlobalColors.red : GlobalColors.accent;

  return showDialog(
    context: context,
    // `dctx` is the dialog's own context. Building off the caller's would
    // keep a dependency on a widget that may already be gone by the time
    // the dialog rebuilds.
    builder: (dctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: GlobalColors.card(dctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: GlobalColors.textPrimary(dctx),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: GlobalColors.textSecondary(dctx),
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(
              'تراجع',
              style: TextStyle(color: GlobalColors.textSecondary(dctx)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
