import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../nav.dart';
import '../../services/chart_api.dart';

class _PlanetColor {
  const _PlanetColor(this.colorName, this.hex, this.color, this.trait, this.why, this.favourFor);
  final String colorName;
  final String hex;
  final Color color;
  final String trait;
  final String why;
  final String favourFor;
}

/// Colour association per graha — classical Vedic correspondences, the same
/// ones ruling-planet gemstone/Rudraksha recommendations use elsewhere in
/// this app. Covers all nine Vimshottari Dasha lords (the original seven
/// classical planets plus Rahu/Ketu), not just the seven weekday rulers.
const Map<String, _PlanetColor> _planetColors = {
  'Sun': _PlanetColor('Sunrise Orange', '#FB8C00', Color(0xFFFB8C00),
      'vitality, confidence and leadership',
      'The Sun governs vitality, authority and self-expression. Orange carries its bold, radiant vibration, favouring confidence and visibility.',
      'leadership moments, presentations, and anything that puts you in the spotlight'),
  'Moon': _PlanetColor('Moonlit White', '#F1F3F6', Color(0xFFF1F3F6),
      'calm, memory and family bonds',
      'The Moon governs mind, emotion, and the home. White carries its cool, reflective vibration, steadying the emotions and sharpening intuition.',
      'family time, journaling, and anything that needs a calm, receptive mind'),
  'Mars': _PlanetColor('Ember Red', '#E53935', Color(0xFFE53935),
      'courage and decisive action',
      'Mars governs drive, courage and quick action. Red carries its fiery, energising vibration, sharpening focus and willpower.',
      'physical activity, bold decisions, and tasks that need momentum'),
  'Mercury': _PlanetColor('Sky Blue', '#87CEEB', Color(0xFF87CEEB),
      'clarity and communication',
      'Mercury governs intellect, speech and exchange of ideas. Sky Blue carries its cool, airy vibration, steadying the mind and keeping conversations clear.',
      'meetings, writing, negotiations and any task that rewards a clear head'),
  'Jupiter': _PlanetColor('Golden Yellow', '#FDD835', Color(0xFFFDD835),
      'wisdom, luck and generosity',
      'Jupiter governs wisdom, growth and good fortune. Yellow carries its warm, expansive vibration, favouring learning and generosity.',
      'learning, mentoring, financial planning and acts of generosity'),
  'Venus': _PlanetColor('Blush Pink', '#F48FB1', Color(0xFFF48FB1),
      'love, beauty and harmony',
      'Venus governs love, beauty and harmony. Pink carries its warm, affectionate vibration, favouring connection and creative pleasure.',
      'relationships, art, self-care, and anything that rewards charm and aesthetics'),
  'Saturn': _PlanetColor('Deep Indigo', '#2B3A55', Color(0xFF2B3A55),
      'discipline, patience and quiet focus',
      'Saturn governs discipline, structure and long-term work. Deep indigo carries its grounded, serious vibration, favouring patience over haste.',
      'finishing overdue work, budgeting, and any task that rewards patience'),
  'Rahu': _PlanetColor('Smoky Grey', '#708090', Color(0xFF708090),
      'ambition, reinvention and bold risk',
      'Rahu governs obsession, ambition and the unconventional. Smoky grey carries its shadowy, shape-shifting vibration, favouring bold moves outside the usual script.',
      'unconventional opportunities, calculated risks, and breaking from routine'),
  'Ketu': _PlanetColor('Ash Brown', '#8B7355', Color(0xFF8B7355),
      'detachment, introspection and letting go',
      "Ketu governs detachment, spirituality and release. Ash brown carries its muted, inward vibration, favouring reflection over new pursuits.",
      'meditation, decluttering, and stepping back from something that no longer serves you'),
};

/// Sunday=1..Saturday=7 in classical Vaar order; DateTime.weekday is
/// 1=Monday..7=Sunday, so this is indexed [weekday - 1].
const List<String> _weekdayRulers = [
  'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Sun',
];

/// "Color & Energy of the Day" — genuinely personalised: driven by the
/// planet ruling your *current* Dasha (Antardasha if known, else
/// Mahadasha — the same "which planet is actively running your life right
/// now" logic the Traffic Signal and Astro Insights screens already use),
/// not just today's weekday. Falls back to the classical weekday ruler
/// (Vaar) only when there's no chart yet — still a real, universal rule,
/// just not personal to you specifically.
class ColorOfDayScreen extends StatefulWidget {
  const ColorOfDayScreen({super.key});

