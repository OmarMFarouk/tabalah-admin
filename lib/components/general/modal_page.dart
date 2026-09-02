import 'dart:ui';

import 'package:flutter/material.dart';

import '../../src/app_colors.dart';

// ─────────────────────────────────────────────
//  MODAL PAGE — صفحة كنافذة
//
//  For screens that used to be pushed routes with
//  a back button — the user profile, and anything
//  like it added later.
//
//  A pushed route replaces the whole window: the
//  top bar goes, the page underneath goes, and the
//  only way back is a button that looks like it
//  might mean "undo". Opening the same content as
//  a panel over the app keeps the context you came
//  from on screen, which is the point — you opened
//  a member's profile *from* a table, and that
//  table is still what you are working through.
//
//  Sized to start just below the top bar so the
//  bar stays visible and usable behind the blur.
// ─────────────────────────────────────────────
class ModalPage extends StatelessWidget {
  const ModalPage({super.key, required this.child, this.maxWidth = 1180});

  final Widget child;

  /// The panel is wide but not unbounded: past about this, table rows turn
  /// into long thin strips and the eye loses the line it is reading.
  final double maxWidth;

  /// Height of MyAppBar. The panel starts below it so the nav stays visible
  /// and clickable — you can switch tabs without closing the profile first.
  static const double topBarHeight = 62;

  /// The one way to open one.
  ///
  /// `useRootNavigator` matters: the panel has to sit above the shell's
  /// PageView, not inside whichever page opened it, or switching tabs
  /// underneath would tear it down mid-animation.
  static Future<T?> show<T>(BuildContext context, Widget child) {
    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      // Transparent on purpose: the panel paints its own full-screen blur
      // layer, and a barrier colour on top of the app would sit *between*
      // the app and that blur, greying out the thing we want to keep
      // recognisable.
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => child,
      transitionBuilder: (context, animation, _, page) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            // A short rise rather than a slide from the edge: it reads as
            // something surfacing over the page, not as navigating away
            // from it.
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: page,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          // ── The backdrop ──────────────────────────
          //  A full-screen BackdropFilter, not a tint. BackdropFilter only
          //  blurs what is behind *its own bounds*, so putting one inside
          //  the panel would have left the app around it — and the nav bar
          //  above it — perfectly sharp, which is not a backdrop blur, it is
          //  a frosted rectangle.
          //
          //  The dim is deliberately light. The point is that the table you
          //  opened this from stays recognisable underneath; darken it much
          //  further and you may as well have pushed a page.
          Positioned.fill(
            child: GestureDetector(
              // Our own dismiss: this layer sits above the route's
              // ModalBarrier and would otherwise swallow the taps that
              // barrierDismissible relies on.
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
              ),
            ),
          ),

          // ── The panel ─────────────────────────────
          Padding(
            // Top clears the nav bar, so it stays visible through the blur
            // and stays clickable — you can switch tab without closing this
            // first. The side and bottom margins keep enough of the app in
            // view that it reads as an overlay rather than a new screen.
            padding: const EdgeInsets.fromLTRB(24, topBarHeight + 12, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                // Fills the padded area rather than shrink-wrapping. The
                // pages that go in here are Columns with an Expanded list
                // inside, and those need a bounded height — shrink-wrapping
                // would hand them an unbounded one and throw on layout.
                child: SizedBox.expand(
                  child: GestureDetector(
                    // Swallow taps on the panel so they don't reach the
                    // dismiss layer underneath.
                    onTap: () {},
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        // A second, gentler blur under the panel's own
                        // surface. The surface is nearly opaque for the sake
                        // of reading tables through it; this is what stops
                        // the remaining translucency looking like a flat
                        // wash and gives it the frosted edge.
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: GlobalColors.bg(
                              context,
                            ).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: GlobalColors.accent.withValues(
                                alpha: 0.22,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 44,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MODAL HEADER — رأس النافذة
//
//  Replaces the back arrow a pushed page needed.
//  A close button, not a back arrow: nothing is
//  being navigated away from, so an arrow would be
//  describing the wrong thing.
// ─────────────────────────────────────────────
class ModalHeader extends StatelessWidget {
  const ModalHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.actions = const [],
    this.isLoading = false,
    this.onRefresh,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> actions;
  final bool isLoading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      decoration: BoxDecoration(
        color: GlobalColors.surface(context).withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: GlobalColors.border(context))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  GlobalColors.accent.withValues(alpha: 0.22),
                  GlobalColors.accentSoft.withValues(alpha: 0.10),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: GlobalColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, size: 20, color: GlobalColors.accentSoft),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: GlobalColors.textSecondary(context),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (isLoading) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(GlobalColors.accent),
              ),
            ),
            const SizedBox(width: 14),
          ],
          ...actions,
          if (onRefresh != null)
            IconButton(
              onPressed: onRefresh,
              tooltip: 'تحديث',
              icon: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: GlobalColors.textSecondary(context),
              ),
            ),
          const SizedBox(width: 4),
          ModalCloseButton(onTap: () => Navigator.of(context).maybePop()),
        ],
      ),
    );
  }
}

/// The dismiss control for a [ModalPage]. Public so a screen with its
/// own header - the profile has one - can use the same button rather
/// than growing a second style of close.
class ModalCloseButton extends StatefulWidget {
  const ModalCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<ModalCloseButton> createState() => _ModalCloseButtonState();
}

class _ModalCloseButtonState extends State<ModalCloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered
                ? GlobalColors.red.withValues(alpha: 0.16)
                : GlobalColors.card(context).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? GlobalColors.red.withValues(alpha: 0.4)
                  : GlobalColors.border(context),
            ),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: _hovered
                ? GlobalColors.red
                : GlobalColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
