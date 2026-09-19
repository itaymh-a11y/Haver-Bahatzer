import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/money_format.dart';
import '../../models/employee_model.dart';
import '../../providers/employee_provider.dart';
import 'employee_form_screen.dart';

class EmployeeListScreen extends StatelessWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final employees = context.watch<EmployeeProvider>().employees;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.manageEmployees)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
        ),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text(AppStrings.addEmployee),
      ),
      body: employees.isEmpty
          ? Center(
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
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: employees.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return _EmployeeTile(employee: employees[index]);
              },
            ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final Employee employee;

  const _EmployeeTile({required this.employee});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.chipBackground,
        child: Icon(
          Icons.person_outline,
          color: employee.isActive
              ? AppColors.primary
              : AppColors.textSecondary,
        ),
      ),
      title: Text(employee.name),
      subtitle: Text(
        '₪${formatMoney(employee.hourlyWage)} ${AppStrings.wagePerHour}',
      ),
      trailing: employee.isActive
          ? null
          : Chip(
              label: const Text(AppStrings.inactiveEmployee),
              visualDensity: VisualDensity.compact,
            ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmployeeFormScreen(employee: employee),
        ),
      ),
    );
  }
}
