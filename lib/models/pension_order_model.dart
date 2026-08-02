import 'package:cloud_firestore/cloud_firestore.dart';

class PensionOrderLine {
  final String productId;
  final String productName;
  final double unitPrice;
  final String? imageUrl;
  final int quantity;

  const PensionOrderLine({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.imageUrl,
    required this.quantity,
  });

  double get lineTotal => unitPrice * quantity;

  factory PensionOrderLine.fromMap(Map<String, dynamic> map) {
    return PensionOrderLine(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      imageUrl: map['imageUrl'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'unitPrice': unitPrice,
      'imageUrl': imageUrl,
      'quantity': quantity,
    };
  }
}

class PensionOrder {
  final String id;
  final List<PensionOrderLine> lines;
  final double totalPrice;
  final String? notes;
  final DateTime createdAt;

  const PensionOrder({
    required this.id,
    required this.lines,
    required this.totalPrice,
    this.notes,
    required this.createdAt,
  });

  factory PensionOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawLines = data['lines'] as List<dynamic>? ?? [];
    final lines = rawLines
        .map((e) => PensionOrderLine.fromMap((e as Map).cast<String, dynamic>()))
        .toList();

    return PensionOrder(
      id: doc.id,
      lines: lines,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0,
      notes: data['notes'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lines': lines.map((l) => l.toMap()).toList(),
      'totalPrice': totalPrice,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String toSupplierText(String formattedDate) {
    final buffer = StringBuffer();
    buffer.writeln('הזמנה לספק — $formattedDate');
    buffer.writeln('────────────────');
    for (final line in lines) {
      buffer.writeln(
        '• ${line.quantity}× ${line.productName} — ₪${line.lineTotal.toStringAsFixed(2)}',
      );
    }
    buffer.writeln('────────────────');
    buffer.writeln('סה"כ הזמנה: ₪${totalPrice.toStringAsFixed(2)}');
    if (notes != null && notes!.trim().isNotEmpty) {
      buffer.writeln('הערות: ${notes!.trim()}');
    }
    return buffer.toString().trim();
  }
}
