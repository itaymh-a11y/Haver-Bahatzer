import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/vacation_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/dog_provider.dart';
import '../../providers/vacation_provider.dart';
import '../../widgets/common/error_snackbar.dart';

class VacationsScreen extends StatelessWidget {
  final DateTime? initialStartDate;

  const VacationsScreen({super.key, this.initialStartDate});

  @override
  Widget build(BuildContext context) {
    final vacations = context.watch<VacationProvider>().vacations;
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.vacations)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showVacationDialog(
          context,
          initialStart: initialStartDate,
        ),
        child: const Icon(Icons.add),
      ),
      body: vacations.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.beach_access,
                        size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.noVacations,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.noVacationsSubtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: vacations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final vacation = vacations[i];
                return ListTile(
                  leading: const Icon(Icons.event_busy, color: AppColors.vacationDay),
                  title: Text(
                    vacation.label?.isNotEmpty == true
                        ? vacation.label!
                        : '${dateFormat.format(vacation.startDate)} – ${dateFormat.format(vacation.endDate)}',
                  ),
                  subtitle: vacation.label?.isNotEmpty == true
                      ? Text(
                          '${dateFormat.format(vacation.startDate)} – ${dateFormat.format(vacation.endDate)}',
                        )
                      : const Text('חסימת אירוח בלבד'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, vacation),
                  ),
                  onTap: () => _showVacationDialog(context, existing: vacation),
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, VacationPeriod vacation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.confirmDeleteVacation),
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
    await context.read<VacationProvider>().deleteVacation(vacation.id);
  }

  Future<void> _showVacationDialog(
    BuildContext context, {
    VacationPeriod? existing,
    DateTime? initialStart,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _VacationDialog(
        existing: existing,
        initialStart: initialStart,
      ),
    );
  }
}

class _VacationDialog extends StatefulWidget {
  final VacationPeriod? existing;
  final DateTime? initialStart;

  const _VacationDialog({this.existing, this.initialStart});

  @override
  State<_VacationDialog> createState() => _VacationDialogState();
}

class _VacationDialogState extends State<_VacationDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  late final TextEditingController _labelController;
  final _dateFormat = DateFormat('dd/MM/yyyy', 'he');

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _startDate = existing?.startDate ??
        widget.initialStart ??
        DateTime.now();
    _endDate = existing?.endDate ?? _startDate;
    _labelController = TextEditingController(text: existing?.label ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('he', 'IL'),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) _startDate = _endDate;
      }
    });
  }

  Future<void> _save() async {
    final bookingProvider = context.read<BookingProvider>();
    final vacationProvider = context.read<VacationProvider>();
    final overlapping =
        bookingProvider.boardingBookingsOverlappingRange(_startDate, _endDate);

    if (overlapping.isNotEmpty) {
      final dogs = context.read<DogProvider>().dogs;
      final summary = overlapping.map((b) {
        final names = b.dogIds
            .map((id) {
              final idx = dogs.indexWhere((d) => d.id == id);
              return idx != -1 ? dogs[idx].name : '';
            })
            .where((n) => n.isNotEmpty)
            .join(', ');
        return '• $names (${_dateFormat.format(b.startDate)} – ${_dateFormat.format(b.endDate)})';
      }).join('\n');

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(AppStrings.vacationOverlapBookingsTitle),
          content: Text('${AppStrings.vacationOverlapBookingsMessage}\n\n$summary'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(AppStrings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(AppStrings.createVacationAnyway),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final label = _labelController.text.trim();
    final now = DateTime.now();

    if (widget.existing != null) {
      await vacationProvider.updateVacation(
        widget.existing!.copyWith(
          startDate: _startDate,
          endDate: _endDate,
          label: label.isEmpty ? null : label,
        ),
      );
    } else {
      await vacationProvider.addVacation(
        VacationPeriod(
          id: '',
          startDate: _startDate,
          endDate: _endDate,
          label: label.isEmpty ? null : label,
          createdAt: now,
        ),
      );
    }

    if (vacationProvider.errorMessage != null) {
      if (mounted) {
        showErrorSnackbar(context, vacationProvider.errorMessage!);
      }
      return;
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? AppStrings.editVacation : AppStrings.addVacation),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(AppStrings.startDate),
              subtitle: Text(_dateFormat.format(_startDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickDate(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(AppStrings.endDate),
              subtitle: Text(_dateFormat.format(_endDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickDate(isStart: false),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: AppStrings.vacationLabel,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancel),
        ),
        TextButton(
          onPressed: _save,
          child: const Text(AppStrings.saveChanges),
        ),
      ],
    );
  }
}
