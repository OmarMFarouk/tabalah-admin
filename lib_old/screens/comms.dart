import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/comms_bloc/comms_cubit.dart';
import '../components/general/app_dialog.dart';
import '../components/general/app_field.dart';
import '../components/general/app_table.dart';
import '../components/general/page_header.dart';
import '../components/general/snackbar.dart';
import '../components/general/stat_card.dart';
import '../models/paginated_model.dart';
import '../models/performance_model.dart';
import '../models/users_model.dart';
import '../src/app_colors.dart';
import '../src/app_globals.dart';
import '../src/app_presets.dart';

// ─────────────────────────────────────────────
//  COMMS — المراسلات
//  Split by blast radius: a one-off email is
//  open to all staff, a newsletter is admin-only.
// ─────────────────────────────────────────────
class CommsScreen extends StatelessWidget {
  const CommsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CommsCubit()..fetch(),
      child: const _CommsView(),
    );
  }
}

class _CommsView extends StatelessWidget {
  const _CommsView();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: GlobalColors.bg(context),
        body: BlocConsumer<CommsCubit, AppStates>(
          listener: (ctx, state) {
            if (state is AppSuccess) {
              MySnackBar.show(ctx, text: state.msg, isSuccess: true);
            }
            if (state is AppFailure) {
              MySnackBar.show(ctx, text: state.msg, isSuccess: false);
            }
          },
          builder: (ctx, state) {
            final c = CommsCubit.get(ctx);
            final loading = state is AppLoading;
            final canBlast = AppGlobals.currentUser?.isAdmin ?? false;

            return Column(
              children: [
                PageHeader(
                  title: 'المراسلات',
                  icon: Icons.campaign_rounded,
                  isLoading: loading,
                  onRefresh: c.fetch,
                  tabs: CommsTab.values
                      .map(
                        (t) => TabPill(
                          label: t.label,
                          icon: t.icon,
                          isActive: c.tab == t,
                          onTap: () => c.switchTab(t),
                        ),
                      )
                      .toList(),
                  actions: [
                    // One member — any staff member may send this.
                    HeaderButton(
                      icon: Icons.mail_rounded,
                      label: 'رسالة لعضو',
                      color: GlobalColors.blue,
                      onTap: () => _customForm(ctx, c),
                    ),
                    if (canBlast)
                      HeaderButton(
                        icon: Icons.campaign_rounded,
                        label: 'إرسال نشرة',
                        color: GlobalColors.green,
                        filled: true,
                        onTap: () => _newsletterForm(ctx, c),
                      ),
                  ],
                ),

                StatRow(
                  cards: [
                    StatCard(
                      label: 'الرسائل',
                      value: '${c.emails.total}',
                      icon: Icons.mark_email_read_rounded,
                      color: GlobalColors.accent,
                      sub: 'في السجل',
                    ),
                    StatCard(
                      label: 'النشرات',
                      value: '${c.newsletters.total}',
                      icon: Icons.campaign_rounded,
                      color: GlobalColors.purple,
                      sub: 'إرسال جماعي',
                    ),
                    StatCard(
                      label: 'إجمالي المستلمين',
                      value:
                          '${c.newsletters.items.fold<int>(0, (s, n) => s + (n.recipientsCount ?? 0))}',
                      icon: Icons.groups_rounded,
                      color: GlobalColors.green,
                      sub: 'ضمن الصفحة الحالية',
                    ),
                    StatCard(
                      label: 'الأعضاء',
                      value: '${AppGlobals.members.length}',
                      icon: Icons.people_alt_rounded,
                      color: GlobalColors.gold,
                      sub: 'جمهور محتمل',
                    ),
                  ],
                ),

                if (c.tab == CommsTab.emails)
                  Toolbar(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SearchField(
                          controller: c.searchCont,
                          hint: 'ابحث في الموضوع أو المستلم... (Enter)',
                          onChanged: (_) => c.fetch(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ...['', 'custom', 'welcome', 'newsletter'].map(
                        (t) => AppFilterChip(
                          label: switch (t) {
                            '' => 'الكل',
                            'custom' => 'مخصصة',
                            'welcome' => 'ترحيب',
                            _ => 'نشرة',
                          },
                          isActive: c.typeFilter == (t.isEmpty ? null : t),
                          onTap: () => c.setFilter(type: t),
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(height: 14),

                Expanded(child: _table(ctx, c, loading)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _table(BuildContext ctx, CommsCubit c, bool loading) {
    if (c.tab == CommsTab.emails) {
      return AppTable<EmailLog>(
        isLoading: loading,
        data: c.emails,
        onPage: c.setPage,
        unitLabel: 'رسالة',
        emptyTitle: 'لا توجد رسائل',
        emptyHint: 'يسجّل النظام كل رسالة تلقائية أو يدوية',
        emptyIcon: Icons.mail_outline_rounded,
        columns: const [
          AppColumn('المستلم', flex: 3),
          AppColumn('الموضوع', flex: 4),
          AppColumn('النوع'),
          AppColumn('التاريخ', flex: 2),
          AppColumn('الحالة'),
        ],
        rowBuilder: (rc, e, i) => AppRow(
          index: i,
          cells: [
            avatarCell(rc, e.toName, flex: 3, sub: e.recipientEmail),
            textCell(rc, e.subject ?? '—', flex: 4, weight: FontWeight.w600),
            StatusBadge(
              label: e.type ?? '—',
              color: GlobalColors.blue,
            ),
            textCell(rc, AppPresets.pretty(e.sentAt), flex: 2, size: 11),
            // The log stores delivery metadata, not the message body —
            // so surface the outcome instead of a preview.
            StatusBadge(
              label: e.failed ? 'فشل' : (e.status ?? 'أُرسلت'),
              color: e.failed ? GlobalColors.red : GlobalColors.green,
              flex: 1,
            ),
          ],
        ),
      );
    }

    return AppTable<Newsletter>(
      isLoading: loading,
      data: c.newsletters,
      onPage: c.setPage,
      unitLabel: 'نشرة',
      emptyTitle: 'لا توجد نشرات',
      emptyHint: 'اضغط "إرسال نشرة" لمخاطبة مجموعة',
      emptyIcon: Icons.campaign_rounded,
      columns: const [
        AppColumn('الموضوع', flex: 4),
        AppColumn('الجمهور', flex: 2),
        AppColumn('المستلمون'),
        AppColumn('التاريخ', flex: 2),
        AppColumn('عرض'),
      ],
      rowBuilder: (rc, n, i) => AppRow(
        index: i,
        cells: [
          avatarCell(rc, n.subject ?? '—', flex: 4),
          StatusBadge(label: n.audienceAr, color: GlobalColors.purple, flex: 2),
          textCell(
            rc,
            '${n.recipientsCount ?? 0}',
            color: GlobalColors.green,
            weight: FontWeight.w700,
          ),
          textCell(rc, AppPresets.pretty(n.sentAt), flex: 2, size: 11),
          actionsCell([
            ActionBtn(
              icon: Icons.visibility_rounded,
              color: GlobalColors.accentSoft,
              tooltip: 'عرض النص',
              onTap: () => _preview(ctx, n.subject ?? '', n.body ?? ''),
            ),
          ], flex: 1),
        ],
      ),
    );
  }

  void _preview(BuildContext ctx, String subject, String body) {
    showDialog(
      context: ctx,
      builder: (dctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: GlobalColors.card(dctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            subject,
            style: TextStyle(
              color: GlobalColors.textPrimary(dctx),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Text(
                body.isEmpty ? 'لا يوجد نص محفوظ.' : body,
                style: TextStyle(
                  color: GlobalColors.textSecondary(dctx),
                  fontSize: 13,
                  height: 1.8,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: Text(
                'إغلاق',
                style: TextStyle(color: GlobalColors.accentSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── One member ──────────────────────────────
  void _customForm(BuildContext ctx, CommsCubit c) {
    c.clearForm();
    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) => AppDialog<CommsCubit>(
            title: 'رسالة إلى عضو',
            icon: Icons.mail_rounded,
            saveLabel: 'إرسال',
            width: 560,
            onSave: c.sendCustom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDropdown<User>(
                  value: pickWhere(AppGlobals.members, (u) => u.userId == c.formUserId),
                  items: AppGlobals.members,
                  labelOf: (u) => '${u.name} · ${u.email ?? ''}',
                  label: 'المستلم *',
                  icon: Icons.person_rounded,
                  onChanged: (u) => setLocal(() => c.formUserId = u?.userId),
                ),
                gap,
                AppField(
                  controller: c.subjectCont,
                  label: 'الموضوع *',
                  icon: Icons.subject_rounded,
                ),
                gap,
                AppField(
                  controller: c.bodyCont,
                  label: 'نص الرسالة *',
                  icon: Icons.article_rounded,
                  maxLines: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mass mail ───────────────────────────────
  void _newsletterForm(BuildContext ctx, CommsCubit c) {
    c.clearForm();
    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) => AppDialog<CommsCubit>(
            title: 'إرسال نشرة',
            icon: Icons.campaign_rounded,
            saveLabel: 'إرسال للجميع',
            width: 580,
            onSave: c.sendNewsletter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GlobalColors.gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: GlobalColors.gold,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'إرسال جماعي — راجع النص قبل الإرسال، فلا يمكن التراجع.',
                          style: TextStyle(
                            color: GlobalColors.textSecondary(sctx),
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                gap,
                AppDropdown<String>(
                  value: c.formAudience,
                  items: Newsletter.audiences,
                  labelOf: Newsletter.audienceLabel,
                  label: 'الجمهور *',
                  icon: Icons.groups_rounded,
                  onChanged: (a) =>
                      setLocal(() => c.formAudience = a ?? 'players'),
                ),

                // A custom audience must name its recipients.
                if (c.formAudience == 'custom') ...[
                  gap,
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: GlobalColors.surface(sctx),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GlobalColors.border(sctx)),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(4),
                      children: AppGlobals.members.map((u) {
                        final on = c.customIds.contains(u.userId);
                        return CheckboxListTile(
                          dense: true,
                          value: on,
                          activeColor: GlobalColors.accent,
                          title: Text(
                            u.name ?? '—',
                            style: TextStyle(
                              color: GlobalColors.textPrimary(sctx),
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Text(
                            u.email ?? '',
                            style: TextStyle(
                              color: GlobalColors.textSecondary(sctx),
                              fontSize: 10,
                            ),
                          ),
                          onChanged: (_) => setLocal(
                            () => c.toggleCustomId(u.userId!),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'تم اختيار ${c.customIds.length} مستلم',
                      style: TextStyle(
                        color: GlobalColors.accentSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                gap,
                AppField(
                  controller: c.subjectCont,
                  label: 'الموضوع *',
                  icon: Icons.subject_rounded,
                ),
                gap,
                AppField(
                  controller: c.bodyCont,
                  label: 'نص النشرة *',
                  icon: Icons.article_rounded,
                  maxLines: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
