import 'dart:convert';

import 'package:http/http.dart' as http;

/// Decodes API JSON; never throws. HTML/error pages become [success]: false.
Map<String, dynamic> parseHttpJsonResponse(http.Response res) {
  final code = res.statusCode;
  final trimmed = res.body.trim();
  if (trimmed.isEmpty) {
    return {
      'success': false,
      'message': 'Empty response from server',
      '_statusCode': code,
    };
  }
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('<!doctype') || lower.startsWith('<html')) {
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
    return map;
  } on FormatException {
    return {
      'success': false,
      'message': 'Invalid JSON from server ($code). Check API URL and backend.',
      '_statusCode': code,
    };
  }
}
