import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/constants/app_strings.dart';
import '../core/constants/kennel_constants.dart';
import '../core/utils/image_utils.dart';
import '../models/booking_model.dart';
import '../models/dog_model.dart';
import '../models/vacation_model.dart';
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

class IntactOppositeSexOverlap {
  final String maleDogName;
  final String femaleDogName;
  final DateTime overlapStart;
  final DateTime overlapEnd;

  const IntactOppositeSexOverlap({
    required this.maleDogName,
    required this.femaleDogName,
    required this.overlapStart,
    required this.overlapEnd,
  });
}

class SoftHoldConflict {
  final Booking introBooking;
  final String? alternativeKennelId;

  const SoftHoldConflict({
    required this.introBooking,
    this.alternativeKennelId,
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
  List<Booking> checkInsForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _bookings
        .where((b) =>
            b.type == BookingType.boarding &&
            _sameDay(b.startDate, d))
        .toList();
  }

  List<Booking> checkOutsForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _bookings
        .where((b) =>
            b.type == BookingType.boarding &&
            _sameDay(b.endDate, d))
        .toList();
  }

  List<Booking> get todayCheckIns => checkInsForDay(_todayDate);

  List<Booking> get todayCheckOuts => checkOutsForDay(_todayDate);

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

  /// Intro meetings whose soft hold covers [day] (may not be the meeting day).
  List<Booking> getSoftHoldsForDay(DateTime day) {
    return _bookings
        .where((b) => b.hasSoftHold && b.softHoldCoversDay(day))
        .toList();
  }

  /// Soft holds that overlap a hard boarding kennel assignment.
  List<SoftHoldConflict> findSoftHoldConflicts({
    required List<String> dogIds,
    required DateTime start,
    required DateTime end,
    required String kennelId,
    DateTime? kennelChangeStartDate,
    String? kennelChangeKennelId,
    String? excludeId,
  }) {
    final conflicts = <SoftHoldConflict>[];
    final rangeStart = _dateOnly(start);
    final rangeEnd = _dateOnly(end);

    for (final hold in _bookings) {
      if (!hold.hasSoftHold) continue;
      if (hold.id == excludeId) continue;

      final holdKennel = hold.softHoldKennelId!;
      final holdStart = _dateOnly(hold.softHoldStartDate!);
      final holdEnd = _dateOnly(hold.softHoldEndDate!);

      // Day-by-day: does this boarding occupy the soft-hold kennel on an overlapping day?
      var overlapsKennel = false;
      for (var day = rangeStart;
          !day.isAfter(rangeEnd);
          day = day.add(const Duration(days: 1))) {
        if (day.isBefore(holdStart) || day.isAfter(holdEnd)) continue;
        final dayKennel = _kennelIdForDay(
          kennelId: kennelId,
          kennelChangeStartDate: kennelChangeStartDate,
          kennelChangeKennelId: kennelChangeKennelId,
          day: day,
        );
        if (dayKennel == holdKennel) {
          overlapsKennel = true;
          break;
        }
      }
      if (!overlapsKennel) continue;

      // Displaced if hard occupancy leaves no room for the soft-hold dogs
      // (simulate after this booking is saved).
      final displaced = !_softHoldHasCapacity(
        hold: hold,
        extraBoarding: (
          dogIds: dogIds,
          start: start,
          end: end,
          kennelId: kennelId,
          kennelChangeStartDate: kennelChangeStartDate,
          kennelChangeKennelId: kennelChangeKennelId,
          excludeId: excludeId,
        ),
      );
      if (!displaced) continue;

      final altKennelId = suggestAlternativeKennel(
        dogIds: hold.dogIds,
        start: hold.softHoldStartDate!,
        end: hold.softHoldEndDate!,
        excludeKennelId: holdKennel,
        excludeBookingId: excludeId,
      );

      conflicts.add(SoftHoldConflict(
        introBooking: hold,
        alternativeKennelId: altKennelId,
      ));
    }
    return conflicts;
  }

  bool isSoftHoldDisplaced(Booking hold) {
    if (!hold.hasSoftHold) return false;
    return !_softHoldHasCapacity(hold: hold);
  }

