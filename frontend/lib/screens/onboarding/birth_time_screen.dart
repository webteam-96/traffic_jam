import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';
import 'package:traffic_jam/models/onboarding_data.dart';

/// Onboarding step 2 of 4 — birth time. Pushed screen (DetailScaffold).
class BirthTimeScreen extends StatefulWidget {
  const BirthTimeScreen({super.key});

  @override
  State<BirthTimeScreen> createState() => _BirthTimeScreenState();
}

class _BirthTimeScreenState extends State<BirthTimeScreen> {
  TimeOfDay _tob = TimeOfDay(hour: OnboardingData.hour24, minute: OnboardingData.minute);
  bool _unknown = OnboardingData.unknownTime;

  void _continue(BuildContext context) {
    OnboardingData.hour24 = _tob.hour;
    OnboardingData.minute = _tob.minute;
    OnboardingData.unknownTime = _unknown;
    goToBirthPlace(context);
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Birth Time',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 2 of 4 progress.
          const SectionLabel('STEP 2 OF 4'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (int i = 0; i < 4; i++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < 2
                          ? AppColors.gold
                          : AppColors.borderSoft.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                if (i < 3) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.section),

          Text('When were you born?',
              style: AppText.serif(size: 28, weight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your exact birth time sharpens the reading — even a few minutes '
            'shifts the ascendant.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.xl),

          Opacity(
            opacity: _unknown ? 0.4 : 1,
            child: BirthTimeField(
              time: _tob,
              enabled: !_unknown,
              onChanged: (t) => setState(() => _tob = t),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // "I don't know my birth time" toggle.
          GlassCard(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text("I don't know my birth time",
                      style: AppText.cardTitle),
                ),
                Switch(
                  value: _unknown,
                  onChanged: (v) => setState(() => _unknown = v),
                  activeThumbColor: AppColors.textOnGold,
                  activeTrackColor: AppColors.gold,
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.surfaceRaised,
                ),
              ],
            ),
          ),
          if (_unknown) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.nightlight_round,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    "We'll use a Moon-sign based reading.",
                    style: AppText.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.section),

          GoldButton(
            label: 'CONTINUE',
            icon: Icons.arrow_forward,
            onPressed: () => _continue(context),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
