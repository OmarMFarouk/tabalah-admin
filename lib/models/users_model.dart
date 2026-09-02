import 'paginated_model.dart';

// ─────────────────────────────────────────────
//  USER — الحساب
//  One account with whichever profile block
//  matches its role.
//
//  The server sends every field prefixed with its resource name —
//  `user_name`, `user_role`, `user_joined_at` — so each parser here
//  normalises through `unprefix` before reading anything.
// ─────────────────────────────────────────────
class User {
  int? userId;

  /// The primary (Arabic) name — required, and what every existing query
  /// and display already uses.
  String? name;

  /// The optional English rendering, shown to members running the app in
  /// English. A trainer's name is on the coaches rail, on session cards and
  /// on membership detail, so leaving this blank is what produces a screen
  /// that is English apart from the person's name.
  String? nameEn;

  String? email;
  String? phone;
  /// The tier: which app this account may open. Distinct from
  /// [accessRoleName], which is the named permission bundle.
  String? role;

  /// Every permission key the server says this account holds, already
  /// resolved (an assigned role's set, or the tier default, or everything
  /// for an owner). The panel gates its nav and buttons on this rather than
  /// on the tier — see [Permissions].
  List<String> permissions;

  /// The named role the permissions came from, for display. Null when the
  /// account is running on its tier default.
  int? accessRoleId;
  String? accessRoleName;

  String? avatar;
  String? createdAt;
  bool isOnline;
  String? lastSeen;

  PlayerProfile? player;
  TrainerProfile? trainer;
  EmployeeProfile? employee;

  User({
    this.userId,
    this.name,
    this.nameEn,
    this.email,
    this.phone,
    this.role,
    this.permissions = const [],
    this.accessRoleId,
    this.accessRoleName,
    this.avatar,
    this.createdAt,
    this.isOnline = false,
    this.lastSeen,
    this.player,
    this.trainer,
    this.employee,
  });

  factory User.fromJson(Map<String, dynamic> raw) {
    final json = unprefix(raw, ['user']);

    return User(
      userId: asInt(json['id']),
      // `name_ar` is the raw primary column; `name` is whatever the API
      // resolved for this request's language. The panel edits the raw
      // columns, so prefer those and fall back for older payloads.
      name: asString(json['name_ar']) ?? asString(json['name']),
      nameEn: asString(json['name_en']),
      email: asString(json['email']),
      phone: asString(json['phone']),
      role: readRole(raw),
      permissions: readPermissions(raw),
      accessRoleId: asInt(_accessRole(raw)?['id']),
      accessRoleName: asString(_accessRole(raw)?['name']),
      // `avatar_url` is the resolved link; `avatar` is the stored path.
      avatar: asString(json['avatar_url'] ?? json['avatar']),
      createdAt: asDate(json['joined_at'] ?? json['created_at']),
      isOnline: asBool(json['is_online']),
      lastSeen: asString(json['last_seen']),

      // The profile blocks arrive nested on the account row and carry no
      // account of their own, so hand each one its parent.
      player: raw['player'] is Map
          ? PlayerProfile.fromJson({
              ...Map<String, dynamic>.from(raw['player']),
              'user': raw,
            })
          : null,
      trainer: raw['trainer'] is Map
          ? TrainerProfile.fromJson({
              ...Map<String, dynamic>.from(raw['trainer']),
              'user': raw,
            })
          : null,
      employee: raw['employee'] is Map
          ? EmployeeProfile.fromJson({
              ...Map<String, dynamic>.from(raw['employee']),
              'user': raw,
            })
          : null,
    );
  }

  /// The `user_access_role` block, when the payload carries one.
  static Map<String, dynamic>? _accessRole(Map<String, dynamic> raw) {
    final json = unprefix(raw, ['user']);
    final node = json['access_role'] ?? raw['user_access_role'];
    return node is Map ? Map<String, dynamic>.from(node) : null;
  }

  /// The permission list, tolerating both the prefixed and bare key.
  ///
  /// Defaults to empty rather than to something permissive: a payload from
  /// an older server carries no permissions, and the right response to "I
  /// don't know what you may do" is to show nothing rather than everything.
  /// The server refuses either way; this only decides what the panel draws.
  static List<String> readPermissions(Map<String, dynamic> raw) {
    final json = unprefix(raw, ['user']);
    final node = json['permissions'] ?? raw['user_permissions'];
    if (node is! List) return const [];
    return node.map((e) => e.toString()).toList(growable: false);
  }

