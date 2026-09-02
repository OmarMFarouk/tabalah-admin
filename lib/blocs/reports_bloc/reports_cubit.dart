import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/paginated_model.dart';
import '../dashboard_bloc/dashboard_cubit.dart' show TopMembershipRow;
import '../../services/apis/reports_api.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  REPORT RANGE — الفترة
//  Presets first: "last 30 days" is what somebody
//  actually wants nine times out of ten, and
//  making them pick two dates for it is friction
//  for no gain.
// ─────────────────────────────────────────────
enum ReportRange { week, month, quarter, year, custom }

extension ReportRangeX on ReportRange {
  String get label => switch (this) {
    ReportRange.week => 'آخر ٧ أيام',
    ReportRange.month => 'آخر ٣٠ يوم',
    ReportRange.quarter => 'آخر ٩٠ يوم',
    ReportRange.year => 'آخر سنة',
    ReportRange.custom => 'فترة مخصّصة',
  };

  int? get days => switch (this) {
    ReportRange.week => 7,
    ReportRange.month => 30,
    ReportRange.quarter => 90,
    ReportRange.year => 365,
    ReportRange.custom => null,
  };
}

// ─────────────────────────────────────────────
//  REPORT SECTIONS — أقسام التقرير
//
//  One long scrolling page meant the trainer table
//  was four screens below the membership numbers,
//  and nobody scrolls that far to check something.
//  Each section is now a tab: everything you asked
//  for is on screen at once, and nothing else is.
// ─────────────────────────────────────────────
enum ReportSection { membership, attendance, financial, sports, trainers }

extension ReportSectionX on ReportSection {
  String get label => switch (this) {
    ReportSection.membership => 'العضوية والاشتراكات',
    ReportSection.attendance => 'الحضور',
    ReportSection.financial => 'المالية',
    ReportSection.sports => 'الرياضات والحصص',
    ReportSection.trainers => 'المدربون',
  };

  IconData get icon => switch (this) {
    ReportSection.membership => Icons.card_membership_rounded,
    ReportSection.attendance => Icons.fact_check_rounded,
    ReportSection.financial => Icons.payments_rounded,
    ReportSection.sports => Icons.sports_soccer_rounded,
    ReportSection.trainers => Icons.sports_rounded,
  };
}

class ReportsCubit extends Cubit<AppStates> {
  ReportsCubit() : super(AppInitial()) {
    _applyRange();
  }

  static ReportsCubit get(context) => BlocProvider.of(context);

  final ReportsApi _api = ReportsApi();

  ReportData? report;
  ReportSection section = ReportSection.membership;
  ReportRange range = ReportRange.month;

  /// The tabs this account can actually see. The financial one is dropped
  /// when the server omitted the block, which it does when the account lacks
  /// `reports.financial` — a tab that opens on "you may not see this" is
  /// worse than one that isn't there.
  List<ReportSection> get sections => ReportSection.values
      .where((s) => s != ReportSection.financial || (report?.hasFinancial ?? false))
      .toList();

  void setSection(ReportSection s) {
    section = s;
    emit(AppLoaded());
  }
  String? from;
  String? to;

  void _applyRange() {
    final days = range.days;
    if (days == null) return;

    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    to = _fmt(now);
    from = _fmt(start);
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void setRange(ReportRange r) {
    range = r;
    _applyRange();
    if (r != ReportRange.custom) fetch();
    emit(AppLoaded());
  }

  void setFrom(String value) {
    from = value;
    fetch();
  }

  void setTo(String value) {
    to = value;
    fetch();
  }

  Future<void> fetch() async {
    emit(AppLoading());

    final r = await _api.fetch(from: from, to: to);

    if (!r.success) {
      emit(AppFailure(msg: r.message));
      return;
    }

    final node = r['report'];
    report = node is Map
        ? ReportData.fromJson(Map<String, dynamic>.from(node))
        : null;

    // The visible tab may have just disappeared - a permission change, or a
    // range with no financial data. Fall back rather than render nothing.
    if (!sections.contains(section)) section = sections.first;

    emit(AppLoaded());
  }
}

// ─────────────────────────────────────────────
//  REPORT DATA — نموذج التقرير
// ─────────────────────────────────────────────
class ReportData {
  // Membership
  final int membersTotal;
  final int membersNew;
  final int activeSubscriptions;
  final int newSubscriptions;
  final int lapsedSubscriptions;
  final int netChange;
  final double? capacityUtilisation;

  // Attendance
  final int present;
  final int late;
  final int absent;
  final int excused;
  final double? attendanceRate;
  final int sessionsHeld;
  final int sessionsCancelled;

  // Financial — absent entirely when the account lacks `reports.financial`,
  // which is why every consumer checks [hasFinancial] rather than assuming.
  final bool hasFinancial;
  final double collected;
  final double pending;
  final double refunded;
  final int failedCount;
  final int transactions;
  final double averagePayment;
  final List<({String name, int count, double total})> bySource;

  final List<({String label, int members, int subscriptions})> growthTrend;
  final List<({String label, double collected})> revenueTrend;
  final List<SportReportRow> sports;
  final List<TrainerReportRow> trainers;

  /// Moved here from the dashboard: which classes are filling up is a
  /// planning question, not a front-desk one.
  final List<TopMembershipRow> topMemberships;

