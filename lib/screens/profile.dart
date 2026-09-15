import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/profile_bloc/profile_cubit.dart';
import '../components/general/app_dialog.dart';
import '../components/general/app_field.dart';
import '../components/general/app_table.dart';
import '../components/general/empty_widget.dart';
import '../components/general/modal_page.dart';
import '../components/general/snackbar.dart';
import '../components/general/star_rating.dart';
import '../components/general/stat_card.dart';
import '../models/catalog_model.dart';
import '../models/finance_model.dart';
import '../models/hr_model.dart';
import '../models/paginated_model.dart';
import '../models/performance_model.dart';
import '../models/profile_model.dart';
import '../models/sessions_model.dart';
import '../models/users_model.dart';
import '../src/app_colors.dart';
import '../src/app_globals.dart';
import '../src/app_permissions.dart';
import 'user_audit.dart';

// ─────────────────────────────────────────────
//  USER PROFILE — الملف الشخصي
//  ONE screen for every kind of account.
//
//  Everything on it describes one period, chosen
//  at the top: the stats, and every tab under them.
//  The role decides the stats and which tabs exist;
//  the server decides which of those this viewer
//  may open, so a tab never appears only to 403.
// ─────────────────────────────────────────────

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.userId,
    this.fallbackName,
    this.autoEnroll = false,
  });

  final int userId;

  /// Opens the enrol form as soon as the profile has loaded. Set when the
  /// user arrived *in order to* enrol — the dashboard's quick action — so
  /// they aren't dropped on a profile and left to find the button.
  final bool autoEnroll;

  /// Shown in the header until the fetch lands, so opening a profile from a
  /// table doesn't flash an empty title bar.
  final String? fallbackName;

  /// The one way to open a profile. Keeps the cubit's lifetime tied to the
  /// route so a stale profile can't leak into the next one.
  ///
  /// Opens as a panel over the app rather than as a pushed page, so the table
  /// it was opened from stays visible behind it.
  static void open(
    BuildContext context,
    int userId, {
    String? name,
    bool autoEnroll = false,
  }) {
    ModalPage.show(
      context,
      BlocProvider(
        create: (_) => ProfileCubit(userId)..fetch(),
        child: UserProfileScreen(
          userId: userId,
          fallbackName: name,
          autoEnroll: autoEnroll,
        ),
      ),
    );
  }

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  /// Guards against the listener firing the dialog twice — every refetch
  /// emits AppLoaded, and re-opening on each would be maddening.
  bool _autoEnrollFired = false;

  @override
  Widget build(BuildContext context) {
    return ModalPage(
      // SelectionArea per screen rather than in MaterialApp.builder, which
      // sits above the Overlay and leaves the copy menu nowhere to mount.
      child: SelectionArea(
        child: Material(
          color: Colors.transparent,
          child: BlocConsumer<ProfileCubit, AppStates>(
            listener: (ctx, state) {
              if (state is AppFailure) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: false);
              }
              if (state is AppSuccess) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: true);
              }

              if (widget.autoEnroll &&
                  !_autoEnrollFired &&
                  state is AppLoaded &&
                  ctx.read<ProfileCubit>().profile.isPlayer) {
                _autoEnrollFired = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) showEnrollDialog(ctx, ctx.read<ProfileCubit>());
                });
              }
            },
            builder: (ctx, state) {
              final c = ctx.read<ProfileCubit>();
              final p = c.profile;
              final loading = state is AppLoading && p.user == null;

              return Column(
                children: [
                  _Header(
                    profile: p,
                    fallbackName: widget.fallbackName,
                    onClose: () => Navigator.of(ctx).maybePop(),
                    onRefresh: c.fetch,
                    onLetter: Permissions.canIssueLetters && (p.isTrainer || p.isStaff)
                        ? c.openEmploymentLetter
                        : null,
                  ),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : _ProfileBody(cubit: c),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BODY — الملخص والتبويبات
// ─────────────────────────────────────────────

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.cubit});
  final ProfileCubit cubit;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> with TickerProviderStateMixin {
  TabController? _tabs;
  List<String> _keys = const [];

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  /// Rebuilt only when the set of tabs changes, so picking a new period keeps
  /// the tab you were on. The old controller is disposed after the frame: the
  /// TabBar still holding it detaches during this build.
  void _syncTabs() {
    final keys = widget.cubit.profile.tabs;
    if (listEquals(keys, _keys) && (_tabs != null || keys.isEmpty)) return;

    final old = _tabs;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }

    _keys = keys;
    _tabs = null;
    if (keys.isEmpty) return;

    final start = keys.indexOf(widget.cubit.activeTab ?? '');
    final controller = TabController(
      length: keys.length,
      vsync: this,
      initialIndex: start < 0 ? 0 : start,
    );
    controller.addListener(() {
      if (!controller.indexIsChanging) {
        widget.cubit.openTab(_keys[controller.index]);
      }
    });
    _tabs = controller;
  }

  @override
  Widget build(BuildContext context) {
    _syncTabs();
    final c = widget.cubit;
    final p = c.profile;
    final tabs = _tabs;

    return NestedScrollView(
      headerSliverBuilder: (ctx, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RangeBar(cubit: c),
                const SizedBox(height: 14),
                ..._summary(ctx, c, p),
              ],
            ),
          ),
        ),
        if (tabs != null)
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              background: GlobalColors.surface(ctx),
              border: GlobalColors.border(ctx),
              bar: TabBar(
                key: ValueKey(_keys.join('|')),
                controller: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: GlobalColors.accentSoft,
                unselectedLabelColor: GlobalColors.textSecondary(ctx),
                indicatorColor: GlobalColors.accent,
                indicatorWeight: 2.5,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: [
                  for (final key in _keys)
                    Tab(
                      height: 44,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_tabIcon(key), size: 16),
                          const SizedBox(width: 6),
                          Text(_tabLabel(key, p)),
                          if (c.sections[key] != null) ...[
                            const SizedBox(width: 6),
                            _CountBadge(count: c.sections[key]!.total),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
      body: tabs == null
          ? const Center(child: EmptyState(title: 'لا توجد سجلات يمكنك الاطلاع عليها'))
          : TabBarView(
              key: ValueKey(_keys.join('|')),
              controller: tabs,
              children: [for (final key in _keys) _SectionView(cubit: c, section: key)],
            ),
    );
  }

  // ── Summary per role ────────────────────────

  List<Widget> _summary(BuildContext ctx, ProfileCubit c, UserProfile p) {
    final s = p.stats;
    final u = p.user;

    if (p.isPlayer) {
      return [
        _MembershipBanner(profile: p, onEnroll: () => showEnrollDialog(ctx, c)),
        if (u?.player?.hasHealthCondition ?? false) ...[
          const SizedBox(height: 12),
          _HealthCard(note: u!.player!.healthCondition),
        ],
        const SizedBox(height: 14),
        _cards([
          StatCard(
            label: 'نسبة الحضور',
            value: s.attendanceRate == null ? '—' : '${s.attendanceRate!.toStringAsFixed(0)}%',
            sub: '${s.presentCount} حضور · ${s.lateCount} تأخير · ${s.absentCount} غياب',
            icon: Icons.how_to_reg_rounded,
            color: _rateColor(s.attendanceRate),
          ),
          StatCard(
            label: 'الحصص المسجّلة',
            value: '${s.sessionsRecorded}',
            sub: '${s.excusedCount} غياب بعذر',
            icon: Icons.event_available_rounded,
            color: GlobalColors.blue,
          ),
          StatCard(
            label: 'متوسط التقييم',
            value: s.averageRating?.toStringAsFixed(1) ?? '—',
            sub: '${s.ratingsCount} تقييم من المدربين',
            icon: Icons.star_rounded,
            color: GlobalColors.gold,
          ),
          if (s.has('total_paid'))
            StatCard(
              label: 'المدفوع',
              value: '${s.totalPaid.toStringAsFixed(0)} ${AppGlobals.currency}',
              sub: s.pendingAmount > 0
                  ? 'معلّق: ${s.pendingAmount.toStringAsFixed(0)}'
                  : 'لا مبالغ معلّقة',
              icon: Icons.payments_rounded,
              color: s.pendingAmount > 0 ? GlobalColors.gold : GlobalColors.green,
            ),
        ]),
      ];
    }

    final payroll = <Widget>[
      if (s.has('attendance_days'))
        StatCard(
          label: 'أيام الحضور',
          value: '${s.attendanceDays}',
          sub: s.lastCheckInAt == null ? 'لم يسجّل حضوراً بعد' : 'آخر حضور ${s.lastCheckInAt}',
          icon: Icons.where_to_vote_rounded,
          color: GlobalColors.green,
        ),
      if (s.has('overtime_hours'))
        StatCard(
          label: 'الساعات الإضافية',
          value: formatHours(s.overtimeHours),
          sub: 'ضمن الفترة',
          icon: Icons.more_time_rounded,
          color: GlobalColors.purple,
        ),
      if (s.has('kpi_records_count'))
        StatCard(
          label: 'تحقيق الأهداف',
          value: s.averageAchievement == null ? '—' : '${s.averageAchievement!.toStringAsFixed(0)}%',
          sub: '${s.kpiRecordsCount} مؤشر مسجّل',
          icon: Icons.speed_rounded,
          color: GlobalColors.blue,
        ),
      if (s.has('salaries_total'))
        StatCard(
          label: 'الرواتب المصروفة',
          value: '${s.salariesTotal.toStringAsFixed(0)} ${AppGlobals.currency}',
          sub: '${s.salariesCount} دفعة',
          icon: Icons.account_balance_wallet_rounded,
          color: GlobalColors.gold,
        ),
    ];

    return [
      if (Permissions.canSeeHr && u != null) ...[
        _HrCard(user: u),
        const SizedBox(height: 14),
      ],
      if (p.isTrainer) ...[
        _cards([
          StatCard(
            label: 'متوسط تقييمه',
            value: s.averageRating?.toStringAsFixed(1) ?? '—',
            sub: '${s.ratingsCount} تقييم مستلم',
            icon: Icons.star_rounded,
            color: GlobalColors.gold,
          ),
          StatCard(
            label: 'الحصص',
            value: '${s.sessionsCount}',
            sub: '${s.completedSessionsCount} مكتملة · ${s.upcomingSessionsCount} قادمة',
            icon: Icons.sports_rounded,
            color: GlobalColors.blue,
          ),
          StatCard(
            label: 'اللاعبون',
            value: '${s.playersCount}',
            sub: 'في ${s.membershipsCount} باقة',
            icon: Icons.groups_rounded,
            color: GlobalColors.green,
          ),
          StatCard(
            label: 'تقييماته للاعبين',
            value: '${s.assessmentsGivenCount}',
            sub: 'ضمن الفترة',
            icon: Icons.rate_review_rounded,
            color: GlobalColors.accent,
          ),
        ]),
        if (payroll.isNotEmpty) ...[const SizedBox(height: 12), _cards(payroll)],
      ] else
        _cards([
          ...payroll,
          StatCard(
            label: 'متوسط التقييم',
            value: s.averageRating?.toStringAsFixed(1) ?? '—',
            sub: '${s.ratingsCount} تقييم',
            icon: Icons.star_rounded,
            color: GlobalColors.gold,
          ),
        ]),
    ];
  }

  /// StatCard expands itself, so a row of them only needs the gaps.
  Widget _cards(List<Widget> cards) => Row(
    children: [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(width: 12),
        cards[i],
      ],
    ],
  );

  static Color _rateColor(double? pct) {
    if (pct == null) return GlobalColors.blue;
    if (pct >= 80) return GlobalColors.green;
    if (pct >= 50) return GlobalColors.gold;
    return GlobalColors.red;
  }
}