  // Read from `user_role` first — that's what the server actually sends.
  // The rest are fallbacks for a differently-shaped payload; normalising
  // the spelling means the getters below have one thing to match.
  static String? readRole(Map<String, dynamic> raw) {
    final json = unprefix(raw, ['user']);
    dynamic value =
        json['role'] ?? json['role_name'] ?? json['type'] ?? json['user_type'];

    if (value == null && json['roles'] is List) {
      final list = json['roles'] as List;
      if (list.isNotEmpty) value = list.first;
    }
    if (value is Map) value = value['name'] ?? value['slug'] ?? value['role'];

    final s = asString(value)?.trim().toLowerCase();
    if (s == null || s.isEmpty) return null;

    return switch (s.replaceAll('_', '-').replaceAll(' ', '-')) {
      'super-admin' || 'superadmin' || 'owner' || 'super' => 'super-admin',
      'admin' || 'administrator' || 'manager' => 'admin',
      'employee' || 'staff' || 'receptionist' => 'employee',
      'trainer' || 'coach' => 'trainer',
      'player' || 'member' || 'client' => 'player',
      _ => s,
    };
  }

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    // Sent even when empty so clearing it actually clears it server-side
    // rather than silently keeping the old spelling.
    'name_en': (nameEn ?? '').isEmpty ? null : nameEn,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
    if (role != null) 'role': role,
  };

  String get roleAr => switch (role) {
    'super-admin' => 'مالك النادي',
    'admin' => 'مدير',
    'employee' => 'موظف',
    'trainer' => 'مدرب',
    'player' => 'عضو',
    _ => role ?? '—',
  };

  // ── Value equality — المساواة بالقيمة ───────
  //  Screens build throwaway User objects to feed dropdowns (the performance
  //  page wraps trainers into Users so staff and trainers share one list).
  //  Those getters run on every build, so the list is a fresh set of
  //  instances each time while DropdownButtonFormField still holds the
  //  instance picked earlier. With identity equality the held value matches
  //  nothing in the new list, and Flutter asserts:
  //
  //    There should be exactly one item with [DropdownButtonFormField]'s
  //    value: Instance of 'User'
  //
  //  Comparing on the account id makes a rebuilt list equal to the old one.
  //  Rows with no id fall back to identity, so unsaved drafts stay distinct.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! User) return false;
    if (userId == null || other.userId == null) return false;
    return userId == other.userId;
  }

  @override
  int get hashCode => userId?.hashCode ?? identityHashCode(this);

  bool get isOwner => role == 'super-admin';
  bool get isAdmin => role == 'admin' || isOwner;
  bool get isStaff => isAdmin || role == 'employee';
  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;
  String get initial =>
      (name != null && name!.isNotEmpty) ? name!.substring(0, 1) : '؟';

  String get presenceAr => isOnline ? 'متصل الآن' : (lastSeen ?? '—');

  // Owner-only actions — إجراءات المالك فقط
  bool get canDeleteUsers => isOwner;
  bool get canManageStaff => isOwner;
  bool get canWriteCatalog => isAdmin;
  bool get canSendNewsletter => isAdmin;
}

// ─────────────────────────────────────────────
//  PROFILE SHAPES — شكلا السجل
//  Two shapes reach the profile parsers below:
//
//  • UserResource  — the account row, with a prefixed block nested
//                    under `player` / `trainer` / `employee`
//  • PlayerResource / TrainerResource / EmployeeResource
//                  — the profile row itself, with the account fields
//                    (name, email, phone, avatar) inlined at the top
//                    level and NO nested user object
//
//  `_shape` returns the profile block and the account fields for
//  whichever arrived, so each parser reads one consistent thing.
// ─────────────────────────────────────────────
({Map<String, dynamic> block, Map<String, dynamic> account, bool nested})
_shape(Map<String, dynamic> raw, String key) {
  final nested = raw[key] is Map;
  return (
    block: nested
        ? unprefix(Map<String, dynamic>.from(raw[key]), [key])
        : raw,
    account: nested ? unprefix(raw, ['user']) : raw,
    nested: nested,
  );
}

// ─────────────────────────────────────────────
//  PLAYER PROFILE — بيانات العضو
// ─────────────────────────────────────────────
class PlayerProfile {
  int? id;
  int? userId;

  /// The member's club id — `TBLH-00042`. What goes on their card and what
  /// they give at the desk, as opposed to [id], which is a database key
  /// nobody outside the server should ever see.
  String? clubId;

  String? name;
  String? nameEn;
  String? email;
  String? phone;
  String? avatar;
  double? height;
  double? weight;
  String? emergencyContact;
  String? qrToken;

  /// The parent-portal credential. A guardian types this into the member
  /// app to get a read-only view of this player and nothing else.
  String? guardianCode;

  /// False once staff have switched the parent portal off for this player.
  /// The code survives; it just stops working until re-enabled.
  bool guardianAccessEnabled;

