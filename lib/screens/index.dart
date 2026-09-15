import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/app_bloc/cubit.dart';
import '../blocs/base_states.dart';
import '../components/index/appbar.dart';
import '../components/index/sidebar.dart';
import '../src/app_colors.dart';
import '../src/app_destinations.dart';

// ─────────────────────────────────────────────
//  MAIN DASHBOARD — الهيكل الرئيسي
//  Title bar across the top, the sidebar on the
//  right, the page beside it. Pages are kept alive
//  so a filter survives a trip elsewhere and back.
// ─────────────────────────────────────────────

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  /// Resolved once per build from the account's permissions. The sidebar and
  /// the PageView read this same list, so their indices cannot drift apart.
  List<AppDestination> get _destinations => AppDestinations.visible();

  @override
  void initState() {
    super.initState();
    // Let screens inside the shell request a page (dashboard quick actions).
    // By id, not index: which index a page sits at depends on what this
    // account can see.
    AppCubit.tabRequestHandler = _goToId;
  }

  @override
  void dispose() {
    AppCubit.tabRequestHandler = null;
    _pageController.dispose();
    super.dispose();
  }

  void _goToId(DestinationId id) {
    final index = AppDestinations.indexOf(id);
    if (index < 0) return;
    _goTo(index);
  }

  void _goTo(int page) {
    setState(() => _currentPage = page);
    // Long jumps skip the animation so the pages between don't flash past.
    _pageController.animateToPage(
      page,
      duration: Duration(
        milliseconds: (page - (_pageController.page?.round() ?? 0)).abs() > 1 ? 1 : 260,
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
            const MyAppBar(),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSidebar(currentPage: _currentPage, onChanged: _goTo),
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
            ),
          ],
        ),
      ),
    );
  }
}
