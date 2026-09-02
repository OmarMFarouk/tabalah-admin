// ─────────────────────────────────────────────
//  PAGINATED ENVELOPE
//  The API answers with a flat named array
//  ({ "trainers": [...] }) but may also wrap it
//  in a Laravel paginator ({ "data": [...] }).
//  This reads both shapes.
// ─────────────────────────────────────────────
class Paginated<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  Paginated({
    required this.items,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.perPage = 15,
  });

  bool get hasPrev => currentPage > 1;
  bool get hasNext => currentPage < lastPage;
  bool get isEmpty => items.isEmpty;

  static Paginated<T> parse<T>(
    dynamic node,
    T Function(Map<String, dynamic>) builder,
  ) {
    // Flat array → { "trainers": [ ... ] }
    if (node is List) {
      final items = node
          .whereType<Map>()
          .map((e) => builder(Map<String, dynamic>.from(e)))
          .toList();
      return Paginated<T>(items: items, total: items.length, lastPage: 1);
    }

    // Wrapped → { "trainers": { "data": [...], "meta": {...} } }
    if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      final raw = map['data'] ?? map['items'] ?? [];
      final meta = Map<String, dynamic>.from(map['meta'] ?? map);
      final items = (raw is List ? raw : [])
          .whereType<Map>()
          .map((e) => builder(Map<String, dynamic>.from(e)))
          .toList();
      return Paginated<T>(
        items: items,
        currentPage: _int(meta['current_page']) ?? 1,
        lastPage: _int(meta['last_page']) ?? 1,
        total: _int(meta['total']) ?? items.length,
        perPage: _int(meta['per_page']) ?? 15,
      );
    }

    return Paginated<T>(items: const []);
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Paginated<T> copyWith({List<T>? items}) => Paginated<T>(
    items: items ?? this.items,
    currentPage: currentPage,
    lastPage: lastPage,
    total: total,
    perPage: perPage,
  );
}

// ── Shared JSON helpers — مساعدات التحويل ─────
int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString());
}

double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool asBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  final s = v.toString().toLowerCase();
  return s == 'true' || s == '1';
}

String? asString(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return (s.isEmpty || s == 'null') ? null : s;
}

// Returns the first match, or null. Defined here rather than relying on
// `firstOrNull`, which lives in package:collection and would add a
// dependency purely for dropdown lookups.
T? pickWhere<T>(Iterable<T> items, bool Function(T) test) {
  for (final e in items) {
    if (test(e)) return e;
  }
  return null;
}

// ─────────────────────────────────────────────
//  KEY NORMALISER — توحيد المفاتيح
//  The API prefixes every field with its resource name:
//  `user_name`, `player_height`, `trainer_sport_id`.
//  Strip the prefix once, up front, so each parser below can read a
//  plain `name` / `height` / `sport_id`. Originals are kept alongside,
//  and putIfAbsent means an unprefixed payload passes through
//  untouched — so both conventions parse.
// ─────────────────────────────────────────────
Map<String, dynamic> unprefix(Map<String, dynamic> json, List<String> prefixes) {
  final out = <String, dynamic>{...json};
  for (final prefix in prefixes) {
    final p = '${prefix}_';
    json.forEach((k, v) {
      if (k.startsWith(p) && k.length > p.length) {
        out.putIfAbsent(k.substring(p.length), () => v);
      }
    });
  }
  return out;
}
