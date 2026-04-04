import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'json_response.dart';

class UserApi {
  static String get _base => '$apiBaseUrl$apiUserPath';

  static Future<Map<String, dynamic>> getUser(int id) async {
    final res = await http.get(
      Uri.parse('$_base/$id'),
      headers: {'Content-Type': 'application/json'},
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateUser(
    int id,
    Map<String, dynamic> body,
  ) async {
    final res = await http.put(
      Uri.parse('$_base/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> sendOtp({
    required String phone,
    String countryCode = '+91',
  }) async {
    final res = await http.post(
      Uri.parse('$_base/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'countryCode': countryCode}),
    );
    return _parse(res);
  }

  /// Verifies 6-digit OTP from server (SMS flow) or server `MASTER_OTP`.
  /// [signupIntent] e.g. `'astrologer'` sets user role to astrologer after verify.
  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String countryCode = '+91',
    String? signupIntent,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'countryCode': countryCode,
      'otp': otp,
    };
    if (signupIntent != null && signupIntent.isNotEmpty) {
      body['signupIntent'] = signupIntent;
    }
    final res = await http.post(
      Uri.parse('$_base/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> signup({
    required String phone,
    String countryCode = '+91',
    String? name,
    String? gender,
    bool? knowBirthTime,
    String? birthTime,
    String? birthDate,
    String? birthPlace,
    List<String>? languages,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'countryCode': countryCode,
    };
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (gender != null && gender.isNotEmpty) body['gender'] = gender;
    if (knowBirthTime != null) body['knowBirthTime'] = knowBirthTime;
    if (birthTime != null && birthTime.isNotEmpty) body['birthTime'] = birthTime;
    if (birthDate != null && birthDate.isNotEmpty) body['birthDate'] = birthDate;
    if (birthPlace != null && birthPlace.isNotEmpty) body['birthPlace'] = birthPlace;
    if (languages != null && languages.isNotEmpty) body['languages'] = languages;

    final res = await http.post(
      Uri.parse('$_base/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Map<String, dynamic> _parse(http.Response res) =>
      parseHttpJsonResponse(res);
}
