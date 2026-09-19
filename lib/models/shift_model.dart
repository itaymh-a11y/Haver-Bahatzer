import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/shift_pay_calculator.dart';

class Shift {
  final String id;
  final String employeeId;
  final String employeeName;
  final double hourlyWage;
  final DateTime startAt;
  final DateTime? endAt;
  final int? regularMinutes;
  final int? premiumMinutes;
  final double? regularPay;
  final double? premiumPay;
  final double? totalPay;
  final DateTime? shabbatStartAt;
  final DateTime? shabbatEndAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Shift({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.hourlyWage,
    required this.startAt,
    this.endAt,
    this.regularMinutes,
    this.premiumMinutes,
    this.regularPay,
    this.premiumPay,
    this.totalPay,
    this.shabbatStartAt,
    this.shabbatEndAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => endAt == null;

  List<ShabbatWindow> get storedWindows {
    final start = shabbatStartAt;
    final end = shabbatEndAt;
    if (start == null || end == null) return const [];
    return [ShabbatWindow(start: start, end: end)];
  }

  factory Shift.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Shift(
      id: doc.id,
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? '',
      hourlyWage: (data['hourlyWage'] as num?)?.toDouble() ?? 0,
      startAt: (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (data['endAt'] as Timestamp?)?.toDate(),
      regularMinutes: data['regularMinutes'] as int?,
      premiumMinutes: data['premiumMinutes'] as int?,
      regularPay: (data['regularPay'] as num?)?.toDouble(),
      premiumPay: (data['premiumPay'] as num?)?.toDouble(),
      totalPay: (data['totalPay'] as num?)?.toDouble(),
      shabbatStartAt: (data['shabbatStartAt'] as Timestamp?)?.toDate(),
      shabbatEndAt: (data['shabbatEndAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'hourlyWage': hourlyWage,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
      'regularMinutes': regularMinutes,
      'premiumMinutes': premiumMinutes,
      'regularPay': regularPay,
      'premiumPay': premiumPay,
      'totalPay': totalPay,
      'shabbatStartAt':
          shabbatStartAt == null ? null : Timestamp.fromDate(shabbatStartAt!),
      'shabbatEndAt':
          shabbatEndAt == null ? null : Timestamp.fromDate(shabbatEndAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Shift copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    double? hourlyWage,
    DateTime? startAt,
    Object? endAt = _sentinel,
    Object? regularMinutes = _sentinel,
    Object? premiumMinutes = _sentinel,
    Object? regularPay = _sentinel,
    Object? premiumPay = _sentinel,
    Object? totalPay = _sentinel,
    Object? shabbatStartAt = _sentinel,
    Object? shabbatEndAt = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Shift(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      hourlyWage: hourlyWage ?? this.hourlyWage,
      startAt: startAt ?? this.startAt,
      endAt: endAt == _sentinel ? this.endAt : endAt as DateTime?,
      regularMinutes: regularMinutes == _sentinel
          ? this.regularMinutes
          : regularMinutes as int?,
      premiumMinutes: premiumMinutes == _sentinel
          ? this.premiumMinutes
          : premiumMinutes as int?,
      regularPay:
          regularPay == _sentinel ? this.regularPay : regularPay as double?,
      premiumPay:
          premiumPay == _sentinel ? this.premiumPay : premiumPay as double?,
      totalPay: totalPay == _sentinel ? this.totalPay : totalPay as double?,
      shabbatStartAt: shabbatStartAt == _sentinel
          ? this.shabbatStartAt
          : shabbatStartAt as DateTime?,
      shabbatEndAt: shabbatEndAt == _sentinel
          ? this.shabbatEndAt
          : shabbatEndAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Shift withBreakdown(ShiftPayBreakdown breakdown) {
    return copyWith(
      regularMinutes: breakdown.regularMinutes,
      premiumMinutes: breakdown.premiumMinutes,
      regularPay: breakdown.regularPay,
      premiumPay: breakdown.premiumPay,
      totalPay: breakdown.totalPay,
      shabbatStartAt: breakdown.shabbatStartAt,
      shabbatEndAt: breakdown.shabbatEndAt,
    );
  }
}

const Object _sentinel = Object();
