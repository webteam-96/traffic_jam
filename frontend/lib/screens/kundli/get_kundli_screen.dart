import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../models/kundli_profile.dart';
import '../../data/world_cities.dart';
import '../../services/chart_api.dart';
import '../../services/api_client.dart';
import '../../nav.dart';
import '../details/kundli_screen.dart';

/// Get Kundli — Business Flow §5.3. Capture a family member/friend's birth
/// details, compute their real chart+Dasha via POST /chart/compute, save
/// the result client-side (KundliStore — no per-user "saved profiles" table
/// on the backend yet), then open it in the same Kundli detail screen used
/// for "My Kundli".
class GetKundliScreen extends StatefulWidget {
  const GetKundliScreen({super.key});

  @override
  State<GetKundliScreen> createState() => _GetKundliScreenState();
}

class _GetKundliScreenState extends State<GetKundliScreen> {
  final _name = TextEditingController();
  final _citySearch = TextEditingController();

  DateTime? _dob;
  int _hour = 6;
  int _minute = 0;
  bool _isAm = true;
  bool _tobUnknown = false;
  CityEntry? _selectedCity;
  List<CityEntry> _allCities = const [];
  List<CityEntry> _popularCities = const [];
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    WorldCities.load().then((cities) {
      if (!mounted) return;
      setState(() {
        _allCities = cities;
        _popularCities = cities.where((c) => c.country == 'India').take(8).toList();
      });
    });
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

  bool get _canGenerate =>
      _name.text.trim().isNotEmpty && _dob != null && _selectedCity != null;

  String _pad(int v) => v.toString().padLeft(2, '0');

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
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

  void _bump(int hourDelta, int minuteDelta) {
    if (_tobUnknown) return;
    setState(() {
      if (hourDelta != 0) {
        _hour += hourDelta;
        if (_hour > 12) _hour = 1;
        if (_hour < 1) _hour = 12;
      }
      if (minuteDelta != 0) _minute = (_minute + minuteDelta + 60) % 60;
    });
  }

  Future<void> _generate() async {
    if (!_canGenerate) return;
    setState(() => _generating = true);
    final city = _selectedCity!;
    var hour24 = _hour % 12;
    if (!_isAm) hour24 += 12;

    try {
      final computed = await ChartApi.compute(
        dob: _dob!,
        hour24: _tobUnknown ? null : hour24,
        minute: _tobUnknown ? null : _minute,
        unknownTime: _tobUnknown,
        lat: city.lat,
        lng: city.lng,
        timezone: city.timezone,
      );
      if (!mounted) return;

      final profile = KundliProfile(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        isOwn: false,
        dob: '${_dob!.day} ${_monthName(_dob!.month)} ${_dob!.year}',
        tob: _tobUnknown ? '' : '${_pad(_hour)}:${_pad(_minute)} ${_isAm ? "AM" : "PM"}',
        tobUnknown: _tobUnknown,
        place: city.displayName,
        generatedOn: 'just now',
        chart: computed['chart'] as Map<String, dynamic>,
        dasha: computed['dasha'] as Map<String, dynamic>,
        doshas: computed['doshas'] as Map<String, dynamic>?,
      );
      KundliStore.add(profile);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => KundliScreen(profile: profile)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      toast(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _generating = false);
      toast(context, "Couldn't reach the server — check your connection.");
    }
  }

  String _monthName(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];

  @override
  Widget build(BuildContext context) {
    if (_generating) return _LoadingView(name: _name.text.trim());

    return DetailScaffold(
      title: 'Get Kundli',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Generate a chart', style: AppText.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter their birth details to cast a personal Kundli — saved to '
            'your list once generated.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.section),

          const SectionLabel('FULL NAME'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            cursorColor: AppColors.gold,
            style: AppText.sans(size: 16, weight: FontWeight.w500, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Rohan Mehta',
              hintStyle: AppText.sans(size: 16, color: AppColors.textMuted),
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
            opacity: _tobUnknown ? 0.4 : 1,
            child: GlassCard(
              goldTopBorder: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeUnit(value: _pad(_hour), onUp: () => _bump(1, 0), onDown: () => _bump(-1, 0)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text(':',
                        style: AppText.serif(size: 32, weight: FontWeight.w700, color: AppColors.amber)),
                  ),
                  _TimeUnit(value: _pad(_minute), onUp: () => _bump(0, 1), onDown: () => _bump(0, -1)),
                  const SizedBox(width: AppSpacing.md),
                  _TimeUnit(
                    value: _isAm ? 'AM' : 'PM',
                    onUp: _tobUnknown ? null : () => setState(() => _isAm = !_isAm),
                    onDown: _tobUnknown ? null : () => setState(() => _isAm = !_isAm),
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
                  child: Text("I don't know their birth time", style: AppText.cardTitle),
                ),
                Switch(
                  value: _tobUnknown,
                  onChanged: (v) => setState(() => _tobUnknown = v),
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
          TextField(
            controller: _citySearch,
            cursorColor: AppColors.gold,
            style: AppText.sans(size: 16, weight: FontWeight.w500, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search city',
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
          const SizedBox(height: AppSpacing.lg),
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
            label: 'GENERATE',
            icon: Icons.auto_awesome,
            onPressed: _canGenerate ? _generate : null,
          ),
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

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      scrollable: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionLabel('CASTING THE CHART'),
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
              name.isEmpty ? 'Reading the stars…' : "Reading $name's stars…",
              textAlign: TextAlign.center,
              style: AppText.serif(size: 24, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