  PlayerProfile({
    this.id,
    this.userId,
    this.clubId,
    this.name,
    this.email,
    this.phone,
    this.avatar,
    this.height,
    this.weight,
    this.emergencyContact,
    this.qrToken,
    this.guardianCode,
    this.guardianAccessEnabled = true,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> raw) {
    final s = _shape(raw, 'player');
    final json = s.block;
    final account = s.account;

    return PlayerProfile(
      id: asInt(json['id']),
      userId: asInt(s.nested ? account['id'] : json['user_id']),
      clubId: asString(json['club_id'] ?? json['player_club_id']),
      name: asString(account['name']),
      email: asString(account['email']),
      phone: asString(account['phone']),
      avatar: asString(account['avatar_url'] ?? account['avatar']),
      height: asDouble(json['height']),
      weight: asDouble(json['weight']),
      emergencyContact: asString(json['emergency_contact']),
      qrToken: asString(json['qr_token']),
      // PlayerResource sends the flat keys; UserResource nests them under
      // its `player` block with a `player_` prefix, and this model is fed
      // from both.
      guardianCode: asString(
        json['guardian_code'] ?? json['player_guardian_code'],
      ),
      guardianAccessEnabled: asBool(
        json['guardian_access_enabled'] ??
            json['player_guardian_access_enabled'] ??
            true,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    if (height != null) 'height': height,
    if (weight != null) 'weight': weight,
    if (emergencyContact != null) 'emergency_contact': emergencyContact,
  };

  String get displayName => name ?? '—';
  double? get bmi {
    if (height == null || weight == null || height == 0) return null;
    final m = height! / 100;
    return weight! / (m * m);
  }
}

// ─────────────────────────────────────────────
//  TRAINER PROFILE — بيانات المدرب
// ─────────────────────────────────────────────
class TrainerProfile {
  int? id;
  int? userId;
  String? name;
  String? nameEn;
  String? email;
  String? phone;
  String? avatar;
  int? sportId;
  String? sportName;
  String? bio;
  String? status;
  double? ratingAvg;
  int? membershipsCount;

  TrainerProfile({
    this.id,
    this.userId,
    this.name,
    this.nameEn,
    this.email,
    this.phone,
    this.avatar,
    this.sportId,
    this.sportName,
    this.bio,
    this.status,
    this.ratingAvg,
    this.membershipsCount,
  });

  factory TrainerProfile.fromJson(Map<String, dynamic> raw) {
    final s = _shape(raw, 'trainer');
    final json = s.block;
    final account = s.account;

    return TrainerProfile(
      id: asInt(json['id']),
      userId: asInt(s.nested ? account['id'] : json['user_id']),
      name: asString(account['name_ar']) ?? asString(account['name']),
      nameEn: asString(account['name_en']),
      email: asString(account['email']),
      phone: asString(account['phone']),
      avatar: asString(account['avatar_url'] ?? account['avatar']),
      sportId: asInt(json['sport_id']),
      sportName: asString(json['sport_name']),
      bio: asString(json['bio']),
      status: asString(json['status']),
      ratingAvg: asDouble(json['rating_avg']),
      // Only present when the endpoint asked for the count.
      membershipsCount: asInt(json['memberships_count']),
    );
  }

  Map<String, dynamic> toJson() => {
    if (sportId != null) 'sport_id': sportId,
    if (bio != null) 'bio': bio,
    if (status != null) 'status': status,
  };

  String get displayName => name ?? '—';
  bool get isActive => status == 'active';
  String get statusAr => isActive ? 'نشط' : 'موقوف';
}

// ─────────────────────────────────────────────
//  EMPLOYEE PROFILE — بيانات الموظف
// ─────────────────────────────────────────────
class EmployeeProfile {
  int? id;
  int? userId;
  String? name;
  String? nameEn;
  String? email;
  String? phone;
  String? avatar;
  /// The tier — which application this account may open.
  String? role;

  /// The named permission bundle from the settings screen: what this member
  /// of staff may actually do inside the panel.
  int? accessRoleId;
  String? accessRoleName;

  /// A free-text job title. Starts life as the name of the role they were
  /// hired into, and is editable from then on — a promotion and a
  /// permissions change are two different events.
  String? position;

  double? salary;
  String? status;

  EmployeeProfile({
    this.id,
    this.userId,
    this.name,
    this.nameEn,
    this.email,
    this.phone,
    this.avatar,
    this.role,
    this.accessRoleId,
    this.accessRoleName,
    this.position,
    this.salary,
    this.status,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> raw) {
    final s = _shape(raw, 'employee');
    final json = s.block;
    final account = s.account;

    return EmployeeProfile(
      id: asInt(json['id']),
      userId: asInt(s.nested ? account['id'] : json['user_id']),
      name: asString(account['name_ar']) ?? asString(account['name']),
      nameEn: asString(account['name_en']),
      email: asString(account['email']),
      phone: asString(account['phone']),
      avatar: asString(account['avatar_url'] ?? account['avatar']),
      role: asString(account['role']),
      accessRoleId: asInt(json['role_id'] ?? account['role_id']),
      accessRoleName: asString(json['role_name'] ?? account['role_name']),
      position: asString(json['position']),
      salary: asDouble(json['salary']),
      status: asString(json['status']),
    );
  }

  Map<String, dynamic> toJson() => {
    if (position != null) 'position': position,
    if (salary != null) 'salary': salary,
    if (status != null) 'status': status,
  };

  String get displayName => name ?? '—';
  bool get isActive => status == 'active';
  String get statusAr => isActive ? 'نشط' : 'موقوف';
}
