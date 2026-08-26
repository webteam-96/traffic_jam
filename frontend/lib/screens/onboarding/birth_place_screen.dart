import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';

/// Onboarding step 3 of 4 — birth place. Search field + mocked city
/// suggestions; tapping a row selects it (gold border). Pushed screen, so it
/// roots in DetailScaffold.
class BirthPlaceScreen extends StatefulWidget {
  const BirthPlaceScreen({super.key});

  @override
  State<BirthPlaceScreen> createState() => _BirthPlaceScreenState();
}

class _BirthPlaceScreenState extends State<BirthPlaceScreen> {
  final _search = TextEditingController();
  int _selected = 0;

  // ponytail: static suggestions — swap for a geocoding lookup when the flow needs it.
  static const _cities = [
    'Mumbai, Maharashtra, India',
    'Delhi, India',
    'Pune, Maharashtra, India',
    'Bengaluru, Karnataka, India',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Birth Place',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          // Thin gold step progress — 3 of 4.
          Row(
            children: const [
              _StepSegment(filled: true),
              SizedBox(width: AppSpacing.xs),
              _StepSegment(filled: true),
              SizedBox(width: AppSpacing.xs),
              _StepSegment(filled: true),
              SizedBox(width: AppSpacing.xs),
              _StepSegment(filled: false),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Step 3 of 4', style: AppText.microLabel),
          const SizedBox(height: AppSpacing.xl),
          Text('Where were you born?', style: AppText.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your birth place fixes the horizon your chart is cast against.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionLabel('SEARCH CITY'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _search,
            textCapitalization: TextCapitalization.words,
            cursorColor: AppColors.gold,
            style: AppText.sans(
              size: 16,
              weight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search your city',
              hintStyle: AppText.sans(size: 16, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.location_on_outlined,
                  color: AppColors.gold),
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
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('SUGGESTIONS'),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < _cities.length; i++) ...[
            GlassCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
              borderColor: i == _selected
                  ? AppColors.gold
                  : AppColors.borderFaint,
              onTap: () => setState(() => _selected = i),
              child: Row(
                children: [
                  Icon(Icons.location_on,
                      color: i == _selected
                          ? AppColors.gold
                          : AppColors.textMuted),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _cities[i],
                      style: AppText.sans(
                        size: 15,
                        weight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (i == _selected)
                    const Icon(Icons.check_circle,
                        color: AppColors.gold, size: 20),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.lg),
          GoldButton(
            label: 'CONTINUE',
            icon: Icons.arrow_forward,
            onPressed: () => goToConsent(context),
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
