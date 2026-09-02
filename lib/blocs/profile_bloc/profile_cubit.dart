import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/profile_model.dart';
import '../../services/apis/profile_api.dart';
import '../../src/app_globals.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  PROFILE CUBIT — كيوبت الملف الشخصي
//  Drives one account's profile screen. The
//  screen is shared across roles, so this holds
//  no role-specific state — it just carries the
//  aggregate through and lets the screen pick
//  which sections to draw.
// ─────────────────────────────────────────────
class ProfileCubit extends Cubit<AppStates> {
  ProfileCubit(this.userId) : super(AppInitial());

  final int userId;
  final ProfileApi _api = ProfileApi();

  UserProfile profile = const UserProfile();

  // ── Enrolment form — نموذج الاشتراك ─────────
  int? formMembershipId;
  bool collectPayment = true;
  String formPaymentStatus = 'success';
  int? formSourceId;
  final TextEditingController amountCont = TextEditingController();
  final TextEditingController startCont = TextEditingController();
  final TextEditingController notesCont = TextEditingController();

  @override
  Future<void> close() {
    amountCont.dispose();
    startCont.dispose();
    notesCont.dispose();
    return super.close();
  }

  Future<void> fetch() async {
    emit(AppLoading());
    final r = await _api.fetchProfile(userId);
    if (!r.success) {
      emit(AppFailure(msg: r.message));
      return;
    }
    profile = UserProfile.fromJson(r.body);
    emit(AppLoaded());
  }

  // ── Enrolment ───────────────────────────────
  void resetEnrollForm() {
    formMembershipId = null;
    collectPayment = true;
    formPaymentStatus = 'success';
    formSourceId = AppGlobals.paymentSources
        .where((s) => s.isDefault)
        .map((s) => s.id)
        .firstOrNull;
    amountCont.clear();
    startCont.clear();
    notesCont.clear();
  }

  /// Pre-fills the amount from the membership price the moment one is
  /// picked, so the desk only types when the price is being overridden.
  void pickMembership(int? id) {
    formMembershipId = id;
    final m = AppGlobals.memberships.where((m) => m.id == id).firstOrNull;
    if (m?.price != null) amountCont.text = m!.price!.toStringAsFixed(2);
    emit(AppLoaded());
  }

  Future<void> submitEnrollment() async {
    if (formMembershipId == null) {
      emit(AppFailure(msg: 'يجب اختيار الاشتراك.'));
      return;
    }

    emit(AppLoading());
    final r = await _api.enroll(
      userId: userId,
      membershipId: formMembershipId!,
      collectPayment: collectPayment,
      startDate: startCont.text.trim(),
      amount: double.tryParse(amountCont.text.trim()),
      paymentSourceId: formSourceId,
      paymentStatus: formPaymentStatus,
      notes: notesCont.text.trim(),
    );

    if (!r.success) {
      emit(AppFailure(msg: r.message));
      return;
    }

    emit(AppSuccess(msg: r.message, shouldPop: true));
    await fetch();
  }

  Future<void> setEnrollmentStatus(dynamic id, String status) async {
    emit(AppLoading());
    final r = await _api.setEnrollmentStatus(id, status);
    if (!r.success) {
      emit(AppFailure(msg: r.message));
      return;
    }
    emit(AppSuccess(msg: r.message, shouldPop: false));
    await fetch();
  }
}
