import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_paths.dart';
import '../models/vacation_model.dart';

class VacationService {
  final _col = FirebaseFirestore.instance.collection(FirestorePaths.vacations);

  Stream<List<VacationPeriod>> watchVacations() {
    return _col.orderBy('startDate', descending: false).snapshots().map(
          (snap) => snap.docs.map(VacationPeriod.fromFirestore).toList(),
        );
  }

  Future<String> addVacation(VacationPeriod vacation) async {
    final doc = await _col.add(vacation.toMap());
    return doc.id;
  }

  Future<void> updateVacation(VacationPeriod vacation) {
    return _col.doc(vacation.id).update(vacation.toMap());
  }

  Future<void> deleteVacation(String id) => _col.doc(id).delete();
}
