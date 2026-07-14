import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';

/// Onboarding step 2 of 4 — birth time. Pushed screen (DetailScaffold).
class BirthTimeScreen extends StatefulWidget {
  const BirthTimeScreen({super.key});

  @override
  State<BirthTimeScreen> createState() => _BirthTimeScreenState();
}

class _BirthTimeScreenState extends State<BirthTimeScreen> {
  int _hour = 4; // 1..12
  int _minute = 42; // 0..59
  bool _isAm = true;
  bool _unknown = false;

  String _pad(int v) => v.toString().padLeft(2, '0');

  void _bump(int hourDelta, int minuteDelta) {
    if (_unknown) return;
    setState(() {
      if (hourDelta != 0) {
        _hour += hourDelta;
        if (_hour > 12) _hour = 1;
        if (_hour < 1) _hour = 12;
      }
      if (minuteDelta != 0) {
        _minute = (_minute + minuteDelta + 60) % 60;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Birth Time',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 2 of 4 progress.
          const SectionLabel('STEP 2 OF 4'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (int i = 0; i < 4; i++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < 2
                          ? AppColors.gold
                          : AppColors.borderSoft.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                if (i < 3) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.section),

          Text('When were you born?',
              style: AppText.serif(size: 28, weight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your exact birth time sharpens the reading — even a few minutes '
            'shifts the ascendant.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Large time display in a GlassCard with up/down controls.
          Opacity(
            opacity: _unknown ? 0.4 : 1,
            child: GlassCard(
              goldTopBorder: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _TimeUnit(
                    value: _pad(_hour),
                    onUp: () => _bump(1, 0),
                    onDown: () => _bump(-1, 0),
                  ),
                  _colon(),
                  _TimeUnit(
                    value: _pad(_minute),
                    onUp: () => _bump(0, 1),
                    onDown: () => _bump(0, -1),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _TimeUnit(
                    value: _isAm ? 'AM' : 'PM',
                    onUp: _unknown ? null : () => setState(() => _isAm = !_isAm),
                    onDown:
                        _unknown ? null : () => setState(() => _isAm = !_isAm),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // "I don't know my birth time" toggle.
          GlassCard(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text("I don't know my birth time",
                      style: AppText.cardTitle),
                ),
                Switch(
                  value: _unknown,
                  onChanged: (v) => setState(() => _unknown = v),
                  activeThumbColor: AppColors.textOnGold,
                  activeTrackColor: AppColors.gold,
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.surfaceRaised,
                ),
              ],
            ),
          ),
          if (_unknown) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.nightlight_round,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    "We'll use a Moon-sign based reading.",
                    style: AppText.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.section),

          GoldButton(
            label: 'CONTINUE',
            icon: Icons.arrow_forward,
            onPressed: () => goToBirthPlace(context),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _colon() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Text(':',
            style: AppText.serif(
                size: 40, weight: FontWeight.w700, color: AppColors.amber)),
      );
}

/// A stacked up-arrow / big serif value / down-arrow control.
class _TimeUnit extends StatelessWidget {
  const _TimeUnit({required this.value, this.onUp, this.onDown});

  final String value;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chevron(Icons.keyboard_arrow_up, onUp),
        const SizedBox(height: AppSpacing.xs),
        Text(value,
            style: AppText.serif(size: 40, weight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        _chevron(Icons.keyboard_arrow_down, onDown),
      ],
    );
  }

  Widget _chevron(IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Icon(icon,
              size: 22,
              color: onTap == null ? AppColors.textMuted : AppColors.gold),
        ),
      );
}
