import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_paths.dart';
import '../models/dog_contract.dart';
import '../models/dog_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _dogs =>
      _db.collection(FirestorePaths.dogs);

  Stream<List<Dog>> watchDogs() {
    return _dogs
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Dog.fromFirestore).toList());
  }

  Future<String> addDog(Dog dog) async {
    final doc = await _dogs.add(dog.toMap());
    return doc.id;
  }

  Future<void> updateDog(Dog dog) {
    return _dogs.doc(dog.id).update(dog.toMap());
  }

  Future<void> deleteDog(String dogId) {
    return _dogs.doc(dogId).delete();
  }

  /// Appends a photo to the valid yearly contract. A missing or expired
  /// contract, or [startNew], archives the current one and starts a new year.
  Future<void> saveDogContractPhoto({
    required Dog dog,
    required String photoUrl,
    required bool startNew,
  }) {
    final current = dog.contract;
    final now = DateTime.now();
    final appendToCurrent =
        !startNew && current != null && current.isValidOn(now);

    if (appendToCurrent) {
      return _dogs.doc(dog.id).update({
        'contract.photoUrls': FieldValue.arrayUnion([photoUrl]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final payload = <String, dynamic>{
      'contract': DogContract(photoUrls: [photoUrl], uploadedAt: now).toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (current != null && current.photoUrls.isNotEmpty) {
      payload['previousContracts'] = FieldValue.arrayUnion([current.toMap()]);
    }
    return _dogs.doc(dog.id).update(payload);
  }

  Future<void> removeDogContractPhoto({
    required Dog dog,
    required String photoUrl,
  }) {
    final current = dog.contract;
    if (current == null) return Future.value();
    final remaining =
        current.photoUrls.where((url) => url != photoUrl).toList();
    if (remaining.isEmpty) {
      return _dogs.doc(dog.id).update({
        'contract': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return _dogs.doc(dog.id).update({
      'contract': DogContract(
        photoUrls: remaining,
        uploadedAt: current.uploadedAt,
      ).toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
