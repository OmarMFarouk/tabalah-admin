import '../../src/app_endpoints.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  REPORTS API — التقارير
// ─────────────────────────────────────────────
class ReportsApi {
  /// One call returns every section. The financial block is present only
  /// when the account holds `reports.financial` — the panel checks for the
  /// key rather than assuming, so a manager without it sees the operational
  /// report instead of an error.
  Future<ApiResponse> fetch({String? from, String? to}) =>
      ApiClient.get(AppEndPoints.reports, query: {'from': from, 'to': to});
}
