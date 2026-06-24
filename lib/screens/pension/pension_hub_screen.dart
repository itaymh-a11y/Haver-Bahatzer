import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/pension_provider.dart';
import 'pension_order_create_screen.dart';
import 'pension_orders_tab.dart';
import 'pension_products_tab.dart';
import 'pension_product_form_screen.dart';

class PensionHubScreen extends StatefulWidget {
  const PensionHubScreen({super.key});

  @override
  State<PensionHubScreen> createState() => _PensionHubScreenState();
}

class _PensionHubScreenState extends State<PensionHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isProductsTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.pensionProducts),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: AppStrings.productLibrary,
              icon: Icon(Icons.inventory_2_outlined),
            ),
            Tab(
              text: AppStrings.supplierOrders,
              icon: Icon(Icons.local_shipping_outlined),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PensionProductsTab(),
          PensionOrdersTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (isProductsTab) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PensionProductFormScreen(),
              ),
            );
          } else {
            final products = context.read<PensionProvider>().products;
            if (products.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(AppStrings.noProducts)),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PensionOrderCreateScreen(),
              ),
            );
          }
        },
        icon: Icon(isProductsTab ? Icons.add : Icons.playlist_add),
        label: Text(
          isProductsTab ? AppStrings.addProduct : AppStrings.newSupplierOrder,
        ),
      ),
    );
  }
}
