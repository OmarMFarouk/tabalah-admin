import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/paginated_model.dart';
import '../../models/sessions_model.dart';
import '../../services/apis/api_client.dart';
import '../../services/apis/hr_api.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  EVALUATIONS — التقييمات
//  Members assessed by their trainers, trainers by
//  their members, and staff by whoever manages
//  them — one list, filtered by who was rated.
// ─────────────────────────────────────────────

enum EvaluationTab { all, players, trainers, staff }

extension EvaluationTabX on EvaluationTab {
  String get label => switch (this) {
    EvaluationTab.all => 'الكل',
    EvaluationTab.players => 'الأعضاء',
    EvaluationTab.trainers => 'المدربون',
    EvaluationTab.staff => 'الموظفون',
  };

  IconData get icon => switch (this) {
    EvaluationTab.all => Icons.star_rate_rounded,
    EvaluationTab.players => Icons.people_alt_rounded,
    EvaluationTab.trainers => Icons.sports_rounded,
    EvaluationTab.staff => Icons.badge_rounded,
  };

  /// What the API filters the ratee's role on.
  String? get role => switch (this) {
    EvaluationTab.all => null,
    EvaluationTab.players => 'player',
    EvaluationTab.trainers => 'trainer',
    EvaluationTab.staff => 'staff',
  };
}

class EvaluationsCubit extends Cubit<AppStates> {
  EvaluationsCubit() : super(AppInitial());

  static EvaluationsCubit get(context) => BlocProvider.of(context);

  final HrApi _api = HrApi();

  EvaluationTab tab = EvaluationTab.all;
  int page = 1;
  final searchCont = TextEditingController();
  String? from;
  String? to;

  Paginated<SessionRating> rows = Paginated(items: []);
  double? average;

  // ── Form ────────────────────────────────────
  /// Which pool the person is picked from: player, trainer or staff.
  String formRole = 'staff';
  int? formUserId;
  double formRating = 4;
  final noteCont = TextEditingController();

  @override
  Future<void> close() {
    searchCont.dispose();
    noteCont.dispose();
    return super.close();
  }

  Future<void> fetch() async {
    emit(AppLoading());
    final r = await _api.fetchEvaluations(
      role: tab.role,
      q: searchCont.text.trim(),
      from: from,
      to: to,
      page: page,
    );
    if (!r.success) return emit(AppFailure(msg: r.message));

    rows = Paginated.read<SessionRating>(r.body, 'session_ratings', SessionRating.fromJson);
    average = asDouble(r.body['average']);

    if (rows.isOrphanedPage) {
      page = 1;
      return fetch();
    }
    emit(AppLoaded());
  }

  void switchTab(EvaluationTab t) {
    tab = t;
    page = 1;
    fetch();
  }

  void setPage(int p) {
    page = p;
    fetch();
  }

  void search() {
    page = 1;
    fetch();
  }

  void setDates({String? from, String? to}) {
    if (from != null) this.from = from;
    if (to != null) this.to = to;
    page = 1;
    fetch();
  }

  void clearDates() {
    from = null;
    to = null;
    page = 1;
    fetch();
  }

  void fillForm(SessionRating? rating) {
    formRole = switch (tab) {
      EvaluationTab.players => 'player',
      EvaluationTab.trainers => 'trainer',
      _ => 'staff',
    };
    formUserId = rating?.userId;
    formRating = rating?.stars ?? 4;
    if (formRating < 0.5) formRating = 0.5;
    noteCont.text = rating?.note ?? '';
  }

  Future<void> save({int? id}) async {
    if (id == null && formUserId == null) {
      return emit(AppFailure(msg: 'اختر الشخص المراد تقييمه.'));
    }

    final note = noteCont.text.trim();
    final data = {
      if (id == null) 'user_id': formUserId,
      'rating': formRating,
      'note': note.isEmpty ? null : note,
    };

    await _write(
      () => id == null ? _api.createEvaluation(data) : _api.updateEvaluation(id, data),
      id == null ? 'تم حفظ التقييم.' : 'تم حفظ التعديل.',
    );
  }

  Future<void> delete(int id) =>
      _write(() => _api.deleteEvaluation(id), 'تم حذف التقييم.', pop: false);

  Future<void> _write(
    Future<ApiResponse> Function() call,
    String okMsg, {
    bool pop = true,
  }) async {
    emit(AppBusy());
    final r = await call();
    if (!r.success) return emit(AppFailure(msg: r.message));
    emit(AppSuccess(msg: okMsg, shouldPop: pop));
    await fetch();
  }
}
