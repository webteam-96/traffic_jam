import 'package:flutter/material.dart';
import 'details/time_windows_screen.dart';
import 'details/traffic_signal_screen.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/services/notification_api.dart';
import 'package:traffic_jam/nav.dart';

/// Notifications inbox (pushed screen). Frosted alert rows with a tinted
/// leading glyph, title, body and relative time. Tapping a row marks it read
/// and opens whatever it is about; the app-bar action clears all. Wired to
/// GET /notifications,
/// POST /notifications/{id}/read, POST /notifications/read-all.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

/// Icon + tint per backend `type` — the backend only sends a free-form type
/// string, not display metadata, so this is the presentation-layer mapping.
/// Falls back to a generic bell for any type not listed here.
/// Keyed on the category prefix of the backend's `type`, which is a dedupe
/// key rather than a label — "rahukaal:2026-09-09", `chat:<message id>`.
const Map<String, (IconData, Color, String)> _categoryStyle = {
  'morning': (Icons.trending_up_rounded, AppColors.success, 'Morning briefing'),
  'rahukaal': (Icons.warning_amber_rounded, AppColors.criticalText, 'Rahu Kaal'),
  'dasha': (Icons.timeline, AppColors.gold, 'Dasha'),
  'chat': (Icons.chat_bubble_outline, AppColors.amber, "Jay's reply"),
  'event': (Icons.auto_awesome_rounded, AppColors.gold, 'Planetary event'),
  'remedy': (Icons.spa_rounded, AppColors.gold, 'Remedy'),
};
const _defaultCategoryStyle =
    (Icons.notifications_none_rounded, AppColors.gold, 'Alert');

(IconData, Color, String) _styleFor(String type) =>
    _categoryStyle[type.split(':').first] ?? _defaultCategoryStyle;

String _relativeTime(String iso) {
  final raw = DateTime.tryParse(iso);
  if (raw == null) return '';
  // The backend always sends UTC wall-clock values, but some timestamps
  // round-trip through MySQL/EF Core without a trailing 'Z', so Dart misreads
  // them as local time. Reinterpret the literal components as UTC regardless.
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

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notifs = await NotificationApi.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifs = notifs;
        _errored = false;
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

  Future<void> _refresh() => _load();

  /// Marks the notification read and opens whatever it is about.
  ///
  /// The destination comes from the category prefix of the backend's `type`,
  /// which is a dedupe key of the form "category:...". A chat notification
  /// carries its question id there too, so it can open that conversation
  /// rather than the list.
  Future<void> _open(int index) async {
    final notif = _notifs[index];
    if (notif['read'] != true) {
      await _markRead(index);
    }

    if (!mounted) return;

    final type = notif['type'] as String? ?? '';
    final parts = type.split(':');

    switch (parts.first) {
      case 'morning':
        pushScreen(context, TrafficSignalScreen.new);
      case 'rahukaal':
        pushScreen(context, TimeWindowsScreen.new);
      case 'dasha':
        goToDashaTimeline(context);
      case 'chat':
        // "chat:<questionId>:<messageId>". An older notification written
        // before the question id was in the key falls back to the list rather
        // than opening a thread that can't be identified.
        if (parts.length >= 3) {
          goToChat(context, questionId: parts[1]);
        } else {
          goToMyQuestions(context);
        }
      default:
        // Nothing specific to open — the notification's own text is the whole
        // of it, so staying put is the honest response.
        break;
    }
  }

  Future<void> _markRead(int index) async {
    final id = _notifs[index]['id'] as String;
    setState(() => _notifs[index] = {..._notifs[index], 'read': true});
    try {
      await NotificationApi.markRead(id);
    } catch (_) {
      if (!mounted) return;
      toast(context, "Couldn't sync — check your connection.");
    }
  }

  Future<void> _markAllRead() async {
    final previous = _notifs;
    setState(() => _notifs = [
          for (final n in _notifs) {...n, 'read': true},
        ]);
    try {
      await NotificationApi.markAllRead();
    } catch (_) {
      if (!mounted) return;
      setState(() => _notifs = previous);
      toast(context, "Couldn't reach the server — check your connection.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DetailScaffold(
        title: 'Notifications',
        scrollable: false,
        child: LoadingView(height: null),
      );
    }

    if (_errored) {
      return DetailScaffold(
        title: 'Notifications',
        scrollable: false,
        child: RetryView(
          height: null,
          message: "Couldn't load notifications",
          onRetry: _refresh,
        ),
      );
    }

    final indices = [for (var i = 0; i < _notifs.length; i++) i];
    final unread = _notifs.where((n) => n['read'] != true).length;

    return DetailScaffold(
      title: 'Notifications',
      actions: [
        IconButton(
          onPressed: unread == 0 ? null : _markAllRead,
          tooltip: 'Mark all read',
          icon: Icon(
            Icons.done_all_rounded,
            size: 20,
            color: unread == 0 ? AppColors.textMuted : AppColors.gold,
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            unread == 0 ? 'All caught up' : '$unread new alert${unread == 1 ? '' : 's'}',
            style: AppText.headingSerif,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The cosmos has been keeping notes for you.',
            style: AppText.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (indices.isEmpty)
            _EmptyState(hasAny: _notifs.isNotEmpty)
          else
            for (final i in indices) ...[
              _NotifRow(
                notif: _notifs[i],
                // Always tappable now: an already-read notification still has
                // somewhere to go, and a row that stops responding once read
                // reads as broken.
                onTap: () => _open(i),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({required this.notif, required this.onTap});
  final Map<String, dynamic> notif;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final read = notif['read'] == true;
    final type = notif['type'] as String? ?? '';
    final (icon, tint, categoryLabel) = _styleFor(type);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      goldTopBorder: !read,
      fillOpacity: read ? 0.28 : 0.4,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 22, color: tint),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notif['title'] as String? ?? '',
                        style: AppText.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!read)
                      Container(
                        margin: const EdgeInsets.only(
                            left: AppSpacing.sm, top: 6),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  notif['body'] as String? ?? '',
                  style: AppText.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${categoryLabel.toUpperCase()}  ·  '
                  '${_relativeTime(notif['at'] as String? ?? '')}',
                  style: AppText.microLabel.copyWith(color: AppColors.textTan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAny});
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          IconChip(
            size: 48,
            circular: true,
            child: const Icon(Icons.notifications_none_rounded,
                size: 24, color: AppColors.gold),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(hasAny ? 'No alerts here' : 'No notifications yet',
              style: AppText.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasAny
                ? 'Nothing in this category right now.'
                : "You're all caught up with the stars.",
            style: AppText.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
