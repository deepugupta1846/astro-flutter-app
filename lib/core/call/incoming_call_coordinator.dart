import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/consultation_api.dart';
import '../session/app_session.dart';
import 'consultation_incoming_call.dart';
import 'consultation_room_accept_bridge.dart';
import 'open_incoming_call_room.dart';

/// App-wide incoming call (socket + FCM). Drives [IncomingCallOverlayHost].
class IncomingCallCoordinator extends ChangeNotifier {
  IncomingCallCoordinator._();
  static final IncomingCallCoordinator instance = IncomingCallCoordinator._();

  IncomingCallInvite? _invite;
  IncomingCallInvite? get invite => _invite;

  bool _busy = false;

  /// Show full-screen accept UI (dedupes same [callLogId]).
  Future<void> present(IncomingCallInvite incoming) async {
    final my = AppSession.userId;
    if (my == null || incoming.startedByUserId == my) return;
    if (_invite?.callLogId == incoming.callLogId) return;

    var inv = incoming;
    if (inv.peerDisplayName == null || inv.peerDisplayName!.isEmpty) {
      final name = await _fetchPeerName(inv.sessionId, my);
      inv = IncomingCallInvite(
        sessionId: inv.sessionId,
        callLogId: inv.callLogId,
        startedByUserId: inv.startedByUserId,
        callType: inv.callType,
        peerDisplayName: name,
      );
    }

    _invite = inv;
    notifyListeners();
  }

  Future<String?> _fetchPeerName(int sessionId, int forUserId) async {
    try {
      final res = await ConsultationApi.getSessionSummary(
        sessionId: sessionId,
        forUserId: forUserId,
      );
      if (res['success'] != true || res['data'] == null) return null;
      final data = Map<String, dynamic>.from(res['data'] as Map);
      final session = Map<String, dynamic>.from(data['session'] as Map);
      final cid = _asInt(session['customerUserId']);
      final aid = _asInt(session['astrologerUserId']);
      if (cid == null || aid == null) return null;
      final peerId = forUserId == cid ? aid : cid;
      final key = forUserId == cid ? 'astrologerUser' : 'customer';
      final peer = data[key];
      if (peer is Map) {
        final n = Map<String, dynamic>.from(peer)['name']?.toString().trim();
        if (n != null && n.isNotEmpty) return n;
      }
      return 'User #$peerId';
    } catch (_) {
      return null;
    }
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  void dismiss() {
    _invite = null;
    notifyListeners();
  }

  Future<void> accept() async {
    final inv = _invite;
    if (inv == null || _busy) return;
    _busy = true;
    try {
      final consumed =
          await ConsultationRoomAcceptBridge.deliverAcceptIfSameSession(inv);
      dismiss();
      if (consumed) return;
      await openConsultationRoomForIncomingCall(inv);
    } finally {
      _busy = false;
    }
  }

  Future<void> decline() async {
    final inv = _invite;
    if (inv == null || _busy) return;
    _busy = true;
    try {
      dismiss();
      try {
        await ConsultationApi.endCall(callLogId: inv.callLogId);
      } catch (_) {}
    } finally {
      _busy = false;
    }
  }

  /// Socket / FCM payload maps.
  void handleRawPayload(Map<String, dynamic> raw) {
    final inv = IncomingCallInvite.tryParse(raw);
    if (inv == null) return;
    unawaited(present(inv));
  }

  /// Other party hung up (or ring cancelled); dismiss full-screen incoming UI if it matches.
  void onRemoteCallEnded({required int sessionId, required int callLogId}) {
    final inv = _invite;
    if (inv == null) return;
    if (inv.sessionId != sessionId || inv.callLogId != callLogId) return;
    dismiss();
  }
}
