import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/validators.dart';
import '../../models/pension_product_model.dart';
import '../../providers/pension_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/error_snackbar.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../widgets/dogs/dog_photo_picker.dart';

class PensionProductFormScreen extends StatefulWidget {
  final PensionProduct? product;

  const PensionProductFormScreen({super.key, this.product});

  bool get isEdit => product != null;

  @override
  State<PensionProductFormScreen> createState() =>
      _PensionProductFormScreenState();
}

class _PensionProductFormScreenState extends State<PensionProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(
      text: p != null && p.price > 0 ? formatMoney(p.price) : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<PensionProvider>();
    final now = DateTime.now();
    final price = double.parse(_priceController.text.replaceAll(',', '.'));

    if (widget.isEdit) {
      await provider.updateProduct(
        product: widget.product!.copyWith(
          name: _nameController.text.trim(),
          price: price,
          updatedAt: now,
        ),
        photoFile: _imageFile,
      );
    } else {
      await provider.addProduct(
        product: PensionProduct(
          id: '',
          name: _nameController.text.trim(),
          price: price,
          createdAt: now,
          updatedAt: now,
        ),
        photoFile: _imageFile,
      );
    }

    if (!mounted) return;
    if (provider.errorMessage != null) {
      showErrorSnackbar(context, provider.errorMessage!);
      return;
    }

    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.confirmDeleteProduct),
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
    if (confirmed != true || !mounted) return;

    await context.read<PensionProvider>().deleteProduct(widget.product!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PensionProvider>();

    return LoadingOverlay(
      isLoading: provider.isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEdit ? AppStrings.editProduct : AppStrings.addProduct,
          ),
          actions: [
            if (widget.isEdit)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DogPhotoPicker(
                imageFile: _imageFile,
                existingPhotoUrl: widget.product?.imageUrl,
                onImageSelected: (file) => setState(() => _imageFile = file),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: AppStrings.productName,
                controller: _nameController,
                validator: Validators.required,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: '${AppStrings.productPrice} (₪)',
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                hint: 'לדוגמה: 9.90',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return AppStrings.fieldRequired;
                  }
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'יש להזין מחיר תקין';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              AppButton(
                label: AppStrings.save,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
