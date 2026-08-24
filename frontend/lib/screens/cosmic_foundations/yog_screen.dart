import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Cosmic Foundations: Yog in Astrology
class YogScreen extends StatelessWidget {
  const YogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _CosmicFoundationsReader(
      title: 'Yog in Astrology',
      subtitle: 'Powerful cosmic pairings',
      icon: Icons.auto_awesome_motion,
      sections: const [
        _Section(
          title: 'What Is a Yoga?',
          body:
              'A Yoga (union) is a specific planetary combination that produces a '
              'distinct, often dramatic result — far beyond what the individual '
              'planets would give alone. There are hundreds of documented yogas in '
              'classical texts (Brihat Parashara Hora Shastra, Phaladeepika, etc.). '
              'Some confer wealth, power, fame; others indicate challenges, '
              'renunciation, or spiritual gifts. A single chart typically contains '
              '15–30 active yogas. The art is in weighing their relative strength, '
              'timing (dasha activation), and mutual modification.',
        ),
        _Section(
          title: 'The Pancha Mahapurusha Yogas — Five Great Personages',
          body:
              'Formed when a planet (Mars, Mercury, Jupiter, Venus, Saturn) is in '
              'its own sign or exaltation IN a kendra (1, 4, 7, 10) from Lagna or Moon:\n\n'
              '🟢 Ruchaka Yoga (Mars) — Warrior, commander, courageous, landed property\n'
              '🟢 Bhadra Yoga (Mercury) — Intellectual, writer, speaker, youthful\n'
              '🟢 Hamsa Yoga (Jupiter) — Wise, righteous, wealthy, respected teacher\n'
              '🟢 Malavya Yoga (Venus) — Luxurious, artistic, beloved, vehicles, comfort\n'
              '🟢 Sasa Yoga (Saturn) — Disciplined, authoritative, long-lived, command\n\n'
              'These are the "celebrity" yogas — visible, tangible results in the world.',
        ),
        _Section(
          title: 'Major Raja Yogas — Combinations for Power',
          body:
              'Raja Yogas link kendra lords (1,4,7,10) with trikona lords (1,5,9):\n\n'
              '• Kendra lord + Trikona lord in mutual aspect/conjunction/exchange\n'
              '• 9th lord in 10th, or 10th lord in 9th (Dharma-Karma-Adhipati)\n'
              '• 5th lord + 9th lord together (highest wisdom + creativity)\n'
              '• Lagna lord in kendra/trikona, aspected by benefics\n\n'
              'The more such linkages, the greater the "royal" result — leadership, '
              'authority, recognition. But they require dasha activation to fructify.',
        ),
        _Section(
          title: 'Dhana Yogas (Wealth) & Daridra Yogas (Poverty)',
          body:
              'Wealth yogas connect 2nd, 11th, 5th, 9th lords:\n'
              '• 2nd lord + 11th lord together = massive income\n'
              '• 9th lord in 2nd, or 2nd lord in 9th = fortune through wisdom\n'
              '• 5th lord + 11th lord = speculative gains, creative income\n\n'
              'Daridra (poverty) yogas:\n'
              '• 12th lord in 2nd/11th, or 2nd/11th lords in 12th\n'
              '• Malefics in 2nd/11th without benefic aspect\n'
              '• 8th lord afflicting 2nd/11th = sudden losses\n\n'
              'Remedies strengthen the weak link — e.g., if 2nd lord is afflicted, '
              'strengthen its dispositor or propitiate the afflicting planet.',
        ),
        _Section(
          title: 'Worked Example',
          body:
              'Chart: Leo Lagna. Sun (Lagna lord) in 10th (Taurus) with Mercury '
              '(2nd/11th lord). Jupiter (5th/8th lord) in 9th (Aries) own sign.\n\n'
              'Yogas present:\n'
              '1. Sun in 10th (kendra) — not own/exalted, but strong by placement\n'
              '2. Mercury (2nd/11th lord) with Sun in 10th = Dhana + Raja Yoga\n'
              '3. Jupiter in 9th (trikona) own sign = Hamsa Yoga (Mahapurusha)\n'
              '4. 9th lord Mars in 4th (kendra) = Raja Yoga\n\n'
              'Timing: Jupiter Mahadasha (Hamsa Yoga lord) activates the wisdom/teaching '
              'yoga. Mercury Antardasha triggers the wealth/communication yoga. The '
              'person becomes a recognized authority (Sun in 10th) who teaches '
              '(Jupiter) and monetizes knowledge (Mercury 2nd/11th). Classic guru-entrepreneur.',
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