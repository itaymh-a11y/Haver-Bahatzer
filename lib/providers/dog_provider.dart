import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/dog_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../core/utils/image_utils.dart';

class DogProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final StorageService _storageService;

  List<Dog> _dogs = [];
  String _searchQuery = '';
  Set<String> _activeTagFilters = {}; // tag IDs
  bool _isLoading = false;
  String? _errorMessage;
  bool _isListening = false;

  List<Dog> get dogs => _dogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  Set<String> get activeTagFilters => _activeTagFilters;

  List<Dog> get filteredDogs {
    var result = _dogs;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((d) {
        return d.name.toLowerCase().contains(q) ||
            d.ownerName.toLowerCase().contains(q);
      }).toList();
    }

    if (_activeTagFilters.isNotEmpty) {
      result = result.where((d) {
        return _activeTagFilters.every((tagId) => d.tags.contains(tagId));
      }).toList();
    }

    return result;
  }

  DogProvider(this._firestoreService, this._storageService);

  void startListening() {
    if (_isListening) return;
    _isListening = true;

    _firestoreService.watchDogs().listen(
      (dogs) {
        _dogs = dogs;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleTagFilter(String tagId) {
    if (_activeTagFilters.contains(tagId)) {
      _activeTagFilters = Set.from(_activeTagFilters)..remove(tagId);
    } else {
      _activeTagFilters = Set.from(_activeTagFilters)..add(tagId);
    }
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _activeTagFilters = {};
    notifyListeners();
  }

  Future<void> addDog({required Dog dog, File? photoFile}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final dogId = await _firestoreService.addDog(dog);

      if (photoFile != null) {
        final bytes = await ImageUtils.compressImageToBytes(photoFile) ??
            await photoFile.readAsBytes();
        final photoUrl = await _storageService.uploadDogPhoto(dogId, bytes);
        final updatedDog = dog.copyWith(id: dogId, photoUrl: photoUrl);
        await _firestoreService.updateDog(updatedDog);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDog({required Dog dog, File? photoFile}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Dog updatedDog = dog.copyWith(updatedAt: DateTime.now());

      if (photoFile != null) {
        final bytes = await ImageUtils.compressImageToBytes(photoFile) ??
            await photoFile.readAsBytes();
        final photoUrl = await _storageService.uploadDogPhoto(dog.id, bytes);
        updatedDog = updatedDog.copyWith(photoUrl: photoUrl);
      }

      await _firestoreService.updateDog(updatedDog);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadContractPhoto({
    required String dogId,
    required File imageFile,
    required bool startNew,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final dog = _dogById(dogId);
      if (dog == null) {
        _errorMessage = 'הכלב לא נמצא';
      } else {
        final bytes = await ImageUtils.compressImageToBytes(imageFile) ??
            await imageFile.readAsBytes();
        final url = await _storageService.uploadContractPhoto(dogId, bytes);
        await _firestoreService.saveDogContractPhoto(
          dog: dog,
          photoUrl: url,
          startNew: startNew,
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> removeContractPhoto({
    required String dogId,
    required String photoUrl,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final dog = _dogById(dogId);
      if (dog == null) {
        _errorMessage = 'הכלב לא נמצא';
      } else {
        await _firestoreService.removeDogContractPhoto(
          dog: dog,
          photoUrl: photoUrl,
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteDog(String dogId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.deleteDog(dogId);
      await _storageService.deleteDogPhoto(dogId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Dog? _dogById(String dogId) {
    final index = _dogs.indexWhere((dog) => dog.id == dogId);
    if (index == -1) return null;
    return _dogs[index];
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
