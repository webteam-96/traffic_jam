import 'dart:async';

import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';
import 'package:traffic_jam/models/onboarding_data.dart';
import 'package:traffic_jam/services/user_api.dart';

/// Onboarding "calculating" screen — shown while the real chart is computed.
/// Centered gold spinner + serif headline + a themed checklist that advances
/// step by step (check = done, spinner = in progress, ring = pending), while
/// the collected [OnboardingData] is saved via `PUT /me/birth-data` in
/// parallel. Navigates to the shell once both the (cosmetic) checklist and
/// the (real) save have finished; shows a retry state if the save fails.
class CalculatingScreen extends StatefulWidget {
  const CalculatingScreen({super.key});

  @override
  State<CalculatingScreen> createState() => _CalculatingScreenState();
}

class _CalculatingScreenState extends State<CalculatingScreen> {
  static const _steps = <String>[
    'Casting Lagna Kundli',
    'Placing the Moon',
    'Drawing Navamsha (D9)',
    'Computing Vimshottari Dasha',
    'Mapping current transits',
  ];

  int _current = 0;
  Timer? _timer;
  bool _checklistDone = false;
  bool _saveDone = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runSave();
    // Advance through the checklist so check/spinner/ring states are all
    // real — purely cosmetic pacing, independent of the actual save below.
    _timer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (_current >= _steps.length) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          setState(() => _checklistDone = true);
          _maybeProceed();
        });
        return;
      }
      setState(() => _current++);
    });
  }

  Future<void> _runSave() async {
    setState(() => _error = null);
    try {
      await UserApi.saveBirthData(
        name: OnboardingData.name,
        dob: OnboardingData.dob!,
        hour24: OnboardingData.unknownTime ? null : OnboardingData.hour24,
        minute: OnboardingData.unknownTime ? null : OnboardingData.minute,
        unknownTime: OnboardingData.unknownTime,
        place: OnboardingData.place!,
        lat: OnboardingData.lat!,
        lng: OnboardingData.lng!,
        timezone: OnboardingData.timezone!,
      );
      if (!mounted) return;
      setState(() => _saveDone = true);
      _maybeProceed();
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _error = "Couldn't save your birth details — check your connection and try again.");
    }
  }

  void _maybeProceed() {
    if (!_checklistDone || !_saveDone) return;
    OnboardingData.reset();
    goToShell(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return DetailScaffold(
        scrollable: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.criticalText),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: AppText.serif(size: 24, weight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, textAlign: TextAlign.center, style: AppText.body),
                const SizedBox(height: AppSpacing.section),
                GoldButton(
                  label: 'TRY AGAIN',
                  icon: Icons.refresh,
                  onPressed: _runSave,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DetailScaffold(
      scrollable: false,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SectionLabel('CASTING YOUR CHART'),
              const SizedBox(height: AppSpacing.xl),
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppColors.gold),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Reading the stars…',
                textAlign: TextAlign.center,
                style: AppText.serif(size: 28, weight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Aligning your birth chart with the current sky. '
                'This only takes a moment.',
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
              const SizedBox(height: AppSpacing.section),
              GlassCard(
                goldTopBorder: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < _steps.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.lg),
                      _StepRow(
                        label: _steps[i],
                        done: i < _current,
                        active: i == _current,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Widget leading;
    if (done) {
      leading = const Icon(Icons.check_circle, size: 22, color: AppColors.gold);
    } else if (active) {
      leading = const SizedBox(
        width: 22,
        height: 22,
        child: Padding(
          padding: EdgeInsets.all(3),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.amber),
          ),
        ),
      );
    } else {
      leading = Icon(Icons.radio_button_unchecked,
          size: 22, color: AppColors.textMuted.withValues(alpha: 0.5));
    }

    final Color textColor = done
        ? AppColors.textCream
        : active
            ? AppColors.textTan
            : AppColors.textMuted;

    return Row(
      children: [
        leading,
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: AppText.sans(
              size: 15,
              weight: active ? FontWeight.w600 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}
