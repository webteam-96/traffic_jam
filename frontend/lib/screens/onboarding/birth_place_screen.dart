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
  CityEntry? _selectedCity;
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
        // Coming back to this step, re-select whatever was chosen before so
        // the field opens showing that place instead of starting over.
        _selectedCity = cities
            .where((c) => c.displayName == OnboardingData.place)
            .firstOrNull;
        _loading = false;
      });
    });
  }

  void _select(CityEntry city) {
    OnboardingData.place = city.displayName;
    OnboardingData.lat = city.lat;
    OnboardingData.lng = city.lng;
    OnboardingData.timezone = city.timezone;
    setState(() => _selectedCity = city);
  }

  void _continue(BuildContext context) {
    if (_selectedCity == null) return;
    goToConsent(context);
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
          CityField(
            cities: _allCities,
            popular: _popular,
            selected: _selectedCity,
            loading: _loading,
            onSelected: _select,
          ),
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
