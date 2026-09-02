// ─────────────────────────────────────────────
//  SPLASH — شاشة البدء
//
//  Shown while the saved session is restored, so
//  it is on screen for a beat or two — long enough
//  that a bare spinner reads as a stall. The
//  entrance runs once; the sheen and the glow keep
//  breathing so the window never looks frozen if
//  the network is slow.
//
//  Everything here is Flutter-only: no packages,
//  no shader files, and no dependency on the logo
//  asset existing.
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../src/app_assets.dart';
import '../src/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Plays once: fade, rise, and settle.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  // Loops: the ambient glow behind the mark, and the gold sweep across it.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    final rise = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: GlobalColors.bg(context),
        body: Stack(
          children: [
            // Ambient wash — keeps the flat background from reading as a
            // failed render on a large desktop window.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ambient,
                builder: (_, __) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.25),
                      radius: 0.9 + (_ambient.value * 0.14),
                      colors: [
                        GlobalColors.accent.withValues(
                          alpha: 0.10 + (_ambient.value * 0.05),
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Center(
              child: FadeTransition(
                opacity: fade,
                child: SlideTransition(
                  position: rise,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Mark(ambient: _ambient, sweep: _sweep),
                      const SizedBox(height: 28),
                      Text(
                        'نظام إدارة النادي',
                        style: TextStyle(
                          color: GlobalColors.textSecondary(context),
                          fontSize: 13,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 34),
                      _ProgressTrack(sweep: _sweep),
                      const SizedBox(height: 14),
                      Text(
                        'جارٍ تجهيز لوحة التحكم...',
                        style: TextStyle(
                          color: GlobalColors.textSecondary(
                            context,
                          ).withValues(alpha: 0.65),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Quiet footer, so the lower half of a tall window isn't empty.
            Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              child: FadeTransition(
                opacity: fade,
                child: Text(
                  'Tabalah Club',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GlobalColors.textSecondary(
                      context,
                    ).withValues(alpha: 0.35),
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MARK — العلامة
//  The wordmark inside a soft gold halo, with a
//  highlight sweeping across it. Falls back to a
//  text wordmark when the asset is absent, so a
//  missing file shows the brand rather than
//  Flutter's red error box.
// ─────────────────────────────────────────────
class _Mark extends StatelessWidget {
  const _Mark({required this.ambient, required this.sweep});

  final Animation<double> ambient;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([ambient, sweep]),
      builder: (_, __) {
        final t = sweep.value;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: GlobalColors.accent.withValues(
                alpha: 0.14 + (ambient.value * 0.10),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: GlobalColors.accent.withValues(
                  alpha: 0.10 + (ambient.value * 0.07),
                ),
                blurRadius: 46,
                spreadRadius: -6,
              ),
            ],
          ),
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              // A narrow bright band travelling left to right. Sitting the
              // band inside two gold stops keeps the mark gold at rest
              // rather than flashing white end to end.
              begin: Alignment(-2.2 + (t * 4.4), 0),
              end: Alignment(-1.2 + (t * 4.4), 0),
              colors: [
                GlobalColors.accent,
                GlobalColors.accentSoft,
                Colors.white,
                GlobalColors.accentSoft,
                GlobalColors.accent,
              ],
              stops: const [0.0, 0.32, 0.5, 0.68, 1.0],
            ).createShader(bounds),
            child: Image.asset(
              AppAssets.slogan,
              width: 250,
              height: 250,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              // No asset, no crash — the brand still reads.
              errorBuilder: (_, __, ___) => const Text(
                'Tabalah',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  PROGRESS — الشريط
//  A sweeping bar rather than CircularProgress-
//  Indicator: it reads as motion at a glance and
//  matches the mark's highlight instead of
//  fighting it.
// ─────────────────────────────────────────────
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.sweep});

  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: 210,
        height: 3,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: GlobalColors.accent.withValues(alpha: 0.12),
              ),
            ),
            AnimatedBuilder(
              animation: sweep,
              builder: (_, __) => Align(
                // -1 parks the bar off the left edge, 1 off the right.
                alignment: Alignment(-1 + (sweep.value * 2), 0),
                // Sized outright rather than fractionally: a
                // FractionallySizedBox with no heightFactor leaves the child
                // loosely constrained, and a gradient box with no intrinsic
                // height collapses to nothing.
                child: Container(
                  width: 80,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        GlobalColors.accent.withValues(alpha: 0),
                        GlobalColors.accentSoft,
                        GlobalColors.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
