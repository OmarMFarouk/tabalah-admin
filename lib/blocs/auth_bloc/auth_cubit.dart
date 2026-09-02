import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/catalog_model.dart';
import '../../models/finance_model.dart';
import '../../models/paginated_model.dart';
import '../../models/settings_model.dart';
import '../../models/users_model.dart';
import '../../services/apis/auth_api.dart';
import '../../services/apis/catalog_api.dart';
import '../../services/apis/finance_api.dart';
import '../../services/apis/people_api.dart';
import '../../services/apis/settings_api.dart';
import '../../src/app_globals.dart';
import '../../src/app_secured.dart';
import '../../services/apis/api_client.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  AUTH CUBIT — الدخول والصلاحيات
//  Signs staff in, then warms the lookup lists
//  every screen's dropdowns read from.
// ─────────────────────────────────────────────
class AuthCubit extends Cubit<AppStates> {
  AuthCubit() : super(AppInitial());
  static AuthCubit get(context) => BlocProvider.of(context);

  final TextEditingController emailCont = TextEditingController();
  final TextEditingController passwordCont = TextEditingController();
  bool obscure = true;

  void toggleObscure() {
    obscure = !obscure;
    emit(AppInitial());
  }

  Future<void> login() async {
    if (emailCont.text.trim().isEmpty || passwordCont.text.isEmpty) {
      emit(AppFailure(msg: 'أدخل البريد وكلمة المرور.'));
      return;
    }

    emit(AppBusy());

    // The whole body is guarded, and that is the point rather than defensive
    // habit. `AppBusy` is what draws the spinner, and the only thing that
    // clears it is a later emit. So *any* escape from this method - a throw,
    // a bad cast, a null - leaves the button spinning for ever with no
    // message and nothing logged. That is the exact symptom this fixes:
    // "it loads and never gives a reason". Whatever goes wrong, the user
    // gets told something.
    try {
      final r = await AuthApi().login(
        email: emailCont.text.trim(),
        password: passwordCont.text,
      );

      if (!r.success) {
        emit(
          AppFailure(
            msg: r.message.isEmpty ? 'تعذّر تسجيل الدخول.' : r.message,
          ),
        );
        return;
      }

      // AuthApi has stored the token by now, so the calls below are signed.
      User? user = _userFrom(r);

      // The login payload doesn't reliably carry `role`. Ask the profile
      // endpoint rather than assume its absence means "not staff".
      if (user?.role == null) {
        user = _userFrom(await AuthApi().profile()) ?? user;
      }

      final admitted = await _admitToPanel(user);
      if (!admitted) return;

      await bootstrapLookups();
      emit(AppSuccess(msg: 'أهلاً ${AppGlobals.currentUser?.name ?? ''}'));
    } catch (e, st) {
      log('login failed: $e\n$st');
      emit(AppFailure(msg: 'تعذّر إكمال تسجيل الدخول: $e'));
    }
  }

  // The server is the authority on who may open the panel: /admin/* sits
  // behind role:super-admin,admin,employee and answers 403 to anyone else.
  // Asking it directly means a role string the client failed to parse
  // can't lock out a legitimate member of staff.
  Future<bool> _admitToPanel(User? user) async {
    final probe = await AuthApi().probePanelAccess();

    if (probe.isForbidden) {
      await AppSecured.delete(ApiClient.tokenKey);
      emit(AppFailure(msg: 'هذا الحساب لا يملك صلاحية دخول لوحة التحكم.'));
      return false;
    }

    if (probe.isUnauthorized) {
      await AppSecured.delete(ApiClient.tokenKey);
      emit(AppFailure(msg: 'انتهت صلاحية الجلسة — سجّل الدخول من جديد.'));
      return false;
    }

    if (!probe.success) {
      // A network or server fault, not a permission verdict.
      emit(AppFailure(msg: probe.message));
      return false;
    }

    // Admitted. If the role never resolved, fall back to the *lowest*
    // staff tier: the panel opens, admin-only buttons stay hidden, and
    // the server still refuses anything beyond that anyway.
    AppGlobals.currentUser =
        user ?? User(name: emailCont.text.trim(), role: 'employee');
    if (AppGlobals.currentUser!.role == null) {
      AppGlobals.currentUser!.role = 'employee';
    }
    return true;
  }

  // Pulls the account out of whichever key the endpoint wrapped it in.
  User? _userFrom(ApiResponse r) {
    if (!r.success) return null;
    final node = r['user'] ?? r['data'] ?? r['profile'];
    if (node is Map) {
      return User.fromJson(Map<String, dynamic>.from(node));
    }
    // Some endpoints return the account at the top level of the envelope.
    if (r.body['email'] != null || r.body['user_id'] != null) {
      return User.fromJson(r.body);
    }
    return null;
  }

