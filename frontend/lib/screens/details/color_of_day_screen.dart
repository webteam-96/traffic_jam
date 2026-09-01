import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../nav.dart';

class _DayColor {
  const _DayColor(this.planet, this.colorName, this.hex, this.color, this.reading, this.why, this.favourFor);
  final String planet;
  final String colorName;
  final String hex;
  final Color color;
  final String reading;
  final String why;
  final String favourFor;
}

/// Vedic Vaar (weekday ruler) → colour of the day — a classical, universal
/// rule (Sun=Sunday, Moon=Monday, Mars=Tuesday, Mercury=Wednesday,
/// Jupiter=Thursday, Venus=Friday, Saturn=Saturday), not user-specific, so
/// this is entirely deterministic from today's date — same for everyone on
/// a given day, the way any "colour of the day" convention works.
/// DateTime.weekday: 1=Monday .. 7=Sunday.
const Map<int, _DayColor> _weekdayColors = {
  1: _DayColor('Moon', 'Moonlit White', '#F1F3F6', Color(0xFFF1F3F6),
      'Nurtures calm, memory and family bonds today.',
      'Monday is ruled by the Moon — mind, emotion, and the home. White carries '
          'its cool, reflective vibration, steadying the emotions and sharpening intuition.',
      'family time, journaling, and anything that needs a calm, receptive mind'),
  2: _DayColor('Mars', 'Ember Red', '#E53935', Color(0xFFE53935),
      'Fuels courage and decisive action today.',
      'Tuesday is ruled by Mars — drive, courage and quick action. Red carries its '
          'fiery, energising vibration, sharpening focus and willpower.',
      'physical activity, bold decisions, and tasks that need momentum'),
  3: _DayColor('Mercury', 'Sky Blue', '#87CEEB', Color(0xFF87CEEB),
      'Improves clarity and communication today.',
      'Wednesday is ruled by Mercury — intellect, speech and exchange of ideas. '
          'Sky Blue carries its cool, airy vibration, steadying the mind and keeping '
          'conversations clear.',
      'meetings, writing, negotiations and any task that rewards a clear head'),
  4: _DayColor('Jupiter', 'Golden Yellow', '#FDD835', Color(0xFFFDD835),
      'Expands wisdom, luck and generosity today.',
      'Thursday is ruled by Jupiter — wisdom, growth and good fortune. Yellow carries '
          'its warm, expansive vibration, favouring learning and generosity.',
      'learning, mentoring, financial planning and acts of generosity'),
  5: _DayColor('Venus', 'Blush Pink', '#F48FB1', Color(0xFFF48FB1),
      'Heightens love, beauty and harmony today.',
      'Friday is ruled by Venus — love, beauty and harmony. Pink carries its warm, '
          'affectionate vibration, favouring connection and creative pleasure.',
      'relationships, art, self-care, and anything that rewards charm and aesthetics'),
  6: _DayColor('Saturn', 'Deep Indigo', '#2B3A55', Color(0xFF2B3A55),
      'Calls for discipline, patience and quiet focus today.',
      'Saturday is ruled by Saturn — discipline, structure and long-term work. Deep '
          'indigo carries its grounded, serious vibration, favouring patience over haste.',
      'finishing overdue work, budgeting, and any task that rewards patience'),
  7: _DayColor('Sun', 'Sunrise Orange', '#FB8C00', Color(0xFFFB8C00),
      'Boosts vitality, confidence and leadership today.',
      'Sunday is ruled by the Sun — vitality, authority and self-expression. Orange '
          'carries its bold, radiant vibration, favouring confidence and visibility.',
      'leadership moments, presentations, and anything that puts you in the spotlight'),
};

/// "Color & Energy of the Day" — hero swatch, ruling planet, and the
/// reasoning behind them, derived from today's weekday ruler.
class ColorOfDayScreen extends StatelessWidget {
  const ColorOfDayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final today = _weekdayColors[DateTime.now().weekday]!;
    return DetailScaffold(
      title: 'Color of the Day',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SectionLabel("TODAY'S COLOUR & ENERGY")),
          const SizedBox(height: AppSpacing.xxl),
          _swatch(today),
          const SizedBox(height: AppSpacing.xl),
          Center(child: _planetChip(today)),
          const SizedBox(height: AppSpacing.xl),
          Text(
            today.reading,
            textAlign: TextAlign.center,
            style: AppText.serif(
              size: 22,
              color: AppColors.textCream,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          _whyCard(today),
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
  Widget _swatch(_DayColor day) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            day.color,
            day.color.withValues(alpha: 0.82),
          ],
        ),
        border: Border.all(color: AppColors.goldBorderSoft),
        boxShadow: [
          BoxShadow(
            color: day.color.withValues(alpha: 0.35),
            blurRadius: 40,
            spreadRadius: 1,
          ),
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
  Widget _planetChip(_DayColor day) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.goldBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.public, size: 16, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Ruled by ${day.planet}',
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
  Widget _whyCard(_DayColor day) {
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
          Text(
            day.why,
            style: AppText.sans(
              size: 14,
              color: AppColors.textTan,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.surfaceRaised3, height: 1),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Favour it for ${day.favourFor}.',
            style: AppText.sans(
              size: 14,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
