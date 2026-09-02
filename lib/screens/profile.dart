import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/profile_bloc/profile_cubit.dart';
import '../components/general/app_dialog.dart';
import '../components/general/app_field.dart';
import '../components/general/empty_widget.dart';
import '../components/general/modal_page.dart';
import '../components/general/snackbar.dart';
import '../components/general/stat_card.dart';
import '../models/catalog_model.dart';
import '../models/profile_model.dart';
import '../src/app_colors.dart';
import '../src/app_globals.dart';
import '../src/app_permissions.dart';
import 'user_audit.dart';

// ─────────────────────────────────────────────
//  USER PROFILE — الملف الشخصي
//  ONE screen for every kind of account.
//
//  The role decides which sections appear, not
//  which screen opens: a member gets enrolments,
//  payments and attendance; a trainer gets their
//  sessions and ratings; staff get KPIs and pay.
//  Everything else — the header, the stat strip,
//  the section chrome — is shared, so a new
//  counter is one entry in a list rather than a
//  new page.
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
  /// they aren't dropped on a profile and left to find the button. The
  /// profile still renders behind it, so what the member is already on is
  /// visible before committing to another.
  final bool autoEnroll;

  /// Shown in the header until the fetch lands, so opening a profile from a
  /// table doesn't flash an empty title bar.
  final String? fallbackName;

  /// The one way to open a profile. Keeps the cubit's lifetime tied to the
  /// route so a stale profile can't leak into the next one.
  ///
  /// Opens as a panel over the app rather than as a pushed page. You reach a
  /// profile *from* a table you are working through, and replacing that table
  /// with a full screen threw away the context you opened it from — the panel
  /// leaves it visible behind the blur, and leaves the nav bar usable.
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
    // ModalPage supplies the Directionality, the frosted surface and the
    // sizing that leaves the top bar visible.
    return ModalPage(
      // SelectionArea sits here, per screen, rather than once in
      // MaterialApp.builder. `builder` wraps the Navigator, so a
      // SelectionArea there would be ABOVE the Overlay and its
      // copy/select context menu would have nowhere to mount - the same
      // trap Tooltip hits in that position. Inside a route the Overlay is
      // an ancestor, so right-click copy works.
      child: SelectionArea(
        child: Material(
          // Transparent: the panel behind already paints the surface, and a
          // second opaque layer would cancel the blur showing through.
          color: Colors.transparent,
          child: BlocConsumer<ProfileCubit, AppStates>(
            listener: (ctx, state) {
              if (state is AppFailure) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: false);
              }
              if (state is AppSuccess) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: true);
              }

              // Arrived here to enrol, and the profile has now loaded — open
              // the form. Waiting for the load matters: the dialog reads the
              // member's current state, and firing it against an empty
              // profile would show a blank banner behind it.
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
                  ),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                            children: _sections(ctx, c, p),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // The role switch lives here and nowhere else.
  List<Widget> _sections(BuildContext ctx, ProfileCubit c, UserProfile p) {
    if (p.isPlayer) return _playerSections(ctx, c, p);
    if (p.isTrainer) return _trainerSections(p);
    return _staffSections(p);
  }

  // ── Member — العضو ──────────────────────────
  List<Widget> _playerSections(
    BuildContext ctx,
    ProfileCubit c,
    UserProfile p,
  ) {
    final s = p.stats;
    return [
      _MembershipBanner(profile: p, onEnroll: () => showEnrollDialog(ctx, c)),
      const SizedBox(height: 16),
      Row(
        children: [
          StatCard(
            label: 'نسبة الحضور',
            value: s.attendanceRate == null
                ? '—'
                : '${s.attendanceRate!.toStringAsFixed(0)}%',
            sub: '${s.presentCount} حضور · ${s.absentCount} غياب',
            icon: Icons.how_to_reg_rounded,
            color: _rateColor(s.attendanceRate),
          ),
          const SizedBox(width: 12),
          StatCard(
            label: 'الحصص المسجّلة',
            value: '${s.sessionsRecorded}',
            sub: '${s.lateCount} تأخير · ${s.excusedCount} بعذر',
            icon: Icons.event_available_rounded,
            color: GlobalColors.blue,
          ),
          const SizedBox(width: 12),
          StatCard(
            label: 'إجمالي المدفوع',
            value: '${s.totalPaid.toStringAsFixed(0)} ${AppGlobals.currency}',
            sub: s.pendingAmount > 0
                ? 'معلّق: ${s.pendingAmount.toStringAsFixed(0)}'
                : 'لا مبالغ معلّقة',
            icon: Icons.payments_rounded,
            color: s.pendingAmount > 0
                ? GlobalColors.gold
                : GlobalColors.green,
          ),
          const SizedBox(width: 12),
          StatCard(
            label: 'الاشتراكات',
            value: '${s.enrollmentsCount}',
            sub: '${s.activeEnrollmentsCount} نشط',
            icon: Icons.card_membership_rounded,
            color: GlobalColors.accent,
          ),
        ],
      ),
      const SizedBox(height: 20),
      _Section(
        title: 'الاشتراكات',
        icon: Icons.card_membership_rounded,
        action: _SectionAction(
          label: 'تسجيل اشتراك',
          icon: Icons.add_rounded,
          onTap: () => showEnrollDialog(ctx, c),
        ),
        child: _EnrollmentList(
          enrollments: p.enrollments,
          onCancel: (id) => c.setEnrollmentStatus(id, 'cancelled'),
          onActivate: (id) => c.setEnrollmentStatus(id, 'active'),
        ),
      ),
      const SizedBox(height: 16),
      _Section(
        title: 'المدفوعات',
        icon: Icons.receipt_long_rounded,
        child: _MiniTable(
          headers: const ['المرجع', 'المبلغ', 'الحالة', 'التاريخ'],
          rows: p.payments
              .map(
                (x) => [
                  x.reference ?? '—',
                  '${x.amount?.toStringAsFixed(2) ?? '—'} ${AppGlobals.currency}',
                  x.statusAr,
                  x.createdAt ?? '—',
                ],
              )
              .toList(),
          emptyLabel: 'لا توجد مدفوعات',
        ),
      ),
      const SizedBox(height: 16),
      _Section(
        title: 'سجل الحضور',
        icon: Icons.fact_check_rounded,
        child: _MiniTable(
          headers: const ['التاريخ', 'الاشتراك', 'الحالة', 'ملاحظة'],
          rows: p.attendances
              .map(
                (x) => [
                  x.date ?? '—',
                  AppGlobals.membershipName(x.membershipId),
                  x.statusAr,
                  x.note ?? '—',
                ],
              )
              .toList(),
          emptyLabel: 'لا يوجد سجل حضور',
        ),
      ),
    ];
  }

  // ── Trainer — المدرب ────────────────────────
  List<Widget> _trainerSections(UserProfile p) {
    final s = p.stats;
    return [
      Row(
        children: [
          StatCard(
            label: 'متوسط التقييم',
            value: s.averageRating == null
                ? '—'
                : s.averageRating!.toStringAsFixed(1),
            sub: '${s.ratingsCount} تقييم',
            icon: Icons.star_rounded,
            color: GlobalColors.gold,
          ),
          const SizedBox(width: 12),
          StatCard(
            label: 'الحصص',
            value: '${s.sessionsCount}',
            sub: '${s.completedSessionsCount} مكتملة',
            icon: Icons.sports_rounded,
            color: GlobalColors.blue,
          ),
          const SizedBox(width: 12),
          StatCard(
            label: 'حصص قادمة',
            value: '${s.upcomingSessionsCount}',
            sub: 'من اليوم فصاعداً',
            icon: Icons.upcoming_rounded,
            color: GlobalColors.accent,
          ),
          const SizedBox(width: 12),
          StatCard(
            label: 'الاشتراكات المسندة',
            value: '${s.membershipsCount}',
            sub: 'يدرّبها حالياً',
            icon: Icons.card_membership_rounded,
            color: GlobalColors.green,
          ),
        ],
      ),
      const SizedBox(height: 20),
      _Section(
        title: 'أحدث الحصص',
        icon: Icons.sports_rounded,
        child: _MiniTable(
          headers: const ['التاريخ', 'الاشتراك', 'من', 'إلى', 'الحالة'],
          rows: p.sessions
              .map(
                (x) => [
                  x.sessionDate ?? '—',
                  x.membershipName ?? '—',
                  x.startTime ?? '—',
                  x.endTime ?? '—',
                  x.statusAr,
                ],
              )
              .toList(),
          emptyLabel: 'لا توجد حصص',
        ),
      ),
      const SizedBox(height: 16),
      _Section(
        title: 'التقييمات المستلمة',
        icon: Icons.star_rounded,
        child: _MiniTable(
          headers: const ['المُقيِّم', 'التقييم', 'ملاحظة'],
          rows: p.ratings
              .map(
                (x) => [
                  x.raterName ?? '—',
                  x.rating?.toStringAsFixed(1) ?? '—',
                  x.note ?? '—',
                ],
              )
              .toList(),
          emptyLabel: 'لا توجد تقييمات',
        ),
      ),
      const SizedBox(height: 16),
      _salarySection(p),
    ];
  }

  // ── Staff — الموظفون ────────────────────────
  List<Widget> _staffSections(UserProfile p) {
    final s = p.stats;
    return [
      Row(
        children: [
          StatCard(
            label: 'متوسط الإنجاز',
            value: s.averageAchievement == null
                ? '—'
                : '${s.averageAchievement!.toStringAsFixed(0)}%',
            sub: '${s.kpiRecordsCount} سجل أداء',
            icon: Icons.speed_rounded,
            color: _rateColor(s.averageAchievement),
          ),
          const SizedBox(width: 12),
          StatCard(
            label: 'إجمالي الرواتب',
            value:
                '${s.salariesTotal.toStringAsFixed(0)} ${AppGlobals.currency}',
            sub: '${s.salariesCount} دفعة',
            icon: Icons.account_balance_wallet_rounded,
            color: GlobalColors.green,
          ),
          const SizedBox(width: 12),
          StatCard(
            label: 'آخر راتب',
            value: s.lastSalaryAt ?? '—',
            sub: 'تاريخ الصرف',
            icon: Icons.event_rounded,
            color: GlobalColors.blue,
          ),
        ],
      ),
      const SizedBox(height: 20),
      _Section(
        title: 'سجلات الأداء',
        icon: Icons.speed_rounded,
        child: _MiniTable(
          headers: const ['المؤشر', 'المستهدف', 'المحقق', 'الفترة'],
          rows: p.kpiRecords
              .map(
                (x) => [
                  x.metric ?? '—',
                  x.target?.toStringAsFixed(1) ?? '—',
                  x.actual?.toStringAsFixed(1) ?? '—',
                  x.period ?? '—',
                ],
              )
              .toList(),
          emptyLabel: 'لا توجد سجلات أداء',
        ),
      ),
      const SizedBox(height: 16),
      _salarySection(p),
    ];
  }

  Widget _salarySection(UserProfile p) => _Section(
    title: 'الرواتب',
    icon: Icons.account_balance_wallet_rounded,
    child: _MiniTable(
      headers: const ['المبلغ', 'الفترة'],
      rows: p.salaries
          .map(
            (x) => [
              '${x.amount?.toStringAsFixed(2) ?? '—'} ${AppGlobals.currency}',
              x.period ?? '—',
            ],
          )
          .toList(),
      emptyLabel: 'لا توجد رواتب مسجّلة',
    ),
  );

  static Color _rateColor(double? pct) {
    if (pct == null) return GlobalColors.blue;
    if (pct >= 80) return GlobalColors.green;
    if (pct >= 50) return GlobalColors.gold;
    return GlobalColors.red;
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
    this.fallbackName,
  });

  final UserProfile profile;
  final String? fallbackName;
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final u = profile.user;
    final name = u?.name ?? fallbackName ?? '...';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      decoration: BoxDecoration(
        color: GlobalColors.surface(context).withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: GlobalColors.border(context)),
        ),
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
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Chip(text: u?.roleAr ?? '—'),
                    if (u?.email != null)
                      _Muted(icon: Icons.mail_outline_rounded, text: u!.email!),
                    if (u?.phone != null)
                      _Muted(
                        icon: Icons.phone_outlined,
                        text: u!.phone!,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Beside refresh: reading a profile and asking "what has this
          // account been doing" is the same sitting, and the club-wide trail
          // in settings makes you filter your way back to this one person.
          if (Permissions.canSeeAudit && u?.userId != null)
            IconButton(
              onPressed: () =>
                  showUserAuditDialog(context, u!.userId!, name: u.name),
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
          // Close, not back: nothing is being navigated away from, so an
          // arrow would describe the wrong thing. It sits at the end of the
          // header, where a panel's dismiss control belongs.
          ModalCloseButton(onTap: onClose),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? GlobalColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700),
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
      Text(
        text,
        style: TextStyle(
          color: GlobalColors.textSecondary(context),
          fontSize: 12,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────
//  MEMBERSHIP BANNER — حالة الاشتراك
//  The answer to "is this member paid up?", which
//  the panel previously had no way to show.
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

    final color = none
        ? GlobalColors.red
        : (urgent ? GlobalColors.gold : GlobalColors.green);

    return Container(
      padding: const EdgeInsets.all(18),
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
                : (urgent
                      ? Icons.hourglass_bottom_rounded
                      : Icons.verified_rounded),
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
                    style: TextStyle(
                      color: GlobalColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
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
//  SECTION — قسم
// ─────────────────────────────────────────────
class _SectionAction {
  const _SectionAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final _SectionAction? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GlobalColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlobalColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: GlobalColors.accentSoft),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (action != null)
                  TextButton.icon(
                    onPressed: action!.onTap,
                    icon: Icon(action!.icon, size: 16),
                    label: Text(action!.label),
                    style: TextButton.styleFrom(
                      foregroundColor: GlobalColors.accentSoft,
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: GlobalColors.border(context)),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MINI TABLE — جدول مصغّر
//  The profile shows a capped recent slice, so it
//  needs headers and rows but none of AppTable's
//  paging machinery.
// ─────────────────────────────────────────────
class _MiniTable extends StatelessWidget {
  const _MiniTable({
    required this.headers,
    required this.rows,
    required this.emptyLabel,
  });

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
        ...rows.map(
          (r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: r
                  .map(
                    (cell) => Expanded(
                      child: Text(
                        cell,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: GlobalColors.textPrimary(context),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  ENROLMENT LIST — قائمة الاشتراكات
//  Rows carry their own actions because an
//  enrolment is the one thing on this screen the
//  desk changes in place.
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
        child: EmptyState(title: 'لا توجد اشتراكات'),
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
                      style: TextStyle(
                        color: GlobalColors.textSecondary(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _Chip(text: e.statusAr, color: color)),
              if (pending && e.id != null)
                TextButton(
                  onPressed: () => onActivate(e.id!),
                  child: const Text('تفعيل'),
                ),
              if (e.status != 'cancelled' && e.id != null)
                TextButton(
                  onPressed: () => onCancel(e.id!),
                  style: TextButton.styleFrom(
                    foregroundColor: GlobalColors.red,
                  ),
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
//  The action the panel was missing entirely:
//  put a member on a membership and take the
//  money for it. Both legs go to the server as
//  one transactional call, so a failed payment
//  can't leave a stranded enrolment behind.
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
          final picked = memberships
              .where((m) => m.id == c.formMembershipId)
              .firstOrNull;

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
                  label: 'الاشتراك',
                  icon: Icons.card_membership_rounded,
                  emptyLabel: 'اختر الاشتراك',
                  onChanged: (v) => setLocal(() => c.pickMembership(v)),
                ),
                const SizedBox(height: 12),

                // The membership carries the price and the duration, so once
                // one is picked there is nothing left to type in the normal
                // case. Shown here so the desk can see what it's committing
                // to before saving.
                if (picked != null)
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
                if (picked != null) const SizedBox(height: 12),

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
                    hint: 'يُعبَّأ من سعر الاشتراك — عدّله عند الحاجة',
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
                    onChanged: (v) =>
                        setLocal(() => c.formPaymentStatus = v ?? 'success'),
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
