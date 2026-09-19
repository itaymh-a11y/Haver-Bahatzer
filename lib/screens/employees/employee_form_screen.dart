import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/validators.dart';
import '../../models/employee_model.dart';
import '../../providers/employee_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/error_snackbar.dart';
import '../../widgets/common/loading_overlay.dart';

class EmployeeFormScreen extends StatefulWidget {
  final Employee? employee;

  const EmployeeFormScreen({super.key, this.employee});

  bool get isEdit => employee != null;

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _wageController;

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;
    _nameController = TextEditingController(text: employee?.name ?? '');
    _wageController = TextEditingController(
      text: employee != null && employee.hourlyWage > 0
          ? formatMoney(employee.hourlyWage)
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _wageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<EmployeeProvider>();
    final now = DateTime.now();
    final wage = double.parse(_wageController.text.replaceAll(',', '.'));

    if (widget.isEdit) {
      await provider.updateEmployee(
        widget.employee!.copyWith(
          name: _nameController.text.trim(),
          hourlyWage: wage,
          updatedAt: now,
        ),
      );
    } else {
      await provider.addEmployee(
        Employee(
          id: '',
          name: _nameController.text.trim(),
          hourlyWage: wage,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (!mounted) return;
    if (provider.errorMessage != null) {
      showErrorSnackbar(context, provider.errorMessage!);
      return;
    }

    Navigator.pop(context);
  }

  Future<void> _deleteOrDeactivate() async {
    final employee = widget.employee;
    if (employee == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.confirmDeleteEmployee),
        content: const Text(AppStrings.confirmDeactivateEmployee),
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

    final provider = context.read<EmployeeProvider>();
    final deleted = await provider.removeOrDeactivateEmployee(employee);
    if (!mounted) return;
    if (provider.errorMessage != null) {
      showErrorSnackbar(context, provider.errorMessage!);
      return;
    }
    showSuccessSnackbar(
      context,
      deleted ? AppStrings.employeeDeleted : AppStrings.employeeDeactivated,
    );
    Navigator.pop(context);
  }

  Future<void> _reactivate() async {
    final employee = widget.employee;
    if (employee == null) return;
    await context.read<EmployeeProvider>().updateEmployee(
          employee.copyWith(isActive: true, updatedAt: DateTime.now()),
        );
    if (!mounted) return;
    showSuccessSnackbar(context, AppStrings.employeeUpdated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeeProvider>();

    return LoadingOverlay(
      isLoading: provider.isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEdit ? AppStrings.editEmployee : AppStrings.addEmployee,
          ),
          actions: [
            if (widget.isEdit)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleteOrDeactivate,
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppTextField(
                label: AppStrings.employeeName,
                controller: _nameController,
                validator: Validators.required,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: '${AppStrings.hourlyWage} (₪)',
                controller: _wageController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                hint: 'לדוגמה: 50',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppStrings.fieldRequired;
                  }
                  final parsed = double.tryParse(value.replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) {
                    return AppStrings.invalidWage;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              AppButton(
                label: AppStrings.save,
                onPressed: _submit,
              ),
              if (widget.isEdit && widget.employee?.isActive == false) ...[
                const SizedBox(height: 12),
                AppButton(
                  label: AppStrings.activateEmployee,
                  onPressed: _reactivate,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
