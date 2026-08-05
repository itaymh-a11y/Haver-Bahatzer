import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_app_check/firebase_app_check.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/dog_provider.dart';
import 'providers/pension_provider.dart';
import 'providers/tag_provider.dart';
import 'providers/vacation_provider.dart';
import 'services/auth_service.dart';
import 'services/booking_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/pension_service.dart';
import 'services/tag_service.dart';
import 'services/vacation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // App Check on web needs a reCAPTCHA site key; mobile uses Play Integrity / App Attest.
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
    await NotificationService.instance.initialize();
  }

  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Seed the 3 built-in tags if the collection is empty
  final tagService = TagService();
  await tagService.seedInitialTags();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<BookingService>(create: (_) => BookingService()),
        Provider<TagService>(create: (_) => tagService),
        Provider<VacationService>(create: (_) => VacationService()),
        Provider<PensionService>(create: (_) => PensionService()),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<AuthService>()),
        ),
        ChangeNotifierProxyProvider<TagService, TagProvider>(
          create: (ctx) =>
              TagProvider(ctx.read<TagService>())..startListening(),
          update: (ctx, tagService, previous) =>
              previous ?? (TagProvider(tagService)..startListening()),
        ),
        ChangeNotifierProxyProvider2<FirestoreService, StorageService,
            DogProvider>(
          create: (ctx) => DogProvider(
            ctx.read<FirestoreService>(),
            ctx.read<StorageService>(),
          ),
          update: (ctx, firestoreService, storageService, previous) =>
              previous ?? DogProvider(firestoreService, storageService),
        ),
        ChangeNotifierProxyProvider2<BookingService, StorageService,
            BookingProvider>(
          create: (ctx) => BookingProvider(
            ctx.read<BookingService>(),
            ctx.read<StorageService>(),
          ),
          update: (ctx, service, storage, previous) =>
              previous ?? BookingProvider(service, storage),
        ),
        ChangeNotifierProxyProvider<VacationService, VacationProvider>(
          create: (ctx) =>
              VacationProvider(ctx.read<VacationService>())..startListening(),
          update: (ctx, service, previous) =>
              previous ?? (VacationProvider(service)..startListening()),
        ),
        ChangeNotifierProxyProvider2<PensionService, StorageService,
            PensionProvider>(
          create: (ctx) => PensionProvider(
            ctx.read<PensionService>(),
            ctx.read<StorageService>(),
          ),
          update: (ctx, service, storage, previous) =>
              previous ?? PensionProvider(service, storage),
        ),
      ],
      child: const HaverBahatzerApp(),
    ),
  );
}
