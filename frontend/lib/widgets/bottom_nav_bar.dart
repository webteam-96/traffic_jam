import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_assets.dart';
import 'app_widgets.dart';

const double kBottomNavHeight = 80;

class _NavItem {
  const _NavItem(this.icon, this.label, this.w, this.h);
  final String icon;
  final String label;
  final double w;
  final double h;
}

const List<_NavItem> _navItems = [
  _NavItem(Assets.navHome, 'HOME', 16, 18),
  _NavItem(Assets.navPanchang, 'PANCHANG', 18, 20),
  _NavItem(Assets.navMyChart, 'MY CHART', 22, 18.5),
  _NavItem(Assets.navAskJay, 'ASK JAY', 20, 20),
  _NavItem(Assets.navProfile, 'PROFILE', 16, 16),
];

/// Frosted bottom navigation with 5 tabs. Active = gold icon+label + dot.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sm)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: kBottomNavHeight + bottomInset,
          padding: EdgeInsets.only(bottom: bottomInset, top: 12),
          decoration: BoxDecoration(
            color: AppColors.navBarBase.withValues(alpha: 0.72),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.sm)),
            border: const Border(
              top: BorderSide(color: AppColors.borderFaint),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < _navItems.length; i++)
                _buildItem(context, i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int i) {
    final item = _navItems[i];
    final active = i == currentIndex;
    final color = active ? AppColors.gold : AppColors.textTan;
    return GestureDetector(
      onTap: () => onTap(i),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 20,
            child: Center(
              child: SvgIcon(item.icon, width: item.w, height: item.h, color: color),
            ),
          ),
          const SizedBox(height: 4),
          Text(item.label, style: AppText.navLabel.copyWith(color: color)),
          const SizedBox(height: 4),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: active ? AppColors.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ],
      ),
    );
  }
}
