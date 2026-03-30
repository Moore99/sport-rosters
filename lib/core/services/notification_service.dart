import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/user_repository.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

// ── Pending navigation state for spare response ───────────────────────────────
class PendingNavigation {
  final String? eventId;
  final String? teamId;
  const PendingNavigation({this.eventId, this.teamId});
}

final pendingSpareNavigationProvider = StateProvider<PendingNavigation>(
  (ref) => const PendingNavigation(),
);

// ── Background message handler — must be top-level ───────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised when this runs.
  // Background/terminated notifications are shown automatically by FCM.
}

// ── Local notification channel (Android 8+) ──────────────────────────────────
const _channel = AndroidNotificationChannel(
  'team_notifications',
  'Team Notifications',
  description: 'Notifications from your teams and coaches.',
  importance: Importance.high,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

class NotificationService {
  final Ref _ref;
  NotificationService(this._ref);

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS + Android 13+)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!granted) return;

    // iOS: present notifications while app is in foreground
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android: create the notification channel and init local notifications
    // so foreground FCM messages can be shown as heads-up notifications.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Save token to Firestore so we can send targeted pushes
    await _saveFcmToken();
    messaging.onTokenRefresh.listen(_onTokenRefresh);

    // Handle when user taps a notification (including background/terminated)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      _handleNotificationTap(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Show foreground messages as local heads-up notifications (Android).
    // iOS handles this natively via setForegroundNotificationPresentationOptions.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });
  }

  void _handleNotificationTap(RemoteMessage? message) {
    if (message == null) return;
    final data = message.data;
    if (data['type'] == 'spareNeeded') {
      final eventId = data['eventId'];
      final teamId = data['teamId'];
      if (eventId != null && teamId != null) {
        _ref.read(pendingSpareNavigationProvider.notifier).state =
            PendingNavigation(
          eventId: eventId,
          teamId: teamId,
        );
      }
    }
  }

  Future<void> _saveFcmToken() async {
    final uid = _ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _ref.read(userRepositoryProvider).updateFcmToken(uid, token);
  }

  void _onTokenRefresh(String token) {
    final uid = _ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    _ref.read(userRepositoryProvider).updateFcmToken(uid, token);
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref),
);
