import 'package:cloud_firestore/cloud_firestore.dart';

class VacationPeriod {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final String? label;
  final DateTime createdAt;

  const VacationPeriod({
    required this.id,
    required this.startDate,
    required this.endDate,
    this.label,
    required this.createdAt,
  });

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool rangesOverlap(
    DateTime startA,
    DateTime endA,
    DateTime startB,
    DateTime endB,
  ) {
    final aStart = dateOnly(startA);
    final aEnd = dateOnly(endA);
    final bStart = dateOnly(startB);
    final bEnd = dateOnly(endB);
    return !aEnd.isBefore(bStart) && !bEnd.isBefore(aStart);
  }

  bool containsDay(DateTime day) {
    final d = dateOnly(day);
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  factory VacationPeriod.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VacationPeriod(
      id: doc.id,
      startDate:
          (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      label: data['label'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'label': label,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  VacationPeriod copyWith({
    String? id,
    DateTime? startDate,
    DateTime? endDate,
    Object? label = _sentinel,
    DateTime? createdAt,
  }) {
    return VacationPeriod(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      label: label == _sentinel ? this.label : label as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

const Object _sentinel = Object();
