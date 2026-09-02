import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/finance_model.dart';
import '../../models/paginated_model.dart';
import '../../models/sessions_model.dart';
import '../../services/apis/dashboard_api.dart';
import '../../services/apis/finance_api.dart';
import '../../services/apis/sessions_api.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  DASHBOARD CUBIT — لوحة المؤشرات
//  The panel's landing page: headline counts,
//  today's sessions, and the latest payments.
// ─────────────────────────────────────────────
class DashboardCubit extends Cubit<AppStates> {
  DashboardCubit() : super(AppInitial());
  static DashboardCubit get(context) => BlocProvider.of(context);

  DashboardStats? stats;
  Map<String, dynamic> raw = {};
  List<Payment> recentPayments = [];
  List<ClubSession> todaySessions = [];
  PaymentTotals totals = PaymentTotals();

  Future<void> fetch() async {
    emit(AppLoading());

    final r = await DashboardApi().fetchDashboard();
    if (!r.success) return emit(AppFailure(msg: r.message));

    raw = r.body;
    stats = DashboardStats.fromJson(r.body);

    // Recent activity may ride along with the dashboard payload;
    // fall back to the list endpoints when it doesn't.
    recentPayments = _readList<Payment>(
      r.body['recent_payments'] ?? r.body['payments'],
      Payment.fromJson,
    );
    todaySessions = _readList<ClubSession>(
      r.body['today_sessions'] ?? r.body['upcoming_sessions'] ?? r.body['sessions'],
      ClubSession.fromJson,
    );

    await Future.wait([
      if (recentPayments.isEmpty) _loadPayments(),
      if (todaySessions.isEmpty) _loadSessions(),
    ]);

    emit(AppLoaded());
  }

  Future<void> _loadPayments() async {
    final r = await FinanceApi().fetchPayments(perPage: 6);
    if (r.success) {
      recentPayments =
          Paginated.parse<Payment>(r['payments'], Payment.fromJson).items;
      totals = PaymentTotals.fromJson(r['totals']);
    }
  }

  Future<void> _loadSessions() async {
    final r = await SessionsApi().fetchSessions(perPage: 6);
    if (r.success) {
      todaySessions = Paginated.parse<ClubSession>(
        r['membership_sessions'],
        ClubSession.fromJson,
      ).items;
    }
  }

  List<T> _readList<T>(dynamic node, T Function(Map<String, dynamic>) builder) {
    if (node == null) return [];
    return Paginated.parse<T>(node, builder).items;
  }
}
