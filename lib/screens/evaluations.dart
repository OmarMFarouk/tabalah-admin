import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/base_states.dart';
import '../blocs/hr_bloc/evaluations_cubit.dart';
import '../components/general/app_dialog.dart';
import '../components/general/app_field.dart';
import '../components/general/app_table.dart';
import '../components/general/page_header.dart';
import '../components/general/snackbar.dart';
import '../components/general/star_rating.dart';
import '../components/general/stat_card.dart';
import '../models/paginated_model.dart';
import '../models/sessions_model.dart';
import '../models/users_model.dart';
import '../src/app_colors.dart';
import '../src/app_globals.dart';
import '../src/app_permissions.dart';
import 'profile.dart';

// ─────────────────────────────────────────────
//  EVALUATIONS — التقييمات
// ─────────────────────────────────────────────

class EvaluationsScreen extends StatelessWidget {
  const EvaluationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EvaluationsCubit()..fetch(),
      child: const _EvaluationsView(),
    );
  }
}

class _EvaluationsView extends StatelessWidget {
  const _EvaluationsView();

  static List<User> _poolFor(String role) => switch (role) {
    'player' => AppGlobals.members,
    'trainer' => AppGlobals.trainers
        .map((t) => User(userId: t.userId, name: t.name, email: t.email, role: 'trainer'))
        .toList(),
    _ => AppGlobals.staff,
  };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SelectionArea(
        child: Scaffold(
          backgroundColor: GlobalColors.bg(context),
          body: BlocConsumer<EvaluationsCubit, AppStates>(
            listener: (ctx, state) {
              if (state is AppSuccess) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: true);
              }
              if (state is AppFailure) {
                MySnackBar.show(ctx, text: state.msg, isSuccess: false);
              }
            },
            builder: (ctx, state) {
              final c = EvaluationsCubit.get(ctx);
              final loading = state is AppLoading;
              final canWrite = Permissions.canManageEvaluations;
              final low = c.rows.items.where((r) => r.stars < 3).length;

              return Column(
                children: [
                  PageHeader(
                    title: 'التقييمات',
                    icon: Icons.star_rate_rounded,
                    isLoading: loading,
                    onRefresh: c.fetch,
                    tabs: EvaluationTab.values
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
                      if (canWrite)
                        HeaderButton(
                          icon: Icons.add_rounded,
                          label: 'تقييم جديد',
                          color: GlobalColors.green,
                          filled: true,
                          onTap: () => _openForm(ctx, c),
                        ),
                    ],
                  ),
                  StatRow(
                    cards: [
                      StatCard(
                        label: 'متوسط التقييم',
                        value: c.average == null ? '—' : c.average!.toStringAsFixed(2),
                        icon: Icons.star_rounded,
                        color: GlobalColors.gold,
                        sub: 'من 5 — ضمن الفلتر',
                      ),
                      StatCard(
                        label: 'عدد التقييمات',
                        value: '${c.rows.total}',
                        icon: Icons.reviews_rounded,
                        color: GlobalColors.accent,
                        sub: c.tab.label,
                      ),
                      StatCard(
                        label: 'تحتاج متابعة',
                        value: '$low',
                        icon: Icons.flag_rounded,
                        color: GlobalColors.red,
                        sub: 'أقل من 3 — في الصفحة الحالية',
                      ),
                    ],
                  ),
                  Toolbar(
                    children: [
                      Expanded(
                        child: SearchField(
                          controller: c.searchCont,
                          hint: 'ابحث باسم من تم تقييمه... (اضغط Enter)',
                          onChanged: (_) => c.search(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 170,
                        child: DateField(
                          value: c.from,
                          label: 'من تاريخ',
                          onPicked: (v) => c.setDates(from: v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 170,
                        child: DateField(
                          value: c.to,
                          label: 'إلى تاريخ',
                          onPicked: (v) => c.setDates(to: v),
                        ),
                      ),
                      if (c.from != null || c.to != null) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: c.clearDates,
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          label: const Text('مسح التاريخ'),
                        ),
                      ],
                    ],
                  ),
                  Expanded(
                    child: AppTable<SessionRating>(
                      isLoading: loading,
                      data: c.rows,
                      onPage: c.setPage,
                      unitLabel: 'تقييم',
                      emptyTitle: 'لا توجد تقييمات',
                      emptyHint: 'يقيّم المدربون اللاعبين بعد كل حصة من التطبيق',
                      emptyIcon: Icons.star_outline_rounded,
                      columns: const [
                        AppColumn('من تم تقييمه', flex: 3),
                        AppColumn('التقييم', flex: 2),
                        AppColumn('الحصة', flex: 3),
                        AppColumn('المُقيِّم', flex: 2),
                        AppColumn('الملاحظة', flex: 4),
                        AppColumn('التاريخ', flex: 2),
                        AppColumn('إجراءات'),
                      ],
                      rowBuilder: (rc, r, i) => AppRow(
                        index: i,
                        onTap: r.userId == null
                            ? null
                            : () => UserProfileScreen.open(rc, r.userId!, name: r.rateeName),
                        cells: [
                          avatarCell(
                            rc,
                            r.rateeName ?? '—',
                            flex: 3,
                            sub: User(role: r.rateeRole).roleAr,
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(child: StarRating(value: r.stars, size: 14)),
                          ),
                          textCell(
                            rc,
                            r.isGeneral ? 'تقييم عام' : (r.membershipName ?? '—'),
                            flex: 3,
                            size: 11,
                            color: r.isGeneral ? GlobalColors.accentSoft : null,
                            sub: r.sessionDate,
                          ),
                          textCell(
                            rc,
                            r.raterName ?? '—',
                            flex: 2,
                            size: 11,
                            sub: User(role: r.raterRole).roleAr,
                          ),
                          textCell(rc, r.note ?? '—', flex: 4, size: 11),
                          textCell(rc, r.createdAt ?? '—', flex: 2, size: 10.5),
                          actionsCell([
                            ActionBtn(
                              icon: Icons.edit_rounded,
                              color: GlobalColors.accentSoft,
                              tooltip: 'تعديل',
                              enabled: canWrite,
                              onTap: () => _openForm(ctx, c, rating: r),
                            ),
                            ActionBtn(
                              icon: Icons.delete_rounded,
                              color: GlobalColors.red,
                              tooltip: 'حذف',
                              enabled: canWrite,
                              onTap: () => showConfirm(
                                ctx,
                                title: 'حذف التقييم',
                                message: 'سيُحذف تقييم ${r.rateeName ?? ''} نهائياً.',
                                onConfirm: () => c.delete(r.id!),
                              ),
                            ),
                          ]),
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

  void _openForm(BuildContext ctx, EvaluationsCubit c, {SessionRating? rating}) {
    c.fillForm(rating);

    showDialog(
      context: ctx,
      builder: (_) => BlocProvider.value(
        value: c,
        child: StatefulBuilder(
          builder: (sctx, setLocal) {
            final pool = _poolFor(c.formRole);
            return AppDialog<EvaluationsCubit>(
              title: rating == null ? 'تقييم جديد' : 'تعديل التقييم',
              icon: Icons.star_rate_rounded,
              saveLabel: rating == null ? 'حفظ التقييم' : 'حفظ',
              width: 520,
              onSave: () => c.save(id: rating?.id),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rating == null) ...[
                    dialogRow([
                      AppDropdown<String>(
                        value: c.formRole,
                        items: const ['staff', 'trainer', 'player'],
                        labelOf: (r) => switch (r) {
                          'player' => 'عضو',
                          'trainer' => 'مدرب',
                          _ => 'موظف',
                        },
                        label: 'نوع الشخص',
                        icon: Icons.category_rounded,
                        onChanged: (v) => setLocal(() {
                          c.formRole = v ?? 'staff';
                          c.formUserId = null;
                        }),
                      ),
                      AppDropdown<User>(
                        value: pickWhere(pool, (u) => u.userId == c.formUserId),
                        items: pool,
                        labelOf: (u) => u.name ?? '—',
                        label: 'الشخص *',
                        icon: Icons.person_rounded,
                        onChanged: (u) => setLocal(() => c.formUserId = u?.userId),
                      ),
                    ]),
                    gap,
                  ] else ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${rating.rateeName ?? '—'}${rating.isGeneral ? '' : ' · ${rating.membershipName ?? ''}'}',
                        style: TextStyle(
                          color: GlobalColors.textPrimary(sctx),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    gap,
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: GlobalColors.surface(sctx),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: GlobalColors.border(sctx)),
                    ),
                    child: Column(
                      children: [
                        StarRating(value: c.formRating, size: 30),
                        Slider(
                          value: c.formRating,
                          min: 0.5,
                          max: 5,
                          divisions: 9,
                          activeColor: GlobalColors.gold,
                          label: c.formRating.toStringAsFixed(1),
                          onChanged: (v) => setLocal(() => c.formRating = v),
                        ),
                      ],
                    ),
                  ),
                  gap,
                  AppField(
                    controller: c.noteCont,
                    label: 'الملاحظة',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                    hint: 'ما الذي أحسن فيه، وما الذي يحتاج إلى تطوير؟',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
