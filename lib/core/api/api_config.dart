import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Production REST base **must** end with `/api` when backend mounts routes at `/api/v1/...`.
/// (Otherwise requests go to `https://host/v1/...` and fail; browser tests often use `/api/v1/...`.)
const String kBaseUrlProduction = 'https://api.astropulse.live/api';

/// Use production when:
/// - **Release** builds (always), or
/// - **Debug/profile** by default.
///
/// Local dev: `flutter run --dart-define=USE_LOCAL_API=true`
/// (then [initDevApiBaseUrl] picks emulator / LAN / `API_BASE_URL` as before).
bool get kUseProductionApi {
  if (kReleaseMode) return true;
  return !bool.fromEnvironment(
    'USE_LOCAL_API',
    defaultValue: false,
  );
}

/// Full override at compile time, e.g.
/// `--dart-define=API_BASE_URL=http://192.168.1.10:5000`
const String kApiBaseUrlFromEnvironment = String.fromEnvironment(
  'API_BASE_URL',
);

/// PC LAN hostname or IP only (no `http://`, no port), e.g. `192.168.1.10`
/// when testing on a **physical** phone over Wi‑Fi without USB reverse.
const String kDevLanHostFromEnvironment = String.fromEnvironment(
  'DEV_LAN_HOST',
);

const String kDevApiPortFromEnvironment = String.fromEnvironment(
  'DEV_API_PORT',
  defaultValue: '5000',
);

/// Resolved in [init] for dev builds; emulator vs phone picks a sane default.
String _devBaseUrl = 'http://10.0.2.2:$kDevApiPortFromEnvironment';

/// Call from `main()` before `runApp` (after `WidgetsFlutterBinding.ensureInitialized`).
///
/// Device lookups are time-bounded so a stuck plugin never blocks [runApp] (white /
/// native splash forever).
Future<void> initDevApiBaseUrl() async {
  if (kUseProductionApi) {
    if (kDebugMode) {
      debugPrint(
        'ApiConfig: production REST → $apiBaseUrl$apiUserPath (send-otp: $apiBaseUrl$apiUserPath/send-otp)',
      );
    }
    return;
  }

  if (kApiBaseUrlFromEnvironment.isNotEmpty) {
    _devBaseUrl = kApiBaseUrlFromEnvironment;
    return;
  }

  if (kIsWeb) {
    _devBaseUrl = 'http://localhost:$kDevApiPortFromEnvironment';
    return;
  }

  const pluginTimeout = Duration(seconds: 5);

  try {
    if (Platform.isAndroid) {
      final android = await DeviceInfoPlugin()
          .androidInfo
          .timeout(pluginTimeout);
      if (!android.isPhysicalDevice) {
        _devBaseUrl = 'http://10.0.2.2:$kDevApiPortFromEnvironment';
        return;
      }
      if (kDevLanHostFromEnvironment.isNotEmpty) {
        _devBaseUrl =
            'http://$kDevLanHostFromEnvironment:$kDevApiPortFromEnvironment';
        return;
      }
      _devBaseUrl = 'http://127.0.0.1:$kDevApiPortFromEnvironment';
      if (kDebugMode) {
        debugPrint(
          'ApiConfig: physical Android → $_devBaseUrl. '
          'If this fails over Wi‑Fi only, use '
          '--dart-define=DEV_LAN_HOST=<your_PC_LAN_IP> '
          'or connect USB and run: adb reverse tcp:$kDevApiPortFromEnvironment tcp:$kDevApiPortFromEnvironment',
        );
      }
      return;
    }

    if (Platform.isIOS) {
      final ios =
          await DeviceInfoPlugin().iosInfo.timeout(pluginTimeout);
      if (!ios.isPhysicalDevice) {
        _devBaseUrl = 'http://127.0.0.1:$kDevApiPortFromEnvironment';
        return;
      }
      if (kDevLanHostFromEnvironment.isNotEmpty) {
        _devBaseUrl =
            'http://$kDevLanHostFromEnvironment:$kDevApiPortFromEnvironment';
        return;
      }
      _devBaseUrl = 'http://127.0.0.1:$kDevApiPortFromEnvironment';
      if (kDebugMode) {
        debugPrint(
          'ApiConfig: physical iOS → $_devBaseUrl. Set DEV_LAN_HOST to your Mac LAN IP if needed.',
        );
      }
      return;
    }
  } on Object catch (e, st) {
    if (kDebugMode) {
      debugPrint('ApiConfig: device info failed ($e), using fallback dev URL.');
      debugPrint('$st');
    }
    _devBaseUrl = Platform.isAndroid
        ? 'http://10.0.2.2:$kDevApiPortFromEnvironment'
        : 'http://127.0.0.1:$kDevApiPortFromEnvironment';
    return;
  }

  _devBaseUrl = 'http://127.0.0.1:$kDevApiPortFromEnvironment';
}

/// Base URL for API calls.
String get apiBaseUrl =>
    kUseProductionApi ? kBaseUrlProduction : _devBaseUrl;

/// Socket.IO server URL (same host as REST; strip trailing `/api` if present).
String get socketUrl {
  final u = Uri.parse(apiBaseUrl);
  var path = u.path;
  if (path.endsWith('/api/')) {
    path = path.substring(0, path.length - 5);
  } else if (path.endsWith('/api')) {
    path = path.substring(0, path.length - 4);
  }
  path = path.replaceAll(RegExp(r'/+$'), '');
  return u.replace(path: path).toString().replaceAll(RegExp(r'/$'), '');
}

/// True when [apiBaseUrl] already ends with `/api` (production host or matching define).
bool get _apiBaseAlreadyHasApiPrefix {
  if (kUseProductionApi) return true;
  final e = kApiBaseUrlFromEnvironment.trim().toLowerCase();
  if (e.isEmpty) return false;
  final n = e.endsWith('/') ? e.substring(0, e.length - 1) : e;
  return n.endsWith('/api');
}

/// Dev server: `http://host:5000` + `/api/v1/...`. Production: `.../api` + `/v1/...`.
String get apiUserPath =>
    _apiBaseAlreadyHasApiPrefix ? '/v1/user' : '/api/v1/user';

/// Astrologer endpoints (same pattern as user).
String get apiAstrologerPath =>
    _apiBaseAlreadyHasApiPrefix ? '/v1/astrologer' : '/api/v1/astrologer';

/// Single image upload (multipart field: image).
String get apiUploadPath =>
    _apiBaseAlreadyHasApiPrefix ? '/v1/upload/image' : '/api/v1/upload/image';

/// Consultation (chat history, Agora tokens, call logs).
String get apiConsultationPath =>
    _apiBaseAlreadyHasApiPrefix ? '/v1/consultation' : '/api/v1/consultation';
