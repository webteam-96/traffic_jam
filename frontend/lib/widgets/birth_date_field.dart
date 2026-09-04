import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';
import 'glass_card.dart';

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Opens a Day / Month / Year wheel picker for a birth date. Unlike
/// Flutter's stock showDatePicker — where month only moves one step at a
/// time via a prev/next arrow, with no independent month selector — each of
/// Day/Month/Year is its own scrollable wheel here, so jumping to e.g.
/// "March 1985" is three flicks, not dozens of taps. Used everywhere a
/// birth date is entered (onboarding, Edit Birth Data, Get Kundli) so date
/// selection behaves identically across the app.
Future<DateTime?> pickBirthDate(BuildContext context, {DateTime? initial}) {
  final now = DateTime.now();
  final start = initial ?? DateTime(now.year - 25, 1, 1);
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.navBarBase,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _BirthDateSheet(initial: start, maxDate: now),
  );
}

/// The tappable field itself — a GlassCard row (calendar icon, formatted
/// date or a placeholder, chevron) that opens [pickBirthDate] on tap. Same
/// look every screen already used inline; now shared so all three birth-date
/// entry points render and behave identically.
class BirthDateField extends StatelessWidget {
  const BirthDateField({super.key, required this.date, required this.onChanged});

  final DateTime? date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      onTap: () async {
        final picked = await pickBirthDate(context, initial: date);
        if (picked != null) onChanged(picked);
      },
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: AppColors.gold),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              date == null
                  ? 'Select date of birth'
                  : '${date!.day} ${_monthAbbrev[date!.month - 1]} ${date!.year}',
              style: AppText.serif(size: 18, weight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}

class _BirthDateSheet extends StatefulWidget {
  const _BirthDateSheet({required this.initial, required this.maxDate});
  final DateTime initial;
  final DateTime maxDate;

  @override
  State<_BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends State<_BirthDateSheet> {
  static const _minYear = 1900;

  late int _day = widget.initial.day;
  late int _month = widget.initial.month;
  late int _year = widget.initial.year.clamp(_minYear, widget.maxDate.year);

  int get _maxYear => widget.maxDate.year;
  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('DATE OF BIRTH', style: AppText.microLabel),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 216,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _wheel(
                      key: ValueKey('day-$_month-$_year'),
                      itemCount: _daysInMonth,
                      initial: _day - 1,
                      labelBuilder: (i) => '${i + 1}',
                      onChanged: (i) => setState(() => _day = i + 1),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _wheel(
                      itemCount: 12,
                      initial: _month - 1,
                      labelBuilder: (i) => _monthNames[i],
                      onChanged: (i) => setState(() {
                        _month = i + 1;
                        if (_day > _daysInMonth) _day = _daysInMonth;
                      }),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _wheel(
                      itemCount: _maxYear - _minYear + 1,
                      initial: _year - _minYear,
                      labelBuilder: (i) => '${_minYear + i}',
                      onChanged: (i) => setState(() {
                        _year = _minYear + i;
                        if (_day > _daysInMonth) _day = _daysInMonth;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
              child: GoldButton(
                label: 'CONFIRM',
                onPressed: () {
                  var picked = DateTime(_year, _month, _day);
                  if (picked.isAfter(widget.maxDate)) picked = widget.maxDate;
                  Navigator.of(context).pop(picked);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // key lets the day wheel rebuild with a fresh initialItem whenever the
  // days-in-month changes (e.g. leaving Feb with day 29 selected) instead of
  // trying to re-scroll an existing controller to a different position.
  Widget _wheel({
    Key? key,
    required int itemCount,
    required int initial,
    required String Function(int) labelBuilder,
    required ValueChanged<int> onChanged,
  }) {
    return CupertinoPicker(
      key: key,
      scrollController: FixedExtentScrollController(initialItem: initial),
      itemExtent: 40,
      backgroundColor: Colors.transparent,
      selectionOverlay: Container(
        decoration: const BoxDecoration(
          border: Border.symmetric(
              horizontal: BorderSide(color: AppColors.goldBorderSoft)),
        ),
      ),
      onSelectedItemChanged: onChanged,
      children: [
        for (int i = 0; i < itemCount; i++)
          Center(
            child: Text(labelBuilder(i),
                style: AppText.serif(size: 18, weight: FontWeight.w600)),
          ),
      ],
    );
  }
}