String _tabLabel(String key, UserProfile p) => switch (key) {
  'enrollments' => 'الاشتراكات',
  'attendances' => 'سجل الحضور',
  'ratings' => p.isPlayer ? 'تقييمات المدربين' : 'التقييمات المستلمة',
  'payments' => 'المدفوعات',
  'sessions' => 'الحصص',
  'assessments_given' => 'تقييماته للاعبين',
  'overtime' => 'الساعات الإضافية',
  'employee_attendances' => 'حضور الدوام',
  'kpi_records' => 'مؤشرات الأداء',
  'salaries' => 'الرواتب',
  _ => key,
};

IconData _tabIcon(String key) => switch (key) {
  'enrollments' => Icons.card_membership_rounded,
  'attendances' => Icons.fact_check_rounded,
  'ratings' => Icons.star_rounded,
  'payments' => Icons.receipt_long_rounded,
  'sessions' => Icons.sports_rounded,
  'assessments_given' => Icons.rate_review_rounded,
  'overtime' => Icons.more_time_rounded,
  'employee_attendances' => Icons.where_to_vote_rounded,
  'kpi_records' => Icons.speed_rounded,
  'salaries' => Icons.account_balance_wallet_rounded,
  _ => Icons.list_alt_rounded,
};

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({required this.bar, required this.background, required this.border});

  final TabBar bar;
  final Color background;
  final Color border;

  @override
  double get minExtent => 47;

  @override
  double get maxExtent => 47;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: bar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => true;
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(
      color: GlobalColors.accent.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$count',
      style: TextStyle(color: GlobalColors.accentSoft, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

// ─────────────────────────────────────────────
//  RANGE BAR — الفترة الزمنية
// ─────────────────────────────────────────────

class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.cubit});
  final ProfileCubit cubit;

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: cubit.from == null
          ? null
          : DateTimeRange(
              start: DateTime.parse(cubit.from!),
              end: DateTime.tryParse(cubit.to ?? '') ?? now,
            ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: GlobalColors.accent,
            surface: GlobalColors.card(context),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) cubit.applyRange(ProfileRange.custom, custom: picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GlobalColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlobalColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range_rounded, size: 18, color: GlobalColors.accentSoft),
          const SizedBox(width: 8),
          Text(
            'الفترة',
            style: TextStyle(
              color: GlobalColors.textPrimary(context),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in ProfileRange.values.where((r) => r != ProfileRange.custom))
                  AppFilterChip(
                    label: r.label,
                    isActive: cubit.range == r,
                    onTap: () => cubit.applyRange(r),
                  ),
                AppFilterChip(
                  label: ProfileRange.custom.label,
                  isActive: cubit.range == ProfileRange.custom,
                  onTap: () => _pickCustom(context),
                ),
              ],
            ),
          ),
          Text(
            cubit.from == null ? 'كل السجلات' : '${cubit.from}  ←  ${cubit.to ?? 'اليوم'}',
            style: TextStyle(color: GlobalColors.textSecondary(context), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION VIEW — محتوى التبويب
// ─────────────────────────────────────────────

class _SectionView extends StatelessWidget {
  const _SectionView({required this.cubit, required this.section});

  final ProfileCubit cubit;
  final String section;

  @override
  Widget build(BuildContext context) {
    final data = cubit.sections[section];
    final loading = cubit.loadingSections.contains(section);

    if (data == null) {
      return Center(
        child: loading
            ? const CircularProgressIndicator()
            : TextButton.icon(
                onPressed: () => cubit.loadSection(section),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحميل السجلات'),
              ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: GlobalColors.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GlobalColors.border(context)),
          ),
          child: _content(data),
        ),
        if (data.lastPage > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (loading) ...[
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                ],
                Paginator(
                  data: data,
                  onPage: (page) => cubit.loadSection(section, page: page),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _content(Paginated<dynamic> data) {
    final items = data.items;
    const empty = 'لا توجد سجلات ضمن الفترة المحددة';

    switch (section) {
      case 'enrollments':
        return _EnrollmentList(
          enrollments: items.cast<Enrollment>(),
          onCancel: (id) => cubit.setEnrollmentStatus(id, 'cancelled'),
          onActivate: (id) => cubit.setEnrollmentStatus(id, 'active'),
        );
      case 'ratings':
      case 'assessments_given':
        return _RatingList(
          ratings: items.cast<SessionRating>(),
          given: section == 'assessments_given',
        );
      case 'attendances':
        return _MiniTable(
          headers: const ['التاريخ', 'الباقة', 'الحالة', 'ملاحظة'],
          rows: [
            for (final Attendance x in items)
              [x.date ?? '—', AppGlobals.membershipName(x.membershipId), x.statusAr, x.note ?? '—'],
          ],
          emptyLabel: empty,
        );
      case 'payments':
        return _MiniTable(
          headers: const ['المرجع', 'المبلغ', 'الحالة', 'التاريخ'],
          rows: [
            for (final Payment x in items)
              [
                x.reference ?? '—',
                '${x.amount?.toStringAsFixed(2) ?? '—'} ${AppGlobals.currency}',
                x.statusAr,
                x.createdAt ?? '—',
              ],
          ],
          emptyLabel: empty,
        );
      case 'sessions':
        return _MiniTable(
          headers: const ['التاريخ', 'الباقة', 'من', 'إلى', 'الحالة'],
          rows: [
            for (final ClubSession x in items)
              [x.sessionDate ?? '—', x.membershipName ?? '—', x.startTime ?? '—', x.endTime ?? '—', x.statusAr],
          ],
          emptyLabel: empty,
        );
      case 'overtime':
        return _MiniTable(
          headers: const ['التاريخ', 'الساعات', 'ملاحظة', 'سجّلها'],
          rows: [
            for (final OvertimeRecord x in items)
              [x.date ?? '—', formatHours(x.hours), x.note ?? '—', x.recorderName ?? '—'],
          ],
          emptyLabel: empty,
        );
      case 'employee_attendances':
        return _MiniTable(
          headers: const ['التاريخ', 'وقت التسجيل', 'المسافة من المركز'],
          rows: [
            for (final EmployeeClockIn x in items)
              [x.dateLabel, x.timeLabel, '${x.distanceMeters} م'],
          ],
          emptyLabel: empty,
        );
      case 'kpi_records':
        return _MiniTable(
          headers: const ['المؤشر', 'المستهدف', 'المحقق', 'الفترة'],
          rows: [
            for (final KpiRecord x in items)
              [
                x.metric ?? '—',
                x.target?.toStringAsFixed(1) ?? '—',
                x.actual?.toStringAsFixed(1) ?? '—',
                x.period ?? '—',
              ],
          ],
          emptyLabel: empty,
        );
      case 'salaries':
        return _MiniTable(
          headers: const ['المبلغ', 'الفترة'],
          rows: [
            for (final Salary x in items)
              ['${x.amount?.toStringAsFixed(2) ?? '—'} ${AppGlobals.currency}', x.period ?? '—'],
          ],
          emptyLabel: empty,
        );
    }
    return const EmptyState(title: empty);
  }
}

// ─────────────────────────────────────────────
//  HEADER — الترويسة
// ─────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.onClose,
    required this.onRefresh,
    this.onLetter,
    this.fallbackName,
  });

  final UserProfile profile;
  final String? fallbackName;
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  /// Null when the viewer may not issue letters, or the account is a member.
  final VoidCallback? onLetter;

  @override
  Widget build(BuildContext context) {
    final u = profile.user;
    final name = u?.name ?? fallbackName ?? '...';
    final flagged = u?.player?.hasHealthCondition ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      decoration: BoxDecoration(
        color: GlobalColors.surface(context).withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: GlobalColors.border(context))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: GlobalColors.accent.withValues(alpha: 0.15),
            backgroundImage: (u?.avatar != null && u!.avatar!.isNotEmpty)
                ? NetworkImage(u.avatar!)
                : null,
            child: (u?.avatar == null || u!.avatar!.isEmpty)
                ? Text(
                    name.characters.take(1).toString(),
                    style: TextStyle(
                      color: GlobalColors.accentSoft,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Chip(text: u?.roleAr ?? '—'),
                    if (u?.player?.clubId != null)
                      _Chip(text: u!.player!.clubId!, color: GlobalColors.blue),
                    if (flagged)
                      _Chip(text: 'حالة صحية خاصة', color: GlobalColors.red, icon: Icons.medical_information_rounded),
                    if (u?.email != null)
                      _Muted(icon: Icons.mail_outline_rounded, text: u!.email!),
                    if (u?.phone != null)
                      _Muted(icon: Icons.phone_outlined, text: u!.phone!),
                  ],
                ),
              ],
            ),
          ),
          if (onLetter != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: OutlinedButton.icon(
                onPressed: onLetter,
                icon: const Icon(Icons.description_rounded, size: 18),
                label: const Text('خطاب تعريف'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GlobalColors.accentSoft,
                  side: BorderSide(color: GlobalColors.accent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          // Beside refresh: reading a profile and asking "what has this
          // account been doing" is the same sitting.
          if (Permissions.canSeeAudit && u?.userId != null)
            IconButton(
              onPressed: () => showUserAuditDialog(context, u!.userId!, name: u.name),
              icon: const Icon(Icons.history_rounded),
              color: GlobalColors.textSecondary(context),
              tooltip: 'سجل النشاط',
            ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            color: GlobalColors.textSecondary(context),
            tooltip: 'تحديث',
          ),
          const SizedBox(width: 4),
          ModalCloseButton(onTap: onClose),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.color, this.icon});
  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? GlobalColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: GlobalColors.textSecondary(context)),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(color: GlobalColors.textSecondary(context), fontSize: 12)),
    ],
  );
}

