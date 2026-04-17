import 'consultation_incoming_call.dart';

typedef AcceptSameSessionCallback = Future<void> Function(
  IncomingCallInvite invite,
);

/// When [ConsultationRoomScreen] is open for [sessionId], it registers here so
/// the global incoming overlay can join the call without pushing a second route.
class ConsultationRoomAcceptBridge {
  ConsultationRoomAcceptBridge._();

  static int? _openSessionId;
  static AcceptSameSessionCallback? _onAcceptSameSession;

  static void registerOpenSession(int sessionId, AcceptSameSessionCallback onAccept) {
    _openSessionId = sessionId;
    _onAcceptSameSession = onAccept;
  }

  static void unregister(int sessionId) {
    if (_openSessionId == sessionId) {
      _openSessionId = null;
      _onAcceptSameSession = null;
    }
  }

  /// Returns true if the active chat consumed Accept (same session).
  static Future<bool> deliverAcceptIfSameSession(IncomingCallInvite invite) async {
    if (_openSessionId != invite.sessionId || _onAcceptSameSession == null) {
      return false;
    }
    await _onAcceptSameSession!(invite);
    return true;
  }
}
