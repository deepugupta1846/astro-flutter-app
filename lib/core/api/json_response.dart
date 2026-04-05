import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_log.dart';

/// Decodes API JSON; never throws. HTML/error pages become [success]: false.
Map<String, dynamic> parseHttpJsonResponse(http.Response res) {
  final code = res.statusCode;
  final trimmed = res.body.trim();
  if (trimmed.isEmpty) {
    logAstroApiError(
      label: 'empty_body',
      response: res,
      message: 'Empty response from server',
    );
    return {
      'success': false,
      'message': 'Empty response from server',
      '_statusCode': code,
    };
  }
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('<!doctype') || lower.startsWith('<html')) {
    logAstroApiError(
      label: 'html_not_json',
      response: res,
      message: 'Server returned HTML instead of JSON (wrong URL / proxy / 404?)',
    );
    return {
      'success': false,
      'message':
          'Server returned a web page instead of JSON (often wrong API URL or 404). '
          'Check base URL and that consultation routes are deployed.',
      '_statusCode': code,
    };
  }
  try {
    final decoded = jsonDecode(trimmed);
    final map = Map<String, dynamic>.from(
      decoded is Map ? decoded : <String, dynamic>{},
    );
    map['_statusCode'] = code;
    final httpOk = code >= 200 && code < 300;
    final apiOk = map['success'] != false;
    if (!httpOk || !apiOk) {
      logAstroApiError(
        label: !httpOk ? 'http_error' : 'api_success_false',
        response: res,
        message: map['message']?.toString() ??
            (!httpOk ? 'Non-success HTTP status' : 'success is false'),
      );
    }
    return map;
  } on FormatException catch (e, st) {
    logAstroApiError(
      label: 'invalid_json',
      response: res,
      message: 'FormatException: ${e.message}',
      error: e,
      stackTrace: st,
    );
    return {
      'success': false,
      'message': 'Invalid JSON from server ($code). Check API URL and backend.',
      '_statusCode': code,
    };
  }
}
