import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

/// Astrologer chat thread (pushed screen). Context chips + alternating
/// message bubbles + pinned input bar. All data mocked inline.
class AskChatScreen extends StatefulWidget {
  const AskChatScreen({super.key});

  @override
  State<AskChatScreen> createState() => _AskChatScreenState();
}

class _AskChatScreenState extends State<AskChatScreen> {
  final _input = TextEditingController();

  // Mock thread — seeded, grows when you send.
  final List<_Msg> _messages = [
    const _Msg(
      "Namaste. I've pulled up your birth chart. What's weighing on you today?",
      fromJay: true,
    ),
    const _Msg(
      "I've been offered a new job, but Saturn is sitting in my 10th house right now. Should I switch?",
      fromJay: false,
    ),
    const _Msg(
      "Saturn in the 10th is a test of patience, not a stop sign. It rewards disciplined moves. The offer itself is well-timed — Jupiter aspects your career house through August.",
      fromJay: true,
    ),
    const _Msg(
      "That's reassuring. When would be the most auspicious day to sign?",
      fromJay: false,
    ),
    const _Msg(
      "Avoid the Rahu Kaal windows. The 22nd, after 11 AM, carries a clean Mercury–Moon alignment — ideal for contracts and commitments.",
      fromJay: true,
    ),
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_Msg(t, fromJay: false));
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Jay',
      scrollable: true,
      bottomBar: _inputBar(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Context chips ─────────────────────────────────────
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: const [
              _Chip(Icons.auto_awesome, 'Birth chart attached'),
              _Chip(Icons.work_outline, 'Career'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text('TODAY',
                style: AppText.microLabel.copyWith(letterSpacing: 1.6)),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Message bubbles ───────────────────────────────────
          for (final m in _messages) ...[
            _bubble(m),
            const SizedBox(height: AppSpacing.md),
          ],

          // Clearance so the last bubble sits above the pinned input bar.
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── One message row ─────────────────────────────────────────
  Widget _bubble(_Msg m) {
    final maxW = MediaQuery.sizeOf(context).width * 0.76;
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: m.fromJay ? _jayBubble(m.text) : _userBubble(m.text),
    );

    if (m.fromJay) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _avatar(),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: content),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [Flexible(child: Align(alignment: Alignment.centerRight, child: content))],
    );
  }

  Widget _jayBubble(String text) => GlassCard(
        radius: AppRadius.lg,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        fill: AppColors.surfaceRaised,
        fillOpacity: 0.55,
        borderColor: AppColors.borderSoft,
        child: Text(
          text,
          style: AppText.sans(
              size: 15, color: AppColors.textCream, height: 22 / 15),
        ),
      );

  Widget _userBubble(String text) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: const BoxDecoration(
          gradient: AppColors.goldButtonGradient,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(AppRadius.lg),
            bottomRight: Radius.circular(AppSpacing.xs),
          ),
        ),
        child: Text(
          text,
          style: AppText.sans(
              size: 15,
              weight: FontWeight.w500,
              color: AppColors.textOnGold,
              height: 22 / 15),
        ),
      );

  Widget _avatar() => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.goldBorderSoft),
        ),
        alignment: Alignment.center,
        child: Text('J',
            style: AppText.serif(
                size: 16, weight: FontWeight.w700, color: AppColors.gold)),
      );

  // ── Pinned bottom input bar ─────────────────────────────────
  Widget _inputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBarBase,
        border: Border(top: BorderSide(color: AppColors.goldBorderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    cursorColor: AppColors.gold,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppText.sans(size: 15, color: AppColors.textPrimary),
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      hintText: 'Message Jay...',
                      hintStyle:
                          AppText.sans(size: 15, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.goldButton,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldButton.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_upward,
                      color: AppColors.textOnGold, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small context pill above the thread.
class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.goldBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.gold),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(label,
              style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  color: AppColors.textTan)),
        ],
      ),
    );
  }
}

class _Msg {
  const _Msg(this.text, {required this.fromJay});
  final String text;
  final bool fromJay;
}
