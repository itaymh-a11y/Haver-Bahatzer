import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/pension_order_model.dart';
import '../../models/pension_product_model.dart';
import '../../providers/pension_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_snackbar.dart';
import '../../widgets/common/loading_overlay.dart';
import 'pension_order_detail_screen.dart';

class PensionOrderCreateScreen extends StatefulWidget {
  const PensionOrderCreateScreen({super.key});

  @override
  State<PensionOrderCreateScreen> createState() =>
      _PensionOrderCreateScreenState();
}

class _PensionOrderCreateScreenState extends State<PensionOrderCreateScreen> {
  final Map<String, int> _quantities = {};
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
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

    final provider = context.read<PensionProvider>();
    final notes = _notesController.text.trim();
    final order = await provider.createOrder(
      lines: lines,
      notes: notes.isEmpty ? null : notes,
    );

    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PensionProvider>();
    final products = provider.products;
    final total = _total(products);
    final selectedCount =
        _quantities.values.fold<int>(0, (sum, q) => sum + q);

    return LoadingOverlay(
      isLoading: provider.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.newSupplierOrder)),
        body: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final qty = _qtyFor(product.id);
                  final isSelected = qty > 0;

                  return Card(
                    clipBehavior: Clip.hardEdge,
                    color: isSelected
                        ? AppColors.chipBackground
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: product.imageUrl != null
                                  ? Image.network(
                                      product.imageUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : ColoredBox(
                                      color: AppColors.divider.withValues(alpha: 0.3),
                                      child: const Icon(Icons.image_outlined),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '₪${product.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: qty > 0
                                ? () => _setQty(product.id, qty - 1)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$qty',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _setQty(product.id, qty + 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.orderNotes,
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
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '₪${total.toStringAsFixed(0)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        AppButton(
                          label: AppStrings.finishOrder,
                          onPressed: () => _finishOrder(products),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
