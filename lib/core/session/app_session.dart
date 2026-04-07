import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Logged-in user from API (`verify-otp` / `signup`). Persisted for drawer & profile.
class AppSession {
  AppSession._();

  static const _keyUser = 'auth_user_json';
  static Map<String, dynamic>? _user;

  static Map<String, dynamic>? get user => _user;

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_keyUser);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _user = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        _user = null;
      }
    }
  }

  /// Call with API `data.user` map from verify-otp or signup.
  static Future<void> setUser(Map<String, dynamic>? raw) async {
    if (raw == null) {
      await clear();
      return;
    }
    _user = Map<String, dynamic>.from(raw);
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyUser, jsonEncode(_user));
  }

  static Future<void> clear() async {
    _user = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyUser);
  }

  static int? get userId {
    final id = _user?['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return null;
  }

  static String get displayName {
    final n = _user?['name']?.toString().trim();
    if (n != null && n.isNotEmpty) return n;
    return 'User';
  }

  /// First word of [name] for greetings (e.g. "Hi Deepu"). Falls back to "User" if no name.
  static String get firstName {
    final n = _user?['name']?.toString().trim();
    if (n == null || n.isEmpty) return 'User';
    final parts = n.split(RegExp(r'\s+'));
    final first = parts.first;
    if (first.isEmpty) return 'User';
    return first[0].toUpperCase() + (first.length > 1 ? first.substring(1) : '');
  }

  static String get phoneLine {
    if (_user == null) return '';
    final cc = _user!['countryCode']?.toString() ?? '+91';
    final ph = _user!['phone']?.toString() ?? '';
    return '$cc $ph'.trim();
  }

  static bool get isLoggedIn => userId != null;

  /// Wallet balance in rupees from persisted [user] (e.g. login/profile API).
  /// Tries `walletBalance`, `wallet_balance`, `balance`, `wallet`.
  static double get walletBalance {
    final u = _user;
    if (u == null) return 0;
    for (final key in [
      'walletBalance',
      'wallet_balance',
      'balance',
      'wallet',
    ]) {
      final v = u[key];
      if (v == null) continue;
      if (v is num) return v.toDouble();
      final p = double.tryParse(v.toString().trim());
      if (p != null) return p;
    }
    return 0;
  }

  /// Backend [User.role] — `'astrologer'` for registered astrologers.
  static bool get isAstrologer {
    final r = _user?['role']?.toString().toLowerCase().trim();
    return r == 'astrologer';
  }
}

