import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blocs/auth_bloc/auth_cubit.dart';
import 'app_colors.dart';
import 'app_navigator.dart';

// ─────────────────────────────────────────────
//  IDLE GUARD — إنهاء الجلسة عند عدم النشاط
//  The panel sits on shared desks. After fifteen
//  minutes with no mouse or keyboard input the
//  session is signed out, and a dialog that cannot
//  be dismissed says so — otherwise the next
//  person at the desk would just see the login
//  card and not know why.
// ─────────────────────────────────────────────

class IdleGuard extends StatefulWidget {
  const IdleGuard({super.key, required this.child});

  final Widget child;

  static const timeout = Duration(minutes: 15);

  @override
  State<IdleGuard> createState() => _IdleGuardState();
}

class _IdleGuardState extends State<IdleGuard> {
  DateTime _lastActivity = DateTime.now();
  Timer? _ticker;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    // A timestamp checked twice a minute, rather than a timer restarted on
    // every mouse move: hover fires hundreds of events a second.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent _) {
    _touch();
    return false;
  }

  void _touch() => _lastActivity = DateTime.now();

  Future<void> _check() async {
    if (_expired || DateTime.now().difference(_lastActivity) < IdleGuard.timeout) return;
    _expired = true;
    _ticker?.cancel();

    final ctx = AppNavigator.navigatorKey.currentContext;
    if (ctx == null) return;
    final auth = AuthCubit.get(context);

    // Shown before signing out: the dialog lives on the navigator's overlay,
    // so it stays up over the login card the gate swaps in underneath.
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: GlobalColors.card(dialogContext),
            icon: Icon(Icons.lock_clock_rounded, size: 42, color: GlobalColors.accent),
            title: const Text('انتهت الجلسة'),
            content: const Text(
              'تم تسجيل خروجك تلقائياً بعد 15 دقيقة دون نشاط.\nسجّل الدخول مجدداً للمتابعة.',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('تسجيل الدخول'),
                style: FilledButton.styleFrom(backgroundColor: GlobalColors.accent),
              ),
            ],
          ),
        ),
      ),
    );

    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _touch(),
      onPointerHover: (_) => _touch(),
      onPointerSignal: (_) => _touch(),
      child: widget.child,
    );
  }
}