// ─────────────────────────────────────────────
//  HEALTH CARD — الحالة الصحية
// ─────────────────────────────────────────────

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.note});

  /// Null when the viewer lacks people.health.view: they see that there is a
  /// condition, not what it is.
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GlobalColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlobalColors.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.medical_information_rounded, color: GlobalColors.red, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حالة صحية خاصة',
                  style: TextStyle(color: GlobalColors.red, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  note ?? 'أفصح ولي الأمر عن حالة صحية — تفاصيلها متاحة لأصحاب صلاحية الاطلاع على الحالة الصحية.',
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HR CARD — بيانات الموارد البشرية
// ─────────────────────────────────────────────

class _HrCard extends StatelessWidget {
  const _HrCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final t = user.trainer;
    final e = user.employee;
    final PayrollDetails? hr = e ?? t;
    if (hr == null) return const SizedBox.shrink();

    final salary = e?.salary ?? t?.salary;
    final missing = hr.iban == null || hr.bankName == null;

    Widget item(IconData icon, String label, String? value) => SizedBox(
      width: 210,
      child: Row(
        children: [
          Icon(icon, size: 17, color: GlobalColors.accentSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: GlobalColors.textSecondary(context), fontSize: 11)),
                Text(
                  value ?? 'غير مسجّل',
                  style: TextStyle(
                    color: value == null ? GlobalColors.red : GlobalColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GlobalColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: missing ? GlobalColors.gold.withValues(alpha: 0.4) : GlobalColors.border(context),
        ),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        children: [
          item(Icons.payments_rounded, 'الراتب الشهري',
              salary == null ? null : '${salary.toStringAsFixed(0)} ${AppGlobals.currency}'),
          item(Icons.event_available_rounded, 'تاريخ الالتحاق', hr.hiredAt),
          item(Icons.account_balance_rounded, 'البنك', hr.bankName),
          item(Icons.numbers_rounded, 'رقم الحساب', hr.accountNumber),
          item(Icons.credit_card_rounded, 'الآيبان', hr.ibanLabel),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MEMBERSHIP BANNER — حالة الاشتراك
// ─────────────────────────────────────────────

class _MembershipBanner extends StatelessWidget {
  const _MembershipBanner({required this.profile, required this.onEnroll});
  final UserProfile profile;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    final s = profile.stats;
    final none = s.currentMembership == null;
    final days = s.daysRemaining;
    final urgent = none || (days != null && days <= 7);
    final color = none ? GlobalColors.red : (urgent ? GlobalColors.gold : GlobalColors.green);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            none
                ? Icons.person_off_rounded
                : (urgent ? Icons.hourglass_bottom_rounded : Icons.verified_rounded),
            color: color,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.currentMembership ?? 'لا يوجد اشتراك نشط',
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  none
                      ? 'هذا العضو غير مشترك حالياً في أي باقة'
                      : '${s.membershipStateAr}  ·  ينتهي في ${s.currentEndsAt ?? '—'}',
                  style: TextStyle(color: color, fontSize: 13),
                ),
                if (s.pendingPaymentEnrollments > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${s.pendingPaymentEnrollments} اشتراك بانتظار الدفع',
                    style: TextStyle(color: GlobalColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          if (Permissions.canEnroll)
            FilledButton.icon(
              onPressed: onEnroll,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('تسجيل اشتراك'),
              style: FilledButton.styleFrom(
                backgroundColor: GlobalColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MINI TABLE — جدول مصغّر
// ─────────────────────────────────────────────

class _MiniTable extends StatelessWidget {
  const _MiniTable({required this.headers, required this.rows, required this.emptyLabel});

  final List<String> headers;
  final List<List<String>> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: EmptyState(title: emptyLabel),
      );
    }

    return Column(
      children: [
        Row(
          children: headers
              .map(
                (h) => Expanded(
                  child: Text(
                    h,
                    style: TextStyle(
                      color: GlobalColors.textSecondary(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < rows.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : Border(top: BorderSide(color: GlobalColors.border(context).withValues(alpha: 0.6))),
            ),
            child: Row(
              children: rows[i]
                  .map(
                    (cell) => Expanded(
                      child: Text(
                        cell,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: GlobalColors.textPrimary(context), fontSize: 12.5),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  RATINGS — التقييمات
// ─────────────────────────────────────────────

class _RatingList extends StatelessWidget {
  const _RatingList({required this.ratings, required this.given});

  final List<SessionRating> ratings;

  /// True on a trainer's "assessments given" tab, where the interesting name
  /// is the player assessed rather than the trainer who wrote it.
  final bool given;

  @override
  Widget build(BuildContext context) {
    if (ratings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: EmptyState(title: 'لا توجد تقييمات ضمن الفترة المحددة'),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < ratings.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : Border(top: BorderSide(color: GlobalColors.border(context).withValues(alpha: 0.6))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StarRating(value: ratings[i].stars, size: 15),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        given ? (ratings[i].rateeName ?? '—') : (ratings[i].raterName ?? '—'),
                        style: TextStyle(
                          color: GlobalColors.textPrimary(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        ratings[i].isGeneral
                            ? 'تقييم عام'
                            : [ratings[i].membershipName, ratings[i].sessionDate]
                                  .whereType<String>()
                                  .join(' · '),
                        style: TextStyle(color: GlobalColors.textSecondary(context), fontSize: 11),
                      ),
                      if (ratings[i].note != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          ratings[i].note!,
                          style: TextStyle(
                            color: GlobalColors.textPrimary(context),
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  ratings[i].createdAt ?? '',
                  style: TextStyle(color: GlobalColors.textSecondary(context), fontSize: 10.5),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  ENROLMENT LIST — قائمة الاشتراكات
// ─────────────────────────────────────────────

class _EnrollmentList extends StatelessWidget {
  const _EnrollmentList({
    required this.enrollments,
    required this.onCancel,
    required this.onActivate,
  });

  final List<Enrollment> enrollments;
  final void Function(int id) onCancel;
  final void Function(int id) onActivate;

  @override
  Widget build(BuildContext context) {
    if (enrollments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: EmptyState(title: 'لا توجد اشتراكات ضمن الفترة المحددة'),
      );
    }

    return Column(
      children: enrollments.map((e) {
        final active = e.status == 'active' && e.isActiveNow;
        final pending = e.status == 'pending_payment';
        final color = active
            ? GlobalColors.green
            : (pending ? GlobalColors.gold : GlobalColors.textSecondary(context));

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(width: 4, height: 34, color: color),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.membershipName ?? '—',
                      style: TextStyle(
                        color: GlobalColors.textPrimary(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${e.startDate ?? '—'} ← ${e.endDate ?? '—'}',
                      style: TextStyle(color: GlobalColors.textSecondary(context), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Expanded(child: _Chip(text: e.statusAr, color: color)),
              if (pending && e.id != null && Permissions.canEnroll)
                TextButton(onPressed: () => onActivate(e.id!), child: const Text('تفعيل')),
              if (e.status != 'cancelled' && e.id != null && Permissions.canEnroll)
                TextButton(
                  onPressed: () => onCancel(e.id!),
                  style: TextButton.styleFrom(foregroundColor: GlobalColors.red),
                  child: const Text('إلغاء'),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
//  ENROL DIALOG — تسجيل اشتراك
//  Put a member on a package and take the money
//  for it. Both legs go to the server as one
//  transactional call, so a failed payment can't
//  leave a stranded enrolment behind.
// ─────────────────────────────────────────────

void showEnrollDialog(BuildContext ctx, ProfileCubit c) {
  c.resetEnrollForm();

  showDialog(
    context: ctx,
    builder: (_) => BlocProvider.value(
      value: c,
      child: StatefulBuilder(
        builder: (sctx, setLocal) {
          final memberships = AppGlobals.memberships
              .where((m) => m.status == 'active' || m.status == null)
              .toList();
          final picked = memberships.where((m) => m.id == c.formMembershipId).firstOrNull;

          return AppDialog<ProfileCubit>(
            title: 'تسجيل اشتراك',
            icon: Icons.card_membership_rounded,
            saveLabel: c.collectPayment ? 'تسجيل وتحصيل' : 'تسجيل',
            width: 560,
            onSave: c.submitEnrollment,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDropdown<int>(
                  value: c.formMembershipId,
                  items: memberships.map((m) => m.id!).toList(),
                  labelOf: AppGlobals.membershipName,
                  label: 'الباقة',
                  icon: Icons.card_membership_rounded,
                  emptyLabel: 'اختر الباقة',
                  onChanged: (v) => setLocal(() => c.pickMembership(v)),
                ),
                const SizedBox(height: 12),
                if (picked != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GlobalColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'المدة ${picked.durationDays ?? '—'} يوم · '
                      'السعر ${picked.price?.toStringAsFixed(2) ?? '—'} ${AppGlobals.currency}'
                      '${picked.sportId != null ? ' · ${AppGlobals.sportName(picked.sportId)}' : ''}',
                      style: TextStyle(
                        color: GlobalColors.textSecondary(sctx),
                        fontSize: 11.5,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                DateField(
                  value: c.startCont.text.isEmpty ? null : c.startCont.text,
                  label: 'تاريخ البدء (اختياري — يبدأ اليوم)',
                  onPicked: (v) => setLocal(() => c.startCont.text = v),
                ),
                const SizedBox(height: 12),
                AppSwitch(
                  value: c.collectPayment,
                  label: 'تحصيل الدفعة الآن',
                  hint: c.collectPayment
                      ? 'سيُفعَّل الاشتراك فور نجاح الدفعة.'
                      : 'سيبقى الاشتراك بانتظار الدفع حتى تُسجَّل دفعته.',
                  onChanged: (v) => setLocal(() => c.collectPayment = v),
                ),
                if (c.collectPayment) ...[
                  const SizedBox(height: 12),
                  AppField(
                    controller: c.amountCont,
                    label: 'المبلغ',
                    icon: Icons.payments_rounded,
                    isNumber: true,
                    hint: 'يُعبَّأ من سعر الباقة — عدّله عند الحاجة',
                  ),
                  const SizedBox(height: 12),
                  AppDropdown<int>(
                    value: c.formSourceId,
                    items: AppGlobals.paymentSources
                        .where((s) => s.isActive)
                        .map((s) => s.id!)
                        .toList(),
                    labelOf: AppGlobals.sourceName,
                    label: 'مصدر الدفع',
                    icon: Icons.account_balance_rounded,
                    emptyLabel: 'المصدر الافتراضي',
                    onChanged: (v) => setLocal(() => c.formSourceId = v),
                  ),
                  const SizedBox(height: 12),
                  AppDropdown<String>(
                    value: c.formPaymentStatus,
                    items: const ['success', 'pending'],
                    labelOf: (s) => s == 'success' ? 'محصّلة' : 'معلّقة',
                    label: 'حالة الدفعة',
                    icon: Icons.verified_rounded,
                    onChanged: (v) => setLocal(() => c.formPaymentStatus = v ?? 'success'),
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    controller: c.notesCont,
                    label: 'ملاحظات (اختياري)',
                    icon: Icons.notes_rounded,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}
