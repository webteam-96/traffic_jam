import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';
import 'package:traffic_jam/models/onboarding_data.dart';

/// Onboarding step 1 of 4 — identity. Name field + date-of-birth picker,
/// both persisted into [OnboardingData]. Pushed screen, so it roots in
/// DetailScaffold.
class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key});

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  late final _name = TextEditingController(text: OnboardingData.name ?? '');
  DateTime? _dob = OnboardingData.dob;

  bool get _canContinue => _name.text.trim().isNotEmpty && _dob != null;

  void _continue(BuildContext context) {
    OnboardingData.name = _name.text.trim();
    OnboardingData.dob = _dob;
    goToBirthTime(context);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'About You',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          // Thin gold step progress — 1 of 4.
          Row(
            children: const [
              _StepSegment(filled: true),
              SizedBox(width: AppSpacing.xs),
              _StepSegment(filled: false),
              SizedBox(width: AppSpacing.xs),
              _StepSegment(filled: false),
              SizedBox(width: AppSpacing.xs),
              _StepSegment(filled: false),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Step 1 of 4', style: AppText.microLabel),
          const SizedBox(height: AppSpacing.xl),
          Text('Tell us who you are', style: AppText.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your name and birth date anchor every reading.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionLabel('YOUR NAME'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            cursorColor: AppColors.gold,
            style: AppText.sans(
              size: 16,
              weight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Ananya Sharma',
              hintStyle: AppText.sans(size: 16, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.bgDeep,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.goldBorderSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.gold),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('DATE OF BIRTH'),
          const SizedBox(height: AppSpacing.md),
          BirthDateField(
            date: _dob,
            onChanged: (d) => setState(() => _dob = d),
          ),
          const SizedBox(height: AppSpacing.section),
          GoldButton(
            label: 'CONTINUE',
            icon: Icons.arrow_forward,
            onPressed: _canContinue ? () => _continue(context) : null,
          ),
        ],
      ),
    );
  }
}

class _StepSegment extends StatelessWidget {
  const _StepSegment({required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          gradient: filled ? AppColors.goldMeter : null,
          color: filled ? null : AppColors.borderSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}