  @override
  State<ColorOfDayScreen> createState() => _ColorOfDayScreenState();
}

class _ColorOfDayScreenState extends State<ColorOfDayScreen> {
  String? _antarLord;
  String? _mahaLord;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dasha = await ChartApi.getDasha();
      final maha = (dasha['maha'] as List).cast<Map<String, dynamic>>();
      final antar = (dasha['antar'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final currentMaha = maha.where((p) => p['current'] == true).firstOrNull;
      final currentAntar = antar.where((p) => p['current'] == true).firstOrNull;
      if (!mounted) return;
      setState(() {
        _mahaLord = currentMaha?['lord'] as String?;
        _antarLord = currentAntar?['lord'] as String?;
      });
    } catch (_) {
      // No chart yet, or a transient error — falls back to the weekday
      // ruler below, same as a logged-out/no-birth-data empty state.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekdayPlanet = _weekdayRulers[DateTime.now().weekday - 1];
    final drivingPlanet = _antarLord ?? _mahaLord;
    final personalized = drivingPlanet != null;
    final today = _planetColors[drivingPlanet ?? weekdayPlanet] ?? _planetColors[weekdayPlanet]!;

    final why = personalized
        ? "You're currently in your $drivingPlanet "
            "${_antarLord != null ? 'Antardasha' : 'Mahadasha'} — the planet actively "
            "running your life right now. ${today.why}${drivingPlanet != weekdayPlanet ? " (Today itself is ruled by $weekdayPlanet, but your personal running period takes precedence.)" : " Today's own ruler, $weekdayPlanet, agrees — a doubly-reinforced day for this colour."}"
        : "Today ($weekdayPlanet's day) is ruled by $weekdayPlanet. ${today.why} "
            'Save your birth details to see this personalised to your own current Dasha instead of just the weekday.';

    return DetailScaffold(
      title: 'Color of the Day',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: SectionLabel(_loading
                  ? "TODAY'S COLOUR & ENERGY"
                  : personalized
                      ? 'YOUR COLOUR & ENERGY TODAY'
                      : "TODAY'S COLOUR & ENERGY")),
          const SizedBox(height: AppSpacing.xxl),
          _swatch(today),
          const SizedBox(height: AppSpacing.xl),
          Center(child: _planetChip(drivingPlanet ?? weekdayPlanet, personalized)),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Favours ${today.trait} today.',
            textAlign: TextAlign.center,
            style: AppText.serif(size: 22, color: AppColors.textCream, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.section),
          _whyCard(why, today),
          const SizedBox(height: AppSpacing.section),
          GoldButton(
            label: 'Share',
            outlined: true,
            icon: Icons.share,
            onPressed: () => toast(context, 'Shared to your story'),
          ),
        ],
      ),
    );
  }

  // ── Hero swatch ──────────────────────────────────────────────────────────
  Widget _swatch(_PlanetColor day) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [day.color, day.color.withValues(alpha: 0.82)],
        ),
        border: Border.all(color: AppColors.goldBorderSoft),
        boxShadow: [
          BoxShadow(color: day.color.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 1),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.colorName,
            style: AppText.serif(
              size: 34,
              weight: FontWeight.w700,
              color: AppColors.bgDeepest,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            day.hex,
            style: AppText.sans(
              size: 13,
              weight: FontWeight.w500,
              color: AppColors.bgDeepest.withValues(alpha: 0.6),
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  // ── Ruling planet chip ───────────────────────────────────────────────────
  Widget _planetChip(String planet, bool personalized) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.goldBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(personalized ? Icons.auto_awesome : Icons.public, size: 16, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Text(
            personalized ? 'Ruled by $planet — your Dasha lord' : 'Ruled by $planet',
            style: AppText.sans(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.goldLight,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Why this colour ──────────────────────────────────────────────────────
  Widget _whyCard(String why, _PlanetColor day) {
    return GlassCard(
      goldTopBorder: true,
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.55,
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('WHY THIS COLOUR'),
          const SizedBox(height: AppSpacing.lg),
          Text(why, style: AppText.sans(size: 14, color: AppColors.textTan, height: 1.6)),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.surfaceRaised3, height: 1),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Favour it for ${day.favourFor}.',
            style: AppText.sans(size: 14, color: AppColors.textMuted, height: 1.6),
          ),
        ],
      ),
    );
  }
}
