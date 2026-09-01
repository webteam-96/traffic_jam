import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';
import 'package:traffic_jam/data/world_cities.dart';
import 'package:traffic_jam/models/onboarding_data.dart';

/// Onboarding step 3 of 4 — birth place. Search field over a bundled
/// ~34,000-city world dataset (real lat/lng/timezone, no API key needed);
/// tapping a row selects it (gold border). Pushed screen, so it roots in
/// DetailScaffold.
class BirthPlaceScreen extends StatefulWidget {
  const BirthPlaceScreen({super.key});

  @override
  State<BirthPlaceScreen> createState() => _BirthPlaceScreenState();
}

class _BirthPlaceScreenState extends State<BirthPlaceScreen> {
  final _search = TextEditingController();
  String? _selectedCity = OnboardingData.place;
  List<CityEntry> _allCities = const [];
  List<CityEntry> _popular = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WorldCities.load().then((cities) {
      if (!mounted) return;
      setState(() {
        _allCities = cities;
        _popular = cities.where((c) => c.country == 'India').take(8).toList();
        _loading = false;
      });
    });
  }

  List<CityEntry> get _filtered {
    final q = _search.text.trim();
    if (q.isEmpty) return _popular;
    return WorldCities.search(_allCities, q);
  }

  void _select(CityEntry city) {
    OnboardingData.place = city.displayName;
    OnboardingData.lat = city.lat;
    OnboardingData.lng = city.lng;
    OnboardingData.timezone = city.timezone;
    setState(() => _selectedCity = city.displayName);
  }

  void _continue(BuildContext context) {
    if (_selectedCity == null) return;
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
          SectionLabel(_search.text.trim().isEmpty ? 'SUGGESTIONS' : 'RESULTS'),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
              ),
            )
          else if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text('No cities match your search.', style: AppText.body),
            )
          else
            for (final city in _filtered) ...[
              GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                borderColor: city.displayName == _selectedCity
                    ? AppColors.gold
                    : AppColors.borderFaint,
                onTap: () => _select(city),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: city.displayName == _selectedCity
                            ? AppColors.gold
                            : AppColors.textMuted),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        city.displayName,
                        style: AppText.sans(
                          size: 15,
                          weight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (city.displayName == _selectedCity)
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
