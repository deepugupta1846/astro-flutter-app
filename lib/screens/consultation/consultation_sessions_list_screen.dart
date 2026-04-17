import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../../core/api/consultation_api.dart';
import '../../core/realtime/consultation_socket.dart';
import '../../core/session/app_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/call/incoming_call_coordinator.dart';
import 'consultation_room_screen.dart';

/// Consultation threads for the logged-in user (bottom-nav Chat tab).
class ConsultationSessionsListScreen extends StatefulWidget {
  const ConsultationSessionsListScreen({
    super.key,
    this.perspective,
    this.includeClosed = false,
  });

  /// `astrologer` | `customer`, or `null` = every thread this account is in (customer + astrologer).
  final String? perspective;

  /// When true, loads closed sessions as well (full chat history).
  final bool includeClosed;

  @override
  State<ConsultationSessionsListScreen> createState() =>
      _ConsultationSessionsListScreenState();
}

class _ConsultationSessionsListScreenState
    extends State<ConsultationSessionsListScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  sio.Socket? _socket;
  Set<int> _onlineUserIds = {};

  @override
  void initState() {
    super.initState();
    _load();
    final uid = AppSession.userId;
    if (uid != null) {
      _socket = createConsultationSocket(uid);
      _socket!.on('inbox_updated', (_) {
        if (mounted) _load(silent: true);
      });
      _socket!.on('incoming_call', _onIncomingCall);
      _socket!.on('call_ended', _onCallEnded);
      _socket!.on('presence_snapshot', _onPresenceSnapshot);
      _socket!.on('user_presence', _onUserPresence);
      _socket!.connect();
    }
  }

  void _onPresenceSnapshot(dynamic raw) {
    if (raw is! Map) return;
    final list = raw['onlineUserIds'];
    if (list is! List) return;
    final next = <int>{};
    for (final e in list) {
      final n = e is int ? e : int.tryParse(e.toString());
      if (n != null && n > 0) next.add(n);
    }
    if (mounted) setState(() => _onlineUserIds = next);
  }

  void _onIncomingCall(dynamic raw) {
    if (!mounted || raw is! Map) return;
    IncomingCallCoordinator.instance.handleRawPayload(
      Map<String, dynamic>.from(raw),
    );
  }

  void _onCallEnded(dynamic raw) {
    if (raw is! Map) return;
    final m = Map<String, dynamic>.from(raw);
    final sid = _intFrom(m, 'sessionId');
    final cid = _intFrom(m, 'callLogId');
    if (sid == null || cid == null) return;
    IncomingCallCoordinator.instance.onRemoteCallEnded(
      sessionId: sid,
      callLogId: cid,
    );
  }

  void _onUserPresence(dynamic raw) {
    if (raw is! Map) return;
    final uid = raw['userId'] is int
        ? raw['userId'] as int
        : int.tryParse(raw['userId']?.toString() ?? '');
    final online = raw['online'] == true;
    if (uid == null || uid <= 0) return;
    if (!mounted) return;
    setState(() {
      if (online) {
        _onlineUserIds.add(uid);
      } else {
        _onlineUserIds.remove(uid);
      }
    });
  }

  @override
  void dispose() {
    _socket?.dispose();
    _socket = null;
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final uid = AppSession.userId;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Not logged in';
      });
      return;
    }
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final res = await ConsultationApi.listSessionsForParticipant(
        userId: uid,
        perspective: widget.perspective,
        includeClosed: widget.includeClosed,
      );
      if (!mounted) return;
      if (res['success'] != true) {
        setState(() {
          _loading = false;
          _error = res['message']?.toString() ?? 'Could not load chats';
        });
        return;
      }
      final raw = res['data'];
      final list = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) list.add(Map<String, dynamic>.from(e));
        }
      }
      setState(() {
        _loading = false;
        _error = null;
        _rows = list;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  static int? _intFrom(Map<String, dynamic>? m, String key) {
    if (m == null) return null;
    final v = m[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  String _peerTitle(Map<String, dynamic> row, int myUid) {
    final session = row['session'];
    if (session is! Map) return 'Chat';
    final sm = Map<String, dynamic>.from(session);
    final cust = _intFrom(sm, 'customerUserId');
    final astro = _intFrom(sm, 'astrologerUserId');
    if (cust == myUid) {
      return row['astrologerDisplayName']?.toString() ?? 'Astrologer';
    }
    if (astro == myUid) {
      return row['customerDisplayName']?.toString() ?? 'Customer';
    }
    return 'Chat';
  }

  void _openRow(Map<String, dynamic> row) {
    final session = row['session'];
    if (session is! Map) return;
    final sm = Map<String, dynamic>.from(session);
    final sid = _intFrom(sm, 'id');
    if (sid == null) return;
    final uid = AppSession.userId;
    if (uid == null) return;
    final peer = _peerTitle(row, uid);
    final astroProfileId = _intFrom(sm, 'astrologerId');
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (ctx) => ConsultationRoomScreen(
          existingSessionId: sid,
          astrologerId: astroProfileId,
          peerDisplayName: peer,
        ),
      ),
    )
        .then((_) {
      if (mounted) _load(silent: true);
    });
  }

  static int? _peerUserId(Map<String, dynamic> row, int myUid) {
    final session = row['session'];
    if (session is! Map) return null;
    final sm = Map<String, dynamic>.from(session);
    final cust = _intFrom(sm, 'customerUserId');
    final astro = _intFrom(sm, 'astrologerUserId');
    if (cust == myUid) return astro;
    if (astro == myUid) return cust;
    return null;
  }

  static String? _peerProfileImageUrl(Map<String, dynamic> row, int myUid) {
    final session = row['session'];
    if (session is! Map) return null;
    final sm = Map<String, dynamic>.from(session);
    final cust = _intFrom(sm, 'customerUserId');
    if (cust == myUid) {
      return row['astrologerProfileImageUrl']?.toString().trim();
    }
    return row['customerProfileImageUrl']?.toString().trim();
  }

  static int _unreadCount(Map<String, dynamic> row) {
    final v = row['unreadCount'];
    if (v is int) return v < 0 ? 0 : v;
    if (v is num) return v.toInt().clamp(0, 1 << 30);
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _previewSubtitle(Map<String, dynamic> row) {
    final lm = row['lastMessage'];
    if (lm is! Map) return 'No messages yet';
    final mm = Map<String, dynamic>.from(lm);
    final mt = mm['messageType']?.toString() ?? 'text';
    if (mt == 'image') return '📷 Photo';
    final body = mm['body']?.toString() ?? '';
    if (body.isEmpty) return 'No messages yet';
    return body.length > 80 ? '${body.substring(0, 80)}…' : body;
  }

  Widget _buildPeerAvatar({
    required String? imageUrl,
    required String fallbackLetter,
    required bool showOnline,
    required int unread,
  }) {
    final letter = fallbackLetter.isNotEmpty
        ? fallbackLetter[0].toUpperCase()
        : '?';
    final url = imageUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              backgroundImage: hasUrl ? NetworkImage(url) : null,
              child: !hasUrl
                  ? Text(
                      letter,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : null,
            ),
          ),
          if (showOnline)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          if (unread > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String? _timeLabel(Map<String, dynamic> row) {
    final lm = row['lastMessage'];
    if (lm is Map) {
      final ca = Map<String, dynamic>.from(lm)['createdAt']?.toString();
      if (ca != null && ca.isNotEmpty) {
        final dt = DateTime.tryParse(ca);
        if (dt != null) return _formatTime(dt);
      }
    }
    final la = row['lastActivityAt']?.toString();
    if (la != null && la.isNotEmpty) {
      final dt = DateTime.tryParse(la);
      if (dt != null) return _formatTime(dt);
    }
    return null;
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    if (d == today) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final isPartnerInbox = widget.perspective == 'astrologer';
    final title = isPartnerInbox ? 'Chats' : 'My chats';
    final myUid = AppSession.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && _rows.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => _load(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(silent: true),
                  child: _rows.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.35,
                            ),
                            Center(
                              child: Text(
                                isPartnerInbox
                                    ? 'No chats yet.\nWhen a customer messages you, the thread appears here.'
                                    : 'No chats yet.\nStart one from the Home tab.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final row = _rows[i];
                            final session = row['session'];
                            final status = session is Map
                                ? Map<String, dynamic>.from(session)['status']
                                    ?.toString()
                                : null;
                            final head = myUid != null
                                ? _peerTitle(row, myUid)
                                : 'Chat';
                            final sub = _previewSubtitle(row);
                            final time = _timeLabel(row);
                            final peerUid = myUid != null
                                ? _peerUserId(row, myUid)
                                : null;
                            final peerImg = myUid != null
                                ? _peerProfileImageUrl(row, myUid)
                                : null;
                            final unread = _unreadCount(row);
                            final peerOnline = peerUid != null &&
                                _onlineUserIds.contains(peerUid);
                            final initial = head.isNotEmpty ? head[0] : '?';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: _buildPeerAvatar(
                                imageUrl: peerImg,
                                fallbackLetter: initial,
                                showOnline: peerOnline,
                                unread: unread,
                              ),
                              title: Text(head),
                              subtitle: Text(
                                sub,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (status == 'closed')
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        'Closed',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  if (time != null)
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.secondaryTextColor,
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () => _openRow(row),
                            );
                          },
                        ),
                ),
    );
  }
}
