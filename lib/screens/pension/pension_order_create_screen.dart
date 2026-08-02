import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/money_format.dart';
import '../../models/pension_order_model.dart';
import '../../models/pension_product_model.dart';
import '../../providers/pension_provider.dart';
import '../../widgets/common/error_snackbar.dart';
import 'pension_order_detail_screen.dart';
import 'pension_product_form_screen.dart';

class PensionOrderCreateScreen extends StatefulWidget {
  const PensionOrderCreateScreen({super.key});

  @override
  State<PensionOrderCreateScreen> createState() =>
      _PensionOrderCreateScreenState();
}

class _PensionOrderCreateScreenState extends State<PensionOrderCreateScreen> {
  final Map<String, int> _quantities = {};
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PensionProvider>().startListening();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int _qtyFor(String productId) => _quantities[productId] ?? 0;

  void _setQty(String productId, int qty) {
    setState(() {
      if (qty <= 0) {
        _quantities.remove(productId);
      } else {
        _quantities[productId] = qty;
      }
    });
  }

  double _total(List<PensionProduct> products) {
    var total = 0.0;
    for (final product in products) {
      final qty = _qtyFor(product.id);
      if (qty > 0) total += product.price * qty;
    }
    return total;
  }

  List<PensionOrderLine> _buildLines(List<PensionProduct> products) {
    final lines = <PensionOrderLine>[];
    for (final product in products) {
      final qty = _qtyFor(product.id);
      if (qty <= 0) continue;
      lines.add(
        PensionOrderLine(
          productId: product.id,
          productName: product.name,
          unitPrice: product.price,
          imageUrl: product.imageUrl,
          quantity: qty,
        ),
      );
    }
    return lines;
  }

  Future<void> _finishOrder(List<PensionProduct> products) async {
    final lines = _buildLines(products);
    if (lines.isEmpty) {
      showErrorSnackbar(context, AppStrings.selectAtLeastOneProduct);
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<PensionProvider>();
    final notes = _notesController.text.trim();
    final order = await provider.createOrder(
      lines: lines,
      notes: notes.isEmpty ? null : notes,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (order == null) {
      if (provider.errorMessage != null) {
        showErrorSnackbar(context, provider.errorMessage!);
      }
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PensionOrderDetailScreen(order: order, isNew: true),
      ),
    );
  }

  Widget _productImage(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: url == null || url.isEmpty
            ? ColoredBox(
                color: AppColors.divider.withValues(alpha: 0.3),
                child: const Icon(Icons.image_outlined),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: AppColors.divider.withValues(alpha: 0.3),
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = context.watch<PensionProvider>().products;
    final query = _searchQuery.trim().toLowerCase();
    final products = query.isEmpty
        ? allProducts
        : allProducts
            .where((p) => p.name.toLowerCase().contains(query))
            .toList();
    final lines = _buildLines(allProducts);
    final total = _total(allProducts);
    final selectedCount =
        _quantities.values.fold<int>(0, (sum, q) => sum + q);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.newSupplierOrder),
      ),
      body: allProducts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      AppStrings.noProducts,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PensionProductFormScreen(),
                        ),
                      ),
                      child: const Text(AppStrings.addProduct),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: TextField(
                    controller: _searchController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'חיפוש מוצר...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                Expanded(
                  child: products.isEmpty
                      ? const Center(
                          child: Text('לא נמצאו מוצרים לחיפוש'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final qty = _qtyFor(product.id);
                            final isSelected = qty > 0;
                            final lineTotal = product.price * qty;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color:
                                  isSelected ? AppColors.chipBackground : null,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    _productImage(product.imageUrl),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '₪${formatMoney(product.price)} ליחידה',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                          if (isSelected)
                                            Text(
                                              'סה"כ לשורה: ₪${formatMoney(lineTotal)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: qty > 0
                                          ? () => _setQty(product.id, qty - 1)
                                          : null,
                                      icon: const Icon(
                                          Icons.remove_circle_outline),
                                    ),
                                    Text(
                                      '$qty',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _setQty(product.id, qty + 1),
                                      icon: const Icon(Icons.add_circle_outline),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (lines.isNotEmpty)
                  Material(
                    color: AppColors.chipBackground,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'סיכום בחירה',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            ...lines.map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${line.productName} × ${line.quantity}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text('₪${formatMoney(line.lineTotal)}'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Material(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: AppStrings.orderNotes,
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$selectedCount פריטים נבחרו',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      '₪${formatMoney(total)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton(
                                onPressed: _saving
                                    ? null
                                    : () => _finishOrder(allProducts),
                                child: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(AppStrings.finishOrder),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
