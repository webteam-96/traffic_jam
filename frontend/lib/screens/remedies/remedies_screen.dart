import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../nav.dart';
import '../../services/remedy_api.dart';

/// Remedies engine — a pushed (non-tab) detail screen. Wired to GET
/// /remedies: general-purpose remedies plus whatever matches the user's
/// current Mahadasha/Antardasha lord (see RemedyEndpoints.cs). Content is
/// standard, classical Vedic practice (mantra/charity/lifestyle) —
/// deliberately no gemstone or medical prescriptions.
class RemediesScreen extends StatefulWidget {
  const RemediesScreen({super.key});

  @override
  State<RemediesScreen> createState() => _RemediesScreenState();
}

class _RemediesScreenState extends State<RemediesScreen> {
  static const _icons = {
    'mantra': Icons.graphic_eq,
    'charity': Icons.volunteer_activism_outlined,
    'lifestyle': Icons.self_improvement,
  };

  List<Map<String, dynamic>>? _remedies;
  bool _loading = true;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    RemedyApi.getRemedies().then((remedies) {
      if (!mounted) return;
      setState(() {
        _remedies = remedies;
        _loading = false;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errored = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Remedies',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('YOUR REMEDIES'),
          const SizedBox(height: AppSpacing.sm),
          Text('Personalised for your current Dasha.', style: AppText.body),
          const SizedBox(height: AppSpacing.section),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
              ),
            )
          else if (_errored || _remedies == null || _remedies!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                'Save your birth data to see your personalised remedies.',
                style: AppText.sans(size: 14, color: AppColors.textMuted),
              ),
            )
          else ...[
            for (final r in _remedies!) ...[
              _remedyCard(r),
              const SizedBox(height: AppSpacing.lg),
            ],
            const SizedBox(height: AppSpacing.md),
            GoldButton(
              label: 'Add all to reminders',
              outlined: true,
              icon: Icons.notifications_none,
              onPressed: () => toast(context, 'All remedies added to reminders'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _remedyCard(Map<String, dynamic> remedy) {
    final type = remedy['type'] as String;
    final trigger = remedy['triggerRule'] as String? ?? 'general';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                  child: Icon(_icons[type] ?? Icons.auto_awesome, size: 20, color: AppColors.gold)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  remedy['title'] as String,
                  style: AppText.serif(size: 18, color: AppColors.textCream, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            remedy['detail'] as String,
            style: AppText.sans(size: 14, color: AppColors.textTan, height: 1.55),
          ),
          const SizedBox(height: AppSpacing.lg),
          _triggerTag(trigger == 'general' ? 'general wellbeing' : 'your $trigger Dasha'),
        ],
      ),
    );
  }

  Widget _triggerTag(String cause) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 13, color: AppColors.amber),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: 'for ',
                style: AppText.sans(size: 12, color: AppColors.textMuted),
                children: [
                  TextSpan(
                    text: cause,
                    style: AppText.sans(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.amber),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
