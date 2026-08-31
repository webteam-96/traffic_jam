import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/services/consult_api.dart';
import 'package:traffic_jam/nav.dart';

/// PUSHED screen — history of questions the user asked Jay.
/// Wired to GET /consult/questions.
class MyQuestionsScreen extends StatefulWidget {
  const MyQuestionsScreen({super.key});

  @override
  State<MyQuestionsScreen> createState() => _MyQuestionsScreenState();
}

class _MyQuestionsScreenState extends State<MyQuestionsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ConsultApi.getQuestions();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errored = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DetailScaffold(
        title: 'My Questions',
        scrollable: false,
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
        ),
      );
    }

    if (_errored) {
      return DetailScaffold(
        title: 'My Questions',
        scrollable: false,
        child: Center(
          child: Text("Couldn't load your questions — check your connection.",
              textAlign: TextAlign.center, style: AppText.body),
        ),
      );
    }

    final answered = _items.where((e) => e['status'] == 'answered').length;
    return DetailScaffold(
      title: 'My Questions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Your History'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_items.length} asked · $answered answered',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text("You haven't asked Jay anything yet.",
                    style: AppText.body),
              ),
            )
          else
            for (final item in _items) ...[
              _QuestionCard(
                item: item,
                onTap: () =>
                    goToChat(context, questionId: item['id'] as String),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  static const _catIcons = {
    'Career': Icons.work_outline,
    'Finance': Icons.savings_outlined,
    'Health': Icons.favorite_border,
    'Relationship': Icons.favorite_border,
    'Business': Icons.business_center_outlined,
  };

  static String _relativeTime(String iso) {
    final raw = DateTime.tryParse(iso);
    if (raw == null) return '';
    // The backend always sends UTC wall-clock values, but a round-trip
    // through MySQL/EF Core loses the DateTimeKind, so some timestamps
    // arrive without a trailing 'Z' and Dart misreads them as local time.
    // Reinterpret the literal components as UTC regardless, then convert.
    final utc = raw.isUtc
        ? raw
        : DateTime.utc(raw.year, raw.month, raw.day, raw.hour, raw.minute,
            raw.second, raw.millisecond, raw.microsecond);
    final dt = utc.toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cat = item['domain'] as String? ?? 'Career';
    final answered = item['status'] == 'answered';
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryChip(label: cat, icon: _catIcons[cat] ?? Icons.help_outline),
              const Spacer(),
              _StatusChip(answered: answered),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            item['question'] as String? ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.serif(
              size: 16,
              height: 1.35,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.schedule, size: 13, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.xs),
              Text(_relativeTime(item['createdAt'] as String? ?? ''),
                  style: AppText.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.goldBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.gold),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppText.sans(
              size: 12,
              weight: FontWeight.w500,
              color: AppColors.goldLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.answered});
  final bool answered;

  @override
  Widget build(BuildContext context) {
    final color = answered ? AppColors.gold : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          answered ? Icons.check_circle_outline : Icons.hourglass_empty,
          size: 13,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          answered ? 'Answered' : 'Pending',
          style: AppText.sans(
            size: 12,
            weight: FontWeight.w600,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
