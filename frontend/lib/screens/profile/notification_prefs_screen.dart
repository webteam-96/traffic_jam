import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';
import 'package:traffic_jam/services/user_api.dart';
import 'package:traffic_jam/services/api_client.dart';

/// Notification preferences — grouped toggle rows in a single GlassCard.
/// Pushed screen, so it roots in DetailScaffold. Wired to GET/PUT
/// /me/notification-preferences.
class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  static const _prefs = <_Pref>[
    _Pref('morning', 'Morning Briefing', 'Your daily signal, 6–7 AM', Icons.wb_twilight),
    _Pref('rahuKaal', 'Rahu Kaal Warning', 'Alert 15 min before the window',
        Icons.warning_amber_rounded),
    _Pref('events', 'Planetary Events', 'Transits, retrogrades & conjunctions', Icons.public),
    _Pref('dasha', 'Dasha Reminders', 'When a planetary period shifts', Icons.timeline),
    _Pref('remedies', 'Remedy Reminders', 'Nudges for your prescribed remedies',
        Icons.spa_outlined),
  ];

  // Fallback defaults for a category the backend hasn't stored channels for yet.
  static const _defaultChannels = <String, Set<String>>{
    'morning': {'Push'},
    'rahuKaal': {'Push', 'WhatsApp'},
    'events': {'Push'},
    'dasha': {'Push', 'Email'},
    'remedies': {'Push'},
  };

  static const _allChannels = ['Push', 'Email', 'WhatsApp'];

  final Map<String, bool> _on = {};
  final Map<String, Set<String>> _channels = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await UserApi.getNotificationPrefs();
      final channelsJson = (data['channels'] as Map?)?.cast<String, dynamic>() ?? {};
      for (final p in _prefs) {
        _on[p.key] = data[p.key] as bool? ?? false;
        final stored = channelsJson[p.key] as List?;
        _channels[p.key] = stored != null
            ? stored.cast<String>().toSet()
            : {..._defaultChannels[p.key]!};
      }
    } catch (_) {
      // Fall back to sensible defaults so the screen is still usable offline.
      for (final p in _prefs) {
        _on[p.key] = p.key == 'events' || p.key == 'remedies' ? false : true;
        _channels[p.key] = {..._defaultChannels[p.key]!};
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleChannel(String key, String channel) => setState(() {
        final set = _channels[key]!;
        if (set.contains(channel)) {
          if (set.length > 1) set.remove(channel);
        } else {
          set.add(channel);
        }
      });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserApi.saveNotificationPrefs(
        morning: _on['morning']!,
        rahuKaal: _on['rahuKaal']!,
        events: _on['events']!,
        dasha: _on['dasha']!,
        remedies: _on['remedies']!,
        channels: {for (final p in _prefs) p.key: _channels[p.key]!.toList()},
      );
      if (!mounted) return;
      toast(context, 'Notification preferences saved');
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message);
    } catch (_) {
      if (!mounted) return;
      toast(context, "Couldn't reach the server — check your connection.");
    } finally {
      if (mounted) setState(() => _saving = false);
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

    return DetailScaffold(
      title: 'Notifications',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Stay in the loop', style: AppText.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Choose which cosmic signals reach you. We only ping when it matters.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionLabel('ALERTS'),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (int i = 0; i < _prefs.length; i++) ...[
                  if (i > 0)
                    const Divider(
                        height: 1, thickness: 1, color: AppColors.borderFaint),
                  _PrefRow(
                    pref: _prefs[i],
                    value: _on[_prefs[i].key]!,
                    onChanged: (v) => setState(() => _on[_prefs[i].key] = v),
                    channels: _channels[_prefs[i].key]!,
                    allChannels: _allChannels,
                    onChannelToggle: (c) => _toggleChannel(_prefs[i].key, c),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          GoldButton(
            label: _saving ? 'SAVING…' : 'SAVE PREFERENCES',
            icon: Icons.check,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _Pref {
  const _Pref(this.key, this.title, this.subtitle, this.icon);
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({
    required this.pref,
    required this.value,
    required this.onChanged,
    required this.channels,
    required this.allChannels,
    required this.onChannelToggle,
  });

  final _Pref pref;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Set<String> channels;
  final List<String> allChannels;
  final ValueChanged<String> onChannelToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(child: Icon(pref.icon, color: AppColors.gold, size: 20)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pref.title, style: AppText.cardTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(pref.subtitle, style: AppText.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.textOnGold,
                activeTrackColor: AppColors.gold,
                inactiveThumbColor: AppColors.textMuted,
                inactiveTrackColor: AppColors.surfaceRaised2,
              ),
            ],
          ),
          if (value) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final c in allChannels)
                    _ChannelChip(
                      label: c,
                      selected: channels.contains(c),
                      onTap: () => onChannelToggle(c),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.amber.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.gold : AppColors.borderSoft),
        ),
        child: Text(
          label,
          style: AppText.sans(
            size: 11,
            weight: FontWeight.w500,
            color: selected ? AppColors.gold : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
