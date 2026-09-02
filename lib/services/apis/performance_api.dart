import '../../src/app_endpoints.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  PERFORMANCE API — المؤشرات والرواتب
//  Staff performance tracking and payroll.
// ─────────────────────────────────────────────
class PerformanceApi {
  // ── KPIs — المؤشرات ─────────────────────────
  Future<ApiResponse> fetchKpis({int page = 1, int perPage = 50}) =>
      ApiClient.get(
        AppEndPoints.kpis,
        query: {'page': page, 'per_page': perPage},
      );

  // metric is unique.
  Future<ApiResponse> createKpi(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.kpis, data: data);

  Future<ApiResponse> updateKpi(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.kpi(id), data: data);

  Future<ApiResponse> deleteKpi(dynamic id) =>
      ApiClient.delete(AppEndPoints.kpi(id));

  // ── KPI records — التسجيلات ─────────────────
  Future<ApiResponse> fetchRecords({
    dynamic kpiId,
    dynamic userId,
    String? period,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.kpiRecords,
    query: {
      'kpi_id': kpiId,
      'user_id': userId,
      'period': period,
      'page': page,
      'per_page': perPage,
    },
  );

  // Target versus actual for one staff member in one month.
  Future<ApiResponse> createRecord(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.kpiRecords, data: data);

  Future<ApiResponse> updateRecord(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.kpiRecord(id), data: data);

  // ── Salaries — الرواتب ──────────────────────
  Future<ApiResponse> fetchSalaries({
    dynamic userId,
    String? period,
    int page = 1,
    int perPage = 15,
  }) => ApiClient.get(
    AppEndPoints.salaries,
    query: {
      'user_id': userId,
      'period': period,
      'page': page,
      'per_page': perPage,
    },
  );

  Future<ApiResponse> createSalary(Map<String, dynamic> data) =>
      ApiClient.post(AppEndPoints.salaries, data: data);

  Future<ApiResponse> updateSalary(dynamic id, Map<String, dynamic> data) =>
      ApiClient.put(AppEndPoints.salary(id), data: data);

  Future<ApiResponse> deleteSalary(dynamic id) =>
      ApiClient.delete(AppEndPoints.salary(id));
}
