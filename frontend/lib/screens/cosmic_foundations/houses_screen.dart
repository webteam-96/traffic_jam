import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Cosmic Foundations: 12 Houses
class HousesScreen extends StatelessWidget {
  const HousesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _CosmicFoundationsReader(
      title: '12 Houses',
      subtitle: 'Areas of life experience',
      icon: Icons.grid_3x3,
      sections: const [
        _Section(
          title: 'The Bhava Chakra — House Wheel',
          body:
              'The 12 houses (bhavas) are the stage on which planetary actors perform. '
              'Each house represents a specific domain of human experience. The sign on '
              'the cusp (starting degree) of each house, its lord (ruler), and any planets '
              'tenanting it determine how that life area manifests. Houses are calculated '
              'from your Lagna (Ascendant) — the 1st house cusp is your rising degree.',
        ),
        _Section(
          title: 'All 12 Houses — Keywords & Themes',
          body:
              '1st — Tanu (Self): Body, personality, appearance, vitality, beginnings\n'
              '2nd — Dhana (Wealth): Money, speech, family, values, food, right eye\n'
              '3rd — Sahaja (Courage): Siblings, communication, skills, short travel, effort\n'
              '4th — Bandhu (Home): Mother, property, vehicles, happiness, chest, roots\n'
              '5th — Putra (Children): Creativity, romance, intelligence, mantra, speculation\n'
              '6th — Shatru (Enemies): Health, debts, service, daily work, competitors, pets\n'
              '7th — Kalatra (Partner): Marriage, business partnerships, public dealings\n'
              '8th — Ayu (Longevity): Transformation, occult, inheritance, crises, secrets\n'
              '9th — Dharma (Fortune): Guru, higher learning, pilgrimage, law, luck, father\n'
              '10th — Karma (Career): Profession, status, authority, reputation, knees\n'
              '11th — Labha (Gains): Income, friends, networks, aspirations, elder siblings\n'
              '12th — Vyaya (Loss): Expenses, foreign lands, spirituality, sleep, liberation',
        ),
        _Section(
          title: 'House Groupings — The Four Aims of Life (Purusharthas)',
          body:
              '🕉 Dharma (Righteousness): 1st, 5th, 9th — Purpose, creativity, wisdom\n'
              '💰 Artha (Wealth): 2nd, 6th, 10th — Resources, work, career\n'
              '❤️ Kama (Desire): 3rd, 7th, 11th — Relationships, partnerships, gains\n'
              '🕊 Moksha (Liberation): 4th, 8th, 12th — Inner peace, transformation, release\n\n'
              'A balanced chart has strength across all four. Over-emphasis in one '
              'creates a lopsided life — e.g., strong Artha/Kama but weak Moksha = '
              'material success with spiritual emptiness.',
        ),
        _Section(
          title: 'Angular, Succedent, Cadent — Power Zones',
          body:
              'Angular (Kendra) — 1, 4, 7, 10: Maximum power. Planets here act visibly.\n'
              'Succedent (Panapara) — 2, 5, 8, 11: Moderate power. Resources & results.\n'
              'Cadent (Apoklima) — 3, 6, 9, 12: Least visible. Internal, adaptive, spiritual.\n\n'
              'Benefics in kendras = visible blessings. Malefics in kendras = visible '
              'challenges that drive growth. The 10th house (career/public) is the '
              'strongest kendra — the "throne" of the chart.',
        ),
        _Section(
          title: 'Worked Example',
          body:
              'Saturn in 10th house (Libra, exalted) for Cancer Lagna:\n'
              '• 10th = career, authority, public standing\n'
              '• Saturn = discipline, structure, karma, delay\n'
              '• Exalted = maximum dignity, but Saturn\'s nature is still restrictive\n\n'
              'Result: The person achieves high status through sustained effort, not luck. '
              'Career starts slowly (Saturn delays) but builds enduring structures. They '
              'become an authority in their field — "the one who stays when others quit." '
              'Public reputation is serious, respected, perhaps feared. The lesson: '
              'mastery requires time. This is a classic "Sasa Yoga" (Pancha Mahapurusha) '
              'giving leadership through discipline.',
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