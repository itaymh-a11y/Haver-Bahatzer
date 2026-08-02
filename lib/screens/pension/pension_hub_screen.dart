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
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PensionProvider>().startListening();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onFabPressed() async {
    final isProductsTab = _tabController.index == 0;
    if (isProductsTab) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PensionProductFormScreen(),
        ),
      );
      return;
    }

    final products = context.read<PensionProvider>().products;
    if (products.isEmpty) {
      final goAdd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(AppStrings.noProducts),
          content: const Text(
            'כדי ליצור הזמנה לספק צריך קודם להוסיף מוצרים לספרייה.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(AppStrings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(AppStrings.addProduct),
            ),
          ],
        ),
      );
      if (goAdd == true && mounted) {
        _tabController.animateTo(0);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PensionProductFormScreen(),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PensionOrderCreateScreen(),
      ),
    );
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
        children: [
          const PensionProductsTab(),
          PensionOrdersTab(onCreateOrder: _onFabPressed),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onFabPressed,
        icon: Icon(isProductsTab ? Icons.add : Icons.playlist_add),
        label: Text(
          isProductsTab ? AppStrings.addProduct : AppStrings.newSupplierOrder,
        ),
      ),
    );
  }
}
