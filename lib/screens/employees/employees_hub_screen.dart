import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../models/employee_model.dart';
import '../../providers/employee_provider.dart';
import 'attendance_tab.dart';
import 'employee_form_screen.dart';
import 'employee_list_screen.dart';
import 'monthly_summary_tab.dart';
import 'shift_edit_sheet.dart';

class EmployeesHubScreen extends StatefulWidget {
  const EmployeesHubScreen({super.key});

  @override
  State<EmployeesHubScreen> createState() => _EmployeesHubScreenState();
}

class _EmployeesHubScreenState extends State<EmployeesHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().startListening();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Employee? _resolveFrom(List<Employee> pool) {
    if (pool.isEmpty) return null;
    final match = pool.where((e) => e.id == _selectedEmployeeId);
    if (match.isNotEmpty) return match.first;
    return pool.first;
  }

  Future<void> _onFabPressed() async {
    final provider = context.read<EmployeeProvider>();
    final isAttendance = _tabController.index == 0;
    if (!isAttendance) return;

    if (provider.activeEmployees.isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
      );
      return;
    }

    final employee = _resolveFrom(provider.activeEmployees);
    if (employee == null) {
      final goAdd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(AppStrings.noEmployees),
          content: const Text(AppStrings.addEmployeeFirst),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(AppStrings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(AppStrings.addEmployee),
            ),
          ],
        ),
      );
      if (goAdd == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
        );
      }
      return;
    }

    if (provider.openShiftFor(employee.id) != null) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(AppStrings.openShift),
          content: const Text(AppStrings.shiftAlreadyOpen),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.close),
            ),
          ],
        ),
      );
      return;
    }

    await ShiftEditSheet.show(context, employee: employee);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeeProvider>();
    final attendanceEmployee = _resolveFrom(provider.activeEmployees);
    final monthlyEmployee = _resolveFrom(
      provider.employees.isNotEmpty
          ? provider.employees
          : provider.activeEmployees,
    );
    final isAttendance = _tabController.index == 0;
    final hasEmployees = provider.activeEmployees.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.employees),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: AppStrings.manageEmployees,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployeeListScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: AppStrings.attendance,
              icon: Icon(Icons.timer_outlined),
            ),
            Tab(
              text: AppStrings.monthlySummary,
              icon: Icon(Icons.calendar_month_outlined),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AttendanceTab(
            selectedEmployee: attendanceEmployee,
            onSelectEmployee: (id) => setState(() => _selectedEmployeeId = id),
          ),
          MonthlySummaryTab(
            selectedEmployee: monthlyEmployee,
            onSelectEmployee: (id) => setState(() => _selectedEmployeeId = id),
          ),
        ],
      ),
      floatingActionButton: isAttendance
          ? FloatingActionButton.extended(
              onPressed: _onFabPressed,
              icon: Icon(hasEmployees ? Icons.add : Icons.person_add_outlined),
              label: Text(
                hasEmployees ? AppStrings.addShift : AppStrings.addEmployee,
              ),
            )
          : null,
    );
  }
}
