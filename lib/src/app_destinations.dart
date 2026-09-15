import 'package:flutter/material.dart';

import '../screens/attendance.dart';
import '../screens/catalog.dart';
import '../screens/comms.dart';
import '../screens/dashboard.dart';
import '../screens/evaluations.dart';
import '../screens/finance.dart';
import '../screens/overtime.dart';
import '../screens/people.dart';
import '../screens/performance.dart';
import '../screens/reports.dart';
import '../screens/sessions.dart';
import '../screens/settings.dart';
import 'app_permissions.dart';

// ─────────────────────────────────────────────
//  DESTINATIONS — صفحات اللوحة
//
//  One list drives both the sidebar and the
//  PageView, so the two cannot drift out of index
//  step when a page is hidden by permission.
//
//  A page whose permission the account does not
//  hold is not built at all — hiding the entry
//  while leaving the page reachable would just
//  move the failure to a 403 on load.
// ─────────────────────────────────────────────

enum DestinationId {
  dashboard,
  people,
  evaluations,
  catalog,
  sessions,
  attendance,
  overtime,
  performance,
  finance,
  reports,
  comms,
  settings,
}

class AppDestination {
  final DestinationId id;
  final IconData icon;
  final String label;

  /// Whether the signed-in account may open this page. Evaluated fresh on
  /// every build, so a role change takes effect without a restart.
  final bool Function() isVisible;
  final Widget Function() build;

  const AppDestination({
    required this.id,
    required this.icon,
    required this.label,
    required this.isVisible,
    required this.build,
  });
}

// ─────────────────────────────────────────────
//  SECTIONS — أقسام القائمة الجانبية
//
//  Grouped by the job being done, not the data
//  model: HR is one person's day (clock-in,
//  overtime, pay), the academy is what is offered
//  and when it meets.
// ─────────────────────────────────────────────

class NavSection {
  final String label;
  final IconData icon;
  final List<DestinationId> children;

  const NavSection({
    required this.label,
    required this.icon,
    required this.children,
  });
}

/// One page in the sidebar, pointing at its index in [AppDestinations.visible].
class NavItem {
  final int index;
  final IconData icon;
  final String label;

  const NavItem({required this.index, required this.icon, required this.label});
}

/// A section after permission filtering. Never empty.
class NavSectionEntry {
  final String label;
  final IconData icon;
  final List<NavItem> items;

  const NavSectionEntry({
    required this.label,
    required this.icon,
    required this.items,
  });
}

class AppDestinations {
  AppDestinations._();

  static final List<AppDestination> all = [
    AppDestination(
      id: DestinationId.dashboard,
      icon: Icons.space_dashboard_rounded,
      label: 'الرئيسية',
      isVisible: () => Permissions.canSeeDashboard,
      build: () => const DashboardScreen(),
    ),
    AppDestination(
      id: DestinationId.people,
      icon: Icons.people_alt_rounded,
      label: 'الأفراد',
      isVisible: () => Permissions.canSeePeople,
      build: () => const PeopleScreen(),
    ),
    AppDestination(
      id: DestinationId.evaluations,
      icon: Icons.star_rate_rounded,
      label: 'التقييمات',
      isVisible: () => Permissions.canSeeEvaluations,
      build: () => const EvaluationsScreen(),
    ),
    AppDestination(
      id: DestinationId.catalog,
      icon: Icons.card_membership_rounded,
      label: 'الباقات والرياضات',
      isVisible: () => Permissions.canSeeCatalog,
      build: () => const CatalogScreen(),
    ),
    AppDestination(
      id: DestinationId.sessions,
      icon: Icons.event_note_rounded,
      label: 'الحصص',
      isVisible: () => Permissions.canSeeSessions,
      build: () => const SessionsScreen(),
    ),
    AppDestination(
      id: DestinationId.attendance,
      icon: Icons.where_to_vote_rounded,
      label: 'حضور الموظفين',
      isVisible: () => Permissions.canSeeHr,
      build: () => const AttendanceScreen(),
    ),
    AppDestination(
      id: DestinationId.overtime,
      icon: Icons.more_time_rounded,
      label: 'الساعات الإضافية',
      isVisible: () => Permissions.canSeeHr,
      build: () => const OvertimeScreen(),
    ),
    AppDestination(
      id: DestinationId.performance,
      icon: Icons.insights_rounded,
      label: 'الأداء والرواتب',
      isVisible: () => Permissions.canSeePerformance,
      build: () => const PerformanceScreen(),
    ),
    AppDestination(
      id: DestinationId.finance,
      icon: Icons.payments_rounded,
      label: 'المالية',
      isVisible: () => Permissions.canSeeFinance,
      build: () => const FinanceScreen(),
    ),
    AppDestination(
      id: DestinationId.reports,
      icon: Icons.query_stats_rounded,
      label: 'التقارير',
      isVisible: () => Permissions.canSeeReports,
      build: () => const ReportsScreen(),
    ),
    AppDestination(
      id: DestinationId.comms,
      icon: Icons.campaign_rounded,
      label: 'المراسلات',
      isVisible: () => Permissions.canSeeComms,
      build: () => const CommsScreen(),
    ),
    AppDestination(
      id: DestinationId.settings,
      icon: Icons.shield_rounded,
      label: 'الأدوار والصلاحيات',
      isVisible: () => Permissions.canSeeRoles || Permissions.canSeeAudit,
      build: () => const SettingsScreen(),
    ),
  ];

