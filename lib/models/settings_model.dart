import 'paginated_model.dart';

// ─────────────────────────────────────────────
//  ROLE — دور
//  A named bundle of permissions, assigned to a
//  staff account. Distinct from `user.role`,
//  which is the tier deciding which app you may
//  open at all.
// ─────────────────────────────────────────────
class AccessRole {
  int? id;
  String? key;
  String? name;
  String? nameEn;
  String? description;

  /// Seeded roles the app relies on. Their permissions stay editable — that
  /// is the point — but they cannot be deleted, because losing the one that
  /// grants role management would lock the club out of its own settings.
  bool isSystem;

  /// The server's verdict on whether delete would succeed, so the panel can
  /// grey the button rather than let the user discover the 422.
  bool isDeletable;

  int usersCount;
  List<String> permissions;

  AccessRole({
    this.id,
    this.key,
    this.name,
    this.nameEn,
    this.description,
    this.isSystem = false,
    this.isDeletable = false,
    this.usersCount = 0,
    this.permissions = const [],
  });

  factory AccessRole.fromJson(Map<String, dynamic> json) => AccessRole(
    id: asInt(json['id']),
    key: asString(json['key']),
    name: asString(json['name_ar']) ?? asString(json['name']),
    nameEn: asString(json['name_en']),
    description: asString(json['description']),
    isSystem: asBool(json['is_system']),
    isDeletable: asBool(json['is_deletable']),
    usersCount: asInt(json['users_count']) ?? 0,
    permissions: (json['permissions'] is List)
        ? (json['permissions'] as List).map((e) => e.toString()).toList()
        : const [],
  );

  Map<String, dynamic> toJson() => {
    if (name != null) 'name_ar': name,
    'name_en': (nameEn ?? '').isEmpty ? null : nameEn,
    'description': (description ?? '').isEmpty ? null : description,
    'permissions': permissions,
  };

  String get displayName => name ?? key ?? '—';
}

// ─────────────────────────────────────────────
//  PERMISSION — صلاحية
// ─────────────────────────────────────────────
class AppPermission {
  int? id;
  String? key;
  String? group;
  String? label;

  AppPermission({this.id, this.key, this.group, this.label});

  factory AppPermission.fromJson(Map<String, dynamic> json) => AppPermission(
    id: asInt(json['id']),
    key: asString(json['key']),
    group: asString(json['group']),
    label: asString(json['label_ar']) ?? asString(json['label']),
  );
}

// ─────────────────────────────────────────────
//  AUDIT ENTRY — سطر في سجل النشاط
// ─────────────────────────────────────────────
class AuditEntry {
  int? id;
  int? userId;

  /// The actor's name as it was *at the time*, not a live lookup — the trail
  /// has to stay readable after the account is deleted.
  String? userName;
  String? userRole;

  String? action;
  String? actionLabel;
  String? recordType;
  String? recordLabel;
  int? recordId;
  String? description;
  String? ipAddress;
  String? createdAt;

  /// `{before: {...}, after: {...}}`, plus `granted`/`revoked` on role
  /// edits. Null for actions that aren't a model write.
  Map<String, dynamic>? changes;

  AuditEntry({
    this.id,
    this.userId,
    this.userName,
    this.userRole,
    this.action,
    this.actionLabel,
    this.recordType,
    this.recordLabel,
    this.recordId,
    this.description,
    this.ipAddress,
    this.createdAt,
    this.changes,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    id: asInt(json['id']),
    userId: asInt(json['user_id']),
    userName: asString(json['user_name']),
    userRole: asString(json['user_role']),
    action: asString(json['action']),
    actionLabel: asString(json['action_label']),
    recordType: asString(json['auditable_type']),
    recordLabel: asString(json['auditable_label']),
    recordId: asInt(json['auditable_id']),
    description: asString(json['description']),
    ipAddress: asString(json['ip_address']),
    createdAt: asDateTime(json['created_at']),
    changes: json['changes'] is Map
        ? Map<String, dynamic>.from(json['changes'])
        : null,
  );

  String get actor => userName ?? 'النظام';

  /// The fields that actually moved, as `field: before → after`.
  ///
  /// A diff rather than a dump: "price 450 → 45" is what somebody reading an
  /// audit trail is looking for, and a full copy of the row is what they
  /// scroll past.
  List<({String field, String? before, String? after})> get diff {
    final before = changes?['before'];
    final after = changes?['after'];
    if (before is! Map && after is! Map) return const [];

    final fields = <String>{
      if (before is Map) ...before.keys.map((k) => k.toString()),
      if (after is Map) ...after.keys.map((k) => k.toString()),
    }..removeWhere((f) => f == 'updated_at' || f == 'created_at');

    return fields
        .map(
          (f) => (
            field: f,
            before: (before is Map ? before[f] : null)?.toString(),
            after: (after is Map ? after[f] : null)?.toString(),
          ),
        )
        .toList();
  }

  /// Role edits carry these on top of the diff.
  List<String> get granted =>
      (changes?['granted'] as List?)?.map((e) => e.toString()).toList() ??
      const [];

  List<String> get revoked =>
      (changes?['revoked'] as List?)?.map((e) => e.toString()).toList() ??
      const [];

  bool get isDestructive => action == 'deleted' || action == 'refunded';
  bool get isAuthEvent =>
      action == 'login' ||
      action == 'logout' ||
      action == 'login_failed' ||
      action == 'guardian_login';
}
