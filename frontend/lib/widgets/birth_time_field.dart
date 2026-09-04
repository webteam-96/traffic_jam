import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// Opens the platform clock-dial time picker, themed to match the app.
/// Replaces the old custom up/down-arrow wheel spinner that was duplicated
/// nearly identically across onboarding's Birth Time step, Edit Birth Data,
/// and Get Kundli — this is the same picker Book Appointment already used
/// for its own time field, now the one time-selection pattern everywhere.
Future<TimeOfDay?> pickBirthTime(BuildContext context, {TimeOfDay? initial}) {
  return showTimePicker(
    context: context,
    initialTime: initial ?? const TimeOfDay(hour: 6, minute: 0),
    initialEntryMode: TimePickerEntryMode.dial,
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          onPrimary: AppColors.textOnGold,
          surface: AppColors.navBarBase,
          onSurface: AppColors.textPrimary,
        ),
      ),
      child: child!,
    ),
  );
}

/// The tappable field itself — a GlassCard row (clock icon, formatted time
/// or a placeholder, chevron) that opens [pickBirthTime] on tap.
class BirthTimeField extends StatelessWidget {
  const BirthTimeField({
    super.key,
    required this.time,
    required this.onChanged,
    this.enabled = true,
  });

  final TimeOfDay? time;
  final ValueChanged<TimeOfDay> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      goldTopBorder: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      onTap: enabled
          ? () async {
              final picked = await pickBirthTime(context, initial: time);
              if (picked != null) onChanged(picked);
            }
          : null,
      child: Row(
        children: [
          const Icon(Icons.access_time, color: AppColors.gold),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              time == null ? 'Select time of birth' : time!.format(context),
              style: AppText.serif(size: 18, weight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
