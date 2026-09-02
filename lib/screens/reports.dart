import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/reports_bloc/reports_cubit.dart';
import '../components/general/app_field.dart';
import '../components/general/empty_widget.dart';
import '../components/general/page_header.dart';
import '../components/general/snackbar.dart';
import '../components/general/stat_card.dart';
import '../src/app_colors.dart';
import '../src/app_globals.dart';
import '../src/sport_icons.dart';

// ─────────────────────────────────────────────
//  REPORTS — التقارير
//
//  Everything analytical, including the financial
//  totals the home screen used to carry. The split
//  is deliberate: home answers "what needs doing
//  today", this answers "how are we doing".
// ─────────────────────────────────────────────
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportsCubit()..fetch(),
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SelectionArea(
        child: Scaffold(
          backgroundColor: GlobalColors.bg(context),
          body: BlocConsumer<ReportsCubit, AppStates>(
            listener: (ctx, state) {
              if (state is AppFailure) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: false);
              }
            },
            builder: (ctx, state) {
              final c = ReportsCubit.get(ctx);
              final loading = state is AppLoading;

              return Column(
                children: [
                  PageHeader(
                    title: 'التقارير',
                    icon: Icons.query_stats_rounded,
                    isLoading: loading,
                    onRefresh: c.fetch,
                  ),
                  _rangeBar(ctx, c),
                  if (c.report != null) _sectionTabs(ctx, c),
                  Expanded(
                    child: c.report == null
                        ? EmptyState(
                            title: loading ? 'جارٍ التحميل...' : 'لا توجد بيانات',
                            hint: 'اختر فترة زمنية ثم اضغط تحديث',
                            icon: Icons.query_stats_rounded,
                          )
                        : _content(ctx, c),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Range picker ────────────────────────────
  Widget _rangeBar(BuildContext ctx, ReportsCubit c) {
    return Toolbar(
      children: [
        // Presets first: "last 30 days" is what somebody actually wants
        // nine times out of ten, and making them pick two dates for it is
        // friction for no gain.
        ...ReportRange.values.map(
          (r) => Padding(
            padding: const EdgeInsets.only(left: 6),
            child: AppFilterChip(
              label: r.label,
              isActive: c.range == r,
              onTap: () => c.setRange(r),
            ),
          ),
        ),
        const Spacer(),
        if (c.range == ReportRange.custom) ...[
          SizedBox(
            width: 160,
            child: DateField(
              value: c.from,
              label: 'من',
              onPicked: c.setFrom,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: DateField(value: c.to, label: 'إلى', onPicked: c.setTo),
          ),
        ] else
          Text(
            '${c.from ?? ''}  →  ${c.to ?? ''}',
            style: TextStyle(
              color: GlobalColors.textSecondary(ctx),
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  // ── Section tabs ────────────────────────────
  //  Centred, horizontal, directly under the date row. The page used to be
  //  one long scroll where the trainer table sat four screens below the
  //  membership numbers — far enough that nobody went looking.
  Widget _sectionTabs(BuildContext ctx, ReportsCubit c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Centres the row while still allowing it to scroll if a narrow
        // window can't fit every pill.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: c.sections
              .map(
                (section) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _SectionPill(
                    label: section.label,
                    icon: section.icon,
                    isActive: c.section == section,
                    onTap: () => c.setSection(section),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ── Body ────────────────────────────────────
  Widget _content(BuildContext ctx, ReportsCubit c) {
    final r = c.report!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (c.section) {
          ReportSection.membership => _membership(ctx, r),
          ReportSection.attendance => _attendance(ctx, r),
          ReportSection.financial => _financial(ctx, r),
          ReportSection.sports => _sports(ctx, r),
          ReportSection.trainers => _trainers(ctx, r),
        },
      ),
    );
  }

  /// Breathing room between a section's cards. The panels used to sit on
  /// the 12px margin [_shell] carries and read as one continuous slab.
  static const Widget _spacer = SizedBox(height: 14);

  /// Lays panels side by side instead of stacking them. Heights are left
  /// natural rather than equalised: a five-row table next to a two-bar chart
  /// looks worse padded out to match than it does ending early.
  Widget _chartRow(List<Widget> children, {List<int>? flex}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(
            flex: flex == null ? 1 : flex[i],
            child: children[i],
          ),
        ],
      ],
    );
  }

  List<Widget> _membership(BuildContext ctx, ReportData r) => [
    StatRow(
      cards: [
        StatCard(
          label: 'الأعضاء',
          value: '${r.membersTotal}',
          icon: Icons.people_alt_rounded,
          color: GlobalColors.accent,
          sub: '+${r.membersNew} في الفترة',
        ),
        StatCard(
          label: 'اشتراكات نشطة',
          value: '${r.activeSubscriptions}',
          icon: Icons.verified_rounded,
          color: GlobalColors.green,
          sub: 'سارية الآن',
        ),
        StatCard(
          label: 'صافي التغيّر',
          value: '${r.netChange > 0 ? '+' : ''}${r.netChange}',
          icon: r.netChange >= 0
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          color: r.netChange >= 0 ? GlobalColors.green : GlobalColors.red,
          sub: '${r.newSubscriptions} جديد / ${r.lapsedSubscriptions} منتهٍ',
        ),
        StatCard(
          label: 'إشغال الطاقة',
          value: r.capacityUtilisation == null
              ? '—'
              : '${r.capacityUtilisation}%',
          icon: Icons.donut_large_rounded,
          color: GlobalColors.purple,
          sub: 'للحصص محدودة العدد',
        ),
      ],
    ),
    _spacer,
    if (r.growthTrend.isNotEmpty)
      _chartRow([
        _trendCard(
          ctx,
          'أعضاء جدد شهرياً',
          r.growthTrend
              .map((m) => (label: m.label, value: m.members.toDouble()))
              .toList(),
          GlobalColors.accent,
        ),
        _trendCard(
          ctx,
          'اشتراكات جديدة شهرياً',
          r.growthTrend
              .map((m) => (label: m.label, value: m.subscriptions.toDouble()))
              .toList(),
          GlobalColors.green,
        ),
      ]),
  ];

  List<Widget> _attendance(BuildContext ctx, ReportData r) => [
    StatRow(
      cards: [
        StatCard(
          label: 'نسبة الحضور',
          value: r.attendanceRate == null ? '—' : '${r.attendanceRate}%',
          icon: Icons.check_circle_rounded,
          color: GlobalColors.green,
          sub: 'حضور + متأخر',
        ),
        StatCard(
          label: 'حاضر',
          value: '${r.present}',
          icon: Icons.person_rounded,
          color: GlobalColors.blue,
          sub: '${r.late} متأخر',
        ),
        StatCard(
          label: 'غياب',
          value: '${r.absent}',
          icon: Icons.person_off_rounded,
          color: GlobalColors.red,
          sub: '${r.excused} بعذر',
        ),
        StatCard(
          label: 'حصص أُقيمت',
          value: '${r.sessionsHeld}',
          icon: Icons.event_available_rounded,
          color: GlobalColors.accent,
          sub: '${r.sessionsCancelled} ملغاة',
        ),
      ],
    ),
    _spacer,
    _chartRow([
      // The four marks side by side: the stat cards above give the counts,
      // this gives the shape — whether the absences are a rounding error or
      // a quarter of the room.
      _donutCard(ctx, 'توزيع الحضور', [
        (label: 'حاضر', value: r.present.toDouble(), color: GlobalColors.green),
        (label: 'متأخر', value: r.late.toDouble(), color: GlobalColors.gold),
        (label: 'غياب', value: r.absent.toDouble(), color: GlobalColors.red),
        (label: 'بعذر', value: r.excused.toDouble(), color: GlobalColors.blue),
      ]),
      _ringCard(
        ctx,
        'نسبة الحضور',
        r.attendanceRate,
        GlobalColors.green,
        note: 'حضور + متأخر من إجمالي التسجيلات',
      ),
    ]),
    _spacer,
    _hBarsCard(ctx, 'الحصص في الفترة', [
      (
        label: 'أُقيمت',
        value: r.sessionsHeld.toDouble(),
        color: GlobalColors.accent,
      ),
      (
        label: 'ملغاة',
        value: r.sessionsCancelled.toDouble(),
        color: GlobalColors.red,
      ),
    ], suffix: ' حصة'),
  ];

  List<Widget> _financial(BuildContext ctx, ReportData r) => [
    StatRow(
      cards: [
        StatCard(
          label: 'المحصّل',
          value: '${r.collected.toStringAsFixed(0)} ${AppGlobals.currency}',
          icon: Icons.check_circle_rounded,
          color: GlobalColors.green,
          sub: '${r.transactions} عملية',
        ),
        StatCard(
          label: 'المعلّق',
          value: '${r.pending.toStringAsFixed(0)} ${AppGlobals.currency}',
          icon: Icons.hourglass_bottom_rounded,
          color: GlobalColors.gold,
          sub: 'بانتظار التسوية',
        ),
        StatCard(
          label: 'المسترد',
          value: '${r.refunded.toStringAsFixed(0)} ${AppGlobals.currency}',
          icon: Icons.undo_rounded,
          color: GlobalColors.red,
          sub: '${r.failedCount} عملية فاشلة',
        ),
        StatCard(
          label: 'متوسط الدفعة',
          value: '${r.averagePayment.toStringAsFixed(0)} ${AppGlobals.currency}',
          icon: Icons.equalizer_rounded,
          color: GlobalColors.purple,
          sub: 'للعملية الناجحة',
        ),
      ],
    ),
    _spacer,
    if (r.revenueTrend.isNotEmpty)
      _trendCard(
        ctx,
        'الإيراد شهرياً',
        r.revenueTrend
            .map((m) => (label: m.label, value: m.collected))
            .toList(),
        GlobalColors.green,
        suffix: ' ${AppGlobals.currency}',
      ),
    _spacer,
    if (r.bySource.isNotEmpty) _sourcesCard(ctx, r),
  ];

  List<Widget> _sports(BuildContext ctx, ReportData r) => [
    // Side by side rather than stacked: enrolment per sport and which
    // classes are filling up are the same planning question asked at two
    // zoom levels, and reading them together is the point.
    _chartRow([
      _sportsCard(ctx, r),
      if (r.topMemberships.isNotEmpty)
        _topMembershipsCard(ctx, r)
      else
        _noteCard(ctx, 'لا توجد اشتراكات.', Icons.card_membership_rounded),
    ]),
    _spacer,
    _hBarsCard(
      ctx,
      'الحصص لكل رياضة',
      r.sports
          .map(
            (sp) => (
              label: sp.name,
              value: sp.membershipsCount.toDouble(),
              color: GlobalColors.purple,
            ),
          )
          .toList(),
      suffix: ' حصة',
    ),
  ];

  List<Widget> _trainers(BuildContext ctx, ReportData r) => [
    // The table carries the detail; the chart beside it carries the ranking,
    // which is the thing anyone actually opens this tab for.
    _chartRow([
      _trainersCard(ctx, r),
      _hBarsCard(
        ctx,
        'الجلسات لكل مدرب',
        (r.trainers.toList()
              ..sort((a, b) => b.sessionsInRange.compareTo(a.sessionsInRange)))
            .take(8)
            .map(
              (t) => (
                label: t.name ?? '—',
                value: t.sessionsInRange.toDouble(),
                color: GlobalColors.accent,
              ),
            )
            .toList(),
        suffix: ' جلسة',
      ),
    ], flex: [3, 2]),
    _spacer,
    _hBarsCard(
      ctx,
      'متوسط التقييم',
      (r.trainers.where((t) => t.ratingAvg != null).toList()
            ..sort((a, b) => b.ratingAvg!.compareTo(a.ratingAvg!)))
          .take(8)
          .map(
            (t) => (
              label: t.name ?? '—',
              value: t.ratingAvg!,
              color: GlobalColors.gold,
            ),
          )
          .toList(),
      // Ratings are on a fixed 0–5 scale, so scaling the bars against the
      // best trainer in the list would make a 4.9 and a 3.1 look further
      // apart than they are.
      maxOverride: 5,
      suffix: ' ★',
      decimals: 1,
    ),
  ];

  Widget _topMembershipsCard(BuildContext ctx, ReportData r) {
    return _shell(
      ctx,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الأكثر إقبالاً',
            style: TextStyle(
              color: GlobalColors.textPrimary(ctx),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...r.topMemberships.map((m) {
            final ratio = m.fillRatio;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    SportIcons.of(m.sportIcon),
                    size: 17,
                    color: GlobalColors.accentSoft,
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 210,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m.name ?? '—',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: GlobalColors.textPrimary(ctx),
                            fontSize: 12.5,
                          ),
                        ),
                        Text(
                          m.sportName ?? '—',
                          style: TextStyle(
                            color: GlobalColors.textSecondary(ctx),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ratio == null
                        // Uncapped: a bar at 0% would read as empty rather
                        // than as unlimited, so it gets a label instead.
                        ? Text(
                            'بلا حد أقصى',
                            style: TextStyle(
                              color: GlobalColors.textSecondary(ctx),
                              fontSize: 10.5,
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              backgroundColor: GlobalColors.bg(ctx),
                              valueColor: AlwaysStoppedAnimation(
                                m.isFull
                                    ? GlobalColors.red
                                    : GlobalColors.green,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: Text(
                      m.capacityLabel,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: m.isFull
                            ? GlobalColors.red
                            : GlobalColors.textSecondary(ctx),
                        fontSize: 11,
                        fontWeight: m.isFull
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }


  Widget _shell(BuildContext ctx, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GlobalColors.surface(ctx),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlobalColors.border(ctx)),
      ),
      child: child,
    );
  }

  Widget _noteCard(BuildContext ctx, String text, IconData icon) {
    return _shell(
      ctx,
      Row(
        children: [
          Icon(icon, size: 18, color: GlobalColors.textSecondary(ctx)),
          const SizedBox(width: 10),
          // Expanded because these notes now sit in half-width columns:
          // a long one overflowed the card before the row could wrap it.
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: GlobalColors.textSecondary(ctx),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A bar series, drawn with plain containers.
  ///
  /// No charting package: the panel has one dependency-light build and a
  /// six-bar series does not justify adding one. Bars are scaled against the
  /// largest value, and a zero-max is handled so an empty month doesn't
  /// divide by zero.
  Widget _trendCard(
    BuildContext ctx,
    String title,
    List<({String label, double value})> points,
    Color color, {
    String suffix = '',
  }) {
    final max = points.fold<double>(0, (m, p) => p.value > m ? p.value : m);

    return _shell(
      ctx,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: GlobalColors.textPrimary(ctx),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((p) {
                final ratio = max <= 0 ? 0.0 : p.value / max;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          p.value == 0
                              ? '—'
                              : '${p.value.toStringAsFixed(0)}$suffix',
                          style: TextStyle(
                            color: GlobalColors.textSecondary(ctx),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // A floor of 3px so a zero month is still a visible
                        // tick rather than a gap that reads as missing data.
                        Container(
                          height: 3 + (ratio * 100),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color,
                                color.withValues(alpha: 0.35),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.label,
                          style: TextStyle(
                            color: GlobalColors.textSecondary(ctx),
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sportsCard(BuildContext ctx, ReportData r) {
    if (r.sports.isEmpty) {
      return _noteCard(ctx, 'لا توجد رياضات.', Icons.sports_soccer_rounded);
    }

    final max = r.sports.fold<int>(
      0,
      (m, s) => s.activeEnrollments > m ? s.activeEnrollments : m,
    );

    return _shell(
      ctx,
      Column(
        children: r.sports.map((s) {
          final ratio = max <= 0 ? 0.0 : s.activeEnrollments / max;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  SportIcons.of(s.icon),
                  size: 18,
                  color: GlobalColors.accentSoft,
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 130,
                  child: Text(
                    s.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: GlobalColors.textPrimary(ctx),
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 9,
                      backgroundColor: GlobalColors.bg(ctx),
                      valueColor: AlwaysStoppedAnimation(GlobalColors.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: Text(
                    '${s.activeEnrollments} مشترك',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: GlobalColors.textSecondary(ctx),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _trainersCard(BuildContext ctx, ReportData r) {
    if (r.trainers.isEmpty) {
      return _noteCard(ctx, 'لا يوجد مدربون.', Icons.sports_rounded);
    }

    return _shell(
      ctx,
      Column(
        children: r.trainers.take(10).map((t) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    t.name ?? '—',
                    style: TextStyle(
                      color: GlobalColors.textPrimary(ctx),
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    t.sportName ?? '—',
                    style: TextStyle(
                      color: GlobalColors.textSecondary(ctx),
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${t.membershipsCount} حصة',
                    style: TextStyle(color: GlobalColors.blue, fontSize: 11),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${t.sessionsInRange} جلسة',
                    style: TextStyle(
                      color: GlobalColors.accentSoft,
                      fontSize: 11,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    t.ratingAvg == null
                        ? '—'
                        : '★ ${t.ratingAvg!.toStringAsFixed(1)}',
                    textAlign: TextAlign.left,
                    style: TextStyle(color: GlobalColors.gold, fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// A horizontal bar list — one row per item, scaled against the largest
  /// value unless [maxOverride] pins the scale to a fixed range.
  ///
  /// Same hand-rolled approach as [_trendCard]: still no charting package,
  /// still not worth one for eight rows.
  Widget _hBarsCard(
    BuildContext ctx,
    String title,
    List<({String label, double value, Color color})> bars, {
    String suffix = '',
    double? maxOverride,
    int decimals = 0,
  }) {
    if (bars.isEmpty) {
      return _noteCard(ctx, '$title — لا توجد بيانات.', Icons.bar_chart_rounded);
    }

    final max =
        maxOverride ?? bars.fold<double>(0, (m, b) => b.value > m ? b.value : m);

    return _shell(
      ctx,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(ctx, title),
          const SizedBox(height: 14),
          ...bars.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      b.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: GlobalColors.textPrimary(ctx),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: max <= 0 ? 0 : (b.value / max).clamp(0.0, 1.0),
                        minHeight: 9,
                        backgroundColor: GlobalColors.bg(ctx),
                        valueColor: AlwaysStoppedAnimation(b.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 74,
                    child: Text(
                      '${b.value.toStringAsFixed(decimals)}$suffix',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: GlobalColors.textSecondary(ctx),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A donut with its legend beside it. Slices worth nothing are dropped
  /// rather than drawn as hairlines, and an all-zero series falls back to a
  /// note so the panel doesn't render an empty ring that reads as broken.
  Widget _donutCard(
    BuildContext ctx,
    String title,
    List<({String label, double value, Color color})> slices,
  ) {
    final live = slices.where((s) => s.value > 0).toList();
    final total = live.fold<double>(0, (t, s) => t + s.value);

    if (total <= 0) {
      return _noteCard(
        ctx,
        '$title — لا توجد بيانات.',
        Icons.donut_large_rounded,
      );
    }

    return _shell(
      ctx,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(ctx, title),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 128,
                height: 128,
                child: CustomPaint(
                  painter: _DonutPainter(
                    slices: live
                        .map((sl) => (value: sl.value, color: sl.color))
                        .toList(),
                    trackColor: GlobalColors.bg(ctx),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          total.toStringAsFixed(0),
                          style: TextStyle(
                            color: GlobalColors.textPrimary(ctx),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'الإجمالي',
                          style: TextStyle(
                            color: GlobalColors.textSecondary(ctx),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: slices
                      .map(
                        (sl) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: sl.color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  sl.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: GlobalColors.textPrimary(ctx),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                '${sl.value.toStringAsFixed(0)}  ·  '
                                '${(sl.value / total * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: GlobalColors.textSecondary(ctx),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A single-value ring for a percentage, reusing the donut painter with a
  /// filled arc and an empty remainder.
  Widget _ringCard(
    BuildContext ctx,
    String title,
    double? percent,
    Color color, {
    String? note,
  }) {
    if (percent == null) {
      return _noteCard(ctx, '$title — لا توجد بيانات.', Icons.percent_rounded);
    }

    final value = percent.clamp(0.0, 100.0);

    return _shell(
      ctx,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(ctx, title),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 128,
              height: 128,
              child: CustomPaint(
                painter: _DonutPainter(
                  slices: [
                    (value: value, color: color),
                    (value: 100 - value, color: GlobalColors.bg(ctx)),
                  ],
                  trackColor: GlobalColors.bg(ctx),
                ),
                child: Center(
                  child: Text(
                    '${value.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: GlobalColors.textPrimary(ctx),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GlobalColors.textSecondary(ctx),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardTitle(BuildContext ctx, String title) => Text(
    title,
    style: TextStyle(
      color: GlobalColors.textPrimary(ctx),
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _sourcesCard(BuildContext ctx, ReportData r) {
    return _shell(
      ctx,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'التحصيل حسب الوسيلة',
            style: TextStyle(
              color: GlobalColors.textPrimary(ctx),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...r.bySource.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.name,
                      style: TextStyle(
                        color: GlobalColors.textPrimary(ctx),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '${s.count} عملية',
                    style: TextStyle(
                      color: GlobalColors.textSecondary(ctx),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${s.total.toStringAsFixed(0)} ${AppGlobals.currency}',
                    style: TextStyle(
                      color: GlobalColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION PILL — تبويب قسم التقرير
//
//  Its own widget rather than reusing AppFilterChip:
//  these carry an icon and sit as the page's primary
//  navigation, so they read one step heavier than a
//  filter chip does.
// ─────────────────────────────────────────────
class _SectionPill extends StatefulWidget {
  const _SectionPill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_SectionPill> createState() => _SectionPillState();
}

class _SectionPillState extends State<_SectionPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    colors: [
                      GlobalColors.accent.withValues(alpha: 0.22),
                      GlobalColors.accentSoft.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  )
                : null,
            color: active
                ? null
                : _hovered
                ? GlobalColors.card(context).withValues(alpha: 0.6)
                : GlobalColors.surface(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active
                  ? GlobalColors.accent.withValues(alpha: 0.5)
                  : GlobalColors.border(context),
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: active
                    ? GlobalColors.accentSoft
                    : GlobalColors.textSecondary(context),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: active
                      ? GlobalColors.accentSoft
                      : _hovered
                      ? GlobalColors.textPrimary(context)
                      : GlobalColors.textSecondary(context),
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────
//  DONUT PAINTER
//
//  Kept deliberately small: the panel still has no
//  charting dependency, and a ring of four arcs is
//  a dozen lines of canvas work.
// ─────────────────────────────
class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.slices, required this.trackColor});

  final List<({double value, Color color})> slices;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (t, s) => t + s.value);
    if (total <= 0) return;

    const stroke = 18.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    canvas.drawArc(
      rect,
      0,
      6.2831853,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );

    // Starts at twelve o'clock and runs clockwise, which is how a share of
    // a whole reads regardless of the page's RTL direction.
    var start = -1.5707963;

    for (final slice in slices) {
      final sweep = slice.value / total * 6.2831853;
      if (sweep <= 0) continue;

      canvas.drawArc(
        rect,
        start,
        // A hairline gap between arcs so adjacent slices stay separable
        // when two of them are close in colour.
        sweep > 0.06 ? sweep - 0.03 : sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = slice.color,
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.trackColor != trackColor;
}
