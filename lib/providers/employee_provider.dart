import 'package:flutter/foundation.dart';
import '../core/constants/app_strings.dart';
import '../core/utils/shift_pay_calculator.dart';
import '../models/employee_model.dart';
import '../models/shift_model.dart';
import '../services/employee_service.dart';
import '../services/shabbat_times_service.dart';

class EmployeeProvider extends ChangeNotifier {
  final EmployeeService _employeeService;
  final ShabbatTimesService _shabbatTimesService;

  List<Employee> _employees = [];
  List<Shift> _shifts = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _employeesListening = false;
  bool _shiftsListening = false;

  EmployeeProvider(
    this._employeeService, {
    ShabbatTimesService? shabbatTimesService,
  }) : _shabbatTimesService = shabbatTimesService ?? ShabbatTimesService();

  List<Employee> get employees => _employees;
  List<Employee> get activeEmployees =>
      _employees.where((e) => e.isActive).toList();
  List<Shift> get shifts => _shifts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void startListening() {
    if (!_employeesListening) {
      _employeesListening = true;
      _employeeService.watchEmployees().listen(
        (employees) {
          _employees = employees;
          notifyListeners();
        },
        onError: (e) {
          _errorMessage = e.toString();
          notifyListeners();
        },
      );
    }
    if (!_shiftsListening) {
      _shiftsListening = true;
      _employeeService.watchShifts().listen(
        (shifts) {
          _shifts = shifts;
          notifyListeners();
        },
        onError: (e) {
          _errorMessage = e.toString();
          notifyListeners();
        },
      );
    }
  }

  Employee? findEmployeeById(String id) {
    final idx = _employees.indexWhere((e) => e.id == id);
    return idx != -1 ? _employees[idx] : null;
  }

  Shift? openShiftFor(String employeeId) {
    final idx = _shifts.indexWhere(
      (s) => s.employeeId == employeeId && s.isOpen,
    );
    return idx != -1 ? _shifts[idx] : null;
  }

  List<Shift> shiftsOverlappingDay(DateTime day, {String? employeeId}) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _shifts.where((shift) {
      if (employeeId != null && shift.employeeId != employeeId) return false;
      final shiftEnd = shift.endAt ?? DateTime.now();
      return shift.startAt.isBefore(end) && shiftEnd.isAfter(start);
    }).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  List<Shift> shiftsOverlappingMonth(DateTime month, {String? employeeId}) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return _shifts.where((shift) {
      if (employeeId != null && shift.employeeId != employeeId) return false;
      final shiftEnd = shift.endAt ?? DateTime.now();
      return shift.startAt.isBefore(end) && shiftEnd.isAfter(start);
    }).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  ShiftPayBreakdown payForShift(Shift shift, {DateTime? now}) {
    final end = shift.endAt ?? now ?? DateTime.now();
    return ShiftPayCalculator.calculate(
      start: shift.startAt,
      end: end,
      hourlyWage: shift.hourlyWage,
      windows: _windowsFor(shift, end),
    );
  }

  ShiftPayBreakdown previewPay({
    required DateTime start,
    required DateTime end,
    required double hourlyWage,
  }) {
    return ShiftPayCalculator.calculate(
      start: start,
      end: end,
      hourlyWage: hourlyWage,
      windows: _shabbatTimesService.windowsOverlapping(start, end),
    );
  }

  List<ShabbatWindow> restWindowsThisWeek([DateTime? now]) {
    return _shabbatTimesService.windowsForWeek(now ?? DateTime.now());
  }

  ShiftPayBreakdown payForMonth(
    DateTime month, {
    String? employeeId,
    DateTime? now,
  }) {
    final monthKey = DateTime(month.year, month.month);
    var total = ShiftPayBreakdown.empty;
    for (final shift in shiftsOverlappingMonth(month, employeeId: employeeId)) {
      final end = shift.endAt ?? now ?? DateTime.now();
      final byMonth = ShiftPayCalculator.splitByCalendarMonth(
        start: shift.startAt,
        end: end,
        hourlyWage: shift.hourlyWage,
        windows: _windowsFor(shift, end),
      );
      total += byMonth[monthKey] ?? ShiftPayBreakdown.empty;
    }
    return total;
  }

