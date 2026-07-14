import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Subscription / paywall — three plan cards with a selected-plan state.
/// Pushed screen, so it roots in DetailScaffold.
/// ponytail: plans are mocked const data; wire to a billing SDK + real prices
/// when the store integration exists.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  static const _plans = <_Plan>[
    _Plan(
      name: 'Free',
      price: '₹0',
      period: 'forever',
      badge: 'CURRENT',
      features: [
        'Daily traffic signal',
        'Basic Panchang',
        'One saved birth chart',
      ],
    ),
    _Plan(
      name: 'Saga+ Monthly',
      price: '₹499',
      period: '/mo',
      badge: 'POPULAR',
      popular: true,
      features: [
        'Unlimited chart readings',
        'Live Rahu Kaal alerts',
        'Ask Jay — priority answers',
        'Full Dasha & transit timeline',
      ],
    ),
    _Plan(
      name: 'Annual',
      price: '₹3,999',
      period: '/yr',
      note: 'Save 33% vs monthly',
      features: [
        'Everything in Saga+ Monthly',
        'Two months free',
        'Yearly remedy roadmap',
        'Early access to new features',
      ],
    ),
  ];

  // Default to the popular monthly plan.
  int _selected = 1;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Go Premium',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Unlock the full cosmos', style: AppText.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Every window, every warning, every remedy — timed to your chart. '
            'Upgrade to Saga+ and never miss your moment.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionLabel('CHOOSE YOUR PLAN'),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < _plans.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _PlanCard(
              plan: _plans[i],
              selected: i == _selected,
              onTap: () => setState(() => _selected = i),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          GoldButton(
            label: 'UPGRADE TO SAGA+',
            icon: Icons.auto_awesome,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Starting checkout for ${_plans[_selected].name}'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              'Cancel anytime · Restore purchases',
              style: AppText.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _Plan {
  const _Plan({
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    this.badge,
    this.note,
    this.popular = false,
  });

  final String name;
  final String price;
  final String period;
  final List<String> features;
  final String? badge;
  final String? note;
  final bool popular;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final _Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      goldTopBorder: plan.popular,
      borderColor: selected ? AppColors.gold : AppColors.borderFaint,
      fillOpacity: selected ? 0.5 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.gold : AppColors.textMuted,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(plan.name, style: AppText.cardTitle)),
              if (plan.badge != null) _Badge(plan.badge!, current: !plan.popular),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(plan.price, style: AppText.serifValue),
              const SizedBox(width: AppSpacing.xs),
              Text(plan.period, style: AppText.bodySmall),
            ],
          ),
          if (plan.note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(plan.note!, style: AppText.bodySmall.copyWith(color: AppColors.success)),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, thickness: 1, color: AppColors.borderFaint),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < plan.features.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Text(plan.features[i], style: AppText.bodySmall)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {this.current = false});
  final String text;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = current ? AppColors.textMuted : AppColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: AppText.sans(
            size: 10, weight: FontWeight.w700, color: color, letterSpacing: 0.8),
      ),
    );
  }
}
