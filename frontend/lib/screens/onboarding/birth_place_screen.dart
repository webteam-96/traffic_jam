import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';
import 'package:traffic_jam/data/curated_cities.dart';
import 'package:traffic_jam/models/onboarding_data.dart';

/// Onboarding step 3 of 4 — birth place. Search field + curated city
/// suggestions (each with real lat/lng/timezone — stands in for Google
/// Places until a real API key is configured); tapping a row selects it
/// (gold border). Pushed screen, so it roots in DetailScaffold.
class BirthPlaceScreen extends StatefulWidget {
  const BirthPlaceScreen({super.key});

  @override
  State<BirthPlaceScreen> createState() => _BirthPlaceScreenState();
}

class _BirthPlaceScreenState extends State<BirthPlaceScreen> {
  final _search = TextEditingController();
  String? _selectedCity = OnboardingData.place;

  List<(String, double, double, String)> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return kCuratedCities;
    return kCuratedCities.where((c) => c.$1.toLowerCase().contains(q)).toList();
  }

  void _continue(BuildContext context) {
    if (_selectedCity == null) return;
    final city = kCuratedCities.firstWhere((c) => c.$1 == _selectedCity);
    OnboardingData.place = city.$1;
    OnboardingData.lat = city.$2;
    OnboardingData.lng = city.$3;
    OnboardingData.timezone = city.$4;
    goToConsent(context);
  }

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
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('SUGGESTIONS'),
          const SizedBox(height: AppSpacing.md),
          for (final city in _filtered) ...[
            GlassCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
              borderColor: city.$1 == _selectedCity
                  ? AppColors.gold
                  : AppColors.borderFaint,
              onTap: () => setState(() => _selectedCity = city.$1),
              child: Row(
                children: [
                  Icon(Icons.location_on,
                      color: city.$1 == _selectedCity
                          ? AppColors.gold
                          : AppColors.textMuted),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      city.$1,
                      style: AppText.sans(
                        size: 15,
                        weight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (city.$1 == _selectedCity)
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
            onPressed: _selectedCity == null ? null : () => _continue(context),
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
