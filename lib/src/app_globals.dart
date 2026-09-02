import '../models/catalog_model.dart';
import '../models/finance_model.dart';
import '../models/settings_model.dart';
import '../models/users_model.dart';

// ─────────────────────────────────────────────
//  APP GLOBALS — الحالة المشتركة
//  Lookup lists the whole panel reads from, so
//  every dropdown resolves names without an
//  extra round trip.
// ─────────────────────────────────────────────
class AppGlobals {
  static User? currentUser;

  // Shared lookups — القوائم المشتركة
  static List<Sport> sports = [];
  static List<Membership> memberships = [];
  static List<TrainerProfile> trainers = [];
  static List<PaymentSource> paymentSources = [];
  static List<User> members = [];
  static List<User> staff = [];

  /// The named permission bundles from the settings screen — what the role
  /// dialog offers. Empty when the signed-in account can't read them, which
  /// is fine: it also can't open that dialog.
  static List<AccessRole> accessRoles = [];

  // Saudi riyal. Every amount in the panel reads this one field.
  static String currency = 'ر.س';

  static bool get isReady => currentUser != null;

  static String sportName(int? id) => sports
      .firstWhere(
        (s) => s.id == id,
        orElse: () => Sport(name: '—'),
      )
      .name ??
      '—';

  static String membershipName(int? id) => memberships
      .firstWhere(
        (m) => m.id == id,
        orElse: () => Membership(name: '—'),
      )
      .name ??
      '—';

  static String sourceName(int? id) => paymentSources
      .firstWhere(
        (s) => s.id == id,
        orElse: () => PaymentSource(name: '—'),
      )
      .name ??
      '—';

  static void clear() {
    currentUser = null;
    sports = [];
    memberships = [];
    trainers = [];
    paymentSources = [];
    members = [];
    staff = [];
    accessRoles = [];
  }
}
