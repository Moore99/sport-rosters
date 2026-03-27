import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/router/app_router.dart';
import 'core/services/biometric_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'firebase_options.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    MobileAds.instance.initialize(),
  ]);

  // ── App Check ──────────────────────────────────────────────────────────────
  // Debug provider in debug mode; Play Integrity / DeviceCheck in release.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );

  FlutterNativeSplash.remove();

  // ── Crashlytics ────────────────────────────────────────────────────────────
  // Disable in debug so crash reports don't pollute the console.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  // Catch Flutter framework errors
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Catch async errors outside Flutter framework (platform channels, isolates)
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(
    const ProviderScope(child: SportsRosteringApp()),
  );
}

class SportsRosteringApp extends ConsumerStatefulWidget {
  const SportsRosteringApp({super.key});

  @override
  ConsumerState<SportsRosteringApp> createState() => _SportsRosteringAppState();
}

class _SportsRosteringAppState extends ConsumerState<SportsRosteringApp>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final bg = _backgroundedAt;
      if (bg != null && DateTime.now().difference(bg).inSeconds > 30) {
        _tryLock();
      }
    }
  }

  Future<void> _tryLock() async {
    final service = ref.read(biometricServiceProvider);
    final enabled = await service.isEnabled();
    if (!enabled) return;
    final available = await service.isAvailable();
    if (available) ref.read(biometricLockProvider.notifier).lock();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationInitProvider); // initializes FCM when user signs in
    final router    = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Sport Rosters',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
