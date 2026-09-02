import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/app_bloc/cubit.dart';
import '../blocs/base_states.dart';
import '../components/index/appbar.dart';
import '../src/app_colors.dart';
import '../src/app_destinations.dart';

// ─────────────────────────────────────────────
//  MAIN DASHBOARD — الهيكل الرئيسي
//  Pages are kept alive so a filter survives a
//  trip to another tab and back.
// ─────────────────────────────────────────────
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  /// Resolved once per build from the account's permissions. Both the nav
  /// bar and the PageView read this same list, so their indices cannot drift
  /// apart when a page is hidden.
  List<AppDestination> get _destinations => AppDestinations.visible();

  @override
  void initState() {
    super.initState();
    // Let screens inside the shell request a tab (dashboard quick actions).
    // By id, not index: which index "المالية" sits at now depends on which
    // pages this account can see.
    AppCubit.tabRequestHandler = _goToId;
  }

  @override
  void dispose() {
    AppCubit.tabRequestHandler = null;
    _pageController.dispose();
    super.dispose();
  }

  /// Jump to a destination by id, ignoring the request when the account
  /// cannot see that page — better than landing somewhere arbitrary.
  void _goToId(DestinationId id) {
    final index = AppDestinations.indexOf(id);
    if (index < 0) return;
    _goTo(index);
  }

  void _goTo(int page) {
    // Long jumps skip the animation so the pages between don't flash past.
    _pageController.animateToPage(
      page,
      duration: Duration(
        milliseconds: (page - _currentPage).abs() > 1 ? 1 : 300,
      ),
      curve: Curves.fastLinearToSlowEaseIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCubit, AppStates>(
      builder: (context, state) => Scaffold(
        backgroundColor: GlobalColors.bg(context),
        body: Column(
          children: [
            MyAppBar(
              currentPage: _currentPage,
              onChanged: _goTo,
              items: AppDestinations.navEntries(),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GlobalColors.bg(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: GlobalColors.border(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: _destinations.map((d) => d.build()).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
