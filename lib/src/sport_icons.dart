import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  SPORT ICONS — أيقونات الرياضات
//
//  The key → glyph map for the icon a sport can be
//  tagged with. The API only ever ships the key
//  (see App\Support\SportIcons); each client owns
//  its own glyph, so the two Flutter apps can draw
//  the same sport with icons that suit their size
//  and their icon set without a schema change.
//
//  Keep the keys in step with the backend list —
//  an unknown key falls back to a neutral glyph
//  rather than rendering an empty box.
// ─────────────────────────────────────────────
class SportIcons {
  const SportIcons._();

  /// Drawn for a sport that has no icon set, or whose icon key this build
  /// doesn't recognise yet.
  static const IconData fallback = Icons.sports_rounded;

  static const Map<String, IconData> _glyphs = {
    'soccer': Icons.sports_soccer_rounded,
    'basketball': Icons.sports_basketball_rounded,
    'volleyball': Icons.sports_volleyball_rounded,
    'tennis': Icons.sports_tennis_rounded,
    'table_tennis': Icons.sports_tennis_outlined,
    'badminton': Icons.sports_tennis_rounded,
    'handball': Icons.sports_handball_rounded,
    'baseball': Icons.sports_baseball_rounded,
    'cricket': Icons.sports_cricket_rounded,
    'rugby': Icons.sports_rugby_rounded,
    'hockey': Icons.sports_hockey_rounded,
    'golf': Icons.sports_golf_rounded,
    'swimming': Icons.pool_rounded,
    'surfing': Icons.surfing_rounded,
    'sailing': Icons.sailing_rounded,
    'running': Icons.directions_run_rounded,
    'athletics': Icons.sports_score_rounded,
    'cycling': Icons.directions_bike_rounded,
    'gym': Icons.fitness_center_rounded,
    'boxing': Icons.sports_mma_rounded,
    'martial_arts': Icons.sports_kabaddi_rounded,
    'wrestling': Icons.sports_kabaddi_outlined,
    'fencing': Icons.sports_martial_arts_rounded,
    'archery': Icons.my_location_rounded,
    'shooting': Icons.gps_fixed_rounded,
    'gymnastics': Icons.accessibility_new_rounded,
    'yoga': Icons.self_improvement_rounded,
    'dance': Icons.music_note_rounded,
    'skating': Icons.ice_skating_rounded,
    'skiing': Icons.downhill_skiing_rounded,
    'snowboarding': Icons.snowboarding_rounded,
    'climbing': Icons.terrain_rounded,
    'hiking': Icons.hiking_rounded,
    'equestrian': Icons.bedroom_baby_rounded,
    'esports': Icons.sports_esports_rounded,
    'chess': Icons.grid_on_rounded,
    'darts': Icons.adjust_rounded,
    'bowling': Icons.sports_rounded,
    'billiards': Icons.circle_rounded,
    'kayaking': Icons.kayaking_rounded,
  };

  /// Every key, in the order the picker shows them.
  static List<String> get keys => _glyphs.keys.toList(growable: false);

  static IconData of(String? key) =>
      key == null ? fallback : (_glyphs[key] ?? fallback);

  static bool isKnown(String? key) => key != null && _glyphs.containsKey(key);

  /// Arabic label for the picker. Falls back to the raw key so a sport
  /// tagged with an icon this build predates still shows *something*
  /// readable instead of a blank tile.
  static String label(String key) => switch (key) {
    'soccer' => 'كرة قدم',
    'basketball' => 'كرة سلة',
    'volleyball' => 'كرة طائرة',
    'tennis' => 'تنس',
    'table_tennis' => 'تنس طاولة',
    'badminton' => 'ريشة طائرة',
    'handball' => 'كرة يد',
    'baseball' => 'بيسبول',
    'cricket' => 'كريكيت',
    'rugby' => 'رغبي',
    'hockey' => 'هوكي',
    'golf' => 'غولف',
    'swimming' => 'سباحة',
    'surfing' => 'ركوب الأمواج',
    'sailing' => 'إبحار',
    'running' => 'جري',
    'athletics' => 'ألعاب قوى',
    'cycling' => 'دراجات',
    'gym' => 'حديد ولياقة',
    'boxing' => 'ملاكمة',
    'martial_arts' => 'فنون قتالية',
    'wrestling' => 'مصارعة',
    'fencing' => 'مبارزة',
    'archery' => 'رماية بالقوس',
    'shooting' => 'رماية',
    'gymnastics' => 'جمباز',
    'yoga' => 'يوغا',
    'dance' => 'رقص',
    'skating' => 'تزلج على الجليد',
    'skiing' => 'تزلج',
    'snowboarding' => 'تزلج بالألواح',
    'climbing' => 'تسلق',
    'hiking' => 'مشي جبلي',
    'equestrian' => 'فروسية',
    'esports' => 'رياضات إلكترونية',
    'chess' => 'شطرنج',
    'darts' => 'سهام',
    'bowling' => 'بولينغ',
    'billiards' => 'بلياردو',
    'kayaking' => 'تجديف',
    _ => key,
  };
}
