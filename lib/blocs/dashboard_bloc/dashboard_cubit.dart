import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/catalog_model.dart';
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

  // Enrolments the front desk should chase today.
  List<Enrollment> needsAttention = [];

  /// The companion list to [needsAttention], so neither owns the full width.
  /// One column is people to chase, the other is people to welcome.
  List<NewMemberRow> newestMembers = [];


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
      r.body['today_sessions'] ??
          r.body['upcoming_sessions'] ??
          r.body['sessions'],
      ClubSession.fromJson,
    );

    // Enrolments that are either unpaid or about to lapse. The dashboard
    // turns these into a worklist rather than another counter to read.
    needsAttention = _readList<Enrollment>(
      r.body['needs_attention'],
      Enrollment.fromJson,
    );

    newestMembers = _readList<NewMemberRow>(
      r.body['newest_members'],
      NewMemberRow.fromJson,
    );

    // The dashboard genuinely carries `today_sessions`, and an empty list is
    // a real answer — no classes today. Falling back on emptiness would
    // quietly backfill the card with the most recent sessions instead, so
    // only reach for the list endpoint when the block is missing outright.
    final hasSessionsBlock = r.body.containsKey('today_sessions') ||
        r.body.containsKey('upcoming_sessions');

    await Future.wait([
      if (recentPayments.isEmpty) _loadPayments(),
      if (!hasSessionsBlock && todaySessions.isEmpty) _loadSessions(),
    ]);

    emit(AppLoaded());
  }

  Future<void> _loadPayments() async {
    final r = await FinanceApi().fetchPayments(perPage: 6);
    if (r.success) {
      recentPayments =
          Paginated.read<Payment>(r.body, 'payments', Payment.fromJson).items;
      totals = PaymentTotals.fromJson(r['totals']);
    }
  }

  Future<void> _loadSessions() async {
    final r = await SessionsApi().fetchSessions(perPage: 6);
    if (r.success) {
      // `sessions` — the resource name is membership-session, but the
      // envelope key is not.
      todaySessions = Paginated.read<ClubSession>(
        r.body,
        'sessions',
        ClubSession.fromJson,
      ).items;
    }
  }

  List<T> _readList<T>(dynamic node, T Function(Map<String, dynamic>) builder) {
    if (node == null) return [];
    return Paginated.parse<T>(node, builder).items;
  }
}

// ─────────────────────────────────────────────
//  NEW MEMBER ROW — عضو جديد
//  The other half of the desk's day: somebody who
//  just joined and may not have bought anything
//  yet.
// ─────────────────────────────────────────────
class NewMemberRow {
  final int? playerId;
  final int? userId;
  final String? name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? joinedAt;

  /// Whether they have actually subscribed. A member with no subscription is
  /// the clearest follow-up on the screen.
  final bool hasSubscription;

  const NewMemberRow({
    this.playerId,
    this.userId,
    this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.joinedAt,
    this.hasSubscription = false,
  });

  factory NewMemberRow.fromJson(Map<String, dynamic> json) => NewMemberRow(
    playerId: asInt(json['player_id']),
    userId: asInt(json['user_id']),
    name: asString(json['name']),
    email: asString(json['email']),
    phone: asString(json['phone']),
    avatarUrl: asString(json['avatar_url']),
    joinedAt: asDate(json['joined_at']),
    hasSubscription: asBool(json['has_subscription']),
  );

  String get initial =>
      (name ?? '').isEmpty ? '؟' : name!.trim().substring(0, 1);
}

// ─────────────────────────────────────────────
//  TOP MEMBERSHIP ROW — الأكثر إقبالاً
// ─────────────────────────────────────────────
class TopMembershipRow {
  final int? id;
  final String? name;
  final String? sportName;
  final String? sportIcon;
  final int activeEnrollments;
  final int? maxAttendees;
  final bool isFull;

  const TopMembershipRow({
    this.id,
    this.name,
    this.sportName,
    this.sportIcon,
    this.activeEnrollments = 0,
    this.maxAttendees,
    this.isFull = false,
  });

  factory TopMembershipRow.fromJson(Map<String, dynamic> json) =>
      TopMembershipRow(
        id: asInt(json['id']),
        name: asString(json['name']),
        sportName: asString(json['sport_name']),
        sportIcon: asString(json['sport_icon']),
        activeEnrollments: asInt(json['active_enrollments']) ?? 0,
        maxAttendees: asInt(json['max_attendees']),
        isFull: asBool(json['is_full']),
      );

  /// 0..1 against the cap, or null when the class is uncapped — an uncapped
  /// class has no "how full" to show, and drawing it at 0% would read as
  /// empty rather than as unlimited.
  double? get fillRatio {
    final cap = maxAttendees;
    if (cap == null || cap <= 0) return null;
    final r = activeEnrollments / cap;
    return r > 1 ? 1 : r;
  }

  String get capacityLabel =>
      maxAttendees == null ? '$activeEnrollments مشترك' : '$activeEnrollments / $maxAttendees';
}
