import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_top_bar.dart';
import 'bottom_nav_bar.dart';
import 'cosmic_background.dart';

/// Scroll wrapper for the five MAIN TAB screens. Applies horizontal screen
/// padding + top/bottom insets so content clears the frosted app bar & nav.
/// Tab screens return `CosmicScrollView(child: Column(...))` — nothing more.
class CosmicScrollView extends StatelessWidget {
  const CosmicScrollView({
    super.key,
    required this.child,
    this.topExtra = AppSpacing.xxl,
    this.bottomExtra = AppSpacing.xxl,
    this.horizontal = AppSpacing.screenH,
  });

  final Widget child;
  final double topExtra;
  final double bottomExtra;
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    final top = kTopBarHeight + MediaQuery.paddingOf(context).top + topExtra;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        top,
        horizontal,
        kBottomNavHeight + bottomExtra,
      ),
      child: child,
    );
  }
}

/// Scaffold for PUSHED (non-tab) screens: cosmic bg + frosted back bar + body.
/// Use for onboarding, auth, detail, remedies, etc.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.showBack = true,
    this.scrollable = true,
    this.padded = true,
    this.bottomBar,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showBack;
  final bool scrollable;
  final bool padded;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    Widget body = child;
    if (padded) {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: body,
      );
    }
    if (scrollable) {
      body = SingleChildScrollView(
        padding: EdgeInsets.only(
          top: kTopBarHeight + topInset + AppSpacing.lg,
          bottom: AppSpacing.section,
        ),
        child: body,
      );
    } else {
      body = Padding(
        padding: EdgeInsets.only(top: kTopBarHeight + topInset),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: CosmicBackground(
        child: Stack(
          children: [
            Positioned.fill(child: body),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _BackBar(title: title, actions: actions, showBack: showBack),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

class _BackBar extends StatelessWidget {
  const _BackBar({this.title, this.actions, this.showBack = true});
  final String? title;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          height: kTopBarHeight + topInset,
          padding: EdgeInsets.only(
              top: topInset, left: AppSpacing.sm, right: AppSpacing.screenH),
          decoration: BoxDecoration(
            color: AppColors.navBarBase.withValues(alpha: 0.8),
            border: const Border(
                bottom: BorderSide(color: AppColors.goldBorderSoft)),
          ),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new,
                      size: 18, color: AppColors.textPrimary),
                )
              else
                const SizedBox(width: AppSpacing.md),
              if (title != null)
                Expanded(
                  child: Text(title!,
                      style: AppText.serif(size: 20, weight: FontWeight.w700)),
                )
              else
                const Spacer(),
              ...?actions,
            ],
          ),
        ),
      ),
    );
  }
}
