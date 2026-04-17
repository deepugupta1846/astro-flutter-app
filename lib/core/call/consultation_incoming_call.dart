/// Incoming voice/video ring from socket or FCM (data payload).
class IncomingCallInvite {
  IncomingCallInvite({
    required this.sessionId,
    required this.callLogId,
    required this.startedByUserId,
    required this.callType,
    this.peerDisplayName,
  });

  final int sessionId;
  final int callLogId;
  final int startedByUserId;
  /// `'voice'` | `'video'`
  final String callType;
  final String? peerDisplayName;

  bool get isVideo => callType.toLowerCase() == 'video';

  static IncomingCallInvite? tryParse(Map<String, dynamic> m) {
    int? pInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '');
    }

    final sessionId = pInt(m['sessionId']);
    final callLogId = pInt(m['callLogId']);
    final starter = pInt(m['startedByUserId']);
    if (sessionId == null || callLogId == null || starter == null) return null;
    final rawType =
        m['callType'] ?? m['call_type'] ?? m['CallType'];
    final ct = rawType?.toString().trim().toLowerCase() ?? 'voice';
    String? peer;
    final pn = m['peerDisplayName']?.toString().trim();
    if (pn != null && pn.isNotEmpty) peer = pn;

    return IncomingCallInvite(
      sessionId: sessionId,
      callLogId: callLogId,
      startedByUserId: starter,
      callType: (ct == 'video' || ct == 'videocall') ? 'video' : 'voice',
      peerDisplayName: peer,
    );
  }
}
