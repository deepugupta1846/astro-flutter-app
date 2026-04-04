import 'package:shared_preferences/shared_preferences.dart';

import 'app_session.dart';

/// Which primary dashboard surface to show for users who can be astrologers.
enum AppDashboardSurface {
  user,
  astrologer,
}

class DashboardModeStore {
  DashboardModeStore._();

  static const _key = 'app_dashboard_surface';

  /// Resolves which shell to open. If nothing was saved yet and
  /// [AppSession.isAstrologer] is true, defaults to [AppDashboardSurface.astrologer]
  /// so `role == 'astrologer'` opens the partner dashboard first; the user app
  /// remains available via drawer / switch.
  static Future<AppDashboardSurface> getSurface() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key);
    if (v == null) {
      if (AppSession.isAstrologer) {
        return AppDashboardSurface.astrologer;
      }
      return AppDashboardSurface.user;
    }
    if (v == AppDashboardSurface.astrologer.name) {
      return AppDashboardSurface.astrologer;
    }
    return AppDashboardSurface.user;
  }

  static Future<void> setSurface(AppDashboardSurface surface) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, surface.name);
  }

  /// Call on logout so the next login does not reuse partner vs user choice.
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
