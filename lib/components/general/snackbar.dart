import 'package:flutter/material.dart';

import '../../src/app_colors.dart';
import '../../src/app_navigator.dart';

// ─────────────────────────────────────────────
//  TOASTS — التنبيهات
//
//  Replaces the stock SnackBar, which stretched
//  the full window width and pinned itself to the
//  bottom — on a wide desktop panel that meant a
//  four-word "تم الحفظ" spanning the whole screen,
//  nowhere near where the click happened.
//
//  These sit top-right under the app bar, sized to
//  their content up to a cap, stack when several
//  arrive at once, and count themselves out with a
//  progress bar. The API is unchanged, so every
//  existing MySnackBar.show call still works.
// ─────────────────────────────────────────────

/// Widest a toast may grow. Past this the text wraps instead — a long server
/// error shouldn't be allowed to span the window.
const double _kMaxWidth = 380;

/// Clears MyAppBar (62px) plus a margin, so a toast never covers the nav.
/// On screens without the bar (login) it simply reads as a top inset.
const double _kTopInset = 78;

const double _kRightInset = 20;

/// Beyond this, older toasts are retired to make room. Three is enough to
/// see a burst without burying the screen.
const int _kMaxVisible = 3;

class MySnackBar {
  MySnackBar._();

  static final List<_ToastData> _queue = [];
  static final ValueNotifier<int> _revision = ValueNotifier(0);
  static OverlayEntry? _host;

  /// Unchanged signature — every existing call site keeps working.
  static void show(
    BuildContext context, {
    required String text,
    required bool isSuccess,
  }) {
    final message = text.trim();
    if (message.isEmpty) return;

    final overlay = _overlayFor(context);
    if (overlay == null) return;

    // The same message twice running is almost always a double-tap or a
    // cubit emitting on two paths; refresh the live one rather than stack a
    // duplicate.
    for (final t in _queue) {
      if (t.text == message) {
        t.restart?.call();
        return;
      }
    }

    _queue.add(_ToastData(text: message, isSuccess: isSuccess));
    while (_queue.length > _kMaxVisible) {
      _queue.removeAt(0);
    }

    _mount(overlay);
    _revision.value++;
  }

  /// Dismisses everything on screen.
  static void clear() {
    if (_queue.isEmpty) return;
    _queue.clear();
    _revision.value++;
    _unmountIfEmpty();
  }

  // ── Plumbing ───────────────────────────────

  static OverlayState? _overlayFor(BuildContext context) {
    // rootOverlay so a toast raised from inside a dialog lands on the window
    // rather than inside the dialog, where it would be clipped and would die
    // with it.
    final local = Overlay.maybeOf(context, rootOverlay: true);
    if (local != null) return local;

    // Fallback for calls made where the context has no overlay of its own.
    return AppNavigator.navigatorKey.currentState?.overlay;
  }

  static void _mount(OverlayState overlay) {
    if (_host != null) return;

    _host = OverlayEntry(
      builder: (_) => Positioned(
        top: _kTopInset,
        right: _kRightInset,
        // Fixed-width column, so a stack of toasts shares one left edge.
        // Letting each size to its own content made short and long messages
        // start at different x positions - the "scattered" look.
        child: SizedBox(
          width: _kMaxWidth,
          child: ValueListenableBuilder<int>(
            valueListenable: _revision,
            builder: (_, __, ___) => Material(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in _queue)
                    _Toast(
                      key: ValueKey(t.id),
                      data: t,
                      onDismiss: () => _remove(t),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_host!);
  }

  static void _remove(_ToastData t) {
    if (!_queue.remove(t)) return;
    _revision.value++;
    _unmountIfEmpty();
  }

  static void _unmountIfEmpty() {
    if (_queue.isNotEmpty) return;
    _host?.remove();
    _host = null;
  }
}

class _ToastData {
  _ToastData({required this.text, required this.isSuccess})
    : id = DateTime.now().microsecondsSinceEpoch;

  final int id;
  final String text;
  final bool isSuccess;

  /// Set by the widget once mounted, so a repeat message resets the
  /// countdown instead of queueing behind itself.
  VoidCallback? restart;
}

// ─────────────────────────────────────────────
//  ONE TOAST
//  Slides in from the right, holds, then leaves
//  the same way. Errors linger longer than
//  confirmations — a failure is worth reading
//  twice, "تم الحفظ" is not.
// ─────────────────────────────────────────────
class _Toast extends StatefulWidget {
  const _Toast({super.key, required this.data, required this.onDismiss});

  final _ToastData data;
  final VoidCallback onDismiss;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: widget.data.isSuccess
        ? const Duration(milliseconds: 3200)
        : const Duration(milliseconds: 5000),
  );

  bool _hovering = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    widget.data.restart = _restart;
    _enter.forward();
    _life.forward();
    _life.addStatusListener((s) {
      if (s == AnimationStatus.completed) _dismiss();
    });
  }

  void _restart() {
    if (!mounted) return;
    _life
      ..reset()
      ..forward();
  }

  Future<void> _dismiss() async {
    // Guards the timer and a click both firing.
    if (_leaving || !mounted) return;
    _leaving = true;
    await _enter.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    widget.data.restart = null;
    _enter.dispose();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = widget.data.isSuccess;
    final accent = ok ? GlobalColors.green : GlobalColors.red;

    final curve = CurvedAnimation(
      parent: _enter,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        // Comes in from the right edge it is anchored to.
        position: Tween<Offset>(
          begin: const Offset(0.35, 0),
          end: Offset.zero,
        ).animate(curve),
        child: SizeTransition(
          sizeFactor: curve,
          axisAlignment: -1,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MouseRegion(
              // Pausing on hover means a long error can actually be read.
              onEnter: (_) {
                setState(() => _hovering = true);
                _life.stop();
              },
              onExit: (_) {
                setState(() => _hovering = false);
                if (!_leaving) _life.forward();
              },
              child: GestureDetector(
                onTap: _dismiss,
                child: SizedBox(
                  width: double.infinity,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Container(
                      decoration: BoxDecoration(
                        color: GlobalColors.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accent.withValues(
                            alpha: _hovering ? 0.55 : 0.3,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: accent.withValues(alpha: 0.12),
                            blurRadius: 18,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    ok
                                        ? Icons.check_rounded
                                        : Icons.priority_high_rounded,
                                    color: accent,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        ok ? 'تم' : 'تعذّر إتمام العملية',
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.data.text,
                                        // Long validation errors wrap rather
                                        // than stretching the toast.
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: GlobalColors.textPrimary(
                                            context,
                                          ),
                                          fontSize: 12.5,
                                          height: 1.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: _dismiss,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 15,
                                      color: GlobalColors.textSecondary(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Time remaining, so a toast never vanishes
                          // without warning.
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                            child: AnimatedBuilder(
                              animation: _life,
                              builder: (_, __) => LinearProgressIndicator(
                                value: 1 - _life.value,
                                minHeight: 2.5,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation(
                                  accent.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
