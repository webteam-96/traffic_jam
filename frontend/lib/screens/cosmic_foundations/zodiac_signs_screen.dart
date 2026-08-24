import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Cosmic Foundations: 12 Zodiac Signs
/// Educational reader page with formatted content.
class ZodiacSignsScreen extends StatelessWidget {
  const ZodiacSignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _CosmicFoundationsReader(
      title: '12 Zodiac Signs',
      subtitle: 'Discover your core identity',
      icon: Icons.auto_awesome,
      sections: const [
        _Section(
          title: 'The Zodiac Wheel',
          body:
              'The zodiac is a 360° belt divided into 12 equal signs of 30° each. '
              'Each sign represents a distinct archetype — a lens through which '
              'planetary energy expresses. Your Sun sign (the sign the Sun occupied '
              'at birth) reveals your core identity and life purpose. Your Moon sign '
              'shows your emotional nature. Your Lagna (Ascendant) shapes your physical '
              'body and how you meet the world.',
        ),
        _Section(
          title: 'The Four Elements',
          body:
              'Signs group into four elements, each with a shared temperament:\n\n'
              '🔥 Fire (Aries, Leo, Sagittarius) — Inspired, action-oriented, spirited\n'
              '🌍 Earth (Taurus, Virgo, Capricorn) — Grounded, practical, enduring\n'
              '💨 Air (Gemini, Libra, Aquarius) — Intellectual, social, communicative\n'
              '💧 Water (Cancer, Scorpio, Pisces) — Intuitive, emotional, receptive',
        ),
        _Section(
          title: 'The Three Modalities',
          body:
              'Each element has three modalities, describing how the energy moves:\n\n'
              '▶ Cardinal (Aries, Cancer, Libra, Capricorn) — Initiators, leaders\n'
              '▶ Fixed (Taurus, Leo, Scorpio, Aquarius) — Sustainers, stabilizers\n'
              '▶ Mutable (Gemini, Virgo, Sagittarius, Pisces) — Adapters, synthesizers',
        ),
        _Section(
          title: 'Quick Reference — All 12 Signs',
          body:
              '♈ Aries (Mar 21–Apr 19) — The Pioneer. Courageous, direct, initiates.\n'
              '♉ Taurus (Apr 20–May 20) — The Builder. Patient, sensual, values security.\n'
              '♊ Gemini (May 21–Jun 20) — The Messenger. Curious, adaptable, communicates.\n'
              '♋ Cancer (Jun 21–Jul 22) — The Nurturer. Protective, intuitive, remembers.\n'
              '♌ Leo (Jul 23–Aug 22) — The Performer. Generous, creative, leads with heart.\n'
              '♍ Virgo (Aug 23–Sep 22) — The Analyst. Precise, service-oriented, refines.\n'
              '♎ Libra (Sep 23–Oct 22) — The Diplomat. Harmonious, fair, seeks balance.\n'
              '♏ Scorpio (Oct 23–Nov 21) — The Transformer. Intense, penetrating, regenerates.\n'
              '♐ Sagittarius (Nov 22–Dec 21) — The Explorer. Optimistic, philosophical, expands.\n'
              '♑ Capricorn (Dec 22–Jan 19) — The Architect. Disciplined, ambitious, structures.\n'
              '♒ Aquarius (Jan 20–Feb 18) — The Innovator. Original, humanitarian, liberates.\n'
              '♓ Pisces (Feb 19–Mar 20) — The Mystic. Compassionate, imaginative, dissolves boundaries.',
        ),
        _Section(
          title: 'Worked Example',
          body:
              'If your Sun is in Virgo (Earth, Mutable), you express your core identity '
              'through practical service and continuous refinement. You notice details others '
              'miss and improve systems. But your Moon in Pisces (Water, Mutable) means your '
              'emotional world is boundless, dreamy, and deeply empathic — a beautiful contrast '
              'between analytical precision and oceanic feeling. This tension is your gift: '
              'you can translate the ineffable into useful form.',
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
          // Hero header
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

          // Content sections
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