  static const List<NavSection> sections = [
    NavSection(
      label: 'الرئيسية',
      icon: Icons.home_rounded,
      children: [DestinationId.dashboard],
    ),
    NavSection(
      label: 'الأفراد',
      icon: Icons.groups_rounded,
      children: [DestinationId.people, DestinationId.evaluations],
    ),
    NavSection(
      label: 'الأكاديمية',
      icon: Icons.sports_soccer_rounded,
      children: [DestinationId.catalog, DestinationId.sessions],
    ),
    NavSection(
      label: 'الموارد البشرية',
      icon: Icons.badge_rounded,
      children: [
        DestinationId.attendance,
        DestinationId.overtime,
        DestinationId.performance,
      ],
    ),
    NavSection(
      label: 'المالية والتقارير',
      icon: Icons.account_balance_wallet_rounded,
      children: [DestinationId.finance, DestinationId.reports],
    ),
    NavSection(
      label: 'الإدارة',
      icon: Icons.admin_panel_settings_rounded,
      children: [DestinationId.comms, DestinationId.settings],
    ),
  ];

  /// The destinations this account may open, in sidebar order.
  static List<AppDestination> visible() =>
      all.where((d) => d.isVisible()).toList();

  /// The sidebar's sections after permission filtering. A section whose pages
  /// are all hidden disappears; a page no section names is appended under
  /// "أخرى" rather than silently dropped.
  static List<NavSectionEntry> navSections() {
    final shown = visible();
    final out = <NavSectionEntry>[];
    final placed = <DestinationId>{};

    for (final section in sections) {
      final items = <NavItem>[];
      for (final id in section.children) {
        placed.add(id);
        final index = shown.indexWhere((d) => d.id == id);
        if (index < 0) continue;
        items.add(
          NavItem(index: index, icon: shown[index].icon, label: shown[index].label),
        );
      }
      if (items.isNotEmpty) {
        out.add(NavSectionEntry(label: section.label, icon: section.icon, items: items));
      }
    }

    final rest = [
      for (var i = 0; i < shown.length; i++)
        if (!placed.contains(shown[i].id))
          NavItem(index: i, icon: shown[i].icon, label: shown[i].label),
    ];
    if (rest.isNotEmpty) {
      out.add(NavSectionEntry(label: 'أخرى', icon: Icons.more_horiz_rounded, items: rest));
    }

    return out;
  }

  /// Where [id] sits in the *visible* list, or -1 when it is hidden. Screens
  /// jump between pages by id because the index depends on what the account
  /// can see.
  static int indexOf(DestinationId id) =>
      visible().indexWhere((d) => d.id == id);
}
