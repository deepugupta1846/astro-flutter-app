import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

const int _kBodyMax = 500;

/// Logs API problems to **logcat** / Flutter console (`adb logcat | findstr AstroApi`).
void logAstroApiError({
  required String label,
  http.Response? response,
  String? message,
  Object? error,
  StackTrace? stackTrace,
  bool logBody = true,
}) {
  final uri = response?.request?.url.toString() ?? '(no URL)';
  final code = response != null ? '${response.statusCode}' : '-';
  final buf = StringBuffer('AstroApi | $label | $uri | HTTP $code');
  if (message != null && message.isNotEmpty) {
    buf.write(' | ');
    buf.write(message);
  }
  developer.log(
    buf.toString(),
    name: 'AstroApi',
    error: error,
    stackTrace: stackTrace,
  );
  if (logBody && response != null) {
    final t = response.body.trim();
    if (t.isNotEmpty) {
      developer.log(
        t.length > _kBodyMax
            ? '${t.substring(0, _kBodyMax)}… (${t.length} chars)'
            : t,
        name: 'AstroApi',
      );
    }
  }
}
