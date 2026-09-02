import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/general/snackbar.dart';
import '../src/app_colors.dart';

// ─────────────────────────────────────────────
//  GUARDIAN CODE SHARING — مشاركة كود ولي الأمر
//
//  Windows has no share sheet worth reaching
//  for, so this offers the three routes a front
//  desk actually uses: WhatsApp, email, or the
//  clipboard.
//
//  What gets sent is the whole sentence, not the
//  eight characters. A parent receiving "K4M9PQ2X"
//  with no context has to ring back to ask what
//  it is, which is the support call the code was
//  supposed to avoid.
// ─────────────────────────────────────────────
String guardianMessage({required String code, required String memberName}) =>
    'كود بوابة ولي الأمر لمتابعة $memberName في نادي طبلة: $code\n'
    'أدخله في تطبيق النادي للاطّلاع على الحضور والمواعيد والاشتراكات.';

void shareGuardianCode(
  BuildContext context, {
  required String code,
  required String memberName,
  String? phone,
}) {
  final message = guardianMessage(code: code, memberName: memberName);

  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: GlobalColors.card(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.ios_share_rounded,
              color: GlobalColors.accentSoft,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'مشاركة الكود',
              style: TextStyle(
                color: GlobalColors.textPrimary(ctx),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlobalColors.surface(ctx),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GlobalColors.border(ctx)),
                ),
                child: SelectableText(
                  message,
                  style: TextStyle(
                    color: GlobalColors.textSecondary(ctx),
                    fontSize: 12,
                    height: 1.7,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _option(
                ctx,
                icon: Icons.chat_rounded,
                label: phone == null || phone.isEmpty
                    ? 'واتساب — اختيار جهة الاتصال'
                    : 'واتساب — $phone',
                color: GlobalColors.green,
                onTap: () => _open(
                  ctx,
                  // wa.me with no number opens the contact picker, which is
                  // what we want when the member has no phone on file.
                  Uri.parse(
                    'https://wa.me/'
                    '${_waNumber(phone)}'
                    '?text=${Uri.encodeComponent(message)}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _option(
                ctx,
                icon: Icons.mail_rounded,
                label: 'البريد الإلكتروني',
                color: GlobalColors.blue,
                onTap: () => _open(
                  ctx,
                  Uri(
                    scheme: 'mailto',
                    // Deliberately no recipient: the parent's address is not
                    // something the club holds, so the operator picks it in
                    // their mail client.
                    query:
                        'subject=${Uri.encodeComponent('كود بوابة ولي الأمر')}'
                        '&body=${Uri.encodeComponent(message)}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _option(
                ctx,
                icon: Icons.copy_rounded,
                label: 'نسخ الرسالة كاملة',
                color: GlobalColors.accentSoft,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message));
                  Navigator.pop(ctx);
                  MySnackBar.show(
                    context,
                    text: 'تم نسخ الرسالة.',
                    isSuccess: true,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إغلاق',
              style: TextStyle(color: GlobalColors.textSecondary(ctx)),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Strips a local number down to what wa.me accepts: digits only, and a
/// leading Saudi country code in place of the local 0.
String _waNumber(String? phone) {
  if (phone == null || phone.trim().isEmpty) return '';

  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = '966${digits.substring(1)}';

  return digits;
}

Future<void> _open(BuildContext context, Uri uri) async {
  final navigator = Navigator.of(context);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!context.mounted) return;
  navigator.pop();

  if (!opened) {
    MySnackBar.show(
      context,
      text: 'تعذّر فتح التطبيق. انسخ الرسالة بدلاً من ذلك.',
      isSuccess: false,
    );
  }
}

Widget _option(
  BuildContext ctx, {
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: GlobalColors.surface(ctx),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlobalColors.border(ctx)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: GlobalColors.textPrimary(ctx),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
