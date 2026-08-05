import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles FCM permission, token persistence, and foreground display.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _staffTopic = 'staff';
  static const _androidChannelId = 'haver_bahatzer_default';
  static const _androidChannelName = 'התראות כלליות';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _initialized = false;
  String? _registeredUserId;
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        importance: Importance.high,
      ),
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  /// Request permission, save FCM token, subscribe to staff topic.
  Future<void> registerForUser(String userId) async {
    if (kIsWeb) return;
    await initialize();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Notification permission denied');
      return;
    }

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(userId: userId, token: token);
      debugPrint('FCM token: $token');
    }

    await _messaging.subscribeToTopic(_staffTopic);
    _registeredUserId = userId;

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? _registeredUserId;
      if (uid == null) return;
      await _saveToken(userId: uid, token: newToken);
      debugPrint('FCM token refreshed: $newToken');
    });
  }

  Future<void> unregister() async {
    if (kIsWeb) return;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _registeredUserId = null;
    try {
      await _messaging.unsubscribeFromTopic(_staffTopic);
    } catch (_) {}
  }

  Future<void> _saveToken({
    required String userId,
    required String token,
  }) async {
    final docId = token.replaceAll('/', '_');
    await _firestore.collection('fcmTokens').doc(docId).set({
      'token': token,
      'userId': userId,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background/terminated display is handled by the OS for notification payloads.
}
