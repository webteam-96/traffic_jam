import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Notifications inbox (pushed screen). Frosted alert rows with a tinted
/// leading glyph, title, body and relative time. Tap a row to mark it read;
/// the app-bar action clears all. All data mocked inline.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _Notif {
  const _Notif(this.icon, this.tint, this.title, this.body, this.category,
      this.time);
  final IconData icon;
  final Color tint;
  final String title;
  final String body;
  final String category;
  final String time;
}

const List<_Notif> _kNotifs = [
  _Notif(
    Icons.trending_up_rounded,
    AppColors.success,
    'GREEN Day!',
    'Moon in Taurus supports financial decisions today.',
    'Morning Briefing',
    '7:00 AM',
  ),
  _Notif(
    Icons.warning_amber_rounded,
    AppColors.criticalText,
    'Rahu Kaal begins in 15 minutes',
    'Avoid starting new ventures until the window passes.',
    'Warning',
    '1h ago',
  ),
  _Notif(
    Icons.auto_awesome_rounded,
    AppColors.gold,
    'Jupiter aspecting your Lagna',
    'Growth amplified — a favourable window for bold moves.',
    'Transit',
    '3h ago',
  ),
  _Notif(
    Icons.spa_rounded,
    AppColors.gold,
    'New remedy suggested',
    'Chant the Budha mantra to steady Mercury this week.',
    'Remedy',
    '5h ago',
  ),
  _Notif(
    Icons.calendar_month_rounded,
    AppColors.amber,
    'Your weekly forecast is ready',
    'Seven days of vibe scores and key transits await.',
    'Forecast',
    '1d ago',
  ),
];

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Unread state, indexed to _kNotifs. Newest three start unread.
  final List<bool> _read = List<bool>.generate(_kNotifs.length, (i) => i > 2);
  int _filter = 0; // 0 = All, 1 = Unread

  void _markAllRead() => setState(() {
        for (var i = 0; i < _read.length; i++) {
          _read[i] = true;
        }
      });

  @override
  Widget build(BuildContext context) {
    final indices = [
      for (var i = 0; i < _kNotifs.length; i++)
        if (_filter == 0 || !_read[i]) i,
    ];
    final unread = _read.where((r) => !r).length;

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
            options: const ['All', 'Unread'],
            selectedIndex: _filter,
            onChanged: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (indices.isEmpty)
            _EmptyState()
          else
            for (final i in indices) ...[
              _NotifRow(
                notif: _kNotifs[i],
                read: _read[i],
                onTap: () => setState(() => _read[i] = true),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({required this.notif, required this.read, required this.onTap});
  final _Notif notif;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      goldTopBorder: !read,
      fillOpacity: read ? 0.28 : 0.4,
      onTap: read ? null : onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: notif.tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(notif.icon, size: 22, color: notif.tint),
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
                        notif.title,
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
                  notif.body,
                  style: AppText.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${notif.category.toUpperCase()}  ·  ${notif.time}',
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
          Text('No unread alerts', style: AppText.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "You're all caught up with the stars.",
            style: AppText.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
