import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';

/// Edit birth data — labelled GlassCard fields prefilled with the user's
/// current chart details. Pushed screen, so it roots in DetailScaffold.
/// ponytail: fields are tap-to-edit rows over mocked const values; wire real
/// pickers/text entry when the profile flow needs to persist changes.
class EditBirthDataScreen extends StatefulWidget {
  const EditBirthDataScreen({super.key});

  @override
  State<EditBirthDataScreen> createState() => _EditBirthDataScreenState();
}

class _EditBirthDataScreenState extends State<EditBirthDataScreen> {
  // Prefilled birth data (mocked).
  static const _fields = <_Field>[
    _Field('FULL NAME', 'Aarav Sharma', Icons.person_outline),
    _Field('DATE OF BIRTH', '24 October 1988', Icons.calendar_month),
    _Field('TIME OF BIRTH', '04:42 AM', Icons.schedule),
    _Field('PLACE OF BIRTH', 'Mumbai, Maharashtra, India', Icons.place_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Edit Birth Data',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Refine your chart', style: AppText.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Accurate birth details sharpen every reading. Tap a field to edit.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.section),
          for (int i = 0; i < _fields.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            _EditableField(
                field: _fields[i],
                onTap: () => toast(context, 'Tap-to-edit coming soon')),
          ],
          const SizedBox(height: AppSpacing.section),
          GoldButton(
            label: 'SAVE CHANGES',
            icon: Icons.check,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Birth data saved')),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _Field {
  const _Field(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _EditableField extends StatelessWidget {
  const _EditableField({required this.field, required this.onTap});
  final _Field field;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      onTap: onTap,
      child: Row(
        children: [
          IconChip(child: Icon(field.icon, color: AppColors.gold, size: 20)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(field.label),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  field.value,
                  style: AppText.serif(size: 18, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 18),
        ],
      ),
    );
  }
}
