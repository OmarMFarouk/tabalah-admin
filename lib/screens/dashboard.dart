import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/app_bloc/cubit.dart';
import '../blocs/base_states.dart';
import '../blocs/dashboard_bloc/dashboard_cubit.dart';
import '../components/general/app_field.dart';
import '../components/general/empty_widget.dart';
import '../components/general/page_header.dart';
import '../components/general/stat_card.dart';
import '../models/catalog_model.dart';
import '../models/finance_model.dart';
import '../models/sessions_model.dart';
import '../src/app_colors.dart';
import '../src/app_destinations.dart';
import '../src/app_globals.dart';
import '../src/app_presets.dart';
import 'profile.dart';

// ─────────────────────────────────────────────
//  DASHBOARD — الرئيسية
//  Headline counts, what's on today, and the
//  last few payments through the desk.
// ─────────────────────────────────────────────
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardCubit()..fetch(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      // SelectionArea sits here, per screen, rather than once in
      // MaterialApp.builder. `builder` wraps the Navigator, so a
      // SelectionArea there would be ABOVE the Overlay and its
      // copy/select context menu would have nowhere to mount - the same
      // trap Tooltip hits in that position. Inside a route the Overlay is
      // an ancestor, so right-click copy works.
      child: SelectionArea(
        child: Scaffold(
          backgroundColor: GlobalColors.bg(context),
          body: BlocBuilder<DashboardCubit, AppStates>(
            builder: (ctx, state) {
              final cubit = DashboardCubit.get(ctx);
              final loading = state is AppLoading;
              final s = cubit.stats;

              return Column(
                children: [
                  PageHeader(
                    title: 'نظرة عامة',
                    icon: Icons.dashboard_rounded,
                    isLoading: loading,
                    onRefresh: cubit.fetch,
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          // ── Quick actions ─────────────
                          _QuickActions(cubit: cubit),
                          const SizedBox(height: 4),

                          // ── Counts ────────────────────
                          StatRow(
                            cards: [
                              StatCard(
                                label: 'الأعضاء',
                                value: '${s?.players ?? 0}',
                                icon: Icons.people_alt_rounded,
                                color: GlobalColors.accent,
                                sub: 'مسجّل',
                              ),
                              StatCard(
                                label: 'المدربون',
                                value: '${s?.trainers ?? 0}',
                                icon: Icons.sports_rounded,
                                color: GlobalColors.blue,
                                sub: 'طاقم التدريب',
                              ),
                              StatCard(
                                label: 'الاشتراكات',
                                value: '${s?.memberships ?? 0}',
                                icon: Icons.card_membership_rounded,
                                color: GlobalColors.gold,
                                sub: 'حصة وباقة',
                              ),
                              StatCard(
                                label: 'التسجيلات',
                                value: '${s?.enrollments ?? 0}',
                                icon: Icons.assignment_turned_in_rounded,
                                color: GlobalColors.green,
                                sub: 'اشتراك نشط',
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // The second row used to be revenue, pending and
                          // refunds. Those answer "how did we do", which is
                          // a weekly question and now lives on the reports
                          // page; this screen answers "what is happening in
                          // the club", which is a daily one.
                          StatRow(
                            cards: [
                              StatCard(
                                label: 'أعضاء جدد',
                                value: '${s?.newMembersThisMonth ?? 0}',
                                icon: Icons.person_add_alt_1_rounded,
                                color: GlobalColors.green,
                                sub: 'هذا الشهر',
                              ),
                              StatCard(
                                label: 'نسبة الحضور',
                                value: s?.attendanceRateMonth == null
                                    ? '—'
                                    : '${s!.attendanceRateMonth!.toStringAsFixed(0)}%',
                                icon: Icons.fact_check_rounded,
                                color: GlobalColors.blue,
                                sub: 'خلال الشهر',
                              ),
                              StatCard(
                                label: 'حصص اليوم',
                                value: '${s?.sessions ?? 0}',
                                icon: Icons.event_note_rounded,
                                color: GlobalColors.gold,
                                sub: 'مجدولة',
                              ),
                              StatCard(
                                label: 'الرياضات',
                                value:
                                    '${s?.sports ?? AppGlobals.sports.length}',
                                icon: Icons.sports_soccer_rounded,
                                color: GlobalColors.purple,
                                sub: 'في الكتالوج',
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── Two worklists, side by side ───
                          //  "Needs attention" used to span the full width,
                          //  which made a short list look like a wall and
                          //  wasted the other half of a 1280px screen. It now
                          //  shares the row with the newest members: one
                          //  column is people to chase, the other is people
                          //  to welcome, and both are things the desk can
                          //  act on rather than numbers to read.
                          if (cubit.needsAttention.isNotEmpty ||
                              cubit.newestMembers.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: cubit.needsAttention.isEmpty
                                        ? _Panel(
                                            title: 'تحتاج متابعة',
                                            icon: Icons.warning_amber_rounded,
                                            child: const _MiniEmpty(
                                              text: 'لا شيء يحتاج متابعة',
                                            ),
                                          )
                                        : _NeedsAttention(
                                            enrollments: cubit.needsAttention,
                                            // The enrolments live on the
                                            // finance page.
                                            onViewAll: () => AppCubit.get(
                                              context,
                                            ).goToPage(DestinationId.finance),
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _Panel(
                                      title: 'حصص قادمة',
                                      icon: Icons.event_note_rounded,
                                      total: cubit.todaySessions.length,
                                      onViewAll: () =>
                                          AppCubit.get(context).goToPage(DestinationId.sessions),
                                      child: cubit.todaySessions.isEmpty
                                          ? const _MiniEmpty(
                                              text: 'لا توجد حصص مجدولة',
                                            )
                                          : Column(
                                              children: cubit.todaySessions
                                                  .take(_maxRows)
                                                  .map(
                                                    (e) =>
                                                        _SessionRow(session: e),
                                                  )
                                                  .toList(),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ── Two panels ────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _Panel(
                                    title: 'أحدث الأعضاء',
                                    icon: Icons.person_add_alt_1_rounded,
                                    total: cubit.newestMembers.length,
                                    onViewAll: () =>
                                        AppCubit.get(context).goToPage(DestinationId.people),
                                    child: cubit.newestMembers.isEmpty
                                        ? const _MiniEmpty(
                                            text: 'لا يوجد أعضاء جدد',
                                          )
                                        : Column(
                                            children: cubit.newestMembers
                                                .take(_maxRows)
                                                .map(
                                                  (m) =>
                                                      _NewMemberTile(member: m),
                                                )
                                                .toList(),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _Panel(
                                    title: 'أحدث المدفوعات',
                                    icon: Icons.receipt_long_rounded,
                                    total: cubit.recentPayments.length,
                                    onViewAll: () =>
                                        AppCubit.get(context).goToPage(DestinationId.finance),
                                    child: cubit.recentPayments.isEmpty
                                        ? const _MiniEmpty(
                                            text: 'لا توجد مدفوعات بعد',
                                          )
                                        : Column(
                                            children: cubit.recentPayments
                                                .take(_maxRows)
                                                .map(
                                                  (e) =>
                                                      _PaymentRow(payment: e),
                                                )
                                                .toList(),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
}

// ─────────────────────────────────────────────
//  PANEL — لوحة جانبية
// ─────────────────────────────────────────────
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.onViewAll,
    this.total,
  });

  final String title;
  final IconData icon;
  final Widget child;

  /// Where the full list lives. Null hides the control — a "view all" that
  /// goes nowhere is worse than none.
  final VoidCallback? onViewAll;

  /// The real count, so the button can say how much is being withheld
  /// rather than just implying it.
  final int? total;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: GlobalColors.card(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: GlobalColors.accentSoft),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // Opposite the title, not under the list: it belongs with
                // the heading it qualifies, and a control at the bottom of a
                // truncated list is easy to miss.
                const Spacer(),
                if (onViewAll != null)
                  _ViewAllButton(onTap: onViewAll!, total: total),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(8), child: child),
        ],
      ),
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  const _MiniEmpty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: EmptyState(title: text, icon: Icons.inbox_rounded),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final ClubSession session;

  @override
  Widget build(BuildContext context) {
    final color = switch (session.status) {
      'ongoing' => GlobalColors.gold,
      'completed' => GlobalColors.green,
      'cancelled' => GlobalColors.red,
      _ => GlobalColors.accent,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.membershipName ?? 'حصة',
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${AppPresets.pretty(session.sessionDate)} · ${session.timeLabel}',
                  style: TextStyle(
                    color: GlobalColors.textSecondary(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            session.statusAr,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final color = switch (payment.status) {
      'success' => GlobalColors.green,
      'refunded' => GlobalColors.red,
      'pending' => GlobalColors.gold,
      _ => GlobalColors.textSecondary(context),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(Icons.attach_money_rounded, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.payerName,
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${payment.sourceName ?? '—'} · ${payment.typeAr}',
                  style: TextStyle(
                    color: GlobalColors.textSecondary(context),
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            payment.amountLabel,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  QUICK ACTIONS — إجراءات سريعة
//  The dashboard used to be read-only. These are
//  the four things the front desk actually does
//  on arriving, each one click from the landing
//  page instead of three tabs deep.
// ─────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.cubit});

  final DashboardCubit cubit;

  @override
  Widget build(BuildContext context) {
    final s = cubit.stats;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          _ActionTile(
            label: 'تسجيل عضو في اشتراك',
            hint: 'اختر العضو ثم الباقة',
            icon: Icons.person_add_alt_1_rounded,
            color: GlobalColors.accent,
            onTap: () => showMemberPicker(context),
          ),
          const SizedBox(width: 12),
          _ActionTile(
            label: 'بانتظار الدفع',
            hint: '${s?.pendingPayments ?? 0} اشتراك غير مدفوع',
            icon: Icons.hourglass_bottom_rounded,
            color: GlobalColors.gold,
            badge: s?.pendingPayments ?? 0,
            onTap: () => AppCubit.get(context).goToPage(DestinationId.finance),
          ),
          const SizedBox(width: 12),
          _ActionTile(
            label: 'اشتراكات توشك على الانتهاء',
            hint: '${s?.expiringSoon ?? 0} خلال ٧ أيام',
            icon: Icons.event_busy_rounded,
            color: GlobalColors.red,
            badge: s?.expiringSoon ?? 0,
            onTap: () => AppCubit.get(context).goToPage(DestinationId.finance),
          ),
          const SizedBox(width: 12),
          _ActionTile(
            label: 'تسجيل الحضور',
            hint: 'حصص اليوم',
            icon: Icons.how_to_reg_rounded,
            color: GlobalColors.green,
            onTap: () => AppCubit.get(context).goToPage(DestinationId.sessions),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String hint;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: GlobalColors.textPrimary(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: GlobalColors.textSecondary(context),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Only worth drawing when there is something to chase.
              if (badge != null && badge! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  NEEDS ATTENTION — تحتاج متابعة
//  Unpaid or about-to-lapse enrolments, named.
//  A count tells you there's a problem; this
//  tells you whose.
// ─────────────────────────────────────────────
/// How many rows a home-screen quick list shows before deferring to
/// "view all". Five is the point where a list still reads as a prompt to act
/// rather than as a table to work through.
const int _maxRows = 5;

class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({required this.enrollments, this.onViewAll});

  final List<Enrollment> enrollments;
  final VoidCallback? onViewAll;

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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  size: 18,
                  color: GlobalColors.gold,
                ),
                const SizedBox(width: 8),
                Text(
                  'تحتاج متابعة',
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${enrollments.length})',
                  style: TextStyle(
                    color: GlobalColors.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (onViewAll != null)
                  _ViewAllButton(onTap: onViewAll!, total: enrollments.length),
              ],
            ),
          ),
          Divider(height: 1, color: GlobalColors.border(context)),
          // Capped at five. A quick list is a prompt to act, not an
          // inventory - past about five rows it stops being scannable and
          // starts being a table, and there is a real one for that.
          ...enrollments.take(_maxRows).map((e) {
            final pending = e.status == 'pending_payment';
            final color = pending ? GlobalColors.gold : GlobalColors.red;

            return InkWell(
              // Straight to the member's profile, where both the chase and
              // the fix live.
              onTap: e.userId == null
                  ? null
                  : () => UserProfileScreen.open(
                      context,
                      e.userId!,
                      name: e.userName,
                    ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Container(width: 3, height: 28, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Text(
                        e.memberName,
                        style: TextStyle(
                          color: GlobalColors.textPrimary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        e.membershipName ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: GlobalColors.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        pending ? 'بانتظار الدفع' : 'ينتهي ${e.endDate ?? ''}',
                        style: TextStyle(
                          color: color,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: GlobalColors.textSecondary(context),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MEMBER PICKER — اختيار العضو
//  Enrolling starts with "who". Rather than
//  duplicate the enrol form here, this picks the
//  member and hands off to their profile, where
//  the enrol dialog already lives and where the
//  desk can see what they're already on before
//  adding another.
// ─────────────────────────────────────────────
void showMemberPicker(BuildContext context) {
  final search = TextEditingController();

  showDialog(
    context: context,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (sctx, setLocal) {
          final q = search.text.trim();
          final members = AppGlobals.members.where((m) {
            if (q.isEmpty) return true;
            return (m.name ?? '').contains(q) ||
                (m.phone ?? '').contains(q) ||
                (m.email ?? '').contains(q);
          }).toList();

          return AlertDialog(
            backgroundColor: GlobalColors.card(sctx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.person_search_rounded,
                  color: GlobalColors.accentSoft,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'اختر العضو',
                  style: TextStyle(
                    color: GlobalColors.textPrimary(sctx),
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              height: 420,
              child: Column(
                children: [
                  SearchField(
                    controller: search,
                    hint: 'ابحث بالاسم أو الجوال...',
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: members.isEmpty
                        ? const EmptyState(title: 'لا يوجد أعضاء مطابقون')
                        : ListView.builder(
                            itemCount: members.length,
                            itemBuilder: (_, i) {
                              final m = members[i];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: GlobalColors.accent
                                      .withValues(alpha: 0.15),
                                  child: Text(
                                    (m.name ?? '?').characters
                                        .take(1)
                                        .toString(),
                                    style: TextStyle(
                                      color: GlobalColors.accentSoft,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  m.name ?? '—',
                                  style: TextStyle(
                                    color: GlobalColors.textPrimary(sctx),
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  m.phone ?? m.email ?? '',
                                  style: TextStyle(
                                    color: GlobalColors.textSecondary(sctx),
                                    fontSize: 11,
                                  ),
                                ),
                                onTap: m.userId == null
                                    ? null
                                    : () {
                                        Navigator.pop(sctx);
                                        UserProfileScreen.open(
                                          context,
                                          m.userId!,
                                          name: m.name,
                                          // Came here to enrol — go straight
                                          // to the form.
                                          autoEnroll: true,
                                        );
                                      },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  NEW MEMBER TILE — عضو جديد
//  Deliberately flags the ones with no
//  subscription: a member who signed up and never
//  bought anything is the clearest follow-up on
//  the screen, and the whole point of putting this
//  list next to "needs attention".
// ─────────────────────────────────────────────
class _NewMemberTile extends StatelessWidget {
  const _NewMemberTile({required this.member});

  final NewMemberRow member;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: GlobalColors.accent.withValues(alpha: 0.15),
            foregroundImage: (member.avatarUrl ?? '').isEmpty
                ? null
                : NetworkImage(member.avatarUrl!),
            child: Text(
              member.initial,
              style: TextStyle(
                color: GlobalColors.accentSoft,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member.name ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: GlobalColors.textPrimary(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  member.phone ?? member.email ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: GlobalColors.textSecondary(context),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          if (!member.hasSubscription)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: GlobalColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: GlobalColors.gold.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'بلا اشتراك',
                style: TextStyle(color: GlobalColors.gold, fontSize: 10),
              ),
            )
          else
            Text(
              member.joinedAt ?? '',
              style: TextStyle(
                color: GlobalColors.textSecondary(context),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────
//  VIEW ALL — عرض الكل
//
//  Sits opposite a quick list's title. Says how
//  many rows there are so the truncation is
//  visible rather than implied — "عرض الكل (12)"
//  tells you something is being withheld; a bare
//  "عرض الكل" leaves you guessing whether the five
//  on screen are all of them.
// ─────────────────────────────────────────────
class _ViewAllButton extends StatefulWidget {
  const _ViewAllButton({required this.onTap, this.total});

  final VoidCallback onTap;
  final int? total;

  @override
  State<_ViewAllButton> createState() => _ViewAllButtonState();
}

class _ViewAllButtonState extends State<_ViewAllButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final more = (widget.total ?? 0) > _maxRows;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered
                ? GlobalColors.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? GlobalColors.accent.withValues(alpha: 0.4)
                  : GlobalColors.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                more ? 'عرض الكل (${widget.total})' : 'عرض الكل',
                style: TextStyle(
                  color: _hovered
                      ? GlobalColors.accentSoft
                      : GlobalColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_back_rounded,
                size: 13,
                color: _hovered
                    ? GlobalColors.accentSoft
                    : GlobalColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