  const ReportData({
    this.membersTotal = 0,
    this.membersNew = 0,
    this.activeSubscriptions = 0,
    this.newSubscriptions = 0,
    this.lapsedSubscriptions = 0,
    this.netChange = 0,
    this.capacityUtilisation,
    this.present = 0,
    this.late = 0,
    this.absent = 0,
    this.excused = 0,
    this.attendanceRate,
    this.sessionsHeld = 0,
    this.sessionsCancelled = 0,
    this.hasFinancial = false,
    this.collected = 0,
    this.pending = 0,
    this.refunded = 0,
    this.failedCount = 0,
    this.transactions = 0,
    this.averagePayment = 0,
    this.bySource = const [],
    this.growthTrend = const [],
    this.revenueTrend = const [],
    this.sports = const [],
    this.trainers = const [],
    this.topMemberships = const [],
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> block(String key) =>
        json[key] is Map ? Map<String, dynamic>.from(json[key]) : {};

    final m = block('membership');
    final a = block('attendance');
    final f = block('financial');

    return ReportData(
      membersTotal: asInt(m['members_total']) ?? 0,
      membersNew: asInt(m['members_new']) ?? 0,
      activeSubscriptions: asInt(m['active_subscriptions']) ?? 0,
      newSubscriptions: asInt(m['new_subscriptions']) ?? 0,
      lapsedSubscriptions: asInt(m['lapsed_subscriptions']) ?? 0,
      netChange: asInt(m['net_change']) ?? 0,
      capacityUtilisation: asDouble(m['capacity_utilisation']),

      present: asInt(a['present']) ?? 0,
      late: asInt(a['late']) ?? 0,
      absent: asInt(a['absent']) ?? 0,
      excused: asInt(a['excused']) ?? 0,
      attendanceRate: asDouble(a['rate']),
      sessionsHeld: asInt(a['sessions_held']) ?? 0,
      sessionsCancelled: asInt(a['sessions_cancelled']) ?? 0,

      hasFinancial: json['financial'] is Map,
      collected: asDouble(f['collected']) ?? 0,
      pending: asDouble(f['pending']) ?? 0,
      refunded: asDouble(f['refunded']) ?? 0,
      failedCount: asInt(f['failed_count']) ?? 0,
      transactions: asInt(f['transactions']) ?? 0,
      averagePayment: asDouble(f['average_payment']) ?? 0,
      bySource: (f['by_source'] is List)
          ? (f['by_source'] as List)
                .whereType<Map>()
                .map(
                  (e) => (
                    name: (e['name'] ?? '—').toString(),
                    count: asInt(e['count']) ?? 0,
                    total: asDouble(e['total']) ?? 0,
                  ),
                )
                .toList()
          : const [],

      growthTrend: (json['growth'] is List)
          ? (json['growth'] as List)
                .whereType<Map>()
                .map(
                  (e) => (
                    label: (e['label'] ?? '').toString(),
                    members: asInt(e['members']) ?? 0,
                    subscriptions: asInt(e['subscriptions']) ?? 0,
                  ),
                )
                .toList()
          : const [],

      revenueTrend: (json['revenue_trend'] is List)
          ? (json['revenue_trend'] as List)
                .whereType<Map>()
                .map(
                  (e) => (
                    label: (e['label'] ?? '').toString(),
                    collected: asDouble(e['collected']) ?? 0,
                  ),
                )
                .toList()
          : const [],

      sports: (json['sports'] is List)
          ? (json['sports'] as List)
                .whereType<Map>()
                .map((e) => SportReportRow.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],

      topMemberships: (json['top_memberships'] is List)
          ? (json['top_memberships'] as List)
                .whereType<Map>()
                .map(
                  (e) => TopMembershipRow.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],

      trainers: (json['trainers'] is List)
          ? (json['trainers'] as List)
                .whereType<Map>()
                .map(
                  (e) => TrainerReportRow.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
    );
  }
}

class SportReportRow {
  final String name;
  final String? icon;
  final int membershipsCount;
  final int activeEnrollments;

  const SportReportRow({
    required this.name,
    this.icon,
    this.membershipsCount = 0,
    this.activeEnrollments = 0,
  });

  factory SportReportRow.fromJson(Map<String, dynamic> json) => SportReportRow(
    name: (json['name'] ?? '—').toString(),
    icon: asString(json['icon']),
    membershipsCount: asInt(json['memberships_count']) ?? 0,
    activeEnrollments: asInt(json['active_enrollments']) ?? 0,
  );
}

class TrainerReportRow {
  final String? name;
  final String? sportName;
  final int membershipsCount;
  final int sessionsInRange;
  final double? ratingAvg;

  const TrainerReportRow({
    this.name,
    this.sportName,
    this.membershipsCount = 0,
    this.sessionsInRange = 0,
    this.ratingAvg,
  });

  factory TrainerReportRow.fromJson(Map<String, dynamic> json) =>
      TrainerReportRow(
        name: asString(json['name']),
        sportName: asString(json['sport_name']),
        membershipsCount: asInt(json['memberships_count']) ?? 0,
        sessionsInRange: asInt(json['sessions_in_range']) ?? 0,
        ratingAvg: asDouble(json['rating_avg']),
      );
}
