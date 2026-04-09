import 'package:flutter/material.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/session/app_session.dart';
import '../../core/session/dashboard_mode_store.dart';
import 'astrologer_main_shell.dart';
import 'user_main_shell.dart';

/// Routes logged-in users to the customer shell or partner shell. Astrologers
/// can switch surfaces; regular users always see [UserMainShell].
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// Match [DashboardModeStore.getSurface] before prefs load: astrologers default
  /// to partner home; everyone else to the user app.
  late AppDashboardSurface _surface = AppSession.isAstrologer
      ? AppDashboardSurface.astrologer
      : AppDashboardSurface.user;

  @override
  void initState() {
    super.initState();
    _restoreSurface();
    PushNotificationService.syncTokenWithBackend();
  }

  Future<void> _restoreSurface() async {
    if (!AppSession.isAstrologer) return;
    final s = await DashboardModeStore.getSurface();
    if (!mounted) return;
    setState(() => _surface = s);
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAstrologer) {
      return const UserMainShell();
    }

    return _surface == AppDashboardSurface.astrologer
        ? AstrologerMainShell(
            onSwitchToUserApp: () async {
              await DashboardModeStore.setSurface(AppDashboardSurface.user);
              if (mounted) {
                setState(() => _surface = AppDashboardSurface.user);
              }
            },
          )
        : UserMainShell(
            onSwitchToAstrologerApp: () async {
              await DashboardModeStore.setSurface(
                AppDashboardSurface.astrologer,
              );
              if (mounted) {
                setState(() => _surface = AppDashboardSurface.astrologer);
              }
            },
          );
  }
}
