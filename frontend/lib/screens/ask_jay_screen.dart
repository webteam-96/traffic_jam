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
  int _plan = 1; // 0 = Standard, 1 = Priority (active by default in design)
  final _question = TextEditingController();
  bool _sending = false;

  List<Map<String, dynamic>> _plans = [];
  bool _loadingPlans = true;

  // White-input colors are design-specific (no dark-theme token fits).
  static const _inputText = Color(0xFF374151);
  static const _inputHint = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    ConsultApi.getPlans().then((plans) {
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loadingPlans = false;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loadingPlans = false);
    });
  }

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
    if (_plan >= _plans.length) {
      toast(context, "Couldn't load plans — check your connection.");
      return;
    }
    setState(() => _sending = true);
    try {
      final result = await ConsultApi.askQuestion(
        domain: _domains[_domain],
        question: text,
        planId: _plans[_plan]['id'] as String,
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

          // ── Response priority ─────────────────────────────────
          const SectionLabel('RESPONSE PRIORITY', color: AppColors.goldLight),
          const SizedBox(height: AppSpacing.lg),
          if (_loadingPlans)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
              ),
            )
          else if (_plans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text("Couldn't load plans — check your connection.",
                  style: AppText.body),
            )
          else
            for (int i = 0; i < _plans.length; i++) ...[
              _planCard(
                index: i,
                title: _plans[i]['name'] as String,
                price: '₹${_plans[i]['priceRupees']}',
                popular: _plans[i]['id'] == 'priority',
                features: [
                  _Feature('Response within ${_plans[i]['slaHours']} hour${_plans[i]['slaHours'] == 1 ? '' : 's'}',
                      strong: _plans[i]['id'] == 'priority'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
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

  // ── Plan card (Standard / Priority) ─────────────────────────
  Widget _planCard({
    required int index,
    required String title,
    required String price,
    required List<Widget> features,
    bool popular = false,
  }) {
    final selected = _plan == index;
    final card = GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.6,
      borderColor: AppColors.borderSoft,
      goldTopBorder: selected,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () => setState(() => _plan = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppText.serif(
                  size: 24,
                  color: selected ? AppColors.goldLight : AppColors.textCream,
                  height: 1.4,
                ),
              ),
              Text(
                price,
                style: AppText.serif(
                  size: 24,
                  color: AppColors.gold,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...features,
          const SizedBox(height: AppSpacing.lg),
          _planButton(selected),
        ],
      ),
    );

    if (!popular) return card;
    // Corner "POPULAR" ribbon — outer clip trims it to a diagonal sliver.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Stack(
        children: [
          card,
          Positioned(
            top: 14,
            right: -30,
            child: Transform.rotate(
              angle: 0.7853981634, // 45°
              child: Container(
                color: AppColors.gold,
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 3,
                ),
                child: Text(
                  'POPULAR',
                  style: AppText.sans(
                    size: 10,
                    weight: FontWeight.w700,
                    color: AppColors.textOnGold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planButton(bool selected) {
    if (selected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          'Active Selection',
          textAlign: TextAlign.center,
          style: AppText.sans(
            size: 16,
            weight: FontWeight.w700,
            color: AppColors.textOnGold,
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        'Select Plan',
        textAlign: TextAlign.center,
        style: AppText.sans(
          size: 16,
          weight: FontWeight.w700,
          color: AppColors.textTan,
        ),
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
                  _plans.isEmpty
                      ? 'Priority questions get the fastest turnaround.'
                      : 'Priority questions get a reply within '
                          '${_plans.firstWhere((p) => p['id'] == 'priority', orElse: () => _plans.first)['slaHours']} hour(s).',
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

/// Check-marked feature line inside a plan card.
class _Feature extends StatelessWidget {
  const _Feature(this.text, {this.strong = false});
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check, size: 14, color: AppColors.amber),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppText.sans(
                size: 14,
                weight: strong ? FontWeight.w700 : FontWeight.w400,
                color: strong ? AppColors.textCream : AppColors.textTan,
                height: 20 / 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
