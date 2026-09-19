import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_paths.dart';
import '../models/employee_model.dart';
import '../models/shift_model.dart';

class EmployeeService {
  final _employees =
      FirebaseFirestore.instance.collection(FirestorePaths.employees);
  final _shifts = FirebaseFirestore.instance.collection(FirestorePaths.shifts);

  Stream<List<Employee>> watchEmployees() {
    return _employees.orderBy('name').snapshots().map(
          (snap) => snap.docs.map(Employee.fromFirestore).toList(),
        );
  }

  Future<String> addEmployee(Employee employee) async {
    final doc = await _employees.add(employee.toMap());
    return doc.id;
  }

  Future<void> updateEmployee(Employee employee) {
    return _employees.doc(employee.id).update(employee.toMap());
  }

  Future<void> deleteEmployee(String id) => _employees.doc(id).delete();

  Stream<List<Shift>> watchShifts() {
    return _shifts.orderBy('startAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(Shift.fromFirestore).toList(),
        );
  }

  Future<String> addShift(Shift shift) async {
    final doc = await _shifts.add(shift.toMap());
    return doc.id;
  }

  Future<void> updateShift(Shift shift) {
    return _shifts.doc(shift.id).update(shift.toMap());
  }

  Future<void> deleteShift(String id) => _shifts.doc(id).delete();

  Future<bool> employeeHasShifts(String employeeId) async {
    final snap = await _shifts
        .where('employeeId', isEqualTo: employeeId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
