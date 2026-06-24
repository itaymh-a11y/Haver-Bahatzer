import 'package:cloud_firestore/cloud_firestore.dart';

class PensionProduct {
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PensionProduct({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PensionProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PensionProduct(
      id: doc.id,
      name: data['name'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      imageUrl: data['imageUrl'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PensionProduct copyWith({
    String? id,
    String? name,
    double? price,
    Object? imageUrl = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PensionProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl:
          imageUrl == _sentinel ? this.imageUrl : imageUrl as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _sentinel = Object();
