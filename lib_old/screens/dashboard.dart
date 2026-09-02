import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/dashboard_bloc/dashboard_cubit.dart';
import '../components/general/empty_widget.dart';
import '../components/general/page_header.dart';
import '../components/general/stat_card.dart';
import '../models/finance_model.dart';
import '../models/sessions_model.dart';
import '../src/app_colors.dart';
import '../src/app_globals.dart';
import '../src/app_presets.dart';

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
                        StatRow(
                          cards: [
                            StatCard(
                              label: 'المحصّل',
                              value:
                                  '${cubit.totals.collected.toStringAsFixed(0)} ${AppGlobals.currency}',
                              icon: Icons.payments_rounded,
                              color: GlobalColors.green,
                              sub: 'إجمالي المدفوعات',
                            ),
                            StatCard(
                              label: 'المعلّق',
                              value:
                                  '${cubit.totals.pending.toStringAsFixed(0)} ${AppGlobals.currency}',
                              icon: Icons.hourglass_bottom_rounded,
                              color: GlobalColors.gold,
                              sub: 'بانتظار التسوية',
                            ),
                            StatCard(
                              label: 'المسترد',
                              value:
                                  '${cubit.totals.refunded.toStringAsFixed(0)} ${AppGlobals.currency}',
                              icon: Icons.undo_rounded,
                              color: GlobalColors.red,
                              sub: 'مبالغ مردودة',
                            ),
                            StatCard(
                              label: 'الرياضات',
                              value: '${s?.sports ?? AppGlobals.sports.length}',
                              icon: Icons.sports_soccer_rounded,
                              color: GlobalColors.purple,
                              sub: 'في الكتالوج',
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Two panels ────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _Panel(
                                  title: 'حصص قادمة',
                                  icon: Icons.event_note_rounded,
                                  child: cubit.todaySessions.isEmpty
                                      ? const _MiniEmpty(
                                          text: 'لا توجد حصص مجدولة',
                                        )
                                      : Column(
                                          children: cubit.todaySessions
                                              .take(6)
                                              .map(
                                                (e) => _SessionRow(session: e),
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
                                  child: cubit.recentPayments.isEmpty
                                      ? const _MiniEmpty(
                                          text: 'لا توجد مدفوعات بعد',
                                        )
                                      : Column(
                                          children: cubit.recentPayments
                                              .take(6)
                                              .map(
                                                (e) => _PaymentRow(payment: e),
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
    );
  }
}

// ─────────────────────────────────────────────
//  PANEL — لوحة جانبية
// ─────────────────────────────────────────────
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

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
            backgroundColor: color.withOpacity(0.14),
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
