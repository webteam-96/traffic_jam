import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/services/subscription_api.dart';
import 'package:traffic_jam/services/api_client.dart';
import 'package:traffic_jam/nav.dart';

/// Subscription / paywall — plan cards fetched from the real Subscription
/// Service, with the user's current tier highlighted as CURRENT.
/// Checkout surfaces a friendly message until a payment gateway is wired up.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<Map<String, dynamic>> _plans = [];
  String? _currentTier;
  String? _currentCycle;
  int _selected = 0;
  bool _loading = true;
  bool _errored = false;
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SubscriptionApi.getPlans(),
        SubscriptionApi.getSubscription(),
      ]);
      if (!mounted) return;
      final plans = results[0] as List<Map<String, dynamic>>;
      final current = results[1] as Map<String, dynamic>;
      setState(() {
        _plans = plans;
        _currentTier = current['tier'] as String?;
        _currentCycle = current['cycle'] as String?;
        _selected = _defaultSelection(plans);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errored = true;
      });
    }
  }

  int _defaultSelection(List<Map<String, dynamic>> plans) {
    // Prefer the popular "Saga+ Monthly" plan; fall back to the first entry.
    final i = plans.indexWhere((p) => p['id'] == 'saga_plus_monthly');
    return i >= 0 ? i : 0;
  }

  // The Free tier has no real billing cycle (the backend's Subscription
  // record always carries a technical Monthly/Yearly default even when the
  // tier is Free) — so match on tier alone there, and tier+cycle otherwise.
  bool _isCurrent(Map<String, dynamic> plan) {
    if (plan['tier'] != _currentTier) return false;
    if (plan['tier'] == 'Free') return true;
    return plan['cycle'] == _currentCycle;
  }

  Future<void> _upgrade() async {
    final plan = _plans[_selected];
    if (_isCurrent(plan)) {
      toast(context, 'This is already your current plan');
      return;
    }
    setState(() => _checkingOut = true);
    try {
      await SubscriptionApi.checkout(plan['id'] as String);
      if (!mounted) return;
      toast(context, 'Checkout started for ${plan['name']}');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'PAYMENTS_NOT_CONFIGURED') {
        toast(context, 'Payments are coming soon — checkout isn\'t live yet.');
      } else {
        toast(context, e.message);
      }
    } catch (_) {
      if (!mounted) return;
      toast(context, "Couldn't reach the server — check your connection.");
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DetailScaffold(
        title: 'Go Premium',
        scrollable: false,
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
        ),
      );
    }

    if (_errored) {
      return DetailScaffold(
        title: 'Go Premium',
        scrollable: false,
        child: Center(
          child: Text("Couldn't load plans — check your connection.",
              textAlign: TextAlign.center, style: AppText.body),
        ),
      );
    }

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
              current: _isCurrent(_plans[i]),
              popular: _plans[i]['id'] == 'saga_plus_monthly',
              onTap: () => setState(() => _selected = i),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          GoldButton(
            label: _checkingOut
                ? 'STARTING CHECKOUT…'
                : (_plans.isNotEmpty && _isCurrent(_plans[_selected])
                    ? 'CURRENT PLAN'
                    : 'UPGRADE TO SAGA+'),
            icon: Icons.auto_awesome,
            onPressed: _checkingOut ? null : _upgrade,
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.current,
    required this.popular,
    required this.onTap,
  });

  final Map<String, dynamic> plan;
  final bool selected;
  final bool current;
  final bool popular;
  final VoidCallback onTap;

  String get _price => '₹${plan['priceRupees']}';
  String get _period => switch (plan['cycle']) {
        'Monthly' => '/mo',
        'Yearly' => '/yr',
        _ => 'forever',
      };

  @override
  Widget build(BuildContext context) {
    final features = (plan['features'] as List).cast<String>();
    return GlassCard(
      onTap: onTap,
      goldTopBorder: popular,
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
              Expanded(
                  child: Text(plan['name'] as String, style: AppText.cardTitle)),
              if (current)
                const _Badge('CURRENT', current: true)
              else if (popular)
                const _Badge('POPULAR'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_price, style: AppText.serifValue),
              const SizedBox(width: AppSpacing.xs),
              Text(_period, style: AppText.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, thickness: 1, color: AppColors.borderFaint),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < features.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(features[i], style: AppText.bodySmall)),
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
        gradient: current
            ? null
            : LinearGradient(
                colors: [
                  AppColors.goldLight.withValues(alpha: 0.22),
                  AppColors.goldButton.withValues(alpha: 0.14),
                ],
              ),
        color: current ? color.withValues(alpha: 0.12) : null,
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
