import 'package:cloud_firestore/cloud_firestore.dart';

class Employee {
  final String id;
  final String name;
  final double hourlyWage;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Employee({
    required this.id,
    required this.name,
    required this.hourlyWage,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Employee.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Employee(
      id: doc.id,
      name: data['name'] as String? ?? '',
      hourlyWage: (data['hourlyWage'] as num?)?.toDouble() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'hourlyWage': hourlyWage,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Employee copyWith({
    String? id,
    String? name,
    double? hourlyWage,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      hourlyWage: hourlyWage ?? this.hourlyWage,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
