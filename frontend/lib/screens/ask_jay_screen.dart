import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../nav.dart';
import '../services/consult_api.dart';
import '../services/api_client.dart';

/// Ask Jay tab — Figma node 1:247 (dc_247_askjay.txt).
/// Domain pills + question input + response-priority plans + send + social proof.
class AskJayScreen extends StatefulWidget {
  const AskJayScreen({super.key});

  @override
  State<AskJayScreen> createState() => _AskJayScreenState();
}

class _AskJayScreenState extends State<AskJayScreen> {
  static const _domains = ['Career', 'Relationship', 'Business'];
  int _domain = 0;
  /// The seeded standard-priority consult plan — see ConsultPlanRows.
  static const _standardPlanId = 'standard';
  final _question = TextEditingController();
  bool _sending = false;

  // White-input colors are design-specific (no dark-theme token fits).
  static const _inputText = Color(0xFF374151);
  static const _inputHint = Color(0xFF6B7280);

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion() async {
    final text = _question.text.trim();
    if (text.isEmpty) {
      toast(context, 'Type your question first');
      return;
    }
    try {
      final result = await ConsultApi.askQuestion(
        domain: _domains[_domain],
        question: text,
        // Every question goes in at the standard response time: the paid
        // priority tier isn't offered while the app has no way to take a
        // payment, so there is nothing to choose between.
        planId: _standardPlanId,
      );
      if (!mounted) return;
      _question.clear();
      goToChat(context, questionId: result['questionId'] as String);
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message);
    } catch (_) {
      if (!mounted) return;
      toast(context, "Couldn't reach the server — check your connection.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CosmicScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero ──────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Text(
                  'Ask Jay',
                  textAlign: TextAlign.center,
                  style: AppText.serif(
                    size: 40,
                    color: AppColors.gold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  "Decoding the celestial alignment to solve your life's "
                  'traffic jams. Get personalized astrological guidance from Jay.',
                  textAlign: TextAlign.center,
                  style: AppText.sans(
                    size: 16,
                    color: AppColors.textTan,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),

          // ── Domain + Question form ────────────────────────────
          GlassCard(
            fill: AppColors.surfaceRaised,
            fillOpacity: 0.6,
            borderColor: AppColors.borderSoft,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel(
                  'CHOOSE YOUR DOMAIN',
                  color: AppColors.goldLight,
                ),
                const SizedBox(height: AppSpacing.lg),
                PillToggle(
                  options: _domains,
                  selectedIndex: _domain,
                  onChanged: (i) => setState(() => _domain = i),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('YOUR QUESTION', color: AppColors.goldLight),
                const SizedBox(height: AppSpacing.md),
                _questionInput(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),

          const SizedBox(height: AppSpacing.xxl),

          // ── Send ──────────────────────────────────────────────
          GoldButton(
            label: _sending ? 'SENDING…' : 'SEND QUESTION',
            icon: Icons.send,
            onPressed: _sending ? null : _sendQuestion,
          ),
          const SizedBox(height: AppSpacing.section),

          // ── Wisdom of the Freeways ────────────────────────────
          _wisdomCard(),
        ],
      ),
    );
  }

  // ── Question textarea (white input per Figma) ───────────────
  // A single Border with mixed colors + borderRadius crashes Flutter's
  // painter ("borderRadius can only be given on borders with uniform
  // colors") — same issue fixed in glass_card.dart. Worked around with a
  // uniform border plus a separate 2px gold accent strip along the bottom.
  Widget _questionInput() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.borderSoft),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: _questionField(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(height: 2, color: AppColors.goldButton),
          ),
        ],
      ),
    );
  }

  Widget _questionField() {
    return TextField(
      controller: _question,
      maxLines: 5,
      maxLength: 500,
      cursorColor: AppColors.goldButton,
      style: AppText.sans(size: 16, color: _inputText, height: 1.5),
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) =>
              Opacity(
                opacity: 0.5,
                child: Text(
                  'Max 500 characters',
                  style: AppText.sans(size: 12, color: AppColors.textTan),
                ),
              ),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText:
            'Example: When is the best time for me to switch my career for '
            'maximum cosmic growth?',
        hintStyle: AppText.sans(size: 16, color: _inputHint, height: 1.5),
      ),
    );
  }


  // ── Wisdom of the Freeways (image + stats) ──────────────────
  Widget _wisdomCard() {
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.6,
      borderColor: AppColors.borderSoft,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: 0.6,
            child: Image.asset(
              figmaAsset('06729d35a049f9010cc058e0003316f7bc479fcc.png'),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The Wisdom of the Freeways',
                  style: AppText.sans(
                    size: 16,
                    color: AppColors.textCream,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Every planet in retrograde is just a traffic jam waiting to '
                  'be cleared. Jay uses traditional Vedic astrology combined '
                  "with modern celestial mechanics to guide you through life's "
                  'complex intersections.',
                  style: AppText.sans(
                    size: 14,
                    color: AppColors.textTan,
                    height: 20 / 14,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _statRow(
                  Icons.verified_user_outlined,
                  'WHO ANSWERS',
                  'Every question is reviewed personally by Jay or a vetted panel astrologer.',
                ),
                const SizedBox(height: AppSpacing.lg),
                _statRow(
                  Icons.access_time,
                  'RESPONSE TIME',
                  'Every question gets a considered reply, not an automated one.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.navBarBase,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.goldBorderSoft),
          ),
          child: Icon(icon, size: 18, color: AppColors.gold),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.goldLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: AppText.sans(
                  size: 14,
                  color: AppColors.textCream,
                  height: 20 / 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}

