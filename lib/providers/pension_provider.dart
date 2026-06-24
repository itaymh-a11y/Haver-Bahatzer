import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/utils/image_utils.dart';
import '../models/pension_order_model.dart';
import '../models/pension_product_model.dart';
import '../services/pension_service.dart';
import '../services/storage_service.dart';

class PensionProvider extends ChangeNotifier {
  final PensionService _pensionService;
  final StorageService _storageService;

  List<PensionProduct> _products = [];
  List<PensionOrder> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _productsListening = false;
  bool _ordersListening = false;

  PensionProvider(
    this._pensionService,
    this._storageService,
  );

  List<PensionProduct> get products => _products;
  List<PensionOrder> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void startListening() {
    if (!_productsListening) {
      _productsListening = true;
      _pensionService.watchProducts().listen(
        (products) {
          _products = products;
          notifyListeners();
        },
        onError: (e) {
          _errorMessage = e.toString();
          notifyListeners();
        },
      );
    }
    if (!_ordersListening) {
      _ordersListening = true;
      _pensionService.watchOrders().listen(
        (orders) {
          _orders = orders;
          notifyListeners();
        },
        onError: (e) {
          _errorMessage = e.toString();
          notifyListeners();
        },
      );
    }
  }

  PensionProduct? findProductById(String id) {
    final idx = _products.indexWhere((p) => p.id == id);
    return idx != -1 ? _products[idx] : null;
  }

  Future<void> addProduct({
    required PensionProduct product,
    File? photoFile,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docId = await _pensionService.addProduct(product);
      if (photoFile != null) {
        final bytes = await ImageUtils.compressImageToBytes(photoFile) ??
            await photoFile.readAsBytes();
        final url = await _storageService.uploadProductPhoto(docId, bytes);
        await _pensionService.updateProduct(
          product.copyWith(id: docId, imageUrl: url),
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProduct({
    required PensionProduct product,
    File? photoFile,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var updated = product;
      if (photoFile != null) {
        final bytes = await ImageUtils.compressImageToBytes(photoFile) ??
            await photoFile.readAsBytes();
        final url =
            await _storageService.uploadProductPhoto(product.id, bytes);
        updated = product.copyWith(imageUrl: url);
      }
      await _pensionService.updateProduct(updated);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    _errorMessage = null;
    try {
      await _pensionService.deleteProduct(id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<PensionOrder?> createOrder({
    required List<PensionOrderLine> lines,
    String? notes,
  }) async {
    if (lines.isEmpty) return null;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final total =
          lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
      final order = PensionOrder(
        id: '',
        lines: lines,
        totalPrice: total,
        notes: notes,
        createdAt: DateTime.now(),
      );
      final docId = await _pensionService.addOrder(order);
      return order.copyWithId(docId);
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteOrder(String id) async {
    _errorMessage = null;
    try {
      await _pensionService.deleteOrder(id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

extension _PensionOrderCopy on PensionOrder {
  PensionOrder copyWithId(String id) {
    return PensionOrder(
      id: id,
      lines: lines,
      totalPrice: totalPrice,
      notes: notes,
      createdAt: createdAt,
    );
  }
}
