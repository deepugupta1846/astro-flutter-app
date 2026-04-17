import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../../core/api/consultation_api.dart';
import '../../core/api/upload_api.dart';
import '../../core/call/consultation_incoming_call.dart';
import '../../core/call/consultation_room_accept_bridge.dart';
import '../../core/call/incoming_call_coordinator.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/realtime/consultation_socket.dart';
import '../../core/session/app_session.dart';
import '../../core/theme/app_theme.dart';

/// Text chat + optional Agora voice/video for a user–astrologer session.
enum ConsultationCallMode { none, voice, video }

class ConsultationRoomScreen extends StatefulWidget {
  const ConsultationRoomScreen({
    super.key,
    this.astrologerId,
    required this.peerDisplayName,
    this.initialCallMode = ConsultationCallMode.none,
    this.existingSessionId,
    this.autoAnswerCallLogId,
    this.autoAnswerCallMode,
  }) : assert(
          existingSessionId != null || astrologerId != null,
          'astrologerId is required when not opening an existing session',
        );

  /// When non-null with [autoAnswerCallMode], joins the Agora channel as callee after load
  /// (used when opening the room from an [incoming_call] socket event).
  final int? autoAnswerCallLogId;
  final ConsultationCallMode? autoAnswerCallMode;

  /// Active consultation room session id (this device). Used to avoid duplicate incoming-call UX.
  static int? activeOpenSessionId;

  /// Astrologer profile id (customers start chat via [createOrGetSession]).
  final int? astrologerId;

  /// Name shown in the app bar (astrologer name for customers; customer name for astrologers).
  final String peerDisplayName;

  /// When set, loads this session directly (partner Chat tab / returning to thread).
  final int? existingSessionId;
  final ConsultationCallMode initialCallMode;

  @override
  State<ConsultationRoomScreen> createState() => _ConsultationRoomScreenState();
}

class _ChatLine {
  _ChatLine({
    this.messageId,
    required this.senderUserId,
    required this.body,
    required this.createdAt,
    required this.mine,
    this.messageType = 'text',
    this.deliveredAt,
    this.readAt,
  });

  final int? messageId;
  final int senderUserId;
  final String body;
  final DateTime? createdAt;
  final bool mine;
  final String messageType;
  final DateTime? deliveredAt;
  final DateTime? readAt;
}

class _ConsultationRoomScreenState extends State<ConsultationRoomScreen> {
  final _msgCtrl = TextEditingController();
  final _msgFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  int? _sessionId;
  String? _channelName;
  String? _agoraAppId;

  final List<_ChatLine> _messages = [];
  final Set<int> _messageIds = {};
  bool _loading = true;
  String? _error;
  sio.Socket? _socket;
  bool _sending = false;
  bool _emojiKeyboardVisible = false;

  String? _myAvatarUrl;
  String? _peerAvatarUrl;
  int? _peerUserId;

  RtcEngine? _engine;
  RtcEngineEventHandler? _rtcHandler;
  bool _rtcBusy = false;
  int? _remoteUid;
  int? _callLogId;
  ConsultationCallMode _activeCallMode = ConsultationCallMode.none;
  bool _micMuted = false;
  bool _speakerOn = false;
  DateTime? _callConnectedAt;
  Timer? _callUiTimer;
  bool _localVideoMuted = false;

  int? get _myUid => AppSession.userId;

  @override
  void initState() {
    super.initState();
    _msgFocus.addListener(_onMessageFocusChanged);
    final ex = widget.existingSessionId;
    if (ex != null) {
      ConsultationRoomScreen.activeOpenSessionId = ex;
    }
    _bootstrap();
  }

  void _onMessageFocusChanged() {
    if (_msgFocus.hasFocus && _emojiKeyboardVisible && mounted) {
      setState(() => _emojiKeyboardVisible = false);
    }
  }

  void _toggleEmojiKeyboard() {
    setState(() {
      _emojiKeyboardVisible = !_emojiKeyboardVisible;
      if (_emojiKeyboardVisible) {
        _msgFocus.unfocus();
      } else {
        _msgFocus.requestFocus();
      }
    });
  }

