class ShabbatWindow {
  final DateTime start;
  final DateTime end;
  final String title;

  const ShabbatWindow({
    required this.start,
    required this.end,
    this.title = 'שבת',
  });

  bool containsMinute(DateTime minute) {
    return !minute.isBefore(start) && minute.isBefore(end);
  }

  bool overlaps(DateTime rangeStart, DateTime rangeEnd) {
    return rangeStart.isBefore(end) && rangeEnd.isAfter(start);
  }
}

class ShiftPayBreakdown {
  final int regularMinutes;
  final int premiumMinutes;
  final double regularPay;
  final double premiumPay;
  final double totalPay;
  final DateTime? shabbatStartAt;
  final DateTime? shabbatEndAt;

  const ShiftPayBreakdown({
    required this.regularMinutes,
    required this.premiumMinutes,
    required this.regularPay,
    required this.premiumPay,
    required this.totalPay,
    this.shabbatStartAt,
    this.shabbatEndAt,
  });

  static const empty = ShiftPayBreakdown(
    regularMinutes: 0,
    premiumMinutes: 0,
    regularPay: 0,
    premiumPay: 0,
    totalPay: 0,
  );

  int get totalMinutes => regularMinutes + premiumMinutes;

  double get totalHours => totalMinutes / 60.0;

  double get regularHours => regularMinutes / 60.0;

  double get premiumHours => premiumMinutes / 60.0;

  ShiftPayBreakdown operator +(ShiftPayBreakdown other) {
    return ShiftPayBreakdown(
      regularMinutes: regularMinutes + other.regularMinutes,
      premiumMinutes: premiumMinutes + other.premiumMinutes,
      regularPay: regularPay + other.regularPay,
      premiumPay: premiumPay + other.premiumPay,
      totalPay: totalPay + other.totalPay,
      shabbatStartAt: _minDate(shabbatStartAt, other.shabbatStartAt),
      shabbatEndAt: _maxDate(shabbatEndAt, other.shabbatEndAt),
    );
  }
}

class ShiftDaySlice {
  final DateTime day;
  final ShiftPayBreakdown pay;

  const ShiftDaySlice({required this.day, required this.pay});
}

class ShiftPayCalculator {
  ShiftPayCalculator._();

  static const premiumMultiplier = 1.5;

  static DateTime truncateToMinute(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
  }

  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static DateTime monthOnly(DateTime dt) => DateTime(dt.year, dt.month);

  static ShiftPayBreakdown calculate({
    required DateTime start,
    required DateTime end,
    required double hourlyWage,
    List<ShabbatWindow> windows = const [],
  }) {
    if (!end.isAfter(start) || hourlyWage < 0) return ShiftPayBreakdown.empty;

    var regularMinutes = 0;
    var premiumMinutes = 0;
    var cursor = truncateToMinute(start);
    final endMinute = truncateToMinute(end);

    while (cursor.isBefore(endMinute)) {
      final isPremium = windows.any((w) => w.containsMinute(cursor));
      if (isPremium) {
        premiumMinutes++;
      } else {
        regularMinutes++;
      }
      cursor = cursor.add(const Duration(minutes: 1));
    }

    return _fromMinutes(
      regularMinutes: regularMinutes,
      premiumMinutes: premiumMinutes,
      hourlyWage: hourlyWage,
      windows: windows.where((w) => w.overlaps(start, end)).toList(),
    );
  }

  static List<ShiftDaySlice> splitByCalendarDay({
    required DateTime start,
    required DateTime end,
    required double hourlyWage,
    List<ShabbatWindow> windows = const [],
  }) {
    return _bucket(
      start: start,
      end: end,
      hourlyWage: hourlyWage,
      windows: windows,
      keyOf: dateOnly,
    )
        .entries
        .map((e) => ShiftDaySlice(day: e.key, pay: e.value))
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  static Map<DateTime, ShiftPayBreakdown> splitByCalendarMonth({
    required DateTime start,
    required DateTime end,
    required double hourlyWage,
    List<ShabbatWindow> windows = const [],
  }) {
    return _bucket(
      start: start,
      end: end,
      hourlyWage: hourlyWage,
      windows: windows,
      keyOf: monthOnly,
    );
  }

  static Map<DateTime, ShiftPayBreakdown> _bucket({
    required DateTime start,
    required DateTime end,
    required double hourlyWage,
    required List<ShabbatWindow> windows,
    required DateTime Function(DateTime) keyOf,
  }) {
    final result = <DateTime, ShiftPayBreakdown>{};
    if (!end.isAfter(start) || hourlyWage < 0) return result;

    final counts = <DateTime, ({int regular, int premium})>{};
    var cursor = truncateToMinute(start);
    final endMinute = truncateToMinute(end);

    while (cursor.isBefore(endMinute)) {
      final key = keyOf(cursor);
      final current = counts[key] ?? (regular: 0, premium: 0);
      final isPremium = windows.any((w) => w.containsMinute(cursor));
      counts[key] = isPremium
          ? (regular: current.regular, premium: current.premium + 1)
          : (regular: current.regular + 1, premium: current.premium);
      cursor = cursor.add(const Duration(minutes: 1));
    }

    final overlapping = windows.where((w) => w.overlaps(start, end)).toList();
    for (final entry in counts.entries) {
      result[entry.key] = _fromMinutes(
        regularMinutes: entry.value.regular,
        premiumMinutes: entry.value.premium,
        hourlyWage: hourlyWage,
        windows: overlapping,
      );
    }
    return result;
  }

  static ShiftPayBreakdown _fromMinutes({
    required int regularMinutes,
    required int premiumMinutes,
    required double hourlyWage,
    required List<ShabbatWindow> windows,
  }) {
    final regularPay = _roundMoney((regularMinutes / 60.0) * hourlyWage);
    final premiumPay = _roundMoney(
      (premiumMinutes / 60.0) * hourlyWage * premiumMultiplier,
    );
    return ShiftPayBreakdown(
      regularMinutes: regularMinutes,
      premiumMinutes: premiumMinutes,
      regularPay: regularPay,
      premiumPay: premiumPay,
      totalPay: _roundMoney(regularPay + premiumPay),
      shabbatStartAt: windows.isEmpty
          ? null
          : windows.map((w) => w.start).reduce((a, b) => a.isBefore(b) ? a : b),
      shabbatEndAt: windows.isEmpty
          ? null
          : windows.map((w) => w.end).reduce((a, b) => a.isAfter(b) ? a : b),
    );
  }

  static double _roundMoney(double value) =>
      (value * 100).roundToDouble() / 100;
}

DateTime? _minDate(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

DateTime? _maxDate(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}
