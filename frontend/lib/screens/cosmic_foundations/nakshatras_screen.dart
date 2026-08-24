import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Cosmic Foundations: 27 Nakshatras
class NakshatrasScreen extends StatelessWidget {
  const NakshatrasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _CosmicFoundationsReader(
      title: '27 Nakshatras',
      subtitle: 'The lunar mansions',
      icon: Icons.nightlight_round,
      sections: const [
        _Section(
          title: 'What Are Nakshatras?',
          body:
              'Nakshatras are the 27 lunar mansions — the Moon\'s path through the zodiac, '
              'each spanning 13°20\'. They are the oldest layer of Vedic astrology, '
              'predating the 12-sign zodiac. Each nakshatra has a deity, symbol, ruling '
              'planet, and unique shakti (power). Your Janma Nakshatra (Moon\'s nakshatra '
              'at birth) reveals your deepest nature, instincts, and karmic imprint. '
              'The nakshatra pada (quarter, 3°20\' each) refines this further — 108 padas '
              'total, mapping to the 108 navamsha positions.',
        ),
        _Section(
          title: 'All 27 Nakshatras — Quick Reference',
          body:
              '1. Ashwini (Aries 0°–13°20\') — Ketu — Healers, speed, beginnings\n'
              '2. Bharani (Aries 13°20\'–26°40\') — Venus — Birth, death, transformation\n'
              '3. Krittika (Aries 26°40\'–Taurus 10°) — Sun — Cutting, purification, leadership\n'
              '4. Rohini (Taurus 10°–23°20\') — Moon — Growth, beauty, fertility\n'
              '5. Mrigashira (Taurus 23°20\'–Gemini 6°40\') — Mars — Seeking, curiosity, deer\n'
              '6. Ardra (Gemini 6°40\'–20°) — Rahu — Storm, tears, transformation\n'
              '7. Punarvasu (Gemini 20°–Cancer 3°20\') — Jupiter — Return, renewal, optimism\n'
              '8. Pushya (Cancer 3°20\'–16°40\') — Saturn — Nourishment, priesthood, care\n'
              '9. Ashlesha (Cancer 16°40\'–30°) — Mercury — Coiling, intuition, hidden power\n'
              '10. Magha (Leo 0°–13°20\') — Ketu — Throne, ancestors, authority\n'
              '11. Purva Phalguni (Leo 13°20\'–26°40\') — Venus — Pleasure, creativity, union\n'
              '12. Uttara Phalguni (Leo 26°40\'–Virgo 10°) — Sun — Patronage, contracts, service\n'
              '13. Hasta (Virgo 10°–23°20\') — Moon — Skill, craft, manifestation\n'
              '14. Chitra (Virgo 23°20\'–Libra 6°40\') — Mars — Design, illusion, brilliance\n'
              '15. Swati (Libra 6°40\'–20°) — Rahu — Independence, trade, wind\n'
              '16. Vishakha (Libra 20°–Scorpio 3°20\') — Jupiter — Purpose, determination, forked\n'
              '17. Anuradha (Scorpio 3°20\'–16°40\') — Saturn — Devotion, friendship, success\n'
              '18. Jyeshtha (Scorpio 16°40\'–30°) — Mercury — Elder, protection, power\n'
              '19. Mula (Sagittarius 0°–13°20\') — Ketu — Roots, destruction, research\n'
              '20. Purva Ashadha (Sag 13°20\'–26°40\') — Venus — Invincibility, fluidity\n'
              '21. Uttara Ashadha (Sag 26°40\'–Cap 10°) — Sun — Universal victory, tenacity\n'
              '22. Shravana (Cap 10°–23°20\') — Moon — Listening, learning, connection\n'
              '23. Dhanishta (Cap 23°20\'–Aqu 6°40\') — Mars — Rhythm, wealth, drum\n'
              '24. Shatabhisha (Aqu 6°40\'–20°) — Rahu — Healing, secrecy, hundred physicians\n'
              '25. Purva Bhadrapada (Aqu 20°–Pis 3°20\') — Jupiter — Penance, transformation\n'
              '26. Uttara Bhadrapada (Pis 3°20\'–16°40\') — Saturn — Wisdom, depth, serpent\n'
              '27. Revati (Pis 16°40\'–30°) — Mercury — Completion, journey\'s end, nourishment',
        ),
        _Section(
          title: 'Nakshatra Groups — Gana, Yoni, Nadi',
          body:
              'Each nakshatra belongs to three classification systems used in matching:\n\n'
              'Gana (Nature): Deva (divine) — 1,4,6,7,9,13,15,18,22,23,24,27\n'
              '             Manushya (human) — 2,3,5,8,10,11,12,14,16,17,19,20,21,25,26\n'
              '             Rakshasa (demonic) — none in standard list (some texts vary)\n\n'
              'Yoni (Animal): 14 animal symbols showing sexual/creative compatibility.\n\n'
              'Nadi (Pulse): Adi (Vata), Madhya (Pitta), Antya (Kapha) — used for '
              'health and progeny matching. Same nadi = nadi dosha (challenge).',
        ),
        _Section(
          title: 'Nakshatra Padas & Navamsha Link',
          body:
              'Each nakshatra = 4 padas × 3°20\' = 13°20\'. The 108 padas map 1:1 to '
              'the 108 navamsha (D9) positions. Your Moon\'s pada determines your '
              'navamsha lagna — the "fruit" of the chart. This is why nakshatra '
              'precision matters: a 3°20\' shift changes your D9 entirely.\n\n'
              'Example: Moon at 10° Cancer = Pushya pada 3. Pushya = Saturn-ruled, '
              'deity Brihaspati (Jupiter). Pada 3 = Libra navamsha (Venus). The '
              'blend: Saturn\'s discipline + Jupiter\'s wisdom + Venus\'s refinement '
              '= a person who serves through beautiful, structured wisdom.',
        ),
        _Section(
          title: 'Worked Example',
          body:
              'Moon in Rohini (Taurus 10°–23°20\'), pada 2:\n'
              '• Deity: Brahma (Creator) — creative manifestation\n'
              '• Symbol: Ox cart — steady, reliable progress\n'
              '• Ruler: Moon — emotional depth, nurturing\n'
              '• Shakti: Rohana (growth) — things grow around you\n'
              '• Pada 2: Virgo navamsha (Mercury) — analytical refinement\n\n'
              'Synthesis: A creator who builds enduring, beautiful structures through '
              'patient, meticulous effort. Emotional fulfillment comes from seeing '
              'tangible results grow. The Virgo pada adds discrimination — not just '
              'any growth, but *correct* growth. Ideal for designers, farmers, '
              'builders of systems that nurture others.',
        ),
      ],
    );
  }
}

class _Section {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;
}

class _CosmicFoundationsReader extends StatelessWidget {
  const _CosmicFoundationsReader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.sections,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_Section> sections;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                IconChip(
                  size: 56,
                  circular: true,
                  glow: true,
                  child: Icon(icon, size: 28, color: AppColors.gold),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppText.serif(size: 26, weight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle,
                          style: AppText.sans(
                              size: 14, color: AppColors.textTan, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (int i = 0; i < sections.length; i++) ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sections[i].title,
                      style: AppText.headingSerif.copyWith(color: AppColors.amber)),
                  const SizedBox(height: AppSpacing.md),
                  Text(sections[i].body, style: AppText.body),
                ],
              ),
            ),
            if (i != sections.length - 1) const SizedBox(height: AppSpacing.lg),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}