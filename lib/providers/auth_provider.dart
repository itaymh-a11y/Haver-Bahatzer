import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_strings.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.unknown;
  bool _isLoading = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider(this._authService) {
    _authService.authStateChanges.listen((user) {
      _status =
          user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
      notifyListeners();
      unawaited(_syncNotifications(user));
    });
  }

  Future<void> _syncNotifications(User? user) async {
    if (kIsWeb) return;
    if (user != null) {
      await NotificationService.instance.registerForUser(user.uid);
    } else {
      await NotificationService.instance.unregister();
    }
  }

  Future<void> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signInWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e.code);
    } catch (_) {
      _errorMessage = AppStrings.authErrorGeneral;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return AppStrings.authErrorWrongPassword;
      case 'user-not-found':
        return AppStrings.authErrorUserNotFound;
      case 'invalid-email':
        return AppStrings.authErrorInvalidEmail;
      case 'too-many-requests':
        return AppStrings.authErrorTooManyRequests;
      case 'network-request-failed':
        return AppStrings.authErrorNetworkFailed;
      default:
        return AppStrings.authErrorGeneral;
    }
  }
}
