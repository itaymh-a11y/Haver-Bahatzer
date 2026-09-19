import 'package:flutter_test/flutter_test.dart';
import 'package:haver_bahatzer/core/utils/shift_pay_calculator.dart';
import 'package:haver_bahatzer/services/shabbat_times_service.dart';

void main() {
  const wage = 50.0;

  group('ShiftPayCalculator', () {
    test('weekday shift is fully regular', () {
      final pay = ShiftPayCalculator.calculate(
        start: DateTime(2026, 9, 15, 8),
        end: DateTime(2026, 9, 15, 12),
        hourlyWage: wage,
      );
      expect(pay.regularMinutes, 240);
      expect(pay.premiumMinutes, 0);
      expect(pay.regularPay, 200);
      expect(pay.totalPay, 200);
    });

    test('zero-length shift pays nothing', () {
      final start = DateTime(2026, 9, 15, 8);
      final pay = ShiftPayCalculator.calculate(
        start: start,
        end: start,
        hourlyWage: wage,
      );
      expect(pay.totalMinutes, 0);
      expect(pay.totalPay, 0);
    });

    test('shift crossing candle lighting splits regular and 1.5x', () {
      final window = ShabbatWindow(
        start: DateTime(2026, 9, 18, 16, 12),
        end: DateTime(2026, 9, 19, 19, 30),
      );
      final pay = ShiftPayCalculator.calculate(
        start: DateTime(2026, 9, 18, 14),
        end: DateTime(2026, 9, 18, 18),
        hourlyWage: wage,
        windows: [window],
      );
      expect(pay.regularMinutes, 132); // 14:00–16:12
      expect(pay.premiumMinutes, 108); // 16:12–18:00
      expect(pay.regularPay, 110);
      expect(pay.premiumPay, 135);
      expect(pay.totalPay, 245);
    });

    test('motzaei shabbat after havdalah is regular', () {
      final window = ShabbatWindow(
        start: DateTime(2026, 9, 18, 16, 12),
        end: DateTime(2026, 9, 19, 19, 30),
      );
      final pay = ShiftPayCalculator.calculate(
        start: DateTime(2026, 9, 19, 18),
        end: DateTime(2026, 9, 19, 21),
        hourlyWage: wage,
        windows: [window],
      );
      expect(pay.premiumMinutes, 90); // 18:00–19:30
      expect(pay.regularMinutes, 90); // 19:30–21:00
    });

    test('overnight Friday to Saturday is fully premium', () {
      final window = ShabbatWindow(
        start: DateTime(2026, 9, 18, 16, 12),
        end: DateTime(2026, 9, 19, 19, 30),
      );
      final pay = ShiftPayCalculator.calculate(
        start: DateTime(2026, 9, 18, 23),
        end: DateTime(2026, 9, 19, 1),
        hourlyWage: wage,
        windows: [window],
      );
      expect(pay.regularMinutes, 0);
      expect(pay.premiumMinutes, 120);
      expect(pay.totalPay, 150);
    });

    test('splitByCalendarDay groups two shifts style overnight hours', () {
      final slices = ShiftPayCalculator.splitByCalendarDay(
        start: DateTime(2026, 9, 15, 23),
        end: DateTime(2026, 9, 16, 2),
        hourlyWage: wage,
      );
      expect(slices, hasLength(2));
      expect(slices[0].day, DateTime(2026, 9, 15));
      expect(slices[0].pay.regularMinutes, 60);
      expect(slices[1].day, DateTime(2026, 9, 16));
      expect(slices[1].pay.regularMinutes, 120);
    });

    test('splitByCalendarMonth splits midnight on the 1st', () {
      final months = ShiftPayCalculator.splitByCalendarMonth(
        start: DateTime(2026, 10, 31, 23),
        end: DateTime(2026, 11, 1, 1),
        hourlyWage: wage,
      );
      expect(months[DateTime(2026, 10)]!.regularMinutes, 60);
      expect(months[DateTime(2026, 11)]!.regularMinutes, 60);
      expect(months[DateTime(2026, 10)]!.totalPay, 50);
      expect(months[DateTime(2026, 11)]!.totalPay, 50);
    });
  });

  group('ShabbatTimesService', () {
    test('computes Friday candle lighting to Saturday nightfall', () {
      final service = ShabbatTimesService();
      final window = service.windowForFriday(DateTime(2026, 9, 18, 12));
      expect(window, isNotNull);
      expect(window!.start.weekday, DateTime.friday);
      expect(window.end.weekday, DateTime.saturday);
      expect(window.start.hour, greaterThanOrEqualTo(15));
      expect(window.end.hour, greaterThanOrEqualTo(18));
      expect(window.end.isAfter(window.start), isTrue);
    });

    test('Friday to Saturday window is returned for a weekend range', () {
      final service = ShabbatTimesService();
      final windows = service.windowsOverlapping(
        DateTime(2026, 9, 18, 12),
        DateTime(2026, 9, 19, 22),
      );
      expect(windows, isNotEmpty);
      expect(
        windows.first.overlaps(
          DateTime(2026, 9, 18, 12),
          DateTime(2026, 9, 19, 22),
        ),
        isTrue,
      );
    });

    test('Yom Kippur 2026 Monday daytime is premium like Shabbat', () {
      final service = ShabbatTimesService();
      final windows = service.windowsOverlapping(
        DateTime(2026, 9, 21, 8),
        DateTime(2026, 9, 21, 16),
      );
      expect(windows, isNotEmpty);
      expect(windows.any((w) => w.title.contains('כיפור')), isTrue);

      final pay = ShiftPayCalculator.calculate(
        start: DateTime(2026, 9, 21, 8),
        end: DateTime(2026, 9, 21, 16),
        hourlyWage: wage,
        windows: windows,
      );
      expect(pay.regularMinutes, 0);
      expect(pay.premiumMinutes, 480);
    });

    test('Erev Yom Kippur morning before candles is regular', () {
      final service = ShabbatTimesService();
      final windows = service.windowsOverlapping(
        DateTime(2026, 9, 20, 8),
        DateTime(2026, 9, 20, 12),
      );
      final pay = ShiftPayCalculator.calculate(
        start: DateTime(2026, 9, 20, 8),
        end: DateTime(2026, 9, 20, 12),
        hourlyWage: wage,
        windows: windows,
      );
      expect(pay.premiumMinutes, 0);
      expect(pay.regularMinutes, 240);
    });

    test('week view includes Shabbat and Yom Kippur in late Sep 2026', () {
      final service = ShabbatTimesService();
      final windows = service.windowsForWeek(DateTime(2026, 9, 19));
      expect(windows.length, greaterThanOrEqualTo(2));
      expect(windows.any((w) => w.title == 'שבת'), isTrue);
      expect(windows.any((w) => w.title.contains('כיפור')), isTrue);
    });
  });
}
