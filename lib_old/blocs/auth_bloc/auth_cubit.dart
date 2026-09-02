import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/catalog_model.dart';
import '../../models/finance_model.dart';
import '../../models/paginated_model.dart';
import '../../models/users_model.dart';
import '../../services/apis/auth_api.dart';
import '../../services/apis/catalog_api.dart';
import '../../services/apis/finance_api.dart';
import '../../services/apis/people_api.dart';
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
    final r = await AuthApi().login(
      email: emailCont.text.trim(),
      password: passwordCont.text,
    );

    if (!r.success) {
      emit(
        AppFailure(msg: r.message.isEmpty ? 'تعذّر تسجيل الدخول.' : r.message),
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
  Future<bool> restoreSession() async {
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

    AppGlobals.currentUser = user ?? User(name: 'فريق العمل', role: 'employee');
    AppGlobals.currentUser!.role ??= 'employee';
    await bootstrapLookups();
    return true;
  }

  // Warms every dropdown the panel needs in one pass.
  Future<void> bootstrapLookups() async {
    final results = await Future.wait([
      CatalogApi().fetchSports(perPage: 100),
      CatalogApi().fetchMemberships(perPage: 100),
      PeopleApi().fetchTrainers(perPage: 100),
      FinanceApi().fetchSources(perPage: 100),
      PeopleApi().fetchUsers(role: 'player', perPage: 100),
      PeopleApi().fetchEmployees(perPage: 100),
    ]);

    if (results[0].success) {
      AppGlobals.sports =
          Paginated.parse<Sport>(results[0]['sports'], Sport.fromJson).items;
    }
    if (results[1].success) {
      AppGlobals.memberships = Paginated.parse<Membership>(
        results[1]['memberships'],
        Membership.fromJson,
      ).items;
    }
    if (results[2].success) {
      AppGlobals.trainers = Paginated.parse<TrainerProfile>(
        results[2]['trainers'],
        TrainerProfile.fromJson,
      ).items;
    }
    if (results[3].success) {
      AppGlobals.paymentSources = Paginated.parse<PaymentSource>(
        results[3]['payment_sources'],
        PaymentSource.fromJson,
      ).items;
    }
    if (results[4].success) {
      AppGlobals.members =
          Paginated.parse<User>(results[4]['users'], User.fromJson).items;
    }
    if (results[5].success) {
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
    }

    emit(AppLoaded());
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
