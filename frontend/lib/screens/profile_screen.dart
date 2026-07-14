import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../nav.dart';

// Figma node 1:397 — Profile tab ("Cosmic Identity"). Mock data inline.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _midnight = true; // Midnight Interface toggle (ON in design)

  // Figma asset hashes (already downloaded to assets/figma/).
  static const _badge = 'e80b18a4357c34fb7ef9d784ffdb9fd09bc69f0b.svg';
  static const _pencil = '886850b078134c9b8ae9ce201d82a869e8c8f2f9.svg';
  static const _moon = '22d29c31a70b0fb74b73605430ebb2d05311368d.svg';
  static const _bell = '03f2afc3d9eee530098fc24f30074b64e0a7359d.svg';
  static const _globe = 'd3c89ffb0ca10903a70d11b119aff787da10b7e7.svg';
  static const _shield = '6f429ace2c21e13233e1fcb115b790a320d63ccd.svg';
  static const _chevron = 'c28676dbdebabd45a223947f18fdeee4acc0cf0b.svg';
  static const _map = '10eb677e2022303a2d9ca18587fd944068344b9a.png';

  @override
  Widget build(BuildContext context) {
    return CosmicScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero title ──────────────────────────────────────────────
          Text(
            'Cosmic Identity',
            style: AppText.serif(
              size: 40,
              weight: FontWeight.w600,
              color: AppColors.gold,
              height: 1.2,
              letterSpacing: -0.48,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Manage your celestial coordinates and subscription tier to '
            'maintain alignment with the universal traffic flow.',
            style: AppText.sans(
                size: 16, color: AppColors.textTan, height: 24 / 16),
          ),
          const SizedBox(height: AppSpacing.section),

          // ── Subscription card ───────────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('ACTIVE PLAN',
                              color: AppColors.gold),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Saga+ Monthly',
                              style: AppText.serif(
                                  size: 26,
                                  weight: FontWeight.w500,
                                  color: AppColors.textOnLight,
                                  height: 1.3)),
                        ],
                      ),
                    ),
                    const SvgIcon(_badge,
                        width: 33, height: 31.5, color: AppColors.gold),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Access to deep-space transits, unlimited daily Panchang '
                  'insights, and direct frequency with Jay.',
                  style: AppText.sans(
                      size: 15, color: AppColors.textTan, height: 24 / 16),
                ),
                const SizedBox(height: AppSpacing.xl),
                GoldButton(
                    label: 'MANAGE PLAN',
                    onPressed: () => goToSubscription(context)),
                const SizedBox(height: AppSpacing.lg),
                GoldButton(
                    label: 'VIEW HISTORY',
                    outlined: true,
                    onPressed: () => goToSubscription(context)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),

          // ── Birth Artifacts card ────────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Birth Artifacts', style: AppText.headingSerif),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => goToEditBirthData(context),
                      child: Row(
                        children: [
                          const SvgIcon(_pencil,
                              width: 11, height: 11, color: AppColors.gold),
                          const SizedBox(width: AppSpacing.sm),
                          Text('EDIT DATA',
                              style: AppText.sans(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: AppColors.gold,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                _field('SOLAR DATE', 'October 24, 1988'),
                const SizedBox(height: AppSpacing.lg),
                _field('CELESTIAL TIME', '04:42 AM'),
                const SizedBox(height: AppSpacing.lg),
                _field('GEOGRAPHIC ORIGIN', 'Mumbai, Maharashtra, India'),
                const SizedBox(height: AppSpacing.xxl),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.surfaceRaised2),
                    ),
                    child: Opacity(
                      opacity: 0.85,
                      child: Image.asset(figmaAsset(_map), fit: BoxFit.cover),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),

          // ── System Preferences card ─────────────────────────────────
          _card(
            fillOpacity: 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('System Preferences', style: AppText.headingSerif),
                const SizedBox(height: AppSpacing.xxl),
                _prefRow(
                  icon: _moon,
                  iconColor: AppColors.amber,
                  title: 'Midnight Interface',
                  subtitle: 'Default dark cosmic view',
                  trailing: _switch(),
                ),
                _divider(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => goToNotificationPrefs(context),
                  child: _prefRow(
                    icon: _bell,
                    title: 'Aura Alerts',
                    subtitle: 'Push notifications for transits',
                    trailing: const SvgIcon(_chevron,
                        width: 7.4, height: 12, color: AppColors.textMuted),
                  ),
                ),
                _divider(),
                _prefRow(
                  icon: _globe,
                  title: 'Dialect',
                  subtitle: 'English (Global)',
                  trailing: const SvgIcon(_chevron,
                      width: 7.4, height: 12, color: AppColors.textMuted),
                ),
                _divider(),
                _prefRow(
                  icon: _shield,
                  title: 'Data Crypts',
                  subtitle: 'Privacy and security settings',
                  trailing: const SvgIcon(_chevron,
                      width: 7.4, height: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.section),
                _logoutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card matching Figma #2b346b surface, #374182 border, radius 8, pad 24.
  Widget _card({required Widget child, double fillOpacity = 0.55}) => GlassCard(
        radius: AppRadius.sm,
        fill: AppColors.surfaceRaised,
        fillOpacity: fillOpacity,
        borderColor: AppColors.surfaceRaised2,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: child,
      );

  // Labelled value with a 2px bottom rule (Birth Artifacts).
  Widget _field(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  color: AppColors.textTan,
                  letterSpacing: 0.5)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 4, bottom: AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(
                bottom:
                    BorderSide(color: AppColors.surfaceRaised2, width: 2),
              ),
            ),
            child: Text(value,
                style: AppText.sans(size: 16, color: AppColors.textOnLight)),
          ),
        ],
      );

  Widget _prefRow({
    required String icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    Color iconColor = AppColors.textTan,
  }) =>
      Row(
        children: [
          SizedBox(
            width: 20,
            child: Center(
                child: SvgIcon(icon, width: 18, height: 18, color: iconColor)),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.sans(
                        size: 16, color: AppColors.textOnLight)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppText.sans(
                        size: 12, color: AppColors.textTan, height: 16 / 12)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          trailing,
        ],
      );

  Widget _divider() => Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        height: 1,
        width: double.infinity,
        color: AppColors.surfaceRaised2,
      );

  Widget _switch() => GestureDetector(
        onTap: () => setState(() => _midnight = !_midnight),
        child: Container(
          width: 48,
          height: 24,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color:
                _midnight ? AppColors.gold : AppColors.surfaceRaised2,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 150),
            alignment:
                _midnight ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color:
                    _midnight ? AppColors.navBarBase : AppColors.textTan,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );

  Widget _logoutButton() => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => goToLogin(context),
        child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(
              color: AppColors.criticalText.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Center(
          child: Text('LOG OUT FROM THE COSMOS',
              style: AppText.sans(
                  size: 14,
                  color: AppColors.criticalText.withValues(alpha: 0.6),
                  letterSpacing: 0.5)),
        ),
      ));
}
