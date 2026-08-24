import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Cosmic Foundations: 9 Planets
class PlanetsScreen extends StatelessWidget {
  const PlanetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _CosmicFoundationsReader(
      title: '9 Planets',
      subtitle: 'The celestial influencers',
      icon: Icons.brightness_7,
      sections: const [
        _Section(
          title: 'The Navagraha — Nine Grahas',
          body:
              'In Vedic astrology, nine "grahas" (seizers/influencers) govern all of life. '
              'Seven are visible planets; two are mathematical points (Rahu, Ketu) — the '
              'lunar nodes where eclipses occur. Each graha represents a specific '
              'intelligence or cosmic function. Their placements in your birth chart '
              'reveal which energies are strong, challenged, or dormant in your life.',
        ),
        _Section(
          title: 'The Nine Grahas & Their Domains',
          body:
              '☉ Surya (Sun) — Soul, vitality, authority, father, government\n'
              '☽ Chandra (Moon) — Mind, emotions, mother, public, comfort\n'
              '♂ Mangal (Mars) — Action, courage, siblings, property, blood\n'
              '☿ Budha (Mercury) — Intellect, speech, commerce, skills, friends\n'
              '♃ Guru (Jupiter) — Wisdom, wealth, children, guru, dharma\n'
              '♀ Shukra (Venus) — Love, beauty, vehicles, arts, relationships\n'
              '♄ Shani (Saturn) — Karma, discipline, longevity, servants, delay\n'
              '☊ Rahu (North Node) — Obsession, foreign, technology, ambition\n'
              '☋ Ketu (South Node) — Detachment, spirituality, past-life, liberation',
        ),
        _Section(
          title: 'Benefic vs Malefic Classification',
          body:
              'Natural benefics: Jupiter, Venus, waxing Moon, well-placed Mercury.\n'
              'Natural malefics: Saturn, Mars, Sun, waning Moon, Rahu, Ketu.\n\n'
              'Functional benefic/malefic depends on your Lagna — e.g., for Taurus '
              'Lagna, Saturn becomes a yogakaraka (benefic) as lord of 9th and 10th. '
              'This is why the same planet gives different results for different people.',
        ),
        _Section(
          title: 'Planetary Friendships & Enmities',
          body:
              'Planets have natural relationships that modify their combined effects:\n\n'
              'Sun friends: Moon, Mars, Jupiter | enemies: Venus, Saturn\n'
              'Moon friends: Sun, Mercury | enemies: none (neutral to all)\n'
              'Mars friends: Sun, Moon, Jupiter | enemies: Mercury\n'
              'Mercury friends: Sun, Venus | enemies: Moon\n'
              'Jupiter friends: Sun, Moon, Mars | enemies: Mercury, Venus\n'
              'Venus friends: Mercury, Saturn | enemies: Sun, Moon\n'
              'Saturn friends: Mercury, Venus | enemies: Sun, Moon, Mars\n'
              'Rahu/Ketu: Mirror each other\'s relationships; Rahu amplifies, Ketu diminishes',
        ),
        _Section(
          title: 'Worked Example',
          body:
              'Jupiter in 5th house (own sign Sagittarius) for Aries Lagna:\n'
              '• 5th = creativity, children, speculation, mantra\n'
              '• Jupiter = wisdom, expansion, guru\n'
              '• Own sign = maximum strength\n\n'
              'Result: Exceptional creative intelligence, fortunate children, '
              'success in speculative ventures (if not afflicted), natural teaching '
              'ability. The person becomes a "guru" in their field — others seek '
              'their counsel. This is a classic "Dhana Yoga" for wealth through '
              'knowledge and creativity.',
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