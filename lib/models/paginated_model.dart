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

  // 1-based index of the first / last row on this page, for the
  // "٢١–٤٠ من ١٣٧" label in the table footer.
  int get firstIndex => isEmpty ? 0 : ((currentPage - 1) * perPage) + 1;
  int get lastIndex => isEmpty ? 0 : firstIndex + items.length - 1;

  // We asked for a page that no longer exists.
  //
  // Happens whenever the result set shrinks under a pager that stayed put:
  // searching while on page 3, tightening a filter, or deleting the last
  // row of the final page. The server answers honestly — an empty page 3 of
  // a 1-page result — but the user reads it as "no results", which is
  // wrong. Cubits watch this and rewind to page 1.
  bool get isOrphanedPage => isEmpty && total > 0 && currentPage > 1;

  // ─────────────────────────────────────────────
  //  ENVELOPE READER — قراءة الغلاف
  //  The API answers flat: the rows sit under their own name and the
  //  paging block sits BESIDE them, not around them —
  //
  //    { "sessions": [ ... ], "meta": { ... }, "success": true }
  //
  //  so handing `parse` only the list node loses the paging entirely and
  //  every table reports last_page = 1. Read both keys off the same body.
  // ─────────────────────────────────────────────
  static Paginated<T> read<T>(
    Map<String, dynamic> body,
    String key,
    T Function(Map<String, dynamic>) builder, {
    // Some payloads name the block differently between endpoints.
    List<String> alsoTry = const [],
  }) {
    dynamic node = body[key];
    for (final k in alsoTry) {
      if (node != null) break;
      node = body[k];
    }

    final base = parse<T>(node, builder);
    final meta = body['meta'];
    if (meta is! Map) return base;

    final m = Map<String, dynamic>.from(meta);
    return Paginated<T>(
      items: base.items,
      currentPage: _int(m['current_page']) ?? base.currentPage,
      lastPage: _int(m['last_page']) ?? base.lastPage,
      total: _int(m['total']) ?? base.total,
      // Falls back to the page size we actually received, so the row-range
      // label stays right even against a server that omits per_page.
      perPage: _int(m['per_page']) ??
          (base.items.isEmpty ? base.perPage : base.items.length),
    );
  }

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

  // Page numbers to draw, with -1 standing in for a gap. Keeps the first
  // and last page always reachable and a window around the current one,
  // so a 40-page result still fits on one row.
  List<int> get pageWindow {
    if (lastPage <= 7) {
      return [for (int i = 1; i <= lastPage; i++) i];
    }
    final out = <int>{1, lastPage};
    for (int i = currentPage - 1; i <= currentPage + 1; i++) {
      if (i > 1 && i < lastPage) out.add(i);
    }
    final sorted = out.toList()..sort();
    final withGaps = <int>[];
    for (int i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) withGaps.add(-1);
      withGaps.add(sorted[i]);
    }
    return withGaps;
  }
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

// ── Dates — التواريخ ────────────────────────
//  Laravel casts date columns to Carbon and serialises them in full ISO
//  8601: "2026-08-15T00:00:00.000000Z". Passing that straight to a Text
//  widget put the raw timestamp - Z and all - on screen.
//
//  `asDate` keeps the calendar day only, which is what every date field in
//  this panel actually means: an enrolment ends on a day, attendance is
//  taken on a day. Parsing is deliberately lenient - a value that is
//  already "2026-08-15" passes through untouched, and anything
//  unrecognisable is returned as-is rather than swallowed.
String? asDate(dynamic v) {
  final raw = asString(v);
  if (raw == null) return null;

  // Already a plain date.
  if (raw.length == 10 && raw[4] == '-' && raw[7] == '-') return raw;

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    // Not a timestamp we recognise; at least drop a trailing time block
    // rather than showing the T and the Z.
    final t = raw.indexOf('T');
    return t == 10 ? raw.substring(0, 10) : raw;
  }

  // toLocal() first: an appointment stored as midnight UTC is still the
  // 15th to a reader in Riyadh, and slicing the UTC string would show the
  // 14th for anyone west of it.
  final d = parsed.isUtc ? parsed.toLocal() : parsed;
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// Same, but keeps the time - for "when did this payment land" rather than
// "which day does this membership end".
String? asDateTime(dynamic v) {
  final raw = asString(v);
  if (raw == null) return null;

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  final d = parsed.isUtc ? parsed.toLocal() : parsed;
  final date = asDate(d.toIso8601String()) ?? raw;
  return '$date  '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
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
