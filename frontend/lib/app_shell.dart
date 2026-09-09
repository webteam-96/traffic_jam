import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'theme/app_assets.dart';
import 'widgets/widgets.dart';
import 'nav.dart';
import 'screens/home_screen.dart';
import 'screens/panchang_screen.dart';
import 'screens/my_chart_screen.dart';
import 'screens/ask_jay_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';

/// Root tab container: frosted top bar + 5-tab bottom nav + Home FAB.
/// Individual tab screens return only their scrollable body (CosmicScrollView).
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Tabs visited before the current one. The five tabs live in an IndexedStack
  /// rather than on the Navigator, so without this the system back button had
  /// nothing to pop from a tab screen and closed the app outright — switching
  /// from Home to Panchang to My Chart and pressing back quit, instead of
  /// retracing those steps.
  final List<int> _tabHistory = [];

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _tabHistory.add(_index);
      _index = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onOpenTab: _select),
      const PanchangScreen(),
      const MyChartScreen(),
      const AskJayScreen(),
      const ProfileScreen(),
    ];
    return PopScope(
      // Only let the pop through (closing the app) once there's no tab left to
      // go back to.
      canPop: _tabHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _tabHistory.isEmpty) return;
        setState(() => _index = _tabHistory.removeLast());
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        extendBody: true,
        extendBodyBehindAppBar: true,
        drawer: const AppNavDrawer(),
        body: CosmicBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(index: _index, children: screens),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppTopBar(
                  onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  onBell: () => pushScreen(context, NotificationsScreen.new),
                ),
              ),
              if (_index == 0)
                Positioned(
                  right: 15,
                  bottom:
                      kBottomNavHeight +
                      MediaQuery.paddingOf(context).bottom +
                      18,
                  child: _HomeFab(onTap: () => _select(3)),
                ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNav(currentIndex: _index, onTap: _select),
      ),
    );
  }
}

class _HomeFab extends StatelessWidget {
  const _HomeFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 15,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: SvgIcon(
            Assets.iconFab,
            width: 20,
            height: 20,
            color: AppColors.textOnGold,
          ),
        ),
      ),
    );
  }
}
