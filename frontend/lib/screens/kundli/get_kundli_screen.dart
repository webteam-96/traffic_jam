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

  DateTime? _dob;
  TimeOfDay _tob = const TimeOfDay(hour: 6, minute: 0);
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
    super.dispose();
  }

  bool get _canGenerate =>
      _name.text.trim().isNotEmpty && _dob != null && _selectedCity != null;

  Future<void> _generate() async {
    if (!_canGenerate) return;
    setState(() => _generating = true);
    final city = _selectedCity!;

    try {
      final computed = await ChartApi.compute(
        dob: _dob!,
        hour24: _tobUnknown ? null : _tob.hour,
        minute: _tobUnknown ? null : _tob.minute,
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
        tob: _tobUnknown ? '' : _tob.format(context),
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
          BirthDateField(
            date: _dob,
            onChanged: (d) => setState(() => _dob = d),
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionLabel('TIME OF BIRTH'),
          const SizedBox(height: AppSpacing.md),
          Opacity(
            opacity: _tobUnknown ? 0.4 : 1,
            child: BirthTimeField(
              time: _tob,
              enabled: !_tobUnknown,
              onChanged: (t) => setState(() => _tob = t),
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
          CityField(
            cities: _allCities,
            popular: _popularCities,
            selected: _selectedCity,
            loading: _allCities.isEmpty,
            hintText: 'Search city',
            onSelected: (city) => setState(() => _selectedCity = city),
          ),
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
