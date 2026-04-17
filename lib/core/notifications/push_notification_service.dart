import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/user_api.dart';
import '../call/incoming_call_coordinator.dart';
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
    description: 'Chat and incoming voice call alerts',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _videoCallChannel =
      AndroidNotificationChannel(
    'astro_pulse_video_calls',
    'Video calls',
    description: 'Incoming video call alerts',
    importance: Importance.max,
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

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.createNotificationChannel(_videoCallChannel);
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _local.initialize(settings: initSettings);

    FirebaseMessaging.onMessage.listen((m) async {
      final dataMap = Map<String, dynamic>.from(m.data);
      _dispatchIncomingCallFromPayload(dataMap);
      final n = m.notification;
      final isVideoIncoming = _isIncomingVideoCall(dataMap);
      if (n != null) {
        await _local.show(
          id: n.hashCode,
          title: n.title,
          body: n.body,
          notificationDetails: NotificationDetails(
            android: _androidDetailsForIncoming(isVideoIncoming),
          ),
        );
      } else if (dataMap['type']?.toString() == 'incoming_call') {
        await _local.show(
          id: m.messageId?.hashCode ?? dataMap.hashCode,
          title: isVideoIncoming ? 'Incoming video call' : 'Incoming call',
          body: isVideoIncoming
              ? 'Open the app to answer with camera'
              : 'Open the app to answer',
          notificationDetails: NotificationDetails(
            android: _androidDetailsForIncoming(isVideoIncoming),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      _dispatchIncomingCallFromPayload(m.data);
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dispatchIncomingCallFromPayload(initial.data);
      });
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _syncTokenToBackend(token);
    });
    _ready = true;
  }

  static Future<void> syncTokenWithBackend() async {
    if (!_ready) await init();
    if (Platform.isAndroid) {
      final st = await Permission.notification.request();
      if (!st.isGranted) {
        if (kDebugMode) {
          debugPrint('Push: notification permission not granted');
        }
        return;
      }
    }
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

  static void _dispatchIncomingCallFromPayload(Map<String, dynamic> data) {
    if (data['type']?.toString() != 'incoming_call') return;
    IncomingCallCoordinator.instance.handleRawPayload(
      Map<String, dynamic>.from(data),
    );
  }

  static bool _isIncomingVideoCall(Map<String, dynamic> data) {
    if (data['type']?.toString() != 'incoming_call') return false;
    final ct = data['callType']?.toString().toLowerCase() ?? '';
    return ct == 'video';
  }

  static AndroidNotificationDetails _androidDetailsForIncoming(bool video) {
    if (video) {
      return const AndroidNotificationDetails(
        'astro_pulse_video_calls',
        'Video calls',
        channelDescription: 'Incoming video call alerts',
        importance: Importance.max,
        priority: Priority.high,
      );
    }
    return const AndroidNotificationDetails(
      'astro_pulse_messages',
      'Messages and Calls',
      channelDescription: 'Chat and incoming voice call alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}
