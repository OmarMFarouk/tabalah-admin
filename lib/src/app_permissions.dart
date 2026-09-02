import '../models/users_model.dart';
import 'app_globals.dart';

// ─────────────────────────────────────────────
//  PERMISSIONS — الصلاحيات
//
//  The UI mirror of the server's permission set.
//  The server remains the authority — every rule
//  here is enforced again by `permission:` on the
//  route and by the policy inside the controller,
//  and the panel hiding a button is a courtesy,
//  not a security boundary.
//
//  What changed: these used to be derived from
//  the account's *tier* (`isAdmin`, `isOwner`).
//  They are now read from the permission list the
//  server sends with the account, so a role built
//  in the panel actually changes what the panel
//  shows — which is the whole point of roles.
//
//  The tier still matters for two things, and only
//  two: which app you may open at all, and the
//  privilege-escalation guards on staff accounts
//  (an admin may not mint another admin, whatever
//  permissions their role carries). Those live in
//  UserPolicy on the server and are mirrored at
//  the bottom of this file.
// ─────────────────────────────────────────────
class Permissions {
  Permissions._();

  static User? get _me => AppGlobals.currentUser;

  // ── Keys ────────────────────────────────────
  //  Kept in step with App\Support\Permissions on the server. A typo here
  //  fails closed (the button hides), which is the safe direction, but it
  //  also means the panel and the server must agree — hence constants
  //  rather than string literals at each call site.
  static const dashboardView = 'dashboard.view';

  static const reportsView = 'reports.view';
  static const reportsFinancial = 'reports.financial';

  static const peopleView = 'people.view';
  static const usersCreate = 'people.users.create';
  static const usersUpdate = 'people.users.update';
  static const usersDelete = 'people.users.delete';
  static const usersAssignRole = 'people.users.assign_role';
  static const staffManage = 'people.staff.manage';
  static const playersManage = 'people.players.manage';
  static const trainersManage = 'people.trainers.manage';
  static const guardianManage = 'people.guardian.manage';

  static const catalogView = 'catalog.view';
  static const sportsManage = 'catalog.sports.manage';
  static const membershipsManage = 'catalog.memberships.manage';
  static const schedulesManage = 'catalog.schedules.manage';

  static const sessionsView = 'sessions.view';
  static const sessionsManage = 'sessions.manage';
  static const attendanceRecord = 'attendance.record';
  static const attendanceDelete = 'attendance.delete';

  static const enrollmentsView = 'enrollments.view';
  static const enrollmentsManage = 'enrollments.manage';
  static const enrollmentsDelete = 'enrollments.delete';

  static const financeView = 'finance.view';
  static const paymentsRecord = 'finance.payments.record';
  static const paymentsUpdate = 'finance.payments.update';
  static const paymentsRefund = 'finance.payments.refund';
  static const sourcesManage = 'finance.sources.manage';

  static const performanceView = 'performance.view';
  static const kpisManage = 'performance.kpis.manage';
  static const salariesManage = 'performance.salaries.manage';

  static const commsView = 'comms.view';
  static const emailSend = 'comms.email.send';
  static const newsletterSend = 'comms.newsletter.send';

  static const rolesView = 'settings.roles.view';
  static const rolesManage = 'settings.roles.manage';
  static const auditView = 'settings.audit.view';

  // ── The check ───────────────────────────────

  /// Whether the signed-in account holds [key].
  ///
  /// The owner short-circuits, mirroring the server's `Gate::before`: a role
  /// edit must never be able to hide the panel from the person who has to
  /// fix it.
  static bool has(String key) {
    if (isOwner) return true;
    return _me?.permissions.contains(key) ?? false;
  }

  static bool hasAny(List<String> keys) {
    if (isOwner) return true;
    final held = _me?.permissions ?? const <String>[];
    return keys.any(held.contains);
  }

  // ── Tier ────────────────────────────────────
  //  Still meaningful for the escalation guards below, and nothing else.
  static bool get isOwner => _me?.isOwner ?? false;
  static bool get isAdmin => _me?.isAdmin ?? false;
  static bool get isStaff => _me?.isStaff ?? false;

  // ── Page-level gates ────────────────────────
  //  The index screen hides a nav entry entirely when its view permission is
  //  missing, rather than showing a page that 403s on load.
  static bool get canSeeDashboard => has(dashboardView);
  static bool get canSeeReports => has(reportsView);
  static bool get canSeeFinancialReports => has(reportsFinancial);
  static bool get canSeePeople => has(peopleView);
  static bool get canSeeCatalog => has(catalogView);
  static bool get canSeeSessions => has(sessionsView);
  static bool get canSeeFinance => has(financeView);
  static bool get canSeePerformance => has(performanceView);
  static bool get canSeeComms => has(commsView);
  static bool get canSeeRoles => has(rolesView);
  static bool get canSeeAudit => has(auditView);

