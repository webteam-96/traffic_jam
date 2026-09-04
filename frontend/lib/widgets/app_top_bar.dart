import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_assets.dart';
import 'app_widgets.dart';

const double kTopBarHeight = 56;

/// Frosted top app bar shown on the five main tabs:
/// hamburger • Traffic Jam logo+wordmark • Cosmic Foundations • bell • avatar.
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, this.onMenu, this.onFoundations, this.onBell, this.onAvatar});

  final VoidCallback? onMenu;
  final VoidCallback? onFoundations;
  final VoidCallback? onBell;
  final VoidCallback? onAvatar;

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
          child: Row(
            children: [
              GestureDetector(
                onTap: onMenu,
                behavior: HitTestBehavior.opaque,
                child: const SvgIcon(Assets.iconMenu,
                    width: 18, height: 12, color: AppColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.lg),
              Image.asset(figmaAsset(Assets.logo), width: 24, height: 24),
              const SizedBox(width: AppSpacing.sm),
              Text('TrafficJam.Life',
                  style: AppText.logoFont(size: 18, letterSpacing: 0.4)),
              const Spacer(),
              GestureDetector(
                onTap: onFoundations,
                behavior: HitTestBehavior.opaque,
                child: const SvgIcon(Assets.iconZodiac,
                    width: 18, height: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.xxl),
              GestureDetector(
                onTap: onBell,
                behavior: HitTestBehavior.opaque,
                child: const SvgIcon(Assets.iconBell,
                    width: 13.3, height: 16.7, color: AppColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.xxl),
              GestureDetector(
                onTap: onAvatar,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.textTan.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        blurRadius: 0,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(figmaAsset(Assets.avatar), fit: BoxFit.cover),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
