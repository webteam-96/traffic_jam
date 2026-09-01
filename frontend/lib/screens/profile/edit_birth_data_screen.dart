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
  int _hour = 6;
  int _minute = 0;
  bool _isAm = true;
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
          final h24 = int.parse(parts[0]);
          _minute = int.parse(parts[1]);
          _isAm = h24 < 12;
          _hour = h24 % 12 == 0 ? 12 : h24 % 12;
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

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            onPrimary: AppColors.textOnGold,
            surface: AppColors.navBarBase,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _bumpTime(int hourDelta, int minuteDelta) {
    if (_unknownTime) return;
    setState(() {
      if (hourDelta != 0) {
        _hour += hourDelta;
        if (_hour > 12) _hour = 1;
        if (_hour < 1) _hour = 12;
      }
      if (minuteDelta != 0) _minute = (_minute + minuteDelta + 60) % 60;
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final city = _selectedCity!;
      var hour24 = _hour % 12;
      if (!_isAm) hour24 += 12;
      await UserApi.saveBirthData(
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
        dob: _dob!,
        hour24: _unknownTime ? null : hour24,
        minute: _unknownTime ? null : _minute,
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

  String _pad(int v) => v.toString().padLeft(2, '0');
  String _monthName(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];

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
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            onTap: _pickDob,
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: AppColors.gold),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _dob == null
                        ? 'Select date of birth'
                        : '${_dob!.day} ${_monthName(_dob!.month)} ${_dob!.year}',
                    style: AppText.serif(size: 18, weight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionLabel('TIME OF BIRTH'),
          const SizedBox(height: AppSpacing.md),
          Opacity(
            opacity: _unknownTime ? 0.4 : 1,
            child: GlassCard(
              goldTopBorder: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeUnit(value: _pad(_hour), onUp: () => _bumpTime(1, 0), onDown: () => _bumpTime(-1, 0)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text(':',
                        style: AppText.serif(size: 32, weight: FontWeight.w700, color: AppColors.amber)),
                  ),
                  _TimeUnit(value: _pad(_minute), onUp: () => _bumpTime(0, 1), onDown: () => _bumpTime(0, -1)),
                  const SizedBox(width: AppSpacing.md),
                  _TimeUnit(
                    value: _isAm ? 'AM' : 'PM',
                    onUp: _unknownTime ? null : () => setState(() => _isAm = !_isAm),
                    onDown: _unknownTime ? null : () => setState(() => _isAm = !_isAm),
                  ),
                ],
              ),
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

class _TimeUnit extends StatelessWidget {
  const _TimeUnit({required this.value, this.onUp, this.onDown});
  final String value;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chevron(Icons.keyboard_arrow_up, onUp),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppText.serif(size: 32, weight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        _chevron(Icons.keyboard_arrow_down, onDown),
      ],
    );
  }

  Widget _chevron(IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Icon(icon, size: 20, color: onTap == null ? AppColors.textMuted : AppColors.gold),
        ),
      );
}
