import 'paginated_model.dart';

// ─────────────────────────────────────────────
//  KPI — مؤشر الأداء
//  metric is unique — المقياس فريد
// ─────────────────────────────────────────────
class Kpi {
  int? id;
  String? metric;
  int? recordsCount;

  Kpi({this.id, this.metric, this.recordsCount});

  factory Kpi.fromJson(Map<String, dynamic> json) => Kpi(
    id: asInt(json['id']),
    metric: asString(json['metric']),
    recordsCount: asInt(json['records_count'] ?? json['kpi_records_count']),
  );

  Map<String, dynamic> toJson() => {if (metric != null) 'metric': metric};
}

// ─────────────────────────────────────────────
//  KPI RECORD — تسجيل مؤشر
//  Target vs actual for one staff member, one month
// ─────────────────────────────────────────────
class KpiRecord {
  int? id;
  int? kpiId;
  int? userId;
  double? target;
  double? actual;
  String? period;
  String? userName;
  String? metric;
  double? achievementPct;

  KpiRecord({
    this.id,
    this.kpiId,
    this.userId,
    this.target,
    this.actual,
    this.period,
    this.userName,
    this.metric,
    this.achievementPct,
  });

  factory KpiRecord.fromJson(Map<String, dynamic> json) => KpiRecord(
    id: asInt(json['id']),
    kpiId: asInt(json['kpi_id']),
    userId: asInt(json['user_id']),
    target: asDouble(json['target']),
    actual: asDouble(json['actual']),
    period: asString(json['period']),
    userName: asString(json['user_name']),
    metric: asString(json['metric']),
    achievementPct: asDouble(json['achievement_pct']),
  );

  Map<String, dynamic> toJson() => {
    if (kpiId != null) 'kpi_id': kpiId,
    if (userId != null) 'user_id': userId,
    if (target != null) 'target': target,
    if (actual != null) 'actual': actual,
    if (period != null) 'period': period,
  };

  String get staffName => userName ?? '—';

  double get progress {
    if (target == null || target == 0) return 0;
    return ((actual ?? 0) / target!).clamp(0, 1.5);
  }

  bool get metTarget => (actual ?? 0) >= (target ?? 0);
}

// ─────────────────────────────────────────────
//  SALARY — الراتب
// ─────────────────────────────────────────────
class Salary {
  int? id;
  int? userId;
  double? amount;
  String? period;
  String? userName;

  Salary({this.id, this.userId, this.amount, this.period, this.userName});

  factory Salary.fromJson(Map<String, dynamic> json) => Salary(
    id: asInt(json['id']),
    userId: asInt(json['user_id']),
    amount: asDouble(json['amount']),
    period: asString(json['period']),
    userName: asString(json['user_name']),
  );

  Map<String, dynamic> toJson() => {
    if (userId != null) 'user_id': userId,
    if (amount != null) 'amount': amount,
    if (period != null) 'period': period,
  };

  String get staffName => userName ?? '—';
  String get amountLabel => '${(amount ?? 0).toStringAsFixed(2)} ر.س';
}

// ─────────────────────────────────────────────
//  EMAIL LOG — سجل البريد
// ─────────────────────────────────────────────
class EmailLog {
  int? id;
  int? userId;
  String? subject;
  String? type;
  String? status;
  String? sentAt;
  String? recipientName;
  String? recipientEmail;
  String? sentByName;
  int? newsletterId;
  String? error;

  EmailLog({
    this.id,
    this.userId,
    this.subject,
    this.type,
    this.status,
    this.sentAt,
    this.recipientName,
    this.recipientEmail,
    this.sentByName,
    this.newsletterId,
    this.error,
  });

  factory EmailLog.fromJson(Map<String, dynamic> json) => EmailLog(
    id: asInt(json['id']),
    userId: asInt(json['user_id']),
    subject: asString(json['subject']),
    type: asString(json['type']),
    status: asString(json['status']),
    sentAt: asDateTime(json['created_at']),
    recipientName: asString(json['recipient_name']),
    recipientEmail: asString(json['recipient_email']),
    sentByName: asString(json['sent_by_name']),
    newsletterId: asInt(json['newsletter_id']),
    error: asString(json['error']),
  );

  String get toName => recipientName ?? recipientEmail ?? '—';
  bool get failed => status == 'failed' || (error ?? '').isNotEmpty;
}

// ─────────────────────────────────────────────
//  NEWSLETTER — النشرة البريدية
//  audience: all | players | trainers | staff | custom
// ─────────────────────────────────────────────
class Newsletter {
  int? id;
  String? subject;
  String? body;
  String? audience;
  int? recipientsCount;
  String? sentAt;

  Newsletter({
    this.id,
    this.subject,
    this.body,
    this.audience,
    this.recipientsCount,
    this.sentAt,
  });

  factory Newsletter.fromJson(Map<String, dynamic> json) => Newsletter(
    id: asInt(json['id']),
    subject: asString(json['subject']),
    body: asString(json['body']),
    audience: asString(json['audience']),
    recipientsCount: asInt(
      json['recipients_count'] ?? json['recipients'] ?? json['sent_count'],
    ),
    sentAt: asDateTime(json['sent_at'] ?? json['created_at']),
  );

  String get audienceAr => audienceLabel(audience ?? '');

  static const List<String> audiences = [
    'all',
    'players',
    'trainers',
    'staff',
    'custom',
  ];

  static String audienceLabel(String en) => switch (en) {
    'all' => 'الجميع',
    'players' => 'الأعضاء',
    'trainers' => 'المدربون',
    'staff' => 'الموظفون',
    'custom' => 'قائمة مخصصة',
    _ => en,
  };
}
