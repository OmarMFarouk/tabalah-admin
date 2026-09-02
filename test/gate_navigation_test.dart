import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabalah_admin/blocs/auth_bloc/auth_cubit.dart';
import 'package:tabalah_admin/models/users_model.dart';
import 'package:tabalah_admin/screens/auth.dart';
import 'package:tabalah_admin/screens/index.dart';
import 'package:tabalah_admin/src/app_globals.dart';
import 'package:tabalah_admin/src/app_root.dart';
import 'package:tabalah_admin/src/app_shared.dart';

/// Regression test for "login returns 200 and nothing happens".
///
/// The gate used to decide what to show from a Future captured at launch, and
/// the API client's 401 handler used to `pushReplacement` over it — which
/// destroyed the gate, since it sits at the root route. From then on a
/// successful login set `AppGlobals.currentUser`, emitted its states, and
/// moved nothing, because the only widget that knew how to reach the
/// dashboard no longer existed. A stale token on launch was enough to do it.
///
/// What this pins down is the property that was actually broken: **the
/// visible screen must follow `AppGlobals.isReady` at all times**, not just
/// once at startup.
///
/// `flutter_secure_storage` has no plugin in the test harness, so
/// `restoreSession()` throws and is caught — which is exactly the
/// "no usable stored session" path, and lands the gate on the login card.
void main() {
  // AppCubit reads AppShared.localStorage, which main() sets up through
  // AppPresets.init(). The window-manager half of that needs a real desktop
  // window, so the test does just the preferences half.
  setUp(() async {
    SharedPreferences.setMockInitialValues({'theme': true});
    await AppShared.init();
    AppGlobals.clear();
  });
  tearDown(AppGlobals.clear);

  /// Lets real async work finish, then advances a few frames.
  ///
  /// Two things make the obvious `pumpAndSettle()` wrong here. The splash and
  /// the login card both run indefinite animations, so nothing ever settles
  /// and it times out. And `restoreSession()` awaits the secure-storage
  /// plugin, which has no implementation in the test harness — the resulting
  /// MissingPluginException is a *real* async event, so it needs
  /// `runAsync` to resolve before any pump can observe the result.
  Future<void> frames(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('no usable session -> login card', (tester) async {
    await tester.pumpWidget(const AppRoot());
    await frames(tester);

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(MainDashboard), findsNothing);
  });

  testWidgets('session appears -> gate moves to the dashboard', (tester) async {
    await tester.pumpWidget(const AppRoot());
    await frames(tester);
    expect(find.byType(AuthScreen), findsOneWidget);

    // Exactly what a successful login does: set the account, then emit.
    final context = tester.element(find.byType(AuthScreen));
    AppGlobals.currentUser = User(name: 'ليلى الدوسري', role: 'admin');
    // Stands in for the states login emits (AppLoaded from bootstrapLookups,
    // then AppSuccess) — the gate rebuilds on any of them.
    AuthCubit.get(context).toggleObscure();
    await frames(tester);

    expect(
      find.byType(MainDashboard),
      findsOneWidget,
      reason: 'the gate must follow isReady, not a Future captured at launch',
    );
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('session revoked -> gate returns to the login card', (
    tester,
  ) async {
    await tester.pumpWidget(const AppRoot());
    await frames(tester);

    AppGlobals.currentUser = User(name: 'ليلى الدوسري', role: 'admin');
    AuthCubit.get(tester.element(find.byType(AuthScreen))).toggleObscure();
    await frames(tester);
    expect(find.byType(MainDashboard), findsOneWidget);

    // A 401 anywhere: ApiClient clears the globals and calls this.
    AuthCubit.get(tester.element(find.byType(MainDashboard))).sessionExpired();
    await frames(tester);

    expect(
      find.byType(AuthScreen),
      findsOneWidget,
      reason: 'an expired token must land on the login card, not a dead route',
    );
    expect(find.byType(MainDashboard), findsNothing);
  });
}
