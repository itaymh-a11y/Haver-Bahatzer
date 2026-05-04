import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingType { boarding, introMeeting }

extension BookingTypeExtension on BookingType {
  String get firestoreValue {
    switch (this) {
      case BookingType.boarding:
        return 'boarding';
      case BookingType.introMeeting:
        return 'intro_meeting';
    }
  }

  String get hebrewLabel {
    switch (this) {
      case BookingType.boarding:
        return 'אירוח';
      case BookingType.introMeeting:
        return 'פגישת היכרות';
    }
  }

  static BookingType fromFirestoreValue(String value) {
    for (final t in BookingType.values) {
      if (t.firestoreValue == value) return t;
    }
    return BookingType.boarding;
  }
}

enum BookingStatus { upcoming, active, completed }

enum PaymentMethod { bit, cash, bankTransfer }

extension PaymentMethodExtension on PaymentMethod {
  String get firestoreValue {
    switch (this) {
      case PaymentMethod.bit:
        return 'bit';
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
    }
  }

  String get hebrewLabel {
    switch (this) {
      case PaymentMethod.bit:
        return 'ביט';
      case PaymentMethod.cash:
        return 'מזומן';
      case PaymentMethod.bankTransfer:
        return 'העברה בנקאית';
    }
  }

  static PaymentMethod? fromFirestoreValue(String? value) {
    if (value == null) return null;
    for (final m in PaymentMethod.values) {
      if (m.firestoreValue == value) return m;
    }
    return null;
  }
}

class PaymentRecord {
  final double amount;
  final PaymentMethod method;
  final DateTime paidAt;

  const PaymentRecord({
    required this.amount,
    required this.method,
    required this.paidAt,
  });

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      method:
          PaymentMethodExtension.fromFirestoreValue(map['method'] as String?) ??
              PaymentMethod.cash,
      paidAt: (map['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'method': method.firestoreValue,
      'paidAt': Timestamp.fromDate(paidAt),
    };
  }
}

class Booking {
  final String id;
  final List<String> dogIds;
  final BookingType type;
  final String? kennelId;
  final DateTime startDate;
  final DateTime endDate;
  final String? meetingTime;
  final double? totalPrice;
  final double? bookingDailyRate;
  final DateTime? rateChangeStartDate;
  final double? rateChangeDailyRate;
  final bool chargeCheckoutDay;
  final bool isPaid;
  final PaymentMethod? paymentMethod;
  final List<PaymentRecord> payments;
  final List<String> contractPhotoUrls;
  final DateTime createdAt;
  final DateTime? paidAt;

  const Booking({
    required this.id,
    required this.dogIds,
    required this.type,
    this.kennelId,
    required this.startDate,
    required this.endDate,
    this.meetingTime,
    this.totalPrice,
    this.bookingDailyRate,
    this.rateChangeStartDate,
    this.rateChangeDailyRate,
    this.chargeCheckoutDay = true,
    this.isPaid = false,
    this.paymentMethod,
    this.payments = const [],
    this.contractPhotoUrls = const [],
    required this.createdAt,
    this.paidAt,
  });

  // Legacy accessor — first photo URL for backward compat
  String? get contractPhotoUrl =>
      contractPhotoUrls.isNotEmpty ? contractPhotoUrls.first : null;

  // Computed — not stored in Firestore
  BookingStatus get status {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    if (todayDate.isBefore(start)) return BookingStatus.upcoming;
    if (todayDate.isAfter(end)) return BookingStatus.completed;
    return BookingStatus.active;
  }

  bool get hasContract => contractPhotoUrls.isNotEmpty;

  double get paidAmount {
    if (payments.isNotEmpty) {
      return payments.fold(0.0, (sum, p) => sum + p.amount);
    }
    if (isPaid) return totalPrice ?? 0;
    return 0;
  }

  double get remainingAmount {
    final total = totalPrice ?? 0;
    final remain = total - paidAmount;
    return remain < 0 ? 0 : remain;
  }

  bool get isFullyPaid => (totalPrice ?? 0) > 0 && remainingAmount <= 0.01;

  bool get needsContractAlert =>
      type == BookingType.boarding &&
      (status == BookingStatus.upcoming || status == BookingStatus.active) &&
      !hasContract;

  int get numberOfDays => endDate.difference(startDate).inDays + 1;