  Config _emojiPickerConfig(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Config(
      height: 256,
      emojiViewConfig: EmojiViewConfig(
        backgroundColor:
            isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8EEF2),
        columns: 8,
        emojiSizeMax: 26,
      ),
      categoryViewConfig: CategoryViewConfig(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary,
        iconColor: scheme.onSurfaceVariant,
        iconColorSelected: scheme.primary,
        backspaceColor: scheme.primary,
      ),
    );
  }

  Future<void> _bootstrap() async {
    final uid = _myUid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Not logged in';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Map<String, dynamic> data;
      if (widget.existingSessionId != null) {
        final res = await ConsultationApi.getSessionSummary(
          sessionId: widget.existingSessionId!,
          forUserId: uid,
        );
        if (!mounted) return;
        if (res['success'] != true || res['data'] == null) {
          setState(() {
            _loading = false;
            _error = res['message']?.toString() ?? 'Could not open session';
          });
          return;
        }
        data = Map<String, dynamic>.from(res['data'] as Map);
      } else {
        final aid = widget.astrologerId;
        if (aid == null) {
          setState(() {
            _loading = false;
            _error = 'Missing astrologer';
          });
          return;
        }
        final res = await ConsultationApi.createOrGetSession(
          customerUserId: uid,
          astrologerId: aid,
        );
        if (!mounted) return;
        if (res['success'] != true || res['data'] == null) {
          setState(() {
            _loading = false;
            _error = res['message']?.toString() ?? 'Could not open session';
          });
          return;
        }
        data = Map<String, dynamic>.from(res['data'] as Map);
      }
      final session = Map<String, dynamic>.from(data['session'] as Map);
      _sessionId = _asInt(session['id']);
      _channelName = session['channelName']?.toString();
      _agoraAppId = data['agoraAppId']?.toString();
      _hydrateParticipants(data, session, uid);

      await _loadMessages();
      await _markConversationOpened();
      _attachRealtime(uid, _sessionId!);
      _registerIncomingAcceptBridge();

      setState(() => _loading = false);

      ConsultationRoomScreen.activeOpenSessionId = _sessionId;

      // Receiver gets push from the server on POST /messages; ensure this device’s
      // FCM token is registered so the other party gets notifications too.
      unawaited(PushNotificationService.syncTokenWithBackend());

      final autoLog = widget.autoAnswerCallLogId;
      final autoMode = widget.autoAnswerCallMode;
      if (autoLog != null &&
          autoMode != null &&
          widget.initialCallMode == ConsultationCallMode.none) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _joinRtc(
            autoMode,
            outgoing: false,
            existingCallLogId: autoLog,
          );
        });
      }

      if (widget.initialCallMode != ConsultationCallMode.none) {
        await _joinRtc(widget.initialCallMode);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _hydrateParticipants(
    Map<String, dynamic> data,
    Map<String, dynamic> session,
    int uid,
  ) {
    final cid = _asInt(session['customerUserId']);
    final aid = _asInt(session['astrologerUserId']);
    _peerUserId = uid == cid ? aid : cid;
    Map<String, dynamic>? custMap;
    Map<String, dynamic>? astroMap;
    final c = data['customer'];
    final a = data['astrologerUser'];
    if (c is Map) custMap = Map<String, dynamic>.from(c);
    if (a is Map) astroMap = Map<String, dynamic>.from(a);
    String? urlFrom(Map<String, dynamic>? m) {
      final u = m?['profileImageUrl']?.toString().trim();
      if (u == null || u.isEmpty) return null;
      return u;
    }

    if (uid == cid) {
      _myAvatarUrl = urlFrom(custMap) ??
          AppSession.user?['profileImageUrl']?.toString();
      _peerAvatarUrl = urlFrom(astroMap);
    } else {
      _myAvatarUrl = urlFrom(astroMap) ??
          AppSession.user?['profileImageUrl']?.toString();
      _peerAvatarUrl = urlFrom(custMap);
    }
  }

  Future<void> _markConversationOpened() async {
    final sid = _sessionId;
    final my = _myUid;
    if (sid == null || my == null) return;
    try {
      await ConsultationApi.markConversationRead(
        sessionId: sid,
        readerUserId: my,
      );
    } catch (_) {}
  }

  void _emitDeliveredAck(List<int> ids) {
    final sid = _sessionId;
    final my = _myUid;
    final sock = _socket;
    if (sid == null || my == null || ids.isEmpty || sock == null) return;
    sock.emit('message_delivered', {
      'sessionId': sid,
      'userId': my,
      'messageIds': ids,
    });
  }

  void _ackUndeliveredIncoming() {
    final ids = <int>[];
    for (final m in _messages) {
      if (m.mine) continue;
      if (m.messageId == null) continue;
      if (m.deliveredAt != null) continue;
      ids.add(m.messageId!);
    }
    if (ids.isNotEmpty) {
      _emitDeliveredAck(ids);
    }
  }

  DateTime? _parseOptionalDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  void _registerIncomingAcceptBridge() {
    final sid = _sessionId;
    if (sid == null) return;
    ConsultationRoomAcceptBridge.registerOpenSession(sid, (invite) async {
      final mode = invite.isVideo
          ? ConsultationCallMode.video
          : ConsultationCallMode.voice;
      if (!mounted) return;
      await _joinRtc(
        mode,
        outgoing: false,
        existingCallLogId: invite.callLogId,
      );
    });
  }

  void _attachRealtime(int userId, int sessionId) {
    _socket?.dispose();
    final s = createConsultationSocket(userId);
    _socket = s;
    s.on('chat_message', (data) {
      if (!mounted || data is! Map) return;
      final m = Map<String, dynamic>.from(data);
      final sender = _asInt(m['senderUserId']) ?? 0;
      final mid = _asInt(m['id']);
      _appendMessageFromPayload(m, userId);
      if (sender != userId && mid != null) {
        _emitDeliveredAck([mid]);
      }
    });
    s.on('message_status', (data) {
      if (!mounted || data is! Map) return;
      _onMessageStatus(Map<String, dynamic>.from(data));
    });
    s.on('conversation_read', (data) {
      if (!mounted || data is! Map) return;
      _onConversationRead(Map<String, dynamic>.from(data));
    });
    s.on('call_ended', (data) {
      if (!mounted || data is! Map) return;
      _onRemoteCallEndedSocket(Map<String, dynamic>.from(data));
    });
    if (widget.autoAnswerCallLogId == null) {
      s.on('incoming_call', (data) {
        if (!mounted || data is! Map) return;
        _handleIncomingCallSocket(Map<String, dynamic>.from(data));
      });
    }
    void join() {
      s.emit('join_consultation', {'sessionId': sessionId});
      _ackUndeliveredIncoming();
    }

    s.onConnect((_) => join());
    s.connect();
  }

  void _onRemoteCallEndedSocket(Map<String, dynamic> m) {
    final sid = _asInt(m['sessionId']);
    final cid = _asInt(m['callLogId']);
    if (sid == null || sid != _sessionId) return;
    if (cid != null &&
        _callLogId != null &&
        cid != _callLogId) {
      return;
    }
    if (_activeCallMode == ConsultationCallMode.none &&
        !_rtcBusy &&
        _engine == null) {
      return;
    }
    unawaited(_tearDownAfterRemoteCallEnded());
  }

  Future<void> _tearDownAfterRemoteCallEnded() async {
    _callLogId = null;
    await _tearDownRtc();
    if (mounted) setState(() {});
  }

  void _handleIncomingCallSocket(Map<String, dynamic> m) {
    final sid = _asInt(m['sessionId']);
    if (sid == null || sid != _sessionId) return;
    final starter = _asInt(m['startedByUserId']);
    final my = _myUid;
    if (my == null || starter == my) return;
    final callLogId = _asInt(m['callLogId']);
    if (callLogId == null) return;
    if (_activeCallMode != ConsultationCallMode.none || _rtcBusy) return;
    if (!mounted) return;
    final inv = IncomingCallInvite.tryParse({
      ...m,
      'peerDisplayName': widget.peerDisplayName,
    });
    if (inv == null) return;
    unawaited(IncomingCallCoordinator.instance.present(inv));
  }

  void _onMessageStatus(Map<String, dynamic> m) {
    final id = _asInt(m['id']);
    if (id == null) return;
    final idx = _messages.indexWhere((e) => e.messageId == id);
    if (idx < 0) return;
    final old = _messages[idx];
    final da = _parseOptionalDate(m['deliveredAt']);
    final ra = _parseOptionalDate(m['readAt']);
    if (!mounted) return;
    setState(() {
      _messages[idx] = _ChatLine(
        messageId: old.messageId,
        senderUserId: old.senderUserId,
        body: old.body,
        createdAt: old.createdAt,
        mine: old.mine,
        messageType: old.messageType,
        deliveredAt: da ?? old.deliveredAt,
        readAt: ra ?? old.readAt,
      );
    });
  }

  void _onConversationRead(Map<String, dynamic> data) {
    final rid = _asInt(data['readerUserId']);
    if (rid == null || rid != _peerUserId) return;
    final readAt =
        _parseOptionalDate(data['readAt']) ?? DateTime.now();
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        final m = _messages[i];
        if (!m.mine) continue;
        _messages[i] = _ChatLine(
          messageId: m.messageId,
          senderUserId: m.senderUserId,
          body: m.body,
          createdAt: m.createdAt,
          mine: m.mine,
          messageType: m.messageType,
          deliveredAt: m.deliveredAt ?? readAt,
          readAt: readAt,
        );
      }
    });
  }

  void _appendMessageFromPayload(Map<String, dynamic> m, int myUid) {
    final id = _asInt(m['id']);
    if (id != null && _messageIds.contains(id)) return;
    final sid = _asInt(m['sessionId']);
    if (sid != null && sid != _sessionId) return;
    final sender = _asInt(m['senderUserId']) ?? 0;
    final body = m['body']?.toString() ?? '';
    DateTime? at;
    final ca = m['createdAt'];
    if (ca is String) {
      at = DateTime.tryParse(ca);
    }
    final mt = m['messageType']?.toString() ?? 'text';
    if (id != null) {
      _messageIds.add(id);
    }
    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatLine(
          messageId: id,
          senderUserId: sender,
          body: body,
          createdAt: at,
          mine: sender == myUid,
          messageType: mt,
          deliveredAt: _parseOptionalDate(m['deliveredAt']),
          readAt: _parseOptionalDate(m['readAt']),
        ),
      );
    });
    _scrollChatToBottom();
  }

  Future<void> _loadMessages() async {
    final sid = _sessionId;
    final my = _myUid;
    if (sid == null || my == null) return;
    try {
      final res = await ConsultationApi.listMessages(sessionId: sid);
      if (!mounted || res['success'] != true) return;
      final raw = res['data'];
      if (raw is! List) return;
      final next = <_ChatLine>[];
      final ids = <int>{};
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final mid = _asInt(m['id']);
        final sender = _asInt(m['senderUserId']) ?? 0;
        final body = m['body']?.toString() ?? '';
        DateTime? at;
        final ca = m['createdAt'];
        if (ca is String) {
          at = DateTime.tryParse(ca);
        }
        if (mid != null) {
          ids.add(mid);
        }
        next.add(
          _ChatLine(
            messageId: mid,
            senderUserId: sender,
            body: body,
            createdAt: at,
            mine: sender == my,
            messageType: m['messageType']?.toString() ?? 'text',
            deliveredAt: _parseOptionalDate(m['deliveredAt']),
            readAt: _parseOptionalDate(m['readAt']),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _messageIds
          ..clear()
          ..addAll(ids);
        _messages
          ..clear()
          ..addAll(next);
      });
      _scrollChatToBottom();
    } catch (_) {}
  }

  Future<void> _sendText() async {
    final sid = _sessionId;
    final my = _myUid;
    final text = _msgCtrl.text.trim();
    if (sid == null || my == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await ConsultationApi.sendMessage(
        sessionId: sid,
        senderUserId: my,
        body: text,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        _msgCtrl.clear();
        final d = res['data'];
        if (d is Map) {
          _appendMessageFromPayload(
            Map<String, dynamic>.from(d),
            my,
          );
        }
        unawaited(PushNotificationService.syncTokenWithBackend());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Send failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final sid = _sessionId;
    final my = _myUid;
    if (sid == null || my == null || _sending) return;
    try {
      final xfile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (xfile == null || !mounted) return;
      setState(() => _sending = true);
      final upload = await UploadApi.uploadImage(xfile.path);
      if (!upload.isOk || upload.url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(upload.errorMessage ?? 'Upload failed'),
            ),
          );
        }
        return;
      }
      final res = await ConsultationApi.sendMessage(
        sessionId: sid,
        senderUserId: my,
        body: upload.url!,
        messageType: 'image',
      );
      if (!mounted) return;
      if (res['success'] == true) {
        final d = res['data'];
        if (d is Map) {
          _appendMessageFromPayload(Map<String, dynamic>.from(d), my);
        }
        unawaited(PushNotificationService.syncTokenWithBackend());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Send failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildAvatar(String? url, String fallbackLetter) {
    final letter = fallbackLetter.isNotEmpty
        ? fallbackLetter[0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
      backgroundImage:
          url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: url == null || url.isEmpty
          ? Text(
              letter,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            )
          : null,
    );
  }

  Widget _receiptTrailing(_ChatLine m) {
    if (!m.mine) return const SizedBox.shrink();
    if (m.readAt != null) {
      return Icon(Icons.done_all_rounded, size: 15, color: Colors.blue.shade700);
    }
    if (m.deliveredAt != null) {
      return Icon(
        Icons.done_all_rounded,
        size: 15,
        color: AppTheme.secondaryTextColor,
      );
    }
    return Icon(
      Icons.check_rounded,
      size: 15,
      color: AppTheme.secondaryTextColor,
    );
  }

  void _openImageUrl(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            maxWidth: MediaQuery.sizeOf(context).width * 0.92,
          ),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubbleContent(_ChatLine m) {
    if (m.messageType == 'image') {
      return GestureDetector(
        onTap: () => _openImageUrl(m.body),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            m.body,
            height: 200,
            width: 220,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                height: 120,
                width: 220,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (_, _, _) => Container(
              height: 100,
              width: 200,
              color: AppTheme.surfaceContainerHigh,
              alignment: Alignment.center,
              child: const Text('Could not load image'),
            ),
          ),
        ),
      );
    }
    return Text(
      m.body,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
    );
  }

  Widget _messageRow(_ChatLine m) {
    final mine = m.mine;
    final peerLabel = widget.peerDisplayName.isNotEmpty
        ? widget.peerDisplayName[0]
        : 'P';
    final avatarUrl = mine ? _myAvatarUrl : _peerAvatarUrl;
    final letter = mine
        ? (AppSession.displayName.isNotEmpty
            ? AppSession.displayName[0]
            : 'Y')
        : peerLabel;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: mine
            ? AppTheme.primaryColor.withValues(alpha: 0.18)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        border: Border.all(color: AppTheme.inputBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _bubbleContent(m),
          if (m.createdAt != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMsgTime(m.createdAt!),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                const SizedBox(width: 6),
                _receiptTrailing(m),
              ],
            ),
          ] else
            Align(
              alignment: Alignment.bottomRight,
              child: _receiptTrailing(m),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!mine) ...[
            _buildAvatar(avatarUrl, peerLabel),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
          if (mine) ...[
            const SizedBox(width: 8),
            _buildAvatar(avatarUrl, letter),
          ],
        ],
      ),
    );
  }

  String _formatMsgTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _joinRtc(
    ConsultationCallMode mode, {
    bool outgoing = true,
    int? existingCallLogId,
  }) async {
    final sid = _sessionId;
    final channel = _channelName;
    final appId = _agoraAppId;
    final uid = _myUid;
    if (sid == null || channel == null || channel == 'pending' || uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session not ready for calling')),
        );
      }
      return;
    }
    if (appId == null || appId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agora is not configured on the server (AGORA_APP_ID).'),
          ),
        );
      }
      return;
    }

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
      return;
    }
    if (mode == ConsultationCallMode.video) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required')),
          );
        }
        return;
      }
    }

    if (_rtcBusy || _engine != null) return;
    setState(() => _rtcBusy = true);

    try {
      final callType = mode == ConsultationCallMode.video ? 'video' : 'voice';
      if (outgoing) {
        final startRes = await ConsultationApi.startCall(
          sessionId: sid,
          callType: callType,
          startedByUserId: uid,
        );
        if (!mounted) return;
        if (startRes['success'] != true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                startRes['message']?.toString() ?? 'Could not start call',
              ),
            ),
          );
          setState(() => _rtcBusy = false);
          return;
        }
        final d = startRes['data'];
        if (d is Map) {
          _callLogId = _asInt(Map<String, dynamic>.from(d)['callLogId']);
        }
      } else {
        if (existingCallLogId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid incoming call')),
            );
            setState(() => _rtcBusy = false);
          }
          return;
        }
        _callLogId = existingCallLogId;
      }

      final tokRes = await ConsultationApi.issueRtcToken(
        channelName: channel,
        uid: uid,
        sessionId: sid,
      );
      if (!mounted) return;
      if (tokRes['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tokRes['message']?.toString() ?? 'Could not get token')),
        );
        setState(() => _rtcBusy = false);
        return;
      }
      final td = Map<String, dynamic>.from(tokRes['data'] as Map);
      final token = td['token']?.toString() ?? '';

      final engine = createAgoraRtcEngine();
      _engine = engine;

      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      _rtcHandler = RtcEngineEventHandler(
        onUserJoined: (connection, remoteUid, elapsed) {
          if (!mounted) return;
          setState(() {
            _remoteUid = remoteUid;
            if (mode == ConsultationCallMode.voice ||
                mode == ConsultationCallMode.video) {
              _callConnectedAt ??= DateTime.now();
            }
          });
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (!mounted) return;
          setState(() {
            if (_remoteUid == remoteUid) {
              _remoteUid = null;
              _callConnectedAt = null;
            }
          });
        },
        onError: (err, msg) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Agora ($err): $msg'),
              duration: const Duration(seconds: 5),
            ),
          );
        },
      );
      engine.registerEventHandler(_rtcHandler!);

      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      if (mode == ConsultationCallMode.video) {
        await engine.enableVideo();
        await engine.enableLocalVideo(true);
        // Required for local preview / publishing; without this many devices error or stay black.
        await engine.startPreview();
      } else {
        await engine.disableVideo();
      }
      await engine.enableAudio();

      await engine.joinChannel(
        token: token,
        channelId: channel,
        uid: uid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: mode == ConsultationCallMode.video,
          autoSubscribeAudio: true,
          autoSubscribeVideo: mode == ConsultationCallMode.video,
        ),
      );
      if (mode == ConsultationCallMode.voice) {
        await engine.setDefaultAudioRouteToSpeakerphone(_speakerOn);
      } else if (mode == ConsultationCallMode.video) {
        try {
          await engine.setDefaultAudioRouteToSpeakerphone(true);
          await engine.setEnableSpeakerphone(true);
        } catch (_) {
          // E.g. desktop / unsupported platform — video can still work.
        }
      }
      if (!mounted) return;
      setState(() {
        _activeCallMode = mode;
        _rtcBusy = false;
        if (mode == ConsultationCallMode.video) {
          _speakerOn = true;
        }
      });
      if (mode == ConsultationCallMode.voice ||
          mode == ConsultationCallMode.video) {
        _startCallUiTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call error: $e')),
        );
        setState(() => _rtcBusy = false);
      }
      await _tearDownRtc();
    }
  }

  void _startCallUiTimer() {
    _callUiTimer?.cancel();
    _callUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          (_activeCallMode == ConsultationCallMode.voice ||
              _activeCallMode == ConsultationCallMode.video)) {
        setState(() {});
      }
    });
  }

  void _stopCallUiTimer() {
    _callUiTimer?.cancel();
    _callUiTimer = null;
  }

  Future<void> _toggleCallMic() async {
    final e = _engine;
    if (e == null) return;
    final next = !_micMuted;
    try {
      await e.muteLocalAudioStream(next);
      if (mounted) setState(() => _micMuted = next);
    } catch (_) {}
  }

  Future<void> _toggleCallSpeaker() async {
    final e = _engine;
    if (e == null) return;
    final next = !_speakerOn;
    try {
      await e.setEnableSpeakerphone(next);
      if (mounted) setState(() => _speakerOn = next);
    } catch (_) {}
  }

  Future<void> _toggleLocalVideoPublished() async {
    final e = _engine;
    if (e == null || _activeCallMode != ConsultationCallMode.video) return;
    final next = !_localVideoMuted;
    try {
      await e.muteLocalVideoStream(next);
      if (!next) {
        try {
          await e.startPreview();
        } catch (_) {}
      }
      if (mounted) setState(() => _localVideoMuted = next);
    } catch (_) {}
  }

  Future<void> _flipCamera() async {
    final e = _engine;
    if (e == null || _activeCallMode != ConsultationCallMode.video) return;
    try {
      await e.switchCamera();
    } catch (_) {}
  }

  Future<void> _tearDownRtc() async {
    _stopCallUiTimer();
    _callConnectedAt = null;
    _micMuted = false;
    _speakerOn = false;
    _localVideoMuted = false;
    final wasVideo = _activeCallMode == ConsultationCallMode.video;
    final engine = _engine;
    final handler = _rtcHandler;
    _engine = null;
    _rtcHandler = null;
    if (engine != null) {
      try {
        if (handler != null) engine.unregisterEventHandler(handler);
        if (wasVideo) {
          try {
            await engine.stopPreview();
          } catch (_) {}
        }
        await engine.leaveChannel();
        await engine.release();
      } catch (_) {}
    }
    _remoteUid = null;
    _activeCallMode = ConsultationCallMode.none;
    _rtcBusy = false;
  }

  Future<void> _hangUp() async {
    final id = _callLogId;
    if (id != null) {
      try {
        await ConsultationApi.endCall(callLogId: id);
      } catch (_) {}
      _callLogId = null;
    }
    await _tearDownRtc();
    if (mounted) setState(() {});
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  @override
  void dispose() {
    final activeSid = _sessionId ?? widget.existingSessionId;
    if (activeSid != null) {
      ConsultationRoomAcceptBridge.unregister(activeSid);
    }
    if (activeSid != null &&
        ConsultationRoomScreen.activeOpenSessionId == activeSid) {
      ConsultationRoomScreen.activeOpenSessionId = null;
    }
    _stopCallUiTimer();
    final sid = _sessionId;
    if (_socket != null && sid != null) {
      _socket!.emit('leave_consultation', {'sessionId': sid});
    }
    _socket?.dispose();
    _socket = null;
    _hangUp();
    _msgFocus.removeListener(_onMessageFocusChanged);
    _msgFocus.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channel = _channelName;
    final engine = _engine;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            _buildAvatar(
              _peerAvatarUrl,
              widget.peerDisplayName.isNotEmpty
                  ? widget.peerDisplayName[0]
                  : 'P',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.peerDisplayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_activeCallMode == ConsultationCallMode.none && !_loading && _error == null)
            IconButton(
              tooltip: 'Voice call',
              onPressed: _rtcBusy ? null : () => _joinRtc(ConsultationCallMode.voice),
              icon: const Icon(Icons.phone_rounded),
            ),
          if (_activeCallMode == ConsultationCallMode.none && !_loading && _error == null)
            IconButton(
              tooltip: 'Video call',
              onPressed: _rtcBusy ? null : () => _joinRtc(ConsultationCallMode.video),
              icon: const Icon(Icons.videocam_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Go back'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (context, i) => _messageRow(_messages[i]),
                          ),
                        ),
                        if (_emojiKeyboardVisible)
                          SizedBox(
                            height: 280,
                            child: EmojiPicker(
                              textEditingController: _msgCtrl,
                              config: _emojiPickerConfig(context),
                            ),
                          ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: 'Photo',
                                  onPressed: _sending ? null : _pickAndSendImage,
                                  icon: const Icon(Icons.image_outlined),
                                ),
                                IconButton(
                                  tooltip: _emojiKeyboardVisible
                                      ? 'Keyboard'
                                      : 'Emoji',
                                  onPressed: _toggleEmojiKeyboard,
                                  icon: Icon(
                                    _emojiKeyboardVisible
                                        ? Icons.keyboard_rounded
                                        : Icons.emoji_emotions_outlined,
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _msgCtrl,
                                    focusNode: _msgFocus,
                                    minLines: 1,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      hintText: 'Message…',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    onSubmitted: (_) => _sendText(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed: _sending ? null : _sendText,
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.send_rounded),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_activeCallMode == ConsultationCallMode.voice &&
                        engine != null &&
                        channel != null)
                      Positioned.fill(
                        child: _WhatsAppVoiceCallOverlay(
                          peerName: widget.peerDisplayName,
                          peerAvatarUrl: _peerAvatarUrl,
                          remoteJoined: _remoteUid != null,
                          connectedAt: _callConnectedAt,
                          micMuted: _micMuted,
                          speakerOn: _speakerOn,
                          onToggleMic: _toggleCallMic,
                          onToggleSpeaker: _toggleCallSpeaker,
                          onHangUp: _hangUp,
                        ),
                      ),
                    if (_activeCallMode == ConsultationCallMode.video &&
                        engine != null &&
                        channel != null)
                      Positioned.fill(
                        child: _WhatsAppVideoCallOverlay(
                          engine: engine,
                          channelName: channel,
                          remoteUid: _remoteUid,
                          peerName: widget.peerDisplayName,
                          peerAvatarUrl: _peerAvatarUrl,
                          connectedAt: _callConnectedAt,
                          micMuted: _micMuted,
                          speakerOn: _speakerOn,
                          localVideoMuted: _localVideoMuted,
                          onToggleMic: _toggleCallMic,
                          onToggleSpeaker: _toggleCallSpeaker,
                          onToggleVideo: _toggleLocalVideoPublished,
                          onFlipCamera: () {
                            _flipCamera();
                          },
                          onHangUp: _hangUp,
                        ),
                      ),
                  ],
                ),
    );
  }
}

