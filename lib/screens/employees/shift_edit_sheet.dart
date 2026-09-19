import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/shift_format.dart';
import '../../core/utils/shift_pay_calculator.dart';
import '../../models/employee_model.dart';
import '../../models/shift_model.dart';
import '../../providers/employee_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_snackbar.dart';
import '../../widgets/common/loading_overlay.dart';

class ShiftEditSheet extends StatefulWidget {
  final Employee employee;
  final Shift? shift;

  const ShiftEditSheet({
    super.key,
    required this.employee,
    this.shift,
  });

  bool get isEdit => shift != null;

  static Future<bool> confirmAndDelete(
    BuildContext context, {
    required String shiftId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.confirmDeleteShift),
        content: const Text(AppStrings.confirmDeleteShiftMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.deleteShift),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    final provider = context.read<EmployeeProvider>();
    await provider.deleteShift(shiftId);
    if (!context.mounted) return false;
    if (provider.errorMessage != null) {
      showErrorSnackbar(context, provider.errorMessage!);
      return false;
    }
    showSuccessSnackbar(context, AppStrings.shiftDeleted);
    return true;
  }

  static Future<void> show(
    BuildContext context, {
    required Employee employee,
    Shift? shift,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ShiftEditSheet(employee: employee, shift: shift),
    );
  }

  @override
  State<ShiftEditSheet> createState() => _ShiftEditSheetState();
}

class _ShiftEditSheetState extends State<ShiftEditSheet> {
  late DateTime _startAt;
  late DateTime _endAt;

  @override
  void initState() {
    super.initState();
    final shift = widget.shift;
    final now = DateTime.now();
    _startAt = shift?.startAt ?? now.subtract(const Duration(hours: 2));
    _endAt = shift?.endAt ?? now;
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final picked = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (isStart) {
        _startAt = picked;
      } else {
        _endAt = picked;
      }
    });
  }

  Future<void> _save() async {
    final provider = context.read<EmployeeProvider>();
    final ok = await provider.saveShift(
      employee: widget.employee,
      startAt: _startAt,
      endAt: _endAt,
      existing: widget.shift,
    );
    if (!mounted) return;
    if (!ok || provider.errorMessage != null) {
      showErrorSnackbar(
        context,
        provider.errorMessage ?? AppStrings.error,
      );
      return;
    }
    showSuccessSnackbar(context, AppStrings.shiftSaved);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final shift = widget.shift;
    if (shift == null) return;
    final deleted = await ShiftEditSheet.confirmAndDelete(
      context,
      shiftId: shift.id,
    );
    if (deleted && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeeProvider>();
    final livePreview = provider.previewPay(
      start: _startAt,
      end: _endAt,
      hourlyWage: widget.shift?.hourlyWage ?? widget.employee.hourlyWage,
    );

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return LoadingOverlay(
      isLoading: provider.isLoading,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isEdit ? AppStrings.editShift : AppStrings.addShift,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.employee.name,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _DateTimeTile(
                label: AppStrings.shiftStart,
                value: dateFormat.format(_startAt),
                onTap: () => _pickDateTime(isStart: true),
              ),
              _DateTimeTile(
                label: AppStrings.shiftEnd,
                value: dateFormat.format(_endAt),
                onTap: () => _pickDateTime(isStart: false),
              ),
              const SizedBox(height: 12),
              _PayBreakdownCard(pay: livePreview),
              const SizedBox(height: 20),
              AppButton(label: AppStrings.save, onPressed: _save),
              if (widget.isEdit) ...[
                const SizedBox(height: 8),
                AppButton(
                  label: AppStrings.deleteShift,
                  onPressed: _delete,
                  backgroundColor: AppColors.error,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.schedule),
      onTap: onTap,
    );
  }
}

class _PayBreakdownCard extends StatelessWidget {
  final ShiftPayBreakdown pay;

  const _PayBreakdownCard({required this.pay});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.payBreakdown,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _row(
              AppStrings.regularHours,
              '${formatDurationMinutes(pay.regularMinutes)} · ₪${formatMoney(pay.regularPay)}',
            ),
            if (pay.premiumMinutes > 0)
              _row(
                AppStrings.shabbatHours,
                '${formatDurationMinutes(pay.premiumMinutes)} · ₪${formatMoney(pay.premiumPay)}',
              ),
            const Divider(),
            _row(
              AppStrings.totalPay,
              '${formatDurationMinutes(pay.totalMinutes)} · ₪${formatMoney(pay.totalPay)}',
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
