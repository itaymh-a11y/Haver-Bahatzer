import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/constants/app_strings.dart';
import '../core/utils/image_utils.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/storage_service.dart';

class BookingPaymentEntry {
  final Booking booking;
  final PaymentRecord payment;

  BookingPaymentEntry({
    required this.booking,
    required this.payment,
  });
}

class BookingProvider extends ChangeNotifier {
  final BookingService _bookingService;
  final StorageService _storageService;

  List<Booking> _bookings = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isListening = false;

  BookingProvider(this._bookingService, this._storageService);

  List<Booking> get bookings => _bookings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Booking> get upcomingBookings =>
      _bookings.where((b) => b.status == BookingStatus.upcoming).toList();

  List<Booking> get activeBookings =>
      _bookings.where((b) => b.status == BookingStatus.active).toList();

  List<Booking> get completedBookings =>
      _bookings.where((b) => b.status == BookingStatus.completed).toList();

  // Dashboard computed getters
  List<Booking> get todayCheckIns {
    final today = _todayDate;
    return _bookings
        .where((b) =>
            b.type == BookingType.boarding &&
            _sameDay(b.startDate, today))
        .toList();
  }

  List<Booking> get todayCheckOuts {
    final today = _todayDate;
    return _bookings
        .where((b) =>
            b.type == BookingType.boarding &&
            _sameDay(b.endDate, today))
        .toList();
  }

  List<Booking> get todayIntros {
    final today = _todayDate;
    final intros = _bookings
        .where((b) =>
            b.type == BookingType.introMeeting &&
            _sameDay(b.startDate, today))
        .toList();
    intros.sort((a, b) => (a.meetingTime ?? '').compareTo(b.meetingTime ?? ''));
    return intros;
  }

  List<Booking> get currentlyOccupiedBookings {
    final today = _todayDate;
    return _bookings
        .where((b) =>
            b.type == BookingType.boarding &&
            b.kennelId != null &&
            !b.startDate.isAfter(today) &&
            !b.endDate.isBefore(today))
        .toList();
  }

  int get occupiedKennelCount => currentlyOccupiedBookings.length;

