import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/theme/app_assets.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';

/// About Astrologer Jay Kotecha — §13 of Business Flow.
/// Dedicated trust-building screen with bio, expertise, philosophy, insights, testimonials, and CTAs.
class AboutJayKotechaScreen extends StatelessWidget {
  const AboutJayKotechaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'About Jay Kotecha',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Portrait & name ────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(color: AppColors.goldBorderSoft),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      figmaAsset(Assets.avatar),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Jay Kotecha',
                    style: AppText.serif(size: 28, weight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                Text('Founder & Chief Astrologer',
                    style: AppText.sans(
                        size: 14, color: AppColors.textTan, letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // ── Biography ──────────────────────────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('BIOGRAPHY'),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Jay Kotecha is a practicing Vedic astrologer with over 18 years of experience '
                  'guiding individuals and businesses through life\'s critical intersections. '
                  'Trained in the traditional guru-shishya parampara under the lineage of '
                  'Pt. Sanjay Rath, he holds advanced certifications in Jaimini Sutras, '
                  'Prashna (horary), and KP (Krishnamurti Paddhati) systems.',
                  style: AppText.body,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Before dedicating himself fully to Jyotish, Jay spent a decade in corporate '
                  'finance and strategy consulting — an experience that grounds his readings in '
                  'practical decision-making rather than abstract prediction. He has served clients '
                  'across 22 countries and is a regular contributor to leading wellness platforms.',
                  style: AppText.body,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Jay founded Traffic Jam for Life to democratize access to authentic, '
                  'birth-chart-level guidance — moving astrology from entertainment to a daily '
                  'decision engine for the modern seeker.',
                  style: AppText.body.copyWith(color: AppColors.amber),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Areas of Expertise ─────────────────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('AREAS OF EXPERTISE'),
                const SizedBox(height: AppSpacing.lg),
                _ExpertiseChip('Vedic Astrology (Parashara)'),
                _ExpertiseChip('KP System (Krishnamurti Paddhati)'),
                _ExpertiseChip('Prashna / Horary Astrology'),
                _ExpertiseChip('Remedial Astrology (Mantra, Yantra, Dana)'),
                _ExpertiseChip('Financial & Business Astrology'),
                _ExpertiseChip('Relationship & Compatibility Analysis'),
                _ExpertiseChip('Muhurat / Electional Astrology'),
                _ExpertiseChip('Nakshatra & Dasha Deep-Dives'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Philosophy ─────────────────────────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('PHILOSOPHY & APPROACH'),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '"Astrology is a compass, not a verdict. The planets show the weather; '
                  'you choose the path. My role is to read the sky clearly so you can walk '
                  'with confidence — whether the signal is green, yellow, or red."',
                  style: AppText.serif(size: 18, height: 1.5, color: AppColors.textCream),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.play_arrow,
                          color: AppColors.gold, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Play Philosophy Statement',
                              style: AppText.sans(
                                  size: 14,
                                  weight: FontWeight.w600,
                                  color: AppColors.gold)),
                          Text('2:14 min • Audio narration by Jay',
                              style: AppText.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Featured Insights ──────────────────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('FEATURED INSIGHTS'),
                const SizedBox(height: AppSpacing.md),
                _InsightItem(
                  date: 'August 2026',
                  title: 'Saturn Retrograde in Pisces: The Karmic Review',
                  excerpt:
                      'Saturn\'s retrograde through Pisces until November invites a collective '
                      'reckoning with spiritual debts and unconscious patterns...',
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(color: AppColors.borderFaint, height: 1),
                const SizedBox(height: AppSpacing.md),
                _InsightItem(
                  date: 'July 2026',
                  title: 'Jupiter in Gemini: The Curious Expansion',
                  excerpt:
                      'Jupiter\'s transit through Gemini amplifies communication, learning, '
                      'and short-distance travel. For mutable ascendants...',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Testimonials ───────────────────────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('CLIENT TESTIMONIALS'),
                const SizedBox(height: AppSpacing.md),
                _Testimonial(
                  quote:
                      '"Jay\'s reading on my Saturn return timing was uncannily precise. '
                      'He identified the exact month my career would pivot — and it did."',
                  author: '— Rohan M., Software Architect',
                ),
                const SizedBox(height: AppSpacing.lg),
                _Testimonial(
                  quote:
                      '"The remedy suggestions were practical, not ritualistic. Drinking water '
                      'from a copper vessel during my Mars transit genuinely shifted my energy."',
                  author: '— Anjali S., Entrepreneur',
                ),
                const SizedBox(height: AppSpacing.lg),
                _Testimonial(
                  quote:
                      '"Business Muhurat for our Series A close — we timed the term sheet '
                      'signing to Abhijit Muhurat. Round oversubscribed in 48 hours."',
                  author: '— Vikram P., Founder',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // ── CTA Buttons ────────────────────────────────────────────────
          GoldButton(
            label: 'ASK JAY A QUESTION',
            icon: Icons.chat_bubble_outline,
            onPressed: () => goToChat(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          GoldButton(
            label: 'BOOK AN APPOINTMENT',
            icon: Icons.calendar_month,
            outlined: true,
            onPressed: () => goToBookAppointment(context),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _ExpertiseChip extends StatelessWidget {
  const _ExpertiseChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.navBarBase.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.goldBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, size: 14, color: AppColors.amber),
            const SizedBox(width: AppSpacing.sm),
            Text(label,
                style: AppText.sans(
                    size: 13, weight: FontWeight.w500, color: AppColors.textCream)),
          ],
        ),
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  const _InsightItem({
    required this.date,
    required this.title,
    required this.excerpt,
  });
  final String date;
  final String title;
  final String excerpt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(date,
            style: AppText.sans(
                size: 11, weight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.xs),
        Text(title,
            style: AppText.sans(
                size: 16, weight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.xs),
        Text(excerpt, style: AppText.bodySmall),
      ],
    );
  }
}

class _Testimonial extends StatelessWidget {
  const _Testimonial({required this.quote, required this.author});
  final String quote;
  final String author;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('"$quote"',
            style: AppText.sans(
                size: 14, color: AppColors.textTan, height: 20 / 14)),
        const SizedBox(height: AppSpacing.sm),
        Text(author,
            style: AppText.sans(
                size: 12, weight: FontWeight.w700, color: AppColors.textCream)),
      ],
    );
  }
}