import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/catalog_model.dart';
import '../../models/finance_model.dart';
import '../../models/paginated_model.dart';
import '../../services/apis/finance_api.dart';
import '../../src/app_globals.dart';
import '../../src/app_presets.dart';
import '../base_states.dart';

// ─────────────────────────────────────────────
//  FINANCE TABS — تبويبات المالية
//  Taking money, the ways of taking it, and the
//  sign-up it pays for — one desk workflow.
// ─────────────────────────────────────────────
enum FinanceTab { payments, sources, enrollments }

extension FinanceTabX on FinanceTab {
  String get label => switch (this) {
    FinanceTab.payments => 'المدفوعات',
    FinanceTab.sources => 'وسائل الدفع',
    FinanceTab.enrollments => 'التسجيلات',
  };

  IconData get icon => switch (this) {
    FinanceTab.payments => Icons.payments_rounded,
    FinanceTab.sources => Icons.account_balance_wallet_rounded,
    FinanceTab.enrollments => Icons.assignment_turned_in_rounded,
  };
}

class FinanceCubit extends Cubit<AppStates> {
  FinanceCubit() : super(AppInitial());
  static FinanceCubit get(context) => BlocProvider.of(context);

  final FinanceApi _api = FinanceApi();

  FinanceTab tab = FinanceTab.payments;
  int page = 1;

  // Filters — الفلاتر
  final referenceCont = TextEditingController();
  final searchCont = TextEditingController();
  String? statusFilter;
  String? typeFilter;
  int? memberFilter;
  int? sourceFilter;
  int? membershipFilter;
  String? fromFilter;
  String? toFilter;
  bool? activeFilter;
  String? kindFilter;

  // Data — البيانات
  Paginated<Payment> payments = Paginated(items: []);
  PaymentTotals totals = PaymentTotals();
  Paginated<PaymentSource> sources = Paginated(items: []);
  Paginated<Enrollment> enrollments = Paginated(items: []);

  // ── Form controllers — حقول النموذج ─────────
  final amountCont = TextEditingController();
  final notesCont = TextEditingController();
  final nameCont = TextEditingController();
  // English rendering of the payment method, shown to members who run the
  // app in English. Optional — blank falls back to the Arabic name.
  final nameEnCont = TextEditingController();
  final codeCont = TextEditingController();
  final descCont = TextEditingController();
  final descEnCont = TextEditingController();
  final sortOrderCont = TextEditingController();
  int? formUserId;
  int? formSourceId;
  int? formEnrollmentId;
  int? formMembershipId;
  String formStatus = 'success';
  String formType = 'enrollment';
  String formKind = 'offline';
  bool formActive = true;
  bool formDefault = false;
  String formStart = AppPresets.today;
  String formEnd = AppPresets.nextMonth;

  void clearForm() {
    for (final c in [
      amountCont,
      notesCont,
      nameCont,
      nameEnCont,
      codeCont,
      descCont,
      descEnCont,
      sortOrderCont,
    ]) {
      c.clear();
    }
    formUserId = null;
    formSourceId = defaultSourceId;
    formEnrollmentId = null;
    formMembershipId = null;
    formStatus = 'success';
    formType = 'enrollment';
    formKind = 'offline';
    formActive = true;
    formDefault = false;
    formStart = AppPresets.today;
    formEnd = AppPresets.nextMonth;
  }

  // A payment falls back to the default source when none is named.
  int? get defaultSourceId {
    final list = sources.items.isNotEmpty
        ? sources.items
        : AppGlobals.paymentSources;
    for (final s in list) {
      if (s.isDefault) return s.id;
    }
    return list.isNotEmpty ? list.first.id : null;
  }

  List<PaymentSource> get activeSources {
    final list = sources.items.isNotEmpty
        ? sources.items
        : AppGlobals.paymentSources;
    return list.where((s) => s.isActive).toList();
  }

  void switchTab(FinanceTab t) {
    tab = t;
    page = 1;
    emit(AppInitial());
    fetch();
  }

  void setPage(int p) {
    page = p;
    fetch();
  }

  void setFilter({
    String? status,
    String? type,
    int? member,
    int? source,
    int? membership,
    String? from,
    String? to,
    bool? active,
    String? kind,
    bool clearDates = false,
  }) {
    if (status != null) statusFilter = status == '' ? null : status;
    if (type != null) typeFilter = type == '' ? null : type;
    if (member != null) memberFilter = member == -1 ? null : member;
    if (source != null) sourceFilter = source == -1 ? null : source;
    if (membership != null) {
      membershipFilter = membership == -1 ? null : membership;
    }
    if (kind != null) kindFilter = kind == '' ? null : kind;
    activeFilter = active;
    if (clearDates) {
      fromFilter = null;
      toFilter = null;
    } else {
      if (from != null) fromFilter = from;
      if (to != null) toFilter = to;
    }
    page = 1;
    fetch();
  }


  Paginated get _active => switch (tab) {
    FinanceTab.payments => payments,
    FinanceTab.sources => sources,
    FinanceTab.enrollments => enrollments,
  };

  // ── SEARCH — البحث ──────────────────────────
  //  A new query is a NEW result set. Page 3 of the old one is meaningless
  //  against it and the server rightly answers with nothing, which reads on
  //  screen as "no results" when there may be plenty on page 1. So every
  //  search starts from the first page; the pager takes over from there.
  void search() {
    page = 1;
    fetch();
  }

