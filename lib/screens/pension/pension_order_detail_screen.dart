import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/pension_order_model.dart';
import '../../providers/pension_provider.dart';

class PensionOrderDetailScreen extends StatelessWidget {
  final PensionOrder order;
  final bool isNew;

  const PensionOrderDetailScreen({
    super.key,
    required this.order,
    this.isNew = false,
  });

  Future<void> _copyText(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.orderCopied)),
      );
    }
  }

  Future<void> _shareWhatsapp(String text) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(text)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.confirmDeleteOrder),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await context.read<PensionProvider>().deleteOrder(order.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');
    final supplierText = order.toSupplierText(dateFormat.format(order.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.orderSummary),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isNew)
            Card(
              color: AppColors.chipBackground,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppStrings.orderSaved,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isNew) const SizedBox(height: 12),
          Text(
            dateFormat.format(order.createdAt),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.orderItems,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...order.lines.map((line) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: line.imageUrl != null
                              ? Image.network(line.imageUrl!, fit: BoxFit.cover)
                              : ColoredBox(
                                  color:
                                      AppColors.divider.withValues(alpha: 0.3),
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
                              line.productName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${AppStrings.quantity}: ${line.quantity}',
                            ),
                            Text(
                              '₪${line.unitPrice.toStringAsFixed(0)} × ${line.quantity} = ₪${line.lineTotal.toStringAsFixed(0)}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.totalPrice,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '₪${order.totalPrice.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              AppStrings.orderNotes,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(order.notes!),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                supplierText,
                style: const TextStyle(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyText(context, supplierText),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text(AppStrings.copyOrderText),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _shareWhatsapp(supplierText),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text(AppStrings.sendViaWhatsapp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
