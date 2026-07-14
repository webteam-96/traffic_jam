import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../nav.dart';

/// Remedies engine — a pushed (non-tab) detail screen. Groups the day's
/// remedies by type (Behavioural, Mantra, Color Therapy, Timing), each with a
/// "triggered by" tag tracing it back to a transit. The mantra card has a gold
/// play toggle → StatefulWidget. All data mocked inline.
class RemediesScreen extends StatefulWidget {
  const RemediesScreen({super.key});

  @override
  State<RemediesScreen> createState() => _RemediesScreenState();
}

class _RemediesScreenState extends State<RemediesScreen> {
  bool _playing = false;

  static const Color _skyBlue = Color(0xFF87CEEB);

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Remedies',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel("TODAY'S REMEDIES"),
          const SizedBox(height: AppSpacing.sm),
          Text('Personalised for your current transits.', style: AppText.body),
          const SizedBox(height: AppSpacing.section),

          // ── Behavioural ────────────────────────────────────────────────
          _remedyCard(
            icon: Icons.self_improvement,
            type: 'Behavioural',
            trigger: 'Weak Mercury',
            body: Text(
              'Avoid arguments today',
              style: AppText.serif(
                  size: 20, color: AppColors.textCream, height: 1.35),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Mantra (with gold play toggle) ─────────────────────────────
          _remedyCard(
            icon: Icons.graphic_eq,
            type: 'Mantra',
            trigger: 'Debilitated Saturn',
            body: Row(
              children: [
                _playButton(),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Om Namah Shivaya · 108x',
                    style: AppText.serif(
                        size: 18, color: AppColors.textCream, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Color Therapy (swatch) ─────────────────────────────────────
          _remedyCard(
            icon: Icons.palette_outlined,
            type: 'Color Therapy',
            trigger: 'Weak Mercury',
            body: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _skyBlue,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.goldBorderSoft),
                    boxShadow: [
                      BoxShadow(
                        color: _skyBlue.withValues(alpha: 0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Wear sky blue',
                    style: AppText.serif(
                        size: 18, color: AppColors.textCream, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Timing ─────────────────────────────────────────────────────
          _remedyCard(
            icon: Icons.schedule,
            type: 'Timing',
            trigger: 'Rahu Transit',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perform during Abhijit Muhurat',
                  style: AppText.serif(
                      size: 18, color: AppColors.textCream, height: 1.3),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time,
                        size: 15, color: AppColors.amber),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '11:48 – 12:36',
                      style: AppText.sans(
                          size: 14,
                          weight: FontWeight.w600,
                          color: AppColors.amber,
                          letterSpacing: 0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),

          GoldButton(
            label: 'Add all to reminders',
            outlined: true,
            icon: Icons.notifications_none,
            onPressed: () => toast(context, 'All remedies added to reminders'),
          ),
        ],
      ),
    );
  }

  // ── Remedy card shell: icon + type header, body, trigger tag ───────────
  Widget _remedyCard({
    required IconData icon,
    required String type,
    required String trigger,
    required Widget body,
  }) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(child: Icon(icon, size: 20, color: AppColors.gold)),
              const SizedBox(width: AppSpacing.md),
              Text(
                type,
                style: AppText.cardTitle.copyWith(color: AppColors.goldLight),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          body,
          const SizedBox(height: AppSpacing.lg),
          _triggerTag(trigger),
        ],
      ),
    );
  }

  Widget _triggerTag(String cause) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 13, color: AppColors.amber),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: 'triggered by ',
                style: AppText.sans(size: 12, color: AppColors.textMuted),
                children: [
                  TextSpan(
                    text: cause,
                    style: AppText.sans(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.amber),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _playButton() {
    return GestureDetector(
      onTap: () => setState(() => _playing = !_playing),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: AppColors.goldButtonGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.goldButton.withValues(alpha: 0.4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(
          _playing ? Icons.pause : Icons.play_arrow,
          color: AppColors.textOnGold,
          size: 24,
        ),
      ),
    );
  }
}