/// WhatsApp-style full-screen voice call UI (peer avatar, status, duration, controls).
class _WhatsAppVoiceCallOverlay extends StatelessWidget {
  const _WhatsAppVoiceCallOverlay({
    required this.peerName,
    required this.peerAvatarUrl,
    required this.remoteJoined,
    required this.connectedAt,
    required this.micMuted,
    required this.speakerOn,
    required this.onToggleMic,
    required this.onToggleSpeaker,
    required this.onHangUp,
  });

  final String peerName;
  final String? peerAvatarUrl;
  final bool remoteJoined;
  final DateTime? connectedAt;
  final bool micMuted;
  final bool speakerOn;
  final Future<void> Function() onToggleMic;
  final Future<void> Function() onToggleSpeaker;
  final VoidCallback onHangUp;

  static String _formatDuration(DateTime start) {
    final sec = DateTime.now().difference(start).inSeconds;
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final letter = peerName.isNotEmpty ? peerName[0].toUpperCase() : '?';
    final url = peerAvatarUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;

    final start = connectedAt;
    final statusText = !remoteJoined
        ? 'Calling…'
        : (start != null ? _formatDuration(start) : 'Connecting…');

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B3D2E),
              Color(0xFF061812),
              Color(0xFF050A08),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Icon(Icons.lock_rounded, size: 14, color: Colors.white.withValues(alpha: 0.45)),
              const SizedBox(height: 6),
              Text(
                'End-to-end encrypted',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(flex: 2),
              CircleAvatar(
                radius: 84,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                backgroundImage: hasPhoto ? NetworkImage(url) : null,
                child: !hasPhoto
                    ? Text(
                        letter,
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  peerName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                statusText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _VoiceCallCircleButton(
                      label: micMuted ? 'Unmute' : 'Mute',
                      icon: micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      iconColor: micMuted ? Colors.redAccent.shade100 : Colors.white,
                      onPressed: () => onToggleMic(),
                    ),
                    _VoiceCallCircleButton(
                      label: '',
                      icon: Icons.call_end_rounded,
                      backgroundColor: const Color(0xFFE53935),
                      iconColor: Colors.white,
                      diameter: 72,
                      onPressed: onHangUp,
                    ),
                    _VoiceCallCircleButton(
                      label: speakerOn ? 'Speaker on' : 'Speaker',
                      icon: speakerOn
                          ? Icons.volume_up_rounded
                          : Icons.hearing_rounded,
                      backgroundColor: speakerOn
                          ? Colors.white.withValues(alpha: 0.28)
                          : Colors.white.withValues(alpha: 0.18),
                      iconColor: Colors.white,
                      onPressed: () => onToggleSpeaker(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceCallCircleButton extends StatelessWidget {
  const _VoiceCallCircleButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onPressed,
    this.diameter = 60,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onPressed;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Ink(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: diameter > 64 ? 34 : 28),
            ),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 88,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ] else
          const SizedBox(height: 22),
      ],
    );
  }
}

/// WhatsApp-style full-screen video call (remote fill, local PiP, bottom toolbar).
class _WhatsAppVideoCallOverlay extends StatelessWidget {
  const _WhatsAppVideoCallOverlay({
    required this.engine,
    required this.channelName,
    required this.remoteUid,
    required this.peerName,
    required this.peerAvatarUrl,
    required this.connectedAt,
    required this.micMuted,
    required this.speakerOn,
    required this.localVideoMuted,
    required this.onToggleMic,
    required this.onToggleSpeaker,
    required this.onToggleVideo,
    required this.onFlipCamera,
    required this.onHangUp,
  });

