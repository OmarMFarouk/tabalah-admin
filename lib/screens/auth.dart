import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_bloc/auth_cubit.dart';
import '../blocs/base_states.dart';
import '../components/general/app_field.dart';
import '../components/general/snackbar.dart';
import '../src/app_assets.dart';
import '../src/app_colors.dart';
import '../src/app_presets.dart';

// ─────────────────────────────────────────────
//  AUTH SCREEN — تسجيل الدخول
//  The panel is staff-only; a member's token is
//  turned away before any screen loads.
// ─────────────────────────────────────────────
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      // SelectionArea sits here, per screen, rather than once in
      // MaterialApp.builder. `builder` wraps the Navigator, so a
      // SelectionArea there would be ABOVE the Overlay and its
      // copy/select context menu would have nowhere to mount - the same
      // trap Tooltip hits in that position. Inside a route the Overlay is
      // an ancestor, so right-click copy works.
      child: SelectionArea(
        child: Scaffold(
          backgroundColor: GlobalColors.bg(context),
          body: GestureDetector(
            onPanStart: (_) => AppPresets.instance.startDragging(),
            child: Stack(
              children: [
                // Ambient wash behind the card
                Positioned(
                  top: -160,
                  left: -120,
                  child: Container(
                    width: 460,
                    height: 460,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GlobalColors.accent.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -180,
                  right: -100,
                  child: Container(
                    width: 420,
                    height: 420,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GlobalColors.accentSoft.withValues(alpha: 0.07),
                    ),
                  ),
                ),

                // Close button — the window is frameless here too
                Positioned(
                  top: 18,
                  right: 18,
                  child: IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => AppPresets.instance.close(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: GlobalColors.textSecondary(context),
                      size: 20,
                    ),
                  ),
                ),

                Center(
                  child: BlocConsumer<AuthCubit, AppStates>(
                    listener: (ctx, state) {
                      if (state is AppFailure) {
                        MySnackBar.show(ctx, text: state.msg, isSuccess: false);
                      }
                    },
                    builder: (ctx, state) {
                      final cubit = AuthCubit.get(ctx);
                      final busy = state is AppBusy;

                      return Container(
                        width: 430,
                        padding: const EdgeInsets.all(34),
                        decoration: BoxDecoration(
                          color: GlobalColors.surface(context),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: GlobalColors.border(context),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: Image.asset(AppAssets.logo),
                            ),
                            const SizedBox(height: 16),
                            ShaderMask(
                              shaderCallback: (b) => LinearGradient(
                                colors: [
                                  GlobalColors.accentSoft,
                                  GlobalColors.accent,
                                ],
                              ).createShader(b),
                              child: const Text(
                                'Tabalah Club',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'لوحة تحكم النادي',
                              style: TextStyle(
                                color: GlobalColors.textSecondary(context),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 30),

                            AppField(
                              controller: cubit.emailCont,
                              label: 'البريد الإلكتروني',
                              icon: Icons.alternate_email_rounded,
                            ),
                            const SizedBox(height: 14),
                            AppField(
                              controller: cubit.passwordCont,
                              label: 'كلمة المرور',
                              icon: Icons.lock_rounded,
                              isObscure: cubit.obscure,
                              suffix: IconButton(
                                onPressed: cubit.toggleObscure,
                                icon: Icon(
                                  cubit.obscure
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  size: 18,
                                  color: GlobalColors.textSecondary(context),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: busy ? null : cubit.login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GlobalColors.accent,
                                  disabledBackgroundColor: GlobalColors.accent
                                      .withValues(alpha: 0.4),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'دخول',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 18),
                            Text(
                              'الدخول متاح لفريق العمل فقط.',
                              style: TextStyle(
                                color: GlobalColors.textSecondary(
                                  context,
                                ).withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
