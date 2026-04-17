import 'package:flutter/material.dart';

import '../../screens/consultation/consultation_room_screen.dart';
import '../navigation/app_navigator.dart';
import 'consultation_incoming_call.dart';

/// Pushes [ConsultationRoomScreen] for an accepted incoming call (not same-session bridge).
Future<void> openConsultationRoomForIncomingCall(IncomingCallInvite inv) async {
  final nav = appNavigatorKey.currentState;
  if (nav == null) return;
  await nav.push<void>(
    MaterialPageRoute<void>(
      builder: (ctx) => ConsultationRoomScreen(
        existingSessionId: inv.sessionId,
        peerDisplayName: inv.peerDisplayName ?? 'Call',
        autoAnswerCallLogId: inv.callLogId,
        autoAnswerCallMode: inv.isVideo
            ? ConsultationCallMode.video
            : ConsultationCallMode.voice,
      ),
    ),
  );
}
