import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/shift_format.dart';
import '../../core/utils/shift_pay_calculator.dart';
import '../../models/employee_model.dart';
import '../../providers/employee_provider.dart';
import 'shift_edit_sheet.dart';

class MonthlySummaryTab extends StatefulWidget {
  final Employee? selectedEmployee;
  final ValueChanged<String> onSelectEmployee;

  const MonthlySummaryTab({
    super.key,
    required this.selectedEmployee,
    required this.onSelectEmployee,
  });

  @override
  State<MonthlySummaryTab> createState() => _MonthlySummaryTabState();
}

class _MonthlySummaryTabState extends State<MonthlySummaryTab> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year &&
        _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeeProvider>();
    final roster = provider.employees;
    final employee = widget.selectedEmployee;
    final monthFormat = DateFormat('MMMM yyyy', 'he');

    if (roster.isEmpty) {
      return const Center(child: Text(AppStrings.noEmployees));
    }
    if (employee == null) {
      return const Center(child: Text(AppStrings.selectEmployee));
    }

    final monthPay = provider.payForMonth(
      _selectedMonth,
      employeeId: employee.id,
    );
    final daySlices = provider.daySlicesForMonth(
      _selectedMonth,
      employeeId: employee.id,
    );

    return Column(
      children: [
        if (roster.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: DropdownButton<String>(
                value: employee.id,
                items: [
                  for (final item in roster)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        item.isActive
                            ? item.name
                            : '${item.name} (${AppStrings.inactiveEmployee})',
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) widget.onSelectEmployee(id);
                },
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _selectedMonth = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month - 1,
                  );
                }),
              ),
              Text(
                monthFormat.format(_selectedMonth),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _isCurrentMonth
                    ? null
                    : () => setState(() {
                          _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month + 1,
                          );
                        }),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              _MonthTotalsCard(pay: monthPay),
              const SizedBox(height: 16),
              if (daySlices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(AppStrings.noShiftsThisMonth)),
                )
              else
                ...daySlices.map((slice) {
                  final shifts = provider.shiftsOverlappingDay(
                    slice.day,
                    employeeId: employee.id,
                  );
                  return _DayExpansionTile(
                    slice: slice,
                    shiftCount: shifts.length,
                    children: [
                      for (final shift in shifts)
                        ListTile(
                          title: Text(_shiftHoursLabel(shift.startAt, shift.endAt)),
                          subtitle: Text(
                            formatDurationMinutes(
                              provider
                                  .payForShiftOnDay(shift, slice.day)
                                  .totalMinutes,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₪${formatMoney(provider.payForShiftOnDay(shift, slice.day).totalPay)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                tooltip: AppStrings.deleteShift,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                ),
                                onPressed: () =>
                                    ShiftEditSheet.confirmAndDelete(
                                  context,
                                  shiftId: shift.id,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => ShiftEditSheet.show(
                            context,
                            employee: employee,
                            shift: shift,
                          ),
                        ),
                    ],
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  String _shiftHoursLabel(DateTime start, DateTime? end) {
    final format = DateFormat('HH:mm', 'he');
    final endLabel = end == null ? AppStrings.openShift : format.format(end);
    return '${format.format(start)} – $endLabel';
  }
}

class _MonthTotalsCard extends StatelessWidget {
  final ShiftPayBreakdown pay;

  const _MonthTotalsCard({required this.pay});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _stat(
              AppStrings.regularHours,
              formatDurationMinutes(pay.regularMinutes),
            ),
            const SizedBox(height: 8),
            _stat(
              AppStrings.shabbatHours,
              formatDurationMinutes(pay.premiumMinutes),
            ),
            const SizedBox(height: 8),
            _stat(
              AppStrings.totalHours,
              formatDurationMinutes(pay.totalMinutes),
            ),
            const Divider(height: 24),
            _stat(
              AppStrings.totalPay,
              '₪${formatMoney(pay.totalPay)}',
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {bool emphasize = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? null : AppColors.textSecondary,
              fontWeight: emphasize ? FontWeight.bold : null,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: emphasize ? 20 : 16,
            color: emphasize ? AppColors.primary : null,
          ),
        ),
      ],
    );
  }
}

class _DayExpansionTile extends StatelessWidget {
  final ShiftDaySlice slice;
  final int shiftCount;
  final List<Widget> children;

  const _DayExpansionTile({
    required this.slice,
    required this.shiftCount,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat("EEEE d.MM.yyyy", 'he').format(slice.day);
    return Card(
      child: ExpansionTile(
        title: Text(
          '$label · $shiftCount ${AppStrings.shiftsCount}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${formatDurationMinutes(slice.pay.totalMinutes)} · ₪${formatMoney(slice.pay.totalPay)}',
        ),
        children: children,
      ),
    );
  }
}
