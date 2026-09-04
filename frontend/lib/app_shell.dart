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

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onOpenTab: _select),
      const PanchangScreen(),
      const MyChartScreen(),
      const AskJayScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
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
                onFoundations: () => goToCosmicFoundations(context),
                onBell: () => pushScreen(context, NotificationsScreen.new),
                onAvatar: () => _select(4),
              ),
            ),
            if (_index == 0)
              Positioned(
                right: 15,
                bottom: kBottomNavHeight +
                    MediaQuery.paddingOf(context).bottom +
                    18,
                child: _HomeFab(onTap: () => _select(3)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _index, onTap: _select),
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
          child: SvgIcon(Assets.iconFab,
              width: 20, height: 20, color: AppColors.textOnGold),
        ),
      ),
    );
  }
}