  int get billingDays {
    final raw = endDate.difference(startDate).inDays + (chargeCheckoutDay ? 1 : 0);
    return raw < 1 ? 1 : raw;
  }

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final dogIdsList = (data['dogIds'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList();

    return Booking(
      id: doc.id,
      dogIds: dogIdsList,
      type: BookingTypeExtension.fromFirestoreValue(
          data['type'] as String? ?? 'boarding'),
      kennelId: data['kennelId'] as String?,
      startDate:
          (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      meetingTime: data['meetingTime'] as String?,
      totalPrice: (data['totalPrice'] as num?)?.toDouble(),
      bookingDailyRate: (data['bookingDailyRate'] as num?)?.toDouble(),
      rateChangeStartDate: (data['rateChangeStartDate'] as Timestamp?)?.toDate(),
      rateChangeDailyRate: (data['rateChangeDailyRate'] as num?)?.toDouble(),
      chargeCheckoutDay: data['chargeCheckoutDay'] as bool? ?? true,
      isPaid: data['isPaid'] as bool? ?? false,
      paymentMethod:
          PaymentMethodExtension.fromFirestoreValue(data['paymentMethod'] as String?),
      payments: _parsePayments(data),
      contractPhotoUrls: _parseContractUrls(data),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dogIds': dogIds,
      'type': type.firestoreValue,
      'kennelId': kennelId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'meetingTime': meetingTime,
      'totalPrice': totalPrice,
      'bookingDailyRate': bookingDailyRate,
      'rateChangeStartDate': rateChangeStartDate != null
          ? Timestamp.fromDate(rateChangeStartDate!)
          : null,
      'rateChangeDailyRate': rateChangeDailyRate,
      'chargeCheckoutDay': chargeCheckoutDay,
      'isPaid': isFullyPaid,
      'paymentMethod': paymentMethod?.firestoreValue,
      'payments': payments.map((p) => p.toMap()).toList(),
      'contractPhotoUrls': contractPhotoUrls,
      'contractPhotoUrl': contractPhotoUrls.isNotEmpty ? contractPhotoUrls.first : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
    };
  }

  Booking copyWith({
    String? id,
    List<String>? dogIds,
    BookingType? type,
    String? kennelId,
    DateTime? startDate,
    DateTime? endDate,
    String? meetingTime,
    double? totalPrice,
    double? bookingDailyRate,
    Object? rateChangeStartDate = _sentinel,
    Object? rateChangeDailyRate = _sentinel,
    bool? chargeCheckoutDay,
    bool? isPaid,
    PaymentMethod? paymentMethod,
    List<PaymentRecord>? payments,
    List<String>? contractPhotoUrls,
    DateTime? createdAt,
    Object? paidAt = _sentinel,
  }) {
    return Booking(
      id: id ?? this.id,
      dogIds: dogIds ?? this.dogIds,
      type: type ?? this.type,
      kennelId: kennelId ?? this.kennelId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      meetingTime: meetingTime ?? this.meetingTime,
      totalPrice: totalPrice ?? this.totalPrice,
      bookingDailyRate: bookingDailyRate ?? this.bookingDailyRate,
      rateChangeStartDate: rateChangeStartDate == _sentinel
          ? this.rateChangeStartDate
          : rateChangeStartDate as DateTime?,
      rateChangeDailyRate: rateChangeDailyRate == _sentinel
          ? this.rateChangeDailyRate
          : rateChangeDailyRate as double?,
      chargeCheckoutDay: chargeCheckoutDay ?? this.chargeCheckoutDay,
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      payments: payments ?? this.payments,
      contractPhotoUrls: contractPhotoUrls ?? this.contractPhotoUrls,
      createdAt: createdAt ?? this.createdAt,
      paidAt: paidAt == _sentinel ? this.paidAt : paidAt as DateTime?,
    );
  }
}

const Object _sentinel = Object();

List<String> _parseContractUrls(Map<String, dynamic> data) {
  final list = data['contractPhotoUrls'];
  if (list is List && list.isNotEmpty) {
    return list.whereType<String>().toList();
  }
  // Backward compat: single URL field from old documents
  final single = data['contractPhotoUrl'] as String?;
  if (single != null && single.isNotEmpty) return [single];
  return const [];
}

List<PaymentRecord> _parsePayments(Map<String, dynamic> data) {
  final raw = data['payments'];
  if (raw is List) {
    return raw
        .map((e) => (e as Map).cast<String, dynamic>())
        .map(PaymentRecord.fromMap)
        .toList();
  }

  // Backward compat for old docs with a single payment.
  final isPaid = data['isPaid'] as bool? ?? false;
  final totalPrice = (data['totalPrice'] as num?)?.toDouble();
  final method =
      PaymentMethodExtension.fromFirestoreValue(data['paymentMethod'] as String?);
  final paidAt = (data['paidAt'] as Timestamp?)?.toDate();

  if (isPaid && totalPrice != null && totalPrice > 0 && method != null && paidAt != null) {
    return [
      PaymentRecord(
        amount: totalPrice,
        method: method,
        paidAt: paidAt,
      ),
    ];
  }

  return const [];
}