  // Restores a saved session on launch.
  //
  // Guarded for the same reason login() is, and the consequence here is
  // worse: the gate holds the splash screen until this Future settles, so a
  // throw or a stalled request means the app never gets past the splash at
  // all. Failing means "show the login card", which is always a recoverable
  // place to land.
  Future<bool> restoreSession() async {
    try {
      final token = await AppSecured.readString(ApiClient.tokenKey);
      if (token == null || token.isEmpty) return false;

      // Identify the account properly rather than assuming a tier — the
      // stored token might belong to an employee, and fabricating an admin
      // here would show them buttons the server will only reject.
      final user = _userFrom(await AuthApi().profile());

      final probe = await AuthApi().probePanelAccess();
      if (!probe.success) {
        if (probe.isForbidden || probe.isUnauthorized) {
          await AppSecured.delete(ApiClient.tokenKey);
        }
        return false;
      }

      AppGlobals.currentUser =
          user ?? User(name: 'فريق العمل', role: 'employee');
      AppGlobals.currentUser!.role ??= 'employee';
      await bootstrapLookups();
      return true;
    } catch (e, st) {
      log('restoreSession failed: $e\n$st');
      return false;
    }
  }

  // Warms every dropdown the panel needs in one pass.
  //
  // Every step is individually guarded, because this runs *inside* the login
  // flow: a throw here used to escape login() entirely and strand the cubit
  // on AppBusy. A lookup that fails should cost the panel one empty dropdown,
  // not the ability to sign in - the screens re-fetch their own data anyway,
  // and these lists are a convenience.
  Future<void> bootstrapLookups() async {
    void guard(String what, void Function() body) {
      try {
        body();
      } catch (e) {
        log('bootstrapLookups: $what failed: $e');
      }
    }

    final results = await Future.wait([
      CatalogApi().fetchSports(perPage: 100),
      CatalogApi().fetchMemberships(perPage: 100),
      PeopleApi().fetchTrainers(perPage: 100),
      FinanceApi().fetchSources(perPage: 100),
      PeopleApi().fetchUsers(role: 'player', perPage: 100),
      PeopleApi().fetchEmployees(perPage: 100),
      SettingsApi().fetchRoles(),
    ]);

    if (results[0].success) {
      guard('sports', () {
        AppGlobals.sports =
            Paginated.parse<Sport>(results[0]['sports'], Sport.fromJson).items;
      });
    }
    if (results[1].success) {
      guard('memberships', () {
        AppGlobals.memberships = Paginated.parse<Membership>(
          results[1]['memberships'],
          Membership.fromJson,
        ).items;
      });
    }
    if (results[2].success) {
      guard('trainers', () {
        AppGlobals.trainers = Paginated.parse<TrainerProfile>(
          results[2]['trainers'],
          TrainerProfile.fromJson,
        ).items;
      });
    }
    if (results[3].success) {
      guard('payment sources', () {
        AppGlobals.paymentSources = Paginated.parse<PaymentSource>(
          results[3]['payment_sources'],
          PaymentSource.fromJson,
        ).items;
      });
    }
    if (results[4].success) {
      guard('members', () {
        AppGlobals.members =
            Paginated.parse<User>(results[4]['users'], User.fromJson).items;
      });
    }
    if (results[5].success) {
      guard('staff', () {
        AppGlobals.staff = Paginated.parse<EmployeeProfile>(
        results[5]['employees'],
        EmployeeProfile.fromJson,
          ).items
          // The staff dropdowns key on `user_id`, so carry the account
          // across rather than keeping only the display name.
          .map(
            (e) => User(
              userId: e.userId,
              name: e.name,
              email: e.email,
              phone: e.phone,
              role: e.role ?? 'employee',
            ),
            )
            .toList();
      });
    }

    if (results[6].success) {
      guard('access roles', () {
        AppGlobals.accessRoles = Paginated.parse<AccessRole>(
          results[6]['roles'],
          AccessRole.fromJson,
        ).items;
      });
    }

    emit(AppLoaded());
  }

  /// The server rejected our token: expired, revoked, or the account signed
  /// in somewhere else (the backend keeps one session per user, so logging in
  /// on another machine invalidates this one).
  ///
  /// ApiClient has already cleared the token and the globals by the time this
  /// runs; emitting is what makes the gate notice and show the login card.
  void sessionExpired() {
    AppGlobals.clear();
    if (!isClosed) emit(AppFailure(msg: 'انتهت صلاحية الجلسة — سجّل الدخول من جديد.'));
  }

  Future<void> logout() async {
    emit(AppBusy());
    await AuthApi().logout();
    AppGlobals.clear();
    emailCont.clear();
    passwordCont.clear();
    emit(AppInitial());
  }
}
