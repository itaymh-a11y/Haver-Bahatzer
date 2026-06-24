import 'package:flutter/foundation.dart';
import '../models/vacation_model.dart';
import '../services/vacation_service.dart';

class VacationProvider extends ChangeNotifier {
  final VacationService _vacationService;

  List<VacationPeriod> _vacations = [];
  bool _isListening = false;
  String? _errorMessage;

  VacationProvider(this._vacationService);

  List<VacationPeriod> get vacations => _vacations;
  String? get errorMessage => _errorMessage;

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    _vacationService.watchVacations().listen(
      (vacations) {
        _vacations = vacations;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  bool isDayBlocked(DateTime day) {
    for (final vacation in _vacations) {
      if (vacation.containsDay(day)) return true;
    }
    return false;
  }

  bool boardingRangeBlocked(DateTime start, DateTime end) {
    final rangeStart = VacationPeriod.dateOnly(start);
    final rangeEnd = VacationPeriod.dateOnly(end);
    for (var day = rangeStart;
        !day.isAfter(rangeEnd);
        day = day.add(const Duration(days: 1))) {
      if (isDayBlocked(day)) return true;
    }
    return false;
  }

  VacationPeriod? vacationForDay(DateTime day) {
    for (final vacation in _vacations) {
      if (vacation.containsDay(day)) return vacation;
    }
    return null;
  }

  Future<void> addVacation(VacationPeriod vacation) async {
    _errorMessage = null;
    try {
      await _vacationService.addVacation(vacation);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateVacation(VacationPeriod vacation) async {
    _errorMessage = null;
    try {
      await _vacationService.updateVacation(vacation);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteVacation(String id) async {
    _errorMessage = null;
    try {
      await _vacationService.deleteVacation(id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
