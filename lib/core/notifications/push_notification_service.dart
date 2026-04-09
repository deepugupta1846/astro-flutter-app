import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/user_api.dart';
import '../session/app_session.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'astro_pulse_messages',
    'Messages and Calls',
    description: 'Chat and incoming call alerts',
    importance: Importance.high,
  );

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _local.initialize(settings: initSettings);

    FirebaseMessaging.onMessage.listen((m) async {
      final n = m.notification;
      if (n == null) return;
      await _local.show(
        id: n.hashCode,
        title: n.title,
        body: n.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'astro_pulse_messages',
            'Messages and Calls',
            channelDescription: 'Chat and incoming call alerts',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _syncTokenToBackend(token);
    });
    _ready = true;
  }

  static Future<void> syncTokenWithBackend() async {
    if (!_ready) await init();
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _syncTokenToBackend(token);
  }

  static Future<void> _syncTokenToBackend(String token) async {
    final uid = AppSession.userId;
    if (uid == null) return;
    try {
      await UserApi.updatePushToken(
        userId: uid,
        token: token,
        platform: _platform(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Push token sync failed: $e');
      }
    }
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}
