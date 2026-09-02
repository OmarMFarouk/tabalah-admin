import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/paginated_model.dart';
import '../../models/performance_model.dart';
import '../../services/apis/performance_api.dart';
import '../../src/app_presets.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  PERFORMANCE TABS — تبويبات الأداء
//  A KPI is defined once, recorded monthly per
//  staff member, and sits next to their pay.
// ─────────────────────────────────────────────
enum PerformanceTab { records, kpis, salaries }

extension PerformanceTabX on PerformanceTab {
  String get label => switch (this) {
    PerformanceTab.records => 'تسجيلات الأداء',
    PerformanceTab.kpis => 'المؤشرات',
    PerformanceTab.salaries => 'الرواتب',
  };

  IconData get icon => switch (this) {
    PerformanceTab.records => Icons.insights_rounded,
    PerformanceTab.kpis => Icons.speed_rounded,
    PerformanceTab.salaries => Icons.account_balance_rounded,
  };
}

class PerformanceCubit extends Cubit<AppStates> {
  PerformanceCubit() : super(AppInitial());
  static PerformanceCubit get(context) => BlocProvider.of(context);

  final PerformanceApi _api = PerformanceApi();

  PerformanceTab tab = PerformanceTab.records;
  int page = 1;

  // Filters — الفلاتر
  int? kpiFilter;
  int? staffFilter;
  String? periodFilter;

  // Data — البيانات
  Paginated<Kpi> kpis = Paginated(items: []);
  Paginated<KpiRecord> records = Paginated(items: []);
  Paginated<Salary> salaries = Paginated(items: []);

  // ── Form controllers — حقول النموذج ─────────
  final metricCont = TextEditingController();
  final targetCont = TextEditingController();
  final actualCont = TextEditingController();
  final amountCont = TextEditingController();
  int? formKpiId;
  int? formUserId;
  String formPeriod = AppPresets.thisMonth;

  void clearForm() {
    for (final c in [metricCont, targetCont, actualCont, amountCont]) {
      c.clear();
    }
    formKpiId = null;
    formUserId = null;
    formPeriod = AppPresets.thisMonth;
  }

  void switchTab(PerformanceTab t) {
    tab = t;
    page = 1;
    emit(AppInitial());
    fetch();
  }

  void setPage(int p) {
    page = p;
    fetch();
  }

  void setFilter({int? kpi, int? staff, String? period}) {
    if (kpi != null) kpiFilter = kpi == -1 ? null : kpi;
    if (staff != null) staffFilter = staff == -1 ? null : staff;
    if (period != null) periodFilter = period.isEmpty ? null : period;
    page = 1;
    fetch();
  }

  Future<void> fetch() async {
    emit(AppLoading());

    switch (tab) {
      case PerformanceTab.records:
        final r = await _api.fetchRecords(
          kpiId: kpiFilter,
          userId: staffFilter,
          period: periodFilter,
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        records = Paginated.parse<KpiRecord>(
          r['kpi_records'],
          KpiRecord.fromJson,
        );
        // The record dialog needs the metric list to name its dropdown.
        if (kpis.items.isEmpty) await _loadKpis();
        break;

      case PerformanceTab.kpis:
        await _loadKpis();
        break;

      case PerformanceTab.salaries:
        final r = await _api.fetchSalaries(
          userId: staffFilter,
          period: periodFilter,
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        salaries = Paginated.parse<Salary>(r['salaries'], Salary.fromJson);
        break;
    }
    emit(AppLoaded());
  }

  Future<void> _loadKpis() async {
    final r = await _api.fetchKpis(perPage: 100);
    if (r.success) {
      kpis = Paginated.parse<Kpi>(r['kpis'], Kpi.fromJson);
    }
  }

  // ── KPIs — المؤشرات ─────────────────────────
  // metric is unique across the club.
  Future<void> saveKpi({int? id}) {
    final data = {'metric': metricCont.text.trim()};
    return _write(
      () => id == null ? _api.createKpi(data) : _api.updateKpi(id, data),
      id == null ? 'تمت إضافة المؤشر.' : 'تم حفظ التعديل.',
    );
  }

  Future<void> deleteKpi(int id) =>
      _write(() => _api.deleteKpi(id), 'تم حذف المؤشر.');

  // ── Records — التسجيلات ─────────────────────
  // Target versus actual for one staff member in one month.
  Future<void> saveRecord({int? id}) {
    final data = KpiRecord(
      kpiId: formKpiId,
      userId: formUserId,
      target: double.tryParse(targetCont.text),
      actual: double.tryParse(actualCont.text),
      period: formPeriod,
    ).toJson();

    return _write(
      () => id == null
          ? _api.createRecord(data)
          : _api.updateRecord(id, {'actual': double.tryParse(actualCont.text)}),
      id == null ? 'تم تسجيل الأداء.' : 'تم تحديث النتيجة.',
    );
  }

  // ── Salaries — الرواتب ──────────────────────
  Future<void> saveSalary({int? id}) {
    final data = Salary(
      userId: formUserId,
      amount: double.tryParse(amountCont.text),
      period: formPeriod,
    ).toJson();

    return _write(
      () => id == null
          ? _api.createSalary(data)
          : _api.updateSalary(id, {'amount': double.tryParse(amountCont.text)}),
      id == null ? 'تم تسجيل الراتب.' : 'تم تعديل الراتب.',
    );
  }

  Future<void> deleteSalary(int id) =>
      _write(() => _api.deleteSalary(id), 'تم حذف الراتب.');

  Future<void> _write(Future Function() call, String okMsg) async {
    emit(AppBusy());
    final r = await call();
    if (r.success) {
      emit(AppSuccess(msg: okMsg));
      await fetch();
    } else {
      emit(AppFailure(msg: r.message));
    }
  }
}
