import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../services/consult_api.dart';
import '../../services/api_client.dart';
import '../../nav.dart';

/// Astrologer chat thread (pushed screen). Context chips + alternating
/// message bubbles + pinned input bar. Wired to GET/POST
/// /consult/questions/{id}/messages.
class AskChatScreen extends StatefulWidget {
  const AskChatScreen({super.key, required this.questionId});
  final String questionId;

  @override
  State<AskChatScreen> createState() => _AskChatScreenState();
}

class _AskChatScreenState extends State<AskChatScreen> {
  final _input = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final messages = await ConsultApi.getMessages(widget.questionId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      toast(context, "Couldn't load this conversation — check your connection.");
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      final msg = await ConsultApi.sendMessage(widget.questionId, t);
      if (!mounted) return;
      setState(() => _messages = [..._messages, msg]);
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message);
    } catch (_) {
      if (!mounted) return;
      toast(context, "Couldn't send — check your connection.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Jay',
      scrollable: !_loading,
      bottomBar: _inputBar(),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Context chips ─────────────────────────────────────
                const Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Chip(Icons.auto_awesome, 'Birth chart attached'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_messages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        'Your question has been sent to Jay. Replies will '
                        'appear here within your plan\'s SLA window.',
                        textAlign: TextAlign.center,
                        style: AppText.sans(size: 14, color: AppColors.textTan),
                      ),
                    ),
                  )
                else ...[
                  Center(
                    child: Text('THREAD',
                        style: AppText.microLabel.copyWith(letterSpacing: 1.6)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final m in _messages) ...[
                    _bubble(m),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],

                // Clearance so the last bubble sits above the pinned input bar.
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  // ── One message row ─────────────────────────────────────────
  Widget _bubble(Map<String, dynamic> m) {
    final fromJay = m['sender'] == 'astrologer';
    final text = m['text'] as String;
    final maxW = MediaQuery.sizeOf(context).width * 0.76;
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: fromJay ? _jayBubble(text) : _userBubble(text),
    );

    if (fromJay) {
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
                onTap: _sending ? null : _send,
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
