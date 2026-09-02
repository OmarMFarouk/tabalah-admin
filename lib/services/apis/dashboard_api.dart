import '../../src/app_endpoints.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────
//  DASHBOARD API — لوحة المؤشرات
//  Read-only, open to every staff role.
// ─────────────────────────────────────────────
class DashboardApi {
  Future<ApiResponse> fetchDashboard() =>
      ApiClient.get(AppEndPoints.dashboard);
}
