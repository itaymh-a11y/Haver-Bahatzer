import 'package:cloud_firestore/cloud_firestore.dart';

class Dog {
  final String id;
  final String name;
  final String breed;
  final String ownerName;
  final String ownerPhone;
  final String? notes;
  final String? photoUrl;
  final List<String> tags; // tag IDs stored in Firestore `tags` collection
  final int? ageYears;
  final double? dailyRate;
  final bool? isNeutered;
  final bool? isMale;
  final int? mealsPerDay;
  final String? additionalNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Dog({
    required this.id,
    required this.name,
    required this.breed,
    required this.ownerName,
    required this.ownerPhone,
    this.notes,
    this.photoUrl,
    this.tags = const [],
    this.ageYears,
    this.dailyRate,
    this.isNeutered,
    this.isMale,
    this.mealsPerDay,
    this.additionalNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Dog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final tagList = (data['tags'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();

    return Dog(
      id: doc.id,
      name: data['name'] as String? ?? '',
      breed: data['breed'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      ownerPhone: data['ownerPhone'] as String? ?? '',
      notes: data['notes'] as String?,
      photoUrl: data['photoUrl'] as String?,
      tags: tagList,
      ageYears: data['ageYears'] as int?,
      dailyRate: (data['dailyRate'] as num?)?.toDouble(),
      isNeutered: data['isNeutered'] as bool?,
      isMale: data['isMale'] as bool?,
      mealsPerDay: data['mealsPerDay'] as int?,
      additionalNotes: data['additionalNotes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'breed': breed,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'notes': notes,
      'photoUrl': photoUrl,
      'tags': tags,
      'ageYears': ageYears,
      'dailyRate': dailyRate,
      'isNeutered': isNeutered,
      'isMale': isMale,
      'mealsPerDay': mealsPerDay,
      'additionalNotes': additionalNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Dog copyWith({
    String? id,
    String? name,
    String? breed,
    String? ownerName,
    String? ownerPhone,
    String? notes,
    String? photoUrl,
    List<String>? tags,
    int? ageYears,
    double? dailyRate,
    Object? isNeutered = _sentinel,
    Object? isMale = _sentinel,
    int? mealsPerDay,
    String? additionalNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Dog(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      notes: notes ?? this.notes,
      photoUrl: photoUrl ?? this.photoUrl,
      tags: tags ?? this.tags,
      ageYears: ageYears ?? this.ageYears,
      dailyRate: dailyRate ?? this.dailyRate,
      isNeutered: isNeutered == _sentinel ? this.isNeutered : isNeutered as bool?,
      isMale: isMale == _sentinel ? this.isMale : isMale as bool?,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isIntactMale => isMale == true && isNeutered == false;

  bool get isIntactFemale => isMale == false && isNeutered == false;

  static bool areIntactOppositeSex(Dog a, Dog b) {
    return (a.isIntactMale && b.isIntactFemale) ||
        (a.isIntactFemale && b.isIntactMale);
  }
}

const _sentinel = Object();
