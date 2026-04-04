import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AstrologerApi {
  static String get _base => '$apiBaseUrl$apiAstrologerPath';

  /// GET all active astrologers (public fields only).
  static Future<Map<String, dynamic>> list() async {
    final res = await http.get(
      Uri.parse(_base),
      headers: {'Content-Type': 'application/json'},
    );
    return _parse(res);
  }

  /// Full registration after OTP (updates user + creates astrologer).
  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> body,
  ) async {
    final res = await http.post(
      Uri.parse('$_base/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Map<String, dynamic> _parse(http.Response res) {
    final code = res.statusCode;
    if (res.body.isEmpty) {
      return {
        'success': false,
        'message': 'Empty response from server ($code)',
        '_statusCode': code,
      };
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        return {
          'success': false,
          'message': 'Unexpected response format ($code)',
          '_statusCode': code,
        };
      }
      final map = Map<String, dynamic>.from(decoded);
      map['_statusCode'] = code;
      return map;
    } on FormatException catch (e) {
      // Often HTML error pages (wrong URL, nginx, CORS proxy).
      return {
        'success': false,
        'message':
            'Could not read astrologer list ($code). Check API base URL matches your server.',
        '_statusCode': code,
        '_parseError': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network or parse error: $e',
        '_statusCode': code,
      };
    }
  }
}
