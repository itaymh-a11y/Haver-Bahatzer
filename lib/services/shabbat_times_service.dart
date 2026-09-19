import 'package:kosher_dart/kosher_dart.dart';
import '../core/utils/shift_pay_calculator.dart';

/// Rest windows (Shabbat and Yom Tov) for Israel, using Haifa.
class ShabbatTimesService {
  static const locationName = 'Haifa';
  static const latitude = 32.7940;
  static const longitude = 34.9896;
  static const candleLightingOffsetMinutes = 20.0;

  final HebrewDateFormatter _holidayFormatter = HebrewDateFormatter()
    ..hebrewFormat = true;

  List<ShabbatWindow> windowsOverlapping(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return const [];

    final scanStart = DateTime(start.year, start.month, start.day)
        .subtract(const Duration(days: 4));
    final scanEnd =
        DateTime(end.year, end.month, end.day).add(const Duration(days: 3));

    return _scanRestWindows(scanStart, scanEnd)
        .where((window) => window.overlaps(start, end))
        .toList();
  }

  /// Sunday–next Monday around [day], so a Sun–Mon holiday after Shabbat still shows.
  List<ShabbatWindow> windowsForWeek(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    final weekStart = date.subtract(Duration(days: date.weekday % 7));
    final weekEnd = weekStart.add(const Duration(days: 9));
    return windowsOverlapping(weekStart, weekEnd);
  }

  ShabbatWindow? windowForFriday(DateTime friday) {
    final fridayDate = DateTime(friday.year, friday.month, friday.day, 12);
    if (fridayDate.weekday != DateTime.friday) return null;
    final windows = windowsOverlapping(
      fridayDate,
      fridayDate.add(const Duration(days: 2)),
    );
    if (windows.isEmpty) return null;
    for (final window in windows) {
      if (window.start.year == fridayDate.year &&
          window.start.month == fridayDate.month &&
          window.start.day == fridayDate.day) {
        return window;
      }
    }
    return windows.first;
  }

  List<ShabbatWindow> _scanRestWindows(DateTime from, DateTime to) {
    final windows = <ShabbatWindow>[];
    DateTime? openStart;
    DateTime? lastRestDay;

    void closeIfOpen() {
      final start = openStart;
      final restDay = lastRestDay;
      if (start == null || restDay == null) {
        openStart = null;
        lastRestDay = null;
        return;
      }
      final end = _tzeitOn(restDay);
      if (end != null && end.isAfter(start)) {
        windows.add(
          ShabbatWindow(
            start: start,
            end: end,
            title: _titleFor(start, end),
          ),
        );
      }
      openStart = null;
      lastRestDay = null;
    }

    var day = DateTime(from.year, from.month, from.day);
    final last = DateTime(to.year, to.month, to.day);
    while (!day.isAfter(last)) {
      final jewish = _jewishOn(day);
      final isRest = jewish.isAssurBemelacha();

      if (!isRest) {
        closeIfOpen();
        if (jewish.hasCandleLighting()) {
          openStart = _candleLightingOn(day);
        }
      } else {
        lastRestDay = day;
        if (openStart == null) {
          final previous = day.subtract(const Duration(days: 1));
          openStart = _candleLightingOn(previous) ??
              DateTime(day.year, day.month, day.day);
        }
      }
      day = day.add(const Duration(days: 1));
    }
    closeIfOpen();
    return windows;
  }

  String _titleFor(DateTime start, DateTime end) {
    final names = <String>{};
    var hasShabbat = false;
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(last)) {
      if (cursor.weekday == DateTime.saturday) hasShabbat = true;
      final jewish = _jewishOn(cursor);
      if (jewish.isYomTovAssurBemelacha()) {
        final name = _holidayFormatter.formatYomTov(jewish);
        if (name.isNotEmpty) names.add(name);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    if (names.isEmpty) return 'שבת';
    final holidays = names.join(' / ');
    if (hasShabbat) return '$holidays / שבת';
    return holidays;
  }

  JewishCalendar _jewishOn(DateTime day) {
    final noon = DateTime(day.year, day.month, day.day, 12);
    final calendar = JewishCalendar.fromDateTime(noon);
    calendar.inIsrael = true;
    return calendar;
  }

  DateTime? _candleLightingOn(DateTime day) {
    try {
      final calendar = _calendarFor(day);
      return calendar.getCandleLighting() ??
          _sunsetMinusMinutes(calendar, candleLightingOffsetMinutes);
    } catch (_) {
      return null;
    }
  }

  DateTime? _tzeitOn(DateTime day) {
    try {
      return _calendarFor(day).getTzaisGeonim8Point5Degrees();
    } catch (_) {
      return null;
    }
  }

  ComplexZmanimCalendar _calendarFor(DateTime day) {
    final localNoon = DateTime(day.year, day.month, day.day, 12);
    final geo = GeoLocation.setLocation(
      locationName,
      latitude,
      longitude,
      localNoon,
    );
    final calendar = ComplexZmanimCalendar.intGeoLocation(geo);
    calendar.setCandleLightingOffset(candleLightingOffsetMinutes);
    calendar.setCalendar(localNoon);
    return calendar;
  }

  DateTime? _sunsetMinusMinutes(ComplexZmanimCalendar calendar, double minutes) {
    final sunset = calendar.getSeaLevelSunset();
    if (sunset == null) return null;
    return sunset.subtract(Duration(minutes: minutes.round()));
  }
}
