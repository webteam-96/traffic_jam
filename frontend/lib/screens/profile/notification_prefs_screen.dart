import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Notification preferences — grouped toggle rows in a single GlassCard.
/// Pushed screen, so it roots in DetailScaffold.
/// ponytail: toggles are local state over mocked defaults; wire to real
/// prefs persistence when the settings backend exists.
class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  static const _prefs = <_Pref>[
    _Pref('Morning Briefing', 'Your daily signal, 6–7 AM',
        Icons.wb_twilight),
    _Pref('Rahu Kaal Warning', 'Alert 15 min before the window',
        Icons.warning_amber_rounded),
    _Pref('Planetary Events', 'Transits, retrogrades & conjunctions',
        Icons.public),
    _Pref('Dasha Reminders', 'When a planetary period shifts',
        Icons.timeline),
    _Pref('Remedy Reminders', 'Nudges for your prescribed remedies',
        Icons.spa_outlined),
  ];

  // Default-on state, one flag per row.
  final List<bool> _on = <bool>[true, true, false, true, false];

  @override
  Widget build(BuildContext context) {
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
                    value: _on[i],
                    onChanged: (v) => setState(() => _on[i] = v),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          GoldButton(
            label: 'SAVE PREFERENCES',
            icon: Icons.check,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notification preferences saved')),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _Pref {
  const _Pref(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({
    required this.pref,
    required this.value,
    required this.onChanged,
  });

  final _Pref pref;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
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
    );
  }
}
