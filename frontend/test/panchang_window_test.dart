import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_jam/screens/panchang_screen.dart';

/// Rahu Kaal's card reads differently in each of three states, and only one of
/// them is ever on screen at a given moment — so without these the "passed"
/// and "active" wordings could only be checked by waiting for the clock.
void main() {
  final start = DateTime(2026, 9, 9, 12, 18);
  final end = DateTime(2026, 9, 9, 13, 52);

  group('periodStateAt', () {
    test('before the window opens, it is upcoming', () {
      expect(periodStateAt(DateTime(2026, 9, 9, 11, 49), start, end),
          PeriodState.upcoming);
    });

    test('inside the window, it is active', () {
      expect(periodStateAt(DateTime(2026, 9, 9, 13, 0), start, end),
          PeriodState.active);
    });

    test('after the window closes, it has passed', () {
      expect(periodStateAt(DateTime(2026, 9, 9, 14, 30), start, end),
          PeriodState.passed);
    });

    // The boundaries decide which of two very different messages shows, so
    // they are pinned rather than left to whichever way the comparison fell.
    test('the instant it opens counts as active, not upcoming', () {
      expect(periodStateAt(start, start, end), PeriodState.active);
    });

    test('the instant it closes counts as passed, not active', () {
      expect(periodStateAt(end, start, end), PeriodState.passed);
    });
  });

  group('formatClockWindow', () {
    test('renders a 12-hour window with both meridiems', () {
      expect(formatClockWindow(start, end), '12:18 PM – 1:52 PM');
    });

    // The reason the meridiem is repeated: shared, this would read
    // "10:42 – 12:15 PM", which looks like a window starting at 10:42 PM.
    test('a window straddling noon is unambiguous', () {
      expect(
        formatClockWindow(
            DateTime(2026, 9, 9, 10, 42), DateTime(2026, 9, 9, 12, 15)),
        '10:42 AM – 12:15 PM',
      );
    });

    test('midnight and noon render as 12, not 0', () {
      expect(
        formatClockWindow(
            DateTime(2026, 9, 9, 0, 5), DateTime(2026, 9, 9, 12, 0)),
        '12:05 AM – 12:00 PM',
      );
    });
  });
}
