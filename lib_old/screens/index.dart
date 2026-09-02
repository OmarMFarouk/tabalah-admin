import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/app_bloc/cubit.dart';
import '../blocs/base_states.dart';
import '../components/index/appbar.dart';
import '../src/app_colors.dart';
import 'catalog.dart';
import 'comms.dart';
import 'dashboard.dart';
import 'finance.dart';
import 'people.dart';
import 'performance.dart';
import 'sessions.dart';

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

  static final List<Widget> _pages = [
    const DashboardScreen(),
    const PeopleScreen(),
    const CatalogScreen(),
    const SessionsScreen(),
    const FinanceScreen(),
    const PerformanceScreen(),
    const CommsScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
            MyAppBar(currentPage: _currentPage, onChanged: _goTo),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GlobalColors.bg(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: GlobalColors.border(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
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
                    children: _pages,
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
