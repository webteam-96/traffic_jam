import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// PUSHED screen — history of questions the user asked Jay.
/// Static list; no interactivity required, so StatelessWidget. (ponytail)
class MyQuestionsScreen extends StatelessWidget {
  const MyQuestionsScreen({super.key});

  // Mock history — inline const, no backend.
  static const List<({String q, String cat, bool answered, String time})>
      _items = [
    (
      q: 'Will this be a good year to switch jobs, or should I hold my current role a while longer?',
      cat: 'Career',
      answered: true,
      time: '2h ago',
    ),
    (
      q: 'Is it a favourable time to invest in property before the next lunar cycle?',
      cat: 'Finance',
      answered: true,
      time: 'Yesterday',
    ),
    (
      q: 'What remedies help with the recurring health issues in my sixth house?',
      cat: 'Health',
      answered: false,
      time: '2 days ago',
    ),
    (
      q: 'Should I start my new business venture during the upcoming Jupiter transit?',
      cat: 'Career',
      answered: true,
      time: 'Last week',
    ),
    (
      q: 'When will my financial situation stabilise according to my current dasha?',
      cat: 'Finance',
      answered: false,
      time: 'Last week',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final answered = _items.where((e) => e.answered).length;
    return DetailScaffold(
      title: 'My Questions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Your History'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_items.length} asked · $answered answered',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final item in _items) ...[
            _QuestionCard(item: item),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.item});
  final ({String q, String cat, bool answered, String time}) item;

  static const _catIcons = {
    'Career': Icons.work_outline,
    'Finance': Icons.savings_outlined,
    'Health': Icons.favorite_border,
  };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryChip(
                label: item.cat,
                icon: _catIcons[item.cat] ?? Icons.help_outline,
              ),
              const Spacer(),
              _StatusChip(answered: item.answered),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            item.q,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.serif(
              size: 16,
              height: 1.35,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.schedule, size: 13, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.xs),
              Text(item.time, style: AppText.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.goldBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.gold),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppText.sans(
              size: 12,
              weight: FontWeight.w500,
              color: AppColors.goldLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.answered});
  final bool answered;

  @override
  Widget build(BuildContext context) {
    final color = answered ? AppColors.gold : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          answered ? Icons.check_circle_outline : Icons.hourglass_empty,
          size: 13,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          answered ? 'Answered' : 'Pending',
          style: AppText.sans(
            size: 12,
            weight: FontWeight.w600,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
