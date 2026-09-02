import 'package:flutter/material.dart';

import '../screens/catalog.dart';
import '../screens/comms.dart';
import '../screens/dashboard.dart';
import '../screens/finance.dart';
import '../screens/people.dart';
import '../screens/performance.dart';
import '../screens/reports.dart';
import '../screens/sessions.dart';
import '../screens/settings.dart';
import 'app_permissions.dart';

// ─────────────────────────────────────────────
//  DESTINATIONS — صفحات اللوحة
//
//  One list drives both the nav bar and the
//  PageView, which is the point: they used to be
//  two hard-coded lists that had to stay
//  index-aligned by hand, and a page hidden by
//  permission in one but not the other would have
//  shifted every index after it.
//
//  A page whose `permission` the account does not
//  hold is not built at all — hiding the nav entry
//  while leaving the page reachable would just
//  move the failure to a 403 on load.
// ─────────────────────────────────────────────
enum DestinationId {
  dashboard,
  people,
  catalog,
  sessions,
  finance,
  reports,
  performance,
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
//  NAV GROUPS — تجميع الصفحات في القائمة العلوية
//
//  Nine top-level entries did not fit the bar at
//  1280px and left it scrolling sideways, which is
//  a bad way to find anything. Related pages are
//  gathered under one entry instead, so the bar
//  carries six.
//
//  The grouping is by *question asked*, not by
//  data model: "what do we offer and when does it
//  meet" is one thought, "how are we doing" is
//  another. That is also why التقارير sits with
//  الأداء rather than under المالية — most of it
//  is membership, attendance and trainer load,
//  and only one block is money.
// ─────────────────────────────────────────────
class NavGroup {
  final String label;
  final IconData icon;
  final List<DestinationId> children;

  const NavGroup({
    required this.label,
    required this.icon,
    required this.children,
  });
}

/// One rendered entry in the top bar: either a page, or a menu of pages.
class NavEntry {
  final String label;
  final IconData icon;

  /// Index into [AppDestinations.visible] when this is a single page,
  /// or -1 when it is a menu.
  final int index;

  final List<NavChild> children;

  const NavEntry({
    required this.label,
    required this.icon,
    required this.index,
    this.children = const [],
  });

  bool get isMenu => children.isNotEmpty;
}

class NavChild {
  final int index;
  final IconData icon;
  final String label;

  const NavChild({
    required this.index,
    required this.icon,
    required this.label,
  });
}


class AppDestinations {
  AppDestinations._();

  static final List<AppDestination> all = [
    AppDestination(
      id: DestinationId.dashboard,
      icon: Icons.dashboard_rounded,
      label: 'الرئيسية',
      isVisible: () => Permissions.canSeeDashboard,
      build: () => const DashboardScreen(),
    ),
    AppDestination(
      id: DestinationId.people,
      icon: Icons.people_alt_rounded,
      label: 'الأشخاص',
      isVisible: () => Permissions.canSeePeople,
      build: () => const PeopleScreen(),
    ),
    AppDestination(
      id: DestinationId.catalog,
      icon: Icons.card_membership_rounded,
      label: 'الاشتراكات',
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
      id: DestinationId.performance,
      icon: Icons.insights_rounded,
      label: 'الأداء',
      isVisible: () => Permissions.canSeePerformance,
      build: () => const PerformanceScreen(),
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
      label: 'الصلاحيات',
      isVisible: () =>
          Permissions.canSeeRoles || Permissions.canSeeAudit,
      build: () => const SettingsScreen(),
    ),
  ];

  /// How the top bar gathers those destinations.
  ///
  /// A destination not named here still appears, on its own, in `all` order —
  /// so adding a page and forgetting this list degrades to the old behaviour
  /// rather than hiding it.
  static const List<NavGroup> groups = [
    NavGroup(
      label: 'الرئيسية',
      icon: Icons.dashboard_rounded,
      children: [DestinationId.dashboard],
    ),
    NavGroup(
      label: 'الأشخاص',
      icon: Icons.people_alt_rounded,
      children: [DestinationId.people],
    ),
    NavGroup(
      label: 'النادي',
      icon: Icons.card_membership_rounded,
      children: [DestinationId.catalog, DestinationId.sessions],
    ),
    NavGroup(
      label: 'المالية',
      icon: Icons.payments_rounded,
      children: [DestinationId.finance],
    ),
    NavGroup(
      label: 'التقارير والأداء',
      icon: Icons.query_stats_rounded,
      children: [DestinationId.reports, DestinationId.performance],
    ),
    NavGroup(
      label: 'الإدارة',
      icon: Icons.tune_rounded,
      children: [DestinationId.comms, DestinationId.settings],
    ),
  ];

  /// The destinations this account may open, in nav order.
  static List<AppDestination> visible() =>
      all.where((d) => d.isVisible()).toList();

  /// The top bar's entries, after permission filtering.
  ///
  /// Two rules that matter:
  ///
  /// * A group whose children are all hidden disappears entirely — no empty
  ///   menu to open.
  /// * A group down to **one** visible child renders as a plain item, not a
  ///   menu. A dropdown holding a single entry is two clicks for what should
  ///   be one, and it happens often here: a front-desk account that can see
  ///   المراسلات but not الصلاحيات would otherwise get exactly that.
  static List<NavEntry> navEntries() {
    final shown = visible();
    final entries = <NavEntry>[];
    final grouped = <DestinationId>{};

    for (final group in groups) {
      final children = <NavChild>[];

      for (final id in group.children) {
        grouped.add(id);
        final index = shown.indexWhere((d) => d.id == id);
        if (index < 0) continue;

        final dest = shown[index];
        children.add(
          NavChild(index: index, icon: dest.icon, label: dest.label),
        );
      }

      if (children.isEmpty) continue;

      if (children.length == 1) {
        entries.add(
          NavEntry(
            // Keep the page's own name, not the group's: "النادي" on its own
            // is vaguer than "الحصص" when it is the only thing in there.
            label: children.first.label,
            icon: children.first.icon,
            index: children.first.index,
          ),
        );
      } else {
        entries.add(
          NavEntry(
            label: group.label,
            icon: group.icon,
            index: -1,
            children: children,
          ),
        );
      }
    }

    // Anything the groups forgot, appended rather than dropped.
    for (var i = 0; i < shown.length; i++) {
      if (grouped.contains(shown[i].id)) continue;
      entries.add(
        NavEntry(label: shown[i].label, icon: shown[i].icon, index: i),
      );
    }

    return entries;
  }

  /// Where [id] sits in the *visible* list, or -1 when it is hidden.
  ///
  /// Screens jump between tabs by id rather than by a hard-coded index,
  /// because the index of "المالية" now depends on which pages the account
  /// can see. A -1 means "you cannot go there", and callers skip the jump
  /// rather than landing somewhere arbitrary.
  static int indexOf(DestinationId id) =>
      visible().indexWhere((d) => d.id == id);
}
