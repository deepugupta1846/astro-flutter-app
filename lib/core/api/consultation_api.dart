import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'json_response.dart';

/// Backend consultation + Agora token endpoints.
class ConsultationApi {
  static String get _base => '$apiBaseUrl$apiConsultationPath';

  static Future<Map<String, dynamic>> createOrGetSession({
    required int customerUserId,
    required int astrologerId,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'customerUserId': customerUserId,
        'astrologerId': astrologerId,
      }),
    );
    return _parse(res);
  }

  /// Sessions for a user. Omit [perspective] to include both customer and astrologer threads.
  /// [includeClosed]: when true, returns closed sessions too (full history).
  static Future<Map<String, dynamic>> listSessionsForParticipant({
    required int userId,
    String? perspective,
    bool includeClosed = false,
  }) async {
    final uri = Uri.parse('$_base/sessions/for-participant/$userId').replace(
      queryParameters: <String, String>{
        if (perspective != null && perspective.isNotEmpty) 'perspective': perspective,
        if (includeClosed) 'includeClosed': 'true',
      },
    );
    final res = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    return _parse(res);
  }

  /// Open an existing session (participant check on server).
  static Future<Map<String, dynamic>> getSessionSummary({
    required int sessionId,
    required int forUserId,
  }) async {
    final res = await http.get(
      Uri.parse(
        '$_base/sessions/$sessionId/summary?forUserId=$forUserId',
      ),
      headers: {'Content-Type': 'application/json'},
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> listMessages({
    required int sessionId,
    int limit = 50,
  }) async {
    final res = await http.get(
      Uri.parse('$_base/sessions/$sessionId/messages?limit=$limit'),
      headers: {'Content-Type': 'application/json'},
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> sendMessage({
    required int sessionId,
    required int senderUserId,
    required String body,
    String messageType = 'text',
  }) async {
    final res = await http.post(
      Uri.parse('$_base/sessions/$sessionId/messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'senderUserId': senderUserId,
        'body': body,
        'messageType': messageType,
      }),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> markConversationRead({
    required int sessionId,
    required int readerUserId,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/sessions/$sessionId/read'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'readerUserId': readerUserId}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> markMessagesDelivered({
    required int sessionId,
    required int readerUserId,
    required List<int> messageIds,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/sessions/$sessionId/messages/mark-delivered'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'readerUserId': readerUserId,
        'messageIds': messageIds,
      }),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> issueRtcToken({
    required String channelName,
    required int uid,
    int? sessionId,
  }) async {
    final body = <String, dynamic>{
      'channelName': channelName,
      'uid': uid,
    };
    if (sessionId != null) body['sessionId'] = sessionId;
    final res = await http.post(
      Uri.parse('$_base/agora/rtc-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> startCall({
    required int sessionId,
    required String callType,
    required int startedByUserId,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/sessions/$sessionId/call/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'callType': callType,
        'startedByUserId': startedByUserId,
      }),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> endCall({required int callLogId}) async {
    final res = await http.patch(
      Uri.parse('$_base/calls/$callLogId/end'),
      headers: {'Content-Type': 'application/json'},
    );
    return _parse(res);
  }

  /// Completed voice/video calls for [userId] (newest first). Requires DB column `duration_seconds`.
  static Future<Map<String, dynamic>> listCallHistory({
    required int userId,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$_base/calls/history/$userId').replace(
      queryParameters: <String, String>{
        'limit': '${limit.clamp(1, 100)}',
      },
    );
    final res = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    return _parse(res);
  }

  static Map<String, dynamic> _parse(http.Response res) =>
      parseHttpJsonResponse(res);
}
