import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Cosmic Foundations: 5 Elements
class ElementsScreen extends StatelessWidget {
  const ElementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _CosmicFoundationsReader(
      title: '5 Elements',
      subtitle: 'The energetic makeup',
      icon: Icons.diamond,
      sections: const [
        _Section(
          title: 'Pancha Mahabhuta — The Five Great Elements',
          body:
              'All of manifest existence arises from five subtle elements (tanmatras) '
              'that combine in infinite proportions. In the birth chart, each planet '
              'and sign carries an elemental signature. Your elemental balance — which '
              'elements are strong, weak, or missing — shapes your temperament, health, '
              'and how you process experience. Ayurveda uses the same framework (doshas).',
        ),
        _Section(
          title: 'The Five Elements & Their Correspondences',
          body:
              '🜁 Akasha (Ether/Space) — Sound, expansion, consciousness, throat\n'
              '   Planets: Jupiter (primary) | Signs: Sagittarius\n\n'
              '🜂 Vayu (Air) — Touch, movement, intellect, nervous system\n'
              '   Planets: Saturn, Rahu | Signs: Gemini, Libra, Aquarius\n\n'
              '🜃 Agni (Fire) — Form, transformation, digestion, vision\n'
              '   Planets: Sun, Mars, Ketu | Signs: Aries, Leo, Sagittarius\n\n'
              '🜄 Jala (Water) — Taste, cohesion, emotions, circulation\n'
              '   Planets: Moon, Venus | Signs: Cancer, Scorpio, Pisces\n\n'
              '🜆 Prithvi (Earth) — Smell, stability, structure, bones\n'
              '   Planets: Mercury | Signs: Taurus, Virgo, Capricorn',
        ),
        _Section(
          title: 'Elemental Balance in Your Chart',
          body:
              'Count planets (Sun through Saturn) by element:\n\n'
              'Dominant (4+ planets): That element drives your life. You express '
              'through its mode naturally.\n\n'
              'Balanced (2–3 each): Versatile, adaptable. You can shift modes.\n\n'
              'Deficient (0–1): A blind spot. You may overcompensate or attract '
              'people strong in that element. Remedies: food, color, mantra, '
              'environment aligned with the missing element.\n\n'
              'Example: Zero Fire planets → low drive, digestion issues, '
              'difficulty initiating. Remedy: Sun salutations, red/orange colors, '
              'spicy food, candle gazing (trataka).',
        ),
        _Section(
          title: 'Elemental Interactions — Creation & Destruction Cycles',
          body:
              'Creation (Generating) Cycle — each element feeds the next:\n'
              'Wood (Fire) → Ash (Earth) → Metal (Air) → Water → Wood...\n'
              'Fire creates Earth (ash); Earth bears Metal; Metal holds Water; '
              'Water nourishes Wood; Wood feeds Fire.\n\n'
              'Destruction (Controlling) Cycle — each element controls another:\n'
              'Fire melts Metal; Metal cuts Wood; Wood parts Earth; Earth dams Water; '
              'Water extinguishes Fire.\n\n'
              'In remedies: strengthen the element that controls your excess, or '
              'support the element your deficiency creates.',
        ),
        _Section(
          title: 'Worked Example',
          body:
              'Chart with Fire: Sun, Mars, Jupiter (3) | Earth: Mercury, Saturn (2) '
              '| Air: Rahu (1) | Water: Moon, Venus (2) | Ether: 0\n\n'
              'Dominant Fire — natural leader, enthusiastic, initiates but may burn out. '
              'Deficient Ether — struggles with "big picture" vision, spiritual '
              'connection feels abstract. Remedy: Akasha practices — meditation, '
              'chanting OM, open-sky time, silence. Wear yellow (Jupiter) or gold '
              'to boost the Fire that generates Ether in the creation cycle.',
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