import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_assets.dart';
import 'app_widgets.dart';

const double kTopBarHeight = 56;

/// Frosted top app bar shown on the five main tabs:
/// hamburger • Traffic Jam logo+wordmark • bell.
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, this.onMenu, this.onBell});

  final VoidCallback? onMenu;
  final VoidCallback? onBell;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          height: kTopBarHeight + topInset,
          padding: EdgeInsets.only(top: topInset, left: AppSpacing.screenH, right: AppSpacing.screenH),
          decoration: BoxDecoration(
            color: AppColors.navBarBase.withValues(alpha: 0.8),
            border: const Border(
              bottom: BorderSide(color: AppColors.goldBorderSoft),
            ),
          ),
          // A Stack, not a Row: the title is centred against the BAR, not
          // against the space left between the icons. In a Row it would drift
          // whenever the trailing icons changed width — and the About Jay
          // avatar is a different width depending on whether a photo has been
          // uploaded, which would visibly shift the title.
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(figmaAsset(Assets.logo), width: 28, height: 28),
                  const SizedBox(width: AppSpacing.sm),
                  Text('TrafficJam.Life',
                      style: AppText.logoFont(size: 24, letterSpacing: 0.4)),
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: onMenu,
                    behavior: HitTestBehavior.opaque,
                    child: const SvgIcon(Assets.iconMenu,
                        width: 18, height: 12, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onBell,
                    behavior: HitTestBehavior.opaque,
                    child: const SvgIcon(Assets.iconBell,
                        width: 13.3, height: 16.7, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