  final RtcEngine engine;
  final String channelName;
  final int? remoteUid;
  final String peerName;
  final String? peerAvatarUrl;
  final DateTime? connectedAt;
  final bool micMuted;
  final bool speakerOn;
  final bool localVideoMuted;
  final Future<void> Function() onToggleMic;
  final Future<void> Function() onToggleSpeaker;
  final Future<void> Function() onToggleVideo;
  final VoidCallback onFlipCamera;
  final VoidCallback onHangUp;

  static String _formatDuration(DateTime start) {
    final sec = DateTime.now().difference(start).inSeconds;
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final paddingTop = MediaQuery.paddingOf(context).top;
    final remoteJoined = remoteUid != null;
    final rid = remoteUid;
    final start = connectedAt;
    final statusText = !remoteJoined
        ? 'Calling…'
        : (start != null ? _formatDuration(start) : 'Connecting…');

    final letter = peerName.isNotEmpty ? peerName[0].toUpperCase() : '?';
    final url = peerAvatarUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (remoteJoined && rid != null)
            Positioned.fill(
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: engine,
                  canvas: VideoCanvas(uid: rid),
                  connection: RtcConnection(channelId: channelName),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: const Color(0xFF1A1F1C),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 72,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      backgroundImage: hasPhoto ? NetworkImage(url) : null,
                      child: !hasPhoto
                          ? Text(
                              letter,
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      peerName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Waiting for video…',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: paddingTop + 100,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: paddingTop + 52,
            right: 12,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              color: Colors.black,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 108,
                  height: 144,
                  child: localVideoMuted
                      ? ColoredBox(
                          color: const Color(0xFF2D3230),
                          child: Icon(
                            Icons.videocam_off_rounded,
                            size: 40,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        )
                      : AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: engine,
                            canvas: const VideoCanvas(uid: 0),
                          ),
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 48, 8, 20),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _VoiceCallCircleButton(
                          label: localVideoMuted ? 'Camera on' : 'Video off',
                          icon: localVideoMuted
                              ? Icons.videocam_off_rounded
                              : Icons.videocam_rounded,
                          backgroundColor: localVideoMuted
                              ? Colors.white.withValues(alpha: 0.28)
                              : Colors.white.withValues(alpha: 0.18),
                          iconColor: Colors.white,
                          diameter: 52,
                          onPressed: () => onToggleVideo(),
                        ),
                        const SizedBox(width: 10),
                        _VoiceCallCircleButton(
                          label: micMuted ? 'Unmute' : 'Mute',
                          icon: micMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          iconColor: micMuted
                              ? Colors.redAccent.shade100
                              : Colors.white,
                          diameter: 52,
                          onPressed: () => onToggleMic(),
                        ),
                        const SizedBox(width: 10),
                        _VoiceCallCircleButton(
                          label: '',
                          icon: Icons.call_end_rounded,
                          backgroundColor: const Color(0xFFE53935),
                          iconColor: Colors.white,
                          diameter: 72,
                          onPressed: onHangUp,
                        ),
                        const SizedBox(width: 10),
                        _VoiceCallCircleButton(
                          label: speakerOn ? 'Speaker on' : 'Speaker',
                          icon: speakerOn
                              ? Icons.volume_up_rounded
                              : Icons.hearing_rounded,
                          backgroundColor: speakerOn
                              ? Colors.white.withValues(alpha: 0.28)
                              : Colors.white.withValues(alpha: 0.18),
                          iconColor: Colors.white,
                          diameter: 52,
                          onPressed: () => onToggleSpeaker(),
                        ),
                        const SizedBox(width: 10),
                        _VoiceCallCircleButton(
                          label: 'Flip',
                          icon: Icons.cameraswitch_rounded,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          iconColor: Colors.white,
                          diameter: 52,
                          onPressed: onFlipCamera,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