  List<Booking> getBookingsForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _bookings.where((b) {
      final start = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
      final end = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
  }

  // ── Financial getters ──────────────────────────────────────────────────────

  List<Booking> paidBookingsForMonth(DateTime month) => _bookings
      .where((b) =>
          b.type == BookingType.boarding &&
          b.payments.any((p) => p.paidAt.year == month.year && p.paidAt.month == month.month))
      .toList();

  List<Booking> get unpaidBookings => _bookings
      .where((b) => b.type == BookingType.boarding && b.remainingAmount > 0.01)
      .toList();

  List<BookingPaymentEntry> paymentEntriesForMonth(DateTime month) {
    final result = <BookingPaymentEntry>[];
    for (final booking in _bookings) {
      if (booking.type != BookingType.boarding) continue;
      for (final payment in booking.payments) {
        if (payment.paidAt.year == month.year && payment.paidAt.month == month.month) {
          result.add(BookingPaymentEntry(booking: booking, payment: payment));
        }
      }
    }
    return result;
  }

  double averageStayDaysForMonth(DateTime month) {
    final bookings = _boardingForMonth(month);
    if (bookings.isEmpty) return 0;
    final total = bookings.fold(0, (sum, b) => sum + b.numberOfDays);
    return total / bookings.length;
  }

  int uniqueDogsHostedForMonth(DateTime month) {
    final ids = <String>{};
    for (final b in _boardingForMonth(month)) {
      ids.addAll(b.dogIds);
    }
    return ids.length;
  }

  List<double> bookingDayDistributionForMonth(DateTime month) {
    final bookings = _boardingForMonth(month);
    final counts = List<int>.filled(7, 0);
    for (final b in bookings) {
      final days = b.endDate.difference(b.startDate).inDays + 1;
      for (int i = 0; i < days; i++) {
        final day = b.startDate.add(Duration(days: i));
        counts[day.weekday % 7]++;
      }
    }
    final total = counts.reduce((a, b) => a + b);
    if (total == 0) return List.filled(7, 0.0);
    return counts.map((c) => c / total).toList();
  }

  List<Booking> boardingBookingsForMonth(DateTime month) => _boardingForMonth(month);

  List<Booking> boardingBookingsOverlappingMonth(DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    return _bookings.where((b) {
      if (b.type != BookingType.boarding) return false;
      return !b.endDate.isBefore(monthStart) && !b.startDate.isAfter(monthEnd);
    }).toList();
  }

  List<Booking> _boardingForMonth(DateTime month) => _bookings
      .where((b) =>
          b.type == BookingType.boarding &&
          b.startDate.year == month.year &&
          b.startDate.month == month.month)
      .toList();

  // ── Per-dog getters ────────────────────────────────────────────────────────

  List<Booking> boardingBookingsForDog(String dogId) => _bookings
      .where((b) => b.type == BookingType.boarding && b.dogIds.contains(dogId))
      .toList();

  int totalBoardingDaysForDog(String dogId) =>
      boardingBookingsForDog(dogId).fold(0, (sum, b) => sum + b.numberOfDays);

  double totalPaidAmountForDog(String dogId) {
    double total = 0.0;
    for (final b in boardingBookingsForDog(dogId)) {
      if (b.totalPrice == null) continue;
      if (b.remainingAmount > 0.01) continue;
      total += b.totalPrice!;
    }
    return total;
  }

  double revenueForMonth(DateTime month) {
    double sum = 0.0;
    for (final b in _bookings) {
      if (b.type != BookingType.boarding) continue;
      for (final payment in b.payments) {
        if (payment.paidAt.year == month.year && payment.paidAt.month == month.month) {
          sum += payment.amount;
        }
      }
    }
    return sum;
  }

  Map<String, int> kennelDistributionForDog(String dogId) {
    final counts = <String, int>{};
    for (final b in boardingBookingsForDog(dogId)) {
      if (b.kennelId == null) continue;
      counts[b.kennelId!] = (counts[b.kennelId!] ?? 0) + b.numberOfDays;
    }
    return counts;
  }

  // ── Listening ─────────────────────────────────────────────────────────────

  void startListening() {
    if (_isListening) return;
    _isListening = true;

    _bookingService.watchBookings().listen(
      (bookings) {
        _bookings = bookings;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  // ── Conflict detection ─────────────────────────────────────────────────────

  String? checkDogConflict(
    List<String> dogIds,
    DateTime start,
    DateTime end, {
    String? excludeId,
  }) {
    for (final booking in _bookings) {
      if (booking.id == excludeId) continue;
      if (booking.type == BookingType.introMeeting) continue;

      final hasOverlap = !end.isBefore(booking.startDate) &&
          !booking.endDate.isBefore(start);
      if (!hasOverlap) continue;

      for (final dogId in dogIds) {
        if (booking.dogIds.contains(dogId)) {
          return AppStrings.conflictDog;
        }
      }
    }
    return null;
  }

  String? checkKennelConflict(
    String kennelId,
    DateTime start,
    DateTime end, {
    String? excludeId,
  }) {
    for (final booking in _bookings) {
      if (booking.id == excludeId) continue;
      if (booking.type == BookingType.introMeeting) continue;
      if (booking.kennelId != kennelId) continue;

      final sameDayTurnover = _sameDay(start, booking.endDate);
      if (sameDayTurnover) continue;

      final hasOverlap = !end.isBefore(booking.startDate) &&
          !booking.endDate.isBefore(start);
      if (hasOverlap) return AppStrings.conflictKennel;
    }
    return null;
  }

  bool hasSameDayCheckoutInKennel(
    String kennelId,
    DateTime start, {
    String? excludeId,
  }) {
    for (final booking in _bookings) {
      if (booking.id == excludeId) continue;
      if (booking.type == BookingType.introMeeting) continue;
      if (booking.kennelId != kennelId) continue;
      if (_sameDay(start, booking.endDate)) return true;
    }
    return false;
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> addBooking(Booking booking) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _bookingService.addBooking(booking);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateBooking(Booking booking) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _bookingService.updateBooking(booking);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteBooking(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _bookingService.deleteBooking(id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadContract(Booking booking, File imageFile) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final bytes = await ImageUtils.compressImageToBytes(imageFile) ??
          await imageFile.readAsBytes();
      final url =
          await _storageService.uploadContractPhoto(booking.id, bytes);
      await _bookingService.addContractUrl(booking.id, url);
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> removeContractUrl(Booking booking, String url) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await _bookingService.removeContractUrl(booking.id, url);
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  DateTime get _todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
