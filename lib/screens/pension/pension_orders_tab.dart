import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/money_format.dart';
import '../../models/pension_order_model.dart';
import '../../providers/pension_provider.dart';
import 'pension_order_detail_screen.dart';

class PensionOrdersTab extends StatelessWidget {
  final VoidCallback? onCreateOrder;

  const PensionOrdersTab({super.key, this.onCreateOrder});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<PensionProvider>().orders;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');

    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 48,
                  color: AppColors.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                AppStrings.noOrders,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.noOrdersSubtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (onCreateOrder != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onCreateOrder,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text(AppStrings.newSupplierOrder),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderTile(order: order, dateFormat: dateFormat);
      },
    );
  }
}

class _OrderTile extends StatelessWidget {
  final PensionOrder order;
  final DateFormat dateFormat;

  const _OrderTile({required this.order, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final itemCount =
        order.lines.fold<int>(0, (sum, line) => sum + line.quantity);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.chipBackground,
        child: Text('${order.lines.length}',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.bold)),
      ),
      title: Text(dateFormat.format(order.createdAt)),
      subtitle: Text('$itemCount פריטים'),
      trailing: Text(
        '₪${formatMoney(order.totalPrice)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PensionOrderDetailScreen(order: order),
        ),
      ),
    );
  }
}
