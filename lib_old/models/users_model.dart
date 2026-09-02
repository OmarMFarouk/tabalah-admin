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
  String? name;
  String? email;
  String? phone;
  String? role;
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
    this.email,
    this.phone,
    this.role,
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
      name: asString(json['name']),
      email: asString(json['email']),
      phone: asString(json['phone']),
      role: readRole(raw),
      // `avatar_url` is the resolved link; `avatar` is the stored path.
      avatar: asString(json['avatar_url'] ?? json['avatar']),
      createdAt: asString(json['joined_at'] ?? json['created_at']),
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
  String? name;
  String? email;
  String? phone;
  String? avatar;
  double? height;
  double? weight;
  String? emergencyContact;
  String? qrToken;

  PlayerProfile({
    this.id,
    this.userId,
    this.name,
    this.email,
    this.phone,
    this.avatar,
    this.height,
    this.weight,
    this.emergencyContact,
    this.qrToken,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> raw) {
    final s = _shape(raw, 'player');
    final json = s.block;
    final account = s.account;

    return PlayerProfile(
      id: asInt(json['id']),
      userId: asInt(s.nested ? account['id'] : json['user_id']),
      name: asString(account['name']),
      email: asString(account['email']),
      phone: asString(account['phone']),
      avatar: asString(account['avatar_url'] ?? account['avatar']),
      height: asDouble(json['height']),
      weight: asDouble(json['weight']),
      emergencyContact: asString(json['emergency_contact']),
      qrToken: asString(json['qr_token']),
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
      name: asString(account['name']),
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
  String? email;
  String? phone;
  String? avatar;
  String? role;
  String? position;
  double? salary;
  String? status;

  EmployeeProfile({
    this.id,
    this.userId,
    this.name,
    this.email,
    this.phone,
    this.avatar,
    this.role,
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
      name: asString(account['name']),
      email: asString(account['email']),
      phone: asString(account['phone']),
      avatar: asString(account['avatar_url'] ?? account['avatar']),
      role: asString(account['role']),
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
