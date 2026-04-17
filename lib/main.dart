import 'dart:async';

import 'package:flutter/material.dart';
import 'core/api/api_config.dart';
import 'core/navigation/app_navigator.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/session/app_session.dart';
import 'core/call/incoming_call_overlay_host.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/details/details_flow_screen.dart';
import 'screens/dashboard/main_shell.dart';
import 'screens/profile/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Session is local + fast; needed before splash decides login vs dashboard.
  await AppSession.init();
  await PushNotificationService.init();
  unawaited(PushNotificationService.syncTokenWithBackend());
  // Never block first frame on device_info / network; splash can show immediately.
  unawaited(initDevApiBaseUrl());
  runApp(const AstroLogerApp());
}

class AstroLogerApp extends StatelessWidget {
  const AstroLogerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'AstroLoger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            const IncomingCallOverlayHost(),
          ],
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/details': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
          return DetailsFlowScreen(
            phone: args?['phone'] ?? '',
            countryCode: args?['countryCode'] ?? '+91',
          );
        },
        '/dashboard': (context) => const MainShell(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
