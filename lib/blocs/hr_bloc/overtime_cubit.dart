import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/hr_model.dart';
import '../../models/paginated_model.dart';
import '../../services/apis/api_client.dart';
import '../../services/apis/hr_api.dart';
import '../../src/app_presets.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  OVERTIME CUBIT — الساعات الإضافية
// ─────────────────────────────────────────────

class OvertimeCubit extends Cubit<AppStates> {
  OvertimeCubit() : super(AppInitial());

  static OvertimeCubit get(context) => BlocProvider.of(context);

  final HrApi _api = HrApi();

  Paginated<OvertimeRecord> rows = Paginated(items: []);

  /// Summed server-side over the whole filter, not just this page.
  double totalHours = 0;

  int page = 1;
  int? userFilter;
  String? from;
  String? to;

  // ── Form ────────────────────────────────────
  int? formUserId;
  String formDate = AppPresets.today;
  final hoursCont = TextEditingController();
  final noteCont = TextEditingController();

  @override
  Future<void> close() {
    hoursCont.dispose();
    noteCont.dispose();
    return super.close();
  }

  Future<void> fetch() async {
    emit(AppLoading());
    final r = await _api.fetchOvertime(
      userId: userFilter,
      from: from,
      to: to,
      page: page,
    );
    if (!r.success) return emit(AppFailure(msg: r.message));

    rows = Paginated.read<OvertimeRecord>(r.body, 'overtime', OvertimeRecord.fromJson);
    totalHours = asDouble(r.body['total_hours']) ?? 0;

    if (rows.isOrphanedPage) {
      page = 1;
      return fetch();
    }
    emit(AppLoaded());
  }

  void setPage(int p) {
    page = p;
    fetch();
  }

  /// `user: -1` clears the person filter.
  void setFilter({int? user, String? from, String? to}) {
    if (user != null) userFilter = user == -1 ? null : user;
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

  void fillForm(OvertimeRecord? record) {
    formUserId = record?.userId;
    formDate = record?.date ?? AppPresets.today;
    hoursCont.text = record == null ? '' : record.hours.toString();
    noteCont.text = record?.note ?? '';
  }

  Future<void> save({int? id}) async {
    final hours = double.tryParse(hoursCont.text.trim());
    if (id == null && formUserId == null) {
      return emit(AppFailure(msg: 'اختر الموظف أو المدرب.'));
    }
    if (hours == null || hours <= 0 || hours > 24) {
      return emit(AppFailure(msg: 'أدخل عدد ساعات صحيحاً بين 0.25 و 24.'));
    }

    final data = {
      if (id == null) 'user_id': formUserId,
      'date': formDate,
      'hours': hours,
      'note': noteCont.text.trim().isEmpty ? null : noteCont.text.trim(),
    };

    await _write(
      () => id == null ? _api.createOvertime(data) : _api.updateOvertime(id, data),
      id == null ? 'تم تسجيل الساعات الإضافية.' : 'تم حفظ التعديل.',
    );
  }

  Future<void> delete(int id) =>
      _write(() => _api.deleteOvertime(id), 'تم حذف السجل.', pop: false);

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