  bool _softHoldHasCapacity({
    required Booking hold,
    ({
      List<String> dogIds,
      DateTime start,
      DateTime end,
      String kennelId,
      DateTime? kennelChangeStartDate,
      String? kennelChangeKennelId,
      String? excludeId,
    })? extraBoarding,
  }) {
    final kennelId = hold.softHoldKennelId!;
    final kennel = KennelConstants.findById(kennelId);
    if (kennel == null) return false;

    final holdStart = _dateOnly(hold.softHoldStartDate!);
    final holdEnd = _dateOnly(hold.softHoldEndDate!);
    final needed = hold.dogIds.length;

    for (var day = holdStart;
        !day.isAfter(holdEnd);
        day = day.add(const Duration(days: 1))) {
      var occupied = 0;
      for (final booking in _bookings) {
        if (booking.type != BookingType.boarding) continue;
        if (booking.kennelId == null) continue;
        if (extraBoarding != null && booking.id == extraBoarding.excludeId) {
          continue;
        }
        if (!_dayInBooking(day, booking)) continue;
        if (booking.kennelIdForDate(day) != kennelId) continue;
        if (kennel.maxDogs == 1 &&
            _sameDay(day, booking.endDate) &&
            extraBoarding != null &&
            _sameDay(day, extraBoarding.start)) {
          continue;
        }
        occupied += booking.dogIds.length;
      }

      if (extraBoarding != null) {
        final dayKennel = _kennelIdForDay(
          kennelId: extraBoarding.kennelId,
          kennelChangeStartDate: extraBoarding.kennelChangeStartDate,
          kennelChangeKennelId: extraBoarding.kennelChangeKennelId,
          day: day,
        );
        final inExtraRange = !day.isBefore(_dateOnly(extraBoarding.start)) &&
            !day.isAfter(_dateOnly(extraBoarding.end));
        if (dayKennel == kennelId && inExtraRange) {
          occupied += extraBoarding.dogIds.length;
        }
      }

      if (occupied + needed > kennel.maxDogs) return false;
    }
    return true;
  }

  String? suggestAlternativeKennel({
    required List<String> dogIds,
    required DateTime start,
    required DateTime end,
    String? excludeKennelId,
    String? excludeBookingId,
  }) {
    for (final kennel in KennelConstants.all) {
      if (kennel.id == excludeKennelId) continue;
      if (dogIds.length > kennel.maxDogs) continue;

      final conflict = checkKennelConflict(
        dogIds: dogIds,
        start: start,
        end: end,
        kennelId: kennel.id,
        excludeId: excludeBookingId,
      );
      if (conflict == null) return kennel.id;
    }
    return null;
  }