  Future<void> fetch() async {
    emit(AppLoading());

    switch (tab) {
      case FinanceTab.payments:
        final r = await _api.fetchPayments(
          status: statusFilter,
          userId: memberFilter,
          sourceId: sourceFilter,
          type: typeFilter,
          from: fromFilter,
          to: toFilter,
          reference: referenceCont.text.trim().isEmpty
              ? null
              : referenceCont.text.trim(),
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        payments = Paginated.read<Payment>(r.body, 'payments', Payment.fromJson);
        // Totals cover the whole filtered set, not just this page.
        totals = PaymentTotals.fromJson(r['totals']);
        break;

      case FinanceTab.sources:
        final r = await _api.fetchSources(
          isActive: activeFilter,
          kind: kindFilter,
          q: searchCont.text.trim(),
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        sources = Paginated.read<PaymentSource>(
          r.body,
          'payment_sources',
          PaymentSource.fromJson,
        );
        AppGlobals.paymentSources = sources.items;
        break;

      case FinanceTab.enrollments:
        final r = await _api.fetchEnrollments(
          userId: memberFilter,
          membershipId: membershipFilter,
          page: page,
        );
        if (!r.success) return emit(AppFailure(msg: r.message));
        enrollments = Paginated.read<Enrollment>(
          r.body,
          'enrollments',
          Enrollment.fromJson,
        );
        break;
    }
    // The page we asked for fell off the end of the result set — a narrower
    // search, a tighter filter, or a deletion. Land on page 1 rather than
    // showing an empty table over a non-zero total.
    if (_active.isOrphanedPage) {
      page = 1;
      return fetch();
    }
    emit(AppLoaded());
  }

  // Keeps the source list warm for the payment dialog's dropdown.
  Future<void> refreshSources() async {
    final r = await _api.fetchSources(perPage: 100);
    if (r.success) {
      AppGlobals.paymentSources = Paginated.parse<PaymentSource>(
        r['payment_sources'],
        PaymentSource.fromJson,
      ).items;
      emit(AppLoaded());
    }
  }

  // ── Payments — المدفوعات ────────────────────
  Future<void> recordPayment() => _write(
    () => _api.recordPayment(
      Payment(
        userId: formUserId,
        paymentSourceId: formSourceId,
        enrollmentId: formEnrollmentId,
        amount: double.tryParse(amountCont.text) ?? 0,
        currency: 'SAR',
        status: formStatus,
        type: formType,
        notes: notesCont.text.trim().isEmpty ? null : notesCont.text.trim(),
      ).toJson(),
    ),
    'تم تسجيل الدفعة.',
  );

  // Bookkeeping only — amount and payer stay as recorded.
  Future<void> correctPayment(int id) => _write(
    () => _api.correctPayment(id, {
      if (formSourceId != null) 'payment_source_id': formSourceId,
      'notes': notesCont.text.trim(),
    }),
    'تم تصحيح بيانات الدفعة.',
  );

  // Refunding also cancels the linked enrollment.
  Future<void> changeStatus(int id, String status) => _write(
    () => _api.changeStatus(
      id,
      status: status,
      notes: notesCont.text.trim().isEmpty ? null : notesCont.text.trim(),
    ),
    status == 'refunded' ? 'تم رد الدفعة.' : 'تم تحديث حالة الدفعة.',
  );

  // ── Payment sources — وسائل الدفع ───────────
  Future<void> saveSource({int? id}) {
    final data = PaymentSource(
      name: nameCont.text.trim(),
      nameEn: nameEnCont.text.trim(),
      code: codeCont.text.trim().isEmpty ? null : codeCont.text.trim(),
      description: descCont.text.trim(),
      descriptionEn: descEnCont.text.trim(),
      kind: formKind,
      isActive: formActive,
      isDefault: formDefault,
      sortOrder: int.tryParse(sortOrderCont.text),
    ).toJson();

    return _write(
      () => id == null ? _api.createSource(data) : _api.updateSource(id, data),
      id == null ? 'تمت إضافة وسيلة الدفع.' : 'تم حفظ التعديل.',
    );
  }

  // The intended way to retire a method — history stays intact.
  Future<void> toggleSource(PaymentSource s) => _write(
    () => _api.updateSource(s.id, {'is_active': !s.isActive}),
    s.isActive ? 'تم تعطيل الوسيلة.' : 'تم تفعيل الوسيلة.',
  );

  Future<void> deleteSource(int id) =>
      _write(() => _api.deleteSource(id), 'تم حذف وسيلة الدفع.');

  // ── Enrollments — التسجيلات ─────────────────
  Future<void> saveEnrollment({int? id}) {
    final data = Enrollment(
      userId: formUserId,
      membershipId: formMembershipId,
      startDate: formStart,
      endDate: formEnd,
    ).toJson();

    return _write(
      () => id == null
          ? _api.createEnrollment(data)
          : _api.updateEnrollment(id, {
              'start_date': formStart,
              'end_date': formEnd,
            }),
      id == null ? 'تم تسجيل العضو.' : 'تم تعديل التسجيل.',
    );
  }

  Future<void> deleteEnrollment(int id) =>
      _write(() => _api.deleteEnrollment(id), 'تم حذف التسجيل.');

  Future<void> _write(Future Function() call, String okMsg) async {
    emit(AppBusy());
    final r = await call();
    if (r.success) {
      emit(AppSuccess(msg: okMsg));
      await fetch();
    } else {
      emit(AppFailure(msg: r.message));
    }
  }
}
