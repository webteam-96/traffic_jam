import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../models/kundli_profile.dart';
import '../details/kundli_screen.dart';
import 'get_kundli_screen.dart';

/// Kundli landing — Business Flow §5.1. Two entry cards (My Kundli / Get
/// Kundli) plus the list of Kundlis already generated for family/friends.
/// Reached from the Home "Kundli" quick-access card and the nav drawer.
class KundliLandingScreen extends StatelessWidget {
  const KundliLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Kundli',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Birth Charts',
              style: AppText.serif(size: 28, weight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'View your own chart, or generate one for family and friends.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.section),
          Row(
            children: [
              Expanded(
                child: _EntryCard(
                  icon: Icons.self_improvement,
                  title: 'My Kundli',
                  subtitle: 'Your own birth chart',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const KundliScreen()),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _EntryCard(
                  icon: Icons.person_add_alt,
                  title: 'Get Kundli',
                  subtitle: 'Generate a new chart',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GetKundliScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionLabel('SAVED KUNDLIS'),
          const SizedBox(height: AppSpacing.md),
          ValueListenableBuilder<List<KundliProfile>>(
            valueListenable: KundliStore.saved,
            builder: (context, saved, _) {
              if (saved.isEmpty) {
                return GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Center(
                    child: Text(
                      'Charts you generate for family or friends will appear '
                      'here. Long-press one to remove it.',
                      textAlign: TextAlign.center,
                      style: AppText.sans(size: 13, color: AppColors.textMuted, height: 1.5),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final p in saved) ...[
                    _SavedKundliRow(profile: p),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      goldTopBorder: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(
            size: 44,
            glow: true,
            child: Icon(icon, size: 20, color: AppColors.gold),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppText.serif(size: 18, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppText.sans(size: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _SavedKundliRow extends StatelessWidget {
  const _SavedKundliRow({required this.profile});
  final KundliProfile profile;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => KundliScreen(profile: profile)),
      ),
      onLongPress: () => _confirmDelete(context),
      child: Row(
        children: [
          IconChip(child: const Icon(Icons.person_outline, size: 18, color: AppColors.gold)),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name, style: AppText.cardTitle),
                const SizedBox(height: 2),
                Text('Generated ${profile.generatedOn}',
                    style: AppText.sans(size: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.navBarBase,
        title: Text('Remove ${profile.name}\'s Kundli?',
            style: AppText.serif(size: 18, color: AppColors.textPrimary)),
        content: Text(
          'This chart will be removed from your saved list. You can generate it again later.',
          style: AppText.sans(size: 13, color: AppColors.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('CANCEL', style: AppText.sans(size: 13, color: AppColors.textTan)),
          ),
          TextButton(
            onPressed: () {
              KundliStore.remove(profile);
              Navigator.of(dialogContext).pop();
            },
            child: Text('REMOVE',
                style: AppText.sans(
                    size: 13, weight: FontWeight.w700, color: AppColors.criticalText)),
          ),
        ],
      ),
    );
  }
}