  List<ShiftDaySlice> daySlicesForMonth(
    DateTime month, {
    String? employeeId,
    DateTime? now,
  }) {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final byDay = <DateTime, ShiftPayBreakdown>{};

    for (final shift in shiftsOverlappingMonth(month, employeeId: employeeId)) {
      final end = shift.endAt ?? now ?? DateTime.now();
      final slices = ShiftPayCalculator.splitByCalendarDay(
        start: shift.startAt,
        end: end,
        hourlyWage: shift.hourlyWage,
        windows: _windowsFor(shift, end),
      );
      for (final slice in slices) {
        if (slice.day.isBefore(monthStart) || !slice.day.isBefore(monthEnd)) {
          continue;
        }
        byDay[slice.day] = (byDay[slice.day] ?? ShiftPayBreakdown.empty) +
            slice.pay;
      }
    }

    return byDay.entries
        .map((e) => ShiftDaySlice(day: e.key, pay: e.value))
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  ShiftPayBreakdown payForDay(
    DateTime day, {
    String? employeeId,
    DateTime? now,
  }) {
    final dayKey = DateTime(day.year, day.month, day.day);
    var total = ShiftPayBreakdown.empty;
    for (final shift in shiftsOverlappingDay(day, employeeId: employeeId)) {
      total += payForShiftOnDay(shift, dayKey, now: now);
    }
    return total;
  }

  ShiftPayBreakdown payForShiftOnDay(
    Shift shift,
    DateTime day, {
    DateTime? now,
  }) {
    final dayKey = DateTime(day.year, day.month, day.day);
    final end = shift.endAt ?? now ?? DateTime.now();
    final slices = ShiftPayCalculator.splitByCalendarDay(
      start: shift.startAt,
      end: end,
      hourlyWage: shift.hourlyWage,
      windows: _windowsFor(shift, end),
    );
    for (final slice in slices) {
      if (slice.day == dayKey) return slice.pay;
    }
    return ShiftPayBreakdown.empty;
  }

  Future<void> addEmployee(Employee employee) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _employeeService.addEmployee(employee);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateEmployee(Employee employee) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _employeeService.updateEmployee(employee);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes the employee when they have no shifts; otherwise marks inactive.
  Future<bool> removeOrDeactivateEmployee(Employee employee) async {
    _errorMessage = null;
    try {
      final hasShifts =
          await _employeeService.employeeHasShifts(employee.id);
      if (hasShifts) {
        await _employeeService.updateEmployee(
          employee.copyWith(isActive: false, updatedAt: DateTime.now()),
        );
        return false;
      }
      await _employeeService.deleteEmployee(employee.id);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> startShift(Employee employee) async {
    _errorMessage = null;
    if (openShiftFor(employee.id) != null) {
      _errorMessage = AppStrings.shiftAlreadyOpen;
      notifyListeners();
      return false;
    }
    final now = DateTime.now();
    try {
      await _employeeService.addShift(
        Shift(
          id: '',
          employeeId: employee.id,
          employeeName: employee.name,
          hourlyWage: employee.hourlyWage,
          startAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> endShift(Shift shift, {DateTime? endedAt}) async {
    _errorMessage = null;
    if (shift.endAt != null) return true;
    final end = endedAt ?? DateTime.now();
    if (!end.isAfter(shift.startAt)) {
      _errorMessage = AppStrings.shiftEndBeforeStart;
      notifyListeners();
      return false;
    }
    try {
      await _employeeService.updateShift(
        _closedShift(shift, end),
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveShift({
    required Employee employee,
    required DateTime startAt,
    required DateTime endAt,
    Shift? existing,
  }) async {
    _errorMessage = null;
    if (!endAt.isAfter(startAt)) {
      _errorMessage = AppStrings.shiftEndBeforeStart;
      notifyListeners();
      return false;
    }
    final open = openShiftFor(employee.id);
    if (open != null && open.id != existing?.id) {
      _errorMessage = AppStrings.shiftAlreadyOpen;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      if (existing == null) {
        final shift = Shift(
          id: '',
          employeeId: employee.id,
          employeeName: employee.name,
          hourlyWage: employee.hourlyWage,
          startAt: startAt,
          createdAt: now,
          updatedAt: now,
        );
        await _employeeService.addShift(_closedShift(shift, endAt));
      } else {
        await _employeeService.updateShift(
          _closedShift(
            existing.copyWith(
              startAt: startAt,
              employeeName: employee.name,
              updatedAt: now,
            ),
            endAt,
          ),
        );
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteShift(String id) async {
    _errorMessage = null;
    try {
      await _employeeService.deleteShift(id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  List<ShabbatWindow> _windowsFor(Shift shift, DateTime end) {
    if (shift.storedWindows.isNotEmpty) return shift.storedWindows;
    return _shabbatTimesService.windowsOverlapping(shift.startAt, end);
  }

  Shift _closedShift(Shift shift, DateTime end) {
    final windows =
        _shabbatTimesService.windowsOverlapping(shift.startAt, end);
    final pay = ShiftPayCalculator.calculate(
      start: shift.startAt,
      end: end,
      hourlyWage: shift.hourlyWage,
      windows: windows,
    );
    return shift.copyWith(endAt: end, updatedAt: DateTime.now()).withBreakdown(pay);
  }
}
