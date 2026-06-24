import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_paths.dart';
import '../models/pension_order_model.dart';
import '../models/pension_product_model.dart';

class PensionService {
  final _products =
      FirebaseFirestore.instance.collection(FirestorePaths.pensionProducts);
  final _orders =
      FirebaseFirestore.instance.collection(FirestorePaths.pensionOrders);

  Stream<List<PensionProduct>> watchProducts() {
    return _products.orderBy('name').snapshots().map(
          (snap) => snap.docs.map(PensionProduct.fromFirestore).toList(),
        );
  }

  Future<String> addProduct(PensionProduct product) async {
    final doc = await _products.add(product.toMap());
    return doc.id;
  }

  Future<void> updateProduct(PensionProduct product) {
    return _products.doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String id) => _products.doc(id).delete();

  Stream<List<PensionOrder>> watchOrders() {
    return _orders.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(PensionOrder.fromFirestore).toList(),
        );
  }

  Future<String> addOrder(PensionOrder order) async {
    final doc = await _orders.add(order.toMap());
    return doc.id;
  }

  Future<void> deleteOrder(String id) => _orders.doc(id).delete();
}
