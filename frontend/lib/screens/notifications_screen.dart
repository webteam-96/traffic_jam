import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/services/notification_api.dart';
import 'package:traffic_jam/nav.dart';

/// Notifications inbox (pushed screen). Frosted alert rows with a tinted
/// leading glyph, title, body and relative time. Tap a row to mark it read;
/// the app-bar action clears all. Wired to GET /notifications,
/// POST /notifications/{id}/read, POST /notifications/read-all.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

/// Icon + tint per backend `type` — the backend only sends a free-form type
/// string, not display metadata, so this is the presentation-layer mapping.
/// Falls back to a generic bell for any type not listed here.
const Map<String, (IconData, Color)> _typeStyle = {
  'morning_briefing': (Icons.trending_up_rounded, AppColors.success),
  'rahu_kaal': (Icons.warning_amber_rounded, AppColors.criticalText),
  'transit': (Icons.auto_awesome_rounded, AppColors.gold),
  'planetary_event': (Icons.auto_awesome_rounded, AppColors.gold),
  'dasha': (Icons.timeline, AppColors.gold),
  'remedy': (Icons.spa_rounded, AppColors.gold),
  'announcement': (Icons.celebration_outlined, AppColors.amber),
  'forecast': (Icons.calendar_month_rounded, AppColors.amber),
};
const _defaultTypeStyle = (Icons.notifications_none_rounded, AppColors.gold);

String _humanizeType(String type) => type
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

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
  int _filter = 0; // 0 = All, 1 = System, 2 = Team

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
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
        ),
      );
    }

    if (_errored) {
      return DetailScaffold(
        title: 'Notifications',
        scrollable: false,
        child: Center(
          child: Text("Couldn't load notifications — check your connection.",
              textAlign: TextAlign.center, style: AppText.body),
        ),
      );
    }

    final indices = [
      for (var i = 0; i < _notifs.length; i++)
        if (_filter == 0 ||
            (_filter == 1 && _notifs[i]['source'] == 'system') ||
            (_filter == 2 && _notifs[i]['source'] == 'team'))
          i,
    ];
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
          PillToggle(
            options: const ['All', 'System', 'Team'],
            selectedIndex: _filter,
            onChanged: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (indices.isEmpty)
            _EmptyState(hasAny: _notifs.isNotEmpty)
          else
            for (final i in indices) ...[
              _NotifRow(
                notif: _notifs[i],
                onTap: _notifs[i]['read'] == true ? null : () => _markRead(i),
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
    final (icon, tint) = _typeStyle[type] ?? _defaultTypeStyle;
    final source = notif['source'] == 'team' ? _Source.team : _Source.system;

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
                Row(
                  children: [
                    _SourceTag(source: source),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${_humanizeType(type).toUpperCase()}  ·  '
                        '${_relativeTime(notif['at'] as String? ?? '')}',
                        style: AppText.microLabel.copyWith(color: AppColors.textTan),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Source { system, team }

/// Small tag distinguishing an app-generated alert from a team announcement.
class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.source});
  final _Source source;

  @override
  Widget build(BuildContext context) {
    final isTeam = source == _Source.team;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isTeam ? AppColors.gold : AppColors.textMuted).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        isTeam ? 'TEAM' : 'SYSTEM',
        style: AppText.sans(
          size: 8,
          weight: FontWeight.w700,
          color: isTeam ? AppColors.gold : AppColors.textMuted,
          letterSpacing: 0.6,
        ),
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