  // ── Action gates ────────────────────────────
  static bool get canManageSports => has(sportsManage);
  static bool get canManageMemberships => has(membershipsManage);
  static bool get canManageSchedules => has(schedulesManage);
  static bool get canManageSessions => has(sessionsManage);
  static bool get canRecordAttendance => has(attendanceRecord);
  static bool get canDeleteAttendance => has(attendanceDelete);
  static bool get canEnroll => has(enrollmentsManage);
  static bool get canDeleteEnrollment => has(enrollmentsDelete);
  static bool get canRecordPayment => has(paymentsRecord);
  static bool get canUpdatePayment => has(paymentsUpdate);
  static bool get canRefundPayment => has(paymentsRefund);
  static bool get canManageSources => has(sourcesManage);
  static bool get canManageKpis => has(kpisManage);
  static bool get canManageSalaries => has(salariesManage);
  static bool get canSendEmail => has(emailSend);
  static bool get canSendNewsletter => has(newsletterSend);
  static bool get canManageRoles => has(rolesManage);
  static bool get canManageGuardianAccess => has(guardianManage);

  static bool get canManagePlayers => has(playersManage);
  static bool get canManageTrainers => has(trainersManage);
  static bool get canManageStaff => has(staffManage);

  static bool get canCreateUsers => has(usersCreate);
  static bool get canManageUsers => has(usersUpdate);
  static bool get canAssignRoles => has(usersAssignRole);

  /// Kept as a broad "may this account change anything here" for screens
  /// that have not been given a finer key. Deliberately generous-looking but
  /// still permission-backed: the server refuses regardless.
  static bool get canWrite => hasAny([
    sportsManage,
    membershipsManage,
    sessionsManage,
    usersUpdate,
    paymentsRecord,
    kpisManage,
  ]);

  // ── Escalation guards ───────────────────────
  //  These are NOT permissions and must not become configurable. They mirror
  //  UserPolicy: a role granting `people.users.assign_role` still cannot be
  //  used to mint an owner, because the tier check runs after the permission
  //  check on the server. The panel reflects the same rule so it never
  //  offers an action the server will refuse.

  /// Deleting any account.
  static bool canDeleteUser(User? target) {
    if (!has(usersDelete)) return false;
    if (target?.userId == _me?.userId) return false;
    // Removing an admin or the owner stays with the owner.
    if ((target?.isAdmin ?? false) || (target?.isOwner ?? false)) return isOwner;
    return true;
  }

  /// Tiers this account may hand out, in descending privilege.
  static List<String> get assignableRoles {
    if (!canAssignRoles) return const [];
    if (isOwner) {
      return const ['super-admin', 'admin', 'employee', 'trainer', 'player'];
    }
    // Non-owners may never mint a privileged tier, permission or not.
    return const ['employee', 'trainer', 'player'];
  }

  static bool canAssignRoleTo(User? target, String role) {
    if (target == null || !canAssignRoles) return false;
    if (target.userId == _me?.userId) return false;
    if (!assignableRoles.contains(role)) return false;
    if ((target.isAdmin || target.isOwner) && !isOwner) return false;
    return true;
  }

  /// Whether the role button shows at all.
  ///
  /// Staff only. A role is a bundle of admin-panel permissions, and members
  /// and coaches never open the panel — offering to give one a role was
  /// offering something with no effect. Their tier isn't editable here
  /// either: a member becomes a coach by being added as one, not by having
  /// their account relabelled underneath the profile row.
  static bool canChangeRoleOf(User? target) {
    if (target == null || !canAssignRoles) return false;
    if (target.userId == _me?.userId) return false;
    if (!target.isStaff) return false;
    if ((target.isAdmin || target.isOwner) && !isOwner) return false;
    return true;
  }

  static String roleDenialReason(User? target) {
    if (!canAssignRoles) return 'ليس لديك صلاحية إسناد الأدوار';
    if (target?.userId == _me?.userId) return 'لا يمكنك تغيير دورك بنفسك';
    if (!(target?.isStaff ?? false)) {
      return 'الأدوار تخص حسابات الموظفين فقط';
    }
    if ((target?.isAdmin ?? false) || (target?.isOwner ?? false)) {
      return 'تعديل حسابات الإدارة متاح للمالك فقط';
    }
    return 'غير مسموح';
  }
}
