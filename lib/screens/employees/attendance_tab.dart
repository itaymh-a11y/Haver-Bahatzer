import 'dart:async';

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
import '../../widgets/common/error_snackbar.dart';
import 'employee_form_screen.dart';
import 'shift_edit_sheet.dart';

class AttendanceTab extends StatefulWidget {
  final Employee? selectedEmployee;
  final ValueChanged<String> onSelectEmployee;

  const AttendanceTab({
    super.key,
    required this.selectedEmployee,
    required this.onSelectEmployee,
  });

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _toggling = false;
  DateTime? _restWindowsDay;
  List<ShabbatWindow> _restWindows = const [];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  DateTime get _today => DateTime(_now.year, _now.month, _now.day);

  List<ShabbatWindow> _weekRestWindows(EmployeeProvider provider) {
    if (_restWindowsDay != _today) {
      _restWindowsDay = _today;
      _restWindows = provider.restWindowsThisWeek(_today);
    }
    return _restWindows;
  }

  Future<void> _toggleShift(Employee employee) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    final provider = context.read<EmployeeProvider>();
    final open = provider.openShiftFor(employee.id);
    final ok = open == null
        ? await provider.startShift(employee)
        : await provider.endShift(open);
    if (!mounted) return;
    setState(() => _toggling = false);
    if (!ok || provider.errorMessage != null) {
      showErrorSnackbar(context, provider.errorMessage ?? AppStrings.error);
      return;
    }
    showSuccessSnackbar(
      context,
      open == null ? AppStrings.shiftStarted : AppStrings.shiftEnded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeeProvider>();
    final active = provider.activeEmployees;
    final employee = widget.selectedEmployee;

    if (active.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.badge_outlined,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.noEmployees,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.noEmployeesSubtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmployeeFormScreen(),
                  ),
                ),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text(AppStrings.addEmployee),
              ),
            ],
          ),
        ),
      );
    }

    if (employee == null) {
      return const Center(child: Text(AppStrings.selectEmployee));
    }

    final open = provider.openShiftFor(employee.id);
    final todayShifts =
        provider.shiftsOverlappingDay(_today, employeeId: employee.id);
    final todayPay = provider.payForDay(
      _today,
      employeeId: employee.id,
      now: _now,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (active.length > 1) ...[
          Text(AppStrings.selectEmployee,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in active)
                ChoiceChip(
                  label: Text(item.name),
                  selected: item.id == employee.id,
                  onSelected: (_) => widget.onSelectEmployee(item.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        _RestTimesCard(windows: _weekRestWindows(provider)),
        const SizedBox(height: 16),
        _ClockCard(
          employee: employee,
          openShift: open,
          now: _now,
          pay: open == null ? null : provider.payForShift(open, now: _now),
          onToggle: _toggling ? null : () => _toggleShift(employee),
        ),
        const SizedBox(height: 16),
        if (todayShifts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text(
                  AppStrings.noShiftsToday,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.noShiftsTodaySubtitle,
                  style: const TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          _TodaySummaryCard(
            pay: todayPay,
            shiftCount: todayShifts.length,
          ),
          const SizedBox(height: 12),
          ...todayShifts.map(
            (shift) => _ShiftTile(
              shift: shift,
              pay: provider.payForShiftOnDay(shift, _today, now: _now),
              onTap: () => ShiftEditSheet.show(
                context,
                employee: employee,
                shift: shift,
              ),
              onDelete: () => ShiftEditSheet.confirmAndDelete(
                context,
                shiftId: shift.id,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RestTimesCard extends StatelessWidget {
  final List<ShabbatWindow> windows;

  const _RestTimesCard({required this.windows});

  @override
  Widget build(BuildContext context) {
    if (windows.isEmpty) return const SizedBox.shrink();

    final dateFormat = DateFormat('EEEE d.MM HH:mm', 'he');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.restTimesThisWeek,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              AppStrings.restTimesHint,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < windows.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              Text(
                windows[i].title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              _RestTimeRow(
                label: AppStrings.restWindowStart,
                value: dateFormat.format(windows[i].start),
              ),
              const SizedBox(height: 4),
              _RestTimeRow(
                label: AppStrings.restWindowEnd,
                value: dateFormat.format(windows[i].end),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RestTimeRow extends StatelessWidget {
  final String label;
  final String value;

  const _RestTimeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _ClockCard extends StatelessWidget {
  final Employee employee;
  final Shift? openShift;
  final DateTime now;
  final ShiftPayBreakdown? pay;
  final VoidCallback? onToggle;

  const _ClockCard({
    required this.employee,
    required this.openShift,
    required this.now,
    required this.pay,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = openShift != null;
    final fromPreviousDay = isOpen &&
        (openShift!.startAt.year != now.year ||
            openShift!.startAt.month != now.month ||
            openShift!.startAt.day != now.day);
    final timeFormat = DateFormat('HH:mm', 'he');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              employee.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '₪${formatMoney(employee.hourlyWage)} ${AppStrings.wagePerHour}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (fromPreviousDay) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${AppStrings.openShiftFromPreviousDay} · ${DateFormat('dd/MM HH:mm', 'he').format(openShift!.startAt)}',
                ),
              ),
            ],
            if (isOpen) ...[
              const SizedBox(height: 16),
              Text(
                formatElapsedClock(now.difference(openShift!.startAt)),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${AppStrings.runningShift} · ${AppStrings.shiftStart} ${timeFormat.format(openShift!.startAt)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (pay != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${AppStrings.estimatedPay}: ₪${formatMoney(pay!.totalPay)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onToggle,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor:
                    isOpen ? AppColors.error : AppColors.primary,
              ),
              icon: Icon(isOpen ? Icons.stop_circle_outlined : Icons.play_arrow),
              label: Text(
                isOpen ? AppStrings.endShift : AppStrings.startShift,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  final ShiftPayBreakdown pay;
  final int shiftCount;

  const _TodaySummaryCard({
    required this.pay,
    required this.shiftCount,
  });

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat("EEEE d.MM.yyyy", 'he').format(DateTime.now());
    return Card(
      color: AppColors.chipBackground,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$dayLabel · $shiftCount ${AppStrings.shiftsCount} · ${formatDurationMinutes(pay.totalMinutes)} · ₪${formatMoney(pay.totalPay)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (pay.premiumMinutes > 0) ...[
              const SizedBox(height: 6),
              Text(
                '${AppStrings.regularHours}: ${formatDurationMinutes(pay.regularMinutes)} · ${AppStrings.shabbatHours}: ${formatDurationMinutes(pay.premiumMinutes)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  final Shift shift;
  final ShiftPayBreakdown pay;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ShiftTile({
    required this.shift,
    required this.pay,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm', 'he');
    final endLabel = shift.endAt == null
        ? AppStrings.openShift
        : timeFormat.format(shift.endAt!);
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(
          '${timeFormat.format(shift.startAt)} – $endLabel',
        ),
        subtitle: Text(
          pay.premiumMinutes > 0
              ? '${formatDurationMinutes(pay.totalMinutes)} · ${AppStrings.regularHours} ${formatDurationMinutes(pay.regularMinutes)} · ${AppStrings.shabbatHours} ${formatDurationMinutes(pay.premiumMinutes)}'
              : formatDurationMinutes(pay.totalMinutes),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₪${formatMoney(pay.totalPay)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              tooltip: AppStrings.deleteShift,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
