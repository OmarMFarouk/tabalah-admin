import 'paginated_model.dart';

// ─────────────────────────────────────────────
//  PAYMENT SOURCE — وسيلة الدفع
//  kind: offline (desk only) | online (checkout)
//  Retire a method with is_active=false rather
//  than deleting — history stays attributable.
// ─────────────────────────────────────────────
class PaymentSource {
  int? id;
  String? name;
  String? code;
  String? description;
  String? kind;
  bool isActive;
  bool isDefault;
  int? sortOrder;
  int? paymentsCount;

  PaymentSource({
    this.id,
    this.name,
    this.code,
    this.description,
    this.kind,
    this.isActive = true,
    this.isDefault = false,
    this.sortOrder,
    this.paymentsCount,
  });

  factory PaymentSource.fromJson(Map<String, dynamic> json) => PaymentSource(
    id: asInt(json['id']),
    name: asString(json['name']),
    code: asString(json['code']),
    description: asString(json['description']),
    kind: asString(json['kind']),
    isActive: asBool(json['is_active']),
    isDefault: asBool(json['is_default']),
    sortOrder: asInt(json['sort_order']),
    paymentsCount: asInt(json['payments_count']),
  );

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (code != null && code!.isNotEmpty) 'code': code,
    if (description != null) 'description': description,
    if (kind != null) 'kind': kind,
    'is_active': isActive,
    'is_default': isDefault,
    if (sortOrder != null) 'sort_order': sortOrder,
  };

  bool get isOnline => kind == 'online';
  String get kindAr => isOnline ? 'إلكتروني' : 'مباشر';
  String get statusAr => isActive ? 'مفعّلة' : 'معطّلة';
  // A source with payments against it can't be deleted — only deactivated.
  bool get canDelete => (paymentsCount ?? 0) == 0;

  static const List<String> kinds = ['offline', 'online'];
  static String kindLabel(String en) => en == 'online' ? 'إلكتروني' : 'مباشر';
}

// ─────────────────────────────────────────────
//  PAYMENT — الدفعة
//  status: success | pending | failed | refunded
//  type:   enrollment | renewal | other
// ─────────────────────────────────────────────
class Payment {
  int? id;
  int? userId;
  int? paymentSourceId;
  int? enrollmentId;
  double? amount;
  String? currency;
  String? status;
  String? type;
  String? reference;
  String? notes;
  String? createdAt;
  String? refundedAt;
  String? userName;
  String? sourceName;
  String? sourceKind;
  String? recordedByName;
  String? enrollmentMembershipName;

  Payment({
    this.id,
    this.userId,
    this.paymentSourceId,
    this.enrollmentId,
    this.amount,
    this.currency,
    this.status,
    this.type,
    this.reference,
    this.notes,
    this.createdAt,
    this.refundedAt,
    this.userName,
    this.sourceName,
    this.sourceKind,
    this.recordedByName,
    this.enrollmentMembershipName,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    // `payment_source` and `enrollment` are only included when the
    // controller eager-loaded them, so read them defensively.
    final source = json['payment_source'] is Map
        ? Map<String, dynamic>.from(json['payment_source'])
        : const <String, dynamic>{};
    final enrollment = json['enrollment'] is Map
        ? Map<String, dynamic>.from(json['enrollment'])
        : const <String, dynamic>{};

    return Payment(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      paymentSourceId: asInt(json['payment_source_id']),
      // There is no flat enrollment_id — it lives on the nested block.
      enrollmentId: asInt(enrollment['id']),
      enrollmentMembershipName: asString(enrollment['membership_name']),
      amount: asDouble(json['amount']),
      currency: asString(json['currency']) ?? 'SAR',
      status: asString(json['status']),
      type: asString(json['type']),
      reference: asString(json['reference']),
      notes: asString(json['notes']),
      // paid_at is when the money moved; created_at is when the row was
      // written. The desk cares about the former.
      createdAt: asString(json['paid_at'] ?? json['created_at']),
      refundedAt: asString(json['refunded_at']),
      userName: asString(json['user_name']),
      sourceName: asString(source['name']),
      sourceKind: asString(source['kind']),
      recordedByName: asString(json['recorded_by_name']),
    );
  }

  // Recording a desk payment — amount and payer are set once.
  Map<String, dynamic> toJson() => {
    if (userId != null) 'user_id': userId,
    if (paymentSourceId != null) 'payment_source_id': paymentSourceId,
    if (enrollmentId != null) 'enrollment_id': enrollmentId,
    if (amount != null) 'amount': amount,
    'currency': currency ?? 'SAR',
    if (status != null) 'status': status,
    if (type != null) 'type': type,
    if (notes != null) 'notes': notes,
  };

  String get payerName => userName ?? '—';

  // The API stores an ISO code; the desk reads a symbol.
  static String symbolFor(String? code) => switch (code) {
    null || '' || 'SAR' => 'ر.س',
    'AED' => 'د.إ',
    'KWD' => 'د.ك',
    'BHD' => 'د.ب',
    'QAR' => 'ر.ق',
    'OMR' => 'ر.ع',
    'EGP' => 'ج.م',
    'USD' => r'$',
    'EUR' => '€',
    _ => code,
  };

  String get amountLabel =>
      '${(amount ?? 0).toStringAsFixed(2)} ${symbolFor(currency)}';
  bool get isRefunded => status == 'refunded';
  bool get isPending => status == 'pending';
  bool get isSuccess => status == 'success';

  String get statusAr => switch (status) {
    'success' => 'محصّلة',
    'pending' => 'معلّقة',
    'failed' => 'فاشلة',
    'refunded' => 'مستردة',
    _ => status ?? '—',
  };

  String get typeAr => switch (type) {
    'enrollment' => 'اشتراك',
    'renewal' => 'تجديد',
    'other' => 'أخرى',
    _ => type ?? '—',
  };

  static const List<String> statuses = [
    'success',
    'pending',
    'failed',
    'refunded',
  ];
  static const List<String> types = ['enrollment', 'renewal', 'other'];

  static String statusLabel(String en) => switch (en) {
    'success' => 'محصّلة',
    'pending' => 'معلّقة',
    'failed' => 'فاشلة',
    'refunded' => 'مستردة',
    _ => en,
  };

  static String typeLabel(String en) => switch (en) {
    'enrollment' => 'اشتراك',
    'renewal' => 'تجديد',
    'other' => 'أخرى',
    _ => en,
  };
}

// ─────────────────────────────────────────────
//  PAYMENT TOTALS — إجماليات محسوبة على الفلتر
//  Computed over the whole filtered set, not
//  just the current page.
// ─────────────────────────────────────────────
class PaymentTotals {
  final double collected;
  final double pending;
  final double refunded;

  PaymentTotals({
    this.collected = 0,
    this.pending = 0,
    this.refunded = 0,
  });

  factory PaymentTotals.fromJson(dynamic json) {
    if (json is! Map) return PaymentTotals();
    final m = unprefix(Map<String, dynamic>.from(json), ['totals', 'total']);
    return PaymentTotals(
      collected: asDouble(m['collected'] ?? m['success']) ?? 0,
      pending: asDouble(m['pending']) ?? 0,
      refunded: asDouble(m['refunded']) ?? 0,
    );
  }
}
