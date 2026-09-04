import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/services/user_api.dart';
import 'package:traffic_jam/services/api_client.dart';
import 'package:traffic_jam/data/world_cities.dart';
import 'package:traffic_jam/nav.dart';

/// Edit birth data — real form wired to GET/PUT /me/birth-data. Pushed
/// screen, so it roots in DetailScaffold. Pops `true` on a successful save
/// so Profile knows to reload.
///
/// Place of birth searches a bundled ~34,000-city world dataset (real
/// lat/lng/timezone, no Google Places API key needed).
class EditBirthDataScreen extends StatefulWidget {
  const EditBirthDataScreen({super.key});

  @override
  State<EditBirthDataScreen> createState() => _EditBirthDataScreenState();
}

class _EditBirthDataScreenState extends State<EditBirthDataScreen> {
  final _name = TextEditingController();
  final _citySearch = TextEditingController();
  DateTime? _dob;
  TimeOfDay _tob = const TimeOfDay(hour: 6, minute: 0);
  bool _unknownTime = false;
  CityEntry? _selectedCity;
  List<CityEntry> _allCities = const [];
  List<CityEntry> _popularCities = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _citySearch.dispose();
    super.dispose();
  }

  List<CityEntry> get _filteredCities {
    final q = _citySearch.text.trim();
    if (q.isEmpty) return _popularCities;
    return WorldCities.search(_allCities, q);
  }

  Future<void> _load() async {
    final cities = await WorldCities.load();
    String? savedPlace;
    double? savedLat, savedLng;
    String? savedTz;
    try {
      final data = await UserApi.getBirthData();
      if (data != null) {
        _name.text = data['name'] as String? ?? '';
        final dobParts = (data['dob'] as String).split('-');
        _dob = DateTime(
            int.parse(dobParts[0]), int.parse(dobParts[1]), int.parse(dobParts[2]));
        _unknownTime = data['unknownTime'] as bool? ?? false;
        final tob = data['tob'] as String?;
        if (tob != null) {
          final parts = tob.split(':');
          _tob = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
        savedPlace = data['place'] as String?;
        savedLat = (data['lat'] as num?)?.toDouble();
        savedLng = (data['lng'] as num?)?.toDouble();
        savedTz = data['timezone'] as String?;
      }
    } catch (_) {
      // No saved data yet (or a transient error) — the form just starts blank.
    }
    if (!mounted) return;
    setState(() {
      _allCities = cities;
      _popularCities = cities.where((c) => c.country == 'India').take(8).toList();
      if (savedPlace != null && savedLat != null && savedLng != null) {
        // Prefer an exact dataset match (keeps it selectable from the same
        // search results a fresh pick would use); fall back to a synthetic
        // entry built from the saved fields so an existing selection is
        // never silently dropped just because its display string doesn't
        // match this dataset's naming.
        CityEntry? match;
        for (final c in cities) {
          if (c.displayName == savedPlace) {
            match = c;
            break;
          }
        }
        _selectedCity = match ??
            CityEntry(
              name: savedPlace,
              state: '',
              country: '',
              lat: savedLat,
              lng: savedLng,
              timezone: savedTz ?? 'Asia/Kolkata',
            );
      }
      _loading = false;
    });
  }

  bool get _canSave => _dob != null && _selectedCity != null && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final city = _selectedCity!;
      await UserApi.saveBirthData(
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
        dob: _dob!,
        hour24: _unknownTime ? null : _tob.hour,
        minute: _unknownTime ? null : _tob.minute,
        unknownTime: _unknownTime,
        place: city.displayName,
        lat: city.lat,
        lng: city.lng,
        timezone: city.timezone,
      );
      if (!mounted) return;
      toast(context, 'Birth data saved');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message);
    } catch (_) {
      if (!mounted) return;
      toast(context, "Couldn't reach the server — check your connection.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DetailScaffold(
        title: 'Edit Birth Data',
        scrollable: false,
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
        ),
      );
    }

    return DetailScaffold(
      title: 'Edit Birth Data',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Refine your chart', style: AppText.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Accurate birth details sharpen every reading.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.section),

          const SectionLabel('FULL NAME'),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              cursorColor: AppColors.gold,
              style: AppText.sans(
                  size: 16, weight: FontWeight.w500, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                hintText: 'e.g. Ananya Sharma',
                hintStyle: AppText.sans(size: 16, color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionLabel('DATE OF BIRTH'),
          const SizedBox(height: AppSpacing.md),
          BirthDateField(
            date: _dob,
            onChanged: (d) => setState(() => _dob = d),
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionLabel('TIME OF BIRTH'),
          const SizedBox(height: AppSpacing.md),
          Opacity(
            opacity: _unknownTime ? 0.4 : 1,
            child: BirthTimeField(
              time: _tob,
              enabled: !_unknownTime,
              onChanged: (t) => setState(() => _tob = t),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text("I don't know my birth time", style: AppText.cardTitle),
                ),
                Switch(
                  value: _unknownTime,
                  onChanged: (v) => setState(() => _unknownTime = v),
                  activeThumbColor: AppColors.textOnGold,
                  activeTrackColor: AppColors.gold,
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.surfaceRaised,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionLabel('PLACE OF BIRTH'),
          const SizedBox(height: AppSpacing.md),
          if (_selectedCity != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text('Current: ${_selectedCity!.displayName}',
                  style: AppText.sans(size: 13, color: AppColors.textMuted)),
            ),
          TextField(
            controller: _citySearch,
            textCapitalization: TextCapitalization.words,
            cursorColor: AppColors.gold,
            style: AppText.sans(size: 16, weight: FontWeight.w500, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search your city',
              hintStyle: AppText.sans(size: 16, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.gold),
              filled: true,
              fillColor: AppColors.bgDeep,
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 16),
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
          const SizedBox(height: AppSpacing.md),
          if (_filteredCities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text('No cities match your search.', style: AppText.body),
            )
          else
            for (final city in _filteredCities) ...[
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                borderColor: city.displayName == _selectedCity?.displayName
                    ? AppColors.gold
                    : AppColors.borderFaint,
                onTap: () => setState(() => _selectedCity = city),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: city.displayName == _selectedCity?.displayName
                            ? AppColors.gold
                            : AppColors.textMuted),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(city.displayName,
                          style: AppText.sans(size: 15, weight: FontWeight.w500, color: AppColors.textPrimary)),
                    ),
                    if (city.displayName == _selectedCity?.displayName)
                      const Icon(Icons.check_circle, color: AppColors.gold, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          const SizedBox(height: AppSpacing.lg),

          GoldButton(
            label: _saving ? 'SAVING…' : 'SAVE CHANGES',
            icon: Icons.check,
            onPressed: _canSave ? _save : null,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