  List<Booking> boardingBookingsOverlappingRange(
    DateTime start,
    DateTime end,
  ) {
    return _bookings.where((b) {
      if (b.type != BookingType.boarding) return false;
      return VacationPeriod.rangesOverlap(
        b.startDate,
        b.endDate,
        start,
        end,
      );
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
      for (final entry in b.kennelDayCounts().entries) {
        counts[entry.key] = (counts[entry.key] ?? 0) + entry.value;
      }
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

  List<IntactOppositeSexOverlap> findIntactOppositeSexOverlaps({
    required List<String> dogIds,
    required DateTime start,
    required DateTime end,
    required List<Dog> allDogs,
    String? excludeId,
  }) {
    final overlaps = <IntactOppositeSexOverlap>[];
    final dogsById = {for (final d in allDogs) d.id: d};
    final newDogs = dogIds
        .map((id) => dogsById[id])
        .whereType<Dog>()
        .toList();

    void addOverlap(Dog a, Dog b, DateTime rangeStart, DateTime rangeEnd) {
      if (!Dog.areIntactOppositeSex(a, b)) return;
      final intersection = _dateRangeIntersection(
        start,
        end,
        rangeStart,
        rangeEnd,
      );
      if (intersection == null) return;

      final male = a.isIntactMale ? a : b;
      final female = a.isIntactFemale ? a : b;
      overlaps.add(
        IntactOppositeSexOverlap(
          maleDogName: male.name,
          femaleDogName: female.name,
          overlapStart: intersection.$1,
          overlapEnd: intersection.$2,
        ),
      );
    }

    for (var i = 0; i < newDogs.length; i++) {
      for (var j = i + 1; j < newDogs.length; j++) {
        addOverlap(newDogs[i], newDogs[j], start, end);
      }
    }

    for (final booking in _bookings) {
      if (booking.id == excludeId) continue;
      if (booking.type != BookingType.boarding) continue;

      for (final newDog in newDogs) {
        for (final existingDogId in booking.dogIds) {
          final existingDog = dogsById[existingDogId];
          if (existingDog == null) continue;
          addOverlap(
            newDog,
            existingDog,
            booking.startDate,
            booking.endDate,
          );
        }
      }
    }

    return overlaps;
  }

  (DateTime, DateTime)? _dateRangeIntersection(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    final start = _dateOnly(aStart);
    final end = _dateOnly(aEnd);
    final bStartD = _dateOnly(bStart);
    final bEndD = _dateOnly(bEnd);

    final overlapStart = start.isAfter(bStartD) ? start : bStartD;
    final overlapEnd = end.isBefore(bEndD) ? end : bEndD;
    if (overlapStart.isAfter(overlapEnd)) return null;
    return (overlapStart, overlapEnd);
  }

  String? checkKennelConflict({
    required List<String> dogIds,
    required DateTime start,
    required DateTime end,
    required String? kennelId,
    DateTime? kennelChangeStartDate,
    String? kennelChangeKennelId,
    String? excludeId,
  }) {
    if (kennelId == null) return null;

    final rangeStart = _dateOnly(start);
    final rangeEnd = _dateOnly(end);

    for (var day = rangeStart;
        !day.isAfter(rangeEnd);
        day = day.add(const Duration(days: 1))) {
      final dayKennelId = _kennelIdForDay(
        kennelId: kennelId,
        kennelChangeStartDate: kennelChangeStartDate,
        kennelChangeKennelId: kennelChangeKennelId,
        day: day,
      );
      if (dayKennelId == null) continue;

      final kennel = KennelConstants.findById(dayKennelId);
      if (kennel == null) continue;

      if (dogIds.length > kennel.maxDogs) {
        return AppStrings.kennelMaxDogsExceeded(kennel.maxDogs);
      }

      var count = dogIds.length;

      for (final booking in _bookings) {
        if (booking.id == excludeId) continue;
        if (booking.type == BookingType.introMeeting) continue;
        if (booking.kennelId == null) continue;
        if (!_dayInBooking(day, booking)) continue;

        final existingKennelId = booking.kennelIdForDate(day);
        if (existingKennelId != dayKennelId) continue;

        if (kennel.maxDogs == 1 &&
            _sameDay(day, start) &&
            _sameDay(booking.endDate, day)) {
          continue;
        }

        count += booking.dogIds.length;
      }

      if (count > kennel.maxDogs) return AppStrings.conflictKennel;
    }
    return null;
  }

  bool hasSameDayTurnoverWarning({
    required String? kennelId,
    required DateTime start,
    DateTime? kennelChangeStartDate,
    String? kennelChangeKennelId,
    String? excludeId,
  }) {
    if (kennelId != null &&
        _hasSameDayCheckoutInKennel(kennelId, start, excludeId: excludeId)) {
      return true;
    }
    if (kennelChangeStartDate != null &&
        kennelChangeKennelId != null &&
        _hasSameDayCheckoutInKennel(
          kennelChangeKennelId,
          kennelChangeStartDate,
          excludeId: excludeId,
        )) {
      return true;
    }
    return false;
  }

  bool _hasSameDayCheckoutInKennel(
    String kennelId,
    DateTime day, {
    String? excludeId,
  }) {
    for (final booking in _bookings) {
      if (booking.id == excludeId) continue;
      if (booking.type == BookingType.introMeeting) continue;
      if (booking.kennelId == null) continue;
      if (!_sameDay(day, booking.endDate)) continue;
      if (booking.kennelIdForDate(booking.endDate) != kennelId) continue;
      return true;
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

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String? _kennelIdForDay({
    required String? kennelId,
    required DateTime? kennelChangeStartDate,
    required String? kennelChangeKennelId,
    required DateTime day,
  }) {
    if (kennelId == null) return null;
    if (kennelChangeStartDate != null &&
        kennelChangeKennelId != null &&
        kennelChangeKennelId.isNotEmpty) {
      final d = _dateOnly(day);
      final changeStart = _dateOnly(kennelChangeStartDate);
      if (!d.isBefore(changeStart)) return kennelChangeKennelId;
    }
    return kennelId;
  }

  bool _dayInBooking(DateTime day, Booking booking) {
    final d = _dateOnly(day);
    final start = _dateOnly(booking.startDate);
    final end = _dateOnly(booking.endDate);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}
